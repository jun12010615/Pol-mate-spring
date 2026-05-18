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
        "WHERE c.dept_id = (SELECT me.dept_id FROM users me WHERE me.user_id = :userId) " +
        "ORDER BY b.updated_at DESC",
        nativeQuery = true)
    List<Object[]> findBoardsForUser(@Param("userId") String userId);
}
