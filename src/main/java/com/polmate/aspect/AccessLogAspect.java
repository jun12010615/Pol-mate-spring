package com.polmate.aspect;

import com.polmate.annotation.LogAccess;
import com.polmate.service.AccessLogService;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpSession;
import lombok.RequiredArgsConstructor;
import org.aspectj.lang.ProceedingJoinPoint;
import org.aspectj.lang.annotation.Around;
import org.aspectj.lang.annotation.Aspect;
import org.springframework.stereotype.Component;
import org.springframework.web.context.request.RequestContextHolder;
import org.springframework.web.context.request.ServletRequestAttributes;

import java.util.Map;
import java.util.Optional;

@Aspect
@Component
@RequiredArgsConstructor
public class AccessLogAspect {

    private final AccessLogService accessLogService;

    @Around("@annotation(logAccess)")
    public Object logAccess(ProceedingJoinPoint pjp, LogAccess logAccess) throws Throwable {
        Object result = pjp.proceed();

        try {
            ServletRequestAttributes attrs =
                (ServletRequestAttributes) RequestContextHolder.getRequestAttributes();
            if (attrs == null) return result;

            HttpServletRequest req = attrs.getRequest();
            HttpSession session = req.getSession(false);
            if (session == null) return result;

            String userId   = (String) session.getAttribute("loginUser");
            String userName = (String) session.getAttribute("userName");
            if (userId == null) return result;

            Object[] args    = pjp.getArgs();
            String targetId  = args.length > 0 ? String.valueOf(args[0]) : null;

            // 동일 type+targetId를 30초 이내 재호출하면 기록 생략
            String dedupKey = "alLog_" + logAccess.type() + "_" + targetId;
            Long lastAt = (Long) session.getAttribute(dedupKey);
            long now = System.currentTimeMillis();
            if (lastAt != null && now - lastAt < 30_000) return result;
            session.setAttribute(dedupKey, now);

            String targetName = extractName(result, logAccess.nameKey());
            String ip         = resolveIp(req);

            accessLogService.saveAsync(userId, userName, logAccess.type(), targetId, targetName, ip);
        } catch (Exception ignored) {}

        return result;
    }

    @SuppressWarnings("unchecked")
    private String extractName(Object result, String nameKey) {
        if (nameKey == null || nameKey.isEmpty()) return null;
        if (!(result instanceof Optional)) return null;
        Optional<?> opt = (Optional<?>) result;
        if (opt.isEmpty()) return null;
        if (!(opt.get() instanceof Map)) return null;
        Object val = ((Map<?, ?>) opt.get()).get(nameKey);
        return val != null ? val.toString() : null;
    }

    private String resolveIp(HttpServletRequest req) {
        for (String header : new String[]{"X-Forwarded-For", "X-Real-IP", "Proxy-Client-IP"}) {
            String ip = req.getHeader(header);
            if (ip != null && !ip.isEmpty() && !"unknown".equalsIgnoreCase(ip)) {
                return ip.contains(",") ? ip.split(",")[0].trim() : ip;
            }
        }
        return req.getRemoteAddr();
    }
}
