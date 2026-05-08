<%@ page language="java" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8"%>
<!DOCTYPE html>
<html lang="ko">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
<title>POL-MATE | 전체 사건</title>
<link href="https://fonts.googleapis.com/css2?family=Noto+Sans+KR:wght@300;400;500;700&display=swap" rel="stylesheet">
<style>
  * { margin:0; padding:0; box-sizing:border-box; -webkit-tap-highlight-color:transparent; }
  :root{
    --deep:#0d1a33; --navy:#1a2744; --mid:#243358;
    --gold:#f0c040; --gold2:#e6b830;
    --blue:#4a7cdc; --accent:#4a7cdc; --danger:#dc2626;
    --tp:#1a1a2e; --ts:#6b7280; --tm:#9ca3af;
    --bg:#f0f2f8; --card:#ffffff; --bd:#e2e5ee;
    --success:#16a34a; --success-bg:#f0fdf4; --success-bd:#bbf7d0;
    --warn-bg:#fffbeb; --warn-text:#92400e;
    --danger-bg:#fef2f2; --danger-bd:#fecaca;
    --info-bg:#eff6ff; --info-text:#1e40af;
  }
  html,body { height:100%; font-family:'Noto Sans KR',sans-serif; background:var(--bg); overflow-x:hidden; }
  .screen { width:100%; max-width:420px; min-height:100vh; margin:0 auto; background:var(--bg); display:flex; flex-direction:column; }

  /* 헤더 */
  .top-header { background:var(--deep); padding:52px 20px 0; position:sticky; top:0; z-index:10; }
  .header-row { display:flex; align-items:center; gap:12px; padding-bottom:14px; }
  .back-btn { width:36px; height:36px; border-radius:50%; background:rgba(255,255,255,0.12); border:none; display:flex; align-items:center; justify-content:center; cursor:pointer; flex-shrink:0; }
  .back-btn svg { width:18px; height:18px; stroke:#fff; }
  .header-title { font-size:17px; font-weight:500; color:#fff; flex:1; }
  .btn-new { background:rgba(255,255,255,0.15); border:1px solid rgba(255,255,255,0.25); color:#fff; border-radius:20px; padding:7px 14px; font-size:12px; font-family:'Noto Sans KR',sans-serif; cursor:pointer; display:flex; align-items:center; gap:5px; }
  .btn-new svg { width:13px; height:13px; stroke:#fff; }

  /* 검색 + 필터 */
  .search-wrap { background:var(--deep); padding:0 16px 14px; }
  .search-box { background:rgba(255,255,255,0.1); border:1px solid rgba(255,255,255,0.2); border-radius:12px; display:flex; align-items:center; gap:10px; padding:10px 14px; margin-bottom:10px; }
  .search-box svg { width:16px; height:16px; stroke:rgba(255,255,255,0.5); flex-shrink:0; }
  .search-input { flex:1; background:none; border:none; outline:none; font-size:13px; color:#fff; font-family:'Noto Sans KR',sans-serif; }
  .search-input::placeholder { color:rgba(255,255,255,0.4); }

  .filter-row { display:flex; gap:6px; overflow-x:auto; -ms-overflow-style:none; scrollbar-width:none; }
  .filter-row::-webkit-scrollbar { display:none; }
  .chip { flex-shrink:0; padding:5px 13px; border-radius:20px; font-size:11px; border:1px solid rgba(255,255,255,0.2); color:rgba(255,255,255,0.6); background:none; cursor:pointer; white-space:nowrap; font-family:'Noto Sans KR',sans-serif; transition:all 0.15s; }
  .chip.active { background:rgba(255,255,255,0.2); color:#fff; border-color:rgba(255,255,255,0.4); }

  /* 정렬 바 */
  .sort-bar { display:flex; align-items:center; justify-content:space-between; padding:12px 16px 8px; }
  .result-count { font-size:11px; color:var(--tm); }
  .sort-select { background:none; border:none; font-size:11px; color:var(--ts); font-family:'Noto Sans KR',sans-serif; cursor:pointer; outline:none; }

  /* 콘텐츠 */
  .content { flex:1; overflow-y:auto; padding-bottom:calc(var(--bnav) + 16px); }

  /* 사건 카드 */
  .case-list { padding:0 16px; display:flex; flex-direction:column; gap:10px; }
  .case-card { background:var(--card); border-radius:16px; border:1px solid var(--bd); padding:16px; cursor:pointer; transition:border-color 0.2s; animation:fadeUp 0.3s ease both; }
  .case-card:active { background:var(--bg); }
  .case-card.urgent { border-left:3px solid var(--danger); }
  .case-top { display:flex; justify-content:space-between; align-items:flex-start; margin-bottom:10px; }
  .case-num  { font-size:11px; color:var(--tm); margin-bottom:3px; }
  .case-name { font-size:15px; font-weight:500; color:var(--tp); }
  .badge { font-size:10px; font-weight:500; padding:4px 10px; border-radius:20px; white-space:nowrap; flex-shrink:0; }
  .badge-warn   { background:var(--warn-bg);    color:var(--warn-text); }
  .badge-ok     { background:var(--success-bg); color:var(--success); }
  .badge-done   { background:#f3f4f6;            color:var(--tm); }
  .badge-danger { background:var(--danger-bg);  color:var(--danger); }
  .badge-info   { background:var(--info-bg);    color:var(--info-text); }
  .case-meta { display:flex; flex-wrap:wrap; gap:10px; margin-bottom:10px; }
  .meta-item { display:flex; align-items:center; gap:5px; font-size:11px; color:var(--tm); }
  .meta-item svg { width:12px; height:12px; stroke:var(--tm); }
  .case-progress-wrap { display:flex; align-items:center; gap:10px; }
  .case-progress-bar  { flex:1; height:4px; background:var(--bd); border-radius:2px; overflow:hidden; }
  .case-progress-fill { height:100%; border-radius:2px; }
  .fill-green { background:var(--success); }
  .fill-blue  { background:var(--accent); }
  .fill-amber { background:#f59e0b; }
  .fill-red   { background:var(--danger); }
  .case-progress-pct { font-size:10px; color:var(--tm); white-space:nowrap; }

  /* 빈 상태 */
  .empty-state { padding:60px 20px; text-align:center; }
  .empty-icon  { width:64px; height:64px; background:var(--bg); border-radius:50%; margin:0 auto 14px; display:flex; align-items:center; justify-content:center; border:1px solid var(--bd); }
  .empty-icon svg { width:28px; height:28px; stroke:var(--tm); }
  .empty-title { font-size:14px; font-weight:500; color:var(--ts); margin-bottom:6px; }
  .empty-desc  { font-size:12px; color:var(--tm); }

  /* 드로어 */
  .overlay { position:fixed; inset:0; background:rgba(0,0,0,0.45); z-index:200; display:none; align-items:flex-end; justify-content:center; }
  .overlay.open { display:flex; }
  .drawer { background:var(--card); border-radius:20px 20px 0 0; width:100%; max-width:420px; padding:0 0 36px; animation:slideUp 0.28s ease both; max-height:88vh; overflow-y:auto; }
  .drawer-handle { width:36px; height:4px; background:var(--bd); border-radius:2px; margin:12px auto 0; }
  .drawer-head { padding:16px 20px; border-bottom:1px solid var(--bd); }
  .drawer-title { font-size:16px; font-weight:500; color:var(--tp); }
  .drawer-sub   { font-size:12px; color:var(--tm); margin-top:3px; }
  .drawer-body  { padding:16px 20px; }
  .detail-row { display:flex; justify-content:space-between; align-items:center; padding:10px 0; border-bottom:1px solid var(--bd); }
  .detail-row:last-child { border-bottom:none; }
  .detail-key { font-size:12px; color:var(--tm); }
  .detail-val { font-size:12px; font-weight:500; color:var(--tp); text-align:right; }
  .action-grid { display:grid; grid-template-columns:1fr 1fr; gap:10px; margin-top:16px; }
  .action-btn { background:var(--bg); border:1px solid var(--bd); border-radius:12px; padding:14px 10px; text-align:center; cursor:pointer; text-decoration:none; display:block; transition:background 0.15s; }
  .action-btn:active { background:var(--bd); }
  .action-btn svg { width:20px; height:20px; display:block; margin:0 auto 6px; }
  .action-btn span { font-size:11px; color:var(--ts); }
  .action-btn.primary { background:var(--navy); border-color:var(--navy); }
  .action-btn.primary svg { stroke:#fff; }
  .action-btn.primary span { color:#fff; }

  /* 하단 네비 */
  .bottom-nav { position:fixed; bottom:0; left:50%; transform:translateX(-50%); width:100%; max-width:420px; height:var(--bnav); background:var(--card); border-top:1px solid var(--bd); display:flex; justify-content:space-around; align-items:center; padding:0 8px; z-index:100; }
  .nav-item { display:flex; flex-direction:column; align-items:center; gap:3px; flex:1; cursor:pointer; text-decoration:none; padding:6px 0; }
  .nav-icon { width:24px; height:24px; display:flex; align-items:center; justify-content:center; }
  .nav-icon svg { width:22px; height:22px; }
  .nav-label { font-size:9px; }
  .nav-item.active .nav-icon svg { stroke:var(--deep); }
  .nav-item.active .nav-label    { color:var(--deep); font-weight:600; }
  .nav-item:not(.active) .nav-icon svg { stroke:var(--tm); }
  .nav-item:not(.active) .nav-label    { color:var(--tm); }

  @keyframes fadeUp  { from{opacity:0;transform:translateY(10px)} to{opacity:1;transform:translateY(0)} }
  @keyframes slideUp { from{transform:translateY(100%);opacity:0} to{transform:translateY(0);opacity:1} }
  @media(min-width:421px){ .screen{box-shadow:0 0 40px rgba(0,0,0,0.1);} }
</style>
</head>
<body>
<div class="screen">

  <div class="top-header">
    <div class="header-row">
      <button class="back-btn" onclick="history.back()">
        <svg viewBox="0 0 24 24" fill="none" stroke-width="2" stroke-linecap="round"><polyline points="15 18 9 12 15 6"/></svg>
      </button>
      <span class="header-title">전체 사건</span>
      <button class="btn-new" onclick="location.href='voiceTranscript'">
        <svg viewBox="0 0 24 24" fill="none" stroke-width="2" stroke-linecap="round"><line x1="12" y1="5" x2="12" y2="19"/><line x1="5" y1="12" x2="19" y2="12"/></svg>
        새 조서
      </button>
    </div>
    <div class="search-wrap">
      <div class="search-box">
        <svg viewBox="0 0 24 24" fill="none" stroke-width="1.8" stroke-linecap="round"><circle cx="11" cy="11" r="8"/><line x1="21" y1="21" x2="16.65" y2="16.65"/></svg>
        <input type="text" class="search-input" id="searchInput" placeholder="사건번호, 사건명, 피의자 검색..." oninput="filterCases()">
      </div>
      <div class="filter-row">
        <button class="chip active" onclick="setFilter(this,'all')">전체</button>
        <button class="chip" onclick="setFilter(this,'검토필요')">검토필요</button>
        <button class="chip" onclick="setFilter(this,'진행중')">진행중</button>
        <button class="chip" onclick="setFilter(this,'완료')">완료</button>
        <button class="chip" onclick="setFilter(this,'모순탐지')">모순탐지</button>
      </div>
    </div>
  </div>

  <div class="content">
    <div class="sort-bar">
      <span class="result-count" id="resultCount">전체 6건</span>
      <select class="sort-select" id="sortSelect" onchange="sortCases()">
        <option value="date">최신순</option>
        <option value="name">사건명순</option>
        <option value="progress">진행률순</option>
      </select>
    </div>
    <div class="case-list" id="caseList"></div>
    <div class="empty-state" id="emptyState" style="display:none;">
      <div class="empty-icon"><svg viewBox="0 0 24 24" fill="none" stroke-width="1.8" stroke-linecap="round"><circle cx="11" cy="11" r="8"/><line x1="21" y1="21" x2="16.65" y2="16.65"/></svg></div>
      <div class="empty-title">검색 결과가 없습니다</div>
      <div class="empty-desc">다른 검색어나 필터를 사용해 보세요</div>
    </div>
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
      <div class="drawer-title" id="drawerTitle"></div>
      <div class="drawer-sub"   id="drawerSub"></div>
    </div>
    <div class="drawer-body">
      <div id="drawerDetails"></div>
      <div class="action-grid" id="drawerActions"></div>
    </div>
  </div>
</div>

<script>
var CASES = [
  { id:'2024-0312', name:'절도사건',  suspect:'홍길동', date:'2025.03.24', status:'검토필요', progress:75,  urgent:true,  docs:3, stage:'조서 분석 완료',    charge:'형법 제329조' },
  { id:'2024-0289', name:'폭행사건',  suspect:'김철수', date:'2025.03.21', status:'진행중',   progress:45,  urgent:false, docs:2, stage:'조서 작성 중',     charge:'형법 제260조' },
  { id:'2024-0271', name:'사기사건',  suspect:'이영희', date:'2025.03.18', status:'완료',     progress:100, urgent:false, docs:4, stage:'절차 점검 완료',   charge:'형법 제347조' },
  { id:'2024-0255', name:'협박사건',  suspect:'박민수', date:'2025.03.12', status:'모순탐지', progress:60,  urgent:true,  docs:2, stage:'모순 항목 검토 필요', charge:'형법 제283조' },
  { id:'2024-0244', name:'강도사건',  suspect:'최수진', date:'2025.03.10', status:'완료',     progress:100, urgent:false, docs:5, stage:'최종 제출 완료',   charge:'형법 제333조' },
  { id:'2024-0230', name:'마약사건',  suspect:'정태양', date:'2025.03.05', status:'진행중',   progress:30,  urgent:false, docs:1, stage:'초기 조사 중',     charge:'마약류관리법' },
  { id:'2024-0218', name:'횡령사건',  suspect:'윤지혜', date:'2025.02.28', status:'완료',     progress:100, urgent:false, docs:6, stage:'최종 제출 완료',   charge:'형법 제355조' },
  { id:'2024-0201', name:'공갈사건',  suspect:'장현우', date:'2025.02.20', status:'진행중',   progress:55,  urgent:false, docs:2, stage:'2차 조사 중',     charge:'형법 제350조' }
];

var currentFilter = 'all';
var currentSort   = 'date';

function setFilter(el, val) {
  document.querySelectorAll('.chip').forEach(function(c) { c.classList.remove('active'); });
  el.classList.add('active');
  currentFilter = val;
  render();
}

function sortCases() {
  currentSort = document.getElementById('sortSelect').value;
  render();
}

function filterCases() { render(); }

function render() {
  var q = document.getElementById('searchInput').value.trim().toLowerCase();
  var list = CASES.filter(function(c) {
    var matchF = currentFilter === 'all' || c.status === currentFilter;
    var matchQ = !q || c.id.toLowerCase().includes(q) || c.name.includes(q) || c.suspect.includes(q);
    return matchF && matchQ;
  });

  if (currentSort === 'name') {
    list.sort(function(a,b) { return a.name.localeCompare(b.name); });
  } else if (currentSort === 'progress') {
    list.sort(function(a,b) { return b.progress - a.progress; });
  }

  document.getElementById('resultCount').textContent = '전체 ' + list.length + '건';
  document.getElementById('emptyState').style.display = list.length ? 'none' : 'block';

  var html = '';
  list.forEach(function(c, i) {
    var bCls = {검토필요:'badge-warn', 진행중:'badge-ok', 완료:'badge-done', 모순탐지:'badge-danger'}[c.status] || 'badge-info';
    var fCls = c.progress===100 ? 'fill-green' : c.progress>=60 ? 'fill-blue' : c.progress>=30 ? 'fill-amber' : 'fill-red';
    html +=
      '<div class="case-card' + (c.urgent?' urgent':'') + '" style="animation-delay:' + (i*0.04) + 's" onclick="openCase(\'' + c.id + '\')">' +
        '<div class="case-top">' +
          '<div><div class="case-num">' + c.id + ' · ' + c.charge + '</div><div class="case-name">' + c.name + '</div></div>' +
          '<span class="badge ' + bCls + '">' + c.status + '</span>' +
        '</div>' +
        '<div class="case-meta">' +
          '<div class="meta-item"><svg viewBox="0 0 24 24" fill="none" stroke-width="1.8" stroke-linecap="round"><path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2"/><circle cx="12" cy="7" r="4"/></svg>' + c.suspect + '</div>' +
          '<div class="meta-item"><svg viewBox="0 0 24 24" fill="none" stroke-width="1.8" stroke-linecap="round"><rect x="3" y="4" width="18" height="18" rx="2"/><line x1="16" y1="2" x2="16" y2="6"/><line x1="8" y1="2" x2="8" y2="6"/><line x1="3" y1="10" x2="21" y2="10"/></svg>' + c.date + '</div>' +
          '<div class="meta-item"><svg viewBox="0 0 24 24" fill="none" stroke-width="1.8" stroke-linecap="round"><path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/><polyline points="14 2 14 8 20 8"/></svg>조서 ' + c.docs + '건</div>' +
        '</div>' +
        '<div class="case-progress-wrap">' +
          '<div class="case-progress-bar"><div class="case-progress-fill ' + fCls + '" style="width:' + c.progress + '%"></div></div>' +
          '<span class="case-progress-pct">' + c.progress + '%</span>' +
        '</div>' +
      '</div>';
  });
  document.getElementById('caseList').innerHTML = html;
}

function openCase(id) {
  var c = CASES.find(function(x){ return x.id===id; });
  if (!c) return;
  var bCls = {검토필요:'badge-warn', 진행중:'badge-ok', 완료:'badge-done', 모순탐지:'badge-danger'}[c.status]||'';
  document.getElementById('drawerTitle').textContent = c.id + ' ' + c.name;
  document.getElementById('drawerSub').textContent   = c.stage;
  document.getElementById('drawerDetails').innerHTML =
    '<div class="detail-row"><span class="detail-key">피의자</span><span class="detail-val">' + c.suspect + '</span></div>' +
    '<div class="detail-row"><span class="detail-key">적용 법조</span><span class="detail-val">' + c.charge + '</span></div>' +
    '<div class="detail-row"><span class="detail-key">최종 수정</span><span class="detail-val">' + c.date + '</span></div>' +
    '<div class="detail-row"><span class="detail-key">진행률</span><span class="detail-val">' + c.progress + '%</span></div>' +
    '<div class="detail-row"><span class="detail-key">조서 수</span><span class="detail-val">' + c.docs + '건</span></div>' +
    '<div class="detail-row"><span class="detail-key">상태</span><span class="detail-val"><span class="badge ' + bCls + '">' + c.status + '</span></span></div>';
  document.getElementById('drawerActions').innerHTML =
    '<a href="writeTranscript?caseId=' + encodeURIComponent(c.id) + '" class="action-btn primary"><svg viewBox="0 0 24 24" fill="none" stroke="#fff" stroke-width="1.8" stroke-linecap="round"><path d="M12 1a3 3 0 0 0-3 3v8a3 3 0 0 0 6 0V4a3 3 0 0 0-3-3z"/><path d="M19 10v2a7 7 0 0 1-14 0v-2"/><line x1="12" y1="19" x2="12" y2="23"/><line x1="8" y1="23" x2="16" y2="23"/></svg><span>조서 추가</span></a>' +
    '<a href="procedureCheck" class="action-btn"><svg viewBox="0 0 24 24" fill="none" stroke="var(--navy)" stroke-width="1.8" stroke-linecap="round"><path d="M9 11l3 3L22 4"/><path d="M21 12v7a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h11"/></svg><span>절차 점검</span></a>' +
    '<a href="voiceTranscript" class="action-btn"><svg viewBox="0 0 24 24" fill="none" stroke="var(--navy)" stroke-width="1.8" stroke-linecap="round"><circle cx="11" cy="11" r="8"/><line x1="21" y1="21" x2="16.65" y2="16.65"/></svg><span>모순 분석</span></a>' +
    '<button class="action-btn" onclick="closeDrawer(\'caseDrawer\')" style="border:none;cursor:pointer;"><svg viewBox="0 0 24 24" fill="none" stroke="var(--tm)" stroke-width="1.8" stroke-linecap="round"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg><span>닫기</span></button>';
  document.getElementById('caseDrawer').classList.add('open');
  document.body.style.overflow = 'hidden';
}

function closeDrawer(id) { document.getElementById(id).classList.remove('open'); document.body.style.overflow=''; }
function closeOnBg(e,id) { if(e.target===document.getElementById(id)) closeDrawer(id); }

render();
</script>
</body>
</html>
