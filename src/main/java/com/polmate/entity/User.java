package com.polmate.entity;

import jakarta.persistence.*;
import lombok.*;
import java.time.LocalDateTime;

@Entity
@Table(name = "users")
@Data @Builder @NoArgsConstructor @AllArgsConstructor
public class User {

    @Id
    @Column(name = "user_id", length = 50)
    private String userId;

    @Column(name = "user_pw")
    private String userPw;

    @Column(name = "user_name")
    private String userName;

    @Column(name = "user_rank")
    private String userRank;

    @Column(name = "user_org")
    private String userOrg;

    @Column(name = "user_phone")
    private String userPhone;

    @Column(name = "dept_id")
    private Integer deptId;

    @Column(name = "badge_num")
    private String badgeNum;

    @Column(name = "user_email")
    private String userEmail;

    @Column(name = "notif_contradiction")
    private boolean notifContradiction;

    @Column(name = "notif_relation")
    private boolean notifRelation;

    @Column(name = "night_mode")
    private boolean nightMode;

    @Column(name = "created_at", updatable = false)
    private LocalDateTime createdAt;

    @Column(name = "password_changed_at")
    private LocalDateTime passwordChangedAt;
}
