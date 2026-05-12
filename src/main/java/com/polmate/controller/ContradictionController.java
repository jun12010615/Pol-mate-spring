package com.polmate.controller;

import com.polmate.service.ContradictionService;
import lombok.RequiredArgsConstructor;
import org.json.JSONArray;
import org.json.JSONObject;
import org.springframework.web.bind.annotation.*;

import jakarta.servlet.http.HttpServletResponse;
import jakarta.servlet.http.HttpSession;
import java.io.IOException;
import java.sql.Timestamp;
import java.time.LocalDateTime;
import java.util.Map;
import java.util.Optional;

@RestController
@RequestMapping("/contradictionApi")
@RequiredArgsConstructor
public class ContradictionController {

    private final ContradictionService contradictionService;

    @GetMapping
    public void doGet(@RequestParam(defaultValue = "list") String action,
                      @RequestParam(required = false) String resultId,
                      HttpServletResponse res, HttpSession session) throws IOException {
        res.setContentType("application/json; charset=UTF-8");
        String userId = getLoginUser(session, res);
        if (userId == null) return;
        switch (action) {
            case "list":   handleList(res, userId);               break;
            case "detail": handleDetail(res, userId, resultId);   break;
            default: res.getWriter().write("{\"error\":\"알 수 없는 action\"}");
        }
    }

    @PostMapping
    public void doPost(@RequestParam(defaultValue = "") String action,
                       @RequestParam(required = false, defaultValue = "") String caseId,
                       @RequestParam(required = false, defaultValue = "") String stmtName,
                       @RequestParam(required = false, defaultValue = "") String stmtType,
                       @RequestParam(required = false, defaultValue = "false") String hasContradiction,
                       @RequestParam(required = false, defaultValue = "") String aiResult,
                       @RequestParam(required = false, defaultValue = "") String stmtText,
                       @RequestParam(required = false) String resultId,
                       HttpServletResponse res, HttpSession session) throws IOException {
        res.setContentType("application/json; charset=UTF-8");
        String userId = getLoginUser(session, res);
        if (userId == null) return;
        switch (action) {
            case "save":
                handleSave(res, userId, caseId, stmtName, stmtType,
                    "true".equals(hasContradiction), aiResult, stmtText);
                break;
            case "delete":
                handleDelete(res, userId, resultId);
                break;
            default: res.getWriter().write("{\"error\":\"알 수 없는 action\"}");
        }
    }

    private void handleList(HttpServletResponse res, String userId) throws IOException {
        try {
            JSONArray arr = new JSONArray();
            for (Map<String, Object> row : contradictionService.list(userId)) {
                JSONObject obj = new JSONObject();
                obj.put("resultId",        ((Number) row.get("result_id")).intValue());
                obj.put("caseId",          nvl((String) row.get("case_id")));
                obj.put("caseName",        nvl((String) row.get("case_name")));
                obj.put("stmtName",        nvl((String) row.get("stmt_name")));
                obj.put("stmtType",        nvl((String) row.get("stmt_type")));
                obj.put("hasContradiction", Boolean.TRUE.equals(row.get("has_contradiction")));
                obj.put("aiResult",        nvl((String) row.get("ai_result")));
                obj.put("stmtText",        nvl((String) row.get("stmt_text")));
                Object ts = row.get("created_at");
                obj.put("createdAt", ts instanceof Timestamp
                    ? ts.toString().substring(0, 10).replace("-", ".") : "");
                arr.put(obj);
            }
            res.getWriter().write(arr.toString());
        } catch (Exception e) {
            e.printStackTrace(); res.getWriter().write("{\"error\":\"목록 조회 중 오류\"}");
        }
    }

    private void handleDetail(HttpServletResponse res, String userId, String resultIdStr) throws IOException {
        try {
            if (resultIdStr == null) { res.getWriter().write("{\"error\":\"resultId 필요\"}"); return; }
            Optional<Map<String, Object>> opt = contradictionService.detail(userId, Integer.parseInt(resultIdStr));
            if (opt.isEmpty()) { res.getWriter().write("{\"error\":\"결과를 찾을 수 없습니다.\"}"); return; }
            Map<String, Object> row = opt.get();
            JSONObject obj = new JSONObject();
            obj.put("resultId",        ((Number) row.get("result_id")).intValue());
            obj.put("caseId",          nvl((String) row.get("case_id")));
            obj.put("caseName",        nvl((String) row.get("case_name")));
            obj.put("stmtName",        nvl((String) row.get("stmt_name")));
            obj.put("stmtType",        nvl((String) row.get("stmt_type")));
            obj.put("hasContradiction", Boolean.TRUE.equals(row.get("has_contradiction")));
            obj.put("aiResult",        nvl((String) row.get("ai_result")));
            obj.put("stmtText",        nvl((String) row.get("stmt_text")));
            res.getWriter().write(obj.toString());
        } catch (Exception e) {
            e.printStackTrace(); res.getWriter().write("{\"error\":\"상세 조회 중 오류\"}");
        }
    }

    private void handleSave(HttpServletResponse res, String userId, String caseId, String stmtName,
                            String stmtType, boolean hasContradiction, String aiResult, String stmtText) throws IOException {
        try {
            int id = contradictionService.save(userId, caseId, stmtName, stmtType, hasContradiction, aiResult, stmtText);
            res.getWriter().write("{\"success\":true,\"resultId\":" + id + "}");
        } catch (Exception e) {
            e.printStackTrace(); res.getWriter().write("{\"success\":false,\"error\":\"저장 중 오류\"}");
        }
    }

    private void handleDelete(HttpServletResponse res, String userId, String resultIdStr) throws IOException {
        try {
            if (resultIdStr == null) { res.getWriter().write("{\"success\":false}"); return; }
            boolean ok = contradictionService.delete(userId, Integer.parseInt(resultIdStr));
            res.getWriter().write("{\"success\":" + ok + "}");
        } catch (Exception e) {
            e.printStackTrace(); res.getWriter().write("{\"success\":false,\"error\":\"삭제 중 오류\"}");
        }
    }

    private String nvl(String s) { return s == null ? "" : s; }

    private String getLoginUser(HttpSession session, HttpServletResponse res) throws IOException {
        String u = session != null ? (String) session.getAttribute("loginUser") : null;
        if (u == null) res.getWriter().write("{\"error\":\"로그인이 필요합니다.\"}");
        return u;
    }
}
