<%@ page language="java" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8"%>
<%
  String paramCaseId   = request.getParameter("caseId")   != null ? request.getParameter("caseId")   : "";
  String paramOpenBoard= request.getParameter("openBoard") != null ? request.getParameter("openBoard") : "";
  String paramDocIds   = request.getParameter("docIds")   != null ? request.getParameter("docIds")   : "";
  String safeCaseIdAttr = paramCaseId.replace("&", "&amp;").replace("\"", "&quot;").replace("'", "&#39;").replace("<", "&lt;");
  String safeOpenBoardAttr = "true".equalsIgnoreCase(paramOpenBoard) ? "true" : "false";
  String safeDocIdsAttr = paramDocIds.replace("&", "&amp;").replace("\"", "&quot;").replace("'", "&#39;").replace("<", "&lt;");

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
<title>POL-MATE | 사건 관계망</title>
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
    --bnav:64px;
    --c-suspect:#dc2626; --c-victim:#3d8f6a; --c-witness:#4a7cdc; --c-reference:#8b5cf6;
  }
html,body { height:100%; font-family:'Noto Sans KR',sans-serif; background:var(--bg); overflow-x:hidden; }
.screen { width:100%; max-width:420px; min-height:100vh; margin:0 auto; background:var(--bg); display:flex; flex-direction:column; }

/* ── 헤더 ── */
.top-header { background:var(--navy); padding:52px 20px 0; position:sticky; top:0; z-index:20; }
.header-row { display:flex; align-items:center; gap:12px; padding-bottom:16px; }
.back-btn { width:36px; height:36px; border-radius:50%; background:rgba(255,255,255,0.12); border:none; display:flex; align-items:center; justify-content:center; cursor:pointer; flex-shrink:0; }
.back-btn svg { width:18px; height:18px; stroke:#fff; }
.header-text { flex:1; }
.header-title { font-size:17px; font-weight:500; color:#fff; }
.header-sub { font-size:10px; color:rgba(255,255,255,0.5); margin-top:2px; }
.header-gold-line { height:1.5px; background:linear-gradient(90deg,transparent,#f0c040 30%,#f0c040 70%,transparent); opacity:0.25; margin:0 -20px; }

/* ── 스크롤 콘텐츠 ── */
.content { flex:1; overflow-y:auto; padding:20px 16px calc(var(--bnav) + 24px); }

/* ── 섹션 라벨 ── */
.section-label { font-size:10px; font-weight:500; color:var(--tm); letter-spacing:0.8px; text-transform:uppercase; margin-bottom:8px; padding-left:2px; }

/* ── 사건 선택 카드 ── */
.case-select-card { background:var(--card); border-radius:16px; border:1px solid var(--bd); overflow:hidden; margin-bottom:16px; }
.case-item { display:flex; align-items:center; padding:14px 16px; border-bottom:1px solid var(--bd); cursor:pointer; transition:background 0.15s; gap:12px; }
.case-item:last-child { border-bottom:none; }
.case-item:active { background:var(--bg); }
.case-item.selected { background:#eff6ff; border-left:3px solid var(--accent); padding-left:13px; }
.case-icon { width:38px; height:38px; border-radius:10px; background:#f0f3f9; display:flex; align-items:center; justify-content:center; flex-shrink:0; }
.case-icon svg { width:18px; height:18px; stroke:var(--navy); }
.case-info { flex:1; min-width:0; }
.case-id { font-size:11px; color:var(--tm); margin-bottom:2px; }
.case-name { font-size:14px; font-weight:500; color:var(--tp); white-space:nowrap; overflow:hidden; text-overflow:ellipsis; }
.case-badge { font-size:10px; padding:3px 9px; border-radius:20px; white-space:nowrap; flex-shrink:0; }
.badge-active { background:var(--success-bg); color:var(--success); }
.badge-done   { background:#eff6ff; color:#1e40af; }
.badge-warn   { background:var(--warn-bg); color:var(--warn-text); }
.badge-danger { background:var(--danger-bg); color:var(--danger); }
.case-arrow svg { width:16px; height:16px; stroke:var(--tm); }

/* ── 빈 상태 ── */
.empty-box { background:var(--card); border-radius:16px; border:1px solid var(--bd); padding:48px 20px; text-align:center; margin-bottom:16px; }
.empty-icon-wrap { width:60px; height:60px; border-radius:50%; background:#f0f3f9; margin:0 auto 14px; display:flex; align-items:center; justify-content:center; }
.empty-icon-wrap svg { width:28px; height:28px; stroke:var(--ts); }
.empty-title { font-size:14px; font-weight:500; color:var(--tp); margin-bottom:6px; }
.empty-desc  { font-size:12px; color:var(--tm); line-height:1.7; }

/* ── AI 분석 섹션 ── */
.ai-section { background:var(--card); border-radius:16px; border:1px solid var(--bd); padding:16px; margin-bottom:16px; }
.ai-section-title { font-size:13px; font-weight:500; color:var(--tp); margin-bottom:4px; display:flex; align-items:center; gap:7px; }
.ai-section-title svg { width:16px; height:16px; }
.ai-section-desc { font-size:11px; color:var(--tm); margin-bottom:14px; line-height:1.6; }
.transcript-list { display:flex; flex-direction:column; gap:7px; margin-bottom:14px; }
.transcript-item { display:flex; align-items:center; gap:10px; padding:11px 13px; background:var(--bg); border-radius:11px; border:1px solid var(--bd); cursor:pointer; transition:border-color 0.15s; }
.transcript-item.checked { border-color:var(--accent); background:#eff6ff; }
.transcript-chk { width:18px; height:18px; border-radius:5px; border:1.5px solid var(--bd); flex-shrink:0; display:flex; align-items:center; justify-content:center; transition:all 0.15s; }
.transcript-item.checked .transcript-chk { background:var(--accent); border-color:var(--accent); }
.transcript-chk svg { width:10px; height:10px; stroke:#fff; display:none; }
.transcript-item.checked .transcript-chk svg { display:block; }
.transcript-info { flex:1; min-width:0; }
.transcript-title { font-size:13px; font-weight:500; color:var(--tp); }
.transcript-meta  { font-size:10px; color:var(--tm); margin-top:2px; }
.transcript-badge { font-size:10px; padding:2px 8px; border-radius:20px; white-space:nowrap; flex-shrink:0; }
.tb-contradiction { background:var(--danger-bg); color:var(--danger); }
.tb-normal        { background:var(--success-bg); color:var(--success); }

/* ── AI 분석 버튼 ── */
.btn-ai-analyze { width:100%; padding:14px; border-radius:13px; border:none; background:linear-gradient(135deg,var(--navy),#243358); color:#fff; font-size:14px; font-weight:500; font-family:'Noto Sans KR',sans-serif; cursor:pointer; display:flex; align-items:center; justify-content:center; gap:8px; transition:transform 0.1s; }
.btn-ai-analyze:active { transform:scale(0.98); }
.btn-ai-analyze:disabled { background:#9ca3af; cursor:not-allowed; }
.btn-ai-analyze svg { width:16px; height:16px; stroke:#fff; }

/* AI 분석 중 상태 */
.ai-loading { display:none; align-items:center; gap:10px; padding:14px; background:#f0f3f9; border-radius:12px; margin-top:10px; }
.ai-loading.show { display:flex; }
.ai-loading-dot { width:7px; height:7px; border-radius:50%; background:var(--accent); animation:aiBounce 1.2s infinite; flex-shrink:0; }
.ai-loading-dot:nth-child(2) { animation-delay:0.2s; }
.ai-loading-dot:nth-child(3) { animation-delay:0.4s; }
.ai-loading-text { font-size:12px; color:var(--ts); }

/* AI 결과 */
.ai-result-box { background:#f0f3f9; border-radius:12px; padding:12px 14px; margin-top:10px; display:none; }
.ai-result-box.show { display:block; }
.ai-result-label { font-size:10px; font-weight:500; color:var(--accent); margin-bottom:6px; text-transform:uppercase; letter-spacing:0.5px; }
.ai-result-text { font-size:12px; color:var(--ts); line-height:1.7; }

/* ── 관계망 보드 섹션 ── */
.board-section { background:var(--card); border-radius:16px; border:1px solid var(--bd); padding:16px; margin-bottom:16px; }
.board-section-title { font-size:13px; font-weight:500; color:var(--tp); margin-bottom:14px; display:flex; align-items:center; gap:7px; }
.board-section-title svg { width:16px; height:16px; stroke:var(--tp); }

/* 인물 그리드 */
.person-grid { display:grid; grid-template-columns:repeat(2,1fr); gap:8px; margin-bottom:14px; }
.person-card { background:var(--bg); border-radius:12px; border:1px solid var(--bd); padding:12px; display:flex; align-items:center; gap:10px; }
.person-avatar { width:36px; height:36px; border-radius:50%; display:flex; align-items:center; justify-content:center; font-size:13px; font-weight:700; color:#fff; flex-shrink:0; }
.person-card-name { font-size:13px; font-weight:500; color:var(--tp); }
.person-card-role { font-size:10px; margin-top:2px; }
.role-suspect  { color:var(--c-suspect); }
.role-victim   { color:var(--c-victim); }
.role-witness  { color:var(--c-witness); }
.role-reference{ color:var(--c-reference); }

/* 관계선 리스트 */
.edge-list { display:flex; flex-direction:column; gap:7px; margin-bottom:14px; }
.edge-item { padding:10px 13px; background:var(--bg); border-radius:11px; border:1px solid var(--bd); border-left:3px solid var(--bd); }
.edge-item.accomplice { border-left-color:#f97316; }
.edge-item.harm       { border-left-color:#dc2626; }
.edge-item.witness    { border-left-color:#4a7cdc; }
.edge-item.acquaint   { border-left-color:var(--tm); }
.edge-item.family     { border-left-color:#16a34a; }
.edge-names { font-size:13px; font-weight:500; color:var(--tp); }
.edge-rel   { font-size:11px; color:var(--tm); margin-top:3px; }
.edge-connector { color:var(--tm); margin:0 5px; font-weight:500; letter-spacing:0.02em; }

/* 보드 그리기 버튼 */
.btn-draw { width:100%; padding:14px; border-radius:13px; border:none; background:var(--accent); color:#fff; font-size:14px; font-weight:500; font-family:'Noto Sans KR',sans-serif; cursor:pointer; display:flex; align-items:center; justify-content:center; gap:8px; transition:transform 0.1s; margin-bottom:12px; }
.btn-draw:active { transform:scale(0.98); }
.btn-draw svg { width:16px; height:16px; stroke:#fff; }

/* 캔버스 */
.canvas-wrap { position:relative; width:100%; background:#0d1a33; border-radius:14px; overflow:hidden; border:1px solid var(--bd); margin-bottom:10px; }
.canvas-toolbar { position:absolute; top:10px; right:10px; z-index:5; display:flex; flex-direction:column; gap:6px; }
.canvas-tool-btn { width:32px; height:32px; border-radius:8px; background:rgba(255,255,255,0.12); border:1px solid rgba(255,255,255,0.18); display:flex; align-items:center; justify-content:center; cursor:pointer; }
.canvas-tool-btn svg { width:15px; height:15px; stroke:#fff; }
#relationCanvas { display:block; width:100%; cursor:grab; touch-action:none; }
.canvas-hint { position:absolute; bottom:10px; left:50%; transform:translateX(-50%); background:rgba(0,0,0,0.5); border-radius:20px; padding:5px 12px; font-size:10px; color:rgba(255,255,255,0.7); white-space:nowrap; pointer-events:none; }

/* 범례 */
.legend-wrap { display:flex; flex-wrap:wrap; gap:8px; margin-top:10px; }
.legend-item { display:flex; align-items:center; gap:5px; font-size:11px; color:var(--ts); }
.legend-dot { width:10px; height:10px; border-radius:50%; flex-shrink:0; }
.legend-line { width:18px; height:2px; flex-shrink:0; }

/* ── 드로어 오버레이 ── */
.overlay { position:fixed; inset:0; background:rgba(0,0,0,0.45); z-index:200; display:none; align-items:flex-end; justify-content:center; }
.overlay.open { display:flex; }
.drawer { background:var(--card); border-radius:20px 20px 0 0; width:100%; max-width:420px; padding:0 0 32px; animation:slideUp 0.28s ease both; max-height:90vh; overflow-y:auto; }
.drawer-handle { width:36px; height:4px; background:var(--bd); border-radius:2px; margin:12px auto 20px; }
.drawer-title { font-size:16px; font-weight:500; color:var(--tp); padding:0 20px 16px; border-bottom:1px solid var(--bd); }
.drawer-body { padding:20px; }
.d-btn { width:100%; background:var(--navy); color:#fff; border:none; border-radius:12px; padding:14px; font-size:14px; font-weight:500; font-family:'Noto Sans KR',sans-serif; cursor:pointer; margin-top:6px; transition:transform 0.1s; }
.d-btn:active { transform:scale(0.98); }
.d-btn-cancel { width:100%; background:var(--bg); color:var(--ts); border:1px solid var(--bd); border-radius:12px; padding:13px; font-size:14px; font-family:'Noto Sans KR',sans-serif; cursor:pointer; margin-top:8px; }

/* ── 하단 네비 ── */
.bottom-nav{
  position:fixed;bottom:0;left:50%;transform:translateX(-50%);
  width:100%;max-width:420px;height:var(--bnav);
  background:var(--card);border-top:1px solid var(--bd);
  display:flex;z-index:100;
}
.nav-item{flex:1;display:flex;flex-direction:column;align-items:center;justify-content:center;gap:3px;text-decoration:none;color:var(--tm);cursor:pointer;border:none;background:none;font-family:'Noto Sans KR',sans-serif;}
.nav-item.active{color:var(--deep);}
.nav-item.active .nav-label{font-weight:600;}
.nav-icon{width:22px;height:22px;display:flex;align-items:center;justify-content:center;}
.nav-icon svg{width:20px;height:20px;stroke:currentColor;fill:none;stroke-width:1.8;stroke-linecap:round;}
.nav-label{font-size:10px;}

/* ── 토스트 ── */
#toast { position:fixed; bottom:84px; left:50%; transform:translateX(-50%) translateY(20px); background:#1a2744; color:#fff; padding:10px 20px; border-radius:24px; font-size:13px; opacity:0; transition:all 0.3s; pointer-events:none; z-index:300; white-space:nowrap; }

@keyframes slideUp { from{transform:translateY(100%);opacity:0} to{transform:translateY(0);opacity:1} }
@keyframes fadeUp  { from{opacity:0;transform:translateY(8px)} to{opacity:1;transform:translateY(0)} }
@keyframes aiBounce { 0%,80%,100%{transform:translateY(0)} 40%{transform:translateY(-5px)} }
@media(min-width:421px){ .screen{box-shadow:0 0 40px rgba(0,0,0,0.1);} .drawer{max-width:420px;} }

/* ── 보드 팝업 오버레이 ── */
.board-popup-overlay {
  position:fixed; inset:0; background:rgba(0,0,0,0.6);
  z-index:400; display:none; align-items:flex-end; justify-content:center;
}
.board-popup-overlay.open { display:flex; }
.board-popup {
  background:var(--bg); border-radius:24px 24px 0 0;
  width:100%; max-width:420px; height:92vh;
  display:flex; flex-direction:column;
  animation:slideUp 0.3s ease both; overflow:hidden;
}
.board-popup-header {
  background:var(--navy); padding:16px 20px;
  display:flex; align-items:center; gap:12px; flex-shrink:0;
}
.board-popup-title { flex:1; font-size:15px; font-weight:500; color:#fff; }
.board-popup-sub   { font-size:10px; color:rgba(255,255,255,0.5); margin-top:2px; }
.popup-close-btn {
  width:32px; height:32px; border-radius:50%; background:rgba(255,255,255,0.12);
  border:none; display:flex; align-items:center; justify-content:center; cursor:pointer;
}
.popup-close-btn svg { width:16px; height:16px; stroke:#fff; }
.board-popup-body {
  flex:1; overflow-y:auto; padding:16px;
}
/* 팝업 내 탭 */
.popup-tabs {
  display:flex; background:var(--card); border-radius:12px;
  border:1px solid var(--bd); padding:4px; gap:4px; margin-bottom:14px;
}
.popup-tab {
  flex:1; padding:9px; border-radius:9px; border:none; cursor:pointer;
  font-size:12px; font-weight:500; font-family:'Noto Sans KR',sans-serif;
  color:var(--tm); background:none; transition:all 0.15s;
}
.popup-tab.active { background:var(--navy); color:#fff; }
/* 팝업 하단 버튼 영역 */
.board-popup-footer {
  background:var(--card); border-top:1px solid var(--bd);
  padding:12px 16px 24px; flex-shrink:0; display:flex; gap:8px;
}
.btn-popup-save {
  flex:1; padding:13px; border-radius:12px; border:none;
  background:var(--navy); color:#fff; font-size:13px; font-weight:500;
  font-family:'Noto Sans KR',sans-serif; cursor:pointer; display:flex;
  align-items:center; justify-content:center; gap:6px; transition:transform 0.1s;
}
.btn-popup-save:active { transform:scale(0.97); }
.btn-popup-save svg { width:15px; height:15px; stroke:#fff; }
.btn-popup-update {
  flex:1; padding:13px; border-radius:12px; border:none;
  background:var(--accent); color:#fff; font-size:13px; font-weight:500;
  font-family:'Noto Sans KR',sans-serif; cursor:pointer; display:flex;
  align-items:center; justify-content:center; gap:6px; transition:transform 0.1s;
}
.btn-popup-update:active { transform:scale(0.97); }
.btn-popup-update svg { width:15px; height:15px; stroke:#fff; }
/* 팝업 내 인물 편집 아이템 */
.popup-person-item {
  display:flex; align-items:center; gap:10px;
  padding:11px 13px; background:var(--card); border-radius:12px;
  border:1px solid var(--bd); margin-bottom:8px;
}
.popup-person-item .person-avatar { width:34px; height:34px; font-size:12px; }
.popup-person-actions { display:flex; gap:5px; margin-left:auto; }
.popup-person-btn {
  width:26px; height:26px; border-radius:7px; background:var(--bg);
  border:1px solid var(--bd); display:flex; align-items:center;
  justify-content:center; cursor:pointer;
}
.popup-person-btn svg { width:12px; height:12px; stroke:var(--ts); }
.popup-person-btn.del svg { stroke:var(--danger); }
/* 팝업 내 관계선 편집 아이템 */
.popup-edge-item {
  padding:10px 13px; background:var(--card); border-radius:12px;
  border:1px solid var(--bd); border-left:3px solid var(--bd);
  margin-bottom:8px; display:flex; align-items:center; gap:8px;
}
.popup-edge-item.accomplice { border-left-color:#f97316; }
.popup-edge-item.harm       { border-left-color:#dc2626; }
.popup-edge-item.witness    { border-left-color:#4a7cdc; }
.popup-edge-item.acquaint   { border-left-color:var(--tm); }
.popup-edge-item.family     { border-left-color:#16a34a; }
/* 인물 추가 미니 폼 */
.mini-form { background:var(--card); border-radius:14px; border:1px solid var(--bd); padding:14px; margin-bottom:12px; }
.mini-form-title { font-size:12px; font-weight:500; color:var(--tp); margin-bottom:10px; }
.mini-input {
  width:100%; padding:9px 12px; background:var(--bg); border:1px solid var(--bd);
  border-radius:9px; font-size:13px; font-family:'Noto Sans KR',sans-serif;
  color:var(--tp); outline:none; margin-bottom:8px;
}
.mini-input:focus { border-color:var(--accent); background:#fff; }
.mini-role-row { display:grid; grid-template-columns:repeat(4,1fr); gap:5px; margin-bottom:10px; }
.mini-role-btn {
  padding:7px 4px; border-radius:8px; border:1.5px solid var(--bd);
  font-size:10px; font-weight:500; cursor:pointer; text-align:center;
  background:none; font-family:'Noto Sans KR',sans-serif; color:var(--tm);
  transition:all 0.15s;
}
.mini-role-btn.sel-suspect  { border-color:var(--c-suspect);  background:#fef2f2; color:var(--c-suspect); }
.mini-role-btn.sel-victim   { border-color:var(--c-victim);   background:#e8f4ef; color:var(--c-victim); }
.mini-role-btn.sel-witness  { border-color:var(--c-witness);  background:#eff6ff; color:var(--c-witness); }
.mini-role-btn.sel-reference{ border-color:var(--c-reference);background:#f5f3ff; color:var(--c-reference); }
.mini-role-btn.sel-active   { border-color:var(--accent); background:#eff6ff; color:var(--accent); font-weight:600; }
.mini-btn-row { display:flex; gap:8px; }
.mini-btn {
  flex:1; padding:9px; border-radius:9px; border:none; font-size:12px; font-weight:500;
  font-family:'Noto Sans KR',sans-serif; cursor:pointer; transition:transform 0.1s;
}
.mini-btn:active { transform:scale(0.97); }
.mini-btn.primary { background:var(--navy); color:#fff; }
.mini-btn.secondary { background:var(--bg); color:var(--ts); border:1px solid var(--bd); }
</style>
</head>
<body>
<div class="screen">

  <!-- ── 헤더 ── -->
  <div class="top-header">
    <div class="header-row">
      <button class="back-btn" onclick="location.href='main'">
        <svg viewBox="0 0 24 24" fill="none" stroke-width="2" stroke-linecap="round"><polyline points="15 18 9 12 15 6"/></svg>
      </button>
      <div class="header-text">
        <div class="header-title">사건 관계망</div>
        <div class="header-sub">사건 선택 · AI 분석 · 관계망 시각화</div>
      </div>
    </div>
    <div class="header-gold-line"></div>
  </div>

  <!-- ── 콘텐츠 ── -->
  <div class="content">

    <!-- STEP 1: 사건 선택 -->
    <div class="section-label" style="margin-top:4px;">① 사건 선택</div>

    <div id="caseSelectCard" class="case-select-card">
      <div style="text-align:center;padding:20px;font-size:12px;color:var(--tm);">불러오는 중...</div>
    </div>

    <!-- STEP 2: AI 조서 분석 (사건 선택 후 표시) -->
    <div id="aiSection" style="display:none;">
      <div class="section-label">② AI 조서 분석</div>
      <div class="ai-section">
        <div class="ai-section-title">
          <svg viewBox="0 0 86 86" fill="none" style="width:16px;height:16px;">
            <path d="M43 7 L66 17 L66 41 C66 57 43 71 43 71 C43 71 20 57 20 41 L20 17 Z" fill="none" stroke="var(--navy)" stroke-width="5"/>
            <circle cx="43" cy="40" r="5" fill="var(--navy)"/>
          </svg>
          조서를 선택해 관계망을 분석합니다
        </div>
        <div class="ai-section-desc">조서를 1개 이상 선택하면 AI가 등장인물과 관계를 자동으로 분석합니다.</div>

        <div class="transcript-list" id="transcriptList">
          <div style="text-align:center;padding:20px;font-size:12px;color:var(--tm);">사건을 선택하면 조서 목록이 표시됩니다.</div>
        </div>

        <button class="btn-ai-analyze" id="btnAnalyze" onclick="analyzeWithAI()" disabled>
          <svg viewBox="0 0 24 24" fill="none" stroke-width="2" stroke-linecap="round">
            <circle cx="12" cy="12" r="10"/><path d="M12 8v4l3 3"/>
          </svg>
          AI 관계망 분석 시작
        </button>

        <div class="ai-loading" id="aiLoading">
          <div class="ai-loading-dot"></div>
          <div class="ai-loading-dot"></div>
          <div class="ai-loading-dot"></div>
          <div class="ai-loading-text" id="aiLoadingText">AI가 조서를 분석하는 중...</div>
        </div>

        <div class="ai-result-box" id="aiResultBox">
          <div class="ai-result-label">AI 분석 결과</div>
          <div class="ai-result-text" id="aiResultText"></div>
        </div>
      </div>
    </div>

    <!-- STEP 3: 관계망 보드 (분석 완료 후 표시) -->
    <div id="boardSection" style="display:none;">
      <div class="section-label">③ 관계망 보드</div>

      <!-- 등록 인물 -->
      <div class="board-section">
        <div class="board-section-title">
          <svg viewBox="0 0 24 24" fill="none" stroke-width="2" stroke-linecap="round">
            <path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"/>
            <circle cx="9" cy="7" r="4"/>
            <path d="M23 21v-2a4 4 0 0 0-3-3.87"/><path d="M16 3.13a4 4 0 0 1 0 7.75"/>
          </svg>
          등록 인물 &nbsp;<span id="personCountBadge" style="font-size:11px;background:#f0f3f9;color:var(--navy);padding:2px 8px;border-radius:20px;font-weight:400;">0명</span>
        </div>
        <div class="person-grid" id="personGrid">
          <div style="grid-column:span 2;text-align:center;padding:16px 0;font-size:12px;color:var(--tm);">분석 완료 후 인물이 표시됩니다.</div>
        </div>
      </div>

      <!-- 관계선 -->
      <div class="board-section">
        <div class="board-section-title">
          <svg viewBox="0 0 24 24" fill="none" stroke-width="2" stroke-linecap="round">
            <line x1="5" y1="12" x2="19" y2="12"/>
          </svg>
          관계선 &nbsp;<span id="edgeCountBadge" style="font-size:11px;background:#f0f3f9;color:var(--navy);padding:2px 8px;border-radius:20px;font-weight:400;">0개</span>
        </div>
        <div class="edge-list" id="edgeListView">
          <div style="text-align:center;padding:12px 0;font-size:12px;color:var(--tm);">분석 완료 후 관계선이 표시됩니다.</div>
        </div>
      </div>

      <!-- 보드 그리기 → 팝업 오픈 -->
      <button class="btn-draw" onclick="openBoardPopup()">
        <svg viewBox="0 0 24 24" fill="none" stroke-width="2" stroke-linecap="round">
          <circle cx="8" cy="12" r="3"/><circle cx="18" cy="6" r="3"/><circle cx="18" cy="18" r="3"/>
          <line x1="10.8" y1="10.7" x2="15.2" y2="7.3"/><line x1="10.8" y1="13.3" x2="15.2" y2="16.7"/>
        </svg>
        보드 그리기
      </button>

      <!-- 캔버스 -->
      <div id="canvasContainer" style="display:none;">
        <div class="canvas-wrap" id="canvasWrap">
          <div class="canvas-toolbar">
            <button type="button" class="canvas-tool-btn" onclick="relationZoomIn()">
              <svg viewBox="0 0 24 24" fill="none" stroke-width="2.5" stroke-linecap="round"><line x1="12" y1="5" x2="12" y2="19"/><line x1="5" y1="12" x2="19" y2="12"/></svg>
            </button>
            <button type="button" class="canvas-tool-btn" onclick="relationZoomOut()">
              <svg viewBox="0 0 24 24" fill="none" stroke-width="2.5" stroke-linecap="round"><line x1="5" y1="12" x2="19" y2="12"/></svg>
            </button>
            <button type="button" class="canvas-tool-btn" onclick="relationResetView()">
              <svg viewBox="0 0 24 24" fill="none" stroke-width="2" stroke-linecap="round"><polyline points="1 4 1 10 7 10"/><path d="M3.51 15a9 9 0 1 0 .49-3.5"/></svg>
            </button>
          </div>
          <canvas id="relationCanvas" height="340"></canvas>
          <div class="canvas-hint">노드 끌어 배치 · 빈 곳 드래그로 이동 · 핀치 확대</div>
        </div>

        <!-- 범례 -->
        <div style="background:var(--card);border-radius:14px;border:1px solid var(--bd);padding:14px 16px;margin-bottom:12px;">
          <div class="legend-wrap">
            <div class="legend-item"><div class="legend-dot" style="background:var(--c-suspect)"></div>피의자</div>
            <div class="legend-item"><div class="legend-dot" style="background:var(--c-victim)"></div>피해자</div>
            <div class="legend-item"><div class="legend-dot" style="background:var(--c-witness)"></div>목격자</div>
            <div class="legend-item"><div class="legend-dot" style="background:var(--c-reference)"></div>참고인</div>
            <div class="legend-item"><div class="legend-line" style="background:#f97316;height:2px;"></div>공범</div>
            <div class="legend-item"><div class="legend-line" style="background:#dc2626;height:2px;"></div>피해관계</div>
            <div class="legend-item"><div class="legend-line" style="background:#4a7cdc;height:2px;"></div>목격</div>
            <div class="legend-item"><div class="legend-line" style="background:#16a34a;height:2px;"></div>가족</div>
            <div class="legend-item"><div class="legend-line" style="background:#9ca3af;height:2px;"></div>지인</div>
            <div class="legend-item"><div class="legend-line" style="background:#f97316;height:2px;"></div>진술 불일치</div>
          </div>
        </div>
      </div>
    </div>

  </div><!-- /content -->

<!-- ═══════════════════════════════════════
     보드 팝업 (관계망 시각화 + 편집 + 저장)
═══════════════════════════════════════ -->
<div class="board-popup-overlay" id="boardPopupOverlay">
  <div class="board-popup">

    <!-- 팝업 헤더 -->
    <div class="board-popup-header">
      <button class="popup-close-btn" onclick="closeBoardPopup()">
        <svg viewBox="0 0 24 24" fill="none" stroke-width="2" stroke-linecap="round">
          <line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/>
        </svg>
      </button>
      <div>
        <div class="board-popup-title" id="popupTitle">사건 관계망 보드</div>
        <div class="board-popup-sub"  id="popupSub">인물·관계선 확인 및 편집</div>
      </div>
    </div>

    <!-- 팝업 탭 -->
    <div class="board-popup-body">
      <div class="popup-tabs">
        <button class="popup-tab active" id="tabCanvas"  onclick="switchPopupTab('canvas')">관계망 보드</button>
        <button class="popup-tab"        id="tabPersons" onclick="switchPopupTab('persons')">인물 편집</button>
        <button class="popup-tab"        id="tabEdges"   onclick="switchPopupTab('edges')">관계선 편집</button>
      </div>

      <!-- 탭: 관계망 보드 (캔버스) -->
      <div id="tabPanelCanvas">
        <div class="canvas-wrap" id="popupCanvasWrap">
          <div class="canvas-toolbar">
            <button type="button" class="canvas-tool-btn" onclick="popupZoomIn()">
              <svg viewBox="0 0 24 24" fill="none" stroke-width="2.5" stroke-linecap="round"><line x1="12" y1="5" x2="12" y2="19"/><line x1="5" y1="12" x2="19" y2="12"/></svg>
            </button>
            <button type="button" class="canvas-tool-btn" onclick="popupZoomOut()">
              <svg viewBox="0 0 24 24" fill="none" stroke-width="2.5" stroke-linecap="round"><line x1="5" y1="12" x2="19" y2="12"/></svg>
            </button>
            <button type="button" class="canvas-tool-btn" onclick="popupResetView()">
              <svg viewBox="0 0 24 24" fill="none" stroke-width="2" stroke-linecap="round"><polyline points="1 4 1 10 7 10"/><path d="M3.51 15a9 9 0 1 0 .49-3.5"/></svg>
            </button>
          </div>
          <canvas id="boardPopupCanvas" height="360"></canvas>
          <div class="canvas-hint">노드 끌어 배치 · 빈 곳 드래그로 이동 · 핀치 확대</div>
        </div>
        <div style="background:var(--card);border-radius:12px;border:1px solid var(--bd);padding:12px 14px;margin-top:10px;">
          <div class="legend-wrap">
            <div class="legend-item"><div class="legend-dot" style="background:var(--c-suspect)"></div>피의자</div>
            <div class="legend-item"><div class="legend-dot" style="background:var(--c-victim)"></div>피해자</div>
            <div class="legend-item"><div class="legend-dot" style="background:var(--c-witness)"></div>목격자</div>
            <div class="legend-item"><div class="legend-dot" style="background:var(--c-reference)"></div>참고인</div>
            <div class="legend-item"><div class="legend-line" style="background:#f97316;height:2px;"></div>공범</div>
            <div class="legend-item"><div class="legend-line" style="background:#dc2626;height:2px;"></div>피해관계</div>
            <div class="legend-item"><div class="legend-line" style="background:#4a7cdc;height:2px;"></div>목격</div>
            <div class="legend-item"><div class="legend-line" style="background:#16a34a;height:2px;"></div>가족</div>
            <div class="legend-item"><div class="legend-line" style="background:#9ca3af;height:2px;"></div>지인</div>
            <div class="legend-item"><div class="legend-line" style="background:#f97316;height:2px;"></div>진술 불일치</div>
          </div>
        </div>
      </div>

      <!-- 탭: 인물 편집 -->
      <div id="tabPanelPersons" style="display:none;">
        <!-- 인물 추가 미니 폼 -->
        <div class="mini-form">
          <div class="mini-form-title" id="miniFormTitle">인물 추가</div>
          <input class="mini-input" id="miniPersonName" placeholder="이름">
          <input class="mini-input" id="miniPersonMemo" placeholder="메모 (선택)">
          <div class="mini-role-row">
            <button type="button" class="mini-role-btn" id="mrole-suspect"   onclick="selectMiniRole('suspect')">🔴 피의자</button>
            <button type="button" class="mini-role-btn" id="mrole-victim"    onclick="selectMiniRole('victim')">🟢 피해자</button>
            <button type="button" class="mini-role-btn" id="mrole-witness"   onclick="selectMiniRole('witness')">🔵 목격자</button>
            <button type="button" class="mini-role-btn" id="mrole-reference" onclick="selectMiniRole('reference')">🟣 참고인</button>
          </div>
          <div class="mini-btn-row">
            <button type="button" class="mini-btn primary" id="miniAddBtn" onclick="addMiniPerson()">추가</button>
            <button type="button" class="mini-btn secondary"  onclick="clearMiniPersonForm()">초기화</button>
          </div>
        </div>
        <div id="popupPersonList"></div>
      </div>

      <!-- 탭: 관계선 편집 -->
      <div id="tabPanelEdges" style="display:none;">
        <!-- 관계선 추가 미니 폼 -->
        <div class="mini-form">
          <div class="mini-form-title">관계선 추가</div>
          <select class="mini-input" id="miniEdgeSrc" style="appearance:none;margin-bottom:8px;">
            <option value="">출발 인물 선택</option>
          </select>
          <select class="mini-input" id="miniEdgeDst" style="appearance:none;margin-bottom:8px;">
            <option value="">도착 인물 선택</option>
          </select>
          <div style="display:flex;gap:6px;flex-wrap:wrap;margin-bottom:10px;" id="miniRelRow">
            <button type="button" class="mini-role-btn" id="mrel-accomplice" onclick="selectMiniRel('accomplice')">공범</button>
            <button type="button" class="mini-role-btn" id="mrel-harm"       onclick="selectMiniRel('harm')">피해관계</button>
            <button type="button" class="mini-role-btn" id="mrel-witness"    onclick="selectMiniRel('witness')">목격</button>
            <button type="button" class="mini-role-btn" id="mrel-acquaint"   onclick="selectMiniRel('acquaint')">지인</button>
            <button type="button" class="mini-role-btn" id="mrel-family"     onclick="selectMiniRel('family')">가족</button>
          </div>
          <div class="mini-btn-row">
            <button type="button" class="mini-btn primary"   onclick="addMiniEdge()">추가</button>
            <button type="button" class="mini-btn secondary" onclick="clearMiniEdgeForm()">초기화</button>
          </div>
        </div>
        <div id="popupEdgeList"></div>
      </div>
    </div>

    <!-- 팝업 하단 버튼 -->
    <div class="board-popup-footer">
      <button class="btn-popup-save" id="btnPopupSave" onclick="saveBoardFromPopup(false)">
        <svg viewBox="0 0 24 24" fill="none" stroke-width="2" stroke-linecap="round">
          <path d="M19 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h11l5 5v11a2 2 0 0 1-2 2z"/>
          <polyline points="17 21 17 13 7 13 7 21"/>
        </svg>
        보드 저장
      </button>
      <button class="btn-popup-update" id="btnPopupUpdate" onclick="saveBoardFromPopup(true)" style="display:none;">
        <svg viewBox="0 0 24 24" fill="none" stroke-width="2" stroke-linecap="round">
          <polyline points="1 4 1 10 7 10"/>
          <path d="M3.51 15a9 9 0 1 0 .49-3.5"/>
        </svg>
        보드 업데이트
      </button>
    </div>
  </div>
</div>


  <!-- ── 하단 네비 ── -->
      <nav class="bottom-nav">
    <a href="main" class="nav-item"><div class="nav-icon"><svg viewBox="0 0 24 24"><path d="M3 9l9-7 9 7v11a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"/><polyline points="9 22 9 12 15 12 15 22"/></svg></div><span class="nav-label">홈</span></a>
    <a href="myCase" class="nav-item"><div class="nav-icon"><svg viewBox="0 0 24 24"><path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/><polyline points="14 2 14 8 20 8"/></svg></div><span class="nav-label">사건</span></a>
    <a href="../askAI" class="nav-item"><div class="nav-icon"><svg width="22" height="22" viewBox="0 0 86 86" fill="none"><path d="M43 7 L66 17 L66 41 C66 57 43 71 43 71 C43 71 20 57 20 41 L20 17 Z" fill="none" stroke="currentColor" stroke-width="5"/><circle cx="43" cy="40" r="11" fill="none" stroke="currentColor" stroke-width="3"/><circle cx="43" cy="40" r="5" fill="currentColor"/><circle cx="43" cy="40" r="2.5" fill="white"/><circle cx="43" cy="22" r="2.8" fill="currentColor"/><circle cx="43" cy="58" r="2.8" fill="currentColor"/><circle cx="28" cy="40" r="2.8" fill="currentColor"/><circle cx="58" cy="40" r="2.8" fill="currentColor"/></svg></div><span class="nav-label">AI</span></a>
    <a href="board" class="nav-item"><div class="nav-icon"><svg viewBox="0 0 24 24"><path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z"/></svg></div><span class="nav-label">커뮤니티</span></a>
    <a href="mypage" class="nav-item"><div class="nav-icon"><svg viewBox="0 0 24 24"><path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2"/><circle cx="12" cy="7" r="4"/></svg></div><span class="nav-label">마이페이지</span></a>
  </nav>
</div>

<div id="toast"></div>
<div id="_relationPageBoot" hidden data-case-id="<%= safeCaseIdAttr %>" data-open-board="<%= safeOpenBoardAttr %>" data-doc-ids="<%= safeDocIdsAttr %>"></div>

<script>
// ── 전역 상태 ──────────────────────────────────────────────────────
var currentCaseId   = '';
var currentCaseName = '';
var persons = [];
var edges   = [];
var checkedTranscripts = [];

// 인물: 피의자 빨강 · 피해자 초록 · 목격 파랑 · 참고 보라 / 관계선: 피해관계=피의자색 · 공범=진술불일치(주황)
var ROLE_COLOR = {suspect:'#dc2626',victim:'#3d8f6a',witness:'#4a7cdc',reference:'#8b5cf6'};
var ROLE_LABEL = {suspect:'피의자',victim:'피해자',witness:'목격자',reference:'참고인'};
var REL_COLOR  = {accomplice:'#f97316',harm:'#dc2626',witness:'#4a7cdc',acquaint:'#9ca3af',family:'#16a34a'};
var EDGE_MISMATCH_STROKE = '#f97316'; // 진술 불일치 = 공범색(피해관계는 피의자색으로 구분)
var REL_LABEL  = {accomplice:'공범',harm:'피해관계',witness:'목격',acquaint:'지인',family:'가족'};

/** Pol-mate-Serv (Flask app.py) — Ollama는 서버에서만 호출. 로컬 개발 시 http://127.0.0.1:5001 로 바꿀 것. */
var POL_MATE_SERV_BASE = '<%= safePolMateServBaseUrl %>';
var RELATION_MAP_URL   = POL_MATE_SERV_BASE.replace(/\/$/, '') + '/relation_map';

// ── STEP 1: 사건 선택 ────────────────────────────────────────────
function selectCase(caseId, caseName) {
  currentCaseId   = caseId;
  currentCaseName = caseName;

  // 선택 표시
  document.querySelectorAll('.case-item').forEach(function(el) {
    el.classList.remove('selected');
  });
  var key = caseId.replace(/-/g, '_');
  var el = document.getElementById('caseItem_' + key);
  if (el) el.classList.add('selected');

  // AI 섹션 표시 + 조서 목록 로드
  document.getElementById('aiSection').style.display   = 'block';
  document.getElementById('boardSection').style.display = 'none';
  checkedTranscripts = [];
  loadTranscripts(caseId);

  // 부드럽게 스크롤
  setTimeout(function() {
    document.getElementById('aiSection').scrollIntoView({behavior:'smooth', block:'start'});
  }, 100);
}

// ── 조서 목록 로드 (caseApi action=caseDetail) ──────────────────
function loadTranscripts(caseId) {
  var list = document.getElementById('transcriptList');
  list.innerHTML = '<div style="text-align:center;padding:20px;font-size:12px;color:var(--tm);">불러오는 중...</div>';
  document.getElementById('btnAnalyze').disabled = true;

  fetch('../caseApi?action=caseDetail&caseId=' + encodeURIComponent(caseId))
    .then(function(r) { return r.json(); })
    .then(function(data) {
      if (data.error) {
        list.innerHTML = '<div style="text-align:center;padding:20px;font-size:12px;color:var(--danger);">' + escHtml(data.error) + '</div>';
        return;
      }
      var docs = data.docs || [];
      if (!docs.length) {
        list.innerHTML = '<div style="text-align:center;padding:20px;font-size:12px;color:var(--tm);">이 사건에 등록된 조서가 없습니다.</div>';
        return;
      }
      // 조서 아이템을 DOM으로 직접 생성 (innerHTML onclick은 따옴표 충돌 위험)
      list.innerHTML = '';
      docs.forEach(function(d) {
        var badgeCls  = d.contradiction ? 'tb-contradiction' : 'tb-normal';
        var badgeTxt  = d.contradiction ? '모순탐지' : '정상';
        var typeLabel = {'피의자':'피의자','피해자':'피해자','목격자':'목격자','참고인':'참고인'}[d.type] || d.type || '미분류';

        var item = document.createElement('div');
        item.className = 'transcript-item';
        item.id = 'tr_' + d.id;

        var chk = document.createElement('div');
        chk.className = 'transcript-chk';
        chk.innerHTML = '<svg viewBox="0 0 12 12" fill="none" stroke-width="2.5" stroke-linecap="round"><polyline points="2 6 5 9 10 3"/></svg>';

        var info = document.createElement('div');
        info.className = 'transcript-info';
        var wordCount = d.textLen || d.words || 0;
        var warnTxt = wordCount === 0
          ? ' <span style="color:#dc2626;font-size:10px;">⚠ 원문 없음</span>' : '';
        info.innerHTML =
          '<div class="transcript-title">' + escHtml(d.name || '미입력') + ' · ' + escHtml(typeLabel) + '</div>' +
          '<div class="transcript-meta">' + escHtml(d.date) + ' · ' + wordCount + '자' + warnTxt + '</div>';

        var badge = document.createElement('span');
        badge.className = 'transcript-badge ' + badgeCls;
        badge.textContent = badgeTxt;

        item.appendChild(chk);
        item.appendChild(info);
        item.appendChild(badge);

        // 클릭 이벤트를 addEventListener로 안전하게 등록
        (function(transcriptId, transcriptName, transcriptType, transcriptDate) {
          item.addEventListener('click', function() {
            toggleTranscript(transcriptId, transcriptName, transcriptType, transcriptDate);
          });
        })(String(d.id), d.name || '', d.type || '', d.date || '');

        list.appendChild(item);
      });
    })
    .catch(function() {
      list.innerHTML = '<div style="text-align:center;padding:20px;font-size:12px;color:var(--danger);">조서 목록을 불러오지 못했습니다.</div>';
    });
}

// ── 조서 체크/해제 ────────────────────────────────────────────────
function toggleTranscript(id, name, type, date) {
  id = String(id); // 타입 통일 (숫자/문자열 혼용 방지)
  var el = document.getElementById('tr_' + id);
  if (!el) return;
  var idx = checkedTranscripts.findIndex(function(t) { return String(t.id) === id; });
  if (idx >= 0) {
    checkedTranscripts.splice(idx, 1);
    el.classList.remove('checked');
  } else {
    checkedTranscripts.push({id:id, name:name, type:type, date:date});
    el.classList.add('checked');
  }
  document.getElementById('btnAnalyze').disabled = checkedTranscripts.length < 1;
}

// ── STEP 2: AI 분석 ───────────────────────────────────────────────
function analyzeWithAI() {
  if (checkedTranscripts.length < 1) {
    showToast('조서를 1개 이상 선택해 주세요.'); return;
  }

  document.getElementById('btnAnalyze').disabled  = true;
  document.getElementById('aiLoading').classList.add('show');
  document.getElementById('aiResultBox').classList.remove('show');
  document.getElementById('aiLoadingText').textContent = '조서 내용을 불러오는 중...';

  // 선택된 조서들의 원문 가져오기
  var fetchPromises = checkedTranscripts.map(function(t) {
    return fetch('../caseApi?action=transcriptText&transcriptId=' + t.id)
      .then(function(r) { return r.json(); })
      .then(function(d) {
        if (d.error) {
          console.warn('[조서 원문 조회 실패] id=' + t.id + ' 오류=' + d.error);
          return { meta: t, text: '' };
        }
        var text = d.text || '';
        console.log('[조서 원문] id=' + t.id + ' 이름=' + t.name + ' 길이=' + text.length + '자');
        if (!text) console.warn('  → 원문이 비어있습니다. DB의 original_text 컬럼을 확인하세요.');
        return { meta: t, text: text };
      })
      .catch(function(err) {
        console.error('[조서 원문 네트워크 오류] id=' + t.id, err);
        return { meta: t, text: '' };
      });
  });

  Promise.all(fetchPromises).then(function(results) {
    // 원문 로드 결과 요약
    var filled = results.filter(function(r) { return r.text && r.text.trim().length > 0; }).length;
    console.log('[조서 원문 로드 완료] 총 ' + results.length + '건 중 ' + filled + '건 원문 있음');
    document.getElementById('aiLoadingText').textContent = 'AI 서버(Pol-mate-Serv)가 관계망을 분석하는 중... (' + filled + '/' + results.length + '건 원문 있음)';

    var payload = {
      caseId: currentCaseId,
      caseName: currentCaseName,
      transcripts: results.map(function(r) {
        return {
          name: r.meta.name || '',
          type: r.meta.type || '',
          text: r.text || ''
        };
      })
    };

    fetch(RELATION_MAP_URL, {
      method: 'POST',
      headers: {'Content-Type': 'application/json'},
      body: JSON.stringify(payload)
    })
    .then(function(r) {
      return r.json().then(function(j) {
        return { ok: r.ok, status: r.status, data: j };
      }).catch(function() {
        return { ok: false, status: r.status, data: { error: 'JSON 파싱 실패', response: '' } };
      });
    })
    .then(function(w) {
      var data = w.data || {};
      if (!w.ok || data.success === false) {
        var msg = (data.error || ('HTTP ' + w.status));
        console.warn('[relation_map]', msg, data);
        document.getElementById('aiLoading').classList.remove('show');
        runFallback('AI 서버: ' + msg);
        return;
      }
      var raw = data.response || '';
      console.log('[relation_map 응답] 길이:', raw.length, '앞부분:', raw.substring(0, 120));
      if (!raw.trim()) {
        runFallback('AI 서버가 빈 응답을 반환했습니다.');
        document.getElementById('aiLoading').classList.remove('show');
        return;
      }
      parseAndApplyAiResult(raw);
    })
    .catch(function(err) {
      console.warn('[relation_map] 네트워크 오류', err);
      document.getElementById('aiLoading').classList.remove('show');
      runFallback(err.message || 'Pol-mate-Serv에 연결할 수 없습니다. (' + RELATION_MAP_URL + ')');
    });
  });
}

// ── AI 응답 파싱 & 적용 ──────────────────────────────────────────
// role/relType 정규화 맵
var VALID_ROLES    = ['suspect','victim','witness','reference'];
var VALID_RELTYPES = ['accomplice','harm','witness','acquaint','family'];
var VALID_STATUSES = ['match','mismatch','unknown'];

function normalizeRole(r) {
  if (!r) return 'reference';
  r = String(r).toLowerCase().trim();
  // 파이프 구분 값이면 첫 번째만
  if (r.indexOf('|') >= 0) r = r.split('|')[0].trim();
  if (VALID_ROLES.indexOf(r) >= 0) return r;
  // 한국어 → 영문 변환
  if (r.indexOf('피의자') >= 0 || r.indexOf('suspect') >= 0) return 'suspect';
  if (r.indexOf('피해자') >= 0 || r.indexOf('victim')  >= 0) return 'victim';
  if (r.indexOf('목격자') >= 0 || r.indexOf('witness') >= 0) return 'witness';
  return 'reference';
}
function normalizeRelType(r) {
  if (!r) return 'acquaint';
  r = String(r).toLowerCase().trim();
  if (r.indexOf('|') >= 0) r = r.split('|')[0].trim();
  if (VALID_RELTYPES.indexOf(r) >= 0) return r;
  if (r.indexOf('공범') >= 0 || r.indexOf('accomplice') >= 0) return 'accomplice';
  if (r.indexOf('피해') >= 0 || r.indexOf('harm')       >= 0) return 'harm';
  if (r.indexOf('목격') >= 0 || r.indexOf('witness')    >= 0) return 'witness';
  if (r.indexOf('가족') >= 0 || r.indexOf('family')     >= 0) return 'family';
  if (r.indexOf('지인') >= 0 || r.indexOf('지언') >= 0 || r.indexOf('acquaint') >= 0) return 'acquaint';
  return 'acquaint';
}
function normalizeStatus(s) {
  if (!s) return 'unknown';
  var raw = String(s).trim();
  var t = raw.toLowerCase();
  if (t.indexOf('|') >= 0) { t = t.split('|')[0].trim(); raw = raw.split('|')[0].trim(); }
  if (VALID_STATUSES.indexOf(t) >= 0) return t;
  if (raw.indexOf('진술') >= 0 && raw.indexOf('불일치') >= 0) return 'mismatch';
  if (raw.indexOf('불일치') >= 0 || t.indexOf('mismatch') >= 0) return 'mismatch';
  if ((raw.indexOf('일치') >= 0 || t === 'match') && raw.indexOf('불일치') < 0 && t.indexOf('mismatch') < 0) return 'match';
  return 'unknown';
}

// 조서 선택 메타와 동일 실명이면 피의자·피해자 역할이 참고·목격보다 우선 (서버 polmate_serv 후처리와 동일 취지)
var ROLE_PRIORITY_NUM = { suspect: 4, victim: 3, witness: 2, reference: 1 };
function personNameCompactKey(name) {
  return String(name || '').replace(/\s+/g, '').toLowerCase();
}
function transcriptRoleHintStronger(a, b) {
  return (ROLE_PRIORITY_NUM[b] || 0) > (ROLE_PRIORITY_NUM[a] || 0) ? b : a;
}
function buildTranscriptRoleHintsFromChecked() {
  var hints = {};
  if (!Array.isArray(checkedTranscripts)) return hints;
  checkedTranscripts.forEach(function(t) {
    var nm = String(t.name || '').trim();
    if (!nm) return;
    var k = personNameCompactKey(nm);
    var role = normalizeRole(t.type || '');
    if (!hints[k]) hints[k] = role;
    else hints[k] = transcriptRoleHintStronger(hints[k], role);
  });
  return hints;
}
function applyTranscriptRoleHintsToPersons(personArr) {
  var hints = buildTranscriptRoleHintsFromChecked();
  return personArr.map(function(p) {
    var k = personNameCompactKey(p.name);
    if (hints[k]) return { id: p.id, name: p.name, role: hints[k], memo: p.memo || '' };
    return p;
  });
}
function mergePersonsByCompactNameStrongestRole(personArr) {
  var buckets = {};
  personArr.forEach(function(p) {
    var k = personNameCompactKey(p.name);
    if (!k) return;
    if (!buckets[k]) buckets[k] = [];
    buckets[k].push(p);
  });
  var out = [];
  Object.keys(buckets).forEach(function(k) {
    var group = buckets[k];
    if (group.length === 1) {
      out.push(group[0]);
      return;
    }
    var best = group.reduce(function(a, b) {
      return (ROLE_PRIORITY_NUM[b.role] || 0) > (ROLE_PRIORITY_NUM[a.role] || 0) ? b : a;
    });
    var role = best.role;
    var winners = group.filter(function(x) { return x.role === role; });
    var canonical = winners.reduce(function(a, b) {
      return String(b.name).trim().length > String(a.name).trim().length ? b : a;
    }).name.trim();
    var memos = [];
    group.forEach(function(x) {
      var m = String(x.memo || '').trim();
      if (m && memos.indexOf(m) < 0) memos.push(m);
    });
    out.push({ id: uid(), name: canonical, role: role, memo: memos.join(' / ') });
  });
  return out;
}

function extractJsonFromRaw(raw) {
  if (!raw) return null;

  // 1. 마크다운 코드블록 제거
  var cleaned = raw
    .replace(/```json\s*/gi, '')
    .replace(/```\s*/g, '')
    .trim();

  // 2. { 부터 } 까지 추출 (중첩 괄호 고려)
  var start = cleaned.indexOf('{');
  if (start < 0) return null;

  var depth = 0, end = -1;
  for (var i = start; i < cleaned.length; i++) {
    if (cleaned[i] === '{') depth++;
    else if (cleaned[i] === '}') {
      depth--;
      if (depth === 0) { end = i; break; }
    }
  }
  if (end < 0) {
    // 닫는 괄호 부족 → 마지막 } 위치로 보정
    end = cleaned.lastIndexOf('}');
    if (end < start) return null;
  }

  var candidate = cleaned.substring(start, end + 1);

  // 3. JSON 유효성 1차 검사 후 반환
  try {
    JSON.parse(candidate);
    return candidate;
  } catch(e1) {
    // 4. 불완전한 JSON 자동 복구 시도
    // 열린 배열/객체 괄호를 닫아줌
    var fixed = candidate;
    var opens = (fixed.match(/\[/g)||[]).length - (fixed.match(/\]/g)||[]).length;
    var openBraces = (fixed.match(/\{/g)||[]).length - (fixed.match(/\}/g)||[]).length;
    // 마지막 콤마 제거
    fixed = fixed.replace(/,\s*([\]\}])/g, '$1');
    for (var k=0; k<opens; k++)      fixed += ']';
    for (var k=0; k<openBraces; k++) fixed += '}';
    try {
      JSON.parse(fixed);
      return fixed;
    } catch(e2) {
      return candidate; // 복구 실패해도 candidate 반환 (parseAndApply에서 재처리)
    }
  }
}

function parseAndApplyAiResult(raw) {
  document.getElementById('aiLoading').classList.remove('show');

  // raw가 비어있으면 바로 fallback
  if (!raw || !raw.trim()) {
    console.warn('[AI 파싱] 응답이 비어있습니다.');
    runFallback('AI가 빈 응답을 반환했습니다.');
    return;
  }

  console.log('[AI 원본 응답]', raw.substring(0, 500));

  // JSON 추출 (마크다운 코드블록 포함 대응)
  var jsonStr = extractJsonFromRaw(raw);
  if (!jsonStr) {
    console.warn('[AI 파싱] JSON 추출 실패. 원본:', raw.substring(0, 300));
    runFallback('AI 응답에서 JSON 구조를 찾지 못했습니다.');
    return;
  }

  var result;
  try {
    result = JSON.parse(jsonStr);
  } catch(parseErr) {
    console.warn('[AI 파싱] JSON.parse 실패:', parseErr.message, '\n원본:', jsonStr.substring(0, 300));
    runFallback('JSON 파싱 실패: ' + parseErr.message);
    return;
  }

  try {
    // gemma3:1b가 키 이름을 틀리는 경우 대응
    var rawPersons = result.persons || result.person || result.인물 || result.people || [];
    var rawEdges   = result.edges   || result.edge   || result.관계선 || result.relations || result.relationships || [];
    // 배열이 아닌 경우 배열로 감싸기
    if (!Array.isArray(rawPersons)) rawPersons = rawPersons ? [rawPersons] : [];
    if (!Array.isArray(rawEdges))   rawEdges   = rawEdges   ? [rawEdges]   : [];

    // uid 부여 + role 정규화
    var parsedPersons = rawPersons.map(function(p) {
      return {
        id:   uid(),
        name: String(p.name || '').trim(),
        role: normalizeRole(p.role),
        memo: String(p.memo || '').trim()
      };
    }).filter(function(p) { return p.name; }); // 이름 없는 인물 제외
    parsedPersons = applyTranscriptRoleHintsToPersons(parsedPersons);
    parsedPersons = mergePersonsByCompactNameStrongestRole(parsedPersons);

    // 엣지: src/dst 이름 → id 변환 + relType/status 정규화 (이름 공백 무시 매칭)
    var parsedEdges = rawEdges.map(function(e) {
      var srcName = String(e.src || e.srcName || '').trim();
      var dstName = String(e.dst || e.dstName || '').trim();
      var sk = personNameCompactKey(srcName), dk = personNameCompactKey(dstName);
      var sp = parsedPersons.find(function(p) { return personNameCompactKey(p.name) === sk; });
      var dp = parsedPersons.find(function(p) { return personNameCompactKey(p.name) === dk; });
      if (!sp || !dp) return null;
      return {
        id:      uid(),
        src:     sp.id,
        dst:     dp.id,
        relType: normalizeRelType(e.relType),
        status:  normalizeStatus(e.status),
        context: String(e.context || '').trim()
      };
    }).filter(Boolean);

    parsedEdges = dedupeEdges(parsedEdges); // 관계선 중복 제거

    // AI가 edges를 반환하지 않으면 역할 기반 자동 생성
    if (parsedEdges.length === 0 && parsedPersons.length >= 2) {
      var autoSuspects = parsedPersons.filter(function(p){ return p.role==='suspect'; });
      var autoVictims  = parsedPersons.filter(function(p){ return p.role==='victim'; });
      var autoWitness  = parsedPersons.filter(function(p){ return p.role==='witness'; });
      autoSuspects.forEach(function(s) {
        autoVictims.forEach(function(v) {
          parsedEdges.push({id:uid(),src:s.id,dst:v.id,relType:'harm',   status:'unknown',context:''});
        });
        autoWitness.forEach(function(w) {
          parsedEdges.push({id:uid(),src:w.id,dst:s.id,relType:'witness',status:'unknown',context:''});
        });
      });
      // 그래도 없으면 전체 지인 연결
      if (parsedEdges.length === 0) {
        for (var ai=0; ai<parsedPersons.length-1; ai++) {
          parsedEdges.push({id:uid(),src:parsedPersons[ai].id,dst:parsedPersons[ai+1].id,
                            relType:'acquaint',status:'unknown',context:''});
        }
      }
    }

    // DB 저장
    saveToDb(currentCaseId, parsedPersons, parsedEdges, function(ok) {
      var summary = '인물 ' + parsedPersons.length + '명, 관계선 ' + parsedEdges.length + '개 분석 완료';
      if (!ok) summary += ' (DB 저장 실패 — 로컬 표시만)';

      document.getElementById('aiResultBox').classList.add('show');
      document.getElementById('aiResultText').textContent = summary;
      document.getElementById('btnAnalyze').disabled = false;
      showToast('✅ ' + summary);
      showBoardSection(parsedPersons, parsedEdges);
    });

  } catch (e) {
    console.warn('[AI 파싱] 처리 중 예외:', e.message, e.stack);
    runFallback('처리 중 오류: ' + e.message);
  }
}

// ── Fallback: 진술자 메타정보로 인물+관계선 자동 생성 ────────────
function runFallback(reason) {
  var roleMap = {'피의자':'suspect','피해자':'victim','목격자':'witness','참고인':'reference'};
  var fallbackPersons = dedupePersons(
    checkedTranscripts.map(function(t) {
      return { id:uid(), name:t.name||'미입력', role:roleMap[t.type]||'reference', memo:t.type||'' };
    }).filter(function(p){ return p.name && p.name !== '미입력'; })
  );

  var fallbackEdges = [];
  var suspects = fallbackPersons.filter(function(p){ return p.role==='suspect'; });
  var victims  = fallbackPersons.filter(function(p){ return p.role==='victim'; });
  var witnesses= fallbackPersons.filter(function(p){ return p.role==='witness'; });
  suspects.forEach(function(s) {
    victims.forEach(function(v) {
      fallbackEdges.push({id:uid(),src:s.id,dst:v.id,relType:'harm',status:'unknown',context:''});
    });
    witnesses.forEach(function(w) {
      fallbackEdges.push({id:uid(),src:w.id,dst:s.id,relType:'witness',status:'unknown',context:''});
    });
  });
  if (fallbackEdges.length === 0 && fallbackPersons.length >= 2) {
    for (var fi=0; fi<fallbackPersons.length-1; fi++) {
      fallbackEdges.push({id:uid(),src:fallbackPersons[fi].id,dst:fallbackPersons[fi+1].id,
                          relType:'acquaint',status:'unknown',context:''});
    }
  }
  fallbackEdges = dedupeEdges(fallbackEdges);

  var msg = '진술자 역할 기반으로 인물 ' + fallbackPersons.length + '명, 관계선 ' + fallbackEdges.length + '개를 자동 생성했습니다.';
  if (reason) msg = '[' + reason + '] ' + msg;
  document.getElementById('aiResultText').textContent = msg;
  document.getElementById('aiResultBox').classList.add('show');
  document.getElementById('btnAnalyze').disabled = false;

  saveToDb(currentCaseId, fallbackPersons, fallbackEdges, function(ok) {
    showToast(ok ? '✅ 자동 생성 완료' : '⚠ 자동 생성 완료 (DB 저장 실패)');
    showBoardSection(fallbackPersons, fallbackEdges);
  });
}

// ── Pol-mate-Serv /relation_map 실패 시 수동 모드 안내 ───────────
function fallbackManualMode() {
  document.getElementById('aiLoading').classList.remove('show');
  document.getElementById('aiResultBox').classList.add('show');
  document.getElementById('aiResultText').textContent =
    'Pol-mate-Serv(' + POL_MATE_SERV_BASE + ')에 연결할 수 없습니다. app.py 실행·방화벽·CORS·서버의 Ollama(OLLAMA_URL)를 확인한 뒤 다시 시도해 주세요.';
  document.getElementById('btnAnalyze').disabled = false;
  showToast('AI 서버 연결 실패');
  showBoardSection([], []);
}

// ── DB 저장 (boardApi) ───────────────────────────────────────────
function saveToDb(caseId, parsedPersons, parsedEdges, callback) {
  var boardJson = buildBoardJson(parsedPersons, parsedEdges);
  var cid = String(caseId || '').trim();
  // 기존 보드가 있으면 isUpdate 플래그 전달(알림·호환). 서버는 존재 여부로 UPSERT 하지만 클라이언트도 명시.
  fetch('../boardApi?action=load&caseId=' + encodeURIComponent(cid))
    .then(function(r) { return r.ok ? r.json() : {}; })
    .catch(function() { return {}; })
    .then(function(info) {
      var exists = !!(info && info.success && info.boardExists);
      return fetch('../boardApi?action=save', {
        method: 'POST',
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: JSON.stringify({caseId: cid, boardJson: boardJson, isUpdate: exists})
      });
    })
  .then(function(r) {
    if (r.status === 404) {
      console.error('[DB 저장 실패] RelationBoardServlet이 배포되지 않았습니다. RelationBoardServlet.java를 배포하고 relation_boards 테이블을 생성해 주세요.');
      showToast('⚠ DB 저장 실패: RelationBoardServlet 미배포 또는 테이블 미생성');
      return {error: '서블릿 미배포'};
    }
    if (!r.ok) {
      console.error('boardApi save HTTP 오류:', r.status, r.statusText);
      return {error: 'HTTP ' + r.status};
    }
    return r.json();
  })
  .then(function(d) {
    if (!d || d.error || d.success === false) {
      if (d && d.error) console.error('boardApi save 서버 오류:', d.error);
      callback(false);
    } else {
      callback(true);
    }
  })
  .catch(function(err) {
    console.error('boardApi save 네트워크 오류:', err);
    callback(false);
  });
}

var VALID_CTX = ['scene','time','evidence'];
function sanitizeContext(ctx) {
  var v = String(ctx||'').trim();
  return VALID_CTX.indexOf(v) >= 0 ? v : '';
}
function serializePersonsWithLayout(personArr) {
  return (personArr || []).map(function(p) {
    var o = { name: p.name, role: p.role, memo: p.memo || '' };
    var lx, ly;
    if (typeof p._px === 'number' && typeof p._py === 'number' && !isNaN(p._px) && !isNaN(p._py)) {
      lx = p._px; ly = p._py;
    } else if (typeof p._x === 'number' && typeof p._y === 'number' && !isNaN(p._x) && !isNaN(p._y)) {
      lx = p._x; ly = p._y;
    } else if (typeof p.layoutX === 'number' && typeof p.layoutY === 'number') {
      lx = p.layoutX; ly = p.layoutY;
    }
    if (typeof lx === 'number' && !isNaN(lx) && typeof ly === 'number' && !isNaN(ly)) {
      o.layoutX = Math.round(lx * 100) / 100;
      o.layoutY = Math.round(ly * 100) / 100;
    }
    return o;
  });
}

function buildBoardJson(pList, eList) {
  var cleanPersons = dedupePersons(pList);
  var personsOut = serializePersonsWithLayout(cleanPersons);
  var edgesForJson = dedupeEdges(
    eList.map(function(e) {
      var sp = cleanPersons.find(function(p) { return p.id === e.src; });
      var dp = cleanPersons.find(function(p) { return p.id === e.dst; });
      return {srcName:sp?sp.name:'', dstName:dp?dp.name:'',
              relType:e.relType, status:e.status, context:sanitizeContext(e.context)};
    }).filter(function(e) { return e.srcName && e.dstName; })
  );
  return JSON.stringify({persons:personsOut, edges:edgesForJson});
}

// ── STEP 3: 보드 섹션 표시 ──────────────────────────────────────
function showBoardSection(parsedPersons, parsedEdges) {
  persons = parsedPersons;
  edges   = parsedEdges;

  // boardJson을 sessionStorage에 저장 후 boardEdit로 이동
  var edgesForJson = edges.map(function(e) {
    var sp = persons.find(function(p){ return p.id===e.src; });
    var dp = persons.find(function(p){ return p.id===e.dst; });
    return {srcName:sp?sp.name:'', dstName:dp?dp.name:'',
            relType:e.relType, status:e.status, context:sanitizeContext(e.context)};
  }).filter(function(e){ return e.srcName && e.dstName; });

  var boardJson = JSON.stringify({persons:serializePersonsWithLayout(persons), edges:edgesForJson});
  try {
    sessionStorage.setItem('boardEdit_caseId',   currentCaseId);
    sessionStorage.setItem('boardEdit_caseName', currentCaseName);
    sessionStorage.setItem('boardEdit_json',     boardJson);
  } catch(ex) { console.warn('sessionStorage 저장 실패:', ex); }

  // 분석 완료 → 보드 편집 페이지로 이동
  location.href = 'boardEdit?caseId=' + encodeURIComponent(currentCaseId);
}

// ── 인물 그리드 렌더링 ───────────────────────────────────────────
function renderPersonGrid() {
  document.getElementById('personCountBadge').textContent = persons.length + '명';
  var el = document.getElementById('personGrid');
  if (!persons.length) {
    el.innerHTML = '<div style="grid-column:span 2;text-align:center;padding:16px 0;font-size:12px;color:var(--tm);">등록된 인물이 없습니다.</div>';
    return;
  }
  el.innerHTML = persons.map(function(p) {
    return '<div class="person-card">' +
      '<div class="person-avatar" style="background:' + (ROLE_COLOR[p.role]||'#4a7cdc') + '">' + escHtml(p.name.charAt(0)) + '</div>' +
      '<div>' +
        '<div class="person-card-name">' + escHtml(p.name) + '</div>' +
        '<div class="person-card-role role-' + p.role + '">' + (ROLE_LABEL[p.role]||p.role) + '</div>' +
      '</div>' +
    '</div>';
  }).join('');
}

// ── 관계선 리스트 렌더링 ─────────────────────────────────────────
function renderEdgeList() {
  document.getElementById('edgeCountBadge').textContent = edges.length + '개';
  var el = document.getElementById('edgeListView');
  if (!edges.length) {
    el.innerHTML = '<div style="text-align:center;padding:12px 0;font-size:12px;color:var(--tm);">관계선이 없습니다.</div>';
    return;
  }
  el.innerHTML = edges.map(function(e) {
    var sp = persons.find(function(p) { return p.id === e.src; });
    var dp = persons.find(function(p) { return p.id === e.dst; });
    if (!sp || !dp) return '';
    var rt = normalizeRelType(e.relType), st = normalizeStatus(e.status);
    var relBlock;
    if (st === 'mismatch') {
      var sub = REL_LABEL[rt] || e.relType || '';
      relBlock = '<span style="display:block">진술 불일치</span>' +
        (sub ? '<span style="display:block;font-size:11px;opacity:0.88;margin-top:2px">' + escHtml(sub) + '</span>' : '');
    } else {
      relBlock = escHtml((REL_LABEL[rt]||e.relType||'') + (st === 'match' ? ' · 일치' : ''));
    }
    return '<div class="edge-item ' + e.relType + '">' +
      '<div class="edge-names">' + escHtml(sp.name) + '<span class="edge-connector">—</span>' + escHtml(dp.name) + '</div>' +
      '<div class="edge-rel">' + relBlock + '</div>' +
    '</div>';
  }).join('');
}

// ── 보드 팝업 열기 ───────────────────────────────────────────────
var popupCanvas, popupCtx;
var popupScale=1, popupOffsetX=0, popupOffsetY=0;
var popupDragging=false, popupLastX=0, popupLastY=0;
var popupDraggingNode = null;
var miniSelectedRole='', miniSelectedRel='';
var boardExistsInDb = false; // 이미 DB에 저장된 보드가 있는지

function openBoardPopup() {
  if (!persons.length) { showToast('표시할 인물이 없습니다.'); return; }

  // 현재 보드가 DB에 있는지 확인
  fetch('../boardApi?action=load&caseId=' + encodeURIComponent(currentCaseId))
    .then(function(r) { return r.json(); })
    .then(function(d) {
      boardExistsInDb = !!(d.success && d.boardExists);
      document.getElementById('btnPopupSave').style.display   = boardExistsInDb ? 'none' : '';
      document.getElementById('btnPopupUpdate').style.display = boardExistsInDb ? '' : 'none';
    })
    .catch(function() { boardExistsInDb = false; });

  document.getElementById('popupTitle').textContent =
    currentCaseId + ' ' + currentCaseName;
  document.getElementById('boardPopupOverlay').classList.add('open');
  document.body.style.overflow = 'hidden';
  _fdInitialized = false; // 새 보드 열릴 때마다 레이아웃 재계산
  switchPopupTab('canvas');

  setTimeout(function() {
    initPopupCanvas();
    resizePopupCanvas();
    drawPopupCanvas();
  }, 120);
}

function closeBoardPopup() {
  document.getElementById('boardPopupOverlay').classList.remove('open');
  document.body.style.overflow = '';
}

function switchPopupTab(tab) {
  ['canvas','persons','edges'].forEach(function(t) {
    document.getElementById('tabPanel' + t.charAt(0).toUpperCase() + t.slice(1)).style.display = t===tab ? 'block' : 'none';
    document.getElementById('tab' + t.charAt(0).toUpperCase() + t.slice(1)).classList.toggle('active', t===tab);
  });
  if (tab === 'canvas') {
    setTimeout(function() { resizePopupCanvas(); drawPopupCanvas(); }, 80);
  } else if (tab === 'persons') {
    renderPopupPersonList();
    refreshMiniPersonSelects();
  } else if (tab === 'edges') {
    refreshMiniPersonSelects();
    renderPopupEdgeList();
  }
}

// ── 팝업 캔버스: 좌표·히트 테스트 (노드 드래그) ───────────────────
function popupClientToDevice(clientX, clientY) {
  if (!popupCanvas) return {x:0,y:0};
  var rect = popupCanvas.getBoundingClientRect();
  var sx = popupCanvas.width / (rect.width || 1);
  var sy = popupCanvas.height / (rect.height || 1);
  return { x: (clientX - rect.left) * sx, y: (clientY - rect.top) * sy };
}
function popupClientToWorld(clientX, clientY) {
  var d = popupClientToDevice(clientX, clientY);
  return {
    x: (d.x - popupOffsetX * popupScale) / popupScale,
    y: (d.y - popupOffsetY * popupScale) / popupScale
  };
}
function popupHitPerson(wx, wy) {
  var nr = 22, r2 = nr * nr * 1.44;
  for (var i = persons.length - 1; i >= 0; i--) {
    var p = persons[i];
    var dx = wx - p._px, dy = wy - p._py;
    if (dx * dx + dy * dy <= r2) return p;
  }
  return null;
}
function clampPopupPersonNode(p) {
  if (!popupCanvas) return;
  var pad = 52;
  p._px = Math.max(pad, Math.min(popupCanvas.width - pad, p._px));
  p._py = Math.max(pad, Math.min(popupCanvas.height - pad, p._py));
}

// ── 팝업 캔버스 초기화 ────────────────────────────────────────────
function initPopupCanvas() {
  if (popupCanvas) return;
  popupCanvas = document.getElementById('boardPopupCanvas');
  popupCtx = popupCanvas.getContext('2d');

  popupCanvas.addEventListener('mousedown', function(e) {
    if (!persons.length) {
      popupDraggingNode = null;
      popupDragging = true;
    } else {
      var w = popupClientToWorld(e.clientX, e.clientY);
      var hit = popupHitPerson(w.x, w.y);
      if (hit) {
        popupDraggingNode = hit;
        popupDragging = false;
        popupCanvas.style.cursor = 'grabbing';
      } else {
        popupDraggingNode = null;
        popupDragging = true;
      }
    }
    popupLastX = e.clientX;
    popupLastY = e.clientY;
  });
  popupCanvas.addEventListener('mousemove', function(e) {
    if (popupDraggingNode) {
      var w0 = popupClientToWorld(popupLastX, popupLastY);
      var w1 = popupClientToWorld(e.clientX, e.clientY);
      popupDraggingNode._px += w1.x - w0.x;
      popupDraggingNode._py += w1.y - w0.y;
      clampPopupPersonNode(popupDraggingNode);
      popupLastX = e.clientX;
      popupLastY = e.clientY;
      drawPopupCanvas();
      return;
    }
    if (popupDragging) {
      popupOffsetX += (e.clientX - popupLastX) / popupScale;
      popupOffsetY += (e.clientY - popupLastY) / popupScale;
      popupLastX = e.clientX;
      popupLastY = e.clientY;
      drawPopupCanvas();
      return;
    }
    if (persons.length) {
      var wh = popupClientToWorld(e.clientX, e.clientY);
      popupCanvas.style.cursor = popupHitPerson(wh.x, wh.y) ? 'grab' : 'default';
    }
  });
  popupCanvas.addEventListener('mouseup', function() {
    popupDraggingNode = null;
    popupDragging = false;
    popupCanvas.style.cursor = '';
  });
  popupCanvas.addEventListener('mouseleave', function() {
    popupDraggingNode = null;
    popupDragging = false;
    popupCanvas.style.cursor = '';
  });

  var pltx, plty, pld;
  popupCanvas.addEventListener('touchstart', function(e) {
    if (e.touches.length === 2) {
      popupDraggingNode = null;
      popupDragging = false;
      pld = Math.hypot(e.touches[0].clientX - e.touches[1].clientX, e.touches[0].clientY - e.touches[1].clientY);
      e.preventDefault();
      return;
    }
    if (e.touches.length === 1) {
      var t = e.touches[0];
      if (persons.length) {
        var w = popupClientToWorld(t.clientX, t.clientY);
        var hit = popupHitPerson(w.x, w.y);
        if (hit) {
          popupDraggingNode = hit;
          popupDragging = false;
        } else {
          popupDraggingNode = null;
          popupDragging = true;
        }
      } else {
        popupDraggingNode = null;
        popupDragging = true;
      }
      pltx = t.clientX;
      plty = t.clientY;
      popupLastX = t.clientX;
      popupLastY = t.clientY;
    }
    e.preventDefault();
  }, {passive:false});
  popupCanvas.addEventListener('touchmove', function(e) {
    if (e.touches.length === 2) {
      var d = Math.hypot(e.touches[0].clientX - e.touches[1].clientX, e.touches[0].clientY - e.touches[1].clientY);
      popupScale = Math.max(0.4, Math.min(2.5, popupScale * d / pld));
      pld = d;
      drawPopupCanvas();
      e.preventDefault();
      return;
    }
    if (e.touches.length === 1 && popupDraggingNode) {
      var tn = e.touches[0];
      var w0 = popupClientToWorld(pltx, plty);
      var w1 = popupClientToWorld(tn.clientX, tn.clientY);
      popupDraggingNode._px += w1.x - w0.x;
      popupDraggingNode._py += w1.y - w0.y;
      clampPopupPersonNode(popupDraggingNode);
      pltx = tn.clientX;
      plty = tn.clientY;
      drawPopupCanvas();
      e.preventDefault();
      return;
    }
    if (e.touches.length === 1 && popupDragging) {
      var tp = e.touches[0];
      popupOffsetX += (tp.clientX - pltx) / popupScale;
      popupOffsetY += (tp.clientY - plty) / popupScale;
      pltx = tp.clientX;
      plty = tp.clientY;
      drawPopupCanvas();
      e.preventDefault();
    }
  }, {passive:false});
  popupCanvas.addEventListener('touchend', function(e) {
    if (e.touches.length === 0) {
      popupDraggingNode = null;
      popupDragging = false;
    } else if (e.touches.length === 1) {
      var tr = e.touches[0];
      pltx = tr.clientX;
      plty = tr.clientY;
      popupLastX = tr.clientX;
      popupLastY = tr.clientY;
    }
  });
}

function resizePopupCanvas() {
  var w = document.getElementById('popupCanvasWrap');
  if (!w || !popupCanvas) return;
  var prevW = popupCanvas.width, prevH = popupCanvas.height;
  popupCanvas.width  = w.clientWidth;
  popupCanvas.height = 360;
  if (_fdInitialized && persons.length && prevW > 0 && (popupCanvas.width !== prevW || popupCanvas.height !== prevH)) {
    var sx = popupCanvas.width / prevW, sy = popupCanvas.height / prevH;
    persons.forEach(function(p) {
      if (typeof p._px === 'number') {
        p._px *= sx;
        p._py *= sy;
      }
    });
  }
  drawPopupCanvas();
}

// ── 두 노드 쌍 묶기 (방향 무시, 시각적으로 한 선으로 병합) ───────
function edgeUndirectedKey(e) {
  if (e.src < e.dst) return e.src + '\x1e' + e.dst;
  return e.dst + '\x1e' + e.src;
}
function groupEdgesByPair(allEdges) {
  var m = {};
  (allEdges || []).forEach(function(e) {
    var k = edgeUndirectedKey(e);
    if (!m[k]) m[k] = [];
    m[k].push(e);
  });
  return m;
}
function mergeEdgeGroupForDraw(edgeList) {
  var anyMis = false;
  var orderLabs = [];
  var seen = {};
  var nonMisLabs = [];
  var seenNM = {};
  edgeList.forEach(function(e) {
    if (normalizeStatus(e.status) === 'mismatch') anyMis = true;
    var rt = normalizeRelType(e.relType);
    var lab = REL_LABEL[rt] || String(e.relType || '').trim();
    if (lab && !seen[lab]) { seen[lab] = true; orderLabs.push(lab); }
  });
  edgeList.forEach(function(e) {
    if (normalizeStatus(e.status) === 'mismatch') return;
    var rt = normalizeRelType(e.relType);
    var lab = REL_LABEL[rt] || String(e.relType || '').trim();
    if (lab && !seenNM[lab]) { seenNM[lab] = true; nonMisLabs.push(lab); }
  });
  var subMis = nonMisLabs.length ? nonMisLabs.join(' · ') : orderLabs.join(' · ');
  var rts = edgeList.map(function(e) { return normalizeRelType(e.relType); });
  var sameRt = rts.length && rts.every(function(rt) { return rt === rts[0]; });
  var anyHarm = rts.indexOf('harm') >= 0;
  var strokeColor;
  if (anyHarm) strokeColor = REL_COLOR.harm;
  else if (anyMis) strokeColor = EDGE_MISMATCH_STROKE;
  else if (sameRt) strokeColor = REL_COLOR[rts[0]] || '#9ca3af';
  else strokeColor = '#9ca3af';
  return { anyMis: anyMis, subMis: subMis, lines: orderLabs, strokeColor: strokeColor, rep: edgeList[0] };
}

/** 진술 불일치: 1행 + 소글씨(나머지 관계 요약). subText는 한 줄 문자열 */
function paintMismatchEdgeLabel(ctx, lx, ly, subText, sc, bgRgba) {
  sc = sc || 1;
  subText = String(subText || '').trim();
  var fzM = 10 * sc, fzS = 8 * sc, gap = 3 * sc, padX = 4 * sc, padY = 3 * sc;
  ctx.textAlign = 'center';
  var line1 = '진술 불일치';
  ctx.font = fzM + 'px Noto Sans KR,sans-serif';
  var w1 = ctx.measureText(line1).width;
  var w2 = 0;
  if (subText) {
    ctx.font = fzS + 'px Noto Sans KR,sans-serif';
    w2 = ctx.measureText(subText).width;
  }
  var tw = Math.max(w1, w2 || w1, 1);
  var innerH = subText ? fzM + gap + fzS : fzM;
  var boxH = innerH + 2 * padY;
  var y0 = ly - boxH / 2;
  ctx.fillStyle = bgRgba || 'rgba(13,26,51,0.6)';
  ctx.fillRect(lx - tw / 2 - padX, y0, tw + 2 * padX, boxH);
  ctx.fillStyle = 'rgba(255,255,255,0.92)';
  ctx.font = fzM + 'px Noto Sans KR,sans-serif';
  ctx.fillText(line1, lx, y0 + padY + fzM * 0.72);
  if (subText) {
    ctx.fillStyle = 'rgba(255,255,255,0.7)';
    ctx.font = fzS + 'px Noto Sans KR,sans-serif';
    ctx.fillText(subText, lx, y0 + padY + fzM + gap + fzS * 0.72);
  }
}

/** 진술 불일치 아님·동일 쌍 다중 관계: 줄마다 한 관계명 */
function paintMultilineRelLabels(ctx, lx, ly, lines, sc, bgRgba) {
  if (!lines || !lines.length) return;
  sc = sc || 1;
  var fz = 10 * sc, gap = 2 * sc, padX = 4 * sc, padY = 3 * sc;
  ctx.textAlign = 'center';
  var maxW = 0;
  lines.forEach(function(line) {
    ctx.font = fz + 'px Noto Sans KR,sans-serif';
    maxW = Math.max(maxW, ctx.measureText(line).width);
  });
  var innerH = lines.length * fz + (lines.length - 1) * gap;
  var boxH = innerH + 2 * padY;
  var y0 = ly - boxH / 2;
  ctx.fillStyle = bgRgba || 'rgba(10,20,50,0.75)';
  ctx.fillRect(lx - maxW / 2 - padX, y0, maxW + 2 * padX, boxH);
  ctx.fillStyle = 'rgba(255,255,255,0.92)';
  lines.forEach(function(line, i) {
    ctx.font = fz + 'px Noto Sans KR,sans-serif';
    var y = y0 + padY + fz * 0.72 + i * (fz + gap);
    ctx.fillText(line, lx, y);
  });
}

// ── Force-directed 레이아웃 초기화 ──────────────────────────────
var _fdInitialized = false; // 현재 사건 기준 초기화 여부

function getPersonDegreeMapRM(list, edgeList) {
  var deg = {};
  (list || []).forEach(function(p) { deg[p.id] = 0; });
  (edgeList || []).forEach(function(e) {
    if (typeof deg[e.src] === 'number') deg[e.src] += 1;
    if (typeof deg[e.dst] === 'number') deg[e.dst] += 1;
  });
  return deg;
}
function pickCenterSuspectRM(list, edgeList) {
  var suspects = (list || []).filter(function(p) { return p.role === 'suspect'; });
  if (!suspects.length) return null;
  var deg = getPersonDegreeMapRM(list, edgeList);
  return suspects.reduce(function(best, cur) {
    var bDeg = deg[best.id] || 0, cDeg = deg[cur.id] || 0;
    if (cDeg !== bDeg) return cDeg > bDeg ? cur : best;
    return String(cur.name || '').localeCompare(String(best.name || '')) < 0 ? cur : best;
  });
}
function isDirectlyLinkedRM(aId, bId) {
  return edges.some(function(e) {
    return (e.src === aId && e.dst === bId) || (e.src === bId && e.dst === aId);
  });
}
function ringAngleSpreadRM(index, count) {
  if (count <= 1) return -Math.PI / 2;
  var span = Math.min(5.15, 2.6 + Math.max(0, count - 2) * 0.14);
  var start = -Math.PI / 2 - span / 2;
  return start + (span * index / (count - 1));
}
function stableUnitFromKeyRM(key) {
  var s = String(key || '');
  var h = 2166136261;
  for (var i = 0; i < s.length; i++) {
    h ^= s.charCodeAt(i);
    h = (h * 16777619) >>> 0;
  }
  return (h >>> 0) / 4294967295;
}

function initForceLayout(canvasW, canvasH) {
  var cx = canvasW / 2, cy = canvasH / 2;
  var n = persons.length;
  if (!n) return;
  var centerSuspect = pickCenterSuspectRM(persons, edges);
  var deg = getPersonDegreeMapRM(persons, edges);
  var minDim = Math.min(canvasW, canvasH);
  var area = Math.max(canvasW * canvasH, 1);
  var k0 = Math.sqrt(area / Math.max(n, 1)) * 0.82;
  var innerR = Math.min(minDim * 0.27, k0 * Math.sqrt(Math.max(n, 2)) * 0.37);
  var outerR = Math.min(minDim * 0.35, k0 * Math.sqrt(Math.max(n, 2)) * 0.51);
  var jitter = k0 * 0.16;

  persons.forEach(function(p, i) {
    var hasPos = typeof p._px === 'number' && typeof p._py === 'number' && !isNaN(p._px) && !isNaN(p._py);
    var lx = Number(p.layoutX), ly = Number(p.layoutY);
    if (hasPos) {
      /* 이미 화면 좌표 있음(드래그·이전 팝업) — 유지 */
    } else if (!isNaN(lx) && !isNaN(ly)) {
      p._px = lx;
      p._py = ly;
    } else {
      p._px = NaN;
      p._py = NaN;
    }
    p._vx = 0; p._vy = 0;
  });
  var unpositioned = persons.filter(function(p) {
    return typeof p._px !== 'number' || typeof p._py !== 'number' || isNaN(p._px) || isNaN(p._py);
  });
  if (centerSuspect && unpositioned.indexOf(centerSuspect) >= 0) {
    centerSuspect._px = cx; centerSuspect._py = cy;
    centerSuspect._vx = 0; centerSuspect._vy = 0;
  }
  if (unpositioned.length) {
    var others = unpositioned.filter(function(p) { return !centerSuspect || p.id !== centerSuspect.id; });
    var firstRing = centerSuspect
      ? others.filter(function(p) { return isDirectlyLinkedRM(centerSuspect.id, p.id); })
      : others.slice();
    var secondRing = others.filter(function(p) { return firstRing.indexOf(p) < 0; });
    firstRing.sort(function(a, b) {
      var ad = deg[a.id] || 0, bd = deg[b.id] || 0;
      if (ad !== bd) return bd - ad;
      return String(a.name || '').localeCompare(String(b.name || ''));
    });
    secondRing.sort(function(a, b) {
      var ad = deg[a.id] || 0, bd = deg[b.id] || 0;
      if (ad !== bd) return bd - ad;
      return String(a.name || '').localeCompare(String(b.name || ''));
    });
    firstRing.forEach(function(p, i) {
      var a = ringAngleSpreadRM(i, firstRing.length);
      var seed = personNameCompactKey(p.name) || p.id;
      var jx = stableUnitFromKeyRM(seed + '|ix|' + i) - 0.5;
      var jy = stableUnitFromKeyRM(seed + '|iy|' + i) - 0.5;
      p._px = cx + Math.cos(a) * innerR + jx * jitter * 0.65;
      p._py = cy + Math.sin(a) * innerR + jy * jitter * 0.65;
      p._vx = 0; p._vy = 0;
    });
    secondRing.forEach(function(p, i) {
      var a = ringAngleSpreadRM(i, secondRing.length);
      var seed = personNameCompactKey(p.name) || p.id;
      var jx = stableUnitFromKeyRM(seed + '|ox|' + i) - 0.5;
      var jy = stableUnitFromKeyRM(seed + '|oy|' + i) - 0.5;
      p._px = cx + Math.cos(a) * outerR + jx * jitter;
      p._py = cy + Math.sin(a) * outerR + jy * jitter;
      p._vx = 0; p._vy = 0;
    });
  }
  if (n === 1) {
    var p0 = persons[0];
    var h = typeof p0._px === 'number' && typeof p0._py === 'number' && !isNaN(p0._px) && !isNaN(p0._py);
    if (!h) {
      var lx0 = Number(p0.layoutX), ly0 = Number(p0.layoutY);
      if (!isNaN(lx0) && !isNaN(ly0)) {
        p0._px = lx0; p0._py = ly0;
      } else {
        p0._px = cx; p0._py = cy;
      }
    }
  }
  _fdInitialized = true;
}

function runForceStep(canvasW, canvasH) {
  var n = persons.length;
  if (n < 2) return;
  var area = Math.max(canvasW * canvasH, 1);
  var k = Math.sqrt(area / n) * 0.82;
  var repulseK = k * k;
  var attract = 0.052;
  var damping = 0.86;
  var cx = canvasW / 2, cy = canvasH / 2;
  var padding = 52;
  var grav = 0.018;
  var centerSuspect = pickCenterSuspectRM(persons, edges);
  var minNodeGap = 58;
  var collideK = 0.24;

  persons.forEach(function(p) { p._fx = 0; p._fy = 0; });

  for (var i = 0; i < n; i++) {
    for (var j = i + 1; j < n; j++) {
      var pi = persons[i], pj = persons[j];
      var dx = pi._px - pj._px, dy = pi._py - pj._py;
      var dist = Math.sqrt(dx * dx + dy * dy);
      if (dist < 0.01) dist = 0.01;
      var force = repulseK / dist;
      var fx = (dx / dist) * force, fy = (dy / dist) * force;
      pi._fx += fx; pi._fy += fy;
      pj._fx -= fx; pj._fy -= fy;
      if (dist < minNodeGap) {
        var push = (minNodeGap - dist) * collideK;
        var cfx = (dx / dist) * push, cfy = (dy / dist) * push;
        pi._fx += cfx; pi._fy += cfy;
        pj._fx -= cfx; pj._fy -= cfy;
      }
    }
  }

  edges.forEach(function(e) {
    var sp = persons.find(function(p){ return p.id === e.src; });
    var dp = persons.find(function(p){ return p.id === e.dst; });
    if (!sp || !dp) return;
    var dx = dp._px - sp._px, dy = dp._py - sp._py;
    var dist = Math.sqrt(dx * dx + dy * dy);
    if (dist < 0.01) dist = 0.01;
    var force = attract * (dist - k);
    var fx = (dx / dist) * force, fy = (dy / dist) * force;
    sp._fx += fx; sp._fy += fy;
    dp._fx -= fx; dp._fy -= fy;
  });
  if (centerSuspect) {
    var neigh = persons.filter(function(p) { return p.id !== centerSuspect.id && isDirectlyLinkedRM(centerSuspect.id, p.id); });
    for (var aIdx = 0; aIdx < neigh.length; aIdx++) {
      for (var bIdx = aIdx + 1; bIdx < neigh.length; bIdx++) {
        var n1 = neigh[aIdx], n2 = neigh[bIdx];
        var v1x = n1._px - centerSuspect._px, v1y = n1._py - centerSuspect._py;
        var v2x = n2._px - centerSuspect._px, v2y = n2._py - centerSuspect._py;
        var d1 = Math.sqrt(v1x * v1x + v1y * v1y), d2 = Math.sqrt(v2x * v2x + v2y * v2y);
        if (d1 < 0.01 || d2 < 0.01) continue;
        var cosA = (v1x * v2x + v1y * v2y) / (d1 * d2);
        if (cosA < -0.92) {
          var opp = Math.min(1, (-cosA - 0.92) / 0.08);
          var tx = -v1y / d1, ty = v1x / d1;
          var am = opp * 0.92;
          n1._fx += tx * am; n1._fy += ty * am;
          n2._fx -= tx * am; n2._fy -= ty * am;
        }
      }
    }
  }

  persons.forEach(function(p) {
    p._fx += (cx - p._px) * grav;
    p._fy += (cy - p._py) * grav;
    if (centerSuspect && p.id === centerSuspect.id) {
      p._fx += (cx - p._px) * 0.52;
      p._fy += (cy - p._py) * 0.52;
    }
  });

  var vmax = k * 0.38;
  persons.forEach(function(p) {
    p._vx = (p._vx + p._fx) * damping;
    p._vy = (p._vy + p._fy) * damping;
    var v = Math.sqrt(p._vx * p._vx + p._vy * p._vy);
    if (v > vmax && v > 0) {
      p._vx *= vmax / v;
      p._vy *= vmax / v;
    }
    p._px = Math.max(padding, Math.min(canvasW - padding, p._px + p._vx));
    p._py = Math.max(padding, Math.min(canvasH - padding, p._py + p._vy));
    if (centerSuspect && p.id === centerSuspect.id) {
      p._px = cx; p._py = cy;
      p._vx = 0; p._vy = 0;
    }
  });
}

function preRunForce(canvasW, canvasH) {
  for (var i = 0; i < 300; i++) runForceStep(canvasW, canvasH);
}

function drawPopupCanvas() {
  var c = popupCanvas, ctx = popupCtx;
  if (!c || !ctx) return;
  ctx.clearRect(0,0,c.width,c.height);
  ctx.fillStyle='#0d1a33'; ctx.fillRect(0,0,c.width,c.height);
  if (!persons.length) {
    ctx.fillStyle='rgba(255,255,255,0.3)'; ctx.font='13px Noto Sans KR,sans-serif';
    ctx.textAlign='center'; ctx.fillText('인물이 없습니다', c.width/2, c.height/2);
    return;
  }

  // 레이아웃 초기화: 저장 좌표가 전부 있으면 힘 시뮬 생략
  if (!_fdInitialized) {
    initForceLayout(c.width, c.height);
    var allSaved = persons.length && persons.every(function(p) {
      var lx = Number(p.layoutX), ly = Number(p.layoutY);
      return !isNaN(lx) && !isNaN(ly);
    });
    if (!allSaved) {
      preRunForce(c.width, c.height);
    }
  }

  ctx.save();

  // offset 적용 (드래그)
  ctx.translate(popupOffsetX * popupScale, popupOffsetY * popupScale);
  ctx.scale(popupScale, popupScale);

  // 관계선 (동일 노드 쌍은 한 줄로 병합)
  var pairMap = groupEdgesByPair(edges);
  Object.keys(pairMap).forEach(function(k) {
    var group = pairMap[k];
    var ids = k.split('\x1e');
    var sp = persons.find(function(p){ return p.id===ids[0]; }),
        dp = persons.find(function(p){ return p.id===ids[1]; });
    if (!sp || !dp) return;
    drawEdgeScaled(ctx, sp, dp, group);
  });

  // 노드
  persons.forEach(function(p) {
    var nr = 22;
    ctx.beginPath(); ctx.arc(p._px, p._py, nr, 0, 2*Math.PI);
    ctx.fillStyle = ROLE_COLOR[p.role] || '#4a7cdc'; ctx.fill();
    ctx.strokeStyle = '#fff'; ctx.lineWidth = 2.5; ctx.stroke();
    ctx.font = 'bold 11px Noto Sans KR,sans-serif';
    ctx.fillStyle = '#fff'; ctx.textAlign = 'center';
    ctx.fillText(p.name.length>3 ? p.name.substr(0,3)+'…' : p.name, p._px, p._py + 4);
    ctx.font = '9px Noto Sans KR,sans-serif'; ctx.fillStyle = 'rgba(255,255,255,0.75)';
    ctx.fillText(ROLE_LABEL[p.role]||'', p._px, p._py + nr + 13);
  });

  ctx.restore();
}

// scale 1 기준 · edgeGroup = 동일 노드 쌍의 엣지 배열
function drawEdgeScaled(ctx, sp, dp, edgeGroup) {
  var merged = mergeEdgeGroupForDraw(edgeGroup);
  var strokeC = merged.strokeColor;

  ctx.lineWidth   = 2;
  ctx.strokeStyle = strokeC;
  ctx.setLineDash([]);

  var mx  = (sp._px + dp._px) / 2;
  var my  = (sp._py + dp._py) / 2;
  var dx  = dp._px - sp._px, dy = dp._py - sp._py;
  var len = Math.sqrt(dx*dx + dy*dy) || 1;

  ctx.beginPath();
  ctx.moveTo(sp._px, sp._py);
  ctx.lineTo(dp._px, dp._py);
  ctx.stroke();

  var lx = mx, ly = my;
  var perpX = -(dy / len), perpY = (dx / len);
  lx += perpX * 12;
  ly += perpY * 12;

  ctx.textAlign = 'center';
  if (merged.anyMis) {
    paintMismatchEdgeLabel(ctx, lx, ly, merged.subMis, 1, 'rgba(10,20,50,0.75)');
  } else if (merged.lines.length > 1) {
    paintMultilineRelLabels(ctx, lx, ly, merged.lines, 1, 'rgba(10,20,50,0.75)');
  } else if (merged.lines.length === 1) {
    var label = merged.lines[0];
    ctx.font = '10px Noto Sans KR,sans-serif';
    var tw = ctx.measureText(label).width;
    ctx.fillStyle = 'rgba(10,20,50,0.75)';
    ctx.beginPath();
    ctx.roundRect ? ctx.roundRect(lx-tw/2-4, ly-9, tw+8, 13, 3)
                  : ctx.rect(lx-tw/2-4, ly-9, tw+8, 13);
    ctx.fill();
    ctx.fillStyle = '#fff';
    ctx.fillText(label, lx, ly);
  }
}

function popupZoomIn()    { var s=popupScale; s=Math.min(2.5,s+0.2); popupScale=s; drawPopupCanvas(); }
function popupZoomOut()   { var s=popupScale; s=Math.max(0.4,s-0.2); popupScale=s; drawPopupCanvas(); }
function popupResetView() { popupScale=1; popupOffsetX=0; popupOffsetY=0; popupDraggingNode=null; popupDragging=false; drawPopupCanvas(); }

// ── 팝업 인물 목록 렌더링 ─────────────────────────────────────────
function renderPopupPersonList() {
  var el = document.getElementById('popupPersonList');
  if (!persons.length) {
    el.innerHTML = '<div style="text-align:center;padding:16px;font-size:12px;color:var(--tm);">등록된 인물이 없습니다.</div>';
    return;
  }
  el.innerHTML = '';
  persons.forEach(function(p) {
    var item = document.createElement('div');
    item.className = 'popup-person-item';

    // 아바타
    var avatar = document.createElement('div');
    avatar.style.cssText = 'background:' + (ROLE_COLOR[p.role]||'#4a7cdc') + ';width:34px;height:34px;border-radius:50%;display:flex;align-items:center;justify-content:center;font-size:12px;font-weight:700;color:#fff;flex-shrink:0;';
    avatar.textContent = p.name.charAt(0);

    // 정보
    var info = document.createElement('div');
    info.style.cssText = 'flex:1;min-width:0;';
    info.innerHTML =
      '<div style="font-size:13px;font-weight:500;color:var(--tp);">' + escHtml(p.name) + '</div>' +
      '<div style="font-size:11px;color:' + (ROLE_COLOR[p.role]||'#4a7cdc') + ';">' + (ROLE_LABEL[p.role]||p.role) + (p.memo ? ' · ' + escHtml(p.memo) : '') + '</div>';

    // 버튼 영역
    var actions = document.createElement('div');
    actions.style.cssText = 'display:flex;gap:5px;';

    // 편집 버튼
    var editBtn = document.createElement('button');
    editBtn.className = 'popup-person-btn';
    editBtn.title = '편집';
    editBtn.innerHTML = '<svg viewBox="0 0 24 24" fill="none" stroke-width="2" stroke-linecap="round" width="13" height="13" stroke="var(--ts)"><path d="M11 4H4a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-7"/><path d="M18.5 2.5a2.121 2.121 0 0 1 3 3L12 15l-4 1 1-4 9.5-9.5z"/></svg>';

    // 삭제 버튼
    var delBtn = document.createElement('button');
    delBtn.className = 'popup-person-btn del';
    delBtn.title = '삭제';
    delBtn.innerHTML = '<svg viewBox="0 0 24 24" fill="none" stroke-width="2" stroke-linecap="round" width="13" height="13" stroke="var(--danger)"><polyline points="3 6 5 6 21 6"/><path d="M19 6l-1 14H6L5 6"/><path d="M10 11v6"/><path d="M14 11v6"/></svg>';

    // 편집 이벤트 — 폼에 값 채우기
    (function(pid) {
      editBtn.addEventListener('click', function() {
        var person = persons.find(function(x){ return x.id === pid; });
        if (!person) return;
        document.getElementById('miniPersonName').value = person.name;
        document.getElementById('miniPersonMemo').value = person.memo || '';
        selectMiniRole(person.role);
        // 편집 모드 표시
        document.getElementById('miniPersonName').dataset.editId = pid;
        document.getElementById('miniFormTitle').textContent = '인물 편집';
        document.getElementById('miniAddBtn').textContent = '수정 완료';
        document.getElementById('miniPersonName').focus();
        // 폼으로 스크롤
        document.querySelector('.mini-form').scrollIntoView({behavior:'smooth', block:'start'});
      });
    })(p.id);

    // 삭제 이벤트
    (function(pid, pname) {
      delBtn.addEventListener('click', function() {
        if (!confirm('"' + pname + '"을(를) 삭제하면 관련 관계선도 삭제됩니다.')) return;
        persons = persons.filter(function(x) { return x.id !== pid; });
        edges   = edges.filter(function(e) { return e.src !== pid && e.dst !== pid; });
        renderPersonGrid(); renderEdgeList();
        renderPopupPersonList(); renderPopupEdgeList();
        drawPopupCanvas();
        autoSaveBoard();
      });
    })(p.id, p.name);

    actions.appendChild(editBtn);
    actions.appendChild(delBtn);
    item.appendChild(avatar);
    item.appendChild(info);
    item.appendChild(actions);
    el.appendChild(item);
  });
}

// ── 팝업 관계선 목록 렌더링 ──────────────────────────────────────
function renderPopupEdgeList() {
  var el = document.getElementById('popupEdgeList');
  if (!edges.length) {
    el.innerHTML = '<div style="text-align:center;padding:16px;font-size:12px;color:var(--tm);">관계선이 없습니다.</div>';
    return;
  }
  el.innerHTML = '';
  edges.forEach(function(e) {
    var sp = persons.find(function(p){return p.id===e.src;}),
        dp = persons.find(function(p){return p.id===e.dst;});
    if (!sp||!dp) return;
    var rt = normalizeRelType(e.relType), st = normalizeStatus(e.status);
    var edgeAccent = (rt === 'harm') ? REL_COLOR.harm : (st === 'mismatch' ? EDGE_MISMATCH_STROKE : (REL_COLOR[rt]||'#9ca3af'));
    var subRel = REL_LABEL[rt] || e.relType || '';
    var subHtml = st === 'mismatch'
      ? ('<span style="display:block;color:var(--tp)">진술 불일치</span>' +
         (subRel ? '<span style="display:block;font-size:10px;color:var(--tm);margin-top:2px">' + escHtml(subRel) + '</span>' : ''))
      : escHtml(subRel + (st === 'match' ? ' · 일치' : ''));
    var item = document.createElement('div');
    item.className = 'popup-edge-item ' + e.relType;
    item.style.cssText = 'display:flex;align-items:center;gap:8px;padding:10px 13px;background:var(--card);border-radius:12px;border:1px solid var(--bd);border-left:3px solid ' + edgeAccent + ';margin-bottom:8px;';
    var info = document.createElement('div');
    info.style.flex='1';
    info.innerHTML =
      '<div style="font-size:13px;font-weight:500;color:var(--tp);">' + escHtml(sp.name) + ' — ' + escHtml(dp.name) + '</div>' +
      '<div style="font-size:11px;color:var(--tm);margin-top:2px;">' + subHtml + '</div>';
    var delBtn = document.createElement('button');
    delBtn.style.cssText = 'width:26px;height:26px;border-radius:7px;background:var(--danger-bg);border:1px solid var(--danger-bd);display:flex;align-items:center;justify-content:center;cursor:pointer;flex-shrink:0;';
    delBtn.innerHTML = '<svg viewBox="0 0 24 24" fill="none" stroke="#dc2626" stroke-width="2" stroke-linecap="round" width="12" height="12"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg>';
    (function(eid, sn, dn) {
      delBtn.addEventListener('click', function() {
        if (!confirm('"' + sn + ' — ' + dn + '" 관계선을 삭제할까요?')) return;
        edges = edges.filter(function(x) { return x.id !== eid; });
        renderEdgeList(); renderPopupEdgeList(); drawPopupCanvas();
        autoSaveBoard();
      });
    })(e.id, sp.name, dp.name);
    item.appendChild(info);
    item.appendChild(delBtn);
    el.appendChild(item);
  });
}

// ── 미니 인물 추가 폼 ─────────────────────────────────────────────
function selectMiniRole(r) {
  miniSelectedRole = r;
  ['suspect','victim','witness','reference'].forEach(function(k) {
    var btn = document.getElementById('mrole-'+k);
    if (btn) btn.className = 'mini-role-btn' + (k===r?' sel-'+k:'');
  });
}
function clearMiniPersonForm() {
  var nameEl = document.getElementById('miniPersonName');
  nameEl.value = '';
  delete nameEl.dataset.editId;
  document.getElementById('miniPersonMemo').value = '';
  document.getElementById('miniFormTitle').textContent = '인물 추가';
  document.getElementById('miniAddBtn').textContent = '추가';
  miniSelectedRole = '';
  ['suspect','victim','witness','reference'].forEach(function(k) {
    document.getElementById('mrole-'+k).className = 'mini-role-btn';
  });
}
function addMiniPerson() {
  var nameEl  = document.getElementById('miniPersonName');
  var name    = nameEl.value.trim();
  var memo    = document.getElementById('miniPersonMemo').value.trim();
  var editId  = nameEl.dataset.editId || '';

  if (!name) { showToast('이름을 입력하세요.'); return; }
  if (!miniSelectedRole) miniSelectedRole = 'reference'; // 미선택 시 참고인으로 기본 설정

  // 편집 모드가 아닐 때만 중복 이름 체크
  if (!editId) {
    var duplicate = persons.find(function(p) {
      return p.name.trim().toLowerCase() === name.toLowerCase();
    });
    if (duplicate) { showToast('"' + name + '"은(는) 이미 등록된 인물입니다.'); return; }
  }

  if (editId) {
    // ── 편집 모드: 기존 인물 수정 ──
    var person = persons.find(function(p){ return p.id === editId; });
    if (person) {
      person.name = name;
      person.role = miniSelectedRole;
      person.memo = memo;
    }
    showToast('인물이 수정됐습니다.');
  } else {
    // ── 추가 모드: 신규 인물 등록 ──
    var np = {id:uid(), name:name, role:miniSelectedRole, memo:memo};
    persons.push(np);
    if (popupCanvas && popupCanvas.width) {
      np._px = popupCanvas.width / 2;
      np._py = popupCanvas.height / 2;
    }
    showToast('인물 추가 완료 — 저장 중...');
  }

  clearMiniPersonForm();
  renderPersonGrid(); renderPopupPersonList(); refreshMiniPersonSelects(); drawPopupCanvas();
  autoSaveBoard();
}

// ── 미니 관계선 추가 폼 ───────────────────────────────────────────
function refreshMiniPersonSelects() {
  var opts = '<option value="">선택</option>' + persons.map(function(p) {
    return '<option value="' + p.id + '">' + escHtml(p.name) + ' (' + (ROLE_LABEL[p.role]||'') + ')</option>';
  }).join('');
  document.getElementById('miniEdgeSrc').innerHTML = opts;
  document.getElementById('miniEdgeDst').innerHTML = opts;
}
function selectMiniRel(r) {
  miniSelectedRel = r;
  ['accomplice','harm','witness','acquaint','family'].forEach(function(k) {
    var btn = document.getElementById('mrel-'+k);
    if (btn) btn.className = 'mini-role-btn' + (k===r?' sel-active':'');
  });
}
function clearMiniEdgeForm() {
  document.getElementById('miniEdgeSrc').value = '';
  document.getElementById('miniEdgeDst').value = '';
  miniSelectedRel = '';
  ['accomplice','harm','witness','acquaint','family'].forEach(function(k) {
    document.getElementById('mrel-'+k).className = 'mini-role-btn';
  });
}
function addMiniEdge() {
  var src = document.getElementById('miniEdgeSrc').value;
  var dst = document.getElementById('miniEdgeDst').value;
  if (!src)             { showToast('출발 인물을 선택하세요.'); return; }
  if (!dst)             { showToast('도착 인물을 선택하세요.'); return; }
  if (src === dst)      { showToast('같은 인물을 선택할 수 없습니다.'); return; }
  if (!miniSelectedRel) { showToast('관계 유형을 선택하세요.'); return; }
  edges.push({id:uid(), src:src, dst:dst, relType:miniSelectedRel, status:'unknown', context:''});
  clearMiniEdgeForm();
  renderEdgeList(); renderPopupEdgeList(); refreshMiniPersonSelects(); drawPopupCanvas();
  showToast('관계선 추가 완료 — 저장 중...');
  autoSaveBoard();
}

// ── 보드 저장 / 업데이트 (팝업에서) ─────────────────────────────
// ── 자동 저장 (편집 후 즉시 DB 반영) ────────────────────────────
var _autoSaveTimer = null;
function autoSaveBoard() {
  // 300ms 디바운스: 연속 편집 시 마지막 한 번만 저장
  clearTimeout(_autoSaveTimer);
  _autoSaveTimer = setTimeout(function() {
    if (!currentCaseId || !persons.length) return;
    var edgesForJson = edges.map(function(e) {
      var sp = persons.find(function(p){return p.id===e.src;}),
          dp = persons.find(function(p){return p.id===e.dst;});
      return {srcName:sp?sp.name:'',dstName:dp?dp.name:'',
              relType:e.relType,status:e.status,context:sanitizeContext(e.context)};
    }).filter(function(e){return e.srcName&&e.dstName;});

    var boardJson = JSON.stringify({persons:serializePersonsWithLayout(persons), edges:edgesForJson});
    fetch('../boardApi?action=save', {
      method:'POST',
      headers:{'Content-Type':'application/json; charset=UTF-8'},
      body: JSON.stringify({caseId:currentCaseId, boardJson:boardJson, isUpdate:boardExistsInDb})
    })
    .then(function(r){ return r.ok ? r.json() : r.text().then(function(t){throw new Error(t);}); })
    .then(function(d){
      if (!d.error) {
        boardExistsInDb = true;
        // 버튼 상태 업데이트
        document.getElementById('btnPopupSave').style.display   = 'none';
        document.getElementById('btnPopupUpdate').style.display = '';
        document.getElementById('btnPopupUpdate').innerHTML =
          '<svg viewBox="0 0 24 24" fill="none" stroke-width="2" stroke-linecap="round" style="width:15px;height:15px;stroke:#fff"><polyline points="20 6 9 17 4 12"/></svg> 저장됨';
        document.getElementById('btnPopupUpdate').disabled = false;
        // 2초 후 원래 텍스트로
        setTimeout(function() {
          document.getElementById('btnPopupUpdate').innerHTML =
            '<svg viewBox="0 0 24 24" fill="none" stroke-width="2" stroke-linecap="round" style="width:15px;height:15px;stroke:#fff"><polyline points="1 4 1 10 7 10"/><path d="M3.51 15a9 9 0 1 0 .49-3.5"/></svg>보드 업데이트';
        }, 2000);
      }
    })
    .catch(function(err){ console.error('자동 저장 실패:', err.message); });
  }, 300);
}

function saveBoardFromPopup(isUpdate) {
  if (!currentCaseId) { showToast('사건이 선택되지 않았습니다.'); return; }
  if (!persons.length) { showToast('등록된 인물이 없습니다.'); return; }

  if (isUpdate) {
    if (!confirm('기존 보드는 삭제되고 현재 보드로 업데이트됩니다.\n계속하시겠습니까?')) return;
  }

  var edgesForJson = edges.map(function(e) {
    var sp = persons.find(function(p){return p.id===e.src;}),
        dp = persons.find(function(p){return p.id===e.dst;});
    return {srcName:sp?sp.name:'', dstName:dp?dp.name:'',
            relType:e.relType, status:e.status, context:sanitizeContext(e.context)};
  }).filter(function(e){return e.srcName&&e.dstName;});

  var boardJson = JSON.stringify({persons:serializePersonsWithLayout(persons), edges:edgesForJson});

  // 버튼 상태 저장 (innerHTML까지 보존)
  var saveBtnId = isUpdate ? 'btnPopupUpdate' : 'btnPopupSave';
  var saveBtn   = document.getElementById(saveBtnId);
  var origHTML  = saveBtn.innerHTML;
  saveBtn.disabled  = true;
  saveBtn.innerHTML = '<span style="display:flex;align-items:center;justify-content:center;gap:6px;">' +
    '<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="#fff" stroke-width="2" stroke-linecap="round">' +
    '<circle cx="12" cy="12" r="10"/><path d="M12 6v6l4 2"/></svg>저장 중...</span>';

  // 타임아웃 처리 (10초 이상 응답 없으면 복원)
  var timeoutId = setTimeout(function() {
    saveBtn.disabled = false;
    saveBtn.innerHTML = origHTML;
    showToast('⚠ 저장 시간 초과. 서버 응답이 없습니다.');
  }, 10000);

  fetch('../boardApi?action=save', {
    method:'POST',
    headers:{'Content-Type':'application/json; charset=UTF-8'},
    body: JSON.stringify({caseId:currentCaseId, boardJson:boardJson, isUpdate:isUpdate})
  })
  .then(function(r) {
    if (!r.ok) {
      // HTTP 오류 시 텍스트로 읽어서 로그
      return r.text().then(function(txt) {
        throw new Error('HTTP ' + r.status + ' — ' + txt.substring(0, 100));
      });
    }
    return r.json();
  })
  .then(function(d) {
    clearTimeout(timeoutId);
    saveBtn.disabled = false;
    if (d.error) {
      saveBtn.innerHTML = origHTML;
      showToast('❌ 저장 실패: ' + d.error);
      console.error('boardApi 저장 실패:', d.error);
      return;
    }
    // 저장 성공
    saveBtn.innerHTML = '<span style="display:flex;align-items:center;justify-content:center;gap:6px;">' +
      '<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="#fff" stroke-width="2" stroke-linecap="round"><polyline points="20 6 9 17 4 12"/></svg>' +
      (isUpdate ? '업데이트 완료' : '저장 완료') + '</span>';
    showToast('✅ ' + (d.message || (isUpdate ? '보드가 업데이트됐습니다.' : '보드가 저장됐습니다.')));
    boardExistsInDb = true;
    // 저장 버튼 → 업데이트 버튼으로 교체
    document.getElementById('btnPopupSave').style.display   = 'none';
    document.getElementById('btnPopupUpdate').style.display = '';
    document.getElementById('btnPopupUpdate').innerHTML =
      '<svg viewBox="0 0 24 24" fill="none" stroke-width="2" stroke-linecap="round" style="width:15px;height:15px;stroke:#fff"><polyline points="1 4 1 10 7 10"/><path d="M3.51 15a9 9 0 1 0 .49-3.5"/></svg>보드 업데이트';
    document.getElementById('btnPopupUpdate').disabled = false;
    if (isUpdate) {
      setTimeout(function() {
        location.href = 'main';
      }, 500);
    }
  })
  .catch(function(err) {
    clearTimeout(timeoutId);
    saveBtn.disabled = false;
    saveBtn.innerHTML = origHTML;
    console.error('boardApi 저장 오류:', err.message);
    if (err.message && err.message.indexOf('HTTP 404') >= 0) {
      showToast('❌ RelationBoardServlet 미배포 — Eclipse에서 서블릿을 배포하세요.');
    } else {
      showToast('❌ 저장 오류: ' + err.message);
    }
  });
}

// ── (구) drawBoard는 openBoardPopup으로 대체됨 ───────────────────
function drawBoard() { openBoardPopup(); }

// ── 캔버스 ───────────────────────────────────────────────────────
var canvas, ctx, scale=1, offsetX=0, offsetY=0, isDragging=false, lastX=0, lastY=0;

window.addEventListener('load', function() {
  canvas = document.getElementById('relationCanvas');
  if (!canvas) return;
  ctx = canvas.getContext('2d');
  resizeCanvas();

  canvas.addEventListener('mousedown',  function(e) { isDragging=true; lastX=e.clientX; lastY=e.clientY; });
  canvas.addEventListener('mousemove',  function(e) { if(!isDragging)return; offsetX+=(e.clientX-lastX)/scale; offsetY+=(e.clientY-lastY)/scale; lastX=e.clientX; lastY=e.clientY; drawCanvas(); });
  canvas.addEventListener('mouseup',    function()  { isDragging=false; });
  canvas.addEventListener('mouseleave', function()  { isDragging=false; });

  var ltx, lty, ld;
  canvas.addEventListener('touchstart', function(e) {
    if(e.touches.length===1){ltx=e.touches[0].clientX;lty=e.touches[0].clientY;}
    if(e.touches.length===2){ld=Math.hypot(e.touches[0].clientX-e.touches[1].clientX,e.touches[0].clientY-e.touches[1].clientY);}
    e.preventDefault();
  },{passive:false});
  canvas.addEventListener('touchmove', function(e) {
    if(e.touches.length===1){offsetX+=(e.touches[0].clientX-ltx)/scale;offsetY+=(e.touches[0].clientY-lty)/scale;ltx=e.touches[0].clientX;lty=e.touches[0].clientY;drawCanvas();}
    if(e.touches.length===2){var d=Math.hypot(e.touches[0].clientX-e.touches[1].clientX,e.touches[0].clientY-e.touches[1].clientY);scale=Math.max(0.4,Math.min(2.5,scale*d/ld));ld=d;drawCanvas();}
    e.preventDefault();
  },{passive:false});
});

function resizeCanvas() {
  var w = document.getElementById('canvasWrap');
  if (!w || !canvas) return;
  canvas.width  = w.clientWidth;
  canvas.height = 340;
  drawCanvas();
}

function drawCanvas() {
  if (!ctx) return;
  ctx.clearRect(0, 0, canvas.width, canvas.height);
  ctx.fillStyle = '#0d1a33';
  ctx.fillRect(0, 0, canvas.width, canvas.height);

  if (!persons.length) {
    ctx.fillStyle = 'rgba(255,255,255,0.3)';
    ctx.font = '13px Noto Sans KR,sans-serif';
    ctx.textAlign = 'center';
    ctx.fillText('보드 그리기를 누르면 관계망이 표시됩니다', canvas.width/2, canvas.height/2);
    return;
  }

  if (!_fdInitialized) {
    initForceLayout(canvas.width, canvas.height);
    var allSaved = persons.length && persons.every(function(p) {
      var lx = Number(p.layoutX), ly = Number(p.layoutY);
      return !isNaN(lx) && !isNaN(ly);
    });
    if (!allSaved) preRunForce(canvas.width, canvas.height);
  }
  persons.forEach(function(p) {
    p._x = p._px + offsetX * scale;
    p._y = p._py + offsetY * scale;
  });

  ctx.save();

  var pairMapMini = groupEdgesByPair(edges);
  Object.keys(pairMapMini).forEach(function(pk) {
    var group = pairMapMini[pk];
    var idsM = pk.split('\x1e');
    var sp = persons.find(function(p){return p.id===idsM[0];}),
        dp = persons.find(function(p){return p.id===idsM[1];});
    if (!sp||!dp) return;
    var merged = mergeEdgeGroupForDraw(group);
    ctx.beginPath(); ctx.moveTo(sp._x,sp._y); ctx.lineTo(dp._x,dp._y);
    ctx.lineWidth = 2*scale;
    ctx.setLineDash([]);
    ctx.strokeStyle = merged.strokeColor;
    ctx.stroke();

    var mx=(sp._x+dp._x)/2, my=(sp._y+dp._y)/2;
    var ang = Math.atan2(dp._y - sp._y, dp._x - sp._x);
    var perpX=-Math.sin(ang), perpY=Math.cos(ang);
    mx += perpX*10*scale; my += perpY*10*scale;
    ctx.textAlign='center';
    if (merged.anyMis) {
      paintMismatchEdgeLabel(ctx, mx, my, merged.subMis, scale, 'rgba(13,26,51,0.55)');
    } else if (merged.lines.length > 1) {
      paintMultilineRelLabels(ctx, mx, my, merged.lines, scale, 'rgba(13,26,51,0.55)');
    } else if (merged.lines.length === 1) {
      ctx.font=(10*scale)+'px Noto Sans KR,sans-serif';
      ctx.fillStyle='rgba(255,255,255,0.75)';
      ctx.fillText(merged.lines[0], mx, my);
    }
  });

  // 인물 노드 그리기
  persons.forEach(function(p) {
    var nr = 20*scale;
    ctx.beginPath(); ctx.arc(p._x, p._y, nr, 0, 2*Math.PI);
    ctx.fillStyle = ROLE_COLOR[p.role]||'#4a7cdc'; ctx.fill();
    ctx.strokeStyle='#fff'; ctx.lineWidth=2*scale; ctx.stroke();
    ctx.font='bold '+(11*scale)+'px Noto Sans KR,sans-serif';
    ctx.fillStyle='#fff'; ctx.textAlign='center';
    ctx.fillText(p.name.length>3?p.name.substr(0,3)+'…':p.name, p._x, p._y+4*scale);
    ctx.font=(9*scale)+'px Noto Sans KR,sans-serif'; ctx.fillStyle='rgba(255,255,255,0.7)';
    ctx.fillText(ROLE_LABEL[p.role]||'', p._x, p._y+nr+12*scale);
  });

  ctx.restore();
}

function relationZoomIn()    { scale=Math.min(2.5,scale+0.2); drawCanvas(); }
function relationZoomOut()   { scale=Math.max(0.4,scale-0.2); drawCanvas(); }
function relationResetView() { scale=1; offsetX=0; offsetY=0; drawCanvas(); }

// ── 유틸 ─────────────────────────────────────────────────────────
function uid() { return Math.random().toString(36).substr(2,9); }

// ── 인물 중복 제거 (이름 기준, 대소문자/공백 무시) ───────────────
function dedupePersons(arr) {
  var seen = {};
  return arr.filter(function(p) {
    var key = p.name.trim().toLowerCase();
    if (!key) return false;
    if (seen[key]) return false;
    seen[key] = true;
    return true;
  });
}

// ── 관계선 중복 제거 (src+dst+relType 기준) ───────────────────────
function dedupeEdges(arr) {
  var seen = {};
  return arr.filter(function(e) {
    var key = e.src + '|' + e.dst + '|' + e.relType;
    if (seen[key]) return false;
    seen[key] = true;
    return true;
  });
}
function escHtml(s) { return String(s||'').replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;'); }
function showToast(msg) {
  var t = document.getElementById('toast');
  t.textContent = msg;
  t.style.opacity='1'; t.style.transform='translateX(-50%) translateY(0)';
  setTimeout(function() { t.style.opacity='0'; t.style.transform='translateX(-50%) translateY(20px)'; }, 2500);
}

window.addEventListener('resize', resizeCanvas);

// ── 사건 목록 AJAX 로드 ────────────────────────────────────────────
function loadCasePanel() {
  var boot = document.getElementById('_relationPageBoot');
  var initCaseId    = boot ? boot.getAttribute('data-case-id') || '' : '';
  var initOpenBoard = boot ? boot.getAttribute('data-open-board') === 'true' : false;
  var initDocIds    = boot ? (boot.getAttribute('data-doc-ids') || '').split(',').map(function(s){ return s.trim(); }).filter(Boolean) : [];

  var card = document.getElementById('caseSelectCard');
  fetch('../caseApi?action=caseList', {credentials: 'same-origin'})
    .then(function(r) { return r.json(); })
    .then(function(data) {
      var cases = Array.isArray(data) ? data : [];
      if (!cases.length) {
        card.innerHTML = '<div class="empty-box"><div class="empty-icon-wrap"><svg viewBox="0 0 24 24" fill="none" stroke-width="1.8" stroke-linecap="round"><path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/><polyline points="14 2 14 8 20 8"/></svg></div><div class="empty-title">담당 사건이 없습니다</div><div class="empty-desc">사건 등록 후 관계망을 분석할 수 있습니다.</div></div>';
        return;
      }
      card.innerHTML = '';
      cases.forEach(function(c) {
        var cid = String(c.id || c.caseId || '');
        var cname = String(c.name || c.caseName || '');
        var status = String(c.status || '진행중');
        var badgeCls = status === '진행중' ? 'badge-active' : status === '완료' ? 'badge-done' : status === '모순탐지' ? 'badge-danger' : 'badge-warn';
        var el = document.createElement('div');
        el.className = 'case-item';
        el.id = 'caseItem_' + cid.replace(/-/g, '_');
        el.innerHTML = '<div class="case-icon"><svg viewBox="0 0 24 24" fill="none" stroke-width="1.8" stroke-linecap="round"><path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/><polyline points="14 2 14 8 20 8"/></svg></div><div class="case-info"><div class="case-id">' + escHtml(cid) + '</div><div class="case-name">' + escHtml(cname) + '</div></div><span class="case-badge ' + badgeCls + '">' + escHtml(status) + '</span><div class="case-arrow"><svg viewBox="0 0 24 24" fill="none" stroke-width="2" stroke-linecap="round"><polyline points="9 18 15 12 9 6"/></svg></div>';
        el.addEventListener('click', function() { selectCase(cid, cname); });
        card.appendChild(el);
      });

      if (!initCaseId) return;
      var target = cases.find(function(c) { return String(c.id || c.caseId || '') === initCaseId; });
      if (!target) return;
      var caseName = String(target.name || target.caseName || '');
      selectCase(initCaseId, caseName);

      // 선택된 조서 자동 체크
      if (initDocIds.length > 0) {
        var maxTry = 30, tried = 0;
        var checkTimer = setInterval(function() {
          tried++;
          var allFound = initDocIds.every(function(id) {
            return document.getElementById('tr_' + id) !== null;
          });
          if (allFound) {
            clearInterval(checkTimer);
            initDocIds.forEach(function(id) {
              var el = document.getElementById('tr_' + id);
              if (el && !el.classList.contains('checked')) {
                el.click();
              }
            });
          } else if (tried >= maxTry) {
            clearInterval(checkTimer);
          }
        }, 150);
      }

      if (initOpenBoard) {
        // 보드 직접 편집: AI 분석 없이 기존 DB 보드 불러와서 팝업 오픈
        fetch('../boardApi?action=load&caseId=' + encodeURIComponent(initCaseId))
          .then(function(r) { return r.json(); })
          .then(function(data) {
            if (!data.success || !data.boardExists) {
              showToast('저장된 보드가 없습니다. 먼저 AI 분석을 진행해 주세요.');
              return;
            }
            var bj;
            try { bj = JSON.parse(data.boardJson); } catch(e) { bj = {}; }

            var loadedPersons = (bj.persons || []).map(function(p) {
              var o = {id:uid(), name:p.name||'', role:p.role||'reference', memo:p.memo||''};
              var lx = Number(p.layoutX), ly = Number(p.layoutY);
              if (!isNaN(lx) && !isNaN(ly)) { o.layoutX = lx; o.layoutY = ly; }
              return o;
            }).filter(function(p){ return p.name; });

            var loadedEdges = (bj.edges || []).map(function(e) {
              var srcN = e.srcName || e.src || '';
              var dstN = e.dstName || e.dst || '';
              var sk = personNameCompactKey(srcN), dk = personNameCompactKey(dstN);
              var sp = loadedPersons.find(function(p){ return personNameCompactKey(p.name) === sk; });
              var dp = loadedPersons.find(function(p){ return personNameCompactKey(p.name) === dk; });
              if (!sp || !dp) return null;
              return {id:uid(), src:sp.id, dst:dp.id,
                      relType:e.relType||'acquaint', status:e.status||'unknown', context:''};
            }).filter(Boolean);

            showBoardSection(loadedPersons, loadedEdges);
          })
          .catch(function() {
            showToast('보드를 불러오지 못했습니다.');
          });
      }
    })
    .catch(function() {
      card.innerHTML = '<div style="text-align:center;padding:20px;font-size:12px;color:var(--tm);">사건 목록을 불러오지 못했습니다.</div>';
    });
}
loadCasePanel();
</script>
</body>
</html>
