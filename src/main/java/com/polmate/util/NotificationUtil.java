package com.polmate.util;

import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.SQLException;

public class NotificationUtil {

    public static void insertNotification(Connection conn,
                                          String userId,
                                          String type,
                                          String tag,
                                          String title,
                                          String description,
                                          String link,
                                          boolean isCritical) throws SQLException {
        PreparedStatement ps = null;
        try {
            ps = conn.prepareStatement(
                "INSERT INTO notifications (user_id, type, tag, title, description, link, is_unread, is_critical) " +
                "VALUES (?, ?, ?, ?, ?, ?, 1, ?)");
            ps.setString(1, userId);
            ps.setString(2, type);
            ps.setString(3, tag);
            ps.setString(4, title);
            ps.setString(5, description);
            ps.setString(6, link);
            ps.setBoolean(7, isCritical);
            ps.executeUpdate();
        } finally {
            if (ps != null) try { ps.close(); } catch (SQLException ignore) {}
        }
    }
}
