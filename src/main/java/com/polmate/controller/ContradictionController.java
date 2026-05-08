package com.polmate.controller;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.*;

import javax.sql.DataSource;
import jakarta.servlet.http.HttpServletResponse;
import jakarta.servlet.http.HttpSession;
import java.io.IOException;
import java.sql.*;

@RestController
@RequestMapping("/contradictionApi")
public class ContradictionController {

    private static final int MAX_CHARS = 65000;

    @Autowired
    private DataSource dataSource;

    @GetMapping
    public void doGet(@RequestParam(defaultValue = "list") String action,
                      @RequestParam(required = false) String resultId,
                      HttpServletResponse res, HttpSession session) throws IOException {
        res.setContentType("application/json; charset=UTF-8");
        String userId = getLoginUser(session, res);
        if (userId == null) return;
        switch (action) {
            case "list":   handleList(res, userId);             break;
            case "detail": handleDetail(res, userId, resultId); break;
            default: res.getWriter().write("{\"error\":\"알 수 없는 action\"}");
        }
    }

    @PostMapping
    public void doPost(@RequestParam(defaultValue = "") String action,
                       @RequestParam(required = false) String caseId,
                       @RequestParam(required = false) String stmtName,
                       @RequestParam(required = false) String stmtType,
                       @RequestParam(required = false) String hasContradiction,
                       @RequestParam(required = false) String aiResult,
                       @RequestParam(required = false) String stmtText,
                       @RequestParam(required = false) String resultId,
                       HttpServletResponse res, HttpSession session) throws IOException {
        res.setContentType("application/json; charset=UTF-8");
        String userId = getLoginUser(session, res);
        if (userId == null) return;
        switch (action) {
            case "save":   handleSave(res, userId, caseId, stmtName, stmtType, hasContradiction, aiResult, stmtText); break;
            case "delete": handleDelete(res, userId, resultId); break;
            default: res.getWriter().write("{\"error\":\"알 수 없는 action\"}");
        }
    }

    private void handleList(HttpServletResponse res, String userId) throws IOException {
        Connection conn = null; PreparedStatement ps = null; ResultSet rs = null;
        try {
            conn = dataSource.getConnection();
            ps = conn.prepareStatement(
                "SELECT cr.result_id, cr.case_id, cr.stmt_name, cr.stmt_type, " +
                "       cr.has_contradiction, cr.ai_result, cr.stmt_text, " +
                "       cr.created_at, c.case_name " +
                "FROM contradiction_results cr " +
                "LEFT JOIN cases c ON cr.case_id = c.case_id " +
                "WHERE cr.user_id = ? ORDER BY cr.created_at DESC");
            ps.setString(1, userId); rs = ps.executeQuery();
            org.json.JSONArray arr = new org.json.JSONArray();
            while (rs.next()) {
                org.json.JSONObject obj = new org.json.JSONObject();
                obj.put("resultId",        rs.getInt("result_id"));
                obj.put("caseId",          nvl(rs.getString("case_id")));
                obj.put("caseName",        nvl(rs.getString("case_name")));
                obj.put("stmtName",        nvl(rs.getString("stmt_name")));
                obj.put("stmtType",        nvl(rs.getString("stmt_type")));
                obj.put("hasContradiction", rs.getBoolean("has_contradiction"));
                obj.put("aiResult",        nvl(rs.getString("ai_result")));
                obj.put("stmtText",        nvl(rs.getString("stmt_text")));
                Timestamp ts = rs.getTimestamp("created_at");
                obj.put("createdAt", ts != null ? ts.toString().substring(0,10).replace("-",".") : "");
                arr.put(obj);
            }
            res.getWriter().write(arr.toString());
        } catch (Exception e) {
            e.printStackTrace();
            res.getWriter().write("{\"error\":\"목록 조회 중 오류가 발생했습니다.\"}");
        } finally { closeAll(conn, ps, rs); }
    }

    private void handleDetail(HttpServletResponse res, String userId, String resultIdStr) throws IOException {
        if (resultIdStr == null) { res.getWriter().write("{\"error\":\"resultId가 필요합니다.\"}"); return; }
        Connection conn = null; PreparedStatement ps = null; ResultSet rs = null;
        try {
            conn = dataSource.getConnection();
            ps = conn.prepareStatement(
                "SELECT cr.result_id, cr.case_id, cr.stmt_name, cr.stmt_type, " +
                "       cr.has_contradiction, cr.ai_result, cr.stmt_text, " +
                "       cr.created_at, c.case_name " +
                "FROM contradiction_results cr " +
                "LEFT JOIN cases c ON cr.case_id = c.case_id " +
                "WHERE cr.result_id = ? AND cr.user_id = ?");
            ps.setInt(1, Integer.parseInt(resultIdStr)); ps.setString(2, userId); rs = ps.executeQuery();
            if (rs.next()) {
                org.json.JSONObject obj = new org.json.JSONObject();
                obj.put("resultId",        rs.getInt("result_id"));
                obj.put("caseId",          nvl(rs.getString("case_id")));
                obj.put("caseName",        nvl(rs.getString("case_name")));
                obj.put("stmtName",        nvl(rs.getString("stmt_name")));
                obj.put("stmtType",        nvl(rs.getString("stmt_type")));
                obj.put("hasContradiction", rs.getBoolean("has_contradiction"));
                obj.put("aiResult",        nvl(rs.getString("ai_result")));
                obj.put("stmtText",        nvl(rs.getString("stmt_text")));
                Timestamp ts = rs.getTimestamp("created_at");
                obj.put("createdAt", ts != null ? ts.toString().substring(0,16).replace("-",".").replace("T"," ") : "");
                res.getWriter().write(obj.toString());
            } else {
                res.getWriter().write("{\"error\":\"결과를 찾을 수 없습니다.\"}");
            }
        } catch (Exception e) {
            e.printStackTrace();
            res.getWriter().write("{\"error\":\"상세 조회 중 오류가 발생했습니다.\"}");
        } finally { closeAll(conn, ps, rs); }
    }

    private void handleSave(HttpServletResponse res, String userId, String caseId,
                            String stmtName, String stmtType, String hasContraStr,
                            String aiResult, String stmtText) throws IOException {
        boolean hasContradiction = "true".equalsIgnoreCase(hasContraStr) || "1".equals(hasContraStr);
        String aiStored   = clip(aiResult, MAX_CHARS);
        String stmtStored = clip(stmtText, MAX_CHARS);
        Connection conn = null; PreparedStatement ps = null;
        try {
            conn = dataSource.getConnection();
            ps = conn.prepareStatement(
                "INSERT INTO contradiction_results (user_id, case_id, stmt_name, stmt_type, has_contradiction, ai_result, stmt_text) VALUES (?,?,?,?,?,?,?)",
                Statement.RETURN_GENERATED_KEYS);
            ps.setString(1, userId);
            ps.setString(2, (caseId != null && !caseId.trim().isEmpty()) ? caseId.trim() : null);
            ps.setString(3, stmtName != null ? stmtName.trim() : "");
            ps.setString(4, stmtType != null ? stmtType.trim() : "");
            ps.setBoolean(5, hasContradiction);
            ps.setString(6, aiStored);
            ps.setString(7, stmtStored);
            ps.executeUpdate();
            ResultSet gk = ps.getGeneratedKeys();
            int newId = gk.next() ? gk.getInt(1) : 0;
            res.getWriter().write("{\"success\":true,\"resultId\":" + newId + "}");
        } catch (SQLException e) {
            e.printStackTrace();
            res.getWriter().write("{\"success\":false,\"error\":\"" + sqlErrorMsg(e) + "\"}");
        } catch (Exception e) {
            e.printStackTrace();
            res.getWriter().write("{\"success\":false,\"error\":\"저장 중 오류가 발생했습니다.\"}");
        } finally { closeAll(conn, ps, null); }
    }

    private void handleDelete(HttpServletResponse res, String userId, String resultIdStr) throws IOException {
        if (resultIdStr == null) { res.getWriter().write("{\"success\":false,\"error\":\"resultId가 필요합니다.\"}"); return; }
        try (Connection conn = dataSource.getConnection();
             PreparedStatement ps = conn.prepareStatement("DELETE FROM contradiction_results WHERE result_id = ? AND user_id = ?")) {
            ps.setInt(1, Integer.parseInt(resultIdStr)); ps.setString(2, userId);
            res.getWriter().write("{\"success\":" + (ps.executeUpdate() > 0) + "}");
        } catch (Exception e) {
            e.printStackTrace();
            res.getWriter().write("{\"success\":false,\"error\":\"삭제 중 오류가 발생했습니다.\"}");
        }
    }

    private String sqlErrorMsg(SQLException e) {
        int code = e.getErrorCode(); String m = e.getMessage();
        if (code == 1452 || (m != null && m.toLowerCase().contains("foreign key")))
            return "등록되지 않은 사건입니다.";
        if (code == 1146) return "contradiction_results 테이블이 없습니다.";
        if (code == 1406 || (m != null && m.contains("too long")))
            return "저장할 분석 결과가 너무 깁니다.";
        return "저장 중 오류가 발생했습니다.";
    }

    private String clip(String s, int max) {
        if (s == null) return "";
        if (s.length() <= max) return s;
        return s.substring(0, max) + "\n…(이하 생략)";
    }

    private String getLoginUser(HttpSession session, HttpServletResponse res) throws IOException {
        String u = (session != null) ? (String) session.getAttribute("loginUser") : null;
        if (u == null) res.getWriter().write("{\"error\":\"로그인이 필요합니다.\"}");
        return u;
    }

    private String nvl(String s) { return s == null ? "" : s; }
    private void closeAll(Connection c, PreparedStatement p, ResultSet r) {
        try { if (r != null) r.close(); } catch (Exception ignored) {}
        try { if (p != null) p.close(); } catch (Exception ignored) {}
        try { if (c != null) c.close(); } catch (Exception ignored) {}
    }
}
