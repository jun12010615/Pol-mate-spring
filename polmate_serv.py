"""
polmate_serv.py  ·  통합 Flask 서버
────────────────────────────────────
[진술 분석 / 관계망]  (구 polmate_serv.py)
  POST /analyze             - 진술 모순 분석 (동기)
  POST /analyze/start       - 진술 분석 작업 시작 (비동기 job 발행)
  GET  /analyze/job/<id>    - 분석 작업 상태 조회
  POST /analyze/stream      - 진술 분석 SSE 스트리밍
  POST /summarize           - 진술 구조 요약(패스1)만 반환
  POST /relation_map        - 사건 관계망 JSON 추출
  POST /timeline/extract    - 조서 1건에서 타임라인 이벤트 JSON 추출

[CCTV 번호판 분석]  (구 app.py)
  POST /cctv/analyze        - 영상 업로드 후 번호판 분석 작업 시작
  GET  /cctv/status/<id>    - CCTV 분석 작업 상태 조회

[공통]
  GET  /health              - 서버 상태 확인
"""

from flask import Flask, request, jsonify, Response, stream_with_context
from flask_cors import CORS
import os
import requests
import json
import re
import uuid
import threading
import tempfile

# ── CV / OCR 관련 (CCTV 분석용) ─────────────────────────────────────────────
import cv2
import numpy as np
import torch
import torch.nn.functional as F
from ultralytics import YOLO
import easyocr

# ocr_engine 경로 추가 (polmate_serv.py 기준 상대경로)
import sys
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(BASE_DIR, 'ocr_engine'))
from model import Model
from utils import AttnLabelConverter

# ════════════════════════════════════════════════════════════════════════════
# Flask 앱 초기화
# ════════════════════════════════════════════════════════════════════════════
app = Flask(__name__)
CORS(app, resources={r"/*": {"origins": "*"}},
     methods=["GET", "POST", "OPTIONS"],
     allow_headers=["Content-Type", "Authorization"])

# ════════════════════════════════════════════════════════════════════════════
# [섹션 1] 진술 분석 / 관계망 — 설정 및 전역 변수
# ════════════════════════════════════════════════════════════════════════════
OLLAMA_URL = os.environ.get("OLLAMA_URL", "http://localhost:11434/api/generate")
MODEL      = os.environ.get("OLLAMA_MODEL", "sam860/exaone-4.0:1.2b")

_ANALYZE_JOBS: dict      = {}
_ANALYZE_JOBS_LOCK       = threading.Lock()

SERVER_REVISION = "polmate_serv-merged-20260418"

NO_MARKDOWN = """[절대 규칙 - 반드시 지킬 것]
- # ## ### 등 헤더 기호 사용 금지
- ** * __ _ 등 강조 기호 사용 금지
- - * 등 불릿 기호 사용 금지
- 번호 목록은 반드시 "1. 2. 3." 형식만 사용
- 마크다운 문법을 일절 사용하지 마라
- 일반 텍스트로만 출력해라
"""

ROLE_EN_TO_KO = {
    "suspect":   "피의자",
    "victim":    "피해자",
    "witness":   "목격자",
    "reference": "참고인",
}

_MERGE_TRADE_REP_ROLES = frozenset({"reference", "witness"})

_ACCOMPLICE_HINT_PATTERN = re.compile(
    r"(공동정범|공동\s*범행|범행\s*을?\s*함께|함께\s*저질(?:렀|를|러)|"
    r"범행\s*공동|공모|공동\s*가담|방조(?:범)?|범죄에\s*공동|"
    r"공범\s*관계|동업\s*범행|절도\s*를?\s*함께|사기\s*를?\s*함께)",
    re.I,
)

_ROLE_PRIORITY_STRENGTH: dict[str, int] = {
    "suspect":   4,
    "victim":    3,
    "witness":   2,
    "reference": 1,
}

_PLACEHOLDER_NAMES_RAW = frozenset({
    "", "미입력", "?", "unknown", "n/a", "na", "무명", "성명불상", "불상",
    "피의자", "피해자", "목격자", "참고인",
    "suspect", "victim", "witness", "reference",
    "진술자", "the suspect", "the victim",
})

# ════════════════════════════════════════════════════════════════════════════
# [섹션 2] CCTV 번호판 분석 — 모델 로드 및 전역 변수
# ════════════════════════════════════════════════════════════════════════════
print("번호판 YOLO 모델 로드 중...")
yolo_model = YOLO("license_plate_detector.pt")

OCR_MODEL_PATH = os.path.join(BASE_DIR, 'ocr_engine', 'saved_models', 'korean_plate', 'best_accuracy.pth')
OCR_CHARACTER  = '0123456789가나다라마거너더러머버서어저고노도로모보소오조구누두루무부수우주바사아자배하허호'
OCR_DEVICE     = torch.device('cuda' if torch.cuda.is_available() else 'cpu')

PLATE_PATTERN            = re.compile(r'\d{2,3}[가나다라마거너더러머버서어저고노도로모보소오조구누두루무부수우주바사아자배하허호]\d{4}')
OCR_CONFIDENCE_THRESHOLD = 0.85

cctv_jobs: dict = {}


class OCRopt:
    character         = OCR_CHARACTER
    Transformation    = 'TPS'
    FeatureExtraction = 'ResNet'
    SequenceModeling  = 'BiLSTM'
    Prediction        = 'Attn'
    sensitive         = False
    num_fiducial      = 20
    input_channel     = 1
    output_channel    = 512
    hidden_size       = 256
    batch_max_length  = 25
    imgH              = 32
    imgW              = 100
    rgb               = False
    PAD               = False


ocr_opt           = OCRopt()
ocr_converter     = AttnLabelConverter(ocr_opt.character)
ocr_opt.num_class = len(ocr_converter.character)

plate_ocr_model = None
try:
    print("학습된 번호판 OCR 모델 로드 중...")
    plate_ocr_model = Model(ocr_opt)
    plate_ocr_model = torch.nn.DataParallel(plate_ocr_model).to(OCR_DEVICE)
    state = torch.load(OCR_MODEL_PATH, map_location=OCR_DEVICE)
    plate_ocr_model.load_state_dict(state)
    plate_ocr_model.eval()
    print("학습된 OCR 모델 로드 완료!")
except Exception as e:
    print(f"학습된 OCR 모델 로드 실패 → EasyOCR 폴백: {e}")
    plate_ocr_model = None

ocr_reader = None
if plate_ocr_model is None:
    print("EasyOCR 로드 중...")
    ocr_reader = easyocr.Reader(['ko', 'en'], gpu=True)

print("모든 모델 로드 완료!")


# ════════════════════════════════════════════════════════════════════════════
# [섹션 3] 진술 분석 — 유틸리티 함수
# ════════════════════════════════════════════════════════════════════════════

def strip_markdown(text: str) -> str:
    text = re.sub(r'\*\*([^*]*)\*\*',       r'\1', text)
    text = re.sub(r'__([^_]*)__',           r'\1', text)
    text = re.sub(r'\*([^*\n]*)\*',         r'\1', text)
    text = re.sub(r'_([^_\n]*)_',           r'\1', text)
    text = re.sub(r'#{1,6}\s*',             '',    text)
    text = re.sub(r'^\s*[-•]\s+',           '',    text, flags=re.MULTILINE)
    text = re.sub(r'`{1,3}([^`]*)`{1,3}',  r'\1', text)
    text = re.sub(r'\*+',                   '',    text)
    text = re.sub(r'#+',                    '',    text)
    text = re.sub(r'\n{3,}',               '\n\n', text)
    return clean_output(text.strip())


def clean_output(text: str) -> str:
    if not text:
        return text
    return re.sub(r"[#*]", "", text)


TIMELINE_MAX_TEXT = int(os.environ.get("TIMELINE_MAX_TEXT", "9000"))
TIMELINE_NUM_PREDICT = int(os.environ.get("TIMELINE_NUM_PREDICT", "3072"))
TIMELINE_OLLAMA_TIMEOUT = int(os.environ.get("TIMELINE_OLLAMA_TIMEOUT", "180"))


def call_ollama(prompt: str, expect_json: bool = False, *, timeline: bool = False) -> str:
    """Ollama 호출. timeline=True 이면 타임라인 추출용 옵션·타임아웃."""
    if timeline:
        options = {
            "temperature": 0.05,
            "repeat_penalty": 1.0,
            "num_predict": TIMELINE_NUM_PREDICT,
            "num_ctx": int(os.environ.get("TIMELINE_NUM_CTX", "8192")),
        }
        attempts, timeout = 2, TIMELINE_OLLAMA_TIMEOUT
    else:
        options = {"temperature": 0.1, "repeat_penalty": 1.0}
        attempts, timeout = 3, 300

    for attempt in range(attempts):
        try:
            res = requests.post(
                OLLAMA_URL,
                json={"model": MODEL, "prompt": prompt, "stream": False, "options": options},
                timeout=timeout,
            )
            res.raise_for_status()
            text = res.json().get("response", "") or ""
            if timeline:
                text = text.strip()
                mobj = re.search(r'\{[\s\S]*"events"\s*:\s*\[[\s\S]*\}', text)
                if mobj:
                    return mobj.group(0).strip()
                return text
            if not expect_json:
                return strip_markdown(text)
            match = re.search(r"\{[\s\S]*\}", text)
            if match:
                return match.group(0)
        except Exception as e:
            if attempt == attempts - 1:
                raise e
    return ""


def call_ollama_timeline(prompt: str) -> str:
    return call_ollama(prompt, timeline=True)


def _truncate_timeline_text(text: str, max_chars=None) -> str:
    limit = max_chars if max_chars is not None else TIMELINE_MAX_TEXT
    text = (text or "").strip()
    if len(text) <= limit:
        return text
    cut = text[:limit]
    nl = cut.rfind("\n")
    if nl > limit * 7 // 10:
        cut = cut[:nl]
    return cut + "\n…(이하 생략)"


def iter_ollama_tokens(prompt: str):
    with requests.post(
        OLLAMA_URL,
        json={"model": MODEL, "prompt": prompt, "stream": True,
              "options": {"temperature": 0.1, "repeat_penalty": 1.0}},
        stream=True, timeout=300,
    ) as res:
        res.raise_for_status()
        for line in res.iter_lines(decode_unicode=True):
            if not line:
                continue
            try:
                obj = json.loads(line)
            except json.JSONDecodeError:
                continue
            piece = obj.get("response")
            if piece:
                yield piece


# ── 프롬프트 빌더 ────────────────────────────────────────────────────────────

def _pass1_prompt(case_num: str, n: int, full_body: str) -> str:
    n_hint = ""
    if n > 1:
        n_hint = (
            f"\n총 {n}개의 진술 조서가 제공된다. 모든 조서를 통합·교차 참고하여 분석하고, "
            "조서 간 모순도 찾아라."
        )
    return f"""{NO_MARKDOWN}
[원본 진술 전체]는 조서별로 구분된 블록이다. RAG에서 검색된 근거 문서를 읽듯이 **각 블록의 원문 표현을 보존**하며 정리해라.

필수 (모순 검토용 참고 자료로 쓰이므로 생략 금지):
- 부정·전면 부정 표현: 전혀, 일절, 절대, 한 번도, 없다, ~하지 않았다, ~한 적 없다 등은 **삭제·약화·일반 표현으로 바꾸지 말 것**. 가능하면 해당 구절을 따옴표 없이 원문 그대로 인용해 포함할 것.
- 긍정·부분 표현: 잠시, 잠깐, 한 적 있다, 했다 등도 동일하게 원문에 가깝게 남길 것.
- 시간·장소·인물·행위는 압축해도 되나, **법적 의미를 바꾸는 단어**는 빼거나 바꾸지 말 것.

위 규칙을 지키며 형사사건 진술을 시간 순서대로 재정리해라.
발언이 여러 명이면 화자를 구분해라.
사건번호: {case_num}
{n_hint}

[원본 진술 전체]
{full_body}

출력 형식 (아래 소제목 문구를 한 글자도 바꾸지 말고 정확히 한 줄에 써라. 생략 금지):
1) 첫 줄 소제목은 반드시 아래와 동일:
시간순 정리된 사건 흐름
2) 시간대별로 해당 기간의 날짜/시간·장소·진술자·주장을 들여쓰기·번호 목록으로 정리.
시간대가 여러개일경우 각 시간대별로 정리.

2) 시간대 정리가 끝난 뒤 각 진술자마다 요약본 제공. 제목은 반드시 "진술자의 알리바이 요약" 형태 한 줄 (예: 김철수의 알리바이 요약).
그 아래에 알리바이 요지만 번호 목록.

3) 조서 간 불일치·모순은 반드시 아래 제목 다음에만 서술 (제목 변경·생략 금지):
모순점 분석
그 아래 1. 2. 3. 번호 목록으로 근거를 요약.

4) 맨 마지막에 반드시:
추가 확인 사항
1. 원본에서 날짜·시간·장소·인물이 불명확한 항목만. 없으면 한 줄로 "없음". 최대 3개.

짧고 명확하게 한국어로만 답해라."""


def _pass3_prompt(corpus: str, verified_contradictions: list) -> str:
    return f"""{NO_MARKDOWN}
아래 모순 항목들이 진짜 모순인지 원본 진술 전체와 대조해서 판단해라.
원문에 없는 내용을 절대 추가하거나 추측하지 마라.
나열된 항목 외에 새로운 모순을 만들어내지 마라.
한국어로만. 3문장 이내.

[원본 진술 전체]
{corpus}

[탐지된 모순]
{json.dumps(verified_contradictions, ensure_ascii=False, indent=2)}"""


def _sse_line(obj: dict) -> str:
    return "data: " + json.dumps(obj, ensure_ascii=False) + "\n\n"


def _score_reliability_prompt(stmt_name: str, stmt_type: str, text: str) -> str:
    return f"""형사 진술 신뢰도를 평가하라. JSON만 출력하라. 다른 설명 금지.

진술자: {stmt_name} ({stmt_type})

[진술]
{text}

4가지 기준 (각 0-100 정수):
1. consistency(일관성): 진술 내에서 사실 관계가 일관적이고 자기모순이 없는가
2. specificity(구체성): 시간·장소·인물·행위 등 구체적 정보가 충분한가
3. emotion(감정안정성): 진술 어조가 차분하고 안정적인가 (흥분·방어적·과장 표현이 적을수록 높음)
4. temporal(시간정합성): 진술의 시간 순서와 시간대가 논리적으로 일치하는가

출력 형식 (JSON만, 다른 문장 절대 금지):
{{"consistency":<정수>,"specificity":<정수>,"emotion":<정수>,"temporal":<정수>,"reasons":{{"consistency":"<평가근거 한 문장>","specificity":"<평가근거 한 문장>","emotion":"<평가근거 한 문장>","temporal":"<평가근거 한 문장>"}}}}"""


def _relation_map_prompt(case_id: str, case_name: str, persons_meta: str, transcript_block: str) -> str:
    return f"""조서에서 인물(persons)과 관계(edges)만 뽑아 JSON 객체 하나만 출력한다. 설명·마크다운·코드펜스는 쓰지 마라.

사건: {case_id} {case_name}
진술자: {persons_meta}

[조서]
{transcript_block}

필드: persons(name, role 영문 suspect|victim|witness|reference, memo""), edges(src·dst=persons.name 동일, relType accomplice|harm|witness|acquaint|family, status match|mismatch|unknown, context "").
동일인: 역할당 노드 1개. 거래처 대표·A거래처 대표는 직함만 다르면 한 사람(reference든 witness든). 직함+실명 노드가 같이 있으면 실명으로 합침. 본문에서 성명이 갈리면 분리.
진술자 메타(요청의 transcripts name·type)와 같은 실명이면 role은 반드시 그 type에 맞춘다(피해자 조서인데 참고인으로 두지 말 것). 피의자·피해자가 목격·참고보다 우선.
relType: accomplice=공동범행·공모·방조 등이 나올 때만. 업무·접대·카드·식사만이면 acquaint. 진술 충돌은 witness+mismatch. 피의자↔피해자는 harm(피해관계). persons에 피의자와 피해자가 모두 있으면 **모든 피의자–피해자 쌍**에 harm edge가 있어야 한다(누락 금지). edge 1개 이상, 임의 인물 남발 금지.

예: {{"persons":[{{"name":"홍길동","role":"suspect","memo":""}},{{"name":"김철수","role":"victim","memo":""}}],"edges":[{{"src":"홍길동","dst":"김철수","relType":"harm","status":"unknown","context":""}}]}}"""


# 「1시간」「10년」 등에서 「1시」「10시」로 오인하지 않도록 시 뒤 '간' 제외
_KR_HOUR_NOT_DURATION = r"(?!\s*간)"
_KR_CLOCK_SIGNAL_RE = re.compile(
    (
        r"(?:오전|오후|새벽|저녁|밤|낮|아침)\s*\d{1,2}\s*시" + _KR_HOUR_NOT_DURATION
        + r"|\d{1,2}\s*:\s*\d{2}"
        + r"|\d{1,2}\s*시" + _KR_HOUR_NOT_DURATION + r"\s*\d{1,2}\s*분"
        + r"|\d{1,2}\s*시" + _KR_HOUR_NOT_DURATION + r"(?:\s*(?:경|쯤|반|무렵|전후))?"
        + r"|\d{4}\s*년\s*\d{1,2}\s*월"
        + r"|\d{1,2}/\d{1,2}"
    ),
    re.I,
)
_DAY_MONTH_RE = re.compile(r"\d{1,2}\s*월\s*\d{1,2}\s*일")
_TIMELESS_RELATIONSHIP_RE = re.compile(
    r"(?:알고\s*지낸|지기\s*친구|비즈니스\s*관계|관계(?:일|로)\s*뿐|인맥|아는\s*사이|"
    r"고교\s*시절|오래\s*알|면\s*알|친분|지인|동창|동업)",
    re.I,
)
_REL_TIME_OFFSET_RE = re.compile(
    r"\d{1,4}\s*분\s*(?:후|뒤|이후|지난|경과)"
    r"|\d{1,2}\s*시간\s*(?:후|뒤|이후|지난|경과)",
    re.I,
)


def _infer_case_reference_date(case_id: str):
    """사건 ID에서 기준일 추론."""
    from datetime import date
    cid = (case_id or "").strip()
    m = re.search(r"(\d{4})-(\d{2})-(\d{2})", cid)
    if m:
        try:
            return date(int(m.group(1)), int(m.group(2)), int(m.group(3)))
        except (TypeError, ValueError):
            pass
    m = re.search(r"(\d{4})[-_](\d{2})(\d{2})\b", cid)
    if m:
        try:
            return date(int(m.group(1)), int(m.group(2)), int(m.group(3)))
        except (TypeError, ValueError):
            pass
    return None


def _parse_reference_date_from_request(data: dict):
    """조서 전문부 날짜·요청 referenceDate·사건 ID 순으로 기준일."""
    from datetime import date
    if not isinstance(data, dict):
        return None
    for key in ("referenceDate", "reference_date"):
        raw = (data.get(key) or "").strip()
        if not raw:
            continue
        dt = _parse_timeline_iso(raw) or _parse_timeline_iso(raw + "T00:00:00")
        if dt:
            return dt.date()
        m = re.search(r"(\d{4})-(\d{2})-(\d{2})", raw)
        if m:
            try:
                return date(int(m.group(1)), int(m.group(2)), int(m.group(3)))
            except (TypeError, ValueError):
                pass
    try:
        y = int(data.get("preambleYear") or data.get("preamble_year") or 0)
        mo = int(data.get("preambleMonth") or data.get("preamble_month") or 0)
        d = int(data.get("preambleDay") or data.get("preamble_day") or 0)
        if y > 0 and mo > 0 and d > 0:
            return date(y, mo, d)
    except (TypeError, ValueError):
        pass
    return _infer_case_reference_date(data.get("caseId") or data.get("case_id") or "")


def _text_has_timeline_clock_signal(*parts: str) -> bool:
    """조서에 실제 시각·날짜·상대시간(N분 후) 표현이 있는지(단순 '목격'·'분' 포함 단어 제외)."""
    joined = " ".join((p or "").strip() for p in parts if p and str(p).strip())
    if not joined:
        return False
    if _KR_CLOCK_SIGNAL_RE.search(joined):
        return True
    if _DAY_MONTH_RE.search(joined):
        return True
    if _REL_TIME_OFFSET_RE.search(joined):
        return True
    if _find_all_korean_clocks_in_text(joined):
        return True
    if re.search(r"(?:당일|그날|이날|금일|범행\s*당시|사건\s*당일|어제|그제|그저께|오늘)", joined):
        return True
    return False


def _clock_phrase_overlaps_quote(time_text: str, quote: str, label: str = "") -> bool:
    """time_text의 시각 표현이 quote·label과 같은 사건 서술인지(부분 일치)."""
    tt = (time_text or "").strip()
    q = (quote or "").strip()
    lb = (label or "").strip()
    if not tt:
        return False
    if q and tt in q:
        return True
    if lb and tt in lb:
        return True
    for _h, _m, phrase in _find_all_korean_clocks_in_text(tt):
        if not phrase:
            continue
        if q and phrase in q:
            return True
        if lb and phrase in lb:
            return True
    dm = _DAY_MONTH_RE.search(tt)
    if dm:
        frag = dm.group(0)
        if (q and frag in q) or (lb and frag in lb):
            return True
    if q or lb:
        return False
    return True


def _observation_has_time_anchor(ev: dict) -> bool:
    """목격·관찰 이벤트: 본문에 시각 단서가 있거나, 앞 시각 문장과 '대신'으로 이어진 경우만."""
    quote = (ev.get("quote") or "").strip()
    tt = (ev.get("time_text") or "").strip()
    label = (ev.get("label") or "").strip()
    if _text_has_timeline_clock_signal(tt, label, quote):
        return True
    src = quote or tt or label
    if _parse_relative_offset_minutes(src) is not None:
        return True
    if "대신" in quote and any(m in quote for m in ("봤", "보았", "목격", "보이지", "없었", "있었")):
        return True
    return False


def _is_timeless_relationship_statement(ev: dict) -> bool:
    """인적관계·신분 설명만 있고 그 순간의 시각이 없는 진술."""
    quote = (ev.get("quote") or "").strip()
    if not quote:
        return False
    if _text_has_timeline_clock_signal(quote) or _parse_relative_offset_minutes(quote) is not None:
        return False
    if not _TIMELESS_RELATIONSHIP_RE.search(quote):
        return False
    timed_action = (
        "갔", "왔", "했다", "하였", "만났", "출발", "도착", "이동", "들어", "나갔",
        "머물", "체류", "방문",
    )
    if any(v in quote for v in timed_action):
        return False
    return True


def _event_time_grounded(ev: dict, reference_date=None) -> bool:
    """
    타임라인에 올릴 수 있는지: quote(원문) 또는 quote와 맞닿은 time_text에 시간 근거.
    AI time_start 단독·인적관계-only 서술은 제외.
    """
    if not isinstance(ev, dict):
        return False
    quote = (ev.get("quote") or "").strip()
    tt = (ev.get("time_text") or "").strip()
    if not quote:
        return False
    if _is_timeless_relationship_statement(ev):
        return False
    if _text_has_timeline_clock_signal(quote):
        return True
    if _parse_relative_offset_minutes(quote) is not None:
        return True
    if _parse_date_from_event_text(quote, reference_date):
        return True
    label = (ev.get("label") or "").strip()
    if tt and _text_has_timeline_clock_signal(tt) and _clock_phrase_overlaps_quote(tt, quote, label):
        return True
    if reference_date and _text_has_timeline_clock_signal(quote, tt):
        return True
    if (ev.get("event_type") or "").lower() == "observation" and _observation_has_time_anchor(ev):
        return True
    return False


def _sanitize_hallucinated_event_times(ev: dict, reference_date=None) -> dict:
    """원문에 없는 시각·날짜 제거(AI·서버 추정 포함)."""
    if not isinstance(ev, dict):
        return ev
    if _event_time_grounded(ev, reference_date):
        return ev
    ev["time_start"] = None
    ev["time_end"] = None
    ev["time_precision"] = "unknown"
    tt = (ev.get("time_text") or "").strip()
    quote = (ev.get("quote") or "").strip()
    if tt and quote and tt not in quote and not _text_has_timeline_clock_signal(quote):
        ev["time_text"] = ""
    return ev


def _sanitize_all_event_times(events: list, reference_date=None) -> list:
    return [_sanitize_hallucinated_event_times(ev, reference_date) for ev in events if isinstance(ev, dict)]


def _filter_timeline_time_only(events: list, reference_date=None) -> list:
    return [e for e in events if isinstance(e, dict) and _event_time_grounded(e, reference_date)]


def _timeline_extract_prompt(case_id: str, stmt_name: str, stmt_type: str, text: str, reference_date=None) -> str:
    ref_line = ""
    if reference_date:
        ref_line = f"\n사건·조서 기준일(날짜 없는 'N월 N일'·'오후 N시'는 이 날짜에 붙임): {reference_date.isoformat()}\n"
    return f"""{NO_MARKDOWN}
조서 원문에서 시간·시각·순서와 직접 관련된 행적·행위만 뽑아 JSON 객체 하나만 출력한다. 설명·마크다운·코드펜스 금지. JSON 밖 문장은 쓰지 마라.
모순·진술 대조·관계망 인물 추출은 하지 않는다.

사건: {case_id}
이 조서 화자(진술자): {stmt_name}
{ref_line}

[조서]
{text}

원문 보존(타임라인·모순 대조에 쓰이므로 생략·왜곡 금지):
1. time_text, quote는 [조서] 시간·순서·행위 표현을 원문 그대로 적는다.
2. label은 [조서]에 실제로 쓰인 단어·어구를 그대로 이어 붙여 한 줄로 쓴다. 요약·의역·번역·대체어 금지.
   - 조서에 「가죽 가방」이면 label에도 「가죽 가방」(leather bag 등 영어·다른 표현 금지).
   - 조서에 「김철수」면 「피해자」「상대방」 등으로 바꾸지 말고 「김철수」.
   - 조서에 「코인노래방」이면 그 표기 그대로(노래방·가라오케 등으로 바꾸지 말 것).
   - label에 넣는 모든 명사·동사·부정어(전혀, 일절, 하지 않았다 등)는 quote·[조서]에서 복사할 것. 새로 짓지 말 것.
3. 날짜·시각·장소·인물·행위를 추측으로 보완하지 말 것. 불명확하면 time_precision을 approximate 또는 relative로 두고 time_text에 원문 표현을 남긴다.
4. **절대시각 정확도**: time_text·quote·label에 나온 시·분·오전/오후/밤·날짜를 time_start·time_end에 그대로 반영한다. period(오전/오후/밤)를 바꾸지 말 것. 「밤 11시 5분」→23:05, 「오후 3시 10분」→15:10. 끝 시각이 본문에 있으면 time_end에 넣고 5분 등으로 대체하지 말 것.
5. time_start·time_end는 quote 또는 time_text에 시각·날짜·상대시간(N분 후·N시간 동안 등)이 있을 때만 채운다. [조서]에 없는 시각을 넣지 말 것.
6. 부정·전면 부정(전혀, 일절, 한 번도, 없다, 하지 않았다 등)과 부분·긍정 표현은 quote에서 빼거나 약화하지 말 것.

반드시 아래 JSON 형식으로만 답하라. 키 이름은 그대로 쓴다.

필드(events 배열 각 항목):
stmt_name: 그 행위를 한 사람 이름(이 조서 화자가 한 행위면 {stmt_name}). 타임라인 레인은 이 이름으로 묶인다.
stmt_type: 피의자, 피해자, 목격자, 참고인, 진술자 중 하나. 이 조서 화자의 행위면 조서 유형({stmt_type})에 맞출 것. event_type 값을 stmt_type에 넣지 말 것.
event_type: alibi(행적·체류), action(본인·타인의 구체 행위), movement(이동·도착·출발), observation(목격·부재·확인·목격한 사실·없었음·봤음), other
time_precision: exact, approximate, relative, unknown
time_start, time_end: YYYY-MM-DDTHH:MM:SS 또는 null
time_text: 본문의 시간·순서 표현(필수. 상대시간·모호 표현 포함)
place: 장소 또는 null
label: [조서] 원문 단어를 최대한 그대로 쓴 한 줄 요약(빈 문자열 금지. 번역·의역 금지)
quote: 근거가 되는 본문 문장 일부(필수, 1문장 이상)
confidence: high, medium, low
sort_order: 10, 20, 30 … 시간순

핵심 규칙:
0. **label = 원문 단어 조합**: 한 줄이어도 [조서]에 없는 표현·영어·일반화된 호칭을 넣지 말 것. quote에 있는 표현을 우선해 label을 만든다.
1. label, time_text, quote 중 하나라도 비거나 근거가 없으면 그 이벤트는 넣지 말 것.
2. 시간·순서 단서가 전혀 없는 일반 서술은 넣지 말 것. **몇 시·몇 분·N분 후·당일·날짜·상대시간 없이** 「~를 봤다」「~하는 것을 목격」만 있는 단순 목격은 events에 넣지 말 것(observation 금지).
2-1. **인적관계·신분·경력 설명만** 있는 문장(예: N년 지기, 비즈니스 관계, 고교 때부터 앎, 진술했다)은 시각이 없으면 events에 넣지 말 것.
2-2. **time_start·time_end는 quote에 시각·날짜·상대시간이 있을 때만** 채운다. 없으면 반드시 null. 오늘 날짜·임의 19시·사건 추정 시각을 넣지 말 것.
2-3. label·time_text에 quote에 없는 시각·날짜를 새로 쓰지 말 것.
3. stmt_name은 행위 주체 이름. 다른 인물의 행위면 그 인물 이름을 쓸 것.
4. quote에 적힌 시각과 time_start, time_end, time_text가 일치해야 한다. 시작·끝 시각이 둘 다 있으면(예: 밤 10시 40분에 … 밤 11시 5분에) time_start·time_end·time_text에 각각 반영하고, 끝 시각을 임의로 5분 뒤로 대체하지 말 것.
5. exact는 본문에 구체 시각(몇 시 몇 분·날짜)이 있을 때만 time_start를 채운다. approximate는 대략·경·쯤. N분 후·N시간 뒤만 있으면 time_start는 null로 두고 time_text·quote에 원문(예: 20분 후)을 그대로 남긴다(서버가 직전 이벤트 시각 기준으로 계산).
6. events는 시간순, sort_order 오름차순.
7. **쪼개기(SPLIT)**: **같은 문장·같은 시각 표현 안**에서 **타인에 대한 목격·부재·대신 관찰**(「대신」「그러나」+ 다른 사람 행적)만 observation으로 분리. 앞 절에 시각이 없으면 observation 단독 이벤트를 만들지 말 것.
8. **묶기(MERGE)**: 진술자 **본인의 한 시각대 알리바이**—어디 있었는지·하지 않은 일·당시 하던 일(코인노래방 1시간 등)—가 **연속**이면 **이벤트 1개**로 묶는다. event_type은 alibi. time_start=시작 시각, time_end=「N시간 동안」이 있으면 시작+N시간(예: 오후 3시쯤+1시간→4시). label·quote에 부정(금은방 미접근)과 체류(노래방)를 함께 요약해도 된다.
9. 「당시 저는 …」「…긴 했지만 … 하지 않았습니다」처럼 앞 문장 시각을 이어받는 **본인 행적 후속**은 새 이벤트로 쪼개지 말고 앞 알리바이에 합친다.
10. 예(묶기): 「어제 오후 3시쯤 서면 지하상가 근처였지만 금은방에는 가지 않았고, 당시 코인노래방에서 1시간 노래」→ **1개** alibi, time_text에 3시~1시간, place=코인노래방.
11. 예(쪼개기): 「3시 10분쯤 코인노래방 앞으로 갔는데 현우는 안에 없었고, 대신 비상구에서 봤다」→ movement+observation 분리(규칙 7).
12. [조서]에 「시」「분」「어제」「오후」「N시간」 등 시간·순서 표현이 하나라도 있으면 events는 **최소 1개 이상** 넣는다. 정말 시간 단서가 전혀 없을 때만 {{"events":[]}}.

출력: JSON 객체 하나만. 키는 events 배열. 각 항목의 quote·label·time_text는 반드시 [조서] 원문에서만 가져온다."""


_KR_CLOCK_PATTERNS = (
    (re.compile(r"(오전)\s*(\d{1,2})\s*시(?!\s*간)(?:\s*(\d{1,2})\s*분)?"), "am"),
    (re.compile(r"(오후)\s*(\d{1,2})\s*시(?!\s*간)(?:\s*(\d{1,2})\s*분)?"), "pm"),
    (re.compile(r"(밤)\s*(\d{1,2})\s*시(?!\s*간)(?:\s*(\d{1,2})\s*분)?"), "pm"),
    (re.compile(r"(저녁)\s*(\d{1,2})\s*시(?!\s*간)(?:\s*(\d{1,2})\s*분)?"), "pm"),
    (re.compile(r"(새벽)\s*(\d{1,2})\s*시(?!\s*간)(?:\s*(\d{1,2})\s*분)?"), "am"),
    (re.compile(r"(낮)\s*(\d{1,2})\s*시(?!\s*간)(?:\s*(\d{1,2})\s*분)?"), "am"),
    (re.compile(r"(아침)\s*(\d{1,2})\s*시(?!\s*간)(?:\s*(\d{1,2})\s*분)?"), "am"),
)
# 오전/오후 없이 「3시 10분」「15시」 등 (signal 정규식과 동일하게 파싱까지 연결)
_BARE_KR_CLOCK_RE = re.compile(
    r"(?<!오전)(?<!오후)(?<!새벽)(?<!저녁)(?<!밤)(?<!낮)(?<!아침)"
    r"(\d{1,2})\s*시(?!\s*간)(?:\s*(\d{1,2})\s*분)?",
    re.I,
)


def _korean_period_to_24h(hour12: int, minute: int, period: str) -> tuple[int, int]:
    m = max(0, min(59, int(minute)))
    h = int(hour12)
    if h < 0 or h > 23:
        h = max(1, min(12, h))
    if period == "am":
        if h in (0, 12):
            return (0, m)
        if 1 <= h <= 11:
            return (h, m)
        return (h % 24, m)
    if h == 12:
        return (12, m)
    if h == 0:
        return (0, m)
    if 1 <= h <= 11:
        return (h + 12, m)
    return (h, m)


def _infer_bare_korean_hour24(h: int, text: str, match_start: int) -> int:
    """period 없는 N시 → 앞뒤 맥락·24시 표기(15시)로 24시간 환산."""
    h = max(0, min(23, int(h)))
    ctx = (text or "")[max(0, match_start - 24):match_start]
    if any(k in ctx for k in ("새벽", "오전", "아침")):
        return 0 if h == 12 else (h if 1 <= h <= 11 else h)
    if any(k in ctx for k in ("오후", "저녁", "밤")):
        if h == 12:
            return 12
        return h + 12 if 1 <= h <= 11 else h
    if h >= 13:
        return h
    if h == 12:
        return 12
    # period 없는 1~11시: 조서·수사 맥락에서는 오후(12h+)가 많음. 새벽/오전 맥락은 위에서 처리.
    if 1 <= h <= 11:
        return h + 12
    return 12


def _find_all_korean_clocks_in_text(text: str) -> list:
    """문장 속 시각을 등장 순서대로 [(hour24, minute, phrase), ...]."""
    if not text or not str(text).strip():
        return []
    src = str(text)
    hits = []
    covered = set()
    for pat, period in _KR_CLOCK_PATTERNS:
        for m in pat.finditer(src):
            try:
                h = int(m.group(2))
                g3 = m.group(3)
                minute = int(g3) if g3 else 0
                h24, mi = _korean_period_to_24h(h, minute, period)
                hits.append((m.start(), m.end(), h24, mi, m.group(0).strip()))
                covered.update(range(m.start(), m.end()))
            except (TypeError, ValueError, IndexError):
                continue
    for m in _BARE_KR_CLOCK_RE.finditer(src):
        if any(i in covered for i in range(m.start(), m.end())):
            continue
        try:
            h = int(m.group(1))
            g2 = m.group(2)
            minute = int(g2) if g2 else 0
            h24 = _infer_bare_korean_hour24(h, src, m.start())
            hits.append((m.start(), m.end(), h24, minute, m.group(0).strip()))
        except (TypeError, ValueError, IndexError):
            continue
    hits.sort(key=lambda x: x[0])
    out = []
    for _pos, _end, h24, mi, phrase in hits:
        if out and out[-1][0] == h24 and out[-1][1] == mi:
            continue
        out.append((h24, mi, phrase))
    return out


def _merge_date_prefix_into_time_text(existing: str, start_phrase: str, end_phrase: str | None) -> str:
    """기존 time_text의 날짜 접두(20nn년 n월 n일)를 유지해 구간 표현 생성."""
    ex = (existing or "").strip()
    date_prefix = ""
    dm = re.search(r"\d{4}\s*년\s*\d{1,2}\s*월\s*\d{1,2}\s*일", ex)
    if dm:
        date_prefix = dm.group(0).strip() + " "
    if end_phrase and end_phrase != start_phrase:
        body = f"{start_phrase} ~ {end_phrase}"
    else:
        body = start_phrase
    if date_prefix and date_prefix.strip() not in body:
        return date_prefix + body
    return body if body else ex


def _event_time_source_text(ev: dict) -> str:
    return "\n".join(
        x for x in (
            (ev.get("quote") or "").strip(),
            (ev.get("time_text") or "").strip(),
            (ev.get("label") or "").strip(),
        )
        if x
    )


def _parse_date_from_event_text(text: str, reference_date=None):
    if not text:
        return None
    from datetime import date
    m = re.search(r"(\d{4})\s*년\s*(\d{1,2})\s*월\s*(\d{1,2})\s*일", text)
    if m:
        try:
            return date(int(m.group(1)), int(m.group(2)), int(m.group(3)))
        except (TypeError, ValueError):
            pass
    m2 = re.search(r"(\d{1,2})\s*월\s*(\d{1,2})\s*일", text)
    if m2 and reference_date:
        try:
            return date(reference_date.year, int(m2.group(1)), int(m2.group(2)))
        except (TypeError, ValueError):
            pass
    if reference_date:
        from datetime import timedelta
        if re.search(r"어제", text):
            return reference_date - timedelta(days=1)
        if re.search(r"(?:그제|그저께)", text):
            return reference_date - timedelta(days=2)
        if re.search(r"(?:오늘|금일)", text):
            return reference_date
    return None


def _parse_datetime_from_text_field(text: str):
    """time_text 등에 들어 있는 ISO 또는 한국어 시각 → datetime."""
    if not text or not str(text).strip():
        return None
    src = str(text).strip()
    dt = _parse_timeline_iso(src)
    if dt:
        return dt
    m = re.search(
        r"(\d{4})-(\d{2})-(\d{2})[T\s](\d{1,2}):(\d{2})(?::(\d{2}))?",
        src,
    )
    if m:
        from datetime import datetime
        try:
            sec = int(m.group(6)) if m.group(6) else 0
            return datetime(
                int(m.group(1)), int(m.group(2)), int(m.group(3)),
                int(m.group(4)), int(m.group(5)), sec,
            )
        except (TypeError, ValueError):
            pass
    return None


def _pick_clock_from_fields(
    time_text: str,
    label: str,
    quote: str,
    *,
    end_after: tuple[int, int] | None = None,
):
    """
    quote → time_text → label 순으로 시각 탐색.
    end_after=(h,m) 이면 마지막 시각(시작과 다른) 반환, 없으면 (None,None,None).
    """
    for src in (quote, time_text, label):
        if not src or not str(src).strip():
            continue
        clocks = _find_all_korean_clocks_in_text(str(src).strip())
        if not clocks:
            continue
        if end_after is None:
            return clocks[0]
        start_h, start_m = end_after
        if len(clocks) >= 2:
            end_h, end_m, end_phrase = clocks[-1]
            if (end_h, end_m) != (start_h, start_m):
                return end_h, end_m, end_phrase
    if end_after is not None:
        return None, None, None
    return None


def _reconcile_timeline_event_times(ev: dict, reference_date=None) -> dict:
    """quote에 근거가 있을 때만 time_start/end 확정. 기준일은 전문부·사건 ID."""
    if not isinstance(ev, dict):
        return ev
    tt = (ev.get("time_text") or "").strip()
    label = (ev.get("label") or "").strip()
    quote = (ev.get("quote") or "").strip()
    sources = _event_time_source_text(ev)
    if not sources:
        return ev

    from datetime import datetime, timedelta

    if not _event_time_grounded(ev, reference_date):
        return _sanitize_hallucinated_event_times(ev, reference_date)

    iso_start = None
    for field in (tt, label):
        cand = _parse_datetime_from_text_field(field)
        if not cand:
            continue
        iso_s = cand.strftime("%Y-%m-%dT%H:%M:%S")
        if (
            iso_s in quote
            or (field and field in quote)
            or _text_has_timeline_clock_signal(quote)
            or (_text_has_timeline_clock_signal(field) and _event_time_grounded(ev, reference_date))
        ):
            iso_start = cand
            break
    if iso_start:
        ev["time_start"] = iso_start.strftime("%Y-%m-%dT%H:%M:%S")
        te = _parse_timeline_iso(ev.get("time_end"))
        if not te or te <= iso_start:
            ev["time_end"] = (iso_start + timedelta(minutes=5)).strftime("%Y-%m-%dT%H:%M:%S")
        prec_src = tt or quote
        if any(x in prec_src for x in ("경", "쯤", "대략", "무렵")):
            ev["time_precision"] = "approximate"
        else:
            ev["time_precision"] = ev.get("time_precision") or "exact"
        return ev

    picked = _pick_clock_from_fields(tt, label, quote)
    if not picked:
        return _sanitize_hallucinated_event_times(ev, reference_date)
    start_h, start_m, start_phrase = picked

    base_date = _parse_date_from_event_text(quote, reference_date)
    if not base_date:
        base_date = _parse_date_from_event_text(tt, reference_date)
    if not base_date:
        base_date = _parse_date_from_event_text(label, reference_date)
    if not base_date and reference_date:
        if _text_has_timeline_clock_signal(quote, tt, label):
            base_date = reference_date
    if not base_date:
        ev["time_start"] = None
        ev["time_end"] = None
        ev["time_precision"] = "unknown"
        if not tt and start_phrase:
            ev["time_text"] = start_phrase
        return ev

    def _combine(h: int, m: int):
        return datetime(base_date.year, base_date.month, base_date.day, h, m, 0)

    start_dt = _combine(start_h, start_m)
    ev["time_start"] = start_dt.strftime("%Y-%m-%dT%H:%M:%S")

    end_h, end_m, end_phrase = _pick_clock_from_fields(tt, label, quote, end_after=(start_h, start_m))
    if end_h is not None:
        end_dt = _combine(end_h, end_m)
        if end_dt <= start_dt:
            end_dt += timedelta(days=1)
        ev["time_end"] = end_dt.strftime("%Y-%m-%dT%H:%M:%S")
        if not tt:
            ev["time_text"] = _merge_date_prefix_into_time_text("", start_phrase, end_phrase)
    else:
        te = _parse_timeline_iso(ev.get("time_end"))
        if not te or te <= start_dt:
            ev["time_end"] = (start_dt + timedelta(minutes=5)).strftime("%Y-%m-%dT%H:%M:%S")
        if not tt:
            ev["time_text"] = _merge_date_prefix_into_time_text("", start_phrase, None)

    ev["time_precision"] = _infer_clock_precision_from_quote(
        sources, start_phrase, end_phrase if end_h is not None else None
    )
    return ev


def _is_approximate_clock_context(quote: str, phrase: str) -> bool:
    if not phrase:
        return False
    if any(m in phrase for m in ("경", "쯤", "대략", "무렵")):
        return True
    if not quote:
        return False
    idx = quote.find(phrase)
    if idx >= 0:
        window = quote[idx : idx + len(phrase) + 4]
        if any(m in window for m in ("경", "쯤", "대략", "무렵")):
            return True
    return False


def _infer_clock_precision_from_quote(quote: str, start_phrase: str, end_phrase: str | None) -> str:
    if _is_approximate_clock_context(quote, start_phrase):
        return "approximate"
    if end_phrase and _is_approximate_clock_context(quote, end_phrase):
        return "approximate"
    return "exact"


def _reconcile_timeline_events_from_quotes(events: list, reference_date=None) -> list:
    return [_reconcile_timeline_event_times(ev, reference_date) for ev in events]


_REL_MINUTES_AFTER = re.compile(
    r"(?:약|대략|그때부터|출발(?:한)?\s*지)?\s*(\d{1,4})\s*분\s*(?:후|뒤|이후|지난|지나|경과)",
    re.I,
)
_REL_MINUTES_ELAPSED = re.compile(
    r"(?:약|대략)?\s*(\d{1,4})\s*분(?:이|이)?\s*(?:지난|지나|경과|후|뒤)",
    re.I,
)
_REL_HOURS_AFTER = re.compile(
    r"(?:약|대략)?\s*(\d{1,2})\s*시간\s*(?:후|뒤|이후|지난|경과|정도)",
    re.I,
)


def _parse_relative_offset_minutes(text: str):
    """'20분 후'·'N시간 후' 등 상대 분 오프셋. 없으면 None."""
    if not text or not str(text).strip():
        return None
    src = str(text).strip()
    for pat in (_REL_MINUTES_AFTER, _REL_MINUTES_ELAPSED):
        m = pat.search(src)
        if m:
            try:
                return int(m.group(1))
            except (TypeError, ValueError):
                pass
    m = _REL_HOURS_AFTER.search(src)
    if m:
        try:
            return int(m.group(1)) * 60
        except (TypeError, ValueError):
            pass
    return None


def _event_datetime(ev: dict):
    return _parse_timeline_iso(ev.get("time_start"))


def _update_chain_anchor(last_anchor, ev: dict):
    """직전 이벤트 시작 시각만 기준(막대 끝 +5분으로 상대시간이 밀리지 않게)."""
    return _event_datetime(ev) or last_anchor


def _relative_chain_key(ev: dict):
    tid = ev.get("transcript_id") or ev.get("transcriptId") or 0
    name = re.sub(r"\s+", "", (ev.get("stmt_name") or ev.get("stmtName") or "").strip())
    return (tid, name)


_SAME_TIME_CONNECTORS = (
    "대신",
    "그러나",
    "그런데",
    "하지만",
    "이어",
    "한편",
    "그리고",
    "그 후",
    "이후",
    "곧",
)


def _is_same_speaker_alibi_continuation(quote: str) -> bool:
    """본인 알리바이 연속 서술(당시·부정·체류) — 별도 observation 이벤트로 쪼개지 않음."""
    q = (quote or "").strip()
    if not q:
        return False
    if re.search(r"당시\s*(저는|나는|제가)", q):
        return True
    if "긴 했지만" in q or "얼씬도" in q or "하지 않았" in q:
        if "저는" in q or "제가" in q or "나는" in q or "혼자" in q:
            return True
    return False


def _quote_needs_same_time_inherit(quote: str) -> bool:
    q = (quote or "").strip()
    if not q:
        return False
    if _is_same_speaker_alibi_continuation(q):
        return False
    if _find_all_korean_clocks_in_text(q):
        return False
    if "대신" in q and any(m in q for m in ("봤", "보았", "목격", "내려", "나타", "있었", "보이지")):
        return True
    # 「그러나/대신」 등 접속으로 앞 시각 문장과 한 덩어리일 때만 상속
    return any(c in q for c in ("그러나", "그런데", "하지만"))


_DUR_HOURS_SPAN = re.compile(r"(\d{1,2})\s*시간\s*동안", re.I)
_DUR_MINUTES_SPAN = re.compile(r"(\d{1,4})\s*분\s*동안", re.I)


def _parse_activity_duration_minutes(text: str):
    if not text:
        return None
    src = str(text)
    m = _DUR_HOURS_SPAN.search(src)
    if m:
        try:
            return int(m.group(1)) * 60
        except (TypeError, ValueError):
            pass
    m = _DUR_MINUTES_SPAN.search(src)
    if m:
        try:
            return int(m.group(1))
        except (TypeError, ValueError):
            pass
    return None


def _apply_activity_duration_end(events: list) -> list:
    """「1시간 동안」 등 → time_end = time_start + 기간."""
    from datetime import timedelta

    for ev in events:
        if not isinstance(ev, dict):
            continue
        start = _event_datetime(ev)
        if not start:
            continue
        src = f"{ev.get('quote') or ''} {ev.get('time_text') or ''}"
        mins = _parse_activity_duration_minutes(src)
        if mins is None or mins <= 0:
            continue
        end = start + timedelta(minutes=mins)
        ev["time_end"] = end.strftime("%Y-%m-%dT%H:%M:%S")
        tt = (ev.get("time_text") or "").strip()
        if "동안" not in tt and mins >= 60 and mins % 60 == 0:
            h = mins // 60
            if tt:
                ev["time_text"] = f"{tt} (~{h}시간)"
    return events


def _is_alibi_like_event(ev: dict) -> bool:
    t = (ev.get("event_type") or "").lower()
    if t in ("alibi", "movement"):
        return True
    q = f"{ev.get('quote') or ''} {ev.get('label') or ''}"
    return any(m in q for m in ("알리바이", "있었", "하지 않", "얼씬", "당시", "혼자", "노래방", "들어가"))


def _can_merge_alibi_cluster(a: dict, b: dict) -> bool:
    if _relative_chain_key(a) != _relative_chain_key(b):
        return False
    if not _is_alibi_like_event(a) or not _is_alibi_like_event(b):
        return False
    bq = (b.get("quote") or "").strip()
    if "대신" in bq and any(m in bq for m in ("봤", "보았", "목격")):
        return False
    et = (b.get("event_type") or "").lower()
    if et == "observation" and not _is_same_speaker_alibi_continuation(bq):
        sn = (b.get("stmt_name") or "").strip()
        if sn and sn not in bq and ("봤" in bq or "없었" in bq):
            return False
    if _is_same_speaker_alibi_continuation(bq):
        return True
    if "당시" in bq and ("저는" in bq or "제가" in bq or "혼자" in bq):
        return True
    a_start = _event_datetime(a)
    b_start = _event_datetime(b)
    if a_start and b_start and abs((b_start - a_start).total_seconds()) <= 3600:
        return True
    return False


def _excerpt_label_from_quote(quote: str, max_len: int = 100) -> str:
    """병합·보조용: label 대신 quote 원문 일부를 잘라 쓴다."""
    q = (quote or "").strip()
    if not q:
        return ""
    for sep in ("습니다.", "했습니다.", "다.", "요.", "죠."):
        idx = q.find(sep)
        if 0 < idx <= max_len * 2:
            return q[: idx + len(sep)].strip()
    if len(q) <= max_len:
        return q
    return q[:max_len].rstrip() + "…"


def _merge_cluster_label(quotes: list, labels: list) -> str:
    """알리바이 묶기 시 label은 quote 원문 발췌를 우선한다."""
    if len(quotes) == 1:
        ex = _excerpt_label_from_quote(quotes[0], 150)
        if ex:
            return ex
    if len(quotes) >= 2:
        a = _excerpt_label_from_quote(quotes[0], 60)
        b = _excerpt_label_from_quote(quotes[-1], 60)
        if a and b:
            return f"{a} … {b}"[:200]
        if a:
            return a
    if len(labels) == 1:
        return labels[0]
    if len(labels) >= 2:
        return labels[0][:80] + " … " + labels[-1][:80]
    return ""


def _combine_alibi_cluster(cluster: list) -> dict:
    base = dict(cluster[0])
    quotes = []
    labels = []
    places = []
    for ev in cluster:
        q = (ev.get("quote") or "").strip()
        if q and q not in quotes:
            quotes.append(q)
        lb = (ev.get("label") or "").strip()
        if lb:
            labels.append(lb)
        pl = (ev.get("place") or "").strip()
        if pl:
            places.append(pl)
    base["event_type"] = "alibi"
    base["quote"] = " / ".join(quotes)[:2000]
    merged_label = _merge_cluster_label(quotes, labels)
    if merged_label:
        base["label"] = merged_label
    if places:
        base["place"] = places[-1]
    base["sort_order"] = min(int(ev.get("sort_order") or 0) for ev in cluster)
    # time_end: longest span
    from datetime import timedelta
    start = _event_datetime(base)
    max_end = None
    for ev in cluster:
        src = f"{ev.get('quote') or ''} {ev.get('time_text') or ''}"
        mins = _parse_activity_duration_minutes(src)
        if start and mins:
            cand = start + timedelta(minutes=mins)
            if max_end is None or cand > max_end:
                max_end = cand
        te = _parse_timeline_iso(ev.get("time_end"))
        if te and (max_end is None or te > max_end):
            max_end = te
    if max_end:
        base["time_end"] = max_end.strftime("%Y-%m-%dT%H:%M:%S")
    return base


def _merge_same_period_alibi_blocks(events: list) -> list:
    ordered = sorted(
        [e for e in events if isinstance(e, dict)],
        key=lambda e: int(e.get("sort_order") or 0),
    )
    out = []
    i = 0
    while i < len(ordered):
        ev = ordered[i]
        if not _is_alibi_like_event(ev):
            out.append(ev)
            i += 1
            continue
        cluster = [ev]
        j = i + 1
        while j < len(ordered) and _can_merge_alibi_cluster(cluster[-1], ordered[j]):
            cluster.append(ordered[j])
            j += 1
        out.append(_combine_alibi_cluster(cluster) if len(cluster) > 1 else ev)
        i = j
    return out


def _inherit_same_time_context(events: list) -> list:
    """앞 이벤트 시각이 있는데 뒤 절만 후술·목격·부재인 경우 동일 시각대 상속."""
    from datetime import timedelta

    ordered = sorted(
        [e for e in events if isinstance(e, dict)],
        key=lambda e: int(e.get("sort_order") or 0),
    )
    last_by_key = {}
    for ev in ordered:
        key = _relative_chain_key(ev)
        quote = (ev.get("quote") or "").strip()
        clocks = _find_all_korean_clocks_in_text(quote)
        if clocks:
            dt = _event_datetime(ev)
            if dt:
                last_by_key[key] = ev
            continue
        prev = last_by_key.get(key)
        if not prev or not _quote_needs_same_time_inherit(quote):
            if _event_datetime(ev):
                last_by_key[key] = ev
            continue
        anchor = _event_datetime(prev)
        if not anchor:
            continue
        if _event_datetime(ev):
            last_by_key[key] = ev
            continue
        ev["time_start"] = anchor.strftime("%Y-%m-%dT%H:%M:%S")
        ev["time_end"] = (anchor + timedelta(minutes=5)).strftime("%Y-%m-%dT%H:%M:%S")
        prec = (ev.get("time_precision") or "").lower()
        if prec not in ("exact", "approximate", "relative"):
            prev_prec = (prev.get("time_precision") or "approximate").lower()
            ev["time_precision"] = prev_prec if prev_prec in ("exact", "approximate") else "approximate"
        tt = (ev.get("time_text") or "").strip()
        prev_tt = (prev.get("time_text") or "").strip()
        if not tt and prev_tt:
            ev["time_text"] = f"{prev_tt} (동일 시각대)"
        last_by_key[key] = ev
    return events


def _resolve_relative_durations_from_text(events: list) -> list:
    """quote/time_text의 'N분 후' → 같은 조서·stmt_name 직전 이벤트 time_start + N분."""
    from datetime import timedelta

    ordered = sorted(
        [e for e in events if isinstance(e, dict)],
        key=lambda e: int(e.get("sort_order") or 0),
    )
    anchors = {}
    for ev in ordered:
        key = _relative_chain_key(ev)
        last_anchor = anchors.get(key)
        quote = (ev.get("quote") or "").strip()
        tt = (ev.get("time_text") or "").strip()
        src = quote or tt

        if _find_all_korean_clocks_in_text(quote):
            anchors[key] = _update_chain_anchor(last_anchor, ev)
            continue

        existing = _event_datetime(ev)
        off = _parse_relative_offset_minutes(src)
        if off is None and quote and tt:
            off = _parse_relative_offset_minutes(quote)
        if off is None:
            if existing:
                anchors[key] = _update_chain_anchor(last_anchor, ev)
            continue

        if last_anchor is None:
            continue

        start_dt = last_anchor + timedelta(minutes=off)
        ev["time_start"] = start_dt.strftime("%Y-%m-%dT%H:%M:%S")
        ev["time_end"] = (start_dt + timedelta(minutes=5)).strftime("%Y-%m-%dT%H:%M:%S")
        ev["time_precision"] = "relative"
        if not tt and quote:
            ev["time_text"] = quote[:200] if len(quote) <= 200 else quote[:199] + "…"
        anchors[key] = start_dt

    return events


def _parse_timeline_iso(s: str):
    if not s or not str(s).strip():
        return None
    from datetime import datetime
    v = str(s).strip().replace(" ", "T")
    for fmt in ("%Y-%m-%dT%H:%M:%S", "%Y-%m-%dT%H:%M", "%Y-%m-%d %H:%M:%S", "%Y-%m-%d %H:%M"):
        try:
            return datetime.strptime(v[:19] if "T" in v else v, fmt)
        except ValueError:
            continue
    return None


def _normalize_timeline_event_fields(ev: dict) -> dict:
    """미사용 anchor/offset 필드 제거."""
    if not isinstance(ev, dict):
        return ev
    for key in ("anchor_index", "anchor_sort_order", "offset_minutes", "offset_end_minutes"):
        ev.pop(key, None)
    return ev


# ── 관계망 — 인물 병합 / 역할 보정 헬퍼 ────────────────────────────────────

def _normalize_role(role: str) -> str:
    r = (role or "reference").lower().strip()
    if r in ROLE_EN_TO_KO:
        return r
    if "피의자" in r or r == "suspect":
        return "suspect"
    if "피해자" in r or r == "victim":
        return "victim"
    if "목격" in r or r == "witness":
        return "witness"
    return "reference"


def _compact_person_label(name: str) -> str:
    return re.sub(r"\s+", "", (name or "").strip())


def _is_placeholder_person_name(name: str) -> bool:
    n = (name or "").strip()
    if not n:
        return True
    if n in _PLACEHOLDER_NAMES_RAW or n.lower() in _PLACEHOLDER_NAMES_RAW:
        return True
    if re.match(r"^(피의자|피해자|목격자|참고인)\s*\d*$", n):
        return True
    if re.match(r"^(피의자|피해자|목격자|참고인)\s*[A-Za-z]$", n):
        return True
    if re.match(r"^(suspect|victim|witness|reference)\s*\d*$", n.lower()):
        return True
    if n == "미입력" or re.match(r"^미입력\s*[\(（]", n):
        return True
    return False


def _is_pure_trade_rep_title(name: str) -> bool:
    n0 = (name or "").strip()
    if not n0 or _is_placeholder_person_name(n0):
        return True
    c = _compact_person_label(n0)
    return bool(re.match(r"^([A-Za-z0-9가-힣]{1,3})?거래처대표$", c))


def _corpus_suggests_accomplice(corpus: str) -> bool:
    if not (corpus or "").strip():
        return False
    return _ACCOMPLICE_HINT_PATTERN.search(corpus) is not None


def _edge_rel_is_accomplice(rel: str) -> bool:
    r = (rel or "").strip().lower()
    if r == "accomplice":
        return True
    return "공범" in (rel or "")


def _person_role_map(persons: list) -> dict[str, str]:
    m: dict[str, str] = {}
    for p in persons or []:
        if not isinstance(p, dict):
            continue
        nm = str(p.get("name") or "").strip()
        if nm:
            m[nm] = _normalize_role(str(p.get("role") or ""))
    return m


def _relation_edge_endpoints(e: dict) -> tuple[str, str]:
    s = str(e.get("src") or e.get("srcName") or "").strip()
    d = str(e.get("dst") or e.get("dstName") or "").strip()
    return s, d


def _stronger_role(role_a: str, role_b: str) -> str:
    a = _normalize_role(role_a)
    b = _normalize_role(role_b)
    return a if _ROLE_PRIORITY_STRENGTH.get(a, 0) >= _ROLE_PRIORITY_STRENGTH.get(b, 0) else b


def _transcript_hint_name_for_role(transcripts: list, role_en: str) -> str | None:
    if not isinstance(transcripts, list):
        return None
    ko = ROLE_EN_TO_KO.get(role_en, "")
    found: list[str] = []
    for tr in transcripts:
        if not isinstance(tr, dict):
            continue
        typ = str(tr.get("type") or "").strip()
        nm  = str(tr.get("name") or "").strip()
        if not nm or _is_placeholder_person_name(nm):
            continue
        if ko and typ == ko:
            found.append(nm)
        elif role_en == "suspect" and ("피의자" in typ or typ == "suspect"):
            found.append(nm)
        elif role_en == "victim"  and ("피해자" in typ or typ == "victim"):
            found.append(nm)
        elif role_en == "witness" and ("목격" in typ or typ == "witness"):
            found.append(nm)
        elif role_en == "reference" and ("참고" in typ or typ == "reference"):
            found.append(nm)
    uniq: list[str] = []
    seen = set()
    for x in found:
        if x not in seen:
            seen.add(x)
            uniq.append(x)
    if len(uniq) == 1:
        return uniq[0]
    return None


def _strip_llm_code_fences(text: str) -> str:
    src = (text or "").strip()
    m = re.search(r"```(?:json)?\s*([\s\S]*?)```", src, re.I)
    if m:
        return m.group(1).strip()
    return src


def _repair_json_text(chunk: str) -> str:
    """모델이 흔히 내는 JSON 문법 오류 완화(주석·후행 쉼표 등)."""
    if not chunk:
        return chunk
    out = re.sub(r"//[^\n]*", "", chunk)
    out = re.sub(r"/\*[\s\S]*?\*/", "", out)
    out = re.sub(r",\s*([}\]])", r"\1", out)
    return out


def _json_loads_lenient(chunk: str):
    if not (chunk or "").strip():
        return None
    for candidate in (chunk, _repair_json_text(chunk)):
        try:
            return json.loads(candidate)
        except json.JSONDecodeError:
            continue
    return None


def _extract_balanced_json_object(text: str, open_ch: str = "{", close_ch: str = "}") -> str | None:
    start = text.find(open_ch)
    if start < 0:
        return None
    depth = 0
    in_str = False
    esc = False
    for i in range(start, len(text)):
        ch = text[i]
        if in_str:
            if esc:
                esc = False
            elif ch == "\\":
                esc = True
            elif ch == '"':
                in_str = False
            continue
        if ch == '"':
            in_str = True
        elif ch == open_ch:
            depth += 1
        elif ch == close_ch:
            depth -= 1
            if depth == 0:
                return text[start: i + 1]
    return None


def _close_truncated_json_array(arr_text: str) -> str:
    depth = 0
    in_str = False
    esc = False
    for ch in arr_text:
        if in_str:
            if esc:
                esc = False
            elif ch == "\\":
                esc = True
            elif ch == '"':
                in_str = False
            continue
        if ch == '"':
            in_str = True
        elif ch == "[":
            depth += 1
        elif ch == "]":
            depth -= 1
    if depth > 0:
        return arr_text.rstrip().rstrip(",") + ("]" * depth)
    return arr_text


def _extract_json_object(text: str) -> dict | None:
    if not (text or "").strip():
        return None
    src = _strip_llm_code_fences(text)
    chunk = _extract_balanced_json_object(src, "{", "}")
    if not chunk:
        m = re.search(r"\{[\s\S]*\}", src)
        chunk = m.group(0) if m else None
    if not chunk:
        return None
    obj = _json_loads_lenient(chunk)
    return obj if isinstance(obj, dict) else None


def _extract_timeline_payload(text: str) -> dict | None:
    """
    타임라인 LLM 응답 → {"events": [...]}.
    본문 설명·깨진 JSON·잘린 배열 등을 여러 단계로 복구한다.
    """
    if not (text or "").strip():
        return None
    src = _strip_llm_code_fences(text)

    obj = _extract_json_object(src)
    if isinstance(obj, dict) and isinstance(obj.get("events"), list):
        return obj

    search_from = 0
    while True:
        pos = src.find('"events"', search_from)
        if pos < 0:
            break
        start = src.rfind("{", 0, pos)
        if start >= 0:
            chunk = _extract_balanced_json_object(src[start:], "{", "}")
            if chunk:
                cand = _json_loads_lenient(chunk)
                if isinstance(cand, dict) and isinstance(cand.get("events"), list):
                    return cand
        search_from = pos + 8

    m = re.search(r'"events"\s*:\s*(\[[\s\S]*)', src, re.I)
    if m:
        arr_part = _close_truncated_json_array(m.group(1))
        arr = _json_loads_lenient(arr_part)
        if isinstance(arr, list):
            return {"events": arr}

    return None


def _timeline_json_retry_suffix() -> str:
    return (
        "\n\n[재요청] 방금 응답의 JSON이 깨졌다. 설명·마크다운·코드펜스 없이 "
        '{"events":[]} 또는 events 배열만 포함한 단일 JSON 객체 하나만 다시 출력하라.'
    )


def _timeline_empty_retry_suffix() -> str:
    return (
        "\n\n[재요청] [조서]에 시간 표현(어제, 오후 N시, N시간 동안 등)이 있는데 events가 비었다. "
        "규칙 8·10(알리바이 묶기)에 따라 최소 1개 이벤트를 넣어라. quote는 [조서] 문장을 그대로 복사. "
        "JSON 객체 하나만 출력."
    )


def _fallback_timeline_events_from_text(
    stmt_name: str, stmt_type: str, text: str, reference_date=None,
) -> list:
    """LLM이 빈 events를 줄 때, 본문에 시각이 있으면 규칙 기반 1건 생성."""
    if not text or not _text_has_timeline_clock_signal(text):
        return []
    quote = ""
    for part in re.split(r"(?<=[.!?。])\s*|\n+", text):
        p = part.strip()
        if len(p) >= 8 and _text_has_timeline_clock_signal(p):
            quote = p
            break
    if not quote:
        quote = text[:500].strip()
    clocks = _find_all_korean_clocks_in_text(quote)
    ev = {
        "stmt_name": stmt_name or "미입력",
        "stmt_type": stmt_type or "진술자",
        "event_type": "alibi",
        "time_precision": "approximate",
        "time_start": None,
        "time_end": None,
        "time_text": clocks[0][2] if clocks else "",
        "place": None,
        "label": _excerpt_label_from_quote(quote, 150) or quote[:150],
        "quote": quote[:2000],
        "confidence": "low",
        "sort_order": 10,
    }
    ev = _reconcile_timeline_event_times(ev, reference_date)
    if _event_time_grounded(ev, reference_date):
        print("[timeline] fallback event from source text (LLM returned empty)", flush=True)
        return [ev]
    return []


def transcript_role_hints_by_name(transcripts: list | None) -> dict[str, str]:
    out: dict[str, str] = {}
    if not isinstance(transcripts, list):
        return out
    for tr in transcripts:
        if not isinstance(tr, dict):
            continue
        nm = str(tr.get("name") or "").strip()
        if not nm or _is_placeholder_person_name(nm):
            continue
        key = _compact_person_label(nm).lower()
        r   = _normalize_role(str(tr.get("type") or ""))
        if key not in out:
            out[key] = r
        else:
            out[key] = _stronger_role(out[key], r)
    return out


def merge_relation_persons_same_identity(parsed: dict, transcripts: list | None) -> dict:
    if not isinstance(parsed, dict):
        return parsed
    persons = parsed.get("persons")
    edges   = parsed.get("edges")
    if not isinstance(persons, list) or len(persons) < 2:
        return parsed
    if not isinstance(edges, list):
        edges = []

    plist: list[dict] = []
    for p in persons:
        if not isinstance(p, dict):
            continue
        nm   = str(p.get("name") or "").strip()
        role = _normalize_role(str(p.get("role") or ""))
        plist.append({"name": nm, "role": role, "memo": str(p.get("memo") or "")})

    if len(plist) < 2:
        return parsed

    by_role: dict[str, list[dict]] = {}
    for p in plist:
        by_role.setdefault(p["role"], []).append(p)

    name_map: dict[str, str] = {}

    for role, group in by_role.items():
        names       = [p["name"] for p in group]
        real        = [n for n in names if not _is_placeholder_person_name(n)]
        uniq_real   = list(dict.fromkeys(real))
        pure_titles = [n for n in uniq_real if _is_pure_trade_rep_title(n)]
        with_specific = [n for n in uniq_real if not _is_pure_trade_rep_title(n)]
        trade_titles_only = (
            role in _MERGE_TRADE_REP_ROLES
            and len(uniq_real) > 1
            and len(with_specific) == 0
            and len(pure_titles) >= 2
        )
        trade_title_plus_specific = (
            role in _MERGE_TRADE_REP_ROLES
            and len(pure_titles) >= 1
            and len(with_specific) == 1
            and len(uniq_real) >= 2
        )

        if len(uniq_real) > 1 and not trade_titles_only and not trade_title_plus_specific:
            continue

        hint = _transcript_hint_name_for_role(transcripts or [], role)
        if uniq_real:
            if trade_title_plus_specific:
                canonical = with_specific[0]
            elif trade_titles_only:
                canonical = hint if hint else "거래처 대표"
            else:
                canonical = uniq_real[0]
        elif hint:
            canonical = hint
        else:
            canonical = ROLE_EN_TO_KO.get(role, role)

        for n in names:
            name_map[n] = canonical

    if not name_map:
        return parsed

    def map_nm(n: str) -> str:
        if not n:
            return n
        if n in name_map:
            return name_map[n]
        return name_map.get(n.strip(), n)

    seen_pairs: set[tuple[str, str]] = set()
    new_persons: list[dict] = []
    for p in plist:
        old       = p["name"]
        role      = p["role"]
        canonical = name_map.get(old, name_map.get((old or "").strip(), old))
        key       = (canonical, role)
        if key in seen_pairs:
            continue
        seen_pairs.add(key)
        new_persons.append({"name": canonical, "role": role, "memo": p["memo"]})

    new_edges: list[dict] = []
    seen_e: set[tuple[str, str, str]] = set()
    for e in edges:
        if not isinstance(e, dict):
            continue
        s  = str(e.get("src") or e.get("srcName") or "").strip()
        d  = str(e.get("dst") or e.get("dstName") or "").strip()
        ns = map_nm(s)
        nd = map_nm(d)
        rel = str(e.get("relType") or "acquaint")
        st  = str(e.get("status")  or "unknown")
        ctx = str(e.get("context") or "")
        if not ns or not nd or ns == nd:
            continue
        ek = (ns, nd, rel)
        if ek in seen_e:
            continue
        seen_e.add(ek)
        new_edges.append({"src": ns, "dst": nd, "relType": rel, "status": st, "context": ctx})

    out = dict(parsed)
    out["persons"] = new_persons
    out["edges"]   = new_edges
    return out


def apply_transcript_priority_roles(parsed: dict, transcripts: list | None) -> dict:
    if not isinstance(parsed, dict):
        return parsed
    persons = parsed.get("persons")
    if not isinstance(persons, list):
        return parsed
    hints = transcript_role_hints_by_name(transcripts)
    if not hints:
        out = dict(parsed)
        out["persons"] = list(persons)
        return out
    new_persons: list[dict] = []
    for p in persons:
        if not isinstance(p, dict):
            new_persons.append(p)
            continue
        nm  = str(p.get("name") or "").strip()
        key = _compact_person_label(nm).lower()
        hint = hints.get(key)
        if hint:
            np_ = dict(p)
            np_["role"] = hint
            new_persons.append(np_)
        else:
            new_persons.append(dict(p))
    out = dict(parsed)
    out["persons"] = new_persons
    return out


def collapse_persons_same_name_keep_strongest_role(parsed: dict) -> dict:
    if not isinstance(parsed, dict):
        return parsed
    persons = parsed.get("persons")
    edges   = parsed.get("edges")
    if not isinstance(persons, list):
        return parsed
    if not isinstance(edges, list):
        edges = []

    groups: dict[str, list[dict]] = {}
    order:  list[str] = []
    for p in persons:
        if not isinstance(p, dict):
            continue
        nm  = str(p.get("name") or "").strip()
        if not nm:
            continue
        key = _compact_person_label(nm).lower()
        if key not in groups:
            order.append(key)
            groups[key] = []
        groups[key].append({
            "name": nm,
            "role": _normalize_role(str(p.get("role") or "")),
            "memo": str(p.get("memo") or ""),
        })

    new_persons: list[dict] = []
    compact_to_canonical: dict[str, str] = {}

    for key in order:
        group = groups[key]
        if not group:
            continue
        best = max(group,
                   key=lambda x: (_ROLE_PRIORITY_STRENGTH.get(x["role"], 0), len(x["name"])))
        br      = best["role"]
        winners  = [x for x in group if x["role"] == br]
        canonical = max(winners, key=lambda z: len(z["name"]))["name"].strip()
        memos: list[str] = []
        for x in group:
            t = (x.get("memo") or "").strip()
            if t and t not in memos:
                memos.append(t)
        memo = " / ".join(memos)[:800]
        new_persons.append({"name": canonical, "role": br, "memo": memo})
        compact_to_canonical[key] = canonical

    new_edges: list[dict] = []
    seen_e: set[tuple[str, str, str]] = set()
    for e in edges:
        if not isinstance(e, dict):
            continue
        s, d = _relation_edge_endpoints(e)
        sk = _compact_person_label(s).lower()
        dk = _compact_person_label(d).lower()
        ns  = compact_to_canonical.get(sk, s.strip())
        nd  = compact_to_canonical.get(dk, d.strip())
        rel = str(e.get("relType") or "acquaint")
        st  = str(e.get("status")  or "unknown")
        ctx = str(e.get("context") or "")
        if not ns or not nd or ns == nd:
            continue
        ek = (ns, nd, rel)
        if ek in seen_e:
            continue
        seen_e.add(ek)
        new_edges.append({"src": ns, "dst": nd, "relType": rel, "status": st, "context": ctx})

    out = dict(parsed)
    out["persons"] = new_persons
    out["edges"]   = new_edges
    return out


def sanitize_relation_accomplice_edges(parsed: dict, corpus: str) -> dict:
    if not isinstance(parsed, dict):
        return parsed
    persons = parsed.get("persons")
    edges   = parsed.get("edges")
    if not isinstance(persons, list) or not isinstance(edges, list):
        return parsed
    roles      = _person_role_map(persons)
    corpus_ok  = _corpus_suggests_accomplice(corpus or "")

    def resolve(src: str, dst: str) -> tuple[str, str]:
        return roles.get(src.strip(), ""), roles.get(dst.strip(), "")

    new_edges: list[dict] = []
    for e in edges:
        if not isinstance(e, dict):
            new_edges.append(e)
            continue
        rel_raw = str(e.get("relType") or "")
        if not _edge_rel_is_accomplice(rel_raw):
            new_edges.append(e)
            continue
        s   = str(e.get("src") or e.get("srcName") or "").strip()
        d   = str(e.get("dst") or e.get("dstName") or "").strip()
        st  = str(e.get("status")  or "unknown").strip()
        ra, rb = resolve(s, d)
        pair   = {ra, rb}
        st_low = st.lower()
        new_rel = "accomplice"
        if pair == {"suspect", "victim"}:
            new_rel = "harm"
        elif pair == {"suspect", "suspect"}:
            new_rel = "accomplice"
        elif pair == {"suspect", "reference"} or pair == {"victim", "reference"}:
            new_rel = "witness" if st_low == "mismatch" else ("acquaint" if not corpus_ok else "accomplice")
        elif pair == {"reference", "reference"}:
            new_rel = "acquaint" if not corpus_ok else "accomplice"
        elif "witness" in pair:
            new_rel = "witness" if not corpus_ok else "accomplice"
        else:
            new_rel = "acquaint" if not corpus_ok else "accomplice"
        ne = dict(e)
        ne["relType"] = new_rel
        new_edges.append(ne)

    out = dict(parsed)
    out["edges"] = new_edges
    return out


def ensure_suspect_victim_harm_edges(parsed: dict) -> dict:
    if not isinstance(parsed, dict):
        return parsed
    persons = parsed.get("persons")
    edges   = parsed.get("edges")
    if not isinstance(persons, list) or not isinstance(edges, list):
        return parsed
    roles    = _person_role_map(persons)
    suspects = [n for n, r in roles.items() if r == "suspect"]
    victims  = [n for n, r in roles.items() if r == "victim"]
    if not suspects or not victims:
        out = dict(parsed)
        out["edges"] = list(edges)
        return out

    new_edges: list[dict] = []
    for e in edges:
        if not isinstance(e, dict):
            new_edges.append(e)
            continue
        ne = dict(e)
        s, d = _relation_edge_endpoints(ne)
        ra, rb = roles.get(s, ""), roles.get(d, "")
        if {ra, rb} == {"suspect", "victim"}:
            ne["relType"] = "harm"
        new_edges.append(ne)

    def sv_pair(a: str, b: str) -> frozenset:
        return frozenset({a, b})

    covered: set[frozenset] = set()
    for e in new_edges:
        s, d = _relation_edge_endpoints(e)
        if str(e.get("relType") or "").strip().lower() != "harm":
            continue
        ra, rb = roles.get(s, ""), roles.get(d, "")
        if {ra, rb} == {"suspect", "victim"}:
            covered.add(sv_pair(s, d))

    for s in suspects:
        for v in victims:
            if s == v:
                continue
            pk = sv_pair(s, v)
            if pk in covered:
                continue
            new_edges.append({"src": s, "dst": v, "relType": "harm", "status": "unknown", "context": ""})
            covered.add(pk)

    seen_harm_sv: set[frozenset] = set()
    deduped: list[dict] = []
    for e in new_edges:
        if not isinstance(e, dict):
            deduped.append(e)
            continue
        s, d = _relation_edge_endpoints(e)
        rel  = str(e.get("relType") or "").strip().lower()
        ra, rb = roles.get(s, ""), roles.get(d, "")
        if rel == "harm" and {ra, rb} == {"suspect", "victim"}:
            pk = sv_pair(s, d)
            if pk in seen_harm_sv:
                continue
            seen_harm_sv.add(pk)
        deduped.append(e)

    out = dict(parsed)
    out["edges"] = deduped
    return out


def _rewrite_relation_response(raw: str, transcripts: list | None, transcript_corpus: str = "") -> str:
    data = _extract_json_object(raw)
    if data is None:
        return raw
    try:
        merged = merge_relation_persons_same_identity(data, transcripts)
        merged = apply_transcript_priority_roles(merged, transcripts)
        merged = collapse_persons_same_name_keep_strongest_role(merged)
        merged = sanitize_relation_accomplice_edges(merged, transcript_corpus)
        merged = ensure_suspect_victim_harm_edges(merged)
        return json.dumps(merged, ensure_ascii=False)
    except Exception:
        return raw


# ── 인용 검증 ────────────────────────────────────────────────────────────────

def _ws_compact(text: str) -> str:
    """인용 대조용: 공백 제거."""
    return re.sub(r"\s+", "", text or "")


def fuzzy_in(
    quote: str,
    original: str,
    min_len: int = 6,
    chunk: int = 10,
    *,
    match_ratio: float = 0.5,
    short_pass: bool = True,
) -> bool:
    """
  원문 포함 여부(부분 일치).
  short_pass=False · match_ratio 높이면 타임라인 quote 검증(환각 차단)에 사용.
    """
    quote = (quote or "").strip()
    original = (original or "").strip()
    if not quote or not original:
        return False
    if len(quote) < min_len:
        return short_pass
    no = _ws_compact(original)
    nq = _ws_compact(quote)
    if nq in no:
        return True
    chunks = [nq[i : i + chunk] for i in range(0, len(nq), chunk) if len(nq[i : i + chunk]) >= min_len]
    if not chunks:
        return short_pass
    matched = sum(1 for c in chunks if c in no)
    return (matched / len(chunks)) >= match_ratio


def quote_grounded_in_source(quote: str, source: str) -> bool:
    """
    타임라인 quote가 조서 본문에 근거하는지.
    완전 일치·연속 10자 부분일치·느슨한 fuzzy 순으로 검사(환각 문장은 차단).
    """
    quote = (quote or "").strip()
    source = (source or "").strip()
    if not quote or not source or len(quote) < 6:
        return False
    nq, ns = _ws_compact(quote), _ws_compact(source)
    if nq in ns:
        return True
    anchor = 10
    if len(nq) >= anchor:
        for i in range(0, len(nq) - anchor + 1):
            if nq[i : i + anchor] in ns:
                return True
    ratio = 0.85 if len(quote) < 28 else 0.62
    return fuzzy_in(quote, source, min_len=8, chunk=6, match_ratio=ratio, short_pass=False)


def verify_quotes(contradictions: list, corpus: str) -> list:
    verified = []
    for item in contradictions:
        quote_a = item.get("statement_a", "")
        quote_b = item.get("statement_b", "")
        if fuzzy_in(quote_a, corpus) and fuzzy_in(quote_b, corpus):
            item["verified"] = True
            verified.append(item)
    return verified


def _filter_timeline_grounded_events(events: list, source: str) -> list:
    """quote가 [조서]에 없는 이벤트 제거, label·place 정합."""
    kept: list = []
    for ev in events:
        if not isinstance(ev, dict):
            continue
        quote = (ev.get("quote") or "").strip()
        if not quote:
            continue
        if not quote_grounded_in_source(quote, source):
            print(f"[timeline] dropped ungrounded quote: {quote[:100]}", flush=True)
            continue
        pl = (ev.get("place") or "").strip()
        if pl and _ws_compact(pl) not in _ws_compact(source):
            ev["place"] = None
        lb = (ev.get("label") or "").strip()
        if lb and not fuzzy_in(lb, source, min_len=12, chunk=8, match_ratio=0.55):
            ex = _excerpt_label_from_quote(quote, 150)
            if ex:
                ev["label"] = ex
        kept.append(ev)
    return kept


# ── payload 정규화 ───────────────────────────────────────────────────────────

def _build_labeled_blocks(all_stmts: list) -> str:
    blocks = []
    for i, st in enumerate(all_stmts, 1):
        label = f"[진술 {i}: {st['stmt_type']} {st['stmt_name']}]"
        blocks.append(f"{label}\n{st['original_text']}")
    return "\n\n".join(blocks)


def normalize_analyze_payload(data: dict):
    case_num   = data.get("caseNum", "미입력")
    statements = data.get("statements")

    if isinstance(statements, list) and len(statements) > 0:
        all_stmts = []
        for s in statements:
            if not isinstance(s, dict):
                continue
            ot = (s.get("original_text") or "").strip()
            if not ot:
                continue
            all_stmts.append({
                "stmt_type":     s.get("stmt_type")    or "?",
                "stmt_name":     s.get("stmt_name")    or "?",
                "original_text": ot,
            })
        if not all_stmts:
            return None, "진술 본문이 있는 조서가 없습니다."
        full_body = _build_labeled_blocks(all_stmts)
        n         = len(all_stmts)
        return {
            "n": n, "case_num": case_num,
            "stmt_type": all_stmts[0]["stmt_type"],
            "stmt_name": all_stmts[0]["stmt_name"],
            "full_body": full_body, "corpus": full_body,
            "all_stmts": all_stmts,
        }, None

    text = (data.get("text") or "").strip()
    if not text:
        return None, "진술 텍스트가 없습니다."

    stmt_type       = data.get("stmtType", "진술자")
    stmt_name       = data.get("stmtName", "미입력")
    prev_statements = data.get("prevStatements") or []

    all_stmts = [{"stmt_type": stmt_type, "stmt_name": stmt_name, "original_text": text}]
    for s in prev_statements:
        if not isinstance(s, dict):
            continue
        ot = (s.get("original_text") or "").strip()
        if not ot:
            continue
        all_stmts.append({
            "stmt_type": s.get("stmt_type") or "?",
            "stmt_name": s.get("stmt_name") or "?",
            "original_text": ot,
        })

    full_body = _build_labeled_blocks(all_stmts)
    n         = len(all_stmts)
    return {
        "n": n, "case_num": case_num,
        "stmt_type": stmt_type, "stmt_name": stmt_name,
        "full_body": full_body, "corpus": full_body,
        "all_stmts": all_stmts,
    }, None


# ── analyze SSE 이벤트 스트림 ────────────────────────────────────────────────

def _iter_analyze_events(data):
    try:
        if not data:
            yield {"event": "error", "message": "요청 데이터가 없습니다."}
            return
        payload, err = normalize_analyze_payload(data)
        if err:
            yield {"event": "error", "message": err}
            return

        n         = payload["n"]
        full_body = payload["full_body"]
        corpus    = payload["corpus"]
        case_num  = payload["case_num"]

        yield {"event": "start", "revision": SERVER_REVISION}
        acc1 = []
        for piece in iter_ollama_tokens(_pass1_prompt(case_num, n, full_body)):
            piece = clean_output(piece)
            if not piece:
                continue
            acc1.append(piece)
            yield {"event": "chunk", "text": piece}
        strip_markdown("".join(acc1))

        contradictions: list         = []
        verified_contradictions      = verify_quotes(contradictions, corpus)

        yield {"event": "done", "success": True, "statement_count": n, "revision": SERVER_REVISION}
    except requests.RequestException as ex:
        yield {"event": "error", "message": f"모델 연결 오류: {ex}"}
    except Exception as ex:
        yield {"event": "error", "message": str(ex)}


def _set_job(job_id: str, **kwargs):
    with _ANALYZE_JOBS_LOCK:
        j = _ANALYZE_JOBS.get(job_id)
        if not j:
            return
        j.update(kwargs)


def _run_job(job_id: str, data):
    print(f"[analyze] job {job_id} background thread started", flush=True)
    acc = []
    _set_job(job_id, status="running", text="")
    for ev in _iter_analyze_events(data):
        et = ev.get("event")
        if et == "chunk":
            piece = ev.get("text") or ""
            if piece:
                acc.append(piece)
                _set_job(job_id, text="".join(acc))
        elif et == "done":
            result = "".join(acc)
            _set_job(job_id, status="done", result=result, text=result)
            print(f"[analyze] job {job_id} done (len={len(result)})", flush=True)
            return
        elif et == "error":
            _set_job(job_id, status="error", message=ev.get("message") or "분석 오류")
            print(f"[analyze] job {job_id} error: {ev.get('message')}", flush=True)
            return
    result = "".join(acc)
    _set_job(job_id, status="done", result=result, text=result)
    print(f"[analyze] job {job_id} done (fallback, len={len(result)})", flush=True)


# ════════════════════════════════════════════════════════════════════════════
# [섹션 4] CCTV 번호판 분석 — 유틸리티 함수
# ════════════════════════════════════════════════════════════════════════════

def _preprocess_for_ocr(img_bgr):
    gray     = cv2.cvtColor(img_bgr, cv2.COLOR_BGR2GRAY)
    clahe    = cv2.createCLAHE(clipLimit=2.0, tileGridSize=(8, 8))
    enhanced = clahe.apply(gray)
    _, binary = cv2.threshold(enhanced, 0, 255, cv2.THRESH_BINARY + cv2.THRESH_OTSU)
    resized  = cv2.resize(binary, (ocr_opt.imgW, ocr_opt.imgH), interpolation=cv2.INTER_CUBIC)
    tensor   = torch.FloatTensor(resized).unsqueeze(0).unsqueeze(0) / 255.0
    return tensor.to(OCR_DEVICE)


def _run_plate_ocr(img_bgr) -> str:
    if plate_ocr_model is not None:
        try:
            tensor          = _preprocess_for_ocr(img_bgr)
            length_for_pred = torch.IntTensor([ocr_opt.batch_max_length]).to(OCR_DEVICE)
            text_for_pred   = torch.LongTensor(1, ocr_opt.batch_max_length + 1).fill_(0).to(OCR_DEVICE)
            with torch.no_grad():
                preds = plate_ocr_model(tensor, text_for_pred, is_train=False)

            preds_prob               = F.softmax(preds, dim=2)
            preds_max_prob, preds_index = preds_prob.max(2)
            preds_str = ocr_converter.decode(preds_index, length_for_pred)
            pred      = preds_str[0]

            if '[s]' in pred:
                end_idx    = pred.index('[s]')
                pred       = pred[:end_idx]
                char_probs = preds_max_prob[0, :end_idx]
            else:
                char_probs = preds_max_prob[0]

            if len(char_probs) == 0:
                return ""
            avg_conf = float(char_probs.mean().item())
            if avg_conf < OCR_CONFIDENCE_THRESHOLD:
                return ""

            matches = PLATE_PATTERN.findall(pred)
            return matches[0] if matches else ""
        except Exception:
            pass

    if ocr_reader is not None:
        try:
            gray     = cv2.cvtColor(img_bgr, cv2.COLOR_BGR2GRAY)
            clahe    = cv2.createCLAHE(clipLimit=2.0, tileGridSize=(8, 8))
            enhanced = clahe.apply(gray)
            _, binary = cv2.threshold(enhanced, 0, 255, cv2.THRESH_BINARY + cv2.THRESH_OTSU)
            results  = ocr_reader.readtext(binary, detail=1,
                                           allowlist='0123456789가나다라마바사아자차카타파하')
            texts    = [t for (_, t, c) in results if c > 0.4]
            full_text = "".join(texts)
            matches   = PLATE_PATTERN.findall(full_text)
            return matches[0] if matches else ""
        except Exception:
            pass
    return ""


def analyze_full_frame(frame) -> str:
    try:
        h, w = frame.shape[:2]
        if w > 1280:
            scale = 1280 / w
            frame = cv2.resize(frame, (1280, int(h * scale)), interpolation=cv2.INTER_AREA)
        return _run_plate_ocr(frame)
    except Exception:
        return ""


def analyze_plate(frame, box) -> str:
    x1, y1, x2, y2 = map(int, box)
    pad = 5
    h, w = frame.shape[:2]
    x1 = max(0, x1 - pad);  y1 = max(0, y1 - pad)
    x2 = min(w, x2 + pad);  y2 = min(h, y2 + pad)
    plate_roi = frame[y1:y2, x1:x2]
    if plate_roi is None or plate_roi.size == 0:
        return ""
    try:
        plate_roi = cv2.resize(plate_roi, None, fx=2, fy=2, interpolation=cv2.INTER_CUBIC)
        return _run_plate_ocr(plate_roi)
    except Exception:
        return ""


def plate_matches(input_plate: str, ocr_text: str) -> bool:
    if not input_plate:
        return False
    match = re.match(r'^(\d+)[가-힣](\d+)$', input_plate.strip())
    if match:
        combined = match.group(1) + match.group(2)
        ocr_nums = re.sub(r'[^0-9]', '', ocr_text)
        return combined in ocr_nums
    input_nums = re.sub(r'[^0-9]', '', input_plate)
    ocr_nums   = re.sub(r'[^0-9]', '', ocr_text)
    return bool(input_nums) and input_nums in ocr_nums


def run_cctv_analysis(job_id: str, video_path: str, plate: str):
    try:
        cctv_jobs[job_id]["status"] = "analyzing"
        cap          = cv2.VideoCapture(video_path)
        fps          = cap.get(cv2.CAP_PROP_FPS) or 30
        total_frames = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
        results      = []
        frame_idx    = 0
        skip         = max(1, int(fps * 0.3))

        while cap.isOpened():
            ret, frame = cap.read()
            if not ret:
                break
            if frame_idx % skip == 0:
                timestamp_sec = frame_idx / fps
                mm = int(timestamp_sec // 60)
                ss = int(timestamp_sec % 60)
                timestamp_str = f"{mm:02d}:{ss:02d}"

                detections  = yolo_model(frame, verbose=False)[0]
                valid_boxes = [det for det in detections.boxes if float(det.conf[0]) >= 0.3]

                yolo_found = False
                for det in valid_boxes:
                    plate_text = analyze_plate(frame, det.xyxy[0].tolist())
                    if not plate_text:
                        continue
                    yolo_found = True
                    if plate and not plate_matches(plate, plate_text):
                        continue
                    results.append({
                        "type":      "vehicle",
                        "timestamp": timestamp_str,
                        "plate":     plate_text,
                        "desc":      f"번호판 '{plate_text}' 차량 발견 (YOLO)"
                    })

                if not yolo_found:
                    plate_text = analyze_full_frame(frame)
                    if plate_text and (not plate or plate_matches(plate, plate_text)):
                        results.append({
                            "type":      "vehicle",
                            "timestamp": timestamp_str,
                            "plate":     plate_text,
                            "desc":      f"번호판 '{plate_text}' 차량 발견 (전체프레임)"
                        })

                cctv_jobs[job_id]["progress"] = int((frame_idx / max(total_frames, 1)) * 100)

            frame_idx += 1

        cap.release()
        os.remove(video_path)

        seen: set = set()
        unique_results: list = []
        for r in results:
            key = (r["timestamp"], r.get("plate", r.get("desc", "")))
            if key not in seen:
                seen.add(key)
                unique_results.append(r)

        cctv_jobs[job_id]["status"]   = "done"
        cctv_jobs[job_id]["progress"] = 100
        cctv_jobs[job_id]["results"]  = unique_results

    except Exception as e:
        cctv_jobs[job_id]["status"] = "error"
        cctv_jobs[job_id]["error"]  = str(e)
        if os.path.exists(video_path):
            os.remove(video_path)


# ════════════════════════════════════════════════════════════════════════════
# [섹션 5] Flask 라우트 — 진술 분석 / 관계망
# ════════════════════════════════════════════════════════════════════════════

@app.route("/analyze", methods=["POST"])
def analyze():
    data = request.json
    if not data:
        return jsonify({"success": False, "error": "요청 데이터가 없습니다."}), 400

    payload, err = normalize_analyze_payload(data)
    if err:
        return jsonify({"success": False, "error": err}), 400

    n         = payload["n"]
    full_body = payload["full_body"]
    corpus    = payload["corpus"]
    case_num  = payload["case_num"]

    structured = call_ollama(_pass1_prompt(case_num, n, full_body))

    contradictions: list        = []
    further_checks: list        = []
    verified_contradictions     = verify_quotes(contradictions, corpus)

    if verified_contradictions:
        final_review = call_ollama(_pass3_prompt(corpus, verified_contradictions))
    else:
        final_review = "원문 근거가 확인된 모순 없음."

    return jsonify({
        "success":             True,
        "statement_count":     n,
        "structured_summary":  structured,
        "contradictions":      verified_contradictions,
        "contradiction_count": len(verified_contradictions),
        "further_checks":      further_checks,
        "final_review":        final_review
    })


@app.route("/summarize", methods=["POST"])
def summarize():
    data = request.get_json(force=True, silent=True)
    if not data:
        return jsonify({"success": False, "error": "요청 데이터가 없습니다."}), 400

    payload, err = normalize_analyze_payload(data)
    if err:
        return jsonify({"success": False, "error": err}), 400

    n         = payload["n"]
    full_body = payload["full_body"]
    case_num  = payload["case_num"]

    structured = call_ollama(_pass1_prompt(case_num, n, full_body))

    return jsonify({
        "success":         True,
        "statement_count": n,
        "structured_summary": structured
    })


@app.route("/analyze/start", methods=["POST", "OPTIONS"])
def analyze_start():
    if request.method == "OPTIONS":
        return "", 204
    data   = request.get_json(force=True, silent=True)
    job_id = str(uuid.uuid4())
    with _ANALYZE_JOBS_LOCK:
        _ANALYZE_JOBS[job_id] = {
            "status": "queued", "text": "", "result": "", "message": "",
        }
    t = threading.Thread(target=_run_job, args=(job_id, data), daemon=True)
    t.start()
    return jsonify({"success": True, "jobId": job_id})


@app.route("/analyze/job/<job_id>", methods=["GET"])
def analyze_job(job_id):
    with _ANALYZE_JOBS_LOCK:
        j = _ANALYZE_JOBS.get(job_id)
    if not j:
        return jsonify({"success": False, "error": "unknown job"}), 404
    out = {"success": True, "status": j.get("status", "queued"), "text": j.get("text", "")}
    if out["status"] == "done":
        out["result"] = j.get("result", "") or out["text"]
    if out["status"] == "error":
        out["message"] = j.get("message", "분석 오류")
    return jsonify(out)


@app.route("/analyze/stream", methods=["POST"])
def analyze_stream():
    data = request.get_json(force=True, silent=True)

    def generate():
        for ev in _iter_analyze_events(data):
            yield _sse_line(ev)

    return Response(
        stream_with_context(generate()),
        mimetype="text/event-stream",
        headers={
            "Cache-Control":    "no-cache",
            "Connection":       "keep-alive",
            "X-Accel-Buffering": "no",
        },
    )


@app.route("/relation_map", methods=["POST", "OPTIONS"])
def relation_map():
    if request.method == "OPTIONS":
        return "", 204

    data = request.get_json(force=True, silent=True)
    if not data:
        return jsonify({"success": False, "error": "요청 데이터가 없습니다.", "response": ""}), 400

    case_id    = (data.get("caseId")    or data.get("case_id")   or "").strip()
    case_name  = (data.get("caseName")  or data.get("case_name") or "").strip()
    transcripts = data.get("transcripts")
    if not isinstance(transcripts, list) or len(transcripts) < 1:
        return jsonify({"success": False,
                        "error": "transcripts 배열이 1개 이상 필요합니다.", "response": ""}), 400

    blocks:     list[str] = []
    meta_parts: list[str] = []
    ord_num = 0
    for tr in transcripts:
        if not isinstance(tr, dict):
            continue
        name = str(tr.get("name") or "").strip()
        typ  = str(tr.get("type") or "").strip()
        text = (tr.get("text") or "").strip()
        meta_parts.append(f"{name}({typ})")
        body = text if text else "(원문 없음 — 진술자 정보만 존재)"
        ord_num += 1
        blocks.append(f"[조서 {ord_num}] 진술자: {name} ({typ})\n{body}")

    if not blocks:
        return jsonify({"success": False,
                        "error": "유효한 조서 항목이 없습니다.", "response": ""}), 400

    transcript_block = "\n\n---\n\n".join(blocks)
    persons_meta     = ", ".join(meta_parts)
    prompt = _relation_map_prompt(case_id, case_name, persons_meta, transcript_block)

    try:
        raw = call_ollama(prompt, expect_json=False)
    except Exception as ex:
        return jsonify({"success": False, "error": f"모델 호출 실패: {ex}", "response": ""}), 502

    if not (raw or "").strip():
        return jsonify({"success": False,
                        "error": "모델이 빈 응답을 반환했습니다.", "response": ""}), 502

    out_raw = _rewrite_relation_response(raw, transcripts, transcript_block)
    return jsonify({"success": True, "response": out_raw, "model": MODEL})


@app.route("/timeline/extract", methods=["POST", "OPTIONS"])
def timeline_extract():
    if request.method == "OPTIONS":
        return "", 204

    data = request.get_json(force=True, silent=True)
    if not data:
        return jsonify({"success": False, "error": "요청 데이터가 없습니다.", "events": []}), 400

    case_id   = (data.get("caseId") or data.get("case_id") or "").strip()
    stmt_name = (data.get("stmtName") or data.get("stmt_name") or "미입력").strip()
    stmt_type = (data.get("stmtType") or data.get("stmt_type") or "진술자").strip()
    text      = _truncate_timeline_text((data.get("text") or "").strip())

    if not text:
        return jsonify({"success": False, "error": "조서 본문이 비어 있습니다.", "events": []}), 400

    reference_date = _parse_reference_date_from_request(data)
    prompt = _timeline_extract_prompt(case_id, stmt_name, stmt_type, text, reference_date)
    try:
        raw = call_ollama_timeline(prompt)
    except Exception as ex:
        return jsonify({"success": False, "error": f"모델 호출 실패: {ex}", "events": []}), 502

    if not (raw or "").strip():
        return jsonify({"success": False, "error": "모델이 빈 응답을 반환했습니다.", "events": []}), 502

    parsed = _extract_timeline_payload(raw)
    if not parsed:
        try:
            raw = call_ollama_timeline(prompt + _timeline_json_retry_suffix())
        except Exception:
            raw = ""
        parsed = _extract_timeline_payload(raw or "")

    if not parsed or not isinstance(parsed.get("events"), list):
        snippet = (raw or "")[:280].replace("\n", " ")
        return jsonify({
            "success": False,
            "error": "이벤트 JSON 파싱 실패",
            "detail": f"모델 출력을 JSON으로 읽지 못했습니다. {snippet}",
            "events": [],
        }), 502

    raw_n = len(parsed.get("events") or [])
    if raw_n == 0 and _text_has_timeline_clock_signal(text):
        try:
            raw2 = call_ollama_timeline(prompt + _timeline_empty_retry_suffix())
            parsed2 = _extract_timeline_payload(raw2 or "")
            if parsed2 and isinstance(parsed2.get("events"), list) and parsed2["events"]:
                parsed, raw = parsed2, raw2
                raw_n = len(parsed["events"])
                print(f"[timeline] empty retry got {raw_n} events", flush=True)
        except Exception as ex:
            print(f"[timeline] empty retry failed: {ex}", flush=True)
    if raw_n == 0:
        fallback = _fallback_timeline_events_from_text(stmt_name, stmt_type, text, reference_date)
        if fallback:
            parsed = {"events": fallback}
            raw_n = len(fallback)
    if raw_n == 0:
        snippet = (raw or "")[:320].replace("\n", " ")
        print(
            f"[timeline] LLM empty events stmt={stmt_name!r} text_len={len(text)} "
            f"has_clock={_text_has_timeline_clock_signal(text)} out={snippet!r}",
            flush=True,
        )

    events = [_normalize_timeline_event_fields(e) for e in parsed["events"] if isinstance(e, dict)]
    events = _filter_timeline_grounded_events(events, text)
    after_ground = len(events)
    events = _reconcile_timeline_events_from_quotes(events, reference_date)
    events = _sanitize_all_event_times(events, reference_date)
    events = _resolve_relative_durations_from_text(events)
    events = _apply_activity_duration_end(events)
    events = _merge_same_period_alibi_blocks(events)
    events = _inherit_same_time_context(events)
    events = _sanitize_all_event_times(events, reference_date)
    events = _filter_timeline_time_only(events, reference_date)
    print(
        f"[timeline] extract stmt={stmt_name!r} raw={raw_n} grounded={after_ground} "
        f"time_ok={len(events)} ref={reference_date}",
        flush=True,
    )
    return jsonify({"success": True, "events": events, "model": MODEL})


# ════════════════════════════════════════════════════════════════════════════
# [섹션 6-A] Flask 라우트 — 유사 사건 추천
# ════════════════════════════════════════════════════════════════════════════

@app.route("/similar_cases", methods=["POST", "OPTIONS"])
def similar_cases():
    if request.method == "OPTIONS":
        return "", 204

    data = request.get_json(force=True, silent=True)
    if not data:
        return jsonify({"success": False, "error": "요청 데이터가 없습니다."}), 400

    current    = data.get("current") or {}
    candidates = data.get("candidates") or []

    case_name = (current.get("caseName") or "").strip()
    charge    = (current.get("charge")   or "").strip()
    summary   = (current.get("summary")  or "").strip()

    if not candidates:
        return jsonify({"success": True, "similar": []})

    cand_lines = []
    for i, c in enumerate(candidates[:20], 1):
        cid   = c.get("caseId",   "")
        cname = c.get("caseName", "")
        cchg  = c.get("charge",   "")
        csum  = (c.get("summary") or "")[:200]
        cand_lines.append(
            f"{i}. [사건ID:{cid}] 사건명:{cname} / 혐의:{cchg} / 요약:{csum}"
        )

    cand_block = "\n".join(cand_lines)

    prompt = f"""당신은 형사사건 수사 AI 어시스턴트입니다. {NO_MARKDOWN}

[현재 사건]
사건명: {case_name}
혐의: {charge}
요약: {summary}

[비교 대상 사건 목록]
{cand_block}

위 비교 대상 목록에서 현재 사건과 가장 유사한 사건 최대 3건을 선택하고, 반드시 아래 JSON 형식으로만 답하세요.
유사도가 낮아 추천할 사건이 없으면 similar 배열을 비워 주세요.

출력 형식 (JSON만, 설명 없이):
{{"similar": [{{"caseId": "사건ID", "caseName": "사건명", "charge": "혐의", "reason": "유사한 이유 1~2문장"}}]}}"""

    try:
        raw = call_ollama(prompt, expect_json=True)
    except Exception as ex:
        return jsonify({"success": False, "error": f"모델 호출 실패: {ex}"}), 502

    if not raw:
        return jsonify({"success": True, "similar": []})

    try:
        parsed = json.loads(raw) if isinstance(raw, str) else raw
        similar = parsed.get("similar", []) if isinstance(parsed, dict) else []
    except Exception:
        similar = []

    return jsonify({"success": True, "similar": similar, "model": MODEL})


# ════════════════════════════════════════════════════════════════════════════
# [섹션 6] Flask 라우트 — CCTV 번호판 분석
# ════════════════════════════════════════════════════════════════════════════

@app.route("/cctv/analyze", methods=["POST"])
def cctv_analyze():
    if "video" not in request.files:
        return jsonify({"success": False, "error": "영상 파일이 없습니다."}), 400
    video_file = request.files["video"]
    plate      = request.form.get("plate", "").strip()

    suffix = os.path.splitext(video_file.filename)[1] or ".mp4"
    tmp    = tempfile.NamedTemporaryFile(delete=False, suffix=suffix)
    video_file.save(tmp.name)
    tmp.close()

    job_id = str(uuid.uuid4())
    cctv_jobs[job_id] = {"status": "queued", "progress": 0, "results": [], "error": None}
    t = threading.Thread(target=run_cctv_analysis, args=(job_id, tmp.name, plate))
    t.daemon = True
    t.start()
    return jsonify({"success": True, "jobId": job_id})


@app.route("/cctv/status/<job_id>", methods=["GET"])
def cctv_status(job_id):
    job = cctv_jobs.get(job_id)
    if not job:
        return jsonify({"success": False, "error": "존재하지 않는 작업입니다."}), 404
    return jsonify({
        "success":  True,
        "status":   job["status"],
        "progress": job["progress"],
        "results":  job["results"],
        "error":    job["error"],
    })


# ════════════════════════════════════════════════════════════════════════════
# [섹션 7] 공통 라우트
# ════════════════════════════════════════════════════════════════════════════

@app.route("/score/reliability", methods=["POST"])
def score_reliability():
    data = request.get_json(force=True, silent=True)
    if not data:
        return jsonify({"success": False, "error": "요청 데이터가 없습니다."}), 400
    text = (data.get("text") or "").strip()
    if not text:
        return jsonify({"success": False, "error": "진술 내용이 없습니다."}), 400
    stmt_name = (data.get("stmtName") or "미입력").strip()
    stmt_type = (data.get("stmtType") or "진술자").strip()
    prompt = _score_reliability_prompt(stmt_name, stmt_type, text)
    try:
        raw = call_ollama(prompt, expect_json=True)
    except Exception as ex:
        return jsonify({"success": False, "error": f"모델 호출 실패: {ex}"}), 502
    parsed = _extract_json_object(raw)
    if not parsed:
        return jsonify({"success": False, "error": "모델 응답 파싱 실패"}), 502

    def clamp(v):
        try:
            return max(0, min(100, int(v)))
        except Exception:
            return 50

    consistency = clamp(parsed.get("consistency", 50))
    specificity = clamp(parsed.get("specificity", 50))
    emotion     = clamp(parsed.get("emotion",     50))
    temporal    = clamp(parsed.get("temporal",    50))
    total       = (consistency + specificity + emotion + temporal) // 4
    reasons = parsed.get("reasons") or {}
    if not isinstance(reasons, dict):
        reasons = {}
    return jsonify({
        "success":     True,
        "consistency": consistency,
        "specificity": specificity,
        "emotion":     emotion,
        "temporal":    temporal,
        "total":       total,
        "reasons": {
            "consistency": str(reasons.get("consistency") or ""),
            "specificity": str(reasons.get("specificity") or ""),
            "emotion":     str(reasons.get("emotion")     or ""),
            "temporal":    str(reasons.get("temporal")    or ""),
        }
    })


@app.route("/health", methods=["GET"])
def health():
    return jsonify({"status": "ok", "model": MODEL, "revision": SERVER_REVISION})


# ════════════════════════════════════════════════════════════════════════════
# [섹션 8] 감정 흐름 분석 (개선 v2)
# ════════════════════════════════════════════════════════════════════════════
#
# 변경 내역
# ─────────────────────────────────────────────────────────────────────────
# [문제 1] 긍/부정 2분류 모델을 4감정에 억지 매핑 → neg 하나로 불안/회피/분노가
#          동시에 움직여 그래프 평탄화 발생
#          → 다감정 분류 모델 우선 로드, 4감정 직접 매핑으로 교체
#
# [문제 2] 키워드 fallback에서 매칭 없으면 모든 감정이 base=20.0 고착
#          → 문장 길이·부정어·어미·문맥을 반영한 가중 키워드 스코어로 교체
#          → 확신 하드코딩(max 30.0) 제거, 진술 특성 기반 동적 베이스라인 적용
#
# [문제 3] 변화율이 낮을 때 하이라이트가 거의 안 잡힘
#          → z-score 기반 + 절대값 하한선 병행, 최소 1구간 보장 옵션 추가
# ─────────────────────────────────────────────────────────────────────────

import math
import re

# ── 다감정 모델 로드 (우선순위 순) ──────────────────────────────────────────
#
# 우선순위 기준:
#   1. snunlp/KR-ELECTRA-discriminator-finetuned  - 한국어 7감정 분류
#   2. hun3359/klue-bert-base-sentiment            - 7감정 (기쁨/슬픔/놀람/분노/혐오/두려움/중립)
#   3. monologg/koelectra-base-finetuned-sentiment - 긍/부정 (최후 수단)
#
# 로드 실패 시 키워드 방식으로 자동 fallback

_EMOTION_PIPELINE   = None
_PIPELINE_LABEL_MAP = None   # 모델별 레이블 → 4감정 매핑 테이블

# ── 모델별 레이블 매핑 정의 ───────────────────────────────────────────────────
#
# 각 모델이 반환하는 레이블을 (불안, 확신, 회피, 분노) 가중치로 변환
# 가중치 합이 1.0일 필요 없음 — 이후 정규화 없이 직접 점수로 사용
_LABEL_MAPS = {
    # hun3359/klue-bert-base-sentiment : 7감정
    "hun3359/klue-bert-base-sentiment": {
        "기쁨":  {"불안": 0.00, "확신": 0.70, "회피": 0.00, "분노": 0.00},
        "슬픔":  {"불안": 0.55, "확신": 0.10, "회피": 0.35, "분노": 0.10},
        "놀람":  {"불안": 0.40, "확신": 0.10, "회피": 0.20, "분노": 0.10},
        "분노":  {"불안": 0.20, "확신": 0.20, "회피": 0.10, "분노": 0.70},
        "혐오":  {"불안": 0.10, "확신": 0.15, "회피": 0.30, "분노": 0.50},
        "두려움":{"불안": 0.70, "확신": 0.05, "회피": 0.40, "분노": 0.05},
        "중립":  {"불안": 0.10, "확신": 0.40, "회피": 0.10, "분노": 0.05},
    },
    # snunlp/KR-ELECTRA — 레이블이 동일한 7감정 체계로 확인된 경우 동일 맵 사용
    "snunlp/KR-ELECTRA-discriminator-finetuned": {
        "기쁨":  {"불안": 0.00, "확신": 0.70, "회피": 0.00, "분노": 0.00},
        "슬픔":  {"불안": 0.55, "확신": 0.10, "회피": 0.35, "분노": 0.10},
        "놀람":  {"불안": 0.40, "확신": 0.10, "회피": 0.20, "분노": 0.10},
        "분노":  {"불안": 0.20, "확신": 0.20, "회피": 0.10, "분노": 0.70},
        "혐오":  {"불안": 0.10, "확신": 0.15, "회피": 0.30, "분노": 0.50},
        "두려움":{"불안": 0.70, "확신": 0.05, "회피": 0.40, "분노": 0.05},
        "중립":  {"불안": 0.10, "확신": 0.40, "회피": 0.10, "분노": 0.05},
    },
    # monologg/koelectra — 긍/부정 2분류 (최후 수단, 개선된 매핑 사용)
    "__binary__": {
        "positive": {"불안": 0.05, "확신": 0.65, "회피": 0.05, "분노": 0.05},
        "negative": {"불안": 0.50, "확신": 0.10, "회피": 0.35, "분노": 0.40},
        # 별칭
        "pos":      {"불안": 0.05, "확신": 0.65, "회피": 0.05, "분노": 0.05},
        "neg":      {"불안": 0.50, "확신": 0.10, "회피": 0.35, "분노": 0.40},
        "1":        {"불안": 0.05, "확신": 0.65, "회피": 0.05, "분노": 0.05},
        "0":        {"불안": 0.50, "확신": 0.10, "회피": 0.35, "분노": 0.40},
    },
}


def _try_load_emotion_model():
    global _EMOTION_PIPELINE, _PIPELINE_LABEL_MAP

    # 1순위: fine-tuned 모델 로드 시도
    import sys, os
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    try:
        from emotion_model_loader import load_finetuned_emotion_model, predict_finetuned
        if load_finetuned_emotion_model("./emotion_model"):
            print("[감정분석] fine-tuned 모델 로드 성공!")
            return True
    except Exception as e:
        print(f"[감정분석] fine-tuned 모델 로드 실패: {e}")

    # 2순위: hun3359 다감정 모델
    try:
        from transformers import pipeline
        _EMOTION_PIPELINE = pipeline(
            "text-classification",
            model="hun3359/klue-bert-base-sentiment",
            tokenizer="hun3359/klue-bert-base-sentiment",
            device=-1,
            top_k=None,
        )
        _PIPELINE_LABEL_MAP = _LABEL_MAPS.get("hun3359/klue-bert-base-sentiment")
        print("[감정분석] hun3359 모델 로드 (fallback)")
        return True
    except Exception as e:
        print(f"[감정분석] 모든 모델 로드 실패 → 키워드 방식으로 실행: {e}")
        return False


import threading as _threading
_emotion_model_thread = _threading.Thread(target=_try_load_emotion_model, daemon=True)
_emotion_model_thread.start()


# ── 개선된 키워드 사전 ──────────────────────────────────────────────────────
# 각 항목: (키워드, 가중치)
# 가중치 기준: 감정 강도가 높을수록 높게 설정 (1.0 = 기본, 2.0 = 강한 표현)

_ANXIETY_KW = [
    ("모르겠", 1.0), ("걱정", 1.2), ("두렵", 1.5), ("불안", 1.5),
    ("무서", 1.5), ("긴장", 1.2), ("어려워", 0.8), ("힘들", 0.8),
    ("혹시", 0.7), ("당황", 1.3), ("떨렸", 1.4), ("겁이", 1.4),
    ("공포", 2.0), ("떨려", 1.3), ("망설", 1.0), ("주저", 1.0),
    ("못할 것 같", 1.1), ("불편", 0.8), ("두근", 1.2), ("어쩌지", 1.1),
    ("무서운지", 1.5), ("어떡해", 1.2), ("두려움", 1.5), ("겁났", 1.4),
    ("조마조마", 1.6), ("초조", 1.4), ("안절부절", 1.6),
]

_CERTAINTY_KW = [
    ("확실히", 1.8), ("분명히", 1.8), ("절대로", 1.6), ("틀림없이", 1.8),
    ("반드시", 1.4), ("확신", 1.8), ("단연코", 2.0), ("맞습니다", 1.2),
    ("그렇습니다", 1.0), ("확실합니다", 1.8), ("분명합니다", 1.8),
    ("절대", 1.4), ("정확히", 1.4), ("명백히", 1.8), ("명확히", 1.8),
    ("틀림없", 1.8), ("했습니다", 0.5), ("있습니다", 0.4), ("없습니다", 0.6),
    ("이었습니다", 0.5), ("확실한", 1.6), ("분명한", 1.6), ("확실하게", 1.6),
    ("분명하게", 1.6), ("제가 봤", 1.4), ("제가 들었", 1.4),
    ("저는 알고", 1.3), ("알고 있습니다", 1.3),
]

_AVOIDANCE_KW = [
    ("기억이 잘", 1.4), ("잘 모르", 1.2), ("그냥", 0.6), ("아마", 0.9),
    ("것 같아", 0.8), ("생각이 안", 1.4), ("기억나지", 1.5),
    ("확실하지 않", 1.4), ("정확히는", 1.0), ("어떻게 말", 1.0),
    ("정확히 기억", 1.4), ("모르겠어요", 1.2), ("기억이 없", 1.5),
    ("생각이 나지", 1.5), ("정확하지", 1.2), ("흐릿", 1.4),
    ("기억이 나지 않", 1.8), ("말씀드리기", 0.8), ("뭐라 해야", 1.1),
    ("기억이 희미", 1.6), ("잘 기억이", 1.4), ("가물가물", 1.8),
    ("잘 모르겠", 1.3), ("확실히는 모르", 1.5), ("말하기 어렵", 1.2),
    ("뭐라고 해야", 1.1), ("어디서부터", 0.9), ("뭐랄까", 1.0),
]

_ANGER_KW = [
    ("화가", 1.6), ("짜증", 1.4), ("억울", 1.8), ("부당", 1.6),
    ("말도 안", 1.4), ("화났", 1.6), ("어이없", 1.4), ("황당", 1.3),
    ("터무니없", 1.6), ("이해가 안", 1.0), ("도저히", 1.2),
    ("진짜로", 0.9), ("어떻게 그런", 1.3), ("용납할 수", 1.6),
    ("분통", 1.8), ("열받", 1.6), ("분개", 1.8), ("격분", 2.0),
    ("분노", 1.8), ("화가 많이", 1.8), ("너무 화", 1.6),
    ("억울해", 1.8), ("부당해", 1.6), ("울분", 1.8), ("분하다", 1.7),
    ("어처구니", 1.5), ("기가 막", 1.5), ("황당하다", 1.4),
]


def _kw_score_weighted(text: str, keywords: list) -> float:
    """가중치 적용 키워드 스코어. 길이 보너스 포함."""
    text_lower = text.lower()
    score = 0.0
    for kw, weight in keywords:
        if kw in text_lower:
            score += weight
    return score


def _sentence_baseline(text: str) -> dict:
    """
    문장 특성 기반 동적 베이스라인.
    진술서 특성상 사실 서술이 많으면 확신 기본값이 높고,
    짧은 문장은 정보가 적어 모든 감정이 낮게 시작.
    """
    length = len(text)

    # 길이 기반 스케일 (짧은 문장은 감정 표현이 적음)
    if length < 15:
        length_factor = 0.6
    elif length < 30:
        length_factor = 0.8
    else:
        length_factor = 1.0

    # 서술형 어미 → 확신 베이스라인 상향
    declarative_endings = ["습니다", "했습니다", "였습니다", "입니다", "다고 합니다"]
    is_declarative = any(text.endswith(e) or e in text[-10:] for e in declarative_endings)

    # 의문형 어미 → 회피/불안 베이스라인 상향
    interrogative = text.strip().endswith("?") or text.strip().endswith("요?")

    base_anxiety   = 15.0 * length_factor
    base_certainty = (28.0 if is_declarative else 18.0) * length_factor
    base_avoidance = (18.0 if interrogative else 12.0) * length_factor
    base_anger     = 10.0 * length_factor

    return {
        "불안": base_anxiety,
        "확신": base_certainty,
        "회피": base_avoidance,
        "분노": base_anger,
    }


def _sentence_emotion_by_keyword(sentence: str) -> dict:
    """개선된 키워드 기반 감정 점수 산출."""
    baseline = _sentence_baseline(sentence)
    scale = 18.0  # 키워드 1점당 점수 증가량 (기존 35.0 → 낮춰서 과도한 상승 방지)

    raw = {
        "불안": _kw_score_weighted(sentence, _ANXIETY_KW),
        "확신": _kw_score_weighted(sentence, _CERTAINTY_KW),
        "회피": _kw_score_weighted(sentence, _AVOIDANCE_KW),
        "분노": _kw_score_weighted(sentence, _ANGER_KW),
    }

    result = {}
    for k in ["불안", "확신", "회피", "분노"]:
        score = baseline[k] + raw[k] * scale
        result[k] = round(min(95.0, score), 1)

    # 상호 억제: 확신이 높으면 회피/불안을 낮춤 (진술서 특성)
    if result["확신"] > 60:
        suppression = (result["확신"] - 60) * 0.3
        result["불안"]  = max(baseline["불안"],  result["불안"]  - suppression)
        result["회피"] = max(baseline["회피"], result["회피"] - suppression)

    # 분노가 높으면 확신도 약간 상승 (강한 주장 특성)
    if result["분노"] > 50:
        result["확신"] = min(95.0, result["확신"] + (result["분노"] - 50) * 0.2)

    return {k: round(v, 1) for k, v in result.items()}


def _sentence_emotion_by_model(sentence: str) -> dict | None:
    """
    로드된 모델로 감정 점수 산출.
    모델 출력 레이블 → 4감정 매핑 테이블 사용.
    키워드 스코어를 보조 신호로 블렌딩.
    """
    # fine-tuned 모델 우선 시도
    try:
        from emotion_model_loader import predict_finetuned
        result = predict_finetuned(sentence)
        if result:
            return result
    except Exception:
        pass

    # 기존 방식 (hun3359 fallback)
    if _EMOTION_PIPELINE is None or _PIPELINE_LABEL_MAP is None:
        return None
    try:
        raw_out = _EMOTION_PIPELINE(sentence[:512], truncation=True)
        if not raw_out:
            return None

        # pipeline 출력 정규화: [[{label, score}, ...]] 또는 [{label, score}, ...]
        items = raw_out[0] if isinstance(raw_out[0], list) else raw_out

        # 레이블별 점수 합산 → 4감정 기여값 계산
        emotion_raw = {"불안": 0.0, "확신": 0.0, "회피": 0.0, "분노": 0.0}
        total_mapped = 0.0
        for item in items:
            label = item["label"].lower().strip()
            score = float(item["score"])

            # 레이블 매핑 탐색 (정확 일치 → 부분 일치)
            mapping = _PIPELINE_LABEL_MAP.get(label)
            if mapping is None:
                # 한글 레이블 직접 탐색
                for map_label, map_val in _PIPELINE_LABEL_MAP.items():
                    if map_label in label or label in map_label:
                        mapping = map_val
                        break
            if mapping is None:
                continue

            for emo, weight in mapping.items():
                emotion_raw[emo] += score * weight
            total_mapped += score

        if total_mapped < 0.01:
            return None

        # 감정별 최대값 기준으로 정규화 후 스케일링
        max_val = max(emotion_raw.values()) if emotion_raw else 1.0
        if max_val < 0.01:
            return None

        # 최대 감정을 70~90 범위로 끌어올리는 동적 스케일
        dynamic_scale = 80.0 / max_val
        model_scores = {k: round(min(95.0, v * dynamic_scale), 1) for k, v in emotion_raw.items()}

        # 키워드 보정: 모델 점수 40% + 키워드 60% 블렌딩
        kw_scores = _sentence_emotion_by_keyword(sentence)
        blended = {}
        for emo in ["불안", "확신", "회피", "분노"]:
            blended[emo] = round(model_scores[emo] * 0.40 + kw_scores[emo] * 0.60, 1)

        return blended

    except Exception as e:
        print(f"[감정분석] 모델 추론 오류: {e}")
        return None


# ── 문장 분리 ────────────────────────────────────────────────────────────────

def _split_korean_sentences(text: str) -> list:
    """
    한국어 진술서 문장 분리.
    마침표·물음표·느낌표 + 최소 길이 조건.
    너무 짧은 조각은 다음 문장에 합침.
    """
    text = re.sub(r'\s+', ' ', text.strip())

    # 분리 기준: 문장 종결 어미 패턴
    split_pattern = re.compile(
        r'(?<=[.!?])\s+'
        r'|(?<=습니다\.)\s+'
        r'|(?<=습니다\?)\s+'
        r'|(?<=습니다!)\s+'
        r'|(?<=했습니다\.)\s+'
        r'|(?<=있습니다\.)\s+'
        r'|(?<=없습니다\.)\s+'
        r'|(?<=입니다\.)\s+'
        r'|(?<=겠습니다\.)\s+'
    )
    raw = split_pattern.split(text)

    sentences = []
    buf = ""
    for part in raw:
        part = part.strip()
        if not part:
            continue
        buf = (buf + " " + part).strip() if buf else part
        # 최소 10자 이상이어야 독립 문장으로 처리
        if len(buf) >= 10:
            sentences.append(buf)
            buf = ""
    # 남은 버퍼 처리
    if buf:
        if sentences and len(buf) < 8:
            sentences[-1] = sentences[-1] + " " + buf
        else:
            sentences.append(buf)

    sentences = [s.strip() for s in sentences if s.strip()]
    return sentences if sentences else [text]


# ── 변화율 및 하이라이트 ─────────────────────────────────────────────────────

def _compute_change_rate(emotions_list: list) -> list:
    """연속 문장 간 4감정 평균 변화량."""
    if len(emotions_list) < 2:
        return [0.0] * len(emotions_list)
    rates = [0.0]
    for i in range(1, len(emotions_list)):
        a, b = emotions_list[i - 1], emotions_list[i]
        diff = sum(abs(b[k] - a[k]) for k in ["불안", "확신", "회피", "분노"]) / 4.0
        rates.append(round(diff, 2))
    return rates


def _detect_highlights(rates: list, threshold_factor: float = 1.2, abs_min: float = 5.0) -> list:
    """
    변화율 기반 하이라이트 구간 탐지 (개선).

    기존 문제: threshold_factor=1.4 + 전체 변화가 작으면 아무것도 안 잡힘
    개선:
    - threshold_factor를 1.2로 낮춤 (더 민감하게)
    - 절대값 하한선 abs_min 추가: 변화율이 낮아도 상대적으로 높은 구간은 탐지
    - 전체 변화량이 매우 작은 경우(평탄한 진술) 최대 변화 구간 1개 강제 반환
    """
    if len(rates) < 2:
        return []

    non_zero = [r for r in rates if r > 0]
    if not non_zero:
        return []

    mu    = sum(rates) / len(rates)
    sigma = math.sqrt(sum((r - mu) ** 2 for r in rates) / len(rates))

    # 변화량이 전반적으로 작은 경우 (sigma < 2.0): 최대값 구간 1개 강제 반환
    if sigma < 2.0:
        max_idx = rates.index(max(rates))
        if rates[max_idx] > 0:
            return [{
                "start":     max(0, max_idx - 1),
                "end":       max_idx,
                "maxChange": round(rates[max_idx], 2),
            }]
        return []

    threshold = max(mu + threshold_factor * sigma, abs_min)
    highlights = []
    i = 0
    while i < len(rates):
        if rates[i] >= threshold:
            start = max(0, i - 1)
            end   = i
            while end + 1 < len(rates) and rates[end + 1] >= threshold:
                end += 1
            highlights.append({
                "start":     start,
                "end":       end,
                "maxChange": round(max(rates[start:end + 1]), 2),
            })
            i = end + 1
        else:
            i += 1
    return highlights


# ── Flask 엔드포인트 ─────────────────────────────────────────────────────────

@app.route("/emotion/analyze", methods=["POST"])
def emotion_analyze():
    data = request.get_json(force=True, silent=True) or {}
    text = (data.get("text") or "").strip()
    if not text:
        return jsonify({"success": False, "error": "진술 내용이 없습니다."}), 400

    sentences = _split_korean_sentences(text)

    results = []
    for sent in sentences:
        emotions = _sentence_emotion_by_model(sent) or _sentence_emotion_by_keyword(sent)
        results.append({"text": sent, "emotions": emotions})

    emotions_list = [r["emotions"] for r in results]
    rates         = _compute_change_rate(emotions_list)
    highlights    = _detect_highlights(rates)

    output = []
    for i, r in enumerate(results):
        output.append({
            "index":      i,
            "text":       r["text"],
            "불안":        r["emotions"]["불안"],
            "확신":        r["emotions"]["확신"],
            "회피":        r["emotions"]["회피"],
            "분노":        r["emotions"]["분노"],
            "changeRate": rates[i],
        })

    # 사용 중인 추론 방식 기록
    if _EMOTION_PIPELINE is not None:
        model_label = "multi-emotion+keyword-blend"
    else:
        model_label = "keyword-weighted"

    return jsonify({
        "success":    True,
        "sentences":  output,
        "highlights": highlights,
        "model":      model_label,
        "total":      len(output),
    })
# ════════════════════════════════════════════════════════════════════════════
if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5001, debug=False, threaded=True)