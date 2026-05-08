<%@ page language="java" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8"%>
<!DOCTYPE html>
<html lang="ko">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>POL-MATE | ID / 비밀번호 찾기</title>
<link href="https://fonts.googleapis.com/css2?family=Noto+Sans+KR:wght@300;400;500;700&family=Space+Grotesk:wght@500;700&display=swap" rel="stylesheet">
<style>
* { box-sizing: border-box; margin: 0; padding: 0; }
html, body { height: 100%; font-family: 'Noto Sans KR', sans-serif; background: #f0f2f8; -webkit-font-smoothing: antialiased; }
.page { min-height: 100vh; display: flex; align-items: center; justify-content: center; padding: 24px; }
.card {
    width: 860px; display: grid; grid-template-columns: 1.1fr 1fr;
    background: #fff; border-radius: 22px; overflow: hidden;
    box-shadow: 0 24px 80px rgba(13,26,51,0.18); min-height: 560px;
    animation: fadeUp 0.35s ease both;
}
@keyframes fadeUp { from { opacity:0; transform:translateY(16px); } to { opacity:1; transform:translateY(0); } }
.brand {
    background: #0d1a33; color: #fff; padding: 48px 40px;
    display: flex; flex-direction: column; justify-content: space-between; position: relative; overflow: hidden;
}
.brand::before { content:''; position:absolute; top:-80px; right:-80px; width:240px; height:240px; border-radius:50%; border:1px solid rgba(240,192,64,0.12); }
.brand::after  { content:''; position:absolute; bottom:-60px; left:-60px; width:180px; height:180px; border-radius:50%; border:1px solid rgba(74,124,220,0.10); }
.brand-gold-line { position:absolute; bottom:0; left:40px; right:40px; height:2px; background:linear-gradient(90deg,transparent,#f0c040,transparent); opacity:0.4; }
.brand-top { position:relative; z-index:1; }
.wordmark { font-family:'Space Grotesk',sans-serif; font-weight:700; font-size:24px; letter-spacing:5px; color:#fff; margin-bottom:6px; }
.tagline { font-size:10px; color:rgba(255,255,255,0.5); letter-spacing:1px; text-transform:uppercase; margin-bottom:18px; }
.gov-badge { display:inline-flex; align-items:center; gap:6px; font-size:10px; font-weight:500; padding:5px 12px; border-radius:20px; background:rgba(240,192,64,0.18); color:#f0c040; border:1px solid rgba(240,192,64,0.35); }
.gov-dot { width:5px; height:5px; border-radius:50%; background:#f0c040; }
.brand-bottom { position:relative; z-index:1; font-size:11px; color:rgba(255,255,255,0.4); line-height:1.8; }

.form-side { display: flex; flex-direction: column; }
.tab-header { background: #0d1a33; display: flex; }
.tab-btn {
    flex: 1; padding: 18px 0; font-size: 13px; font-weight: 500;
    color: rgba(255,255,255,0.5); background: none; border: none;
    cursor: pointer; font-family: 'Noto Sans KR', sans-serif;
    border-bottom: 2px solid transparent; transition: all 0.2s;
}
.tab-btn.active { color: #fff; border-bottom-color: #f0c040; }
.tab-content { flex: 1; padding: 36px 44px; overflow-y: auto; }

.form-eyebrow { font-size:10px; color:#9ca3af; letter-spacing:0.8px; text-transform:uppercase; margin-bottom:3px; }
.form-title   { font-size:18px; font-weight:500; color:#1a1a2e; margin-bottom:4px; }
.form-sub     { font-size:12px; color:#6b7280; margin-bottom:24px; }

.field { margin-bottom:14px; }
.field-label { display:block; font-size:10px; font-weight:500; color:#6b7280; letter-spacing:0.7px; text-transform:uppercase; margin-bottom:5px; }
.field-wrap { position:relative; }
.field-wrap svg { position:absolute; left:13px; top:50%; transform:translateY(-50%); width:14px; height:14px; stroke:#9ca3af; pointer-events:none; }
.field-input { width:100%; padding:11px 12px 11px 38px; background:#f4f6fb; border:1.5px solid #e2e5ee; border-radius:10px; font-size:13px; font-family:'Noto Sans KR',sans-serif; color:#1a1a2e; outline:none; transition:border-color 0.15s,background 0.15s,box-shadow 0.15s; }
.field-input:focus { border-color:#0d1a33; background:#fff; box-shadow:0 0 0 3px rgba(13,26,51,0.07); }
.field-input::placeholder { color:#9ca3af; font-size:12px; }
.inline-row { display:flex; gap:8px; }
.inline-row .field-wrap { flex:1; }
.btn-send { background:#0d1a33; color:#fff; border:none; border-radius:10px; padding:0 14px; font-size:12px; font-family:'Noto Sans KR',sans-serif; cursor:pointer; white-space:nowrap; font-weight:500; height:44px; }
.btn-send:hover { background:#1a2744; }
.btn-send:disabled { opacity:0.5; cursor:not-allowed; }
.timer { font-size:12px; color:#dc2626; font-weight:500; position:absolute; right:12px; top:50%; transform:translateY(-50%); }

.btn-submit { width:100%; padding:13px; background:#0d1a33; color:#fff; border:none; border-radius:12px; font-size:14px; font-weight:500; font-family:'Noto Sans KR',sans-serif; cursor:pointer; transition:background 0.15s; margin-top:8px; }
.btn-submit:hover { background:#1a2744; }

.result-card { background:#eff6ff; border:1px solid #bfdbfe; border-radius:14px; padding:22px 20px; margin-bottom:16px; text-align:center; display:none; animation:fadeUp 0.3s ease both; }
.result-label { font-size:11px; color:#1e40af; margin-bottom:8px; }
.result-value { font-size:18px; font-weight:700; color:#0d1a33; }
.result-sub   { font-size:11px; color:#9ca3af; margin-top:6px; }

.back-link { display:block; text-align:center; margin-top:14px; font-size:12px; color:#4a7cdc; text-decoration:none; }
.back-link:hover { text-decoration:underline; }

.pw-strength-wrap { margin-top:6px; }
.pw-strength-bar  { height:3px; background:#e2e5ee; border-radius:2px; margin-bottom:4px; }
.pw-strength-fill { height:100%; border-radius:2px; width:0; transition:width 0.3s,background 0.3s; }
.pw-strength-msg  { font-size:10px; color:#9ca3af; }

.tab-panel { display:none; animation:fadeUp 0.25s ease both; }
.tab-panel.active { display:block; }

@media (max-width:800px) { .card { grid-template-columns:1fr; width:100%; max-width:480px; } .brand { padding:32px; } .tab-content { padding:28px 28px; } }
</style>
</head>
<body>
<div class="page">
<div class="card">

    <div class="brand">
        <div class="brand-top">
            <svg style="display:block;margin-bottom:18px;" width="52" height="52" viewBox="0 0 86 86" fill="none">
                <path d="M43 7 L66 17 L66 41 C66 57 43 71 43 71 C43 71 20 57 20 41 L20 17 Z" fill="#162240"/>
                <path d="M43 7 L66 17 L66 41 C66 57 43 71 43 71 C43 71 20 57 20 41 L20 17 Z" fill="none" stroke="#f0c040" stroke-width="1.8"/>
                <circle cx="43" cy="40" r="11" fill="#0d1a33"/>
                <circle cx="43" cy="40" r="6"  fill="#4a7cdc" opacity="0.85"/>
                <circle cx="43" cy="40" r="3"  fill="#fff"/>
                <circle cx="43" cy="22" r="2"  fill="#f0c040"/>
                <circle cx="43" cy="58" r="2"  fill="#f0c040"/>
                <circle cx="28" cy="40" r="2"  fill="#f0c040"/>
                <circle cx="58" cy="40" r="2"  fill="#f0c040"/>
            </svg>
            <div class="wordmark">POL-MATE</div>
            <div class="tagline">Criminal Justice Information System</div>
            <div class="gov-badge"><span class="gov-dot"></span>대한민국 경찰청 공식 시스템</div>
        </div>
        <div class="brand-bottom">
            등록된 이메일로 아이디 확인 및<br>비밀번호 재설정을 진행합니다.
        </div>
        <div class="brand-gold-line"></div>
    </div>

    <div class="form-side">
        <div class="tab-header">
            <button class="tab-btn active" id="tabId" onclick="switchTab('id')">아이디 찾기</button>
            <button class="tab-btn" id="tabPw" onclick="switchTab('pw')">비밀번호 찾기</button>
        </div>

        <div class="tab-content">

            <!-- 아이디 찾기 -->
            <div class="tab-panel active" id="panelId">
                <div id="findIdForm">
                    <div class="form-eyebrow">아이디 찾기</div>
                    <div class="form-title">가입 정보로 확인</div>
                    <div class="form-sub">등록된 이름과 이메일 주소를 입력해 주세요.</div>
                    <div class="field">
                        <label class="field-label">이름</label>
                        <div class="field-wrap">
                            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2"/><circle cx="12" cy="7" r="4"/></svg>
                            <input type="text" id="findIdName" class="field-input" placeholder="가입 시 등록한 이름">
                        </div>
                    </div>
                    <div class="field">
                        <label class="field-label">이메일</label>
                        <div class="field-wrap">
                            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><path d="M4 4h16c1.1 0 2 .9 2 2v12c0 1.1-.9 2-2 2H4c-1.1 0-2-.9-2-2V6c0-1.1.9-2 2-2z"/><polyline points="22,6 12,13 2,6"/></svg>
                            <input type="email" id="findIdEmail" class="field-input" placeholder="가입 시 등록한 이메일">
                        </div>
                    </div>
                    <button class="btn-submit" id="btnFindId" onclick="doFindId()">아이디 찾기</button>
                    <a href="${pageContext.request.contextPath}/desktop/login" class="back-link">로그인 화면으로 돌아가기</a>
                </div>
                <div id="findIdDone" style="display:none;">
                    <div class="result-card" style="display:block;">
                        <div class="result-label">이메일 발송 완료</div>
                        <div class="result-value" id="maskedEmailEl" style="font-size:14px;letter-spacing:0;word-break:break-all;"></div>
                        <div class="result-sub" style="margin-top:10px;line-height:1.7;">위 이메일로 아이디를 발송했습니다.<br>스팸함도 확인해 주세요.</div>
                    </div>
                    <button class="btn-submit" onclick="location.href='${pageContext.request.contextPath}/desktop/login'">로그인 화면으로 이동</button>
                </div>
            </div>

            <!-- 비밀번호 찾기 -->
            <div class="tab-panel" id="panelPw">

                <!-- Step 1: 아이디 + 이메일 -->
                <div id="pwStep1">
                    <div class="form-eyebrow">비밀번호 찾기</div>
                    <div class="form-title">이메일로 인증</div>
                    <div class="form-sub">가입한 아이디와 이메일 주소를 입력해 주세요.</div>
                    <div class="field">
                        <label class="field-label">아이디</label>
                        <div class="field-wrap">
                            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2"/><circle cx="12" cy="7" r="4"/></svg>
                            <input type="text" id="findPwUserId" class="field-input" placeholder="가입한 아이디">
                        </div>
                    </div>
                    <div class="field">
                        <label class="field-label">이메일</label>
                        <div class="inline-row">
                            <div class="field-wrap" style="flex:1;">
                                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><path d="M4 4h16c1.1 0 2 .9 2 2v12c0 1.1-.9 2-2 2H4c-1.1 0-2-.9-2-2V6c0-1.1.9-2 2-2z"/><polyline points="22,6 12,13 2,6"/></svg>
                                <input type="email" id="findPwEmail" class="field-input" placeholder="가입 시 등록한 이메일">
                            </div>
                            <button class="btn-send" id="btnSendCode" onclick="sendPwCode()">인증코드 발송</button>
                        </div>
                    </div>
                    <div class="field" id="otpFieldPw" style="display:none;">
                        <label class="field-label">인증코드</label>
                        <div class="field-wrap" style="position:relative;">
                            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><rect x="3" y="11" width="18" height="11" rx="2"/><path d="M7 11V7a5 5 0 0 1 10 0v4"/></svg>
                            <input type="text" id="otpPw" class="field-input" placeholder="이메일로 받은 6자리 코드" maxlength="6" inputmode="numeric" style="padding-right:52px;">
                            <span class="timer" id="timerPwEl"></span>
                        </div>
                    </div>
                    <button class="btn-submit" id="btnVerifyPw" onclick="verifyPwCode()">인증 확인</button>
                    <a href="${pageContext.request.contextPath}/desktop/login" class="back-link">로그인 화면으로 돌아가기</a>
                </div>

                <!-- Step 2: 새 비밀번호 -->
                <div id="pwStep2" style="display:none;">
                    <div class="form-eyebrow">비밀번호 재설정</div>
                    <div class="form-title">새 비밀번호 입력</div>
                    <div class="form-sub">사용할 새 비밀번호를 입력해 주세요.</div>
                    <div class="field">
                        <label class="field-label">새 비밀번호</label>
                        <div class="field-wrap">
                            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><rect x="3" y="11" width="18" height="11" rx="2"/><path d="M7 11V7a5 5 0 0 1 10 0v4"/></svg>
                            <input type="password" id="newPw" class="field-input" placeholder="8자 이상 영문+숫자+특수문자" oninput="checkPwStrength()">
                        </div>
                        <div class="pw-strength-wrap">
                            <div class="pw-strength-bar"><div id="pwStrengthBar" class="pw-strength-fill"></div></div>
                            <div id="pwStrengthMsg" class="pw-strength-msg"></div>
                        </div>
                    </div>
                    <div class="field">
                        <label class="field-label">비밀번호 확인</label>
                        <div class="field-wrap">
                            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><rect x="3" y="11" width="18" height="11" rx="2"/><path d="M7 11V7a5 5 0 0 1 10 0v4"/></svg>
                            <input type="password" id="newPwCf" class="field-input" placeholder="비밀번호를 다시 입력하세요">
                        </div>
                    </div>
                    <button class="btn-submit" id="btnResetPw" onclick="doResetPw()">비밀번호 변경 완료</button>
                </div>

                <!-- Step 3: 완료 -->
                <div id="pwStep3" style="display:none;">
                    <div class="result-card" style="display:block; background:#f0fdf4; border-color:#bbf7d0; text-align:center;">
                        <div style="font-size:32px;margin-bottom:10px;">✓</div>
                        <div class="result-label" style="color:#15803d;">비밀번호 변경 완료</div>
                        <div class="result-value" style="font-size:14px;letter-spacing:0;color:#1a2744;">새 비밀번호로 로그인하세요</div>
                    </div>
                    <button class="btn-submit" onclick="location.href='${pageContext.request.contextPath}/desktop/login'">로그인 화면으로 이동</button>
                </div>

            </div>
        </div>
    </div>
</div>
</div>

<script>
function switchTab(tab) {
    document.getElementById('panelId').classList.toggle('active', tab==='id');
    document.getElementById('panelPw').classList.toggle('active', tab==='pw');
    document.getElementById('tabId').classList.toggle('active', tab==='id');
    document.getElementById('tabPw').classList.toggle('active', tab==='pw');
}

async function doFindId() {
    var name  = document.getElementById('findIdName').value.trim();
    var email = document.getElementById('findIdEmail').value.trim();
    if (!name)  { alert('이름을 입력해 주세요.'); return; }
    if (!email) { alert('이메일을 입력해 주세요.'); return; }
    if (!/^[\w.+-]+@[\w-]+\.[\w.]+$/.test(email)) { alert('이메일 형식이 올바르지 않습니다.'); return; }
    var btn = document.getElementById('btnFindId'); btn.disabled=true; btn.textContent='조회 중...';
    try {
        var data = await fetch('${pageContext.request.contextPath}/findAccount', {
            method:'POST', headers:{'Content-Type':'application/x-www-form-urlencoded; charset=UTF-8'},
            body: new URLSearchParams({action:'findId', name:name, email:email}).toString()
        }).then(function(r){return r.json();});
        if (data.success) {
            document.getElementById('maskedEmailEl').textContent = data.maskedEmail;
            document.getElementById('findIdForm').style.display='none';
            document.getElementById('findIdDone').style.display='block';
        } else { alert(data.message); btn.disabled=false; btn.textContent='아이디 찾기'; }
    } catch(e) { alert('서버 통신 오류가 발생했습니다.'); btn.disabled=false; btn.textContent='아이디 찾기'; }
}

var pwTimerIv = null;
async function sendPwCode() {
    var userId = document.getElementById('findPwUserId').value.trim();
    var email  = document.getElementById('findPwEmail').value.trim();
    if (!userId) { alert('아이디를 입력해 주세요.'); return; }
    if (!email || !/^[\w.+-]+@[\w-]+\.[\w.]+$/.test(email)) { alert('올바른 이메일을 입력해 주세요.'); return; }
    var btn = document.getElementById('btnSendCode'); btn.disabled=true; btn.textContent='발송 중...';
    try {
        var data = await fetch('${pageContext.request.contextPath}/findAccount', {
            method:'POST', headers:{'Content-Type':'application/x-www-form-urlencoded; charset=UTF-8'},
            body: new URLSearchParams({action:'sendCode', userId:userId, email:email}).toString()
        }).then(function(r){return r.json();});
        if (data.success) {
            document.getElementById('otpFieldPw').style.display='block';
            btn.textContent='재발송'; btn.disabled=false;
            startTimer(); alert('인증코드가 이메일로 발송되었습니다.');
        } else { alert(data.message); btn.disabled=false; btn.textContent='인증코드 발송'; }
    } catch(e) { alert('서버 통신 오류가 발생했습니다.'); btn.disabled=false; btn.textContent='인증코드 발송'; }
}

function startTimer() {
    clearInterval(pwTimerIv); var sec=180; var el=document.getElementById('timerPwEl');
    var tick=function(){ var m=String(Math.floor(sec/60)).padStart(2,'0'); var s=String(sec%60).padStart(2,'0'); el.textContent=m+':'+s; if(sec--<=0){clearInterval(pwTimerIv); el.textContent='만료';} };
    tick(); pwTimerIv=setInterval(tick,1000);
}

async function verifyPwCode() {
    var code = document.getElementById('otpPw').value.trim();
    if (!code) { alert('인증코드를 입력해 주세요.'); return; }
    var btn = document.getElementById('btnVerifyPw'); btn.disabled=true; btn.textContent='확인 중...';
    try {
        var data = await fetch('${pageContext.request.contextPath}/findAccount', {
            method:'POST', headers:{'Content-Type':'application/x-www-form-urlencoded; charset=UTF-8'},
            body: new URLSearchParams({action:'verifyCode', code:code}).toString()
        }).then(function(r){return r.json();});
        btn.disabled=false; btn.textContent='인증 확인';
        if (data.success) { clearInterval(pwTimerIv); document.getElementById('pwStep1').style.display='none'; document.getElementById('pwStep2').style.display='block'; }
        else { alert(data.message); }
    } catch(e) { alert('서버 통신 오류가 발생했습니다.'); btn.disabled=false; btn.textContent='인증 확인'; }
}

async function doResetPw() {
    var newPw  = document.getElementById('newPw').value;
    var newPwCf= document.getElementById('newPwCf').value;
    if (!newPw || newPw.length<8) { alert('비밀번호를 8자 이상 입력해 주세요.'); return; }
    if (!/[a-zA-Z]/.test(newPw)) { alert('영문자를 포함해야 합니다.'); return; }
    if (!/[0-9]/.test(newPw))    { alert('숫자를 포함해야 합니다.'); return; }
    if (!/[!@#$%^&*()_+\-=]/.test(newPw)) { alert('특수문자를 포함해야 합니다.'); return; }
    if (newPw !== newPwCf) { alert('비밀번호가 일치하지 않습니다.'); return; }
    var btn = document.getElementById('btnResetPw'); btn.disabled=true; btn.textContent='변경 중...';
    try {
        var data = await fetch('${pageContext.request.contextPath}/findAccount', {
            method:'POST', headers:{'Content-Type':'application/x-www-form-urlencoded; charset=UTF-8'},
            body: new URLSearchParams({action:'resetPw', newPw:newPw}).toString()
        }).then(function(r){return r.json();});
        btn.disabled=false; btn.textContent='비밀번호 변경 완료';
        if (data.success) { document.getElementById('pwStep2').style.display='none'; document.getElementById('pwStep3').style.display='block'; }
        else { alert(data.message); }
    } catch(e) { alert('서버 통신 오류가 발생했습니다.'); btn.disabled=false; btn.textContent='비밀번호 변경 완료'; }
}

function checkPwStrength() {
    var pw=document.getElementById('newPw').value; var score=0;
    if(pw.length>=8)score++; if(/[A-Z]/.test(pw))score++; if(/[a-z]/.test(pw))score++; if(/[0-9]/.test(pw))score++; if(/[!@#$%^&*()_+\-=]/.test(pw))score++;
    var lv=[{p:'0%',c:'#e2e5ee',t:''},{p:'25%',c:'#dc2626',t:'매우 약함'},{p:'50%',c:'#f97316',t:'약함'},{p:'75%',c:'#eab308',t:'보통'},{p:'90%',c:'#16a34a',t:'강함'},{p:'100%',c:'#16a34a',t:'매우 강함 ✓'}][Math.min(score,5)];
    var bar=document.getElementById('pwStrengthBar'); var msg=document.getElementById('pwStrengthMsg');
    bar.style.width=lv.p; bar.style.background=lv.c; msg.textContent=lv.t; msg.style.color=lv.c;
}
</script>
</body>
</html>
