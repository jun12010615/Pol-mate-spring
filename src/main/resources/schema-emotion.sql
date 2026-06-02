-- 감정 분석 결과 저장 테이블
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

-- 로그인 시도 기록 (서버 재시작 후에도 잠금 상태 유지)
CREATE TABLE IF NOT EXISTS login_attempts (
    ip          VARCHAR(45) NOT NULL,
    attempts    INT         NOT NULL DEFAULT 0,
    locked_until DATETIME,
    PRIMARY KEY (ip)
);
