package com.polmate.repository;

import com.polmate.entity.Case;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;
import java.util.Optional;

public interface CaseRepository extends JpaRepository<Case, String> {

    // 접근 권한 확인 (사건 목록/상세와 동일: 동일 부서 사건)
    @Query(value =
        "SELECT 1 FROM cases c WHERE c.case_id = :caseId " +
        "AND c.dept_id = (SELECT me.dept_id FROM users me WHERE me.user_id = :userId)",
        nativeQuery = true)
    Optional<Integer> checkAccess(@Param("caseId") String caseId, @Param("userId") String userId);

    // 사건 목록 (집계 포함) — 동적 필터는 CaseService에서 JdbcTemplate으로 처리
    @Query(value =
        "SELECT c.case_id, c.case_name, c.suspect, c.charge, c.status, c.created_at, c.user_id, " +
        "u.user_name, u.user_rank, " +
        "(SELECT COUNT(*) FROM transcripts t WHERE t.case_id = c.case_id) AS doc_count, " +
        "(SELECT COUNT(*) FROM transcripts t WHERE t.case_id = c.case_id AND t.has_contradiction = 1) AS contradiction_count " +
        "FROM cases c LEFT JOIN users u ON c.user_id = u.user_id " +
        "WHERE c.dept_id = (SELECT me.dept_id FROM users me WHERE me.user_id = :userId) " +
        "ORDER BY c.created_at DESC",
        nativeQuery = true)
    List<Object[]> findAllForDept(@Param("userId") String userId);

    // 사건 상세 (조서 포함) — CaseService에서 JdbcTemplate으로 처리
    @Query(value =
        "SELECT c.*, u.user_name, u.user_rank, d.dept_name FROM cases c " +
        "LEFT JOIN users u ON c.user_id = u.user_id " +
        "LEFT JOIN departments d ON c.dept_id = d.dept_id " +
        "WHERE c.case_id = :caseId",
        nativeQuery = true)
    Optional<Object[]> findDetailById(@Param("caseId") String caseId);
}
