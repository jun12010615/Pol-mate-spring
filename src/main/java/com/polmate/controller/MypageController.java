package com.polmate.controller;

import com.google.gson.Gson;
import com.polmate.dao.MypageDAO;
import com.polmate.dto.MypageStatsDTO;
import com.polmate.dto.TranscriptDTO;
import com.polmate.dto.UserDTO;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.*;

import jakarta.servlet.http.HttpServletResponse;
import jakarta.servlet.http.HttpSession;
import java.io.IOException;
import java.util.*;

@RestController
@RequestMapping("/mypage")
public class MypageController {

    @Autowired
    private MypageDAO dao;

    private final Gson gson = new Gson();

    @GetMapping
    public void doGet(@RequestParam(defaultValue = "") String action,
                      @RequestParam(required = false) String org,
                      @RequestParam(required = false) String period,
                      HttpServletResponse res, HttpSession session) throws IOException {
        res.setContentType("application/json; charset=UTF-8");
        String userId = getLoginUser(session, res);
        if (userId == null) return;

        switch (action) {
            case "load": {
                UserDTO user = dao.getUserById(userId);
                MypageStatsDTO stats = dao.getStats(userId);
                if (user == null || user.getUserId() == null) {
                    res.setStatus(404);
                    res.getWriter().print(gson.toJson(Map.of("success", false, "message", "사용자 정보를 찾을 수 없습니다."))); return;
                }
                Map<String, Object> settings = dao.getSettings(userId);
                Map<String, Object> result = new HashMap<>();
                result.put("user",     toSafeUserMap(user));
                result.put("stats",    stats);
                result.put("settings", settings);
                res.getWriter().print(gson.toJson(result));
                break;
            }
            case "getDepts": {
                if (org == null || org.trim().isEmpty()) { res.getWriter().print("[]"); return; }
                res.getWriter().print(gson.toJson(dao.getDepartmentsByOrg(org)));
                break;
            }
            case "history": {
                List<TranscriptDTO> history = dao.getTranscriptHistory(userId, 20);
                Map<String, Object> result = new HashMap<>();
                result.put("history", history);
                res.getWriter().print(gson.toJson(result));
                break;
            }
            case "stats": {
                if (period == null || period.isEmpty()) period = "all";
                MypageStatsDTO stats = "all".equals(period) ? dao.getStats(userId) : dao.getStatsByPeriod(userId, period);
                Map<String, Integer> monthly = dao.getMonthlyTranscripts(userId);
                int contraCount = dao.getContradictionCount(userId, period);
                Map<String, Object> result = new HashMap<>();
                result.put("totalCases",         stats.getTotalCases());
                result.put("activeCases",        stats.getActiveCases());
                result.put("totalTranscripts",   stats.getTotalTranscripts());
                result.put("contradictionCount", contraCount);
                result.put("relationEdges",      stats.getRelationEdges());
                result.put("monthly",            monthly);
                res.getWriter().print(gson.toJson(result));
                break;
            }
            default:
                res.setStatus(400);
                res.getWriter().print(gson.toJson(Map.of("success", false, "message", "알 수 없는 action 파라미터입니다.")));
        }
    }

    @PostMapping
    public void doPost(@RequestParam(defaultValue = "") String action,
                       @RequestParam(required = false) String userName,
                       @RequestParam(required = false) String userRank,
                       @RequestParam(required = false) String userOrg,
                       @RequestParam(required = false) String userPhone,
                       @RequestParam(required = false) String deptId,
                       @RequestParam(required = false) String curPw,
                       @RequestParam(required = false) String newPw,
                       @RequestParam(required = false) String newPwCf,
                       @RequestParam(required = false) String password,
                       @RequestParam(required = false) String notifContradiction,
                       @RequestParam(required = false) String notifRelation,
                       @RequestParam(required = false) String nightMode,
                       HttpServletResponse res, HttpSession session) throws IOException {
        res.setContentType("application/json; charset=UTF-8");

        if ("logout".equals(action)) {
            if (session != null) session.invalidate();
            res.sendRedirect("/desktop/login");
            return;
        }

        String userId = getLoginUser(session, res);
        if (userId == null) return;

        switch (action) {
            case "saveSettings": {
                boolean nc  = "1".equals(notifContradiction);
                boolean nr  = "1".equals(notifRelation);
                boolean nm  = "1".equals(nightMode);
                boolean ok = dao.saveSettings(userId, nc, nr, nm);
                res.getWriter().print(ok
                    ? gson.toJson(Map.of("success", true,  "message", "설정이 저장되었습니다."))
                    : gson.toJson(Map.of("success", false, "message", "설정 저장에 실패했습니다.")));
                break;
            }
            case "updateProfile": {
                String uName = trim(userName), uRank = trim(userRank), uOrg = trim(userOrg);
                if (uName.isEmpty() || uRank.isEmpty() || uOrg.isEmpty()) {
                    res.setStatus(400);
                    res.getWriter().print(gson.toJson(Map.of("success", false, "message", "이름, 계급, 소속은 필수 입력 항목입니다."))); return;
                }
                UserDTO dto = new UserDTO();
                dto.setUserId(userId); dto.setUserName(uName); dto.setUserRank(uRank);
                dto.setUserOrg(uOrg); dto.setUserPhone(trim(userPhone));
                try { dto.setDeptId(deptId != null && !deptId.trim().isEmpty() ? Integer.parseInt(deptId.trim()) : null); }
                catch (NumberFormatException e) { dto.setDeptId(null); }
                boolean ok = dao.updateProfile(dto);
                if (ok) {
                    session.setAttribute("userName",  uName);
                    session.setAttribute("userRank",  uRank);
                    session.setAttribute("userOrg",   uOrg);
                    session.setAttribute("userPhone", trim(userPhone));
                    res.getWriter().print(gson.toJson(Map.of("success", true, "message", "프로필이 수정되었습니다.")));
                } else {
                    res.getWriter().print(gson.toJson(Map.of("success", false, "message", "프로필 수정에 실패했습니다.")));
                }
                break;
            }
            case "changePassword": {
                if (isBlank(curPw) || isBlank(newPw) || isBlank(newPwCf)) {
                    res.setStatus(400);
                    res.getWriter().print(gson.toJson(Map.of("success", false, "message", "모든 항목을 입력해 주세요."))); return;
                }
                if (!newPw.equals(newPwCf)) {
                    res.setStatus(400);
                    res.getWriter().print(gson.toJson(Map.of("success", false, "message", "새 비밀번호가 일치하지 않습니다."))); return;
                }
                if (newPw.length() < 8) {
                    res.setStatus(400);
                    res.getWriter().print(gson.toJson(Map.of("success", false, "message", "새 비밀번호는 8자 이상이어야 합니다."))); return;
                }
                if (!dao.checkPassword(userId, curPw)) {
                    res.setStatus(400);
                    res.getWriter().print(gson.toJson(Map.of("success", false, "message", "현재 비밀번호가 올바르지 않습니다."))); return;
                }
                boolean ok = dao.changePassword(userId, newPw);
                res.getWriter().print(ok
                    ? gson.toJson(Map.of("success", true,  "message", "비밀번호가 변경되었습니다."))
                    : gson.toJson(Map.of("success", false, "message", "비밀번호 변경에 실패했습니다.")));
                break;
            }
            case "withdraw": {
                if (isBlank(password)) {
                    res.setStatus(400);
                    res.getWriter().print(gson.toJson(Map.of("success", false, "message", "비밀번호를 입력해 주세요."))); return;
                }
                if (!dao.checkPassword(userId, password)) {
                    res.setStatus(400);
                    res.getWriter().print(gson.toJson(Map.of("success", false, "message", "비밀번호가 올바르지 않습니다."))); return;
                }
                boolean ok = dao.withdrawUser(userId);
                if (ok) {
                    session.invalidate();
                    res.getWriter().print(gson.toJson(Map.of("success", true, "message", "회원탈퇴가 완료되었습니다.")));
                } else {
                    res.getWriter().print(gson.toJson(Map.of("success", false, "message", "탈퇴 처리 중 오류가 발생했습니다.")));
                }
                break;
            }
            default:
                res.setStatus(400);
                res.getWriter().print(gson.toJson(Map.of("success", false, "message", "알 수 없는 action 파라미터입니다.")));
        }
    }

    private Map<String, Object> toSafeUserMap(UserDTO user) {
        Map<String, Object> map = new HashMap<>();
        map.put("userId",    user.getUserId());
        map.put("userName",  user.getUserName());
        map.put("userRank",  user.getUserRank());
        map.put("userOrg",   user.getUserOrg());
        map.put("userPhone", user.getUserPhone());
        map.put("userDept",  user.getUserDept());
        map.put("deptId",    user.getDeptId());
        return map;
    }

    private String getLoginUser(HttpSession session, HttpServletResponse res) throws IOException {
        String u = (session != null) ? (String) session.getAttribute("loginUser") : null;
        if (u == null) {
            res.setStatus(401);
            res.getWriter().print(gson.toJson(Map.of("success", false, "message", "로그인이 필요합니다.")));
        }
        return u;
    }

    private String trim(String s)    { return s == null ? "" : s.trim(); }
    private boolean isBlank(String s){ return s == null || s.trim().isEmpty(); }
}
