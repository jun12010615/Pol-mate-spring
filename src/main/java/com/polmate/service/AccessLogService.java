package com.polmate.service;

import com.polmate.entity.AccessLog;
import com.polmate.repository.AccessLogRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Service;

import java.util.ArrayList;
import java.util.List;
import java.util.Map;

@Service
@RequiredArgsConstructor
public class AccessLogService {

    private final AccessLogRepository accessLogRepo;
    private final JdbcTemplate jdbc;

    @Async
    public void saveAsync(String userId, String userName, String targetType,
                          String targetId, String targetName, String ip) {
        try {
            AccessLog log = new AccessLog();
            log.setUserId(userId);
            log.setUserName(userName);
            log.setTargetType(targetType);
            log.setTargetId(targetId);
            log.setTargetName(targetName);
            log.setIpAddress(ip);
            accessLogRepo.save(log);
        } catch (Exception ignored) {}
    }

    public List<Map<String, Object>> list(String myUserId, String targetType,
                                          String fromDate, String toDate, int page, int size) {
        StringBuilder sql = new StringBuilder(
            "SELECT al.log_id, al.user_id, al.user_name, al.target_type, " +
            "al.target_id, al.target_name, al.ip_address, al.accessed_at " +
            "FROM access_logs al " +
            "WHERE al.user_id IN (" +
            "  SELECT user_id FROM users WHERE dept_id=(SELECT dept_id FROM users WHERE user_id=?)" +
            ") ");
        List<Object> params = new ArrayList<>();
        params.add(myUserId);

        if (targetType != null && !targetType.isEmpty()) {
            sql.append("AND al.target_type=? ");
            params.add(targetType);
        }
        if (fromDate != null && !fromDate.isEmpty()) {
            sql.append("AND DATE(al.accessed_at)>=? ");
            params.add(fromDate);
        }
        if (toDate != null && !toDate.isEmpty()) {
            sql.append("AND DATE(al.accessed_at)<=? ");
            params.add(toDate);
        }

        sql.append("ORDER BY al.accessed_at DESC LIMIT ? OFFSET ?");
        params.add(size);
        params.add(page * size);

        return jdbc.queryForList(sql.toString(), params.toArray());
    }

    public Map<String, Object> stats(String myUserId) {
        return jdbc.queryForMap(
            "SELECT " +
            "SUM(CASE WHEN DATE(accessed_at)=CURDATE() THEN 1 ELSE 0 END) AS today, " +
            "SUM(CASE WHEN accessed_at >= DATE_SUB(NOW(), INTERVAL 7 DAY) THEN 1 ELSE 0 END) AS week " +
            "FROM access_logs " +
            "WHERE user_id IN (SELECT user_id FROM users WHERE dept_id=(SELECT dept_id FROM users WHERE user_id=?))",
            myUserId);
    }
}
