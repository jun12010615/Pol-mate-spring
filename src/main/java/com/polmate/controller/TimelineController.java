package com.polmate.controller;

import com.polmate.service.TimelineService;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import jakarta.servlet.http.HttpServletResponse;
import jakarta.servlet.http.HttpSession;
import java.io.IOException;
import java.util.Map;

@RestController
@RequestMapping("/timelineApi")
@RequiredArgsConstructor
public class TimelineController {

    private final TimelineService timelineService;
    private final ObjectMapper objectMapper;

    @GetMapping
    public void doGet(@RequestParam(defaultValue = "get") String action,
                      @RequestParam(required = false) String caseId,
                      HttpServletResponse res, HttpSession session) throws IOException {
        res.setContentType("application/json;charset=UTF-8");
        String userId = getLoginUser(session, res);
        if (userId == null) return;

        try {
            Map<String, Object> payload;
            if ("get".equals(action)) {
                payload = timelineService.getTimelineForCase(caseId, userId);
            } else if ("rebuild".equals(action)) {
                payload = timelineService.startRebuildForCase(caseId, userId);
            } else {
                res.getWriter().write("{\"success\":false,\"error\":\"알 수 없는 action\"}");
                return;
            }
            res.getWriter().write(objectMapper.writeValueAsString(payload));
        } catch (Exception e) {
            e.printStackTrace();
            res.getWriter().write("{\"success\":false,\"error\":\"타임라인 API 오류\"}");
        }
    }

    private String getLoginUser(HttpSession session, HttpServletResponse res) throws IOException {
        String u = session != null ? (String) session.getAttribute("loginUser") : null;
        if (u == null) {
            res.getWriter().write("{\"success\":false,\"error\":\"로그인이 필요합니다.\"}");
        }
        return u;
    }
}
