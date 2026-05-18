package com.polmate.config;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;

@Component
@RequiredArgsConstructor
@Slf4j
public class TimelineSchemaInitializer implements ApplicationRunner {

    private final JdbcTemplate jdbc;

    private static final String CREATE_TIMELINE_EVENTS = """
        CREATE TABLE IF NOT EXISTS timeline_events (
            event_id           BIGINT       NOT NULL AUTO_INCREMENT,
            case_id            VARCHAR(20)  NOT NULL,
            transcript_id      INT          NULL,
            lane_key           VARCHAR(100) NOT NULL,
            stmt_name          VARCHAR(100) NULL,
            stmt_type          VARCHAR(50)  NULL,
            event_type         VARCHAR(30)  NOT NULL,
            time_start         DATETIME     NULL,
            time_end           DATETIME     NULL,
            time_text          VARCHAR(200) NULL,
            time_precision     VARCHAR(20)  NULL,
            anchor_sort_order  INT          NULL,
            offset_minutes     INT          NULL,
            offset_end_minutes INT          NULL,
            place              VARCHAR(200) NULL,
            label              VARCHAR(300) NOT NULL,
            quote              TEXT         NULL,
            confidence         VARCHAR(20)  NULL,
            sort_order         INT          NOT NULL DEFAULT 0,
            created_at         DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (event_id),
            KEY idx_timeline_case (case_id),
            KEY idx_timeline_case_time (case_id, time_start),
            KEY idx_timeline_transcript (transcript_id)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
        """;

    private static final String[] MIGRATE_COLUMNS = {
        "ALTER TABLE timeline_events ADD COLUMN time_precision VARCHAR(20) NULL",
        "ALTER TABLE timeline_events ADD COLUMN anchor_sort_order INT NULL",
        "ALTER TABLE timeline_events ADD COLUMN offset_minutes INT NULL",
        "ALTER TABLE timeline_events ADD COLUMN offset_end_minutes INT NULL",
    };

    @Override
    public void run(ApplicationArguments args) {
        try {
            jdbc.execute(CREATE_TIMELINE_EVENTS);
            for (String sql : MIGRATE_COLUMNS) {
                try {
                    jdbc.execute(sql);
                } catch (Exception ignored) {
                    // column already exists
                }
            }
            log.info("timeline_events table ready");
        } catch (Exception e) {
            log.warn("timeline_events init failed: {}", e.getMessage());
        }
    }
}
