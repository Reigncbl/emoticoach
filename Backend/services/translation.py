import os
import sys
from typing import List, Dict, Any, Tuple

import torch
import torch.nn.functional as F
from transformers import AutoTokenizer, AutoModelForSequenceClassification
from dotenv import load_dotenv
from groq import Groq
import pandas as pd
from sklearn.metrics import f1_score, confusion_matrix, classification_report
import numpy as np

# -------------------------------


def get_translation_prompt(tagalog_text: str, dataset_emotion: str) -> str:
    """
    Creates an advanced emotion-aware prompt with Chain-of-Thought, persona, and few-shot examples.
    """
    emotion_guidance = {
        'anger': {'emoji': '🤬'},
        'disgust': {'emoji': '🤢'},
        'fear': {'emoji': '😨'},
        'joy': {'emoji': '😀'},
        'neutral': {'emoji': '😐'},
        'sadness': {'emoji': '😭'},
        'surprise': {'emoji': '😲'}
    }

    guidance = emotion_guidance.get(dataset_emotion.lower(), {'emoji': ''})
    emoji = guidance['emoji']

    prompt = f"""Translate this Tagalog text to English, keeping the casual style and emotion {dataset_emotion.upper()} {emoji}.
Guidelines:
1. Keep the same level of formality as the original
2. Use natural English expressions
3. Preserve the emotional tone

**Tagalog Text:** {tagalog_text}

**English Translation:**"""

    return prompt


def clean_llm_output(text: str) -> str:
    """Clean translation output from LLM."""
    if not text:
        return ""
    text = text.strip().strip('"\'')
    if "**English Translation:**" in text:
        text = text.split("**English Translation:**")[-1].strip()
    for prefix in ['english translation:', 'translation:', 'english:', 'translated:']:
        if text.lower().startswith(prefix):
            text = text[len(prefix):].strip()
    return text


def translate_texts(
    tagalog_texts: List[str],
    dataset_emotions: List[str],
    groq_client: Groq,
    groq_model: str
) -> Tuple[List[str], int]:
    """Translate texts with emotion-aware prompts. Returns translations and count of failures."""
    translated_texts = []
    failures = 0

    for i, (text, emotion) in enumerate(zip(tagalog_texts, dataset_emotions)):
        try:
            prompt = get_translation_prompt(text, emotion)
            response = groq_client.chat.completions.create(
                messages=[{"role": "user", "content": prompt}],
                model=groq_model,
                temperature=0.3,
                max_tokens=200
            )
            translated = clean_llm_output(response.choices[0].message.content)
            translated_texts.append(translated)
        except Exception as e:
            translated_texts.append("Translation failed")
            failures += 1
            print(f"Error translating sample {i+1}: {e}")

    return translated_texts, failures

