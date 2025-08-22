import os
import json
from typing import List, Dict, Any, Optional, Union

import torch
from transformers import AutoTokenizer, AutoModelForSequenceClassification
import torch.nn.functional as F

# Absolute path to the local model directory
# c:\Users\John Carlo\emoticoach\emoticoach\Backend\AIModel
MODEL_DIR = os.path.normpath(
    os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "AIModel")
)

_tokenizer: Optional[AutoTokenizer] = None
_model: Optional[AutoModelForSequenceClassification] = None
_device: Optional[torch.device] = None
_id2label: Dict[int, str] = {}


def _resolve_device() -> torch.device:
    if torch.cuda.is_available():
        return torch.device("cuda")
    # MPS isn't available on Windows typically; keep CPU fallback
    return torch.device("cpu")


def load_local_model(model_dir: str = MODEL_DIR) -> None:
    """
    Load tokenizer and model from a local directory once (singleton-style).

    Args:
        model_dir: Path to the local Hugging Face model directory
    """
    global _tokenizer, _model, _device, _id2label

    if _tokenizer is not None and _model is not None:
        return

    if not os.path.isdir(model_dir):
        raise FileNotFoundError(f"Model directory not found: {model_dir}")

    # Load tokenizer and model locally without internet
    _tokenizer = AutoTokenizer.from_pretrained(model_dir, local_files_only=True)
    _model = AutoModelForSequenceClassification.from_pretrained(
        model_dir, local_files_only=True
    )
    _model.eval()

    _device = _resolve_device()
    _model.to(_device)

    # Build id2label mapping
    cfg = getattr(_model, "config", None)
    if cfg and getattr(cfg, "id2label", None):
        # Keys may be strings; normalize to int
        _id2label = {int(k): v for k, v in cfg.id2label.items()}
    else:
        # Fallback to generic labels
        num_labels = int(getattr(cfg, "num_labels", 0) or 0) or _model.classifier.out_features
        _id2label = {i: f"LABEL_{i}" for i in range(num_labels)}


def _ensure_model_loaded() -> None:
    if _model is None or _tokenizer is None:
        load_local_model()


def _softmax_logits(logits: torch.Tensor) -> torch.Tensor:
    return F.softmax(logits, dim=-1)


def predict_one(text: str, top_k: int = 1) -> Dict[str, Any]:
    """
    Run prediction on a single text input.

    Returns a dict with top predicted label and score, plus optional top_k list.
    """
    _ensure_model_loaded()

    if not isinstance(text, str) or not text.strip():
        return {"error": "Empty text"}

    enc = _tokenizer(
        text,
        return_tensors="pt",
        truncation=True,
        max_length=512,
        padding=False,
    )

    enc = {k: v.to(_device) for k, v in enc.items()}

    with torch.no_grad():
        outputs = _model(**enc)
        logits = outputs.logits.squeeze(0)
        probs = _softmax_logits(logits).detach().cpu()

    # Top-1
    score, idx = torch.max(probs, dim=-1)
    label = _id2label.get(idx.item(), f"LABEL_{idx.item()}")

    # Top-k
    top_k = max(1, min(top_k, probs.numel()))
    top_scores, top_indices = torch.topk(probs, k=top_k)
    top = [
        {"label": _id2label.get(i.item(), f"LABEL_{i.item()}"), "score": s.item()}
        for s, i in zip(top_scores, top_indices)
    ]

    return {
        "label": label,
        "score": score.item(),
        "top": top,
    }


def predict_batch(texts: List[str], top_k: int = 1, batch_size: int = 8) -> List[Dict[str, Any]]:
    """
    Run prediction on a batch of texts.
    """
    _ensure_model_loaded()

    # Clean inputs
    clean_texts = [t if isinstance(t, str) else str(t) for t in texts]

    results: List[Dict[str, Any]] = []
    for i in range(0, len(clean_texts), batch_size):
        chunk = clean_texts[i : i + batch_size]
        enc = _tokenizer(
            chunk,
            return_tensors="pt",
            truncation=True,
            max_length=512,
            padding=True,
        )
        enc = {k: v.to(_device) for k, v in enc.items()}

        with torch.no_grad():
            outputs = _model(**enc)
            logits = outputs.logits  # [B, C]
            probs = _softmax_logits(logits).detach().cpu()

        for row in probs:
            score, idx = torch.max(row, dim=-1)
            label = _id2label.get(idx.item(), f"LABEL_{idx.item()}")
            topn = max(1, min(top_k, row.numel()))
            ts, ti = torch.topk(row, k=topn)
            top = [
                {"label": _id2label.get(j.item(), f"LABEL_{j.item()}"), "score": s.item()}
                for s, j in zip(ts, ti)
            ]
            results.append({"label": label, "score": score.item(), "top": top})

    return results


def analyze_emotion(text: str) -> Dict[str, Any]:
    """
    Compatibility wrapper that returns a dict similar to the previous LLM-based output.
    - label: predicted class label (from model config id2label)
    - score: probability of the predicted class (0-1)
    - analysis: short note about local model usage
    """
    pred = predict_one(text)
    if "error" in pred:
        return {"analysis": pred["error"], "dim": None, "score": 0.0}

    # Keep keys similar to the LLM JSON convention used elsewhere
    return {
        "analysis": "Local model prediction",
        "dim": pred["label"],
        "score": float(round(pred["score"], 6)),
    }


def analyze_file(file_path: str) -> List[Dict[str, Any]]:
    """
    Analyze a JSON file of messages using the local model. The input file can be:
    - A dict with key "messages" mapping to list[dict|str]
    - A list of dicts or strings

    Output format per item:
    {
        "text": str,
        "timestamp": Optional[str],
        "emotion": str,        # model label
        "score": float,        # probability 0..1
        "analysis": str        # info
    }
    """
    with open(file_path, "r", encoding="utf-8") as f:
        data = json.load(f)

    if isinstance(data, dict) and "messages" in data:
        msgs = data["messages"]
    elif isinstance(data, list):
        msgs = data
    else:
        raise ValueError("Unsupported file format: expected dict with 'messages' or list")

    texts: List[str] = []
    meta: List[Dict[str, Any]] = []

    for msg in msgs:
        if isinstance(msg, dict) and "text" in msg:
            texts.append(msg["text"] or "")
            meta.append({"timestamp": msg.get("date")})
        elif isinstance(msg, str):
            texts.append(msg)
            meta.append({"timestamp": None})
        else:
            # Skip unknown
            continue

    batch_preds = predict_batch(texts, top_k=3)

    results: List[Dict[str, Any]] = []
    for (text, m), pred in zip(zip(texts, meta), batch_preds):
        results.append(
            {
                "text": text,
                "timestamp": m.get("timestamp"),
                "emotion": pred["label"],
                "score": float(round(pred["score"], 6)),
                "analysis": "Local model prediction",
            }
        )

    return results


if __name__ == "__main__":
    # Basic manual test (adjust path if needed).
    sample = "I am very happy to see you today!"
    print("MODEL_DIR:", MODEL_DIR)
    print("Prediction:", predict_one(sample))
