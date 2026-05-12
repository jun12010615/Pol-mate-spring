package com.polmate.repository;

import com.polmate.entity.RelationEdge;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

public interface RelationEdgeRepository extends JpaRepository<RelationEdge, Integer> {

    List<RelationEdge> findByCaseId(String caseId);

    @Modifying @Transactional
    void deleteByCaseId(String caseId);
}
