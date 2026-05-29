package com.polmate.controller.system;

import com.polmate.service.UserService;
import lombok.RequiredArgsConstructor;
import org.json.JSONArray;
import org.json.JSONObject;
import org.springframework.web.bind.annotation.*;

import jakarta.servlet.http.HttpServletResponse;
import jakarta.servlet.http.HttpSession;
import java.io.IOException;
import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/adminApi")
@RequiredArgsConstructor
public class AdminController {

    private final UserService userService;

    /* ── GET ──────────────────────────────────────────── */
    @GetMapping
    public void doGet(@RequestParam(defaultValue = "userList") String action,
                      HttpServletResponse res, HttpSession session) throws IOException {
        res.setContentType("application/json;charset=UTF-8");

        if (!isAdmin(session, res)) return;
        String loginUser = (String) session.getAttribute("loginUser");

        if ("userList".equals(action)) {
            handleUserList(res, loginUser);
        } else {
            res.getWriter().write("{\"error\":\"알 수 없는 action입니다.\"}");
        }
    }

    /* ── POST ─────────────────────────────────────────── */
    @PostMapping
    public void doPost(@RequestParam(defaultValue = "")      String  action,
                       @RequestParam(defaultValue = "")      String  targetId,
                       @RequestParam(defaultValue = "false") boolean grant,
                       HttpServletResponse res, HttpSession session) throws IOException {
        res.setContentType("application/json;charset=UTF-8");

        if (!isAdmin(session, res)) return;
        String loginUser = (String) session.getAttribute("loginUser");

        if ("setAdmin".equals(action)) {
            handleSetAdmin(res, loginUser, targetId, grant);
        } else {
            res.getWriter().write("{\"error\":\"알 수 없는 action입니다.\"}");
        }
    }

    /* ── 핸들러 ───────────────────────────────────────── */

    /** 부서 내 사용자 목록 반환 */
    private void handleUserList(HttpServletResponse res, String loginUser) throws IOException {
        try {
            List<Map<String, Object>> users = userService.getDeptUsers(loginUser);
            JSONArray arr = new JSONArray();
            for (Map<String, Object> u : users) {
                JSONObject o = new JSONObject();
                o.put("userId",   nvl(u.get("user_id")));
                o.put("userName", nvl(u.get("user_name")));
                o.put("userRank", nvl(u.get("user_rank")));
                o.put("isAdmin",  toBoolean(u.get("is_admin")));
                o.put("isSelf",   loginUser.equals(nvl(u.get("user_id"))));
                arr.put(o);
            }
            res.getWriter().write(arr.toString());
        } catch (Exception e) {
            e.printStackTrace();
            res.getWriter().write("{\"error\":\"" + e.getMessage() + "\"}");
        }
    }

    /** 관리자 권한 부여 / 해제 */
    private void handleSetAdmin(HttpServletResponse res, String loginUser,
                                String targetId, boolean grant) throws IOException {
        try {
            if (targetId == null || targetId.trim().isEmpty()) {
                res.getWriter().write("{\"error\":\"대상 아이디가 없습니다.\"}");
                return;
            }
            // 자기 자신의 권한 해제 차단
            if (loginUser.equals(targetId) && !grant) {
                res.getWriter().write("{\"error\":\"자신의 관리자 권한은 해제할 수 없습니다.\"}");
                return;
            }
            boolean ok = userService.setAdminStatus(targetId, grant);
            if (ok) {
                res.getWriter().write("{\"ok\":true}");
            } else {
                res.getWriter().write("{\"error\":\"대상 사용자를 찾을 수 없습니다.\"}");
            }
        } catch (Exception e) {
            e.printStackTrace();
            res.getWriter().write("{\"error\":\"처리 중 오류가 발생했습니다.\"}");
        }
    }

    /* ── 공통 유틸 ────────────────────────────────────── */

    /** 관리자 여부 확인 — false 반환 시 이미 에러 응답 완료 */
    private boolean isAdmin(HttpSession session, HttpServletResponse res) throws IOException {
        String loginUser = (String) session.getAttribute("loginUser");
        if (loginUser == null) {
            res.getWriter().write("{\"error\":\"로그인이 필요합니다.\"}");
            return false;
        }
        Boolean isAdmin = (Boolean) session.getAttribute("isAdmin");
        if (isAdmin == null || !isAdmin) {
            res.getWriter().write("{\"error\":\"관리자 권한이 필요합니다.\"}");
            return false;
        }
        return true;
    }

    private String nvl(Object o) { return o == null ? "" : o.toString(); }

    /**
     * MySQL JDBC 드라이버는 TINYINT(1)을 Boolean으로 반환하는 경우가 있음.
     * Boolean / Number / String 모두 안전하게 처리.
     */
    private boolean toBoolean(Object val) {
        if (val == null)            return false;
        if (val instanceof Boolean) return (Boolean) val;
        if (val instanceof Number)  return ((Number) val).intValue() == 1;
        return "1".equals(val.toString()) || "true".equalsIgnoreCase(val.toString());
    }
}
