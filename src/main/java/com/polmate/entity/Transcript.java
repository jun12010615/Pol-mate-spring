package com.polmate.entity;

import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.CreationTimestamp;
import java.time.LocalDateTime;

@Entity
@Table(name = "transcripts")
@Data @Builder @NoArgsConstructor @AllArgsConstructor
public class Transcript {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "transcript_id")
    private Integer transcriptId;

    @Column(name = "case_id")
    private String caseId;

    @Column(name = "user_id")
    private String userId;

    @Column(name = "stmt_name")
    private String stmtName;

    @Column(name = "stmt_type")
    private String stmtType;

    @Column(name = "original_text", columnDefinition = "TEXT")
    private String originalText;

    // 형광펜/메모 등 서식을 보존하기 위한 HTML 본문 (UI 복원용)
    @Column(name = "original_html", columnDefinition = "TEXT")
    private String originalHtml;

    @Column(name = "ai_result", columnDefinition = "TEXT")
    private String aiResult;

    @Column(name = "writer_name", length = 100)
    private String writerName;

    @Column(name = "writer_org", length = 200)
    private String writerOrg;

    // 전문부 날짜: 조서 작성 당시의 년/월/일을 고정 보관
    // (created_at은 시스템 시각이라 timezone/표시 변환 영향을 받으므로 별도 컬럼으로 박음)
    @Column(name = "preamble_year")
    private Integer preambleYear;

    @Column(name = "preamble_month")
    private Integer preambleMonth;

    @Column(name = "preamble_day")
    private Integer preambleDay;

    @Column(name = "has_contradiction")
    private int hasContradiction;

    @CreationTimestamp
    @Column(name = "created_at", updatable = false)
    private LocalDateTime createdAt;
}