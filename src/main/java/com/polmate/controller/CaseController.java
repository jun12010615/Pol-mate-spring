package com.polmate.controller;

import com.polmate.util.NotificationUtil;
import org.json.JSONArray;
import org.json.JSONObject;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.web.bind.annotation.*;

import jakarta.servlet.http.HttpServletResponse;
import jakarta.servlet.http.HttpSession;
import javax.sql.DataSource;
import java.io.*;
import java.net.HttpURLConnection;
import java.net.URL;
import java.nio.charset.StandardCharsets;
import java.sql.*;
import java.text.SimpleDateFormat;
import java.util.*;

@RestController
@RequestMapping("/caseApi")
public class CaseController {

    private static final SimpleDateFormat DATE_FMT = new SimpleDateFormat("yyyy.MM.dd");
    static { DATE_FMT.setTimeZone(TimeZone.getTimeZone("Asia/Seoul")); }

    @Autowired
    private DataSource dataSource;

    @Value("${polmate.serv.base-url}")
    private String polMateServBaseUrl;

    @GetMapping
    public void doGet(@RequestParam(defaultValue = "caseList") String action,
                      @RequestParam(required = false) String caseId,
                      @RequestParam(required = false) String status,
                      @RequestParam(required = false) String keyword,
                      @RequestParam(required = false) String transcriptId,
                      HttpServletResponse res, HttpSession session) throws IOException {
        res.setContentType("application/json;charset=UTF-8");
        String loginUser = getLoginUser(session, res);
        if (loginUser == null) return;

        switch (action) {
            case "caseList":       handleCaseList(res, loginUser, nvl(status, "all"), nvl(keyword, "")); break;
            case "caseDetail":     handleCaseDetail(res, loginUser, caseId);     break;
            case "docList":        handleDocList(res, loginUser, nvl(keyword, "")); break;
            case "docStats":       handleDocStats(res, loginUser);               break;
            case "myDept":         handleMyDept(res, loginUser);                 break;
            case "transcriptText": handleTranscriptText(res, loginUser, transcriptId); break;
            case "getScore":       handleGetScore(res, loginUser, transcriptId);       break;
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
            case "caseCreate":          handleCaseCreate(res, loginUser, caseId, caseName, nvl(suspect, ""), nvl(charge, "")); break;
            case "caseDelete":          handleCaseDelete(res, loginUser, caseId);          break;
            case "caseStatus":          handleCaseStatus(res, loginUser, caseId, status);  break;
            case "transcriptSave":      handleTranscriptSave(res, loginUser, caseId, nvl(stmtType, ""), nvl(stmtName, ""), nvl(originalText, "")); break;
            case "transcriptSummarize": handleTranscriptSummarize(res, loginUser, transcriptId); break;
            case "scoreTranscript":     handleScoreTranscript(res, loginUser, transcriptId);     break;
            default: res.getWriter().write("{\"error\":\"알 수 없는 action\"}");
        }
    }

    private void handleCaseList(HttpServletResponse res, String loginUser, String status, String keyword) throws IOException {
        Connection conn = null; PreparedStatement ps = null; ResultSet rs = null;
        try {
            conn = dataSource.getConnection();
            StringBuilder sql = new StringBuilder(
                "SELECT c.case_id, c.case_name, c.suspect, c.charge, c.status, " +
                "       c.created_at, c.user_id, u.user_name, u.user_rank, " +
                "       (SELECT COUNT(*) FROM transcripts t WHERE t.case_id = c.case_id) AS doc_count, " +
                "       (SELECT COUNT(*) FROM transcripts t WHERE t.case_id = c.case_id AND t.has_contradiction = 1) AS contradiction_count " +
                "FROM cases c LEFT JOIN users u ON c.user_id = u.user_id " +
                "WHERE c.dept_id = (SELECT me.dept_id FROM users me WHERE me.user_id = ?) ");
            List<Object> params = new ArrayList<>();
            params.add(loginUser);
            if (!"all".equals(status)) { sql.append("AND c.status = ? "); params.add(status); }
            if (!keyword.isEmpty()) {
                sql.append("AND (c.case_id LIKE ? OR c.case_name LIKE ? OR c.suspect LIKE ?) ");
                params.add("%" + keyword + "%"); params.add("%" + keyword + "%"); params.add("%" + keyword + "%");
            }
            sql.append("ORDER BY c.updated_at DESC");
            ps = conn.prepareStatement(sql.toString());
            for (int i = 0; i < params.size(); i++) ps.setObject(i + 1, params.get(i));
            rs = ps.executeQuery();
            JSONArray arr = new JSONArray();
            while (rs.next()) {
                JSONObject c = new JSONObject();
                c.put("id",             rs.getString("case_id"));
                c.put("name",           rs.getString("case_name"));
                c.put("suspect",        nvl(rs.getString("suspect"),   "미입력"));
                c.put("charge",         nvl(rs.getString("charge"),    "미입력"));
                c.put("detective",      nvl(rs.getString("user_name"), "미입력"));
                c.put("rank",           nvl(rs.getString("user_rank"), ""));
                c.put("status",         rs.getString("status"));
                c.put("docs",           rs.getInt("doc_count"));
                c.put("contradictions", rs.getInt("contradiction_count"));
                c.put("urgent",         rs.getInt("contradiction_count") > 0);
                c.put("isMine",         loginUser.equals(rs.getString("user_id")));
                Timestamp ts = rs.getTimestamp("created_at");
                c.put("date", ts != null ? DATE_FMT.format(ts) : "");
                arr.put(c);
            }
            res.getWriter().write(arr.toString());
        } catch (Exception e) {
            e.printStackTrace();
            res.getWriter().write("{\"error\":\"사건 목록 조회 중 오류가 발생했습니다.\"}");
        } finally { closeAll(conn, ps, rs); }
    }

    private void handleCaseDetail(HttpServletResponse res, String loginUser, String caseId) throws IOException {
        if (isEmpty(caseId)) { res.getWriter().write("{\"error\":\"caseId가 필요합니다.\"}"); return; }
        Connection conn = null; PreparedStatement ps = null; ResultSet rs = null;
        try {
            conn = dataSource.getConnection();
            ps = conn.prepareStatement(
                "SELECT c.case_id, c.case_name, c.suspect, c.charge, c.status, " +
                "       c.created_at, c.user_id, d.dept_name, d.org_name, " +
                "       u.user_name, u.user_rank " +
                "FROM cases c LEFT JOIN users u ON c.user_id = u.user_id " +
                "LEFT JOIN departments d ON c.dept_id = d.dept_id " +
                "WHERE c.case_id = ? " +
                "AND c.dept_id = (SELECT me.dept_id FROM users me WHERE me.user_id = ?)");
            ps.setString(1, caseId); ps.setString(2, loginUser);
            rs = ps.executeQuery();
            if (!rs.next()) { res.getWriter().write("{\"error\":\"사건을 찾을 수 없거나 접근 권한이 없습니다.\"}"); return; }
            JSONObject detail = new JSONObject();
            detail.put("id",        rs.getString("case_id"));
            detail.put("name",      rs.getString("case_name"));
            detail.put("suspect",   nvl(rs.getString("suspect"),   "미입력"));
            detail.put("charge",    nvl(rs.getString("charge"),    "미입력"));
            detail.put("status",    rs.getString("status"));
            detail.put("isMine",    loginUser.equals(rs.getString("user_id")));
            detail.put("detective", nvl(rs.getString("user_name"), "미입력"));
            detail.put("rank",      nvl(rs.getString("user_rank"), ""));
            String deptName = rs.getString("dept_name"), orgName = rs.getString("org_name");
            if (deptName != null && !deptName.isEmpty())
                detail.put("deptName", orgName != null && !orgName.isEmpty() ? deptName + " (" + orgName + ")" : deptName);
            else detail.put("deptName", "미배정");
            Timestamp ts = rs.getTimestamp("created_at");
            detail.put("date", ts != null ? DATE_FMT.format(ts) : "");
            rs.close(); ps.close();

            ps = conn.prepareStatement(
                "SELECT t.transcript_id, t.stmt_type, t.stmt_name, t.has_contradiction, " +
                "       t.created_at, t.user_id, u.user_name, u.user_rank, " +
                "       CHAR_LENGTH(IFNULL(t.original_text,'')) AS text_len, " +
                "       ts.total_score, ts.consistency_score, ts.specificity_score, " +
                "       ts.emotion_score, ts.temporal_score, " +
                "       ts.consistency_reason, ts.specificity_reason, ts.emotion_reason, ts.temporal_reason " +
                "FROM transcripts t LEFT JOIN users u ON t.user_id = u.user_id " +
                "LEFT JOIN transcript_scores ts ON t.transcript_id = ts.transcript_id " +
                "WHERE t.case_id = ? ORDER BY t.created_at DESC");
            ps.setString(1, caseId); rs = ps.executeQuery();
            JSONArray docs = new JSONArray();
            while (rs.next()) {
                JSONObject d = new JSONObject();
                d.put("id",           rs.getInt("transcript_id"));
                d.put("type",         nvl(rs.getString("stmt_type"), "미분류"));
                d.put("name",         nvl(rs.getString("stmt_name"), "미입력"));
                d.put("contradiction", rs.getBoolean("has_contradiction"));
                d.put("textLen",      rs.getInt("text_len"));
                d.put("writerId",     nvl(rs.getString("user_id"),   ""));
                d.put("writerName",   nvl(rs.getString("user_name"), "알 수 없음"));
                d.put("writerRank",   nvl(rs.getString("user_rank"), ""));
                Timestamp dts = rs.getTimestamp("created_at");
                d.put("date", dts != null ? DATE_FMT.format(dts) : "");
                Object totalObj = rs.getObject("total_score");
                boolean scored = totalObj != null;
                d.put("scored", scored);
                if (scored) {
                    d.put("totalScore",  ((Number) totalObj).intValue());
                    d.put("consistency", rs.getInt("consistency_score"));
                    d.put("specificity", rs.getInt("specificity_score"));
                    d.put("emotion",     rs.getInt("emotion_score"));
                    d.put("temporal",    rs.getInt("temporal_score"));
                    d.put("cReason",     nvl(rs.getString("consistency_reason"), ""));
                    d.put("sReason",     nvl(rs.getString("specificity_reason"), ""));
                    d.put("eReason",     nvl(rs.getString("emotion_reason"),     ""));
                    d.put("tReason",     nvl(rs.getString("temporal_reason"),    ""));
                }
                docs.put(d);
            }
            detail.put("docs", docs); detail.put("docCount", docs.length());
            res.getWriter().write(detail.toString());
        } catch (Exception e) {
            e.printStackTrace();
            res.getWriter().write("{\"error\":\"사건 상세 조회 중 오류가 발생했습니다.\"}");
        } finally { closeAll(conn, ps, rs); }
    }

    private void handleCaseCreate(HttpServletResponse res, String loginUser,
                                  String caseId, String caseName, String suspect, String charge) throws IOException {
        if (isEmpty(caseId) || isEmpty(caseName)) {
            writeResult(res, false, "사건번호와 사건명은 필수입니다."); return;
        }
        if (!caseId.matches("^\\d{4}-\\d{4}$")) {
            writeResult(res, false, "사건번호 형식이 올바르지 않습니다. (예: 2024-0312)"); return;
        }
        Connection conn = null; PreparedStatement ps = null;
        try {
            conn = dataSource.getConnection();
            ps = conn.prepareStatement("SELECT 1 FROM cases WHERE case_id = ?");
            ps.setString(1, caseId);
            ResultSet rs = ps.executeQuery();
            if (rs.next()) { rs.close(); ps.close(); writeResult(res, false, "이미 존재하는 사건번호입니다."); return; }
            rs.close(); ps.close();

            ps = conn.prepareStatement(
                "SELECT u.dept_id, d.dept_name, d.org_name FROM users u " +
                "LEFT JOIN departments d ON u.dept_id = d.dept_id WHERE u.user_id = ?");
            ps.setString(1, loginUser); rs = ps.executeQuery();
            Integer creatorDeptId = null; String deptLabel = "부서 미배정";
            if (rs.next()) {
                int deptIdVal = rs.getInt("dept_id");
                if (!rs.wasNull()) {
                    creatorDeptId = deptIdVal;
                    String dn = rs.getString("dept_name"), on = rs.getString("org_name");
                    if (dn != null && !dn.isEmpty())
                        deptLabel = on != null && !on.isEmpty() ? dn + " (" + on + ")" : dn;
                }
            }
            rs.close(); ps.close();

            ps = conn.prepareStatement(
                "INSERT INTO cases (case_id, user_id, dept_id, case_name, suspect, charge, status) VALUES (?,?,?,?,?,?,'진행중')");
            ps.setString(1, caseId); ps.setString(2, loginUser);
            if (creatorDeptId != null) ps.setInt(3, creatorDeptId); else ps.setNull(3, Types.INTEGER);
            ps.setString(4, caseName.trim());
            ps.setString(5, suspect.isEmpty() ? null : suspect.trim());
            ps.setString(6, charge.isEmpty()  ? null : charge.trim());
            ps.executeUpdate(); ps.close();

            try {
                ps = conn.prepareStatement(
                    "SELECT u2.user_id FROM users u2 WHERE u2.dept_id = ? AND u2.dept_id IS NOT NULL " +
                    "  AND u2.user_id != ? AND u2.notif_relation = 1");
                if (creatorDeptId != null) ps.setInt(1, creatorDeptId); else ps.setNull(1, Types.INTEGER);
                ps.setString(2, loginUser); rs = ps.executeQuery();
                List<String> teammates = new ArrayList<>();
                while (rs.next()) teammates.add(rs.getString("user_id"));
                rs.close(); ps.close(); ps = null;
                String notifTitle = "팀 새 사건 등록: " + caseName.trim();
                String notifDesc  = "사건 " + caseId + "(" + caseName.trim() + ")이(가) 팀에 등록됐습니다.";
                for (String teammate : teammates) {
                    try { NotificationUtil.insertNotification(conn, teammate, "case", "새 사건", notifTitle, notifDesc, "myCase.jsp?caseId=" + caseId, false); }
                    catch (Exception ignored) {}
                }
            } catch (SQLException ignored) {}

            JSONObject result = new JSONObject();
            result.put("success", true); result.put("caseId", caseId);
            result.put("deptLabel", deptLabel); result.put("message", "사건이 등록됐습니다.");
            res.getWriter().write(result.toString());
        } catch (Exception e) {
            e.printStackTrace(); writeResult(res, false, "사건 등록 중 오류가 발생했습니다.");
        } finally { closeAll(conn, ps, null); }
    }

    private void handleCaseDelete(HttpServletResponse res, String loginUser, String caseId) throws IOException {
        if (isEmpty(caseId)) { writeResult(res, false, "caseId가 필요합니다."); return; }
        Connection conn = null; PreparedStatement ps = null;
        try {
            conn = dataSource.getConnection();
            ps = conn.prepareStatement("SELECT user_id FROM cases WHERE case_id = ?");
            ps.setString(1, caseId); ResultSet rs = ps.executeQuery();
            if (!rs.next() || !loginUser.equals(rs.getString("user_id"))) {
                rs.close(); writeResult(res, false, "삭제 권한이 없습니다. (등록자만 삭제 가능)"); return;
            }
            rs.close(); ps.close();
            ps = conn.prepareStatement("DELETE FROM cases WHERE case_id = ?");
            ps.setString(1, caseId); ps.executeUpdate();
            writeResult(res, true, "사건이 삭제됐습니다.");
        } catch (Exception e) {
            e.printStackTrace(); writeResult(res, false, "삭제 중 오류가 발생했습니다.");
        } finally { closeAll(conn, ps, null); }
    }

    private void handleCaseStatus(HttpServletResponse res, String loginUser, String caseId, String status) throws IOException {
        if (isEmpty(caseId)) { writeResult(res, false, "caseId가 필요합니다."); return; }
        Connection conn = null; PreparedStatement ps = null;
        try {
            conn = dataSource.getConnection();
            ps = conn.prepareStatement(
                "SELECT 1 FROM cases WHERE case_id = ? " +
                "AND dept_id = (SELECT me.dept_id FROM users me WHERE me.user_id = ?)");
            ps.setString(1, caseId); ps.setString(2, loginUser);
            ResultSet rs = ps.executeQuery();
            if (!rs.next()) { rs.close(); writeResult(res, false, "수정 권한이 없습니다."); return; }
            rs.close(); ps.close();

            List<Object> params = new ArrayList<>();
            StringBuilder sql = new StringBuilder("UPDATE cases SET updated_at = NOW()");
            if (!isEmpty(status)) { sql.append(", status = ?"); params.add(status); }
            sql.append(" WHERE case_id = ?"); params.add(caseId);
            ps = conn.prepareStatement(sql.toString());
            for (int i = 0; i < params.size(); i++) ps.setObject(i + 1, params.get(i));
            ps.executeUpdate(); ps.close();

            if (!isEmpty(status)) {
                boolean isCritical = "모순탐지".equals(status);
                String notifCol = isCritical ? "notif_contradiction" : "notif_relation";
                ps = conn.prepareStatement(
                    "SELECT u2.user_id FROM users u2 JOIN cases c ON c.case_id = ? " +
                    "WHERE u2.dept_id = c.dept_id AND c.dept_id IS NOT NULL " +
                    "  AND u2.user_id != ? AND u2." + notifCol + " = 1");
                ps.setString(1, caseId); ps.setString(2, loginUser);
                rs = ps.executeQuery();
                List<String> teammates = new ArrayList<>();
                while (rs.next()) teammates.add(rs.getString("user_id"));
                rs.close(); ps.close(); ps = null;
                String notifTitle = "사건 상태 변경: " + caseId;
                String notifDesc  = "사건 " + caseId + "의 상태가 [" + status + "](으)로 변경됐습니다.";
                String tag = isCritical ? "경고" : "새 사건";
                for (String teammate : teammates) {
                    try { NotificationUtil.insertNotification(conn, teammate, "case", tag, notifTitle, notifDesc, "myCase.jsp?caseId=" + caseId, isCritical); }
                    catch (Exception ignored) {}
                }
            }
            writeResult(res, true, "수정됐습니다.");
        } catch (Exception e) {
            e.printStackTrace(); writeResult(res, false, "수정 중 오류가 발생했습니다.");
        } finally { closeAll(conn, ps, null); }
    }

    private void handleDocList(HttpServletResponse res, String loginUser, String keyword) throws IOException {
        Connection conn = null; PreparedStatement ps = null; ResultSet rs = null;
        try {
            conn = dataSource.getConnection();
            StringBuilder sql = new StringBuilder(
                "SELECT t.transcript_id, t.case_id, t.stmt_type, t.stmt_name, " +
                "       t.has_contradiction, t.created_at, " +
                "       CHAR_LENGTH(IFNULL(t.original_text,'')) AS text_len, c.case_name " +
                "FROM transcripts t JOIN cases c ON t.case_id = c.case_id " +
                "WHERE t.user_id = ? ");
            List<Object> params = new ArrayList<>(); params.add(loginUser);
            if (!keyword.isEmpty()) {
                sql.append("AND (c.case_id LIKE ? OR c.case_name LIKE ? OR t.stmt_name LIKE ?) ");
                params.add("%" + keyword + "%"); params.add("%" + keyword + "%"); params.add("%" + keyword + "%");
            }
            sql.append("ORDER BY t.created_at DESC");
            ps = conn.prepareStatement(sql.toString());
            for (int i = 0; i < params.size(); i++) ps.setObject(i + 1, params.get(i));
            rs = ps.executeQuery();
            JSONArray arr = new JSONArray();
            while (rs.next()) {
                String stmtType = nvl(rs.getString("stmt_type"), "미분류");
                String stmtName = nvl(rs.getString("stmt_name"), "미입력");
                boolean hasCont = rs.getBoolean("has_contradiction");
                JSONObject d = new JSONObject();
                d.put("id",           rs.getInt("transcript_id"));
                d.put("caseId",       rs.getString("case_id"));
                d.put("caseName",     rs.getString("case_name"));
                d.put("title",        stmtName + " " + stmtType + " 진술 조서");
                d.put("type",         stmtType);
                d.put("status",       hasCont ? "모순탐지" : "완료");
                d.put("words",        rs.getInt("text_len"));
                d.put("contradiction", hasCont);
                Timestamp ts = rs.getTimestamp("created_at");
                d.put("date", ts != null ? DATE_FMT.format(ts) : "");
                arr.put(d);
            }
            res.getWriter().write(arr.toString());
        } catch (Exception e) {
            e.printStackTrace(); res.getWriter().write("{\"error\":\"조서 목록 조회 중 오류가 발생했습니다.\"}");
        } finally { closeAll(conn, ps, rs); }
    }

    private void handleDocStats(HttpServletResponse res, String loginUser) throws IOException {
        Connection conn = null; PreparedStatement ps = null; ResultSet rs = null;
        try {
            conn = dataSource.getConnection();
            ps = conn.prepareStatement(
                "SELECT COUNT(*) AS total, SUM(CASE WHEN has_contradiction = 1 THEN 1 ELSE 0 END) AS contradiction " +
                "FROM transcripts WHERE user_id = ?");
            ps.setString(1, loginUser); rs = ps.executeQuery();
            JSONObject stats = new JSONObject();
            if (rs.next()) { stats.put("total", rs.getInt("total")); stats.put("contradiction", rs.getInt("contradiction")); }
            else           { stats.put("total", 0); stats.put("contradiction", 0); }
            res.getWriter().write(stats.toString());
        } catch (Exception e) {
            e.printStackTrace(); res.getWriter().write("{\"error\":\"통계 조회 중 오류가 발생했습니다.\"}");
        } finally { closeAll(conn, ps, rs); }
    }

    private void handleTranscriptSave(HttpServletResponse res, String loginUser,
                                      String caseId, String stmtType, String stmtName, String originalText) throws IOException {
        if (isEmpty(caseId))       { writeResult(res, false, "사건번호를 선택해 주세요."); return; }
        if (isEmpty(originalText)) { writeResult(res, false, "진술 내용을 입력해 주세요."); return; }
        Connection conn = null; PreparedStatement ps = null; ResultSet rs = null;
        try {
            conn = dataSource.getConnection();
            ps = conn.prepareStatement(
                "SELECT 1 FROM cases WHERE case_id = ? " +
                "AND dept_id = (SELECT me.dept_id FROM users me WHERE me.user_id = ?)");
            ps.setString(1, caseId); ps.setString(2, loginUser); rs = ps.executeQuery();
            if (!rs.next()) { writeResult(res, false, "해당 사건에 접근 권한이 없습니다."); return; }
            rs.close(); ps.close();

            ps = conn.prepareStatement(
                "INSERT INTO transcripts (case_id, user_id, original_text, stmt_type, stmt_name, has_contradiction) VALUES (?,?,?,?,?,0)",
                Statement.RETURN_GENERATED_KEYS);
            ps.setString(1, caseId); ps.setString(2, loginUser); ps.setString(3, originalText);
            ps.setString(4, stmtType.isEmpty() ? null : stmtType);
            ps.setString(5, stmtName.isEmpty() ? null : stmtName);
            ps.executeUpdate();
            rs = ps.getGeneratedKeys(); rs.next(); int newId = rs.getInt(1);
            rs.close(); ps.close();

            try {
                ps = conn.prepareStatement(
                    "SELECT u2.user_id FROM users u2 JOIN cases c ON c.case_id = ? " +
                    "WHERE u2.dept_id = c.dept_id AND c.dept_id IS NOT NULL " +
                    "  AND u2.user_id != ? AND u2.notif_contradiction = 1");
                ps.setString(1, caseId); ps.setString(2, loginUser);
                rs = ps.executeQuery();
                List<String> teammates = new ArrayList<>();
                while (rs.next()) teammates.add(rs.getString("user_id"));
                rs.close(); ps.close(); ps = null;
                String who   = stmtName.isEmpty() ? "" : stmtName + " ";
                String tDesc = "사건 " + caseId + "에 " + who + (stmtType.isEmpty() ? "" : stmtType + " ") + "조서가 추가됐습니다.";
                for (String teammate : teammates) {
                    try { NotificationUtil.insertNotification(conn, teammate, "case", "조서", "새 조서 등록: " + caseId, tDesc, "myCase.jsp?caseId=" + caseId, false); }
                    catch (Exception ignored) {}
                }
            } catch (Exception ignored) {}

            JSONObject result = new JSONObject();
            result.put("success", true); result.put("transcriptId", newId); result.put("message", "조서가 저장됐습니다.");
            res.getWriter().write(result.toString());
        } catch (Exception e) {
            e.printStackTrace(); writeResult(res, false, "조서 저장 중 오류가 발생했습니다.");
        } finally { closeAll(conn, ps, rs); }
    }

    private void handleTranscriptText(HttpServletResponse res, String loginUser, String idStr) throws IOException {
        if (isEmpty(idStr)) { res.getWriter().write("{\"error\":\"transcriptId가 필요합니다.\"}"); return; }
        int transcriptId;
        try { transcriptId = Integer.parseInt(idStr); }
        catch (NumberFormatException e) { res.getWriter().write("{\"error\":\"잘못된 transcriptId\"}"); return; }
        Connection conn = null; PreparedStatement ps = null; ResultSet rs = null;
        try {
            conn = dataSource.getConnection();
            ps = conn.prepareStatement(
                "SELECT t.transcript_id, t.original_text, t.stmt_type, t.stmt_name, t.ai_result " +
                "FROM transcripts t JOIN cases c ON t.case_id = c.case_id " +
                "WHERE t.transcript_id = ? " +
                "AND c.dept_id = (SELECT me.dept_id FROM users me WHERE me.user_id = ?)");
            ps.setInt(1, transcriptId); ps.setString(2, loginUser); rs = ps.executeQuery();
            if (!rs.next()) { res.getWriter().write("{\"error\":\"조서를 찾을 수 없거나 접근 권한이 없습니다.\"}"); return; }
            JSONObject result = new JSONObject();
            result.put("id",   rs.getInt("transcript_id"));
            result.put("text", nvl(rs.getString("original_text"), ""));
            result.put("type", nvl(rs.getString("stmt_type"),     ""));
            result.put("name", nvl(rs.getString("stmt_name"),     ""));
            String ar = rs.getString("ai_result");
            result.put("summary", (ar != null && !ar.isEmpty()) ? ar : "");
            res.getWriter().write(result.toString());
        } catch (Exception e) {
            e.printStackTrace(); res.getWriter().write("{\"error\":\"조서 원문 조회 중 오류가 발생했습니다.\"}");
        } finally { closeAll(conn, ps, rs); }
    }

    private void handleTranscriptSummarize(HttpServletResponse res, String loginUser, String idStr) throws IOException {
        if (isEmpty(idStr)) { res.getWriter().write("{\"error\":\"transcriptId가 필요합니다.\"}"); return; }
        int transcriptId;
        try { transcriptId = Integer.parseInt(idStr); }
        catch (NumberFormatException e) { res.getWriter().write("{\"error\":\"잘못된 transcriptId\"}"); return; }
        Connection conn = null; PreparedStatement ps = null; ResultSet rs = null;
        try {
            conn = dataSource.getConnection();
            ps = conn.prepareStatement(
                "SELECT t.case_id, t.original_text, t.stmt_type, t.stmt_name " +
                "FROM transcripts t JOIN cases c ON t.case_id = c.case_id " +
                "WHERE t.transcript_id = ? " +
                "AND c.dept_id = (SELECT me.dept_id FROM users me WHERE me.user_id = ?)");
            ps.setInt(1, transcriptId); ps.setString(2, loginUser); rs = ps.executeQuery();
            if (!rs.next()) { res.getWriter().write("{\"error\":\"조서를 찾을 수 없거나 접근 권한이 없습니다.\"}"); return; }
            String caseId = rs.getString("case_id");
            String originalText = rs.getString("original_text");
            String stmtType = rs.getString("stmt_type");
            String stmtName = rs.getString("stmt_name");
            rs.close(); ps.close(); ps = null; rs = null;

            if (originalText == null || originalText.trim().isEmpty()) {
                writeResult(res, false, "요약할 진술 본문이 없습니다."); return;
            }

            JSONObject body = new JSONObject();
            body.put("caseNum",  caseId != null ? caseId : "미입력");
            body.put("text",     originalText);
            body.put("stmtType", stmtType != null && !stmtType.trim().isEmpty() ? stmtType.trim() : "진술자");
            body.put("stmtName", stmtName != null && !stmtName.trim().isEmpty() ? stmtName.trim() : "미입력");

            String structured = callPolMateSummarize(body);
            if (structured == null) { writeResult(res, false, "요약 서버 호출에 실패했습니다."); return; }

            ps = conn.prepareStatement("UPDATE transcripts SET ai_result = ? WHERE transcript_id = ?");
            ps.setString(1, structured); ps.setInt(2, transcriptId);
            int n = ps.executeUpdate();
            JSONObject out = new JSONObject();
            out.put("success", n > 0);
            out.put("message", n > 0 ? "요약이 저장되었습니다." : "요약 저장에 실패했습니다.");
            res.getWriter().write(out.toString());
        } catch (Exception e) {
            e.printStackTrace(); writeResult(res, false, "요약 처리 중 오류가 발생했습니다.");
        } finally { closeAll(conn, ps, rs); }
    }

    private void handleMyDept(HttpServletResponse res, String loginUser) throws IOException {
        Connection conn = null; PreparedStatement ps = null; ResultSet rs = null;
        try {
            conn = dataSource.getConnection();
            ps = conn.prepareStatement(
                "SELECT d.dept_id, d.dept_name, d.org_name FROM users u " +
                "LEFT JOIN departments d ON u.dept_id = d.dept_id WHERE u.user_id = ?");
            ps.setString(1, loginUser); rs = ps.executeQuery();
            JSONObject result = new JSONObject();
            if (rs.next() && rs.getString("dept_name") != null) {
                result.put("deptId",   rs.getInt("dept_id"));
                result.put("deptName", rs.getString("dept_name"));
                result.put("org",      nvl(rs.getString("org_name"), ""));
                result.put("label",    rs.getString("dept_name") + " (" + nvl(rs.getString("org_name"), "") + ")");
            } else {
                result.put("deptId",   JSONObject.NULL);
                result.put("deptName", "미배정");
                result.put("org",      "");
                result.put("label",    "부서 미배정");
            }
            res.getWriter().write(result.toString());
        } catch (Exception e) {
            e.printStackTrace(); res.getWriter().write("{\"error\":\"부서 정보 조회 중 오류가 발생했습니다.\"}");
        } finally { closeAll(conn, ps, rs); }
    }

    private void handleGetScore(HttpServletResponse res, String loginUser, String idStr) throws IOException {
        if (isEmpty(idStr)) { res.getWriter().write("{\"error\":\"transcriptId가 필요합니다.\"}"); return; }
        int transcriptId;
        try { transcriptId = Integer.parseInt(idStr); }
        catch (NumberFormatException e) { res.getWriter().write("{\"error\":\"잘못된 transcriptId\"}"); return; }
        Connection conn = null; PreparedStatement ps = null; ResultSet rs = null;
        try {
            conn = dataSource.getConnection();
            ps = conn.prepareStatement(
                "SELECT ts.total_score, ts.consistency_score, ts.specificity_score, ts.emotion_score, ts.temporal_score, " +
                "       ts.consistency_reason, ts.specificity_reason, ts.emotion_reason, ts.temporal_reason, ts.scored_at " +
                "FROM transcript_scores ts " +
                "JOIN transcripts t ON t.transcript_id = ts.transcript_id " +
                "JOIN cases c ON c.case_id = t.case_id " +
                "WHERE ts.transcript_id = ? " +
                "AND c.dept_id = (SELECT me.dept_id FROM users me WHERE me.user_id = ?)");
            ps.setInt(1, transcriptId); ps.setString(2, loginUser); rs = ps.executeQuery();
            if (!rs.next()) { res.getWriter().write("{\"scored\":false}"); return; }
            JSONObject r = new JSONObject();
            r.put("scored",      true);
            r.put("total",       rs.getInt("total_score"));
            r.put("consistency", rs.getInt("consistency_score"));
            r.put("specificity", rs.getInt("specificity_score"));
            r.put("emotion",     rs.getInt("emotion_score"));
            r.put("temporal",    rs.getInt("temporal_score"));
            JSONObject reasons = new JSONObject();
            reasons.put("consistency", nvl(rs.getString("consistency_reason"), ""));
            reasons.put("specificity", nvl(rs.getString("specificity_reason"), ""));
            reasons.put("emotion",     nvl(rs.getString("emotion_reason"),     ""));
            reasons.put("temporal",    nvl(rs.getString("temporal_reason"),    ""));
            r.put("reasons", reasons);
            Timestamp st = rs.getTimestamp("scored_at");
            r.put("scoredAt", st != null ? DATE_FMT.format(st) : "");
            res.getWriter().write(r.toString());
        } catch (Exception e) {
            e.printStackTrace(); res.getWriter().write("{\"error\":\"점수 조회 중 오류가 발생했습니다.\"}");
        } finally { closeAll(conn, ps, rs); }
    }

    private void handleScoreTranscript(HttpServletResponse res, String loginUser, String idStr) throws IOException {
        if (isEmpty(idStr)) { res.getWriter().write("{\"error\":\"transcriptId가 필요합니다.\"}"); return; }
        int transcriptId;
        try { transcriptId = Integer.parseInt(idStr); }
        catch (NumberFormatException e) { res.getWriter().write("{\"error\":\"잘못된 transcriptId\"}"); return; }
        Connection conn = null; PreparedStatement ps = null; ResultSet rs = null;
        try {
            conn = dataSource.getConnection();
            ps = conn.prepareStatement(
                "SELECT t.original_text, t.stmt_type, t.stmt_name, t.case_id " +
                "FROM transcripts t JOIN cases c ON t.case_id = c.case_id " +
                "WHERE t.transcript_id = ? " +
                "AND c.dept_id = (SELECT me.dept_id FROM users me WHERE me.user_id = ?)");
            ps.setInt(1, transcriptId); ps.setString(2, loginUser); rs = ps.executeQuery();
            if (!rs.next()) { writeResult(res, false, "조서를 찾을 수 없거나 접근 권한이 없습니다."); return; }
            String originalText = rs.getString("original_text");
            String stmtType     = nvl(rs.getString("stmt_type"), "진술자");
            String stmtName     = nvl(rs.getString("stmt_name"), "미입력");
            String caseId       = nvl(rs.getString("case_id"),   "미입력");
            rs.close(); ps.close(); ps = null; rs = null;

            if (originalText == null || originalText.trim().isEmpty()) {
                writeResult(res, false, "분석할 진술 본문이 없습니다."); return;
            }

            JSONObject body = new JSONObject();
            body.put("text",     originalText);
            body.put("stmtType", stmtType);
            body.put("stmtName", stmtName);
            body.put("caseNum",  caseId);

            JSONObject scoreResult = callScoreReliability(body);
            if (scoreResult == null) { writeResult(res, false, "신뢰도 분석 서버 호출에 실패했습니다."); return; }

            int consistency = scoreResult.optInt("consistency", 50);
            int specificity = scoreResult.optInt("specificity", 50);
            int emotion     = scoreResult.optInt("emotion",     50);
            int temporal    = scoreResult.optInt("temporal",    50);
            int total       = scoreResult.optInt("total",       (consistency + specificity + emotion + temporal) / 4);
            JSONObject reasons = scoreResult.optJSONObject("reasons");
            if (reasons == null) reasons = new JSONObject();

            ps = conn.prepareStatement(
                "INSERT INTO transcript_scores " +
                "(transcript_id, consistency_score, specificity_score, emotion_score, temporal_score, total_score, " +
                " consistency_reason, specificity_reason, emotion_reason, temporal_reason, scored_at) " +
                "VALUES (?,?,?,?,?,?,?,?,?,?,NOW()) " +
                "ON DUPLICATE KEY UPDATE " +
                "consistency_score=VALUES(consistency_score), specificity_score=VALUES(specificity_score), " +
                "emotion_score=VALUES(emotion_score), temporal_score=VALUES(temporal_score), " +
                "total_score=VALUES(total_score), consistency_reason=VALUES(consistency_reason), " +
                "specificity_reason=VALUES(specificity_reason), emotion_reason=VALUES(emotion_reason), " +
                "temporal_reason=VALUES(temporal_reason), scored_at=NOW()");
            ps.setInt(1, transcriptId);
            ps.setInt(2, consistency); ps.setInt(3, specificity);
            ps.setInt(4, emotion);     ps.setInt(5, temporal);    ps.setInt(6, total);
            ps.setString(7,  reasons.optString("consistency", ""));
            ps.setString(8,  reasons.optString("specificity", ""));
            ps.setString(9,  reasons.optString("emotion",     ""));
            ps.setString(10, reasons.optString("temporal",    ""));
            ps.executeUpdate();

            JSONObject out = new JSONObject();
            out.put("success",     true);
            out.put("total",       total);
            out.put("consistency", consistency);
            out.put("specificity", specificity);
            out.put("emotion",     emotion);
            out.put("temporal",    temporal);
            out.put("reasons",     reasons);
            res.getWriter().write(out.toString());
        } catch (Exception e) {
            e.printStackTrace(); writeResult(res, false, "신뢰도 분석 중 오류가 발생했습니다.");
        } finally { closeAll(conn, ps, rs); }
    }

    private JSONObject callScoreReliability(JSONObject body) {
        HttpURLConnection hc = null;
        try {
            String baseUrl = polMateServBaseUrl;
            while (baseUrl.endsWith("/")) baseUrl = baseUrl.substring(0, baseUrl.length() - 1);
            URL url = new URL(baseUrl + "/score/reliability");
            hc = (HttpURLConnection) url.openConnection();
            hc.setRequestMethod("POST");
            hc.setRequestProperty("Content-Type", "application/json; charset=UTF-8");
            hc.setDoOutput(true); hc.setConnectTimeout(15000); hc.setReadTimeout(120000);
            byte[] bytes = body.toString().getBytes(StandardCharsets.UTF_8);
            try (OutputStream os = hc.getOutputStream()) { os.write(bytes); }
            int code = hc.getResponseCode();
            InputStream inStream = (code >= 200 && code < 300) ? hc.getInputStream() : hc.getErrorStream();
            if (inStream == null) return null;
            StringBuilder sb = new StringBuilder();
            try (BufferedReader br = new BufferedReader(new InputStreamReader(inStream, StandardCharsets.UTF_8))) {
                String line; while ((line = br.readLine()) != null) sb.append(line);
            }
            JSONObject j = new JSONObject(sb.toString());
            return j.optBoolean("success", false) ? j : null;
        } catch (Exception e) {
            e.printStackTrace(); return null;
        } finally { if (hc != null) hc.disconnect(); }
    }

    private String callPolMateSummarize(JSONObject body) {
        HttpURLConnection hc = null;
        try {
            String baseUrl = polMateServBaseUrl;
            while (baseUrl.endsWith("/")) baseUrl = baseUrl.substring(0, baseUrl.length() - 1);
            URL url = new URL(baseUrl + "/summarize");
            hc = (HttpURLConnection) url.openConnection();
            hc.setRequestMethod("POST");
            hc.setRequestProperty("Content-Type", "application/json; charset=UTF-8");
            hc.setDoOutput(true); hc.setConnectTimeout(15000); hc.setReadTimeout(120000);
            byte[] bytes = body.toString().getBytes(StandardCharsets.UTF_8);
            try (OutputStream os = hc.getOutputStream()) { os.write(bytes); }
            int code = hc.getResponseCode();
            InputStream inStream = (code >= 200 && code < 300) ? hc.getInputStream() : hc.getErrorStream();
            if (inStream == null) return null;
            StringBuilder sb = new StringBuilder();
            try (BufferedReader br = new BufferedReader(new InputStreamReader(inStream, StandardCharsets.UTF_8))) {
                String line; while ((line = br.readLine()) != null) sb.append(line);
            }
            JSONObject j = new JSONObject(sb.toString());
            if (!j.optBoolean("success", false)) return null;
            String structured = j.optString("structured_summary", null);
            return (structured == null || structured.isEmpty()) ? null : structured;
        } catch (Exception e) {
            e.printStackTrace(); return null;
        } finally {
            if (hc != null) hc.disconnect();
        }
    }

    private void writeResult(HttpServletResponse res, boolean ok, String msg) throws IOException {
        JSONObject j = new JSONObject(); j.put("success", ok); j.put("message", msg);
        res.getWriter().write(j.toString());
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
