package com.polmate.controller;

import com.polmate.entity.Notification;
import com.polmate.service.NotificationService;
import com.polmate.service.UserService;
import lombok.RequiredArgsConstructor;
import org.json.JSONArray;
import org.json.JSONObject;
import org.springframework.web.bind.annotation.*;

import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import jakarta.servlet.http.HttpSession;
import java.io.IOException;
import java.text.SimpleDateFormat;
import java.util.List;
import java.util.TimeZone;

@RestController
@RequestMapping("/notifApi")
@RequiredArgsConstructor
public class NotificationController {

    private static final SimpleDateFormat DATE_FMT = new SimpleDateFormat("yyyy.MM.dd HH:mm");
    static { DATE_FMT.setTimeZone(TimeZone.getTimeZone("Asia/Seoul")); }
    private static final int PW_WARN_DAYS = 90;

    private final NotificationService notifService;
    private final UserService userService;

    @GetMapping
    public void doGet(@RequestParam(defaultValue = "list") String action,
                      HttpServletRequest req, HttpServletResponse res,
                      HttpSession session) throws IOException {
        res.setContentType("application/json;charset=UTF-8");
        String loginUser = getLoginUser(session, res);
        if (loginUser == null) return;

        switch (action) {
            case "list":        handleList(req, res, loginUser);   break;
            case "unreadCount": handleUnreadCount(res, loginUser); break;
            default: res.getWriter().write("{\"error\":\"알 수 없는 action\"}");
        }
    }

    @PostMapping
    public void doPost(@RequestParam(defaultValue = "") String action,
                       HttpServletRequest req, HttpServletResponse res,
                       HttpSession session) throws IOException {
        res.setContentType("application/json;charset=UTF-8");
        String loginUser = getLoginUser(session, res);
        if (loginUser == null) return;

        switch (action) {
            case "markRead":    handleMarkRead(req, res, loginUser);  break;
            case "markAllRead": handleMarkAllRead(res, loginUser);    break;
            default: res.getWriter().write("{\"error\":\"알 수 없는 action\"}");
        }
    }

    private void handleList(HttpServletRequest req, HttpServletResponse res, String loginUser) throws IOException {
        String typeFilter = nvl(req.getParameter("type"), "all");
        try {
            // 비밀번호 변경 권고 자동 알림
            Integer daysSince = userService.getDaysSincePasswordChange(loginUser);
            if (daysSince != null && daysSince >= PW_WARN_DAYS) {
                int recentWarn = notifService.countRecentByTypeAndTag(loginUser, "sys", "보안");
                if (recentWarn == 0) {
                    notifService.insert(loginUser, "sys", "보안",
                        "비밀번호 변경 권고",
                        daysSince + "일째 비밀번호를 변경하지 않으셨습니다. 보안을 위해 변경을 권장합니다.",
                        "mypage", true);
                }
            }
            List<Notification> list = notifService.list(loginUser, typeFilter);
            JSONArray arr = new JSONArray();
            for (Notification n : list) {
                JSONObject obj = new JSONObject();
                obj.put("id",          n.getNotifId());
                obj.put("type",        nvl(n.getType(), ""));
                obj.put("tag",         nvl(n.getTag(),  ""));
                obj.put("title",       nvl(n.getTitle(), ""));
                obj.put("description", nvl(n.getDescription(), ""));
                obj.put("link",        nvl(n.getLink(), ""));
                obj.put("isUnread",    n.isUnread());
                obj.put("isCritical",  n.isCritical());
                obj.put("time",        n.getCreatedAt() != null ? DATE_FMT.format(
                    java.sql.Timestamp.valueOf(n.getCreatedAt())) : "");
                arr.put(obj);
            }
            res.getWriter().write(arr.toString());
        } catch (Exception e) {
            e.printStackTrace();
            res.getWriter().write("{\"error\":\"알림 목록 조회 중 오류가 발생했습니다.\"}");
        }
    }

    private void handleUnreadCount(HttpServletResponse res, String loginUser) throws IOException {
        try {
            int count = notifService.unreadCount(loginUser);
            res.getWriter().write("{\"count\":" + count + "}");
        } catch (Exception e) {
            res.getWriter().write("{\"count\":0}");
        }
    }

    private void handleMarkRead(HttpServletRequest req, HttpServletResponse res, String loginUser) throws IOException {
        try {
            String idStr = req.getParameter("id");
            if (idStr == null) { res.getWriter().write("{\"success\":false}"); return; }
            boolean ok = notifService.markRead(loginUser, Integer.parseInt(idStr));
            res.getWriter().write("{\"success\":" + ok + "}");
        } catch (Exception e) {
            res.getWriter().write("{\"success\":false}");
        }
    }

    private void handleMarkAllRead(HttpServletResponse res, String loginUser) throws IOException {
        try {
            notifService.markAllRead(loginUser);
            res.getWriter().write("{\"success\":true}");
        } catch (Exception e) {
            res.getWriter().write("{\"success\":false}");
        }
    }

    private String nvl(String s, String def) { return (s == null || s.isEmpty()) ? def : s; }

    private String getLoginUser(HttpSession session, HttpServletResponse res) throws IOException {
        String u = session != null ? (String) session.getAttribute("loginUser") : null;
        if (u == null) res.getWriter().write("{\"error\":\"로그인이 필요합니다.\"}");
        return u;
    }
}
