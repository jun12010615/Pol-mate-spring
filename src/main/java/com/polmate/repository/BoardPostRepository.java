package com.polmate.repository;

import com.polmate.entity.BoardPost;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

public interface BoardPostRepository extends JpaRepository<BoardPost, Integer> {

    // 목록 조회 (동적 필터는 BoardService에서 JdbcTemplate으로 처리)
    @Query(value =
        "SELECT p.*, u.user_name, u.user_rank, " +
        "(SELECT COUNT(*) FROM board_comments bc WHERE bc.post_id = p.post_id) AS comment_count " +
        "FROM board_posts p LEFT JOIN users u ON p.user_id = u.user_id " +
        "ORDER BY p.created_at DESC",
        nativeQuery = true)
    List<Object[]> findAllWithMeta();

    @Modifying @Transactional
    @Query("UPDATE BoardPost p SET p.viewCount = p.viewCount + 1 WHERE p.postId = :id")
    int incrementViewCount(@Param("id") Integer id);

    @Modifying @Transactional
    @Query("UPDATE BoardPost p SET p.likeCount = p.likeCount + 1 WHERE p.postId = :id")
    int incrementLikeCount(@Param("id") Integer id);

    @Modifying @Transactional
    @Query("UPDATE BoardPost p SET p.likeCount = p.likeCount - 1 WHERE p.postId = :id AND p.likeCount > 0")
    int decrementLikeCount(@Param("id") Integer id);
}
