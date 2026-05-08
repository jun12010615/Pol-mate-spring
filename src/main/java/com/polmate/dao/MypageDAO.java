package com.polmate.dao;

import com.polmate.dto.MypageStatsDTO;
import com.polmate.dto.TranscriptDTO;
import com.polmate.dto.UserDTO;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Component;

import javax.sql.DataSource;
import java.sql.*;
import java.util.*;

@Component
public class MypageDAO {

    @Autowired
    private DataSource dataSource;

    public UserDTO getUserById(String userId) {
        UserDTO dto = new UserDTO();
        Connection conn = null; PreparedStatement ps = null; ResultSet rs = null;
        try {
            conn = dataSource.getConnection();
            ps = conn.prepareStatement(
                "SELECT u.user_id, u.user_name, u.user_phone, u.user_org, u.user_rank, " +
                "       d.dept_name AS user_dept, u.badge_num, u.created_at, u.dept_id " +
                "FROM users u LEFT JOIN departments d ON u.dept_id = d.dept_id " +
                "WHERE u.user_id = ?");
            ps.setString(1, userId); rs = ps.executeQuery();
            if (rs.next()) {
                dto.setUserId(rs.getString("user_id"));
                dto.setUserName(rs.getString("user_name"));
                dto.setUserPhone(rs.getString("user_phone"));
                dto.setUserOrg(rs.getString("user_org"));
                dto.setUserRank(rs.getString("user_rank"));
                dto.setUserDept(rs.getString("user_dept"));
                dto.setBadgeNum(rs.getString("badge_num"));
                dto.setCreatedAt(rs.getTimestamp("created_at"));
                int deptId = rs.getInt("dept_id");
                dto.setDeptId(rs.wasNull() ? null : deptId);
                return dto;
            }
        } catch (Exception e) { e.printStackTrace(); }
        finally { closeAll(conn, ps, rs); }
        return dto;
    }

    public boolean updateProfile(UserDTO dto) {
        Connection conn = null; PreparedStatement ps = null;
        try {
            conn = dataSource.getConnection();
            ps = conn.prepareStatement(
                "UPDATE users SET user_name=?, user_rank=?, user_org=?, user_phone=?, dept_id=? WHERE user_id=?");
            ps.setString(1, dto.getUserName()); ps.setString(2, dto.getUserRank());
            ps.setString(3, dto.getUserOrg());  ps.setString(4, dto.getUserPhone());
            if (dto.getDeptId() != null && dto.getDeptId() > 0) ps.setInt(5, dto.getDeptId());
            else ps.setNull(5, Types.INTEGER);
            ps.setString(6, dto.getUserId());
            return ps.executeUpdate() > 0;
        } catch (Exception e) { e.printStackTrace(); }
        finally { closeAll(conn, ps, null); }
        return false;
    }

    public boolean checkPassword(String userId, String plainPw) {
        Connection conn = null; PreparedStatement ps = null; ResultSet rs = null;
        try {
            conn = dataSource.getConnection();
            ps = conn.prepareStatement("SELECT user_pw FROM users WHERE user_id = ?");
            ps.setString(1, userId); rs = ps.executeQuery();
            if (rs.next()) return rs.getString("user_pw").equals(plainPw);
        } catch (Exception e) { e.printStackTrace(); }
        finally { closeAll(conn, ps, rs); }
        return false;
    }

    public boolean changePassword(String userId, String newPw) {
        Connection conn = null; PreparedStatement ps = null;
        try {
            conn = dataSource.getConnection();
            ps = conn.prepareStatement(
                "UPDATE users SET user_pw=?, password_changed_at=NOW() WHERE user_id=?");
            ps.setString(1, newPw); ps.setString(2, userId);
            return ps.executeUpdate() > 0;
        } catch (Exception e) { e.printStackTrace(); }
        finally { closeAll(conn, ps, null); }
        return false;
    }

    public List<TranscriptDTO> getTranscriptHistory(String userId, int limit) {
        List<TranscriptDTO> list = new ArrayList<>();
        Connection conn = null; PreparedStatement ps = null; ResultSet rs = null;
        try {
            conn = dataSource.getConnection();
            ps = conn.prepareStatement(
                "SELECT t.transcript_id, t.case_id, t.user_id, " +
                "       t.stmt_name, t.stmt_type, t.has_contradiction, t.created_at, " +
                "       c.case_name, c.status AS case_status " +
                "FROM transcripts t JOIN cases c ON t.case_id = c.case_id " +
                "WHERE t.user_id = ? " +
                "  AND ((SELECT me.dept_id FROM users me WHERE me.user_id = ?) IS NULL " +
                "    OR c.dept_id = (SELECT me.dept_id FROM users me WHERE me.user_id = ?)) " +
                "ORDER BY t.created_at DESC LIMIT ?");
            ps.setString(1, userId); ps.setString(2, userId);
            ps.setString(3, userId); ps.setInt(4, limit);
            rs = ps.executeQuery();
            while (rs.next()) {
                TranscriptDTO dto = new TranscriptDTO();
                dto.setTranscriptId(rs.getInt("transcript_id"));
                dto.setCaseId(rs.getString("case_id")); dto.setUserId(rs.getString("user_id"));
                dto.setStmtName(rs.getString("stmt_name")); dto.setStmtType(rs.getString("stmt_type"));
                dto.setHasContradiction(rs.getInt("has_contradiction"));
                dto.setCreatedAt(rs.getTimestamp("created_at"));
                dto.setCaseName(rs.getString("case_name")); dto.setCaseStatus(rs.getString("case_status"));
                list.add(dto);
            }
        } catch (Exception e) { e.printStackTrace(); }
        finally { closeAll(conn, ps, rs); }
        return list;
    }

    public MypageStatsDTO getStats(String userId) {
        MypageStatsDTO stats = new MypageStatsDTO();
        Connection conn = null; PreparedStatement ps = null; ResultSet rs = null;
        try {
            conn = dataSource.getConnection();
            ps = conn.prepareStatement(
                "SELECT COUNT(*) AS total_transcripts, SUM(t.has_contradiction) AS contradiction_count, " +
                "  SUM(CASE WHEN c.status='완료' THEN 1 ELSE 0 END) AS completed_transcripts " +
                "FROM transcripts t JOIN cases c ON t.case_id = c.case_id " +
                "WHERE t.user_id = ? " +
                "  AND ((SELECT me.dept_id FROM users me WHERE me.user_id=?) IS NULL " +
                "    OR c.dept_id=(SELECT me.dept_id FROM users me WHERE me.user_id=?))");
            ps.setString(1, userId); ps.setString(2, userId); ps.setString(3, userId);
            rs = ps.executeQuery();
            if (rs.next()) {
                stats.setTotalTranscripts(rs.getInt("total_transcripts"));
                stats.setContradictionCount(rs.getInt("contradiction_count"));
                stats.setCompletedTranscripts(rs.getInt("completed_transcripts"));
            }
            rs.close(); ps.close();

            ps = conn.prepareStatement(
                "SELECT COUNT(*) AS total_cases, SUM(CASE WHEN c.status!='완료' THEN 1 ELSE 0 END) AS active_cases " +
                "FROM cases c WHERE c.dept_id=(SELECT me.dept_id FROM users me WHERE me.user_id=?)");
            ps.setString(1, userId); rs = ps.executeQuery();
            if (rs.next()) { stats.setTotalCases(rs.getInt("total_cases")); stats.setActiveCases(rs.getInt("active_cases")); }
            rs.close(); ps.close();

            ps = conn.prepareStatement("SELECT COUNT(*) AS cnt FROM relation_history WHERE user_id=?");
            ps.setString(1, userId); rs = ps.executeQuery();
            if (rs.next()) stats.setRelationEdges(rs.getInt("cnt"));
        } catch (Exception e) { e.printStackTrace(); }
        finally { closeAll(conn, ps, rs); }
        return stats;
    }

    public MypageStatsDTO getStatsByPeriod(String userId, String period) {
        MypageStatsDTO stats = new MypageStatsDTO();
        String dateFilter = "week".equals(period) ? " AND t.created_at >= DATE_SUB(NOW(), INTERVAL 7 DAY)"
                          : "month".equals(period) ? " AND t.created_at >= DATE_SUB(NOW(), INTERVAL 30 DAY)" : "";
        Connection conn = null; PreparedStatement ps = null; ResultSet rs = null;
        try {
            conn = dataSource.getConnection();
            ps = conn.prepareStatement(
                "SELECT COUNT(*) AS total_transcripts, SUM(t.has_contradiction) AS contradiction_count " +
                "FROM transcripts t JOIN cases c ON t.case_id = c.case_id " +
                "WHERE t.user_id=? " +
                "  AND ((SELECT me.dept_id FROM users me WHERE me.user_id=?) IS NULL " +
                "    OR c.dept_id=(SELECT me.dept_id FROM users me WHERE me.user_id=?))" + dateFilter);
            ps.setString(1, userId); ps.setString(2, userId); ps.setString(3, userId);
            rs = ps.executeQuery();
            if (rs.next()) { stats.setTotalTranscripts(rs.getInt("total_transcripts")); stats.setContradictionCount(rs.getInt("contradiction_count")); }
            rs.close(); ps.close();

            ps = conn.prepareStatement(
                "SELECT COUNT(*) AS total_cases, SUM(CASE WHEN c.status!='완료' THEN 1 ELSE 0 END) AS active_cases " +
                "FROM cases c WHERE c.dept_id=(SELECT me.dept_id FROM users me WHERE me.user_id=?)");
            ps.setString(1, userId); rs = ps.executeQuery();
            if (rs.next()) { stats.setTotalCases(rs.getInt("total_cases")); stats.setActiveCases(rs.getInt("active_cases")); }
            rs.close(); ps.close();

            String relFilter = "week".equals(period)  ? " AND created_at >= DATE_SUB(NOW(), INTERVAL 7 DAY)"
                             : "month".equals(period) ? " AND created_at >= DATE_SUB(NOW(), INTERVAL 30 DAY)" : "";
            ps = conn.prepareStatement("SELECT COUNT(*) AS cnt FROM relation_history WHERE user_id=?" + relFilter);
            ps.setString(1, userId); rs = ps.executeQuery();
            if (rs.next()) stats.setRelationEdges(rs.getInt("cnt"));
        } catch (Exception e) { e.printStackTrace(); }
        finally { closeAll(conn, ps, rs); }
        return stats;
    }

    public Map<String, Integer> getMonthlyTranscripts(String userId) {
        Map<String, Integer> result = new LinkedHashMap<>();
        Calendar cal = Calendar.getInstance();
        for (int i = 5; i >= 0; i--) {
            Calendar c2 = (Calendar) cal.clone();
            c2.add(Calendar.MONTH, -i);
            result.put(String.format("%d.%02d", c2.get(Calendar.YEAR), c2.get(Calendar.MONTH) + 1), 0);
        }
        Connection conn = null; PreparedStatement ps = null; ResultSet rs = null;
        try {
            conn = dataSource.getConnection();
            ps = conn.prepareStatement(
                "SELECT DATE_FORMAT(t.created_at,'%Y.%m') AS ym, COUNT(*) AS cnt " +
                "FROM transcripts t JOIN cases c ON t.case_id = c.case_id " +
                "WHERE t.user_id=? AND t.created_at >= DATE_SUB(NOW(), INTERVAL 6 MONTH) " +
                "  AND ((SELECT me.dept_id FROM users me WHERE me.user_id=?) IS NULL " +
                "    OR c.dept_id=(SELECT me.dept_id FROM users me WHERE me.user_id=?)) " +
                "GROUP BY ym ORDER BY ym");
            ps.setString(1, userId); ps.setString(2, userId); ps.setString(3, userId);
            rs = ps.executeQuery();
            while (rs.next()) { String ym = rs.getString("ym"); if (result.containsKey(ym)) result.put(ym, rs.getInt("cnt")); }
        } catch (Exception e) { e.printStackTrace(); }
        finally { closeAll(conn, ps, rs); }
        return result;
    }

    public boolean withdrawUser(String userId) {
        Connection conn = null; PreparedStatement ps = null;
        try {
            conn = dataSource.getConnection();
            conn.setAutoCommit(false);

            String[] deletes = {
                "DELETE FROM notifications WHERE user_id = ?",
                "DELETE FROM relation_history WHERE user_id = ?",
                "DELETE FROM transcripts WHERE user_id = ?",
                "DELETE FROM transcripts WHERE case_id IN (SELECT case_id FROM cases WHERE user_id = ?)",
                "DELETE FROM cases WHERE user_id = ?",
            };
            for (String sql : deletes) {
                ps = conn.prepareStatement(sql); ps.setString(1, userId); ps.executeUpdate(); ps.close();
            }

            ps = conn.prepareStatement(
                "UPDATE board_posts p SET p.like_count = (" +
                "  SELECT COUNT(*) FROM board_likes l WHERE l.target_type='post' AND l.target_id=p.post_id) - 1 " +
                "WHERE p.post_id IN (SELECT target_id FROM board_likes WHERE user_id=? AND target_type='post')");
            ps.setString(1, userId); ps.executeUpdate(); ps.close();

            String[] deletes2 = {
                "DELETE FROM board_likes WHERE user_id = ?",
                "DELETE FROM board_likes WHERE target_type='comment' AND target_id IN (SELECT comment_id FROM board_comments WHERE post_id IN (SELECT post_id FROM board_posts WHERE user_id=?))",
                "DELETE FROM board_likes WHERE target_type='post' AND target_id IN (SELECT post_id FROM board_posts WHERE user_id=?)",
                "DELETE FROM board_comments WHERE user_id = ?",
                "DELETE FROM board_comments WHERE post_id IN (SELECT post_id FROM board_posts WHERE user_id=?)",
                "DELETE FROM board_tags WHERE post_id IN (SELECT post_id FROM board_posts WHERE user_id=?)",
                "DELETE FROM board_links WHERE post_id IN (SELECT post_id FROM board_posts WHERE user_id=?)",
                "DELETE FROM board_posts WHERE user_id = ?",
                "DELETE FROM users WHERE user_id = ?",
            };
            for (String sql : deletes2) {
                ps = conn.prepareStatement(sql); ps.setString(1, userId); ps.executeUpdate(); ps.close();
            }

            conn.commit();
            return true;
        } catch (Exception e) {
            e.printStackTrace();
            try { if (conn != null) conn.rollback(); } catch (Exception ignored) {}
            return false;
        } finally {
            try { if (conn != null) conn.setAutoCommit(true); } catch (Exception ignored) {}
            closeAll(conn, ps, null);
        }
    }

    public Map<String, Object> getSettings(String userId) {
        Map<String, Object> settings = new HashMap<>();
        settings.put("notifContradiction", true); settings.put("notifRelation", true); settings.put("nightMode", false);
        Connection conn = null; PreparedStatement ps = null; ResultSet rs = null;
        try {
            conn = dataSource.getConnection();
            ps = conn.prepareStatement("SELECT notif_contradiction, notif_relation, night_mode FROM users WHERE user_id=?");
            ps.setString(1, userId); rs = ps.executeQuery();
            if (rs.next()) {
                settings.put("notifContradiction", rs.getInt("notif_contradiction") == 1);
                settings.put("notifRelation",      rs.getInt("notif_relation")      == 1);
                settings.put("nightMode",          rs.getInt("night_mode")          == 1);
            }
        } catch (Exception e) { e.printStackTrace(); }
        finally { closeAll(conn, ps, rs); }
        return settings;
    }

    public boolean saveSettings(String userId, boolean notifContradiction, boolean notifRelation, boolean nightMode) {
        Connection conn = null; PreparedStatement ps = null;
        try {
            conn = dataSource.getConnection();
            ps = conn.prepareStatement(
                "UPDATE users SET notif_contradiction=?, notif_relation=?, night_mode=? WHERE user_id=?");
            ps.setInt(1, notifContradiction ? 1 : 0); ps.setInt(2, notifRelation ? 1 : 0);
            ps.setInt(3, nightMode ? 1 : 0); ps.setString(4, userId);
            return ps.executeUpdate() > 0;
        } catch (Exception e) { e.printStackTrace(); }
        finally { closeAll(conn, ps, null); }
        return false;
    }

    public List<Map<String, Object>> getDepartmentsByOrg(String org) {
        List<Map<String, Object>> list = new ArrayList<>();
        Connection conn = null; PreparedStatement ps = null; ResultSet rs = null;
        try {
            conn = dataSource.getConnection();
            ps = conn.prepareStatement("SELECT dept_id, dept_name FROM departments WHERE org_name=? ORDER BY dept_name");
            ps.setString(1, org.trim()); rs = ps.executeQuery();
            while (rs.next()) {
                Map<String, Object> map = new HashMap<>();
                map.put("dept_id", rs.getInt("dept_id")); map.put("dept_name", rs.getString("dept_name"));
                list.add(map);
            }
        } catch (Exception e) { e.printStackTrace(); }
        finally { closeAll(conn, ps, rs); }
        return list;
    }

    public int getContradictionCount(String userId, String period) {
        String sql = "week".equals(period)  ? "SELECT COUNT(*) FROM contradiction_results WHERE user_id=? AND has_contradiction=1 AND created_at >= DATE_SUB(NOW(), INTERVAL 7 DAY)"
                   : "month".equals(period) ? "SELECT COUNT(*) FROM contradiction_results WHERE user_id=? AND has_contradiction=1 AND created_at >= DATE_SUB(NOW(), INTERVAL 1 MONTH)"
                   : "year".equals(period)  ? "SELECT COUNT(*) FROM contradiction_results WHERE user_id=? AND has_contradiction=1 AND created_at >= DATE_SUB(NOW(), INTERVAL 1 YEAR)"
                   :                          "SELECT COUNT(*) FROM contradiction_results WHERE user_id=? AND has_contradiction=1";
        Connection conn = null; PreparedStatement ps = null; ResultSet rs = null;
        try {
            conn = dataSource.getConnection();
            ps = conn.prepareStatement(sql); ps.setString(1, userId); rs = ps.executeQuery();
            if (rs.next()) return rs.getInt(1);
        } catch (Exception e) { e.printStackTrace(); }
        finally { closeAll(conn, ps, rs); }
        return 0;
    }

    private void closeAll(Connection c, PreparedStatement p, ResultSet r) {
        try { if (r != null) r.close(); } catch (Exception ignored) {}
        try { if (p != null) p.close(); } catch (Exception ignored) {}
        try { if (c != null) c.close(); } catch (Exception ignored) {}
    }
}
