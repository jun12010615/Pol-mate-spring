# POL-MATE 수사 보조 시스템 (Spring Boot)

대한민국 경찰청 형사 수사관을 위한 AI 기반 수사 보조 플랫폼입니다.
진술 모순 탐지, 감정 분석, 사건 관계망 시각화, CCTV 번호판 분석, AI 수사 챗봇 기능을 제공합니다.

**Spring Boot 3.3.5 + JPA + Thymeleaf** 기반 웹 애플리케이션. 데스크탑/모바일 UI 분리 제공.

---

## 목차

1. [시스템 구성](#1-시스템-구성)
2. [필수 설치 프로그램](#2-필수-설치-프로그램)
3. [프로젝트 클론 및 빌드 준비](#3-프로젝트-클론-및-빌드-준비)
4. [Ollama LLM 모델 설치](#4-ollama-llm-모델-설치)
5. [Python 패키지 설치](#5-python-패키지-설치)
6. [application.properties 설정](#6-applicationproperties-설정)
7. [서버 실행 순서](#7-서버-실행-순서)
8. [접속 및 최초 로그인](#8-접속-및-최초-로그인)
9. [주요 기능 설명](#9-주요-기능-설명)
10. [프로젝트 구조](#10-프로젝트-구조)
11. [문제 해결](#11-문제-해결)
12. [외부 API 키 발급 안내](#12-외부-api-키-발급-안내)

---

## 1. 시스템 구성

POL-MATE는 세 개의 독립 서버가 함께 동작합니다.

```
[사용자 브라우저]
        ↕  HTTP :8080
[Spring Boot 서버]  ← 페이지 라우팅, DB 처리, 세션 관리
        ↕  HTTP :5001
[Python Flask 서버]  ← 진술 AI 분석, 관계망 추출, CCTV 번호판 탐지, 감정 분석
        ↕  HTTP :11434
[Ollama LLM 서버]  ← 진술 분석 / AI 챗봇 추론
```

| 서버 | 포트 | 역할 |
|------|------|------|
| Spring Boot (Java) | 8080 | 웹 페이지, REST API, DB 연동, 세션 관리 |
| Flask (Python) | 5001 | 진술 분석, 관계망 추출, CCTV 번호판 분석, 감정 분석 |
| Ollama | 11434 | LLM 추론 (`ingu627/exaone4.0:1.2b`, `gemma3:1b`) |

---

## 2. 필수 설치 프로그램

### Java
- **JDK 21** — https://adoptium.net
  - 설치 후 `JAVA_HOME` 환경 변수 설정 권장
- **IntelliJ IDEA** (Community 또는 Ultimate) — https://www.jetbrains.com/idea/download

### Python
- **Python 3.10 ~ 3.12** — https://www.python.org/downloads
  - 설치 시 **"Add Python to PATH"** 반드시 체크

### MySQL
- **MySQL 8.0** 이상 — https://dev.mysql.com/downloads/installer
  - 또는 MySQL Workbench (GUI 관리 도구)

### Ollama
- **Ollama** — https://ollama.com/download
  - Windows / macOS / Linux 지원

---

## 3. 프로젝트 클론 및 빌드 준비

### 저장소 클론

```bash
git clone <저장소 URL>
cd Pol-mate-spring
```

### IntelliJ에서 열기

1. IntelliJ 실행 → **Open** → 프로젝트 폴더 선택
2. `build.gradle` 파일을 우클릭 → **"Link Gradle Project"** 클릭
3. Gradle 동기화가 완료될 때까지 대기 (우측 하단 진행바 확인)
4. **File → Project Structure → SDK** 에서 JDK 21 설정 확인

> Gradle 동기화가 완료되지 않으면 실행 버튼이 비활성화됩니다.

---

## 4. Ollama LLM 모델 설치

Ollama 설치 후 터미널(CMD/PowerShell)에서 실행합니다.

```cmd
ollama pull ingu627/exaone4.0:1.2b
ollama pull gemma3:1b
```

| 모델 | 용도 | 크기 |
|------|------|------|
| `ingu627/exaone4.0:1.2b` | 진술 모순 분석, 관계망 추출, 타임라인 (Flask 서버 사용) | 약 1.3GB |
| `gemma3:1b` | AI 수사 챗봇 (Spring Boot 직접 호출) | 약 1GB |

> 사용 모델은 `application.properties`의 `ollama.model` 값을 수정해 변경할 수 있습니다.

---

## 5. Python 패키지 설치

프로젝트 루트(`polmate_serv.py`가 있는 폴더)에서 실행합니다.

```cmd
pip install flask flask-cors requests
pip install opencv-python numpy
pip install torch torchvision
pip install ultralytics easyocr
pip install transformers
```

가상환경을 사용하는 경우:

```cmd
python -m venv venv
venv\Scripts\activate
pip install flask flask-cors requests opencv-python numpy torch torchvision ultralytics easyocr transformers
```

### 모델 파일 준비

> **주의**: 일부 대용량 모델 파일은 파일 크기 제한으로 저장소에 포함되지 않습니다.
> 팀 내 공유 경로 또는 별도 전달 방법으로 수령한 뒤 아래 위치에 배치하세요.

프로젝트 루트에 다음 구조로 파일이 있어야 Flask 서버가 정상 실행됩니다.

```
Pol-mate-spring/
├── polmate_serv.py
├── emotion_model_loader.py
├── license_plate_detector.pt                        ← 저장소 포함 (6MB)
├── emotion_model/                                   ← 저장소 미포함, 별도 수령
│   ├── emotion_model.pt                             ← KoELECTRA 학습 가중치 (~450MB)
│   └── encoder/                                     ← tokenizer + config
│       ├── config.json
│       ├── tokenizer_config.json
│       └── vocab.txt
└── ocr_engine/
    ├── model.py
    ├── utils.py
    ├── modules/
    └── saved_models/
        └── korean_plate/
            ├── best_accuracy.pth                    ← 저장소 미포함, 별도 수령 (~190MB)
            └── best_norm_ED.pth                     ← 저장소 미포함, 별도 수령 (~190MB)
```

---

## 6. application.properties 설정

`src/main/resources/application.properties` 파일을 상황에 맞게 수정합니다.

```properties
# ── DB 연결 ──────────────────────────────────────────────────────
spring.datasource.url=jdbc:mysql://DB서버주소:포트/pol-mate?characterEncoding=UTF-8&serverTimezone=Asia%2FSeoul
spring.datasource.username=DB계정
spring.datasource.password=DB비밀번호
spring.datasource.driver-class-name=com.mysql.cj.jdbc.Driver

# ── Flask 서버 URL ───────────────────────────────────────────────
polmate.serv.base-url=http://localhost:5001

# ── CLOVA Speech STT (음성 조서 기능) ────────────────────────────
clova.speech.invoke-url=https://clovaspeech-gw.ncloud.com/recog/v1/stt
clova.speech.secret-key=발급받은_시크릿_키

# ── Ollama AI ────────────────────────────────────────────────────
ollama.url=http://localhost:11434/api/generate
ollama.model=ingu627/exaone4.0:1.2b

# ── 국가법령정보 API (AI 챗봇 법령 검색) ─────────────────────────
law.api.oc=발급받은_OC_ID

# ── Thymeleaf (개발 중 캐시 비활성화) ────────────────────────────
spring.thymeleaf.cache=false

# ── Gmail SMTP (비밀번호 찾기 인증코드) ──────────────────────────
spring.mail.host=smtp.gmail.com
spring.mail.port=587
spring.mail.username=발신용_이메일@gmail.com
spring.mail.password=Gmail_앱_비밀번호
spring.mail.properties.mail.smtp.auth=true
spring.mail.properties.mail.smtp.starttls.enable=true
```

> **Gmail 앱 비밀번호**: Google 계정 → 보안 → 2단계 인증 활성화 후 → 앱 비밀번호 발급

---

## 7. 서버 실행 순서

### 1단계: Ollama 실행

Ollama 설치 시 자동으로 백그라운드에서 실행됩니다.
수동으로 시작하려면:

```cmd
ollama serve
```

### 2단계: Flask 서버 실행

프로젝트 루트에서 실행합니다.

```cmd
cd C:\경로\Pol-mate-spring
python polmate_serv.py
```

정상 실행 시 출력:

```
번호판 YOLO 모델 로드 중...
학습된 번호판 OCR 모델 로드 중...
학습된 OCR 모델 로드 완료!
모든 모델 로드 완료!
 * Running on http://0.0.0.0:5001
```

서버 상태 확인:
```cmd
curl http://localhost:5001/health
```

### 3단계: Spring Boot 실행

IntelliJ에서 `src/main/java/com/polmate/PolmateApplication.java`를 열고 **▶ Run** 버튼 클릭.

또는 터미널에서:

```cmd
gradlew bootRun
```

Spring Boot가 정상 실행되면 콘솔에 아래 메시지가 출력됩니다:

```
Started PolmateApplication in X.XXX seconds (process running for X.XXX)
```

> 빌드만 하려면: `gradlew build -x test`

---

## 8. 접속 및 최초 로그인

세 서버(Spring Boot, Flask, Ollama)가 모두 실행 중인 상태에서 브라우저로 접속합니다.

```
http://localhost:8080
```

자동으로 데스크탑 로그인 페이지(`/desktop/login`)로 이동합니다.
모바일 페이지는 `http://localhost:8080/mobile/login`에서 접속합니다.

### 최초 가입

1. 로그인 화면에서 **회원가입** 클릭
2. **공무원증 번호(4자리)** 입력이 필요합니다 — DB의 `officer_badges` 테이블에 등록된 번호만 허용
3. 가입 완료 후 로그인하면 메인 화면으로 이동

### 관리자 계정 설정

최초 가입 후 DB에서 직접 `is_admin = 1`로 설정합니다.

```sql
UPDATE users SET is_admin = 1 WHERE user_id = '관리자_아이디';
```

관리자는 사이드바에 **접근 로그**, **관리 패널** 메뉴가 추가로 표시됩니다.

---

## 9. 주요 기능 설명

### 사건 관리
- 사건 등록/조회/삭제 (사건번호 형식: `2024-0312`)
- 조서(진술서) 등록 — 텍스트 직접 입력 또는 음성 녹음(STT)
- 진술 AI 분석 — Ollama LLM이 시간순 정리 및 모순 탐지
- 모순 탐지 결과 저장 및 목록 조회
- 조서 신뢰도 점수 산출 (일관성·구체성·감정·시간 4개 항목)
- 유사 사건 자동 검색 (캐시 결과 재사용)

### 진술 감정 분석
- 조서 텍스트를 문장 단위로 분리 후 4감정(불안·확신·회피·분노) 점수 산출
- KoELECTRA fine-tuned 회귀 모델 사용 (Flask `/emotion/analyze`)
- 모델 미로드 시 키워드 기반 fallback으로 자동 대체
- 분석 결과는 `emotion_analyses` 테이블에 저장, 데스크탑/모바일 감정분석 페이지에서 열람

### 사건 타임라인
- 조서 저장 시 Flask `/timeline/extract` 비동기 호출로 타임라인 이벤트 자동 추출
- 이벤트 유형: action / alibi / movement / other
- 시간 정밀도: exact / approximate / relative
- 상태 추적: `empty → pending → extracting → ready → failed`
- 데스크탑 타임라인 페이지에서 시각화

### 관계망 시각화
- 조서에서 인물/관계 자동 추출 (Flask → Ollama)
- Canvas 기반 인터랙티브 관계망 에디터
- 피의자·피해자·목격자·참고인 역할 구분 시각화
- 관계망 수정 이력 자동 저장 (`relation_history`)

### CCTV 영상 분석
- MP4/MOV/AVI/MKV 영상 업로드
- YOLO + 한국어 번호판 OCR 모델로 번호판 자동 탐지
- 번호판 일부 입력 후 검색, 탐지 시점(타임스탬프) 표시

### AI 수사 챗봇
- 형사소송법, 경찰관직무집행법 등 법령 기반 답변
- 국가법령정보 API 연동 실시간 법령 검색 후 LLM 컨텍스트 주입
- `gemma3:1b` 모델 사용, SSE 스트리밍으로 실시간 출력

### 음성 조서 작성
- CLOVA Speech API 연동 음성→텍스트 변환
- 변환된 텍스트 즉시 AI 분석 연동 가능

### 전체 통합 검색
- appbar 검색창에서 사건·조서·게시글 통합 검색
- 280ms 디바운스, 키워드 하이라이팅 지원

### 커뮤니티 게시판
- 부서 내 정보 공유, 게시글/댓글/좋아요
- 핫게시물 자동 분류, 태그 기반 검색

### 접근 로그 (관리자 전용)
- 사건 상세·조서 원문·게시글 열람 시 자동 기록 (AOP 방식)
- 관리자만 `/desktop/accessLog`에서 부서 전체 열람 이력 조회 가능

### 관리 패널 (관리자 전용)
- 부서 내 사용자 목록 조회
- 관리자 권한 부여·해제

---

## 10. 프로젝트 구조

```
Pol-mate-spring/
├── src/
│   └── main/
│       ├── java/com/polmate/
│       │   ├── PolmateApplication.java
│       │   ├── config/WebConfig.java                 ← AuthInterceptor 등록
│       │   ├── annotation/LogAccess.java             ← AOP 마킹 어노테이션
│       │   ├── aspect/AccessLogAspect.java           ← 접근 로그 AOP 구현
│       │   ├── controller/
│       │   │   ├── auth/       LoginController, RegisterController, FindAccountController
│       │   │   ├── cases/      CaseController, TimelineController, ContradictionController
│       │   │   ├── ai/         AiChatController, SttController, AnalyzeProxyController
│       │   │   ├── board/      BoardController, RelationBoardController
│       │   │   └── system/     PageController, SearchController, NotificationController,
│       │   │                   MypageController, AdminController, AccessLogController
│       │   ├── service/        (12개 — UserService, CaseService, TranscriptService,
│       │   │                    TimelineService, BoardService, RelationBoardService,
│       │   │                    ContradictionService, NotificationService,
│       │   │                    AccessLogService, SearchService, DepartmentService,
│       │   │                    LoginAttemptService)
│       │   ├── repository/
│       │   │   ├── (flat 12개)  UserRepository, CaseRepository, TranscriptRepository ...
│       │   │   ├── board/       BoardPost/Comment/Like/Link/TagRepository
│       │   │   └── relation/    RelationBoard/Person/Edge/HistoryRepository
│       │   └── entity/
│       │       ├── (flat 12개)  User, Case, Transcript, TranscriptScore,
│       │       │                ContradictionResult, Notification, OfficerBadge,
│       │       │                Department, CaseSimilarCache, TimelineEvent,
│       │       │                AccessLog, EmotionAnalysis
│       │       ├── board/       BoardPost, BoardComment, BoardLike, BoardLikeId,
│       │       │                BoardLink, BoardTag
│       │       └── relation/    RelationBoard, RelationPerson, RelationEdge, RelationHistory
│       └── resources/
│           ├── application.properties
│           └── templates/
│               ├── desktop/    (19개 페이지 + fragments/appbar.html, sidebar.html)
│               └── mobile/     (18개 페이지)
├── build.gradle
├── polmate_serv.py                      ← Flask 통합 서버
├── emotion_model_loader.py              ← KoELECTRA 감정 모델 로더
├── license_plate_detector.pt            ← YOLO 번호판 감지 모델
├── emotion_model/                       ← KoELECTRA fine-tuned 가중치
├── ocr_engine/                          ← 한국 번호판 OCR 모델
└── scripts/                             ← 개발·학습·테스트 스크립트
    ├── train_emotion.py                 ← 감정 모델 fine-tuning
    ├── call_relation_map.py             ← 관계망 API 테스트
    └── transcripts_2026_0528.json       ← 테스트 데이터
```

### 아키텍처 개요

```
[브라우저]
    │ GET /desktop/myCase
    ▼
[AuthInterceptor]  ← 세션 검사 (loginUser 없으면 로그인 리다이렉트)
    │
    ▼
[PageController]   ← URL → 뷰 이름 매핑
    │
    ▼
[Thymeleaf]        ← HTML 렌더링
    │
    ▼
[브라우저 JS]      ← fetch('/caseApi?action=caseList') AJAX 호출
    │
    ▼
[@RestController]  ← JSON 반환
    │
    ▼
[Service]          ← 비즈니스 로직
    │
    ▼
[JPA / JdbcTemplate]  ← DB 처리
```

**인증**: 모든 `/mobile/**`, `/desktop/**` 요청은 `AuthInterceptor`를 통과합니다.
세션에 `loginUser`가 없으면 자동으로 로그인 페이지로 리다이렉트됩니다.
각 HTML 파일에는 세션 체크 코드를 작성하지 않습니다 — Interceptor가 일괄 처리합니다.

---

## 11. 문제 해결

### Spring Boot 실행 관련

| 증상 | 원인 | 해결 |
|------|------|------|
| IntelliJ 실행 버튼 비활성화 | Gradle 미연동 | `build.gradle` 우클릭 → "Link Gradle Project" |
| DB 연결 오류 | `application.properties` 설정 오류 | datasource URL/계정 확인 |
| 포트 8080 충돌 | 다른 프로그램이 사용 중 | `server.port=8081` 로 변경하거나 충돌 프로세스 종료 |
| 한글 깨짐 | 인코딩 설정 누락 | `application.properties`에 `server.servlet.encoding.force=true` 확인 |
| HTML 수정이 반영되지 않음 | Thymeleaf 캐시 활성화 상태 | `spring.thymeleaf.cache=false` 설정 후 앱 재시작 |

### Flask 서버 관련

| 증상 | 원인 | 해결 |
|------|------|------|
| `ModuleNotFoundError` | Python 패키지 미설치 | `pip install 패키지명` |
| `license_plate_detector.pt` 없음 | YOLO 모델 파일 누락 | 프로젝트 루트에 파일 배치 |
| `best_accuracy.pth` 로드 실패 | OCR 모델 경로 오류 | `ocr_engine/saved_models/korean_plate/` 경로 확인 |
| `emotion_model.pt` 로드 실패 | 감정 모델 미배치 | `emotion_model/` 폴더에 파일 배치 후 서버 재시작 |
| Flask 포트 5001 충돌 | 다른 프로세스가 사용 중 | `polmate_serv.py` 내 포트 변경 후 `application.properties`도 동일하게 수정 |

### Ollama 관련

| 증상 | 원인 | 해결 |
|------|------|------|
| AI 챗봇 응답 없음 | Ollama 미실행 | `ollama serve` 실행 |
| 진술 분석 오류 | 모델 미설치 | `ollama pull ingu627/exaone4.0:1.2b` |
| 응답이 매우 느림 | GPU 미사용 | CUDA 지원 PyTorch 설치 또는 GPU 서버에서 실행 |

### CCTV / 번호판 분석 관련

| 증상 | 원인 | 해결 |
|------|------|------|
| 서버 연결 실패 | `polmate.serv.base-url` 오류 | `application.properties`에서 URL 확인 |
| 번호판 0건 탐지 | 영상 화질 또는 각도 문제 | `polmate_serv.py`에서 프레임 샘플링 간격 조정 |
| OCR 인식 오류 | 신뢰도 임계값 문제 | `OCR_CONFIDENCE_THRESHOLD` 값을 낮춤 (기본 0.85) |

### 감정 분석 관련

| 증상 | 원인 | 해결 |
|------|------|------|
| 감정 분석 결과가 모두 동일 | KoELECTRA 모델 미로드 | `emotion_model/` 배치 확인, Flask 서버 재시작 |
| `transformers` 패키지 오류 | 미설치 | `pip install transformers` |

---

## 12. 외부 API 키 발급 안내

| API | 발급처 | 용도 |
|-----|--------|------|
| CLOVA Speech | https://www.ncloud.com | 음성 → 텍스트 변환 (STT) |
| 국가법령정보 | https://www.law.go.kr/LSW/openapiInfo.do | 법령/판례 검색 (AI 챗봇 컨텍스트) |
| Gmail 앱 비밀번호 | Google 계정 → 보안 → 앱 비밀번호 | 비밀번호 찾기 인증코드 발송 |
