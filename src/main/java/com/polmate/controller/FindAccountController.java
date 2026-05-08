package com.polmate.controller;

import com.google.gson.JsonObject;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.mail.javamail.JavaMailSender;
import org.springframework.mail.javamail.MimeMessageHelper;
import org.springframework.stereotype.Controller;
import org.springframework.web.bind.annotation.*;

import javax.sql.DataSource;
import jakarta.mail.internet.MimeMessage;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpSession;
import java.sql.*;
import java.util.Random;

@Controller
@RequestMapping("/findAccount")
public class FindAccountController {

    private static final String SESS_CODE    = "pw_code";
    private static final String SESS_USERID  = "pw_userId";
    private static final String SESS_EXPIRES = "pw_expires";
    private static final long   CODE_TTL_MS  = 3 * 60 * 1000L;

    @Autowired private DataSource dataSource;
    @Autowired private JavaMailSender mailSender;

    @PostMapping
    @ResponseBody
    public String doPost(@RequestParam(defaultValue = "") String action,
                         HttpServletRequest request) {
        return switch (action) {
            case "findId"     -> handleFindId(request);
            case "sendCode"   -> handleSendCode(request);
            case "verifyCode" -> handleVerifyCode(request);
            case "resetPw"    -> handleResetPw(request);
            default           -> fail("알 수 없는 요청입니다.");
        };
    }

    private String handleFindId(HttpServletRequest req) {
        String name  = nvl(req.getParameter("name"));
        String email = nvl(req.getParameter("email"));
        if (name.isEmpty())  return fail("이름을 입력해 주세요.");
        if (email.isEmpty()) return fail("이메일을 입력해 주세요.");
        if (!isValidEmail(email)) return fail("이메일 형식이 올바르지 않습니다.");

        try (Connection conn = dataSource.getConnection();
             PreparedStatement ps = conn.prepareStatement(
                 "SELECT user_id FROM users WHERE user_name = ? AND user_email = ?")) {
            ps.setString(1, name); ps.setString(2, email);
            ResultSet rs = ps.executeQuery();
            if (!rs.next()) return fail("입력하신 이름과 이메일이 일치하는 계정을 찾을 수 없습니다.");
            String maskedId = maskId(rs.getString("user_id"));
            sendHtmlMail(email, "[POL-MATE] 아이디 찾기 안내", buildFindIdHtml(name, maskedId));
            JsonObject jo = new JsonObject();
            jo.addProperty("success", true);
            jo.addProperty("maskedEmail", maskEmail(email));
            return jo.toString();
        } catch (Exception e) {
            e.printStackTrace();
            return fail("서버 오류가 발생했습니다.");
        }
    }

    private String handleSendCode(HttpServletRequest req) {
        String userId = nvl(req.getParameter("userId"));
        String email  = nvl(req.getParameter("email"));
        if (userId.isEmpty()) return fail("아이디를 입력해 주세요.");
        if (email.isEmpty())  return fail("이메일을 입력해 주세요.");
        if (!isValidEmail(email)) return fail("이메일 형식이 올바르지 않습니다.");

        try (Connection conn = dataSource.getConnection();
             PreparedStatement ps = conn.prepareStatement(
                 "SELECT user_id FROM users WHERE user_id = ? AND user_email = ?")) {
            ps.setString(1, userId); ps.setString(2, email);
            if (!ps.executeQuery().next()) return fail("아이디 또는 이메일이 일치하지 않습니다.");
            String code = String.format("%06d", new Random().nextInt(1_000_000));
            HttpSession sess = req.getSession();
            sess.setAttribute(SESS_CODE,    code);
            sess.setAttribute(SESS_USERID,  userId);
            sess.setAttribute(SESS_EXPIRES, System.currentTimeMillis() + CODE_TTL_MS);
            sendHtmlMail(email, "[POL-MATE] 비밀번호 재설정 인증코드", buildCodeHtml(userId, code));
            return ok("인증코드가 발송되었습니다.");
        } catch (Exception e) {
            e.printStackTrace();
            return fail("서버 오류가 발생했습니다.");
        }
    }

    private String handleVerifyCode(HttpServletRequest req) {
        String inputCode = nvl(req.getParameter("code"));
        if (inputCode.isEmpty()) return fail("인증코드를 입력해 주세요.");
        HttpSession sess = req.getSession(false);
        if (sess == null) return fail("세션이 만료되었습니다. 인증코드를 다시 발송해 주세요.");
        String savedCode = (String) sess.getAttribute(SESS_CODE);
        Long   expires   = (Long)   sess.getAttribute(SESS_EXPIRES);
        if (savedCode == null || expires == null) return fail("인증코드를 먼저 발송해 주세요.");
        if (System.currentTimeMillis() > expires) return fail("인증코드가 만료되었습니다. 재발송해 주세요.");
        if (!savedCode.equals(inputCode)) return fail("인증코드가 올바르지 않습니다.");
        sess.removeAttribute(SESS_CODE);
        sess.removeAttribute(SESS_EXPIRES);
        return ok("인증되었습니다.");
    }

    private String handleResetPw(HttpServletRequest req) {
        String newPw = nvl(req.getParameter("newPw"));
        HttpSession sess = req.getSession(false);
        if (sess == null) return fail("세션이 만료되었습니다. 처음부터 다시 시도해 주세요.");
        String userId = (String) sess.getAttribute(SESS_USERID);
        if (userId == null) return fail("인증 정보가 없습니다. 처음부터 다시 시도해 주세요.");
        if (newPw.length() < 8) return fail("비밀번호는 8자 이상이어야 합니다.");
        if (!newPw.matches(".*[a-zA-Z].*")) return fail("영문자를 포함해야 합니다.");
        if (!newPw.matches(".*[0-9].*"))    return fail("숫자를 포함해야 합니다.");
        if (!newPw.matches(".*[!@#$%^&*()_+\\-=].*")) return fail("특수문자를 포함해야 합니다.");

        try (Connection conn = dataSource.getConnection();
             PreparedStatement ps = conn.prepareStatement(
                 "UPDATE users SET user_pw = ?, password_changed_at = NOW() WHERE user_id = ?")) {
            ps.setString(1, newPw); ps.setString(2, userId);
            if (ps.executeUpdate() == 0) return fail("계정을 찾을 수 없습니다.");
            sess.removeAttribute(SESS_USERID);
            return ok("비밀번호가 변경되었습니다.");
        } catch (Exception e) {
            e.printStackTrace();
            return fail("서버 오류가 발생했습니다.");
        }
    }

    private void sendHtmlMail(String to, String subject, String html) throws Exception {
        MimeMessage msg = mailSender.createMimeMessage();
        MimeMessageHelper helper = new MimeMessageHelper(msg, true, "UTF-8");
        helper.setFrom("a01077202445@gmail.com", "POLMATE");
        helper.setTo(to);
        helper.setSubject(subject);
        helper.setText(html, true);
        mailSender.send(msg);
    }

    private String buildFindIdHtml(String name, String maskedId) {
        return baseHtml("아이디 찾기 안내",
            "<p>안녕하세요, <strong>" + esc(name) + "</strong> 수사관님</p>" +
            "<p>회원님의 아이디: <strong>" + esc(maskedId) + "</strong></p>");
    }

    private String buildCodeHtml(String userId, String code) {
        return baseHtml("비밀번호 재설정 인증코드",
            "<p>안녕하세요, <strong>" + esc(userId) + "</strong> 수사관님</p>" +
            "<p>인증코드: <strong style='font-size:24px;letter-spacing:4px'>" + esc(code) + "</strong></p>" +
            "<p>3분 이내에 입력해 주세요.</p>");
    }

    private String baseHtml(String title, String body) {
        return "<!DOCTYPE html><html><body><h2>" + esc(title) + "</h2>" + body +
               "<p style='color:#999;font-size:12px'>POL-MATE 자동발송 메일입니다.</p></body></html>";
    }

    private boolean isValidEmail(String e) { return e.matches("^[\\w.+\\-]+@[\\w\\-]+\\.[\\w.]+$"); }
    private String maskId(String id) {
        if (id == null || id.length() <= 2) return id;
        int show = (int) Math.ceil(id.length() / 2.0);
        return id.substring(0, show) + "*".repeat(id.length() - show);
    }
    private String maskEmail(String email) {
        int at = email.indexOf('@');
        if (at <= 0) return email;
        String local = email.substring(0, at), domain = email.substring(at);
        int show = Math.min(2, local.length());
        return local.substring(0, show) + "*".repeat(local.length() - show) + domain;
    }
    private String esc(String s) {
        return s == null ? "" : s.replace("&","&amp;").replace("<","&lt;").replace(">","&gt;");
    }
    private String nvl(String s) { return s == null ? "" : s.trim(); }
    private String ok(String msg) { JsonObject j = new JsonObject(); j.addProperty("success",true); j.addProperty("message",msg); return j.toString(); }
    private String fail(String msg) { JsonObject j = new JsonObject(); j.addProperty("success",false); j.addProperty("message",msg); return j.toString(); }
}
