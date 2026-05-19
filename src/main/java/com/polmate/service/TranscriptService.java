package com.polmate.service;

import com.polmate.entity.Notification;
import com.polmate.entity.Transcript;
import com.polmate.entity.TranscriptScore;
import com.polmate.repository.NotificationRepository;
import com.polmate.repository.TranscriptRepository;
import com.polmate.repository.TranscriptScoreRepository;
import lombok.RequiredArgsConstructor;
import org.json.JSONObject;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.io.*;
import java.net.HttpURLConnection;
import java.net.URL;
import java.nio.charset.StandardCharsets;
import java.time.LocalDateTime;
import java.util.*;

@Service
@RequiredArgsConstructor
public class TranscriptService {

    private final TranscriptRepository transcriptRepo;
    private final TranscriptScoreRepository scoreRepo;
    private final NotificationRepository notifRepo;
    private final TimelineService timelineService;
    private final JdbcTemplate jdbc;

    @Value("${polmate.serv.base-url}")
    private String servBaseUrl;

    // ── 조서 원문 + 요약 조회 ────────────────────────────────────
    public Optional<Map<String, Object>> getText(Integer transcriptId, String userId) {
        List<Map<String, Object>> rows = jdbc.queryForList(
            "SELECT t.transcript_id, t.original_text, t.stmt_type, t.stmt_name, t.ai_result " +
            "FROM transcripts t JOIN cases c ON t.case_id=c.case_id WHERE t.transcript_id=? " +
            "AND c.dept_id=(SELECT me.dept_id FROM users me WHERE me.user_id=?)",
            transcriptId, userId);
        return rows.isEmpty() ? Optional.empty() : Optional.of(rows.get(0));
    }

    // ── 조서 저장 ────────────────────────────────────────────────
    @Transactional
    public Map<String, Object> save(String userId, String caseId,
                                    String stmtType, String stmtName, String originalText) {
        Map<String, Object> result = new HashMap<>();
        int check = jdbc.queryForObject(
            "SELECT COUNT(*) FROM cases WHERE case_id=? AND dept_id=(SELECT me.dept_id FROM users me WHERE me.user_id=?)",
            Integer.class, caseId, userId);
        if (check == 0) { result.put("success", false); result.put("message", "접근 권한이 없습니다."); return result; }

        Transcript t = Transcript.builder()
            .caseId(caseId).userId(userId).originalText(originalText)
            .stmtType(stmtType.isEmpty() ? null : stmtType)
            .stmtName(stmtName.isEmpty() ? null : stmtName)
            .hasContradiction(0).build();
        Transcript saved = transcriptRepo.save(t);

        List<String> teammates = jdbc.queryForList(
            "SELECT u2.user_id FROM users u2 JOIN cases c ON c.case_id=? WHERE u2.dept_id=c.dept_id " +
            "AND c.dept_id IS NOT NULL AND u2.user_id!=? AND u2.notif_contradiction=1",
            String.class, caseId, userId);
        String who   = stmtName.isEmpty() ? "" : stmtName + " ";
        String tDesc = "사건 " + caseId + "에 " + who + (stmtType.isEmpty() ? "" : stmtType + " ") + "조서가 추가됐습니다.";
        for (String tm : teammates) {
            notifRepo.save(Notification.builder()
                .userId(tm).type("case").tag("조서").title("새 조서 등록: " + caseId)
                .description(tDesc).link("myCase.jsp?caseId=" + caseId)
                .isUnread(true).isCritical(false).createdAt(LocalDateTime.now()).build());
        }
        result.put("success", true); result.put("transcriptId", saved.getTranscriptId());
        result.put("message", "조서가 저장됐습니다.");
        timelineService.scheduleExtractForTranscript(saved.getTranscriptId());
        return result;
    }

    // ── 조서 AI 요약 ─────────────────────────────────────────────
    @Transactional
    public Map<String, Object> summarize(Integer transcriptId, String userId) {
        Map<String, Object> result = new HashMap<>();
        List<Map<String, Object>> rows = jdbc.queryForList(
            "SELECT t.case_id, t.original_text, t.stmt_type, t.stmt_name " +
            "FROM transcripts t JOIN cases c ON t.case_id=c.case_id WHERE t.transcript_id=? " +
            "AND c.dept_id=(SELECT me.dept_id FROM users me WHERE me.user_id=?)",
            transcriptId, userId);
        if (rows.isEmpty()) { result.put("success", false); result.put("message", "접근 권한이 없습니다."); return result; }

        Map<String, Object> row = rows.get(0);
        String originalText = (String) row.get("original_text");
        if (originalText == null || originalText.trim().isEmpty()) {
            result.put("success", false); result.put("message", "요약할 진술 본문이 없습니다."); return result;
        }

        JSONObject body = new JSONObject();
        body.put("caseNum",  nvl((String) row.get("case_id"),    "미입력"));
        body.put("text",     originalText);
        body.put("stmtType", nvl((String) row.get("stmt_type"),  "진술자"));
        body.put("stmtName", nvl((String) row.get("stmt_name"),  "미입력"));

        String structured = callFlask("/summarize", body);
        if (structured == null) { result.put("success", false); result.put("message", "요약 서버 호출에 실패했습니다."); return result; }

        int n = jdbc.update("UPDATE transcripts SET ai_result=? WHERE transcript_id=?", structured, transcriptId);
        result.put("success", n > 0);
        result.put("message", n > 0 ? "요약이 저장되었습니다." : "요약 저장에 실패했습니다.");
        return result;
    }

    // ── 신뢰도 점수 조회 ─────────────────────────────────────────
    public Optional<TranscriptScore> getScore(Integer transcriptId, String userId) {
        List<Map<String, Object>> check = jdbc.queryForList(
            "SELECT 1 FROM transcripts t JOIN cases c ON t.case_id=c.case_id WHERE t.transcript_id=? " +
            "AND (c.user_id=? OR c.dept_id=(SELECT me.dept_id FROM users me WHERE me.user_id=?))",
            transcriptId, userId, userId);
        if (check.isEmpty()) return Optional.empty();
        return scoreRepo.findByTranscriptId(transcriptId);
    }

    // ── 신뢰도 분석 실행 ─────────────────────────────────────────
    @Transactional
    public Map<String, Object> scoreTranscript(Integer transcriptId, String userId) {
        Map<String, Object> result = new HashMap<>();
        List<Map<String, Object>> rows = jdbc.queryForList(
            "SELECT t.original_text, t.stmt_name, t.stmt_type FROM transcripts t " +
            "JOIN cases c ON t.case_id=c.case_id WHERE t.transcript_id=? " +
            "AND c.dept_id=(SELECT me.dept_id FROM users me WHERE me.user_id=?)",
            transcriptId, userId);
        if (rows.isEmpty()) { result.put("success", false); result.put("message", "접근 권한이 없습니다."); return result; }

        Map<String, Object> row = rows.get(0);
        String originalText = (String) row.get("original_text");
        if (originalText == null || originalText.trim().isEmpty()) {
            result.put("success", false); result.put("message", "진술 본문이 없습니다."); return result;
        }

        JSONObject body = new JSONObject();
        body.put("stmt_name", nvl((String) row.get("stmt_name"), "미입력"));
        body.put("stmt_type", nvl((String) row.get("stmt_type"), "진술자"));
        body.put("text",      originalText);

        String resp = callFlask("/score/reliability", body);
        if (resp == null) { result.put("success", false); result.put("message", "분석 서버 호출에 실패했습니다."); return result; }

        try {
            JSONObject scores = new JSONObject(resp);
            TranscriptScore score = scoreRepo.findByTranscriptId(transcriptId)
                .orElse(TranscriptScore.builder().transcriptId(transcriptId).scoredAt(LocalDateTime.now()).build());
            score.setConsistencyScore(scores.getInt("consistency"));
            score.setSpecificityScore(scores.getInt("specificity"));
            score.setEmotionScore(scores.getInt("emotion"));
            score.setTemporalScore(scores.getInt("temporal"));
            score.setTotalScore(scores.getInt("total"));
            JSONObject reasons = scores.optJSONObject("reasons");
            if (reasons != null) {
                score.setConsistencyReason(reasons.optString("consistency", ""));
                score.setSpecificityReason(reasons.optString("specificity", ""));
                score.setEmotionReason(reasons.optString("emotion", ""));
                score.setTemporalReason(reasons.optString("temporal", ""));
            }
            score.setScoredAt(LocalDateTime.now());
            scoreRepo.save(score);
            result.put("success", true);
            result.put("total",       score.getTotalScore());
            result.put("consistency", score.getConsistencyScore());
            result.put("specificity", score.getSpecificityScore());
            result.put("emotion",     score.getEmotionScore());
            result.put("temporal",    score.getTemporalScore());
            result.put("cReason",     score.getConsistencyReason());
            result.put("sReason",     score.getSpecificityReason());
            result.put("eReason",     score.getEmotionReason());
            result.put("tReason",     score.getTemporalReason());
        } catch (Exception e) {
            e.printStackTrace();
            result.put("success", false); result.put("message", "점수 파싱에 실패했습니다.");
        }
        return result;
    }

    private String callFlask(String path, JSONObject body) {
        try {
            URL url = new URL(servBaseUrl + path);
            HttpURLConnection conn = (HttpURLConnection) url.openConnection();
            conn.setRequestMethod("POST");
            conn.setRequestProperty("Content-Type", "application/json;charset=UTF-8");
            conn.setDoOutput(true);
            conn.setConnectTimeout(5000); conn.setReadTimeout(120000);
            try (OutputStream os = conn.getOutputStream()) {
                os.write(body.toString().getBytes(StandardCharsets.UTF_8));
            }
            if (conn.getResponseCode() != 200) return null;
            try (BufferedReader br = new BufferedReader(
                    new InputStreamReader(conn.getInputStream(), StandardCharsets.UTF_8))) {
                StringBuilder sb = new StringBuilder();
                String line;
                while ((line = br.readLine()) != null) sb.append(line);
                return sb.toString();
            }
        } catch (Exception e) { e.printStackTrace(); return null; }
    }

    private String nvl(String s, String def) {
        return (s == null || s.trim().isEmpty()) ? def : s.trim();
    }
}
