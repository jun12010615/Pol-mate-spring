package com.polmate.service;

import com.polmate.entity.ContradictionResult;
import com.polmate.repository.ContradictionResultRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.*;

@Service
@RequiredArgsConstructor
public class ContradictionService {

    private final ContradictionResultRepository resultRepo;
    private final JdbcTemplate jdbc;

    public List<Map<String, Object>> list(String userId) {
        return jdbc.queryForList(
            "SELECT cr.result_id, cr.case_id, cr.stmt_name, cr.stmt_type, " +
            "cr.has_contradiction, cr.ai_result, cr.stmt_text, cr.created_at, c.case_name " +
            "FROM contradiction_results cr LEFT JOIN cases c ON cr.case_id=c.case_id " +
            "WHERE cr.user_id=? ORDER BY cr.created_at DESC", userId);
    }

    public Optional<Map<String, Object>> detail(String userId, Integer resultId) {
        List<Map<String, Object>> rows = jdbc.queryForList(
            "SELECT cr.*, c.case_name FROM contradiction_results cr " +
            "LEFT JOIN cases c ON cr.case_id=c.case_id " +
            "WHERE cr.result_id=? AND cr.user_id=?", resultId, userId);
        return rows.isEmpty() ? Optional.empty() : Optional.of(rows.get(0));
    }

    @Transactional
    public int save(String userId, String caseId, String stmtName, String stmtType,
                    boolean hasContradiction, String aiResult, String stmtText) {
        ContradictionResult cr = ContradictionResult.builder()
            .userId(userId).caseId(caseId.isEmpty() ? null : caseId)
            .stmtName(stmtName).stmtType(stmtType)
            .hasContradiction(hasContradiction)
            .aiResult(aiResult.length() > 65000 ? aiResult.substring(0, 65000) : aiResult)
            .stmtText(stmtText.length()  > 65000 ? stmtText.substring(0, 65000)  : stmtText)
            .createdAt(LocalDateTime.now())
            .build();
        return resultRepo.save(cr).getResultId();
    }

    @Transactional
    public boolean delete(String userId, Integer resultId) {
        Optional<ContradictionResult> opt = resultRepo.findByResultIdAndUserId(resultId, userId);
        if (opt.isEmpty()) return false;
        resultRepo.deleteById(resultId);
        return true;
    }
}
