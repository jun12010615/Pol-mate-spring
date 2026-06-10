package com.polmate.service;

import com.polmate.entity.LoginAttempt;
import com.polmate.repository.LoginAttemptRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.time.temporal.ChronoUnit;

@Service
@RequiredArgsConstructor
public class LoginAttemptService {

    @Value("${login.attempt.max-attempts:5}")
    private int maxAttempts;

    @Value("${login.attempt.lock-seconds:30}")
    private int lockSeconds;

    private final LoginAttemptRepository attemptRepo;

    @Transactional(readOnly = true)
    public boolean isBlocked(String ip) {
        return attemptRepo.findById(ip)
            .filter(a -> a.getLockedUntil() != null && a.getLockedUntil().isAfter(LocalDateTime.now()))
            .isPresent();
    }

    @Transactional(readOnly = true)
    public long remainingSeconds(String ip) {
        return attemptRepo.findById(ip)
            .filter(a -> a.getLockedUntil() != null && a.getLockedUntil().isAfter(LocalDateTime.now()))
            .map(a -> ChronoUnit.SECONDS.between(LocalDateTime.now(), a.getLockedUntil()))
            .map(s -> Math.max(0L, s))
            .orElse(0L);
    }

    @Transactional
    public void loginFailed(String ip) {
        LoginAttempt attempt = attemptRepo.findById(ip)
            .orElseGet(() -> new LoginAttempt(ip, 0, null));

        // 이미 잠금 중이면 카운트 증가 안 함
        if (attempt.getLockedUntil() != null && attempt.getLockedUntil().isAfter(LocalDateTime.now())) {
            return;
        }

        attempt.setAttempts(attempt.getAttempts() + 1);
        if (attempt.getAttempts() >= maxAttempts) {
            attempt.setLockedUntil(LocalDateTime.now().plusSeconds(lockSeconds));
        }
        attemptRepo.save(attempt);
    }

    @Transactional
    public void loginSucceeded(String ip) {
        attemptRepo.deleteById(ip);
    }

    // 만료된 잠금 레코드를 1시간마다 정리
    @Scheduled(fixedDelay = 3_600_000)
    @Transactional
    public void cleanExpiredLocks() {
        attemptRepo.deleteExpiredLocks();
    }
}
