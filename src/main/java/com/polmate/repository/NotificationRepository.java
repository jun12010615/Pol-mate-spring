package com.polmate.repository;

import com.polmate.entity.Notification;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

public interface NotificationRepository extends JpaRepository<Notification, Integer> {

    List<Notification> findByUserIdOrderByCreatedAtDesc(String userId);

    List<Notification> findByUserIdAndTypeOrderByCreatedAtDesc(String userId, String type);

    @Query("SELECT COUNT(n) FROM Notification n WHERE n.userId = :userId AND n.isUnread = true")
    int countUnread(@Param("userId") String userId);

    @Modifying @Transactional
    @Query("UPDATE Notification n SET n.isUnread = false WHERE n.notifId = :id AND n.userId = :userId")
    int markRead(@Param("id") Integer id, @Param("userId") String userId);

    @Modifying @Transactional
    @Query("UPDATE Notification n SET n.isUnread = false WHERE n.userId = :userId")
    int markAllRead(@Param("userId") String userId);

    void deleteByUserId(String userId);

    @Query(value =
        "SELECT COUNT(*) FROM notifications WHERE user_id = :userId AND type = :type AND tag = :tag " +
        "AND created_at >= DATE_SUB(NOW(), INTERVAL 24 HOUR)",
        nativeQuery = true)
    int countRecentByTypeAndTag(@Param("userId") String userId,
                                @Param("type") String type,
                                @Param("tag") String tag);
}
