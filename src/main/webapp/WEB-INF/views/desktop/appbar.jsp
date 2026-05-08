<%@ page pageEncoding="UTF-8" %>
<%
String[] _ab_crumbs = (String[]) request.getAttribute("breadcrumb");
if (_ab_crumbs == null) _ab_crumbs = new String[]{"POL-MATE"};
%>
<style>
.pm-appbar {
    height: 64px;
    background: #fff;
    border-bottom: 1px solid #e2e5ee;
    display: flex;
    align-items: center;
    padding: 0 28px;
    gap: 16px;
    position: sticky;
    top: 0;
    z-index: 50;
    flex-shrink: 0;
}
.pm-appbar-burger {
    display: none;
    width: 36px; height: 36px;
    border: none; background: transparent; cursor: pointer;
    border-radius: 8px;
    align-items: center; justify-content: center;
    color: #6b7280;
    transition: background 0.13s;
}
.pm-appbar-burger:hover { background: #f4f6fb; }
@media (max-width: 900px) { .pm-appbar-burger { display: flex; } }
.pm-breadcrumb { display: flex; align-items: center; gap: 6px; flex: 1; min-width: 0; }
.pm-bc-item { font-size: 12px; color: #9ca3af; white-space: nowrap; }
.pm-bc-item.current { font-size: 14px; font-weight: 500; color: #1a1a2e; }
.pm-bc-sep { font-size: 11px; color: #e2e5ee; }
.pm-appbar-search {
    display: flex; align-items: center; gap: 8px;
    background: #f4f6fb; border: 1.5px solid #e2e5ee;
    border-radius: 12px; padding: 8px 14px; width: 240px;
    transition: border-color 0.15s, box-shadow 0.15s;
}
.pm-appbar-search:focus-within {
    border-color: #0d1a33;
    box-shadow: 0 0 0 3px rgba(13,26,51,0.07);
    background: #fff;
}
.pm-appbar-search svg { color: #9ca3af; flex-shrink: 0; }
.pm-appbar-search input {
    border: none; background: transparent; outline: none;
    font-size: 13px; font-family: 'Noto Sans KR', sans-serif;
    color: #1a1a2e; width: 100%;
}
.pm-appbar-search input::placeholder { color: #9ca3af; }
.pm-appbar-actions { display: flex; align-items: center; gap: 4px; }
.pm-appbar-icon-btn {
    width: 36px; height: 36px; border-radius: 10px;
    border: none; background: transparent; cursor: pointer;
    display: flex; align-items: center; justify-content: center;
    color: #6b7280; position: relative;
    text-decoration: none;
    transition: background 0.13s, color 0.13s;
}
.pm-appbar-icon-btn:hover { background: #f4f6fb; color: #1a1a2e; }
.pm-appbar-notif-dot {
    position: absolute; top: 5px; right: 5px;
    width: 7px; height: 7px; border-radius: 50%;
    background: #dc2626; border: 2px solid #fff; display: none;
}
.pm-appbar-notif-dot.on { display: block; }
.pm-appbar-avatar {
    width: 32px; height: 32px; border-radius: 8px;
    background: #0d1a33;
    display: flex; align-items: center; justify-content: center;
    border: 1.5px solid rgba(240,192,64,0.3);
    text-decoration: none;
    transition: border-color 0.13s; flex-shrink: 0;
}
.pm-appbar-avatar:hover { border-color: #f0c040; }
</style>

<header class="pm-appbar">
    <button class="pm-appbar-burger" onclick="pmToggleSidebar()">
        <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round">
            <line x1="3" y1="6" x2="21" y2="6"/>
            <line x1="3" y1="12" x2="21" y2="12"/>
            <line x1="3" y1="18" x2="21" y2="18"/>
        </svg>
    </button>

    <nav class="pm-breadcrumb">
        <% for (int _i = 0; _i < _ab_crumbs.length; _i++) { %>
            <% if (_i > 0) { %><span class="pm-bc-sep">›</span><% } %>
            <span class="pm-bc-item <%= (_i == _ab_crumbs.length - 1) ? "current" : "" %>"><%= _ab_crumbs[_i] %></span>
        <% } %>
    </nav>

    <div class="pm-appbar-search">
        <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round">
            <circle cx="11" cy="11" r="8"/><line x1="21" y1="21" x2="16.65" y2="16.65"/>
        </svg>
        <input type="text" placeholder="사건번호, 피의자 검색..." oninput="pmGlobalSearch(this.value)">
    </div>

    <div class="pm-appbar-actions">
        <a href="${pageContext.request.contextPath}/desktop/notifications" class="pm-appbar-icon-btn">
            <svg width="17" height="17" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round">
                <path d="M18 8a6 6 0 0 0-12 0c0 7-3 9-3 9h18s-3-2-3-9"/>
                <path d="M13.7 21a2 2 0 0 1-3.4 0"/>
            </svg>
            <span class="pm-appbar-notif-dot" id="pmAbDot"></span>
        </a>
        <a href="${pageContext.request.contextPath}/desktop/mypage" class="pm-appbar-avatar">
            <svg width="18" height="18" viewBox="0 0 86 86" fill="none">
                <path d="M43 7 L66 17 L66 41 C66 57 43 71 43 71 C43 71 20 57 20 41 L20 17 Z" fill="#162240"/>
                <path d="M43 7 L66 17 L66 41 C66 57 43 71 43 71 C43 71 20 57 20 41 L20 17 Z" fill="none" stroke="#f0c040" stroke-width="2.5"/>
                <circle cx="43" cy="40" r="6" fill="#4a7cdc" opacity="0.9"/>
                <circle cx="43" cy="40" r="3" fill="#fff"/>
            </svg>
        </a>
    </div>
</header>

<script>
(function() {
    var _abCp = '${pageContext.request.contextPath}';
    function refreshAbDot() {
        fetch(_abCp + '/notifApi?action=unreadCount', {credentials: 'same-origin'})
            .then(function(r) { return r.json(); })
            .then(function(d) {
                var dot = document.getElementById('pmAbDot');
                if (!dot) return;
                dot.classList.toggle('on', (d.count || 0) > 0);
            }).catch(function() {});
    }
    refreshAbDot();
    setInterval(refreshAbDot, 60000);

    var _abTimer;
    window.pmGlobalSearch = function(q) {
        clearTimeout(_abTimer);
        if (!q || q.trim().length < 2) return;
        _abTimer = setTimeout(function() {
            location.href = _abCp + '/desktop/myCase?q=' + encodeURIComponent(q.trim());
        }, 300);
    };
})();
</script>
