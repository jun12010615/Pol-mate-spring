package com.polmate.controller;

import com.google.gson.Gson;
import com.polmate.service.DepartmentService;
import com.polmate.service.UserService;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.*;

import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import jakarta.servlet.http.HttpSession;
import java.io.IOException;
import java.util.*;

@RestController
@RequestMapping("/mypage")
@RequiredArgsConstructor
public class MypageController {

    private final UserService userService;
    private final DepartmentService deptService;
    private final Gson gson = new Gson();

    @GetMapping
    public void doGet(@RequestParam(defaultValue = "") String action,
                      @RequestParam(required = false) String org,
                      @RequestParam(required = false) String period,
                      HttpServletResponse res, HttpSession session) throws IOException {
        res.setContentType("application/json; charset=UTF-8");
        String userId = getLoginUser(session, res);
        if (userId == null) return;

        switch (action) {
            case "load": {
                Map<String, Object> profile = userService.getProfile(userId);
                Map<String, Object> settings = userService.getSettings(userId);
                Map<String, Object> stats = userService.getStats(userId);
                Map<String, Object> result = new HashMap<>();
                result.put("user",     sanitizeProfile(profile));
                result.put("stats",    stats);
                result.put("settings", settings);
                res.getWriter().print(gson.toJson(result));
                break;
            }
            case "getDepts": {
                if (org == null || org.trim().isEmpty()) { res.getWriter().print("[]"); return; }
                res.getWriter().print(gson.toJson(deptService.getByOrg(org.trim())));
                break;
            }
            case "history": {
                List<Map<String, Object>> history = userService.getHistory(userId);
                Map<String, Object> histResult = new HashMap<>();
                histResult.put("history", history);
                res.getWriter().print(gson.toJson(histResult));
                break;
            }
            case "stats": {
                String p = (period != null && !period.isEmpty()) ? period : "all";
                res.getWriter().print(gson.toJson(userService.getStatsForPeriod(userId, p)));
                break;
            }
            default:
                res.setStatus(400);
                res.getWriter().print("{\"success\":false,\"message\":\"알 수 없는 action\"}");
        }
    }

    @PostMapping
    public void doPost(@RequestParam(defaultValue = "") String action,
                       HttpServletRequest req, HttpServletResponse res, HttpSession session) throws IOException {
        res.setContentType("application/json; charset=UTF-8");
        String userId = getLoginUser(session, res);
        if (userId == null) return;

        switch (action) {
            case "saveSettings": {
                boolean nc = "true".equals(req.getParameter("notifContradiction"));
                boolean nr = "true".equals(req.getParameter("notifRelation"));
                boolean nm = "true".equals(req.getParameter("nightMode"));
                boolean ok = userService.saveSettings(userId, nc, nr, nm);
                res.getWriter().print("{\"success\":" + ok + "}");
                break;
            }
            case "updateProfile": {
                String name  = nvl(req.getParameter("userName"),  "");
                String rank  = nvl(req.getParameter("userRank"),  "");
                String org   = nvl(req.getParameter("userOrg"),   "");
                String phone = nvl(req.getParameter("userPhone"), "");
                String deptStr = req.getParameter("deptId");
                Integer deptId = null;
                try { if (deptStr != null && !deptStr.isEmpty()) deptId = Integer.parseInt(deptStr); }
                catch (NumberFormatException ignored) {}
                boolean ok = userService.updateProfile(userId, name, rank, org, phone, deptId);
                if (ok) {
                    session.setAttribute("userName", name);
                    session.setAttribute("userRank", rank);
                    session.setAttribute("userOrg",  org);
                    session.setAttribute("userPhone", phone);
                }
                res.getWriter().print("{\"success\":" + ok + "}");
                break;
            }
            case "changePassword": {
                String curPw  = nvl(req.getParameter("curPw"),  "");
                String newPw  = nvl(req.getParameter("newPw"),  "");
                String newPwCf = nvl(req.getParameter("newPwCf"), "");
                if (curPw.isEmpty() || newPw.isEmpty() || newPwCf.isEmpty()) {
                    res.getWriter().print("{\"success\":false,\"message\":\"모든 항목을 입력해 주세요.\"}"); return;
                }
                if (!newPw.equals(newPwCf)) {
                    res.getWriter().print("{\"success\":false,\"message\":\"새 비밀번호가 일치하지 않습니다.\"}"); return;
                }
                if (!userService.checkPassword(userId, curPw)) {
                    res.getWriter().print("{\"success\":false,\"message\":\"현재 비밀번호가 올바르지 않습니다.\"}"); return;
                }
                boolean ok = userService.changePassword(userId, newPw);
                res.getWriter().print("{\"success\":" + ok + "}");
                break;
            }
            case "withdraw": {
                String pw = nvl(req.getParameter("userPw"), "");
                if (!userService.checkPassword(userId, pw)) {
                    res.getWriter().print("{\"success\":false,\"message\":\"비밀번호가 올바르지 않습니다.\"}"); return;
                }
                boolean ok = userService.withdraw(userId);
                if (ok) session.invalidate();
                res.getWriter().print("{\"success\":" + ok + "}");
                break;
            }
            case "logout": {
                session.invalidate();
                res.getWriter().print("{\"success\":true,\"redirect\":\"/login\"}");
                break;
            }
            default:
                res.setStatus(400);
                res.getWriter().print("{\"success\":false,\"message\":\"알 수 없는 action\"}");
        }
    }

    private Map<String, Object> sanitizeProfile(Map<String, Object> profile) {
        Map<String, Object> safe = new LinkedHashMap<>(profile);
        safe.remove("user_pw");
        return safe;
    }

    private String nvl(String s, String def) { return (s == null || s.isEmpty()) ? def : s; }

    private String getLoginUser(HttpSession session, HttpServletResponse res) throws IOException {
        String u = session != null ? (String) session.getAttribute("loginUser") : null;
        if (u == null) res.getWriter().print("{\"error\":\"로그인이 필요합니다.\"}");
        return u;
    }
}
