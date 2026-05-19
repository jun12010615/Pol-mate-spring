package com.polmate.repository;

import com.polmate.entity.TimelineEvent;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

public interface TimelineEventRepository extends JpaRepository<TimelineEvent, Long> {

    List<TimelineEvent> findByCaseIdOrderBySortOrderAscTimeStartAscEventIdAsc(String caseId);

    long countByCaseId(String caseId);

    @Modifying(clearAutomatically = true, flushAutomatically = true)
    @Transactional
    @Query("DELETE FROM TimelineEvent e WHERE e.caseId = :caseId")
    void deleteByCaseId(@Param("caseId") String caseId);

    @Modifying(clearAutomatically = true, flushAutomatically = true)
    @Transactional
    @Query("DELETE FROM TimelineEvent e WHERE e.transcriptId = :transcriptId")
    void deleteByTranscriptId(@Param("transcriptId") Integer transcriptId);
}
