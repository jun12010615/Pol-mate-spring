package com.polmate.entity;

import jakarta.persistence.*;
import lombok.*;
import java.time.LocalDateTime;

@Entity
@Table(name = "case_similar_cache")
@Data @Builder @NoArgsConstructor @AllArgsConstructor
public class CaseSimilarCache {

    @Id
    @Column(name = "case_id")
    private String caseId;

    @Column(name = "result_json", columnDefinition = "TEXT")
    private String resultJson;

    @Column(name = "analyzed_at")
    private LocalDateTime analyzedAt;
}
