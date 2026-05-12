package com.polmate.controller;

import com.polmate.service.BoardService;
import lombok.RequiredArgsConstructor;
import org.json.JSONArray;
import org.json.JSONObject;
import org.springframework.web.bind.annotation.*;

import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import jakarta.servlet.http.HttpSession;
import java.io.IOException;
import java.sql.Timestamp;
import java.text.SimpleDateFormat;
import java.util.*;

@RestController
@RequestMapping("/board")
@RequiredArgsConstructor
public class BoardController {

    private static final SimpleDateFormat DATE_FMT = new SimpleDateFormat("yyyy.MM.dd");
    static { DATE_FMT.setTimeZone(TimeZone.getTimeZone("Asia/Seoul")); }

    private final BoardService boardService;

    @GetMapping
    public void doGet(@RequestParam(defaultValue = "list") String action,
                      @RequestParam(required = false) String id,
                      @RequestParam(required = false) String category,
                      @RequestParam(required = false) String sort,
                      @RequestParam(required = false, defaultValue = "") String keyword,
                      HttpServletResponse res, HttpSession session) throws IOException {
        res.setContentType("application/json;charset=UTF-8");
        String loginUser = getLoginUser(session, res);
        if (loginUser == null) return;
        switch (action) {
            case "list":   handleList(res, loginUser, category, sort, keyword); break;
            case "detail": handleDetail(res, loginUser, id);                   break;
            default: res.getWriter().write("{\"error\":\"알 수 없는 action\"}");
        }
    }

    @PostMapping
    public void doPost(@RequestParam(defaultValue = "") String action,
                       HttpServletRequest req, HttpServletResponse res, HttpSession session) throws IOException {
        res.setContentType("application/json;charset=UTF-8");
        String loginUser = getLoginUser(session, res);
        if (loginUser == null) return;
        switch (action) {
            case "write":         handleWrite(req, res, loginUser);         break;
            case "edit":          handleEdit(req, res, loginUser);          break;
            case "delete":        handleDelete(req, res, loginUser);        break;
            case "comment":       handleComment(req, res, loginUser);       break;
            case "deleteComment": handleDeleteComment(req, res, loginUser); break;
            case "like":          handleLike(req, res, loginUser);          break;
            default: res.getWriter().write("{\"error\":\"알 수 없는 action\"}");
        }
    }

    private void handleList(HttpServletResponse res, String loginUser,
                            String category, String sort, String keyword) throws IOException {
        try {
            JSONArray arr = new JSONArray();
            for (Map<String, Object> row : boardService.list(loginUser, category, sort, keyword)) {
                boolean anon = Integer.valueOf(1).equals(row.get("anonymous"));
                int postId = num(row.get("post_id"));
                JSONObject p = new JSONObject();
                p.put("id", postId); p.put("cat", nvl((String) row.get("category")));
                p.put("title", nvl((String) row.get("title")));
                String content = (String) row.get("content");
                p.put("preview", content != null && content.length() > 80 ? content.substring(0, 80) + "..." : nvl(content));
                p.put("views", num(row.get("view_count"))); p.put("likes", num(row.get("like_count")));
                p.put("commentCount", num(row.get("comment_count")));
                p.put("hot", num(row.get("like_count")) >= 20);
                p.put("anonymous", anon ? 1 : 0);
                p.put("userId",     anon ? "" : nvl((String) row.get("user_id")));
                p.put("author",     anon ? "익명" : nvl((String) row.get("user_name")));
                p.put("authorRank", anon ? "" : nvl((String) row.get("user_rank")));
                p.put("isMine", loginUser.equals(row.get("user_id")));
                Object ts = row.get("created_at");
                p.put("date", ts instanceof Timestamp ? DATE_FMT.format((Timestamp) ts) : "");
                arr.put(p);
            }
            res.getWriter().write(arr.toString());
        } catch (Exception e) {
            e.printStackTrace(); res.getWriter().write("{\"error\":\"목록 조회 중 오류\"}");
        }
    }

    private void handleDetail(HttpServletResponse res, String loginUser, String idStr) throws IOException {
        if (idStr == null || idStr.isEmpty()) { res.getWriter().write("{\"error\":\"id가 필요합니다.\"}"); return; }
        try {
            int postId = Integer.parseInt(idStr);
            Optional<Map<String, Object>> opt = boardService.detail(postId, loginUser);
            if (opt.isEmpty()) { res.getWriter().write("{\"error\":\"게시글을 찾을 수 없습니다.\"}"); return; }
            Map<String, Object> row = opt.get();
            boolean anon = Integer.valueOf(1).equals(row.get("anonymous"));
            JSONObject p = new JSONObject();
            p.put("id",        num(row.get("post_id")));
            p.put("cat",       nvl((String) row.get("category")));
            p.put("title",     nvl((String) row.get("title")));
            p.put("content",   nvl((String) row.get("content")));
            p.put("views",     num(row.get("view_count")));
            p.put("likes",     num(row.get("like_count")));
            p.put("anonymous", anon ? 1 : 0);
            p.put("userId",    anon ? "" : nvl((String) row.get("user_id")));
            p.put("author",    anon ? "익명" : nvl((String) row.get("user_name")));
            p.put("authorRank", anon ? "" : nvl((String) row.get("user_rank")));
            p.put("authorOrg",  anon ? "" : nvl((String) row.get("user_org")));
            p.put("isMine", loginUser.equals(row.get("user_id")));
            Object ts = row.get("created_at");
            p.put("date", ts instanceof Timestamp ? DATE_FMT.format((Timestamp) ts) : "");
            p.put("liked", Boolean.TRUE.equals(row.get("liked")));

            // tags
            JSONArray tags = new JSONArray();
            @SuppressWarnings("unchecked")
            List<String> tagList = (List<String>) row.get("tags");
            if (tagList != null) tagList.forEach(tags::put);
            p.put("tags", tags);

            // links
            JSONArray links = new JSONArray();
            @SuppressWarnings("unchecked")
            List<Map<String, Object>> linkList = (List<Map<String, Object>>) row.get("links");
            if (linkList != null) {
                for (Map<String, Object> lk : linkList) {
                    JSONObject l = new JSONObject();
                    l.put("name", nvl((String) lk.get("link_name")));
                    l.put("url",  nvl((String) lk.get("link_url")));
                    links.put(l);
                }
            }
            p.put("links", links);

            // comments
            JSONArray comments = new JSONArray();
            @SuppressWarnings("unchecked")
            List<Map<String, Object>> cmtList = (List<Map<String, Object>>) row.get("comments");
            if (cmtList != null) {
                for (Map<String, Object> cm : cmtList) {
                    JSONObject c = new JSONObject();
                    c.put("id",     num(cm.get("comment_id")));
                    c.put("author", nvl((String) cm.get("user_name")));
                    c.put("rank",   nvl((String) cm.get("user_rank")));
                    c.put("userId", nvl((String) cm.get("user_id")));
                    c.put("text",   nvl((String) cm.get("content")));
                    c.put("likes",  num(cm.get("like_count")));
                    c.put("isMine", loginUser.equals(cm.get("user_id")));
                    Object cts = cm.get("created_at");
                    c.put("time",   cts instanceof Timestamp ? relativeTime((Timestamp) cts) : "");
                    comments.put(c);
                }
            }
            p.put("comments", comments);
            res.getWriter().write(p.toString());
        } catch (NumberFormatException e) {
            res.getWriter().write("{\"error\":\"잘못된 id\"}");
        } catch (Exception e) {
            e.printStackTrace(); res.getWriter().write("{\"error\":\"상세 조회 중 오류\"}");
        }
    }

    private void handleWrite(HttpServletRequest req, HttpServletResponse res, String loginUser) throws IOException {
        String category = req.getParameter("category"); String title = req.getParameter("title");
        String content  = req.getParameter("content");  String tagsRaw = req.getParameter("tags");
        int anonymous = "1".equals(req.getParameter("anonymous")) ? 1 : 0;
        if (category == null || category.isEmpty() || title == null || title.trim().isEmpty()
                || content == null || content.trim().isEmpty()) {
            res.getWriter().write("{\"success\":false,\"error\":\"필수 항목을 모두 입력하세요.\"}"); return;
        }
        try {
            int newId = boardService.write(loginUser, category, title, content, anonymous, tagsRaw,
                req.getParameterValues("linkNames"), req.getParameterValues("linkUrls"));
            res.getWriter().write("{\"success\":true,\"postId\":" + newId + "}");
        } catch (Exception e) {
            e.printStackTrace(); res.getWriter().write("{\"success\":false,\"error\":\"게시글 등록 중 오류\"}");
        }
    }

    private void handleEdit(HttpServletRequest req, HttpServletResponse res, String loginUser) throws IOException {
        String idStr = req.getParameter("postId"); String title = req.getParameter("title");
        String content = req.getParameter("content"); String tagsRaw = req.getParameter("tags");
        int anonymous = "1".equals(req.getParameter("anonymous")) ? 1 : 0;
        if (idStr == null || title == null || title.trim().isEmpty() || content == null || content.trim().isEmpty()) {
            res.getWriter().write("{\"success\":false,\"error\":\"필수 항목을 모두 입력하세요.\"}"); return;
        }
        try {
            boolean ok = boardService.edit(loginUser, Integer.parseInt(idStr), title, content, anonymous, tagsRaw,
                req.getParameterValues("linkNames"), req.getParameterValues("linkUrls"));
            res.getWriter().write("{\"success\":" + ok + (ok ? "" : ",\"error\":\"수정 권한이 없습니다.\"") + "}");
        } catch (Exception e) {
            e.printStackTrace(); res.getWriter().write("{\"success\":false,\"error\":\"수정 중 오류\"}");
        }
    }

    private void handleDelete(HttpServletRequest req, HttpServletResponse res, String loginUser) throws IOException {
        String idStr = req.getParameter("postId");
        if (idStr == null) { res.getWriter().write("{\"success\":false,\"error\":\"postId 필요\"}"); return; }
        try {
            boolean ok = boardService.delete(loginUser, Integer.parseInt(idStr));
            res.getWriter().write("{\"success\":" + ok + (ok ? "" : ",\"error\":\"삭제 권한이 없습니다.\"") + "}");
        } catch (Exception e) {
            e.printStackTrace(); res.getWriter().write("{\"success\":false,\"error\":\"삭제 중 오류\"}");
        }
    }

    private void handleComment(HttpServletRequest req, HttpServletResponse res, String loginUser) throws IOException {
        String idStr = req.getParameter("postId"); String content = req.getParameter("content");
        if (idStr == null || content == null || content.trim().isEmpty()) {
            res.getWriter().write("{\"success\":false,\"error\":\"내용을 입력하세요.\"}"); return;
        }
        try {
            boardService.addComment(loginUser, Integer.parseInt(idStr), content);
            res.getWriter().write("{\"success\":true}");
        } catch (Exception e) {
            e.printStackTrace(); res.getWriter().write("{\"success\":false,\"error\":\"댓글 등록 중 오류\"}");
        }
    }

    private void handleDeleteComment(HttpServletRequest req, HttpServletResponse res, String loginUser) throws IOException {
        String idStr = req.getParameter("commentId");
        if (idStr == null) { res.getWriter().write("{\"success\":false}"); return; }
        try {
            boolean ok = boardService.deleteComment(loginUser, Integer.parseInt(idStr));
            res.getWriter().write("{\"success\":" + ok + (ok ? "" : ",\"error\":\"삭제 권한이 없습니다.\"") + "}");
        } catch (Exception e) {
            e.printStackTrace(); res.getWriter().write("{\"success\":false,\"error\":\"댓글 삭제 중 오류\"}");
        }
    }

    private void handleLike(HttpServletRequest req, HttpServletResponse res, String loginUser) throws IOException {
        String targetType = req.getParameter("targetType"); String targetIdStr = req.getParameter("targetId");
        if (targetType == null || targetIdStr == null) { res.getWriter().write("{\"success\":false}"); return; }
        if (!"post".equals(targetType) && !"comment".equals(targetType)) { res.getWriter().write("{\"success\":false}"); return; }
        try {
            boolean liked = boardService.toggleLike(loginUser, targetType, Integer.parseInt(targetIdStr));
            res.getWriter().write("{\"success\":true,\"liked\":" + liked + "}");
        } catch (Exception e) {
            e.printStackTrace(); res.getWriter().write("{\"success\":false}");
        }
    }

    private String relativeTime(Timestamp ts) {
        long diff = System.currentTimeMillis() - ts.getTime();
        if (diff < 60000)    return "방금";
        if (diff < 3600000)  return (diff / 60000) + "분 전";
        if (diff < 86400000) return (diff / 3600000) + "시간 전";
        return DATE_FMT.format(ts);
    }

    private String nvl(String s) { return s == null ? "" : s; }
    private int num(Object o)    { return o == null ? 0 : ((Number) o).intValue(); }

    private String getLoginUser(HttpSession session, HttpServletResponse res) throws IOException {
        String u = session != null ? (String) session.getAttribute("loginUser") : null;
        if (u == null) res.getWriter().write("{\"error\":\"로그인이 필요합니다.\"}");
        return u;
    }
}
