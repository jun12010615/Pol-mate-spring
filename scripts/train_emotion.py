"""
train_emotion.py
────────────────────────────────────────────────────────
AI Hub 전처리 CSV로 KoELECTRA 4감정 회귀 모델 fine-tuning

요구사항:
    pip install transformers torch pandas scikit-learn

사용법:
    python train_emotion.py \
        --train output/emotion_train.csv \
        --val   output/emotion_val.csv \
        --out   ./emotion_model
"""

import argparse
import os
import pandas as pd
import torch
from torch.utils.data import Dataset, DataLoader
from transformers import (
    AutoTokenizer,
    AutoModel,
    get_linear_schedule_with_warmup,
)
from torch import nn
from torch.optim import AdamW

BASE_MODEL   = "monologg/koelectra-base-v3-discriminator"
MAX_LEN      = 128
BATCH_SIZE   = 32
EPOCHS       = 5
LR           = 2e-5
LABELS       = ["불안", "확신", "회피", "분노"]
LOG_INTERVAL = 50


class EmotionDataset(Dataset):
    def __init__(self, df, tokenizer, max_len):
        self.texts     = df["text"].tolist()
        self.labels    = df[LABELS].values.astype("float32") / 100.0
        self.tokenizer = tokenizer
        self.max_len   = max_len

    def __len__(self):
        return len(self.texts)

    def __getitem__(self, idx):
        enc = self.tokenizer(
            self.texts[idx],
            max_length=self.max_len,
            padding="max_length",
            truncation=True,
            return_tensors="pt",
        )
        return {
            "input_ids":      enc["input_ids"].squeeze(0),
            "attention_mask": enc["attention_mask"].squeeze(0),
            "labels":         torch.tensor(self.labels[idx], dtype=torch.float32),
        }


class EmotionRegressor(nn.Module):
    def __init__(self, model_name, num_labels=4):
        super().__init__()
        self.encoder = AutoModel.from_pretrained(model_name)
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


def train(args):
    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
    print(f"[학습] 디바이스: {device}", flush=True)

    train_df = pd.read_csv(args.train, encoding="utf-8-sig")
    val_df   = pd.read_csv(args.val,   encoding="utf-8-sig")
    print(f"[데이터] train {len(train_df)}건 / val {len(val_df)}건", flush=True)

    tokenizer = AutoTokenizer.from_pretrained(BASE_MODEL)
    train_ds  = EmotionDataset(train_df, tokenizer, MAX_LEN)
    val_ds    = EmotionDataset(val_df,   tokenizer, MAX_LEN)
    train_dl  = DataLoader(train_ds, batch_size=BATCH_SIZE, shuffle=True,  num_workers=0)
    val_dl    = DataLoader(val_ds,   batch_size=BATCH_SIZE, shuffle=False, num_workers=0)

    total_batches = len(train_dl)
    print(f"[배치] epoch당 총 {total_batches}배치 / {LOG_INTERVAL}배치마다 로그 출력", flush=True)

    model     = EmotionRegressor(BASE_MODEL).to(device)
    optimizer = AdamW(model.parameters(), lr=LR, weight_decay=0.01)
    total_steps = total_batches * EPOCHS
    scheduler   = get_linear_schedule_with_warmup(
        optimizer,
        num_warmup_steps=total_steps // 10,
        num_training_steps=total_steps,
    )
    criterion     = nn.MSELoss()
    best_val_loss = float("inf")
    os.makedirs(args.out, exist_ok=True)

    for epoch in range(1, EPOCHS + 1):
        print(f"\n{'='*50}", flush=True)
        print(f"[Epoch {epoch}/{EPOCHS}] 학습 시작", flush=True)
        print(f"{'='*50}", flush=True)

        model.train()
        total_loss  = 0.0
        batch_count = 0

        for batch in train_dl:
            input_ids      = batch["input_ids"].to(device)
            attention_mask = batch["attention_mask"].to(device)
            labels         = batch["labels"].to(device)

            optimizer.zero_grad()
            preds = model(input_ids, attention_mask)
            loss  = criterion(preds, labels)
            loss.backward()
            nn.utils.clip_grad_norm_(model.parameters(), 1.0)
            optimizer.step()
            scheduler.step()

            total_loss  += loss.item()
            batch_count += 1

            # 첫 번째 배치 즉시 출력
            if batch_count == 1:
                print(
                    f"  [Epoch {epoch} | 1/{total_batches}배치 (0.0%)] "
                    f"현재loss={loss.item():.4f}  평균loss={loss.item():.4f} ← 첫 배치 시작!",
                    flush=True
                )

            # 50배치마다 로그
            elif batch_count % LOG_INTERVAL == 0:
                avg_so_far = total_loss / batch_count
                pct = batch_count / total_batches * 100
                print(
                    f"  [Epoch {epoch} | {batch_count}/{total_batches}배치 ({pct:.1f}%)] "
                    f"현재loss={loss.item():.4f}  평균loss={avg_so_far:.4f}",
                    flush=True
                )

        avg_train = total_loss / total_batches

        # ── Validation
        print(f"  → Validation 시작...", flush=True)
        model.eval()
        val_loss = 0.0
        with torch.no_grad():
            for batch in val_dl:
                input_ids      = batch["input_ids"].to(device)
                attention_mask = batch["attention_mask"].to(device)
                labels         = batch["labels"].to(device)
                preds          = model(input_ids, attention_mask)
                val_loss      += criterion(preds, labels).item()

        avg_val = val_loss / len(val_dl)
        print(f"[Epoch {epoch}/{EPOCHS}] train_loss={avg_train:.4f}  val_loss={avg_val:.4f}", flush=True)

        if avg_val < best_val_loss:
            best_val_loss = avg_val
            model.encoder.save_pretrained(os.path.join(args.out, "encoder"))
            tokenizer.save_pretrained(os.path.join(args.out, "encoder"))
            torch.save(model.state_dict(), os.path.join(args.out, "emotion_model.pt"))
            print(f"  → 모델 저장! (val_loss={avg_val:.4f})", flush=True)

    print(f"\n{'='*50}", flush=True)
    print(f"학습 완료! 최적 val_loss: {best_val_loss:.4f}", flush=True)
    print(f"저장 위치: {args.out}/", flush=True)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--train", required=True)
    parser.add_argument("--val",   required=True)
    parser.add_argument("--out",   default="./emotion_model")
    args = parser.parse_args()
    train(args)
