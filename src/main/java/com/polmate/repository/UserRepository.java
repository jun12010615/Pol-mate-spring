package com.polmate.repository;

import com.polmate.entity.User;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;

public interface UserRepository extends JpaRepository<User, String> {

    @Query(value =
        "SELECT DATEDIFF(NOW(), IFNULL(password_changed_at, created_at)) FROM users WHERE user_id = :userId",
        nativeQuery = true)
    Integer getDaysSincePasswordChange(@Param("userId") String userId);

    @Query(value =
        "SELECT u2.* FROM users u2 JOIN users me ON me.user_id = :userId " +
        "WHERE u2.dept_id = me.dept_id AND me.dept_id IS NOT NULL " +
        "AND u2.user_id != :userId AND u2.notif_relation = 1",
        nativeQuery = true)
    List<User> findTeammatesForNotification(@Param("userId") String userId);

    @Query(value =
        "SELECT u2.user_id FROM users u2 JOIN users me ON me.user_id = :userId " +
        "WHERE u2.dept_id = me.dept_id AND me.dept_id IS NOT NULL AND u2.user_id != :userId",
        nativeQuery = true)
    List<String> findTeammateIds(@Param("userId") String userId);

    Optional<com.polmate.entity.User> findByUserNameAndUserEmail(String userName, String userEmail);

    boolean existsByUserIdAndUserEmail(String userId, String userEmail);

    @Modifying @Transactional
    @Query("UPDATE User u SET u.userPw = :pw, u.passwordChangedAt = :now WHERE u.userId = :userId")
    int updatePassword(@Param("userId") String userId, @Param("pw") String pw, @Param("now") LocalDateTime now);

    @Modifying @Transactional
    @Query("UPDATE User u SET u.notifContradiction = :nc, u.notifRelation = :nr, u.nightMode = :nm WHERE u.userId = :userId")
    int updateSettings(@Param("userId") String userId,
                       @Param("nc") boolean nc,
                       @Param("nr") boolean nr,
                       @Param("nm") boolean nm);
}
