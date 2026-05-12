package com.polmate.entity;

import jakarta.persistence.*;
import lombok.*;
import java.time.LocalDateTime;

@Entity
@Table(name = "relation_history")
@Data @Builder @NoArgsConstructor @AllArgsConstructor
public class RelationHistory {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "history_id")
    private Integer historyId;

    @Column(name = "case_id")
    private String caseId;

    @Column(name = "user_id")
    private String userId;

    @Column(name = "action")
    private String action;

    @Column(name = "created_at", updatable = false)
    private LocalDateTime createdAt;
}
