package com.polmate.controller;

import org.springframework.stereotype.Controller;
import org.springframework.web.bind.annotation.GetMapping;

/**
 * JSP 페이지 매핑 컨트롤러
 * WEB-INF/views/ 하위의 JSP 파일을 URL에 매핑
 */
@Controller
public class PageController {

    @GetMapping("/")
    public String root() { return "redirect:/desktop/login"; }

    // ── 모바일 ────────────────────────────────────────────────
    @GetMapping("/mobile/login")       public String mobileLogin()       { return "mobile/login"; }
    @GetMapping("/mobile/register")    public String mobileRegister()    { return "mobile/register"; }
    @GetMapping("/mobile/findAccount") public String mobileFindAccount() { return "mobile/findAccount"; }
    @GetMapping("/mobile/main")        public String mobileMain()        { return "mobile/main"; }
    @GetMapping("/mobile/myCase")      public String mobileMyCaseList()  { return "mobile/myCase"; }
    @GetMapping("/mobile/caseList")    public String mobileCaseList()    { return "mobile/caseList"; }
    @GetMapping("/mobile/board")       public String mobileBoard()       { return "mobile/board"; }
    @GetMapping("/mobile/boardView")   public String mobileBoardView()   { return "mobile/boardView"; }
    @GetMapping("/mobile/boardEdit")   public String mobileBoardEdit()   { return "mobile/boardEdit"; }
    @GetMapping("/mobile/mypage")      public String mobileMypage()      { return "mobile/mypage"; }
    @GetMapping("/mobile/notifications") public String mobileNotifications() { return "mobile/notifications"; }
    @GetMapping("/mobile/contradictionList") public String mobileContradictionList() { return "mobile/contradictionList"; }
    @GetMapping("/mobile/aiChat")      public String mobileAiChat()      { return "mobile/aiChat"; }
    @GetMapping("/mobile/voiceTranscript") public String mobileVoiceTranscript() { return "mobile/voiceTranscript"; }
    @GetMapping("/mobile/writeTranscript") public String mobileWriteTranscript() { return "mobile/writeTranscript"; }
    @GetMapping("/mobile/caseRelationMap") public String mobileCaseRelationMap() { return "mobile/caseRelationMap"; }
    @GetMapping("/mobile/cctvAnalysis") public String mobileCctvAnalysis() { return "mobile/cctvAnalysis"; }

    // ── 데스크탑 ──────────────────────────────────────────────
    @GetMapping("/desktop/login")       public String desktopLogin()       { return "desktop/login"; }
    @GetMapping("/desktop/register")    public String desktopRegister()    { return "desktop/register"; }
    @GetMapping("/desktop/findAccount") public String desktopFindAccount() { return "desktop/findAccount"; }
    @GetMapping("/desktop/main")        public String desktopMain()        { return "desktop/main"; }
    @GetMapping("/desktop/myCase")      public String desktopMyCase()      { return "desktop/myCase"; }
    @GetMapping("/desktop/board")       public String desktopBoard()       { return "desktop/board"; }
    @GetMapping("/desktop/boardView")   public String desktopBoardView()   { return "desktop/boardView"; }
    @GetMapping("/desktop/mypage")      public String desktopMypage()      { return "desktop/mypage"; }
    @GetMapping("/desktop/notifications") public String desktopNotifications() { return "desktop/notifications"; }
    @GetMapping("/desktop/aiChat")      public String desktopAiChat()      { return "desktop/aiChat"; }
    @GetMapping("/desktop/voiceTranscript") public String desktopVoiceTranscript() { return "desktop/voiceTranscript"; }
    @GetMapping("/desktop/writeTranscript") public String desktopWriteTranscript() { return "desktop/writeTranscript"; }
    @GetMapping("/desktop/caseRelationMap") public String desktopCaseRelationMap() { return "desktop/caseRelationMap"; }
    @GetMapping("/desktop/caseTimeline")     public String desktopCaseTimeline()     { return "desktop/caseTimeline"; }
    @GetMapping("/desktop/cctvAnalysis") public String desktopCctvAnalysis() { return "desktop/cctvAnalysis"; }
}
