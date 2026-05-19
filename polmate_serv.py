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
MODEL      = os.environ.get("OLLAMA_MODEL", "exaone3.5:2.4b")

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


def call_ollama(prompt: str, expect_json: bool = False) -> str:
    for attempt in range(3):
        try:
            res = requests.post(OLLAMA_URL, json={
                "model":   MODEL,
                "prompt":  prompt,
                "stream":  False,
                "options": {"temperature": 0.1, "repeat_penalty": 1.0}
            }, timeout=300)
            text = res.json().get("response", "")
            if not expect_json:
                return strip_markdown(text)
            match = re.search(r'\{[\s\S]*\}', text)
            if match:
                return match.group(0)
        except Exception as e:
            if attempt == 2:
                raise e
    return ""


TIMELINE_MAX_TEXT = int(os.environ.get("TIMELINE_MAX_TEXT", "9000"))
TIMELINE_NUM_PREDICT = int(os.environ.get("TIMELINE_NUM_PREDICT", "3072"))
TIMELINE_OLLAMA_TIMEOUT = int(os.environ.get("TIMELINE_OLLAMA_TIMEOUT", "180"))


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


def call_ollama_timeline(prompt: str) -> str:
    """타임라인 전용: 출력 토큰 상한·짧은 타임아웃으로 속도 우선."""
    opts = {
        "temperature": 0.05,
        "repeat_penalty": 1.0,
        "num_predict": TIMELINE_NUM_PREDICT,
        "num_ctx": int(os.environ.get("TIMELINE_NUM_CTX", "8192")),
    }
    for attempt in range(2):
        try:
            res = requests.post(OLLAMA_URL, json={
                "model": MODEL,
                "prompt": prompt,
                "stream": False,
                "options": opts,
            }, timeout=TIMELINE_OLLAMA_TIMEOUT)
            res.raise_for_status()
            text = res.json().get("response", "")
            match = re.search(r'\{[\s\S]*\}', text)
            if match:
                return match.group(0)
        except Exception as e:
            if attempt == 1:
                raise e
    return ""


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


def iter_ollama_tokens_display(prompt: str):
    for piece in iter_ollama_tokens(prompt):
        yield clean_output(piece)


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


def _cross_rules(n: int) -> str:
    if n <= 1:
        return ""
    cross_rules = (
        f"\n총 {n}개 조서를 서로 비교한다. "
        "statement_a와 statement_b 인용은 반드시 위 [원본 진술 전체]에 나타난 문장을 그대로 복사해라. "
        "서로 다른 조서에서 인용해도 된다."
    )
    if n > 2:
        cross_rules += (
            " 조서가 세 개 이상이면 모든 조서 쌍·조합을 고려해 "
            "날짜·시간·장소·행동 등의 불일치를 빠짐없이 탐지해라."
        )
    return cross_rules


def _pass2_prompt(full_body: str, n: int) -> str:
    cross_rules = _cross_rules(n)
    return f"""당신은 형사 진술 대조 전문가다. 아래 [원본 진술 전체] **원문만** 근거로 논리·사실 모순을 찾아라.{cross_rules}
별도 요약문은 제공되지 않는다. [진술 1:] … 형태의 블록을 검색·대조(RAG 근거 단편)처럼 각각 읽고 서로 비교해라.

반드시 아래 JSON 형식으로만 답하라. JSON 외 문장은 쓰지 마라.

[원본 진술 전체]
{full_body}

핵심 규칙:
1. statement_a, statement_b는 위 원문에서 **연속된 문자열을 한 글자도 바꾸지 말고** 복사한다. 부정어·조사·띄어쓰기까지 동일해야 한다.
2. **부정·전면 부정**(전혀, 일절, 절대, 한 번도, 없다, 하지 않았다, 한 적 없다 등)과 **부분·긍정**(잠시, 잠깐, 한 적 있다, 했다 등)이 **같은 사건·행위**를 말할 때 서로 배치되면 모순 후보로 본다.
3. 서로 다른 [진술 i] 블록에서 인용해도 된다.
4. 확실하지 않으면 contradictions 배열을 비운다.

JSON 형식:
{{
  "contradictions": [
    {{
      "type": "시간 불일치 또는 장소 불일치 또는 행동 불일치",
      "statement_a": "원문에서 그대로 인용한 첫 번째 진술",
      "statement_b": "원문에서 그대로 인용한 두 번째 진술 (statement_a와 모순)",
      "reason": "왜 모순인지 한 문장 설명"
    }}
  ],
  "further_checks": [
    "원본 진술에서 날짜·시간·장소·인물이 불명확한 항목만 적을 것.",
    "추측이나 새로운 의혹 제기 금지. 최대 2개.",
    "해당 없으면 빈 배열 []로 둘 것."
  ]
}}"""


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


def _timeline_event_has_time_signal(ev: dict) -> bool:
    """시간 단서가 있는 이벤트만 타임라인 대상."""
    if not isinstance(ev, dict):
        return False
    if _parse_timeline_iso(ev.get("time_start")):
        return True
    tt = (ev.get("time_text") or "").strip()
    prec = (ev.get("time_precision") or "").lower()
    if prec in ("exact", "approximate", "relative") and tt:
        return True
    # 본문에 시간·순서 표현이 있으면 포함
    if tt and prec != "unknown":
        return True
    time_hints = ("시", "분", "쯤", "경", "전", "후", "뒤", "이후", "이전", "당시", "무렵", "경", "오전", "오후", "새벽", "저녁", "낮")
    return any(h in tt for h in time_hints)


def _filter_timeline_time_only(events: list) -> list:
    return [e for e in events if isinstance(e, dict) and _timeline_event_has_time_signal(e)]


def _timeline_extract_prompt(case_id: str, stmt_name: str, stmt_type: str, text: str) -> str:
    return f"""{NO_MARKDOWN}
조서 원문에서 시간·시각·순서와 직접 관련된 행적·행위만 뽑아 JSON 객체 하나만 출력한다. 설명·마크다운·코드펜스 금지. JSON 밖 문장은 쓰지 마라.
모순·진술 대조·관계망 인물 추출은 하지 않는다.

사건: {case_id}
이 조서 화자(진술자): {stmt_name}

[조서]
{text}

원문 보존(타임라인·모순 대조에 쓰이므로 생략·왜곡 금지):
1. time_text, quote는 [조서] 시간·순서·행위 표현을 원문 그대로 적는다.
2. **label**은 [조서]에 실제로 쓰인 **단어·어구를 그대로** 이어 붙여 한 줄로 쓴다. 요약·의역·번역·대체어 금지.
   - 조서에 「가죽 가방」이면 label에도 「가죽 가방」(leather bag 등 영어·다른 표현 금지).
   - 조서에 「김철수」면 「피해자」「상대방」 등으로 바꾸지 말고 「김철수」.
   - 조서에 「코인노래방」이면 그 표기 그대로(노래방·가라오케 등으로 바꾸지 말 것).
   - label에 넣는 모든 명사·동사·부정어(전혀, 일절, 하지 않았다 등)는 quote·[조서]에서 **복사**할 것. 새로 짓지 말 것.
3. 날짜·시각·장소·인물·행위를 추측으로 보완하지 말 것. 불명확하면 time_precision을 approximate 또는 relative로 두고 time_text에 원문 표현을 남긴다.
4. **time_start·time_end는 time_text를 기준**으로 채운다(오후 3시 5분→15:05). time_text·label에 시각이 있으면 quote에 없어도 time_start를 넣는다. AI가 넣은 time_start가 time_text와 다르면 time_text가 맞다.
5. 부정·전면 부정(전혀, 일절, 한 번도, 없다, 하지 않았다 등)과 부분·긍정 표현은 quote에서 빼거나 약화하지 말 것.

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
2. 시간·순서 단서가 전혀 없는 일반 서술은 넣지 말 것.
3. stmt_name은 행위 주체 이름. 다른 인물의 행위면 그 인물 이름을 쓸 것.
4. quote에 적힌 시각과 time_start, time_end, time_text가 일치해야 한다. 시작·끝 시각이 둘 다 있으면(예: 밤 10시 40분에 … 밤 11시 5분에) time_start·time_end·time_text에 각각 반영하고, 끝 시각을 임의로 5분 뒤로 대체하지 말 것.
5. exact는 본문에 구체 시각(몇 시 몇 분·날짜)이 있을 때만 time_start를 채운다. approximate는 대략·경·쯤. N분 후·N시간 뒤만 있으면 time_start는 null로 두고 time_text·quote에 원문(예: 20분 후)을 그대로 남긴다(서버가 직전 이벤트 시각 기준으로 계산).
6. events는 시간순, sort_order 오름차순.
7. **쪼개기(SPLIT)**: 같은 시각대라도 **타인에 대한 목격·부재·대신 관찰**(「대신」「그러나」+ 다른 사람 행적)은 이벤트를 나눈다. observation으로 분리.
8. **묶기(MERGE)**: 진술자 **본인의 한 시각대 알리바이**—어디 있었는지·하지 않은 일·당시 하던 일(코인노래방 1시간 등)—가 **연속**이면 **이벤트 1개**로 묶는다. event_type은 alibi. time_start=시작 시각, time_end=「N시간 동안」이 있으면 시작+N시간(예: 오후 3시쯤+1시간→4시). label·quote에 부정(금은방 미접근)과 체류(노래방)를 함께 요약해도 된다.
9. 「당시 저는 …」「…긴 했지만 … 하지 않았습니다」처럼 앞 문장 시각을 이어받는 **본인 행적 후속**은 새 이벤트로 쪼개지 말고 앞 알리바이에 합친다.
10. 예(묶기): 「어제 오후 3시쯤 서면 지하상가 근처였지만 금은방에는 가지 않았고, 당시 코인노래방에서 1시간 노래」→ **1개** alibi, time_text에 3시~1시간, place=코인노래방.
11. 예(쪼개기): 「3시 10분쯤 코인노래방 앞으로 갔는데 현우는 안에 없었고, 대신 비상구에서 봤다」→ movement+observation 분리(규칙 7).
12. 해당 없으면 {{"events":[]}}

JSON 형식:
{{
  "events": [
    {{
      "stmt_name": "홍길동",
      "stmt_type": "피의자",
      "event_type": "action",
      "time_precision": "exact",
      "time_start": "2024-05-01T14:30:00",
      "time_end": null,
      "time_text": "2024년 5월 1일 오후 2시 30분경",
      "place": "역삼동 주택",
      "label": "오후 2시 30분경 역삼동 집 앞에서 김철수를 만남",
      "quote": "그때 역삼동 집 앞에서 김철수를 만났다.",
      "confidence": "high",
      "sort_order": 10
    }}
  ]
}}"""


_KR_CLOCK_PATTERNS = (
    (re.compile(r"(오전)\s*(\d{1,2})\s*시(?:\s*(\d{1,2})\s*분)?"), "am"),
    (re.compile(r"(오후)\s*(\d{1,2})\s*시(?:\s*(\d{1,2})\s*분)?"), "pm"),
    (re.compile(r"(밤)\s*(\d{1,2})\s*시(?:\s*(\d{1,2})\s*분)?"), "pm"),
    (re.compile(r"(저녁)\s*(\d{1,2})\s*시(?:\s*(\d{1,2})\s*분)?"), "pm"),
    (re.compile(r"(새벽)\s*(\d{1,2})\s*시(?:\s*(\d{1,2})\s*분)?"), "am"),
    (re.compile(r"(낮)\s*(\d{1,2})\s*시(?:\s*(\d{1,2})\s*분)?"), "am"),
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


def _find_korean_clock_in_text(text: str):
    """첫 번째 시각 (hour24, minute, phrase) 또는 None."""
    clocks = _find_all_korean_clocks_in_text(text)
    if not clocks:
        return None
    c = clocks[0]
    return c[1], c[2], c[3]


def _find_all_korean_clocks_in_text(text: str) -> list:
    """문장 속 시각을 등장 순서대로 [(hour24, minute, phrase), ...]."""
    if not text or not str(text).strip():
        return []
    src = str(text)
    hits = []
    for pat, period in _KR_CLOCK_PATTERNS:
        for m in pat.finditer(src):
            try:
                h = int(m.group(2))
                g3 = m.group(3)
                minute = int(g3) if g3 else 0
                h24, mi = _korean_period_to_24h(h, minute, period)
                hits.append((m.start(), h24, mi, m.group(0).strip()))
            except (TypeError, ValueError, IndexError):
                continue
    hits.sort(key=lambda x: x[0])
    out = []
    for _pos, h24, mi, phrase in hits:
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


def _parse_date_from_event_text(text: str):
    if not text:
        return None
    from datetime import date
    m = re.search(r"(\d{4})\s*년\s*(\d{1,2})\s*월\s*(\d{1,2})\s*일", text)
    if not m:
        return None
    try:
        return date(int(m.group(1)), int(m.group(2)), int(m.group(3)))
    except (TypeError, ValueError):
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


def _pick_start_clock(time_text: str, label: str, quote: str):
    for src in (time_text, label, quote):
        if not src or not str(src).strip():
            continue
        clocks = _find_all_korean_clocks_in_text(str(src).strip())
        if clocks:
            return clocks[0]
    return None


def _pick_end_clock(time_text: str, label: str, quote: str, start_h: int, start_m: int):
    for src in (time_text, label, quote):
        if not src or not str(src).strip():
            continue
        clocks = _find_all_korean_clocks_in_text(str(src).strip())
        if len(clocks) >= 2:
            end_h, end_m, end_phrase = clocks[-1]
            if (end_h, end_m) != (start_h, start_m):
                return end_h, end_m, end_phrase
    return None, None, None


def _reconcile_timeline_event_times(ev: dict) -> dict:
    """time_text → label → quote 순으로 time_start/end 확정 (AI time_start보다 우선)."""
    if not isinstance(ev, dict):
        return ev
    tt = (ev.get("time_text") or "").strip()
    label = (ev.get("label") or "").strip()
    quote = (ev.get("quote") or "").strip()
    sources = _event_time_source_text(ev)
    if not sources:
        return ev

    from datetime import datetime, timedelta

    iso_start = _parse_datetime_from_text_field(tt) or _parse_datetime_from_text_field(label)
    if iso_start:
        ev["time_start"] = iso_start.strftime("%Y-%m-%dT%H:%M:%S")
        te = _parse_timeline_iso(ev.get("time_end"))
        if not te or te <= iso_start:
            ev["time_end"] = (iso_start + timedelta(minutes=5)).strftime("%Y-%m-%dT%H:%M:%S")
        prec_src = tt or sources
        if any(x in prec_src for x in ("경", "쯤", "대략", "무렵")):
            ev["time_precision"] = "approximate"
        else:
            ev["time_precision"] = ev.get("time_precision") or "exact"
        return ev

    picked = _pick_start_clock(tt, label, quote)
    if not picked:
        return ev
    start_h, start_m, start_phrase = picked

    base_date = _parse_date_from_event_text(tt)
    if not base_date:
        base_date = _parse_date_from_event_text(label)
    if not base_date:
        base_date = _parse_date_from_event_text(quote)
    ts = _parse_timeline_iso(ev.get("time_start"))
    if not base_date and ts:
        base_date = ts.date()
    if not base_date:
        base_date = datetime.now().date()

    def _combine(h: int, m: int):
        return datetime(base_date.year, base_date.month, base_date.day, h, m, 0)

    start_dt = _combine(start_h, start_m)
    ev["time_start"] = start_dt.strftime("%Y-%m-%dT%H:%M:%S")

    end_h, end_m, end_phrase = _pick_end_clock(tt, label, quote, start_h, start_m)
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


def _reconcile_timeline_events_from_quotes(events: list) -> list:
    return [_reconcile_timeline_event_times(ev) for ev in events]


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


def _try_parse_relative_offset_minutes(text: str):
    """'20분 후' 등 상대 분·시간만 추출."""
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


def _parse_relative_offset_minutes(text: str):
    """상대 표현 우선. 없고 절대 시각만 있으면 None."""
    if not text or not str(text).strip():
        return None
    src = str(text).strip()
    rel = _try_parse_relative_offset_minutes(src)
    if rel is not None:
        return rel
    if _find_all_korean_clocks_in_text(src):
        return None
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
    if "대신" in q and any(m in q for m in ("봤", "보았", "목격", "내려", "나타", "있었")):
        return True
    return any(c in q for c in _SAME_TIME_CONNECTORS if c != "대신") or any(
        m in q for m in ("보이지", "목격", "봤", "보았")
    )


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


def _extract_json_object(text: str) -> dict | None:
    if not (text or "").strip():
        return None
    start = text.find("{")
    if start < 0:
        return None
    depth = 0
    end   = -1
    for i in range(start, len(text)):
        if text[i] == "{":
            depth += 1
        elif text[i] == "}":
            depth -= 1
            if depth == 0:
                end = i
                break
    if end < 0:
        m = re.search(r"\{[\s\S]*\}", text)
        if not m:
            return None
        chunk = m.group(0)
    else:
        chunk = text[start: end + 1]
    try:
        return json.loads(chunk)
    except json.JSONDecodeError:
        return None


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

def normalize(text: str) -> str:
    return re.sub(r'\s+', '', text)


def fuzzy_in(quote: str, original: str, min_len: int = 6, chunk: int = 10) -> bool:
    quote = quote.strip()
    if len(quote) < min_len:
        return True
    norm_original = normalize(original)
    norm_quote    = normalize(quote)
    if norm_quote in norm_original:
        return True
    chunks  = [norm_quote[i:i+chunk] for i in range(0, len(norm_quote), chunk)
               if len(norm_quote[i:i+chunk]) >= min_len]
    if not chunks:
        return True
    matched = sum(1 for c in chunks if c in norm_original)
    return (matched / len(chunks)) >= 0.5


def verify_quotes(contradictions: list, corpus: str) -> list:
    verified = []
    for item in contradictions:
        quote_a = item.get("statement_a", "")
        quote_b = item.get("statement_b", "")
        if fuzzy_in(quote_a, corpus) and fuzzy_in(quote_b, corpus):
            item["verified"] = True
            verified.append(item)
    return verified


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
        for piece in iter_ollama_tokens_display(_pass1_prompt(case_num, n, full_body)):
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

    prompt = _timeline_extract_prompt(case_id, stmt_name, stmt_type, text)
    try:
        raw = call_ollama_timeline(prompt)
    except Exception as ex:
        return jsonify({"success": False, "error": f"모델 호출 실패: {ex}", "events": []}), 502

    parsed = _extract_json_object(raw or "")
    if not parsed or not isinstance(parsed.get("events"), list):
        return jsonify({"success": False, "error": "이벤트 JSON 파싱 실패", "events": []}), 502

    events = [_normalize_timeline_event_fields(e) for e in parsed["events"] if isinstance(e, dict)]
    events = _reconcile_timeline_events_from_quotes(events)
    events = _resolve_relative_durations_from_text(events)
    events = _apply_activity_duration_end(events)
    events = _merge_same_period_alibi_blocks(events)
    events = _inherit_same_time_context(events)
    events = _filter_timeline_time_only(events)
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
if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5001, debug=False)