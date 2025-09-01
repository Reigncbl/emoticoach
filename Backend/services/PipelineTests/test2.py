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
# 1. Load classifier
# -------------------------------
MODEL_PATH = r"C:\Users\John Carlo\emoticoach\emoticoach\Backend\AIModel\emotion_model"
try:
    tokenizer = AutoTokenizer.from_pretrained(MODEL_PATH)
    model = AutoModelForSequenceClassification.from_pretrained(MODEL_PATH)
    emotion_labels = list(model.config.id2label.values())
except FileNotFoundError:
    print(f"Error: Model files not found at {MODEL_PATH}")
    sys.exit(1)


def classify_emotions(texts: List[str]) -> List[Dict[str, Any]]:
    """Classify a list of texts and return predicted emotion with confidence."""
    results = []
    for text in texts:
        inputs = tokenizer(text, return_tensors="pt", truncation=True, padding=True, max_length=512)
        with torch.no_grad():
            outputs = model(**inputs)
            probs = F.softmax(outputs.logits, dim=1).squeeze()
        top_idx = probs.argmax().item()
        results.append({"emotion": emotion_labels[top_idx], "confidence": float(probs[top_idx])})
    return results


# -------------------------------
# 2. Advanced Emotion-aware translation prompt
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
        # Fallback for emotions not in the guidance dict
        guidance = {'words': 'appropriate', 'tone': 'appropriate', 'emoji': ''}

    words_list = guidance['words']
    tone = guidance['tone']
    emoji = guidance['emoji']

    # New prompt incorporating CoT and persona
    prompt = f"""You are a professional human translator specializing in the cultural and emotional nuances of the Tagalog language. Your job is not to provide a literal translation, but to translate the given text while maintaining the exact emotional tone of {dataset_emotion.upper()} {emoji}.

Follow these steps for a perfect translation:
1.  **Analyze**: Carefully read the Tagalog text and identify the specific words, idioms, or sentence structures that convey the emotion.
2.  **Translate**: Based on your analysis, provide a high-quality English translation that captures the required tone and emotion.
3.  **Finalize**: Ensure the translation is a single sentence or short phrase, without any extra commentary.

"""
    # Append examples if they exist for the current emotion
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
    # Remove any step-by-step thinking or commentary the LLM might have included
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


# -------------------------------
# 3. Evaluation pipeline with in-depth metrics
# -------------------------------
def evaluate_translation_preservation(
    tagalog_texts: List[str],
    dataset_emotions: List[str],
    groq_client: Groq,
    groq_model: str
) -> Dict[str, Any]:
    """
    Translate Tagalog texts to English and evaluate if classifier predicts same emotion as dataset label,
    with comprehensive metrics including a classification report and confidence analysis.
    """
    print("🎭 EVALUATING TRANSLATION EMOTION PRESERVATION")
    translated_texts, failures = translate_texts(tagalog_texts, dataset_emotions, groq_client, groq_model)

    english_results = classify_emotions(translated_texts)
    english_emotions = [r['emotion'] for r in english_results]
    english_confidences = [r['confidence'] for r in english_results]

    # Compare predicted English emotions with dataset labels
    preserved_flags = [pred == true for pred, true in zip(english_emotions, dataset_emotions)]
    preservation_rate = sum(preserved_flags) / len(tagalog_texts)

    # Per-emotion performance
    unique_emotions = sorted(list(set(dataset_emotions)))
    
    # 1. Classification Report
    print("\n📋 CLASSIFICATION REPORT:")
    report = classification_report(
        y_true=dataset_emotions,
        y_pred=english_emotions,
        labels=unique_emotions,
        zero_division=0,
        output_dict=True
    )
    report_df = pd.DataFrame(report).T
    print(report_df)

    # 2. Confusion Matrix
    print("\n📈 CONFUSION MATRIX:")
    print("Rows = True Emotion, Columns = Predicted Emotion")
    cm = confusion_matrix(dataset_emotions, english_emotions, labels=unique_emotions)
    df_cm = pd.DataFrame(cm, index=unique_emotions, columns=unique_emotions)
    print(df_cm)

    # 3. Confidence Analysis
    confidence_per_emotion = {emotion: [] for emotion in unique_emotions}
    for i, emotion in enumerate(dataset_emotions):
        confidence_per_emotion[emotion].append(english_confidences[i])
    
    mean_confidence = {
        emotion: np.mean(confidences) if confidences else 0
        for emotion, confidences in confidence_per_emotion.items()
    }

    print("\n⭐ MEAN CONFIDENCE PER EMOTION:")
    for emotion, conf in mean_confidence.items():
        print(f"{emotion:<12}: {conf:.2f}")

    # Final summary and return
    print(f"\n💾 Overall Preservation Rate (Accuracy): {preservation_rate*100:.1f}%")
    print(f"Failed Translations: {failures}")
    
    return {
        "preservation_rate": preservation_rate,
        "failed_translations": failures,
        "classification_report": report,
        "confusion_matrix": df_cm.to_dict(),
        "mean_confidence": mean_confidence,
        "analysis_data": [
            {
                'tagalog': tagalog_texts[i],
                'english': translated_texts[i],
                'dataset_emotion': dataset_emotions[i],
                'english_classified': english_emotions[i],
                'confidence': english_confidences[i],
                'preserved': preserved_flags[i]
            } for i in range(len(tagalog_texts))
        ]
    }


# -------------------------------
# 4. Main execution
# -------------------------------
if __name__ == "__main__":
    # Load environment variables
    load_dotenv()
    api_key = os.getenv('api_key')
    groq_model = os.getenv('model')

    if not api_key or not groq_model:
        raise ValueError("Please set GROQ_API_KEY and GROQ_MODEL in your .env")

    # Initialize Groq client
    client = Groq(api_key=api_key)
    
    # -------------------------------
    # Load EMOTERA-All dataset
    # -------------------------------
    dataset_path = r"C:\Users\John Carlo\Downloads\EMOTERA-All.tsv"
    try:
        df = pd.read_csv(dataset_path, sep='\t')
    except FileNotFoundError:
        print(f"Error: Dataset not found at {dataset_path}")
        sys.exit(1)

    # Keep only core classes recognized by your classifier
    core_classes = ["Anger", "Disgust", "Fear", "Joy", "Sadness", "Surprise"]
    df = df[df['emotion'].isin(core_classes)].reset_index(drop=True)

    # Random sample of 50
    sample_size = 50
    if len(df) < sample_size:
        print(f"Warning: Dataset size ({len(df)}) is less than sample size ({sample_size}). Using entire dataset.")
        sample_df = df
    else:
        sample_df = df.sample(n=sample_size, random_state=42).reset_index(drop=True)
    
    tagalog_texts = sample_df['tweet'].tolist()
    dataset_emotions = [
        # Map EMOTERA emotions to classifier labels (lowercase)
        {"Anger": "anger", "Disgust": "disgust", "Fear": "fear",
         "Joy": "joy", "Sadness": "sadness", "Surprise": "surprise"}[e]
        for e in sample_df['emotion']
    ]

    print(f"Loaded {len(tagalog_texts)} texts for evaluation.")

    # -------------------------------
    # Evaluate translation + emotion preservation
    # -------------------------------
    try:
        results = evaluate_translation_preservation(
            tagalog_texts=tagalog_texts,
            dataset_emotions=dataset_emotions,
            groq_client=client,
            groq_model=groq_model
        )
        print("\n🎉 Evaluation completed successfully!")
        print(f"Processed {len(tagalog_texts)} samples")
    except Exception as e:
        print(f"❌ Evaluation failed: {e}")
        sys.exit(1)