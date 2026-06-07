package com.polmate.controller.auth;

import com.polmate.entity.User;
import com.polmate.service.LoginAttemptService;
import com.polmate.service.UserService;
import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.*;

import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpSession;
import java.util.Arrays;
import java.util.Optional;
import java.util.Set;
import java.util.stream.Collectors;

@Controller
@RequestMapping("/login")
@RequiredArgsConstructor
public class LoginController {

    private final UserService userService;
    private final LoginAttemptService loginAttemptService;

    @Value("${trusted.proxy.ips:}")
    private String trustedProxyIpsRaw;

    @GetMapping
    public String loginPage() {
        return "redirect:/mobile/login";
    }

    @PostMapping
    public String doLogin(
            @RequestParam(required = false) String userId,
            @RequestParam(required = false) String userPw,
            @RequestParam(required = false, defaultValue = "") String redirectTo,
            HttpServletRequest request, Model model) {

        String errorView = "desktop".equals(redirectTo) ? "desktop/login" : "mobile/login";
        String clientIp = resolveClientIp(request);

        if (loginAttemptService.isBlocked(clientIp)) {
            long remaining = loginAttemptService.remainingSeconds(clientIp);
            model.addAttribute("loginError", "로그인 시도가 너무 많습니다. " + remaining + "초 후 다시 시도해 주세요.");
            return errorView;
        }

        if (userId == null || userId.trim().isEmpty()
                || userPw == null || userPw.trim().isEmpty()) {
            model.addAttribute("loginError", "아이디와 비밀번호를 입력해 주세요.");
            return errorView;
        }

        Optional<User> opt = userService.findById(userId.trim());
        if (opt.isEmpty() || !userService.authenticate(userId.trim(), userPw)) {
            loginAttemptService.loginFailed(clientIp);
            model.addAttribute("loginError", "아이디 또는 비밀번호가 올바르지 않습니다.");
            return errorView;
        }

        loginAttemptService.loginSucceeded(clientIp);

        // 로그인 성공: 기존 세션 파기 후 새 세션 발급 (Session Fixation 방어)
        HttpSession oldSession = request.getSession(false);
        if (oldSession != null) {
            oldSession.invalidate();
        }
        HttpSession session = request.getSession(true);

        User user = opt.get();
        session.setAttribute("loginUser",  user.getUserId());
        session.setAttribute("userName",   user.getUserName());
        session.setAttribute("userRank",   user.getUserRank());
        session.setAttribute("userOrg",    user.getUserOrg());
        session.setAttribute("userPhone",  user.getUserPhone());
        session.setAttribute("isAdmin",    user.isAdmin());
        session.setMaxInactiveInterval(60 * 60);

        return "desktop".equals(redirectTo) ? "redirect:/desktop/main" : "redirect:/mobile/main";
    }

    private String resolveClientIp(HttpServletRequest request) {
        String remoteAddr = request.getRemoteAddr();
        Set<String> trustedProxies = Arrays.stream(trustedProxyIpsRaw.split(","))
                .map(String::trim)
                .filter(s -> !s.isEmpty())
                .collect(Collectors.toSet());
        // X-Forwarded-For는 직접 연결 IP가 신뢰 프록시일 때만 수락
        if (trustedProxies.contains(remoteAddr)) {
            String forwarded = request.getHeader("X-Forwarded-For");
            if (forwarded != null && !forwarded.isBlank()) {
                return forwarded.split(",")[0].trim();
            }
        }
        return remoteAddr;
    }
}
