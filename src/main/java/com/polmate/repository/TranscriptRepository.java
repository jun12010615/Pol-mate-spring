package com.polmate.repository;

import com.polmate.entity.Transcript;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

public interface TranscriptRepository extends JpaRepository<Transcript, Integer> {

    List<Transcript> findByCaseIdOrderByCreatedAtDesc(String caseId);

    List<Transcript> findByUserIdOrderByCreatedAtDesc(String userId);

    @Query(value =
        "SELECT t.*, c.case_name, c.status AS case_status FROM transcripts t " +
        "JOIN cases c ON t.case_id = c.case_id " +
        "WHERE t.user_id = :userId " +
        "AND ((SELECT me.dept_id FROM users me WHERE me.user_id = :userId) IS NULL " +
        "  OR c.dept_id = (SELECT me.dept_id FROM users me WHERE me.user_id = :userId)) " +
        "ORDER BY t.created_at DESC LIMIT :lim",
        nativeQuery = true)
    List<Object[]> findHistoryForUser(@Param("userId") String userId, @Param("lim") int limit);

    @Modifying @Transactional
    @Query("UPDATE Transcript t SET t.aiResult = :result WHERE t.transcriptId = :id")
    int updateAiResult(@Param("id") Integer id, @Param("result") String result);

    @Modifying @Transactional
    @Query("UPDATE Transcript t SET t.hasContradiction = :flag WHERE t.transcriptId = :id")
    int updateHasContradiction(@Param("id") Integer id, @Param("flag") int flag);
}
