-- 감정 분석 결과 저장 테이블
-- pol-mate DB에 직접 실행하세요
CREATE TABLE IF NOT EXISTS emotion_analyses (
    analysis_id     INT          NOT NULL AUTO_INCREMENT,
    transcript_id   INT          NOT NULL,
    model           VARCHAR(50),
    sentence_count  INT          NOT NULL DEFAULT 0,
    highlight_count INT          NOT NULL DEFAULT 0,
    sentences_json  LONGTEXT,
    highlights_json TEXT,
    analyzed_at     DATETIME,
    PRIMARY KEY (analysis_id),
    UNIQUE KEY uq_emotion_transcript (transcript_id)
);
