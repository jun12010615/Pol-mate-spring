package com.polmate.controller;

import com.polmate.util.NotificationUtil;
import org.json.JSONArray;
import org.json.JSONObject;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.*;

import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import jakarta.servlet.http.HttpSession;
import javax.sql.DataSource;
import java.io.*;
import java.sql.*;
import java.util.*;

@RestController
@RequestMapping("/boardApi")
public class RelationBoardController {

    @Autowired
    private DataSource dataSource;

    @GetMapping
    public void doGet(@RequestParam(defaultValue = "load") String action,
                      @RequestParam(required = false) String caseId,
                      HttpServletResponse res, HttpSession session) throws IOException {
        res.setContentType("application/json;charset=UTF-8");
        String loginUser = getLoginUser(session, res);
        if (loginUser == null) return;

        switch (action) {
            case "load":       handleLoad(res, loginUser, caseId);       break;
            case "listBoards": handleListBoards(res, loginUser);         break;
            default: res.getWriter().write("{\"error\":\"알 수 없는 action\"}");
        }
    }

    @PostMapping
    public void doPost(@RequestParam(defaultValue = "") String action,
                       @RequestParam(required = false) String caseId,
                       HttpServletRequest request, HttpServletResponse res, HttpSession session) throws IOException {
        res.setContentType("application/json;charset=UTF-8");
        String loginUser = getLoginUser(session, res);
        if (loginUser == null) return;

        switch (action) {
            case "save":   handleSave(request, res, loginUser);    break;
            case "delete": handleDelete(res, loginUser, caseId);   break;
            default: res.getWriter().write("{\"error\":\"알 수 없는 action\"}");
        }
    }

    private void handleLoad(HttpServletResponse res, String loginUser, String caseId) throws IOException {
        if (isEmpty(caseId)) { res.getWriter().write("{\"error\":\"caseId가 필요합니다.\"}"); return; }
        Connection conn = null; PreparedStatement ps = null; ResultSet rs = null;
        try {
            conn = dataSource.getConnection();
            if (!hasAccess(conn, caseId, loginUser)) { res.getWriter().write("{\"error\":\"접근 권한이 없습니다.\"}"); return; }
            ps = conn.prepareStatement(
                "SELECT b.board_id, b.case_id, b.board_json, b.created_at, b.updated_at, " +
                "       u1.user_name AS creator_name, u2.user_name AS updater_name, c.case_name " +
                "FROM relation_boards b " +
                "LEFT JOIN users u1 ON b.created_by = u1.user_id " +
                "LEFT JOIN users u2 ON b.updated_by = u2.user_id " +
                "LEFT JOIN cases c  ON b.case_id = c.case_id " +
                "WHERE b.case_id = ?");
            ps.setString(1, caseId); rs = ps.executeQuery();
            if (!rs.next()) {
                JSONObject empty = new JSONObject();
                empty.put("success", false); empty.put("boardExists", false); empty.put("message", "저장된 보드가 없습니다.");
                res.getWriter().write(empty.toString()); return;
            }
            JSONObject result = new JSONObject();
            result.put("success",     true);
            result.put("boardExists", true);
            result.put("boardId",     rs.getInt("board_id"));
            result.put("caseId",      rs.getString("case_id"));
            result.put("caseName",    nvl(rs.getString("case_name"), ""));
            result.put("boardJson",   rs.getString("board_json"));
            result.put("creatorName", nvl(rs.getString("creator_name"), ""));
            result.put("updaterName", nvl(rs.getString("updater_name"), ""));
            Timestamp ca = rs.getTimestamp("created_at"), ua = rs.getTimestamp("updated_at");
            result.put("createdAt", ca != null ? ca.toString().substring(0,16) : "");
            result.put("updatedAt", ua != null ? ua.toString().substring(0,16) : "");
            res.getWriter().write(result.toString());
        } catch (Exception e) {
            e.printStackTrace(); res.getWriter().write("{\"error\":\"보드 조회 중 오류가 발생했습니다.\"}");
        } finally { closeAll(conn, ps, rs); }
    }

    private void handleListBoards(HttpServletResponse res, String loginUser) throws IOException {
        Connection conn = null; PreparedStatement ps = null; ResultSet rs = null;
        try {
            conn = dataSource.getConnection();
            ps = conn.prepareStatement(
                "SELECT b.board_id, b.case_id, c.case_name, c.status, " +
                "       b.updated_at, u.user_name AS updater_name, b.board_json " +
                "FROM relation_boards b JOIN cases c ON b.case_id = c.case_id " +
                "LEFT JOIN users u ON b.updated_by = u.user_id " +
                "WHERE (c.user_id = ? OR c.user_id IN (" +
                "  SELECT u2.user_id FROM users u2 JOIN users me ON me.user_id = ? " +
                "  WHERE u2.dept_id = me.dept_id AND me.dept_id IS NOT NULL)) " +
                "ORDER BY b.updated_at DESC");
            ps.setString(1, loginUser); ps.setString(2, loginUser); rs = ps.executeQuery();
            JSONArray arr = new JSONArray();
            while (rs.next()) {
                JSONObject b = new JSONObject();
                b.put("boardId",     rs.getInt("board_id"));
                b.put("caseId",      rs.getString("case_id"));
                b.put("caseName",    nvl(rs.getString("case_name"), ""));
                b.put("status",      nvl(rs.getString("status"),    "진행중"));
                Timestamp ua = rs.getTimestamp("updated_at");
                b.put("updatedAt",   ua != null ? ua.toString().substring(0,16) : "");
                b.put("updaterName", nvl(rs.getString("updater_name"), ""));
                try {
                    JSONObject bj = new JSONObject(nvl(rs.getString("board_json"), "{}"));
                    b.put("personCount", bj.optJSONArray("persons") != null ? bj.optJSONArray("persons").length() : 0);
                    b.put("edgeCount",   bj.optJSONArray("edges")   != null ? bj.optJSONArray("edges").length()   : 0);
                } catch (Exception ignored) { b.put("personCount", 0); b.put("edgeCount", 0); }
                arr.put(b);
            }
            JSONObject result = new JSONObject(); result.put("success", true); result.put("boards", arr);
            res.getWriter().write(result.toString());
        } catch (Exception e) {
            e.printStackTrace(); res.getWriter().write("{\"error\":\"보드 목록 조회 중 오류가 발생했습니다.\"}");
        } finally { closeAll(conn, ps, rs); }
    }

    private void handleSave(HttpServletRequest request, HttpServletResponse res, String loginUser) throws IOException {
        StringBuilder sb = new StringBuilder();
        try (BufferedReader br = request.getReader()) {
            String line; while ((line = br.readLine()) != null) sb.append(line);
        }
        JSONObject body;
        try { body = new JSONObject(sb.toString()); }
        catch (Exception e) { res.getWriter().write("{\"error\":\"요청 JSON이 올바르지 않습니다.\"}"); return; }

        String caseId    = nvl(body.optString("caseId"),    "");
        String boardJson = body.optString("boardJson",      "{}");
        boolean isUpdate = body.optBoolean("isUpdate",      false);
        if (isEmpty(caseId)) { res.getWriter().write("{\"error\":\"caseId가 필요합니다.\"}"); return; }

        Connection conn = null; PreparedStatement ps = null;
        try {
            conn = dataSource.getConnection();
            if (!hasAccess(conn, caseId, loginUser)) { res.getWriter().write("{\"error\":\"접근 권한이 없습니다.\"}"); return; }

            ps = conn.prepareStatement("SELECT board_id FROM relation_boards WHERE case_id=?");
            ps.setString(1, caseId); ResultSet rs = ps.executeQuery();
            boolean exists = rs.next(); rs.close(); ps.close();

            if (exists) {
                ps = conn.prepareStatement("UPDATE relation_boards SET board_json=?, updated_by=?, updated_at=NOW() WHERE case_id=?");
                ps.setString(1, boardJson); ps.setString(2, loginUser); ps.setString(3, caseId);
            } else {
                ps = conn.prepareStatement("INSERT INTO relation_boards (case_id, created_by, updated_by, board_json) VALUES (?,?,?,?)");
                ps.setString(1, caseId); ps.setString(2, loginUser); ps.setString(3, loginUser); ps.setString(4, boardJson);
            }
            ps.executeUpdate(); ps.close(); ps = null;

            syncPersonsAndEdges(conn, caseId, boardJson, loginUser);

            String caseName = getCaseName(conn, caseId);
            String tag      = isUpdate ? "관계망" : "새 사건";
            String title    = isUpdate ? "관계망 보드 업데이트: " + caseId : "관계망 보드 등록: " + caseId;
            String desc     = isUpdate
                ? "사건 " + caseId + "(" + caseName + ")의 관계망 보드가 업데이트됐습니다."
                : "사건 " + caseId + "(" + caseName + ")의 관계망 보드가 등록됐습니다.";
            sendTeamNotif(conn, loginUser, caseId, tag, title, desc);

            JSONObject result = new JSONObject();
            result.put("success",  true);
            result.put("isUpdate", exists);
            result.put("message",  exists ? "보드가 업데이트됐습니다." : "보드가 저장됐습니다.");
            res.getWriter().write(result.toString());
        } catch (Exception e) {
            e.printStackTrace(); res.getWriter().write("{\"error\":\"보드 저장 중 오류가 발생했습니다: " + e.getMessage() + "\"}");
        } finally { closeAll(conn, ps, null); }
    }

    private void handleDelete(HttpServletResponse res, String loginUser, String caseId) throws IOException {
        if (isEmpty(caseId)) { res.getWriter().write("{\"error\":\"caseId가 필요합니다.\"}"); return; }
        Connection conn = null; PreparedStatement ps = null;
        try {
            conn = dataSource.getConnection();
            if (!hasAccess(conn, caseId, loginUser)) { res.getWriter().write("{\"error\":\"접근 권한이 없습니다.\"}"); return; }
            ps = conn.prepareStatement("DELETE FROM relation_boards WHERE case_id=?");
            ps.setString(1, caseId); ps.executeUpdate();
            res.getWriter().write("{\"success\":true,\"message\":\"보드가 삭제됐습니다.\"}");
        } catch (Exception e) {
            e.printStackTrace(); res.getWriter().write("{\"error\":\"보드 삭제 중 오류가 발생했습니다.\"}");
        } finally { closeAll(conn, ps, null); }
    }

    private void syncPersonsAndEdges(Connection conn, String caseId, String boardJson, String userId) throws Exception {
        JSONObject bj = new JSONObject(boardJson);
        JSONArray persons = bj.optJSONArray("persons");
        JSONArray edges   = bj.optJSONArray("edges");

        PreparedStatement ps = conn.prepareStatement("DELETE FROM relation_edges WHERE case_id=?");
        ps.setString(1, caseId); ps.executeUpdate(); ps.close();
        ps = conn.prepareStatement("DELETE FROM relation_persons WHERE case_id=?");
        ps.setString(1, caseId); ps.executeUpdate(); ps.close();

        Map<String, Integer> nameToId = new HashMap<>();
        if (persons != null) {
            ps = conn.prepareStatement(
                "INSERT INTO relation_persons (case_id, person_name, role, memo) VALUES (?,?,?,?)",
                Statement.RETURN_GENERATED_KEYS);
            for (int i = 0; i < persons.length(); i++) {
                JSONObject p = persons.getJSONObject(i);
                String pName = nvl(p.optString("name"), "").trim();
                if (pName.isEmpty() || nameToId.containsKey(pName)) continue;
                ps.setString(1, caseId); ps.setString(2, pName);
                ps.setString(3, nvl(p.optString("role"), "reference"));
                ps.setString(4, nvl(p.optString("memo"), ""));
                ps.executeUpdate();
                ResultSet gk = ps.getGeneratedKeys();
                if (gk.next()) nameToId.put(pName, gk.getInt(1));
                gk.close();
            }
            ps.close();
        }

        if (edges != null && !nameToId.isEmpty()) {
            ps = conn.prepareStatement(
                "INSERT INTO relation_edges (case_id, src_person_id, dst_person_id, rel_type, status, context) VALUES (?,?,?,?,?,?)");
            for (int i = 0; i < edges.length(); i++) {
                JSONObject e = edges.getJSONObject(i);
                Integer srcId = nameToId.get(nvl(e.optString("srcName"), ""));
                Integer dstId = nameToId.get(nvl(e.optString("dstName"), ""));
                if (srcId == null || dstId == null) continue;
                ps.setString(1, caseId); ps.setString(2, String.valueOf(srcId)); ps.setString(3, String.valueOf(dstId));
                ps.setString(4, nvl(e.optString("relType"), "acquaint"));
                ps.setString(5, nvl(e.optString("status"),  "unknown"));
                String ctx = e.optString("context", "").trim();
                if (!ctx.equals("scene") && !ctx.equals("time") && !ctx.equals("evidence")) ctx = "";
                ps.setString(6, ctx.isEmpty() ? null : ctx);
                ps.executeUpdate();
            }
            ps.close();
        }

        ps = conn.prepareStatement("INSERT INTO relation_history (case_id, user_id, action) VALUES (?,?,?)");
        int pCount = persons != null ? persons.length() : 0;
        int eCount = edges   != null ? edges.length()   : 0;
        ps.setString(1, caseId); ps.setString(2, userId);
        ps.setString(3, "보드 저장: 인물 " + pCount + "명, 관계선 " + eCount + "개");
        ps.executeUpdate(); ps.close();
    }

    private void sendTeamNotif(Connection conn, String loginUser, String caseId, String tag, String title, String desc) {
        try {
            PreparedStatement ps = conn.prepareStatement(
                "SELECT u2.user_id FROM users u2 JOIN users me ON me.user_id=? " +
                "WHERE u2.dept_id=me.dept_id AND me.dept_id IS NOT NULL AND u2.user_id!=? AND u2.notif_relation=1");
            ps.setString(1, loginUser); ps.setString(2, loginUser);
            ResultSet rs = ps.executeQuery();
            List<String> teammates = new ArrayList<>();
            while (rs.next()) teammates.add(rs.getString("user_id"));
            rs.close(); ps.close();
            for (String tm : teammates) {
                try { NotificationUtil.insertNotification(conn, tm, "case", tag, title, desc, "boardView.jsp?caseId=" + caseId, false); }
                catch (Exception ignored) {}
            }
        } catch (Exception e) { e.printStackTrace(); }
    }

    private boolean hasAccess(Connection conn, String caseId, String userId) throws SQLException {
        PreparedStatement ps = conn.prepareStatement(
            "SELECT 1 FROM cases WHERE case_id=? " +
            "AND (user_id=? OR user_id IN (" +
            "  SELECT u2.user_id FROM users u2 JOIN users me ON me.user_id=? " +
            "  WHERE u2.dept_id=me.dept_id AND me.dept_id IS NOT NULL))");
        ps.setString(1, caseId); ps.setString(2, userId); ps.setString(3, userId);
        ResultSet rs = ps.executeQuery(); boolean ok = rs.next(); rs.close(); ps.close();
        return ok;
    }

    private String getCaseName(Connection conn, String caseId) {
        try {
            PreparedStatement ps = conn.prepareStatement("SELECT case_name FROM cases WHERE case_id=?");
            ps.setString(1, caseId); ResultSet rs = ps.executeQuery();
            String name = rs.next() ? rs.getString("case_name") : ""; rs.close(); ps.close();
            return name;
        } catch (Exception e) { return ""; }
    }

    private String getLoginUser(HttpSession session, HttpServletResponse res) throws IOException {
        String u = (session != null) ? (String) session.getAttribute("loginUser") : null;
        if (u == null) res.getWriter().write("{\"error\":\"로그인이 필요합니다.\"}");
        return u;
    }

    private String nvl(String s, String def) { return (s == null || s.trim().isEmpty()) ? def : s.trim(); }
    private String nvl(String s)             { return nvl(s, ""); }
    private boolean isEmpty(String s)        { return s == null || s.trim().isEmpty(); }
    private void closeAll(Connection c, PreparedStatement p, ResultSet r) {
        try { if (r != null) r.close(); } catch (Exception ignored) {}
        try { if (p != null) p.close(); } catch (Exception ignored) {}
        try { if (c != null) c.close(); } catch (Exception ignored) {}
    }
}
