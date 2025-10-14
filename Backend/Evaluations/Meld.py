from datasets import load_dataset
from transformers import pipeline, AutoTokenizer, AutoModelForSequenceClassification
import torch
import pandas as pd
from sklearn.metrics import (
    accuracy_score, precision_score, recall_score, f1_score,
    classification_report, confusion_matrix
)
import numpy as np
from datetime import datetime
import time

# 1. Load the MELD dataset or create a custom evaluation set
# The model predicts 7 emotions: anger, disgust, fear, joy, neutral, sadness, surprise
# Note: The "emotion" dataset only has 6 classes (missing disgust and neutral)
# For a complete benchmark, we should evaluate on all 7 emotion classes

# For now, we'll use the emotion dataset but note the limitation
dataset = load_dataset("emotion", split="test")

# 2. Initialize the model and tokenizer
model_name = "j-hartmann/emotion-english-distilroberta-base"
print("="*80)
print("EMOTION CLASSIFICATION MODEL BENCHMARK - CAPSTONE PROJECT")
print("="*80)
print(f"Model: {model_name}")
print(f"Dataset: emotion (test split)")
print(f"Date: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
print(f"Device: {'GPU' if torch.cuda.is_available() else 'CPU'}")
print("\nModel Emotion Classes:")
print("  🤬 anger | 🤢 disgust | 😨 fear | 😀 joy | 😐 neutral | 😭 sadness | 😲 surprise")
print("="*80)
print("\nLoading model and tokenizer...")

tokenizer = AutoTokenizer.from_pretrained(model_name)
model = AutoModelForSequenceClassification.from_pretrained(model_name)
device = 0 if torch.cuda.is_available() else -1
classifier = pipeline("text-classification", model=model, tokenizer=tokenizer, device=device)

# 3. Predict on the test dataset
# Convert dataset["text"] to a Python list for the classifier
text_list = list(dataset["text"])
print(f"\nRunning predictions on {len(text_list)} test samples...")
start_time = time.time()
predictions = classifier(text_list)
inference_time = time.time() - start_time
print(f"Inference completed in {inference_time:.2f} seconds")
print(f"Average time per sample: {(inference_time/len(text_list))*1000:.2f} ms")

# 4. Extract predictions and true labels
predicted_labels = [p['label'] for p in predictions]
confidence_scores = [p['score'] for p in predictions]
true_labels = [dataset.features["label"].int2str(label) for label in dataset["label"]]

# 5. Calculate comprehensive metrics
print("\n" + "="*80)
print("EVALUATION METRICS")
print("="*80)

# Overall metrics
accuracy = accuracy_score(true_labels, predicted_labels)
precision_macro = precision_score(true_labels, predicted_labels, average="macro", zero_division=0)
recall_macro = recall_score(true_labels, predicted_labels, average="macro", zero_division=0)
f1_macro = f1_score(true_labels, predicted_labels, average="macro", zero_division=0)

precision_weighted = precision_score(true_labels, predicted_labels, average="weighted", zero_division=0)
recall_weighted = recall_score(true_labels, predicted_labels, average="weighted", zero_division=0)
f1_weighted = f1_score(true_labels, predicted_labels, average="weighted", zero_division=0)

# Overall metrics table
print("\n1. OVERALL PERFORMANCE METRICS")
print("-"*80)
overall_metrics = pd.DataFrame({
    'Metric': ['Accuracy', 'Precision (Macro)', 'Recall (Macro)', 'F1-Score (Macro)',
               'Precision (Weighted)', 'Recall (Weighted)', 'F1-Score (Weighted)'],
    'Score': [accuracy, precision_macro, recall_macro, f1_macro,
              precision_weighted, recall_weighted, f1_weighted]
})
overall_metrics['Score'] = overall_metrics['Score'].apply(lambda x: f"{x:.4f}")
print(overall_metrics.to_string(index=False))

# Per-class metrics
print("\n2. PER-CLASS PERFORMANCE METRICS")
print("-"*80)
# Define emoji mapping for emotions
emotion_emojis = {
    'anger': '🤬',
    'disgust': '🤢',
    'fear': '😨',
    'joy': '😀',
    'neutral': '😐',
    'sadness': '😭',
    'surprise': '😲'
}

class_report = classification_report(true_labels, predicted_labels, output_dict=True, zero_division=0)
class_metrics = []

# Get all emotions from both predictions and true labels
all_emotions = sorted(set(true_labels + predicted_labels))

for emotion in all_emotions:
    if emotion in class_report:
        emoji = emotion_emojis.get(emotion, '❓')
        support = int(class_report[emotion]['support'])
        note = ""
        if support == 0:
            note = " (not in dataset)"
        
        class_metrics.append({
            'Emotion': f"{emoji} {emotion.capitalize()}{note}",
            'Precision': f"{class_report[emotion]['precision']:.4f}",
            'Recall': f"{class_report[emotion]['recall']:.4f}",
            'F1-Score': f"{class_report[emotion]['f1-score']:.4f}",
            'Support': support
        })

class_df = pd.DataFrame(class_metrics)
print(class_df.to_string(index=False))

# Confusion Matrix
print("\n3. CONFUSION MATRIX")
print("-"*80)
# Get all unique labels from both true and predicted
all_labels = sorted(set(true_labels + predicted_labels))
cm = confusion_matrix(true_labels, predicted_labels, labels=all_labels)
cm_df = pd.DataFrame(cm, index=all_labels, columns=all_labels)
print("True Labels (rows) vs Predicted Labels (columns):")
print(cm_df)

# Confidence score analysis
print("\n4. CONFIDENCE SCORE ANALYSIS")
print("-"*80)
avg_confidence = np.mean(confidence_scores)
std_confidence = np.std(confidence_scores)
min_confidence = np.min(confidence_scores)
max_confidence = np.max(confidence_scores)

confidence_stats = pd.DataFrame({
    'Statistic': ['Mean Confidence', 'Std Deviation', 'Min Confidence', 'Max Confidence'],
    'Value': [f"{avg_confidence:.4f}", f"{std_confidence:.4f}", 
              f"{min_confidence:.4f}", f"{max_confidence:.4f}"]
})
print(confidence_stats.to_string(index=False))

# Error analysis
print("\n5. ERROR ANALYSIS")
print("-"*80)
correct_predictions = sum([1 for t, p in zip(true_labels, predicted_labels) if t == p])
incorrect_predictions = len(true_labels) - correct_predictions
error_rate = (incorrect_predictions / len(true_labels)) * 100

error_stats = pd.DataFrame({
    'Category': ['Correct Predictions', 'Incorrect Predictions', 'Total Samples', 'Error Rate'],
    'Value': [correct_predictions, incorrect_predictions, len(true_labels), f"{error_rate:.2f}%"]
})
print(error_stats.to_string(index=False))

# Model Information
print("\n6. MODEL INFORMATION")
print("-"*80)
model_info = pd.DataFrame({
    'Property': ['Model Name', 'Architecture', 'Parameters', 'Framework', 
                 'Dataset Size', 'Inference Time', 'Avg Time/Sample'],
    'Value': [model_name, 'DistilRoBERTa', '82M (distilled)', 'PyTorch/Transformers',
              f"{len(text_list)} samples", f"{inference_time:.2f}s", 
              f"{(inference_time/len(text_list))*1000:.2f}ms"]
})
print(model_info.to_string(index=False))

# Dataset coverage analysis
print("\n7. DATASET COVERAGE ANALYSIS")
print("-"*80)
print("Model supports 7 emotion classes:")
print("  🤬 anger | 🤢 disgust | 😨 fear | 😀 joy | 😐 neutral | 😭 sadness | 😲 surprise")
print("\nDataset 'emotion' contains 6 emotion classes:")
dataset_emotions = sorted(set(true_labels))
print(f"  {' | '.join([emotion_emojis.get(e, '❓') + ' ' + e for e in dataset_emotions])}")
print("\nNote: The dataset is missing 'disgust' and 'neutral' classes.")
print("      This may affect the model's ability to demonstrate full capability.")

# Summary
print("\n" + "="*80)
print("BENCHMARK SUMMARY")
print("="*80)
print(f"✓ Model successfully evaluated on {len(text_list)} test samples")
print(f"✓ Overall Accuracy: {accuracy*100:.2f}%")
print(f"✓ Macro F1-Score: {f1_macro*100:.2f}%")
print(f"✓ Weighted F1-Score: {f1_weighted*100:.2f}%")
print(f"✓ Average Inference Time: {(inference_time/len(text_list))*1000:.2f}ms per sample")
print(f"✓ Dataset Coverage: {len(dataset_emotions)}/7 emotion classes")
print("="*80)

# Save results to file
output_file = "emotion_model_benchmark_results.txt"
with open(output_file, 'w') as f:
    f.write("="*80 + "\n")
    f.write("EMOTION CLASSIFICATION MODEL BENCHMARK - CAPSTONE PROJECT\n")
    f.write("="*80 + "\n")
    f.write(f"Date: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")
    f.write(f"Model: {model_name}\n")
    f.write(f"Overall Accuracy: {accuracy*100:.2f}%\n")
    f.write(f"Macro F1-Score: {f1_macro*100:.2f}%\n")
    f.write(f"Weighted F1-Score: {f1_weighted*100:.2f}%\n")
    f.write("\nDetailed results saved in this report.\n")

print(f"\n✓ Results saved to: {output_file}")