package com.polmate.entity;

import jakarta.persistence.*;
import lombok.*;
import java.io.Serializable;

@Embeddable
@Data @NoArgsConstructor @AllArgsConstructor
public class BoardLikeId implements Serializable {

    @Column(name = "user_id")
    private String userId;

    @Column(name = "target_type")
    private String targetType;

    @Column(name = "target_id")
    private Integer targetId;
}
