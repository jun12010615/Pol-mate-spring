package com.polmate.entity;

import jakarta.persistence.*;
import lombok.*;
import java.time.LocalDateTime;

@Entity
@Table(name = "transcript_scores")
@Data @Builder @NoArgsConstructor @AllArgsConstructor
public class TranscriptScore {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "score_id")
    private Integer scoreId;

    @Column(name = "transcript_id", unique = true)
    private Integer transcriptId;

    @Column(name = "consistency_score")
    private int consistencyScore;

    @Column(name = "specificity_score")
    private int specificityScore;

    @Column(name = "emotion_score")
    private int emotionScore;

    @Column(name = "temporal_score")
    private int temporalScore;

    @Column(name = "total_score")
    private int totalScore;

    @Column(name = "consistency_reason", columnDefinition = "TEXT")
    private String consistencyReason;

    @Column(name = "specificity_reason", columnDefinition = "TEXT")
    private String specificityReason;

    @Column(name = "emotion_reason", columnDefinition = "TEXT")
    private String emotionReason;

    @Column(name = "temporal_reason", columnDefinition = "TEXT")
    private String temporalReason;

    @Column(name = "scored_at", updatable = false)
    private LocalDateTime scoredAt;
}
