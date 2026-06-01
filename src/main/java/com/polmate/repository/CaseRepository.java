package com.polmate.repository;

import com.polmate.entity.Case;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.Optional;

public interface CaseRepository extends JpaRepository<Case, String> {

    // 접근 권한 확인 (사건 목록/상세와 동일: 동일 부서 사건)
    @Query(value =
        "SELECT 1 FROM cases c WHERE c.case_id = :caseId " +
        "AND c.dept_id = (SELECT me.dept_id FROM users me WHERE me.user_id = :userId)",
        nativeQuery = true)
    Optional<Integer> checkAccess(@Param("caseId") String caseId, @Param("userId") String userId);

}
