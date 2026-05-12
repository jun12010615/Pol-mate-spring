package com.polmate.repository;

import com.polmate.entity.BoardTag;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.transaction.annotation.Transactional;

public interface BoardTagRepository extends JpaRepository<BoardTag, Integer> {

    @Modifying @Transactional
    @Query(value =
        "DELETE FROM board_tags WHERE post_id IN (SELECT post_id FROM board_posts WHERE user_id = :userId)",
        nativeQuery = true)
    void deleteByPostOwner(@Param("userId") String userId);

    void deleteByPostId(Integer postId);
}
