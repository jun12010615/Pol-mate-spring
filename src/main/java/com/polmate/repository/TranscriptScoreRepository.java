package com.polmate.repository;

import com.polmate.entity.TranscriptScore;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.Optional;

public interface TranscriptScoreRepository extends JpaRepository<TranscriptScore, Integer> {

    Optional<TranscriptScore> findByTranscriptId(Integer transcriptId);

    @Query(value =
        "SELECT ts.* FROM transcript_scores ts " +
        "JOIN transcripts t ON ts.transcript_id = t.transcript_id " +
        "JOIN cases c ON t.case_id = c.case_id " +
        "WHERE ts.transcript_id = :tId " +
        "AND (c.user_id = :userId OR c.dept_id = " +
        "  (SELECT me.dept_id FROM users me WHERE me.user_id = :userId))",
        nativeQuery = true)
    Optional<Object[]> findWithAccessCheck(@Param("tId") Integer transcriptId, @Param("userId") String userId);
}
