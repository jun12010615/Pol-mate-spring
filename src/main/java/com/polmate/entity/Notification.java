package com.polmate.entity;

import jakarta.persistence.*;
import lombok.*;
import java.time.LocalDateTime;

@Entity
@Table(name = "notifications")
@Data @Builder @NoArgsConstructor @AllArgsConstructor
public class Notification {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "notif_id")
    private Integer notifId;

    @Column(name = "user_id")
    private String userId;

    @Column(name = "type")
    private String type;

    @Column(name = "tag")
    private String tag;

    @Column(name = "title")
    private String title;

    @Column(name = "description", columnDefinition = "TEXT")
    private String description;

    @Column(name = "link")
    private String link;

    @Column(name = "is_unread")
    private boolean isUnread;

    @Column(name = "is_critical")
    private boolean isCritical;

    @Column(name = "created_at", updatable = false)
    private LocalDateTime createdAt;
}
