package com.polmate.repository;

import com.polmate.entity.BoardComment;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;

public interface BoardCommentRepository extends JpaRepository<BoardComment, Integer> {

    @Query(value =
        "SELECT bc.*, u.user_name, u.user_rank FROM board_comments bc " +
        "LEFT JOIN users u ON bc.user_id = u.user_id " +
        "WHERE bc.post_id = :postId ORDER BY bc.created_at ASC",
        nativeQuery = true)
    List<Object[]> findByPostIdWithUser(@Param("postId") Integer postId);

    void deleteByPostId(Integer postId);
}
