package com.polmate.entity;

import jakarta.persistence.*;
import lombok.*;
import java.time.LocalDateTime;

@Entity
@Table(name = "board_comments")
@Data @Builder @NoArgsConstructor @AllArgsConstructor
public class BoardComment {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "comment_id")
    private Integer commentId;

    @Column(name = "post_id")
    private Integer postId;

    @Column(name = "user_id")
    private String userId;

    @Column(name = "content", columnDefinition = "TEXT")
    private String content;

    @Column(name = "anonymous")
    private int anonymous;

    @Column(name = "created_at", updatable = false)
    private LocalDateTime createdAt;
}
