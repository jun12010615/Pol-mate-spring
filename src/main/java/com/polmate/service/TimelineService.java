package com.polmate.service;

import com.polmate.entity.Case;
import com.polmate.entity.TimelineEvent;
import com.polmate.entity.Transcript;
import com.polmate.repository.CaseRepository;
import com.polmate.repository.RelationPersonRepository;
import com.polmate.repository.TimelineEventRepository;
import com.polmate.repository.TranscriptRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.json.JSONArray;
import org.json.JSONObject;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.transaction.support.TransactionTemplate;

import java.io.*;
import java.net.HttpURLConnection;
import java.net.URL;
import java.nio.charset.StandardCharsets;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.LocalTime;
import java.time.format.DateTimeFormatter;
import java.time.format.DateTimeParseException;
import java.util.*;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
import java.util.concurrent.ConcurrentHashMap;
import java.util.Locale;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
@Slf4j
public class TimelineService {

    /** 동일 사건에 대한 추출·재추출이 겹치지 않도록 (StaleObjectStateException 방지) */
    private final ConcurrentHashMap<String, Object> caseTimelineLocks = new ConcurrentHashMap<>();
    private final ConcurrentHashMap<String, RebuildJob> rebuildJobs = new ConcurrentHashMap<>();

    static final class RebuildJob {
        volatile String status = "running";
        volatile String message = "";
        volatile int processed;
        volatile int total;
        volatile int eventsSaved;
        volatile String currentLabel = "";
    }

    private static final class FlaskCall {
        final boolean ok;
        final String body;
        final String error;

        FlaskCall(boolean ok, String body, String error) {
            this.ok = ok;
            this.body = body;
            this.error = error;
        }
    }

    private static final DateTimeFormatter ISO = DateTimeFormatter.ISO_LOCAL_DATE_TIME;
    private static final Map<String, String> ROLE_COLORS = Map.of(
        "suspect", "#dc2626",
        "victim", "#3d8f6a",
        "witness", "#4a7cdc",
        "reference", "#8b5cf6",
        "statement", "#9ca3af"
    );
    private static final String DEFAULT_LANE_COLOR = "#9ca3af";
    private static final Set<String> EVENT_TYPE_WORDS = Set.of(
        "action", "alibi", "movement", "other", "unknown"
    );

    private record KoreanClock(int hour24, int minute, String phrase, int position) {}

    private static final Pattern[] KR_CLOCK_PATTERNS = {
        Pattern.compile("(오전)\\s*(\\d{1,2})\\s*시(?:\\s*(\\d{1,2})\\s*분)?"),
        Pattern.compile("(오후)\\s*(\\d{1,2})\\s*시(?:\\s*(\\d{1,2})\\s*분)?"),
        Pattern.compile("(밤)\\s*(\\d{1,2})\\s*시(?:\\s*(\\d{1,2})\\s*분)?"),
        Pattern.compile("(저녁)\\s*(\\d{1,2})\\s*시(?:\\s*(\\d{1,2})\\s*분)?"),
        Pattern.compile("(새벽)\\s*(\\d{1,2})\\s*시(?:\\s*(\\d{1,2})\\s*분)?"),
        Pattern.compile("(낮)\\s*(\\d{1,2})\\s*시(?:\\s*(\\d{1,2})\\s*분)?"),
    };

    private static final boolean[] KR_CLOCK_IS_PM = {false, true, true, true, false, false};

    private final TimelineEventRepository eventRepo;
    private final CaseRepository caseRepo;
    private final TranscriptRepository transcriptRepo;
    private final RelationPersonRepository relationPersonRepo;
    private final PlatformTransactionManager transactionManager;

    @Value("${polmate.serv.base-url}")
    private String servBaseUrl;

    @Value("${polmate.timeline.max-text-chars:9000}")
    private int timelineMaxTextChars;

    /** /health 성공 시 true 캐시 → 재추출마다 health 호출 생략. 추출 연결 실패 시 무효화 */
    private volatile Boolean flaskHealthAvailable = null;

    public boolean hasAccess(String caseId, String userId) {
        return caseRepo.checkAccess(caseId, userId).isPresent();
    }

    public Map<String, Object> getTimelineForCase(String caseId, String userId) {
        Map<String, Object> out = new LinkedHashMap<>();
        out.put("success", false);

        if (caseId == null || caseId.isBlank()) {
            out.put("error", "caseId가 필요합니다.");
            return out;
        }
        if (!hasAccess(caseId, userId)) {
            out.put("error", "접근 권한이 없습니다.");
            return out;
        }

        String caseName = caseRepo.findById(caseId).map(Case::getCaseName).orElse("");
        long transcriptCount = transcriptRepo.findByCaseIdOrderByCreatedAtDesc(caseId).size();
        List<TimelineEvent> rows = eventRepo.findByCaseIdOrderBySortOrderAscTimeStartAscEventIdAsc(caseId);
        persistTimelineTimeNormalization(rows);
        List<TimelineEvent> resolved = rows.stream()
            .filter(this::hasTimeSignal)
            .filter(e -> e.getTimeStart() != null)
            .toList();
        long eventCount = resolved.size();

        out.put("success", true);
        out.put("caseId", caseId);
        out.put("caseName", caseName);
        out.put("transcriptCount", transcriptCount);
        out.put("eventCount", eventCount);
        out.put("version", 1);
        out.put("builtAt", LocalDateTime.now().format(ISO));
        attachRebuildJob(out, caseId);

        RebuildJob job = rebuildJobs.get(caseId);
        if (job != null && "running".equals(job.status)) {
            out.put("status", "extracting");
            out.put("message", rebuildProgressMessage(job));
            out.put("timeline", null);
            return out;
        }

        if (eventCount == 0) {
            if (job != null && "failed".equals(job.status)) {
                out.put("status", "failed");
                out.put("message", job.message);
            } else if (job != null && "completed".equals(job.status)) {
                out.put("status", "pending");
                out.put("message", job.message);
            } else {
                out.put("status", transcriptCount == 0 ? "empty" : "pending");
                out.put("message", transcriptCount == 0
                    ? "등록된 조서가 없습니다. 조서 저장 후 타임라인 이벤트가 생성됩니다."
                    : "타임라인 이벤트가 없습니다. 「이벤트 재추출」을 누르거나 조서 저장 후 잠시 기다려 주세요.");
            }
            out.put("timeline", null);
            return out;
        }

        out.put("status", "ready");
        out.put("message", job != null && "completed".equals(job.status) ? job.message : "");
        out.put("timeline", buildTimelineView(caseId, resolved));
        return out;
    }

    private Map<String, Object> buildTimelineView(String caseId, List<TimelineEvent> rows) {
        Map<String, Object> timeline = new LinkedHashMap<>();
        timeline.put("caseId", caseId);

        Optional<Case> caseOpt = caseRepo.findById(caseId);
        Map<String, String> personRoles = buildPersonRoleMap(caseId, caseOpt, rows);

        Map<String, Map<String, Object>> laneMap = new LinkedHashMap<>();
        List<Map<String, Object>> eventDtos = new ArrayList<>();
        Set<String> seenEventKeys = new HashSet<>();
        LocalDateTime min = null;
        LocalDateTime max = null;

        for (TimelineEvent e : rows) {
            if (!hasTimeSignal(e) || e.getTimeStart() == null) continue;
            String personName = nvl(e.getStmtName(), "미상");
            String roleKey = resolvePersonRoleKey(personName, e.getStmtType(), personRoles);
            laneMap.compute(personName, (k, lane) -> {
                if (lane == null) return newLane(personName, roleKey);
                upgradeLaneRole(lane, roleKey);
                return lane;
            });

            LocalDateTime start = e.getTimeStart();
            LocalDateTime end = e.getTimeEnd();
            String precision = nvl(e.getTimePrecision(), "");
            if (precision.isBlank()) {
                precision = e.getTimeStart() != null ? "exact" : "unknown";
            }
            boolean hasClockInQuote = !findAllKoreanClocks(nvl(e.getQuote(), "")).isEmpty();
            boolean timeUncertain = "relative".equals(precision)
                || "unknown".equals(precision)
                || ("approximate".equals(precision) && !hasClockInQuote);

            if (end == null) {
                end = start.plusMinutes(5);
            }

            if (start != null) {
                min = min == null || start.isBefore(min) ? start : min;
            }
            if (end != null) {
                max = max == null || end.isAfter(max) ? end : max;
            }

            String laneId = (String) laneMap.get(personName).get("id");
            String dedupeKey = personName + "|" + formatTime(start) + "|" + formatTime(end)
                + "|" + nvl(e.getLabel(), "") + "|" + e.getEventId();
            if (!seenEventKeys.add(dedupeKey)) continue;

            Map<String, Object> ev = new LinkedHashMap<>();
            ev.put("id", "evt_" + e.getEventId());
            ev.put("laneId", laneId);
            ev.put("type", nvl(e.getEventType(), "unknown"));
            ev.put("start", formatTime(start));
            ev.put("end", formatTime(end));
            ev.put("timeText", nvl(e.getTimeText(), ""));
            ev.put("timePrecision", precision);
            ev.put("timeUncertain", timeUncertain);
            ev.put("label", nvl(e.getLabel(), ""));
            ev.put("place", nvl(e.getPlace(), ""));
            ev.put("quote", nvl(e.getQuote(), ""));
            ev.put("confidence", nvl(e.getConfidence(), "medium"));
            ev.put("actorName", personName);
            ev.put("actorRole", roleKeyToLabel(roleKey));
            ev.put("actorRoleKey", roleKey);
            ev.put("source", Map.of(
                "transcriptId", e.getTranscriptId() != null ? e.getTranscriptId() : 0,
                "stmtName", nvl(e.getStmtName(), ""),
                "stmtType", roleKeyToLabel(roleKey)
            ));
            eventDtos.add(ev);
        }

        if (min == null) {
            min = LocalDateTime.now().minusHours(6);
            max = LocalDateTime.now();
        } else if (max == null) {
            max = min.plusHours(2);
        }
        min = min.minusMinutes(30);
        max = max.plusMinutes(30);

        Map<String, Object> range = new LinkedHashMap<>();
        range.put("start", formatTime(min));
        range.put("end", formatTime(max));
        range.put("paddingMinutes", 30);
        timeline.put("range", range);

        Optional<LocalDateTime[]> crime = inferCrimeWindow(rows);
        crime.ifPresent(win -> {
            Map<String, Object> cw = new LinkedHashMap<>();
            cw.put("start", formatTime(win[0]));
            cw.put("end", formatTime(win[1]));
            cw.put("source", "inferred");
            cw.put("label", "범행 추정 구간");
            timeline.put("crimeWindow", cw);
        });

        timeline.put("lanes", new ArrayList<>(laneMap.values()));
        timeline.put("events", eventDtos);
        timeline.put("gaps", computeGaps(rows, laneMap, crime.orElse(null)));
        return timeline;
    }

    private static int koreanTo24Hour(int hour12, int minute, boolean pm) {
        int h = Math.max(1, Math.min(12, hour12));
        int m = Math.max(0, Math.min(59, minute));
        if (!pm) {
            return h == 12 ? 0 : h;
        }
        return h == 12 ? 12 : (h < 12 ? h + 12 : h);
    }

    private static List<KoreanClock> findAllKoreanClocks(String text) {
        if (text == null || text.isBlank()) {
            return List.of();
        }
        List<KoreanClock> hits = new ArrayList<>();
        for (int i = 0; i < KR_CLOCK_PATTERNS.length; i++) {
            Matcher m = KR_CLOCK_PATTERNS[i].matcher(text);
            boolean pm = KR_CLOCK_IS_PM[i];
            while (m.find()) {
                try {
                    int h12 = Integer.parseInt(m.group(2));
                    String minGroup = m.group(3);
                    int minute = minGroup != null && !minGroup.isBlank() ? Integer.parseInt(minGroup) : 0;
                    int h24 = koreanTo24Hour(h12, minute, pm);
                    hits.add(new KoreanClock(h24, minute, m.group(0).trim(), m.start()));
                } catch (NumberFormatException ignored) {
                }
            }
        }
        hits.sort(Comparator.comparingInt(KoreanClock::position));
        List<KoreanClock> out = new ArrayList<>();
        for (KoreanClock c : hits) {
            if (!out.isEmpty()) {
                KoreanClock prev = out.get(out.size() - 1);
                if (prev.hour24() == c.hour24() && prev.minute() == c.minute()) {
                    continue;
                }
            }
            out.add(c);
        }
        return out;
    }

    private static String mergeDatePrefixTimeText(String existing, String startPhrase, String endPhrase) {
        String ex = nvl(existing, "").trim();
        String datePrefix = "";
        Matcher dm = Pattern.compile("\\d{4}\\s*년\\s*\\d{1,2}\\s*월\\s*\\d{1,2}\\s*일").matcher(ex);
        if (dm.find()) {
            datePrefix = dm.group().trim() + " ";
        }
        String body = (endPhrase != null && !endPhrase.isBlank() && !endPhrase.equals(startPhrase))
            ? startPhrase + " ~ " + endPhrase
            : startPhrase;
        if (!datePrefix.isEmpty() && !body.contains(datePrefix.trim())) {
            return datePrefix + body;
        }
        return body.isBlank() ? ex : body;
    }

    /** quote에 여러 시각이 있으면 첫 시각=시작, 마지막 시각=종료로 보정 (표시·기존 DB용). */
    private void reconcileEventTimesFromQuote(TimelineEvent e) {
        String quote = nvl(e.getQuote(), "");
        if (quote.isBlank()) {
            return;
        }
        List<KoreanClock> clocks = findAllKoreanClocks(quote);
        if (clocks.isEmpty()) {
            return;
        }

        KoreanClock start = clocks.get(0);
        LocalDate base = e.getTimeStart() != null
            ? e.getTimeStart().toLocalDate()
            : LocalDate.now();
        LocalDateTime startDt = LocalDateTime.of(base, LocalTime.of(start.hour24(), start.minute()));
        e.setTimeStart(startDt);

        if (clocks.size() >= 2) {
            KoreanClock end = clocks.get(clocks.size() - 1);
            LocalDateTime endDt = LocalDateTime.of(base, LocalTime.of(end.hour24(), end.minute()));
            if (!endDt.isAfter(startDt)) {
                endDt = endDt.plusDays(1);
            }
            e.setTimeEnd(endDt);
            e.setTimeText(mergeDatePrefixTimeText(e.getTimeText(), start.phrase(), end.phrase()));
        } else {
            LocalDateTime endDt = e.getTimeEnd();
            if (endDt == null || !endDt.isAfter(startDt)) {
                e.setTimeEnd(startDt.plusMinutes(5));
            }
            if (nvl(e.getTimeText(), "").isBlank()) {
                e.setTimeText(start.phrase());
            }
        }
        e.setTimePrecision(inferClockPrecisionFromQuote(quote, start, clocks.size() >= 2 ? clocks.get(clocks.size() - 1) : null));
    }

    /** quote·시각 구문 주변의 경/쯤/대략 등 → approximate, 아니면 exact */
    private static String inferClockPrecisionFromQuote(String quote, KoreanClock start, KoreanClock end) {
        if (isApproximateClockContext(quote, nvl(start.phrase(), ""), start.position())) {
            return "approximate";
        }
        if (end != null && isApproximateClockContext(quote, nvl(end.phrase(), ""), end.position())) {
            return "approximate";
        }
        return "exact";
    }

    private static boolean isApproximateClockContext(String quote, String phrase, int position) {
        if (phrase != null && (phrase.contains("경") || phrase.contains("쯤")
            || phrase.contains("대략") || phrase.contains("무렵"))) {
            return true;
        }
        if (quote == null || quote.isBlank()) {
            return false;
        }
        int from = Math.max(0, position);
        int to = Math.min(quote.length(), from + Math.max(phrase != null ? phrase.length() : 0, 0) + 4);
        if (from < to) {
            String window = quote.substring(from, to);
            if (window.contains("경") || window.contains("쯤")
                || window.contains("대략") || window.contains("무렵")) {
                return true;
            }
        }
        return false;
    }

    private void normalizeTimelineEventTimes(List<TimelineEvent> rows) {
        for (TimelineEvent row : rows) {
            reconcileEventTimesFromQuote(row);
        }
        resolveRelativeDurationsFromText(rows);
        resolveVagueEventTimes(rows);
    }

    private void persistTimelineTimeNormalization(List<TimelineEvent> rows) {
        if (rows.isEmpty()) {
            return;
        }
        Map<Long, TimelineTimeSnapshot> before = new HashMap<>();
        for (TimelineEvent row : rows) {
            if (row.getEventId() != null) {
                before.put(row.getEventId(), TimelineTimeSnapshot.of(row));
            }
        }
        normalizeTimelineEventTimes(rows);
        List<TimelineEvent> dirty = new ArrayList<>();
        for (TimelineEvent row : rows) {
            if (row.getEventId() == null) {
                continue;
            }
            TimelineTimeSnapshot snap = before.get(row.getEventId());
            if (snap != null && !snap.matches(row)) {
                dirty.add(row);
            }
        }
        if (dirty.isEmpty()) {
            return;
        }
        new TransactionTemplate(transactionManager).executeWithoutResult(status -> {
            for (TimelineEvent row : dirty) {
                eventRepo.save(row);
            }
        });
    }

    private static final class TimelineTimeSnapshot {
        private final LocalDateTime timeStart;
        private final LocalDateTime timeEnd;
        private final String timePrecision;
        private final String timeText;

        private TimelineTimeSnapshot(LocalDateTime timeStart, LocalDateTime timeEnd,
                                     String timePrecision, String timeText) {
            this.timeStart = timeStart;
            this.timeEnd = timeEnd;
            this.timePrecision = timePrecision;
            this.timeText = timeText;
        }

        static TimelineTimeSnapshot of(TimelineEvent e) {
            return new TimelineTimeSnapshot(
                e.getTimeStart(), e.getTimeEnd(), e.getTimePrecision(), e.getTimeText());
        }

        boolean matches(TimelineEvent e) {
            return Objects.equals(timeStart, e.getTimeStart())
                && Objects.equals(timeEnd, e.getTimeEnd())
                && Objects.equals(timePrecision, e.getTimePrecision())
                && Objects.equals(timeText, e.getTimeText());
        }
    }

    private static String relativeChainKey(TimelineEvent e) {
        int tid = e.getTranscriptId() != null ? e.getTranscriptId() : 0;
        return tid + "|" + normPersonName(nvl(e.getStmtName(), ""));
    }

    /** 타임라인 저장·표시 대상: 시간 단서가 있는 이벤트만 */
    private boolean hasTimeSignal(TimelineEvent e) {
        if (e.getTimeStart() != null) return true;
        String prec = nvl(e.getTimePrecision(), "");
        String tt = nvl(e.getTimeText(), "");
        if (tt.isEmpty()) return false;
        if ("exact".equals(prec) || "approximate".equals(prec) || "relative".equals(prec)) return true;
        String[] hints = {"시", "분", "쯤", "경", "전", "후", "뒤", "이후", "이전", "당시", "무렵", "오전", "오후", "새벽", "저녁"};
        for (String h : hints) {
            if (tt.contains(h)) return true;
        }
        return false;
    }

    private static final Pattern REL_MINUTES_AFTER = Pattern.compile(
        "(?:약|대략|그때부터|출발(?:한)?\\s*지)?\\s*(\\d{1,4})\\s*분\\s*(?:후|뒤|이후|지난|지나|경과)",
        Pattern.CASE_INSENSITIVE);
    private static final Pattern REL_MINUTES_ELAPSED = Pattern.compile(
        "(?:약|대략)?\\s*(\\d{1,4})\\s*분(?:이|이)?\\s*(?:지난|지나|경과|후|뒤)",
        Pattern.CASE_INSENSITIVE);
    private static final Pattern REL_HOURS_AFTER = Pattern.compile(
        "(?:약|대략)?\\s*(\\d{1,2})\\s*시간\\s*(?:후|뒤|이후|지난|경과|정도)",
        Pattern.CASE_INSENSITIVE);

    /** quote의 'N분 후' → 같은 조서·같은 행위 주체(stmt_name)의 직전 이벤트 time_start + N분. */
    private void resolveRelativeDurationsFromText(List<TimelineEvent> rows) {
        Map<String, List<TimelineEvent>> byChain = rows.stream()
            .collect(Collectors.groupingBy(TimelineService::relativeChainKey));

        for (List<TimelineEvent> group : byChain.values()) {
            group.sort(Comparator.comparingInt(TimelineEvent::getSortOrder)
                .thenComparing(e -> e.getEventId() != null ? e.getEventId() : 0L));
            LocalDateTime lastAnchor = null;
            for (TimelineEvent e : group) {
                String quote = nvl(e.getQuote(), "");
                if (!findAllKoreanClocks(quote).isEmpty()) {
                    lastAnchor = chainAnchorAfterEvent(e);
                    continue;
                }
                String src = quote.isBlank() ? nvl(e.getTimeText(), "") : quote;
                int offMin = parseRelativeOffsetMinutes(src);
                if (offMin < 0) {
                    if (e.getTimeStart() != null) {
                        lastAnchor = chainAnchorAfterEvent(e);
                    }
                    continue;
                }
                if (lastAnchor == null) {
                    continue;
                }
                LocalDateTime start = lastAnchor.plusMinutes(offMin);
                e.setTimeStart(start);
                e.setTimeEnd(start.plusMinutes(5));
                e.setTimePrecision("relative");
                if (nvl(e.getTimeText(), "").isBlank() && !quote.isBlank()) {
                    e.setTimeText(quote.length() > 200 ? quote.substring(0, 199) + "…" : quote);
                }
                lastAnchor = start;
            }
        }
    }

    private static LocalDateTime chainAnchorAfterEvent(TimelineEvent e) {
        return e.getTimeStart();
    }

    /** 분 단위 오프셋, 없으면 -1 */
    private static int parseRelativeOffsetMinutes(String text) {
        if (text == null || text.isBlank()) {
            return -1;
        }
        if (!findAllKoreanClocks(text).isEmpty()) {
            return -1;
        }
        for (Pattern pat : new Pattern[] { REL_MINUTES_AFTER, REL_MINUTES_ELAPSED }) {
            Matcher m = pat.matcher(text);
            if (m.find()) {
                try {
                    return Integer.parseInt(m.group(1));
                } catch (NumberFormatException ignored) {
                }
            }
        }
        Matcher m = REL_HOURS_AFTER.matcher(text);
        if (m.find()) {
            try {
                return Integer.parseInt(m.group(1)) * 60;
            } catch (NumberFormatException ignored) {
            }
        }
        return -1;
    }

    /** time_end 미설정 시 짧은 기본 구간만 부여. */
    private List<TimelineEvent> resolveVagueEventTimes(List<TimelineEvent> rows) {
        for (TimelineEvent e : rows) {
            if (e.getTimeStart() == null) continue;
            if (e.getTimeEnd() == null || !e.getTimeEnd().isAfter(e.getTimeStart())) {
                e.setTimeEnd(e.getTimeStart().plusMinutes(5));
            }
        }
        return rows;
    }

    private Map<String, Object> newLane(String personName, String roleKey) {
        String id = "lane_" + Integer.toHexString(personName.hashCode());
        Map<String, Object> lane = new LinkedHashMap<>();
        lane.put("id", id);
        lane.put("name", personName);
        lane.put("roleKey", roleKey);
        lane.put("role", roleKeyToLabel(roleKey));
        lane.put("color", ROLE_COLORS.getOrDefault(roleKey, DEFAULT_LANE_COLOR));
        return lane;
    }

    private static void upgradeLaneRole(Map<String, Object> lane, String roleKey) {
        String current = (String) lane.get("roleKey");
        if (rolePriority(roleKey) > rolePriority(current)) {
            lane.put("roleKey", roleKey);
            lane.put("role", roleKeyToLabel(roleKey));
            lane.put("color", ROLE_COLORS.getOrDefault(roleKey, DEFAULT_LANE_COLOR));
        }
    }

    private Map<String, String> buildPersonRoleMap(String caseId, Optional<Case> caseOpt, List<TimelineEvent> rows) {
        Map<String, String> map = new HashMap<>();
        caseOpt.map(Case::getSuspect).filter(s -> !s.isBlank())
            .ifPresent(s -> mergePersonRole(map, normPersonName(s), "suspect"));
        for (var p : relationPersonRepo.findByCaseId(caseId)) {
            if (p.getPersonName() == null || p.getPersonName().isBlank()) continue;
            String rk = resolveRoleKey(p.getRole());
            if (!"statement".equals(rk)) {
                mergePersonRole(map, normPersonName(p.getPersonName()), rk);
            }
        }
        for (TimelineEvent e : rows) {
            String name = nvl(e.getStmtName(), "");
            if (name.isBlank()) continue;
            String rk = resolveRoleKey(e.getStmtType());
            if (!"statement".equals(rk)) {
                mergePersonRole(map, normPersonName(name), rk);
            }
        }
        return map;
    }

    private static void mergePersonRole(Map<String, String> map, String nameKey, String roleKey) {
        if (nameKey == null || nameKey.isBlank()) return;
        String existing = map.get(nameKey);
        if (existing == null || rolePriority(roleKey) > rolePriority(existing)) {
            map.put(nameKey, roleKey);
        }
    }

    private static String resolvePersonRoleKey(String personName, String stmtType,
                                               Map<String, String> personRoles) {
        String fromStmt = resolveRoleKey(stmtType);
        if (!"statement".equals(fromStmt)) return fromStmt;
        String key = normPersonName(personName);
        if (!key.isBlank()) {
            String mapped = personRoles.get(key);
            if (mapped != null) return mapped;
        }
        return "statement";
    }

    private static String normPersonName(String name) {
        if (name == null) return "";
        return name.trim().replaceAll("\\s+", "");
    }

    private static String resolveRoleKey(String raw) {
        if (raw == null || raw.isBlank()) return "statement";
        String r = raw.toLowerCase(Locale.ROOT).trim();
        if (r.contains("|")) r = r.substring(0, r.indexOf('|')).trim();
        if (EVENT_TYPE_WORDS.contains(r)) return "statement";
        if (r.contains("suspect") || r.contains("피의자")) return "suspect";
        if (r.contains("victim") || r.contains("피해자") || r.contains("피해")) return "victim";
        if (r.contains("witness") || r.contains("목격")) return "witness";
        if (r.contains("reference") || r.contains("참고인") || r.contains("참고")) return "reference";
        return "statement";
    }

    private static String roleKeyToLabel(String roleKey) {
        return switch (roleKey) {
            case "suspect" -> "피의자";
            case "victim" -> "피해자";
            case "witness" -> "목격자";
            case "reference" -> "참고인";
            default -> "진술자";
        };
    }

    private static int rolePriority(String roleKey) {
        return switch (roleKey) {
            case "suspect" -> 50;
            case "victim" -> 40;
            case "witness" -> 30;
            case "reference" -> 20;
            default -> 10;
        };
    }

    private List<Map<String, Object>> computeGaps(List<TimelineEvent> rows,
                                                   Map<String, Map<String, Object>> laneMap,
                                                   LocalDateTime[] crimeWindow) {
        if (crimeWindow == null) return List.of();

        LocalDateTime cStart = crimeWindow[0];
        LocalDateTime cEnd = crimeWindow[1];
        List<Map<String, Object>> gaps = new ArrayList<>();
        int gapSeq = 0;

        Map<String, List<TimelineEvent>> byLane = rows.stream()
            .collect(Collectors.groupingBy(e -> nvl(e.getStmtName(), "미상")));

        for (Map.Entry<String, List<TimelineEvent>> entry : byLane.entrySet()) {
            String personName = entry.getKey();
            List<TimelineEvent> alibis = entry.getValue().stream()
                .filter(e -> "alibi".equalsIgnoreCase(e.getEventType()))
                .filter(e -> e.getTimeStart() != null)
                .sorted(Comparator.comparing(TimelineEvent::getTimeStart))
                .toList();

            if (alibis.isEmpty()) continue;

            boolean covered = false;
            for (TimelineEvent a : alibis) {
                LocalDateTime aStart = a.getTimeStart();
                LocalDateTime aEnd = a.getTimeEnd() != null ? a.getTimeEnd() : aStart.plusMinutes(30);
                if (!aEnd.isBefore(cStart) && !aStart.isAfter(cEnd)) {
                    covered = true;
                    break;
                }
            }
            if (!covered) {
                @SuppressWarnings("unchecked")
                String laneId = (String) laneMap.get(personName).get("id");
                Map<String, Object> gap = new LinkedHashMap<>();
                gap.put("id", "gap_" + (++gapSeq));
                gap.put("laneId", laneId);
                gap.put("start", formatTime(cStart));
                gap.put("end", formatTime(cEnd));
                gap.put("severity", "high");
                gap.put("reason", "범행 추정 구간에 알리바이 주장이 겹치지 않습니다.");
                gap.put("crimeWindowOverlap", true);
                gaps.add(gap);
            }
        }
        return gaps;
    }

    public Map<String, Object> startRebuildForCase(String caseId, String userId) {
        Map<String, Object> out = new LinkedHashMap<>();
        out.put("success", false);
        if (caseId == null || caseId.isBlank()) {
            out.put("error", "caseId가 필요합니다.");
            return out;
        }
        if (!hasAccess(caseId, userId)) {
            out.put("error", "접근 권한이 없습니다.");
            return out;
        }

        RebuildJob existing = rebuildJobs.get(caseId);
        if (existing != null && "running".equals(existing.status)) {
            out.put("error", "이미 재추출이 진행 중입니다.");
            attachRebuildJob(out, caseId);
            return out;
        }

        List<Transcript> all = transcriptRepo.findByCaseIdOrderByCreatedAtDesc(caseId);
        List<Transcript> targets = all.stream()
            .filter(t -> !resolveTranscriptBody(t).isBlank())
            .toList();

        if (targets.isEmpty()) {
            long docCount = all.size();
            out.put("message", docCount == 0
                ? "등록된 조서가 없습니다. 진술 조서에서 「조서 확정」으로 저장한 뒤 재추출해 주세요."
                : "조서 " + docCount + "건이 있으나 본문이 비어 있습니다. 「조서 확정」으로 원문을 저장했는지 확인해 주세요.");
            return out;
        }

        if (!ensureFlaskAvailable()) {
            out.put("error", "타임라인 AI 서버(" + servBaseUrl + ")에 연결할 수 없습니다. polmate_serv.py 실행 후 /health 를 확인해 주세요.");
            return out;
        }

        scheduleRebuildForCase(caseId, targets);
        out.put("success", true);
        out.put("caseId", caseId);
        out.put("transcriptCount", targets.size());
        out.put("status", "extracting");
        out.put("message", "조서 " + targets.size() + "건에 대해 AI 타임라인 추출을 시작했습니다.");
        attachRebuildJob(out, caseId);
        return out;
    }

    public void scheduleRebuildForCase(String caseId, List<Transcript> targets) {
        RebuildJob job = new RebuildJob();
        job.total = targets.size();
        job.message = "AI 추출 준비 중…";
        rebuildJobs.put(caseId, job);

        Thread t = new Thread(() -> runRebuildForCase(caseId, targets, job), "timeline-rebuild-" + caseId);
        t.setDaemon(true);
        t.start();
    }

    private void runRebuildForCase(String caseId, List<Transcript> targets, RebuildJob job) {
        TransactionTemplate tx = new TransactionTemplate(transactionManager);
        int savedTotal = 0;
        String lastError = null;

        try {
            synchronized (lockForCase(caseId)) {
                tx.executeWithoutResult(status -> eventRepo.deleteByCaseId(caseId));
                for (Transcript tr : targets) {
                    job.processed++;
                    job.currentLabel = nvl(tr.getStmtName(), "조서 #" + tr.getTranscriptId());
                    job.message = rebuildProgressMessage(job);
                    try {
                        int saved = tx.execute(status -> doExtractEventsForTranscript(tr));
                        savedTotal += saved;
                    } catch (Exception e) {
                        lastError = e.getMessage();
                        log.warn("timeline rebuild failed transcriptId={}: {}", tr.getTranscriptId(), e.getMessage(), e);
                    }
                    job.eventsSaved = savedTotal;
                }
            }

            job.eventsSaved = savedTotal;
            if (lastError != null && savedTotal == 0) {
                job.status = "failed";
                job.message = lastError;
            } else if (savedTotal == 0) {
                job.status = "completed";
                job.message = "조서 " + job.processed + "건을 처리했으나, 시간 정보가 있는 이벤트가 추출되지 않았습니다.";
            } else {
                job.status = "completed";
                job.message = "조서 " + job.processed + "건에서 이벤트 " + savedTotal + "건을 추출·저장했습니다.";
            }
        } catch (Exception e) {
            job.status = "failed";
            job.message = "재추출 중 오류: " + e.getMessage();
            log.warn("timeline rebuild case {} failed: {}", caseId, e.getMessage(), e);
        }
    }

    private String rebuildProgressMessage(RebuildJob job) {
        if ("running".equals(job.status)) {
            String who = job.currentLabel.isBlank() ? "" : " · " + job.currentLabel;
            int current = Math.min(Math.max(job.processed, 1), Math.max(job.total, 1));
            return "AI 추출 중 (" + current + "/" + job.total + ")" + who;
        }
        return job.message;
    }

    private void attachRebuildJob(Map<String, Object> out, String caseId) {
        RebuildJob job = rebuildJobs.get(caseId);
        if (job == null) return;
        Map<String, Object> m = new LinkedHashMap<>();
        m.put("status", job.status);
        m.put("message", job.message);
        m.put("processed", job.processed);
        m.put("total", job.total);
        m.put("eventsSaved", job.eventsSaved);
        m.put("currentLabel", job.currentLabel);
        out.put("rebuildJob", m);
    }

    private String resolveTranscriptBody(Transcript tr) {
        String raw;
        if (tr.getOriginalText() != null && !tr.getOriginalText().isBlank()) {
            raw = tr.getOriginalText().trim();
        } else {
            String ai = tr.getAiResult();
            if (ai == null || ai.isBlank()) return "";
            String plain = ai.replaceAll("<[^>]+>", " ").replaceAll("\\s+", " ").trim();
            raw = plain.length() >= 30 ? plain : "";
        }
        return truncateForTimelineExtract(raw);
    }

    private String truncateForTimelineExtract(String text) {
        if (text == null || text.isBlank()) return "";
        int max = Math.max(2000, timelineMaxTextChars);
        if (text.length() <= max) return text;
        String cut = text.substring(0, max);
        int nl = cut.lastIndexOf('\n');
        if (nl > max * 7 / 10) cut = cut.substring(0, nl);
        return cut + "\n…(이하 생략)";
    }

    /** 최초 1회(또는 이전 실패 후)만 /health 호출, 성공하면 이후 재추출에서 생략 */
    private boolean ensureFlaskAvailable() {
        if (Boolean.TRUE.equals(flaskHealthAvailable)) {
            return true;
        }
        boolean ok = pingFlaskHealth();
        if (ok) {
            flaskHealthAvailable = true;
            log.info("Flask health OK — 이후 재추출에서 /health 생략 ({})", servBaseUrl);
        }
        return ok;
    }

    private void invalidateFlaskHealth() {
        flaskHealthAvailable = null;
    }

    private boolean pingFlaskHealth() {
        try {
            URL url = new URL(servBaseUrl + "/health");
            HttpURLConnection conn = (HttpURLConnection) url.openConnection();
            conn.setRequestMethod("GET");
            conn.setConnectTimeout(4000);
            conn.setReadTimeout(4000);
            int code = conn.getResponseCode();
            return code >= 200 && code < 300;
        } catch (Exception e) {
            log.warn("Flask health check failed ({}): {}", servBaseUrl, e.getMessage());
            return false;
        }
    }

    private Object lockForCase(String caseId) {
        return caseTimelineLocks.computeIfAbsent(caseId, k -> new Object());
    }

    private Optional<LocalDateTime[]> inferCrimeWindow(List<TimelineEvent> rows) {
        List<TimelineEvent> actions = rows.stream()
            .filter(e -> "action".equalsIgnoreCase(e.getEventType()) && e.getTimeStart() != null)
            .sorted(Comparator.comparing(TimelineEvent::getTimeStart))
            .toList();
        if (actions.isEmpty()) return Optional.empty();

        LocalDateTime start = actions.get(0).getTimeStart();
        LocalDateTime end = actions.stream()
            .map(e -> e.getTimeEnd() != null ? e.getTimeEnd() : e.getTimeStart().plusMinutes(15))
            .max(LocalDateTime::compareTo)
            .orElse(start.plusMinutes(30));
        return Optional.of(new LocalDateTime[]{start.minusMinutes(15), end.plusMinutes(15)});
    }

    @Transactional
    public TimelineEvent saveEvent(TimelineEvent event) {
        return eventRepo.save(event);
    }

    public void scheduleExtractForTranscript(Integer transcriptId) {
        if (transcriptId == null) return;
        Thread t = new Thread(() -> {
            try {
                extractEventsForTranscript(transcriptId);
            } catch (Exception e) {
                log.warn("timeline extract failed transcriptId={}: {}", transcriptId, e.getMessage(), e);
            }
        }, "timeline-extract-" + transcriptId);
        t.setDaemon(true);
        t.start();
    }

    public void extractEventsForTranscript(Integer transcriptId) {
        Optional<Transcript> opt = transcriptRepo.findById(transcriptId);
        if (opt.isEmpty()) return;

        Transcript tr = opt.get();
        String caseId = tr.getCaseId();
        if (caseId == null || caseId.isBlank()) return;

        synchronized (lockForCase(caseId)) {
            TransactionTemplate tx = new TransactionTemplate(transactionManager);
            tx.executeWithoutResult(status -> doExtractEventsForTranscript(tr));
        }
    }

    private int doExtractEventsForTranscript(Transcript tr) {
        Integer transcriptId = tr.getTranscriptId();
        String text = resolveTranscriptBody(tr);
        if (text.isEmpty()) return 0;

        JSONObject body = new JSONObject();
        body.put("caseId", nvl(tr.getCaseId(), ""));
        body.put("transcriptId", transcriptId);
        body.put("stmtName", nvl(tr.getStmtName(), "미입력"));
        body.put("stmtType", nvl(tr.getStmtType(), "진술자"));
        body.put("text", text);

        FlaskCall fc = callFlask("/timeline/extract", body);
        if (!fc.ok) {
            throw new IllegalStateException(
                "조서 #" + transcriptId + " AI 추출 실패: " + nvl(fc.error, "서버 응답 없음"));
        }

        JSONObject resp;
        try {
            resp = new JSONObject(fc.body);
        } catch (Exception e) {
            throw new IllegalStateException("조서 #" + transcriptId + " 응답 JSON 파싱 실패");
        }
        if (!resp.optBoolean("success", false)) {
            throw new IllegalStateException(
                "조서 #" + transcriptId + " 추출 실패: " + nvl(resp.optString("error", ""), "알 수 없음"));
        }

        JSONArray events = resp.optJSONArray("events");
        eventRepo.deleteByTranscriptId(transcriptId);
        if (events == null || events.isEmpty()) {
            return 0;
        }
        String caseId = tr.getCaseId();
        String defaultActor = nvl(tr.getStmtName(), "미상");
        Map<String, String> personRoles = buildPersonRoleMap(
            caseId, caseRepo.findById(caseId), List.of());
        int order = 0;
        List<TimelineEvent> batch = new ArrayList<>();
        for (int i = 0; i < events.length(); i++) {
            JSONObject ev = events.optJSONObject(i);
            if (ev == null) continue;
            if (!jsonEventHasTimeSignal(ev)) continue;

            String label = pickEventLabel(ev, "이벤트");
            String quote = pickEventQuote(ev);
            if (quote == null || quote.isBlank()) continue;

            String actorName = resolveEventActorName(ev, defaultActor);
            String eventType = nvl(ev.optString("event_type", ev.optString("eventType", "")), "unknown");
            TimelineEvent row = TimelineEvent.builder()
                .caseId(caseId)
                .transcriptId(transcriptId)
                .stmtName(actorName)
                .stmtType(roleKeyToLabel(resolvePersonRoleKeyForExtract(
                    actorName,
                    nvl(ev.optString("stmt_type", ev.optString("stmtType", "")), tr.getStmtType()), tr, personRoles)))
                .eventType(eventType)
                .timeStart(parseDateTime(ev.optString("time_start", ev.optString("timeStart", null))))
                .timeEnd(parseDateTime(ev.optString("time_end", ev.optString("timeEnd", null))))
                .timeText(optString(ev, "time_text", "timeText"))
                .timePrecision(optString(ev, "time_precision", "timePrecision"))
                .place(ev.optString("place", null))
                .label(label)
                .quote(quote)
                .confidence(nvl(ev.optString("confidence", ""), "medium"))
                .sortOrder(ev.optInt("sort_order", ev.optInt("sortOrder", (++order) * 10)))
                .build();
            batch.add(row);
        }
        normalizeTimelineEventTimes(batch);
        int saved = 0;
        for (TimelineEvent row : batch) {
            eventRepo.save(row);
            saved++;
        }
        return saved;
    }

    private FlaskCall callFlask(String path, JSONObject body) {
        HttpURLConnection conn = null;
        try {
            URL url = new URL(servBaseUrl + path);
            conn = (HttpURLConnection) url.openConnection();
            conn.setRequestMethod("POST");
            conn.setRequestProperty("Content-Type", "application/json;charset=UTF-8");
            conn.setDoOutput(true);
            conn.setConnectTimeout(5000);
            conn.setReadTimeout(180000);
            try (OutputStream os = conn.getOutputStream()) {
                os.write(body.toString().getBytes(StandardCharsets.UTF_8));
            }
            int code = conn.getResponseCode();
            InputStream stream = code >= 200 && code < 300
                ? conn.getInputStream()
                : conn.getErrorStream();
            String payload = readStream(stream);
            if (code != 200) {
                if (code >= 500 || code == 0) invalidateFlaskHealth();
                return new FlaskCall(false, null,
                    "HTTP " + code + (payload.isBlank() ? "" : ": " + payload));
            }
            return new FlaskCall(true, payload, null);
        } catch (Exception e) {
            log.warn("Flask call {} failed: {}", path, e.getMessage());
            invalidateFlaskHealth();
            return new FlaskCall(false, null, e.getMessage());
        } finally {
            if (conn != null) conn.disconnect();
        }
    }

    private static String readStream(InputStream stream) throws IOException {
        if (stream == null) return "";
        try (BufferedReader br = new BufferedReader(new InputStreamReader(stream, StandardCharsets.UTF_8))) {
            StringBuilder sb = new StringBuilder();
            String line;
            while ((line = br.readLine()) != null) sb.append(line);
            return sb.toString();
        }
    }

    private static LocalDateTime parseDateTime(String s) {
        if (s == null || s.isBlank()) return null;
        String v = s.trim().replace(' ', 'T');
        try {
            return LocalDateTime.parse(v, ISO);
        } catch (DateTimeParseException e1) {
            try {
                return LocalDateTime.parse(v, DateTimeFormatter.ofPattern("yyyy-MM-dd'T'HH:mm"));
            } catch (DateTimeParseException e2) {
                return null;
            }
        }
    }

    private static String formatTime(LocalDateTime t) {
        return t == null ? null : t.format(ISO);
    }

    private static String nvl(String s, String def) {
        return (s == null || s.isBlank()) ? def : s.trim();
    }

    private static String resolveEventActorName(JSONObject ev, String defaultActor) {
        String name = nvl(ev.optString("stmt_name", ev.optString("stmtName", "")), "").trim();
        if (name.isEmpty()) {
            name = nvl(ev.optString("lane_key", ev.optString("laneKey", "")), "").trim();
        }
        if (name.isEmpty()) {
            name = defaultActor;
        }
        return name;
    }

    private String resolvePersonRoleKeyForExtract(String actorName, String aiStmtType, Transcript tr,
                                                  Map<String, String> personRoles) {
        String fromAi = resolveRoleKey(aiStmtType);
        if (!"statement".equals(fromAi)) return fromAi;
        String rk = resolvePersonRoleKey(actorName, aiStmtType, personRoles);
        if (!"statement".equals(rk)) return rk;
        String trName = normPersonName(tr.getStmtName());
        String person = normPersonName(actorName);
        if (!person.isBlank() && person.equals(trName)) {
            String trRole = resolveRoleKey(tr.getStmtType());
            if (!"statement".equals(trRole)) return trRole;
        }
        return "statement";
    }

    private static String pickEventLabel(JSONObject ev, String fallback) {
        String label = nvl(ev.optString("label", ""), "").trim();
        if (!label.isEmpty() && !"이벤트".equals(label)) return label;
        String timeText = nvl(optString(ev, "time_text", "timeText"), "").trim();
        if (!timeText.isEmpty()) return timeText.length() > 80 ? timeText.substring(0, 79) + "…" : timeText;
        String quote = nvl(ev.optString("quote", ""), "").trim();
        if (!quote.isEmpty()) return quote.length() > 80 ? quote.substring(0, 79) + "…" : quote;
        return label.isEmpty() ? fallback : label;
    }

    private static String pickEventQuote(JSONObject ev) {
        String quote = nvl(ev.optString("quote", ""), "").trim();
        if (!quote.isEmpty()) return quote;
        return null;
    }

    private static String optString(JSONObject ev, String snake, String camel) {
        String v = ev.optString(snake, ev.optString(camel, ""));
        return v.isBlank() ? null : v.trim();
    }

    private static Integer optInteger(JSONObject ev, String snake, String camel) {
        if (ev.has(snake) && !ev.isNull(snake)) return ev.optInt(snake);
        if (ev.has(camel) && !ev.isNull(camel)) return ev.optInt(camel);
        return null;
    }

    private boolean jsonEventHasTimeSignal(JSONObject ev) {
        if (parseDateTime(ev.optString("time_start", ev.optString("timeStart", null))) != null) {
            return true;
        }
        String tt = nvl(optString(ev, "time_text", "timeText"), "");
        if (tt.isEmpty()) return false;
        String prec = nvl(optString(ev, "time_precision", "timePrecision"), "");
        if ("exact".equals(prec) || "approximate".equals(prec) || "relative".equals(prec)) return true;
        String[] hints = {"시", "분", "쯤", "경", "전", "후", "뒤", "이후", "이전", "당시", "무렵", "오전", "오후", "새벽", "저녁"};
        for (String h : hints) {
            if (tt.contains(h)) return true;
        }
        return false;
    }
}
