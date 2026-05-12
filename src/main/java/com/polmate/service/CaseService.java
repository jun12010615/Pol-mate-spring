package com.polmate.service;

import com.polmate.entity.Case;
import com.polmate.entity.Notification;
import com.polmate.repository.CaseRepository;
import com.polmate.repository.NotificationRepository;
import com.polmate.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.*;

@Service
@RequiredArgsConstructor
public class CaseService {

    private final CaseRepository caseRepo;
    private final UserRepository userRepo;
    private final NotificationRepository notifRepo;
    private final JdbcTemplate jdbc;

    // ── 목록 (동적 필터) ───────────────────────────────────────────
    public List<Map<String, Object>> list(String userId, String status, String keyword) {
        StringBuilder sql = new StringBuilder(
            "SELECT c.case_id, c.case_name, c.suspect, c.charge, c.status, " +
            "c.created_at, c.user_id, u.user_name, u.user_rank, " +
            "(SELECT COUNT(*) FROM transcripts t WHERE t.case_id=c.case_id) AS doc_count, " +
            "(SELECT COUNT(*) FROM transcripts t WHERE t.case_id=c.case_id AND t.has_contradiction=1) AS contradiction_count " +
            "FROM cases c LEFT JOIN users u ON c.user_id=u.user_id " +
            "WHERE c.dept_id=(SELECT me.dept_id FROM users me WHERE me.user_id=?) ");
        List<Object> params = new ArrayList<>();
        params.add(userId);
        if (!"all".equals(status)) { sql.append("AND c.status=? "); params.add(status); }
        if (keyword != null && !keyword.isEmpty()) {
            sql.append("AND (c.case_id LIKE ? OR c.case_name LIKE ? OR c.suspect LIKE ?) ");
            params.add("%" + keyword + "%"); params.add("%" + keyword + "%"); params.add("%" + keyword + "%");
        }
        sql.append("ORDER BY c.updated_at DESC");
        return jdbc.queryForList(sql.toString(), params.toArray());
    }

    // ── 사건 상세 ─────────────────────────────────────────────────
    public Optional<Map<String, Object>> detail(String caseId, String userId) {
        List<Map<String, Object>> rows = jdbc.queryForList(
            "SELECT c.case_id, c.case_name, c.suspect, c.charge, c.status, " +
            "c.created_at, c.user_id, d.dept_name, d.org_name, u.user_name, u.user_rank " +
            "FROM cases c LEFT JOIN users u ON c.user_id=u.user_id " +
            "LEFT JOIN departments d ON c.dept_id=d.dept_id " +
            "WHERE c.case_id=? AND c.dept_id=(SELECT me.dept_id FROM users me WHERE me.user_id=?)",
            caseId, userId);
        return rows.isEmpty() ? Optional.empty() : Optional.of(rows.get(0));
    }

    // ── 사건의 조서 목록 (점수 포함) ─────────────────────────────
    public List<Map<String, Object>> transcriptList(String caseId) {
        return jdbc.queryForList(
            "SELECT t.transcript_id, t.stmt_type, t.stmt_name, t.has_contradiction, " +
            "t.created_at, t.user_id, u.user_name, u.user_rank, " +
            "CHAR_LENGTH(IFNULL(t.original_text,'')) AS text_len, " +
            "ts.total_score, ts.consistency_score, ts.specificity_score, " +
            "ts.emotion_score, ts.temporal_score, " +
            "ts.consistency_reason, ts.specificity_reason, ts.emotion_reason, ts.temporal_reason " +
            "FROM transcripts t LEFT JOIN users u ON t.user_id=u.user_id " +
            "LEFT JOIN transcript_scores ts ON t.transcript_id=ts.transcript_id " +
            "WHERE t.case_id=? ORDER BY t.created_at DESC", caseId);
    }

    // ── 내 조서 목록 ──────────────────────────────────────────────
    public List<Map<String, Object>> docList(String userId, String keyword) {
        StringBuilder sql = new StringBuilder(
            "SELECT t.transcript_id, t.case_id, t.stmt_type, t.stmt_name, " +
            "t.has_contradiction, t.created_at, " +
            "CHAR_LENGTH(IFNULL(t.original_text,'')) AS text_len, c.case_name " +
            "FROM transcripts t JOIN cases c ON t.case_id=c.case_id WHERE t.user_id=? ");
        List<Object> params = new ArrayList<>(); params.add(userId);
        if (keyword != null && !keyword.isEmpty()) {
            sql.append("AND (c.case_id LIKE ? OR c.case_name LIKE ? OR t.stmt_name LIKE ?) ");
            params.add("%" + keyword + "%"); params.add("%" + keyword + "%"); params.add("%" + keyword + "%");
        }
        sql.append("ORDER BY t.created_at DESC");
        return jdbc.queryForList(sql.toString(), params.toArray());
    }

    // ── 내 부서 ───────────────────────────────────────────────────
    public Map<String, Object> myDept(String userId) {
        List<Map<String, Object>> rows = jdbc.queryForList(
            "SELECT d.dept_id, d.dept_name, d.org_name FROM users u " +
            "LEFT JOIN departments d ON u.dept_id=d.dept_id WHERE u.user_id=?", userId);
        return rows.isEmpty() ? Map.of() : rows.get(0);
    }

    // ── 조서 통계 ─────────────────────────────────────────────────
    public Map<String, Object> docStats(String userId) {
        return jdbc.queryForMap(
            "SELECT COUNT(*) AS total, SUM(CASE WHEN has_contradiction=1 THEN 1 ELSE 0 END) AS contradiction " +
            "FROM transcripts WHERE user_id=?", userId);
    }

    // ── 사건 생성 ─────────────────────────────────────────────────
    @Transactional
    public Map<String, Object> createCase(String userId, String caseId, String caseName,
                                          String suspect, String charge) {
        Map<String, Object> result = new HashMap<>();
        if (caseId == null || !caseId.matches("^\\d{4}-\\d{4}$")) {
            result.put("success", false); result.put("message", "사건번호 형식이 올바르지 않습니다. (예: 2024-0312)"); return result;
        }
        if (caseRepo.existsById(caseId)) {
            result.put("success", false); result.put("message", "이미 존재하는 사건번호입니다."); return result;
        }
        List<Map<String, Object>> deptRows = jdbc.queryForList(
            "SELECT u.dept_id, d.dept_name, d.org_name FROM users u LEFT JOIN departments d ON u.dept_id=d.dept_id WHERE u.user_id=?", userId);
        Integer deptId = null; String deptLabel = "부서 미배정";
        if (!deptRows.isEmpty() && deptRows.get(0).get("dept_id") != null) {
            deptId = ((Number) deptRows.get(0).get("dept_id")).intValue();
            String dn = (String) deptRows.get(0).get("dept_name");
            String on = (String) deptRows.get(0).get("org_name");
            if (dn != null && !dn.isEmpty())
                deptLabel = on != null && !on.isEmpty() ? dn + " (" + on + ")" : dn;
        }

        Case c = Case.builder()
            .caseId(caseId).caseName(caseName).suspect(suspect.isEmpty() ? null : suspect)
            .charge(charge.isEmpty() ? null : charge).status("진행중")
            .userId(userId).deptId(deptId).build();
        caseRepo.save(c);

        if (deptId != null) {
            final int finalDeptId = deptId;
            List<String> teammates = jdbc.queryForList(
                "SELECT user_id FROM users WHERE dept_id=? AND user_id!=? AND notif_relation=1",
                String.class, finalDeptId, userId);
            String title = "팀 새 사건 등록: " + caseName;
            String desc  = "사건 " + caseId + "(" + caseName + ")이(가) 팀에 등록됐습니다.";
            for (String tm : teammates) {
                notifRepo.save(Notification.builder()
                    .userId(tm).type("case").tag("새 사건").title(title).description(desc)
                    .link("myCase.jsp?caseId=" + caseId).isUnread(true).isCritical(false)
                    .createdAt(LocalDateTime.now()).build());
            }
        }
        result.put("success", true); result.put("caseId", caseId); result.put("deptLabel", deptLabel);
        result.put("message", "사건이 등록됐습니다.");
        return result;
    }

    // ── 사건 삭제 ─────────────────────────────────────────────────
    @Transactional
    public Map<String, Object> deleteCase(String userId, String caseId) {
        Map<String, Object> result = new HashMap<>();
        Optional<Case> opt = caseRepo.findById(caseId);
        if (opt.isEmpty() || !userId.equals(opt.get().getUserId())) {
            result.put("success", false); result.put("message", "삭제 권한이 없습니다. (등록자만 삭제 가능)"); return result;
        }
        caseRepo.deleteById(caseId);
        result.put("success", true); result.put("message", "사건이 삭제됐습니다.");
        return result;
    }

    // ── 사건 상태 변경 ────────────────────────────────────────────
    @Transactional
    public Map<String, Object> updateStatus(String userId, String caseId, String status) {
        Map<String, Object> result = new HashMap<>();
        int check = jdbc.queryForObject(
            "SELECT COUNT(*) FROM cases WHERE case_id=? AND dept_id=(SELECT me.dept_id FROM users me WHERE me.user_id=?)",
            Integer.class, caseId, userId);
        if (check == 0) { result.put("success", false); result.put("message", "수정 권한이 없습니다."); return result; }

        jdbc.update("UPDATE cases SET updated_at=NOW(), status=? WHERE case_id=?", status, caseId);

        boolean isCritical = "모순탐지".equals(status);
        String notifCol = isCritical ? "notif_contradiction" : "notif_relation";
        List<String> teammates = jdbc.queryForList(
            "SELECT u2.user_id FROM users u2 JOIN cases c ON c.case_id=? WHERE u2.dept_id=c.dept_id " +
            "AND c.dept_id IS NOT NULL AND u2.user_id!=? AND u2." + notifCol + "=1",
            String.class, caseId, userId);
        String title = "사건 상태 변경: " + caseId;
        String desc  = "사건 " + caseId + "의 상태가 [" + status + "](으)로 변경됐습니다.";
        for (String tm : teammates) {
            notifRepo.save(Notification.builder()
                .userId(tm).type("case").tag(isCritical ? "경고" : "새 사건")
                .title(title).description(desc)
                .link("myCase.jsp?caseId=" + caseId)
                .isUnread(true).isCritical(isCritical).createdAt(LocalDateTime.now()).build());
        }
        result.put("success", true); result.put("message", "수정됐습니다.");
        return result;
    }

    public boolean hasAccess(String caseId, String userId) {
        return caseRepo.checkAccess(caseId, userId).isPresent();
    }
}
