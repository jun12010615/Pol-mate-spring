-- pol-mate 로컬 개발용 스키마 (MySQL 9+)
-- 실행: mysql -u root pol-mate < schema-local.sql

CREATE TABLE IF NOT EXISTS departments (
  dept_id   INT          NOT NULL AUTO_INCREMENT PRIMARY KEY,
  dept_name VARCHAR(255),
  org_name  VARCHAR(255)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS officer_badges (
  badge_num VARCHAR(10) NOT NULL PRIMARY KEY,
  is_used   INT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS users (
  user_id              VARCHAR(50)  NOT NULL PRIMARY KEY,
  user_pw              VARCHAR(255),
  user_name            VARCHAR(255),
  user_rank            VARCHAR(255),
  user_org             VARCHAR(255),
  user_phone           VARCHAR(255),
  dept_id              INT,
  badge_num            VARCHAR(255),
  user_email           VARCHAR(255),
  notif_contradiction  TINYINT(1),
  notif_relation       TINYINT(1),
  night_mode           TINYINT(1),
  is_admin             TINYINT(1),
  created_at           DATETIME DEFAULT CURRENT_TIMESTAMP,
  password_changed_at  DATETIME
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS login_attempts (
  ip           VARCHAR(45) NOT NULL PRIMARY KEY,
  attempts     INT         NOT NULL DEFAULT 0,
  locked_until DATETIME
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS cases (
  case_id    VARCHAR(20)  NOT NULL PRIMARY KEY,
  case_name  VARCHAR(255),
  suspect    VARCHAR(255),
  charge     VARCHAR(255),
  status     VARCHAR(255),
  dept_id    INT,
  user_id    VARCHAR(255),
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS transcripts (
  transcript_id INT          NOT NULL AUTO_INCREMENT PRIMARY KEY,
  case_id       VARCHAR(255),
  user_id       VARCHAR(255),
  stmt_name     VARCHAR(255),
  stmt_type     VARCHAR(255),
  original_text TEXT,
  original_html TEXT,
  ai_result     TEXT,
  writer_name   VARCHAR(100),
  writer_org    VARCHAR(200),
  preamble_year  INT,
  preamble_month INT,
  preamble_day   INT,
  has_contradiction INT,
  created_at    DATETIME DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS transcript_scores (
  score_id           INT  NOT NULL AUTO_INCREMENT PRIMARY KEY,
  transcript_id      INT  UNIQUE,
  consistency_score  INT,
  specificity_score  INT,
  emotion_score      INT,
  temporal_score     INT,
  total_score        INT,
  consistency_reason TEXT,
  specificity_reason TEXT,
  emotion_reason     TEXT,
  temporal_reason    TEXT,
  scored_at          DATETIME
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS emotion_analyses (
  analysis_id     INT         NOT NULL AUTO_INCREMENT PRIMARY KEY,
  transcript_id   INT         UNIQUE,
  model           VARCHAR(50),
  sentence_count  INT,
  highlight_count INT,
  sentences_json  LONGTEXT,
  highlights_json TEXT,
  analyzed_at     DATETIME
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS timeline_events (
  event_id       BIGINT       NOT NULL AUTO_INCREMENT PRIMARY KEY,
  case_id        VARCHAR(20)  NOT NULL,
  transcript_id  INT,
  stmt_name      VARCHAR(100) NOT NULL,
  stmt_type      VARCHAR(50),
  event_type     VARCHAR(30)  NOT NULL,
  time_start     DATETIME,
  time_end       DATETIME,
  time_text      VARCHAR(200),
  time_precision VARCHAR(20),
  place          VARCHAR(200),
  label          VARCHAR(300) NOT NULL,
  quote          TEXT,
  confidence     VARCHAR(20),
  sort_order     INT          NOT NULL,
  normalized     TINYINT(1)   NOT NULL DEFAULT 0,
  created_at     DATETIME     DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS contradiction_results (
  result_id        INT          NOT NULL AUTO_INCREMENT PRIMARY KEY,
  case_id          VARCHAR(255),
  user_id          VARCHAR(255),
  stmt_name        VARCHAR(255),
  stmt_type        VARCHAR(255),
  has_contradiction TINYINT(1),
  ai_result        TEXT,
  stmt_text        TEXT,
  created_at       DATETIME DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS case_similar_cache (
  case_id     VARCHAR(255) NOT NULL PRIMARY KEY,
  result_json TEXT,
  analyzed_at DATETIME
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS notifications (
  notif_id    INT          NOT NULL AUTO_INCREMENT PRIMARY KEY,
  user_id     VARCHAR(255),
  type        VARCHAR(255),
  tag         VARCHAR(255),
  title       VARCHAR(255),
  description TEXT,
  link        VARCHAR(255),
  is_unread   TINYINT(1),
  is_critical TINYINT(1),
  created_at  DATETIME DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS access_logs (
  log_id      BIGINT       NOT NULL AUTO_INCREMENT PRIMARY KEY,
  user_id     VARCHAR(50)  NOT NULL,
  user_name   VARCHAR(100),
  target_type VARCHAR(30)  NOT NULL,
  target_id   VARCHAR(100),
  target_name VARCHAR(200),
  ip_address  VARCHAR(50),
  accessed_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_al_user   (user_id),
  INDEX idx_al_target (target_type, target_id),
  INDEX idx_al_time   (accessed_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS relation_boards (
  board_id   INT          NOT NULL AUTO_INCREMENT PRIMARY KEY,
  case_id    VARCHAR(255),
  board_json TEXT,
  created_by VARCHAR(255),
  updated_by VARCHAR(255),
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS relation_persons (
  person_id   INT          NOT NULL AUTO_INCREMENT PRIMARY KEY,
  case_id     VARCHAR(255),
  person_name VARCHAR(255),
  role        VARCHAR(255),
  memo        VARCHAR(255)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS relation_edges (
  edge_id       INT          NOT NULL AUTO_INCREMENT PRIMARY KEY,
  case_id       VARCHAR(255),
  src_person_id VARCHAR(255),
  dst_person_id VARCHAR(255),
  rel_type      VARCHAR(255),
  status        VARCHAR(255),
  context       VARCHAR(255)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS relation_history (
  history_id INT          NOT NULL AUTO_INCREMENT PRIMARY KEY,
  case_id    VARCHAR(255),
  user_id    VARCHAR(255),
  action     VARCHAR(255),
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS board_posts (
  post_id     INT          NOT NULL AUTO_INCREMENT PRIMARY KEY,
  user_id     VARCHAR(255),
  category    VARCHAR(255),
  title       VARCHAR(255),
  content     TEXT,
  view_count  INT,
  like_count  INT,
  anonymous   INT,
  created_at  DATETIME DEFAULT CURRENT_TIMESTAMP,
  updated_at  DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS board_tags (
  tag_id    INT          NOT NULL AUTO_INCREMENT PRIMARY KEY,
  post_id   INT,
  tag_name  VARCHAR(255)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS board_comments (
  comment_id INT          NOT NULL AUTO_INCREMENT PRIMARY KEY,
  post_id    INT,
  user_id    VARCHAR(255),
  content    TEXT,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS board_links (
  link_id   INT          NOT NULL AUTO_INCREMENT PRIMARY KEY,
  post_id   INT,
  link_name VARCHAR(255),
  link_url  VARCHAR(255)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS board_likes (
  user_id     VARCHAR(255) NOT NULL,
  target_type VARCHAR(255) NOT NULL,
  target_id   INT          NOT NULL,
  PRIMARY KEY (user_id, target_type, target_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- emotion_sentences 테이블 (schema-emotion.sql)
CREATE TABLE IF NOT EXISTS emotion_sentences (
  id            BIGINT       NOT NULL AUTO_INCREMENT PRIMARY KEY,
  transcript_id INT          NOT NULL,
  sentence_idx  INT          NOT NULL,
  text          TEXT,
  emotion       VARCHAR(50),
  score         DOUBLE,
  is_highlight  TINYINT(1)   DEFAULT 0,
  created_at    DATETIME     DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
