package com.polmate.service;

import com.polmate.entity.*;
import com.polmate.repository.*;
import lombok.RequiredArgsConstructor;
import org.json.JSONArray;
import org.json.JSONObject;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.support.GeneratedKeyHolder;
import org.springframework.jdbc.support.KeyHolder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.sql.PreparedStatement;
import java.sql.Statement;
import java.time.LocalDateTime;
import java.util.*;

@Service
@RequiredArgsConstructor
public class RelationBoardService {

    private final RelationBoardRepository boardRepo;
    private final RelationPersonRepository personRepo;
    private final RelationEdgeRepository edgeRepo;
    private final RelationHistoryRepository historyRepo;
    private final CaseRepository caseRepo;
    private final NotificationRepository notifRepo;
    private final UserRepository userRepo;
    private final JdbcTemplate jdbc;

    public boolean hasAccess(String caseId, String userId) {
        return caseRepo.checkAccess(caseId, userId).isPresent();
    }

    public Optional<Map<String, Object>> load(String caseId, String userId) {
        if (!hasAccess(caseId, userId)) return Optional.empty();
        List<Map<String, Object>> rows = jdbc.queryForList(
            "SELECT b.board_id, b.case_id, b.board_json, b.created_at, b.updated_at, " +
            "u1.user_name AS creator_name, u2.user_name AS updater_name, c.case_name " +
            "FROM relation_boards b LEFT JOIN users u1 ON b.created_by=u1.user_id " +
            "LEFT JOIN users u2 ON b.updated_by=u2.user_id LEFT JOIN cases c ON b.case_id=c.case_id " +
            "WHERE b.case_id=?", caseId);
        return rows.isEmpty() ? Optional.empty() : Optional.of(rows.get(0));
    }

    public List<Map<String, Object>> listBoards(String userId) {
        return jdbc.queryForList(
            "SELECT b.board_id, b.case_id, c.case_name, c.status, b.updated_at, " +
            "u.user_name AS updater_name, b.board_json " +
            "FROM relation_boards b JOIN cases c ON b.case_id=c.case_id " +
            "LEFT JOIN users u ON b.updated_by=u.user_id " +
            "WHERE c.dept_id=(SELECT me.dept_id FROM users me WHERE me.user_id=?) " +
            "ORDER BY b.updated_at DESC", userId);
    }

    @Transactional
    public Map<String, Object> save(String userId, String caseId, String boardJson, boolean isUpdate) {
        Map<String, Object> result = new HashMap<>();
        if (!hasAccess(caseId, userId)) {
            result.put("success", false);
            result.put("message", "접근 권한이 없습니다.");
            result.put("error", "접근 권한이 없습니다.");
            return result;
        }
        boolean exists = boardRepo.existsByCaseId(caseId);
        if (exists) {
            jdbc.update("UPDATE relation_boards SET board_json=?, updated_by=?, updated_at=NOW() WHERE case_id=?",
                boardJson, userId, caseId);
        } else {
            jdbc.update("INSERT INTO relation_boards (case_id, created_by, updated_by, board_json) VALUES (?,?,?,?)",
                caseId, userId, userId, boardJson);
        }

        syncPersonsAndEdges(caseId, boardJson, userId);

        String caseName = caseRepo.findById(caseId).map(Case::getCaseName).orElse("");
        String tag   = isUpdate ? "관계망" : "새 사건";
        String title = isUpdate ? "관계망 보드 업데이트: " + caseId : "관계망 보드 등록: " + caseId;
        String desc  = isUpdate
            ? "사건 " + caseId + "(" + caseName + ")의 관계망 보드가 업데이트됐습니다."
            : "사건 " + caseId + "(" + caseName + ")의 관계망 보드가 등록됐습니다.";
        List<String> teammates = userRepo.findTeammateIds(userId);
        for (String tm : teammates) {
            try {
                notifRepo.save(Notification.builder()
                    .userId(tm).type("case").tag(tag).title(title).description(desc)
                    .link("boardView.jsp?caseId=" + caseId)
                    .isUnread(true).isCritical(false).createdAt(LocalDateTime.now()).build());
            } catch (Exception ignored) {}
        }

        result.put("success", true); result.put("isUpdate", exists);
        result.put("message", exists ? "보드가 업데이트됐습니다." : "보드가 저장됐습니다.");
        return result;
    }

    @Transactional
    public boolean delete(String userId, String caseId) {
        if (!hasAccess(caseId, userId)) return false;
        boardRepo.deleteByCaseId(caseId);
        return true;
    }

    private void syncPersonsAndEdges(String caseId, String boardJson, String userId) {
        personRepo.deleteByCaseId(caseId);
        edgeRepo.deleteByCaseId(caseId);
        try {
            JSONObject bj = new JSONObject(boardJson);
            JSONArray persons = bj.optJSONArray("persons");
            JSONArray edges   = bj.optJSONArray("edges");
            Map<String, Integer> nameToId = new HashMap<>();
            int pCount = 0, eCount = 0;

            if (persons != null) {
                for (int i = 0; i < persons.length(); i++) {
                    JSONObject p = persons.getJSONObject(i);
                    String name = p.optString("name", "").trim();
                    if (name.isEmpty() || nameToId.containsKey(name)) continue;
                    KeyHolder kh = new GeneratedKeyHolder();
                    jdbc.update(con -> {
                        PreparedStatement ps = con.prepareStatement(
                            "INSERT INTO relation_persons (case_id, person_name, role, memo) VALUES (?,?,?,?)",
                            Statement.RETURN_GENERATED_KEYS);
                        ps.setString(1, caseId); ps.setString(2, name);
                        ps.setString(3, p.optString("role", "reference"));
                        ps.setString(4, p.optString("memo", ""));
                        return ps;
                    }, kh);
                    if (kh.getKey() != null) nameToId.put(name, kh.getKey().intValue());
                    pCount++;
                }
            }
            if (edges != null) {
                for (int i = 0; i < edges.length(); i++) {
                    JSONObject e = edges.getJSONObject(i);
                    Integer srcId = nameToId.get(e.optString("srcName", ""));
                    Integer dstId = nameToId.get(e.optString("dstName", ""));
                    if (srcId == null || dstId == null) continue;
                    String ctx = e.optString("context", "").trim();
                    if (!Set.of("scene","time","evidence").contains(ctx)) ctx = null;
                    jdbc.update(
                        "INSERT INTO relation_edges (case_id, src_person_id, dst_person_id, rel_type, status, context) VALUES (?,?,?,?,?,?)",
                        caseId, String.valueOf(srcId), String.valueOf(dstId),
                        e.optString("relType", "acquaint"), e.optString("status", "unknown"), ctx);
                    eCount++;
                }
            }
            historyRepo.save(RelationHistory.builder()
                .caseId(caseId).userId(userId)
                .action("보드 저장: 인물 " + pCount + "명, 관계선 " + eCount + "개")
                .createdAt(LocalDateTime.now()).build());
        } catch (Exception e) {
            throw new IllegalStateException("관계망 인물·관계선 동기화 실패: " + e.getMessage(), e);
        }
    }
}
