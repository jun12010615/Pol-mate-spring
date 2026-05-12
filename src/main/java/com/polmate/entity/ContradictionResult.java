package com.polmate.entity;

import jakarta.persistence.*;
import org.hibernate.annotations.CreationTimestamp;
import lombok.*;
import java.time.LocalDateTime;

@Entity
@Table(name = "contradiction_results")
@Data @Builder @NoArgsConstructor @AllArgsConstructor
public class ContradictionResult {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "result_id")
    private Integer resultId;

    @Column(name = "case_id")
    private String caseId;

    @Column(name = "user_id")
    private String userId;

    @Column(name = "stmt_name")
    private String stmtName;

    @Column(name = "stmt_type")
    private String stmtType;

    @Column(name = "has_contradiction")
    private boolean hasContradiction;

    @Column(name = "ai_result", columnDefinition = "TEXT")
    private String aiResult;

    @Column(name = "stmt_text", columnDefinition = "TEXT")
    private String stmtText;

    @CreationTimestamp

    @Column(name = "created_at", updatable = false)
    private LocalDateTime createdAt;
}
