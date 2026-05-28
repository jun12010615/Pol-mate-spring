package com.polmate.controller;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.web.bind.annotation.*;

import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import jakarta.servlet.http.HttpSession;
import java.io.*;
import java.net.HttpURLConnection;
import java.net.URL;
import java.nio.charset.StandardCharsets;

/**
 * polmate_serv.py의 /analyze/start 및 /analyze/job 엔드포인트를 Spring Boot에서 프록시.
 * 프론트엔드가 직접 Ollama를 호출하지 않고 여기를 거쳐 Flask 서버를 사용하도록 한다.
 */
@RestController
@RequestMapping("/aiApi")
public class AnalyzeProxyController {

    @Value("${polmate.serv.base-url}")
    private String servBaseUrl;

    /** POST /aiApi/analyze/start  →  polmate_serv.py /analyze/start */
    @PostMapping("/analyze/start")
    public void analyzeStart(HttpServletRequest req, HttpServletResponse res,
                             HttpSession session) throws IOException {
        res.setContentType("application/json;charset=UTF-8");

        String userId = (session != null) ? (String) session.getAttribute("loginUser") : null;
        if (userId == null) {
            res.getWriter().write("{\"success\":false,\"error\":\"로그인이 필요합니다.\"}");
            return;
        }

        // 요청 바디 읽기
        StringBuilder sb = new StringBuilder();
        try (BufferedReader br = req.getReader()) {
            String line;
            while ((line = br.readLine()) != null) sb.append(line);
        }

        // polmate_serv.py로 포워딩
        String result = callFlask("/analyze/start", sb.toString());
        if (result == null) {
            res.getWriter().write("{\"success\":false,\"error\":\"AI 서버에 연결할 수 없습니다.\"}");
            return;
        }
        res.getWriter().write(result);
    }

    /** GET /aiApi/analyze/job/{jobId}  →  polmate_serv.py /analyze/job/{jobId} */
    @GetMapping("/analyze/job/{jobId}")
    public void analyzeJob(@PathVariable String jobId,
                           HttpServletResponse res,
                           HttpSession session) throws IOException {
        res.setContentType("application/json;charset=UTF-8");

        String userId = (session != null) ? (String) session.getAttribute("loginUser") : null;
        if (userId == null) {
            res.getWriter().write("{\"success\":false,\"error\":\"로그인이 필요합니다.\"}");
            return;
        }

        String result = fetchFlask("/analyze/job/" + jobId);
        if (result == null) {
            res.getWriter().write("{\"success\":false,\"status\":\"error\",\"message\":\"AI 서버에 연결할 수 없습니다.\"}");
            return;
        }
        res.getWriter().write(result);
    }

    // ── 내부 유틸 ───────────────────────────────────────────────────

    private String callFlask(String path, String jsonBody) {
        HttpURLConnection conn = null;
        try {
            URL url = new URL(servBaseUrl + path);
            conn = (HttpURLConnection) url.openConnection();
            conn.setRequestMethod("POST");
            conn.setRequestProperty("Content-Type", "application/json;charset=UTF-8");
            conn.setConnectTimeout(5_000);
            conn.setReadTimeout(300_000);
            conn.setDoOutput(true);
            try (OutputStream os = conn.getOutputStream()) {
                os.write(jsonBody.getBytes(StandardCharsets.UTF_8));
            }
            int status = conn.getResponseCode();
            InputStream is = (status >= 200 && status < 300)
                    ? conn.getInputStream() : conn.getErrorStream();
            if (is == null) return null;
            try (BufferedReader br = new BufferedReader(new InputStreamReader(is, StandardCharsets.UTF_8))) {
                StringBuilder sb = new StringBuilder();
                String line;
                while ((line = br.readLine()) != null) sb.append(line);
                return sb.toString();
            }
        } catch (Exception e) {
            return null;
        } finally {
            if (conn != null) conn.disconnect();
        }
    }

    private String fetchFlask(String path) {
        HttpURLConnection conn = null;
        try {
            URL url = new URL(servBaseUrl + path);
            conn = (HttpURLConnection) url.openConnection();
            conn.setRequestMethod("GET");
            conn.setConnectTimeout(5_000);
            conn.setReadTimeout(30_000);
            int status = conn.getResponseCode();
            InputStream is = (status >= 200 && status < 300)
                    ? conn.getInputStream() : conn.getErrorStream();
            if (is == null) return null;
            try (BufferedReader br = new BufferedReader(new InputStreamReader(is, StandardCharsets.UTF_8))) {
                StringBuilder sb = new StringBuilder();
                String line;
                while ((line = br.readLine()) != null) sb.append(line);
                return sb.toString();
            }
        } catch (Exception e) {
            return null;
        } finally {
            if (conn != null) conn.disconnect();
        }
    }
}
