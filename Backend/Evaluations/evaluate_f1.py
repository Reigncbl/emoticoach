import csv
import os
import random
import statistics
import sys
from typing import Dict, List

sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

from services.RAGPipeline import SimpleRAG, RESPONSE_POLICY
from transformers import AutoTokenizer, AutoModelForSequenceClassification
import torch
import pandas as pd


ROBERTA_MODEL = os.getenv("HF_MODEL", "j-hartmann/emotion-english-distilroberta-base")


_tokenizer = None
_classifier = None


def load_classifier():
    global _tokenizer, _classifier
    if _tokenizer is None or _classifier is None:
        _tokenizer = AutoTokenizer.from_pretrained(ROBERTA_MODEL)
        _classifier = AutoModelForSequenceClassification.from_pretrained(ROBERTA_MODEL)
    return _tokenizer, _classifier


def orange_print(text: str) -> None:
    """Print text in orange color for terminal output."""
    print(f"\033[38;5;208m{text}\033[0m")


def classify_response_emotion(rag, text: str) -> str:
    """Classify emotion using RoBERTa model directly (no Groq translation)."""
    tokenizer, classifier = load_classifier()
    inputs = tokenizer(
        text,
        return_tensors="pt",
        padding=True,
        truncation=True,
        max_length=512,
    )
    with torch.no_grad():
        logits = classifier(**inputs).logits
        probabilities = torch.softmax(logits, dim=-1)
        predicted_idx = int(torch.argmax(probabilities, dim=-1).item())
    return classifier.config.id2label[predicted_idx].lower()


def expected_tone_from_label(label: str) -> str:
    return RESPONSE_POLICY.get(label.lower(), "Supportive")


# Define emotion polarity for tone-switching validation
EMOTION_POLARITY = {
    "anger": "negative",
    "sadness": "negative",
    "fear": "negative",
    "disgust": "negative",
    "joy": "positive",
    "surprise": "positive",
    "neutral": "neutral",
}

# Expected response polarity based on input emotion (tone switching)
# Negative emotions should get positive/neutral responses
# Positive/neutral emotions can get positive/neutral responses
EXPECTED_RESPONSE_POLARITY = {
    "anger": ["positive", "neutral"],      # Calm, reassuring
    "sadness": ["positive", "neutral"],   # Encouraging, supportive
    "fear": ["positive", "neutral"],      # Reassuring, calm
    "disgust": ["positive", "neutral"],   # Understanding, supportive
    "joy": ["positive", "neutral"],       # Supportive, reflective
    "surprise": ["positive", "neutral"],  # Supportive
    "neutral": ["positive", "neutral"],   # Reflective, any supportive
}


def load_dataset(dataset_path: str, sample_size: int = 50, seed: int = 42) -> List[Dict[str, str]]:
    with open(dataset_path, encoding="utf-8") as dataset_file:
        reader = list(csv.DictReader(dataset_file, delimiter="\t"))

    random.seed(seed)
    if sample_size > 0:
        reader = random.sample(reader, min(sample_size, len(reader)))

    return reader


def evaluate_f1(sample_size: int = 50) -> None:
    dataset_env = os.getenv("RAG_F1_DATASET")
    if not dataset_env:
        dataset_path = os.path.abspath(
            os.path.join(
                os.path.dirname(__file__),
                "..",  # Go up from Backend
                "..",  # Go up from Backend/Evaluations
                "Evaluations",
                "Taglish_Dataset",
                "EMOTERA-All-cleaned.tsv",
            )
        )
    else:
        dataset_path = dataset_env

    orange_print("Initializing RAG with Hugging Face Inference API for BAAI/bge-m3...")
    rag = SimpleRAG()
    
    rows = load_dataset(dataset_path, sample_size=sample_size)

    y_true: List[str] = []
    y_pred: List[str] = []
    tones_failed = 0
    sample_records: List[Dict[str, str]] = []

    # Valid emotions from RoBERTa model
    valid_emotions = {"anger", "joy", "fear", "surprise", "sadness", "neutral", "disgust"}

    for row in rows:
        original_emotion = row["emotion"].strip().lower()
        prompt = row["tweet"].strip()

        # Skip rows with invalid emotions (like "other", "anticipation", "trust")
        if not prompt or original_emotion not in valid_emotions:
            continue

        response = rag.generate_response(prompt)
        generated_emotion = classify_response_emotion(rag, response)
        expected_tone = expected_tone_from_label(original_emotion)
        predicted_tone = expected_tone_from_label(generated_emotion)

        # Check if response polarity is appropriate for tone switching
        response_polarity = EMOTION_POLARITY.get(generated_emotion, "neutral")
        expected_polarities = EXPECTED_RESPONSE_POLARITY.get(original_emotion, ["neutral"])
        is_appropriate_switch = response_polarity in expected_polarities

        # For F1, we check if the tone switch is appropriate
        # y_true: expected polarity (positive/neutral for negative inputs)
        # y_pred: actual response polarity
        expected_polarity = expected_polarities[0]  # Primary expected polarity
        y_true.append(expected_polarity)
        y_pred.append(response_polarity)

        if not is_appropriate_switch:
            tones_failed += 1

        sample_records.append(
            {
                "original_emotion": original_emotion,
                "original_polarity": EMOTION_POLARITY[original_emotion],
                "expected_tone": expected_tone.lower(),
                "expected_polarity": "/".join(expected_polarities),
                "response_emotion": generated_emotion,
                "response_polarity": response_polarity,
                "predicted_tone": predicted_tone.lower(),
                "appropriate_switch": is_appropriate_switch,
                "response_text": response,
            }
        )

    if not y_true:
        raise RuntimeError("No valid samples evaluated.")

    # Calculate F1 by polarity (positive, negative, neutral)
    polarities = sorted(set(y_true) | set(y_pred))
    f1_total = 0.0
    per_polarity = {}

    for polarity in polarities:
        tp = sum(1 for yt, yp in zip(y_true, y_pred) if yt == polarity and yp == polarity)
        fp = sum(1 for yt, yp in zip(y_true, y_pred) if yt != polarity and yp == polarity)
        fn = sum(1 for yt, yp in zip(y_true, y_pred) if yt == polarity and yp != polarity)
        precision = tp / (tp + fp) if (tp + fp) else 0.0
        recall = tp / (tp + fn) if (tp + fn) else 0.0
        f1 = 2 * precision * recall / (precision + recall) if (precision + recall) else 0.0
        per_polarity[polarity] = {
            "precision": precision,
            "recall": recall,
            "f1": f1,
            "support": sum(1 for yt in y_true if yt == polarity),
        }
        f1_total += f1

    macro_f1 = statistics.mean([metrics["f1"] for metrics in per_polarity.values()])
    
    # Calculate accuracy for appropriate tone switching
    appropriate_switches = sum(1 for record in sample_records if record["appropriate_switch"])
    tone_switch_accuracy = appropriate_switches / len(sample_records) if sample_records else 0.0

    orange_print("=== Tone Switching Evaluation ===")
    orange_print(f"Samples evaluated: {len(sample_records)}")
    orange_print(f"Tone Switch Accuracy: {tone_switch_accuracy:.3f} ({appropriate_switches}/{len(sample_records)})")
    orange_print(f"Macro F1 (Polarity): {macro_f1:.3f}")
    orange_print(f"Inappropriate switches (negative→negative, etc.): {tones_failed}")
    orange_print("")
    for record in sample_records:
        switch_mark = "✓" if record["appropriate_switch"] else "✗"
        orange_print(
            f"Original={record['original_emotion']}({record['original_polarity']}), "
            f"Response={record['response_emotion']}({record['response_polarity']}), "
            f"Expected={record['expected_polarity']}, "
            f"Switch={switch_mark}, "
            f"Text='{record['response_text'][:80]}...'"
        )
    orange_print("=" * 50)
    for polarity, metrics in per_polarity.items():
        orange_print(
            f"Polarity '{polarity}': F1={metrics['f1']:.3f} Precision={metrics['precision']:.3f} "
            f"Recall={metrics['recall']:.3f} Support={metrics['support']}"
        )

    orange_print("==================================")

    from datetime import datetime
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    
    output_path = os.getenv(
        "RAG_F1_OUTPUT",
        os.path.abspath(
            os.path.join(
                os.path.dirname(__file__),
                "results",
                f"tone_mapping_f1_{timestamp}.xlsx",
            )
        ),
    )
    os.makedirs(os.path.dirname(output_path), exist_ok=True)

    details_df = pd.DataFrame(sample_records)
    summary_df = pd.DataFrame(
        [
            {
                "metric": "Tone Switch Accuracy",
                "value": tone_switch_accuracy,
            },
            {
                "metric": "Appropriate Switches",
                "value": appropriate_switches,
            },
            {
                "metric": "Macro F1 (Polarity)",
                "value": macro_f1,
            },
            {
                "metric": "Samples Evaluated",
                "value": len(sample_records),
            },
            {
                "metric": "Inappropriate Switches",
                "value": tones_failed,
            },
        ]
    )
    per_polarity_df = pd.DataFrame.from_dict(per_polarity, orient="index").reset_index().rename(columns={"index": "polarity"})

    with pd.ExcelWriter(output_path, engine="openpyxl") as writer:
        details_df.to_excel(writer, sheet_name="samples", index=False)
        per_polarity_df.to_excel(writer, sheet_name="per_polarity", index=False)
        summary_df.to_excel(writer, sheet_name="summary", index=False)

    orange_print(f"Excel report saved to: {output_path}")


if __name__ == "__main__":
    sample_size = int(os.getenv("RAG_TEST_MAX_SAMPLES", "50"))
    evaluate_f1(sample_size=sample_size)
