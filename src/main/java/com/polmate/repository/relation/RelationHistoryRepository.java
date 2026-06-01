package com.polmate.repository.relation;

import com.polmate.entity.relation.RelationHistory;
import org.springframework.data.jpa.repository.JpaRepository;

public interface RelationHistoryRepository extends JpaRepository<RelationHistory, Integer> {

    int countByUserId(String userId);

    void deleteByUserId(String userId);
}
