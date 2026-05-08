package com.polmate.controller;

import com.google.gson.JsonObject;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Controller;
import org.springframework.web.bind.annotation.*;

import javax.sql.DataSource;
import java.sql.*;

@Controller
@RequestMapping("/register")
public class RegisterController {

    @Autowired
    private DataSource dataSource;

    @GetMapping
    public String registerPage(@RequestParam(required = false) String action,
                               @RequestParam(required = false) String userId,
                               @RequestParam(required = false) String badgeNum,
                               @RequestParam(required = false) String org,
                               jakarta.servlet.http.HttpServletResponse response) throws Exception {
        if ("checkId".equals(action)) {
            response.setContentType("application/json; charset=UTF-8");
            if (userId == null || userId.trim().isEmpty()) {
                response.getWriter().print(jsonResult(false, "아이디를 입력해 주세요.")); return null;
            }
            userId = userId.trim();
            if (!userId.matches("^[a-z0-9]{4,16}$")) {
                response.getWriter().print(jsonResult(false, "영문 소문자+숫자 4~16자로 입력해 주세요.")); return null;
            }
            try (Connection conn = dataSource.getConnection();
                 PreparedStatement ps = conn.prepareStatement("SELECT 1 FROM users WHERE user_id = ?")) {
                ps.setString(1, userId);
                ResultSet rs = ps.executeQuery();
                response.getWriter().print(rs.next()
                    ? jsonResult(false, "이미 사용 중인 아이디입니다.")
                    : jsonResult(true,  "사용 가능한 아이디입니다."));
            } catch (Exception e) {
                response.getWriter().print(jsonResult(false, "서버 오류: " + e.getMessage()));
            }
            return null;
        }
        if ("verifyBadge".equals(action)) {
            response.setContentType("application/json; charset=UTF-8");
            if (badgeNum == null || !badgeNum.trim().matches("^[0-9]{4}$")) {
                response.getWriter().print(jsonResult(false, "수사관 번호는 숫자 4자리입니다.")); return null;
            }
            try (Connection conn = dataSource.getConnection();
                 PreparedStatement ps = conn.prepareStatement("SELECT is_used FROM officer_badges WHERE badge_num = ?")) {
                ps.setString(1, badgeNum.trim());
                ResultSet rs = ps.executeQuery();
                if (!rs.next()) response.getWriter().print(jsonResult(false, "등록되지 않은 수사관 번호입니다."));
                else if (rs.getInt("is_used") == 1) response.getWriter().print(jsonResult(false, "이미 사용된 수사관 번호입니다."));
                else response.getWriter().print(jsonResult(true, "인증되었습니다."));
            } catch (Exception e) {
                response.getWriter().print(jsonResult(false, "서버 오류: " + e.getMessage()));
            }
            return null;
        }
        if ("getDepts".equals(action)) {
            response.setContentType("application/json; charset=UTF-8");
            if (org == null || org.trim().isEmpty()) { response.getWriter().print("[]"); return null; }
            try (Connection conn = dataSource.getConnection();
                 PreparedStatement ps = conn.prepareStatement(
                     "SELECT dept_id, dept_name FROM departments WHERE org_name = ? ORDER BY dept_id")) {
                ps.setString(1, org.trim());
                ResultSet rs = ps.executeQuery();
                org.json.JSONArray arr = new org.json.JSONArray();
                while (rs.next()) {
                    org.json.JSONObject o = new org.json.JSONObject();
                    o.put("dept_id",   rs.getInt("dept_id"));
                    o.put("dept_name", rs.getString("dept_name"));
                    arr.put(o);
                }
                response.getWriter().print(arr.toString());
            } catch (Exception e) {
                response.getWriter().print("[]");
            }
            return null;
        }
        return "redirect:/mobile/register";
    }

    @PostMapping
    @ResponseBody
    public String doRegister(
            @RequestParam(defaultValue = "") String userId,
            @RequestParam(defaultValue = "") String userPw,
            @RequestParam(defaultValue = "") String userName,
            @RequestParam(defaultValue = "") String userPhone,
            @RequestParam(defaultValue = "") String userOrg,
            @RequestParam(defaultValue = "") String userRank,
            @RequestParam(defaultValue = "") String deptId,
            @RequestParam(defaultValue = "") String badgeNum,
            @RequestParam(defaultValue = "") String userEmail) {

        if (userId.isEmpty())   return jsonResult(false, "아이디를 입력해 주세요.");
        if (userPw.isEmpty())   return jsonResult(false, "비밀번호를 입력해 주세요.");
        if (userName.isEmpty()) return jsonResult(false, "이름을 입력해 주세요.");
        if (userOrg.isEmpty())  return jsonResult(false, "소속 기관을 선택해 주세요.");
        if (userRank.isEmpty()) return jsonResult(false, "계급을 선택해 주세요.");
        if (badgeNum.isEmpty()) return jsonResult(false, "수사관 번호를 입력해 주세요.");
        if (userEmail.isEmpty()) return jsonResult(false, "이메일을 입력해 주세요.");
        if (!userEmail.matches("^[\\w.+\\-]+@[\\w\\-]+\\.[\\w.]+$"))
            return jsonResult(false, "이메일 형식이 올바르지 않습니다.");
        if (!userId.matches("^[a-z0-9]{4,16}$"))
            return jsonResult(false, "아이디는 영문 소문자+숫자 4~16자로 입력해 주세요.");
        if (userPw.length() < 8) return jsonResult(false, "비밀번호는 8자 이상 입력해 주세요.");
        if (!userPw.matches(".*[a-zA-Z].*")) return jsonResult(false, "비밀번호에 영문자를 포함해 주세요.");
        if (!userPw.matches(".*[0-9].*")) return jsonResult(false, "비밀번호에 숫자를 포함해 주세요.");
        if (!userPw.matches(".*[!@#$%^&*()_+\\-=\\[\\]{};':\"\\\\|,.<>\\/?].*"))
            return jsonResult(false, "비밀번호에 특수문자를 포함해 주세요.");

        try (Connection conn = dataSource.getConnection()) {
            // 아이디 중복 확인
            try (PreparedStatement ps = conn.prepareStatement("SELECT 1 FROM users WHERE user_id = ?")) {
                ps.setString(1, userId);
                if (ps.executeQuery().next()) return jsonResult(false, "이미 사용 중인 아이디입니다.");
            }
            // 공무원증 확인
            try (PreparedStatement ps = conn.prepareStatement("SELECT is_used FROM officer_badges WHERE badge_num = ?")) {
                ps.setString(1, badgeNum);
                ResultSet rs = ps.executeQuery();
                if (!rs.next()) return jsonResult(false, "등록되지 않은 수사관 번호입니다.");
                if (rs.getInt("is_used") == 1) return jsonResult(false, "이미 사용된 수사관 번호입니다.");
            }
            // 이메일 중복 확인
            try (PreparedStatement ps = conn.prepareStatement("SELECT 1 FROM users WHERE user_email = ?")) {
                ps.setString(1, userEmail);
                if (ps.executeQuery().next()) return jsonResult(false, "이미 사용 중인 이메일입니다.");
            }
            // INSERT
            String sql = "INSERT INTO users (user_id, user_pw, user_name, user_phone, user_email, user_org, user_rank, dept_id, badge_num) VALUES (?,?,?,?,?,?,?,?,?)";
            try (PreparedStatement ps = conn.prepareStatement(sql)) {
                ps.setString(1, userId);
                ps.setString(2, userPw);
                ps.setString(3, userName);
                ps.setString(4, userPhone.isEmpty() ? null : userPhone);
                ps.setString(5, userEmail);
                ps.setString(6, userOrg);
                ps.setString(7, userRank);
                if (deptId.isEmpty()) ps.setNull(8, Types.INTEGER);
                else { try { ps.setInt(8, Integer.parseInt(deptId)); } catch (NumberFormatException e) { ps.setNull(8, Types.INTEGER); } }
                ps.setString(9, badgeNum);
                ps.executeUpdate();
            }
            // officer_badges 사용 처리
            try (PreparedStatement ps = conn.prepareStatement("UPDATE officer_badges SET is_used = 1 WHERE badge_num = ?")) {
                ps.setString(1, badgeNum); ps.executeUpdate();
            }
            return jsonResult(true, "회원가입이 완료되었습니다.");
        } catch (SQLIntegrityConstraintViolationException e) {
            return jsonResult(false, "이미 사용 중인 아이디 또는 수사관 번호입니다.");
        } catch (Exception e) {
            e.printStackTrace();
            return jsonResult(false, "가입 중 오류가 발생했습니다: " + e.getMessage());
        }
    }

    private String jsonResult(boolean success, String message) {
        JsonObject obj = new JsonObject();
        obj.addProperty("success", success);
        obj.addProperty("message", message);
        return obj.toString();
    }
}
