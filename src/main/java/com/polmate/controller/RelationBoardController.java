package com.polmate.controller;

import com.polmate.service.RelationBoardService;
import lombok.RequiredArgsConstructor;
import org.json.JSONArray;
import org.json.JSONObject;
import org.springframework.web.bind.annotation.*;

import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import jakarta.servlet.http.HttpSession;
import java.io.*;
import java.sql.Timestamp;
import java.util.Map;
import java.util.Optional;

@RestController
@RequestMapping("/boardApi")
@RequiredArgsConstructor
public class RelationBoardController {

    private final RelationBoardService boardService;

    @GetMapping
    public void doGet(@RequestParam(defaultValue = "load") String action,
                      @RequestParam(required = false) String caseId,
                      HttpServletResponse res, HttpSession session) throws IOException {
        res.setContentType("application/json;charset=UTF-8");
        String loginUser = getLoginUser(session, res);
        if (loginUser == null) return;
        switch (action) {
            case "load":       handleLoad(res, loginUser, caseId);   break;
            case "listBoards": handleListBoards(res, loginUser);     break;
            default: res.getWriter().write("{\"error\":\"알 수 없는 action\"}");
        }
    }

    @PostMapping
    public void doPost(@RequestParam(defaultValue = "") String action,
                       @RequestParam(required = false) String caseId,
                       HttpServletRequest request, HttpServletResponse res, HttpSession session) throws IOException {
        res.setContentType("application/json;charset=UTF-8");
        String loginUser = getLoginUser(session, res);
        if (loginUser == null) return;
        switch (action) {
            case "save":   handleSave(request, res, loginUser); break;
            case "delete": handleDelete(res, loginUser, caseId); break;
            default: res.getWriter().write("{\"error\":\"알 수 없는 action\"}");
        }
    }

    private void handleLoad(HttpServletResponse res, String loginUser, String caseId) throws IOException {
        if (isEmpty(caseId)) { res.getWriter().write("{\"error\":\"caseId가 필요합니다.\"}"); return; }
        try {
            Optional<Map<String, Object>> opt = boardService.load(caseId, loginUser);
            if (opt.isEmpty()) {
                res.getWriter().write("{\"success\":false,\"boardExists\":false,\"message\":\"저장된 보드가 없습니다.\"}"); return;
            }
            Map<String, Object> row = opt.get();
            JSONObject result = new JSONObject();
            result.put("success",     true);
            result.put("boardExists", true);
            result.put("boardId",     num(row.get("board_id")));
            result.put("caseId",      nvl((String) row.get("case_id")));
            result.put("caseName",    nvl((String) row.get("case_name")));
            result.put("boardJson",   nvl((String) row.get("board_json")));
            result.put("creatorName", nvl((String) row.get("creator_name")));
            result.put("updaterName", nvl((String) row.get("updater_name")));
            result.put("createdAt",   fmtTs(row.get("created_at")));
            result.put("updatedAt",   fmtTs(row.get("updated_at")));
            res.getWriter().write(result.toString());
        } catch (Exception e) {
            e.printStackTrace(); res.getWriter().write("{\"error\":\"보드 조회 중 오류가 발생했습니다.\"}");
        }
    }

    private void handleListBoards(HttpServletResponse res, String loginUser) throws IOException {
        try {
            JSONArray arr = new JSONArray();
            for (Map<String, Object> row : boardService.listBoards(loginUser)) {
                JSONObject b = new JSONObject();
                b.put("boardId",     num(row.get("board_id")));
                b.put("caseId",      nvl((String) row.get("case_id")));
                b.put("caseName",    nvl((String) row.get("case_name")));
                b.put("status",      nvl((String) row.get("status"), "진행중"));
                b.put("updatedAt",   fmtTs(row.get("updated_at")));
                b.put("updaterName", nvl((String) row.get("updater_name")));
                try {
                    JSONObject bj = new JSONObject(nvl((String) row.get("board_json"), "{}"));
                    b.put("personCount", bj.optJSONArray("persons") != null ? bj.optJSONArray("persons").length() : 0);
                    b.put("edgeCount",   bj.optJSONArray("edges")   != null ? bj.optJSONArray("edges").length()   : 0);
                } catch (Exception ignored) { b.put("personCount", 0); b.put("edgeCount", 0); }
                arr.put(b);
            }
            res.getWriter().write(new JSONObject().put("success", true).put("boards", arr).toString());
        } catch (Exception e) {
            e.printStackTrace(); res.getWriter().write("{\"error\":\"보드 목록 조회 중 오류가 발생했습니다.\"}");
        }
    }

    private void handleSave(HttpServletRequest request, HttpServletResponse res, String loginUser) throws IOException {
        StringBuilder sb = new StringBuilder();
        try (BufferedReader br = request.getReader()) {
            String line; while ((line = br.readLine()) != null) sb.append(line);
        }
        JSONObject body;
        try { body = new JSONObject(sb.toString()); }
        catch (Exception e) { res.getWriter().write("{\"error\":\"요청 JSON이 올바르지 않습니다.\"}"); return; }
        try {
            String caseId    = body.optString("caseId",    "");
            String boardJson = body.optString("boardJson", "{}");
            boolean isUpdate = body.optBoolean("isUpdate", false);
            if (isEmpty(caseId)) { res.getWriter().write("{\"error\":\"caseId가 필요합니다.\"}"); return; }
            Map<String, Object> result = boardService.save(loginUser, caseId, boardJson, isUpdate);
            res.getWriter().write(new JSONObject(result).toString());
        } catch (Exception e) {
            e.printStackTrace(); res.getWriter().write("{\"error\":\"보드 저장 중 오류가 발생했습니다.\"}");
        }
    }

    private void handleDelete(HttpServletResponse res, String loginUser, String caseId) throws IOException {
        if (isEmpty(caseId)) { res.getWriter().write("{\"error\":\"caseId가 필요합니다.\"}"); return; }
        try {
            boolean ok = boardService.delete(loginUser, caseId);
            res.getWriter().write(ok ? "{\"success\":true,\"message\":\"보드가 삭제됐습니다.\"}"
                                     : "{\"error\":\"접근 권한이 없습니다.\"}");
        } catch (Exception e) {
            e.printStackTrace(); res.getWriter().write("{\"error\":\"보드 삭제 중 오류가 발생했습니다.\"}");
        }
    }

    private String fmtTs(Object o) {
        if (o instanceof Timestamp) return ((Timestamp) o).toString().substring(0, 16);
        return "";
    }
    private String nvl(String s, String def) { return (s == null || s.isEmpty()) ? def : s; }
    private String nvl(String s)             { return nvl(s, ""); }
    private boolean isEmpty(String s)        { return s == null || s.trim().isEmpty(); }
    private int num(Object o)                { return o == null ? 0 : ((Number) o).intValue(); }

    private String getLoginUser(HttpSession session, HttpServletResponse res) throws IOException {
        String u = session != null ? (String) session.getAttribute("loginUser") : null;
        if (u == null) res.getWriter().write("{\"error\":\"로그인이 필요합니다.\"}");
        return u;
    }
}
