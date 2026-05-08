<%@ page pageEncoding="UTF-8" %>
<%
String _sb_name = (String) session.getAttribute("userName");
String _sb_rank = (String) session.getAttribute("userRank");
String _sb_org  = (String) session.getAttribute("userOrg");
String _sb_page = (String) request.getAttribute("currentPage");
String _sb_user = (String) session.getAttribute("loginUser");
if (_sb_name == null) _sb_name = _sb_user != null ? _sb_user : "";
if (_sb_rank == null) _sb_rank = "";
if (_sb_org  == null) _sb_org  = "";
if (_sb_page == null) _sb_page = "";
%>
<style>
.pm-layout {
    display: flex;
    min-height: 100vh;
    background: #f4f6fb;
    font-family: 'Noto Sans KR', sans-serif;
}
.pm-sidebar {
    width: 240px;
    background: #0d1a33;
    color: #fff;
    display: flex;
    flex-direction: column;
    position: fixed;
    top: 0; left: 0; bottom: 0;
    z-index: 100;
    border-right: 1px solid rgba(0,0,0,0.25);
    overflow: hidden;
    transition: transform 0.25s ease;
}
.pm-sb-logo {
    padding: 22px 16px 18px;
    position: relative;
    border-bottom: 1px solid rgba(255,255,255,0.06);
    flex-shrink: 0;
}
.pm-sb-logo-inner { display: flex; align-items: center; gap: 10px; }
.pm-sb-wordmark {
    font-family: 'Space Grotesk', sans-serif;
    font-weight: 700;
    font-size: 16px;
    letter-spacing: 3px;
    color: #fff;
    line-height: 1.2;
}
.pm-sb-sub { font-size: 9px; color: rgba(255,255,255,0.42); letter-spacing: 0.5px; margin-top: 2px; }
.pm-sb-hairline {
    position: absolute; bottom: 0; left: 16px; right: 16px; height: 1.5px;
    background: linear-gradient(90deg, transparent, #f0c040, transparent);
    opacity: 0.4;
}
.pm-sb-nav { flex: 1; padding: 20px 16px; overflow-y: auto; scrollbar-width: none; }
.pm-sb-nav::-webkit-scrollbar { display: none; }
.pm-nav-group { margin-bottom: 24px; }
.pm-nav-group-title {
    font-size: 9px; font-weight: 500; color: rgba(255,255,255,0.32);
    text-transform: uppercase; letter-spacing: 1.2px;
    padding: 0 14px; margin-bottom: 6px;
}
.pm-nav-item {
    display: flex; align-items: center; gap: 11px;
    padding: 10px 14px; border-radius: 11px;
    color: rgba(255,255,255,0.62); font-size: 13px; font-weight: 400;
    text-decoration: none; position: relative;
    transition: background 0.13s, color 0.13s;
    margin-bottom: 1px;
}
.pm-nav-item:hover { background: rgba(255,255,255,0.05); color: rgba(255,255,255,0.88); text-decoration: none; }
.pm-nav-item.active { background: rgba(255,255,255,0.10); color: #fff; font-weight: 500; }
.pm-nav-item.active::before {
    content: '';
    position: absolute; left: -16px; top: 8px; bottom: 8px; width: 3px;
    background: #f0c040; border-radius: 0 3px 3px 0;
}
.pm-nav-icon { display: flex; align-items: center; flex-shrink: 0; color: rgba(255,255,255,0.48); transition: color 0.13s; }
.pm-nav-item:hover .pm-nav-icon,
.pm-nav-item.active .pm-nav-icon { color: #f0c040; }
.pm-nav-label { flex: 1; }
.pm-nav-badge {
    font-size: 9.5px; font-weight: 500; padding: 2px 7px; border-radius: 10px;
    background: #dc2626; color: #fff; line-height: 1.4; flex-shrink: 0;
}
.pm-nav-badge.blue { background: #4a7cdc; }
.pm-sb-officer {
    padding: 14px 16px; border-top: 1px solid rgba(255,255,255,0.06);
    display: flex; align-items: center; gap: 10px;
    transition: background 0.13s; text-decoration: none; flex-shrink: 0;
}
.pm-sb-officer:hover { background: rgba(255,255,255,0.04); }
.pm-officer-avatar {
    width: 36px; height: 36px; border-radius: 10px;
    background: rgba(255,255,255,0.08); border: 1px solid rgba(240,192,64,0.28);
    display: flex; align-items: center; justify-content: center; flex-shrink: 0;
}
.pm-officer-info { flex: 1; min-width: 0; }
.pm-officer-name { font-size: 12px; font-weight: 500; color: #fff; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.pm-officer-dept { font-size: 10px; color: rgba(255,255,255,0.42); margin-top: 1px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.pm-logout-btn {
    background: transparent; border: none; cursor: pointer;
    width: 28px; height: 28px; border-radius: 7px;
    color: rgba(255,255,255,0.45);
    display: inline-flex; align-items: center; justify-content: center;
    transition: background 0.13s, color 0.13s; flex-shrink: 0;
}
.pm-logout-btn:hover { background: rgba(255,255,255,0.10); color: #fff; }
.pm-content {
    margin-left: 240px; flex: 1;
    display: flex; flex-direction: column;
    min-height: 100vh; min-width: 0;
}
.pm-sb-overlay {
    display: none; position: fixed; inset: 0;
    background: rgba(0,0,0,0.45); z-index: 99;
}
@media (max-width: 900px) {
    .pm-sidebar { transform: translateX(-100%); }
    .pm-sidebar.open { transform: translateX(0); }
    .pm-content { margin-left: 0; }
    .pm-sb-overlay.open { display: block; }
}
</style>

<div class="pm-sb-overlay" id="pmSbOverlay" onclick="pmToggleSidebar()"></div>

<aside class="pm-sidebar" id="pmSidebar">

    <div class="pm-sb-logo">
        <div class="pm-sb-logo-inner">
            <svg width="32" height="32" viewBox="0 0 86 86" fill="none">
                <path d="M43 7 L66 17 L66 41 C66 57 43 71 43 71 C43 71 20 57 20 41 L20 17 Z" fill="#162240"/>
                <path d="M43 7 L66 17 L66 41 C66 57 43 71 43 71 C43 71 20 57 20 41 L20 17 Z" fill="none" stroke="#f0c040" stroke-width="1.8"/>
                <circle cx="43" cy="40" r="15" fill="none" stroke="#4a7cdc" stroke-width="1.2" stroke-dasharray="4.5 2.5" opacity="0.65"/>
                <circle cx="43" cy="40" r="11" fill="#0d1a33"/>
                <circle cx="43" cy="40" r="6" fill="#4a7cdc" opacity="0.85"/>
                <circle cx="43" cy="40" r="3" fill="#fff"/>
                <circle cx="43" cy="22" r="2" fill="#f0c040"/>
                <circle cx="43" cy="58" r="2" fill="#f0c040"/>
                <circle cx="28" cy="40" r="2" fill="#f0c040"/>
                <circle cx="58" cy="40" r="2" fill="#f0c040"/>
                <polygon points="43,8 44.4,12 48.5,12 45.2,14.5 46.6,18.5 43,16 39.4,18.5 40.8,14.5 37.5,12 41.6,12" fill="#f0c040"/>
            </svg>
            <div>
                <div class="pm-sb-wordmark">POL-MATE</div>
                <div class="pm-sb-sub">Criminal Justice IS</div>
            </div>
        </div>
        <div class="pm-sb-hairline"></div>
    </div>

    <nav class="pm-sb-nav">

        <div class="pm-nav-group">
            <div class="pm-nav-group-title">Workspace</div>
            <a href="${pageContext.request.contextPath}/desktop/main" class="pm-nav-item <%= "dashboard".equals(_sb_page) ? "active" : "" %>">
                <span class="pm-nav-icon"><svg width="17" height="17" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"><path d="M3 9l9-7 9 7v11a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"/><polyline points="9 22 9 12 15 12 15 22"/></svg></span>
                <span class="pm-nav-label">대시보드</span>
            </a>
            <a href="${pageContext.request.contextPath}/desktop/myCase" class="pm-nav-item <%= "cases".equals(_sb_page) ? "active" : "" %>">
                <span class="pm-nav-icon"><svg width="17" height="17" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"><path d="M22 19a2 2 0 0 1-2 2H4a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h5l2 3h9a2 2 0 0 1 2 2z"/></svg></span>
                <span class="pm-nav-label">내 사건</span>
                <span class="pm-nav-badge blue" id="pmCaseBadge" style="display:none;"></span>
            </a>
            <a href="${pageContext.request.contextPath}/desktop/notifications" class="pm-nav-item <%= "notifications".equals(_sb_page) ? "active" : "" %>">
                <span class="pm-nav-icon"><svg width="17" height="17" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"><path d="M18 8a6 6 0 0 0-12 0c0 7-3 9-3 9h18s-3-2-3-9"/><path d="M13.7 21a2 2 0 0 1-3.4 0"/></svg></span>
                <span class="pm-nav-label">알림</span>
                <span class="pm-nav-badge" id="pmNotifBadge" style="display:none;"></span>
            </a>
        </div>

        <div class="pm-nav-group">
            <div class="pm-nav-group-title">수사 도구</div>
            <a href="${pageContext.request.contextPath}/desktop/writeTranscript" class="pm-nav-item <%= "transcript".equals(_sb_page) ? "active" : "" %>">
                <span class="pm-nav-icon"><svg width="17" height="17" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"><path d="M12 1a3 3 0 0 0-3 3v8a3 3 0 0 0 6 0V4a3 3 0 0 0-3-3z"/><path d="M19 10v2a7 7 0 0 1-14 0v-2"/><line x1="12" y1="19" x2="12" y2="23"/></svg></span>
                <span class="pm-nav-label">진술 조서 작성</span>
            </a>
            <a href="${pageContext.request.contextPath}/desktop/voiceTranscript" class="pm-nav-item <%= "contradiction".equals(_sb_page) ? "active" : "" %>">
                <span class="pm-nav-icon"><svg width="17" height="17" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"><circle cx="12" cy="12" r="10"/><line x1="12" y1="8" x2="12" y2="12"/><line x1="12" y1="16" x2="12.01" y2="16"/></svg></span>
                <span class="pm-nav-label">모순 탐지</span>
            </a>
            <a href="${pageContext.request.contextPath}/desktop/caseRelationMap" class="pm-nav-item <%= "relations".equals(_sb_page) ? "active" : "" %>">
                <span class="pm-nav-icon"><svg width="17" height="17" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"><circle cx="6" cy="12" r="2.5"/><circle cx="18" cy="5" r="2.5"/><circle cx="18" cy="19" r="2.5"/><line x1="8.4" y1="11" x2="15.6" y2="6.5"/><line x1="8.4" y1="13" x2="15.6" y2="17.5"/></svg></span>
                <span class="pm-nav-label">사건 관계망</span>
            </a>
            <a href="${pageContext.request.contextPath}/desktop/cctvAnalysis" class="pm-nav-item <%= "video".equals(_sb_page) ? "active" : "" %>">
                <span class="pm-nav-icon"><svg width="17" height="17" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"><path d="M23 7 16 12 23 17V7z"/><rect x="1" y="5" width="15" height="14" rx="2"/></svg></span>
                <span class="pm-nav-label">영상 분석</span>
            </a>
            <a href="${pageContext.request.contextPath}/desktop/aiChat" class="pm-nav-item <%= "ai".equals(_sb_page) ? "active" : "" %>">
                <span class="pm-nav-icon"><svg width="17" height="17" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"><path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z"/></svg></span>
                <span class="pm-nav-label">AI 수사 보조</span>
            </a>
        </div>

        <div class="pm-nav-group">
            <div class="pm-nav-group-title">기타</div>
            <a href="${pageContext.request.contextPath}/desktop/board" class="pm-nav-item <%= "board".equals(_sb_page) ? "active" : "" %>">
                <span class="pm-nav-icon"><svg width="17" height="17" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"><path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/><polyline points="14 2 14 8 20 8"/></svg></span>
                <span class="pm-nav-label">커뮤니티 게시판</span>
            </a>
            <a href="${pageContext.request.contextPath}/desktop/mypage" class="pm-nav-item <%= "mypage".equals(_sb_page) ? "active" : "" %>">
                <span class="pm-nav-icon"><svg width="17" height="17" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"><path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2"/><circle cx="12" cy="7" r="4"/></svg></span>
                <span class="pm-nav-label">마이페이지</span>
            </a>
        </div>

    </nav>

    <a href="${pageContext.request.contextPath}/desktop/mypage" class="pm-sb-officer">
        <div class="pm-officer-avatar">
            <svg width="20" height="20" viewBox="0 0 86 86" fill="none">
                <path d="M43 7 L66 17 L66 41 C66 57 43 71 43 71 C43 71 20 57 20 41 L20 17 Z" fill="#162240"/>
                <path d="M43 7 L66 17 L66 41 C66 57 43 71 43 71 C43 71 20 57 20 41 L20 17 Z" fill="none" stroke="#f0c040" stroke-width="2"/>
                <circle cx="43" cy="40" r="6" fill="#4a7cdc" opacity="0.85"/>
                <circle cx="43" cy="40" r="3" fill="#fff"/>
                <circle cx="43" cy="22" r="2" fill="#f0c040"/>
                <circle cx="43" cy="58" r="2" fill="#f0c040"/>
                <circle cx="28" cy="40" r="2" fill="#f0c040"/>
                <circle cx="58" cy="40" r="2" fill="#f0c040"/>
            </svg>
        </div>
        <div class="pm-officer-info">
            <div class="pm-officer-name"><%= _sb_rank.isEmpty() ? "" : _sb_rank + " " %><%= _sb_name %></div>
            <div class="pm-officer-dept"><%= _sb_org %></div>
        </div>
        <form action="${pageContext.request.contextPath}/mypage" method="post" style="margin:0;" onsubmit="return confirm('로그아웃 하시겠습니까?');">
            <input type="hidden" name="action" value="logout">
            <button type="submit" class="pm-logout-btn" onclick="event.stopPropagation();">
                <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round">
                    <path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4"/>
                    <polyline points="16 17 21 12 16 7"/>
                    <line x1="21" y1="12" x2="9" y2="12"/>
                </svg>
            </button>
        </form>
    </a>

</aside>

<script>
(function() {
    var _sbCp = '${pageContext.request.contextPath}';
    function refreshNotif() {
        fetch(_sbCp + '/notifApi?action=unreadCount', {credentials: 'same-origin'})
            .then(function(r) { return r.json(); })
            .then(function(d) {
                var b = document.getElementById('pmNotifBadge');
                if (!b) return;
                var n = d.count || 0;
                b.textContent = n;
                b.style.display = n > 0 ? '' : 'none';
            }).catch(function() {});
    }
    function refreshCase() {
        fetch(_sbCp + '/caseApi?action=caseList', {credentials: 'same-origin'})
            .then(function(r) { return r.json(); })
            .then(function(d) {
                var b = document.getElementById('pmCaseBadge');
                if (!b) return;
                var list = Array.isArray(d) ? d : [];
                var n = list.filter(function(c) { return c.status !== '완료'; }).length;
                b.textContent = n;
                b.style.display = n > 0 ? '' : 'none';
            }).catch(function() {});
    }
    refreshNotif();
    refreshCase();
    setInterval(refreshNotif, 60000);
    setInterval(refreshCase, 120000);
    window.pmToggleSidebar = function() {
        var sb = document.getElementById('pmSidebar');
        var ov = document.getElementById('pmSbOverlay');
        var open = sb.classList.toggle('open');
        ov.classList.toggle('open', open);
    };
})();
</script>
