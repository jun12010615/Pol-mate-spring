package com.polmate.controller;

import com.polmate.entity.TranscriptScore;
import com.polmate.service.CaseService;
import com.polmate.service.TranscriptService;
import lombok.RequiredArgsConstructor;
import org.json.JSONArray;
import org.json.JSONObject;
import org.springframework.web.bind.annotation.*;

import jakarta.servlet.http.HttpServletResponse;
import jakarta.servlet.http.HttpSession;
import java.io.IOException;
import java.sql.Timestamp;
import java.text.SimpleDateFormat;
import java.util.*;

@RestController
@RequestMapping("/caseApi")
@RequiredArgsConstructor
public class CaseController {

    private static final SimpleDateFormat DATE_FMT = new SimpleDateFormat("yyyy.MM.dd");
    static { DATE_FMT.setTimeZone(TimeZone.getTimeZone("Asia/Seoul")); }

    private final CaseService caseService;
    private final TranscriptService transcriptService;

    @GetMapping
    public void doGet(@RequestParam(defaultValue = "caseList") String action,
                      @RequestParam(required = false) String caseId,
                      @RequestParam(required = false) String status,
                      @RequestParam(required = false) String keyword,
                      @RequestParam(required = false) String transcriptId,
                      @RequestParam(defaultValue = "false") boolean forceRefresh,
                      HttpServletResponse res, HttpSession session) throws IOException {
        res.setContentType("application/json;charset=UTF-8");
        String loginUser = getLoginUser(session, res);
        if (loginUser == null) return;

        switch (action) {
            case "caseList":       handleCaseList(res, loginUser, nvl(status,"all"), nvl(keyword,"")); break;
            case "caseDetail":     handleCaseDetail(res, loginUser, caseId);     break;
            case "docList":        handleDocList(res, loginUser, nvl(keyword,"")); break;
            case "docStats":       handleDocStats(res, loginUser);               break;
            case "myDept":         handleMyDept(res, loginUser);                 break;
            case "transcriptText": handleTranscriptText(res, loginUser, transcriptId); break;
            case "getScore":       handleGetScore(res, loginUser, transcriptId);       break;
            case "similarCases":   handleSimilarCases(res, loginUser, caseId, forceRefresh); break;
            default: res.getWriter().write("{\"error\":\"알 수 없는 action\"}");
        }
    }

    @PostMapping
    public void doPost(@RequestParam(defaultValue = "") String action,
                       @RequestParam(required = false) String caseId,
                       @RequestParam(required = false) String caseName,
                       @RequestParam(required = false) String suspect,
                       @RequestParam(required = false) String charge,
                       @RequestParam(required = false) String status,
                       @RequestParam(required = false) String transcriptId,
                       @RequestParam(required = false) String stmtType,
                       @RequestParam(required = false) String stmtName,
                       @RequestParam(required = false) String originalText,
                       HttpServletResponse res, HttpSession session) throws IOException {
        res.setContentType("application/json;charset=UTF-8");
        String loginUser = getLoginUser(session, res);
        if (loginUser == null) return;

        switch (action) {
            case "caseCreate":
                writeMap(res, caseService.createCase(loginUser, caseId, nvl(caseName,""), nvl(suspect,""), nvl(charge,"")));
                break;
            case "caseDelete":
                writeMap(res, caseService.deleteCase(loginUser, caseId));
                break;
            case "caseStatus":
                writeMap(res, caseService.updateStatus(loginUser, caseId, status));
                break;
            case "transcriptSave":
                writeMap(res, transcriptService.save(loginUser, caseId, nvl(stmtType,""), nvl(stmtName,""), nvl(originalText,"")));
                break;
            case "transcriptSummarize":
                handleTranscriptSummarize(res, loginUser, transcriptId);
                break;
            case "scoreTranscript":
                handleScoreTranscript(res, loginUser, transcriptId);
                break;
            default: res.getWriter().write("{\"error\":\"알 수 없는 action\"}");
        }
    }

    private void handleCaseList(HttpServletResponse res, String loginUser, String status, String keyword) throws IOException {
        try {
            JSONArray arr = new JSONArray();
            for (Map<String, Object> row : caseService.list(loginUser, status, keyword)) {
                JSONObject c = new JSONObject();
                c.put("id",             nvl((String) row.get("case_id")));
                c.put("name",           nvl((String) row.get("case_name")));
                c.put("suspect",        nvl((String) row.get("suspect"), "미입력"));
                c.put("charge",         nvl((String) row.get("charge"),  "미입력"));
                c.put("detective",      nvl((String) row.get("user_name"), "미입력"));
                c.put("rank",           nvl((String) row.get("user_rank"), ""));
                c.put("status",         nvl((String) row.get("status")));
                int docs  = num(row.get("doc_count"));
                int contr = num(row.get("contradiction_count"));
                c.put("docs",           docs);
                c.put("contradictions", contr);
                c.put("urgent",         contr > 0);
                c.put("isMine",         loginUser.equals(row.get("user_id")));
                Object ts = row.get("created_at");
                c.put("date", ts instanceof Timestamp ? DATE_FMT.format((Timestamp) ts) : "");
                arr.put(c);
            }
            res.getWriter().write(arr.toString());
        } catch (Exception e) {
            e.printStackTrace(); res.getWriter().write("{\"error\":\"사건 목록 조회 중 오류가 발생했습니다.\"}");
        }
    }

    private void handleCaseDetail(HttpServletResponse res, String loginUser, String caseId) throws IOException {
        if (isEmpty(caseId)) { res.getWriter().write("{\"error\":\"caseId가 필요합니다.\"}"); return; }
        try {
            Optional<Map<String, Object>> optCase = caseService.detail(caseId, loginUser);
            if (optCase.isEmpty()) { res.getWriter().write("{\"error\":\"사건을 찾을 수 없거나 접근 권한이 없습니다.\"}"); return; }
            Map<String, Object> row = optCase.get();
            JSONObject detail = new JSONObject();
            detail.put("id",        nvl((String) row.get("case_id")));
            detail.put("name",      nvl((String) row.get("case_name")));
            detail.put("suspect",   nvl((String) row.get("suspect"), "미입력"));
            detail.put("charge",    nvl((String) row.get("charge"),  "미입력"));
            detail.put("status",    nvl((String) row.get("status")));
            detail.put("isMine",    loginUser.equals(row.get("user_id")));
            detail.put("detective", nvl((String) row.get("user_name"), "미입력"));
            detail.put("rank",      nvl((String) row.get("user_rank"), ""));
            String dn = (String) row.get("dept_name"), on = (String) row.get("org_name");
            detail.put("deptName",  dn != null && !dn.isEmpty()
                ? (on != null && !on.isEmpty() ? dn + " (" + on + ")" : dn) : "미배정");
            Object ts = row.get("created_at");
            detail.put("date", ts instanceof Timestamp ? DATE_FMT.format((Timestamp) ts) : "");

            JSONArray docs = new JSONArray();
            for (Map<String, Object> d : caseService.transcriptList(caseId)) {
                JSONObject obj = new JSONObject();
                obj.put("id",           num(d.get("transcript_id")));
                obj.put("type",         nvl((String) d.get("stmt_type"), "미분류"));
                obj.put("name",         nvl((String) d.get("stmt_name"), "미입력"));
                obj.put("contradiction", Boolean.TRUE.equals(d.get("has_contradiction"))
                    || Integer.valueOf(1).equals(d.get("has_contradiction")));
                obj.put("textLen",      num(d.get("text_len")));
                obj.put("writerId",     nvl((String) d.get("user_id"),   ""));
                obj.put("writerName",   nvl((String) d.get("user_name"), "알 수 없음"));
                obj.put("writerRank",   nvl((String) d.get("user_rank"), ""));
                Object dts = d.get("created_at");
                obj.put("date", dts instanceof Timestamp ? DATE_FMT.format((Timestamp) dts) : "");
                Object totalObj = d.get("total_score");
                boolean scored = totalObj != null;
                obj.put("scored", scored);
                if (scored) {
                    obj.put("totalScore",  num(totalObj));
                    obj.put("consistency", num(d.get("consistency_score")));
                    obj.put("specificity", num(d.get("specificity_score")));
                    obj.put("emotion",     num(d.get("emotion_score")));
                    obj.put("temporal",    num(d.get("temporal_score")));
                    obj.put("cReason",     nvl((String) d.get("consistency_reason"), ""));
                    obj.put("sReason",     nvl((String) d.get("specificity_reason"), ""));
                    obj.put("eReason",     nvl((String) d.get("emotion_reason"),     ""));
                    obj.put("tReason",     nvl((String) d.get("temporal_reason"),    ""));
                }
                docs.put(obj);
            }
            detail.put("docs", docs); detail.put("docCount", docs.length());
            res.getWriter().write(detail.toString());
        } catch (Exception e) {
            e.printStackTrace(); res.getWriter().write("{\"error\":\"사건 상세 조회 중 오류가 발생했습니다.\"}");
        }
    }

    private void handleDocList(HttpServletResponse res, String loginUser, String keyword) throws IOException {
        try {
            JSONArray arr = new JSONArray();
            for (Map<String, Object> d : caseService.docList(loginUser, keyword)) {
                JSONObject obj = new JSONObject();
                obj.put("id",           num(d.get("transcript_id")));
                obj.put("caseId",       nvl((String) d.get("case_id")));
                obj.put("caseName",     nvl((String) d.get("case_name")));
                String st = nvl((String) d.get("stmt_type"), "미분류");
                String sn = nvl((String) d.get("stmt_name"), "미입력");
                obj.put("title",        sn + " " + st + " 진술 조서");
                obj.put("type",         st);
                boolean hasCont = Boolean.TRUE.equals(d.get("has_contradiction"))
                    || Integer.valueOf(1).equals(d.get("has_contradiction"));
                obj.put("status",       hasCont ? "모순탐지" : "완료");
                obj.put("words",        num(d.get("text_len")));
                obj.put("contradiction", hasCont);
                Object ts = d.get("created_at");
                obj.put("date", ts instanceof Timestamp ? DATE_FMT.format((Timestamp) ts) : "");
                arr.put(obj);
            }
            res.getWriter().write(arr.toString());
        } catch (Exception e) {
            e.printStackTrace(); res.getWriter().write("{\"error\":\"조서 목록 조회 중 오류가 발생했습니다.\"}");
        }
    }

    private void handleDocStats(HttpServletResponse res, String loginUser) throws IOException {
        try {
            Map<String, Object> stats = caseService.docStats(loginUser);
            JSONObject obj = new JSONObject();
            obj.put("total",       num(stats.get("total")));
            obj.put("contradiction", num(stats.get("contradiction")));
            res.getWriter().write(obj.toString());
        } catch (Exception e) {
            e.printStackTrace(); res.getWriter().write("{\"error\":\"통계 조회 중 오류가 발생했습니다.\"}");
        }
    }

    private void handleMyDept(HttpServletResponse res, String loginUser) throws IOException {
        try {
            Map<String, Object> dept = caseService.myDept(loginUser);
            JSONObject result = new JSONObject();
            if (!dept.isEmpty() && dept.get("dept_name") != null) {
                result.put("deptId",   num(dept.get("dept_id")));
                result.put("deptName", nvl((String) dept.get("dept_name")));
                result.put("org",      nvl((String) dept.get("org_name")));
                result.put("label",    dept.get("dept_name") + " (" + nvl((String) dept.get("org_name"), "") + ")");
            } else {
                result.put("deptId", JSONObject.NULL);
                result.put("deptName", "미배정"); result.put("org", ""); result.put("label", "부서 미배정");
            }
            res.getWriter().write(result.toString());
        } catch (Exception e) {
            e.printStackTrace(); res.getWriter().write("{\"error\":\"부서 정보 조회 중 오류가 발생했습니다.\"}");
        }
    }

    private void handleTranscriptText(HttpServletResponse res, String loginUser, String idStr) throws IOException {
        if (isEmpty(idStr)) { res.getWriter().write("{\"error\":\"transcriptId가 필요합니다.\"}"); return; }
        try {
            int tid = Integer.parseInt(idStr);
            Optional<Map<String, Object>> opt = transcriptService.getText(tid, loginUser);
            if (opt.isEmpty()) { res.getWriter().write("{\"error\":\"조서를 찾을 수 없거나 접근 권한이 없습니다.\"}"); return; }
            Map<String, Object> row = opt.get();
            JSONObject result = new JSONObject();
            result.put("id",      num(row.get("transcript_id")));
            result.put("text",    nvl((String) row.get("original_text"), ""));
            result.put("type",    nvl((String) row.get("stmt_type"),     ""));
            result.put("name",    nvl((String) row.get("stmt_name"),     ""));
            String ar = (String) row.get("ai_result");
            result.put("summary", ar != null && !ar.isEmpty() ? ar : "");
            res.getWriter().write(result.toString());
        } catch (NumberFormatException e) {
            res.getWriter().write("{\"error\":\"잘못된 transcriptId\"}");
        } catch (Exception e) {
            e.printStackTrace(); res.getWriter().write("{\"error\":\"조서 원문 조회 중 오류가 발생했습니다.\"}");
        }
    }

    private void handleTranscriptSummarize(HttpServletResponse res, String loginUser, String idStr) throws IOException {
        if (isEmpty(idStr)) { res.getWriter().write("{\"error\":\"transcriptId가 필요합니다.\"}"); return; }
        try {
            Map<String, Object> result = transcriptService.summarize(Integer.parseInt(idStr), loginUser);
            writeMap(res, result);
        } catch (Exception e) {
            e.printStackTrace(); res.getWriter().write("{\"error\":\"요약 처리 중 오류가 발생했습니다.\"}");
        }
    }

    private void handleGetScore(HttpServletResponse res, String loginUser, String idStr) throws IOException {
        if (isEmpty(idStr)) { res.getWriter().write("{\"error\":\"transcriptId가 필요합니다.\"}"); return; }
        try {
            int tid = Integer.parseInt(idStr);
            Optional<TranscriptScore> opt = transcriptService.getScore(tid, loginUser);
            if (opt.isEmpty()) { res.getWriter().write("{\"scored\":false}"); return; }
            TranscriptScore ts = opt.get();
            JSONObject r = new JSONObject();
            r.put("scored",      true);
            r.put("total",       ts.getTotalScore());
            r.put("consistency", ts.getConsistencyScore());
            r.put("specificity", ts.getSpecificityScore());
            r.put("emotion",     ts.getEmotionScore());
            r.put("temporal",    ts.getTemporalScore());
            JSONObject reasons = new JSONObject();
            reasons.put("consistency", nvl(ts.getConsistencyReason(), ""));
            reasons.put("specificity", nvl(ts.getSpecificityReason(), ""));
            reasons.put("emotion",     nvl(ts.getEmotionReason(),     ""));
            reasons.put("temporal",    nvl(ts.getTemporalReason(),    ""));
            r.put("reasons", reasons);
            res.getWriter().write(r.toString());
        } catch (Exception e) {
            e.printStackTrace(); res.getWriter().write("{\"error\":\"점수 조회 중 오류가 발생했습니다.\"}");
        }
    }

    private void handleScoreTranscript(HttpServletResponse res, String loginUser, String idStr) throws IOException {
        if (isEmpty(idStr)) { res.getWriter().write("{\"error\":\"transcriptId가 필요합니다.\"}"); return; }
        try {
            Map<String, Object> result = transcriptService.scoreTranscript(Integer.parseInt(idStr), loginUser);
            writeMap(res, result);
        } catch (Exception e) {
            e.printStackTrace(); res.getWriter().write("{\"error\":\"신뢰도 분석 중 오류가 발생했습니다.\"}");
        }
    }

    private void handleSimilarCases(HttpServletResponse res, String loginUser,
                                    String caseId, boolean forceRefresh) throws IOException {
        if (isEmpty(caseId)) { res.getWriter().write("{\"error\":\"caseId가 필요합니다.\"}"); return; }
        writeMap(res, caseService.similarCases(caseId, loginUser, forceRefresh));
    }

    private void writeMap(HttpServletResponse res, Map<String, Object> map) throws IOException {
        res.getWriter().write(new JSONObject(map).toString());
    }

    private String nvl(String s, String def) { return (s == null || s.isEmpty()) ? def : s; }
    private String nvl(String s)             { return nvl(s, ""); }
    private boolean isEmpty(String s)        { return s == null || s.trim().isEmpty(); }
    private int num(Object o)               { return o == null ? 0 : ((Number) o).intValue(); }

    private String getLoginUser(HttpSession session, HttpServletResponse res) throws IOException {
        String u = session != null ? (String) session.getAttribute("loginUser") : null;
        if (u == null) res.getWriter().write("{\"error\":\"로그인이 필요합니다.\"}");
        return u;
    }
}
