package com.polmate.service;

import com.polmate.entity.Notification;
import com.polmate.repository.NotificationRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.List;

@Service
@RequiredArgsConstructor
public class NotificationService {

    private final NotificationRepository notifRepo;

    public List<Notification> list(String userId, String typeFilter) {
        if ("all".equals(typeFilter)) return notifRepo.findByUserIdOrderByCreatedAtDesc(userId);
        return notifRepo.findByUserIdAndTypeOrderByCreatedAtDesc(userId, typeFilter);
    }

    public int unreadCount(String userId) {
        return notifRepo.countUnread(userId);
    }

    @Transactional
    public boolean markRead(String userId, Integer notifId) {
        return notifRepo.markRead(notifId, userId) > 0;
    }

    @Transactional
    public void markAllRead(String userId) {
        notifRepo.markAllRead(userId);
    }

    @Transactional
    public void insert(String userId, String type, String tag, String title,
                       String description, String link, boolean isCritical) {
        Notification n = Notification.builder()
            .userId(userId).type(type).tag(tag).title(title)
            .description(description).link(link)
            .isUnread(true).isCritical(isCritical)
            .createdAt(LocalDateTime.now())
            .build();
        notifRepo.save(n);
    }

    public int countRecentByTypeAndTag(String userId, String type, String tag) {
        return notifRepo.countRecentByTypeAndTag(userId, type, tag);
    }

    public Integer getDaysSincePasswordChange(String userId) {
        return notifRepo.countRecentByTypeAndTag(userId, "sys", "보안");
    }
}
