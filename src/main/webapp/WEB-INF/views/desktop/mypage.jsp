<%@ page language="java" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8"%>
<%
String loginUser = (String) session.getAttribute("loginUser");
String userName  = (String) session.getAttribute("userName");
String userRank  = (String) session.getAttribute("userRank");
String userOrg   = (String) session.getAttribute("userOrg");
if (userName == null) userName = loginUser != null ? loginUser : "";
if (userRank == null) userRank = "";
if (userOrg  == null) userOrg  = "";
request.setAttribute("currentPage", "mypage");
request.setAttribute("breadcrumb",  new String[]{"POL-MATE", "마이페이지"});
String userInitial = (userName.length() > 0) ? String.valueOf(userName.charAt(0)) : "경";
%>
<!DOCTYPE html>
<html lang="ko">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>POL-MATE | 마이페이지</title>
<link href="https://fonts.googleapis.com/css2?family=Noto+Sans+KR:wght@300;400;500;700&family=Space+Grotesk:wght@500;700&display=swap" rel="stylesheet">
<link rel="stylesheet" href="${pageContext.request.contextPath}/css/polmate.css">
<script>var _ctx = '${pageContext.request.contextPath}';</script>
<style>
* { box-sizing: border-box; margin: 0; padding: 0; }
html, body { height: 100%; font-family: 'Noto Sans KR', sans-serif; background: #f4f6fb; color: #1a1a2e; -webkit-font-smoothing: antialiased; }
.pm-page { padding: 28px 32px 48px; max-width: 1100px; }

.profile-card {
    background: #0d1a33; border-radius: 18px; padding: 28px 32px;
    display: flex; align-items: center; gap: 24px; margin-bottom: 24px;
    position: relative; overflow: hidden;
}
.profile-card::after { content:''; position:absolute; top:-60px; right:-60px; width:200px; height:200px; border-radius:50%; border:1px solid rgba(240,192,64,0.1); }
.avatar-lg {
    width: 72px; height: 72px; border-radius: 16px;
    background: rgba(255,255,255,0.12); border: 2px solid rgba(240,192,64,0.35);
    display: flex; align-items: center; justify-content: center;
    font-size: 26px; font-weight: 700; color: #fff; flex-shrink: 0;
}
.profile-info { flex: 1; min-width: 0; }
.profile-name { font-size: 20px; font-weight: 700; color: #fff; margin-bottom: 4px; }
.profile-rank { font-size: 12px; color: rgba(255,255,255,0.6); margin-bottom: 10px; }
.profile-badges { display: flex; gap: 8px; flex-wrap: wrap; }
.pbadge { display:inline-flex; align-items:center; gap:5px; background:rgba(255,255,255,0.1); border:1px solid rgba(255,255,255,0.18); border-radius:20px; padding:4px 12px; font-size:10px; color:rgba(255,255,255,0.75); }
.pbadge-dot { width:5px; height:5px; border-radius:50%; background:#4ade80; }

.stat-grid { display:grid; grid-template-columns:repeat(3,1fr); gap:12px; margin-bottom:24px; }
.stat-card { background:#fff; border:1px solid #e2e5ee; border-radius:14px; padding:18px; text-align:center; }
.stat-val { font-family:'Space Grotesk',sans-serif; font-size:30px; font-weight:700; color:#0d1a33; line-height:1.1; }
.stat-lbl { font-size:11px; color:#9ca3af; margin-top:5px; }

.content-grid { display:grid; grid-template-columns:1fr 1fr; gap:20px; }
.section-card { background:#fff; border:1px solid #e2e5ee; border-radius:16px; overflow:hidden; }
.section-head { padding:16px 20px; border-bottom:1px solid #e2e5ee; display:flex; align-items:center; justify-content:space-between; }
.section-title { font-size:13px; font-weight:500; }
.section-body  { padding:20px; }

.info-row { display:flex; align-items:center; padding:11px 0; border-bottom:1px solid #f0f2f8; }
.info-row:last-child { border-bottom:none; }
.info-label { font-size:11px; color:#9ca3af; width:90px; flex-shrink:0; }
.info-value { font-size:13px; color:#1a1a2e; flex:1; }
.info-edit  { font-size:11px; color:#4a7cdc; cursor:pointer; }
.info-edit:hover { text-decoration:underline; }

.menu-item { display:flex; align-items:center; gap:12px; padding:13px 0; border-bottom:1px solid #f0f2f8; cursor:pointer; text-decoration:none; color:inherit; transition:background 0.12s; }
.menu-item:last-child { border-bottom:none; }
.menu-item:hover { color:#0d1a33; }
.menu-icon { width:34px; height:34px; border-radius:9px; display:flex; align-items:center; justify-content:center; flex-shrink:0; }
.menu-text { flex:1; }
.menu-label { font-size:13px; font-weight:500; }
.menu-sub   { font-size:10px; color:#9ca3af; margin-top:1px; }
.menu-arrow { color:#9ca3af; }

.danger-zone { background:#fef2f2; border:1px solid #fecaca; border-radius:12px; padding:14px 18px; display:flex; align-items:center; justify-content:space-between; margin-top:8px; }
.btn-logout { padding:8px 18px; background:#dc2626; color:#fff; border:none; border-radius:10px; font-size:12px; font-family:'Noto Sans KR',sans-serif; cursor:pointer; }
.btn-logout:hover { background:#b91c1c; }

/* 비밀번호 변경 모달 */
.modal-backdrop { display:none; position:fixed; inset:0; background:rgba(0,0,0,0.35); z-index:300; align-items:center; justify-content:center; }
.modal-backdrop.open { display:flex; }
.modal { background:#fff; border-radius:16px; padding:28px; width:420px; box-shadow:0 20px 60px rgba(0,0,0,0.2); }
.modal-title { font-size:16px; font-weight:500; margin-bottom:20px; }
.form-field { margin-bottom:14px; }
.form-label { display:block; font-size:10px; font-weight:500; color:#6b7280; text-transform:uppercase; letter-spacing:0.7px; margin-bottom:6px; }
.form-input { width:100%; padding:10px 12px; border:1.5px solid #e2e5ee; border-radius:10px; font-size:13px; font-family:'Noto Sans KR',sans-serif; color:#1a1a2e; background:#f4f6fb; outline:none; transition:border-color 0.15s; }
.form-input:focus { border-color:#0d1a33; background:#fff; box-shadow:0 0 0 3px rgba(13,26,51,0.07); }
.modal-actions { display:flex; gap:8px; justify-content:flex-end; margin-top:20px; }
.btn-cancel  { padding:9px 18px; background:transparent; border:1px solid #e2e5ee; border-radius:10px; font-size:13px; font-family:'Noto Sans KR',sans-serif; cursor:pointer; color:#6b7280; }
.btn-confirm { padding:9px 18px; background:#0d1a33; color:#fff; border:none; border-radius:10px; font-size:13px; font-family:'Noto Sans KR',sans-serif; cursor:pointer; }

.toast { position:fixed; bottom:28px; left:50%; transform:translateX(-50%) translateY(80px); background:#1a2744; color:#fff; padding:10px 20px; border-radius:10px; font-size:13px; font-family:'Noto Sans KR',sans-serif; opacity:0; transition:all 0.25s; z-index:500; white-space:nowrap; }
.toast.show { opacity:1; transform:translateX(-50%) translateY(0); }

@media (max-width:1000px) { .content-grid { grid-template-columns:1fr; } }
</style>
</head>
<body>
<div class="pm-layout">

<%@ include file="sidebar.jsp" %>
<div class="pm-content">
<%@ include file="appbar.jsp" %>

<main class="pm-page">

    <div class="profile-card">
        <div class="avatar-lg"><%= userInitial %></div>
        <div class="profile-info">
            <div class="profile-name"><%= userRank.isEmpty() ? "" : userRank + " " %><%= userName %></div>
            <div class="profile-rank"><%= userOrg.isEmpty() ? "POL-MATE 수사관" : userOrg %></div>
            <div class="profile-badges">
                <span class="pbadge"><span class="pbadge-dot"></span>활성 계정</span>
                <span class="pbadge">ID: <%= loginUser %></span>
            </div>
        </div>
    </div>

    <div class="stat-grid">
        <div class="stat-card"><div class="stat-val" id="statCase">-</div><div class="stat-lbl">담당 사건 수</div></div>
        <div class="stat-card"><div class="stat-val" id="statTranscript">-</div><div class="stat-lbl">작성 진술 조서</div></div>
        <div class="stat-card"><div class="stat-val" id="statBoard">-</div><div class="stat-lbl">커뮤니티 게시글</div></div>
    </div>

    <div class="content-grid">

        <div class="section-card">
            <div class="section-head">
                <span class="section-title">계정 정보</span>
            </div>
            <div class="section-body">
                <div class="info-row">
                    <span class="info-label">아이디</span>
                    <span class="info-value"><%= loginUser %></span>
                </div>
                <div class="info-row">
                    <span class="info-label">이름</span>
                    <span class="info-value"><%= userName %></span>
                </div>
                <div class="info-row">
                    <span class="info-label">계급</span>
                    <span class="info-value"><%= userRank.isEmpty() ? "-" : userRank %></span>
                </div>
                <div class="info-row">
                    <span class="info-label">소속 기관</span>
                    <span class="info-value"><%= userOrg.isEmpty() ? "-" : userOrg %></span>
                </div>
                <div class="info-row">
                    <span class="info-label">연락처</span>
                    <span class="info-value" id="infoPhone">-</span>
                </div>
                <div class="info-row">
                    <span class="info-label">이메일</span>
                    <span class="info-value" id="infoEmail">-</span>
                </div>
            </div>
        </div>

        <div>
            <div class="section-card" style="margin-bottom:16px;">
                <div class="section-head"><span class="section-title">빠른 이동</span></div>
                <div class="section-body">
                    <a href="${pageContext.request.contextPath}/desktop/myCase" class="menu-item">
                        <div class="menu-icon" style="background:#eff6ff;">
                            <svg width="17" height="17" viewBox="0 0 24 24" fill="none" stroke="#1e40af" stroke-width="1.8" stroke-linecap="round"><path d="M22 19a2 2 0 0 1-2 2H4a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h5l2 3h9a2 2 0 0 1 2 2z"/></svg>
                        </div>
                        <div class="menu-text">
                            <div class="menu-label">내 사건 관리</div>
                            <div class="menu-sub">담당 사건 목록 조회 및 수정</div>
                        </div>
                        <svg class="menu-arrow" width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"><polyline points="9 18 15 12 9 6"/></svg>
                    </a>
                    <a href="${pageContext.request.contextPath}/desktop/writeTranscript" class="menu-item">
                        <div class="menu-icon" style="background:#f0fdf4;">
                            <svg width="17" height="17" viewBox="0 0 24 24" fill="none" stroke="#16a34a" stroke-width="1.8" stroke-linecap="round"><path d="M12 1a3 3 0 0 0-3 3v8a3 3 0 0 0 6 0V4a3 3 0 0 0-3-3z"/><path d="M19 10v2a7 7 0 0 1-14 0v-2"/><line x1="12" y1="19" x2="12" y2="23"/></svg>
                        </div>
                        <div class="menu-text">
                            <div class="menu-label">진술 조서 작성</div>
                            <div class="menu-sub">STT 기반 자동 조서화</div>
                        </div>
                        <svg class="menu-arrow" width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"><polyline points="9 18 15 12 9 6"/></svg>
                    </a>
                    <a href="${pageContext.request.contextPath}/desktop/board" class="menu-item">
                        <div class="menu-icon" style="background:#fffbeb;">
                            <svg width="17" height="17" viewBox="0 0 24 24" fill="none" stroke="#92400e" stroke-width="1.8" stroke-linecap="round"><path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z"/></svg>
                        </div>
                        <div class="menu-text">
                            <div class="menu-label">커뮤니티 게시판</div>
                            <div class="menu-sub">수사관 정보 공유</div>
                        </div>
                        <svg class="menu-arrow" width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"><polyline points="9 18 15 12 9 6"/></svg>
                    </a>
                </div>
            </div>

            <div class="section-card">
                <div class="section-head"><span class="section-title">계정 설정</span></div>
                <div class="section-body">
                    <div class="menu-item" onclick="openPwModal()">
                        <div class="menu-icon" style="background:#f4f6fb;">
                            <svg width="17" height="17" viewBox="0 0 24 24" fill="none" stroke="#6b7280" stroke-width="1.8" stroke-linecap="round"><rect x="3" y="11" width="18" height="11" rx="2"/><path d="M7 11V7a5 5 0 0 1 10 0v4"/></svg>
                        </div>
                        <div class="menu-text">
                            <div class="menu-label">비밀번호 변경</div>
                            <div class="menu-sub">현재 비밀번호 확인 후 변경</div>
                        </div>
                        <svg class="menu-arrow" width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"><polyline points="9 18 15 12 9 6"/></svg>
                    </div>
                    <div class="danger-zone">
                        <div>
                            <div style="font-size:13px; font-weight:500; color:#dc2626;">로그아웃</div>
                            <div style="font-size:11px; color:#9ca3af; margin-top:2px;">현재 세션을 종료합니다.</div>
                        </div>
                        <form action="${pageContext.request.contextPath}/mypage" method="post" onsubmit="return confirm('로그아웃 하시겠습니까?');">
                            <input type="hidden" name="action" value="logout">
                            <button type="submit" class="btn-logout">로그아웃</button>
                        </form>
                    </div>
                </div>
            </div>
        </div>

    </div>

</main>
</div>
</div>

<!-- 비밀번호 변경 모달 -->
<div class="modal-backdrop" id="pwModal">
    <div class="modal" onclick="event.stopPropagation()">
        <div class="modal-title">비밀번호 변경</div>
        <div class="form-field">
            <label class="form-label">현재 비밀번호</label>
            <input type="password" class="form-input" id="curPw" placeholder="현재 비밀번호 입력">
        </div>
        <div class="form-field">
            <label class="form-label">새 비밀번호</label>
            <input type="password" class="form-input" id="newPw" placeholder="8자 이상, 영문+숫자+특수문자">
        </div>
        <div class="form-field">
            <label class="form-label">새 비밀번호 확인</label>
            <input type="password" class="form-input" id="newPwCf" placeholder="새 비밀번호를 다시 입력">
        </div>
        <div class="modal-actions">
            <button class="btn-cancel" onclick="closePwModal()">취소</button>
            <button class="btn-confirm" onclick="submitPwChange()">변경</button>
        </div>
    </div>
</div>

<div class="toast" id="toast"></div>

<script>
(function() {
    fetch(_ctx + '/mypage?action=load', {credentials: 'same-origin'})
        .then(function(r) { return r.json(); })
        .then(function(d) {
            var u = d.user || {};
            if (document.getElementById('infoPhone')) document.getElementById('infoPhone').textContent = u.userPhone || '-';
            if (document.getElementById('infoEmail')) document.getElementById('infoEmail').textContent = u.userEmail || '-';
            var s = d.stats || {};
            if (document.getElementById('statCase')) document.getElementById('statCase').textContent = s.totalCases != null ? s.totalCases : '-';
            if (document.getElementById('statTranscript')) document.getElementById('statTranscript').textContent = s.completedTranscripts != null ? s.completedTranscripts : '-';
            if (document.getElementById('statBoard')) document.getElementById('statBoard').textContent = '-';
        }).catch(function() {});
})();

function openPwModal()  { document.getElementById('pwModal').classList.add('open'); }
function closePwModal() { document.getElementById('pwModal').classList.remove('open'); ['curPw','newPw','newPwCf'].forEach(function(id){document.getElementById(id).value='';}); }

function submitPwChange() {
    var cur   = document.getElementById('curPw').value;
    var np    = document.getElementById('newPw').value;
    var npcf  = document.getElementById('newPwCf').value;
    if (!cur) { showToast('현재 비밀번호를 입력해 주세요.'); return; }
    if (!np || np.length < 8) { showToast('새 비밀번호를 8자 이상 입력해 주세요.'); return; }
    if (np !== npcf) { showToast('새 비밀번호가 일치하지 않습니다.'); return; }
    var fd = new FormData();
    fd.append('action', 'changePassword');
    fd.append('curPw', cur);
    fd.append('newPw', np);
    fd.append('newPwCf', npcf);
    fetch(_ctx + '/mypage', {method:'POST', body:fd, credentials:'same-origin'})
        .then(function(r){return r.json();})
        .then(function(d){
            if (d.success) { closePwModal(); showToast('비밀번호가 변경되었습니다.'); }
            else { showToast(d.message || '변경에 실패했습니다.'); }
        }).catch(function(){ showToast('서버 통신 오류가 발생했습니다.'); });
}

function showToast(msg) {
    var t = document.getElementById('toast'); t.textContent=msg; t.classList.add('show');
    setTimeout(function(){t.classList.remove('show');}, 2500);
}

document.getElementById('pwModal').addEventListener('click', function(e){if(e.target===this)closePwModal();});
</script>
</body>
</html>
