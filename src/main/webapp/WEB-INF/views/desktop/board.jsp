<%@ page language="java" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8"%>
<%
String loginUser = (String) session.getAttribute("loginUser");
String userName  = (String) session.getAttribute("userName");
String userRank  = (String) session.getAttribute("userRank");
if (userName == null) userName = loginUser != null ? loginUser : "";
if (userRank == null) userRank = "";
request.setAttribute("currentPage", "board");
request.setAttribute("breadcrumb",  new String[]{"POL-MATE", "커뮤니티 게시판"});
%>
<!DOCTYPE html>
<html lang="ko">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>POL-MATE | 커뮤니티 게시판</title>
<link href="https://fonts.googleapis.com/css2?family=Noto+Sans+KR:wght@300;400;500;700&family=Space+Grotesk:wght@500;700&display=swap" rel="stylesheet">
<link rel="stylesheet" href="${pageContext.request.contextPath}/css/polmate.css">
<script>var _ctx='${pageContext.request.contextPath}'; var _loginUser='<%= loginUser %>'; var _userName='<%= userName %>'; var _userRank='<%= userRank %>';</script>
<style>
* { box-sizing: border-box; margin: 0; padding: 0; }
html, body { height: 100%; font-family: 'Noto Sans KR', sans-serif; background: #f4f6fb; color: #1a1a2e; -webkit-font-smoothing: antialiased; }
.pm-page { padding: 28px 32px 48px; }

.page-header { display:flex; align-items:flex-end; justify-content:space-between; margin-bottom:20px; }
.page-title  { font-size:22px; font-weight:500; }
.page-sub    { font-size:12px; color:#9ca3af; margin-top:3px; }
.btn-write {
    display:flex; align-items:center; gap:6px;
    background:#0d1a33; color:#fff; border:none; border-radius:10px;
    padding:9px 16px; font-size:13px; font-family:'Noto Sans KR',sans-serif;
    font-weight:500; cursor:pointer; transition:background 0.13s;
}
.btn-write:hover { background:#1a2744; }

/* 카테고리 탭 */
.cat-tabs { display:flex; gap:6px; margin-bottom:18px; }
.cat-tab {
    padding:7px 16px; border-radius:20px; font-size:12px; font-family:'Noto Sans KR',sans-serif;
    border:1px solid #e2e5ee; background:#fff; color:#6b7280; cursor:pointer; transition:all 0.13s;
    display:flex; align-items:center; gap:5px;
}
.cat-tab .tab-dot { width:6px; height:6px; border-radius:50%; flex-shrink:0; }
.cat-tab.active { background:#0d1a33; color:#fff; border-color:#0d1a33; }
.cat-tab.active .tab-dot { background:#f0c040; }
.cat-tab:not(.active).tip-tab   .tab-dot { background:#f97316; }
.cat-tab:not(.active).gear-tab  .tab-dot { background:#16a34a; }
.cat-tab:not(.active).free-tab  .tab-dot { background:#4a7cdc; }

/* 검색 + 정렬 */
.toolbar { display:flex; align-items:center; gap:10px; margin-bottom:16px; }
.search-box {
    flex:1; max-width:320px; display:flex; align-items:center; gap:8px;
    background:#fff; border:1.5px solid #e2e5ee; border-radius:12px; padding:8px 14px;
    transition:border-color 0.15s;
}
.search-box:focus-within { border-color:#0d1a33; }
.search-box input { border:none; background:transparent; outline:none; font-size:13px; font-family:'Noto Sans KR',sans-serif; color:#1a1a2e; width:100%; }
.search-box input::placeholder { color:#9ca3af; }
.sort-select { padding:7px 12px; border:1.5px solid #e2e5ee; border-radius:10px; font-size:12px; font-family:'Noto Sans KR',sans-serif; color:#6b7280; background:#fff; outline:none; cursor:pointer; }

/* 게시글 리스트 */
.board-list { display:flex; flex-direction:column; gap:10px; }
.post-card {
    background:#fff; border:1px solid #e2e5ee; border-radius:14px;
    padding:18px 20px; cursor:pointer; transition:border-color 0.13s, box-shadow 0.13s;
}
.post-card:hover { border-color:#0d1a33; box-shadow:0 4px 16px rgba(13,26,51,0.06); }
.post-head { display:flex; align-items:center; gap:10px; margin-bottom:10px; }
.cat-badge { font-size:10px; font-weight:500; padding:3px 9px; border-radius:20px; flex-shrink:0; }
.cat-tip  { background:#fff7ed; color:#c2410c; }
.cat-gear { background:#f0fdf4; color:#166534; }
.cat-free { background:#eff6ff; color:#1e40af; }
.post-title { font-size:14px; font-weight:500; flex:1; white-space:nowrap; overflow:hidden; text-overflow:ellipsis; }
.pinned-icon { color:#f0c040; flex-shrink:0; }
.post-preview { font-size:12px; color:#6b7280; line-height:1.6; margin-bottom:12px; display:-webkit-box; -webkit-line-clamp:2; -webkit-box-orient:vertical; overflow:hidden; }
.post-tags { display:flex; gap:6px; flex-wrap:wrap; margin-bottom:10px; }
.tag-item { font-size:10px; background:#f4f6fb; border:1px solid #e2e5ee; border-radius:4px; padding:2px 7px; color:#9ca3af; }
.post-foot { display:flex; align-items:center; gap:16px; font-size:11px; color:#9ca3af; }
.post-foot-left { display:flex; align-items:center; gap:5px; }
.stat-icon { display:flex; align-items:center; gap:3px; }

.empty-state { padding:60px 20px; text-align:center; color:#9ca3af; font-size:13px; }
.load-more { width:100%; padding:11px; background:#fff; border:1.5px solid #e2e5ee; border-radius:12px; font-size:13px; font-family:'Noto Sans KR',sans-serif; color:#6b7280; cursor:pointer; margin-top:12px; transition:all 0.13s; }
.load-more:hover { border-color:#0d1a33; color:#0d1a33; }

/* 작성 모달 */
.modal-backdrop { display:none; position:fixed; inset:0; background:rgba(0,0,0,0.35); z-index:300; align-items:center; justify-content:center; }
.modal-backdrop.open { display:flex; }
.modal { background:#fff; border-radius:18px; padding:28px; width:620px; max-height:90vh; overflow-y:auto; box-shadow:0 20px 60px rgba(0,0,0,0.2); }
.modal-title { font-size:16px; font-weight:500; margin-bottom:20px; }
.form-field { margin-bottom:14px; }
.form-label { display:block; font-size:10px; font-weight:500; color:#6b7280; text-transform:uppercase; letter-spacing:0.7px; margin-bottom:6px; }
.form-input, .form-select { width:100%; padding:10px 12px; border:1.5px solid #e2e5ee; border-radius:10px; font-size:13px; font-family:'Noto Sans KR',sans-serif; color:#1a1a2e; background:#f4f6fb; outline:none; }
.form-input:focus, .form-select:focus { border-color:#0d1a33; background:#fff; box-shadow:0 0 0 3px rgba(13,26,51,0.07); }
.form-textarea { width:100%; min-height:180px; padding:12px; border:1.5px solid #e2e5ee; border-radius:10px; font-size:13px; font-family:'Noto Sans KR',sans-serif; color:#1a1a2e; background:#f4f6fb; outline:none; resize:vertical; line-height:1.7; }
.form-textarea:focus { border-color:#0d1a33; background:#fff; }
.modal-actions { display:flex; gap:8px; justify-content:flex-end; margin-top:20px; }
.btn-cancel  { padding:9px 18px; background:transparent; border:1px solid #e2e5ee; border-radius:10px; font-size:13px; font-family:'Noto Sans KR',sans-serif; cursor:pointer; color:#6b7280; }
.btn-confirm { padding:9px 18px; background:#0d1a33; color:#fff; border:none; border-radius:10px; font-size:13px; font-family:'Noto Sans KR',sans-serif; cursor:pointer; }

.toast { position:fixed; bottom:28px; left:50%; transform:translateX(-50%) translateY(80px); background:#1a2744; color:#fff; padding:10px 20px; border-radius:10px; font-size:13px; font-family:'Noto Sans KR',sans-serif; opacity:0; transition:all 0.25s; z-index:500; white-space:nowrap; }
.toast.show { opacity:1; transform:translateX(-50%) translateY(0); }
</style>
</head>
<body>
<div class="pm-layout">

<%@ include file="sidebar.jsp" %>
<div class="pm-content">
<%@ include file="appbar.jsp" %>

<main class="pm-page">

    <div class="page-header">
        <div>
            <div class="page-title">커뮤니티 게시판</div>
            <div class="page-sub">수사관 간 정보 공유 및 노하우 교류</div>
        </div>
        <button class="btn-write" onclick="openWriteModal()">
            <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><line x1="12" y1="5" x2="12" y2="19"/><line x1="5" y1="12" x2="19" y2="12"/></svg>
            글쓰기
        </button>
    </div>

    <div class="cat-tabs">
        <button class="cat-tab active" data-cat="all" onclick="setCat(this)">
            <span class="tab-dot" style="background:#9ca3af;"></span>전체
        </button>
        <button class="cat-tab tip-tab" data-cat="수사팁" onclick="setCat(this)">
            <span class="tab-dot"></span>수사 팁
        </button>
        <button class="cat-tab gear-tab" data-cat="장비정보" onclick="setCat(this)">
            <span class="tab-dot"></span>장비 정보
        </button>
        <button class="cat-tab free-tab" data-cat="자유" onclick="setCat(this)">
            <span class="tab-dot"></span>자유
        </button>
    </div>

    <div class="toolbar">
        <div class="search-box">
            <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="#9ca3af" stroke-width="1.8" stroke-linecap="round"><circle cx="11" cy="11" r="8"/><line x1="21" y1="21" x2="16.65" y2="16.65"/></svg>
            <input type="text" id="searchInput" placeholder="제목, 내용, 태그 검색..." oninput="filterPosts()">
        </div>
        <select class="sort-select" id="sortSelect" onchange="loadPosts()">
            <option value="latest">최신순</option>
            <option value="popular">인기순</option>
            <option value="comments">댓글순</option>
        </select>
    </div>

    <div class="board-list" id="postList">
        <div class="empty-state">로드 중...</div>
    </div>
    <button class="load-more" id="btnLoadMore" style="display:none;" onclick="loadMore()">더 보기</button>

</main>
</div>
</div>

<!-- 글쓰기 모달 -->
<div class="modal-backdrop" id="writeModal">
    <div class="modal" onclick="event.stopPropagation()">
        <div class="modal-title">게시글 작성</div>
        <div class="form-field">
            <label class="form-label">카테고리</label>
            <select class="form-select" id="wCat">
                <option value="수사팁">수사 팁</option>
                <option value="장비정보">장비 정보</option>
                <option value="자유">자유</option>
            </select>
        </div>
        <div class="form-field">
            <label class="form-label">제목 <span style="color:#dc2626">*</span></label>
            <input type="text" class="form-input" id="wTitle" placeholder="게시글 제목을 입력하세요">
        </div>
        <div class="form-field">
            <label class="form-label">내용 <span style="color:#dc2626">*</span></label>
            <textarea class="form-textarea" id="wContent" placeholder="내용을 입력하세요..."></textarea>
        </div>
        <div class="form-field">
            <label class="form-label">태그 <span style="color:#9ca3af;font-size:9px;text-transform:none;">쉼표로 구분</span></label>
            <input type="text" class="form-input" id="wTags" placeholder="예: 수사기법, 조서작성, 증거">
        </div>
        <div class="modal-actions">
            <button class="btn-cancel" onclick="closeWriteModal()">취소</button>
            <button class="btn-confirm" onclick="submitPost()">게시</button>
        </div>
    </div>
</div>

<div class="toast" id="toast"></div>

<script>
var _posts = [];
var _page  = 1;
var _pageSize = 15;
var _currentCat = 'all';
var _hasMore = false;

function loadPosts(reset) {
    if (reset) { _page = 1; _posts = []; }
    var sort = document.getElementById('sortSelect').value;
    var cat  = _currentCat === 'all' ? '' : _currentCat;
    fetch(_ctx + '/board?action=list&category=' + encodeURIComponent(cat) + '&sort=' + sort, {credentials:'same-origin'})
        .then(function(r){return r.json();})
        .then(function(d) {
            var items = d.posts || d || [];
            if (reset) _posts = items; else _posts = _posts.concat(items);
            _hasMore = items.length === _pageSize;
            renderPosts();
        })
        .catch(function() { document.getElementById('postList').innerHTML = '<div class="empty-state">게시글을 불러올 수 없습니다.</div>'; });
}

function renderPosts() {
    var kw = document.getElementById('searchInput').value.trim().toLowerCase();
    var list = kw ? _posts.filter(function(p) {
        return (p.title||'').toLowerCase().includes(kw) || (p.content||'').toLowerCase().includes(kw) || ((p.tags||[]).join(' ')).toLowerCase().includes(kw);
    }) : _posts;

    var el = document.getElementById('postList');
    if (list.length === 0) { el.innerHTML = '<div class="empty-state">게시글이 없습니다.</div>'; document.getElementById('btnLoadMore').style.display='none'; return; }

    el.innerHTML = list.map(function(p) {
        var catCls = p.cat === '수사팁' ? 'cat-tip' : p.cat === '장비정보' ? 'cat-gear' : 'cat-free';
        var tags = (p.tags || []).map(function(t){ return '<span class="tag-item">#' + t + '</span>'; }).join('');
        return '<div class="post-card" onclick="openPost(' + p.id + ')">'
            + '<div class="post-head">'
            + '<span class="cat-badge ' + catCls + '">' + (p.cat||'자유') + '</span>'
            + (p.hot ? '<svg class="pinned-icon" width="13" height="13" viewBox="0 0 24 24" fill="#f0c040" stroke="none"><path d="M12 2l3.09 6.26L22 9.27l-5 4.87 1.18 6.88L12 17.77l-6.18 3.25L7 14.14 2 9.27l6.91-1.01L12 2z"/></svg>' : '')
            + '<span class="post-title">' + (p.title||'') + '</span>'
            + '</div>'
            + '<div class="post-preview">' + (p.preview||'') + '</div>'
            + (tags ? '<div class="post-tags">' + tags + '</div>' : '')
            + '<div class="post-foot">'
            + '<div class="post-foot-left">'
            + '<span>' + (p.authorRank||'') + ' ' + (p.author||'') + '</span>'
            + '<span>·</span><span>' + (p.date||'') + '</span>'
            + '</div>'
            + '<div style="margin-left:auto;display:flex;gap:12px;">'
            + '<span class="stat-icon"><svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"><path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z"/><circle cx="12" cy="12" r="3"/></svg> ' + (p.views||0) + '</span>'
            + '<span class="stat-icon"><svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"><path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z"/></svg> ' + (p.commentCount||0) + '</span>'
            + '<span class="stat-icon"><svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"><path d="M20.84 4.61a5.5 5.5 0 0 0-7.78 0L12 5.67l-1.06-1.06a5.5 5.5 0 0 0-7.78 7.78l1.06 1.06L12 21.23l7.78-7.78 1.06-1.06a5.5 5.5 0 0 0 0-7.78z"/></svg> ' + (p.likes||0) + '</span>'
            + '</div></div></div>';
    }).join('');
    document.getElementById('btnLoadMore').style.display = (_hasMore && !kw) ? 'block' : 'none';
}

function filterPosts() { renderPosts(); }

function setCat(btn) {
    document.querySelectorAll('.cat-tab').forEach(function(t){t.classList.remove('active');});
    btn.classList.add('active');
    _currentCat = btn.dataset.cat;
    loadPosts(true);
}

function loadMore() { _page++; loadPosts(false); }

function openPost(id) {
    location.href = _ctx + '/desktop/boardView?postId=' + id;
}

function openWriteModal()  { document.getElementById('writeModal').classList.add('open'); }
function closeWriteModal() { document.getElementById('writeModal').classList.remove('open'); }

function submitPost() {
    var title   = document.getElementById('wTitle').value.trim();
    var content = document.getElementById('wContent').value.trim();
    var cat     = document.getElementById('wCat').value;
    var tags    = document.getElementById('wTags').value.trim();
    if (!title)   { showToast('제목을 입력해 주세요.'); return; }
    if (!content) { showToast('내용을 입력해 주세요.'); return; }
    var fd = new FormData();
    fd.append('action', 'write');
    fd.append('title', title);
    fd.append('content', content);
    fd.append('category', cat);
    fd.append('tags', tags);
    fetch(_ctx + '/board', {method:'POST', body:fd, credentials:'same-origin'})
        .then(function(r){return r.json();})
        .then(function(d){
            if (d.success || d.postId) {
                closeWriteModal();
                document.getElementById('wTitle').value=''; document.getElementById('wContent').value=''; document.getElementById('wTags').value='';
                showToast('게시글이 등록되었습니다.');
                loadPosts(true);
            } else { showToast(d.message || '등록에 실패했습니다.'); }
        }).catch(function(){showToast('서버 통신 오류가 발생했습니다.');});
}

function showToast(msg) {
    var t=document.getElementById('toast'); t.textContent=msg; t.classList.add('show');
    setTimeout(function(){t.classList.remove('show');},2500);
}

document.getElementById('writeModal').addEventListener('click', function(e){if(e.target===this)closeWriteModal();});
loadPosts(true);
</script>
</body>
</html>
