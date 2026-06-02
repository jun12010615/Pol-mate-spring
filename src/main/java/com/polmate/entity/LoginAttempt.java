package com.polmate.entity;

import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;

@Entity
@Table(name = "login_attempts")
@Data
@NoArgsConstructor
@AllArgsConstructor
public class LoginAttempt {

    @Id
    @Column(name = "ip", length = 45)
    private String ip;

    @Column(name = "attempts", nullable = false)
    private int attempts;

    @Column(name = "locked_until")
    private LocalDateTime lockedUntil;
}
