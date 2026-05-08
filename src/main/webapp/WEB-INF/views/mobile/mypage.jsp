<%@ page language="java" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8"%>
<!DOCTYPE html>
<html lang="ko">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
<title>POL-MATE | 마이페이지</title>
<link href="https://fonts.googleapis.com/css2?family=Noto+Sans+KR:wght@300;400;500;700&display=swap" rel="stylesheet">
<style>
  * { margin: 0; padding: 0; box-sizing: border-box; -webkit-tap-highlight-color: transparent; }

  :root {
    --navy: #1a2744;
    --navy-light: #243358;
    --accent: #4a7cdc;
    --danger: #e74c3c;
    --text-primary: #1a1a2e;
    --text-secondary: #6b7280;
    --text-muted: #9ca3af;
    --bg: #f4f6fb;
    --card: #ffffff;
    --border: #e5e7eb;
    --success: #16a34a;
    --success-bg: #f0fdf4;
    --danger-bg: #fef2f2;
    --danger-border: #fecaca;
    --bottom-nav-h: 64px;
  }

  html, body {
    height: 100%;
    font-family: 'Noto Sans KR', sans-serif;
    background: var(--bg);
    overflow-x: hidden;
  }

  .screen {
    width: 100%;
    max-width: 420px;
    min-height: 100vh;
    margin: 0 auto;
    background: var(--bg);
    display: flex;
    flex-direction: column;
  }

  /* ── 헤더 ── */
  .top-header {
    background: var(--navy);
    padding: 52px 20px 0;
    position: sticky;
    top: 0;
    z-index: 10;
  }

  .header-row {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding-bottom: 20px;
  }

  .header-title { font-size: 17px; font-weight: 500; color: #fff; }

  .edit-btn {
    background: rgba(255,255,255,0.12);
    border: 1px solid rgba(255,255,255,0.2);
    color: #fff;
    border-radius: 20px;
    padding: 6px 14px;
    font-size: 12px;
    font-family: 'Noto Sans KR', sans-serif;
    cursor: pointer;
    transition: background 0.2s;
  }
  .edit-btn:active { background: rgba(255,255,255,0.2); }

  /* ── 프로필 카드 ── */
  .profile-band {
    background: var(--navy);
    padding: 0 20px 28px;
  }

  .profile-card {
    background: rgba(255,255,255,0.08);
    border: 1px solid rgba(255,255,255,0.15);
    border-radius: 18px;
    padding: 20px;
    display: flex;
    align-items: center;
    gap: 16px;
  }

  .avatar-lg {
    width: 60px;
    height: 60px;
    border-radius: 50%;
    background: rgba(255,255,255,0.2);
    border: 2px solid rgba(255,255,255,0.35);
    display: flex;
    align-items: center;
    justify-content: center;
    font-size: 18px;
    font-weight: 700;
    color: #fff;
    flex-shrink: 0;
  }

  .profile-info { flex: 1; min-width: 0; }

  .profile-name {
    font-size: 17px;
    font-weight: 700;
    color: #fff;
    margin-bottom: 4px;
  }

  .profile-rank {
    font-size: 12px;
    color: rgba(255,255,255,0.65);
    margin-bottom: 6px;
  }

  .profile-badge {
    display: inline-flex;
    align-items: center;
    gap: 5px;
    background: rgba(255,255,255,0.15);
    border-radius: 20px;
    padding: 3px 10px;
    font-size: 10px;
    color: rgba(255,255,255,0.85);
  }

  .badge-dot {
    width: 5px;
    height: 5px;
    border-radius: 50%;
    background: #4ade80;
  }

  /* ── 통계 띠 ── */
  .stats-band {
    background: var(--navy);
    padding: 0 20px 0;
  }

  .stats-strip {
    background: var(--card);
    border-radius: 16px 16px 0 0;
    padding: 16px 0 0;
    display: grid;
    grid-template-columns: repeat(3, 1fr);
  }

  .stat-col {
    text-align: center;
    padding: 10px 0 16px;
    position: relative;
  }

  .stat-col::after {
    content: '';
    position: absolute;
    right: 0; top: 20%; bottom: 20%;
    width: 1px;
    background: var(--border);
  }
  .stat-col:last-child::after { display: none; }

  .stat-num { font-size: 22px; font-weight: 700; color: var(--navy); }
  .stat-lbl { font-size: 10px; color: var(--text-muted); margin-top: 3px; }

  /* ── 스크롤 영역 ── */
  .content {
    flex: 1;
    overflow-y: auto;
    padding-bottom: calc(var(--bottom-nav-h) + 16px);
    background: var(--bg);
  }

  .section {
    padding: 16px 16px 0;
  }

  .section-label {
    font-size: 10px;
    font-weight: 500;
    color: var(--text-muted);
    letter-spacing: 0.8px;
    text-transform: uppercase;
    margin-bottom: 8px;
    padding-left: 4px;
  }

  /* ── 메뉴 리스트 카드 ── */
  .menu-list {
    background: var(--card);
    border-radius: 14px;
    border: 1px solid var(--border);
    overflow: hidden;
    margin-bottom: 0;
  }

  .menu-row {
    display: flex;
    align-items: center;
    padding: 15px 16px;
    cursor: pointer;
    transition: background 0.15s;
    text-decoration: none;
    border-bottom: 1px solid var(--border);
  }
  .menu-row:last-child { border-bottom: none; }
  .menu-row:active { background: var(--bg); }

  .menu-icon-wrap {
    width: 36px;
    height: 36px;
    border-radius: 10px;
    display: flex;
    align-items: center;
    justify-content: center;
    margin-right: 14px;
    flex-shrink: 0;
  }

  .menu-icon-wrap svg { width: 18px; height: 18px; }

  .bg-blue   { background: #eff6ff; }
  .bg-green  { background: #f0fdf4; }
  .bg-amber  { background: #fffbeb; }
  .bg-purple { background: #f5f3ff; }
  .bg-red    { background: #fef2f2; }
  .bg-gray   { background: #f3f4f6; }
  .bg-navy   { background: #f0f3f9; }

  .stroke-blue   { stroke: #1d4ed8; }
  .stroke-green  { stroke: #15803d; }
  .stroke-amber  { stroke: #b45309; }
  .stroke-purple { stroke: #7c3aed; }
  .stroke-red    { stroke: #dc2626; }
  .stroke-gray   { stroke: #6b7280; }
  .stroke-navy   { stroke: #1a2744; }

  .menu-text { flex: 1; }
  .menu-name { font-size: 14px; color: var(--text-primary); font-weight: 400; }
  .menu-sub  { font-size: 11px; color: var(--text-muted); margin-top: 2px; }

  .menu-right {
    display: flex;
    align-items: center;
    gap: 8px;
  }

  .menu-value { font-size: 12px; color: var(--text-muted); }
  .menu-arrow svg { width: 16px; height: 16px; stroke: var(--text-muted); }

  .toggle-wrap { position: relative; width: 44px; height: 26px; }
  .toggle-input { opacity: 0; width: 0; height: 0; position: absolute; }
  .toggle-slider {
    position: absolute; inset: 0;
    background: var(--border);
    border-radius: 13px;
    cursor: pointer;
    transition: background 0.25s;
  }
  .toggle-slider::before {
    content: '';
    position: absolute;
    width: 20px; height: 20px;
    border-radius: 50%;
    background: #fff;
    top: 3px; left: 3px;
    transition: transform 0.25s;
    box-shadow: 0 1px 3px rgba(0,0,0,0.2);
  }
  .toggle-input:checked + .toggle-slider { background: var(--navy); }
  .toggle-input:checked + .toggle-slider::before { transform: translateX(18px); }

  /* ── 드로어 오버레이 ── */
  .overlay {
    position: fixed; inset: 0;
    background: rgba(0,0,0,0.45);
    z-index: 200;
    display: none;
    align-items: flex-end;
    justify-content: center;
  }
  .overlay.open { display: flex; }

  .drawer {
    background: var(--card);
    border-radius: 20px 20px 0 0;
    width: 100%;
    max-width: 420px;
    padding: 0 0 32px;
    animation: slideUp 0.28s ease both;
    max-height: 90vh;
    overflow-y: auto;
  }

  .drawer-handle {
    width: 36px; height: 4px;
    background: var(--border);
    border-radius: 2px;
    margin: 12px auto 20px;
  }

  .drawer-title {
    font-size: 16px;
    font-weight: 500;
    color: var(--text-primary);
    padding: 0 20px 16px;
    border-bottom: 1px solid var(--border);
  }

  .drawer-body { padding: 20px; }

  .d-field { margin-bottom: 14px; }
  .d-label {
    font-size: 11px;
    font-weight: 500;
    color: var(--text-secondary);
    display: block;
    margin-bottom: 6px;
  }
  .d-input {
    width: 100%;
    padding: 12px 14px;
    background: var(--bg);
    border: 1px solid var(--border);
    border-radius: 10px;
    font-size: 14px;
    font-family: 'Noto Sans KR', sans-serif;
    color: var(--text-primary);
    outline: none;
    transition: border-color 0.2s;
  }
  .d-input:focus { border-color: var(--accent); background: #fff; }
  .d-input:disabled { color: var(--text-muted); }

  .d-btn {
    width: 100%;
    background: var(--navy);
    color: #fff;
    border: none;
    border-radius: 12px;
    padding: 14px;
    font-size: 14px;
    font-weight: 500;
    font-family: 'Noto Sans KR', sans-serif;
    cursor: pointer;
    margin-top: 6px;
    transition: transform 0.1s;
  }
  .d-btn:active { transform: scale(0.98); }

  .d-btn-cancel {
    width: 100%;
    background: var(--bg);
    color: var(--text-secondary);
    border: 1px solid var(--border);
    border-radius: 12px;
    padding: 13px;
    font-size: 14px;
    font-family: 'Noto Sans KR', sans-serif;
    cursor: pointer;
    margin-top: 8px;
  }

  /* 조서 이력 리스트 */
  .history-list { padding: 0 20px; }
  .history-item {
    border-bottom: 1px solid var(--border);
    display: flex;
    justify-content: space-between;
    align-items: center;
    cursor: pointer;
    transition: background 0.15s;
    margin: 0 -20px;
    padding: 14px 20px;
  }
  .history-item:last-child { border-bottom: none; }
  .history-item:active { background: var(--bg); }
  .h-title { font-size: 13px; font-weight: 500; color: var(--text-primary); margin-bottom: 4px; }
  .h-meta  { font-size: 11px; color: var(--text-muted); }
  .h-right { display: flex; align-items: center; gap: 8px; flex-shrink: 0; }
  .h-arrow svg { width: 14px; height: 14px; stroke: var(--text-muted); }
  .h-badge {
    font-size: 10px; padding: 3px 9px; border-radius: 20px; white-space: nowrap; flex-shrink: 0;
  }
  .h-badge-ok   { background: #f0fdf4; color: #15803d; }
  .h-badge-warn { background: #fffbeb; color: #92400e; }
  .h-badge-done { background: #eff6ff; color: #1e40af; }

  /* 로그아웃 버튼 */
  .logout-btn {
    width: calc(100% - 32px);
    margin: 0 16px;
    background: var(--card);
    border: 1px solid #fca5a5;
    border-radius: 12px;
    padding: 15px;
    color: var(--danger);
    font-size: 14px;
    font-weight: 500;
    font-family: 'Noto Sans KR', sans-serif;
    cursor: pointer;
    display: flex;
    align-items: center;
    justify-content: center;
    gap: 8px;
    transition: background 0.2s;
  }
  .logout-btn svg { width: 16px; height: 16px; stroke: var(--danger); }
  .logout-btn:active { background: #fef2f2; }

  /* 앱 정보 */
  .app-info-card {
    background: var(--card);
    border-radius: 14px;
    border: 1px solid var(--border);
    padding: 20px;
    text-align: center;
  }
  .app-ver  { font-size: 13px; color: var(--text-secondary); margin-bottom: 6px; }
  .app-name { font-size: 20px; font-weight: 700; color: var(--navy); letter-spacing: 2px; margin-bottom: 4px; }
  .app-copy { font-size: 10px; color: var(--text-muted); }

  /* ── 하단 네비 ── */
  .bottom-nav{
  position:fixed;bottom:0;left:50%;transform:translateX(-50%);
  width:100%;max-width:420px;height:64px;
  background:#ffffff;border-top:1px solid #e2e5ee;
  display:flex;z-index:100;
}
.nav-item{flex:1;display:flex;flex-direction:column;align-items:center;justify-content:center;gap:3px;text-decoration:none;color:#9ca3af;cursor:pointer;border:none;background:none;font-family:'Noto Sans KR',sans-serif;}
.nav-item.active{color:#0d1a33;}
.nav-item.active .nav-label{font-weight:600;}
.nav-icon{width:22px;height:22px;display:flex;align-items:center;justify-content:center;}
.nav-icon svg{width:20px;height:20px;stroke:currentColor;fill:none;stroke-width:1.8;stroke-linecap:round;}
.nav-label{font-size:10px;}

  @keyframes slideUp {
    from { transform: translateY(100%); opacity: 0; }
    to   { transform: translateY(0);    opacity: 1; }
  }
  @keyframes fadeUp {
    from { opacity: 0; transform: translateY(10px); }
    to   { opacity: 1; transform: translateY(0); }
  }

  @media (min-width: 421px) {
    .screen { box-shadow: 0 0 40px rgba(0,0,0,0.1); }
    .drawer { max-width: 420px; }
  }
</style>
</head>
<body>

<%
  String userId    = (String) session.getAttribute("loginUser");
  String userName  = (String) session.getAttribute("userName");
  String userRank  = (String) session.getAttribute("userRank");
  String userOrg   = (String) session.getAttribute("userOrg");
  String userPhone = (String) session.getAttribute("userPhone");
  if (userId == null) userId = ""; if (userName == null) userName = "";
  if (userRank == null) userRank = ""; if (userOrg == null) userOrg = "";
  if (userPhone == null) userPhone = "";
%>

<div class="screen">

  <!-- ── 헤더 ── -->
  <div class="top-header">
    <div class="header-row">
      <span class="header-title">마이페이지</span>
      <button class="edit-btn" onclick="openProfileDrawer()">프로필 편집</button>
    </div>
  </div>

  <!-- ── 프로필 카드 ── -->
  <div class="profile-band">
    <div class="profile-card">
      <div class="avatar-lg"><%= userName.length() >= 2 ? userName.substring(0,2) : userName %></div>
      <div class="profile-info">
        <div class="profile-name"><%= userName %> <%= userRank %></div>
        <div class="profile-rank"><%= userOrg %></div>
        <div class="profile-badge">
          <span class="badge-dot"></span>
          <span>접속 중 · <%= userId %></span>
        </div>
      </div>
    </div>
  </div>

  <!-- ── 통계 띠 ── -->
  <div class="stats-band">
    <div class="stats-strip">
      <div class="stat-col">
        <div class="stat-num" id="statActiveCases">-</div>
        <div class="stat-lbl">진행 사건</div>
      </div>
      <div class="stat-col">
        <div class="stat-num" id="statContradiction" style="color:#dc2626;">-</div>
        <div class="stat-lbl">모순 탐지</div>
      </div>
      <div class="stat-col">
        <div class="stat-num" id="statCompleted">-</div>
        <div class="stat-lbl">작성 조서</div>
      </div>
    </div>
  </div>

  <!-- ── 스크롤 콘텐츠 ── -->
  <div class="content">

    <!-- 계정 관리 -->
    <div class="section" style="margin-top:16px;">
      <div class="section-label">계정 관리</div>
      <div class="menu-list">

        <div class="menu-row" onclick="openDrawer('profileViewDrawer')">
          <div class="menu-icon-wrap bg-blue">
            <svg viewBox="0 0 24 24" fill="none" stroke-width="1.8" stroke-linecap="round" class="stroke-blue">
              <path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2"/><circle cx="12" cy="7" r="4"/>
            </svg>
          </div>
          <div class="menu-text">
            <div class="menu-name">프로필 정보</div>
            <div class="menu-sub">이름 · 계급 · 소속 · 연락처</div>
          </div>
          <div class="menu-right">
            <div class="menu-arrow"><svg viewBox="0 0 24 24" fill="none" stroke-width="2" stroke-linecap="round"><polyline points="9 18 15 12 9 6"/></svg></div>
          </div>
        </div>

        <div class="menu-row" onclick="openDrawer('pwDrawer')">
          <div class="menu-icon-wrap bg-amber">
            <svg viewBox="0 0 24 24" fill="none" stroke-width="1.8" stroke-linecap="round" class="stroke-amber">
              <rect x="3" y="11" width="18" height="11" rx="2"/><path d="M7 11V7a5 5 0 0 1 10 0v4"/>
            </svg>
          </div>
          <div class="menu-text">
            <div class="menu-name">비밀번호 변경</div>
            <div class="menu-sub">현재 비밀번호 확인 후 변경</div>
          </div>
          <div class="menu-right">
            <div class="menu-arrow"><svg viewBox="0 0 24 24" fill="none" stroke-width="2" stroke-linecap="round"><polyline points="9 18 15 12 9 6"/></svg></div>
          </div>
        </div>

      </div>
    </div>

    <!-- 수사 활동 -->
    <div class="section" style="margin-top:16px;">
      <div class="section-label">수사 활동</div>
      <div class="menu-list">

        <div class="menu-row" onclick="openDrawer('historyDrawer')">
          <div class="menu-icon-wrap bg-navy">
            <svg viewBox="0 0 24 24" fill="none" stroke-width="1.8" stroke-linecap="round" class="stroke-navy">
              <path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/>
              <polyline points="14 2 14 8 20 8"/><line x1="16" y1="13" x2="8" y2="13"/><line x1="16" y1="17" x2="8" y2="17"/>
            </svg>
          </div>
          <div class="menu-text">
            <div class="menu-name">내 조서 이력</div>
            <div class="menu-sub">작성 · 수정 · 완료 기록</div>
          </div>
          <div class="menu-right">
            <span class="menu-value" id="menuHistoryCount">-</span>
            <div class="menu-arrow"><svg viewBox="0 0 24 24" fill="none" stroke-width="2" stroke-linecap="round"><polyline points="9 18 15 12 9 6"/></svg></div>
          </div>
        </div>

        <div class="menu-row" onclick="openDrawer('statsDrawer')">
          <div class="menu-icon-wrap bg-green">
            <svg viewBox="0 0 24 24" fill="none" stroke-width="1.8" stroke-linecap="round" class="stroke-green">
              <line x1="18" y1="20" x2="18" y2="10"/><line x1="12" y1="20" x2="12" y2="4"/><line x1="6" y1="20" x2="6" y2="14"/>
            </svg>
          </div>
          <div class="menu-text">
            <div class="menu-name">활동 통계</div>
            <div class="menu-sub">처리 사건 수 · 기간별 현황</div>
          </div>
          <div class="menu-right">
            <div class="menu-arrow"><svg viewBox="0 0 24 24" fill="none" stroke-width="2" stroke-linecap="round"><polyline points="9 18 15 12 9 6"/></svg></div>
          </div>
        </div>

        <a class="menu-row" href="contradictionList" style="text-decoration:none;">
          <div class="menu-icon-wrap bg-red">
            <svg viewBox="0 0 24 24" fill="none" stroke-width="1.8" stroke-linecap="round" class="stroke-red">
              <path d="M10.29 3.86L1.82 18a2 2 0 0 0 1.71 3h16.94a2 2 0 0 0 1.71-3L13.71 3.86a2 2 0 0 0-3.42 0z"/>
              <line x1="12" y1="9" x2="12" y2="13"/><line x1="12" y1="17" x2="12.01" y2="17"/>
            </svg>
          </div>
          <div class="menu-text">
            <div class="menu-name">모순탐지 목록</div>
            <div class="menu-sub">저장된 AI 모순탐지 결과 조회</div>
          </div>
          <div class="menu-right">
            <span class="menu-value" id="menuContraCount">-</span>
            <div class="menu-arrow"><svg viewBox="0 0 24 24" fill="none" stroke-width="2" stroke-linecap="round"><polyline points="9 18 15 12 9 6"/></svg></div>
          </div>
        </a>

      </div>
    </div>

    <!-- 설정 -->
    <div class="section" style="margin-top:16px;">
      <div class="section-label">설정</div>
      <div class="menu-list">

        <div class="menu-row">
          <div class="menu-icon-wrap bg-purple">
            <svg viewBox="0 0 24 24" fill="none" stroke-width="1.8" stroke-linecap="round" class="stroke-purple">
              <path d="M18 8A6 6 0 0 0 6 8c0 7-3 9-3 9h18s-3-2-3-9"/><path d="M13.73 21a2 2 0 0 1-3.46 0"/>
            </svg>
          </div>
          <div class="menu-text">
            <div class="menu-name">모순 탐지 알림</div>
            <div class="menu-sub">탐지 시 즉시 알림</div>
          </div>
          <div class="menu-right">
            <label class="toggle-wrap">
              <input type="checkbox" class="toggle-input" id="toggleContradiction" checked onchange="saveSettings()">
              <span class="toggle-slider"></span>
            </label>
          </div>
        </div>

        <div class="menu-row">
          <div class="menu-icon-wrap bg-purple">
            <svg viewBox="0 0 24 24" fill="none" stroke-width="1.8" stroke-linecap="round" class="stroke-purple">
              <circle cx="6" cy="12" r="2.5"/><circle cx="18" cy="5" r="2.5"/><circle cx="18" cy="19" r="2.5"/>
              <line x1="8.4" y1="11.0" x2="15.6" y2="6.5"/><line x1="8.4" y1="13.0" x2="15.6" y2="17.5"/>
            </svg>
          </div>
          <div class="menu-text">
            <div class="menu-name">관계망 변경 알림</div>
            <div class="menu-sub">인물·관계 업데이트 알림</div>
          </div>
          <div class="menu-right">
            <label class="toggle-wrap">
              <input type="checkbox" class="toggle-input" id="toggleRelation" checked onchange="saveSettings()">
              <span class="toggle-slider"></span>
            </label>
          </div>
        </div>

        <div class="menu-row">
          <div class="menu-icon-wrap bg-gray">
            <svg viewBox="0 0 24 24" fill="none" stroke-width="1.8" stroke-linecap="round" class="stroke-gray">
              <circle cx="12" cy="12" r="3"/><path d="M19.07 4.93A10 10 0 1 0 4.93 19.07"/>
              <path d="M12 2v2M12 20v2M4.22 4.22l1.42 1.42M18.36 18.36l1.42 1.42M2 12h2M20 12h2"/>
            </svg>
          </div>
          <div class="menu-text">
            <div class="menu-name">야간 방해금지</div>
            <div class="menu-sub">22:00 ~ 07:00 알림 차단</div>
          </div>
          <div class="menu-right">
            <label class="toggle-wrap">
              <input type="checkbox" class="toggle-input" id="toggleNightMode" onchange="saveSettings()">
              <span class="toggle-slider"></span>
            </label>
          </div>
        </div>

      </div>
    </div>

    <!-- 앱 정보 -->
    <div class="section" style="margin-top:16px;">
      <div class="section-label">앱 정보</div>
      <div class="app-info-card">
        <div class="app-name">POL-MATE</div>
        <div class="app-ver">버전 1.0.0-beta · 2025.03</div>
        <div class="app-copy" style="margin-top:10px; color:var(--text-muted);">형사사법정보지원 시스템</div>
        <div style="margin-top:14px; padding-top:14px; border-top:1px solid var(--border); display:flex; justify-content:center; gap:24px;">
          <a href="#" onclick="openDrawer('termsDrawer');return false;" style="font-size:11px; color:var(--accent); text-decoration:none;">이용약관</a>
          <a href="#" onclick="openDrawer('privacyDrawer');return false;" style="font-size:11px; color:var(--accent); text-decoration:none;">개인정보처리방침</a>
          <a href="#" onclick="openDrawer('licenseDrawer');return false;" style="font-size:11px; color:var(--accent); text-decoration:none;">오픈소스 라이선스</a>
        </div>
      </div>
    </div>

    <!-- 로그아웃 -->
    <div style="padding:16px 0 4px;">
      <button class="logout-btn" onclick="confirmLogout()">
        <svg viewBox="0 0 24 24" fill="none" stroke-width="2" stroke-linecap="round">
          <path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4"/>
          <polyline points="16 17 21 12 16 7"/>
          <line x1="21" y1="12" x2="9" y2="12"/>
        </svg>
        로그아웃
      </button>
    </div>

    <!-- 회원탈퇴 -->
    <div style="padding:0 0 20px; text-align:center;">
      <button onclick="confirmWithdraw()" style="background:none;border:none;font-size:11px;color:var(--text-muted);font-family:'Noto Sans KR',sans-serif;cursor:pointer;text-decoration:underline;text-underline-offset:2px;">회원탈퇴</button>
    </div>

  </div><!-- /content -->

  <!-- ── 하단 네비 ── -->
    <nav class="bottom-nav">
  <a href="main" class="nav-item">
    <div class="nav-icon"><svg viewBox="0 0 24 24"><path d="M3 9l9-7 9 7v11a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"/><polyline points="9 22 9 12 15 12 15 22"/></svg></div>
    <span class="nav-label">홈</span>
  </a>
  <a href="myCase" class="nav-item">
    <div class="nav-icon"><svg viewBox="0 0 24 24"><path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/><polyline points="14 2 14 8 20 8"/></svg></div>
    <span class="nav-label">사건</span>
  </a>
  <a href="../askAI" class="nav-item">
      <div class="nav-icon">
        <svg width="22" height="22" viewBox="0 0 86 86" fill="none">
          <path d="M43 7 L66 17 L66 41 C66 57 43 71 43 71 C43 71 20 57 20 41 L20 17 Z" fill="none" stroke="currentColor" stroke-width="5"/>
          <circle cx="43" cy="40" r="11" fill="none" stroke="currentColor" stroke-width="3"/>
          <circle cx="43" cy="40" r="5" fill="currentColor"/>
          <circle cx="43" cy="40" r="2.5" fill="white"/>
          <circle cx="43" cy="22" r="2.8" fill="currentColor"/>
          <circle cx="43" cy="58" r="2.8" fill="currentColor"/>
          <circle cx="28" cy="40" r="2.8" fill="currentColor"/>
          <circle cx="58" cy="40" r="2.8" fill="currentColor"/>
        </svg>
      </div>
      <span class="nav-label">AI</span>
    </a>
  <a href="board" class="nav-item">
    <div class="nav-icon"><svg viewBox="0 0 24 24"><path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z"/></svg></div>
    <span class="nav-label">커뮤니티</span>
  </a>
  <a href="mypage" class="nav-item active">
    <div class="nav-icon"><svg viewBox="0 0 24 24"><path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2"/><circle cx="12" cy="7" r="4"/></svg></div>
    <span class="nav-label">마이페이지</span>
  </a>
</nav>
</div>


</div><!-- /screen -->


<!-- ════════════════════════════════════ -->
<!-- 드로어: 프로필 정보 (읽기 전용)       -->
<!-- ════════════════════════════════════ -->
<div class="overlay" id="profileViewDrawer" onclick="closeOnBg(event,'profileViewDrawer')">
  <div class="drawer">
    <div class="drawer-handle"></div>
    <div class="drawer-title">프로필 정보</div>
    <div class="drawer-body">

      <div style="display:flex;flex-direction:column;gap:12px;margin-bottom:20px;">

        <div style="background:var(--bg);border-radius:12px;padding:14px 16px;border:1px solid var(--border);">
          <div style="font-size:10px;color:var(--text-muted);font-weight:500;letter-spacing:0.5px;margin-bottom:4px;">이름</div>
          <div style="font-size:14px;color:var(--text-primary);font-weight:500;"><%= userName %></div>
        </div>

        <div style="background:var(--bg);border-radius:12px;padding:14px 16px;border:1px solid var(--border);">
          <div style="font-size:10px;color:var(--text-muted);font-weight:500;letter-spacing:0.5px;margin-bottom:4px;">계급</div>
          <div style="font-size:14px;color:var(--text-primary);font-weight:500;"><%= userRank != null ? userRank : "-" %></div>
        </div>

        <div style="background:var(--bg);border-radius:12px;padding:14px 16px;border:1px solid var(--border);">
          <div style="font-size:10px;color:var(--text-muted);font-weight:500;letter-spacing:0.5px;margin-bottom:4px;">소속 기관</div>
          <div style="font-size:14px;color:var(--text-primary);font-weight:500;"><%= userOrg != null ? userOrg : "-" %></div>
        </div>

        <div style="background:var(--bg);border-radius:12px;padding:14px 16px;border:1px solid var(--border);" id="viewDeptRow">
          <div style="font-size:10px;color:var(--text-muted);font-weight:500;letter-spacing:0.5px;margin-bottom:4px;">부서</div>
          <div style="font-size:14px;color:var(--text-primary);font-weight:500;" id="viewDeptName">-</div>
        </div>

        <div style="background:var(--bg);border-radius:12px;padding:14px 16px;border:1px solid var(--border);">
          <div style="font-size:10px;color:var(--text-muted);font-weight:500;letter-spacing:0.5px;margin-bottom:4px;">연락처</div>
          <div style="font-size:14px;color:var(--text-primary);font-weight:500;"><%= userPhone != null && !userPhone.isEmpty() ? userPhone : "-" %></div>
        </div>

        <div style="background:var(--bg);border-radius:12px;padding:14px 16px;border:1px solid var(--border);">
          <div style="font-size:10px;color:var(--text-muted);font-weight:500;letter-spacing:0.5px;margin-bottom:4px;">아이디</div>
          <div style="font-size:14px;color:var(--text-primary);font-weight:500;"><%= userId %></div>
        </div>

      </div>

      <button class="d-btn-cancel" onclick="closeDrawer('profileViewDrawer')">닫기</button>
    </div>
  </div>
</div>


<!-- ════════════════════════════════════ -->
<!-- 드로어: 프로필 편집                   -->
<!-- ════════════════════════════════════ -->
<div class="overlay" id="profileDrawer" onclick="closeOnBg(event,'profileDrawer')">
  <div class="drawer">
    <div class="drawer-handle"></div>
    <div class="drawer-title">프로필 정보</div>
    <div class="drawer-body">
      <div class="d-field">
        <label class="d-label">이름</label>
        <input type="text" class="d-input" id="editName" value="<%= userName %>">
      </div>
      <div class="d-field">
        <label class="d-label">계급</label>
        <select class="d-input" id="editRank">
          <% String[] ranks = {"순경","경장","경사","경위","경감","경정","총경","경무관"}; %>
          <% for(String r : ranks) { %>
            <option <%= r.equals(userRank) ? "selected" : "" %>><%= r %></option>
          <% } %>
        </select>
      </div>
      <div class="d-field">
        <label class="d-label">소속 기관</label>
        <select class="d-input" id="editOrg" onchange="onOrgChange()">
          <option value="">선택하세요</option>
          <option <%= "서울경찰청".equals(userOrg) ? "selected" : "" %>>서울경찰청</option>
          <option <%= "부산지방경찰청".equals(userOrg) ? "selected" : "" %>>부산지방경찰청</option>
          <option <%= "인천지방경찰청".equals(userOrg) ? "selected" : "" %>>인천지방경찰청</option>
          <option <%= "경기남부경찰청".equals(userOrg) ? "selected" : "" %>>경기남부경찰청</option>
          <option <%= "경기북부경찰청".equals(userOrg) ? "selected" : "" %>>경기북부경찰청</option>
          <option <%= "대구지방경찰청".equals(userOrg) ? "selected" : "" %>>대구지방경찰청</option>
          <option <%= "광주지방경찰청".equals(userOrg) ? "selected" : "" %>>광주지방경찰청</option>
          <option <%= "대전지방경찰청".equals(userOrg) ? "selected" : "" %>>대전지방경찰청</option>
          <option <%= "울산지방경찰청".equals(userOrg) ? "selected" : "" %>>울산지방경찰청</option>
          <option <%= "기타".equals(userOrg) ? "selected" : "" %>>기타</option>
        </select>
      </div>
      <div class="d-field">
        <label class="d-label">부서</label>
        <select class="d-input" id="editDept" disabled>
          <option value="">소속 기관을 먼저 선택하세요</option>
        </select>
      </div>
      <div class="d-field">
        <label class="d-label">연락처</label>
        <input type="tel" class="d-input" id="editPhone" value="<%= userPhone %>">
      </div>
      <div class="d-field">
        <label class="d-label">아이디 (변경 불가)</label>
        <input type="text" class="d-input" value="<%= userId %>" disabled>
      </div>
      <button class="d-btn" onclick="saveProfile()">저장</button>
      <button class="d-btn-cancel" onclick="closeDrawer('profileDrawer')">취소</button>
    </div>
  </div>
</div>


<!-- ════════════════════════════════════ -->
<!-- 드로어: 비밀번호 변경                 -->
<!-- ════════════════════════════════════ -->
<div class="overlay" id="pwDrawer" onclick="closeOnBg(event,'pwDrawer')">
  <div class="drawer">
    <div class="drawer-handle"></div>
    <div class="drawer-title">비밀번호 변경</div>
    <div class="drawer-body">
      <div class="d-field">
        <label class="d-label">현재 비밀번호</label>
        <input type="password" class="d-input" id="curPw" placeholder="현재 비밀번호 입력">
      </div>
      <div class="d-field">
        <label class="d-label">새 비밀번호</label>
        <input type="password" class="d-input" id="newPw" placeholder="8자 이상, 영문+숫자+특수문자">
      </div>
      <div class="d-field">
        <label class="d-label">새 비밀번호 확인</label>
        <input type="password" class="d-input" id="newPwCf" placeholder="새 비밀번호 재입력">
      </div>
      <p id="pwChangeMsg" style="font-size:11px; color:var(--danger); margin-bottom:10px; display:none;"></p>
      <button class="d-btn" onclick="changePw()">변경 완료</button>
      <button class="d-btn-cancel" onclick="closeDrawer('pwDrawer')">취소</button>
    </div>
  </div>
</div>


<!-- ════════════════════════════════════ -->
<!-- 드로어: 내 조서 이력                  -->
<!-- ════════════════════════════════════ -->
<div class="overlay" id="historyDrawer" onclick="closeOnBg(event,'historyDrawer')">
  <div class="drawer">
    <div class="drawer-handle"></div>
    <div class="drawer-title">내 조서 이력</div>
    <div class="history-list" id="historyList">
      <!-- JS로 채움 (MypageServlet action=history) -->
    </div>
    <div style="padding:16px 20px 0;">
      <button class="d-btn-cancel" onclick="closeDrawer('historyDrawer')">닫기</button>
    </div>
  </div>
</div>


<!-- ════════════════════════════════════ -->
<!-- 드로어: 활동 통계                    -->
<!-- ════════════════════════════════════ -->
<div class="overlay" id="statsDrawer" onclick="closeOnBg(event,'statsDrawer')">
  <div class="drawer">
    <div class="drawer-handle"></div>
    <div class="drawer-title">활동 통계</div>
    <div class="drawer-body">

      <!-- 기간 선택 -->
      <div style="display:flex; gap:8px; margin-bottom:18px;">
        <button class="period-btn active" onclick="setPeriod(this,'week')">이번 주</button>
        <button class="period-btn" onclick="setPeriod(this,'month')">이번 달</button>
        <button class="period-btn" onclick="setPeriod(this,'all')">전체</button>
      </div>

      <!-- 요약 배지 4개 -->
      <div class="stats-summary-row" id="statsSummary">
        <!-- JS로 채움 -->
      </div>

      <!-- 도넛 차트: 활동 유형별 비율 -->
      <div class="chart-section">
        <div class="chart-section-title">활동 유형별 비율</div>
        <div class="donut-wrap">
          <!-- 레티나 대응: 실제 픽셀은 JS에서 2x로 설정 -->
          <div style="position:relative;flex-shrink:0;width:140px;height:140px;">
            <canvas id="donutChart" style="width:140px;height:140px;display:block;"></canvas>
            <div id="donutCenter" style="position:absolute;top:50%;left:50%;transform:translate(-50%,-50%);text-align:center;pointer-events:none;"></div>
          </div>
          <div class="donut-legend" id="donutLegend"><!-- JS로 채움 --></div>
        </div>
      </div>

      <!-- 막대 차트: 월별 조서 처리 현황 -->
      <div class="chart-section">
        <div class="chart-section-title">월별 조서 처리 현황</div>
        <canvas id="barChartCanvas" width="340" height="130"
          style="width:100%;max-width:100%;display:block;"></canvas>
      </div>

      <button class="d-btn-cancel" style="margin-top:4px;" onclick="closeDrawer('statsDrawer')">닫기</button>
    </div>
  </div>
</div>

<!-- ════════════════════════════════════ -->
<!-- 드로어: 이용약관                      -->
<!-- ════════════════════════════════════ -->
<div class="overlay" id="termsDrawer" onclick="closeOnBg(event,'termsDrawer')">
  <div class="drawer">
    <div class="drawer-handle"></div>
    <div class="drawer-title">이용약관</div>
    <div class="drawer-body" style="font-size:13px; color:var(--text-secondary); line-height:1.8;">

      <p style="font-weight:600; color:var(--text-primary); margin-bottom:6px;">제1조 (목적)</p>
      <p style="margin-bottom:16px;">본 약관은 POL-MATE(이하 "서비스")의 이용에 관한 조건 및 절차, 기타 필요한 사항을 규정함을 목적으로 합니다.</p>

      <p style="font-weight:600; color:var(--text-primary); margin-bottom:6px;">제2조 (정의)</p>
      <p style="margin-bottom:16px;">① "서비스"란 형사사법정보 지원을 위해 제공되는 조서 작성·분석·관리 시스템을 의미합니다.<br>② "이용자"란 본 약관에 동의하고 서비스를 이용하는 수사 담당 공무원을 말합니다.</p>

      <p style="font-weight:600; color:var(--text-primary); margin-bottom:6px;">제3조 (약관의 효력 및 변경)</p>
      <p style="margin-bottom:16px;">① 본 약관은 서비스 내 공지 또는 이용자에게 통지하는 방법으로 효력이 발생합니다.<br>② 운영 기관은 관련 법령을 위반하지 않는 범위에서 약관을 개정할 수 있으며, 변경 시 사전 공지합니다.</p>

      <p style="font-weight:600; color:var(--text-primary); margin-bottom:6px;">제4조 (서비스의 제공 및 중단)</p>
      <p style="margin-bottom:16px;">① 서비스는 연중 24시간 제공을 원칙으로 합니다.<br>② 시스템 점검, 보안 업데이트, 불가항력적 사유 등으로 서비스가 일시 중단될 수 있습니다.</p>

      <p style="font-weight:600; color:var(--text-primary); margin-bottom:6px;">제5조 (이용자의 의무)</p>
      <p style="margin-bottom:16px;">① 이용자는 다음 행위를 하여서는 안 됩니다.<br>
        &nbsp;&nbsp;1. 허가받지 않은 타인의 계정 이용<br>
        &nbsp;&nbsp;2. 서비스로 취득한 정보의 무단 외부 유출<br>
        &nbsp;&nbsp;3. 시스템의 정상적인 운영을 방해하는 행위<br>
        &nbsp;&nbsp;4. 수사 목적 외 데이터 접근 및 활용<br>
      ② 이용자는 관계 법령, 수사 규정 및 본 약관을 준수하여야 합니다.</p>

      <p style="font-weight:600; color:var(--text-primary); margin-bottom:6px;">제6조 (책임의 한계)</p>
      <p style="margin-bottom:16px;">AI 분석 결과는 참고 자료로만 활용하며, 수사·기소 등 법적 판단의 근거로 단독 사용할 수 없습니다. 최종 판단은 담당 수사관의 책임 하에 이루어져야 합니다.</p>

      <p style="font-weight:600; color:var(--text-primary); margin-bottom:6px;">제7조 (준거법)</p>
      <p style="margin-bottom:20px;">본 약관은 대한민국 법령에 따라 해석 및 적용됩니다.</p>

      <p style="font-size:11px; color:var(--text-muted); border-top:1px solid var(--border); padding-top:12px;">시행일: 2025년 3월 1일</p>

      <button class="d-btn-cancel" style="margin-top:16px;" onclick="closeDrawer('termsDrawer')">닫기</button>
    </div>
  </div>
</div>


<!-- ════════════════════════════════════ -->
<!-- 드로어: 개인정보처리방침               -->
<!-- ════════════════════════════════════ -->
<div class="overlay" id="privacyDrawer" onclick="closeOnBg(event,'privacyDrawer')">
  <div class="drawer">
    <div class="drawer-handle"></div>
    <div class="drawer-title">개인정보처리방침</div>
    <div class="drawer-body" style="font-size:13px; color:var(--text-secondary); line-height:1.8;">

      <p style="margin-bottom:16px;">POL-MATE(이하 "서비스")는 「개인정보 보호법」에 따라 이용자의 개인정보를 보호하고 이와 관련한 고충을 신속하게 처리하기 위하여 다음과 같이 개인정보처리방침을 수립·공개합니다.</p>

      <p style="font-weight:600; color:var(--text-primary); margin-bottom:6px;">1. 수집하는 개인정보 항목</p>
      <p style="margin-bottom:16px;">
        · <b>필수 항목:</b> 아이디, 비밀번호(암호화 저장), 이름, 계급, 소속 기관<br>
        · <b>선택 항목:</b> 부서, 연락처<br>
        · <b>자동 수집:</b> 접속 로그, 서비스 이용 기록
      </p>

      <p style="font-weight:600; color:var(--text-primary); margin-bottom:6px;">2. 개인정보 수집 목적</p>
      <p style="margin-bottom:16px;">
        · 이용자 식별 및 서비스 이용 자격 확인<br>
        · 사건·조서 관리 및 수사 활동 지원<br>
        · 불법·부정 이용 방지 및 보안 유지<br>
        · 서비스 개선 및 통계 분석
      </p>

      <p style="font-weight:600; color:var(--text-primary); margin-bottom:6px;">3. 개인정보 보유 및 이용 기간</p>
      <p style="margin-bottom:16px;">회원 탈퇴 또는 이용 목적 달성 시 즉시 파기합니다. 단, 관계 법령에 의거하여 보존이 필요한 경우 해당 기간 동안 보관합니다.</p>

      <p style="font-weight:600; color:var(--text-primary); margin-bottom:6px;">4. 개인정보의 제3자 제공</p>
      <p style="margin-bottom:16px;">수집된 개인정보는 원칙적으로 제3자에게 제공하지 않습니다. 다만, 수사 절차상 법령에 따른 요청이 있는 경우는 예외로 합니다.</p>

      <p style="font-weight:600; color:var(--text-primary); margin-bottom:6px;">5. 개인정보의 안전성 확보</p>
      <p style="margin-bottom:16px;">
        · 비밀번호 단방향 암호화(bcrypt) 저장<br>
        · 접근 권한 최소화 및 계정 이상 접근 감지<br>
        · 보안 취약점 정기 점검
      </p>

      <p style="font-weight:600; color:var(--text-primary); margin-bottom:6px;">6. 이용자의 권리</p>
      <p style="margin-bottom:16px;">이용자는 언제든지 자신의 개인정보를 조회·수정할 수 있으며, 회원탈퇴를 통해 개인정보 삭제를 요청할 수 있습니다.</p>

      <p style="font-weight:600; color:var(--text-primary); margin-bottom:6px;">7. 개인정보 보호 담당</p>
      <p style="margin-bottom:20px;">개인정보 처리 관련 문의는 서비스 운영 기관 정보보안 담당 부서로 연락하시기 바랍니다.</p>

      <p style="font-size:11px; color:var(--text-muted); border-top:1px solid var(--border); padding-top:12px;">시행일: 2025년 3월 1일</p>

      <button class="d-btn-cancel" style="margin-top:16px;" onclick="closeDrawer('privacyDrawer')">닫기</button>
    </div>
  </div>
</div>


<!-- ════════════════════════════════════ -->
<!-- 드로어: 오픈소스 라이선스              -->
<!-- ════════════════════════════════════ -->
<div class="overlay" id="licenseDrawer" onclick="closeOnBg(event,'licenseDrawer')">
  <div class="drawer">
    <div class="drawer-handle"></div>
    <div class="drawer-title">오픈소스 라이선스</div>
    <div class="drawer-body" style="font-size:13px; color:var(--text-secondary); line-height:1.8;">

      <p style="margin-bottom:16px; color:var(--text-muted); font-size:12px;">POL-MATE는 아래 오픈소스 소프트웨어를 사용합니다.</p>

      <!-- 항목 -->
      <div style="border:1px solid var(--border); border-radius:12px; overflow:hidden; margin-bottom:12px;">

        <div style="padding:14px 16px; border-bottom:1px solid var(--border);">
          <div style="display:flex; justify-content:space-between; align-items:center; margin-bottom:4px;">
            <span style="font-weight:600; color:var(--text-primary);">Apache Tomcat</span>
            <span style="font-size:10px; background:#eff6ff; color:#1d4ed8; padding:2px 8px; border-radius:20px;">Apache 2.0</span>
          </div>
          <div style="font-size:11px; color:var(--text-muted);">Java Servlet 컨테이너 · Apache Software Foundation</div>
        </div>

        <div style="padding:14px 16px; border-bottom:1px solid var(--border);">
          <div style="display:flex; justify-content:space-between; align-items:center; margin-bottom:4px;">
            <span style="font-weight:600; color:var(--text-primary);">MySQL Connector/J</span>
            <span style="font-size:10px; background:#f0fdf4; color:#15803d; padding:2px 8px; border-radius:20px;">GPL 2.0</span>
          </div>
          <div style="font-size:11px; color:var(--text-muted);">Java-MySQL JDBC 드라이버 · Oracle Corporation</div>
        </div>

        <div style="padding:14px 16px; border-bottom:1px solid var(--border);">
          <div style="display:flex; justify-content:space-between; align-items:center; margin-bottom:4px;">
            <span style="font-weight:600; color:var(--text-primary);">Gson</span>
            <span style="font-size:10px; background:#eff6ff; color:#1d4ed8; padding:2px 8px; border-radius:20px;">Apache 2.0</span>
          </div>
          <div style="font-size:11px; color:var(--text-muted);">Java JSON 직렬화/역직렬화 라이브러리 · Google</div>
        </div>

        <div style="padding:14px 16px; border-bottom:1px solid var(--border);">
          <div style="display:flex; justify-content:space-between; align-items:center; margin-bottom:4px;">
            <span style="font-weight:600; color:var(--text-primary);">Noto Sans KR</span>
            <span style="font-size:10px; background:#f5f3ff; color:#7c3aed; padding:2px 8px; border-radius:20px;">OFL 1.1</span>
          </div>
          <div style="font-size:11px; color:var(--text-muted);">한국어 웹 폰트 · Google Fonts / Sandoll</div>
        </div>

        <div style="padding:14px 16px; border-bottom:1px solid var(--border);">
          <div style="display:flex; justify-content:space-between; align-items:center; margin-bottom:4px;">
            <span style="font-weight:600; color:var(--text-primary);">BCrypt</span>
            <span style="font-size:10px; background:#eff6ff; color:#1d4ed8; padding:2px 8px; border-radius:20px;">ISC License</span>
          </div>
          <div style="font-size:11px; color:var(--text-muted);">비밀번호 단방향 해시 암호화 라이브러리</div>
        </div>

        <div style="padding:14px 16px;">
          <div style="display:flex; justify-content:space-between; align-items:center; margin-bottom:4px;">
            <span style="font-weight:600; color:var(--text-primary);">D3.js</span>
            <span style="font-size:10px; background:#eff6ff; color:#1d4ed8; padding:2px 8px; border-radius:20px;">ISC License</span>
          </div>
          <div style="font-size:11px; color:var(--text-muted);">관계망 시각화 라이브러리 · Mike Bostock</div>
        </div>

      </div>

      <p style="font-size:11px; color:var(--text-muted); line-height:1.6;">각 라이브러리의 전체 라이선스 텍스트는 해당 프로젝트 공식 저장소에서 확인할 수 있습니다.</p>

      <button class="d-btn-cancel" style="margin-top:16px;" onclick="closeDrawer('licenseDrawer')">닫기</button>
    </div>
  </div>
</div>


<style>
  .period-btn {
    flex: 1; padding: 8px 0; font-size: 12px; font-family: 'Noto Sans KR', sans-serif;
    background: var(--bg); border: 1px solid var(--border); border-radius: 8px; cursor: pointer;
    color: var(--text-secondary); transition: all 0.15s;
  }
  .period-btn.active { background: var(--navy); color: #fff; border-color: var(--navy); }

  /* ── 활동 통계 그래프 ── */
  .stats-summary-row {
    display: flex; gap: 8px; margin-bottom: 20px; flex-wrap: wrap;
  }
  .stats-badge {
    flex: 1; min-width: 80px;
    background: var(--bg); border: 1px solid var(--bd); border-radius: 10px;
    padding: 10px 8px; text-align: center;
  }
  .stats-badge-num {
    font-size: 20px; font-weight: 700; color: var(--navy); line-height: 1;
  }
  .stats-badge-lbl {
    font-size: 10px; color: var(--tm); margin-top: 4px;
  }
  .chart-section { margin-bottom: 22px; }
  .chart-section-title {
    font-size: 11px; font-weight: 600; color: var(--ts);
    margin-bottom: 10px; display: flex; align-items: center; gap: 6px;
  }
  .chart-section-title::after {
    content: ''; flex: 1; height: 1px; background: var(--bd);
  }
  .donut-wrap {
    display: flex; align-items: center; gap: 16px;
  }
  .donut-legend {
    flex: 1; display: flex; flex-direction: column; gap: 8px;
  }
  .legend-item {
    display: flex; align-items: center; gap: 8px; font-size: 11px;
  }
  .legend-dot {
    width: 10px; height: 10px; border-radius: 50%; flex-shrink: 0;
  }
  .legend-label { color: var(--ts); flex: 1; }
  .legend-val   { color: var(--navy); font-weight: 600; }
  .legend-pct   { color: var(--tm); font-size: 10px; }

  .stat-tile {
    background: var(--bg); border-radius: 12px; padding: 14px;
    text-align: center; border: 1px solid var(--border);
  }
  .tile-num { font-size: 24px; font-weight: 700; color: var(--navy); }
  .tile-lbl { font-size: 11px; color: var(--text-muted); margin-top: 4px; }

  .bar-col { flex: 1; display: flex; flex-direction: column; align-items: center; justify-content: flex-end; }
  .bar-fill { width: 100%; border-radius: 4px 4px 0 0; background: #c7d7f0; transition: height 0.4s; }
  .bar-fill.cur { background: var(--navy); }
  .bar-lbl { font-size: 9px; color: var(--text-muted); text-align: center; flex: 0 0 auto; width: 100%; }
</style>

<script>
// ── 드로어 열기/닫기 ──────────────────────────────────────────────
function openDrawer(id) {
  document.getElementById(id).classList.add('open');
  document.body.style.overflow = 'hidden';
  if (id === 'statsDrawer')      loadStats('week');
  if (id === 'historyDrawer')    loadHistory();
  if (id === 'profileViewDrawer') {
    // 부서명을 load 응답에서 받아온 값으로 표시
    var el = document.getElementById('viewDeptName');
    if (el) el.textContent = currentDeptName || '-';
  }
}
function closeDrawer(id) {
  document.getElementById(id).classList.remove('open');
  document.body.style.overflow = '';
}
function closeOnBg(e, id) {
  if (e.target === document.getElementById(id)) closeDrawer(id);
}

// ── 초기 로드: 프로필 통계 띠 ──────────────────────────────────────
var currentDeptId   = null;
var currentDeptName = null;
document.addEventListener('DOMContentLoaded', function() {
  fetch('../mypage?action=load')
    .then(function(r) { return r.json(); })
    .then(function(data) {
      if (!data.user) return;
      var s = data.stats;
      document.getElementById('statActiveCases').textContent  = s.activeCases;
      // statContradiction은 loadContraCount()추원이 contradiction_results 기준으로 업레이트 (여기서 덮어쓰지 않음)
      document.getElementById('statCompleted').textContent    = s.totalTranscripts;
      document.getElementById('menuHistoryCount').textContent = s.totalTranscripts + '건';

      // 설정값 토글에 반영
      if (data.settings) {
        document.getElementById('toggleContradiction').checked = data.settings.notifContradiction !== false;
        document.getElementById('toggleRelation').checked      = data.settings.notifRelation      !== false;
        document.getElementById('toggleNightMode').checked     = data.settings.nightMode          === true;
      }
      // 현재 dept_id 저장 (프로필 드로어에서 부서 선택값 복원용)
      if (data.user) {
        currentDeptId   = data.user.deptId   || null;
        currentDeptName = data.user.userDept  || null;
        // 프로필 정보 보기 드로어의 부서명 세팅
        var deptEl = document.getElementById('viewDeptName');
        if (deptEl) deptEl.textContent = currentDeptName || '-';
      }
    })
    .catch(function(e) { console.error('초기 로드 실패', e); });

  // 모순탐지 목록 카운트 로드
  loadContraCount();

  // BroadcastChannel: contradictionList페이지에서 추가/삭제 시 실시간 업레이트
  try {
    var _mypageContraCh = new BroadcastChannel('contradictionCount');
    _mypageContraCh.onmessage = function(e) {
      if (e.data && e.data.type === 'update') {
        var statEl = document.getElementById('statContradiction');
        if (statEl) statEl.textContent = e.data.count;
        var menuEl = document.getElementById('menuContraCount');
        if (menuEl) {
          menuEl.textContent = e.data.count + '건';
          menuEl.style.color = e.data.count > 0 ? '#dc2626' : '';
        }
      }
    };
  } catch(e) {}
});

// ── 기관 변경 시 부서 동적 로드 ──────────────────────────────────
function onOrgChange() {
  var org = document.getElementById('editOrg').value;
  var deptSel = document.getElementById('editDept');
  deptSel.innerHTML = '<option value="">불러오는 중...</option>';
  deptSel.disabled = true;

  if (!org) {
    deptSel.innerHTML = '<option value="">소속 기관을 먼저 선택하세요</option>';
    return;
  }

  fetch('../mypage?action=getDepts&org=' + encodeURIComponent(org))
    .then(function(r) { return r.json(); })
    .then(function(depts) {
      deptSel.innerHTML = '<option value="">부서 선택 (선택)</option>';
      if (!depts.length) {
        deptSel.innerHTML = '<option value="">등록된 부서가 없습니다</option>';
        return;
      }
      depts.forEach(function(d) {
        var opt = document.createElement('option');
        opt.value = d.dept_id;
        opt.textContent = d.dept_name;
        deptSel.appendChild(opt);
      });
      deptSel.disabled = false;
    })
    .catch(function() {
      deptSel.innerHTML = '<option value="">불러오기 실패</option>';
    });
}

// ── 프로필 드로어 열기 (기존 부서 선택값 복원) ───────────────────
function openProfileDrawer() {
  // 드로어 열기
  openDrawer('profileDrawer');

  // 현재 기관으로 부서 목록 로드 후 현재 dept_id 선택
  var org = document.getElementById('editOrg').value;
  if (!org) return;

  var deptSel = document.getElementById('editDept');
  deptSel.innerHTML = '<option value="">불러오는 중...</option>';
  deptSel.disabled = true;

  fetch('../mypage?action=getDepts&org=' + encodeURIComponent(org))
    .then(function(r) { return r.json(); })
    .then(function(depts) {
      deptSel.innerHTML = '<option value="">부서 선택 (선택)</option>';
      depts.forEach(function(d) {
        var opt = document.createElement('option');
        opt.value = d.dept_id;
        opt.textContent = d.dept_name;
        // 현재 dept_id와 일치하면 선택
        if (String(d.dept_id) === String(currentDeptId)) opt.selected = true;
        deptSel.appendChild(opt);
      });
      deptSel.disabled = depts.length === 0;
    })
    .catch(function() {
      deptSel.innerHTML = '<option value="">불러오기 실패</option>';
    });
}

// ── 프로필 저장 ────────────────────────────────────────────────────
function saveProfile() {
  var params = new URLSearchParams();
  params.append('action',    'updateProfile');
  params.append('userName',  document.getElementById('editName').value.trim());
  params.append('userRank',  document.getElementById('editRank').value);
  params.append('userOrg',   document.getElementById('editOrg').value);
  params.append('userPhone', document.getElementById('editPhone').value.trim());
  params.append('deptId',    document.getElementById('editDept').value || '');

  fetch('../mypage', { method: 'POST', body: params })
    .then(function(r) { return r.json(); })
    .then(function(data) {
      if (data.success) {
        alert('프로필이 저장되었습니다.');
        closeDrawer('profileDrawer');
        // 부서가 바뀌었을 수 있으므로 통계·이력·카운트 즉시 갱신
        reloadAfterDeptChange();
      } else {
        alert(data.message || '저장에 실패했습니다.');
      }
    })
    .catch(function(e) { alert('오류가 발생했습니다.'); console.error(e); });
}

// ── 부서 변경 후 통계·이력·카운트 전체 갱신 ──────────────────────
function reloadAfterDeptChange() {
  // ① 상단 통계 띠 재로드 (작성 조서 수 & 진행 사건 수)
  fetch('../mypage?action=load&_=' + Date.now())
    .then(function(r) { return r.json(); })
    .then(function(data) {
      if (!data.user) return;
      var s = data.stats;
      document.getElementById('statActiveCases').textContent  = s.activeCases;
      document.getElementById('statCompleted').textContent    = s.totalTranscripts;
      document.getElementById('menuHistoryCount').textContent = s.totalTranscripts + '건';

      // 현재 dept 정보 갱신
      currentDeptId   = data.user.deptId  || null;
      currentDeptName = data.user.userDept || null;
      // 프로필 뷰 드로어 부서명 갱신
      var deptEl = document.getElementById('viewDeptName');
      if (deptEl) deptEl.textContent = currentDeptName || '-';
      // 설정 토글 유지
      if (data.settings) {
        document.getElementById('toggleContradiction').checked = data.settings.notifContradiction !== false;
        document.getElementById('toggleRelation').checked      = data.settings.notifRelation      !== false;
        document.getElementById('toggleNightMode').checked     = data.settings.nightMode          === true;
      }
    })
    .catch(function(e) { console.error('통계 갱신 실패', e); });

  // ② 활동 통계 드로어 재로드
  loadStats(_currentPeriod || 'week');

  // ③ 조서 이력 드로어 재로드 (드로어가 열려 있을 때도 반영)
  var historyList = document.getElementById('historyList');
  if (historyList) loadHistory();

  // ④ 모순탐지 카운트 재로드
  loadContraCount();
}


function changePw() {
  var cur   = document.getElementById('curPw').value;
  var nw    = document.getElementById('newPw').value;
  var nwcf  = document.getElementById('newPwCf').value;
  var msg   = document.getElementById('pwChangeMsg');
  msg.style.display = 'none';

  if (!cur)              { showPwMsg('현재 비밀번호를 입력해 주세요.'); return; }
  if (!nw || nw.length < 8) { showPwMsg('새 비밀번호를 8자 이상 입력해 주세요.'); return; }
  if (nw !== nwcf)       { showPwMsg('새 비밀번호가 일치하지 않습니다.'); return; }

  var params = new URLSearchParams();
  params.append('action', 'changePassword');
  params.append('curPw',  cur);
  params.append('newPw',  nw);
  params.append('newPwCf',nwcf);

  fetch('../mypage', { method: 'POST', body: params })
    .then(function(r) { return r.json(); })
    .then(function(data) {
      if (data.success) {
        alert('비밀번호가 변경되었습니다.');
        document.getElementById('curPw').value   = '';
        document.getElementById('newPw').value   = '';
        document.getElementById('newPwCf').value = '';
        closeDrawer('pwDrawer');
      } else {
        showPwMsg(data.message || '변경에 실패했습니다.');
      }
    })
    .catch(function(e) { alert('오류가 발생했습니다.'); console.error(e); });
}
function showPwMsg(m) {
  var el = document.getElementById('pwChangeMsg');
  el.textContent = m;
  el.style.display = 'block';
}

// ── 회원탈퇴 ──────────────────────────────────────────────────────
function confirmWithdraw() {
  document.getElementById('withdrawPw').value = '';
  document.getElementById('withdrawMsg').style.display = 'none';
  openDrawer('withdrawDrawer');
}

function submitWithdraw() {
  var pw  = document.getElementById('withdrawPw').value;
  var msg = document.getElementById('withdrawMsg');
  var btn = document.getElementById('withdrawBtn');
  msg.style.display = 'none';

  if (!pw) {
    msg.textContent = '비밀번호를 입력해 주세요.';
    msg.style.display = 'block';
    return;
  }

  // 중복 클릭 방지
  btn.disabled = true;
  btn.textContent = '처리 중...';

  var params = new URLSearchParams();
  params.append('action', 'withdraw');
  params.append('password', pw);

  fetch('../mypage', { method: 'POST', body: params })
    .then(function(r) { return r.json(); })
    .then(function(data) {
      if (data.success) {
        alert('탈퇴가 완료되었습니다.');
        location.href = 'login';
      } else {
        msg.textContent = data.message || '탈퇴 처리에 실패했습니다.';
        msg.style.display = 'block';
        btn.disabled = false;
        btn.textContent = '탈퇴하기';
      }
    })
    .catch(function() {
      msg.textContent = '오류가 발생했습니다. 다시 시도해 주세요.';
      msg.style.display = 'block';
      btn.disabled = false;
      btn.textContent = '탈퇴하기';
    });
}

function confirmLogout() {
  if (confirm('로그아웃 하시겠습니까?')) {
    var params = new URLSearchParams();
    params.append('action', 'logout');
    fetch('../mypage', { method: 'POST', body: params })
      .then(function() { location.href = 'login'; })
      .catch(function() { location.href = 'login'; });
  }
}

// ── 내 조서 이력 로드 ─────────────────────────────────────────────
function loadHistory() {
  var container = document.getElementById('historyList');
  container.innerHTML = '<p style="padding:20px; text-align:center; color:var(--text-muted); font-size:13px;">불러오는 중...</p>';

  fetch('../mypage?action=history')
    .then(function(r) { return r.json(); })
    .then(function(data) {
      var list = data.history;
      if (!list || list.length === 0) {
        container.innerHTML = '<p style="padding:20px; text-align:center; color:var(--text-muted); font-size:13px;">조서 이력이 없습니다.</p>';
        return;
      }
      var BADGE_MAP = {
        '진행중':   'h-badge-ok',
        '검토필요': 'h-badge-warn',
        '모순탐지': 'h-badge-warn',
        '완료':     'h-badge-done'
      };
      container.innerHTML = list.map(function(t) {
    	  var date = t.createdAt 
    	    ? new Date(t.createdAt).toLocaleDateString('ko-KR', {
    	        year: 'numeric',
    	        month: '2-digit',
    	        day: '2-digit',
    	        timeZone: 'Asia/Seoul'
    	      }).replace(/\. /g, '.').replace(/\.$/, '') 
    	    : '';
        var badge  = BADGE_MAP[t.caseStatus] || 'h-badge-done';
        var caseIdEsc = (t.caseId || '').replace(/'/g, "\\'");
        return '<div class="history-item" onclick="goToCase(\'' + caseIdEsc + '\')">' +
          '<div style="flex:1;min-width:0;">' +
            '<div class="h-title">' + escHtml(t.caseId) + ' ' + escHtml(t.caseName || '') + '</div>' +
            '<div class="h-meta">' + date + (t.stmtName ? ' · ' + escHtml(t.stmtType || '') + ' ' + escHtml(t.stmtName) + ' 진술' : '') + '</div>' +
          '</div>' +
          '<div class="h-right">' +
            '<span class="h-badge ' + badge + '">' + escHtml(t.caseStatus || '') + '</span>' +
            '<div class="h-arrow"><svg viewBox="0 0 24 24" fill="none" stroke-width="2" stroke-linecap="round"><polyline points="9 18 15 12 9 6"/></svg></div>' +
          '</div>' +
        '</div>';
      }).join('');
    })
    .catch(function(e) {
      container.innerHTML = '<p style="padding:20px; text-align:center; color:var(--danger); font-size:13px;">불러오기에 실패했습니다.</p>';
      console.error(e);
    });
}

// ── 모순탐지 목록 카운트 로드 ─────────────────────────────────────
function loadContraCount() {
  fetch('../contradictionApi?action=list&_=' + Date.now())
    .then(function(r) { return r.json(); })
    .then(function(data) {
      if (!Array.isArray(data)) return;

      var totalCount = data.length;
      var contraCount = data.filter(function(d) { return d.hasContradiction; }).length;

      // 메뉴 카운트 뱃지 업레이트 (모순 탐지된 건수만)
      var el = document.getElementById('menuContraCount');
      if (el) {
        el.textContent = contraCount + '건';
        if (contraCount > 0) {
          el.style.color = '#dc2626';
          el.textContent = totalCount + '건 (' + contraCount + '모순)';
        } else {
          el.style.color = '';
        }
      }

      // 상단 통계 란 '모순 탐지' 숫자 업레이트 (모순 탐지된 건수만)
      var statEl = document.getElementById('statContradiction');
      if (statEl) {
        statEl.textContent = contraCount;
      }
    })
    .catch(function() { /* 카운트 로드 실패 시 기존 값 유지 */ });
}

// ── 활동 통계 로드 ────────────────────────────────────────────────
var _currentPeriod = 'week';

function loadStats(period) {
  _currentPeriod = period || 'week';
  fetch('../mypage?action=stats&period=' + _currentPeriod + '&_=' + Date.now())
    .then(function(r) { return r.json(); })
    .then(function(data) { renderStats(data); })
    .catch(function(e) { console.error('통계 로드 실패', e); });
}

// ── 요약 배지 렌더 ──────────────────────────────────────────────
function renderStatsSummary(data) {
  var badges = [
    { num: data.activeCases       || 0, lbl: '진행 사건' },
    { num: data.totalTranscripts  || 0, lbl: '조서 처리' },
    { num: data.contradictionCount|| 0, lbl: '모순 탐지' },
    { num: data.relationEdges     || 0, lbl: '관계망 등록' },
  ];
  document.getElementById('statsSummary').innerHTML = badges.map(function(b) {
    return '<div class="stats-badge">' +
      '<div class="stats-badge-num">' + b.num + '</div>' +
      '<div class="stats-badge-lbl">' + b.lbl + '</div>' +
    '</div>';
  }).join('');
}

// ── 도넛 차트 렌더 ──────────────────────────────────────────────
function renderDonutChart(data) {
  var canvas = document.getElementById('donutChart');
  if (!canvas) return;

  // ── 레티나 선명도: devicePixelRatio 적용 ──
  var dpr    = window.devicePixelRatio || 2;
  var SIZE   = 140;
  canvas.width  = SIZE * dpr;
  canvas.height = SIZE * dpr;

  var ctx = canvas.getContext('2d');
  ctx.scale(dpr, dpr); // 이후 모든 좌표는 논리 px 기준

  var cx = SIZE / 2, cy = SIZE / 2;
  var R_OUT = 58, R_IN = 38; // 외반경, 내반경 → 두께 = 20px

  var vals = [
    { label: '조서 처리',   val: data.totalTranscripts   || 0, color: '#1A2744' },
    { label: '진행 사건',   val: data.activeCases        || 0, color: '#4A7CDB' },
    { label: '모순 탐지',   val: data.contradictionCount || 0, color: '#E8B84B' },
    { label: '관계망 등록', val: data.relationEdges      || 0, color: '#34C9A3' },
  ];

  var total = vals.reduce(function(s, v) { return s + v.val; }, 0);

  ctx.clearRect(0, 0, SIZE, SIZE);

  if (total === 0) {
    // 빈 상태 링
    ctx.beginPath();
    ctx.arc(cx, cy, (R_OUT + R_IN) / 2, 0, Math.PI * 2);
    ctx.strokeStyle = '#EEF1F8';
    ctx.lineWidth   = R_OUT - R_IN;
    ctx.stroke();

    // 중앙 텍스트
    var centerEl = document.getElementById('donutCenter');
    if (centerEl) {
      centerEl.innerHTML = '<div style="font-size:11px;color:#9CA3AF;">데이터 없음</div>';
    }
    document.getElementById('donutLegend').innerHTML = '';
    return;
  }

  // ── arc fill 방식 (fill 채우기 → 선명하고 갭 완벽 제어) ──
  var GAP_DEG   = 2.5;                    // 세그먼트 사이 간격 (도)
  var GAP_RAD   = (GAP_DEG * Math.PI) / 180;
  var startAngle = -Math.PI / 2;          // 12시 방향 시작

  vals.forEach(function(v) {
    if (v.val <= 0) return;
    var sweep = (v.val / total) * Math.PI * 2 - GAP_RAD;
    if (sweep <= 0) return;

    var endAngle = startAngle + sweep;

    ctx.beginPath();
    ctx.arc(cx, cy, R_OUT, startAngle, endAngle);       // 바깥 호
    ctx.arc(cx, cy, R_IN,  endAngle, startAngle, true); // 안쪽 호 (역방향)
    ctx.closePath();

    ctx.fillStyle = v.color;
    ctx.fill();

    startAngle += sweep + GAP_RAD;
  });

  // ── 중앙 흰 원 (배경이 card:#fff 이므로) ──
  ctx.beginPath();
  ctx.arc(cx, cy, R_IN - 1, 0, Math.PI * 2);
  ctx.fillStyle = '#FFFFFF';
  ctx.fill();

  // ── 중앙 텍스트 (DOM 오버레이) ──
  var centerEl = document.getElementById('donutCenter');
  if (centerEl) {
    centerEl.innerHTML =
      '<div style="font-size:20px;font-weight:700;color:#1A2744;line-height:1;">' + total + '</div>' +
      '<div style="font-size:9px;color:#9CA3AF;margin-top:2px;">전체 활동</div>';
  }

  // ── 범례 ──
  var legendEl = document.getElementById('donutLegend');
  legendEl.innerHTML = vals.map(function(v) {
    var pct = total > 0 ? Math.round(v.val / total * 100) : 0;
    return '<div class="legend-item">' +
      '<div class="legend-dot" style="background:' + v.color + ';border-radius:3px;width:10px;height:10px;flex-shrink:0;"></div>' +
      '<span class="legend-label">' + v.label + '</span>' +
      '<span class="legend-val">' + v.val + '</span>' +
      '<span class="legend-pct"> ' + pct + '%</span>' +
    '</div>';
  }).join('');
}

// ── 막대 차트 (Canvas) ──────────────────────────────────────────
function renderBarChartCanvas(monthly) {
  var canvas = document.getElementById('barChartCanvas');
  if (!canvas) return;

  // canvas 실제 픽셀 크기 = 표시 크기의 2배 (레티나 선명도)
  var displayW = canvas.offsetWidth || 340;
  var displayH = 130;
  canvas.width  = displayW * 2;
  canvas.height = displayH * 2;
  canvas.style.width  = displayW + 'px';
  canvas.style.height = displayH + 'px';

  var ctx = canvas.getContext('2d');
  ctx.scale(2, 2); // 레티나 스케일
  var W = displayW, H = displayH;
  ctx.clearRect(0, 0, W, H);

  var entries = Object.entries(monthly || {});
  if (!entries.length) {
    ctx.fillStyle = '#9CA3AF';
    ctx.font = '11px Noto Sans KR, sans-serif';
    ctx.textAlign = 'center';
    ctx.fillText('데이터 없음', W/2, H/2);
    return;
  }

  var maxVal = Math.max.apply(null, entries.map(function(e){ return e[1]; })) || 1;
  var padL = 28, padR = 8, padT = 22, padB = 24;
  var chartW = W - padL - padR;
  var chartH = H - padT - padB;
  var barW   = (chartW / entries.length) * 0.55;
  var gap    = chartW / entries.length;

  // 격자선 3개
  ctx.strokeStyle = '#EEF1F8';
  ctx.lineWidth   = 1;
  [0.25, 0.5, 0.75, 1.0].forEach(function(r) {
    var y = padT + chartH * (1 - r);
    ctx.beginPath();
    ctx.moveTo(padL, y);
    ctx.lineTo(W - padR, y);
    ctx.stroke();
    // Y축 레이블
    ctx.fillStyle = '#9CA3AF';
    ctx.font = '8px Noto Sans KR, sans-serif';
    ctx.textAlign = 'right';
    ctx.fillText(Math.round(maxVal * r), padL - 4, y + 3);
  });

  // 막대
  entries.forEach(function(entry, i) {
    var ym  = entry[0];
    var val = entry[1];
    var bh  = val > 0 ? Math.max((val / maxVal) * chartH, 4) : 2;
    var x   = padL + i * gap + (gap - barW) / 2;
    var y   = padT + chartH - bh;

    // 막대 그라데이션
    var grad = ctx.createLinearGradient(x, y, x, y + bh);
    if (val > 0) {
      grad.addColorStop(0, '#4A7CDB');
      grad.addColorStop(1, '#1A2744');
    } else {
      grad.addColorStop(0, '#E2E5EE');
      grad.addColorStop(1, '#E2E5EE');
    }
    ctx.fillStyle = grad;
    ctx.beginPath();
    ctx.roundRect(x, y, barW, bh, [3, 3, 0, 0]);
    ctx.fill();

    // 수치 레이블
    if (val > 0) {
      ctx.fillStyle = '#1A2744';
      ctx.font = 'bold 9px Noto Sans KR, sans-serif';
      ctx.textAlign = 'center';
      ctx.fillText(val, x + barW/2, y - 4);
    }

    // X축 레이블 (월만)
    ctx.fillStyle = '#9CA3AF';
    ctx.font = '8px Noto Sans KR, sans-serif';
    ctx.textAlign = 'center';
    ctx.fillText(ym.slice(5), x + barW/2, H - 6);
  });
}

function renderStats(data) {
  renderStatsSummary(data);
  renderDonutChart(data);
  renderBarChartCanvas(data.monthly || {});
}

/* renderBarChart 제거 — renderBarChartCanvas로 대체 */

function setPeriod(btn, period) {
  document.querySelectorAll('.period-btn').forEach(function(b) { b.classList.remove('active'); });
  btn.classList.add('active');
  loadStats(period);
}

// ── 조서 이력 → 사건 화면 이동 ──────────────────────────────────────
function goToCase(caseId) {
  if (!caseId) return;
  location.href = 'myCase?caseId=' + encodeURIComponent(caseId);
}

function escHtml(s) {
  return String(s || '').replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;');
}

// ── 설정 저장 (토글 변경 시 즉시 호출) ───────────────────────────
function saveSettings() {
  var params = new URLSearchParams();
  params.append('action',             'saveSettings');
  params.append('notifContradiction', document.getElementById('toggleContradiction').checked ? '1' : '0');
  params.append('notifRelation',      document.getElementById('toggleRelation').checked      ? '1' : '0');
  params.append('nightMode',          document.getElementById('toggleNightMode').checked     ? '1' : '0');

  fetch('../mypage', { method: 'POST', body: params })
    .catch(function(e) { console.error('설정 저장 실패', e); });
}
</script>

</body>
</html>
