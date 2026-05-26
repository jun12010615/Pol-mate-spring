package com.polmate.entity;

import jakarta.persistence.*;
import lombok.*;
import java.time.LocalDateTime;

@Entity
@Table(name = "emotion_analyses")
@Data @Builder @NoArgsConstructor @AllArgsConstructor
public class EmotionAnalysis {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "analysis_id")
    private Integer analysisId;

    @Column(name = "transcript_id", unique = true)
    private Integer transcriptId;

    @Column(name = "model", length = 50)
    private String model;

    @Column(name = "sentence_count")
    private int sentenceCount;

    @Column(name = "highlight_count")
    private int highlightCount;

    @Column(name = "sentences_json", columnDefinition = "LONGTEXT")
    private String sentencesJson;

    @Column(name = "highlights_json", columnDefinition = "TEXT")
    private String highlightsJson;

    @Column(name = "analyzed_at")
    private LocalDateTime analyzedAt;
}
