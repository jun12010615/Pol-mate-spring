package com.polmate.repository.relation;

import com.polmate.entity.relation.RelationEdge;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.transaction.annotation.Transactional;

public interface RelationEdgeRepository extends JpaRepository<RelationEdge, Integer> {

    @Modifying @Transactional
    void deleteByCaseId(String caseId);
}
