<%@ page language="java" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8"%>
<%
String postIdParam = request.getParameter("postId");
if (postIdParam == null || postIdParam.trim().isEmpty()) {
    response.sendRedirect(request.getContextPath() + "/desktop/board");
    return;
}
request.setAttribute("currentPage", "board");
request.setAttribute("breadcrumb", new String[]{"POL-MATE", "커뮤니티", "게시글"});
String safePostId = postIdParam.replaceAll("[^0-9]", "");
%>
<!DOCTYPE html>
<html lang="ko">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>POL-MATE | 게시글</title>
<link href="https://fonts.googleapis.com/css2?family=Noto+Sans+KR:wght@300;400;500;700&family=Space+Grotesk:wght@500;700&display=swap" rel="stylesheet">
<link rel="stylesheet" href="${pageContext.request.contextPath}/css/polmate.css">
<script>var _ctx = '${pageContext.request.contextPath}';</script>
<style>
* { box-sizing: border-box; margin: 0; padding: 0; }
html, body { height: 100%; font-family: 'Noto Sans KR', sans-serif; background: #f4f6fb; color: #1a1a2e; -webkit-font-smoothing: antialiased; }
.pm-page { padding: 28px 32px 48px; max-width: 860px; }

.back-link { display: inline-flex; align-items: center; gap: 7px; font-size: 13px; color: #6b7280; text-decoration: none; margin-bottom: 18px; transition: color 0.13s; }
.back-link:hover { color: #0d1a33; }
.back-link svg { width: 15px; height: 15px; stroke: currentColor; fill: none; stroke-width: 2; stroke-linecap: round; }

.post-card {
    background: #fff; border: 1px solid #e2e5ee; border-radius: 14px;
    padding: 28px 32px; margin-bottom: 16px;
}

.post-category { display: inline-block; font-size: 11px; font-weight: 500; padding: 3px 10px; border-radius: 20px; margin-bottom: 12px; }
.cat-수사팁 { background: #eff6ff; color: #1e40af; }
.cat-장비정보 { background: #f0fdf4; color: #166534; }
.cat-자유 { background: #f3f4f6; color: #6b7280; }
.cat-공지 { background: #fef3c7; color: #92400e; }

.post-title { font-size: 22px; font-weight: 600; color: #0d1a33; line-height: 1.4; margin-bottom: 14px; }

.post-meta { display: flex; align-items: center; gap: 16px; padding-bottom: 20px; border-bottom: 1px solid #f0f1f5; margin-bottom: 24px; }
.meta-avatar { width: 36px; height: 36px; border-radius: 10px; background: #1a2744; display: flex; align-items: center; justify-content: center; font-size: 13px; font-weight: 600; color: #fff; flex-shrink: 0; }
.meta-info { flex: 1; }
.meta-name { font-size: 13px; font-weight: 500; color: #1a1a2e; }
.meta-sub { font-size: 11px; color: #9ca3af; margin-top: 2px; }
.meta-stats { display: flex; align-items: center; gap: 14px; }
.stat-item { display: flex; align-items: center; gap: 5px; font-size: 12px; color: #9ca3af; }
.stat-item svg { width: 14px; height: 14px; stroke: currentColor; fill: none; stroke-width: 1.8; stroke-linecap: round; }

.post-content { font-size: 14px; line-height: 2; color: #374151; white-space: pre-wrap; word-break: break-word; margin-bottom: 24px; }

.post-tags { display: flex; flex-wrap: wrap; gap: 7px; margin-bottom: 20px; }
.tag { font-size: 11px; background: #f4f6fb; border: 1px solid #e2e5ee; border-radius: 6px; padding: 3px 10px; color: #6b7280; }

.post-actions { display: flex; align-items: center; gap: 10px; border-top: 1px solid #f0f1f5; padding-top: 20px; }
.btn-like {
    display: flex; align-items: center; gap: 7px;
    padding: 9px 18px; border-radius: 10px; border: 1.5px solid #e2e5ee;
    background: transparent; color: #6b7280; font-size: 13px;
    font-family: 'Noto Sans KR', sans-serif; cursor: pointer;
    transition: all 0.15s;
}
.btn-like:hover, .btn-like.liked { background: #eff6ff; border-color: #4a7cdc; color: #1e40af; }
.btn-like svg { width: 16px; height: 16px; stroke: currentColor; stroke-width: 1.8; stroke-linecap: round; fill: none; }
.btn-like.liked svg { fill: #4a7cdc; stroke: #4a7cdc; }
.btn-share {
    display: flex; align-items: center; gap: 7px;
    padding: 9px 18px; border-radius: 10px; border: 1.5px solid #e2e5ee;
    background: transparent; color: #6b7280; font-size: 13px;
    font-family: 'Noto Sans KR', sans-serif; cursor: pointer;
    transition: all 0.15s;
}
.btn-share:hover { background: #f4f6fb; }
.btn-share svg { width: 15px; height: 15px; stroke: currentColor; stroke-width: 1.8; stroke-linecap: round; fill: none; }
.btn-delete {
    margin-left: auto;
    display: flex; align-items: center; gap: 7px;
    padding: 9px 18px; border-radius: 10px; border: 1.5px solid #fecaca;
    background: transparent; color: #dc2626; font-size: 13px;
    font-family: 'Noto Sans KR', sans-serif; cursor: pointer;
    transition: all 0.15s;
}
.btn-delete:hover { background: #fef2f2; }
.btn-delete svg { width: 15px; height: 15px; stroke: currentColor; stroke-width: 1.8; stroke-linecap: round; fill: none; }

/* 댓글 */
.comment-card { background: #fff; border: 1px solid #e2e5ee; border-radius: 14px; padding: 24px 28px; }
.section-title { font-size: 14px; font-weight: 600; color: #0d1a33; margin-bottom: 18px; display: flex; align-items: center; gap: 8px; }
.section-title span { font-size: 13px; color: #4a7cdc; font-weight: 400; }

.comment-list { display: flex; flex-direction: column; gap: 14px; margin-bottom: 20px; }
.comment-item { display: flex; gap: 12px; }
.comment-avatar { width: 32px; height: 32px; border-radius: 9px; background: #f0f3f9; display: flex; align-items: center; justify-content: center; font-size: 12px; font-weight: 500; color: #6b7280; flex-shrink: 0; }
.comment-body { flex: 1; min-width: 0; }
.comment-header { display: flex; align-items: center; gap: 8px; margin-bottom: 5px; }
.comment-name { font-size: 12px; font-weight: 500; color: #1a1a2e; }
.comment-rank { font-size: 10px; color: #9ca3af; }
.comment-time { font-size: 10px; color: #9ca3af; }
.comment-text { font-size: 13px; color: #374151; line-height: 1.7; }
.comment-del { margin-left: auto; background: none; border: none; cursor: pointer; color: #d1d5db; font-size: 11px; padding: 2px 6px; border-radius: 5px; transition: color 0.13s; flex-shrink: 0; }
.comment-del:hover { color: #dc2626; }

.comment-empty { padding: 28px 0; text-align: center; font-size: 13px; color: #9ca3af; }

.comment-input-row { display: flex; gap: 10px; align-items: flex-end; }
.comment-input {
    flex: 1; padding: 11px 14px; background: #f4f6fb; border: 1.5px solid #e2e5ee;
    border-radius: 10px; font-size: 13px; font-family: 'Noto Sans KR', sans-serif;
    color: #1a1a2e; outline: none; resize: none; min-height: 44px; max-height: 120px;
    line-height: 1.6; transition: border-color 0.15s;
}
.comment-input:focus { border-color: #4a7cdc; background: #fff; }
.comment-input::placeholder { color: #9ca3af; }
.btn-comment-submit {
    padding: 11px 18px; border-radius: 10px; border: none;
    background: #0d1a33; color: #fff; font-size: 13px; font-weight: 500;
    font-family: 'Noto Sans KR', sans-serif; cursor: pointer;
    transition: background 0.13s; white-space: nowrap;
}
.btn-comment-submit:hover { background: #1a2744; }

.loading-state { padding: 48px; text-align: center; }
.loading-state svg { width: 32px; height: 32px; stroke: #9ca3af; fill: none; stroke-width: 1.5; stroke-linecap: round; animation: spin 1s linear infinite; margin-bottom: 10px; }
.loading-state p { font-size: 13px; color: #9ca3af; }
@keyframes spin { to { transform: rotate(360deg); } }

.toast { position: fixed; bottom: 28px; left: 50%; transform: translateX(-50%) translateY(80px); background: #1a2744; color: #fff; padding: 10px 20px; border-radius: 10px; font-size: 13px; font-family: 'Noto Sans KR', sans-serif; opacity: 0; transition: all 0.25s; z-index: 500; white-space: nowrap; }
.toast.show { opacity: 1; transform: translateX(-50%) translateY(0); }
</style>
</head>
<body>
<div class="pm-layout">

<%@ include file="sidebar.jsp" %>
<div class="pm-content">
<%@ include file="appbar.jsp" %>

<main class="pm-page">
    <a href="${pageContext.request.contextPath}/desktop/board" class="back-link">
        <svg viewBox="0 0 24 24"><polyline points="15 18 9 12 15 6"/></svg>
        커뮤니티 게시판으로 돌아가기
    </a>

    <div id="postArea">
        <div class="loading-state">
            <svg viewBox="0 0 24 24"><path d="M21 12a9 9 0 1 1-6.22-8.56"/></svg>
            <p>게시글을 불러오는 중...</p>
        </div>
    </div>

    <div id="commentArea" style="display:none;">
        <div class="comment-card">
            <div class="section-title">댓글 <span id="commentCountLabel"></span></div>
            <div class="comment-list" id="commentList"></div>
            <div class="comment-input-row">
                <textarea class="comment-input" id="commentInput" rows="1" placeholder="댓글을 입력하세요..." oninput="autoResizeComment(this)"></textarea>
                <button class="btn-comment-submit" onclick="submitComment()">등록</button>
            </div>
        </div>
    </div>
</main>
</div>
</div>

<div class="toast" id="toast"></div>

<script>
var _postId = '<%= safePostId %>';
var _postData = null;
var _isLiked = false;

function loadPost() {
    fetch(_ctx + '/board?action=detail&id=' + _postId, { credentials: 'same-origin' })
        .then(function(r) { return r.json(); })
        .then(function(d) {
            if (d.error || !d.id) {
                document.getElementById('postArea').innerHTML =
                    '<div class="loading-state"><p style="color:#dc2626;">' + (d.error || '게시글을 찾을 수 없습니다.') + '</p></div>';
                return;
            }
            _postData = d;
            _isLiked = d.liked || false;
            renderPost(d);
            renderComments(d.comments || []);
            document.getElementById('commentArea').style.display = '';
        })
        .catch(function() {
            document.getElementById('postArea').innerHTML =
                '<div class="loading-state"><p style="color:#dc2626;">게시글을 불러올 수 없습니다.</p></div>';
        });
}

function renderPost(p) {
    var initial = (p.author || '?').charAt(0);
    var catCls = 'cat-' + (p.cat || '자유');
    var tags = Array.isArray(p.tags) ? p.tags : (p.tags || '').split(',').filter(function(t) { return t.trim(); });
    var tagsHtml = tags.map(function(t) { return '<span class="tag">' + esc(String(t).trim()) + '</span>'; }).join('');
    var html =
        '<div class="post-card">' +
            '<span class="post-category ' + catCls + '">' + esc(p.cat || '자유') + '</span>' +
            '<div class="post-title">' + esc(p.title || '') + '</div>' +
            '<div class="post-meta">' +
                '<div class="meta-avatar">' + esc(initial) + '</div>' +
                '<div class="meta-info">' +
                    '<div class="meta-name">' + esc(p.authorRank || '') + ' ' + esc(p.author || '') + '</div>' +
                    '<div class="meta-sub">' + esc(p.authorOrg || '') + ' · ' + esc(p.date || '') + '</div>' +
                '</div>' +
                '<div class="meta-stats">' +
                    '<span class="stat-item"><svg viewBox="0 0 24 24"><path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z"/><circle cx="12" cy="12" r="3"/></svg>' + (p.views || 0) + '</span>' +
                    '<span class="stat-item"><svg viewBox="0 0 24 24"><path d="M20.84 4.61a5.5 5.5 0 0 0-7.78 0L12 5.67l-1.06-1.06a5.5 5.5 0 0 0-7.78 7.78l1.06 1.06L12 21.23l7.78-7.78 1.06-1.06a5.5 5.5 0 0 0 0-7.78z"/></svg>' + (p.likes || 0) + '</span>' +
                    '<span class="stat-item"><svg viewBox="0 0 24 24"><path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z"/></svg>' + (p.comments ? p.comments.length : 0) + '</span>' +
                '</div>' +
            '</div>' +
            '<div class="post-content">' + esc(p.content || '') + '</div>' +
            (tagsHtml ? '<div class="post-tags">' + tagsHtml + '</div>' : '') +
            '<div class="post-actions">' +
                '<button class="btn-like' + (_isLiked ? ' liked' : '') + '" id="likeBtn" onclick="toggleLike()">' +
                    '<svg viewBox="0 0 24 24"><path d="M20.84 4.61a5.5 5.5 0 0 0-7.78 0L12 5.67l-1.06-1.06a5.5 5.5 0 0 0-7.78 7.78l1.06 1.06L12 21.23l7.78-7.78 1.06-1.06a5.5 5.5 0 0 0 0-7.78z"/></svg>' +
                    '<span id="likeCount">' + (p.likes || 0) + '</span>개 좋아요' +
                '</button>' +
                '<button class="btn-share" onclick="sharePost()">' +
                    '<svg viewBox="0 0 24 24"><circle cx="18" cy="5" r="3"/><circle cx="6" cy="12" r="3"/><circle cx="18" cy="19" r="3"/><line x1="8.59" y1="13.51" x2="15.42" y2="17.49"/><line x1="15.41" y1="6.51" x2="8.59" y2="10.49"/></svg>' +
                    '공유' +
                '</button>' +
                (p.isMine ? '<button class="btn-delete" onclick="deletePost()"><svg viewBox="0 0 24 24"><polyline points="3 6 5 6 21 6"/><path d="M19 6l-1 14a2 2 0 0 1-2 2H8a2 2 0 0 1-2-2L5 6"/><path d="M10 11v6"/><path d="M14 11v6"/><path d="M9 6V4a1 1 0 0 1 1-1h4a1 1 0 0 1 1 1v2"/></svg>삭제</button>' : '') +
            '</div>' +
        '</div>';
    document.getElementById('postArea').innerHTML = html;
}

function renderComments(comments) {
    var list = document.getElementById('commentList');
    var label = document.getElementById('commentCountLabel');
    label.textContent = '(' + comments.length + ')';
    if (!comments.length) {
        list.innerHTML = '<div class="comment-empty">첫 번째 댓글을 남겨보세요.</div>';
        return;
    }
    list.innerHTML = comments.map(function(c) {
        var initial = (c.author || '?').charAt(0);
        return '<div class="comment-item" id="comment-' + c.id + '">' +
            '<div class="comment-avatar">' + esc(initial) + '</div>' +
            '<div class="comment-body">' +
                '<div class="comment-header">' +
                    '<span class="comment-name">' + esc(c.rank || '') + ' ' + esc(c.author || '') + '</span>' +
                    '<span class="comment-time">' + esc(c.time || '') + '</span>' +
                '</div>' +
                '<div class="comment-text">' + esc(c.text || '') + '</div>' +
            '</div>' +
            (c.isMine ? '<button class="comment-del" onclick="deleteComment(' + c.id + ')">삭제</button>' : '') +
        '</div>';
    }).join('');
}

function toggleLike() {
    var fd = new FormData();
    fd.append('action', 'like');
    fd.append('targetType', 'post');
    fd.append('targetId', _postId);
    fetch(_ctx + '/board', { method: 'POST', body: fd, credentials: 'same-origin' })
        .then(function(r) { return r.json(); })
        .then(function(d) {
            if (d.success) {
                _isLiked = d.liked;
                var btn = document.getElementById('likeBtn');
                btn.classList.toggle('liked', _isLiked);
                document.getElementById('likeCount').textContent = d.likes;
            }
        }).catch(function() {});
}

function submitComment() {
    var input = document.getElementById('commentInput');
    var text = input.value.trim();
    if (!text) return;
    var fd = new FormData();
    fd.append('action', 'comment');
    fd.append('postId', _postId);
    fd.append('content', text);
    fetch(_ctx + '/board', { method: 'POST', body: fd, credentials: 'same-origin' })
        .then(function(r) { return r.json(); })
        .then(function(d) {
            if (d.success) {
                input.value = '';
                input.style.height = 'auto';
                loadPost();
            } else {
                showToast(d.error || '댓글 등록에 실패했습니다.');
            }
        }).catch(function() { showToast('오류가 발생했습니다.'); });
}

function deleteComment(id) {
    if (!confirm('댓글을 삭제하시겠습니까?')) return;
    var fd = new FormData();
    fd.append('action', 'deleteComment');
    fd.append('commentId', id);
    fd.append('postId', _postId);
    fetch(_ctx + '/board', { method: 'POST', body: fd, credentials: 'same-origin' })
        .then(function(r) { return r.json(); })
        .then(function(d) {
            if (d.success) loadPost();
            else showToast(d.error || '삭제에 실패했습니다.');
        }).catch(function() {});
}

function deletePost() {
    if (!confirm('게시글을 삭제하시겠습니까?')) return;
    var fd = new FormData();
    fd.append('action', 'delete');
    fd.append('postId', _postId);
    fetch(_ctx + '/board', { method: 'POST', body: fd, credentials: 'same-origin' })
        .then(function(r) { return r.json(); })
        .then(function(d) {
            if (d.success) location.href = _ctx + '/desktop/board';
            else showToast(d.error || '삭제에 실패했습니다.');
        }).catch(function() {});
}

function sharePost() {
    if (navigator.clipboard) {
        navigator.clipboard.writeText(location.href).then(function() {
            showToast('링크가 클립보드에 복사되었습니다.');
        });
    }
}

function autoResizeComment(el) {
    el.style.height = 'auto';
    el.style.height = Math.min(el.scrollHeight, 120) + 'px';
}

function showToast(msg) {
    var t = document.getElementById('toast');
    t.textContent = msg; t.classList.add('show');
    setTimeout(function() { t.classList.remove('show'); }, 2500);
}

function esc(s) {
    return String(s || '').replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
}

document.getElementById('commentInput').addEventListener('keydown', function(e) {
    if (e.key === 'Enter' && e.ctrlKey) { submitComment(); }
});

loadPost();
</script>
</body>
</html>
