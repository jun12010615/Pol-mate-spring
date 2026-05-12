package com.polmate.entity;

import jakarta.persistence.*;
import lombok.*;

@Entity
@Table(name = "board_tags")
@Data @Builder @NoArgsConstructor @AllArgsConstructor
public class BoardTag {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "tag_id")
    private Integer tagId;

    @Column(name = "post_id")
    private Integer postId;

    @Column(name = "tag_name")
    private String tagName;
}
