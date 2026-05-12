package com.polmate.repository;

import com.polmate.entity.BoardLike;
import com.polmate.entity.BoardLikeId;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.transaction.annotation.Transactional;

public interface BoardLikeRepository extends JpaRepository<BoardLike, BoardLikeId> {

    boolean existsById(BoardLikeId id);

    @Modifying @Transactional
    @Query(value = "DELETE FROM board_likes WHERE user_id = :userId", nativeQuery = true)
    void deleteByUserId(@Param("userId") String userId);

    @Modifying @Transactional
    @Query(value =
        "DELETE FROM board_likes WHERE target_type = :type AND target_id IN " +
        "(SELECT post_id FROM board_posts WHERE user_id = :userId)",
        nativeQuery = true)
    void deleteByTargetTypeAndOwner(@Param("type") String type, @Param("userId") String userId);
}
