"""
emotion_model_loader.py
────────────────────────────────────────────────────────
학습된 4감정 모델을 polmate_serv.py 에 연결하는 로더

polmate_serv.py 섹션 8의 _try_load_emotion_model() 함수를
아래 load_finetuned_emotion_model() 로 교체하면 됩니다.

모델 디렉토리 구조:
    emotion_model/
        encoder/          ← KoELECTRA encoder + tokenizer
        emotion_model.pt  ← 학습된 가중치
"""

import os
import torch
from torch import nn
from transformers import AutoTokenizer, AutoModel

LABELS     = ["불안", "확신", "회피", "분노"]
MODEL_DIR  = os.environ.get("EMOTION_MODEL_DIR", "./emotion_model")
MAX_LEN    = 128


class EmotionRegressor(nn.Module):
    def __init__(self, encoder_path: str, num_labels: int = 4):
        super().__init__()
        self.encoder = AutoModel.from_pretrained(encoder_path)
        hidden_size  = self.encoder.config.hidden_size
        self.dropout = nn.Dropout(0.1)
        self.head    = nn.Sequential(
            nn.Linear(hidden_size, 256),
            nn.GELU(),
            nn.Dropout(0.1),
            nn.Linear(256, num_labels),
            nn.Sigmoid(),
        )

    def forward(self, input_ids, attention_mask):
        out    = self.encoder(input_ids=input_ids, attention_mask=attention_mask)
        pooled = out.last_hidden_state[:, 0, :]
        return self.head(self.dropout(pooled))


# ── 전역 모델 객체 ────────────────────────────────────────────────────────────
_FT_MODEL     = None
_FT_TOKENIZER = None
_FT_DEVICE    = torch.device("cuda" if torch.cuda.is_available() else "cpu")


def load_finetuned_emotion_model(model_dir: str = MODEL_DIR) -> bool:
    """
    학습된 모델 로드. 성공 시 True, 실패 시 False.
    polmate_serv.py 의 _try_load_emotion_model() 대신 호출.
    """
    global _FT_MODEL, _FT_TOKENIZER
    encoder_path = os.path.join(model_dir, "encoder")
    weights_path = os.path.join(model_dir, "emotion_model.pt")

    if not os.path.exists(encoder_path) or not os.path.exists(weights_path):
        print(f"[감정분석] fine-tuned 모델 없음 ({model_dir}) → 기존 방식 사용")
        return False

    try:
        _FT_TOKENIZER = AutoTokenizer.from_pretrained(encoder_path)
        model         = EmotionRegressor(encoder_path)
        model.load_state_dict(torch.load(weights_path, map_location=_FT_DEVICE, weights_only=False))
        model.to(_FT_DEVICE).eval()
        _FT_MODEL = model
        print(f"[감정분석] fine-tuned 모델 로드 성공: {model_dir}")
        return True
    except Exception as e:
        print(f"[감정분석] fine-tuned 모델 로드 실패: {e}")
        return False


def predict_finetuned(sentence: str) -> dict | None:
    """
    학습된 모델로 문장 감정 점수 예측.
    모델 미로드 시 None 반환 → 기존 키워드 방식으로 fallback.
    """
    if _FT_MODEL is None or _FT_TOKENIZER is None:
        return None
    try:
        enc = _FT_TOKENIZER(
            sentence[:512],
            max_length=MAX_LEN,
            padding="max_length",
            truncation=True,
            return_tensors="pt",
        )
        with torch.no_grad():
            out = _FT_MODEL(
                enc["input_ids"].to(_FT_DEVICE),
                enc["attention_mask"].to(_FT_DEVICE),
            )
        scores = (out.squeeze(0).cpu().numpy() * 100).tolist()
        return {label: round(scores[i], 1) for i, label in enumerate(LABELS)}
    except Exception as e:
        print(f"[감정분석] fine-tuned 추론 오류: {e}")
        return None
