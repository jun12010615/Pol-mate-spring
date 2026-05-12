package com.polmate.repository;

import com.polmate.entity.RelationBoard;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;
import java.util.Optional;

public interface RelationBoardRepository extends JpaRepository<RelationBoard, Integer> {

    Optional<RelationBoard> findByCaseId(String caseId);

    boolean existsByCaseId(String caseId);

    void deleteByCaseId(String caseId);

    @Query(value =
        "SELECT b.board_id, b.case_id, c.case_name, c.status, b.updated_at, u.user_name AS updater_name, b.board_json " +
        "FROM relation_boards b JOIN cases c ON b.case_id = c.case_id " +
        "LEFT JOIN users u ON b.updated_by = u.user_id " +
        "WHERE (c.user_id = :userId OR c.user_id IN (" +
        "  SELECT u2.user_id FROM users u2 JOIN users me ON me.user_id = :userId " +
        "  WHERE u2.dept_id = me.dept_id AND me.dept_id IS NOT NULL)) " +
        "ORDER BY b.updated_at DESC",
        nativeQuery = true)
    List<Object[]> findBoardsForUser(@Param("userId") String userId);
}
