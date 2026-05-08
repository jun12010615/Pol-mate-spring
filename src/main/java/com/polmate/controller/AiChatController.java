package com.polmate.controller;

import com.google.gson.JsonObject;
import com.google.gson.JsonParser;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.web.bind.annotation.*;

import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import jakarta.servlet.http.HttpSession;
import java.io.*;
import java.net.*;

@RestController
@RequestMapping("/askAI")
public class AiChatController {

    @Value("${ollama.url}")
    private String ollamaUrl;

    @Value("${law.api.oc}")
    private String lawOc;

    private static final String LAW_SEARCH  = "https://www.law.go.kr/DRF/lawSearch.do";
    private static final String PREC_SEARCH = "https://www.law.go.kr/DRF/precSearch.do";
    private static final String LAW_SERVICE = "https://www.law.go.kr/DRF/lawService.do";

    private static final String SYSTEM_PROMPT =
        "당신은 대한민국 경찰청 형사사법정보 AI 보조 시스템(POL-MATE)입니다.\n" +
        "현직 수사관의 질문에 다음 원칙으로 답변하세요:\n" +
        "1. 형사소송법, 경찰관직무집행법, 헌법 등 관련 법령을 인용하여 답변\n" +
        "2. 수사 실무에 즉시 적용 가능한 구체적인 내용 제공\n" +
        "3. 피의자 인권 보호 및 적법 절차 준수 강조\n" +
        "4. 반드시 한국어로 답변\n" +
        "5. 답변은 명확하고 간결하게 (200자 내외 권장)\n\n";

    @GetMapping
    public void getAiPage(HttpServletRequest request, HttpServletResponse response,
                           HttpSession session) throws Exception {
        if (session != null && session.getAttribute("userName") != null) {
            request.setAttribute("userName", session.getAttribute("userName"));
        }
        response.sendRedirect(request.getContextPath() + "/mobile/aiChat");
    }

    @PostMapping
    public void streamAi(@RequestParam(required = false) String userMsg,
                         @RequestParam(required = false) String category,
                         HttpServletResponse response, HttpSession session) throws IOException {
        response.setContentType("text/event-stream;charset=UTF-8");
        response.setHeader("Cache-Control", "no-cache");
        response.setHeader("X-Accel-Buffering", "no");
        PrintWriter out = response.getWriter();

        if (userMsg == null || userMsg.trim().isEmpty()) {
            out.write("data: [ERROR] 질문을 입력해 주세요.\n\n");
            out.flush(); return;
        }

        String prompt = SYSTEM_PROMPT;
        if (category != null && !category.trim().isEmpty()) prompt += "[질문 분류: " + category + "]\n\n";
        String lawText  = searchLaw(userMsg.trim());
        String precText = searchPrec(userMsg.trim());
        if (!lawText.isEmpty())  prompt += "[관련 법령]\n" + lawText + "\n\n";
        if (!precText.isEmpty()) prompt += "[관련 판례]\n" + precText + "\n\n";
        prompt += "수사관 질문: " + userMsg.trim();

        try {
            URL url = new URL(ollamaUrl);
            HttpURLConnection conn = (HttpURLConnection) url.openConnection();
            conn.setRequestMethod("POST");
            conn.setRequestProperty("Content-Type", "application/json; utf-8");
            conn.setConnectTimeout(5000);
            conn.setReadTimeout(180000);
            conn.setDoOutput(true);

            JsonObject jsonInput = new JsonObject();
            jsonInput.addProperty("model",  "gemma3:1b");
            jsonInput.addProperty("prompt", prompt);
            jsonInput.addProperty("stream", true);

            try (OutputStream os = conn.getOutputStream()) {
                os.write(jsonInput.toString().getBytes("utf-8"));
            }

            if (conn.getResponseCode() == 200) {
                BufferedReader br = new BufferedReader(new InputStreamReader(conn.getInputStream(), "utf-8"));
                String line;
                while ((line = br.readLine()) != null) {
                    JsonObject chunk = JsonParser.parseString(line).getAsJsonObject();
                    String token = chunk.has("response") ? chunk.get("response").getAsString() : "";
                    boolean done = chunk.has("done") && chunk.get("done").getAsBoolean();
                    if (!token.isEmpty()) { out.write("data: " + token.replace("\n","\\n") + "\n\n"); out.flush(); }
                    if (done) { out.write("data: [DONE]\n\n"); out.flush(); break; }
                }
            } else {
                out.write("data: [ERROR] Ollama 응답 오류\n\n"); out.flush();
            }
        } catch (ConnectException ce) {
            out.write("data: [ERROR] Ollama 서버에 연결할 수 없습니다.\n\n"); out.flush();
        } catch (Exception e) {
            out.write("data: [ERROR] " + e.getMessage() + "\n\n"); out.flush();
        }
    }

    private String searchLaw(String query) {
        try {
            String enc = URLEncoder.encode(query, "UTF-8");
            String json = fetchUrl(LAW_SEARCH + "?OC=" + lawOc + "&target=law&type=JSON&display=3&query=" + enc);
            if (json == null || json.isEmpty()) return "";
            StringBuilder sb = new StringBuilder();
            com.google.gson.JsonObject root = JsonParser.parseString(json).getAsJsonObject();
            com.google.gson.JsonArray items = null;
            if (root.has("LawSearch")) {
                com.google.gson.JsonObject ls = root.getAsJsonObject("LawSearch");
                if (ls.has("law")) {
                    com.google.gson.JsonElement lawEl = ls.get("law");
                    items = lawEl.isJsonArray() ? lawEl.getAsJsonArray() : new com.google.gson.JsonArray();
                    if (!lawEl.isJsonArray()) items.add(lawEl);
                }
            }
            if (items == null) return "";
            for (int i = 0; i < items.size() && i < 3; i++) {
                com.google.gson.JsonObject item = items.get(i).getAsJsonObject();
                String lawName = item.has("법령명한글") ? item.get("법령명한글").getAsString() : "";
                String lawId   = item.has("법령ID")    ? item.get("법령ID").getAsString()    : "";
                if (!lawName.isEmpty()) {
                    sb.append("▶ ").append(lawName).append("\n");
                    String detail = fetchLawDetail(lawId);
                    if (!detail.isEmpty()) sb.append(detail).append("\n");
                }
            }
            return sb.toString();
        } catch (Exception e) { return ""; }
    }

    private String fetchLawDetail(String lawId) {
        try {
            if (lawId == null || lawId.isEmpty()) return "";
            String json = fetchUrl(LAW_SERVICE + "?OC=" + lawOc + "&target=law&type=JSON&MST=" + lawId);
            if (json == null) return "";
            com.google.gson.JsonObject root = JsonParser.parseString(json).getAsJsonObject();
            if (root.has("법령") && root.getAsJsonObject("법령").has("조문")) {
                com.google.gson.JsonElement jo = root.getAsJsonObject("법령").get("조문");
                if (jo.isJsonArray() && jo.getAsJsonArray().size() > 0) {
                    com.google.gson.JsonObject first = jo.getAsJsonArray().get(0).getAsJsonObject();
                    if (first.has("조문내용")) {
                        String content = first.get("조문내용").getAsString();
                        if (content.length() > 500) content = content.substring(0, 500) + "...";
                        return content;
                    }
                }
            }
            return "";
        } catch (Exception e) { return ""; }
    }

    private String searchPrec(String query) {
        try {
            String enc = URLEncoder.encode(query, "UTF-8");
            String json = fetchUrl(PREC_SEARCH + "?OC=" + lawOc + "&target=prec&type=JSON&display=2&query=" + enc);
            if (json == null || json.isEmpty()) return "";
            StringBuilder sb = new StringBuilder();
            com.google.gson.JsonObject root = JsonParser.parseString(json).getAsJsonObject();
            com.google.gson.JsonArray items = null;
            if (root.has("PrecSearch")) {
                com.google.gson.JsonObject ps = root.getAsJsonObject("PrecSearch");
                if (ps.has("prec")) {
                    com.google.gson.JsonElement precEl = ps.get("prec");
                    items = precEl.isJsonArray() ? precEl.getAsJsonArray() : new com.google.gson.JsonArray();
                    if (!precEl.isJsonArray()) items.add(precEl);
                }
            }
            if (items == null) return "";
            for (int i = 0; i < items.size() && i < 2; i++) {
                com.google.gson.JsonObject item = items.get(i).getAsJsonObject();
                String caseName = item.has("사건명")   ? item.get("사건명").getAsString()   : "";
                String summary  = item.has("사건번호") ? item.get("사건번호").getAsString() : "";
                if (!caseName.isEmpty()) {
                    sb.append("▶ ").append(caseName).append("\n");
                    if (!summary.isEmpty()) {
                        if (summary.length() > 300) summary = summary.substring(0, 300) + "...";
                        sb.append(summary).append("\n");
                    }
                }
            }
            return sb.toString();
        } catch (Exception e) { return ""; }
    }

    private String fetchUrl(String urlStr) {
        try {
            HttpURLConnection conn = (HttpURLConnection) new URL(urlStr).openConnection();
            conn.setRequestMethod("GET"); conn.setConnectTimeout(5000); conn.setReadTimeout(10000);
            conn.setRequestProperty("Accept-Charset", "UTF-8");
            if (conn.getResponseCode() != 200) return "";
            BufferedReader br = new BufferedReader(new InputStreamReader(conn.getInputStream(), "UTF-8"));
            StringBuilder sb = new StringBuilder(); String line;
            while ((line = br.readLine()) != null) sb.append(line);
            br.close(); return sb.toString();
        } catch (Exception e) { return ""; }
    }
}
