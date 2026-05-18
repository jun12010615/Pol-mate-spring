package com.polmate.entity;

import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.CreationTimestamp;

import java.time.LocalDateTime;

@Entity
@Table(name = "timeline_events")
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class TimelineEvent {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "event_id")
    private Long eventId;

    @Column(name = "case_id", nullable = false, length = 20)
    private String caseId;

    @Column(name = "transcript_id")
    private Integer transcriptId;

    @Column(name = "lane_key", nullable = false, length = 100)
    private String laneKey;

    @Column(name = "stmt_name", length = 100)
    private String stmtName;

    @Column(name = "stmt_type", length = 50)
    private String stmtType;

    @Column(name = "event_type", nullable = false, length = 30)
    private String eventType;

    @Column(name = "time_start")
    private LocalDateTime timeStart;

    @Column(name = "time_end")
    private LocalDateTime timeEnd;

    @Column(name = "time_text", length = 200)
    private String timeText;

    @Column(name = "time_precision", length = 20)
    private String timePrecision;

    @Column(name = "anchor_sort_order")
    private Integer anchorSortOrder;

    @Column(name = "offset_minutes")
    private Integer offsetMinutes;

    @Column(name = "offset_end_minutes")
    private Integer offsetEndMinutes;

    @Column(name = "place", length = 200)
    private String place;

    @Column(name = "label", nullable = false, length = 300)
    private String label;

    @Column(name = "quote", columnDefinition = "TEXT")
    private String quote;

    @Column(name = "confidence", length = 20)
    private String confidence;

    @Column(name = "sort_order", nullable = false)
    private int sortOrder;

    @CreationTimestamp
    @Column(name = "created_at", updatable = false)
    private LocalDateTime createdAt;
}
