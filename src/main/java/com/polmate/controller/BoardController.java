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
@RequestMapping("/board")
public class BoardController {

    private static final SimpleDateFormat DATE_FMT = new SimpleDateFormat("yyyy.MM.dd");
    static { DATE_FMT.setTimeZone(TimeZone.getTimeZone("Asia/Seoul")); }

    @Autowired
    private DataSource dataSource;

    @GetMapping
    public void doGet(@RequestParam(defaultValue = "list") String action,
                      @RequestParam(required = false) String id,
                      @RequestParam(required = false) String category,
                      @RequestParam(required = false) String sort,
                      @RequestParam(required = false, defaultValue = "") String keyword,
                      HttpServletResponse res, HttpSession session) throws IOException {
        res.setContentType("application/json;charset=UTF-8");
        String loginUser = getLoginUser(session, res);
        if (loginUser == null) return;
        switch (action) {
            case "list":   handleList(res, loginUser, category, sort, keyword);   break;
            case "detail": handleDetail(res, loginUser, id);                      break;
            default: res.getWriter().write("{\"error\":\"알 수 없는 action\"}");
        }
    }

    @PostMapping
    public void doPost(@RequestParam(defaultValue = "") String action,
                       HttpServletRequest req, HttpServletResponse res, HttpSession session) throws IOException {
        res.setContentType("application/json;charset=UTF-8");
        String loginUser = getLoginUser(session, res);
        if (loginUser == null) return;
        switch (action) {
            case "write":         handleWrite(req, res, loginUser);         break;
            case "edit":          handleEdit(req, res, loginUser);          break;
            case "delete":        handleDelete(req, res, loginUser);        break;
            case "comment":       handleComment(req, res, loginUser);       break;
            case "deleteComment": handleDeleteComment(req, res, loginUser); break;
            case "like":          handleLike(req, res, loginUser);          break;
            default: res.getWriter().write("{\"error\":\"알 수 없는 action\"}");
        }
    }

    private void handleList(HttpServletResponse res, String loginUser, String category, String sort, String keyword) throws IOException {
        if (category == null || category.isEmpty()) category = "all";
        if (sort == null || sort.isEmpty()) sort = "latest";
        StringBuilder sql = new StringBuilder(
            "SELECT p.post_id, p.category, p.title, p.content, p.view_count, p.like_count, p.created_at, p.anonymous, " +
            "p.user_id, u.user_name, u.user_rank, " +
            "(SELECT COUNT(*) FROM board_comments bc WHERE bc.post_id = p.post_id) AS comment_count " +
            "FROM board_posts p LEFT JOIN users u ON p.user_id = u.user_id WHERE 1=1 ");
        List<Object> params = new ArrayList<>();
        if ("mine".equals(category)) { sql.append("AND p.user_id = ? "); params.add(loginUser); }
        else if (!"all".equals(category)) { sql.append("AND p.category = ? "); params.add(category); }
        if (!keyword.isEmpty()) { sql.append("AND (p.title LIKE ? OR p.content LIKE ?) "); params.add("%"+keyword+"%"); params.add("%"+keyword+"%"); }
        sql.append("popular".equals(sort) ? "ORDER BY p.like_count DESC, p.created_at DESC " : "ORDER BY p.created_at DESC ");
        Connection conn = null; PreparedStatement ps = null; ResultSet rs = null;
        try {
            conn = dataSource.getConnection();
            ps = conn.prepareStatement(sql.toString());
            for (int i = 0; i < params.size(); i++) ps.setObject(i+1, params.get(i));
            rs = ps.executeQuery();
            org.json.JSONArray arr = new org.json.JSONArray();
            while (rs.next()) {
                boolean anon = rs.getInt("anonymous") == 1;
                int postId = rs.getInt("post_id");
                org.json.JSONObject p = new org.json.JSONObject();
                p.put("id", postId); p.put("cat", rs.getString("category")); p.put("title", rs.getString("title"));
                String content = rs.getString("content");
                p.put("preview", content != null && content.length() > 80 ? content.substring(0,80)+"..." : content);
                p.put("views", rs.getInt("view_count")); p.put("likes", rs.getInt("like_count"));
                p.put("commentCount", rs.getInt("comment_count")); p.put("hot", rs.getInt("like_count") >= 20);
                p.put("anonymous", anon ? 1 : 0); p.put("userId", anon ? "" : rs.getString("user_id"));
                p.put("author", anon ? "익명" : rs.getString("user_name")); p.put("authorRank", anon ? "" : rs.getString("user_rank"));
                p.put("isMine", loginUser.equals(rs.getString("user_id")));
                Timestamp ts = rs.getTimestamp("created_at"); p.put("date", ts != null ? DATE_FMT.format(ts) : "");
                p.put("tags", getTagsForPost(conn, postId));
                arr.put(p);
            }
            res.getWriter().write(arr.toString());
        } catch (Exception e) { e.printStackTrace(); res.getWriter().write("{\"error\":\"목록 조회 중 오류\"}");
        } finally { closeAll(conn, ps, rs); }
    }

    private void handleDetail(HttpServletResponse res, String loginUser, String idStr) throws IOException {
        if (idStr == null || idStr.isEmpty()) { res.getWriter().write("{\"error\":\"id가 필요합니다.\"}"); return; }
        int postId;
        try { postId = Integer.parseInt(idStr); } catch (NumberFormatException e) { res.getWriter().write("{\"error\":\"잘못된 id\"}"); return; }
        Connection conn = null; PreparedStatement ps = null; ResultSet rs = null;
        try {
            conn = dataSource.getConnection();
            ps = conn.prepareStatement("UPDATE board_posts SET view_count = view_count + 1 WHERE post_id = ?");
            ps.setInt(1, postId); ps.executeUpdate(); ps.close();
            ps = conn.prepareStatement(
                "SELECT p.post_id, p.category, p.title, p.content, p.view_count, p.like_count, p.created_at, p.anonymous, " +
                "p.user_id, u.user_name, u.user_rank, u.user_org FROM board_posts p LEFT JOIN users u ON p.user_id = u.user_id WHERE p.post_id = ?");
            ps.setInt(1, postId); rs = ps.executeQuery();
            if (!rs.next()) { res.getWriter().write("{\"error\":\"게시글을 찾을 수 없습니다.\"}"); return; }
            boolean anon = rs.getInt("anonymous") == 1;
            org.json.JSONObject p = new org.json.JSONObject();
            p.put("id", rs.getInt("post_id")); p.put("cat", rs.getString("category")); p.put("title", rs.getString("title"));
            p.put("content", rs.getString("content")); p.put("views", rs.getInt("view_count")); p.put("likes", rs.getInt("like_count"));
            p.put("anonymous", anon ? 1 : 0); p.put("userId", anon ? "" : rs.getString("user_id"));
            p.put("author", anon ? "익명" : rs.getString("user_name")); p.put("authorRank", anon ? "" : rs.getString("user_rank"));
            p.put("authorOrg", anon ? "" : rs.getString("user_org")); p.put("isMine", loginUser.equals(rs.getString("user_id")));
            Timestamp ts = rs.getTimestamp("created_at"); p.put("date", ts != null ? DATE_FMT.format(ts) : "");
            rs.close(); ps.close();
            ps = conn.prepareStatement("SELECT COUNT(*) FROM board_likes WHERE user_id=? AND target_type='post' AND target_id=?");
            ps.setString(1, loginUser); ps.setInt(2, postId); rs = ps.executeQuery(); rs.next(); p.put("liked", rs.getInt(1) > 0); rs.close(); ps.close();
            p.put("tags", getTagsForPost(conn, postId)); p.put("links", getLinksForPost(conn, postId));
            ps = conn.prepareStatement(
                "SELECT c.comment_id, c.content, c.created_at, c.user_id, u.user_name, u.user_rank, " +
                "(SELECT COUNT(*) FROM board_likes bl WHERE bl.target_type='comment' AND bl.target_id=c.comment_id) AS like_count " +
                "FROM board_comments c LEFT JOIN users u ON c.user_id = u.user_id WHERE c.post_id = ? ORDER BY c.created_at ASC");
            ps.setInt(1, postId); rs = ps.executeQuery();
            org.json.JSONArray comments = new org.json.JSONArray();
            while (rs.next()) {
                org.json.JSONObject c = new org.json.JSONObject();
                c.put("id", rs.getInt("comment_id")); c.put("author", rs.getString("user_name")); c.put("rank", rs.getString("user_rank"));
                c.put("userId", rs.getString("user_id")); c.put("text", rs.getString("content")); c.put("likes", rs.getInt("like_count"));
                c.put("isMine", loginUser.equals(rs.getString("user_id")));
                Timestamp cts = rs.getTimestamp("created_at"); c.put("time", cts != null ? relativeTime(cts) : "");
                comments.put(c);
            }
            p.put("comments", comments);
            res.getWriter().write(p.toString());
        } catch (Exception e) { e.printStackTrace(); res.getWriter().write("{\"error\":\"상세 조회 중 오류\"}");
        } finally { closeAll(conn, ps, rs); }
    }

    private void handleWrite(jakarta.servlet.http.HttpServletRequest req, HttpServletResponse res, String loginUser) throws IOException {
        String category = req.getParameter("category"); String title = req.getParameter("title");
        String content  = req.getParameter("content");  String tagsRaw = req.getParameter("tags");
        int anonymous = "1".equals(req.getParameter("anonymous")) ? 1 : 0;
        if (category == null || category.isEmpty() || title == null || title.trim().isEmpty() || content == null || content.trim().isEmpty()) {
            res.getWriter().write("{\"success\":false,\"error\":\"필수 항목을 모두 입력하세요.\"}"); return;
        }
        Connection conn = null; PreparedStatement ps = null; ResultSet rs = null;
        try {
            conn = dataSource.getConnection(); conn.setAutoCommit(false);
            ps = conn.prepareStatement("INSERT INTO board_posts (user_id, category, title, content, anonymous) VALUES (?,?,?,?,?)", Statement.RETURN_GENERATED_KEYS);
            ps.setString(1, loginUser); ps.setString(2, category); ps.setString(3, title.trim()); ps.setString(4, content.trim()); ps.setInt(5, anonymous);
            ps.executeUpdate(); rs = ps.getGeneratedKeys(); rs.next(); int newPostId = rs.getInt(1); rs.close(); ps.close();
            if (tagsRaw != null && !tagsRaw.trim().isEmpty()) {
                for (String tag : tagsRaw.split(",")) {
                    String t = tag.trim(); if (t.isEmpty()) continue;
                    ps = conn.prepareStatement("INSERT INTO board_tags (post_id, tag_name) VALUES (?,?)");
                    ps.setInt(1, newPostId); ps.setString(2, t); ps.executeUpdate(); ps.close();
                }
            }
            if ("gear".equals(category)) {
                String[] linkNames = req.getParameterValues("linkNames"); String[] linkUrls = req.getParameterValues("linkUrls");
                if (linkNames != null && linkUrls != null) {
                    int max = Math.min(linkNames.length, Math.min(linkUrls.length, 3));
                    for (int i = 0; i < max; i++) {
                        String lname = linkNames[i].trim(); String lurl = linkUrls[i].trim();
                        if (!lname.isEmpty() && !lurl.isEmpty()) {
                            ps = conn.prepareStatement("INSERT INTO board_links (post_id, link_name, link_url) VALUES (?,?,?)");
                            ps.setInt(1, newPostId); ps.setString(2, lname); ps.setString(3, lurl); ps.executeUpdate(); ps.close();
                        }
                    }
                }
            }
            conn.commit(); res.getWriter().write("{\"success\":true,\"postId\":" + newPostId + "}");
        } catch (Exception e) {
            e.printStackTrace(); try { if (conn != null) conn.rollback(); } catch (Exception ignored) {}
            res.getWriter().write("{\"success\":false,\"error\":\"게시글 등록 중 오류\"}");
        } finally { try { if (conn != null) conn.setAutoCommit(true); } catch (Exception ignored) {} closeAll(conn, ps, rs); }
    }

    private void handleEdit(jakarta.servlet.http.HttpServletRequest req, HttpServletResponse res, String loginUser) throws IOException {
        String idStr = req.getParameter("postId"); String title = req.getParameter("title"); String content = req.getParameter("content");
        String tagsRaw = req.getParameter("tags"); int anonymous = "1".equals(req.getParameter("anonymous")) ? 1 : 0;
        if (idStr == null || title == null || title.trim().isEmpty() || content == null || content.trim().isEmpty()) {
            res.getWriter().write("{\"success\":false,\"error\":\"필수 항목을 모두 입력하세요.\"}"); return;
        }
        int postId; try { postId = Integer.parseInt(idStr); } catch (NumberFormatException e) { res.getWriter().write("{\"success\":false}"); return; }
        Connection conn = null; PreparedStatement ps = null; ResultSet rs = null;
        try {
            conn = dataSource.getConnection(); conn.setAutoCommit(false);
            ps = conn.prepareStatement("SELECT user_id FROM board_posts WHERE post_id=?"); ps.setInt(1, postId); rs = ps.executeQuery();
            if (!rs.next() || !loginUser.equals(rs.getString("user_id"))) { res.getWriter().write("{\"success\":false,\"error\":\"수정 권한이 없습니다.\"}"); conn.rollback(); return; }
            rs.close(); ps.close();
            ps = conn.prepareStatement("UPDATE board_posts SET title=?, content=?, anonymous=?, updated_at=NOW() WHERE post_id=?");
            ps.setString(1, title.trim()); ps.setString(2, content.trim()); ps.setInt(3, anonymous); ps.setInt(4, postId); ps.executeUpdate(); ps.close();
            ps = conn.prepareStatement("DELETE FROM board_tags WHERE post_id=?"); ps.setInt(1, postId); ps.executeUpdate(); ps.close();
            if (tagsRaw != null && !tagsRaw.trim().isEmpty()) {
                for (String tag : tagsRaw.split(",")) {
                    String t = tag.trim(); if (t.isEmpty()) continue;
                    ps = conn.prepareStatement("INSERT INTO board_tags (post_id, tag_name) VALUES (?,?)");
                    ps.setInt(1, postId); ps.setString(2, t); ps.executeUpdate(); ps.close();
                }
            }
            ps = conn.prepareStatement("DELETE FROM board_links WHERE post_id=?"); ps.setInt(1, postId); ps.executeUpdate(); ps.close();
            String[] lns = req.getParameterValues("linkNames"); String[] lus = req.getParameterValues("linkUrls");
            if (lns != null && lus != null) {
                int max = Math.min(lns.length, Math.min(lus.length, 3));
                for (int i = 0; i < max; i++) {
                    String ln = lns[i].trim(); String lu = lus[i].trim();
                    if (!ln.isEmpty() && !lu.isEmpty()) {
                        ps = conn.prepareStatement("INSERT INTO board_links (post_id, link_name, link_url) VALUES (?,?,?)");
                        ps.setInt(1, postId); ps.setString(2, ln); ps.setString(3, lu); ps.executeUpdate(); ps.close();
                    }
                }
            }
            conn.commit(); res.getWriter().write("{\"success\":true}");
        } catch (Exception e) {
            e.printStackTrace(); try { if (conn != null) conn.rollback(); } catch (Exception ignored) {}
            res.getWriter().write("{\"success\":false,\"error\":\"수정 중 오류\"}");
        } finally { try { if (conn != null) conn.setAutoCommit(true); } catch (Exception ignored) {} closeAll(conn, ps, rs); }
    }

    private void handleDelete(jakarta.servlet.http.HttpServletRequest req, HttpServletResponse res, String loginUser) throws IOException {
        String idStr = req.getParameter("postId");
        if (idStr == null) { res.getWriter().write("{\"success\":false,\"error\":\"postId 필요\"}"); return; }
        int postId; try { postId = Integer.parseInt(idStr); } catch (NumberFormatException e) { res.getWriter().write("{\"success\":false}"); return; }
        Connection conn = null; PreparedStatement ps = null; ResultSet rs = null;
        try {
            conn = dataSource.getConnection();
            ps = conn.prepareStatement("SELECT user_id FROM board_posts WHERE post_id=?"); ps.setInt(1, postId); rs = ps.executeQuery();
            if (!rs.next() || !loginUser.equals(rs.getString("user_id"))) { res.getWriter().write("{\"success\":false,\"error\":\"삭제 권한이 없습니다.\"}"); return; }
            rs.close(); ps.close();
            ps = conn.prepareStatement("DELETE FROM board_posts WHERE post_id=?"); ps.setInt(1, postId); ps.executeUpdate();
            res.getWriter().write("{\"success\":true}");
        } catch (Exception e) { e.printStackTrace(); res.getWriter().write("{\"success\":false,\"error\":\"삭제 중 오류\"}");
        } finally { closeAll(conn, ps, rs); }
    }

    private void handleComment(jakarta.servlet.http.HttpServletRequest req, HttpServletResponse res, String loginUser) throws IOException {
        String idStr = req.getParameter("postId"); String content = req.getParameter("content");
        if (idStr == null || content == null || content.trim().isEmpty()) { res.getWriter().write("{\"success\":false,\"error\":\"내용을 입력하세요.\"}"); return; }
        int postId; try { postId = Integer.parseInt(idStr); } catch (NumberFormatException e) { res.getWriter().write("{\"success\":false}"); return; }
        try (Connection conn = dataSource.getConnection();
             PreparedStatement ps = conn.prepareStatement("INSERT INTO board_comments (post_id, user_id, content) VALUES (?,?,?)")) {
            ps.setInt(1, postId); ps.setString(2, loginUser); ps.setString(3, content.trim()); ps.executeUpdate();
            res.getWriter().write("{\"success\":true}");
        } catch (Exception e) { e.printStackTrace(); res.getWriter().write("{\"success\":false,\"error\":\"댓글 등록 중 오류\"}"); }
    }

    private void handleDeleteComment(jakarta.servlet.http.HttpServletRequest req, HttpServletResponse res, String loginUser) throws IOException {
        String idStr = req.getParameter("commentId");
        if (idStr == null) { res.getWriter().write("{\"success\":false}"); return; }
        int commentId; try { commentId = Integer.parseInt(idStr); } catch (NumberFormatException e) { res.getWriter().write("{\"success\":false}"); return; }
        Connection conn = null; PreparedStatement ps = null; ResultSet rs = null;
        try {
            conn = dataSource.getConnection(); conn.setAutoCommit(false);
            ps = conn.prepareStatement("SELECT user_id FROM board_comments WHERE comment_id=?"); ps.setInt(1, commentId); rs = ps.executeQuery();
            if (!rs.next() || !loginUser.equals(rs.getString("user_id"))) { res.getWriter().write("{\"success\":false,\"error\":\"삭제 권한이 없습니다.\"}"); conn.rollback(); return; }
            rs.close(); ps.close();
            ps = conn.prepareStatement("DELETE FROM board_likes WHERE target_type='comment' AND target_id=?"); ps.setInt(1, commentId); ps.executeUpdate(); ps.close();
            ps = conn.prepareStatement("DELETE FROM board_comments WHERE comment_id=?"); ps.setInt(1, commentId); ps.executeUpdate();
            conn.commit(); res.getWriter().write("{\"success\":true}");
        } catch (Exception e) {
            e.printStackTrace(); try { if (conn != null) conn.rollback(); } catch (Exception ignored) {}
            res.getWriter().write("{\"success\":false,\"error\":\"댓글 삭제 중 오류\"}");
        } finally { try { if (conn != null) conn.setAutoCommit(true); } catch (Exception ignored) {} closeAll(conn, ps, rs); }
    }

    private void handleLike(jakarta.servlet.http.HttpServletRequest req, HttpServletResponse res, String loginUser) throws IOException {
        String targetType = req.getParameter("targetType"); String targetIdStr = req.getParameter("targetId");
        if (targetType == null || targetIdStr == null) { res.getWriter().write("{\"success\":false}"); return; }
        if (!"post".equals(targetType) && !"comment".equals(targetType)) { res.getWriter().write("{\"success\":false}"); return; }
        int targetId; try { targetId = Integer.parseInt(targetIdStr); } catch (NumberFormatException e) { res.getWriter().write("{\"success\":false}"); return; }
        Connection conn = null; PreparedStatement ps = null; ResultSet rs = null;
        try {
            conn = dataSource.getConnection(); conn.setAutoCommit(false);
            ps = conn.prepareStatement("SELECT COUNT(*) FROM board_likes WHERE user_id=? AND target_type=? AND target_id=?");
            ps.setString(1, loginUser); ps.setString(2, targetType); ps.setInt(3, targetId); rs = ps.executeQuery(); rs.next();
            boolean alreadyLiked = rs.getInt(1) > 0; rs.close(); ps.close();
            if (alreadyLiked) {
                ps = conn.prepareStatement("DELETE FROM board_likes WHERE user_id=? AND target_type=? AND target_id=?");
                ps.setString(1, loginUser); ps.setString(2, targetType); ps.setInt(3, targetId); ps.executeUpdate(); ps.close();
                if ("post".equals(targetType)) {
                    ps = conn.prepareStatement("UPDATE board_posts SET like_count = GREATEST(like_count-1, 0) WHERE post_id=?");
                    ps.setInt(1, targetId); ps.executeUpdate(); ps.close();
                }
            } else {
                ps = conn.prepareStatement("INSERT INTO board_likes (user_id, target_type, target_id) VALUES (?,?,?)");
                ps.setString(1, loginUser); ps.setString(2, targetType); ps.setInt(3, targetId); ps.executeUpdate(); ps.close();
                if ("post".equals(targetType)) {
                    ps = conn.prepareStatement("UPDATE board_posts SET like_count = like_count+1 WHERE post_id=?");
                    ps.setInt(1, targetId); ps.executeUpdate(); ps.close();
                }
            }
            conn.commit();
            int currentLikes = 0;
            if ("post".equals(targetType)) {
                ps = conn.prepareStatement("SELECT like_count FROM board_posts WHERE post_id=?"); ps.setInt(1, targetId); rs = ps.executeQuery(); if (rs.next()) currentLikes = rs.getInt(1);
            } else {
                ps = conn.prepareStatement("SELECT COUNT(*) FROM board_likes WHERE target_type='comment' AND target_id=?"); ps.setInt(1, targetId); rs = ps.executeQuery(); if (rs.next()) currentLikes = rs.getInt(1);
            }
            res.getWriter().write("{\"success\":true,\"liked\":" + !alreadyLiked + ",\"likes\":" + currentLikes + "}");
        } catch (Exception e) {
            e.printStackTrace(); try { if (conn != null) conn.rollback(); } catch (Exception ignored) {}
            res.getWriter().write("{\"success\":false,\"error\":\"추천 처리 중 오류\"}");
        } finally { try { if (conn != null) conn.setAutoCommit(true); } catch (Exception ignored) {} closeAll(conn, ps, rs); }
    }

    private org.json.JSONArray getTagsForPost(Connection conn, int postId) throws SQLException {
        org.json.JSONArray tags = new org.json.JSONArray();
        PreparedStatement ps = conn.prepareStatement("SELECT tag_name FROM board_tags WHERE post_id=? ORDER BY tag_id");
        ps.setInt(1, postId); ResultSet r = ps.executeQuery();
        while (r.next()) tags.put(r.getString("tag_name"));
        r.close(); ps.close(); return tags;
    }

    private org.json.JSONArray getLinksForPost(Connection conn, int postId) throws SQLException {
        org.json.JSONArray links = new org.json.JSONArray();
        PreparedStatement ps = conn.prepareStatement("SELECT link_name, link_url FROM board_links WHERE post_id=? ORDER BY link_id");
        ps.setInt(1, postId); ResultSet r = ps.executeQuery();
        while (r.next()) { org.json.JSONObject lk = new org.json.JSONObject(); lk.put("name", r.getString("link_name")); lk.put("url", r.getString("link_url")); links.put(lk); }
        r.close(); ps.close(); return links;
    }

    private String relativeTime(Timestamp ts) {
        long diff = System.currentTimeMillis() - ts.getTime(); long min = diff / 60000;
        if (min < 1) return "방금 전"; if (min < 60) return min + "분 전";
        long hours = min / 60; if (hours < 24) return hours + "시간 전";
        return (hours / 24) + "일 전";
    }

    private String getLoginUser(HttpSession session, HttpServletResponse res) throws IOException {
        String u = (session != null) ? (String) session.getAttribute("loginUser") : null;
        if (u == null) res.getWriter().write("{\"error\":\"로그인이 필요합니다.\"}");
        return u;
    }

    private void closeAll(Connection c, PreparedStatement p, ResultSet r) {
        try { if (r != null) r.close(); } catch (Exception ignored) {}
        try { if (p != null) p.close(); } catch (Exception ignored) {}
        try { if (c != null) c.close(); } catch (Exception ignored) {}
    }
}
