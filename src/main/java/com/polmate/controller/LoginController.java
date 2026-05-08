package com.polmate.controller;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;

import javax.sql.DataSource;
import jakarta.servlet.http.HttpSession;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;

@Controller
@RequestMapping("/login")
public class LoginController {

    @Autowired
    private DataSource dataSource;

    @GetMapping
    public String loginPage() {
        return "redirect:/mobile/login";
    }

    @PostMapping
    public String doLogin(
            @RequestParam(required = false) String userId,
            @RequestParam(required = false) String userPw,
            @RequestParam(required = false, defaultValue = "") String redirectTo,
            HttpSession session, Model model) {

        if (userId == null || userId.trim().isEmpty()
                || userPw == null || userPw.trim().isEmpty()) {
            model.addAttribute("loginError", "아이디와 비밀번호를 입력해 주세요.");
            return "mobile/login";
        }

        Connection conn = null;
        PreparedStatement pstmt = null;
        ResultSet rs = null;

        try {
            conn = dataSource.getConnection();
            String sql = "SELECT user_id, user_pw, user_name, user_rank, user_org, user_phone FROM USERS WHERE user_id = ?";
            pstmt = conn.prepareStatement(sql);
            pstmt.setString(1, userId.trim());
            rs = pstmt.executeQuery();

            if (rs.next()) {
                String dbPw    = rs.getString("user_pw");
                String dbName  = rs.getString("user_name");
                String dbRank  = rs.getString("user_rank");
                String dbOrg   = rs.getString("user_org");
                String dbPhone = rs.getString("user_phone");

                if (dbPw.equals(userPw)) {
                    session.setAttribute("loginUser", userId.trim());
                    session.setAttribute("userName",  dbName);
                    session.setAttribute("userRank",  dbRank);
                    session.setAttribute("userOrg",   dbOrg);
                    session.setAttribute("userPhone", dbPhone);
                    session.setMaxInactiveInterval(60 * 60);

                    if ("desktop".equals(redirectTo)) {
                        return "redirect:/desktop/main";
                    } else {
                        return "redirect:/mobile/main";
                    }
                } else {
                    model.addAttribute("loginError", "아이디 또는 비밀번호가 올바르지 않습니다.");
                    return "mobile/login";
                }
            } else {
                model.addAttribute("loginError", "아이디 또는 비밀번호가 올바르지 않습니다.");
                return "mobile/login";
            }

        } catch (Exception e) {
            e.printStackTrace();
            model.addAttribute("loginError", "로그인 중 오류가 발생했습니다. 잠시 후 다시 시도해 주세요.");
            return "mobile/login";
        } finally {
            try { if (rs != null) rs.close(); } catch (Exception ignored) {}
            try { if (pstmt != null) pstmt.close(); } catch (Exception ignored) {}
            try { if (conn != null) conn.close(); } catch (Exception ignored) {}
        }
    }
}
