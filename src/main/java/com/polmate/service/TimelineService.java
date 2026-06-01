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
import java.security.MessageDigest;
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
        volatile int skipped;
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
        "action", "alibi", "movement", "observation", "other", "unknown"
    );

    private record KoreanClock(int hour24, int minute, String phrase, int position) {}

    private static final Pattern[] KR_CLOCK_PATTERNS = {
        Pattern.compile("(오전)\\s*(\\d{1,2})\\s*시(?!\\s*간)(?:\\s*(\\d{1,2})\\s*분)?"),
        Pattern.compile("(오후)\\s*(\\d{1,2})\\s*시(?!\\s*간)(?:\\s*(\\d{1,2})\\s*분)?"),
        Pattern.compile("(밤)\\s*(\\d{1,2})\\s*시(?!\\s*간)(?:\\s*(\\d{1,2})\\s*분)?"),
        Pattern.compile("(저녁)\\s*(\\d{1,2})\\s*시(?!\\s*간)(?:\\s*(\\d{1,2})\\s*분)?"),
        Pattern.compile("(새벽)\\s*(\\d{1,2})\\s*시(?!\\s*간)(?:\\s*(\\d{1,2})\\s*분)?"),
        Pattern.compile("(낮)\\s*(\\d{1,2})\\s*시(?!\\s*간)(?:\\s*(\\d{1,2})\\s*분)?"),
        Pattern.compile("(아침)\\s*(\\d{1,2})\\s*시(?!\\s*간)(?:\\s*(\\d{1,2})\\s*분)?"),
    };

    /** 오전/오후 없는 「3시 10분」「15시」 — signal 탐지와 파싱 일치 */
    private static final Pattern KR_BARE_CLOCK = Pattern.compile(
        "(?<!(?:오전|오후|새벽|저녁|밤|낮|아침)\\s)(\\d{1,2})\\s*시(?!\\s*간)(?:\\s*(\\d{1,2})\\s*분)?");

    private static final Pattern KR_COLON_CLOCK = Pattern.compile("\\d{1,2}\\s*:\\s*\\d{2}");

    private static final Pattern TIMELESS_RELATIONSHIP = Pattern.compile(
        "(?:알고\\s*지낸|지기\\s*친구|비즈니스\\s*관계|관계(?:일|로)\\s*뿐|인맥|아는\\s*사이|"
            + "고교\\s*시절|오래\\s*알|면\\s*알|친분|지인|동창|동업)",
        Pattern.CASE_INSENSITIVE);

    private static final Pattern KR_MONTH_DAY = Pattern.compile("(\\d{1,2})\\s*월\\s*(\\d{1,2})\\s*일");

    private static final boolean[] KR_CLOCK_IS_PM = {false, true, true, true, false, false, false};

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
        Map<Integer, LocalDate> refCache = buildTranscriptReferenceCache(caseId);
        persistTimelineTimeNormalization(rows, refCache);
        List<TimelineEvent> resolved = rows.stream()
            .filter(e -> hasTimeSignal(e, refCache))
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
        out.put("timeline", buildTimelineView(caseId, resolved, refCache));
        return out;
    }

    private Map<String, Object> buildTimelineView(String caseId, List<TimelineEvent> rows,
                                                  Map<Integer, LocalDate> refCache) {
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
            if (!hasTimeSignal(e, refCache) || e.getTimeStart() == null) continue;
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
        int m = Math.max(0, Math.min(59, minute));
        int h = hour12;
        if (h < 0 || h > 23) {
            h = Math.max(1, Math.min(12, h));
        }
        if (!pm) {
            if (h == 12 || h == 0) {
                return 0;
            }
            if (h >= 1 && h <= 11) {
                return h;
            }
            return h % 24;
        }
        if (h == 12) {
            return 12;
        }
        if (h == 0) {
            return 0;
        }
        if (h >= 1 && h <= 11) {
            return h + 12;
        }
        return h;
    }

    private static int inferBareKoreanHour24(int h, String text, int matchStart) {
        h = Math.max(0, Math.min(23, h));
        int from = Math.max(0, matchStart - 24);
        String ctx = text.substring(from, matchStart);
        if (ctx.contains("새벽") || ctx.contains("오전") || ctx.contains("아침")) {
            return h == 12 ? 0 : h;
        }
        if (ctx.contains("오후") || ctx.contains("저녁") || ctx.contains("밤")) {
            if (h == 12) {
                return 12;
            }
            return (h >= 1 && h <= 11) ? h + 12 : h;
        }
        if (h >= 13) {
            return h;
        }
        if (h == 12) {
            return 12;
        }
        if (h >= 1 && h <= 11) {
            return h + 12;
        }
        return 12;
    }

    private static List<KoreanClock> findAllKoreanClocks(String text) {
        if (text == null || text.isBlank()) {
            return List.of();
        }
        List<KoreanClock> hits = new ArrayList<>();
        boolean[] covered = new boolean[text.length() + 1];
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
                    for (int p = m.start(); p < m.end() && p < covered.length; p++) {
                        covered[p] = true;
                    }
                } catch (NumberFormatException ignored) {
                }
            }
        }
        Matcher bare = KR_BARE_CLOCK.matcher(text);
        while (bare.find()) {
            boolean overlap = false;
            for (int p = bare.start(); p < bare.end(); p++) {
                if (p < covered.length && covered[p]) {
                    overlap = true;
                    break;
                }
            }
            if (overlap) {
                continue;
            }
            try {
                int h = Integer.parseInt(bare.group(1));
                String minGroup = bare.group(2);
                int minute = minGroup != null && !minGroup.isBlank() ? Integer.parseInt(minGroup) : 0;
                int h24 = inferBareKoreanHour24(h, text, bare.start());
                hits.add(new KoreanClock(h24, minute, bare.group(0).trim(), bare.start()));
            } catch (NumberFormatException ignored) {
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

    private static final Pattern KR_DATE_PREFIX = Pattern.compile(
        "(\\d{4})\\s*년\\s*(\\d{1,2})\\s*월\\s*(\\d{1,2})\\s*일");

    private static String eventTimeSourceText(TimelineEvent e) {
        return nvl(e.getQuote(), "") + "\n" + nvl(e.getTimeText(), "") + "\n" + nvl(e.getLabel(), "");
    }

    private static LocalDate parseDateFromEventText(String text, LocalDate referenceDate) {
        if (text == null || text.isBlank()) {
            return null;
        }
        Matcher dm = KR_DATE_PREFIX.matcher(text);
        if (dm.find()) {
            try {
                return LocalDate.of(
                    Integer.parseInt(dm.group(1)),
                    Integer.parseInt(dm.group(2)),
                    Integer.parseInt(dm.group(3)));
            } catch (NumberFormatException e) {
                return null;
            }
        }
        if (referenceDate != null) {
            Matcher md = KR_MONTH_DAY.matcher(text);
            if (md.find()) {
                try {
                    return LocalDate.of(
                        referenceDate.getYear(),
                        Integer.parseInt(md.group(1)),
                        Integer.parseInt(md.group(2)));
                } catch (NumberFormatException e) {
                    return null;
                }
            }
            if (text.contains("어제")) {
                return referenceDate.minusDays(1);
            }
            if (text.contains("그제") || text.contains("그저께")) {
                return referenceDate.minusDays(2);
            }
            if (text.contains("오늘") || text.contains("금일")) {
                return referenceDate;
            }
        }
        return null;
    }

    /** 조서 전문부 날짜 → 본문 상단 'YYYY년 M월 D일'. 사건번호는 사용하지 않음. */
    private LocalDate resolveTranscriptReferenceDate(Transcript tr) {
        if (tr.getPreambleYear() != null && tr.getPreambleYear() > 0
            && tr.getPreambleMonth() != null && tr.getPreambleMonth() > 0
            && tr.getPreambleDay() != null && tr.getPreambleDay() > 0) {
            return LocalDate.of(tr.getPreambleYear(), tr.getPreambleMonth(), tr.getPreambleDay());
        }
        return parseReferenceDateFromTranscriptBody(resolveTranscriptBody(tr));
    }

    private static LocalDate parseReferenceDateFromTranscriptBody(String body) {
        if (body == null || body.isBlank()) {
            return null;
        }
        String head = body.length() > 2500 ? body.substring(0, 2500) : body;
        return parseDateFromEventText(head, null);
    }

    private Map<Integer, LocalDate> buildTranscriptReferenceCache(String caseId) {
        Map<Integer, LocalDate> cache = new HashMap<>();
        for (Transcript tr : transcriptRepo.findByCaseIdOrderByCreatedAtDesc(caseId)) {
            if (tr.getTranscriptId() != null) {
                cache.put(tr.getTranscriptId(), resolveTranscriptReferenceDate(tr));
            }
        }
        return cache;
    }

    private LocalDate referenceDateForEvent(TimelineEvent e, Map<Integer, LocalDate> refCache) {
        if (e.getTranscriptId() != null && refCache != null) {
            LocalDate ref = refCache.get(e.getTranscriptId());
            if (ref != null) {
                return ref;
            }
        }
        return null;
    }

    private static final Pattern ISO_DATETIME_IN_TEXT = Pattern.compile(
        "(\\d{4})-(\\d{2})-(\\d{2})[T\\s](\\d{1,2}):(\\d{2})(?::(\\d{2}))?");

    /** quote·기준일에 근거가 있을 때만 time_start/end 확정. */
    private void reconcileEventTimesFromQuote(TimelineEvent e, LocalDate referenceDate) {
        String timeText = nvl(e.getTimeText(), "");
        String label = nvl(e.getLabel(), "");
        String quote = nvl(e.getQuote(), "");
        String sources = eventTimeSourceText(e);
        if (sources.isBlank()) {
            return;
        }

        if (!eventTimeGrounded(e, referenceDate)) {
            sanitizeHallucinatedEventTimes(e, referenceDate);
            return;
        }

        LocalDateTime isoStart = null;
        LocalDateTime fromTt = parseDateTimeFromTextField(timeText);
        if (fromTt != null && (quoteContainsTimeEvidence(quote, timeText, fromTt)
            || (textHasTimelineClockSignal(timeText) && eventTimeGrounded(e, referenceDate)))) {
            isoStart = fromTt;
        }
        if (isoStart == null) {
            LocalDateTime fromLabel = parseDateTimeFromTextField(label);
            if (fromLabel != null && (quoteContainsTimeEvidence(quote, label, fromLabel)
                || (textHasTimelineClockSignal(label) && eventTimeGrounded(e, referenceDate)))) {
                isoStart = fromLabel;
            }
        }
        if (isoStart != null) {
            e.setTimeStart(isoStart);
            LocalDateTime endDt = e.getTimeEnd();
            if (endDt == null || !endDt.isAfter(isoStart)) {
                e.setTimeEnd(isoStart.plusMinutes(5));
            }
            e.setTimePrecision(inferClockPrecisionFromQuote(sources, null, null, timeText));
            return;
        }

        KoreanClock start = pickStartClock(timeText, label, quote);
        if (start == null) {
            sanitizeHallucinatedEventTimes(e, referenceDate);
            return;
        }
        LocalDate base = parseDateFromEventText(quote, referenceDate);
        if (base == null) {
            base = parseDateFromEventText(timeText, referenceDate);
        }
        if (base == null) {
            base = parseDateFromEventText(label, referenceDate);
        }
        if (base == null && referenceDate != null
            && textHasTimelineClockSignal(quote, timeText, label)) {
            base = referenceDate;
        }
        if (base == null) {
            e.setTimeStart(null);
            e.setTimeEnd(null);
            e.setTimePrecision("unknown");
            if (timeText.isBlank()) {
                e.setTimeText(start.phrase());
            }
            return;
        }

        LocalDateTime startDt = LocalDateTime.of(base, LocalTime.of(start.hour24(), start.minute()));
        e.setTimeStart(startDt);

        KoreanClock endClock = pickEndClock(timeText, label, quote, start);
        if (endClock != null) {
            LocalDateTime endDt = LocalDateTime.of(base, LocalTime.of(endClock.hour24(), endClock.minute()));
            if (!endDt.isAfter(startDt)) {
                endDt = endDt.plusDays(1);
            }
            e.setTimeEnd(endDt);
            if (timeText.isBlank() || !timeTextContainsClock(timeText, endClock)) {
                e.setTimeText(mergeDatePrefixTimeText(e.getTimeText(), start.phrase(), endClock.phrase()));
            }
        } else {
            LocalDateTime endDt = e.getTimeEnd();
            if (endDt == null || !endDt.isAfter(startDt)) {
                e.setTimeEnd(startDt.plusMinutes(5));
            }
            if (timeText.isBlank()) {
                e.setTimeText(mergeDatePrefixTimeText("", start.phrase(), null));
            }
        }
        e.setTimePrecision(inferClockPrecisionFromQuote(sources, start, endClock, timeText));
    }

    private static LocalDateTime parseDateTimeFromTextField(String text) {
        if (text == null || text.isBlank()) {
            return null;
        }
        LocalDateTime direct = parseDateTime(text.trim());
        if (direct != null) {
            return direct;
        }
        Matcher m = ISO_DATETIME_IN_TEXT.matcher(text);
        if (!m.find()) {
            return null;
        }
        try {
            int sec = m.group(6) != null ? Integer.parseInt(m.group(6)) : 0;
            return LocalDateTime.of(
                Integer.parseInt(m.group(1)),
                Integer.parseInt(m.group(2)),
                Integer.parseInt(m.group(3)),
                Integer.parseInt(m.group(4)),
                Integer.parseInt(m.group(5)),
                sec);
        } catch (NumberFormatException e) {
            return null;
        }
    }

    private static KoreanClock pickStartClock(String timeText, String label, String quote) {
        for (String src : List.of(quote, timeText, label)) {
            if (src.isBlank()) {
                continue;
            }
            List<KoreanClock> clocks = findAllKoreanClocks(src);
            if (!clocks.isEmpty()) {
                return clocks.get(0);
            }
        }
        return null;
    }

    private static KoreanClock pickEndClock(String timeText, String label, String quote, KoreanClock start) {
        for (String src : List.of(quote, timeText, label)) {
            if (src.isBlank()) {
                continue;
            }
            List<KoreanClock> clocks = findAllKoreanClocks(src);
            if (clocks.size() >= 2) {
                KoreanClock end = clocks.get(clocks.size() - 1);
                if (end.hour24() != start.hour24() || end.minute() != start.minute()) {
                    return end;
                }
            }
        }
        return null;
    }

    private static boolean timeTextContainsClock(String timeText, KoreanClock clock) {
        if (timeText.isBlank()) {
            return false;
        }
        for (KoreanClock c : findAllKoreanClocks(timeText)) {
            if (c.hour24() == clock.hour24() && c.minute() == clock.minute()) {
                return true;
            }
        }
        return false;
    }

    /** quote·time_text·시각 구문 주변의 경/쯤/대략 등 → approximate, 아니면 exact */
    private static String inferClockPrecisionFromQuote(String sources, KoreanClock start, KoreanClock end,
                                                       String timeText) {
        String precText = !nvl(timeText, "").isBlank() ? timeText : sources;
        if (start != null && isApproximateClockContext(precText, nvl(start.phrase(), ""), start.position())) {
            return "approximate";
        }
        if (end != null && isApproximateClockContext(precText, nvl(end.phrase(), ""), end.position())) {
            return "approximate";
        }
        if (precText.contains("경") || precText.contains("쯤") || precText.contains("대략") || precText.contains("무렵")) {
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

    private static final String[] SAME_TIME_CONNECTORS = {
        "대신", "그러나", "그런데", "하지만", "이어", "한편", "그리고", "그 후", "이후", "곧"
    };

    private static final Pattern DUR_HOURS_SPAN = Pattern.compile(
        "(\\d{1,2})\\s*시간\\s*동안", Pattern.CASE_INSENSITIVE);
    private static final Pattern DUR_MINUTES_SPAN = Pattern.compile(
        "(\\d{1,4})\\s*분\\s*동안", Pattern.CASE_INSENSITIVE);

    private void normalizeTimelineEventTimes(List<TimelineEvent> rows) {
        normalizeTimelineEventTimes(rows, false);
    }

    private void normalizeTimelineEventTimes(List<TimelineEvent> rows, boolean deleteMergedRows) {
        normalizeTimelineEventTimes(rows, deleteMergedRows, null);
    }

    private void normalizeTimelineEventTimes(List<TimelineEvent> rows, boolean deleteMergedRows, LocalDate referenceDate) {
        for (TimelineEvent row : rows) {
            reconcileEventTimesFromQuote(row, referenceDate);
        }
        resolveRelativeDurationsFromText(rows);
        applyActivityDurationEnd(rows);
        mergeSamePeriodAlibiBlocks(rows, deleteMergedRows);
        inheritSameTimeContext(rows);
        sanitizeAllEventTimes(rows, referenceDate);
        resolveVagueEventTimes(rows);
    }

    private static boolean quoteContainsTimeEvidence(String quote, String field, LocalDateTime dt) {
        if (quote == null || quote.isBlank() || dt == null) {
            return false;
        }
        if (field != null && !field.isBlank() && quote.contains(field.trim())) {
            return true;
        }
        String iso = dt.format(ISO);
        return quote.contains(iso) || textHasTimelineClockSignal(quote);
    }

    private void applyActivityDurationEnd(List<TimelineEvent> rows) {
        for (TimelineEvent e : rows) {
            LocalDateTime start = e.getTimeStart();
            if (start == null) continue;
            String src = nvl(e.getQuote(), "") + " " + nvl(e.getTimeText(), "");
            Integer mins = parseActivityDurationMinutes(src);
            if (mins == null || mins <= 0) continue;
            e.setTimeEnd(start.plusMinutes(mins));
        }
    }

    private static Integer parseActivityDurationMinutes(String text) {
        if (text == null || text.isBlank()) return null;
        Matcher hm = DUR_HOURS_SPAN.matcher(text);
        if (hm.find()) {
            try {
                return Integer.parseInt(hm.group(1)) * 60;
            } catch (NumberFormatException ignored) {
            }
        }
        Matcher mm = DUR_MINUTES_SPAN.matcher(text);
        if (mm.find()) {
            try {
                return Integer.parseInt(mm.group(1));
            } catch (NumberFormatException ignored) {
            }
        }
        return null;
    }

    private void mergeSamePeriodAlibiBlocks(List<TimelineEvent> rows, boolean deleteMergedRows) {
        if (rows.isEmpty()) return;
        List<TimelineEvent> sorted = new ArrayList<>(rows);
        sorted.sort(Comparator.comparingInt(TimelineEvent::getSortOrder)
            .thenComparing(e -> e.getEventId() != null ? e.getEventId() : 0L));
        List<TimelineEvent> merged = new ArrayList<>();
        int i = 0;
        while (i < sorted.size()) {
            TimelineEvent ev = sorted.get(i);
            if (!isAlibiLikeEvent(ev)) {
                merged.add(ev);
                i++;
                continue;
            }
            List<TimelineEvent> cluster = new ArrayList<>();
            cluster.add(ev);
            int j = i + 1;
            while (j < sorted.size() && canMergeAlibiCluster(cluster.get(cluster.size() - 1), sorted.get(j))) {
                cluster.add(sorted.get(j));
                j++;
            }
            if (cluster.size() == 1) {
                merged.add(ev);
            } else {
                merged.add(combineAlibiCluster(cluster, deleteMergedRows));
            }
            i = j;
        }
        rows.clear();
        rows.addAll(merged);
    }

    private static boolean isAlibiLikeEvent(TimelineEvent e) {
        String t = nvl(e.getEventType(), "").toLowerCase(Locale.ROOT);
        if ("alibi".equals(t) || "movement".equals(t)) return true;
        String q = nvl(e.getQuote(), "") + " " + nvl(e.getLabel(), "");
        return q.contains("알리바이") || q.contains("있었") || q.contains("하지 않")
            || q.contains("얼씬") || q.contains("당시") || q.contains("혼자") || q.contains("들어가");
    }

    private static boolean isSameSpeakerAlibiContinuation(String quote) {
        if (quote.isBlank()) return false;
        if (quote.matches(".*당시\\s*(저는|나는|제가).*")) return true;
        if ((quote.contains("긴 했지만") || quote.contains("얼씬도") || quote.contains("하지 않았"))
            && (quote.contains("저는") || quote.contains("제가") || quote.contains("나는") || quote.contains("혼자"))) {
            return true;
        }
        return false;
    }

    private static boolean canMergeAlibiCluster(TimelineEvent a, TimelineEvent b) {
        if (!relativeChainKey(a).equals(relativeChainKey(b))) return false;
        if (!isAlibiLikeEvent(a) || !isAlibiLikeEvent(b)) return false;
        String bq = nvl(b.getQuote(), "");
        if (bq.contains("대신") && (bq.contains("봤") || bq.contains("보았") || bq.contains("목격"))) {
            return false;
        }
        if (isSameSpeakerAlibiContinuation(bq)) return true;
        if (bq.contains("당시") && (bq.contains("저는") || bq.contains("제가") || bq.contains("혼자"))) {
            return true;
        }
        LocalDateTime aStart = a.getTimeStart();
        LocalDateTime bStart = b.getTimeStart();
        if (aStart != null && bStart != null) {
            long sec = Math.abs(java.time.Duration.between(aStart, bStart).getSeconds());
            return sec <= 3600;
        }
        return false;
    }

    private static String excerptLabelFromQuote(String quote, int maxLen) {
        String q = nvl(quote, "").trim();
        if (q.isEmpty()) return "";
        for (String sep : List.of("습니다.", "했습니다.", "다.", "요.", "죠.")) {
            int idx = q.indexOf(sep);
            if (idx > 0 && idx <= maxLen * 2) {
                return q.substring(0, idx + sep.length()).trim();
            }
        }
        if (q.length() <= maxLen) return q;
        return q.substring(0, maxLen).stripTrailing() + "…";
    }

    private static String mergeClusterLabelFromQuotes(List<String> quotes, List<String> labels) {
        if (quotes.size() == 1) {
            String ex = excerptLabelFromQuote(quotes.get(0), 150);
            if (!ex.isBlank()) return ex;
        }
        if (quotes.size() >= 2) {
            String a = excerptLabelFromQuote(quotes.get(0), 60);
            String b = excerptLabelFromQuote(quotes.get(quotes.size() - 1), 60);
            if (!a.isBlank() && !b.isBlank()) {
                String merged = a + " … " + b;
                return merged.length() > 200 ? merged.substring(0, 200) : merged;
            }
            if (!a.isBlank()) return a;
        }
        if (labels.size() == 1) return labels.get(0);
        if (labels.size() >= 2) {
            String first = labels.get(0);
            String last = labels.get(labels.size() - 1);
            return first.substring(0, Math.min(80, first.length())) + " … "
                + last.substring(0, Math.min(80, last.length()));
        }
        return "";
    }

    private TimelineEvent combineAlibiCluster(List<TimelineEvent> cluster, boolean deleteMergedRows) {
        TimelineEvent base = cluster.get(0);
        StringBuilder quotes = new StringBuilder();
        List<String> quoteList = new ArrayList<>();
        List<String> labels = new ArrayList<>();
        String place = null;
        LocalDateTime maxEnd = base.getTimeEnd();
        for (TimelineEvent ev : cluster) {
            String q = nvl(ev.getQuote(), "").trim();
            if (!q.isBlank()) {
                if (!quoteList.contains(q)) quoteList.add(q);
                if (quotes.length() > 0) quotes.append(" / ");
                if (!quotes.toString().contains(q)) quotes.append(q);
            }
            String lb = nvl(ev.getLabel(), "").trim();
            if (!lb.isBlank()) labels.add(lb);
            if (ev.getPlace() != null && !ev.getPlace().isBlank()) place = ev.getPlace();
            String src = nvl(ev.getQuote(), "") + " " + nvl(ev.getTimeText(), "");
            Integer mins = parseActivityDurationMinutes(src);
            if (base.getTimeStart() != null && mins != null) {
                LocalDateTime cand = base.getTimeStart().plusMinutes(mins);
                if (maxEnd == null || cand.isAfter(maxEnd)) maxEnd = cand;
            }
            if (ev.getTimeEnd() != null && (maxEnd == null || ev.getTimeEnd().isAfter(maxEnd))) {
                maxEnd = ev.getTimeEnd();
            }
        }
        base.setEventType("alibi");
        if (quotes.length() > 0) {
            String q = quotes.toString();
            base.setQuote(q.length() > 65000 ? q.substring(0, 65000) : q);
        }
        String mergedLabel = mergeClusterLabelFromQuotes(quoteList, labels);
        if (!mergedLabel.isBlank()) {
            base.setLabel(mergedLabel);
        }
        if (place != null) base.setPlace(place);
        if (maxEnd != null) base.setTimeEnd(maxEnd);
        base.setSortOrder(cluster.stream().mapToInt(TimelineEvent::getSortOrder).min().orElse(base.getSortOrder()));
        for (int k = 1; k < cluster.size(); k++) {
            TimelineEvent extra = cluster.get(k);
            if (deleteMergedRows && extra.getEventId() != null) {
                eventRepo.delete(extra);
            }
        }
        return base;
    }

    /** 앞 이벤트에만 시각이 있고 뒤 절이 대신·부재·목격 후술이면 동일 시각대 상속. */
    private void inheritSameTimeContext(List<TimelineEvent> rows) {
        Map<String, List<TimelineEvent>> byChain = rows.stream()
            .collect(Collectors.groupingBy(TimelineService::relativeChainKey));

        for (List<TimelineEvent> group : byChain.values()) {
            group.sort(Comparator.comparingInt(TimelineEvent::getSortOrder)
                .thenComparing(e -> e.getEventId() != null ? e.getEventId() : 0L));
            TimelineEvent lastTimed = null;
            for (TimelineEvent e : group) {
                String quote = nvl(e.getQuote(), "");
                if (!findAllKoreanClocks(quote).isEmpty()) {
                    if (e.getTimeStart() != null) {
                        lastTimed = e;
                    }
                    continue;
                }
                if (lastTimed == null || !quoteNeedsSameTimeInherit(quote)) {
                    if (e.getTimeStart() != null) {
                        lastTimed = e;
                    }
                    continue;
                }
                if (e.getTimeStart() != null) {
                    lastTimed = e;
                    continue;
                }
                LocalDateTime anchor = lastTimed.getTimeStart();
                if (anchor == null) {
                    continue;
                }
                e.setTimeStart(anchor);
                e.setTimeEnd(anchor.plusMinutes(5));
                String prec = nvl(e.getTimePrecision(), "");
                if (!"exact".equals(prec) && !"approximate".equals(prec) && !"relative".equals(prec)) {
                    String prevPrec = nvl(lastTimed.getTimePrecision(), "approximate");
                    e.setTimePrecision(
                        "exact".equals(prevPrec) || "approximate".equals(prevPrec) ? prevPrec : "approximate");
                }
                if (nvl(e.getTimeText(), "").isBlank()) {
                    String prevTt = nvl(lastTimed.getTimeText(), "");
                    if (!prevTt.isBlank()) {
                        e.setTimeText(prevTt + " (동일 시각대)");
                    }
                }
                lastTimed = e;
            }
        }
    }

    private static boolean quoteNeedsSameTimeInherit(String quote) {
        if (quote.isBlank() || !findAllKoreanClocks(quote).isEmpty()) {
            return false;
        }
        if (isSameSpeakerAlibiContinuation(quote)) {
            return false;
        }
        if (quote.contains("대신") && (quote.contains("봤") || quote.contains("보았") || quote.contains("목격")
            || quote.contains("보이지") || quote.contains("없었") || quote.contains("있었"))) {
            return true;
        }
        return quote.contains("그러나") || quote.contains("그런데") || quote.contains("하지만");
    }


    private void persistTimelineTimeNormalization(List<TimelineEvent> rows, Map<Integer, LocalDate> refCache) {
        if (rows.isEmpty()) {
            return;
        }
        Map<Long, TimelineTimeSnapshot> before = new HashMap<>();
        for (TimelineEvent row : rows) {
            if (row.getEventId() != null) {
                before.put(row.getEventId(), TimelineTimeSnapshot.of(row));
            }
        }
        Map<Integer, List<TimelineEvent>> byTranscript = rows.stream()
            .collect(Collectors.groupingBy(e -> e.getTranscriptId() != null ? e.getTranscriptId() : 0));
        new TransactionTemplate(transactionManager).executeWithoutResult(status -> {
            for (Map.Entry<Integer, List<TimelineEvent>> entry : byTranscript.entrySet()) {
                LocalDate ref = entry.getKey() != 0
                    ? referenceDateForEvent(entry.getValue().get(0), refCache)
                    : null;
                normalizeTimelineEventTimes(entry.getValue(), true, ref);
            }
            for (TimelineEvent row : rows) {
                if (row.getEventId() == null) {
                    continue;
                }
                TimelineTimeSnapshot snap = before.get(row.getEventId());
                if (snap != null && !snap.matches(row)) {
                    eventRepo.save(row);
                }
            }
        });
    }

    private static final class TimelineTimeSnapshot {
        private final LocalDateTime timeStart;
        private final LocalDateTime timeEnd;
        private final String timePrecision;
        private final String timeText;
        private final String label;

        private TimelineTimeSnapshot(LocalDateTime timeStart, LocalDateTime timeEnd,
                                     String timePrecision, String timeText, String label) {
            this.timeStart = timeStart;
            this.timeEnd = timeEnd;
            this.timePrecision = timePrecision;
            this.timeText = timeText;
            this.label = label;
        }

        static TimelineTimeSnapshot of(TimelineEvent e) {
            return new TimelineTimeSnapshot(
                e.getTimeStart(), e.getTimeEnd(), e.getTimePrecision(), e.getTimeText(), e.getLabel());
        }

        boolean matches(TimelineEvent e) {
            return Objects.equals(timeStart, e.getTimeStart())
                && Objects.equals(timeEnd, e.getTimeEnd())
                && Objects.equals(timePrecision, e.getTimePrecision())
                && Objects.equals(timeText, e.getTimeText())
                && Objects.equals(label, e.getLabel());
        }
    }

    private static String relativeChainKey(TimelineEvent e) {
        int tid = e.getTranscriptId() != null ? e.getTranscriptId() : 0;
        return tid + "|" + normPersonName(nvl(e.getStmtName(), ""));
    }

    /** 타임라인 저장·표시 대상: quote(원문)에 시간 근거가 있는 이벤트만 */
    private boolean hasTimeSignal(TimelineEvent e, Map<Integer, LocalDate> refCache) {
        return eventTimeGrounded(e, referenceDateForEvent(e, refCache));
    }

    private static boolean eventTimeGrounded(TimelineEvent e, LocalDate referenceDate) {
        String quote = nvl(e.getQuote(), "").trim();
        String timeText = nvl(e.getTimeText(), "").trim();
        if (quote.isBlank()) {
            return false;
        }
        if (isTimelessRelationshipStatement(e)) {
            return false;
        }
        if (textHasTimelineClockSignal(quote)) {
            return true;
        }
        if (tryParseRelativeOffsetMinutes(quote) != null) {
            return true;
        }
        if (parseDateFromEventText(quote, referenceDate) != null) {
            return true;
        }
        String label = nvl(e.getLabel(), "").trim();
        if (!timeText.isBlank() && textHasTimelineClockSignal(timeText)
            && clockPhraseOverlapsQuote(timeText, quote, label)) {
            return true;
        }
        if (referenceDate != null && textHasTimelineClockSignal(quote, timeText)) {
            return true;
        }
        return "observation".equalsIgnoreCase(nvl(e.getEventType(), ""))
            && observationHasTimeAnchor(e);
    }

    private static boolean clockPhraseOverlapsQuote(String timeText, String quote, String label) {
        if (timeText.isBlank()) {
            return false;
        }
        if (!quote.isBlank() && quote.contains(timeText)) {
            return true;
        }
        if (!label.isBlank() && label.contains(timeText)) {
            return true;
        }
        for (KoreanClock c : findAllKoreanClocks(timeText)) {
            if (!quote.isBlank() && quote.contains(c.phrase())) {
                return true;
            }
            if (!label.isBlank() && label.contains(c.phrase())) {
                return true;
            }
        }
        Matcher md = KR_MONTH_DAY.matcher(timeText);
        if (md.find()) {
            String frag = md.group(0);
            if ((!quote.isBlank() && quote.contains(frag)) || (!label.isBlank() && label.contains(frag))) {
                return true;
            }
        }
        return quote.isBlank() && label.isBlank();
    }

    private static boolean isTimelessRelationshipStatement(TimelineEvent e) {
        String quote = nvl(e.getQuote(), "").trim();
        if (quote.isBlank()) {
            return false;
        }
        if (textHasTimelineClockSignal(quote) || tryParseRelativeOffsetMinutes(quote) != null) {
            return false;
        }
        if (!TIMELESS_RELATIONSHIP.matcher(quote).find()) {
            return false;
        }
        String[] timedActions = {"갔", "왔", "했다", "하였", "만났", "출발", "도착", "이동", "들어", "나갔", "머물", "체류", "방문"};
        for (String v : timedActions) {
            if (quote.contains(v)) {
                return false;
            }
        }
        return true;
    }

    private void sanitizeHallucinatedEventTimes(TimelineEvent e, LocalDate referenceDate) {
        if (eventTimeGrounded(e, referenceDate)) {
            return;
        }
        e.setTimeStart(null);
        e.setTimeEnd(null);
        e.setTimePrecision("unknown");
        String tt = nvl(e.getTimeText(), "");
        String quote = nvl(e.getQuote(), "");
        if (!tt.isBlank() && !quote.isBlank() && !quote.contains(tt) && !textHasTimelineClockSignal(quote)) {
            e.setTimeText(null);
        }
    }

    private void sanitizeAllEventTimes(List<TimelineEvent> rows, LocalDate referenceDate) {
        for (TimelineEvent row : rows) {
            sanitizeHallucinatedEventTimes(row, referenceDate);
        }
    }

    private static boolean observationHasTimeAnchor(TimelineEvent e) {
        String quote = nvl(e.getQuote(), "");
        if (textHasTimelineClockSignal(quote)) {
            return true;
        }
        if (tryParseRelativeOffsetMinutes(quote) != null) {
            return true;
        }
        return quote.contains("대신")
            && (quote.contains("봤") || quote.contains("보았") || quote.contains("목격")
            || quote.contains("보이지") || quote.contains("없었") || quote.contains("있었"));
    }

    private static boolean textHasTimelineClockSignal(String... parts) {
        if (parts == null || parts.length == 0) {
            return false;
        }
        if (parts.length == 1) {
            return textHasTimelineClockSignalInText(parts[0]);
        }
        StringBuilder sb = new StringBuilder();
        for (String p : parts) {
            if (p != null && !p.isBlank()) {
                if (sb.length() > 0) sb.append(' ');
                sb.append(p.trim());
            }
        }
        return textHasTimelineClockSignalInText(sb.toString());
    }

    private static boolean textHasTimelineClockSignalInText(String joined) {
        if (joined == null || joined.isBlank()) {
            return false;
        }
        if (!findAllKoreanClocks(joined).isEmpty()) {
            return true;
        }
        if (REL_MINUTES_AFTER.matcher(joined).find() || REL_HOURS_AFTER.matcher(joined).find()) {
            return true;
        }
        if (ISO_DATETIME_IN_TEXT.matcher(joined).find()) {
            return true;
        }
        if (KR_MONTH_DAY.matcher(joined).find()) {
            return true;
        }
        if (joined.matches(".*\\d{4}\\s*년\\s*\\d{1,2}\\s*월.*")) {
            return true;
        }
        if (joined.matches(".*\\d{1,2}/\\d{1,2}.*")) {
            return true;
        }
        if (joined.contains("당일") || joined.contains("그날") || joined.contains("이날")
            || joined.contains("금일") || joined.contains("범행 당시") || joined.contains("사건 당시")
            || joined.contains("어제") || joined.contains("그제") || joined.contains("그저께")
            || joined.contains("오늘")) {
            return true;
        }
        return KR_COLON_CLOCK.matcher(joined).find() || KR_BARE_CLOCK.matcher(joined).find();
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
                if (offMin < 0 && !quote.isBlank() && !nvl(e.getTimeText(), "").isBlank()) {
                    offMin = parseRelativeOffsetMinutes(quote);
                }
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

    /** 분 단위 오프셋(N분 후 등). 상대 표현을 먼저 찾고, 없을 때만 절대 시각으로 판단. */
    private static int parseRelativeOffsetMinutes(String text) {
        if (text == null || text.isBlank()) {
            return -1;
        }
        Integer rel = tryParseRelativeOffsetMinutes(text);
        if (rel != null) {
            return rel;
        }
        if (!findAllKoreanClocks(text).isEmpty()) {
            return -1;
        }
        return -1;
    }

    private static Integer tryParseRelativeOffsetMinutes(String text) {
        for (Pattern pat : new Pattern[] { REL_MINUTES_AFTER, REL_MINUTES_ELAPSED }) {
            Matcher m = pat.matcher(text);
            if (m.find()) {
                try {
                    return Integer.parseInt(m.group(1));
                } catch (NumberFormatException ignored) {
                }
            }
        }
        Matcher hm = REL_HOURS_AFTER.matcher(text);
        if (hm.find()) {
            try {
                return Integer.parseInt(hm.group(1)) * 60;
            } catch (NumberFormatException ignored) {
            }
        }
        return null;
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
        return startRebuildForCase(caseId, userId, false);
    }

    /** DEV-ONLY: 본문 해시 동일해도 전 조서 AI 재추출. 배포 전 삭제. */
    public Map<String, Object> startDevRebuildForCase(String caseId, String userId) {
        return startRebuildForCase(caseId, userId, true);
    }

    private Map<String, Object> startRebuildForCase(String caseId, String userId, boolean forceExtract) {
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

        long toExtract = forceExtract
            ? targets.size()
            : targets.stream().filter(t -> !shouldSkipExtract(t)).count();
        long skipCount = targets.size() - toExtract;

        if (!forceExtract && toExtract == 0) {
            RebuildJob job = new RebuildJob();
            job.status = "completed";
            job.total = targets.size();
            job.processed = targets.size();
            job.skipped = targets.size();
            job.message = "조서 " + targets.size() + "건 본문 동일 — 기존 타임라인 이벤트를 유지했습니다.";
            rebuildJobs.put(caseId, job);
            out.put("success", true);
            out.put("caseId", caseId);
            out.put("transcriptCount", targets.size());
            out.put("status", "completed");
            out.put("message", job.message);
            attachRebuildJob(out, caseId);
            return out;
        }

        scheduleRebuildForCase(caseId, targets, forceExtract);
        out.put("success", true);
        out.put("caseId", caseId);
        out.put("transcriptCount", targets.size());
        out.put("status", "extracting");
        if (forceExtract) {
            out.put("message", "[개발용] 조서 " + targets.size() + "건 강제 AI 재추출을 시작했습니다.");
        } else if (skipCount > 0) {
            out.put("message", "조서 " + targets.size() + "건 중 " + toExtract + "건만 AI 추출(나머지 " + skipCount + "건은 기존 이벤트 유지).");
        } else {
            out.put("message", "조서 " + targets.size() + "건에 대해 AI 타임라인 추출을 시작했습니다.");
        }
        attachRebuildJob(out, caseId);
        return out;
    }

    public void scheduleRebuildForCase(String caseId, List<Transcript> targets) {
        scheduleRebuildForCase(caseId, targets, false);
    }

    private void scheduleRebuildForCase(String caseId, List<Transcript> targets, boolean forceExtract) {
        RebuildJob job = new RebuildJob();
        job.total = targets.size();
        job.message = forceExtract ? "[개발용] AI 추출 준비 중…" : "AI 추출 준비 중…";
        rebuildJobs.put(caseId, job);

        String threadName = forceExtract ? "timeline-rebuild-dev-" + caseId : "timeline-rebuild-" + caseId;
        Thread t = new Thread(() -> runRebuildForCase(caseId, targets, job, forceExtract), threadName);
        t.setDaemon(true);
        t.start();
    }

    private void runRebuildForCase(String caseId, List<Transcript> targets, RebuildJob job, boolean forceExtract) {
        TransactionTemplate tx = new TransactionTemplate(transactionManager);
        int savedTotal = 0;
        int skipped = 0;
        int extracted = 0;
        String lastError = null;

        try {
            synchronized (lockForCase(caseId)) {
                for (Transcript tr : targets) {
                    job.processed++;
                    job.currentLabel = nvl(tr.getStmtName(), "조서 #" + tr.getTranscriptId());
                    job.message = rebuildProgressMessage(job);
                    if (!forceExtract && shouldSkipExtract(tr)) {
                        skipped++;
                        job.skipped = skipped;
                        continue;
                    }
                    try {
                        int saved = tx.execute(status -> doExtractEventsForTranscript(tr));
                        savedTotal += saved;
                        extracted++;
                    } catch (Exception e) {
                        lastError = e.getMessage();
                        log.warn("timeline rebuild failed transcriptId={}: {}", tr.getTranscriptId(), e.getMessage(), e);
                    }
                    job.eventsSaved = savedTotal;
                    job.skipped = skipped;
                }
            }

            job.eventsSaved = savedTotal;
            job.skipped = skipped;
            if (lastError != null && extracted == 0 && skipped == 0) {
                job.status = "failed";
                job.message = lastError;
            } else if (extracted == 0 && skipped == targets.size()) {
                job.status = "completed";
                job.message = "조서 " + skipped + "건 본문 동일 — 기존 타임라인 이벤트를 유지했습니다.";
            } else if (savedTotal == 0 && extracted > 0) {
                job.status = "completed";
                job.message = rebuildDoneMessage(skipped, extracted, savedTotal);
            } else {
                job.status = "completed";
                job.message = rebuildDoneMessage(skipped, extracted, savedTotal);
            }
        } catch (Exception e) {
            job.status = "failed";
            job.message = "재추출 중 오류: " + e.getMessage();
            log.warn("timeline rebuild case {} failed: {}", caseId, e.getMessage(), e);
        }
    }

    private static String rebuildDoneMessage(int skipped, int extracted, int savedTotal) {
        StringBuilder sb = new StringBuilder();
        if (skipped > 0) {
            sb.append("조서 ").append(skipped).append("건 스킵(본문 동일·이벤트 유지)");
        }
        if (extracted > 0) {
            if (!sb.isEmpty()) sb.append(", ");
            sb.append("추출 ").append(extracted).append("건");
            if (savedTotal > 0) {
                sb.append(" · 이벤트 ").append(savedTotal).append("건 저장");
            } else {
                sb.append(" · 시간 정보 있는 이벤트 없음");
            }
        }
        return sb.isEmpty() ? "재추출을 완료했습니다." : sb.toString();
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
        m.put("skipped", job.skipped);
        m.put("currentLabel", job.currentLabel);
        out.put("rebuildJob", m);
    }

    private String resolveTranscriptBody(Transcript tr) {
        String raw = "";
        if (tr.getOriginalText() != null && !tr.getOriginalText().isBlank()) {
            raw = tr.getOriginalText().trim();
        }
        if (raw.isBlank() && tr.getOriginalHtml() != null && !tr.getOriginalHtml().isBlank()) {
            raw = tr.getOriginalHtml().replaceAll("<[^>]+>", " ").replaceAll("\\s+", " ").trim();
        }
        if (raw.isBlank()) {
            String ai = tr.getAiResult();
            if (ai != null && !ai.isBlank()) {
                String plain = ai.replaceAll("<[^>]+>", " ").replaceAll("\\s+", " ").trim();
                if (plain.length() >= 30) {
                    raw = plain;
                }
            }
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

    /** 조서 저장(신규) 직후 해당 조서만 백그라운드 추출 */
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
        if (resolveTranscriptBody(tr).isBlank()) return;

        synchronized (lockForCase(caseId)) {
            if (shouldSkipExtract(tr)) {
                log.debug("timeline extract skip unchanged transcriptId={}", transcriptId);
                return;
            }
            TransactionTemplate tx = new TransactionTemplate(transactionManager);
            tx.executeWithoutResult(status -> doExtractEventsForTranscript(tr));
        }
    }

    private boolean shouldSkipExtract(Transcript tr) {
        if (tr == null || tr.getTranscriptId() == null) return false;
        String stored = tr.getTimelineSourceHash();
        if (stored == null || stored.isBlank()) return false;
        return stored.equals(computeExtractSourceHash(tr));
    }

    private String computeExtractSourceHash(Transcript tr) {
        String body = resolveTranscriptBody(tr);
        String ref = Optional.ofNullable(resolveTranscriptReferenceDate(tr))
            .map(LocalDate::toString)
            .orElse("");
        String meta = nvl(tr.getStmtName(), "") + "|" + nvl(tr.getStmtType(), "")
            + "|" + tr.getPreambleYear() + "|" + tr.getPreambleMonth() + "|" + tr.getPreambleDay()
            + "|" + timelineMaxTextChars + "|extract-v5";
        return sha256Hex(body + "\n" + ref + "\n" + meta);
    }

    private void persistExtractSourceHash(Transcript tr) {
        if (tr == null || tr.getTranscriptId() == null) return;
        String hash = computeExtractSourceHash(tr);
        transcriptRepo.updateTimelineSourceHash(tr.getTranscriptId(), hash);
        tr.setTimelineSourceHash(hash);
    }

    private static String sha256Hex(String input) {
        try {
            MessageDigest md = MessageDigest.getInstance("SHA-256");
            byte[] digest = md.digest(input.getBytes(StandardCharsets.UTF_8));
            StringBuilder sb = new StringBuilder(digest.length * 2);
            for (byte b : digest) {
                sb.append(String.format("%02x", b));
            }
            return sb.toString();
        } catch (Exception e) {
            throw new IllegalStateException("SHA-256 unavailable", e);
        }
    }

    private int doExtractEventsForTranscript(Transcript tr) {
        Integer transcriptId = tr.getTranscriptId();
        String text = resolveTranscriptBody(tr);
        if (text.isEmpty()) {
            throw new IllegalStateException(
                "조서 #" + transcriptId + " 본문이 비어 있습니다. 원문(또는 HTML)을 저장한 뒤 재추출하세요.");
        }

        LocalDate referenceDate = resolveTranscriptReferenceDate(tr);

        JSONObject body = new JSONObject();
        body.put("caseId", nvl(tr.getCaseId(), ""));
        body.put("transcriptId", transcriptId);
        body.put("stmtName", nvl(tr.getStmtName(), "미입력"));
        body.put("stmtType", nvl(tr.getStmtType(), "진술자"));
        body.put("text", text);
        if (referenceDate != null) {
            body.put("referenceDate", referenceDate.toString());
        }
        if (tr.getPreambleYear() != null) {
            body.put("preambleYear", tr.getPreambleYear());
            body.put("preambleMonth", tr.getPreambleMonth());
            body.put("preambleDay", tr.getPreambleDay());
        }

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
            persistExtractSourceHash(tr);
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
            if (!jsonEventHasTimeSignal(ev, referenceDate)) continue;

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
        normalizeTimelineEventTimes(batch, false, referenceDate);
        int saved = 0;
        for (TimelineEvent row : batch) {
            if (row.getTimeStart() == null || !eventTimeGrounded(row, referenceDate)) {
                continue;
            }
            eventRepo.save(row);
            saved++;
        }
        persistExtractSourceHash(tr);
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
        if (label.isEmpty() || "이벤트".equals(label)) {
            String timeText = nvl(optString(ev, "time_text", "timeText"), "").trim();
            if (!timeText.isEmpty()) {
                label = timeText.length() > 80 ? timeText.substring(0, 79) + "…" : timeText;
            } else {
                String quote = nvl(ev.optString("quote", ""), "").trim();
                if (!quote.isEmpty()) {
                    label = quote.length() > 80 ? quote.substring(0, 79) + "…" : quote;
                }
            }
        }
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

    private boolean jsonEventHasTimeSignal(JSONObject ev, LocalDate referenceDate) {
        String quote = nvl(ev.optString("quote", ""), "").trim();
        String timeText = nvl(optString(ev, "time_text", "timeText"), "");
        if (quote.isBlank()) {
            return false;
        }
        String eventType = nvl(ev.optString("event_type", ev.optString("eventType", "")), "");
        if (isTimelessRelationshipJson(ev, quote)) {
            return false;
        }
        if (textHasTimelineClockSignal(quote)) {
            return true;
        }
        if (tryParseRelativeOffsetMinutes(quote) != null) {
            return true;
        }
        if (parseDateFromEventText(quote, referenceDate) != null) {
            return true;
        }
        String label = nvl(pickEventLabel(ev, ""), "").trim();
        if (!timeText.isBlank() && textHasTimelineClockSignal(timeText)
            && clockPhraseOverlapsQuote(timeText, quote, label)) {
            return true;
        }
        if (referenceDate != null && textHasTimelineClockSignal(quote, timeText)) {
            return true;
        }
        if ("observation".equalsIgnoreCase(eventType)) {
            return quote.contains("대신")
                && (quote.contains("봤") || quote.contains("보았") || quote.contains("목격")
                || quote.contains("보이지"));
        }
        return false;
    }

    private static boolean isTimelessRelationshipJson(JSONObject ev, String quote) {
        if (textHasTimelineClockSignal(quote) || tryParseRelativeOffsetMinutes(quote) != null) {
            return false;
        }
        if (!TIMELESS_RELATIONSHIP.matcher(quote).find()) {
            return false;
        }
        String[] timedActions = {"갔", "왔", "했다", "하였", "만났", "출발", "도착", "이동", "들어", "나갔", "머물", "체류", "방문"};
        for (String v : timedActions) {
            if (quote.contains(v)) {
                return false;
            }
        }
        return true;
    }
}
