package com.polmate.service;

import com.polmate.entity.OfficerBadge;
import com.polmate.entity.User;
import com.polmate.repository.*;
import lombok.RequiredArgsConstructor;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;

@Service
@RequiredArgsConstructor
public class UserService {

    private final UserRepository userRepo;
    private final OfficerBadgeRepository badgeRepo;
    private final NotificationRepository notifRepo;
    private final RelationHistoryRepository historyRepo;
    private final TranscriptRepository transcriptRepo;
    private final BoardPostRepository postRepo;
    private final BoardCommentRepository commentRepo;
    private final BoardLikeRepository likeRepo;
    private final BoardTagRepository tagRepo;
    private final BoardLinkRepository linkRepo;
    private final JdbcTemplate jdbc;
    private final BCryptPasswordEncoder passwordEncoder = new BCryptPasswordEncoder();

    public Optional<User> findById(String userId) {
        return userRepo.findById(userId);
    }

    public Optional<User> findByNameAndEmail(String name, String email) {
        return userRepo.findByUserNameAndUserEmail(name, email);
    }

    public boolean existsByIdAndEmail(String userId, String email) {
        return userRepo.existsByUserIdAndUserEmail(userId, email);
    }

    public boolean authenticate(String userId, String rawPw) {
        return userRepo.findById(userId)
                       .map(u -> passwordEncoder.matches(rawPw, u.getUserPw()))
                       .orElse(false);
    }

    public boolean existsById(String userId) {
        return userRepo.existsById(userId);
    }

    public boolean existsByEmail(String email) {
        return jdbc.queryForObject(
            "SELECT COUNT(*) FROM users WHERE user_email = ?", Integer.class, email) > 0;
    }

    public boolean isValidBadge(String badgeNum) {
        return badgeRepo.findByBadgeNum(badgeNum)
                        .map(b -> b.getIsUsed() == 0)
                        .orElse(false);
    }

    @Transactional
    public void register(String userId, String userPw, String userName, String userPhone,
                         String userEmail, String userOrg, String userRank,
                         Integer deptId, String badgeNum) {
        User user = User.builder()
            .userId(userId).userPw(passwordEncoder.encode(userPw)).userName(userName)
            .userPhone(userPhone.isEmpty() ? null : userPhone)
            .userEmail(userEmail).userOrg(userOrg).userRank(userRank)
            .deptId(deptId).badgeNum(badgeNum)
            .notifContradiction(true).notifRelation(true).nightMode(false)
            .build();
        userRepo.save(user);
        badgeRepo.markUsed(badgeNum);
    }

    public Map<String, Object> getProfile(String userId) {
        return jdbc.queryForMap(
            "SELECT u.user_id, u.user_name, u.user_phone, u.user_org, u.user_rank, " +
            "u.badge_num, u.dept_id, u.created_at, d.dept_name " +
            "FROM users u LEFT JOIN departments d ON u.dept_id = d.dept_id WHERE u.user_id = ?", userId);
    }

    public Map<String, Object> getSettings(String userId) {
        Map<String, Object> s = new HashMap<>();
        s.put("notifContradiction", true); s.put("notifRelation", true); s.put("nightMode", false);
        userRepo.findById(userId).ifPresent(u -> {
            s.put("notifContradiction", u.isNotifContradiction());
            s.put("notifRelation",      u.isNotifRelation());
            s.put("nightMode",          u.isNightMode());
        });
        return s;
    }

    @Transactional
    public boolean updateProfile(String userId, String userName, String userRank,
                                 String userOrg, String userPhone, Integer deptId) {
        return userRepo.findById(userId).map(u -> {
            u.setUserName(userName); u.setUserRank(userRank);
            u.setUserOrg(userOrg);  u.setUserPhone(userPhone);
            u.setDeptId(deptId);
            userRepo.save(u);
            return true;
        }).orElse(false);
    }

    public boolean checkPassword(String userId, String rawPw) {
        return userRepo.findById(userId)
                       .map(u -> passwordEncoder.matches(rawPw, u.getUserPw()))
                       .orElse(false);
    }

    @Transactional
    public boolean changePassword(String userId, String newPw) {
        return userRepo.updatePassword(userId, passwordEncoder.encode(newPw), LocalDateTime.now()) > 0;
    }

    @Transactional
    public boolean saveSettings(String userId, boolean notifContradiction,
                                boolean notifRelation, boolean nightMode) {
        return userRepo.updateSettings(userId, notifContradiction, notifRelation, nightMode) > 0;
    }

    @Transactional
    public boolean withdraw(String userId) {
        try {
            notifRepo.deleteByUserId(userId);
            historyRepo.deleteByUserId(userId);
            jdbc.update("DELETE FROM transcripts WHERE user_id = ?", userId);
            jdbc.update("DELETE FROM transcripts WHERE case_id IN (SELECT case_id FROM cases WHERE user_id = ?)", userId);
            jdbc.update("DELETE FROM cases WHERE user_id = ?", userId);

            jdbc.update(
                "UPDATE board_posts p SET p.like_count = (" +
                "  SELECT COUNT(*) FROM board_likes l WHERE l.target_type='post' AND l.target_id=p.post_id) - 1 " +
                "WHERE p.post_id IN (SELECT target_id FROM board_likes WHERE user_id=? AND target_type='post')", userId);

            likeRepo.deleteByUserId(userId);
            likeRepo.deleteByTargetTypeAndOwner("comment", userId);
            likeRepo.deleteByTargetTypeAndOwner("post", userId);
            tagRepo.deleteByPostOwner(userId);
            linkRepo.deleteByPostOwner(userId);
            jdbc.update("DELETE FROM board_comments WHERE post_id IN (SELECT post_id FROM board_posts WHERE user_id = ?)", userId);
            jdbc.update("DELETE FROM board_comments WHERE user_id = ?", userId);
            jdbc.update("DELETE FROM board_posts WHERE user_id = ?", userId);
            userRepo.deleteById(userId);
            return true;
        } catch (Exception e) {
            e.printStackTrace();
            return false;
        }
    }

    public Integer getDaysSincePasswordChange(String userId) {
        return userRepo.getDaysSincePasswordChange(userId);
    }

    public List<Map<String, Object>> getHistory(String userId) {
        List<Map<String, Object>> rows = jdbc.queryForList(
            "SELECT t.transcript_id, t.case_id, c.case_name, t.stmt_type, t.stmt_name, " +
            "t.created_at, c.status AS case_status " +
            "FROM transcripts t JOIN cases c ON t.case_id = c.case_id " +
            "WHERE t.user_id = ? ORDER BY t.created_at DESC LIMIT 50", userId);
        List<Map<String, Object>> result = new ArrayList<>();
        for (Map<String, Object> row : rows) {
            Map<String, Object> item = new HashMap<>();
            item.put("transcriptId", row.get("transcript_id"));
            item.put("caseId",       row.get("case_id"));
            item.put("caseName",     row.get("case_name"));
            item.put("stmtType",     row.get("stmt_type"));
            item.put("stmtName",     row.get("stmt_name"));
            Object ca = row.get("created_at");
            item.put("createdAt",    ca != null ? ca.toString() : null);
            item.put("caseStatus",   row.get("case_status"));
            result.add(item);
        }
        return result;
    }

    public Map<String, Object> getStatsForPeriod(String userId, String period) {
        String dateFilter = "";
        if ("week".equals(period))       dateFilter = " AND t.created_at >= DATE_SUB(NOW(), INTERVAL 7 DAY)";
        else if ("month".equals(period)) dateFilter = " AND t.created_at >= DATE_SUB(NOW(), INTERVAL 30 DAY)";

        Map<String, Object> stats = new HashMap<>();

        Map<String, Object> tRow = jdbc.queryForMap(
            "SELECT COUNT(*) AS total_transcripts, " +
            "COALESCE(SUM(t.has_contradiction), 0) AS contradiction_count " +
            "FROM transcripts t WHERE t.user_id = ?" + dateFilter, userId);
        stats.put("totalTranscripts",   ((Number) tRow.get("total_transcripts")).intValue());
        stats.put("contradictionCount", ((Number) tRow.get("contradiction_count")).intValue());

        Map<String, Object> caseRow = jdbc.queryForMap(
            "SELECT COUNT(*) AS total_cases, " +
            "SUM(CASE WHEN c.status != '완료' THEN 1 ELSE 0 END) AS active_cases " +
            "FROM cases c WHERE c.dept_id = (SELECT me.dept_id FROM users me WHERE me.user_id = ?)", userId);
        stats.put("totalCases",  ((Number) caseRow.get("total_cases")).intValue());
        stats.put("activeCases", ((Number) caseRow.get("active_cases")).intValue());

        stats.put("relationEdges", historyRepo.countByUserId(userId));

        List<Map<String, Object>> monthlyRows = jdbc.queryForList(
            "SELECT DATE_FORMAT(t.created_at, '%Y-%m') AS month, COUNT(*) AS cnt " +
            "FROM transcripts t WHERE t.user_id = ?" + dateFilter +
            " GROUP BY month ORDER BY month", userId);
        Map<String, Integer> monthly = new LinkedHashMap<>();
        for (Map<String, Object> mr : monthlyRows) {
            monthly.put((String) mr.get("month"), ((Number) mr.get("cnt")).intValue());
        }
        stats.put("monthly", monthly);
        return stats;
    }

    public Map<String, Object> getStats(String userId) {
        Map<String, Object> stats = new HashMap<>();
        Map<String, Object> row = jdbc.queryForMap(
            "SELECT COUNT(*) AS total_transcripts, SUM(t.has_contradiction) AS contradiction_count, " +
            "  SUM(CASE WHEN c.status='완료' THEN 1 ELSE 0 END) AS completed_transcripts " +
            "FROM transcripts t JOIN cases c ON t.case_id = c.case_id " +
            "WHERE t.user_id = ? AND ((SELECT me.dept_id FROM users me WHERE me.user_id=?) IS NULL " +
            "  OR c.dept_id=(SELECT me.dept_id FROM users me WHERE me.user_id=?))",
            userId, userId, userId);
        stats.put("totalTranscripts",   ((Number) row.getOrDefault("total_transcripts",   0)).intValue());
        stats.put("contradictionCount", ((Number) row.getOrDefault("contradiction_count", 0)).intValue());
        stats.put("completedTranscripts",((Number)row.getOrDefault("completed_transcripts",0)).intValue());

        Map<String, Object> caseRow = jdbc.queryForMap(
            "SELECT COUNT(*) AS total_cases, SUM(CASE WHEN c.status!='완료' THEN 1 ELSE 0 END) AS active_cases " +
            "FROM cases c WHERE c.dept_id=(SELECT me.dept_id FROM users me WHERE me.user_id=?)", userId);
        stats.put("totalCases",  ((Number) caseRow.getOrDefault("total_cases",  0)).intValue());
        stats.put("activeCases", ((Number) caseRow.getOrDefault("active_cases", 0)).intValue());

        int relEdges = historyRepo.countByUserId(userId);
        stats.put("relationEdges", relEdges);
        return stats;
    }
}
