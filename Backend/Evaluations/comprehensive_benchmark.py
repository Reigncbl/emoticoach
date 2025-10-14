"""
Comprehensive Emotion Classification Benchmark - Capstone Project
Tests the emotion model on multiple standard benchmark datasets
"""

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
import warnings
warnings.filterwarnings('ignore')

# Emotion emoji mapping
EMOTION_EMOJIS = {
    'anger': '🤬', 'disgust': '🤢', 'fear': '😨', 'joy': '😀',
    'neutral': '😐', 'sadness': '😭', 'surprise': '😲',
    'love': '❤️', 'happiness': '😊', 'happy': '😊'
}

def print_header():
    """Print benchmark header"""
    print("="*100)
    print("COMPREHENSIVE EMOTION CLASSIFICATION BENCHMARK - CAPSTONE PROJECT")
    print("="*100)
    print(f"Date: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print(f"Device: {'GPU (CUDA)' if torch.cuda.is_available() else 'CPU'}")
    print("\nModel Emotion Classes:")
    print("  🤬 anger | 🤢 disgust | 😨 fear | 😀 joy | 😐 neutral | 😭 sadness | 😲 surprise")
    print("="*100)

def evaluate_on_dataset(classifier, dataset_name, split_name, text_col, label_col, label_mapping=None):
    """
    Evaluate the model on a specific dataset
    
    Args:
        classifier: The emotion classification pipeline
        dataset_name: Name of the dataset on HuggingFace
        split_name: Split to evaluate on (e.g., 'test', 'validation')
        text_col: Column name for text
        label_col: Column name for labels
        label_mapping: Optional mapping from dataset labels to model labels
    """
    print(f"\n{'='*100}")
    print(f"EVALUATING ON: {dataset_name} ({split_name} split)")
    print(f"{'='*100}")
    
    try:
        # Load dataset
        print(f"Loading {dataset_name}...")
        # Try loading with config if it's tweet_eval
        if 'tweet_eval' in dataset_name.lower():
            dataset = load_dataset(dataset_name, 'emotion', split=split_name)
        else:
            dataset = load_dataset(dataset_name, split=split_name)
        
        # Extract text and labels
        if text_col in dataset.column_names:
            text_list = list(dataset[text_col])
        else:
            print(f"❌ Column '{text_col}' not found. Available columns: {dataset.column_names}")
            return None
        
        # Get true labels
        if label_col in dataset.column_names:
            if hasattr(dataset.features[label_col], 'int2str'):
                true_labels = [dataset.features[label_col].int2str(label) for label in dataset[label_col]]
            else:
                true_labels = list(dataset[label_col])
        else:
            print(f"❌ Column '{label_col}' not found. Available columns: {dataset.column_names}")
            return None
        
        # Apply label mapping if provided
        if label_mapping:
            true_labels = [label_mapping.get(label.lower(), label.lower()) for label in true_labels]
        
        print(f"Dataset size: {len(text_list)} samples")
        print(f"Unique labels in dataset: {sorted(set(true_labels))}")
        
        # Run predictions
        print(f"Running predictions...")
        start_time = time.time()
        
        # Process in batches to avoid memory issues
        batch_size = 32
        predictions = []
        for i in range(0, len(text_list), batch_size):
            batch = text_list[i:i+batch_size]
            predictions.extend(classifier(batch))
        
        inference_time = time.time() - start_time
        print(f"✓ Inference completed in {inference_time:.2f}s (avg: {(inference_time/len(text_list))*1000:.2f}ms/sample)")
        
        # Extract predictions
        predicted_labels = [p['label'] for p in predictions]
        confidence_scores = [p['score'] for p in predictions]
        
        # Calculate metrics
        accuracy = accuracy_score(true_labels, predicted_labels)
        precision_macro = precision_score(true_labels, predicted_labels, average="macro", zero_division=0)
        recall_macro = recall_score(true_labels, predicted_labels, average="macro", zero_division=0)
        f1_macro = f1_score(true_labels, predicted_labels, average="macro", zero_division=0)
        f1_weighted = f1_score(true_labels, predicted_labels, average="weighted", zero_division=0)
        
        # Print results
        print(f"\n📊 RESULTS:")
        print(f"  ✓ Accuracy:       {accuracy*100:.2f}%")
        print(f"  ✓ F1-Score (Macro):    {f1_macro*100:.2f}%")
        print(f"  ✓ F1-Score (Weighted): {f1_weighted*100:.2f}%")
        print(f"  ✓ Precision (Macro):   {precision_macro*100:.2f}%")
        print(f"  ✓ Recall (Macro):      {recall_macro*100:.2f}%")
        print(f"  ✓ Avg Confidence:      {np.mean(confidence_scores)*100:.2f}%")
        
        # Per-class performance
        print(f"\n📈 PER-CLASS PERFORMANCE:")
        class_report = classification_report(true_labels, predicted_labels, output_dict=True, zero_division=0)
        
        class_data = []
        for emotion in sorted(set(true_labels + predicted_labels)):
            if emotion in class_report and emotion not in ['accuracy', 'macro avg', 'weighted avg']:
                emoji = EMOTION_EMOJIS.get(emotion, '❓')
                support = int(class_report[emotion]['support'])
                class_data.append({
                    'Emotion': f"{emoji} {emotion}",
                    'Precision': f"{class_report[emotion]['precision']:.3f}",
                    'Recall': f"{class_report[emotion]['recall']:.3f}",
                    'F1-Score': f"{class_report[emotion]['f1-score']:.3f}",
                    'Support': support
                })
        
        class_df = pd.DataFrame(class_data)
        print(class_df.to_string(index=False))
        
        return {
            'dataset': dataset_name,
            'split': split_name,
            'samples': len(text_list),
            'accuracy': accuracy,
            'f1_macro': f1_macro,
            'f1_weighted': f1_weighted,
            'precision_macro': precision_macro,
            'recall_macro': recall_macro,
            'inference_time': inference_time,
            'avg_confidence': np.mean(confidence_scores)
        }
        
    except Exception as e:
        print(f"❌ Error evaluating {dataset_name}: {str(e)}")
        return None

def main():
    """Main benchmark function"""
    print_header()
    
    # Initialize model
    model_name = "j-hartmann/emotion-english-distilroberta-base"
    print(f"\n📦 Loading model: {model_name}")
    
    tokenizer = AutoTokenizer.from_pretrained(model_name)
    model = AutoModelForSequenceClassification.from_pretrained(model_name)
    device = 0 if torch.cuda.is_available() else -1
    classifier = pipeline("text-classification", model=model, tokenizer=tokenizer, device=device)
    print("✓ Model loaded successfully")
    
    # Store results
    all_results = []
    
    # 1. Emotion Dataset (Go Emotions subset)
    result = evaluate_on_dataset(
        classifier=classifier,
        dataset_name="emotion",
        split_name="test",
        text_col="text",
        label_col="label"
    )
    if result:
        all_results.append(result)
    
    # 2. TweetEval Emotion (Twitter emotion classification)
    try:
        print("\n⚠️  Loading TweetEval emotion dataset...")
        result = evaluate_on_dataset(
            classifier=classifier,
            dataset_name="cardiffnlp/tweet_eval",
            split_name="test",
            text_col="text",
            label_col="label",
        )
        if result:
            all_results.append(result)
    except Exception as e:
        print(f"⚠️  TweetEval dataset skipped: {str(e)}")
    
    # 3. GoEmotions (Google Emotions dataset - 27 emotions)
    try:
        print("\n⚠️  Loading GoEmotions dataset...")
        result = evaluate_on_dataset(
            classifier=classifier,
            dataset_name="google-research-datasets/go_emotions",
            split_name="test",
            text_col="text",
            label_col="labels",
        )
        if result:
            all_results.append(result)
    except Exception as e:
        print(f"⚠️  GoEmotions dataset skipped: {str(e)}")
    
    # 4. Emotion (dair-ai - another emotion dataset)
    try:
        print("\n⚠️  Loading additional emotion dataset...")
        result = evaluate_on_dataset(
            classifier=classifier,
            dataset_name="dair-ai/emotion",
            split_name="test",
            text_col="text",
            label_col="label",
        )
        if result:
            all_results.append(result)
    except Exception as e:
        print(f"⚠️  Additional emotion dataset skipped: {str(e)}")
    
    # Print summary
    print("\n" + "="*100)
    print("📊 BENCHMARK SUMMARY - ALL DATASETS")
    print("="*100)
    
    if all_results:
        summary_df = pd.DataFrame(all_results)
        summary_df['accuracy'] = summary_df['accuracy'].apply(lambda x: f"{x*100:.2f}%")
        summary_df['f1_macro'] = summary_df['f1_macro'].apply(lambda x: f"{x*100:.2f}%")
        summary_df['f1_weighted'] = summary_df['f1_weighted'].apply(lambda x: f"{x*100:.2f}%")
        summary_df['avg_confidence'] = summary_df['avg_confidence'].apply(lambda x: f"{x*100:.2f}%")
        summary_df['inference_time'] = summary_df['inference_time'].apply(lambda x: f"{x:.2f}s")
        
        print("\n" + summary_df.to_string(index=False))
        
        # Save to file
        output_file = "comprehensive_emotion_benchmark_results.csv"
        pd.DataFrame(all_results).to_csv(output_file, index=False)
        print(f"\n✓ Detailed results saved to: {output_file}")
        
        # Save summary report
        report_file = "benchmark_summary_report.txt"
        with open(report_file, 'w', encoding='utf-8') as f:
            f.write("="*100 + "\n")
            f.write("COMPREHENSIVE EMOTION CLASSIFICATION BENCHMARK - CAPSTONE PROJECT\n")
            f.write("="*100 + "\n")
            f.write(f"Date: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")
            f.write(f"Model: {model_name}\n\n")
            f.write("SUMMARY OF RESULTS:\n")
            f.write("-"*100 + "\n")
            for result in all_results:
                f.write(f"\nDataset: {result['dataset']} ({result['split']})\n")
                f.write(f"  Samples: {result['samples']}\n")
                f.write(f"  Accuracy: {result['accuracy']*100:.2f}%\n")
                f.write(f"  F1-Score (Macro): {result['f1_macro']*100:.2f}%\n")
                f.write(f"  F1-Score (Weighted): {result['f1_weighted']*100:.2f}%\n")
                f.write(f"  Inference Time: {result['inference_time']:.2f}s\n")
        
        print(f"✓ Summary report saved to: {report_file}")
    else:
        print("❌ No results to display")
    
    print("\n" + "="*100)
    print("✓ BENCHMARK COMPLETE")
    print("="*100)

if __name__ == "__main__":
    main()
