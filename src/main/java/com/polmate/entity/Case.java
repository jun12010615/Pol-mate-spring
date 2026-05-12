package com.polmate.entity;

import jakarta.persistence.*;
import org.hibernate.annotations.CreationTimestamp;
import org.hibernate.annotations.UpdateTimestamp;
import lombok.*;
import java.time.LocalDateTime;

@Entity
@Table(name = "cases")
@Data @Builder @NoArgsConstructor @AllArgsConstructor
public class Case {

    @Id
    @Column(name = "case_id", length = 20)
    private String caseId;

    @Column(name = "case_name")
    private String caseName;

    @Column(name = "suspect")
    private String suspect;

    @Column(name = "charge")
    private String charge;

    @Column(name = "status")
    private String status;

    @Column(name = "dept_id")
    private Integer deptId;

    @Column(name = "user_id")
    private String userId;

    @CreationTimestamp

    @Column(name = "created_at", updatable = false)
    private LocalDateTime createdAt;

    @UpdateTimestamp
    @Column(name = "updated_at")
    private LocalDateTime updatedAt;
}
