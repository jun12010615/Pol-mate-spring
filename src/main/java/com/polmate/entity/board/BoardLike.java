package com.polmate.entity.board;

import jakarta.persistence.*;
import lombok.*;

@Entity
@Table(name = "board_likes")
@Data @Builder @NoArgsConstructor @AllArgsConstructor
public class BoardLike {

    @EmbeddedId
    private BoardLikeId id;
}
