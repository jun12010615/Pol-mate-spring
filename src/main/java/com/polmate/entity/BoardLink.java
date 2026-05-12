package com.polmate.entity;

import jakarta.persistence.*;
import lombok.*;

@Entity
@Table(name = "board_links")
@Data @Builder @NoArgsConstructor @AllArgsConstructor
public class BoardLink {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "link_id")
    private Integer linkId;

    @Column(name = "post_id")
    private Integer postId;

    @Column(name = "link_name")
    private String linkName;

    @Column(name = "link_url")
    private String linkUrl;
}
