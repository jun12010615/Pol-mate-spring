package com.polmate.service;

import com.polmate.entity.*;
import com.polmate.repository.*;
import lombok.RequiredArgsConstructor;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.*;

@Service
@RequiredArgsConstructor
public class BoardService {

    private final BoardPostRepository postRepo;
    private final BoardCommentRepository commentRepo;
    private final BoardLikeRepository likeRepo;
    private final BoardTagRepository tagRepo;
    private final BoardLinkRepository linkRepo;
    private final JdbcTemplate jdbc;

    // ── 목록 (동적 필터) ─────────────────────────────────────────
    public List<Map<String, Object>> list(String userId, String category, String sort, String keyword) {
        if (category == null || category.isEmpty()) category = "all";
        if (sort      == null || sort.isEmpty())     sort     = "latest";
        StringBuilder sql = new StringBuilder(
            "SELECT p.post_id, p.category, p.title, p.content, p.view_count, p.like_count, " +
            "p.created_at, p.anonymous, p.user_id, u.user_name, u.user_rank, " +
            "(SELECT COUNT(*) FROM board_comments bc WHERE bc.post_id=p.post_id) AS comment_count " +
            "FROM board_posts p LEFT JOIN users u ON p.user_id=u.user_id WHERE 1=1 ");
        List<Object> params = new ArrayList<>();
        if ("mine".equals(category)) { sql.append("AND p.user_id=? "); params.add(userId); }
        else if (!"all".equals(category)) { sql.append("AND p.category=? "); params.add(category); }
        if (keyword != null && !keyword.isEmpty()) {
            sql.append("AND (p.title LIKE ? OR p.content LIKE ?) ");
            params.add("%" + keyword + "%"); params.add("%" + keyword + "%");
        }
        sql.append("popular".equals(sort)
            ? "ORDER BY p.like_count DESC, p.created_at DESC"
            : "ORDER BY p.created_at DESC");
        return jdbc.queryForList(sql.toString(), params.toArray());
    }

    // ── 상세 조회 ────────────────────────────────────────────────
    @Transactional
    public Optional<Map<String, Object>> detail(Integer postId, String userId) {
        postRepo.incrementViewCount(postId);
        List<Map<String, Object>> rows = jdbc.queryForList(
            "SELECT p.post_id, p.category, p.title, p.content, p.view_count, p.like_count, " +
            "p.created_at, p.anonymous, p.user_id, u.user_name, u.user_rank, u.user_org " +
            "FROM board_posts p LEFT JOIN users u ON p.user_id=u.user_id WHERE p.post_id=?", postId);
        if (rows.isEmpty()) return Optional.empty();
        Map<String, Object> post = rows.get(0);
        post.put("liked", jdbc.queryForObject(
            "SELECT COUNT(*) FROM board_likes WHERE user_id=? AND target_type='post' AND target_id=?",
            Integer.class, userId, postId) > 0);
        post.put("tags",  getTags(postId));
        post.put("links", getLinks(postId));
        post.put("comments", jdbc.queryForList(
            "SELECT c.comment_id, c.content, c.created_at, c.user_id, u.user_name, u.user_rank, " +
            "(SELECT COUNT(*) FROM board_likes bl WHERE bl.target_type='comment' AND bl.target_id=c.comment_id) AS like_count " +
            "FROM board_comments c LEFT JOIN users u ON c.user_id=u.user_id WHERE c.post_id=? ORDER BY c.created_at ASC", postId));
        return Optional.of(post);
    }

    // ── 게시글 작성 ──────────────────────────────────────────────
    @Transactional
    public int write(String userId, String category, String title, String content,
                     int anonymous, String tagsRaw, String[] linkNames, String[] linkUrls) {
        BoardPost post = BoardPost.builder()
            .userId(userId).category(category).title(title.trim()).content(content.trim())
            .anonymous(anonymous).viewCount(0).likeCount(0).build();
        int newId = postRepo.save(post).getPostId();
        saveTags(newId, tagsRaw);
        saveLinks(newId, "gear".equals(category), linkNames, linkUrls);
        return newId;
    }

    // ── 게시글 수정 ──────────────────────────────────────────────
    @Transactional
    public boolean edit(String userId, Integer postId, String title, String content,
                        int anonymous, String tagsRaw, String[] linkNames, String[] linkUrls) {
        Optional<BoardPost> opt = postRepo.findById(postId);
        if (opt.isEmpty() || !userId.equals(opt.get().getUserId())) return false;
        BoardPost p = opt.get();
        p.setTitle(title.trim()); p.setContent(content.trim());
        p.setAnonymous(anonymous); p.setUpdatedAt(LocalDateTime.now());
        postRepo.save(p);
        tagRepo.deleteByPostId(postId);
        linkRepo.deleteByPostId(postId);
        saveTags(postId, tagsRaw);
        saveLinks(postId, true, linkNames, linkUrls);
        return true;
    }

    // ── 게시글 삭제 ──────────────────────────────────────────────
    @Transactional
    public boolean delete(String userId, Integer postId) {
        Optional<BoardPost> opt = postRepo.findById(postId);
        if (opt.isEmpty() || !userId.equals(opt.get().getUserId())) return false;
        postRepo.deleteById(postId);
        return true;
    }

    // ── 댓글 작성 ────────────────────────────────────────────────
    @Transactional
    public void addComment(String userId, Integer postId, String content) {
        commentRepo.save(BoardComment.builder()
            .postId(postId).userId(userId).content(content.trim()).anonymous(0).build());
    }

    // ── 댓글 삭제 ────────────────────────────────────────────────
    @Transactional
    public boolean deleteComment(String userId, Integer commentId) {
        Optional<BoardComment> opt = commentRepo.findById(commentId);
        if (opt.isEmpty() || !userId.equals(opt.get().getUserId())) return false;
        jdbc.update("DELETE FROM board_likes WHERE target_type='comment' AND target_id=?", commentId);
        commentRepo.deleteById(commentId);
        return true;
    }

    // ── 좋아요 토글 ──────────────────────────────────────────────
    @Transactional
    public boolean toggleLike(String userId, String targetType, Integer targetId) {
        BoardLikeId id = new BoardLikeId(userId, targetType, targetId);
        if (likeRepo.existsById(id)) {
            likeRepo.deleteById(id);
            if ("post".equals(targetType)) postRepo.decrementLikeCount(targetId);
            return false;
        } else {
            likeRepo.save(new BoardLike(id));
            if ("post".equals(targetType)) postRepo.incrementLikeCount(targetId);
            return true;
        }
    }

    private List<String> getTags(Integer postId) {
        return jdbc.queryForList("SELECT tag_name FROM board_tags WHERE post_id=?", String.class, postId);
    }

    private List<Map<String, Object>> getLinks(Integer postId) {
        return jdbc.queryForList("SELECT link_name, link_url FROM board_links WHERE post_id=?", postId);
    }

    private void saveTags(Integer postId, String tagsRaw) {
        if (tagsRaw == null || tagsRaw.trim().isEmpty()) return;
        for (String tag : tagsRaw.split(",")) {
            String t = tag.trim(); if (t.isEmpty()) continue;
            tagRepo.save(BoardTag.builder().postId(postId).tagName(t).build());
        }
    }

    private void saveLinks(Integer postId, boolean isGear, String[] names, String[] urls) {
        if (!isGear || names == null || urls == null) return;
        int max = Math.min(names.length, Math.min(urls.length, 3));
        for (int i = 0; i < max; i++) {
            String n = names[i].trim(), u = urls[i].trim();
            if (!n.isEmpty() && !u.isEmpty())
                linkRepo.save(BoardLink.builder().postId(postId).linkName(n).linkUrl(u).build());
        }
    }
}
