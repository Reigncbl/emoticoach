"""
Comprehensive Model Comparison Benchmark - Capstone Project
Compares three emotion classification models on the same test dataset
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
import matplotlib.pyplot as plt
import seaborn as sns
warnings.filterwarnings('ignore')

# Set style for better-looking plots
plt.style.use('seaborn-v0_8-darkgrid')
sns.set_palette("husl")

# Emotion emoji mapping - Standardized to emotion dataset classes
EMOTION_EMOJIS = {
    'anger': '🤬',
    'disgust': '🤢',
    'fear': '😨',
    'joy': '😀',
    'sadness': '😭',
    'surprise': '😲',
    # Additional mappings for model outputs
    'happy': '😀',
    'happiness': '😀',
    'neutral': '😐',
    'sad': '😭',
    'love': '❤️'
}

# Label mapping to standardize to 7 target classes
# Target classes: anger, disgust, fear, joy, sadness, surprise, neutral
LABEL_MAPPING = {
    # Standard emotion dataset labels (keep as-is)
    'anger': 'anger',
    'disgust': 'disgust',
    'fear': 'fear',
    'joy': 'joy',
    'sadness': 'sadness',
    'surprise': 'surprise',
    'neutral': 'neutral',
    # Map model variants to standard labels
    'happy': 'joy',
    'happiness': 'joy',
    'sad': 'sadness',
    'love': 'joy',  # Map love to joy as closest emotion
    # Additional mappings for LABEL_ prefix (from custom XLM-RoBERTa model)
    'label_0': 'joy',      # happiness -> joy
    'label_1': 'sadness',  # sadness
    'label_2': 'anger',
    'label_3': 'fear',
    'label_4': 'joy',      # love -> joy
    'label_5': 'neutral',  # neutral
    'label_6': 'surprise',
    'label_7': 'disgust'
}

# Models to compare
MODELS = [
    {
        'name': 'Custom XLM-RoBERTa (Emoticoach)',
        'model_id': r'C:\Users\John Carlo\emoticoach\emoticoach\Backend\AIModel',  # Absolute path
        'params': '~278M',
        'architecture': 'XLM-RoBERTa-Base',
        'is_local': True
    },
    {
        'name': 'RoBERTa-Large',
        'model_id': 'j-hartmann/emotion-english-roberta-large',
        'params': '~355M',
        'architecture': 'RoBERTa-Large',
        'is_local': False
    },
    {
        'name': 'DistilRoBERTa-Base',
        'model_id': 'j-hartmann/emotion-english-distilroberta-base',
        'params': '~82M',
        'architecture': 'DistilRoBERTa-Base',
        'is_local': False
    },
    {
        'name': 'DeBERTa-v3-Large',
        'model_id': 'Tanneru/Emotion-Classification-DeBERTa-v3-Large',
        'params': '~434M',
        'architecture': 'DeBERTa-v3-Large',
        'is_local': False
    }
]

def print_header():
    """Print benchmark header"""
    print("="*100)
    print("EMOTION CLASSIFICATION MODEL COMPARISON BENCHMARK - CAPSTONE PROJECT")
    print("="*100)
    print(f"Date: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print(f"Device: {'GPU (CUDA)' if torch.cuda.is_available() else 'CPU'}")
    print(f"\n📊 COMPREHENSIVE MULTI-DATASET EVALUATION")
    print("\nTest Datasets:")
    print("  1. dair-ai/emotion - https://huggingface.co/datasets/dair-ai/emotion")
    print("  2. cardiffnlp/tweet_eval (emotion) - https://huggingface.co/datasets/cardiffnlp/tweet_eval")
    print("  3. SetFit/go_emotions - https://huggingface.co/datasets/SetFit/go_emotions")
    print("  4. mrm8488/goemotions (full) - https://huggingface.co/datasets/mrm8488/goemotions")
    print("\nTarget Emotion Classes:")
    print("  🤬 anger | 🤢 disgust | 😨 fear | 😀 joy | 😐 neutral | � sadness | 😲 surprise | ❤️ love")
    print("\nNote: Labels are mapped to standardized emotion classes for consistent comparison")
    print(f"\nModels being compared ({len(MODELS)} models):")
    for i, model in enumerate(MODELS, 1):
        model_type = " [LOCAL]" if model.get('is_local', False) else ""
        print(f"  {i}. {model['name']} ({model['params']}){model_type}")
        print(f"     {model['model_id']}")
    print("="*100)

def evaluate_model(model_info, dataset):
    """
    Evaluate a single model on the dataset
    
    Args:
        model_info: Dictionary containing model information
        dataset: The test dataset
    
    Returns:
        Dictionary with evaluation results
    """
    print(f"\n{'='*100}")
    print(f"EVALUATING: {model_info['name']} ({model_info['architecture']})")
    print(f"Model ID: {model_info['model_id']}")
    print(f"Parameters: {model_info['params']}")
    print(f"{'='*100}")
    
    try:
        # Load model and tokenizer
        print("Loading model and tokenizer...")
        start_load_time = time.time()
        
        # Check if it's a local model
        is_local = model_info.get('is_local', False)
        model_path = model_info['model_id']
        
        if is_local:
            print(f"Loading local model from: {model_path}")
            # For local models, ensure the path is absolute and normalized
            import os
            if not os.path.isabs(model_path):
                model_path = os.path.abspath(model_path)
            # Normalize path to handle spaces and special characters
            model_path = os.path.normpath(model_path)
            print(f"Normalized path: {model_path}")
            
            # Check if directory exists
            if not os.path.isdir(model_path):
                raise FileNotFoundError(f"Model directory not found: {model_path}")
            
            # Load tokenizer and model locally (same approach as AI_inferenece.py)
            tokenizer = AutoTokenizer.from_pretrained(model_path, local_files_only=True)
            model = AutoModelForSequenceClassification.from_pretrained(model_path, local_files_only=True)
            print(f"✓ Loaded local model successfully")
        else:
            # Load from HuggingFace Hub
            tokenizer = AutoTokenizer.from_pretrained(model_path)
            model = AutoModelForSequenceClassification.from_pretrained(model_path)
        
        device = 0 if torch.cuda.is_available() else -1
        classifier = pipeline("text-classification", model=model, tokenizer=tokenizer, device=device)
        load_time = time.time() - start_load_time
        print(f"✓ Model loaded in {load_time:.2f}s")
        
        # Prepare data - emotion dataset uses 'text' and 'label'
        if "text" not in dataset.column_names:
            raise ValueError(f"Dataset missing 'text' column. Available: {dataset.column_names}")
        
        if "label" not in dataset.column_names:
            raise ValueError(f"Dataset missing 'label' column. Available: {dataset.column_names}")
        
        text_list = list(dataset["text"])
        
        # Get labels - emotion dataset uses integer labels
        if hasattr(dataset.features["label"], 'int2str'):
            true_labels_raw = [dataset.features["label"].int2str(label) for label in dataset["label"]]
        else:
            true_labels_raw = list(dataset["label"])
        
        # Keep labels as-is (no mapping needed for true labels since they're already standard)
        true_labels = [str(label).lower() for label in true_labels_raw]
        
        print(f"✓ Using emotion dataset with {len(text_list)} samples")
        print(f"✓ Found {len(set(true_labels))} unique emotion classes: {sorted(set(true_labels))}")
        
        # Run predictions
        print(f"Running predictions on {len(text_list)} samples...")
        start_time = time.time()
        
        # Process in batches for memory efficiency
        batch_size = 32
        predictions = []
        for i in range(0, len(text_list), batch_size):
            batch = text_list[i:i+batch_size]
            predictions.extend(classifier(batch))
            if (i // batch_size + 1) % 10 == 0:
                print(f"  Progress: {i+len(batch)}/{len(text_list)} samples processed...")
        
        inference_time = time.time() - start_time
        avg_time_per_sample = (inference_time / len(text_list)) * 1000
        
        print(f"✓ Inference completed in {inference_time:.2f}s")
        print(f"✓ Average time per sample: {avg_time_per_sample:.2f}ms")
        
        # Extract predictions and map to standardized emotion classes
        predicted_labels_raw = [p['label'] for p in predictions]
        predicted_labels = [LABEL_MAPPING.get(label.lower(), label.lower()) for label in predicted_labels_raw]
        confidence_scores = [p['score'] for p in predictions]
        
        # Verify classes match the 7 target classes
        standard_classes = {'anger', 'disgust', 'fear', 'joy', 'neutral', 'sadness', 'surprise'}
        unique_predicted = set(predicted_labels)
        unique_true = set(true_labels)
        
        print(f"✓ Predicted classes: {sorted(unique_predicted)}")
        print(f"✓ True classes: {sorted(unique_true)}")
        
        # Check for unmapped labels
        unmapped_pred = unique_predicted - standard_classes
        unmapped_true = unique_true - standard_classes
        if unmapped_pred:
            print(f"⚠️  Warning: Unmapped predicted labels: {unmapped_pred}")
        if unmapped_true:
            print(f"⚠️  Warning: Unmapped true labels: {unmapped_true}")
        
        # Calculate metrics
        accuracy = accuracy_score(true_labels, predicted_labels)
        precision_macro = precision_score(true_labels, predicted_labels, average="macro", zero_division=0)
        recall_macro = recall_score(true_labels, predicted_labels, average="macro", zero_division=0)
        f1_macro = f1_score(true_labels, predicted_labels, average="macro", zero_division=0)
        
        precision_weighted = precision_score(true_labels, predicted_labels, average="weighted", zero_division=0)
        recall_weighted = recall_score(true_labels, predicted_labels, average="weighted", zero_division=0)
        f1_weighted = f1_score(true_labels, predicted_labels, average="weighted", zero_division=0)
        
        avg_confidence = np.mean(confidence_scores)
        
        # Calculate error metrics
        correct_predictions = sum([1 for t, p in zip(true_labels, predicted_labels) if t == p])
        incorrect_predictions = len(true_labels) - correct_predictions
        error_rate = (incorrect_predictions / len(true_labels)) * 100
        
        # Print summary results
        print(f"\n📊 PERFORMANCE SUMMARY:")
        print(f"  ✓ Accuracy:            {accuracy*100:.2f}%")
        print(f"  ✓ F1-Score (Macro):    {f1_macro*100:.2f}%")
        print(f"  ✓ F1-Score (Weighted): {f1_weighted*100:.2f}%")
        print(f"  ✓ Precision (Macro):   {precision_macro*100:.2f}%")
        print(f"  ✓ Recall (Macro):      {recall_macro*100:.2f}%")
        print(f"  ✓ Average Confidence:  {avg_confidence*100:.2f}%")
        print(f"  ✓ Error Rate:          {error_rate:.2f}%")
        
        # Per-class performance
        print(f"\n📈 PER-CLASS PERFORMANCE:")
        class_report = classification_report(true_labels, predicted_labels, output_dict=True, zero_division=0)
        
        class_data = []
        all_emotions = sorted(set(true_labels + predicted_labels))
        
        for emotion in all_emotions:
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
        
        # Clean up to free memory
        del model
        del classifier
        torch.cuda.empty_cache() if torch.cuda.is_available() else None
        
        return {
            'model_name': model_info['name'],
            'model_id': model_info['model_id'],
            'architecture': model_info['architecture'],
            'parameters': model_info['params'],
            'accuracy': accuracy,
            'f1_macro': f1_macro,
            'f1_weighted': f1_weighted,
            'precision_macro': precision_macro,
            'precision_weighted': precision_weighted,
            'recall_macro': recall_macro,
            'recall_weighted': recall_weighted,
            'avg_confidence': avg_confidence,
            'error_rate': error_rate,
            'correct_predictions': correct_predictions,
            'incorrect_predictions': incorrect_predictions,
            'inference_time': inference_time,
            'avg_time_per_sample_ms': avg_time_per_sample,
            'load_time': load_time,
            'per_class_metrics': class_data
        }
        
    except Exception as e:
        print(f"❌ Error evaluating {model_info['name']}: {str(e)}")
        import traceback
        traceback.print_exc()
        return None

def create_comparison_tables(results):
    """Create comparison tables from results"""
    
    print("\n" + "="*100)
    print("📊 COMPARATIVE ANALYSIS - ALL MODELS")
    print("="*100)
    
    # Overall Performance Comparison
    print("\n1. OVERALL PERFORMANCE COMPARISON")
    print("-"*100)
    
    comparison_data = []
    for result in results:
        comparison_data.append({
            'Model': result['model_name'],
            'Architecture': result['architecture'],
            'Parameters': result['parameters'],
            'Accuracy': f"{result['accuracy']*100:.2f}%",
            'F1-Macro': f"{result['f1_macro']*100:.2f}%",
            'F1-Weighted': f"{result['f1_weighted']*100:.2f}%",
            'Avg Confidence': f"{result['avg_confidence']*100:.2f}%",
            'Error Rate': f"{result['error_rate']:.2f}%"
        })
    
    comparison_df = pd.DataFrame(comparison_data)
    print(comparison_df.to_string(index=False))
    
    # Speed Comparison
    print("\n2. INFERENCE SPEED COMPARISON")
    print("-"*100)
    
    speed_data = []
    for result in results:
        speed_data.append({
            'Model': result['model_name'],
            'Load Time': f"{result['load_time']:.2f}s",
            'Total Inference': f"{result['inference_time']:.2f}s",
            'Avg per Sample': f"{result['avg_time_per_sample_ms']:.2f}ms",
            'Samples/Second': f"{2000/result['inference_time']:.2f}"
        })
    
    speed_df = pd.DataFrame(speed_data)
    print(speed_df.to_string(index=False))
    
    # Detailed Metrics Comparison
    print("\n3. DETAILED METRICS COMPARISON")
    print("-"*100)
    
    detailed_data = []
    for result in results:
        detailed_data.append({
            'Model': result['model_name'],
            'Precision (Macro)': f"{result['precision_macro']*100:.2f}%",
            'Recall (Macro)': f"{result['recall_macro']*100:.2f}%",
            'Precision (Weighted)': f"{result['precision_weighted']*100:.2f}%",
            'Recall (Weighted)': f"{result['recall_weighted']*100:.2f}%",
            'Correct': result['correct_predictions'],
            'Incorrect': result['incorrect_predictions']
        })
    
    detailed_df = pd.DataFrame(detailed_data)
    print(detailed_df.to_string(index=False))
    
    # Best Model Analysis
    print("\n4. BEST MODEL ANALYSIS")
    print("-"*100)
    
    best_accuracy = max(results, key=lambda x: x['accuracy'])
    best_f1_macro = max(results, key=lambda x: x['f1_macro'])
    best_f1_weighted = max(results, key=lambda x: x['f1_weighted'])
    fastest = min(results, key=lambda x: x['avg_time_per_sample_ms'])
    
    print(f"🏆 Best Accuracy:       {best_accuracy['model_name']} ({best_accuracy['accuracy']*100:.2f}%)")
    print(f"🏆 Best F1-Macro:       {best_f1_macro['model_name']} ({best_f1_macro['f1_macro']*100:.2f}%)")
    print(f"🏆 Best F1-Weighted:    {best_f1_weighted['model_name']} ({best_f1_weighted['f1_weighted']*100:.2f}%)")
    print(f"⚡ Fastest Inference:   {fastest['model_name']} ({fastest['avg_time_per_sample_ms']:.2f}ms/sample)")
    
    return comparison_df, speed_df, detailed_df

def create_visualizations(results):
    """Create comparison visualizations"""
    print("\n5. GENERATING COMPARISON CHARTS")
    print("-"*100)
    
    # Extract model names for plotting
    model_names = [r['model_name'] for r in results]
    
    # Create figure with subplots
    fig = plt.figure(figsize=(20, 12))
    
    # 1. Overall Performance Metrics Comparison (Bar Chart)
    ax1 = plt.subplot(2, 3, 1)
    metrics = ['accuracy', 'f1_macro', 'f1_weighted']
    metric_labels = ['Accuracy', 'F1-Macro', 'F1-Weighted']
    x = np.arange(len(model_names))
    width = 0.25
    
    for i, (metric, label) in enumerate(zip(metrics, metric_labels)):
        values = [r[metric] * 100 for r in results]
        ax1.bar(x + i*width, values, width, label=label, alpha=0.8)
    
    ax1.set_xlabel('Models', fontsize=12, fontweight='bold')
    ax1.set_ylabel('Score (%)', fontsize=12, fontweight='bold')
    ax1.set_title('Overall Performance Comparison', fontsize=14, fontweight='bold')
    ax1.set_xticks(x + width)
    ax1.set_xticklabels(model_names, rotation=15, ha='right')
    ax1.legend()
    ax1.grid(axis='y', alpha=0.3)
    ax1.set_ylim([0, 100])
    
    # 2. Precision and Recall Comparison
    ax2 = plt.subplot(2, 3, 2)
    precision_macro = [r['precision_macro'] * 100 for r in results]
    recall_macro = [r['recall_macro'] * 100 for r in results]
    
    x = np.arange(len(model_names))
    width = 0.35
    ax2.bar(x - width/2, precision_macro, width, label='Precision (Macro)', alpha=0.8)
    ax2.bar(x + width/2, recall_macro, width, label='Recall (Macro)', alpha=0.8)
    
    ax2.set_xlabel('Models', fontsize=12, fontweight='bold')
    ax2.set_ylabel('Score (%)', fontsize=12, fontweight='bold')
    ax2.set_title('Precision vs Recall Comparison', fontsize=14, fontweight='bold')
    ax2.set_xticks(x)
    ax2.set_xticklabels(model_names, rotation=15, ha='right')
    ax2.legend()
    ax2.grid(axis='y', alpha=0.3)
    ax2.set_ylim([0, 100])
    
    # 3. Inference Speed Comparison (Lower is better)
    ax3 = plt.subplot(2, 3, 3)
    inference_times = [r['avg_time_per_sample_ms'] for r in results]
    colors = ['#2ecc71', '#f39c12', '#e74c3c', '#9b59b6'][:len(model_names)]
    bars = ax3.barh(model_names, inference_times, color=colors, alpha=0.8)
    
    ax3.set_xlabel('Time per Sample (ms)', fontsize=12, fontweight='bold')
    ax3.set_title('Inference Speed Comparison', fontsize=14, fontweight='bold')
    ax3.grid(axis='x', alpha=0.3)
    
    # Add value labels on bars
    for i, (bar, val) in enumerate(zip(bars, inference_times)):
        ax3.text(val + max(inference_times)*0.02, bar.get_y() + bar.get_height()/2, 
                f'{val:.2f}ms', va='center', fontweight='bold')
    
    # 4. Error Rate Comparison (Lower is better)
    ax4 = plt.subplot(2, 3, 4)
    error_rates = [r['error_rate'] for r in results]
    colors_error = ['#2ecc71' if e == min(error_rates) else '#95a5a6' for e in error_rates]
    bars = ax4.bar(model_names, error_rates, color=colors_error, alpha=0.8)
    
    ax4.set_xlabel('Models', fontsize=12, fontweight='bold')
    ax4.set_ylabel('Error Rate (%)', fontsize=12, fontweight='bold')
    ax4.set_title('Error Rate Comparison (Lower is Better)', fontsize=14, fontweight='bold')
    ax4.set_xticklabels(model_names, rotation=15, ha='right')
    ax4.grid(axis='y', alpha=0.3)
    
    # Add value labels on bars
    for bar, val in zip(bars, error_rates):
        height = bar.get_height()
        ax4.text(bar.get_x() + bar.get_width()/2., height + 0.5,
                f'{val:.2f}%', ha='center', va='bottom', fontweight='bold')
    
    # 5. Confidence Score Comparison
    ax5 = plt.subplot(2, 3, 5)
    confidence = [r['avg_confidence'] * 100 for r in results]
    colors_conf = ['#3498db', '#9b59b6', '#1abc9c', '#e67e22'][:len(model_names)]
    bars = ax5.bar(model_names, confidence, color=colors_conf, alpha=0.8)
    
    ax5.set_xlabel('Models', fontsize=12, fontweight='bold')
    ax5.set_ylabel('Average Confidence (%)', fontsize=12, fontweight='bold')
    ax5.set_title('Average Confidence Score', fontsize=14, fontweight='bold')
    ax5.set_xticklabels(model_names, rotation=15, ha='right')
    ax5.grid(axis='y', alpha=0.3)
    ax5.set_ylim([80, 100])
    
    # Add value labels on bars
    for bar, val in zip(bars, confidence):
        height = bar.get_height()
        ax5.text(bar.get_x() + bar.get_width()/2., height - 3,
                f'{val:.2f}%', ha='center', va='top', fontweight='bold', color='white')
    
    # 6. Radar Chart for Overall Comparison
    ax6 = plt.subplot(2, 3, 6, projection='polar')
    
    categories = ['Accuracy', 'F1-Macro', 'Precision', 'Recall', 'Confidence']
    num_vars = len(categories)
    angles = np.linspace(0, 2 * np.pi, num_vars, endpoint=False).tolist()
    angles += angles[:1]
    
    for i, result in enumerate(results):
        values = [
            result['accuracy'] * 100,
            result['f1_macro'] * 100,
            result['precision_macro'] * 100,
            result['recall_macro'] * 100,
            result['avg_confidence'] * 100
        ]
        values += values[:1]
        
        ax6.plot(angles, values, 'o-', linewidth=2, label=result['model_name'], alpha=0.8)
        ax6.fill(angles, values, alpha=0.15)
    
    ax6.set_xticks(angles[:-1])
    ax6.set_xticklabels(categories, size=10, fontweight='bold')
    ax6.set_ylim(0, 100)
    ax6.set_title('Overall Model Performance (Radar)', fontsize=14, fontweight='bold', pad=20)
    ax6.legend(loc='upper right', bbox_to_anchor=(1.3, 1.1))
    ax6.grid(True)
    
    plt.tight_layout()
    
    # Save figure
    chart_file = "model_comparison_charts.png"
    plt.savefig(chart_file, dpi=300, bbox_inches='tight')
    print(f"✓ Comparison charts saved to: {chart_file}")
    
    # Create per-class performance comparison
    num_models = len(results)
    fig2, axes = plt.subplots(1, num_models, figsize=(6*num_models, 6))
    
    # Handle case where there's only one model
    if num_models == 1:
        axes = [axes]
    
    for idx, result in enumerate(results):
        per_class = pd.DataFrame(result['per_class_metrics'])
        
        # Extract emotion names (remove emojis)
        emotions = [e.split()[-1] for e in per_class['Emotion']]
        
        # Convert string percentages to floats
        precision = [float(p) for p in per_class['Precision']]
        recall = [float(r) for r in per_class['Recall']]
        f1_scores = [float(f) for f in per_class['F1-Score']]
        
        x = np.arange(len(emotions))
        width = 0.25
        
        axes[idx].bar(x - width, precision, width, label='Precision', alpha=0.8)
        axes[idx].bar(x, recall, width, label='Recall', alpha=0.8)
        axes[idx].bar(x + width, f1_scores, width, label='F1-Score', alpha=0.8)
        
        axes[idx].set_xlabel('Emotions', fontsize=12, fontweight='bold')
        axes[idx].set_ylabel('Score', fontsize=12, fontweight='bold')
        axes[idx].set_title(f'{result["model_name"]} - Per-Class Performance', 
                           fontsize=14, fontweight='bold')
        axes[idx].set_xticks(x)
        axes[idx].set_xticklabels(emotions, rotation=45, ha='right')
        axes[idx].legend()
        axes[idx].grid(axis='y', alpha=0.3)
        axes[idx].set_ylim([0, 1.0])
    
    plt.tight_layout()
    
    # Save per-class comparison
    perclass_file = "per_class_comparison_charts.png"
    plt.savefig(perclass_file, dpi=300, bbox_inches='tight')
    print(f"✓ Per-class comparison charts saved to: {perclass_file}")
    
    plt.close('all')
    
    return chart_file, perclass_file

def save_results(results, comparison_df, speed_df, detailed_df):
    """Save results to files"""
    
    # Save CSV with all results
    csv_file = "model_comparison_results.csv"
    results_df = pd.DataFrame(results)
    results_df.to_csv(csv_file, index=False)
    print(f"\n✓ Detailed results saved to: {csv_file}")
    
    # Save comprehensive report
    report_file = "model_comparison_report.txt"
    with open(report_file, 'w', encoding='utf-8') as f:
        f.write("="*100 + "\n")
        f.write("EMOTION CLASSIFICATION MODEL COMPARISON BENCHMARK - CAPSTONE PROJECT\n")
        f.write("="*100 + "\n")
        f.write(f"Date: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")
        f.write(f"Test Dataset: Emotion (HuggingFace) - Filtered to 7 emotion classes\n")
        f.write(f"Target Classes: anger, disgust, fear, joy, neutral, sadness, surprise\n")
        f.write(f"Source: https://huggingface.co/datasets/emotion\n")
        f.write(f"Device: {'GPU (CUDA)' if torch.cuda.is_available() else 'CPU'}\n\n")
        
        f.write("MODELS EVALUATED:\n")
        f.write("-"*100 + "\n")
        for i, model in enumerate(MODELS, 1):
            f.write(f"{i}. {model['name']} ({model['params']})\n")
            f.write(f"   {model['model_id']}\n\n")
        
        f.write("\nOVERALL PERFORMANCE COMPARISON:\n")
        f.write("-"*100 + "\n")
        f.write(comparison_df.to_string(index=False) + "\n\n")
        
        f.write("\nINFERENCE SPEED COMPARISON:\n")
        f.write("-"*100 + "\n")
        f.write(speed_df.to_string(index=False) + "\n\n")
        
        f.write("\nDETAILED METRICS COMPARISON:\n")
        f.write("-"*100 + "\n")
        f.write(detailed_df.to_string(index=False) + "\n\n")
        
        f.write("\nKEY FINDINGS:\n")
        f.write("-"*100 + "\n")
        best_accuracy = max(results, key=lambda x: x['accuracy'])
        best_f1 = max(results, key=lambda x: x['f1_weighted'])
        fastest = min(results, key=lambda x: x['avg_time_per_sample_ms'])
        
        f.write(f"• Best Overall Performance: {best_accuracy['model_name']} ")
        f.write(f"(Accuracy: {best_accuracy['accuracy']*100:.2f}%)\n")
        f.write(f"• Best F1-Score: {best_f1['model_name']} ")
        f.write(f"(F1-Weighted: {best_f1['f1_weighted']*100:.2f}%)\n")
        f.write(f"• Fastest Model: {fastest['model_name']} ")
        f.write(f"({fastest['avg_time_per_sample_ms']:.2f}ms per sample)\n")
    
    print(f"✓ Comparison report saved to: {report_file}")

def load_test_datasets():
    """Load multiple test datasets for comprehensive evaluation"""
    datasets_info = []
    
    print("\n📦 Loading multiple test datasets for comprehensive evaluation...")
    print("="*100)
    
    # 1. dair-ai/emotion - Standard emotion dataset
    try:
        print("\n1. Loading dair-ai/emotion dataset...")
        dataset1 = load_dataset("dair-ai/emotion", split="test")
        print(f"   ✓ Loaded: {len(dataset1)} samples")
        print(f"   Source: https://huggingface.co/datasets/dair-ai/emotion")
        datasets_info.append({
            'name': 'dair-ai/emotion',
            'dataset': dataset1,
            'url': 'https://huggingface.co/datasets/dair-ai/emotion'
        })
    except Exception as e:
        print(f"   ❌ Failed to load dair-ai/emotion: {str(e)}")
    
    # 2. cardiffnlp/tweet_eval (emotion subset)
    try:
        print("\n2. Loading cardiffnlp/tweet_eval (emotion subset)...")
        dataset2 = load_dataset("cardiffnlp/tweet_eval", "emotion", split="test")
        print(f"   ✓ Loaded: {len(dataset2)} samples")
        print(f"   Source: https://huggingface.co/datasets/cardiffnlp/tweet_eval")
        datasets_info.append({
            'name': 'tweet_eval (emotion)',
            'dataset': dataset2,
            'url': 'https://huggingface.co/datasets/cardiffnlp/tweet_eval'
        })
    except Exception as e:
        print(f"   ❌ Failed to load tweet_eval: {str(e)}")
    
    # 3. SetFit/go_emotions (simplified subset)
    try:
        print("\n3. Loading SetFit/go_emotions (simplified subset)...")
        dataset3 = load_dataset("SetFit/go_emotions", split="test")
        print(f"   ✓ Loaded: {len(dataset3)} samples")
        print(f"   Source: https://huggingface.co/datasets/SetFit/go_emotions")
        datasets_info.append({
            'name': 'go_emotions (SetFit)',
            'dataset': dataset3,
            'url': 'https://huggingface.co/datasets/SetFit/go_emotions'
        })
    except Exception as e:
        print(f"   ❌ Failed to load SetFit/go_emotions: {str(e)}")
    
    # 4. mrm8488/goemotions (full GoEmotions dataset) - Optional, large dataset
    try:
        print("\n4. Loading mrm8488/goemotions (full dataset)...")
        dataset4 = load_dataset("mrm8488/goemotions", split="test")
        print(f"   ✓ Loaded: {len(dataset4)} samples")
        print(f"   Source: https://huggingface.co/datasets/mrm8488/goemotions")
        datasets_info.append({
            'name': 'goemotions (full)',
            'dataset': dataset4,
            'url': 'https://huggingface.co/datasets/mrm8488/goemotions'
        })
    except Exception as e:
        print(f"   ❌ Failed to load mrm8488/goemotions: {str(e)}")
    
    print("\n" + "="*100)
    print(f"✓ Successfully loaded {len(datasets_info)} test datasets")
    
    return datasets_info

def main():
    """Main comparison function"""
    print_header()
    
    # Load multiple test datasets
    datasets_info = load_test_datasets()
    
    if not datasets_info:
        print("\n❌ No datasets loaded successfully. Exiting...")
        return
    
    # Store all results across datasets
    all_results = {}
    
    # Evaluate each model on each dataset
    for dataset_info in datasets_info:
        dataset_name = dataset_info['name']
        dataset = dataset_info['dataset']
        dataset_url = dataset_info['url']
        
        print("\n\n" + "🔷"*50)
        print(f"📊 EVALUATING ON DATASET: {dataset_name}")
        print(f"🔗 Source: {dataset_url}")
        print(f"📝 Samples: {len(dataset)}")
        print("🔷"*50)
        
        results = []
        
        for i, model_info in enumerate(MODELS, 1):
            print(f"\n\n{'#'*100}")
            print(f"# MODEL {i}/{len(MODELS)}: {model_info['name']}")
            print(f"# DATASET: {dataset_name}")
            print(f"{'#'*100}")
            
            result = evaluate_model(model_info, dataset)
            if result:
                result['dataset'] = dataset_name
                result['dataset_url'] = dataset_url
                results.append(result)
            
            # Small pause between models
            time.sleep(2)
        
        # Store results for this dataset
        all_results[dataset_name] = results
        
        # Create and display comparison tables for this dataset
        if len(results) > 0:
            print(f"\n\n{'='*100}")
            print(f"📊 RESULTS SUMMARY FOR: {dataset_name}")
            print(f"{'='*100}")
            
            comparison_df, speed_df, detailed_df = create_comparison_tables(results)
            
            # Create visualizations with dataset name in filename
            dataset_safe_name = dataset_name.replace('/', '_').replace(' ', '_')
            chart_file = f"model_comparison_charts_{dataset_safe_name}.png"
            perclass_file = f"per_class_comparison_{dataset_safe_name}.png"
            
            # Temporarily modify create_visualizations to use custom filenames
            # (We'll save with custom names)
            try:
                import matplotlib.pyplot as plt
                # Create visualizations
                create_visualizations(results)
                # Rename the generated files
                import os
                if os.path.exists("model_comparison_charts.png"):
                    os.rename("model_comparison_charts.png", chart_file)
                if os.path.exists("per_class_comparison_charts.png"):
                    os.rename("per_class_comparison_charts.png", perclass_file)
                
                print(f"\n📊 VISUALIZATIONS GENERATED:")
                print(f"  ✓ Overall comparison charts: {chart_file}")
                print(f"  ✓ Per-class comparison charts: {perclass_file}")
            except Exception as e:
                print(f"⚠️  Warning: Could not generate visualizations: {str(e)}")
            
            # Save results for this dataset
            csv_file = f"model_comparison_results_{dataset_safe_name}.csv"
            report_file = f"model_comparison_report_{dataset_safe_name}.txt"
            
            results_df = pd.DataFrame(results)
            results_df.to_csv(csv_file, index=False)
            print(f"✓ Results saved to: {csv_file}")
            
            # Save detailed report
            with open(report_file, 'w', encoding='utf-8') as f:
                f.write("="*100 + "\n")
                f.write("EMOTION CLASSIFICATION MODEL COMPARISON BENCHMARK - CAPSTONE PROJECT\n")
                f.write("="*100 + "\n")
                f.write(f"Date: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")
                f.write(f"Test Dataset: {dataset_name}\n")
                f.write(f"Source: {dataset_url}\n")
                f.write(f"Samples: {len(dataset)}\n")
                f.write(f"Device: {'GPU (CUDA)' if torch.cuda.is_available() else 'CPU'}\n\n")
                
                f.write("MODELS EVALUATED:\n")
                f.write("-"*100 + "\n")
                for i, model in enumerate(MODELS, 1):
                    f.write(f"{i}. {model['name']} ({model['params']})\n")
                    f.write(f"   {model['model_id']}\n\n")
                
                f.write("\nOVERALL PERFORMANCE COMPARISON:\n")
                f.write("-"*100 + "\n")
                f.write(comparison_df.to_string(index=False) + "\n\n")
                
                f.write("\nINFERENCE SPEED COMPARISON:\n")
                f.write("-"*100 + "\n")
                f.write(speed_df.to_string(index=False) + "\n\n")
                
                f.write("\nDETAILED METRICS COMPARISON:\n")
                f.write("-"*100 + "\n")
                f.write(detailed_df.to_string(index=False) + "\n\n")
            
            print(f"✓ Report saved to: {report_file}")
        else:
            print(f"\n❌ No results for dataset: {dataset_name}")
    
    # Create aggregate summary across all datasets
    print("\n\n" + "🌟"*50)
    print("📊 AGGREGATE SUMMARY ACROSS ALL DATASETS")
    print("🌟"*50)
    
    aggregate_summary = []
    for dataset_name, results in all_results.items():
        if results:
            for result in results:
                aggregate_summary.append({
                    'Dataset': dataset_name,
                    'Model': result['model_name'],
                    'Accuracy': f"{result['accuracy']*100:.2f}%",
                    'F1-Macro': f"{result['f1_macro']*100:.2f}%",
                    'F1-Weighted': f"{result['f1_weighted']*100:.2f}%",
                    'Avg Time (ms)': f"{result['avg_time_per_sample_ms']:.2f}"
                })
    
    if aggregate_summary:
        aggregate_df = pd.DataFrame(aggregate_summary)
        print("\n" + aggregate_df.to_string(index=False))
        
        # Save aggregate results
        aggregate_df.to_csv("aggregate_results_all_datasets.csv", index=False)
        print(f"\n✓ Aggregate results saved to: aggregate_results_all_datasets.csv")
    
    print("\n" + "="*100)
    print("✓ COMPREHENSIVE BENCHMARK COMPLETE")
    print(f"✓ Evaluated {len(MODELS)} models on {len(datasets_info)} datasets")
    print("="*100)

if __name__ == "__main__":
    main()
