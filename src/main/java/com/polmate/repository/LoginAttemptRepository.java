package com.polmate.repository;

import com.polmate.entity.LoginAttempt;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.transaction.annotation.Transactional;

public interface LoginAttemptRepository extends JpaRepository<LoginAttempt, String> {

    @Modifying
    @Transactional
    @Query("DELETE FROM LoginAttempt a WHERE a.lockedUntil IS NOT NULL AND a.lockedUntil < CURRENT_TIMESTAMP")
    void deleteExpiredLocks();
}
