package com.polmate.controller.ai;

import com.google.gson.JsonObject;
import com.google.gson.JsonParser;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.io.*;
import java.net.*;
import java.util.Set;

@RestController
@RequestMapping("/stt")
public class SttController {

    private static final Set<String> ALLOWED_MIME_TYPES = Set.of(
        "audio/wav", "audio/x-wav", "audio/wave",
        "audio/mpeg", "audio/mp3",
        "audio/webm", "audio/ogg",
        "audio/mp4", "audio/x-m4a", "audio/aac",
        "audio/flac"
    );
    private static final Set<String> ALLOWED_EXTENSIONS = Set.of(
        "wav", "mp3", "webm", "ogg", "m4a", "aac", "flac"
    );
    private static final long MAX_FILE_SIZE = 50 * 1024 * 1024L; // 50MB

    @Value("${clova.speech.invoke-url}")
    private String invokeUrl;

    @Value("${clova.speech.secret-key}")
    private String secretKey;

    @GetMapping
    public String checkConfig() {
        boolean configured = secretKey != null && !secretKey.isEmpty() && !secretKey.equals("YOUR_CLOVA_SECRET_KEY");
        return "{\"configured\":" + configured + "}";
    }

    @PostMapping
    public String doStt(@RequestParam("audioFile") MultipartFile audioFile,
                        @RequestParam(defaultValue = "Kor") String language) {
        if (secretKey == null || secretKey.isEmpty()) {
            return errorJson("CLOVA Secret Key가 설정되지 않았습니다.");
        }
        if (audioFile == null || audioFile.isEmpty()) {
            return errorJson("음성 파일이 없습니다.");
        }
        if (audioFile.getSize() > MAX_FILE_SIZE) {
            return errorJson("파일 크기가 50MB를 초과합니다.");
        }

        String originalFilename = audioFile.getOriginalFilename();
        String ext = (originalFilename != null && originalFilename.contains("."))
            ? originalFilename.substring(originalFilename.lastIndexOf('.') + 1).toLowerCase()
            : "";
        if (!ALLOWED_EXTENSIONS.contains(ext)) {
            return errorJson("허용되지 않는 파일 형식입니다. (wav, mp3, webm, ogg, m4a, aac, flac 허용)");
        }

        String contentType = audioFile.getContentType();
        if (contentType == null || !ALLOWED_MIME_TYPES.contains(contentType.toLowerCase())) {
            return errorJson("허용되지 않는 MIME 타입입니다.");
        }

        try {
            String apiUrl = invokeUrl + "?lang=" + language;
            URL url = new URL(apiUrl);
            HttpURLConnection conn = (HttpURLConnection) url.openConnection();
            conn.setRequestMethod("POST");
            conn.setDoOutput(true);
            conn.setConnectTimeout(10000);
            conn.setReadTimeout(60000);
            conn.setRequestProperty("Content-Type",          "application/octet-stream");
            conn.setRequestProperty("X-CLOVASPEECH-API-KEY", secretKey);

            try (OutputStream os = conn.getOutputStream();
                 InputStream  is = audioFile.getInputStream()) {
                byte[] buffer = new byte[4096]; int bytesRead;
                while ((bytesRead = is.read(buffer)) != -1) os.write(buffer, 0, bytesRead);
            }

            int statusCode = conn.getResponseCode();
            if (statusCode == 200) {
                StringBuilder sb = new StringBuilder();
                try (BufferedReader br = new BufferedReader(new InputStreamReader(conn.getInputStream(), "UTF-8"))) {
                    String line; while ((line = br.readLine()) != null) sb.append(line);
                }
                JsonObject jsonRes = JsonParser.parseString(sb.toString()).getAsJsonObject();
                String text = jsonRes.has("text") ? jsonRes.get("text").getAsString() : "";
                JsonObject result = new JsonObject();
                result.addProperty("success",  true);
                result.addProperty("text",      text);
                result.addProperty("language",  language);
                result.addProperty("fileSize",  audioFile.getSize());
                result.addProperty("fileName",  audioFile.getOriginalFilename());
                return result.toString();
            } else {
                String errBody = "";
                InputStream errStream = conn.getErrorStream();
                if (errStream != null) {
                    BufferedReader br = new BufferedReader(new InputStreamReader(errStream, "UTF-8"));
                    StringBuilder sb = new StringBuilder(); String line;
                    while ((line = br.readLine()) != null) sb.append(line);
                    errBody = sb.toString();
                }
                return errorJson("CLOVA API 오류 (" + statusCode + "): " + errBody);
            }
        } catch (ConnectException ce) {
            return errorJson("CLOVA API 서버에 연결할 수 없습니다.");
        } catch (Exception e) {
            return errorJson("STT 처리 중 오류: " + e.getMessage());
        }
    }

    private String errorJson(String message) {
        JsonObject obj = new JsonObject();
        obj.addProperty("success", false);
        obj.addProperty("error",   message);
        return obj.toString();
    }
}
