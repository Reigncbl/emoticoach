"""
F1 Score Benchmark for MELD Dataset
Evaluates emotion classification on English conversational data from MELD (Multimodal EmotionLines Dataset)
"""

import csv
import os
import random
import sys
from typing import Dict, List, Tuple, Optional
from collections import defaultdict
import json
from datetime import datetime
import argparse
import torch
import time
import numpy as np
from tqdm import tqdm

sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

from transformers import AutoTokenizer, AutoModelForSequenceClassification
from dotenv import load_dotenv

load_dotenv()

# Model to benchmark - Using DeBERTa model directly
MODEL_NAME = "Tanneru/Emotion-Classification-DeBERTa-v3-Large"

# Emotion labels - same 7 classes as Filipino dataset
EMOTION_LABELS = ['anger', 'disgust', 'fear', 'joy', 'neutral', 'sadness', 'surprise']

# Emotion emojis for visualization
EMOTION_EMOJIS = {
    'anger': '🤬',
    'disgust': '🤢',
    'fear': '😨',
    'joy': '😀',
    'neutral': '😐',
    'sadness': '😭',
    'surprise': '😲'
}


def orange_print(text: str) -> None:
    """Print text in orange color for terminal output."""
    print(f"\033[38;5;208m{text}\033[0m")


def green_print(text: str) -> None:
    """Print text in green color for terminal output."""
    print(f"\033[92m{text}\033[0m")


def red_print(text: str) -> None:
    """Print text in red color for terminal output."""
    print(f"\033[91m{text}\033[0m")


def blue_print(text: str) -> None:
    """Print text in blue color for terminal output."""
    print(f"\033[94m{text}\033[0m")


class MELDEmotionEvaluator:
    """Evaluates emotion classification model on MELD dataset with batch processing."""
    
    def __init__(self, model_name: str = MODEL_NAME, batch_size: int = 16, use_fp16: bool = False):
        """
        Initialize the evaluator with DeBERTa model loaded directly.
        
        Args:
            model_name: HuggingFace model to use
            batch_size: Batch size for inference
            use_fp16: Use mixed precision (float16) for faster inference
        """
        self.model_name = model_name
        self.batch_size = batch_size
        self.use_fp16 = use_fp16
        
        # Load model and tokenizer directly
        orange_print(f"Loading model: {model_name}...")
        self.tokenizer = AutoTokenizer.from_pretrained(model_name, use_fast=False)
        self.model = AutoModelForSequenceClassification.from_pretrained(model_name)
        
        # Set device (GPU if available, else CPU)
        self.device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
        self.model.to(self.device)
        
        # Use mixed precision if requested and on GPU
        if use_fp16 and self.device.type == "cuda":
            self.model = self.model.half()
            green_print(f"✅ Using FP16 (mixed precision)")
        
        self.model.eval()  # Set to evaluation mode
        
        green_print(f"✅ Model loaded on device: {self.device}")
        green_print(f"✅ Batch size: {batch_size}")
        
        # Store timing information
        self.inference_times = []
        
        self.reset_metrics()
    
    def reset_metrics(self):
        """Reset all metrics counters."""
        self.true_positives = defaultdict(int)
        self.false_positives = defaultdict(int)
        self.false_negatives = defaultdict(int)
        self.predictions = []
        self.total_samples = 0
        self.confusion_matrix = defaultdict(lambda: defaultdict(int))
    
    def predict_emotion(self, text: str) -> Tuple[str, float]:
        """
        Predict emotion for a single text using DeBERTa model directly.
        
        Args:
            text: Input text to classify (English utterance)
            
        Returns:
            Tuple of (predicted emotion label, confidence score)
        """
        results = self.predict_emotions_batch([text])
        return results[0] if results else ('neutral', 0.0)
    
    def predict_emotions_batch(self, texts: List[str]) -> List[Tuple[str, float]]:
        """
        Predict emotions for a batch of texts (more efficient).
        
        Args:
            texts: List of input texts to classify
            
        Returns:
            List of tuples (predicted emotion label, confidence score)
        """
        try:
            start_time = time.time()
            
            # Tokenize batch
            inputs = self.tokenizer(
                texts, 
                return_tensors="pt", 
                truncation=True, 
                max_length=512, 
                padding=True
            )
            inputs = {k: v.to(self.device) for k, v in inputs.items()}
            
            # Get predictions
            with torch.no_grad():
                outputs = self.model(**inputs)
                logits = outputs.logits
                probabilities = torch.nn.functional.softmax(logits, dim=-1)
                
                # Get predicted classes and confidences
                confidences, predicted_classes = torch.max(probabilities, dim=-1)
            
            # Convert to CPU and numpy for processing
            confidences = confidences.cpu().numpy()
            predicted_classes = predicted_classes.cpu().numpy()
            
            # Map class indices to emotion labels
            results = []
            for pred_class, confidence in zip(predicted_classes, confidences):
                # Map class index to emotion label
                if hasattr(self.model.config, 'id2label'):
                    predicted_label = self.model.config.id2label[int(pred_class)].lower()
                else:
                    predicted_label = EMOTION_LABELS[int(pred_class)] if int(pred_class) < len(EMOTION_LABELS) else 'neutral'
                
                # Ensure the label is one of the valid classes
                if predicted_label not in EMOTION_LABELS:
                    predicted_label = 'neutral'
                
                results.append((predicted_label, float(confidence)))
            
            # Track inference time
            inference_time = time.time() - start_time
            self.inference_times.append(inference_time)
            
            return results
                
        except Exception as e:
            red_print(f"Batch prediction error: {e}")
            return [('neutral', 0.0) for _ in texts]
    
    def update_metrics(self, true_label: str, predicted_label: str):
        """
        Update confusion matrix metrics.
        
        Args:
            true_label: Ground truth label
            predicted_label: Model's predicted label
        """
        true_label = true_label.lower()
        predicted_label = predicted_label.lower()
        
        # Skip if labels are not in valid classes
        if true_label not in EMOTION_LABELS:
            red_print(f"Warning: Invalid true label '{true_label}' - skipping")
            return
        if predicted_label not in EMOTION_LABELS:
            red_print(f"Warning: Invalid predicted label '{predicted_label}' - skipping")
            return
        
        self.total_samples += 1
        
        # Update confusion matrix
        self.confusion_matrix[true_label][predicted_label] += 1
        
        # Update counts
        if true_label == predicted_label:
            self.true_positives[true_label] += 1
        else:
            self.false_positives[predicted_label] += 1
            self.false_negatives[true_label] += 1
        
        # Store prediction
        self.predictions.append({
            'true': true_label,
            'predicted': predicted_label,
            'correct': true_label == predicted_label
        })
    
    def update_metrics_with_confidence(self, true_label: str, predicted_label: str, confidence: float):
        """
        Update metrics including confidence score.
        
        Args:
            true_label: Ground truth label
            predicted_label: Model's predicted label
            confidence: Prediction confidence
        """
        self.update_metrics(true_label, predicted_label)
        # Store confidence in last prediction
        if self.predictions:
            self.predictions[-1]['confidence'] = confidence
    
    def calculate_metrics(self) -> Dict[str, Dict[str, float]]:
        """
        Calculate precision, recall, and F1 score for each emotion.
        
        Returns:
            Dictionary with metrics for each emotion
        """
        metrics = {}
        
        for emotion in EMOTION_LABELS:
            tp = self.true_positives[emotion]
            fp = self.false_positives[emotion]
            fn = self.false_negatives[emotion]
            
            # Calculate precision
            precision = tp / (tp + fp) if (tp + fp) > 0 else 0.0
            
            # Calculate recall
            recall = tp / (tp + fn) if (tp + fn) > 0 else 0.0
            
            # Calculate F1 score
            f1 = 2 * (precision * recall) / (precision + recall) if (precision + recall) > 0 else 0.0
            
            # Support (number of true instances)
            support = tp + fn
            
            metrics[emotion] = {
                'precision': precision,
                'recall': recall,
                'f1': f1,
                'support': support,
                'tp': tp,
                'fp': fp,
                'fn': fn
            }
        
        return metrics
    
    def calculate_macro_metrics(self, metrics: Dict[str, Dict[str, float]]) -> Dict[str, float]:
        """
        Calculate macro-averaged metrics across all emotions.
        
        Args:
            metrics: Per-emotion metrics dictionary
            
        Returns:
            Dictionary with macro-averaged precision, recall, and F1
        """
        total_precision = sum(m['precision'] for m in metrics.values())
        total_recall = sum(m['recall'] for m in metrics.values())
        total_f1 = sum(m['f1'] for m in metrics.values())
        num_emotions = len(EMOTION_LABELS)
        
        return {
            'macro_precision': total_precision / num_emotions,
            'macro_recall': total_recall / num_emotions,
            'macro_f1': total_f1 / num_emotions
        }
    
    def calculate_weighted_metrics(self, metrics: Dict[str, Dict[str, float]]) -> Dict[str, float]:
        """
        Calculate weighted-averaged metrics (weighted by support).
        
        Args:
            metrics: Per-emotion metrics dictionary
            
        Returns:
            Dictionary with weighted-averaged precision, recall, and F1
        """
        total_support = sum(m['support'] for m in metrics.values())
        
        if total_support == 0:
            return {
                'weighted_precision': 0.0,
                'weighted_recall': 0.0,
                'weighted_f1': 0.0
            }
        
        weighted_precision = sum(m['precision'] * m['support'] for m in metrics.values()) / total_support
        weighted_recall = sum(m['recall'] * m['support'] for m in metrics.values()) / total_support
        weighted_f1 = sum(m['f1'] * m['support'] for m in metrics.values()) / total_support
        
        return {
            'weighted_precision': weighted_precision,
            'weighted_recall': weighted_recall,
            'weighted_f1': weighted_f1
        }
    
    def calculate_micro_metrics(self) -> Dict[str, float]:
        """
        Calculate micro-averaged metrics (aggregate all classes).
        
        Returns:
            Dictionary with micro-averaged precision, recall, and F1
        """
        total_tp = sum(self.true_positives.values())
        total_fp = sum(self.false_positives.values())
        total_fn = sum(self.false_negatives.values())
        
        micro_precision = total_tp / (total_tp + total_fp) if (total_tp + total_fp) > 0 else 0.0
        micro_recall = total_tp / (total_tp + total_fn) if (total_tp + total_fn) > 0 else 0.0
        micro_f1 = 2 * (micro_precision * micro_recall) / (micro_precision + micro_recall) if (micro_precision + micro_recall) > 0 else 0.0
        
        return {
            'micro_precision': micro_precision,
            'micro_recall': micro_recall,
            'micro_f1': micro_f1
        }
    
    def calculate_accuracy(self) -> float:
        """Calculate overall accuracy."""
        correct = sum(1 for p in self.predictions if p['correct'])
        total = len(self.predictions)
        return correct / total if total > 0 else 0.0
    
    def print_confusion_matrix(self):
        """Print confusion matrix."""
        blue_print("\n📊 CONFUSION MATRIX:")
        print(f"{'':>12}", end="")
        for pred_emotion in EMOTION_LABELS:
            print(f"{pred_emotion[:6]:>8}", end="")
        print("\n" + "-" * 80)
        
        for true_emotion in EMOTION_LABELS:
            print(f"{true_emotion:<12}", end="")
            for pred_emotion in EMOTION_LABELS:
                count = self.confusion_matrix[true_emotion][pred_emotion]
                if count == 0:
                    print(f"{'':>8}", end="")
                elif true_emotion == pred_emotion:
                    # Highlight diagonal (correct predictions)
                    print(f"\033[92m{count:>8}\033[0m", end="")
                else:
                    print(f"{count:>8}", end="")
            print()
        print()
        
        # Show top misclassifications
        misclassifications = []
        for true_emotion in EMOTION_LABELS:
            for pred_emotion in EMOTION_LABELS:
                if true_emotion != pred_emotion:
                    count = self.confusion_matrix[true_emotion][pred_emotion]
                    if count > 0:
                        misclassifications.append((count, true_emotion, pred_emotion))
        
        if misclassifications:
            misclassifications.sort(reverse=True)
            orange_print("⚠️  Top 3 Misclassifications:")
            for i, (count, true_emotion, pred_emotion) in enumerate(misclassifications[:3], 1):
                print(f"  {i}. {EMOTION_EMOJIS[true_emotion]} {true_emotion} → {EMOTION_EMOJIS[pred_emotion]} {pred_emotion}: {count} times")
            print()
    
    def print_results(self, metrics: Dict[str, Dict[str, float]], macro_metrics: Dict[str, float], 
                     weighted_metrics: Optional[Dict[str, float]] = None,
                     micro_metrics: Optional[Dict[str, float]] = None):
        """
        Print formatted results table with all metrics.
        
        Args:
            metrics: Per-emotion metrics
            macro_metrics: Macro-averaged metrics
            weighted_metrics: Weighted-averaged metrics
            micro_metrics: Micro-averaged metrics
        """
        print("\n" + "="*80)
        blue_print("📊 MELD DATASET F1 SCORE EVALUATION RESULTS")
        print("="*80 + "\n")
        
        # Print header
        header = f"{'Emotion':<12} {'Emoji':<6} {'Precision':<12} {'Recall':<12} {'F1 Score':<12} {'Support':<10}"
        green_print(header)
        print("-" * 80)
        
        # Print per-emotion results
        for emotion in EMOTION_LABELS:
            m = metrics[emotion]
            emoji = EMOTION_EMOJIS[emotion]
            
            # Color code F1 scores
            f1_str = f"{m['f1']:.4f}"
            if m['f1'] >= 0.70:
                f1_colored = f"\033[92m{f1_str}\033[0m"  # Green for good
            elif m['f1'] >= 0.50:
                f1_colored = f"\033[93m{f1_str}\033[0m"  # Yellow for okay
            else:
                f1_colored = f"\033[91m{f1_str}\033[0m"  # Red for poor
            
            row = f"{emotion:<12} {emoji:<6} {m['precision']:.4f}      {m['recall']:.4f}      {f1_colored}      {m['support']:<10}"
            print(row)
        
        print("-" * 80)
        
        # Print averages
        orange_print(f"\n{'Macro Avg':<12} {'📈':<6} "
                    f"{macro_metrics['macro_precision']:.4f}      "
                    f"{macro_metrics['macro_recall']:.4f}      "
                    f"{macro_metrics['macro_f1']:.4f}")
        
        if weighted_metrics:
            orange_print(f"{'Weighted Avg':<12} {'⚖️ ':<6} "
                        f"{weighted_metrics['weighted_precision']:.4f}      "
                        f"{weighted_metrics['weighted_recall']:.4f}      "
                        f"{weighted_metrics['weighted_f1']:.4f}")
        
        if micro_metrics:
            orange_print(f"{'Micro Avg':<12} {'🔬':<6} "
                        f"{micro_metrics['micro_precision']:.4f}      "
                        f"{micro_metrics['micro_recall']:.4f}      "
                        f"{micro_metrics['micro_f1']:.4f}")
        
        # Print overall accuracy and timing
        accuracy = self.calculate_accuracy()
        green_print(f"\n{'Overall Accuracy:':<20} {accuracy:.4f} ({accuracy*100:.2f}%)")
        green_print(f"{'Total Samples:':<20} {self.total_samples}")
        
        # Print timing statistics
        if self.inference_times:
            avg_time = np.mean(self.inference_times)
            total_time = np.sum(self.inference_times)
            throughput = self.total_samples / total_time if total_time > 0 else 0
            
            blue_print(f"\n⏱️  Performance:")
            print(f"  Total inference time: {total_time:.2f}s")
            print(f"  Average batch time: {avg_time*1000:.2f}ms")
            print(f"  Throughput: {throughput:.2f} samples/second")
        
        print("\n" + "="*80 + "\n")
    
    def save_results(self, metrics: Dict[str, Dict[str, float]], 
                    macro_metrics: Dict[str, float],
                    weighted_metrics: Optional[Dict[str, float]] = None,
                    micro_metrics: Optional[Dict[str, float]] = None,
                    output_file: str = None):
        """
        Save results to JSON file.
        
        Args:
            metrics: Per-emotion metrics
            macro_metrics: Macro-averaged metrics
            weighted_metrics: Weighted-averaged metrics
            micro_metrics: Micro-averaged metrics
            output_file: Output file path (optional)
        """
        if output_file is None:
            timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
            output_file = f"meld_f1_results_{timestamp}.json"
        
        results = {
            'timestamp': datetime.now().isoformat(),
            'model_name': self.model_name,
            'dataset': 'MELD',
            'total_samples': self.total_samples,
            'accuracy': self.calculate_accuracy(),
            'macro_metrics': macro_metrics,
            'weighted_metrics': weighted_metrics or {},
            'micro_metrics': micro_metrics or {},
            'per_emotion_metrics': metrics,
            'confusion_matrix': {k: dict(v) for k, v in self.confusion_matrix.items()},
            'predictions': self.predictions[:100],  # Save first 100 to reduce file size
            'performance': {
                'total_inference_time': float(np.sum(self.inference_times)) if self.inference_times else 0,
                'avg_batch_time': float(np.mean(self.inference_times)) if self.inference_times else 0,
                'throughput': self.total_samples / np.sum(self.inference_times) if self.inference_times and np.sum(self.inference_times) > 0 else 0
            }
        }
        
        os.makedirs(os.path.dirname(output_file) if os.path.dirname(output_file) else '.', exist_ok=True)
        
        with open(output_file, 'w', encoding='utf-8') as f:
            json.dump(results, f, indent=2, ensure_ascii=False)
        
        green_print(f"\n✅ Results saved to: {output_file}")


def load_meld_dataset(file_path: str, sample_size: int = None, random_seed: int = 42) -> List[Tuple[str, str]]:
    """
    Load MELD dataset from CSV file.
    
    Args:
        file_path: Path to the MELD CSV file
        sample_size: Number of samples to use (None for all)
        random_seed: Random seed for sampling
        
    Returns:
        List of (utterance, emotion) tuples
    """
    data = []
    
    if not os.path.exists(file_path):
        red_print(f"❌ Error: File not found: {file_path}")
        sys.exit(1)
    
    with open(file_path, 'r', encoding='utf-8') as f:
        reader = csv.DictReader(f)
        for row in reader:
            utterance = row.get('utterance', '').strip()
            emotion = row.get('emotion_name', '').strip().lower()
            
            # Only include valid emotions
            if emotion in EMOTION_LABELS and utterance:
                data.append((utterance, emotion))
    
    orange_print(f"📁 Loaded {len(data)} samples from MELD dataset")
    
    # Sample if requested
    if sample_size and sample_size < len(data):
        random.seed(random_seed)
        data = random.sample(data, sample_size)
        orange_print(f"🎲 Randomly sampled {sample_size} utterances")
    
    # Show emotion distribution
    emotion_counts = defaultdict(int)
    for _, emotion in data:
        emotion_counts[emotion] += 1
    
    print("\n📊 Emotion distribution in sample:")
    for emotion in EMOTION_LABELS:
        count = emotion_counts[emotion]
        percentage = (count / len(data) * 100) if data else 0
        emoji = EMOTION_EMOJIS[emotion]
        print(f"  {emoji} {emotion:<10}: {count:>4} ({percentage:>5.2f}%)")
    print()
    
    return data


def main():
    """Main evaluation function."""
    # Get default file path relative to this script
    default_file = os.path.join(os.path.dirname(__file__), 'results', 'meld-train-cleaned.csv')
    
    parser = argparse.ArgumentParser(description='Evaluate F1 scores on MELD dataset')
    parser.add_argument('--file', type=str, 
                       default=default_file,
                       help='Path to MELD CSV file')
    parser.add_argument('--sample-size', type=int, default=100,
                       help='Number of samples to evaluate (default: 100)')
    parser.add_argument('--batch-size', type=int, default=16,
                       help='Batch size for inference (default: 16)')
    parser.add_argument('--output', type=str, default=None,
                       help='Output JSON file path')
    parser.add_argument('--seed', type=int, default=42,
                       help='Random seed for sampling')
    parser.add_argument('--model', type=str, default=MODEL_NAME,
                       help='HuggingFace model to benchmark')
    parser.add_argument('--fp16', action='store_true',
                       help='Use mixed precision (FP16) for faster inference')
    
    args = parser.parse_args()
    
    blue_print("\n" + "="*80)
    blue_print("🎬 MELD EMOTION CLASSIFICATION F1 BENCHMARK")
    blue_print(f"📦 Model: {args.model}")
    blue_print("="*80 + "\n")
    
    # Load dataset
    data = load_meld_dataset(args.file, args.sample_size, args.seed)
    
    if not data:
        red_print("❌ No valid data to evaluate!")
        sys.exit(1)
    
    orange_print(f"🤖 Initializing model: {args.model}")
    evaluator = MELDEmotionEvaluator(
        model_name=args.model, 
        batch_size=args.batch_size,
        use_fp16=args.fp16
    )
    green_print("✅ Model ready\n")
    
    # Evaluate with batch processing
    orange_print(f"🔄 Evaluating {len(data)} utterances with batch size {args.batch_size}...\n")
    
    # Process in batches with progress bar
    batch_size = evaluator.batch_size
    num_batches = (len(data) + batch_size - 1) // batch_size
    
    examples_shown = 0
    
    with tqdm(total=len(data), desc="Evaluating", unit="samples") as pbar:
        for batch_idx in range(num_batches):
            start_idx = batch_idx * batch_size
            end_idx = min(start_idx + batch_size, len(data))
            batch_data = data[start_idx:end_idx]
            
            # Extract texts and labels
            texts = [utterance for utterance, _ in batch_data]
            true_emotions = [emotion for _, emotion in batch_data]
            
            # Predict batch
            predictions = evaluator.predict_emotions_batch(texts)
            
            # Update metrics for each prediction
            for (utterance, true_emotion), (predicted_emotion, confidence) in zip(batch_data, predictions):
                evaluator.update_metrics_with_confidence(true_emotion, predicted_emotion, confidence)
                
                # Show first few examples
                if examples_shown < 5:
                    correct = "✅" if true_emotion == predicted_emotion else "❌"
                    tqdm.write(f"{correct} Sample {examples_shown + 1}:")
                    tqdm.write(f"   Text: {utterance[:80]}...")
                    tqdm.write(f"   True: {EMOTION_EMOJIS[true_emotion]} {true_emotion} | Predicted: {EMOTION_EMOJIS[predicted_emotion]} {predicted_emotion} (conf: {confidence:.2f})\n")
                    examples_shown += 1
            
            # Update progress bar
            pbar.update(len(batch_data))
    
    print()  # New line after progress
    
    # Calculate metrics
    metrics = evaluator.calculate_metrics()
    macro_metrics = evaluator.calculate_macro_metrics(metrics)
    weighted_metrics = evaluator.calculate_weighted_metrics(metrics)
    micro_metrics = evaluator.calculate_micro_metrics()
    
    # Print results
    evaluator.print_results(metrics, macro_metrics, weighted_metrics, micro_metrics)
    
    # Print confusion matrix
    evaluator.print_confusion_matrix()
    
    # Save results
    if args.output:
        output_path = args.output
    else:
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        output_path = f"Backend/Evaluations/results/meld_f1_results_{timestamp}.json"
    
    evaluator.save_results(metrics, macro_metrics, weighted_metrics, micro_metrics, output_path)
    
    # Print summary statistics
    print("\n📈 Key Insights:")
    
    # Best performing emotion
    best_emotion = max(EMOTION_LABELS, key=lambda e: metrics[e]['f1'])
    best_f1 = metrics[best_emotion]['f1']
    green_print(f"  ✨ Best: {EMOTION_EMOJIS[best_emotion]} {best_emotion} (F1: {best_f1:.4f})")
    
    # Worst performing emotion
    worst_emotion = min(EMOTION_LABELS, key=lambda e: metrics[e]['f1'])
    worst_f1 = metrics[worst_emotion]['f1']
    red_print(f"  ⚠️  Worst: {EMOTION_EMOJIS[worst_emotion]} {worst_emotion} (F1: {worst_f1:.4f})")
    
    # Emotions below threshold
    threshold = 0.60
    low_performers = [e for e in EMOTION_LABELS if metrics[e]['f1'] < threshold]
    if low_performers:
        orange_print(f"\n  ⚡ Emotions below {threshold:.2f} F1 threshold:")
        for emotion in low_performers:
            print(f"     {EMOTION_EMOJIS[emotion]} {emotion}: {metrics[emotion]['f1']:.4f}")
    
    print("\n" + "="*80 + "\n")


if __name__ == "__main__":
    main()
