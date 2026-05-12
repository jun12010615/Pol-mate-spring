package com.polmate.controller;

import com.polmate.entity.User;
import com.polmate.service.UserService;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.*;

import jakarta.servlet.http.HttpSession;
import java.util.Optional;

@Controller
@RequestMapping("/login")
@RequiredArgsConstructor
public class LoginController {

    private final UserService userService;

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

        String errorView = "desktop".equals(redirectTo) ? "desktop/login" : "mobile/login";

        if (userId == null || userId.trim().isEmpty()
                || userPw == null || userPw.trim().isEmpty()) {
            model.addAttribute("loginError", "아이디와 비밀번호를 입력해 주세요.");
            return errorView;
        }

        Optional<User> opt = userService.findById(userId.trim());
        if (opt.isEmpty() || !userPw.equals(opt.get().getUserPw())) {
            model.addAttribute("loginError", "아이디 또는 비밀번호가 올바르지 않습니다.");
            return errorView;
        }

        User user = opt.get();
        session.setAttribute("loginUser",  user.getUserId());
        session.setAttribute("userName",   user.getUserName());
        session.setAttribute("userRank",   user.getUserRank());
        session.setAttribute("userOrg",    user.getUserOrg());
        session.setAttribute("userPhone",  user.getUserPhone());
        session.setMaxInactiveInterval(60 * 60);

        return "desktop".equals(redirectTo) ? "redirect:/desktop/main" : "redirect:/mobile/main";
    }
}
