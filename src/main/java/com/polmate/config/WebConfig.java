package com.polmate.config;

import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import jakarta.servlet.http.HttpSession;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.servlet.HandlerInterceptor;
import org.springframework.web.servlet.config.annotation.InterceptorRegistry;
import org.springframework.web.servlet.config.annotation.WebMvcConfigurer;

@Configuration
public class WebConfig implements WebMvcConfigurer {

    @Override
    public void addInterceptors(InterceptorRegistry registry) {
        registry.addInterceptor(new AuthInterceptor())
                .addPathPatterns("/mobile/**", "/desktop/**")
                .excludePathPatterns(
                        "/mobile/login", "/mobile/register", "/mobile/findAccount",
                        "/desktop/login", "/desktop/register", "/desktop/findAccount"
                );
    }

    static class AuthInterceptor implements HandlerInterceptor {
        @Override
        public boolean preHandle(HttpServletRequest request, HttpServletResponse response,
                                 Object handler) throws Exception {
            HttpSession session = request.getSession(false);
            if (session == null || session.getAttribute("loginUser") == null) {
                String uri = request.getRequestURI();
                if (uri.startsWith(request.getContextPath() + "/desktop")) {
                    response.sendRedirect(request.getContextPath() + "/desktop/login");
                } else {
                    response.sendRedirect(request.getContextPath() + "/mobile/login");
                }
                return false;
            }
            return true;
        }
    }
}
