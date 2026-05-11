<%@ page language="java" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8"%>
<%
    String loginUser = (String) session.getAttribute("loginUser");
    String userName  = (String) session.getAttribute("userName");
    String paramCaseId = request.getParameter("caseId") != null ? request.getParameter("caseId") : "";
    String safeParamCaseIdJs = paramCaseId.replace("\\", "\\\\").replace("'", "\\'");

    String polMateServBaseUrl = "http://113.198.238.111:5001";
    try {
        java.util.Properties props = new java.util.Properties();
        java.io.InputStream is = application.getResourceAsStream("/WEB-INF/config.properties");
        if (is != null) {
            props.load(is);
            String u = props.getProperty("POL_MATE_SERV_BASE_URL", "").trim();
            if (!u.isEmpty()) {
                while (u.endsWith("/")) u = u.substring(0, u.length() - 1);
                polMateServBaseUrl = u;
            }
            is.close();
        }
    } catch (Exception ignored) {}
    String safePolMateServBaseUrl = polMateServBaseUrl.replace("\\", "\\\\").replace("'", "\\'");
%>
<!DOCTYPE html>
<html lang="ko">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
<title>POL-MATE | 사건 관리</title>
<link href="https://fonts.googleapis.com/css2?family=Noto+Sans+KR:wght@300;400;500;700&display=swap" rel="stylesheet">
<style>
  * { margin:0; padding:0; box-sizing:border-box; -webkit-tap-highlight-color:transparent; }
  :root {
    --navy:#1a2744; --accent:#4a7cdc; --danger:#dc2626;
    --contra-section-accent:#c2410c;
    --text-primary:#1a1a2e; --text-secondary:#6b7280; --text-muted:#9ca3af;
    --bg:#f4f6fb; --card:#ffffff; --border:#e5e7eb;
    --success:#16a34a; --success-bg:#f0fdf4; --success-border:#bbf7d0;
    --warn-bg:#fffbeb; --warn-text:#92400e;
    --danger-bg:#fef2f2; --danger-border:#fecaca;
    --info-bg:#eff6ff; --info-text:#1e40af;
    --bnav:64px;
  }
  html,body { height:100%; font-family:'Noto Sans KR',sans-serif; background:var(--bg); overflow-x:hidden; }
  .screen { width:100%; max-width:420px; height:100dvh; margin:0 auto; background:var(--bg); display:flex; flex-direction:column; }

  /* ── 헤더 ── */
  .top-header { background:var(--navy); padding:52px 20px 0; position:sticky; top:0; z-index:10; }
  .header-row { display:flex; align-items:center; justify-content:space-between; padding-bottom:14px; }
  .header-title { font-size:17px; font-weight:500; color:#fff; }
  .btn-new {
    background:rgba(255,255,255,0.15); border:1px solid rgba(255,255,255,0.25);
    color:#fff; border-radius:20px; padding:7px 14px; font-size:12px;
    font-family:'Noto Sans KR',sans-serif; cursor:pointer; display:flex; align-items:center; gap:5px;
  }
  .btn-new svg { width:13px; height:13px; stroke:#fff; }

  /* 검색 바 */
  .search-wrap { background:var(--navy); padding:0 16px 16px; }
  .search-box {
    background:rgba(255,255,255,0.1); border:1px solid rgba(255,255,255,0.2);
    border-radius:12px; display:flex; align-items:center; gap:10px; padding:10px 14px;
  }
  .search-box svg { width:16px; height:16px; stroke:rgba(255,255,255,0.5); flex-shrink:0; }
  .search-input {
    flex:1; background:none; border:none; outline:none;
    font-size:13px; color:#fff; font-family:'Noto Sans KR',sans-serif;
  }
  .search-input::placeholder { color:rgba(255,255,255,0.4); }

  /* ── 콘텐츠 ── */
  .content { flex:1; overflow-y:auto; padding-bottom:calc(var(--bnav) + 16px); }

  /* 필터 칩 */
  .filter-row {
    display:flex; gap:8px; padding:14px 16px 10px; overflow-x:auto;
    -ms-overflow-style:none; scrollbar-width:none;
  }
  .filter-row::-webkit-scrollbar { display:none; }
  .chip {
    flex-shrink:0; padding:6px 14px; border-radius:20px; font-size:12px;
    border:1px solid var(--border); background:var(--card); color:var(--text-secondary);
    cursor:pointer; white-space:nowrap; transition:all 0.15s; font-family:'Noto Sans KR',sans-serif;
  }
  .chip.active { background:var(--navy); color:#fff; border-color:var(--navy); }

  /* 정렬 바 */
  .sort-bar {
    display:flex; align-items:center; justify-content:flex-end;
    padding:0 16px 10px; gap:6px;
  }
  .sort-btn {
    display:flex; align-items:center; gap:4px;
    padding:5px 11px; border-radius:20px; font-size:11px;
    border:1px solid var(--border); background:var(--card); color:var(--text-secondary);
    cursor:pointer; white-space:nowrap; transition:all 0.15s; font-family:'Noto Sans KR',sans-serif;
  }
  .sort-btn svg { width:12px; height:12px; stroke:currentColor; flex-shrink:0; }
  .sort-btn.active { background:var(--navy); color:#fff; border-color:var(--navy); }

  /* 사건 카드 */
  .case-list { padding:0 16px; display:flex; flex-direction:column; gap:10px; }
  .case-card {
    background:var(--card); border-radius:16px; border:1px solid var(--border);
    padding:16px; cursor:pointer; transition:border-color 0.2s;
    animation:fadeUp 0.3s ease both; text-decoration:none; display:block;
  }
  .case-card:active { background:var(--bg); }
  .case-card.urgent { border-left:3px solid var(--danger); }

  .case-top { display:flex; justify-content:space-between; align-items:flex-start; margin-bottom:10px; }
  .case-num  { font-size:12px; color:var(--text-muted); margin-bottom:3px; }
  .case-name { font-size:15px; font-weight:500; color:var(--text-primary); }

  .badge { font-size:10px; font-weight:500; padding:4px 10px; border-radius:20px; white-space:nowrap; flex-shrink:0; }
  .badge-warn   { background:var(--warn-bg);    color:var(--warn-text); }
  .badge-ok     { background:var(--success-bg); color:var(--success); }
  .badge-info   { background:var(--info-bg);    color:var(--info-text); }
  .badge-done   { background:#f3f4f6;            color:var(--text-muted); }
  .badge-danger { background:var(--danger-bg);  color:var(--danger); }

  .case-meta { display:flex; gap:14px; flex-wrap:wrap; }
  .meta-item { display:flex; align-items:center; gap:5px; font-size:11px; color:var(--text-muted); }
  .meta-item svg { width:12px; height:12px; stroke:var(--text-muted); }



  /* 빈 상태 */
  .empty-state { padding:48px 20px; text-align:center; }
  .empty-icon  { width:60px; height:60px; background:var(--bg); border-radius:50%; margin:0 auto 14px; display:flex; align-items:center; justify-content:center; }
  .empty-icon svg { width:28px; height:28px; stroke:var(--text-muted); }
  .empty-title { font-size:14px; font-weight:500; color:var(--text-secondary); margin-bottom:6px; }
  .empty-desc  { font-size:12px; color:var(--text-muted); }

  /* ── 드로어 ── */
  .overlay { position:fixed; inset:0; background:rgba(0,0,0,0.45); z-index:200; display:none; align-items:flex-end; justify-content:center; }
  .overlay.open { display:flex; }
  .drawer { background:var(--card); border-radius:20px 20px 0 0; width:100%; max-width:420px; padding:0 0 36px; animation:slideUp 0.28s ease both; max-height:88vh; overflow-y:auto; }
  .drawer-handle { width:36px; height:4px; background:var(--border); border-radius:2px; margin:12px auto 0; }
  .drawer-head   { padding:16px 20px; border-bottom:1px solid var(--border); }
  .drawer-title  { font-size:16px; font-weight:500; color:var(--text-primary); }
  .drawer-sub    { font-size:12px; color:var(--text-muted); margin-top:3px; }
  .drawer-body   { padding:16px 20px; }

  .action-grid { display:grid; grid-template-columns:1fr 1fr; gap:10px; margin-top:16px; }
  .action-btn {
    background:var(--bg); border:1px solid var(--border); border-radius:12px;
    padding:14px 10px; text-align:center; cursor:pointer; text-decoration:none; display:block; transition:background 0.15s;
  }
  .action-btn:active { background:var(--border); }
  .action-btn svg { width:20px; height:20px; display:block; margin:0 auto 6px; }
  .action-btn span { font-size:11px; color:var(--text-secondary); }
  .action-btn.primary { background:var(--navy); border-color:var(--navy); }
  .action-btn.primary svg { stroke:#fff; }
  .action-btn.primary span { color:#fff; }

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

  .status-btn { padding:10px 8px; border:1px solid var(--border); border-radius:10px; background:var(--card); font-size:13px; font-family:'Noto Sans KR',sans-serif; color:var(--text-secondary); cursor:pointer; transition:all 0.15s; }
  .status-btn.selected { background:var(--navy); color:#fff; border-color:var(--navy); }

  /* ── 드로어 내 조서 목록 ── */
  .drawer-doc-list { display:flex; flex-direction:column; gap:8px; margin-bottom:6px; }
  .drawer-doc-item { display:flex; align-items:center; gap:10px; background:var(--bg); border:1px solid var(--border); border-radius:12px; padding:11px 13px; cursor:pointer; transition:border-color 0.15s; }
  .drawer-doc-item:active { border-color:var(--accent); }
  .drawer-doc-item.checked { border-color:var(--accent); background:#eff6ff; }
  .doc-checkbox { width:18px; height:18px; border-radius:5px; border:2px solid var(--border); background:var(--card); display:flex; align-items:center; justify-content:center; flex-shrink:0; transition:all 0.15s; }
  .doc-checkbox.on { background:var(--accent); border-color:var(--accent); }
  .doc-checkbox.on::after { content:''; display:block; width:5px; height:9px; border:2px solid #fff; border-top:none; border-left:none; transform:rotate(45deg) translateY(-1px); }
  .drawer-doc-icon { width:34px; height:34px; border-radius:9px; display:flex; align-items:center; justify-content:center; flex-shrink:0; }
  .drawer-doc-icon svg { width:17px; height:17px; }
  .drawer-doc-info { flex:1; min-width:0; }
  .drawer-doc-title { font-size:12px; font-weight:500; color:var(--text-primary); white-space:nowrap; overflow:hidden; text-overflow:ellipsis; }
  .drawer-doc-meta  { font-size:10px; color:var(--text-muted); margin-top:2px; }
  .drawer-doc-badge { flex-shrink:0; }
  .action-btn.disabled { opacity:0.38; cursor:not-allowed; pointer-events:none; }
  #contraBtn:not(.disabled) { cursor:pointer; pointer-events:auto; opacity:1; }
  .action-btn.contra-active { background:var(--danger-bg); border-color:var(--danger); }
  .action-btn.contra-active svg { stroke:var(--danger) !important; }
  .action-btn.contra-active span { color:var(--danger) !important; }

  /* ── 팝업 ── */
  .popup-overlay { position:fixed; inset:0; background:rgba(0,0,0,0.55); z-index:400; display:none; align-items:center; justify-content:center; padding:20px; }
  .popup-overlay.open { display:flex; }
  .popup-sheet { background:var(--card); border-radius:16px; width:100%; max-width:380px; max-height:75vh; display:flex; flex-direction:column; animation:slideUp 0.22s ease both; }
  .popup-head { padding:16px 18px 12px; border-bottom:1px solid var(--border); display:flex; align-items:flex-start; justify-content:space-between; gap:10px; }
  .popup-title { font-size:14px; font-weight:600; color:var(--text-primary); flex:1; }
  .popup-close { width:28px; height:28px; border-radius:50%; border:none; background:var(--bg); display:flex; align-items:center; justify-content:center; cursor:pointer; flex-shrink:0; }
  .popup-close svg { width:14px; height:14px; stroke:var(--text-muted); }
  .popup-body { flex:1; overflow-y:auto; padding:14px 18px 18px; font-size:13px; color:var(--text-primary); line-height:1.8; white-space:pre-wrap; }
  .popup-summary {
    flex:0 0 auto;
    max-height:170px;
    overflow-y:auto;
    border-top:1px solid var(--border);
    background:var(--bg);
    padding:12px 18px 16px;
  }
  .popup-summary-title { font-size:12px; font-weight:600; color:var(--navy); margin-bottom:6px; }
  .popup-summary-text  { font-size:12px; color:var(--text-primary); line-height:1.8; white-space:pre-wrap; }
  .popup-summary-empty { color:var(--text-muted); font-size:12px; }
  .popup-empty { color:var(--text-muted); font-size:12px; text-align:center; padding:24px 0; }
  .contra-result { font-size:13px; color:var(--text-primary); line-height:1.8; white-space:pre-wrap; }
  .contra-loading { text-align:center; padding:30px 0; color:var(--text-muted); font-size:13px; }
  .contra-buffer-spinner {
    width:36px; height:36px; margin:0 auto 14px;
    border:3px solid var(--border); border-top-color:var(--navy); border-radius:50%;
    animation:contraSpin 0.72s linear infinite;
  }
  @keyframes contraSpin { to { transform:rotate(360deg); } }
  .contra-analyze-loading { text-align:center; padding:32px 16px 28px; color:var(--text-muted); font-size:13px; }
  .contra-analyze-loading-title { font-size:14px; font-weight:600; color:var(--navy); margin-bottom:6px; }
  .contra-analyze-loading-sub { font-size:11px; line-height:1.5; color:var(--text-muted); }
  .contra-bubble-wrap { display:flex; justify-content:flex-start; width:100%; }
  .contra-bubble {
    max-width:100%; width:100%;
    background:linear-gradient(165deg, #f0f4ff 0%, #f8fafc 100%);
    border:1px solid #e2e8f0; border-radius:18px 18px 18px 6px;
    padding:14px 16px 16px;
    box-shadow:0 2px 8px rgba(26,39,68,0.06);
    font-size:13px; color:var(--text-primary); line-height:1.75;
    white-space:pre-wrap; word-break:break-word;
  }
  .contra-type-text { min-height:1.4em; }
  .contra-analyze-section-title {
    color:var(--contra-section-accent);
    font-weight:600;
  }
  .contra-bubble-caret {
    display:inline-block; width:2px; height:14px; margin-left:2px;
    background:var(--navy); border-radius:1px; vertical-align:-2px;
    animation:contraCaretBlink 0.85s step-end infinite;
  }
  @keyframes contraCaretBlink { 50% { opacity:0; } }

  @keyframes fadeUp  { from{opacity:0;transform:translateY(10px)} to{opacity:1;transform:translateY(0)} }
  @keyframes slideUp { from{transform:translateY(100%);opacity:0} to{transform:translateY(0);opacity:1} }
  @media(min-width:421px){ .screen{box-shadow:0 0 40px rgba(0,0,0,0.1);} }

  /* ── 신뢰도 스코어 ── */
  .m-score-badge { font-size:10px; font-weight:600; padding:2px 7px; border-radius:10px; white-space:nowrap; cursor:pointer; display:inline-block; }
  .m-score-high  { background:#f0fdf4; color:#16a34a; }
  .m-score-mid   { background:#fffbeb; color:#92400e; }
  .m-score-low   { background:#fef2f2; color:#dc2626; }
  .m-score-btn   { width:26px; height:26px; border-radius:8px; border:1px solid var(--border); background:var(--bg); display:inline-flex; align-items:center; justify-content:center; cursor:pointer; padding:0; }
  .m-score-total-card { background:var(--bg); border-radius:12px; padding:14px 16px; margin-bottom:14px; display:flex; align-items:center; gap:14px; }
  .m-score-total-num   { font-size:40px; font-weight:700; line-height:1; }
  .m-score-total-label { font-size:10px; color:var(--text-muted); text-transform:uppercase; letter-spacing:0.5px; margin-bottom:2px; }
  .m-score-total-grade { font-size:13px; font-weight:500; color:var(--text-primary); }
  .m-score-bars { display:flex; flex-direction:column; gap:12px; margin-bottom:4px; }
  .m-score-row-header { display:flex; justify-content:space-between; align-items:center; margin-bottom:5px; }
  .m-score-row-label  { font-size:12px; font-weight:500; color:var(--text-primary); }
  .m-score-row-val    { font-size:12px; font-weight:600; }
  .m-score-bar-track  { height:5px; background:#f0f2f8; border-radius:3px; overflow:hidden; }
  .m-score-bar-fill   { height:100%; border-radius:3px; }
  .m-fill-high { background:#16a34a; }
  .m-fill-mid  { background:#f59e0b; }
  .m-fill-low  { background:#dc2626; }
  .m-score-row-reason { font-size:11px; color:var(--text-muted); margin-top:4px; line-height:1.45; }
  .m-score-empty   { padding:30px 0; text-align:center; color:var(--text-muted); font-size:13px; line-height:1.7; }
  .m-score-loading { padding:30px 0; text-align:center; color:var(--text-muted); font-size:13px; line-height:1.7; }
  /* 도움말 팝오버 */
  .m-help-wrap { position:relative; display:inline-flex; align-items:center; }
  .m-help-btn  { width:16px; height:16px; border-radius:50%; border:1.5px solid #d1d5db; background:#f9fafb; color:#6b7280; font-size:10px; font-weight:700; cursor:pointer; display:inline-flex; align-items:center; justify-content:center; padding:0; line-height:1; }
  .m-help-popover { display:none; position:absolute; top:calc(100% + 6px); left:0; width:256px; background:#fff; border:1px solid var(--border); border-radius:12px; box-shadow:0 6px 20px rgba(0,0,0,0.12); padding:14px; z-index:600; }
  .m-help-popover.open { display:block; }
  .m-help-popover-title { font-size:10px; font-weight:700; color:var(--text-primary); text-transform:uppercase; letter-spacing:0.5px; margin-bottom:10px; }
  .m-help-criterion { margin-bottom:9px; }
  .m-help-criterion-name  { font-size:11px; font-weight:600; color:var(--navy); margin-bottom:2px; }
  .m-help-criterion-range { font-size:10px; font-weight:400; color:var(--text-muted); margin-left:4px; }
  .m-help-criterion-desc  { font-size:11px; color:var(--text-secondary); line-height:1.5; }
  .m-help-total-note { font-size:10px; color:var(--text-muted); padding-top:7px; border-top:1px solid var(--border); margin-top:4px; }
</style>
</head>
<body>
<div class="screen">

  <div class="top-header">
    <div class="header-row">
      <span class="header-title">사건 관리</span>
      <button class="btn-new" onclick="openNewCaseDrawer()">
        <svg viewBox="0 0 24 24" fill="none" stroke-width="2" stroke-linecap="round"><line x1="12" y1="5" x2="12" y2="19"/><line x1="5" y1="12" x2="19" y2="12"/></svg>
        새 사건
      </button>
    </div>
    <div class="search-wrap">
      <div class="search-box">
        <svg viewBox="0 0 24 24" fill="none" stroke-width="1.8" stroke-linecap="round"><circle cx="11" cy="11" r="8"/><line x1="21" y1="21" x2="16.65" y2="16.65"/></svg>
        <input type="text" class="search-input" id="searchInput" placeholder="사건번호 또는 사건명 검색...">
      </div>
    </div>
  </div>

  <div class="content">
      <div class="filter-row">
        <button class="chip active" onclick="setFilter(this,'all')">전체</button>
        <button class="chip" onclick="setFilter(this,'검토필요')">검토필요</button>
        <button class="chip" onclick="setFilter(this,'진행중')">진행중</button>
        <button class="chip" onclick="setFilter(this,'완료')">완료</button>
        <button class="chip" onclick="setFilter(this,'모순탐지')">모순탐지</button>
      </div>
    <div class="sort-bar">
      <button class="sort-btn active" id="sortDateDesc" onclick="setSort('date_desc')">
        <svg viewBox="0 0 24 24" fill="none" stroke-width="2" stroke-linecap="round"><rect x="3" y="4" width="18" height="18" rx="2"/><line x1="16" y1="2" x2="16" y2="6"/><line x1="8" y1="2" x2="8" y2="6"/><line x1="3" y1="10" x2="21" y2="10"/></svg>
        최신순
      </button>
      <button class="sort-btn" id="sortDateAsc" onclick="setSort('date_asc')">
        <svg viewBox="0 0 24 24" fill="none" stroke-width="2" stroke-linecap="round"><rect x="3" y="4" width="18" height="18" rx="2"/><line x1="16" y1="2" x2="16" y2="6"/><line x1="8" y1="2" x2="8" y2="6"/><line x1="3" y1="10" x2="21" y2="10"/></svg>
        오래된순
      </button>

    </div>
    <div class="case-list" id="caseList"></div>
    </div>

  <nav class="bottom-nav">
    <a href="main" class="nav-item">
    <div class="nav-icon"><svg viewBox="0 0 24 24"><path d="M3 9l9-7 9 7v11a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"/><polyline points="9 22 9 12 15 12 15 22"/></svg></div>
      <span class="nav-label">홈</span>
    </a>
    <a href="myCase" class="nav-item active">
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
    <a href="mypage" class="nav-item">
    <div class="nav-icon"><svg viewBox="0 0 24 24"><path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2"/><circle cx="12" cy="7" r="4"/></svg></div>
      <span class="nav-label">마이페이지</span>
    </a>
  </nav>
</div>

<!-- 사건 상세 드로어 -->
<div class="overlay" id="caseDrawer" onclick="closeOnBg(event,'caseDrawer')">
  <div class="drawer">
    <div class="drawer-handle"></div>
    <div class="drawer-head">
      <div class="drawer-title" id="drawerTitle">-</div>
      <div class="drawer-sub"   id="drawerSub">-</div>
    </div>
    <div class="drawer-body">
      <div id="drawerDocList"></div>
      <div class="action-grid" id="drawerActions"></div>
    </div>
  </div>
</div>

<!-- 조서 내용 팝업 -->
<div class="popup-overlay" id="transcriptPopup" onclick="closeTranscriptPopup(event)">
  <div class="popup-sheet">
    <div class="popup-head">
      <div class="popup-title" id="popupTitle">-</div>
      <button class="popup-close" onclick="closeTranscriptPopup()"><svg viewBox="0 0 24 24" fill="none" stroke-width="2" stroke-linecap="round"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg></button>
    </div>
    <div class="popup-body" id="popupBody"></div>
    <div class="popup-summary" id="popupSummary">
      <div class="popup-summary-title">요약본</div>
      <div class="popup-summary-text" id="popupSummaryText"></div>
    </div>
  </div>
</div>

<!-- 모순탐지 결과 팝업 -->
<div class="popup-overlay" id="contraPopup" onclick="closeContraPopup(event)">
  <div class="popup-sheet">
    <div class="popup-head">
      <div class="popup-title" id="contraPopupTitle">모순 분석 결과</div>
      <button class="popup-close" onclick="closeContraPopup()"><svg viewBox="0 0 24 24" fill="none" stroke-width="2" stroke-linecap="round"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg></button>
    </div>
    <div class="popup-body" id="contraPopupBody"></div>
    <!-- 자동 저장 실패 시에만 표시 (다시 시도) -->
    <div id="contraSaveFooter" style="display:none; padding:12px 18px 16px; border-top:1px solid var(--border);">
      <div id="contraSaveHint" style="display:none;font-size:11px;color:var(--danger);text-align:center;margin-bottom:10px;line-height:1.5;">목록에 자동 저장되지 않았습니다. 아래를 눌러 다시 시도하세요.</div>
      <button id="contraSaveBtn" onclick="saveContraResult()"
        style="width:100%; background:var(--navy); color:#fff; border:none; border-radius:12px;
               padding:13px; font-size:13px; font-weight:500; font-family:'Noto Sans KR',sans-serif;
               cursor:pointer; display:flex; align-items:center; justify-content:center; gap:8px;">
        <svg viewBox="0 0 24 24" fill="none" stroke="#fff" stroke-width="2" stroke-linecap="round" style="width:15px;height:15px;">
          <path d="M19 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h11l5 5v11a2 2 0 0 1-2 2z"/>
          <polyline points="17 21 17 13 7 13 7 21"/><polyline points="7 3 7 8 15 8"/>
        </svg>
        다시 저장하기
      </button>
    </div>
  </div>
</div>

<!-- 새 사건 등록 드로어 -->
<div class="overlay" id="newCaseDrawer" onclick="closeOnBg(event,'newCaseDrawer')">
  <div class="drawer">
    <div class="drawer-handle"></div>
    <div class="drawer-head">
      <div class="drawer-title">새 사건 등록</div>
      <div class="drawer-sub">담당 사건을 새로 등록합니다</div>
    </div>
    <div class="drawer-body">
      <div style="display:flex;flex-direction:column;gap:12px;">
        <div style="background:#f4f6fb;border-radius:10px;padding:11px 14px;display:flex;align-items:center;justify-content:space-between;">
          <span style="font-size:12px;color:var(--text-muted);">담당 부서</span>
          <span id="newCaseDeptLabel" style="font-size:13px;font-weight:500;color:var(--navy);">불러오는 중...</span>
        </div>
        <div>
          <label style="font-size:11px;color:var(--text-muted);font-weight:500;display:block;margin-bottom:5px;">사건번호 <span style="color:var(--danger)">*</span></label>
          <input id="newCaseId" type="text" placeholder="예: 2024-0312" maxlength="9" style="width:100%;padding:11px 14px;border:1px solid var(--border);border-radius:10px;font-size:14px;font-family:'Noto Sans KR',sans-serif;outline:none;">
        </div>
        <div>
          <label style="font-size:11px;color:var(--text-muted);font-weight:500;display:block;margin-bottom:5px;">사건명 <span style="color:var(--danger)">*</span></label>
          <input id="newCaseName" type="text" placeholder="예: 절도사건" maxlength="50" style="width:100%;padding:11px 14px;border:1px solid var(--border);border-radius:10px;font-size:14px;font-family:'Noto Sans KR',sans-serif;outline:none;">
        </div>
        <div>
          <label style="font-size:11px;color:var(--text-muted);font-weight:500;display:block;margin-bottom:5px;">피의자 성명 (선택)</label>
          <input id="newSuspect" type="text" placeholder="홍길동" maxlength="30" style="width:100%;padding:11px 14px;border:1px solid var(--border);border-radius:10px;font-size:14px;font-family:'Noto Sans KR',sans-serif;outline:none;">
        </div>
        <button onclick="submitNewCase()" style="width:100%;padding:14px;background:var(--navy);color:#fff;border:none;border-radius:12px;font-size:14px;font-weight:500;font-family:'Noto Sans KR',sans-serif;cursor:pointer;margin-top:4px;">등록하기</button>
      </div>
    </div>
  </div>
</div>

<!-- 상태·진행률 수정 드로어 -->
<div class="overlay" id="editDrawer" onclick="closeOnBg(event,'editDrawer')">
  <div class="drawer">
    <div class="drawer-handle"></div>
    <div class="drawer-head">
      <div class="drawer-title">사건 수정</div>
      <div class="drawer-sub" id="editDrawerSub">-</div>
    </div>
    <div class="drawer-body">
      <div style="display:flex;flex-direction:column;gap:14px;">
        <div>
          <label style="font-size:11px;color:var(--text-muted);font-weight:500;display:block;margin-bottom:8px;">상태</label>
          <div style="display:grid;grid-template-columns:1fr 1fr;gap:8px;">
            <button class="status-btn" data-val="진행중"   onclick="selectStatus(this)">진행중</button>
            <button class="status-btn" data-val="검토필요" onclick="selectStatus(this)">검토필요</button>
            <button class="status-btn" data-val="완료"     onclick="selectStatus(this)">완료</button>
            <button class="status-btn" data-val="모순탐지" onclick="selectStatus(this)">모순탐지</button>
          </div>
        </div>

        <button onclick="submitEditCase()" style="width:100%;padding:14px;background:var(--navy);color:#fff;border:none;border-radius:12px;font-size:14px;font-weight:500;font-family:'Noto Sans KR',sans-serif;cursor:pointer;">저장하기</button>
      </div>
    </div>
  </div>
</div>

<!-- 신뢰도 분석 팝업 -->
<div class="popup-overlay" id="scorePopup" onclick="closeScoreSheet(event)">
  <div class="popup-sheet" style="max-height:85vh;">
    <div class="popup-head">
      <div style="flex:1;">
        <div style="display:flex;align-items:center;gap:6px;margin-bottom:3px;">
          <span style="font-size:10px;color:var(--text-muted);text-transform:uppercase;letter-spacing:0.5px;">신뢰도 분석</span>
          <div class="m-help-wrap">
            <button class="m-help-btn" onclick="toggleMobileHelp(event)">?</button>
            <div class="m-help-popover" id="mHelpPopover">
              <div class="m-help-popover-title">채점 기준 안내</div>
              <div class="m-help-criterion">
                <div class="m-help-criterion-name">일관성<span class="m-help-criterion-range">0–100점</span></div>
                <div class="m-help-criterion-desc">진술 내부에서 동일 사건·행위에 대한 주장이 앞뒤로 모순 없이 일치하는 정도. 부정·긍정 표현이 혼재하면 감점.</div>
              </div>
              <div class="m-help-criterion">
                <div class="m-help-criterion-name">구체성<span class="m-help-criterion-range">0–100점</span></div>
                <div class="m-help-criterion-desc">날짜·시각·장소·인물·행위가 얼마나 구체적으로 기술됐는지. 모호한 표현이 많을수록 감점.</div>
              </div>
              <div class="m-help-criterion">
                <div class="m-help-criterion-name">감정 안정성<span class="m-help-criterion-range">0–100점</span></div>
                <div class="m-help-criterion-desc">흥분·방어적·과장 표현 없이 차분하고 중립적인 정도.</div>
              </div>
              <div class="m-help-criterion">
                <div class="m-help-criterion-name">시간 정합성<span class="m-help-criterion-range">0–100점</span></div>
                <div class="m-help-criterion-desc">사건 시간 순서와 이동 경로가 논리적으로 맞는 정도.</div>
              </div>
              <div class="m-help-total-note">종합 점수는 4개 기준의 단순 평균입니다.</div>
            </div>
          </div>
        </div>
        <div class="popup-title" id="scorePopupTitle"></div>
      </div>
      <button class="popup-close" onclick="closeScoreSheet()">
        <svg viewBox="0 0 24 24" fill="none" stroke-width="2" stroke-linecap="round"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg>
      </button>
    </div>
    <div class="popup-body" id="scorePopupBody" style="padding:14px 18px;"></div>
    <div style="padding:0 18px 24px;flex-shrink:0;">
      <button id="mBtnAnalyze" onclick="runMobileScoreAnalysis()"
        style="width:100%;padding:13px;background:var(--navy);color:#fff;border:none;border-radius:12px;font-size:13px;font-weight:500;font-family:'Noto Sans KR',sans-serif;cursor:pointer;">
        신뢰도 분석 실행
      </button>
    </div>
  </div>
</div>

<div id="toast" style="position:fixed;bottom:84px;left:50%;transform:translateX(-50%) translateY(20px);background:var(--navy);color:#fff;padding:10px 20px;border-radius:24px;font-size:13px;opacity:0;transition:all 0.3s;pointer-events:none;z-index:999;white-space:nowrap;font-family:'Noto Sans KR',sans-serif;"></div>

<script>
var CASES = [], currentFilter = 'all', currentSort = 'date_desc', currentCaseId = null, editCaseId = null, selectedStatus = '';
var BADGE_CLS = { '검토필요':'badge-warn','진행중':'badge-ok','완료':'badge-done','모순탐지':'badge-danger' };
var mDocScores = {}, mCurrentScoreId = null;

function setFilter(el, val) {
  document.querySelectorAll('.chip').forEach(function(c){c.classList.remove('active');});
  el.classList.add('active'); currentFilter = val; loadCaseList();
}

function setSort(val) {
  currentSort = val;
  document.querySelectorAll('.sort-btn').forEach(function(b){b.classList.remove('active');});
  var idMap = { date_desc:'sortDateDesc', date_asc:'sortDateAsc' };
  document.getElementById(idMap[val]).classList.add('active');
  renderCases(sortedCases(CASES));
}

function sortedCases(list) {
  var arr = list.slice();
  if (currentSort === 'date_asc') {
    arr.sort(function(a, b){ return a.date < b.date ? -1 : a.date > b.date ? 1 : 0; });
  } else { // date_desc (기본)
    arr.sort(function(a, b){ return a.date < b.date ? 1 : a.date > b.date ? -1 : 0; });
  }
  return arr;
}

var _st = null;
document.getElementById('searchInput').addEventListener('input', function(){
  clearTimeout(_st); _st = setTimeout(loadCaseList, 350);
});

function loadCaseList() {
  var kw = document.getElementById('searchInput').value.trim();
  document.getElementById('caseList').innerHTML = '<div style="text-align:center;padding:40px 0;color:var(--text-muted);font-size:13px;">불러오는 중...</div>';
  fetch('../caseApi?action=caseList&status=' + encodeURIComponent(currentFilter) + '&keyword=' + encodeURIComponent(kw))
    .then(function(r){ if(!r.ok) throw new Error('HTTP '+r.status); return r.json(); })
    .then(function(data){
      if(data.error){ document.getElementById('caseList').innerHTML='<div class="empty-state"><div class="empty-title" style="color:var(--danger)">'+data.error+'</div></div>'; return; }
      CASES = Array.isArray(data) ? data : []; renderCases(sortedCases(CASES));
    })
    .catch(function(e){ console.error(e); document.getElementById('caseList').innerHTML='<div class="empty-state"><div class="empty-title" style="color:var(--danger)">목록 로드 실패</div></div>'; });
}

function renderCases(list) {
  if(!list.length){
    document.getElementById('caseList').innerHTML='<div class="empty-state"><div class="empty-icon"><svg viewBox="0 0 24 24" fill="none" stroke-width="1.8" stroke-linecap="round"><circle cx="11" cy="11" r="8"/><line x1="21" y1="21" x2="16.65" y2="16.65"/></svg></div><div class="empty-title">사건이 없습니다</div><div class="empty-desc">새 사건을 등록해 보세요</div></div>';
    return;
  }
  var html='';
  list.forEach(function(c,i){
    var bc=BADGE_CLS[c.status]||'badge-info';
    var dt=(c.rank?c.rank+' ':'')+escHtml(c.detective);
    var tt=!c.isMine?'<span style="font-size:10px;background:#f0fdf4;color:#16a34a;padding:2px 7px;border-radius:10px;margin-left:4px;">팀원</span>':'';
    var st=(c.suspect&&c.suspect!=='미입력')
      ?'<span style="font-size:11px;color:var(--text-muted);white-space:nowrap;">피의자: '+escHtml(c.suspect)+'</span>':'';
    html+='<div class="case-card'+(c.urgent?' urgent':'')+'" style="animation-delay:'+(i*0.05)+'s" onclick="openCase(\''+escStr(c.id)+'\')">' +
      '<div class="case-top">' +
        '<div><div class="case-num">'+escHtml(c.id)+tt+'</div><div class="case-name">'+escHtml(c.name)+'</div></div>' +
        '<div style="display:flex;align-items:center;gap:7px;flex-shrink:0;">'+st+'<span class="badge '+bc+'">'+escHtml(c.status)+'</span></div>' +
      '</div>' +
      '<div class="case-meta">' +
        '<div class="meta-item"><svg viewBox="0 0 24 24" fill="none" stroke-width="1.8" stroke-linecap="round"><path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2"/><circle cx="12" cy="7" r="4"/></svg>'+dt+'</div>' +
        '<div class="meta-item"><svg viewBox="0 0 24 24" fill="none" stroke-width="1.8" stroke-linecap="round"><rect x="3" y="4" width="18" height="18" rx="2"/><line x1="16" y1="2" x2="16" y2="6"/><line x1="8" y1="2" x2="8" y2="6"/><line x1="3" y1="10" x2="21" y2="10"/></svg>'+escHtml(c.date)+'</div>' +
        '<div class="meta-item"><svg viewBox="0 0 24 24" fill="none" stroke-width="1.8" stroke-linecap="round"><path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/><polyline points="14 2 14 8 20 8"/></svg>조서 '+c.docs+'건</div>' +
      '</div>' +
    '</div>';
  });
  document.getElementById('caseList').innerHTML=html;
}

var checkedDocs=[], currentDocs=[], currentCaseData={};

function openCase(id) {
  currentCaseId=id; checkedDocs=[]; currentDocs=[]; currentCaseData={};
  document.getElementById('drawerTitle').textContent=id;
  document.getElementById('drawerSub').textContent='불러오는 중...';
  document.getElementById('drawerDocList').innerHTML='';
  document.getElementById('drawerActions').innerHTML='';
  document.getElementById('caseDrawer').classList.add('open');
  document.body.style.overflow='hidden';
  fetch('../caseApi?action=caseDetail&caseId='+encodeURIComponent(id))
    .then(function(r){return r.json();})
    .then(function(c){
      if(c.error){showToast(c.error);closeDrawer('caseDrawer');return;}
      currentCaseData=c; currentDocs=Array.isArray(c.docs)?c.docs:[];
      document.getElementById('drawerTitle').textContent=c.id+' '+c.name;
      document.getElementById('drawerSub').textContent='조서 '+c.docCount+'건'+(c.suspect&&c.suspect!=='미입력'?'  ·  피의자: '+c.suspect:'');
      renderDrawerDocs(currentDocs); renderDrawerActions(c);
    })
    .catch(function(){showToast('상세 조회 실패');});
}

function renderDrawerDocs(docs) {
  mDocScores = {};
  var im={'피의자':'#fee2e2','피해자':'#e8f4ef','목격자':'#dbeafe','참고인':'#ede9fe'};
  var sm={'피의자':'#dc2626','피해자':'#3d8f6a','목격자':'#4a7cdc','참고인':'#8b5cf6'};
  if(!docs.length){document.getElementById('drawerDocList').innerHTML='<div style="text-align:center;padding:24px 0;color:var(--text-muted);font-size:12px;">등록된 조서가 없습니다.<br>조서 추가 버튼으로 첫 조서를 작성하세요.</div>';return;}
  var html='<div class="drawer-doc-list">';
  docs.forEach(function(d,i){
    mDocScores[d.id] = d;
    var bg=im[d.type]||'#f3f4f6', st=sm[d.type]||'#6b7280';
    var bc=d.contradiction?'badge-danger':'badge-done', bt=d.contradiction?'모순탐지':'완료';
    var scElem;
    if(d.scored){
      var sc=d.totalScore, scCls=sc>=70?'m-score-high':sc>=40?'m-score-mid':'m-score-low';
      scElem='<span id="mscore-'+d.id+'" class="m-score-badge '+scCls+'" onclick="event.stopPropagation();openScoreSheet('+d.id+')">'+sc+'점</span>';
    }else{
      scElem='<button id="mscore-'+d.id+'" class="m-score-btn" onclick="event.stopPropagation();openScoreSheet('+d.id+')" title="신뢰도 분석">' +
        '<svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="var(--text-muted)" stroke-width="2" stroke-linecap="round"><line x1="18" y1="20" x2="18" y2="10"/><line x1="12" y1="20" x2="12" y2="4"/><line x1="6" y1="20" x2="6" y2="14"/></svg>' +
        '</button>';
    }
    html+='<div class="drawer-doc-item" id="ddi-'+d.id+'" onclick="toggleDocCheck('+d.id+','+i+')">' +
      '<div class="doc-checkbox" id="chk-'+d.id+'"></div>' +
      '<div class="drawer-doc-icon" style="background:'+bg+'"><svg viewBox="0 0 24 24" fill="none" stroke="'+st+'" stroke-width="1.8" stroke-linecap="round"><path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/><polyline points="14 2 14 8 20 8"/><line x1="16" y1="13" x2="8" y2="13"/><line x1="16" y1="17" x2="8" y2="17"/></svg></div>' +
      '<div class="drawer-doc-info" onclick="event.stopPropagation();openTranscriptPopup('+i+')">' +
        '<div class="drawer-doc-title">'+escHtml(d.name)+' '+escHtml(d.type)+' 진술 조서</div>' +
        '<div class="drawer-doc-meta">'+escHtml(d.createdAt||d.date)+'  ·  '+(d.textLen||0).toLocaleString()+'자</div>' +
        '<div class="drawer-doc-meta" style="margin-top:2px;display:flex;align-items:center;gap:3px;">' +
          '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" style="width:10px;height:10px;flex-shrink:0;"><path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2"/><circle cx="12" cy="7" r="4"/></svg>' +
          escHtml((d.writerRank?d.writerRank+' ':'')+d.writerName) +
      '</div>' +
      '</div>' +
      '<div class="drawer-doc-badge" style="display:flex;flex-direction:column;align-items:flex-end;gap:4px;">' +
        '<span class="badge '+bc+'">'+bt+'</span>' +
        scElem +
      '</div>' +
    '</div>';
  });
  document.getElementById('drawerDocList').innerHTML=html+'</div>';
}

function toggleDocCheck(docId,idx){
  var pos=checkedDocs.indexOf(docId);
  if(pos===-1){checkedDocs.push(docId);document.getElementById('chk-'+docId).classList.add('on');document.getElementById('ddi-'+docId).classList.add('checked');}
  else{checkedDocs.splice(pos,1);document.getElementById('chk-'+docId).classList.remove('on');document.getElementById('ddi-'+docId).classList.remove('checked');}
  var btn=document.getElementById('contraBtn');
  if(btn){var a=checkedDocs.length>=2;btn.classList.toggle('disabled',!a);btn.classList.toggle('contra-active',a);}
}

function renderDrawerActions(c){
  var del=c.isMine?'<button class="action-btn" onclick="confirmDeleteCase(\''+escStr(c.id)+'\')" style="border:none;cursor:pointer;"><svg viewBox="0 0 24 24" fill="none" stroke="var(--danger)" stroke-width="1.8" stroke-linecap="round"><polyline points="3 6 5 6 21 6"/><path d="M19 6l-1 14H6L5 6"/><path d="M10 11v6"/><path d="M14 11v6"/><path d="M9 6V4h6v2"/></svg><span style="color:var(--danger)">삭제</span></button>':'';
  document.getElementById('drawerActions').innerHTML=
    '<a href="writeTranscript?caseId='+encodeURIComponent(c.id)+'" class="action-btn primary"><svg viewBox="0 0 24 24" fill="none" stroke="#fff" stroke-width="1.8" stroke-linecap="round"><path d="M12 1a3 3 0 0 0-3 3v8a3 3 0 0 0 6 0V4a3 3 0 0 0-3-3z"/><path d="M19 10v2a7 7 0 0 1-14 0v-2"/><line x1="12" y1="19" x2="12" y2="23"/><line x1="8" y1="23" x2="16" y2="23"/></svg><span>조서 추가</span></a>' +
    '<button class="action-btn" onclick="openEditDrawer(\''+escStr(c.id)+'\',\''+escStr(c.status)+'\')" style="border:1px solid var(--border);cursor:pointer;"><svg viewBox="0 0 24 24" fill="none" stroke="var(--navy)" stroke-width="1.8" stroke-linecap="round"><path d="M11 4H4a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-7"/><path d="M18.5 2.5a2.121 2.121 0 0 1 3 3L12 15l-4 1 1-4 9.5-9.5z"/></svg><span>상태 수정</span></button>' +
    '<a href="javascript:void(0)" onclick="goRelationMap()" class="action-btn"><svg viewBox="0 0 24 24" fill="none" stroke="var(--navy)" stroke-width="1.8" stroke-linecap="round"><circle cx="6" cy="12" r="2.5"/><circle cx="18" cy="5" r="2.5"/><circle cx="18" cy="19" r="2.5"/><line x1="8.4" y1="11.0" x2="15.6" y2="6.5"/><line x1="8.4" y1="13.0" x2="15.6" y2="17.5"/></svg><span>관계망</span></a>' +
    '<button type="button" class="action-btn disabled" id="contraBtn" onclick="runContradiction()" style="border:1px solid var(--border);"><svg viewBox="0 0 24 24" fill="none" stroke="var(--text-muted)" stroke-width="1.8" stroke-linecap="round"><circle cx="12" cy="12" r="10"/><line x1="12" y1="8" x2="12" y2="12"/><line x1="12" y1="16" x2="12.01" y2="16"/></svg><span>모순탐지</span></button>' +
    del +
    '<button class="action-btn" onclick="closeDrawer(\'caseDrawer\')" style="border:none;cursor:pointer;"><svg viewBox="0 0 24 24" fill="none" stroke="var(--text-muted)" stroke-width="1.8" stroke-linecap="round"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg><span>닫기</span></button>';
}

// ── 관계망으로 이동 (현재 사건 + 선택된 조서 전달) ──────────────
function goRelationMap() {
  var url = 'caseRelationMap?caseId=' + encodeURIComponent(currentCaseId);
  if (checkedDocs.length > 0) {
    url += '&docIds=' + checkedDocs.join(',');
  }
  location.href = url;
}

function openTranscriptPopup(idx){
  var d=currentDocs[idx]; if(!d) return;
  document.getElementById('popupTitle').textContent=d.name+' '+d.type+' 진술 조서 ('+(d.createdAt||d.date)+')';
  if(d.originalText!==undefined){
    document.getElementById('popupBody').innerHTML=d.originalText?'<span>'+escHtml(d.originalText)+'</span>':'<div class="popup-empty">저장된 진술 내용이 없습니다.</div>';
    renderTranscriptSummary(d.summaryText||'');
  } else {
    document.getElementById('popupBody').innerHTML='<div class="popup-empty">불러오는 중...</div>';
    // 요약은 DB 업데이트 완료 시점부터만 보이도록 숨김
    var sumWrapLoading=document.getElementById('popupSummary');
    if(sumWrapLoading) sumWrapLoading.style.display='none';
    fetch('../caseApi?action=transcriptText&transcriptId='+d.id).then(function(r){return r.json();}).then(function(res){
      d.originalText=res.text||'';
      d.summaryText=res.summary||'';
      document.getElementById('popupBody').innerHTML=d.originalText?'<span>'+escHtml(d.originalText)+'</span>':'<div class="popup-empty">저장된 진술 내용이 없습니다.</div>';
      renderTranscriptSummary(d.summaryText||'');
    }).catch(function(){
      document.getElementById('popupBody').innerHTML='<div class="popup-empty">불러올 수 없습니다.</div>';
      var sumWrapErr=document.getElementById('popupSummary');
      if(sumWrapErr) sumWrapErr.style.display='none';
    });
  }
  document.getElementById('transcriptPopup').classList.add('open');
}
function closeTranscriptPopup(e){if(!e||e.target===document.getElementById('transcriptPopup')||!e.target)document.getElementById('transcriptPopup').classList.remove('open');}

function renderTranscriptSummary(summary){
  var wrap=document.getElementById('popupSummary');
  var box=document.getElementById('popupSummaryText');
  if(!box) return;
  var s=summary||'';
  if(s.trim()){
    if(wrap) wrap.style.display='';
    box.textContent=s;
  } else {
    if(wrap) wrap.style.display='none';
    box.textContent='';
  }
}

var POL_MATE_SERV_BASE='<%= safePolMateServBaseUrl %>';
var ANALYZE_STREAM_URL=POL_MATE_SERV_BASE+'/analyze/stream';
var contraTypeSession=0;
var contraStreamAbort=null;
var contraHasContradictionFromServer=null;
function removeContraCaret(caret){if(caret&&caret.parentNode)caret.parentNode.removeChild(caret);}
function consumeAnalyzeStream(response,session){
  return new Promise(function(resolve,reject){
    if(!response.body||!response.body.getReader){
      reject(new Error('스트림을 읽을 수 없습니다.'));
      return;
    }
    var bodyEl=document.getElementById('contraPopupBody');
    var textSpan=null;
    var caret=null;
    var outputStarted=false;
    var accPlain='';
    function ensureOutputPanel(){
      if(outputStarted)return;
      outputStarted=true;
      bodyEl.innerHTML='<div class="contra-bubble-wrap"><div class="contra-bubble"><span class="contra-type-text"></span><span class="contra-bubble-caret" aria-hidden="true"></span></div></div>';
      textSpan=bodyEl.querySelector('.contra-type-text');
      caret=bodyEl.querySelector('.contra-bubble-caret');
    }
    var reader=response.body.getReader();
    var dec=new TextDecoder();
    var buf='';
    var finished=false;
    function parseFrames(chunk){
      var parts=chunk.split('\n\n');
      for(var pi=0;pi<parts.length;pi++){
        var frame=parts[pi].trim();
        if(frame.indexOf('data:')!==0)continue;
        var jsonStr=frame.slice(5).trim();
        var ev;
        try{ev=JSON.parse(jsonStr);}catch(e){continue;}
        if(ev.event==='chunk'&&ev.text){
          ensureOutputPanel();
          accPlain+=normalizeStatementLabels(ev.text);
          textSpan.innerHTML=formatContradictionAnalyzeHtml(accPlain);
        }else if(ev.event==='error'){
          finished=true;
          removeContraCaret(caret);
          reject(new Error(ev.message||'분석 오류'));
          return;
        }else if(ev.event==='done'){
          if(typeof ev.has_contradiction==='boolean'){
            contraHasContradictionFromServer=ev.has_contradiction;
          }else if(typeof ev.contradiction_count==='number'){
            contraHasContradictionFromServer=ev.contradiction_count>0;
          }
          finished=true;
          removeContraCaret(caret);
          resolve();
          return;
        }
      }
    }
    function pump(){
      reader.read().then(function(result){
        if(session!==contraTypeSession){
          reader.cancel().catch(function(){});
          return;
        }
        if(result.done){
          if(result.value&&result.value.byteLength)
            buf+=dec.decode(result.value,{stream:false});
          if(buf.trim())parseFrames(buf);
          if(!finished){
            if(!outputStarted)ensureOutputPanel();
            removeContraCaret(caret);
            resolve();
          }
          return;
        }
        buf+=dec.decode(result.value,{stream:true});
        var parts=buf.split('\n\n');
        buf=parts.pop()||'';
        for(var i=0;i<parts.length;i++){
          if(session!==contraTypeSession){reader.cancel().catch(function(){});return;}
          parseFrames(parts[i]);
          if(finished){
            reader.cancel().catch(function(){});
            return;
          }
        }
        if(finished)return;
        pump();
      }).catch(function(err){
        removeContraCaret(caret);
        if(err.name==='AbortError'){resolve();return;}
        reject(err);
      });
    }
    pump();
  });
}
function runContradiction(){
  if(checkedDocs.length<2) return;
  contraTypeSession++;
  contraHasContradictionFromServer=null;
  contraSavePosting=false;
  // 저장 푸터 초기화 (자동 저장 실패 시에만 표시)
  document.getElementById('contraSaveFooter').style.display='none';
  var hint=document.getElementById('contraSaveHint');
  if(hint)hint.style.display='none';
  var contraSaveBtn=document.getElementById('contraSaveBtn');
  if(contraSaveBtn){
    contraSaveBtn.disabled=false;
    contraSaveBtn.innerHTML='<svg viewBox="0 0 24 24" fill="none" stroke="#fff" stroke-width="2" stroke-linecap="round" style="width:15px;height:15px;"><path d="M19 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h11l5 5v11a2 2 0 0 1-2 2z"/><polyline points="17 21 17 13 7 13 7 21"/><polyline points="7 3 7 8 15 8"/></svg>다시 저장하기';
  }
  var caseId=currentCaseData.id||'';
  var titles=checkedDocs.map(function(id){var d=currentDocs.find(function(x){return x.id===id;});return d?d.name+' '+d.type+' 진술':'ID:'+id;});
  document.getElementById('contraPopupTitle').textContent='모순 분석 중...';
  document.getElementById('contraPopupBody').innerHTML='<div class="contra-loading"><div class="contra-buffer-spinner"></div><div style="font-size:13px;font-weight:600;color:var(--navy);margin-bottom:8px;">조서를 불러오는 중</div><div style="font-size:12px;">선택한 '+checkedDocs.length+'개 조서를 준비합니다.</div><div style="margin-top:8px;font-size:11px;color:var(--text-muted);">'+titles.join(', ')+'</div></div>';
  document.getElementById('contraPopup').classList.add('open');
  var fp=checkedDocs.map(function(id){var d=currentDocs.find(function(x){return x.id===id;});if(d&&d.originalText!==undefined)return Promise.resolve(d);return fetch('../caseApi?action=transcriptText&transcriptId='+id).then(function(r){return r.json();}).then(function(res){if(d)d.originalText=res.text||'';return d;});});
  Promise.all(fp).then(function(docs){
    var ordered=checkedDocs.map(function(id){return docs.find(function(x){return x&&x.id===id;});}).filter(Boolean);
    if(ordered.length<2) throw new Error('조서를 불러오지 못했습니다.');
    var stmts=ordered.map(function(d){
      return{transcript_id:d.id,stmt_type:d.type||'진술',stmt_name:d.name||'미입력',original_text:String(d.originalText||'').trim()};
    });
    var missing=stmts.some(function(s){return !s.original_text;});
    if(missing) throw new Error('본문이 없는 조서가 있습니다. 텍스트를 저장한 뒤 다시 시도하세요.');
    document.getElementById('contraPopupBody').innerHTML='<div class="contra-analyze-loading"><div class="contra-buffer-spinner"></div><div class="contra-analyze-loading-title">조서 분석 중</div><div class="contra-analyze-loading-sub">결과가 표시될때까지 기다려주세요.</div></div>';
    if(contraStreamAbort)contraStreamAbort.abort();
    contraStreamAbort=new AbortController();
    return fetch(ANALYZE_STREAM_URL,{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({caseNum:caseId,statements:stmts}),signal:contraStreamAbort.signal});
  })
  .then(function(r){
    if(!r.ok) throw new Error('HTTP '+r.status);
    document.getElementById('contraPopupTitle').textContent='모순 분석 결과';
    var sess=contraTypeSession;
    return consumeAnalyzeStream(r,sess).then(function(){ return sess; });
  })
  .then(function(sess){
    if(sess!==contraTypeSession) return;
    requestAnimationFrame(function(){
      requestAnimationFrame(function(){
        if(sess!==contraTypeSession) return;
        attemptAutoPersistContra(sess);
      });
    });
  })
  .catch(function(err){
    if(err.name==='AbortError')return;
    document.getElementById('contraPopupTitle').textContent='분석 실패';
    document.getElementById('contraPopupBody').innerHTML='<div class="popup-empty">'+(err&&err.message?escHtml(err.message):'연결 실패')+'<br><br>서버(<code>'+escHtml(POL_MATE_SERV_BASE)+'</code>) <code>/analyze/stream</code>·CORS를 확인해 주세요.</div>';
  });
}
function closeContraPopup(e){
  if(!e||e.target===document.getElementById('contraPopup')||!e.target){
    if(contraStreamAbort)contraStreamAbort.abort();
    contraTypeSession++;
    contraHasContradictionFromServer=null;
    document.getElementById('contraPopup').classList.remove('open');
    document.getElementById('contraSaveFooter').style.display='none';
    var h=document.getElementById('contraSaveHint');
    if(h)h.style.display='none';
  }
}

var contraSavePosting=false;

/** 분석 출력의 statement_x 표기를 조서N(1-base)으로 통일 */
function normalizeStatementLabels(s){
  return String(s||'').replace(/statement_([a-z]+)/gi, function(_, letters){
    var n = 0;
    var t = String(letters || '').toLowerCase();
    for (var i = 0; i < t.length; i++) {
      var c = t.charCodeAt(i);
      if (c < 97 || c > 122) return 'statement_' + letters;
      n = n * 26 + (c - 96);
    }
    return '조서' + n;
  });
}

/** polmate_serv _pass1_prompt 소제목(시간순 정리된 사건 흐름 / 진술자의 알리바이 요약 / 모순점 분석) 표시 — contradictionList.jsp와 동일 색 */
function stripAnalyzeSectionNumberPrefix(trimmed){
  return String(trimmed||'').replace(/^\d+[\).]\s*/, '');
}
function formatContradictionAnalyzeHtml(plain){
  var raw=String(plain||'');
  if(!raw)return '';
  var lines=raw.split(/\r?\n/);
  var parts=[];
  for(var i=0;i<lines.length;i++){
    var line=lines[i];
    var tr=line.trim();
    var core=stripAnalyzeSectionNumberPrefix(tr);
    var isTitle=(core==='시간순 정리된 사건 흐름'||core==='진술자의 알리바이 요약'||core==='모순점 분석'||core==='추가 확인 사항');
    if(isTitle)
      parts.push('<span class="contra-analyze-section-title">'+escHtml(line)+'</span>');
    else
      parts.push(escHtml(line));
  }
  return parts.join('<br>');
}

/** contradictionList.jsp·writeTranscript.jsp와 동일 기준 (저장 시 플래그 정확도) */
function inferHasContradictionFromAiText(ai){
  var s=String(ai||'');
  if(!s.trim())return false;
  var strong=[
    '【모순','모순점','모순 항목','모순이 발생','모순이 있습니다','모순입니다',
    '모순 발견','모순이 탐지','모순이 확인','모순이 존재','진술 불일치',
    '진술 간에','진술 간 모순','진술에 모순','상충','엇갈린','앞뒤가 맞지',
    '일치하지 않','일치가 없','주장이 다름','서로 다른','행동 불일치','알리바이 불일치',
    '불일치가 발견','불일치를 발견','불일치합니다','조서1','조서2','조서 1','조서 2',
    '거짓 진술','허위 진술','시간대가 맞지','알리바이가 맞지','위반이 확인'
  ];
  if(strong.some(function(p){ return s.indexOf(p)>=0; }))return true;
  if(s.indexOf('모순')<0)return false;
  var neg=[
    '모순이 없','모순은 없','모순 없','모순이 발견되지','모순이 탐지되지',
    '모순이 없습니다','특별한 모순이 없','명확한 모순이 탐지되지','명확한 모순이 발견되지'
  ];
  if(neg.some(function(p){ return s.indexOf(p)>=0; }))return false;
  return true;
}

function buildContraSavePayload(){
  var bodyEl=document.getElementById('contraPopupBody');
  var textSpan=bodyEl.querySelector('.contra-type-text');
  // 저장 시 줄바꿈 보존: textContent는 <br>를 붙여버려 상세창에서 한 줄로 보일 수 있음
  var aiResult=textSpan?(textSpan.innerText||textSpan.textContent):(bodyEl?(bodyEl.innerText||bodyEl.textContent):'');
  aiResult=normalizeStatementLabels(aiResult);
  var stmtNames=checkedDocs.map(function(id){
    var d=currentDocs.find(function(x){return x.id===id;});
    return d?(d.name||'미입력'):'';
  }).filter(Boolean).join(', ');
  var stmtTypes=checkedDocs.map(function(id){
    var d=currentDocs.find(function(x){return x.id===id;});
    return d?(d.type||''):'';
  }).filter(Boolean).join(', ');
  // 저장 상태 불일치 방지:
  // 서버 플래그가 false로 오더라도, 본문에 모순 서술이 있으면 true로 보수 판단
  var inferred = inferHasContradictionFromAiText(aiResult);
  var hasContradiction = (typeof contraHasContradictionFromServer==='boolean')
    ? (contraHasContradictionFromServer || inferred)
    : inferred;
  var caseId=currentCaseData?currentCaseData.id||'':'';
  return { aiResult:aiResult, stmtNames:stmtNames, stmtTypes:stmtTypes, hasContradiction:hasContradiction, caseId:caseId };
}

function postContraSaveFromMyCase(fields, opts){
  var opt=opts||{};
  if(contraSavePosting)return;
  contraSavePosting=true;
  var btn=opt.btn||null;
  var redirect=!!opt.redirect;
  var streamSession=opt.streamSession;
  if(btn){
    btn.disabled=true;
    btn.innerHTML='<svg viewBox="0 0 24 24" fill="none" stroke="#fff" stroke-width="2" stroke-linecap="round" style="width:15px;height:15px;animation:contraSpin 0.7s linear infinite"><path d="M21 12a9 9 0 1 1-6.22-8.56"/></svg>&nbsp;저장 중...';
  }
  var params=new URLSearchParams();
  params.append('action','save');
  params.append('caseId',fields.caseId);
  params.append('stmtName',fields.stmtNames);
  params.append('stmtType',fields.stmtTypes);
  params.append('hasContradiction',fields.hasContradiction?'true':'false');
  params.append('aiResult',fields.aiResult);
  params.append('stmtText','');
  fetch('../contradictionApi',{
    method:'POST',
    headers:{'Content-Type':'application/x-www-form-urlencoded;charset=UTF-8'},
    body:params.toString()
  })
    .then(function(r){ return r.text().then(function(t){
      try{ return JSON.parse(t);}catch(e){
        throw new Error(t.indexOf('<html')>=0||t.indexOf('<!DOCTYPE')>=0?'로그인이 만료되었거나 서버 오류입니다. 다시 로그인 후 시도하세요.':(t.substring(0,120)||'응답 해석 실패'));
      }
    });})
    .then(function(data){
      contraSavePosting=false;
      if(streamSession!=null&&streamSession!==contraTypeSession)return;
      if(data.success){
        localStorage.setItem('contradictionUpdated',Date.now().toString());
        if(redirect)location.href='contradictionList';
        else showToast('모순탐지 목록에 저장되었습니다.');
        document.getElementById('contraSaveFooter').style.display='none';
        var hint=document.getElementById('contraSaveHint');
        if(hint)hint.style.display='none';
      }else{
        alert(data.error||'저장에 실패했습니다.');
        document.getElementById('contraSaveFooter').style.display='block';
        var hint2=document.getElementById('contraSaveHint');
        if(hint2)hint2.style.display='block';
        if(btn){
          btn.disabled=false;
          btn.innerHTML='<svg viewBox="0 0 24 24" fill="none" stroke="#fff" stroke-width="2" stroke-linecap="round" style="width:15px;height:15px;"><path d="M19 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h11l5 5v11a2 2 0 0 1-2 2z"/><polyline points="17 21 17 13 7 13 7 21"/><polyline points="7 3 7 8 15 8"/></svg>다시 저장하기';
        }
      }
    })
    .catch(function(err){
      contraSavePosting=false;
      if(streamSession!=null&&streamSession!==contraTypeSession)return;
      alert(err&&err.message?err.message:'서버 연결 오류가 발생했습니다.');
      document.getElementById('contraSaveFooter').style.display='block';
      var hint3=document.getElementById('contraSaveHint');
      if(hint3)hint3.style.display='block';
      if(btn){
        btn.disabled=false;
        btn.innerHTML='<svg viewBox="0 0 24 24" fill="none" stroke="#fff" stroke-width="2" stroke-linecap="round" style="width:15px;height:15px;"><path d="M19 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h11l5 5v11a2 2 0 0 1-2 2z"/><polyline points="17 21 17 13 7 13 7 21"/><polyline points="7 3 7 8 15 8"/></svg>다시 저장하기';
      }
    });
}

function attemptAutoPersistContra(streamSession){
  if(streamSession!==contraTypeSession)return;
  var fields=buildContraSavePayload();
  postContraSaveFromMyCase(fields,{ redirect:false, streamSession:streamSession, btn:null });
}

// ── 모순탐지 결과 수동 재저장 ─────────────────────────────────────
function saveContraResult(){
  var btn=document.getElementById('contraSaveBtn');
  postContraSaveFromMyCase(buildContraSavePayload(),{ redirect:true, btn:btn, streamSession:null });
}

function openNewCaseDrawer(){
  document.getElementById('newCaseId').value=''; document.getElementById('newCaseName').value='';
  document.getElementById('newSuspect').value='';
  document.getElementById('newCaseDeptLabel').textContent='불러오는 중...';
  document.getElementById('newCaseDeptLabel').style.color='var(--text-muted)';
  document.getElementById('newCaseDrawer').classList.add('open');
  document.body.style.overflow='hidden';
  setTimeout(function(){document.getElementById('newCaseId').focus();},300);
  fetch('../caseApi?action=myDept').then(function(r){return r.json();}).then(function(d){
    if(d.error){document.getElementById('newCaseDeptLabel').textContent='조회 실패';return;}
    document.getElementById('newCaseDeptLabel').textContent=d.label;
    document.getElementById('newCaseDeptLabel').style.color=d.deptId?'var(--navy)':'var(--text-muted)';
  }).catch(function(){document.getElementById('newCaseDeptLabel').textContent='조회 실패';});
}

function submitNewCase(){
  var ci=document.getElementById('newCaseId').value.trim(), cn=document.getElementById('newCaseName').value.trim();
  var ss=document.getElementById('newSuspect').value.trim();
  if(!ci){showToast('사건번호를 입력하세요.');return;} if(!cn){showToast('사건명을 입력하세요.');return;}
  var p=new URLSearchParams();p.append('action','caseCreate');p.append('caseId',ci);p.append('caseName',cn);p.append('suspect',ss);
  fetch('../caseApi',{method:'POST',headers:{'Content-Type':'application/x-www-form-urlencoded'},body:p.toString()}).then(function(r){return r.json();}).then(function(d){
    if(d.success){closeDrawer('newCaseDrawer');showToast('✓ 사건이 등록됐습니다'+(d.deptLabel?' · '+d.deptLabel:''));loadCaseList();}
    else showToast(d.message||'등록 실패');
  }).catch(function(){showToast('등록 중 오류 발생');});
}

function openEditDrawer(caseId,status){
  editCaseId=caseId;selectedStatus=status;
  document.getElementById('editDrawerSub').textContent=caseId;
  document.querySelectorAll('.status-btn').forEach(function(b){b.classList.toggle('selected',b.getAttribute('data-val')===status);});
  closeDrawer('caseDrawer');document.getElementById('editDrawer').classList.add('open');document.body.style.overflow='hidden';
}
function selectStatus(btn){document.querySelectorAll('.status-btn').forEach(function(b){b.classList.remove('selected');});btn.classList.add('selected');selectedStatus=btn.getAttribute('data-val');}
function submitEditCase(){
  if(!editCaseId) return;
  var p=new URLSearchParams();p.append('action','caseStatus');p.append('caseId',editCaseId);p.append('status',selectedStatus);
  fetch('../caseApi',{method:'POST',headers:{'Content-Type':'application/x-www-form-urlencoded'},body:p.toString()}).then(function(r){return r.json();}).then(function(d){
    if(d.success){closeDrawer('editDrawer');showToast('✓ 수정됐습니다');loadCaseList();}else showToast(d.message||'수정 실패');
  }).catch(function(){showToast('수정 중 오류 발생');});
}

function confirmDeleteCase(caseId){
  if(!confirm('사건 ['+caseId+']을 삭제할까요?\n관련 조서·관계망 데이터도 모두 삭제됩니다.')) return;
  var p=new URLSearchParams();p.append('action','caseDelete');p.append('caseId',caseId);
  fetch('../caseApi',{method:'POST',headers:{'Content-Type':'application/x-www-form-urlencoded'},body:p.toString()}).then(function(r){return r.json();}).then(function(d){
    if(d.success){closeDrawer('caseDrawer');showToast('✓ 사건이 삭제됐습니다');loadCaseList();}else showToast(d.message||'삭제 실패');
  }).catch(function(){showToast('삭제 중 오류 발생');});
}

function closeDrawer(id){document.getElementById(id).classList.remove('open');document.body.style.overflow='';}
function closeOnBg(e,id){if(e.target===document.getElementById(id))closeDrawer(id);}
function escHtml(s){return String(s||'').replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;');}
function escStr(s){return String(s||'').replace(/'/g,"\\'");}
function showToast(msg){var t=document.getElementById('toast');t.textContent=msg;t.style.opacity='1';t.style.transform='translateX(-50%) translateY(0)';setTimeout(function(){t.style.opacity='0';t.style.transform='translateX(-50%) translateY(20px)';},2200);}

/* ── 신뢰도 분석 ────────────────────────────────────────────────── */
function openScoreSheet(transcriptId) {
  mCurrentScoreId = transcriptId;
  var doc = mDocScores[transcriptId];
  var title = doc ? escHtml((doc.name||'미입력')+' '+(doc.type||'')+' 진술조서') : '진술조서';
  document.getElementById('scorePopupTitle').textContent = title;
  var btn = document.getElementById('mBtnAnalyze');
  btn.disabled = false;
  document.getElementById('mHelpPopover').classList.remove('open');
  if (doc && doc.scored) {
    renderMobileScore({
      total: doc.totalScore, consistency: doc.consistency,
      specificity: doc.specificity, emotion: doc.emotion, temporal: doc.temporal,
      reasons: { consistency: doc.cReason, specificity: doc.sReason, emotion: doc.eReason, temporal: doc.tReason }
    });
    btn.textContent = '재분석';
  } else {
    document.getElementById('scorePopupBody').innerHTML =
      '<div class="m-score-empty">아직 분석된 신뢰도 점수가 없습니다.</div>';
    btn.textContent = '신뢰도 분석 실행';
  }
  document.getElementById('scorePopup').classList.add('open');
}

function closeScoreSheet(e) {
  if (!e || e.target === document.getElementById('scorePopup') || !e.target) {
    document.getElementById('scorePopup').classList.remove('open');
    document.getElementById('mHelpPopover').classList.remove('open');
    mCurrentScoreId = null;
  }
}

function renderMobileScore(data) {
  var total = data.total || 0;
  var grade = total >= 70 ? '신뢰도 높음' : total >= 40 ? '검토 필요' : '신뢰도 낮음';
  var numColor = total >= 70 ? '#16a34a' : total >= 40 ? '#d97706' : '#dc2626';
  var bars = [
    { label:'일관성',     val: data.consistency || 0, reason: (data.reasons||{}).consistency || '' },
    { label:'구체성',     val: data.specificity  || 0, reason: (data.reasons||{}).specificity || '' },
    { label:'감정 안정성', val: data.emotion     || 0, reason: (data.reasons||{}).emotion     || '' },
    { label:'시간 정합성', val: data.temporal    || 0, reason: (data.reasons||{}).temporal    || '' }
  ];
  var html = '<div class="m-score-total-card">'
    + '<div class="m-score-total-num" style="color:'+numColor+'">'+total+'</div>'
    + '<div><div class="m-score-total-label">종합 신뢰도</div><div class="m-score-total-grade">'+grade+'</div></div>'
    + '</div><div class="m-score-bars">';
  bars.forEach(function(b) {
    var fc = b.val >= 70 ? 'm-fill-high' : b.val >= 40 ? 'm-fill-mid' : 'm-fill-low';
    var vc = b.val >= 70 ? '#16a34a' : b.val >= 40 ? '#d97706' : '#dc2626';
    html += '<div>'
      + '<div class="m-score-row-header"><span class="m-score-row-label">'+escHtml(b.label)+'</span>'
      + '<span class="m-score-row-val" style="color:'+vc+'">'+b.val+'점</span></div>'
      + '<div class="m-score-bar-track"><div class="m-score-bar-fill '+fc+'" style="width:'+b.val+'%"></div></div>'
      + (b.reason ? '<div class="m-score-row-reason">'+escHtml(b.reason)+'</div>' : '')
      + '</div>';
  });
  html += '</div>';
  document.getElementById('scorePopupBody').innerHTML = html;
}

function runMobileScoreAnalysis() {
  if (!mCurrentScoreId) return;
  var btn = document.getElementById('mBtnAnalyze');
  btn.disabled = true;
  btn.textContent = '분석 중...';
  document.getElementById('scorePopupBody').innerHTML =
    '<div class="m-score-loading">AI가 진술을 분석하는 중입니다...<br><small>약 30~60초 소요됩니다</small></div>';
  var p = new URLSearchParams();
  p.append('action', 'scoreTranscript');
  p.append('transcriptId', mCurrentScoreId);
  fetch('../caseApi', { method:'POST', headers:{'Content-Type':'application/x-www-form-urlencoded'}, body:p.toString() })
    .then(function(r){ return r.json(); })
    .then(function(d) {
      btn.disabled = false;
      if (d.success) {
        var doc = mDocScores[mCurrentScoreId];
        if (doc) {
          doc.scored = true; doc.totalScore = d.total;
          doc.consistency = d.consistency; doc.specificity = d.specificity;
          doc.emotion = d.emotion;         doc.temporal   = d.temporal;
          doc.cReason = (d.reasons||{}).consistency || '';
          doc.sReason = (d.reasons||{}).specificity || '';
          doc.eReason = (d.reasons||{}).emotion     || '';
          doc.tReason = (d.reasons||{}).temporal    || '';
        }
        renderMobileScore(d);
        updateMobileScoreBadge(mCurrentScoreId, d.total);
        btn.textContent = '재분석';
        showToast('신뢰도 분석 완료');
      } else {
        document.getElementById('scorePopupBody').innerHTML =
          '<div class="m-score-empty">'+escHtml(d.message||'분석에 실패했습니다.')+'</div>';
        btn.textContent = '다시 시도';
      }
    })
    .catch(function() {
      btn.disabled = false;
      btn.textContent = '다시 시도';
      document.getElementById('scorePopupBody').innerHTML =
        '<div class="m-score-empty">오류가 발생했습니다.</div>';
    });
}

function updateMobileScoreBadge(transcriptId, score) {
  var badge = document.getElementById('mscore-' + transcriptId);
  if (!badge) return;
  var cls = score >= 70 ? 'm-score-high' : score >= 40 ? 'm-score-mid' : 'm-score-low';
  badge.className = 'm-score-badge ' + cls;
  badge.textContent = score + '점';
}

function toggleMobileHelp(e) {
  e.stopPropagation();
  document.getElementById('mHelpPopover').classList.toggle('open');
}
document.addEventListener('click', function(e) {
  var pop = document.getElementById('mHelpPopover');
  if (pop && pop.classList.contains('open') && !pop.contains(e.target)) {
    pop.classList.remove('open');
  }
});

loadCaseList();

// 알림에서 caseId 파라미터로 직접 진입 시 해당 사건 드로어 자동 오픈
(function() {
  var targetId = '<%= safeParamCaseIdJs %>';
  if (!targetId) return;
  // 카드 렌더링 완료 후 해당 사건 드로어 오픈
  var maxTry = 20, tried = 0;
  var timer = setInterval(function() {
    tried++;
    var cards = document.querySelectorAll('.case-card');
    if (cards.length > 0) {
      clearInterval(timer);
      openCase(targetId);
    } else if (tried >= maxTry) {
      clearInterval(timer);
    }
  }, 150);
})();
</script>
</body>
</html>