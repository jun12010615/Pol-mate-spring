<%@ page language="java" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8"%>
<%
String _loginError = (String) request.getAttribute("loginError");
%>
<!DOCTYPE html>
<html lang="ko">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>POL-MATE | 로그인</title>
<link href="https://fonts.googleapis.com/css2?family=Noto+Sans+KR:wght@300;400;500;700&family=Space+Grotesk:wght@500;700&display=swap" rel="stylesheet">
<style>
* { box-sizing: border-box; margin: 0; padding: 0; }
html, body {
    height: 100%;
    font-family: 'Noto Sans KR', sans-serif;
    background: #f0f2f8;
    -webkit-font-smoothing: antialiased;
}
.page {
    min-height: 100vh;
    display: flex;
    align-items: center;
    justify-content: center;
    padding: 24px;
}
.card {
    width: 920px;
    display: grid;
    grid-template-columns: 1.1fr 1fr;
    background: #fff;
    border-radius: 22px;
    overflow: hidden;
    box-shadow: 0 24px 80px rgba(13,26,51,0.18);
    min-height: 600px;
    animation: fadeUp 0.35s ease both;
}
@keyframes fadeUp { from { opacity:0; transform:translateY(16px); } to { opacity:1; transform:translateY(0); } }

.brand {
    background: #0d1a33;
    color: #fff;
    padding: 56px 48px;
    display: flex;
    flex-direction: column;
    justify-content: space-between;
    position: relative;
    overflow: hidden;
}
.brand::before {
    content: '';
    position: absolute;
    top: -80px; right: -80px;
    width: 240px; height: 240px;
    border-radius: 50%;
    border: 1px solid rgba(240,192,64,0.12);
}
.brand::after {
    content: '';
    position: absolute;
    bottom: -60px; left: -60px;
    width: 180px; height: 180px;
    border-radius: 50%;
    border: 1px solid rgba(74,124,220,0.10);
}
.brand-gold-line {
    position: absolute;
    bottom: 0; left: 48px; right: 48px;
    height: 2px;
    background: linear-gradient(90deg, transparent, #f0c040, transparent);
    opacity: 0.4;
}
.brand-top { position: relative; z-index: 1; }
.shield {
    display: block;
    margin-bottom: 22px;
}
.wordmark {
    font-family: 'Space Grotesk', sans-serif;
    font-weight: 700;
    font-size: 28px;
    letter-spacing: 5px;
    color: #fff;
    margin-bottom: 8px;
}
.tagline {
    font-size: 11px;
    color: rgba(255,255,255,0.5);
    letter-spacing: 1px;
    text-transform: uppercase;
    margin-bottom: 22px;
}
.gov-badge {
    display: inline-flex;
    align-items: center;
    gap: 6px;
    font-size: 10px;
    font-weight: 500;
    padding: 5px 12px;
    border-radius: 20px;
    background: rgba(240,192,64,0.18);
    color: #f0c040;
    border: 1px solid rgba(240,192,64,0.35);
}
.gov-dot { width: 5px; height: 5px; border-radius: 50%; background: #f0c040; }
.brand-bottom {
    position: relative;
    z-index: 1;
    font-size: 11px;
    color: rgba(255,255,255,0.45);
    line-height: 1.8;
}

.form-side {
    padding: 56px 48px;
    display: flex;
    flex-direction: column;
    justify-content: center;
}
.form-eyebrow {
    font-size: 11px;
    color: #9ca3af;
    letter-spacing: 0.8px;
    text-transform: uppercase;
    margin-bottom: 4px;
}
.form-title {
    font-size: 22px;
    font-weight: 500;
    color: #1a1a2e;
    margin-bottom: 6px;
}
.form-sub {
    font-size: 12px;
    color: #6b7280;
    margin-bottom: 28px;
}
.field { margin-bottom: 14px; }
.field-label {
    display: block;
    font-size: 10px;
    font-weight: 500;
    color: #6b7280;
    letter-spacing: 0.8px;
    text-transform: uppercase;
    margin-bottom: 6px;
}
.field-wrap { position: relative; }
.field-wrap svg {
    position: absolute;
    left: 14px; top: 50%;
    transform: translateY(-50%);
    width: 15px; height: 15px;
    stroke: #9ca3af;
    pointer-events: none;
}
.field-input {
    width: 100%;
    padding: 13px 14px 13px 42px;
    background: #f0f2f8;
    border: 1.5px solid #e2e5ee;
    border-radius: 14px;
    font-size: 14px;
    font-family: 'Noto Sans KR', sans-serif;
    color: #1a1a2e;
    outline: none;
    transition: border-color 0.15s, background 0.15s, box-shadow 0.15s;
}
.field-input:focus {
    border-color: #0d1a33;
    background: #fff;
    box-shadow: 0 0 0 3px rgba(13,26,51,0.07);
}
.field-input::placeholder { color: #9ca3af; }
.field-error {
    font-size: 12px; color: #dc2626;
    margin-top: 4px; padding-left: 4px; display: none;
}
.form-row {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin: 6px 0 22px;
    font-size: 11px;
}
.remember-label {
    display: flex; gap: 7px; align-items: center;
    color: #6b7280; cursor: pointer;
}
.remember-label input { accent-color: #0d1a33; }
.forgot-link { color: #4a7cdc; text-decoration: none; }
.forgot-link:hover { text-decoration: underline; }
.server-error {
    background: #fef2f2; border: 1px solid #fecaca;
    border-radius: 10px; padding: 10px 14px;
    font-size: 12px; color: #b91c1c; margin-bottom: 14px;
}
.btn-login {
    width: 100%; padding: 15px;
    background: #0d1a33; color: #fff;
    border: none; border-radius: 14px;
    font-size: 14px; font-weight: 500; letter-spacing: 0.5px;
    font-family: 'Noto Sans KR', sans-serif;
    cursor: pointer; position: relative; overflow: hidden;
    transition: background 0.15s, transform 0.1s;
}
.btn-login::after {
    content: '';
    position: absolute;
    bottom: 0; left: 25%; right: 25%;
    height: 2px; background: #f0c040; opacity: 0.5;
}
.btn-login:hover { background: #1a2744; }
.btn-login:active { transform: scale(0.98); background: #08111f; }
.divider {
    display: flex; align-items: center; gap: 10px;
    margin: 22px 0; font-size: 11px; color: #9ca3af;
}
.divider span { flex: 1; height: 1px; background: #e2e5ee; }
.btn-register {
    width: 100%; padding: 13px;
    background: transparent; color: #1a1a2e;
    border: 1.5px solid #e2e5ee; border-radius: 14px;
    font-size: 13px; font-weight: 500;
    font-family: 'Noto Sans KR', sans-serif;
    cursor: pointer; transition: border-color 0.15s, background 0.15s;
}
.btn-register:hover { border-color: #0d1a33; background: #f4f6fb; }
.form-footer {
    margin-top: 22px;
    font-size: 10px; color: #9ca3af;
    text-align: center; line-height: 1.7;
}

@media (max-width: 800px) {
    .card { grid-template-columns: 1fr; width: 100%; max-width: 480px; }
    .brand { padding: 36px 32px; }
    .form-side { padding: 36px 32px; }
}
</style>
</head>
<body>
<div class="page">
<div class="card">

    <div class="brand">
        <div class="brand-top">
            <svg class="shield" width="64" height="64" viewBox="0 0 86 86" fill="none">
                <path d="M43 7 L66 17 L66 41 C66 57 43 71 43 71 C43 71 20 57 20 41 L20 17 Z" fill="#162240"/>
                <path d="M43 7 L66 17 L66 41 C66 57 43 71 43 71 C43 71 20 57 20 41 L20 17 Z" fill="none" stroke="#f0c040" stroke-width="1.8"/>
                <path d="M43 13 L60 21 L60 40 C60 53 43 64 43 64 C43 64 26 53 26 40 L26 21 Z" fill="none" stroke="rgba(240,192,64,0.18)" stroke-width="0.8"/>
                <circle cx="43" cy="40" r="15" fill="none" stroke="#4a7cdc" stroke-width="1.2" stroke-dasharray="4.5 2.5" opacity="0.65"/>
                <circle cx="43" cy="40" r="11" fill="#0d1a33"/>
                <circle cx="43" cy="40" r="6" fill="#4a7cdc" opacity="0.85"/>
                <circle cx="43" cy="40" r="3" fill="#fff"/>
                <circle cx="45.5" cy="37.5" r="1.2" fill="rgba(255,255,255,0.55)"/>
                <circle cx="43" cy="22" r="2" fill="#f0c040"/>
                <circle cx="43" cy="58" r="2" fill="#f0c040"/>
                <circle cx="28" cy="40" r="2" fill="#f0c040"/>
                <circle cx="58" cy="40" r="2" fill="#f0c040"/>
                <polygon points="43,8 44.4,12 48.5,12 45.2,14.5 46.6,18.5 43,16 39.4,18.5 40.8,14.5 37.5,12 41.6,12" fill="#f0c040"/>
                <line x1="35" y1="65" x2="51" y2="65" stroke="#f0c040" stroke-width="1" opacity="0.4" stroke-linecap="round"/>
            </svg>
            <div class="wordmark">POL-MATE</div>
            <div class="tagline">Criminal Justice Information System</div>
            <div class="gov-badge">
                <span class="gov-dot"></span>
                대한민국 경찰찰 공식 시스템
            </div>
        </div>
        <div class="brand-bottom">
            본 시스템은 인가된 수사관만 접근 가능합니다.<br>
            무단 접근 및 수사 정보 유출 시 형사처베을 받을 수 있습니다.
        </div>
        <div class="brand-gold-line"></div>
    </div>

    <div class="form-side">
        <div class="form-eyebrow">수사관 로그인</div>
        <div class="form-title">다시 오신 것을 환영합니다</div>
        <div class="form-sub">계정 정보를 입력해 주십시오.</div>

        <% if (_loginError != null) { %>
        <div class="server-error"><%= _loginError %></div>
        <% } %>

        <form action="${pageContext.request.contextPath}/login" method="post" onsubmit="return validate();">
            <input type="hidden" name="redirectTo" value="desktop">

            <div class="field">
                <label class="field-label" for="userId">수사관 ID</label>
                <div class="field-wrap">
                    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round">
                        <path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2"/><circle cx="12" cy="7" r="4"/>
                    </svg>
                    <input type="text" id="userId" name="userId" class="field-input"
                           placeholder="예: hong.gd" autocomplete="username">
                </div>
                <div class="field-error" id="idErr">아이데이를 입력해 주세요.</div>
            </div>

            <div class="field">
                <label class="field-label" for="userPw">비밀번호</label>
                <div class="field-wrap">
                    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round">
                        <rect x="3" y="11" width="18" height="11" rx="2"/><path d="M7 11V7a5 5 0 0 1 10 0v4"/>
                    </svg>
                    <input type="password" id="userPw" name="userPw" class="field-input"
                           placeholder="••••••••" autocomplete="current-password">
                </div>
                <div class="field-error" id="pwErr">비밀번호를 입력해 주세요.</div>
            </div>

            <div class="form-row">
                <label class="remember-label">
                    <input type="checkbox" checked> 로그인 유지
                </label>
                <a href="${pageContext.request.contextPath}/desktop/findAccount" class="forgot-link">비밀번호 찾기</a>
            </div>

            <button type="submit" class="btn-login">로그인</button>
        </form>

        <div class="divider"><span></span>또는<span></span></div>

        <button class="btn-register" onclick="location.href='${pageContext.request.contextPath}/desktop/register'">
            신규 수사관 등록
        </button>

        <div class="form-footer">
            &copy; 2025 대한민국 경찰찰 &middot; POL-MATE v1.4
        </div>
    </div>

</div>
</div>
<script>
function validate() {
    var ok = true;
    var uid = document.getElementById('userId').value.trim();
    var upw = document.getElementById('userPw').value.trim();
    var ie = document.getElementById('idErr');
    var pe = document.getElementById('pwErr');
    ie.style.display = 'none';
    pe.style.display = 'none';
    if (!uid) { ie.style.display = 'block'; ok = false; }
    if (!upw) { pe.style.display = 'block'; ok = false; }
    return ok;
}
</script>
</body>
</html>
