package com.polmate.entity;

import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.CreationTimestamp;
import java.time.LocalDateTime;

@Entity
@Table(name = "transcripts")
@Data @Builder @NoArgsConstructor @AllArgsConstructor
public class Transcript {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "transcript_id")
    private Integer transcriptId;

    @Column(name = "case_id")
    private String caseId;

    @Column(name = "user_id")
    private String userId;

    @Column(name = "stmt_name")
    private String stmtName;

    @Column(name = "stmt_type")
    private String stmtType;

    @Column(name = "original_text", columnDefinition = "TEXT")
    private String originalText;

    @Column(name = "ai_result", columnDefinition = "TEXT")
    private String aiResult;

    @Column(name = "has_contradiction")
    private int hasContradiction;

    @CreationTimestamp
    @Column(name = "created_at", updatable = false)
    private LocalDateTime createdAt;
}
