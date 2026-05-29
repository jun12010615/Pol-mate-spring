package com.polmate.controller.system;

import com.polmate.service.AccessLogService;
import lombok.RequiredArgsConstructor;
import org.json.JSONArray;
import org.json.JSONObject;
import org.springframework.web.bind.annotation.*;

import jakarta.servlet.http.HttpServletResponse;
import jakarta.servlet.http.HttpSession;
import java.io.IOException;
import java.sql.Timestamp;
import java.text.SimpleDateFormat;
import java.util.List;
import java.util.Map;
import java.util.TimeZone;

@RestController
@RequestMapping("/accessLogApi")
@RequiredArgsConstructor
public class AccessLogController {

    private static final SimpleDateFormat DT_FMT = new SimpleDateFormat("yyyy.MM.dd HH:mm:ss");
    static { DT_FMT.setTimeZone(TimeZone.getTimeZone("Asia/Seoul")); }

    private final AccessLogService accessLogService;

    @GetMapping
    public void doGet(@RequestParam(defaultValue = "list") String action,
                      @RequestParam(defaultValue = "")  String type,
                      @RequestParam(defaultValue = "")  String from,
                      @RequestParam(defaultValue = "")  String to,
                      @RequestParam(defaultValue = "0")  int page,
                      @RequestParam(defaultValue = "50") int size,
                      HttpServletResponse res, HttpSession session) throws IOException {
        res.setContentType("application/json;charset=UTF-8");
        String loginUser = (String) session.getAttribute("loginUser");
        if (loginUser == null) { res.getWriter().write("{\"error\":\"로그인이 필요합니다.\"}"); return; }

        Boolean isAdmin = (Boolean) session.getAttribute("isAdmin");
        if (isAdmin == null) isAdmin = false;

        if ("stats".equals(action)) {
            handleStats(res, loginUser, isAdmin);
        } else {
            handleList(res, loginUser, isAdmin, type, from, to, page, Math.min(size, 100));
        }
    }

    private void handleList(HttpServletResponse res, String loginUser, boolean isAdmin,
                            String type, String from, String to,
                            int page, int size) throws IOException {
        try {
            List<Map<String, Object>> rows = accessLogService.list(loginUser, isAdmin, type, from, to, page, size);
            JSONArray arr = new JSONArray();
            for (Map<String, Object> r : rows) {
                JSONObject o = new JSONObject();
                o.put("logId",      r.get("log_id"));
                o.put("userId",     nvl(r.get("user_id")));
                o.put("userName",   nvl(r.get("user_name")));
                o.put("targetType", nvl(r.get("target_type")));
                o.put("targetId",   nvl(r.get("target_id")));
                o.put("targetName", nvl(r.get("target_name")));
                o.put("ip",         nvl(r.get("ip_address")));
                Object ts = r.get("accessed_at");
                o.put("accessedAt", ts instanceof Timestamp ? DT_FMT.format((Timestamp) ts) : String.valueOf(ts));
                arr.put(o);
            }
            res.getWriter().write(arr.toString());
        } catch (Exception e) {
            e.printStackTrace();
            res.getWriter().write("{\"error\":\"로그 조회 중 오류가 발생했습니다.\"}");
        }
    }

    private void handleStats(HttpServletResponse res, String loginUser, boolean isAdmin) throws IOException {
        try {
            Map<String, Object> stats = accessLogService.stats(loginUser, isAdmin);
            JSONObject o = new JSONObject();
            Object today = stats.get("today"); o.put("today", today != null ? ((Number) today).longValue() : 0);
            Object week  = stats.get("week");  o.put("week",  week  != null ? ((Number) week).longValue()  : 0);
            res.getWriter().write(o.toString());
        } catch (Exception e) {
            e.printStackTrace();
            res.getWriter().write("{\"today\":0,\"week\":0}");
        }
    }

    private String nvl(Object o) { return o == null ? "" : o.toString(); }
}
