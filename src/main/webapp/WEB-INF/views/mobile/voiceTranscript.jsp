<%@ page language="java" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8"%>
<!DOCTYPE html>
<html lang="ko">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
<title>POL-MATE | 음성 조서 변환</title>
<link href="https://fonts.googleapis.com/css2?family=Noto+Sans+KR:wght@300;400;500;700&display=swap" rel="stylesheet">
<style>
  * { margin: 0; padding: 0; box-sizing: border-box; -webkit-tap-highlight-color: transparent; }
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
  html, body { height: 100%; font-family: 'Noto Sans KR', sans-serif; background: var(--bg); overflow-x: hidden; }

  .screen { width: 100%; max-width: 420px; min-height: 100vh; margin: 0 auto; background: var(--bg); display: flex; flex-direction: column; }

  /* ── 헤더 ── */
  .top-header {
    background:var(--deep); padding: 52px 20px 20px;
    display: flex; align-items: center; gap: 12px;
    position: sticky; top: 0; z-index: 10;
  }
  .back-btn {
    width: 36px; height: 36px; border-radius: 50%;
    background: rgba(255,255,255,0.12); border: none;
    display: flex; align-items: center; justify-content: center; cursor: pointer; flex-shrink: 0;
  }
  .back-btn svg { width: 18px; height: 18px; stroke: #fff; }
  .header-text { flex: 1; }
  .header-title { font-size: 16px; font-weight: 500; color: #fff; }
  .header-sub   { font-size: 10px; color: rgba(255,255,255,0.5); margin-top: 2px; }

  /* ── 스크롤 콘텐츠 ── */
  .content { flex: 1; overflow-y: auto; padding: 20px 16px calc(var(--bnav) + 20px); }

  /* ── 카드 공통 ── */
  .card {
    background: var(--card); border-radius: 16px; border: 1px solid var(--bd);
    padding: 20px; margin-bottom: 14px;
    animation: fadeUp 0.35s ease both;
  }
  .card-title {
    font-size: 12px; font-weight: 500; color: var(--ts);
    text-transform: uppercase; letter-spacing: 0.6px;
    margin-bottom: 14px; display: flex; align-items: center; gap: 7px;
  }
  .card-title svg { width: 14px; height: 14px; stroke: var(--tm); }

  /* ── STEP 표시 ── */
  .step-flow {
    display: flex; align-items: center; gap: 0;
    background: var(--card); border-radius: 14px; border: 1px solid var(--bd);
    padding: 14px 16px; margin-bottom: 14px;
  }
  .step-node {
    display: flex; flex-direction: column; align-items: center; flex: 1; gap: 5px;
  }
  .step-circle {
    width: 32px; height: 32px; border-radius: 50%; border: 2px solid var(--bd);
    display: flex; align-items: center; justify-content: center;
    font-size: 12px; font-weight: 500; color: var(--tm);
    background: var(--bg); transition: all 0.3s;
  }
  .step-circle.active { background: var(--navy); border-color: var(--navy); color: #fff; }
  .step-circle.done   { background: var(--accent); border-color: var(--accent); color: #fff; }
  .step-circle svg    { width: 14px; height: 14px; }
  .step-name { font-size: 9px; color: var(--tm); text-align: center; }
  .step-name.active { color: var(--navy); font-weight: 500; }
  .step-line { flex: 1; height: 1px; background: var(--bd); margin-bottom: 14px; }

  /* ── 업로드 존 ── */
  .upload-zone {
    border: 2px dashed var(--bd); border-radius: 14px;
    padding: 32px 20px; text-align: center; cursor: pointer;
    transition: border-color 0.2s, background 0.2s; position: relative;
  }
  .upload-zone:hover, .upload-zone.drag { border-color: var(--accent); background: #f0f5ff; }
  .upload-zone input { position: absolute; inset: 0; opacity: 0; cursor: pointer; width: 100%; height: 100%; }

  .upload-icon {
    width: 52px; height: 52px; background: #eff6ff; border-radius: 50%;
    margin: 0 auto 12px; display: flex; align-items: center; justify-content: center;
  }
  .upload-icon svg { width: 24px; height: 24px; stroke: var(--accent); }
  .upload-title { font-size: 14px; font-weight: 500; color: var(--tp); margin-bottom: 4px; }
  .upload-desc  { font-size: 11px; color: var(--tm); }
  .upload-hint  { font-size: 10px; color: var(--tm); margin-top: 10px; }

  /* 선택된 파일 */
  .file-selected {
    background: var(--success-bg); border: 1px solid var(--success-border);
    border-radius: 12px; padding: 14px 16px; display: none;
    align-items: center; gap: 12px; margin-top: 12px;
  }
  .file-icon { width: 36px; height: 36px; background: #dcfce7; border-radius: 10px; display: flex; align-items: center; justify-content: center; flex-shrink: 0; }
  .file-icon svg { width: 18px; height: 18px; stroke: var(--success); }
  .file-meta { flex: 1; min-width: 0; }
  .file-name { font-size: 13px; font-weight: 500; color: var(--tp); white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
  .file-size { font-size: 10px; color: var(--tm); margin-top: 2px; }
  .file-remove { width: 24px; height: 24px; border-radius: 50%; background: #fef2f2; border: none; cursor: pointer; display: flex; align-items: center; justify-content: center; }
  .file-remove svg { width: 12px; height: 12px; stroke: var(--danger); }

  /* ── 텍스트 직접 입력 ── */
  .divider { display: flex; align-items: center; gap: 10px; margin: 14px 0; }
  .divider span { font-size: 11px; color: var(--tm); white-space: nowrap; }
  .divider::before, .divider::after { content: ''; flex: 1; height: 1px; background: var(--bd); }

  .text-area {
    width: 100%; min-height: 120px; padding: 13px 14px;
    background: var(--bg); border: 1px solid var(--bd); border-radius: 12px;
    font-size: 13px; font-family: 'Noto Sans KR', sans-serif;
    color: var(--tp); outline: none; resize: vertical; line-height: 1.7;
    transition: border-color 0.2s;
  }
  .text-area:focus { border-color: var(--accent); background: #fff; }
  .text-area::placeholder { color: var(--tm); font-size: 12px; }

  /* ── 사건 정보 입력 ── */
  .field-row { display: flex; gap: 10px; margin-bottom: 10px; }
  .field-half { flex: 1; }
  .field-label { font-size: 11px; font-weight: 500; color: var(--ts); display: block; margin-bottom: 5px; }
  .field-input {
    width: 100%; padding: 10px 12px; background: var(--bg);
    border: 1px solid var(--bd); border-radius: 10px;
    font-size: 13px; font-family: 'Noto Sans KR', sans-serif;
    color: var(--tp); outline: none; transition: border-color 0.2s;
  }
  .field-input:focus { border-color: var(--accent); background: #fff; }
  .field-input::placeholder { color: var(--tm); font-size: 12px; }
  select.field-input { appearance: none; }

  /* ── 분석 버튼 ── */
  .btn-analyze {
    width: 100%; background: var(--navy); color: #fff; border: none;
    border-radius: 14px; padding: 16px; font-size: 15px; font-weight: 500;
    font-family: 'Noto Sans KR', sans-serif; cursor: pointer;
    display: flex; align-items: center; justify-content: center; gap: 8px;
    transition: transform 0.1s, background 0.2s; margin-bottom: 14px;
  }
  .btn-analyze:active { transform: scale(0.98); }
  .btn-analyze:disabled { background: var(--bd); color: var(--tm); cursor: not-allowed; }
  .btn-analyze svg { width: 18px; height: 18px; stroke: #fff; }

  /* ── 로딩 ── */
  .loading-card {
    background: var(--card); border-radius: 16px; border: 1px solid var(--bd);
    padding: 28px 20px; text-align: center; display: none; margin-bottom: 14px;
  }
  .spinner {
    width: 40px; height: 40px; border: 3px solid var(--bd);
    border-top-color: var(--navy); border-radius: 50%;
    animation: spin 0.8s linear infinite; margin: 0 auto 14px;
  }
  .loading-title { font-size: 14px; font-weight: 500; color: var(--tp); margin-bottom: 4px; }
  .loading-sub   { font-size: 12px; color: var(--tm); }
  .loading-steps { display: flex; flex-direction: column; gap: 8px; margin-top: 16px; text-align: left; }
  .loading-step  { display: flex; align-items: center; gap: 10px; font-size: 12px; color: var(--tm); }
  .loading-step svg { width: 14px; height: 14px; flex-shrink: 0; }
  .loading-step.done   { color: var(--success); }
  .loading-step.active { color: var(--navy); font-weight: 500; }

  /* ── 결과 영역 ── */
  .result-section { display: none; }

  /* 변환 텍스트 */
  .transcript-box {
    background: var(--bg); border-radius: 12px; border: 1px solid var(--bd);
    padding: 14px; font-size: 13px; color: var(--tp);
    line-height: 1.9; max-height: 200px; overflow-y: auto;
    white-space: pre-wrap; position: relative;
  }
  .copy-btn {
    position: absolute; top: 10px; right: 10px;
    background: var(--card); border: 1px solid var(--bd); border-radius: 8px;
    padding: 5px 10px; font-size: 11px; color: var(--ts);
    cursor: pointer; font-family: 'Noto Sans KR', sans-serif;
    display: flex; align-items: center; gap: 4px;
  }
  .copy-btn svg { width: 12px; height: 12px; stroke: currentColor; }

  /* AI 분석 결과 */
  .ai-result-box {
    background: var(--bg); border-radius: 12px; border: 1px solid var(--bd);
    padding: 14px; font-size: 13px; color: var(--tp); line-height: 1.9;
    white-space: pre-wrap; max-height: 300px; overflow-y: auto;
  }

  /* 모순 탐지 배지 */
  .contra-banner {
    border-radius: 12px; padding: 14px 16px;
    display: flex; align-items: flex-start; gap: 12px; margin-bottom: 10px;
  }
  .contra-banner.found    { background: var(--danger-bg); border: 1px solid var(--danger-border); }
  .contra-banner.notfound { background: var(--success-bg); border: 1px solid var(--success-border); }
  .contra-dot { width: 8px; height: 8px; border-radius: 50%; margin-top: 4px; flex-shrink: 0; }
  .contra-dot.red   { background: var(--danger); animation: pulse 1.5s infinite; }
  .contra-dot.green { background: var(--success); }
  .contra-title { font-size: 13px; font-weight: 500; margin-bottom: 3px; }
  .contra-title.red   { color: #b91c1c; }
  .contra-title.green { color: var(--success); }
  .contra-desc  { font-size: 11px; color: var(--ts); line-height: 1.6; }

  /* 모순 항목 리스트 */
  .contra-list { display: flex; flex-direction: column; gap: 8px; }
  .contra-item {
    background: #fff; border: 1px solid var(--danger-border);
    border-left: 3px solid var(--danger); border-radius: 10px; padding: 12px 14px;
  }
  .contra-item-title { font-size: 12px; font-weight: 500; color: #b91c1c; margin-bottom: 5px; display: flex; align-items: center; gap: 6px; }
  .contra-item-title svg { width: 13px; height: 13px; stroke: var(--danger); }
  .contra-item-desc  { font-size: 11px; color: var(--ts); line-height: 1.7; }

  /* 저장 버튼 */
  .btn-save {
    width: 100%; background: var(--success); color: #fff; border: none;
    border-radius: 14px; padding: 15px; font-size: 14px; font-weight: 500;
    font-family: 'Noto Sans KR', sans-serif; cursor: pointer; margin-top: 6px;
    display: flex; align-items: center; justify-content: center; gap: 8px;
    transition: transform 0.1s;
  }
  .btn-save:active { transform: scale(0.98); }
  .btn-save svg { width: 16px; height: 16px; stroke: #fff; }

  .btn-reset {
    width: 100%; background: var(--bg); color: var(--ts);
    border: 1px solid var(--bd); border-radius: 14px; padding: 14px;
    font-size: 14px; font-family: 'Noto Sans KR', sans-serif; cursor: pointer; margin-top: 8px;
  }

  /* ── 하단 네비 ── */
  .bottom-nav {
    position: fixed; bottom: 0; left: 50%; transform: translateX(-50%);
    width: 100%; max-width: 420px; height: var(--bnav);
    background: var(--card); border-top: 1px solid var(--bd);
    display: flex; justify-content: space-around; align-items: center;
    padding: 0 8px; z-index: 100;
  }
  .nav-item { display: flex; flex-direction: column; align-items: center; gap: 3px; flex: 1; cursor: pointer; text-decoration: none; padding: 6px 0; }
  .nav-icon { width: 24px; height: 24px; display: flex; align-items: center; justify-content: center; }
  .nav-icon svg { width: 22px; height: 22px; }
  .nav-label { font-size: 9px; }
  .nav-item.active .nav-icon svg { stroke: var(--navy); }
  .nav-item.active .nav-label    { color: var(--navy); font-weight: 500; }
  .nav-item:not(.active) .nav-icon svg { stroke: var(--tm); }
  .nav-item:not(.active) .nav-label    { color: var(--tm); }

  @keyframes fadeUp  { from { opacity:0; transform: translateY(12px); } to { opacity:1; transform: translateY(0); } }
  @keyframes spin    { to { transform: rotate(360deg); } }
  @keyframes pulse   { 0%,100% { opacity:1; } 50% { opacity:0.3; } }

  @media (min-width: 421px) { .screen { box-shadow: 0 0 40px rgba(0,0,0,0.1); } }
</style>
</head>
<body>

<%
  String userName = "김민준"; // 임시 (세션 연동 후 교체)
%>

<div class="screen">

  <!-- 헤더 -->
  <div class="top-header">
    <button class="back-btn" onclick="history.back()">
      <svg viewBox="0 0 24 24" fill="none" stroke-width="2" stroke-linecap="round"><polyline points="15 18 9 12 15 6"/></svg>
    </button>
    <div class="header-text">
      <div class="header-title">음성 조서 변환</div>
      <div class="header-sub">STT 변환 · AI 모순 탐지</div>
    </div>
  </div>

  <div class="content">

    <!-- 진행 단계 -->
    <div class="step-flow" id="stepFlow">
      <div class="step-node">
        <div class="step-circle active" id="sc1">1</div>
        <div class="step-name active"  id="sn1">입력</div>
      </div>
      <div class="step-line"></div>
      <div class="step-node">
        <div class="step-circle" id="sc2">2</div>
        <div class="step-name"   id="sn2">변환</div>
      </div>
      <div class="step-line"></div>
      <div class="step-node">
        <div class="step-circle" id="sc3">3</div>
        <div class="step-name"   id="sn3">분석</div>
      </div>
      <div class="step-line"></div>
      <div class="step-node">
        <div class="step-circle" id="sc4">4</div>
        <div class="step-name"   id="sn4">결과</div>
      </div>
    </div>

    <!-- ── 입력 섹션 ── -->
    <div id="inputSection">

      <!-- 사건 정보 -->
      <div class="card" style="animation-delay:0.05s">
        <div class="card-title">
          <svg viewBox="0 0 24 24" fill="none" stroke-width="1.8" stroke-linecap="round"><rect x="3" y="3" width="18" height="18" rx="2"/><path d="M9 9h6M9 12h6M9 15h4"/></svg>
          사건 정보
        </div>
        <div class="field-row">
          <div class="field-half">
            <label class="field-label">사건번호</label>
            <input type="text" class="field-input" id="caseNum" placeholder="예: 2024-0312">
          </div>
          <div class="field-half">
            <label class="field-label">진술 유형</label>
            <select class="field-input" id="stmtType">
              <option value="피의자">피의자 진술</option>
              <option value="목격자">목격자 진술</option>
              <option value="참고인">참고인 진술</option>
            </select>
          </div>
        </div>
        <div>
          <label class="field-label">진술자 성명</label>
          <input type="text" class="field-input" id="stmtName" placeholder="진술자 이름">
        </div>
      </div>

      <!-- 음성 파일 업로드 -->
      <div class="card" style="animation-delay:0.1s">
        <div class="card-title">
          <svg viewBox="0 0 24 24" fill="none" stroke-width="1.8" stroke-linecap="round"><path d="M12 1a3 3 0 0 0-3 3v8a3 3 0 0 0 6 0V4a3 3 0 0 0-3-3z"/><path d="M19 10v2a7 7 0 0 1-14 0v-2"/><line x1="12" y1="19" x2="12" y2="23"/><line x1="8" y1="23" x2="16" y2="23"/></svg>
          음성 파일 업로드
          <span style="font-size:9px; background:#eff6ff; color:#1e40af; border-radius:4px; padding:2px 6px; margin-left:auto; font-weight:400;">CLOVA Speech API</span>
        </div>

        <div class="upload-zone" id="uploadZone"
             ondragover="event.preventDefault(); this.classList.add('drag')"
             ondragleave="this.classList.remove('drag')"
             ondrop="handleDrop(event)">
          <input type="file" id="audioFile" accept=".mp3,.wav,.m4a,.ogg,.webm" onchange="handleFile(this)">
          <div class="upload-icon">
            <svg viewBox="0 0 24 24" fill="none" stroke-width="1.8" stroke-linecap="round"><polyline points="16 16 12 12 8 16"/><line x1="12" y1="12" x2="12" y2="21"/><path d="M20.39 18.39A5 5 0 0 0 18 9h-1.26A8 8 0 1 0 3 16.3"/></svg>
          </div>
          <div class="upload-title">음성 파일을 업로드하세요</div>
          <div class="upload-desc">클릭하거나 파일을 드래그하세요</div>
          <div class="upload-hint">지원 형식: MP3, WAV, M4A, OGG, WEBM · 최대 100MB</div>
        </div>

        <div class="file-selected" id="fileSelected">
          <div class="file-icon">
            <svg viewBox="0 0 24 24" fill="none" stroke-width="1.8" stroke-linecap="round"><path d="M12 1a3 3 0 0 0-3 3v8a3 3 0 0 0 6 0V4a3 3 0 0 0-3-3z"/></svg>
          </div>
          <div class="file-meta">
            <div class="file-name" id="fileName">-</div>
            <div class="file-size" id="fileSize">-</div>
          </div>
          <button class="file-remove" onclick="removeFile()">
            <svg viewBox="0 0 24 24" fill="none" stroke-width="2" stroke-linecap="round"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg>
          </button>
        </div>

        <!-- STT 변환 버튼 (파일 선택 후 표시) -->
        <div id="sttBtnWrap" style="display:none; margin-top:10px;">
          <button onclick="convertStt()" id="sttBtn"
            style="width:100%; background:#1e40af; color:#fff; border:none; border-radius:12px;
                   padding:12px; font-size:13px; font-weight:500; font-family:'Noto Sans KR',sans-serif;
                   cursor:pointer; display:flex; align-items:center; justify-content:center; gap:8px;
                   transition:transform 0.1s;">
            <svg viewBox="0 0 24 24" fill="none" stroke="#fff" stroke-width="2" stroke-linecap="round" style="width:16px;height:16px;"><path d="M12 1a3 3 0 0 0-3 3v8a3 3 0 0 0 6 0V4a3 3 0 0 0-3-3z"/><path d="M19 10v2a7 7 0 0 1-14 0v-2"/></svg>
            CLOVA Speech로 텍스트 변환
          </button>
          <!-- STT 처리 중 상태 -->
          <div id="sttLoading" style="display:none; text-align:center; padding:12px; font-size:12px; color:#1e40af;">
            <span id="sttLoadingMsg">음성 파일을 CLOVA에 전송 중...</span>
          </div>
        </div>
      </div>

      <!-- 또는 텍스트 직접 입력 -->
      <div class="card" style="animation-delay:0.15s">
        <div class="card-title">
          <svg viewBox="0 0 24 24" fill="none" stroke-width="1.8" stroke-linecap="round"><line x1="17" y1="10" x2="3" y2="10"/><line x1="21" y1="6" x2="3" y2="6"/><line x1="21" y1="14" x2="3" y2="14"/><line x1="17" y1="18" x2="3" y2="18"/></svg>
          진술 텍스트 직접 입력
          <span style="font-size:9px; background:#f0fdf4; color:#166534; border-radius:4px; padding:2px 6px; margin-left:auto; font-weight:400;">현재 사용 가능</span>
        </div>
        <textarea class="text-area" id="stmtText"
          placeholder="진술 내용을 직접 입력하거나 붙여넣기 하세요.&#10;&#10;예) 저는 3월 15일 오후 2시에 집에 있었습니다. 그날 외출한 적이 없으며..."></textarea>
        <div style="display:flex; justify-content:flex-end; margin-top:6px;">
          <span style="font-size:10px; color:var(--tm);" id="charCount">0자</span>
        </div>
      </div>

      <button class="btn-analyze" onclick="startAnalysis()">
        <svg viewBox="0 0 24 24" fill="none" stroke-width="2" stroke-linecap="round"><circle cx="11" cy="11" r="8"/><line x1="21" y1="21" x2="16.65" y2="16.65"/></svg>
        AI 분석 시작
      </button>

    </div><!-- /inputSection -->

    <!-- ── 로딩 ── -->
    <div class="loading-card" id="loadingCard">
      <div class="spinner"></div>
      <div class="loading-title">AI 분석 중...</div>
      <div class="loading-sub" id="loadingSub">잠시만 기다려 주세요</div>
      <div class="loading-steps">
        <div class="loading-step" id="ls1">
          <svg viewBox="0 0 24 24" fill="none" stroke-width="2" stroke-linecap="round"><circle cx="12" cy="12" r="10"/><polyline points="12 6 12 12 16 14"/></svg>
          텍스트 전처리 중
        </div>
        <div class="loading-step" id="ls2">
          <svg viewBox="0 0 24 24" fill="none" stroke-width="2" stroke-linecap="round"><circle cx="12" cy="12" r="10"/><polyline points="12 6 12 12 16 14"/></svg>
          Ollama LLM 분석 요청
        </div>
        <div class="loading-step" id="ls3">
          <svg viewBox="0 0 24 24" fill="none" stroke-width="2" stroke-linecap="round"><circle cx="12" cy="12" r="10"/><polyline points="12 6 12 12 16 14"/></svg>
          모순 항목 추출
        </div>
        <div class="loading-step" id="ls4">
          <svg viewBox="0 0 24 24" fill="none" stroke-width="2" stroke-linecap="round"><circle cx="12" cy="12" r="10"/><polyline points="12 6 12 12 16 14"/></svg>
          결과 정리
        </div>
      </div>
    </div>

    <!-- ── 결과 섹션 ── -->
    <div class="result-section" id="resultSection">

      <!-- 모순 탐지 요약 -->
      <div class="card">
        <div class="card-title">
          <svg viewBox="0 0 24 24" fill="none" stroke-width="1.8" stroke-linecap="round"><path d="M10.29 3.86L1.82 18a2 2 0 0 0 1.71 3h16.94a2 2 0 0 0 1.71-3L13.71 3.86a2 2 0 0 0-3.42 0z"/></svg>
          모순 탐지 요약
        </div>
        <div class="contra-banner" id="contraBanner">
          <div class="contra-dot" id="contraDot"></div>
          <div>
            <div class="contra-title" id="contraTitle"></div>
            <div class="contra-desc"  id="contraDesc"></div>
          </div>
        </div>
        <div class="contra-list" id="contraList"></div>
      </div>

      <!-- 변환된 텍스트 -->
      <div class="card">
        <div class="card-title">
          <svg viewBox="0 0 24 24" fill="none" stroke-width="1.8" stroke-linecap="round"><path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/><polyline points="14 2 14 8 20 8"/></svg>
          진술 텍스트
        </div>
        <div style="position:relative;">
          <div class="transcript-box" id="transcriptBox"></div>
          <button class="copy-btn" onclick="copyText()">
            <svg viewBox="0 0 24 24" fill="none" stroke-width="1.8" stroke-linecap="round"><rect x="9" y="9" width="13" height="13" rx="2"/><path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1"/></svg>
            복사
          </button>
        </div>
      </div>

      <!-- AI 분석 결과 -->
      <div class="card">
        <div class="card-title">
          <svg viewBox="0 0 24 24" fill="none" stroke-width="1.8" stroke-linecap="round"><circle cx="12" cy="12" r="10"/><path d="M12 8v4l3 3"/></svg>
          AI 분석 결과
          <span style="font-size:9px; background:#eff6ff; color:#1e40af; border-radius:4px; padding:2px 6px; margin-left:auto; font-weight:400;">gemma3:1b</span>
        </div>
        <div class="ai-result-box" id="aiResultBox"></div>
      </div>

      <!-- 저장 / 재시작 -->
      <button class="btn-save" id="btnSaveResult" onclick="saveResult()">
        <svg viewBox="0 0 24 24" fill="none" stroke-width="2" stroke-linecap="round"><path d="M19 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h11l5 5v11a2 2 0 0 1-2 2z"/><polyline points="17 21 17 13 7 13 7 21"/><polyline points="7 3 7 8 15 8"/></svg>
        결과 저장하기
      </button>
      <button class="btn-reset" onclick="resetAll()">새로 분석하기</button>

    </div><!-- /resultSection -->

  </div><!-- /content -->

  <!-- 하단 네비 -->
  <nav class="bottom-nav">
    <a href="main" class="nav-item">
      <div class="nav-icon"><svg viewBox="0 0 24 24" fill="none" stroke-width="2" stroke-linecap="round"><path d="M3 9l9-7 9 7v11a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"/><polyline points="9 22 9 12 15 12 15 22"/></svg></div>
      <span class="nav-label">홈</span>
    </a>
    <a href="myCase" class="nav-item">
      <div class="nav-icon"><svg viewBox="0 0 24 24" fill="none" stroke-width="2" stroke-linecap="round"><path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/><polyline points="14 2 14 8 20 8"/></svg></div>
      <span class="nav-label">조서</span>
    </a>
    <a href="../askAI" class="nav-item active">
      <div class="nav-icon"><svg viewBox="0 0 24 24" fill="none" stroke-width="2" stroke-linecap="round"><circle cx="12" cy="12" r="10"/><path d="M12 8v4l3 3"/></svg></div>
      <span class="nav-label">AI</span>
    </a>
    <a href="board" class="nav-item">
      <div class="nav-icon"><svg viewBox="0 0 24 24" fill="none" stroke-width="2" stroke-linecap="round"><path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z"/></svg></div>
      <span class="nav-label">커뮤니티</span>
    </a>
    <a href="mypage" class="nav-item">
      <div class="nav-icon"><svg viewBox="0 0 24 24" fill="none" stroke-width="2" stroke-linecap="round"><path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2"/><circle cx="12" cy="7" r="4"/></svg></div>
      <span class="nav-label">마이페이지</span>
    </a>
  </nav>

</div><!-- /screen -->

<script>
// ── 파일 처리 ────────────────────────────────────────────────────
function handleFile(input) {
  if (!input.files || !input.files[0]) return;
  const f = input.files[0];
  showFile(f);
}
function handleDrop(e) {
  e.preventDefault();
  document.getElementById('uploadZone').classList.remove('drag');
  const f = e.dataTransfer.files[0];
  if (f) showFile(f);
}
function showFile(f) {
  document.getElementById('fileName').textContent = f.name;
  document.getElementById('fileSize').textContent = formatSize(f.size);
  document.getElementById('fileSelected').style.display = 'flex';
  document.getElementById('sttBtnWrap').style.display = 'block';
}
function removeFile() {
  document.getElementById('audioFile').value = '';
  document.getElementById('fileSelected').style.display = 'none';
  document.getElementById('sttBtnWrap').style.display = 'none';
  document.getElementById('sttLoading').style.display = 'none';
}

// ── CLOVA Speech API 호출 (SttServlet → CLOVA CSR) ───────────────
function convertStt() {
  var fileInput = document.getElementById('audioFile');
  if (!fileInput.files || !fileInput.files[0]) {
    alert('음성 파일을 선택해 주세요.');
    return;
  }

  var sttBtn     = document.getElementById('sttBtn');
  var sttLoading = document.getElementById('sttLoading');
  var sttMsg     = document.getElementById('sttLoadingMsg');

  sttBtn.style.display     = 'none';
  sttLoading.style.display = 'block';
  sttMsg.textContent       = '음성 파일을 CLOVA Speech에 전송 중...';

  var formData = new FormData();
  formData.append('audioFile', fileInput.files[0]);
  formData.append('language', 'Kor');

  fetch('../stt', {
    method: 'POST',
    body: formData
  })
  .then(function(r) { return r.json(); })
  .then(function(data) {
    sttLoading.style.display = 'none';
    sttBtn.style.display     = 'flex';

    if (data.success) {
      // 변환된 텍스트를 textarea에 자동 채움
      var textarea = document.getElementById('stmtText');
      textarea.value = data.text;
      document.getElementById('charCount').textContent = data.text.length + '자';

      // 성공 안내
      sttMsg.textContent = '변환 완료! 아래 텍스트를 확인하세요.';
      sttLoading.style.display = 'block';
      sttLoading.style.color   = '#16a34a';
      setTimeout(function() { sttLoading.style.display = 'none'; }, 3000);

    } else {
      // API 키 미설정 또는 오류
      var msg = data.error || 'STT 변환에 실패했습니다.';
      if (data.error && data.error.indexOf('API 키') >= 0) {
        msg = 'CLOVA API 키가 설정되지 않았습니다.\nWEB-INF/config.properties에 키를 입력해 주세요.';
      }
      alert(msg);
    }
  })
  .catch(function(err) {
    sttLoading.style.display = 'none';
    sttBtn.style.display     = 'flex';
    alert('네트워크 오류: ' + err.message + '\nSttServlet이 등록되어 있는지 확인해 주세요.');
  });
}
function formatSize(b) {
  if (b < 1024*1024) return (b/1024).toFixed(1) + ' KB';
  return (b/(1024*1024)).toFixed(1) + ' MB';
}

// 글자수 카운트
document.getElementById('stmtText').addEventListener('input', function() {
  document.getElementById('charCount').textContent = this.value.length + '자';
});

// ── 분석 시작 ────────────────────────────────────────────────────
function startAnalysis() {
  const text = document.getElementById('stmtText').value.trim();
  if (!text) { alert('진술 텍스트를 입력해 주세요.'); return; }

  // UI 전환
  document.getElementById('inputSection').style.display = 'none';
  document.getElementById('loadingCard').style.display  = 'block';
  setStep(2);

  // 로딩 스텝 애니메이션
  animateLoadingSteps(function() {
    setStep(3);
    callOllama(text);
  });
}

function animateLoadingSteps(callback) {
  const steps = ['ls1','ls2','ls3','ls4'];
  const msgs  = ['텍스트 전처리 중...','Ollama LLM 요청 중...','모순 항목 추출 중...','결과 정리 중...'];
  let i = 0;
  function next() {
    if (i > 0) {
      document.getElementById(steps[i-1]).classList.remove('active');
      document.getElementById(steps[i-1]).classList.add('done');
    }
    if (i >= steps.length) { callback(); return; }
    document.getElementById(steps[i]).classList.add('active');
    document.getElementById('loadingSub').textContent = msgs[i];
    i++;
    setTimeout(next, 900);
  }
  next();
}

// ── Ollama 호출 ──────────────────────────────────────────────────
function callOllama(text) {
  const caseNum  = document.getElementById('caseNum').value  || '미입력';
  const stmtType = document.getElementById('stmtType').value || '진술자';
  const stmtName = document.getElementById('stmtName').value || '미입력';

  const prompt =
    "다음은 형사사건 수사 진술입니다. 아래 내용을 분석하여 결과를 반드시 한국어로 답해주세요.\n\n" +
    "[사건번호: " + caseNum + "]\n" +
    "[진술 유형: " + stmtType + "]\n" +
    "[진술자: " + stmtName + "]\n\n" +
    "[진술 내용]\n" + text + "\n\n" +
    "다음 항목을 분석해주세요:\n" +
    "1. 진술 요약 (3줄 이내)\n" +
    "2. 모순 또는 불일치 항목 (있다면 구체적으로)\n" +
    "3. 추가 확인이 필요한 사항\n" +
    "4. 종합 평가";

  fetch('http://localhost:11434/api/generate', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      model: 'gemma3:1b',
      prompt: prompt,
      stream: false
    })
  })
  .then(function(r) { return r.json(); })
  .then(function(data) {
    showResult(text, data.response || '응답 없음', true);
  })
  .catch(function(err) {
    // Ollama 미실행 시 데모 결과 표시
    var demoResult =
      "【진술 요약】\n진술자는 해당 날짜 오후 2시에 집에 있었다고 주장하며,\n외출 사실을 전면 부인하고 있습니다.\n\n" +
      "【모순 항목】\n- 진술 초반 '집에 있었다'고 했으나, 이후 '잠깐 편의점을 다녀왔다'는\n  언급이 포함되어 있어 알리바이에 불일치가 발견됩니다.\n\n" +
      "【추가 확인 필요】\n- 편의점 CCTV 확인\n- 동거인 또는 인접 주민 목격 여부 확인\n\n" +
      "【종합 평가】\n진술에 경미한 모순이 포함되어 있으며 추가 조사가 권고됩니다.\n\n⚠ (Ollama 미연결 — 데모 결과입니다)";
    showResult(text, demoResult, true);
  });
}

// ── 결과 표시 ────────────────────────────────────────────────────
function showResult(originalText, aiResponse, hasContra) {
  setStep(4);
  document.getElementById('loadingCard').style.display = 'none';
  document.getElementById('resultSection').style.display = 'block';

  // 진술 텍스트
  document.getElementById('transcriptBox').textContent = originalText;

  // AI 분석
  document.getElementById('aiResultBox').textContent = aiResponse;

  // 모순 탐지 판단 (간단한 키워드 기반)
  var contraKeywords = ['모순','불일치','불일치','위반','거짓','허위','불명확'];
  var found = contraKeywords.some(function(k) { return aiResponse.includes(k); });

  var banner = document.getElementById('contraBanner');
  var dot    = document.getElementById('contraDot');
  var title  = document.getElementById('contraTitle');
  var desc   = document.getElementById('contraDesc');

  if (found) {
    banner.className = 'contra-banner found';
    dot.className    = 'contra-dot red';
    title.className  = 'contra-title red';
    title.textContent = '모순 항목이 탐지되었습니다';
    desc.textContent  = 'AI가 진술에서 불일치 또는 모순된 내용을 발견했습니다. 아래 분석 결과를 확인하세요.';
    document.getElementById('contraList').innerHTML =
      '<div class="contra-item">' +
        '<div class="contra-item-title">' +
          '<svg viewBox="0 0 24 24" fill="none" stroke-width="2" stroke-linecap="round"><path d="M10.29 3.86L1.82 18a2 2 0 0 0 1.71 3h16.94a2 2 0 0 0 1.71-3L13.71 3.86a2 2 0 0 0-3.42 0z"/><line x1="12" y1="9" x2="12" y2="13"/><line x1="12" y1="17" x2="12.01" y2="17"/></svg>' +
          '알리바이 불일치' +
        '</div>' +
        '<div class="contra-item-desc">진술 내 시간대 및 위치 정보가 상호 모순됩니다. AI 분석 결과를 참고하여 추가 확인이 필요합니다.</div>' +
      '</div>';
  } else {
    banner.className = 'contra-banner notfound';
    dot.className    = 'contra-dot green';
    title.className  = 'contra-title green';
    title.textContent = '명확한 모순이 탐지되지 않았습니다';
    desc.textContent  = '진술 내에서 즉각적인 모순은 발견되지 않았으나, 전체 분석 결과를 반드시 직접 검토하세요.';
    document.getElementById('contraList').innerHTML = '';
  }

  window.scrollTo(0, 0);
}

// ── 유틸 ─────────────────────────────────────────────────────────
function setStep(n) {
  for (var i = 1; i <= 4; i++) {
    var c = document.getElementById('sc'+i);
    var s = document.getElementById('sn'+i);
    if (i < n)      { c.className = 'step-circle done';   s.className = 'step-name'; }
    else if (i===n) { c.className = 'step-circle active'; s.className = 'step-name active'; }
    else            { c.className = 'step-circle';        s.className = 'step-name'; }
  }
}

function copyText() {
  var t = document.getElementById('transcriptBox').textContent;
  navigator.clipboard.writeText(t).then(function() {
    alert('클립보드에 복사되었습니다.');
  });
}

// ── 결과 저장하기 (DB 저장 → 모순탐지 목록) ───────────────────────
function saveResult() {
  var btn = document.getElementById('btnSaveResult');
  btn.disabled = true;
  btn.innerHTML = '<svg viewBox="0 0 24 24" fill="none" stroke-width="2" stroke-linecap="round" style="width:16px;height:16px;animation:spin 0.7s linear infinite"><path d="M21 12a9 9 0 1 1-6.22-8.56"/></svg> 저장 중...';

  var caseId    = document.getElementById('caseNum')   ? document.getElementById('caseNum').value.trim()   : '';
  var stmtName  = document.getElementById('stmtName')  ? document.getElementById('stmtName').value.trim()  : '';
  var stmtType  = document.getElementById('stmtType')  ? document.getElementById('stmtType').value          : '';
  var stmtText  = document.getElementById('transcriptBox') ? document.getElementById('transcriptBox').textContent : '';
  var aiResult  = document.getElementById('aiResultBox')   ? document.getElementById('aiResultBox').textContent   : '';
  var banner = document.getElementById('contraBanner');
  var hasContradiction = banner && banner.classList.contains('found');

  var params = new URLSearchParams();
  params.append('action', 'save');
  params.append('caseId', caseId);
  params.append('stmtName', stmtName);
  params.append('stmtType', stmtType);
  params.append('hasContradiction', hasContradiction ? 'true' : 'false');
  params.append('aiResult', aiResult);
  params.append('stmtText', stmtText);

  fetch('../contradictionApi', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded;charset=UTF-8' },
    body: params.toString()
  })
    .then(function(r) { return r.text().then(function(t) {
      try { return JSON.parse(t); } catch (e) {
        throw new Error(t.indexOf('<html') >= 0 || t.indexOf('<!DOCTYPE') >= 0 ? '로그인이 만료되었거나 서버 오류입니다. 다시 로그인 후 시도하세요.' : (t.substring(0, 120) || '응답 해석 실패'));
      }
    }); })
    .then(function(data) {
      if (data.success) {
        location.href = 'contradictionList';
      } else {
        alert(data.error || '저장에 실패했습니다.');
        btn.disabled = false;
        btn.innerHTML = '<svg viewBox="0 0 24 24" fill="none" stroke-width="2" stroke-linecap="round" style="width:16px;height:16px;"><path d="M19 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h11l5 5v11a2 2 0 0 1-2 2z"/><polyline points="17 21 17 13 7 13 7 21"/><polyline points="7 3 7 8 15 8"/></svg> 결과 저장하기';
      }
    })
    .catch(function(err) {
      alert(err && err.message ? err.message : '서버 연결 오류가 발생했습니다.');
      btn.disabled = false;
      btn.innerHTML = '<svg viewBox="0 0 24 24" fill="none" stroke-width="2" stroke-linecap="round" style="width:16px;height:16px;"><path d="M19 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h11l5 5v11a2 2 0 0 1-2 2z"/><polyline points="17 21 17 13 7 13 7 21"/><polyline points="7 3 7 8 15 8"/></svg> 결과 저장하기';
    });
}

function resetAll() {
  document.getElementById('inputSection').style.display  = 'block';
  document.getElementById('loadingCard').style.display   = 'none';
  document.getElementById('resultSection').style.display = 'none';
  document.getElementById('stmtText').value = '';
  document.getElementById('charCount').textContent = '0자';
  removeFile();
  setStep(1);
  ['ls1','ls2','ls3','ls4'].forEach(function(id) {
    var el = document.getElementById(id);
    el.classList.remove('active','done');
  });
  window.scrollTo(0,0);
}
</script>
</body>
</html>
