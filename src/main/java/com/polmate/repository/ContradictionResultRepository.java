package com.polmate.repository;

import com.polmate.entity.ContradictionResult;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;
import java.util.Optional;

public interface ContradictionResultRepository extends JpaRepository<ContradictionResult, Integer> {

    List<ContradictionResult> findByUserIdOrderByCreatedAtDesc(String userId);

    List<ContradictionResult> findByCaseIdAndHasContradiction(String caseId, boolean hasContradiction);

    @Query(value =
        "SELECT cr.*, c.case_name FROM contradiction_results cr " +
        "LEFT JOIN cases c ON cr.case_id = c.case_id " +
        "WHERE cr.user_id = :userId ORDER BY cr.created_at DESC",
        nativeQuery = true)
    List<Object[]> findByUserIdWithCaseName(@Param("userId") String userId);

    Optional<ContradictionResult> findByResultIdAndUserId(Integer resultId, String userId);

    @Query(value =
        "SELECT COUNT(*) FROM contradiction_results WHERE user_id = :userId AND has_contradiction = 1",
        nativeQuery = true)
    int countByUserIdAndContradiction(@Param("userId") String userId);

    @Query(value =
        "SELECT COUNT(*) FROM contradiction_results WHERE user_id = :userId AND has_contradiction = 1 " +
        "AND created_at >= DATE_SUB(NOW(), INTERVAL :days DAY)",
        nativeQuery = true)
    int countByUserIdAndContradictionWithinDays(@Param("userId") String userId, @Param("days") int days);
}
