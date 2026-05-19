package com.polmate.service;

import org.springframework.stereotype.Service;

import java.util.concurrent.ConcurrentHashMap;

@Service
public class LoginAttemptService {

    private static final int MAX_ATTEMPTS = 5;
    private static final long LOCK_MS = 30_000;

    // value: long[0]=연속실패횟수, long[1]=잠금해제시각(epoch ms, 0=미잠금)
    private final ConcurrentHashMap<String, long[]> state = new ConcurrentHashMap<>();

    public boolean isBlocked(String ip) {
        long[] s = state.get(ip);
        if (s == null) return false;
        if (s[1] > 0 && System.currentTimeMillis() < s[1]) return true;
        if (s[1] > 0) state.remove(ip); // 잠금 만료 → 초기화
        return false;
    }

    public long remainingSeconds(String ip) {
        long[] s = state.get(ip);
        if (s == null || s[1] == 0) return 0;
        return Math.max(0, (s[1] - System.currentTimeMillis()) / 1000);
    }

    public void loginFailed(String ip) {
        state.compute(ip, (k, s) -> {
            if (s == null) s = new long[]{0, 0};
            s[0]++;
            if (s[0] >= MAX_ATTEMPTS) s[1] = System.currentTimeMillis() + LOCK_MS;
            return s;
        });
    }

    public void loginSucceeded(String ip) {
        state.remove(ip);
    }
}
