<%@ page language="java" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8"%>
<%
request.setAttribute("currentPage", "cases");
request.setAttribute("breadcrumb",  new String[]{"POL-MATE", "내 사건"});
String initCaseId = request.getParameter("caseId") != null ? request.getParameter("caseId") : "";
%>
<!DOCTYPE html>
<html lang="ko">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>POL-MATE | 내 사건</title>
<link href="https://fonts.googleapis.com/css2?family=Noto+Sans+KR:wght@300;400;500;700&family=Space+Grotesk:wght@500;700&display=swap" rel="stylesheet">
<link rel="stylesheet" href="${pageContext.request.contextPath}/css/polmate.css">
<script>var _ctx = '${pageContext.request.contextPath}'; var _initCaseId = '<%= initCaseId %>';</script>
<style>
* { box-sizing: border-box; margin: 0; padding: 0; }
html, body { height: 100%; font-family: 'Noto Sans KR', sans-serif; background: #f4f6fb; color: #1a1a2e; -webkit-font-smoothing: antialiased; }

.pm-page { padding: 28px 32px 48px; }


.toolbar {
    display: flex; align-items: center; gap: 12px; margin-bottom: 20px;
}
.search-box {
    flex: 1; max-width: 320px;
    display: flex; align-items: center; gap: 8px;
    background: #fff; border: 1.5px solid #e2e5ee; border-radius: 12px;
    padding: 9px 14px; transition: border-color 0.15s, box-shadow 0.15s;
}
.search-box:focus-within { border-color: #0d1a33; box-shadow: 0 0 0 3px rgba(13,26,51,0.07); }
.search-box input { border: none; background: transparent; outline: none; font-size: 13px; font-family: 'Noto Sans KR', sans-serif; color: #1a1a2e; width: 100%; }
.search-box input::placeholder { color: #9ca3af; }
.filter-chips { display: flex; gap: 6px; }
.chip {
    padding: 6px 14px; border-radius: 20px; font-size: 11px; font-family: 'Noto Sans KR', sans-serif;
    border: 1px solid #e2e5ee; background: #fff; color: #6b7280; cursor: pointer; transition: all 0.13s;
}
.chip.active { background: #0d1a33; color: #fff; border-color: #0d1a33; }
.chip:hover:not(.active) { border-color: #0d1a33; color: #0d1a33; }
.btn-new {
    display: flex; align-items: center; gap: 6px;
    background: #0d1a33; color: #fff; border: none; border-radius: 10px;
    padding: 9px 16px; font-size: 13px; font-family: 'Noto Sans KR', sans-serif;
    font-weight: 500; cursor: pointer; transition: background 0.13s; margin-left: auto;
}
.btn-new:hover { background: #1a2744; }


.case-table { background: #fff; border: 1px solid #e2e5ee; border-radius: 16px; overflow: hidden; }
.case-table-head {
    display: grid; grid-template-columns: 130px 1fr 110px 80px 70px 70px 44px;
    padding: 10px 16px; border-bottom: 1px solid #e2e5ee; background: #f9fafb;
}
.th { font-size: 10px; font-weight: 500; color: #9ca3af; text-transform: uppercase; letter-spacing: 0.6px; display: flex; align-items: center; }
.case-row {
    display: grid; grid-template-columns: 130px 1fr 110px 80px 70px 70px 44px;
    padding: 13px 16px; border-bottom: 1px solid #f0f2f8;
    align-items: center; cursor: pointer; transition: background 0.12s;
}
.case-row:last-child { border-bottom: none; }
.case-row:hover { background: #f4f6fb; }
.case-row.urgent { border-left: 3px solid #dc2626; padding-left: 13px; }
.case-row.selected { background: #eff6ff; }
.case-id { font-size: 11px; color: #9ca3af; font-family: 'Space Grotesk', sans-serif; }
.case-name { font-size: 13px; font-weight: 500; }
.case-suspect { font-size: 12px; color: #6b7280; }
.badge { display: inline-flex; align-items: center; font-size: 10px; font-weight: 500; padding: 3px 9px; border-radius: 20px; }
.b-jinhaeng { background: #f0fdf4; color: #16a34a; }
.b-wanryo   { background: #eff6ff; color: #1e40af; }
.b-moosun   { background: #fef2f2; color: #dc2626; }
.b-geomto   { background: #fffbeb; color: #92400e; }
.doc-count  { font-size: 12px; color: #6b7280; }
.contra-count { font-size: 12px; color: #dc2626; font-weight: 500; }
.action-btn {
    width: 30px; height: 30px; border-radius: 7px; border: none; background: transparent;
    cursor: pointer; display: flex; align-items: center; justify-content: center;
    color: #9ca3af; transition: background 0.13s, color 0.13s;
}
.action-btn:hover { background: #fee2e2; color: #dc2626; }
.empty-state { padding: 60px 20px; text-align: center; color: #9ca3af; font-size: 13px; }


.detail-overlay {
    display: none; position: fixed; inset: 0; background: rgba(0,0,0,0.25); z-index: 200;
}
.detail-overlay.open { display: block; }
.detail-panel {
    position: fixed; top: 0; right: 0; bottom: 0; width: 520px;
    background: #fff; box-shadow: -4px 0 32px rgba(0,0,0,0.12);
    z-index: 201; display: flex; flex-direction: column;
    transform: translateX(100%); transition: transform 0.25s cubic-bezier(0.4,0,0.2,1);
    overflow: hidden;
}
.detail-panel.open { transform: translateX(0); }
.detail-header {
    padding: 20px 24px 16px; border-bottom: 1px solid #e2e5ee;
    display: flex; align-items: flex-start; gap: 12px; flex-shrink: 0;
}
.detail-close {
    width: 32px; height: 32px; border-radius: 8px; border: 1px solid #e2e5ee;
    background: transparent; cursor: pointer; display: flex; align-items: center;
    justify-content: center; color: #6b7280; transition: all 0.13s; flex-shrink: 0;
}
.detail-close:hover { background: #f4f6fb; }
.detail-title { font-size: 15px; font-weight: 500; flex: 1; margin-top: 4px; }
.detail-id { font-size: 11px; color: #9ca3af; font-family: 'Space Grotesk', sans-serif; margin-top: 2px; }
.detail-body { flex: 1; overflow-y: auto; padding: 20px 24px; }
.detail-tabs { display: flex; gap: 0; border-bottom: 1px solid #e2e5ee; margin-bottom: 20px; }
.dtab {
    padding: 8px 16px; font-size: 13px; font-family: 'Noto Sans KR', sans-serif;
    border: none; background: transparent; cursor: pointer; color: #6b7280;
    border-bottom: 2px solid transparent; margin-bottom: -1px; transition: all 0.13s;
}
.dtab.active { color: #0d1a33; font-weight: 500; border-bottom-color: #0d1a33; }
.tab-pane { display: none; }
.tab-pane.active { display: block; }
.info-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 14px; margin-bottom: 20px; }
.info-item { }
.info-label { font-size: 10px; font-weight: 500; color: #9ca3af; text-transform: uppercase; letter-spacing: 0.7px; margin-bottom: 4px; }
.info-value { font-size: 13px; color: #1a1a2e; }
.sec-label {
    font-size: 10px; font-weight: 500; color: #6b7280; text-transform: uppercase; letter-spacing: 0.8px;
    display: flex; align-items: center; gap: 8px; margin-bottom: 12px;
}
.sec-label::after { content: ''; flex: 1; height: 1px; background: #e2e5ee; }
.doc-item {
    display: flex; align-items: center; gap: 12px; padding: 10px 12px;
    border: 1px solid #e2e5ee; border-radius: 10px; margin-bottom: 8px;
    text-decoration: none; color: inherit; transition: border-color 0.13s, background 0.13s;
}
.doc-item:hover { border-color: #0d1a33; background: #f4f6fb; }
.doc-item.has-contra { border-left: 3px solid #dc2626; padding-left: 9px; }
.doc-icon { width: 32px; height: 32px; border-radius: 8px; background: #f0f2f8; display: flex; align-items: center; justify-content: center; flex-shrink: 0; }
.doc-name { font-size: 13px; font-weight: 500; }
.doc-meta { font-size: 11px; color: #9ca3af; margin-top: 1px; }
.status-form { display: flex; gap: 8px; align-items: center; margin-bottom: 20px; }
.status-select {
    padding: 8px 12px; border: 1.5px solid #e2e5ee; border-radius: 10px;
    font-size: 13px; font-family: 'Noto Sans KR', sans-serif; color: #1a1a2e;
    background: #fff; outline: none; cursor: pointer;
}
.btn-save {
    padding: 8px 16px; background: #0d1a33; color: #fff; border: none; border-radius: 10px;
    font-size: 12px; font-family: 'Noto Sans KR', sans-serif; cursor: pointer; transition: background 0.13s;
}
.btn-save:hover { background: #1a2744; }
.btn-danger {
    padding: 8px 14px; background: transparent; color: #dc2626; border: 1px solid #fecaca;
    border-radius: 10px; font-size: 12px; font-family: 'Noto Sans KR', sans-serif; cursor: pointer; transition: all 0.13s;
}
.btn-danger:hover { background: #fef2f2; }
.detail-footer {
    padding: 14px 24px; border-top: 1px solid #e2e5ee;
    display: flex; gap: 8px; flex-shrink: 0;
}


.modal-backdrop { display: none; position: fixed; inset: 0; background: rgba(0,0,0,0.35); z-index: 300; align-items: center; justify-content: center; }
.modal-backdrop.open { display: flex; }
.modal { background: #fff; border-radius: 16px; padding: 28px; width: 460px; box-shadow: 0 20px 60px rgba(0,0,0,0.2); }
.modal-title { font-size: 16px; font-weight: 500; margin-bottom: 20px; }
.form-field { margin-bottom: 14px; }
.form-label { display: block; font-size: 10px; font-weight: 500; color: #6b7280; text-transform: uppercase; letter-spacing: 0.7px; margin-bottom: 6px; }
.form-input, .form-select {
    width: 100%; padding: 11px 14px;
    border: 1.5px solid #e2e5ee; border-radius: 10px;
    font-size: 13px; font-family: 'Noto Sans KR', sans-serif; color: #1a1a2e;
    background: #f4f6fb; outline: none; transition: border-color 0.15s, background 0.15s, box-shadow 0.15s;
}
.form-input:focus, .form-select:focus { border-color: #0d1a33; background: #fff; box-shadow: 0 0 0 3px rgba(13,26,51,0.07); }
.modal-actions { display: flex; gap: 8px; justify-content: flex-end; margin-top: 20px; }
.btn-cancel { padding: 9px 18px; background: transparent; border: 1px solid #e2e5ee; border-radius: 10px; font-size: 13px; font-family: 'Noto Sans KR', sans-serif; cursor: pointer; color: #6b7280; }
.btn-confirm { padding: 9px 18px; background: #0d1a33; color: #fff; border: none; border-radius: 10px; font-size: 13px; font-family: 'Noto Sans KR', sans-serif; cursor: pointer; }
.toast {
    position: fixed; bottom: 28px; left: 50%; transform: translateX(-50%) translateY(80px);
    background: #1a2744; color: #fff; padding: 10px 20px; border-radius: 10px;
    font-size: 13px; font-family: 'Noto Sans KR', sans-serif;
    opacity: 0; transition: all 0.25s; z-index: 500; white-space: nowrap;
}
.toast.show { opacity: 1; transform: translateX(-50%) translateY(0); }

/* === 신뢰도 스코어 === */
.score-badge {
    display: inline-flex; align-items: center; padding: 2px 8px;
    border-radius: 10px; font-size: 10px; font-weight: 600; white-space: nowrap; flex-shrink: 0;
}
.score-high { background: #f0fdf4; color: #16a34a; }
.score-mid  { background: #fffbeb; color: #92400e; }
.score-low  { background: #fef2f2; color: #dc2626; }
.score-btn {
    flex-shrink: 0; width: 26px; height: 26px; border-radius: 6px;
    border: 1px solid #e2e5ee; background: transparent; cursor: pointer;
    display: flex; align-items: center; justify-content: center;
    color: #9ca3af; transition: all 0.13s; margin-left: 4px;
}
.score-btn:hover { background: #eff6ff; color: #1e40af; border-color: #bfdbfe; }
.score-total-card {
    border: 1.5px solid #e2e5ee; border-radius: 12px; padding: 18px 20px;
    margin-bottom: 20px; display: flex; align-items: center; gap: 20px; background: #f9fafb;
}
.score-total-num { font-size: 48px; font-weight: 700; line-height: 1; font-family: 'Space Grotesk', sans-serif; }
.score-total-label { font-size: 10px; color: #9ca3af; text-transform: uppercase; letter-spacing: 0.7px; margin-bottom: 3px; }
.score-total-grade { font-size: 14px; font-weight: 500; color: #1a1a2e; }
.score-bars { display: flex; flex-direction: column; gap: 14px; margin-bottom: 20px; }
.score-row-header { display: flex; align-items: center; justify-content: space-between; margin-bottom: 6px; }
.score-row-label { font-size: 12px; font-weight: 500; color: #374151; }
.score-row-val { font-size: 12px; font-weight: 600; color: #1a1a2e; font-family: 'Space Grotesk', sans-serif; }
.score-bar-track { height: 5px; background: #f0f2f8; border-radius: 3px; overflow: hidden; }
.score-bar-fill { height: 100%; border-radius: 3px; transition: width 0.6s ease; }
.fill-high { background: #16a34a; }
.fill-mid  { background: #f59e0b; }
.fill-low  { background: #dc2626; }
.score-row-reason { font-size: 11px; color: #9ca3af; margin-top: 5px; line-height: 1.45; }
.score-empty-state { padding: 32px 20px; text-align: center; color: #9ca3af; font-size: 13px; }
.score-loading-state { padding: 32px 20px; text-align: center; color: #9ca3af; font-size: 13px; line-height: 1.7; }
.btn-analyze {
    width: 100%; padding: 10px; background: #0d1a33; color: #fff; border: none;
    border-radius: 10px; font-size: 13px; font-family: 'Noto Sans KR', sans-serif;
    font-weight: 500; cursor: pointer; transition: background 0.13s; margin-top: 4px;
}
.btn-analyze:hover:not(:disabled) { background: #1a2744; }
.btn-analyze:disabled { background: #9ca3af; cursor: not-allowed; }

/* === 채점기준 도움말 === */
.help-wrap { position: relative; display: inline-flex; align-items: center; }
.help-btn {
    width: 16px; height: 16px; border-radius: 50%;
    border: 1.5px solid #d1d5db; background: #f9fafb;
    color: #6b7280; font-size: 10px; font-weight: 700;
    cursor: pointer; display: inline-flex; align-items: center; justify-content: center;
    line-height: 1; padding: 0; transition: all 0.13s; flex-shrink: 0;
}
.help-btn:hover { border-color: #0d1a33; color: #0d1a33; background: #eff6ff; }
.help-popover {
    display: none; position: absolute; top: calc(100% + 8px); left: 0;
    width: 300px; background: #fff; border: 1.5px solid #e2e5ee;
    border-radius: 12px; box-shadow: 0 8px 24px rgba(0,0,0,0.12);
    padding: 16px; z-index: 600;
}
.help-popover.open { display: block; }
.help-popover-title {
    font-size: 11px; font-weight: 600; color: #1a1a2e;
    text-transform: uppercase; letter-spacing: 0.6px; margin-bottom: 12px;
}
.help-criterion { margin-bottom: 12px; }
.help-criterion:last-of-type { margin-bottom: 8px; }
.help-criterion-name {
    font-size: 12px; font-weight: 600; color: #0d1a33; margin-bottom: 3px;
    display: flex; align-items: center; gap: 6px;
}
.help-criterion-range {
    font-size: 10px; font-weight: 400; color: #9ca3af;
    font-family: 'Space Grotesk', sans-serif;
}
.help-criterion-desc { font-size: 11px; color: #6b7280; line-height: 1.55; }
.help-total-note {
    font-size: 10px; color: #9ca3af; padding-top: 8px;
    border-top: 1px solid #f0f2f8; margin-top: 4px;
}
</style>
</head>
<body>
<div class="pm-layout">

<%@ include file="sidebar.jsp" %>
<div class="pm-content">
<%@ include file="appbar.jsp" %>

<main class="pm-page">

    <div class="toolbar">
        <div class="search-box">
            <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="#9ca3af" stroke-width="1.8" stroke-linecap="round"><circle cx="11" cy="11" r="8"/><line x1="21" y1="21" x2="16.65" y2="16.65"/></svg>
            <input type="text" id="searchInput" placeholder="사건번호, 피의자, 종류 검색..." oninput="filterCases()">
        </div>
        <div class="filter-chips">
            <button class="chip active" data-status="all" onclick="setFilter(this)">전체</button>
            <button class="chip" data-status="진행중" onclick="setFilter(this)">진행중</button>
            <button class="chip" data-status="모순탐지" onclick="setFilter(this)">모순탐지</button>
            <button class="chip" data-status="검토필요" onclick="setFilter(this)">검토필요</button>
            <button class="chip" data-status="완료" onclick="setFilter(this)">완료</button>
        </div>
        <button class="btn-new" onclick="openNewModal()">
            <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><line x1="12" y1="5" x2="12" y2="19"/><line x1="5" y1="12" x2="19" y2="12"/></svg>
            새 사건
        </button>
    </div>

    <div class="case-table">
        <div class="case-table-head">
            <span class="th">사건번호</span>
            <span class="th">사건명</span>
            <span class="th">피의자</span>
            <span class="th">상태</span>
            <span class="th">조서</span>
            <span class="th">모순</span>
            <span class="th"></span>
        </div>
        <div id="caseList">
            <div class="empty-state">로딩 중...</div>
        </div>
    </div>

</main>

</div>
</div>


<div class="detail-overlay" id="detailOverlay" onclick="closeDetail()"></div>
<div class="detail-panel" id="detailPanel">
    <div class="detail-header">
        <div style="flex:1">
            <div class="detail-id" id="dpId"></div>
            <div class="detail-title" id="dpName"></div>
        </div>
        <button class="detail-close" onclick="closeDetail()">
            <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg>
        </button>
    </div>
    <div class="detail-body">
        <div class="detail-tabs">
            <button class="dtab active" onclick="switchTab('info')">기본 정보</button>
            <button class="dtab" onclick="switchTab('docs')">조서 목록</button>
        </div>
        <div class="tab-pane active" id="tabInfo">
            <div class="info-grid" id="dpInfoGrid"></div>
            <div class="sec-label" style="margin-top:16px">상태 변경</div>
            <div class="status-form">
                <select class="status-select" id="dpStatusSel">
                    <option>진행중</option>
                    <option>검토필요</option>
                    <option>완료</option>
                </select>
                <button class="btn-save" onclick="saveStatus()">저장</button>
            </div>
        </div>
        <div class="tab-pane" id="tabDocs">
            <div id="dpDocList"><div class="empty-state">조서가 없습니다</div></div>
            <div style="margin-top:16px">
                <a id="btnNewDoc" href="#" class="btn-new" style="display:inline-flex;text-decoration:none;">
                    <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><line x1="12" y1="5" x2="12" y2="19"/><line x1="5" y1="12" x2="19" y2="12"/></svg>
                    조서 작성
                </a>
            </div>
        </div>
    </div>
    <div class="detail-footer">
        <button class="btn-danger" onclick="deleteCase()">사건 삭제</button>
    </div>
</div>


<div class="modal-backdrop" id="newModal">
    <div class="modal" onclick="event.stopPropagation()">
        <div class="modal-title">새 사건 등록</div>
        <div class="form-field">
            <label class="form-label">사건명 <span style="color:#dc2626">*</span></label>
            <input type="text" class="form-input" id="newCaseName" placeholder="사건명 입력">
        </div>
        <div class="form-field">
            <label class="form-label">피의자</label>
            <input type="text" class="form-input" id="newSuspect" placeholder="피의자 성명">
        </div>
        <div class="form-field">
            <label class="form-label">종류</label>
            <input type="text" class="form-input" id="newCharge" placeholder="종류명 (예: 절도주거즼)">
        </div>
        <div class="modal-actions">
            <button class="btn-cancel" onclick="closeNewModal()">취소</button>
            <button class="btn-confirm" onclick="createCase()">등록</button>
        </div>
    </div>
</div>

<div class="toast" id="toast"></div>

<div class="modal-backdrop" id="scoreModal" onclick="closeScoreModal()">
    <div class="modal" style="width:500px;max-width:96vw;" onclick="event.stopPropagation()">
        <div style="display:flex;align-items:flex-start;justify-content:space-between;gap:12px;margin-bottom:18px;">
            <div style="flex:1;">
                <div style="display:flex;align-items:center;gap:6px;margin-bottom:3px;">
                    <span style="font-size:10px;color:#9ca3af;text-transform:uppercase;letter-spacing:0.7px;">진술 신뢰도 분석</span>
                    <div class="help-wrap">
                        <button class="help-btn" onclick="toggleHelp(event)" title="채점 기준 보기">?</button>
                        <div class="help-popover" id="helpPopover">
                            <div class="help-popover-title">채점 기준 안내</div>
                            <div class="help-criterion">
                                <div class="help-criterion-name">일관성 <span class="help-criterion-range">0 – 100점</span></div>
                                <div class="help-criterion-desc">진술 내부에서 동일 사건·행위에 대한 주장이 앞뒤로 모순 없이 일치하는 정도. 부정·긍정 표현이 같은 행위에 혼재하면 감점.</div>
                            </div>
                            <div class="help-criterion">
                                <div class="help-criterion-name">구체성 <span class="help-criterion-range">0 – 100점</span></div>
                                <div class="help-criterion-desc">날짜·시각·장소·인물·행위가 얼마나 구체적으로 기술됐는지. "어딘가에서", "언제쯤" 등 모호한 표현이 많을수록 감점.</div>
                            </div>
                            <div class="help-criterion">
                                <div class="help-criterion-name">감정 안정성 <span class="help-criterion-range">0 – 100점</span></div>
                                <div class="help-criterion-desc">진술 전반의 어조가 차분하고 중립적인 정도. 과도한 흥분·방어적 표현·감정적 과장이 빈번할수록 감점.</div>
                            </div>
                            <div class="help-criterion">
                                <div class="help-criterion-name">시간 정합성 <span class="help-criterion-range">0 – 100점</span></div>
                                <div class="help-criterion-desc">사건 진행 순서와 시간대가 논리적으로 맞는지. 시간 역행·공백·불가능한 이동 시간 등이 있으면 감점.</div>
                            </div>
                            <div class="help-total-note">종합 점수는 4개 기준의 단순 평균입니다.</div>
                        </div>
                    </div>
                </div>
                <div id="scoreDocTitle" style="font-size:15px;font-weight:500;color:#1a1a2e;"></div>
            </div>
            <button class="detail-close" onclick="closeScoreModal()" style="flex-shrink:0;margin-top:2px;">
                <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg>
            </button>
        </div>
        <div id="scoreModalContent"></div>
        <button class="btn-analyze" id="btnAnalyze" onclick="runScoreAnalysis()">신뢰도 분석 실행</button>
    </div>
</div>

<script>
var _cases = [];
var _currentFilter = 'all';
var _currentCaseId = null;
var _docScores = {};
var _currentScoreTranscriptId = null;

function badgeClass(status) {
    if (status === '진행중') return 'b-jinhaeng';
    if (status === '모순탐지') return 'b-moosun';
    if (status === '검토필요') return 'b-geomto';
    return 'b-wanryo';
}

function loadCases() {
    fetch(_ctx + '/caseApi?action=caseList', {credentials: 'same-origin'})
        .then(function(r) { return r.json(); })
        .then(function(data) {
            if (Array.isArray(data)) {
                _cases = data;
            } else if (data.cases) {
                _cases = data.cases;
            } else {
                _cases = [];
            }
            renderCases();
        })
        .catch(function() { showToast('사건 목록를 벊려엁 수 없습니다.'); });
}

function renderCases() {
    var kw = document.getElementById('searchInput').value.trim().toLowerCase();
    var list = _cases.filter(function(c) {
        var matchFilter = _currentFilter === 'all' || c.status === _currentFilter;
        var matchKw = !kw || (c.id||'').toLowerCase().includes(kw)
            || (c.name||'').toLowerCase().includes(kw)
            || (c.suspect||'').toLowerCase().includes(kw);
        return matchFilter && matchKw;
    });

    var el = document.getElementById('caseList');
    if (list.length === 0) {
        el.innerHTML = '<div class="empty-state">조건하는 사건이 없습니다</div>';
        return;
    }

    el.innerHTML = list.map(function(c) {
        var bc = badgeClass(c.status);
        var urgent = c.urgent ? 'urgent' : '';
        var sel = c.id === _currentCaseId ? 'selected' : '';
        return '<div class="case-row ' + urgent + ' ' + sel + '" onclick="openDetail(\'' + c.id + '\')">'
            + '<span class="case-id">' + (c.id||'') + '</span>'
            + '<span class="case-name">' + (c.name||'') + '</span>'
            + '<span class="case-suspect">' + (c.suspect||'') + '</span>'
            + '<span><span class="badge ' + bc + '">' + (c.status||'') + '</span></span>'
            + '<span class="doc-count">' + (c.docs||0) + '건</span>'
            + '<span class="contra-count">' + (c.contradictions > 0 ? c.contradictions + '건' : '-') + '</span>'
            + '<button class="action-btn" title="삭제" onclick="event.stopPropagation();confirmDelete(\'' + c.id + '\')">'
            + '<svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"><polyline points="3 6 5 6 21 6"/><path d="M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6m3 0V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2"/></svg>'
            + '</button>'
            + '</div>';
    }).join('');
}

function setFilter(btn) {
    document.querySelectorAll('.chip').forEach(function(c) { c.classList.remove('active'); });
    btn.classList.add('active');
    _currentFilter = btn.dataset.status;
    renderCases();
}

function filterCases() { renderCases(); }

function openDetail(caseId) {
    _currentCaseId = caseId;
    renderCases();
    document.getElementById('detailOverlay').classList.add('open');
    document.getElementById('detailPanel').classList.add('open');
    switchTab('info');

    fetch(_ctx + '/caseApi?action=caseDetail&caseId=' + encodeURIComponent(caseId), {credentials: 'same-origin'})
        .then(function(r) { return r.json(); })
        .then(function(d) {
            var c = d.case || d;
            document.getElementById('dpId').textContent = c.id || caseId;
            document.getElementById('dpName').textContent = c.name || '';
            document.getElementById('dpStatusSel').value = c.status || '진행중';

            var grid = document.getElementById('dpInfoGrid');
            grid.innerHTML = [
                ['피의자', c.suspect || '-'],
                ['종류', c.charge || '-'],
                ['당답 수사관', (c.rank || '') + ' ' + (c.detective || '-')],
                ['홍상 부서', c.deptName || '-'],
                ['등록일', c.date || '-'],
                ['조서 수', (c.docCount || 0) + '건']
            ].map(function(pair) {
                return '<div class="info-item"><div class="info-label">' + pair[0] + '</div><div class="info-value">' + pair[1] + '</div></div>';
            }).join('');

            var docs = c.docs || [];
            _docScores = {};
            var docEl = document.getElementById('dpDocList');
            if (docs.length === 0) {
                docEl.innerHTML = '<div class="empty-state">조서가 없습니다</div>';
            } else {
                docEl.innerHTML = docs.map(function(doc) {
                    _docScores[doc.id] = doc;
                    var contra = doc.contradiction ? 'has-contra' : '';
                    var scBadge;
                    if (doc.scored) {
                        var sc = doc.totalScore;
                        var scCls = sc >= 70 ? 'score-high' : sc >= 40 ? 'score-mid' : 'score-low';
                        scBadge = '<span id="score-badge-' + doc.id + '" class="score-badge ' + scCls + '" style="margin-right:4px">' + sc + '점</span>';
                    } else {
                        scBadge = '<span id="score-badge-' + doc.id + '" class="score-badge" style="display:none"></span>';
                    }
                    var docTitle = (doc.name || '미입력') + (doc.type ? ' ' + doc.type : '') + ' 진술조서';
                    var safeTitle = docTitle.replace(/\\/g, '\\\\').replace(/'/g, "\\'");
                    return '<a href="' + _ctx + '/desktop/writeTranscript?transcriptId=' + (doc.id||'') + '" class="doc-item ' + contra + '">'
                        + '<div class="doc-icon"><svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="#6b7280" stroke-width="1.8" stroke-linecap="round"><path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/><polyline points="14 2 14 8 20 8"/></svg></div>'
                        + '<div style="flex:1"><div class="doc-name">' + (doc.name || '조서 #' + doc.id) + '</div>'
                        + '<div class="doc-meta">' + (doc.date || '') + (doc.contradiction ? ' &nbsp;▸ 모순 탐지' : '') + '</div></div>'
                        + scBadge
                        + '<button class="score-btn" title="신뢰도 분석" onclick="event.preventDefault();event.stopPropagation();openScoreModal(' + (doc.id||0) + ',\'' + safeTitle + '\')">'
                        + '<svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><line x1="18" y1="20" x2="18" y2="10"/><line x1="12" y1="20" x2="12" y2="4"/><line x1="6" y1="20" x2="6" y2="14"/></svg>'
                        + '</button>'
                        + '</a>';
                }).join('');
            }
            document.getElementById('btnNewDoc').href = _ctx + '/desktop/writeTranscript?caseId=' + encodeURIComponent(caseId);
        })
        .catch(function() { showToast('사건 상세를 벊려엁 수 없습니다.'); });
}

function closeDetail() {
    _currentCaseId = null;
    document.getElementById('detailOverlay').classList.remove('open');
    document.getElementById('detailPanel').classList.remove('open');
    renderCases();
}

function switchTab(name) {
    document.querySelectorAll('.dtab').forEach(function(t, i) {
        t.classList.toggle('active', (i === 0 && name === 'info') || (i === 1 && name === 'docs'));
    });
    document.getElementById('tabInfo').classList.toggle('active', name === 'info');
    document.getElementById('tabDocs').classList.toggle('active', name === 'docs');
}

function saveStatus() {
    if (!_currentCaseId) return;
    var status = document.getElementById('dpStatusSel').value;
    var fd = new FormData();
    fd.append('action', 'caseStatus');
    fd.append('caseId', _currentCaseId);
    fd.append('status', status);
    fetch(_ctx + '/caseApi', {method: 'POST', body: fd, credentials: 'same-origin'})
        .then(function(r) { return r.json(); })
        .then(function() {
            showToast('상태가 업데이트되었습니다.');
            loadCases();
        });
}

function confirmDelete(caseId) {
    if (!confirm('사건 ' + caseId + '를 삭제하시겠습니꿀?')) return;
    doDelete(caseId);
}
function deleteCase() {
    if (!_currentCaseId) return;
    if (!confirm('사건 ' + _currentCaseId + '를 삭제하시겠습니꿀?')) return;
    doDelete(_currentCaseId);
    closeDetail();
}
function doDelete(caseId) {
    var fd = new FormData();
    fd.append('action', 'caseDelete');
    fd.append('caseId', caseId);
    fetch(_ctx + '/caseApi', {method: 'POST', body: fd, credentials: 'same-origin'})
        .then(function(r) { return r.json(); })
        .then(function() { showToast('삭제되었습니다.'); loadCases(); });
}

function openNewModal() { document.getElementById('newModal').classList.add('open'); }
function closeNewModal() { document.getElementById('newModal').classList.remove('open'); }

function createCase() {
    var name = document.getElementById('newCaseName').value.trim();
    if (!name) { showToast('사건명을 입력해 주세요.'); return; }
    var fd = new FormData();
    fd.append('action', 'caseCreate');
    fd.append('caseName', name);
    fd.append('suspect', document.getElementById('newSuspect').value.trim());
    fd.append('charge',  document.getElementById('newCharge').value.trim());
    fetch(_ctx + '/caseApi', {method: 'POST', body: fd, credentials: 'same-origin'})
        .then(function(r) { return r.json(); })
        .then(function(d) {
            closeNewModal();
            document.getElementById('newCaseName').value = '';
            document.getElementById('newSuspect').value = '';
            document.getElementById('newCharge').value = '';
            showToast('사건이 등록되었습니다.');
            loadCases();
            if (d.caseId) openDetail(d.caseId);
        })
        .catch(function() { showToast('등록 중 오류가 발생피습니다.'); });
}

function showToast(msg) {
    var t = document.getElementById('toast');
    t.textContent = msg;
    t.classList.add('show');
    setTimeout(function() { t.classList.remove('show'); }, 2500);
}

function toggleHelp(e) {
    e.stopPropagation();
    var pop = document.getElementById('helpPopover');
    pop.classList.toggle('open');
}
document.addEventListener('click', function(e) {
    var pop = document.getElementById('helpPopover');
    if (pop && pop.classList.contains('open') && !pop.contains(e.target)) {
        pop.classList.remove('open');
    }
});

function openScoreModal(transcriptId, docTitle) {
    _currentScoreTranscriptId = transcriptId;
    document.getElementById('scoreDocTitle').textContent = docTitle;
    var btn = document.getElementById('btnAnalyze');
    btn.disabled = false;
    var doc = _docScores[transcriptId];
    if (doc && doc.scored) {
        renderScoreResult({
            total: doc.totalScore, consistency: doc.consistency,
            specificity: doc.specificity, emotion: doc.emotion, temporal: doc.temporal,
            reasons: { consistency: doc.cReason, specificity: doc.sReason, emotion: doc.eReason, temporal: doc.tReason }
        });
        btn.textContent = '재분석';
    } else {
        document.getElementById('scoreModalContent').innerHTML =
            '<div class="score-empty-state">아직 분석된 신뢰도 점수가 없습니다.</div>';
        btn.textContent = '신뢰도 분석 실행';
    }
    document.getElementById('scoreModal').classList.add('open');
}

function closeScoreModal() {
    document.getElementById('scoreModal').classList.remove('open');
    document.getElementById('helpPopover').classList.remove('open');
    _currentScoreTranscriptId = null;
}

function renderScoreResult(data) {
    var total = data.total || 0;
    var grade = total >= 70 ? '신뢰도 높음' : total >= 40 ? '검토 필요' : '신뢰도 낮음';
    var numColor = total >= 70 ? '#16a34a' : total >= 40 ? '#d97706' : '#dc2626';
    var bars = [
        { label: '일관성',     val: data.consistency || 0, reason: (data.reasons||{}).consistency || '' },
        { label: '구체성',     val: data.specificity  || 0, reason: (data.reasons||{}).specificity || '' },
        { label: '감정 안정성', val: data.emotion     || 0, reason: (data.reasons||{}).emotion     || '' },
        { label: '시간 정합성', val: data.temporal    || 0, reason: (data.reasons||{}).temporal    || '' }
    ];
    var html = '<div class="score-total-card">'
        + '<div class="score-total-num" style="color:' + numColor + '">' + total + '</div>'
        + '<div><div class="score-total-label">종합 신뢰도</div><div class="score-total-grade">' + grade + '</div></div>'
        + '</div><div class="score-bars">';
    bars.forEach(function(b) {
        var fc = b.val >= 70 ? 'fill-high' : b.val >= 40 ? 'fill-mid' : 'fill-low';
        html += '<div>'
            + '<div class="score-row-header"><span class="score-row-label">' + b.label + '</span><span class="score-row-val">' + b.val + '점</span></div>'
            + '<div class="score-bar-track"><div class="score-bar-fill ' + fc + '" style="width:' + b.val + '%"></div></div>'
            + (b.reason ? '<div class="score-row-reason">' + b.reason + '</div>' : '')
            + '</div>';
    });
    html += '</div>';
    document.getElementById('scoreModalContent').innerHTML = html;
}

function runScoreAnalysis() {
    if (!_currentScoreTranscriptId) return;
    var btn = document.getElementById('btnAnalyze');
    btn.disabled = true;
    btn.textContent = '분석 중...';
    document.getElementById('scoreModalContent').innerHTML =
        '<div class="score-loading-state">AI가 진술을 분석하는 중입니다...<br><small>약 30~60초 소요됩니다</small></div>';
    var fd = new FormData();
    fd.append('action', 'scoreTranscript');
    fd.append('transcriptId', _currentScoreTranscriptId);
    fetch(_ctx + '/caseApi', { method: 'POST', body: fd, credentials: 'same-origin' })
        .then(function(r) { return r.json(); })
        .then(function(d) {
            btn.disabled = false;
            if (d.success) {
                var doc = _docScores[_currentScoreTranscriptId];
                if (doc) {
                    doc.scored = true; doc.totalScore = d.total;
                    doc.consistency = d.consistency; doc.specificity = d.specificity;
                    doc.emotion = d.emotion; doc.temporal = d.temporal;
                    doc.cReason = (d.reasons||{}).consistency || '';
                    doc.sReason = (d.reasons||{}).specificity || '';
                    doc.eReason = (d.reasons||{}).emotion     || '';
                    doc.tReason = (d.reasons||{}).temporal    || '';
                }
                renderScoreResult(d);
                updateScoreBadge(_currentScoreTranscriptId, d.total);
                btn.textContent = '재분석';
                showToast('신뢰도 분석이 완료되었습니다.');
            } else {
                document.getElementById('scoreModalContent').innerHTML =
                    '<div class="score-empty-state">' + (d.message || '분석에 실패했습니다.') + '</div>';
                btn.textContent = '다시 시도';
            }
        })
        .catch(function() {
            btn.disabled = false;
            btn.textContent = '다시 시도';
            document.getElementById('scoreModalContent').innerHTML =
                '<div class="score-empty-state">오류가 발생했습니다.</div>';
        });
}

function updateScoreBadge(transcriptId, score) {
    var badge = document.getElementById('score-badge-' + transcriptId);
    if (!badge) return;
    var cls = score >= 70 ? 'score-high' : score >= 40 ? 'score-mid' : 'score-low';
    badge.className = 'score-badge ' + cls;
    badge.textContent = score + '점';
    badge.style.display = '';
}

loadCases();


if (_initCaseId) { setTimeout(function() { openDetail(_initCaseId); }, 300); }
</script>
</body>
</html>
