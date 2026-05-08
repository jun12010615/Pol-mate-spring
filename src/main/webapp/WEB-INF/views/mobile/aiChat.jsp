<%@ page language="java" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8"%>
<%@ page import="java.util.*, java.text.*" %>
<!DOCTYPE html>
<html lang="ko">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
<title>POL-MATE | AI 수사 보조</title>
<link href="https://fonts.googleapis.com/css2?family=Noto+Sans+KR:wght@300;400;500;700&display=swap" rel="stylesheet">
<style>
  * { margin:0; padding:0; box-sizing:border-box; -webkit-tap-highlight-color:transparent; }
  :root{
    --deep:#0d1a33; --navy:#1a2744; --mid:#243358;
    --bubble-user:#0d1a33; --bubble-ai:#ffffff;
    --gold:#f0c040; --gold2:#e6b830;
    --blue:#4a7cdc; --accent:#4a7cdc; --danger:#dc2626;
    --tp:#1a1a2e; --ts:#6b7280; --tm:#9ca3af;
    --bg:#f0f2f8; --card:#ffffff; --bd:#e2e5ee;
    --success:#16a34a; --success-bg:#f0fdf4; --success-bd:#bbf7d0;
    --warn-bg:#fffbeb; --warn-text:#92400e;
    --danger-bg:#fef2f2; --danger-bd:#fecaca;
    --info-bg:#eff6ff; --info-text:#1e40af;
  }
  html,body { height:100%; font-family:'Noto Sans KR',sans-serif; background:var(--bg); overflow:hidden; }

  .screen {
    width:100%; max-width:420px; height:100vh;
    margin:0 auto; background:var(--bg);
    display:flex; flex-direction:column;
    position:relative;
  }

  /* ── 헤더 ── */
  .top-header {
    background:var(--deep); padding:52px 20px 14px;
    display:flex; align-items:center; gap:12px;
    flex-shrink:0; position:relative; z-index:10;
  }
  .back-btn { width:36px; height:36px; border-radius:50%; background:rgba(255,255,255,0.12); border:none; display:flex; align-items:center; justify-content:center; cursor:pointer; flex-shrink:0; }
  .back-btn svg { width:18px; height:18px; stroke:#fff; }
  .header-center { flex:1; }
  .header-title  { font-size:16px; font-weight:500; color:#fff; }
  .header-status { display:flex; align-items:center; gap:5px; margin-top:3px; }
  .status-dot    { width:6px; height:6px; border-radius:50%; }
  .status-dot.on  { background:#4ade80; animation:pulse 2s infinite; }
  .status-dot.off { background:#9ca3af; }
  .status-text   { font-size:10px; }
  .status-text.on  { color:#4ade80; }
  .status-text.off { color:rgba(255,255,255,0.45); }
  .btn-clear { background:rgba(255,255,255,0.12); border:1px solid rgba(255,255,255,0.2); color:#fff; border-radius:20px; padding:6px 12px; font-size:11px; font-family:'Noto Sans KR',sans-serif; cursor:pointer; white-space:nowrap; }

  /* ── 카테고리 칩 ── */
  .cat-wrap { background:var(--deep); padding:0 0 14px; flex-shrink:0; position:relative; }
  .cat-scroll-wrap { display:flex; align-items:center; gap:0; position:relative; }
  .cat-row  {
    display:flex; gap:6px; overflow-x:auto; -ms-overflow-style:none; scrollbar-width:none;
    -webkit-overflow-scrolling:touch; padding:0 16px; flex:1;
    scroll-behavior:smooth;
  }
  .cat-row::-webkit-scrollbar { display:none; }
  .cat-chip {
    flex-shrink:0; padding:6px 12px; border-radius:20px; font-size:11px;
    border:1px solid rgba(255,255,255,0.2); color:rgba(255,255,255,0.6);
    background:none; cursor:pointer; white-space:nowrap; font-family:'Noto Sans KR',sans-serif;
    transition:all 0.15s;
  }
  .cat-chip.active { background:rgba(255,255,255,0.2); color:#fff; border-color:rgba(255,255,255,0.4); }

  /* 좌우 스크롤 버튼 */
  .cat-arrow {
    width:28px; height:28px; border-radius:50%; flex-shrink:0;
    background:rgba(255,255,255,0.15); border:1px solid rgba(255,255,255,0.2);
    display:flex; align-items:center; justify-content:center;
    cursor:pointer; transition:background 0.15s; z-index:1;
  }
  .cat-arrow:hover  { background:rgba(255,255,255,0.25); }
  .cat-arrow:active { background:rgba(255,255,255,0.35); }
  .cat-arrow svg { width:13px; height:13px; stroke:#fff; stroke-width:2.5; }
  .cat-arrow.left  { margin-left:8px; }
  .cat-arrow.right { margin-right:8px; }
  .cat-arrow.hidden { opacity:0; pointer-events:none; }

  /* ── 채팅 영역 ── */
  .chat-wrap {
    flex:1; overflow-y:auto; padding:16px 16px 90px;
    display:flex; flex-direction:column; gap:14px;
    scroll-behavior:smooth;
  }

  /* 날짜 구분선 */
  .date-divider { display:flex; align-items:center; gap:10px; }
  .date-divider span { font-size:10px; color:var(--tm); white-space:nowrap; }
  .date-divider::before, .date-divider::after { content:''; flex:1; height:1px; background:var(--bd); }

  /* AI 웰컴 메시지 */
  .welcome-card {
    background:var(--card); border-radius:18px 18px 18px 4px;
    border:1px solid var(--bd); padding:16px;
    max-width:88%; animation:fadeUp 0.4s ease both;
  }
  .welcome-logo { display:flex; align-items:center; gap:8px; margin-bottom:10px; }
  .logo-dot { width:28px; height:28px; background:var(--navy); border-radius:8px; display:flex; align-items:center; justify-content:center; flex-shrink:0; }
  .logo-dot svg { width:14px; height:14px; stroke:#fff; }
  .logo-name { font-size:12px; font-weight:500; color:var(--navy); }
  .welcome-text { font-size:13px; color:var(--tp); line-height:1.8; margin-bottom:12px; }
  .suggest-label { font-size:10px; color:var(--tm); margin-bottom:7px; font-weight:500; text-transform:uppercase; letter-spacing:0.5px; }
  .suggest-list { display:flex; flex-direction:column; gap:5px; }
  .suggest-btn {
    background:var(--bg); border:1px solid var(--bd); border-radius:10px;
    padding:9px 12px; font-size:12px; color:var(--ts);
    text-align:left; cursor:pointer; font-family:'Noto Sans KR',sans-serif;
    transition:background 0.15s; display:flex; align-items:center; gap:7px;
  }
  .suggest-btn svg { width:13px; height:13px; stroke:var(--accent); flex-shrink:0; }
  .suggest-btn:active { background:var(--bd); }

  /* 메시지 공통 */
  .msg-row { display:flex; align-items:flex-end; gap:8px; }
  .msg-row.user { flex-direction:row-reverse; }

  .avatar-sm {
    width:28px; height:28px; border-radius:50%;
    display:flex; align-items:center; justify-content:center;
    font-size:10px; font-weight:500; flex-shrink:0;
  }
  .avatar-ai   { background:var(--navy); }
  .avatar-ai svg { width:14px; height:14px; stroke:#fff; }
  .avatar-user { background:var(--accent); color:#fff; }

  .bubble {
    max-width:82%; padding:12px 15px; border-radius:18px;
    font-size:13px; line-height:1.8; word-break:keep-all;
    animation:fadeUp 0.25s ease both;
  }
  .bubble.ai {
    background:var(--bubble-ai); border:1px solid var(--bd);
    color:var(--tp); border-radius:18px 18px 18px 4px;
  }
  .bubble.user {
    background:var(--bubble-user); color:#fff;
    border-radius:18px 18px 4px 18px;
    word-break:break-all; white-space:pre-wrap;
    min-width:60px; max-width:82%;
  }
  .bubble-meta { font-size:10px; color:var(--tm); margin-top:4px; padding:0 4px; }
  .msg-row.user .bubble-meta { text-align:right; }

  /* 오류 버블 */
  .bubble.error { background:#fef2f2; border:1px solid #fecaca; color:var(--danger); }

  /* 카테고리 태그 (AI 버블 위) */
  .cat-tag { font-size:10px; background:var(--info-bg); color:var(--info-text); border-radius:5px; padding:2px 7px; margin-bottom:5px; display:inline-block; }

  /* 로딩 버블 */
  .typing-bubble { background:var(--card); border:1px solid var(--bd); border-radius:18px 18px 18px 4px; padding:14px 16px; display:inline-flex; align-items:center; gap:5px; }
  .dot { width:6px; height:6px; border-radius:50%; background:var(--tm); animation:bounce 1.2s infinite; }
  .dot:nth-child(2) { animation-delay:0.2s; }
  .dot:nth-child(3) { animation-delay:0.4s; }

  /* Ollama 오프라인 배너 */
  .offline-banner {
    background:#fef3c7; border:1px solid #fde68a; border-radius:12px;
    padding:10px 14px; display:flex; align-items:center; gap:10px;
    margin:0 0 4px; font-size:11px; color:#92400e; line-height:1.6;
    flex-shrink:0;
  }
  .offline-banner svg { width:14px; height:14px; stroke:#f59e0b; flex-shrink:0; }

  /* ── 입력 영역 ── */
  .input-area {
    background:var(--card); border-top:1px solid var(--bd);
    padding:10px 12px 10px;
    flex-shrink:0;
    position:sticky; bottom:64px; z-index:50;
  }
  .input-row { display:flex; gap:8px; align-items:flex-end; }
  .input-box {
    flex:1; background:var(--bg); border:1px solid var(--bd); border-radius:14px;
    padding:11px 14px; font-size:13px; font-family:'Noto Sans KR',sans-serif;
    color:var(--tp); outline:none; resize:none; max-height:100px;
    line-height:1.6; transition:border-color 0.2s; overflow-y:auto;
  }
  .input-box:focus { border-color:var(--accent); background:#fff; }
  .input-box::placeholder { color:var(--tm); }
  .send-btn {
    width:40px; height:40px; border-radius:50%; background:var(--navy); border:none;
    display:flex; align-items:center; justify-content:center; cursor:pointer;
    flex-shrink:0; transition:transform 0.1s, background 0.15s;
  }
  .send-btn:active  { transform:scale(0.92); }
  .send-btn:disabled { background:var(--bd); cursor:not-allowed; }
  .send-btn svg { width:16px; height:16px; stroke:#fff; }

  /* ── 하단 네비 ── */
  .bottom-nav{
  position:fixed;bottom:0;left:50%;transform:translateX(-50%);
  width:100%;max-width:420px;height:64px;
  background:#ffffff;border-top:1px solid #e2e5ee;
  display:flex;z-index:100;
}
.nav-item{flex:1;display:flex;flex-direction:column;align-items:center;justify-content:center;gap:3px;text-decoration:none;color:#9ca3af;cursor:pointer;border:none;background:none;font-family:'Noto Sans KR',sans-serif;}
.nav-item.active{color:var(--deep);}
.nav-item.active .nav-label{font-weight:600;}
.nav-icon{width:22px;height:22px;display:flex;align-items:center;justify-content:center;}
.nav-icon svg{width:20px;height:20px;stroke:currentColor;fill:none;stroke-width:1.8;stroke-linecap:round;}
.nav-label{font-size:10px;}

  @keyframes fadeUp  { from{opacity:0;transform:translateY(8px)} to{opacity:1;transform:translateY(0)} }
  @keyframes bounce  { 0%,80%,100%{transform:translateY(0)} 40%{transform:translateY(-6px)} }
  @keyframes pulse   { 0%,100%{opacity:1} 50%{opacity:0.4} }
  @media(min-width:421px){ .screen{box-shadow:0 0 40px rgba(0,0,0,0.1);} }
</style>
</head>
<body>

<%
  // 서블릿에서 전달된 값
  String result    = (String) request.getAttribute("result");
  String prevMsg   = (String) request.getAttribute("userMsg");
  String category  = (String) request.getAttribute("category");
  Boolean ollamaOk = (Boolean) request.getAttribute("ollamaOk");

  boolean hasResult  = (result != null && !result.isEmpty());
  boolean isOffline  = (hasResult && result.startsWith("[OFFLINE]"));
  boolean isError    = (hasResult && result.startsWith("[오류]"));

  // 현재 시간
  java.text.SimpleDateFormat sdf = new java.text.SimpleDateFormat("HH:mm");
  String nowTime = sdf.format(new java.util.Date());

  // 세션에서 사용자 이름 가져오기
  HttpSession userSession = request.getSession(false);
  String userName = "";
  if (userSession != null) {
    Object nameObj = userSession.getAttribute("userName");
    if (nameObj != null) userName = nameObj.toString();
  }
  String userInitial = userName.length() >= 1 ? String.valueOf(userName.charAt(0)) : "U";
%>

<div class="screen">

  <!-- 헤더 -->
  <div class="top-header">
    <button class="back-btn" onclick="history.back()">
      <svg viewBox="0 0 24 24" fill="none" stroke-width="2" stroke-linecap="round"><polyline points="15 18 9 12 15 6"/></svg>
    </button>
    <div class="header-center">
      <div class="header-title">AI 수사 보조</div>
      <div class="header-status">
        <% if (Boolean.TRUE.equals(ollamaOk)) { %>
          <div class="status-dot on"></div>
          <span class="status-text on">Ollama 연결됨 · gemma3:1b</span>
        <% } else if (hasResult && isOffline) { %>
          <div class="status-dot off"></div>
          <span class="status-text off">Ollama 오프라인</span>
        <% } else { %>
          <div class="status-dot on"></div>
          <span class="status-text on">gemma3:1b 대기 중</span>
        <% } %>
      </div>
    </div>
    <button class="btn-clear" onclick="clearChat()">대화 초기화</button>
  </div>

  <!-- 카테고리 칩 -->
  <div class="cat-wrap">
    <div class="cat-scroll-wrap">
      <button class="cat-arrow left hidden" id="catLeft" onclick="scrollCat(-1)">
        <svg viewBox="0 0 24 24" fill="none" stroke-linecap="round"><polyline points="15 18 9 12 15 6"/></svg>
      </button>
      <div class="cat-row" id="catRow" onscroll="updateArrows()">
        <button class="cat-chip <%= (category == null || category.isEmpty()) ? "active" : "" %>" onclick="setCategory(this,'')">전체</button>
        <button class="cat-chip <%= "미란다".equals(category) ? "active" : "" %>" onclick="setCategory(this,'미란다')">미란다 원칙</button>
        <button class="cat-chip <%= "체포구속".equals(category) ? "active" : "" %>" onclick="setCategory(this,'체포구속')">체포·구속</button>
        <button class="cat-chip <%= "조서작성".equals(category) ? "active" : "" %>" onclick="setCategory(this,'조서작성')">조서 작성</button>
        <button class="cat-chip <%= "압수수색".equals(category) ? "active" : "" %>" onclick="setCategory(this,'압수수색')">압수·수색</button>
        <button class="cat-chip <%= "증거".equals(category) ? "active" : "" %>" onclick="setCategory(this,'증거')">증거법</button>
        <button class="cat-chip <%= "인권".equals(category) ? "active" : "" %>" onclick="setCategory(this,'인권')">피의자 인권</button>
      </div>
      <button class="cat-arrow right" id="catRight" onclick="scrollCat(1)">
        <svg viewBox="0 0 24 24" fill="none" stroke-linecap="round"><polyline points="9 18 15 12 9 6"/></svg>
      </button>
    </div>
  </div>

  <!-- 채팅창 -->
  <div class="chat-wrap" id="chatWrap">

    <div class="date-divider"><span><%= new java.text.SimpleDateFormat("yyyy년 M월 d일").format(new java.util.Date()) %></span></div>

    <!-- 웰컴 메시지 -->
    <% if (!hasResult) { %>
    <div>
      <div class="welcome-card">
        <div class="welcome-logo">
          <div class="logo-dot">
            <svg viewBox="0 0 24 24" fill="none" stroke-width="2" stroke-linecap="round"><circle cx="12" cy="12" r="10"/><path d="M12 8v4l3 3"/></svg>
          </div>
          <span class="logo-name">POL-MATE AI</span>
        </div>
        <div class="welcome-text">안녕하세요, <%= userName %> 수사관님.<br>형사사법 절차, 법령 해석, 수사 기법 등<br>무엇이든 질문하세요.</div>
        <div class="suggest-label">추천 질문</div>
        <div class="suggest-list">
          <button class="suggest-btn" onclick="fillInput('피의자가 묵비권을 행사할 때 수사관의 대처 방법은?')">
            <svg viewBox="0 0 24 24" fill="none" stroke-width="1.8" stroke-linecap="round"><circle cx="12" cy="12" r="10"/><line x1="12" y1="8" x2="12" y2="12"/><line x1="12" y1="16" x2="12.01" y2="16"/></svg>
            피의자가 묵비권을 행사할 때 대처 방법은?
          </button>
          <button class="suggest-btn" onclick="fillInput('긴급체포 요건과 절차를 설명해줘')">
            <svg viewBox="0 0 24 24" fill="none" stroke-width="1.8" stroke-linecap="round"><path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"/></svg>
            긴급체포 요건과 절차를 설명해줘
          </button>
          <button class="suggest-btn" onclick="fillInput('압수수색영장 없이 핸드폰을 확인할 수 있는 경우는?')">
            <svg viewBox="0 0 24 24" fill="none" stroke-width="1.8" stroke-linecap="round"><circle cx="11" cy="11" r="8"/><line x1="21" y1="21" x2="16.65" y2="16.65"/></svg>
            영장 없이 핸드폰을 확인할 수 있는 경우는?
          </button>
          <button class="suggest-btn" onclick="fillInput('자백의 증거능력이 인정되려면 어떤 조건이 필요한가요?')">
            <svg viewBox="0 0 24 24" fill="none" stroke-width="1.8" stroke-linecap="round"><path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/><polyline points="14 2 14 8 20 8"/></svg>
            자백의 증거능력이 인정되려면?
          </button>
        </div>
      </div>
    </div>
    <% } %>

    <!-- 이전 대화 결과 (서블릿 응답) -->
    <% if (hasResult && prevMsg != null && !prevMsg.isEmpty()) { %>

      <!-- Ollama 오프라인 배너 -->
      <% if (isOffline) { %>
      <div class="offline-banner">
        <svg viewBox="0 0 24 24" fill="none" stroke-width="1.8" stroke-linecap="round"><path d="M10.29 3.86L1.82 18a2 2 0 0 0 1.71 3h16.94a2 2 0 0 0 1.71-3L13.71 3.86a2 2 0 0 0-3.42 0z"/><line x1="12" y1="9" x2="12" y2="13"/><line x1="12" y1="17" x2="12.01" y2="17"/></svg>
        <span>Ollama 서버 미연결. 터미널에서 <strong>ollama run gemma3:1b</strong> 실행 후 재시도하세요.</span>
      </div>
      <% } %>

      <!-- 사용자 버블 -->
      <div class="msg-row user">
        <div>
          <div class="bubble user"><%= prevMsg.replace("<","&lt;").replace(">","&gt;") %></div>
          <div class="bubble-meta"><%= nowTime %></div>
        </div>
        <div class="avatar-sm avatar-user"><%= userInitial %></div>
      </div>

      <!-- AI 버블 -->
      <div class="msg-row">
        <div class="avatar-sm avatar-ai">
          <svg viewBox="0 0 24 24" fill="none" stroke-width="2" stroke-linecap="round"><circle cx="12" cy="12" r="10"/><path d="M12 8v4l3 3"/></svg>
        </div>
        <div>
          <% if (category != null && !category.isEmpty()) { %>
            <div class="cat-tag"><%= category %></div>
          <% } %>
          <div class="bubble ai <%= isError || isOffline ? "error" : "" %>">
            <%= result.replace("<","&lt;").replace(">","&gt;").replace("\n","<br>") %>
          </div>
          <div class="bubble-meta"><%= nowTime %> · gemma3:1b</div>
        </div>
      </div>

    <% } %>

    <!-- 로딩 placeholder (JS 제어) -->
    <div id="typingRow" class="msg-row" style="display:none;">
      <div class="avatar-sm avatar-ai">
        <svg viewBox="0 0 24 24" fill="none" stroke-width="2" stroke-linecap="round"><circle cx="12" cy="12" r="10"/><path d="M12 8v4l3 3"/></svg>
      </div>
      <div class="typing-bubble">
        <div class="dot"></div><div class="dot"></div><div class="dot"></div>
      </div>
    </div>

  </div><!-- /chat-wrap -->

  <!-- 입력창 -->
  <div class="input-area">
    <form id="chatForm">
      <input type="hidden" name="category" id="categoryInput" value="<%= category != null ? category : "" %>">
      <div class="input-row">
        <textarea
          name="userMsg"
          id="msgInput"
          class="input-box"
          rows="1"
          placeholder="수사 관련 질문을 입력하세요..."
          oninput="autoResize(this)"></textarea>
        <button type="button" class="send-btn" id="sendBtn" onclick="handleSubmit()">
          <svg viewBox="0 0 24 24" fill="none" stroke-width="2" stroke-linecap="round"><line x1="22" y1="2" x2="11" y2="13"/><polygon points="22 2 15 22 11 13 2 9 22 2"/></svg>
        </button>
      </div>
    </form>
  </div>

  <!-- 하단 네비 -->
  <nav class="bottom-nav">
  <a href="main" class="nav-item">
    <div class="nav-icon"><svg viewBox="0 0 24 24"><path d="M3 9l9-7 9 7v11a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"/><polyline points="9 22 9 12 15 12 15 22"/></svg></div>
    <span class="nav-label">홈</span>
  </a>
  <a href="myCase" class="nav-item">
    <div class="nav-icon"><svg viewBox="0 0 24 24"><path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/><polyline points="14 2 14 8 20 8"/></svg></div>
    <span class="nav-label">사건</span>
  </a>
  <a href="../askAI" class="nav-item active">
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


<script>
var selectedCategory = '<%= category != null ? category : "" %>';

// ── 카테고리 좌우 스크롤
function scrollCat(dir) {
  document.getElementById('catRow').scrollLeft += dir * 120;
}
function updateArrows() {
  var row   = document.getElementById('catRow');
  var left  = document.getElementById('catLeft');
  var right = document.getElementById('catRight');
  left.classList.toggle('hidden',  row.scrollLeft <= 4);
  right.classList.toggle('hidden', row.scrollLeft >= row.scrollWidth - row.clientWidth - 4);
}

// ── 카테고리 선택
function setCategory(el, val) {
  document.querySelectorAll('.cat-chip').forEach(function(c){ c.classList.remove('active'); });
  el.classList.add('active');
  selectedCategory = val;
  document.getElementById('categoryInput').value = val;
}

// ── 추천 질문 채우기
function fillInput(text) {
  var input = document.getElementById('msgInput');
  input.value = text;
  autoResize(input);
  input.focus();
}

// ── 자동 높이 조절
function autoResize(el) {
  el.style.height = 'auto';
  el.style.height = Math.min(el.scrollHeight, 100) + 'px';
}

// ── 전송
function handleSubmit() {
  var msg = document.getElementById('msgInput').value.trim();
  if (!msg) return false;

  var category = document.getElementById('categoryInput').value;
  var now = new Date();
  var timeStr = String(now.getHours()).padStart(2,'0') + ':' + String(now.getMinutes()).padStart(2,'0');

  // 유저 말풍선 추가
  var escaped = msg.replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;');
  var userRow = document.createElement('div');
  userRow.className = 'msg-row user';
  userRow.innerHTML =
    '<div>' +
      '<div class="bubble user">' + escaped + '</div>' +
      '<div class="bubble-meta" style="text-align:right;">' + timeStr + '</div>' +
    '</div>' +
    '<div class="avatar-sm avatar-user"><%= userInitial %></div>';
  document.getElementById('chatWrap').insertBefore(userRow, document.getElementById('typingRow'));

  // 입력창 비우기
  document.getElementById('msgInput').value = '';
  document.getElementById('msgInput').style.height = 'auto';

  // 로딩 표시
  document.getElementById('typingRow').style.display = 'flex';
  document.getElementById('sendBtn').disabled = true;
  scrollToBottom();

  // fetch SSE
  var params = new URLSearchParams();
  params.append('userMsg', msg);
  params.append('category', category);

  fetch('../askAI', { method: 'POST', body: params })
    .then(function(res) {
      document.getElementById('typingRow').style.display = 'none';

      // AI 말풍선 생성 (변수 참조 — id 중복 없음)
      var avatarEl = document.createElement('div');
      avatarEl.className = 'avatar-sm avatar-ai';
      avatarEl.innerHTML = '<svg viewBox="0 0 24 24" fill="none" stroke="#fff" stroke-width="2" stroke-linecap="round"><circle cx="12" cy="12" r="10"/><path d="M12 8v4l3 3"/></svg>';

      var bubbleEl = document.createElement('div');
      bubbleEl.className = 'bubble ai';

      var metaEl = document.createElement('div');
      metaEl.className = 'bubble-meta';

      var innerDiv = document.createElement('div');
      innerDiv.appendChild(bubbleEl);
      innerDiv.appendChild(metaEl);

      var aiRow = document.createElement('div');
      aiRow.className = 'msg-row';
      aiRow.appendChild(avatarEl);
      aiRow.appendChild(innerDiv);
      document.getElementById('chatWrap').insertBefore(aiRow, document.getElementById('typingRow'));
      scrollToBottom();

      var reader = res.body.getReader();
      var decoder = new TextDecoder();
      var buf = '';
      var fullText = '';

      function pump() {
        reader.read().then(function(result) {
          if (result.done) {
            var now2 = new Date();
            metaEl.textContent = String(now2.getHours()).padStart(2,'0') + ':' + String(now2.getMinutes()).padStart(2,'0') + ' · gemma3:1b';
            document.getElementById('sendBtn').disabled = false;
            return;
          }
          buf += decoder.decode(result.value, { stream: true });
          var lines = buf.split('\n\n');
          buf = lines.pop();
          lines.forEach(function(line) {
            if (!line.startsWith('data: ')) return;
            var token = line.slice(6);
            if (token === '[DONE]') {
              var now2 = new Date();
              metaEl.textContent = String(now2.getHours()).padStart(2,'0') + ':' + String(now2.getMinutes()).padStart(2,'0') + ' · gemma3:1b';
              document.getElementById('sendBtn').disabled = false;
              return;
            }
            if (token.startsWith('[ERROR]')) {
              bubbleEl.textContent = token.slice(7).trim();
              document.getElementById('sendBtn').disabled = false;
              return;
            }
            fullText += token.replace(/\\n/g, '\n');
            bubbleEl.innerHTML = fullText.replace(/\n/g, '<br>');
            scrollToBottom();
          });
          pump();
        }).catch(function() {
          document.getElementById('sendBtn').disabled = false;
        });
      }
      pump();
    })
    .catch(function() {
      document.getElementById('typingRow').style.display = 'none';
      document.getElementById('sendBtn').disabled = false;
    });

}

// ── 대화 초기화
function clearChat() {
  if (confirm('대화 내역을 초기화하시겠습니까?')) {
    location.href = '../askAI';
  }
}

// ── 스크롤 하단
function scrollToBottom() {
  var wrap = document.getElementById('chatWrap');
  wrap.scrollTop = wrap.scrollHeight;
}

window.addEventListener('load', function() {
  scrollToBottom();
  updateArrows();
  var input = document.getElementById('msgInput');
  input.addEventListener('focus', function() { setTimeout(scrollToBottom, 300); });
  input.addEventListener('keydown', function(e) {
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault();
      e.stopPropagation();
      handleSubmit();
      return false;
    }
  });
});
</script>
</body>
</html>
