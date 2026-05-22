package com.polmate.controller;

import com.polmate.service.SearchService;
import lombok.RequiredArgsConstructor;
import org.json.JSONObject;
import org.springframework.web.bind.annotation.*;

import jakarta.servlet.http.HttpServletResponse;
import jakarta.servlet.http.HttpSession;
import java.io.IOException;
import java.util.Map;

@RestController
@RequestMapping("/searchApi")
@RequiredArgsConstructor
public class SearchController {

    private final SearchService searchService;

    @GetMapping
    public void doGet(@RequestParam(defaultValue = "") String q,
                      HttpServletResponse res, HttpSession session) throws IOException {
        res.setContentType("application/json;charset=UTF-8");
        String loginUser = (String) session.getAttribute("loginUser");
        if (loginUser == null) {
            res.getWriter().write("{\"error\":\"로그인이 필요합니다.\"}");
            return;
        }
        String trimmed = q.trim();
        if (trimmed.length() < 2) {
            res.getWriter().write("{\"cases\":[],\"transcripts\":[],\"posts\":[]}");
            return;
        }
        Map<String, Object> result = searchService.search(loginUser, trimmed);
        res.getWriter().write(new JSONObject(result).toString());
    }
}
