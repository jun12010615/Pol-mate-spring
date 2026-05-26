package com.polmate.service;

import lombok.RequiredArgsConstructor;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;

import java.util.*;

@Service
@RequiredArgsConstructor
public class SearchService {

    private final JdbcTemplate jdbc;

    public Map<String, Object> search(String userId, String keyword) {
        String kw = "%" + keyword + "%";
        Map<String, Object> result = new LinkedHashMap<>();

        List<Map<String, Object>> cases = jdbc.queryForList(
            "SELECT c.case_id, c.case_name, c.suspect, c.charge, c.status " +
            "FROM cases c WHERE c.dept_id=(SELECT dept_id FROM users WHERE user_id=?) " +
            "AND (c.case_id LIKE ? OR c.case_name LIKE ? OR c.suspect LIKE ? OR c.charge LIKE ?) " +
            "ORDER BY c.updated_at DESC LIMIT 5",
            userId, kw, kw, kw, kw);

        List<Map<String, Object>> rawTranscripts = jdbc.queryForList(
            "SELECT t.transcript_id, t.case_id, c.case_name, t.stmt_name, t.stmt_type, t.original_text " +
            "FROM transcripts t JOIN cases c ON t.case_id=c.case_id " +
            "WHERE c.dept_id=(SELECT dept_id FROM users WHERE user_id=?) " +
            "AND (t.stmt_name LIKE ? OR t.original_text LIKE ?) " +
            "ORDER BY t.created_at DESC LIMIT 5",
            userId, kw, kw);

        List<Map<String, Object>> rawPosts = jdbc.queryForList(
            "SELECT p.post_id, p.title, p.content, u.user_name " +
            "FROM board_posts p JOIN users u ON p.user_id=u.user_id " +
            "WHERE p.title LIKE ? OR p.content LIKE ? " +
            "ORDER BY p.created_at DESC LIMIT 5",
            kw, kw);

        List<Map<String, Object>> transcripts = new ArrayList<>();
        for (Map<String, Object> t : rawTranscripts) {
            Map<String, Object> item = new LinkedHashMap<>();
            item.put("id",       t.get("transcript_id"));
            item.put("caseId",   t.get("case_id"));
            item.put("caseName", t.get("case_name"));
            item.put("stmtName", t.get("stmt_name"));
            item.put("stmtType", t.get("stmt_type"));
            item.put("snippet",  extractSnippet((String) t.get("original_text"), keyword, 80));
            transcripts.add(item);
        }

        List<Map<String, Object>> posts = new ArrayList<>();
        for (Map<String, Object> p : rawPosts) {
            Map<String, Object> item = new LinkedHashMap<>();
            item.put("id",      p.get("post_id"));
            item.put("title",   p.get("title"));
            item.put("author",  p.get("user_name"));
            item.put("snippet", extractSnippet((String) p.get("content"), keyword, 80));
            posts.add(item);
        }

        result.put("cases",       cases);
        result.put("transcripts", transcripts);
        result.put("posts",       posts);
        return result;
    }

    private String extractSnippet(String text, String keyword, int windowSize) {
        if (text == null || text.isEmpty()) return "";
        int idx = text.toLowerCase().indexOf(keyword.toLowerCase());
        if (idx < 0) return text.length() > windowSize ? text.substring(0, windowSize) + "..." : text;
        int start = Math.max(0, idx - 20);
        int end = Math.min(text.length(), start + windowSize);
        String snippet = text.substring(start, end);
        if (start > 0) snippet = "..." + snippet;
        if (end < text.length()) snippet += "...";
        return snippet;
    }
}
