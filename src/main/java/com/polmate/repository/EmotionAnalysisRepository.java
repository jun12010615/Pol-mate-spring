package com.polmate.repository;

import com.polmate.entity.EmotionAnalysis;
import org.springframework.data.jpa.repository.JpaRepository;
import java.util.Optional;

public interface EmotionAnalysisRepository extends JpaRepository<EmotionAnalysis, Integer> {
    Optional<EmotionAnalysis> findByTranscriptId(Integer transcriptId);
}
