package com.polmate.controller;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.*;

import javax.sql.DataSource;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import jakarta.servlet.http.HttpSession;
import java.io.IOException;
import java.sql.*;
import java.text.SimpleDateFormat;
import java.util.*;

@RestController
@RequestMapping("/notifApi")
public class NotificationController {

    private static final SimpleDateFormat DATE_FMT = new SimpleDateFormat("yyyy.MM.dd HH:mm");
    static { DATE_FMT.setTimeZone(TimeZone.getTimeZone("Asia/Seoul")); }
    private static final int PW_WARN_DAYS = 90;

    @Autowired
    private DataSource dataSource;

    @GetMapping
    public void doGet(@RequestParam(defaultValue = "list") String action,
                      HttpServletRequest req, HttpServletResponse res,
                      HttpSession session) throws IOException {
        res.setContentType("application/json;charset=UTF-8");
        String loginUser = getLoginUser(session, res);
        if (loginUser == null) return;

        switch (action) {
            case "list":        handleList(req, res, loginUser);        break;
            case "unreadCount": handleUnreadCount(res, loginUser);      break;
            default:            res.getWriter().write("{\"error\":\"알 수 없는 action\"}");
        }
    }

    @PostMapping
    public void doPost(@RequestParam(defaultValue = "") String action,
                       HttpServletRequest req, HttpServletResponse res,
                       HttpSession session) throws IOException {
        res.setContentType("application/json;charset=UTF-8");
        String loginUser = getLoginUser(session, res);
        if (loginUser == null) return;

        switch (action) {
            case "markRead":    handleMarkRead(req, res, loginUser);    break;
            case "markAllRead": handleMarkAllRead(res, loginUser);      break;
            default:            res.getWriter().write("{\"error\":\"알 수 없는 action\"}");
        }
    }

    private void handleList(HttpServletRequest req, HttpServletResponse res, String loginUser) throws IOException {
        String typeFilter = nvl(req.getParameter("type"), "all");
        Connection conn = null; PreparedStatement ps = null; ResultSet rs = null;
        try {
            conn = dataSource.getConnection();
            org.json.JSONArray arr = new org.json.JSONArray();

            if ("all".equals(typeFilter) || "alert".equals(typeFilter) || "sys".equals(typeFilter)) {
                ps = conn.prepareStatement(
                    "SELECT DATEDIFF(NOW(), IFNULL(password_changed_at, created_at)) AS days_since FROM users WHERE user_id = ?");
                ps.setString(1, loginUser); rs = ps.executeQuery();
                if (rs.next()) {
                    int daysSince = rs.getInt("days_since");
                    if (daysSince >= PW_WARN_DAYS) {
                        rs.close(); ps.close();
                        ps = conn.prepareStatement(
                            "SELECT COUNT(*) AS cnt FROM notifications WHERE user_id = ? AND type = 'sys' AND tag = '보안' AND created_at >= DATE_SUB(NOW(), INTERVAL 24 HOUR)");
                        ps.setString(1, loginUser); rs = ps.executeQuery();
                        int recentPwWarn = rs.next() ? rs.getInt("cnt") : 0;
                        rs.close(); ps.close();
                        if (recentPwWarn == 0) {
                            ps = conn.prepareStatement(
                                "INSERT INTO notifications (user_id, type, tag, title, description, link, is_unread, is_critical) VALUES (?, 'sys', '보안', ?, ?, 'mypage', 1, ?)");
                            ps.setString(1, loginUser);
                            ps.setString(2, "비밀번호 변경 권고");
                            ps.setString(3, "마지막 비밀번호 변경 후 " + daysSince + "일이 경과했습니다. 보안을 위해 비밀번호를 변경해 주세요.");
                            ps.setBoolean(4, daysSince >= 180);
                            ps.executeUpdate(); ps.close();
                        }
                    } else { rs.close(); ps.close(); }
                } else { rs.close(); ps.close(); }
                ps = null; rs = null;
            }

            StringBuilder sql = new StringBuilder(
                "SELECT notif_id, type, tag, title, description, link, is_unread, is_critical, created_at " +
                "FROM notifications WHERE user_id = ? ");
            List<Object> params = new ArrayList<>(); params.add(loginUser);
            if ("alert".equals(typeFilter)) sql.append("AND (type = 'sys' OR (type = 'case' AND is_critical = 1)) ");
            else if ("case".equals(typeFilter)) sql.append("AND type = 'case' ");
            else if ("sys".equals(typeFilter)) sql.append("AND type = 'sys' ");
            sql.append("ORDER BY created_at DESC LIMIT 100");

            ps = conn.prepareStatement(sql.toString());
            for (int i = 0; i < params.size(); i++) ps.setObject(i + 1, params.get(i));
            rs = ps.executeQuery();
            while (rs.next()) {
                org.json.JSONObject n = new org.json.JSONObject();
                n.put("notifId",     rs.getInt("notif_id"));
                n.put("type",        nvl(rs.getString("type"),        "sys"));
                n.put("tag",         nvl(rs.getString("tag"),         ""));
                n.put("title",       nvl(rs.getString("title"),       ""));
                n.put("description", nvl(rs.getString("description"), ""));
                n.put("link",        nvl(rs.getString("link"),        ""));
                n.put("isUnread",    rs.getBoolean("is_unread"));
                n.put("isCritical",  rs.getBoolean("is_critical"));
                Timestamp ts = rs.getTimestamp("created_at");
                n.put("timeLabel", ts != null ? relativeTime(ts) : "");
                arr.put(n);
            }
            res.getWriter().write(arr.toString());
        } catch (Exception e) {
            e.printStackTrace();
            res.getWriter().write("{\"error\":\"알림 목록 조회 중 오류가 발생했습니다.\"}");
        } finally {
            closeAll(conn, ps, rs);
        }
    }

    private void handleUnreadCount(HttpServletResponse res, String loginUser) throws IOException {
        if (isDoNotDisturb(loginUser)) {
            res.getWriter().write("{\"count\":0}"); return;
        }
        Connection conn = null; PreparedStatement ps = null; ResultSet rs = null;
        try {
            conn = dataSource.getConnection();
            ps = conn.prepareStatement("SELECT COUNT(*) AS cnt FROM notifications WHERE user_id = ? AND is_unread = 1");
            ps.setString(1, loginUser); rs = ps.executeQuery();
            int cnt = rs.next() ? rs.getInt("cnt") : 0;
            rs.close(); ps.close();
            ps = conn.prepareStatement("SELECT DATEDIFF(NOW(), IFNULL(password_changed_at, created_at)) AS days_since FROM users WHERE user_id = ?");
            ps.setString(1, loginUser); rs = ps.executeQuery();
            if (rs.next() && rs.getInt("days_since") >= PW_WARN_DAYS) {
                rs.close(); ps.close();
                ps = conn.prepareStatement("SELECT COUNT(*) AS cnt FROM notifications WHERE user_id = ? AND type = 'sys' AND tag = '보안' AND created_at >= DATE_SUB(NOW(), INTERVAL 24 HOUR)");
                ps.setString(1, loginUser); rs = ps.executeQuery();
                if (rs.next() && rs.getInt("cnt") == 0) cnt++;
            }
            res.getWriter().write("{\"count\":" + cnt + "}");
        } catch (Exception e) {
            e.printStackTrace();
            res.getWriter().write("{\"error\":\"미읽음 수 조회 중 오류\"}");
        } finally { closeAll(conn, ps, rs); }
    }

    private void handleMarkRead(HttpServletRequest req, HttpServletResponse res, String loginUser) throws IOException {
        String idStr = nvl(req.getParameter("notifId"), "");
        if (idStr.isEmpty()) { res.getWriter().write("{\"success\":false,\"message\":\"notifId가 필요합니다.\"}"); return; }
        int notifId;
        try { notifId = Integer.parseInt(idStr); } catch (NumberFormatException e) { res.getWriter().write("{\"success\":false}"); return; }
        if (notifId == -1) { res.getWriter().write("{\"success\":true}"); return; }
        try (Connection conn = dataSource.getConnection();
             PreparedStatement ps = conn.prepareStatement("UPDATE notifications SET is_unread = 0 WHERE notif_id = ? AND user_id = ?")) {
            ps.setInt(1, notifId); ps.setString(2, loginUser); ps.executeUpdate();
            res.getWriter().write("{\"success\":true,\"message\":\"읽음 처리됐습니다.\"}");
        } catch (Exception e) {
            e.printStackTrace();
            res.getWriter().write("{\"success\":false}");
        }
    }

    private void handleMarkAllRead(HttpServletResponse res, String loginUser) throws IOException {
        try (Connection conn = dataSource.getConnection();
             PreparedStatement ps = conn.prepareStatement("UPDATE notifications SET is_unread = 0 WHERE user_id = ? AND is_unread = 1")) {
            ps.setString(1, loginUser); ps.executeUpdate();
            res.getWriter().write("{\"success\":true,\"message\":\"모두 읽음 처리됐습니다.\"}");
        } catch (Exception e) {
            e.printStackTrace();
            res.getWriter().write("{\"success\":false}");
        }
    }

    private boolean isDoNotDisturb(String userId) {
        try (Connection conn = dataSource.getConnection();
             PreparedStatement ps = conn.prepareStatement("SELECT night_mode FROM users WHERE user_id = ?")) {
            ps.setString(1, userId);
            ResultSet rs = ps.executeQuery();
            return rs.next() && rs.getInt("night_mode") == 1;
        } catch (Exception e) { return false; }
    }

    private String getLoginUser(HttpSession session, HttpServletResponse res) throws IOException {
        String u = (session != null) ? (String) session.getAttribute("loginUser") : null;
        if (u == null) res.getWriter().write("{\"error\":\"로그인이 필요합니다.\"}");
        return u;
    }

    private String relativeTime(Timestamp ts) {
        long diff = System.currentTimeMillis() - ts.getTime();
        long min = diff / 60000;
        if (min < 1) return "방금 전";
        if (min < 60) return min + "분 전";
        long hour = min / 60;
        if (hour < 24) return hour + "시간 전";
        long day = hour / 24;
        if (day < 7) return day + "일 전";
        SimpleDateFormat sdf = new SimpleDateFormat("MM.dd");
        sdf.setTimeZone(TimeZone.getTimeZone("Asia/Seoul"));
        return sdf.format(ts);
    }

    private String nvl(String s, String def) { return (s == null || s.trim().isEmpty()) ? def : s.trim(); }
    private void closeAll(Connection c, PreparedStatement p, ResultSet r) {
        try { if (r != null) r.close(); } catch (Exception ignored) {}
        try { if (p != null) p.close(); } catch (Exception ignored) {}
        try { if (c != null) c.close(); } catch (Exception ignored) {}
    }
}
