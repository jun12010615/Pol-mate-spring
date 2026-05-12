package com.polmate.entity;

import jakarta.persistence.*;
import lombok.*;

@Entity
@Table(name = "officer_badges")
@Data @Builder @NoArgsConstructor @AllArgsConstructor
public class OfficerBadge {

    @Id
    @Column(name = "badge_num", length = 10)
    private String badgeNum;

    @Column(name = "is_used")
    private int isUsed;
}
