package com.polmate.repository;

import com.polmate.entity.RelationHistory;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface RelationHistoryRepository extends JpaRepository<RelationHistory, Integer> {

    int countByUserId(String userId);

    @Query(value =
        "SELECT COUNT(*) FROM relation_history WHERE user_id = :userId AND created_at >= DATE_SUB(NOW(), INTERVAL :days DAY)",
        nativeQuery = true)
    int countByUserIdWithinDays(@Param("userId") String userId, @Param("days") int days);

    void deleteByUserId(String userId);
}
