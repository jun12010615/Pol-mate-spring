package com.polmate.controller;

import com.polmate.service.DepartmentService;
import com.polmate.service.UserService;
import lombok.RequiredArgsConstructor;
import org.json.JSONArray;
import org.json.JSONObject;
import org.springframework.stereotype.Controller;
import org.springframework.web.bind.annotation.*;

import jakarta.servlet.http.HttpServletResponse;
import java.util.Map;

@Controller
@RequestMapping("/register")
@RequiredArgsConstructor
public class RegisterController {

    private final UserService userService;
    private final DepartmentService deptService;

    @GetMapping
    public String registerPage(
            @RequestParam(required = false) String action,
            @RequestParam(required = false) String userId,
            @RequestParam(required = false) String badgeNum,
            @RequestParam(required = false) String org,
            HttpServletResponse response) throws Exception {

        if ("checkId".equals(action)) {
            response.setContentType("application/json; charset=UTF-8");
            if (userId == null || userId.trim().isEmpty()) {
                response.getWriter().print(json(false, "아이디를 입력해 주세요.")); return null;
            }
            userId = userId.trim();
            if (!userId.matches("^[a-z0-9]{4,16}$")) {
                response.getWriter().print(json(false, "영문 소문자+숫자 4~16자로 입력해 주세요.")); return null;
            }
            response.getWriter().print(userService.existsById(userId)
                ? json(false, "이미 사용 중인 아이디입니다.")
                : json(true,  "사용 가능한 아이디입니다."));
            return null;
        }

        if ("verifyBadge".equals(action)) {
            response.setContentType("application/json; charset=UTF-8");
            if (badgeNum == null || !badgeNum.trim().matches("^[0-9]{4}$")) {
                response.getWriter().print(json(false, "수사관 번호는 숫자 4자리입니다.")); return null;
            }
            response.getWriter().print(userService.isValidBadge(badgeNum.trim())
                ? json(true,  "인증되었습니다.")
                : json(false, "등록되지 않거나 이미 사용된 수사관 번호입니다."));
            return null;
        }

        if ("getDepts".equals(action)) {
            response.setContentType("application/json; charset=UTF-8");
            if (org == null || org.trim().isEmpty()) { response.getWriter().print("[]"); return null; }
            JSONArray arr = new JSONArray();
            for (Map<String, Object> d : deptService.getByOrg(org.trim())) {
                JSONObject o = new JSONObject();
                o.put("dept_id",   d.get("dept_id"));
                o.put("dept_name", d.get("dept_name"));
                arr.put(o);
            }
            response.getWriter().print(arr.toString());
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

        if (userId.isEmpty())    return json(false, "아이디를 입력해 주세요.");
        if (userPw.isEmpty())    return json(false, "비밀번호를 입력해 주세요.");
        if (userName.isEmpty())  return json(false, "이름을 입력해 주세요.");
        if (userOrg.isEmpty())   return json(false, "소속 기관을 선택해 주세요.");
        if (userRank.isEmpty())  return json(false, "계급을 선택해 주세요.");
        if (badgeNum.isEmpty())  return json(false, "수사관 번호를 입력해 주세요.");
        if (userEmail.isEmpty()) return json(false, "이메일을 입력해 주세요.");
        if (!userEmail.matches("^[\\w.+\\-]+@[\\w\\-]+\\.[\\w.]+$"))
            return json(false, "이메일 형식이 올바르지 않습니다.");
        if (!userId.matches("^[a-z0-9]{4,16}$"))
            return json(false, "아이디는 영문 소문자+숫자 4~16자로 입력해 주세요.");
        if (userPw.length() < 8) return json(false, "비밀번호는 8자 이상 입력해 주세요.");
        if (!userPw.matches(".*[a-zA-Z].*")) return json(false, "비밀번호에 영문자를 포함해 주세요.");
        if (!userPw.matches(".*[0-9].*"))    return json(false, "비밀번호에 숫자를 포함해 주세요.");
        if (!userPw.matches(".*[!@#$%^&*()_+\\-=\\[\\]{};':\"\\\\|,.<>\\/?].*"))
            return json(false, "비밀번호에 특수문자를 포함해 주세요.");

        if (userService.existsById(userId))    return json(false, "이미 사용 중인 아이디입니다.");
        if (!userService.isValidBadge(badgeNum)) return json(false, "등록되지 않거나 이미 사용된 수사관 번호입니다.");
        if (userService.existsByEmail(userEmail)) return json(false, "이미 사용 중인 이메일입니다.");

        try {
            Integer deptIdInt = deptId.isEmpty() ? null : Integer.parseInt(deptId);
            userService.register(userId, userPw, userName, userPhone, userEmail, userOrg, userRank, deptIdInt, badgeNum);
            return json(true, "회원가입이 완료되었습니다.");
        } catch (NumberFormatException e) {
            return json(false, "부서 정보가 올바르지 않습니다.");
        } catch (Exception e) {
            e.printStackTrace();
            return json(false, "가입 중 오류가 발생했습니다.");
        }
    }

    private String json(boolean success, String message) {
        return new JSONObject().put("success", success).put("message", message).toString();
    }
}
