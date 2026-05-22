package com.polmate.entity;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;
import org.hibernate.annotations.CreationTimestamp;

import java.time.LocalDateTime;

@Entity
@Table(name = "access_logs",
       indexes = {
           @Index(name = "idx_al_user",   columnList = "user_id"),
           @Index(name = "idx_al_target", columnList = "target_type,target_id"),
           @Index(name = "idx_al_time",   columnList = "accessed_at")
       })
@Getter @Setter
public class AccessLog {

    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "log_id")
    private Long logId;

    @Column(name = "user_id", nullable = false, length = 50)
    private String userId;

    @Column(name = "user_name", length = 100)
    private String userName;

    @Column(name = "target_type", nullable = false, length = 30)
    private String targetType;

    @Column(name = "target_id", length = 100)
    private String targetId;

    @Column(name = "target_name", length = 200)
    private String targetName;

    @Column(name = "ip_address", length = 50)
    private String ipAddress;

    @CreationTimestamp
    @Column(name = "accessed_at", updatable = false)
    private LocalDateTime accessedAt;
}
