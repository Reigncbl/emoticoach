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
        'anger': {'words': 'furious, enraged, infuriated, hostile', 'tone': 'hostile and aggressive', 'emoji': '🤬'},
        'disgust': {'words': 'revolted, appalled, sickened, gross', 'tone': 'contemptuous and repulsed', 'emoji': '🤢'},
        'fear': {'words': 'terrified, anxious, frightened, alarmed', 'tone': 'anxious and unsettling', 'emoji': '😨'},
        'joy': {'words': 'thrilled, delighted, ecstatic, jubilant', 'tone': 'exuberant and cheerful', 'emoji': '😀'},
        'neutral': {'words': 'simple, straightforward, matter-of-fact', 'tone': 'neutral and informative', 'emoji': '😐'},
        'sadness': {'words': 'heartbroken, melancholy, sorrowful, dejected', 'tone': 'mournful and sorrowful', 'emoji': '😭'},
        'surprise': {'words': 'astonished, amazed, shocked, startled', 'tone': 'shocked and sudden', 'emoji': '😲'}
    }

    # Add few-shot examples for underperforming emotions
    examples = {
        'disgust': [
            {"tagalog": "Kadiri naman 'yan, ang baho!", "english": "How disgusting, that smells so bad!"},
            {"tagalog": "Nandidiri ako sa ginawa mo.", "english": "I'm revolted by what you did."}
        ],
        'joy': [
            {"tagalog": "Ang saya-saya ko ngayon!", "english": "I'm so incredibly happy right now!"},
            {"tagalog": "Aba, nanalo ako! Yahoo!", "english": "Oh my, I won! Yahoo!"}
        ]
    }

    guidance = emotion_guidance.get(dataset_emotion.lower())
    if not guidance:
        guidance = {'words': 'appropriate', 'tone': 'appropriate', 'emoji': ''}

    words_list = guidance['words']
    tone = guidance['tone']
    emoji = guidance['emoji']

    prompt = f"""You are a professional human translator specializing in the cultural and emotional nuances of the Tagalog language. Your job is not to provide a literal translation, but to translate the given text while maintaining the exact emotional tone of {dataset_emotion.upper()} {emoji}.

Follow these steps for a perfect translation:
1.  **Analyze**: Carefully read the Tagalog text and identify the specific words, idioms, or sentence structures that convey the emotion.
2.  **Translate**: Based on your analysis, provide a high-quality English translation that captures the required tone and emotion.
3.  **Finalize**: Ensure the translation is a single sentence or short phrase, without any extra commentary.

"""
    if dataset_emotion.lower() in examples:
        prompt += "Here are a few examples of how to handle this emotion:\n"
        for ex in examples[dataset_emotion.lower()]:
            prompt += f"Tagalog: {ex['tagalog']}\nEnglish Translation: {ex['english']}\n\n"

    prompt += f"""---
**Source Language:** Tagalog
**Target Language:** English
**Required Emotion:** {dataset_emotion.upper()} {emoji}
**Key Words to Use:** {words_list}
**Target Tone:** {tone}

**Tagalog Text:** {tagalog_text}

**Final English Translation:**"""

    return prompt


def clean_llm_output(text: str) -> str:
    """Clean translation output from LLM."""
    if not text:
        return ""
    text = text.strip().strip('"\'')
    if "**Final English Translation:**" in text:
        text = text.split("**Final English Translation:**")[-1].strip()
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

