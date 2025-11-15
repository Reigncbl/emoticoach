import csv
import os
import random
import sys
from typing import Dict, List, Tuple
from collections import defaultdict
import json
from datetime import datetime

sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

from huggingface_hub import InferenceClient
from services.emotion_pipeline import EmotionEmbedder
from dotenv import load_dotenv

load_dotenv()

# Model to evaluate
MODEL_NAME = "j-hartmann/emotion-english-distilroberta-base"

# Emotion labels (standard order for the model) - ONLY VALID CLASSES
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

# Label mapping for dataset (common variations) - map to VALID CLASSES ONLY
LABEL_MAPPING = {
    'anger': 'anger',
    'disgust': 'disgust',
    'fear': 'fear',
    'joy': 'joy',
    'neutral': 'neutral',
    'sadness': 'sadness',
    'surprise': 'surprise',
    'happy': 'joy',
    'happiness': 'joy',
    'sad': 'sadness',
    'angry': 'anger',
    'scared': 'fear',
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


class EmotionF1Evaluator:
    """Evaluates emotion classification model using F1 scores with translation support."""
    
    def __init__(self, model_name: str = MODEL_NAME, use_translation: bool = True):
        """
        Initialize the evaluator.
        
        Args:
            model_name: HuggingFace model name to evaluate
            use_translation: Whether to use translation for non-English text
        """
        self.model_name = model_name
        self.use_translation = use_translation
        
        # Initialize HF Inference Client
        hf_token = os.environ.get("HF_TOKEN")
        if not hf_token:
            raise ValueError("HF_TOKEN not found in environment variables")
        
        self.client = InferenceClient(
            provider="hf-inference",
            api_key=hf_token,
        )
        
        # Initialize emotion pipeline for translation
        self.emotion_pipeline = EmotionEmbedder(model_name=model_name) if use_translation else None
        
        # Initialize metrics storage
        self.reset_metrics()
    
    def reset_metrics(self):
        """Reset all metrics counters."""
        self.true_positives = defaultdict(int)
        self.false_positives = defaultdict(int)
        self.false_negatives = defaultdict(int)
        self.predictions = []
        self.translation_count = 0
    
    def predict_emotion(self, text: str) -> str:
        """
        Predict emotion for a given text using HF Inference API.
        
        Args:
            text: Input text to classify
            
        Returns:
            Predicted emotion label (one of the 7 valid classes)
        """
        try:
            # Translate if needed
            processed_text = text
            if self.use_translation and self.emotion_pipeline:
                processed_text = self.emotion_pipeline._translate_text(text)
                if processed_text != text:
                    self.translation_count += 1
            
            # Get prediction from HF Inference API
            result = self.client.text_classification(
                processed_text,
                model=self.model_name,
            )
            
            # Extract the top prediction
            if result and len(result) > 0:
                predicted_label = result[0]['label'].lower()
                
                # Ensure the label is one of the valid classes
                if predicted_label not in EMOTION_LABELS:
                    # Try to map it
                    predicted_label = LABEL_MAPPING.get(predicted_label, 'neutral')
                
                return predicted_label
            else:
                return 'neutral'  # Default fallback
                
        except Exception as e:
            red_print(f"Prediction error: {e}")
            return 'neutral'  # Fallback to neutral on error
    
    def update_metrics(self, true_label: str, predicted_label: str):
        """
        Update confusion matrix metrics.
        
        Args:
            true_label: Ground truth label (must be one of the 7 valid classes)
            predicted_label: Model's predicted label (must be one of the 7 valid classes)
        """
        # Normalize labels
        true_label = true_label.lower()
        predicted_label = predicted_label.lower()
        
        # Map to standard labels if needed (only valid classes)
        true_label = LABEL_MAPPING.get(true_label, true_label)
        predicted_label = LABEL_MAPPING.get(predicted_label, predicted_label)
        
        # Skip if labels are not in valid classes (data quality check)
        if true_label not in EMOTION_LABELS:
            red_print(f"Warning: Invalid true label '{true_label}' - skipping")
            return
        if predicted_label not in EMOTION_LABELS:
            red_print(f"Warning: Invalid predicted label '{predicted_label}' - skipping")
            return
        
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
            
            metrics[emotion] = {
                'precision': precision,
                'recall': recall,
                'f1': f1,
                'support': tp + fn  # Number of true instances
            }
        
        return metrics
    
    def calculate_macro_avg(self, metrics: Dict[str, Dict[str, float]]) -> Dict[str, float]:
        """
        Calculate macro-averaged metrics.
        
        Args:
            metrics: Per-class metrics
            
        Returns:
            Macro-averaged precision, recall, and F1
        """
        precisions = [m['precision'] for m in metrics.values()]
        recalls = [m['recall'] for m in metrics.values()]
        f1s = [m['f1'] for m in metrics.values()]
        
        return {
            'precision': sum(precisions) / len(precisions) if precisions else 0.0,
            'recall': sum(recalls) / len(recalls) if recalls else 0.0,
            'f1': sum(f1s) / len(f1s) if f1s else 0.0
        }
    
    def calculate_weighted_avg(self, metrics: Dict[str, Dict[str, float]]) -> Dict[str, float]:
        """
        Calculate weighted-averaged metrics.
        
        Args:
            metrics: Per-class metrics
            
        Returns:
            Weighted-averaged precision, recall, and F1
        """
        total_support = sum(m['support'] for m in metrics.values())
        
        if total_support == 0:
            return {'precision': 0.0, 'recall': 0.0, 'f1': 0.0}
        
        weighted_precision = sum(m['precision'] * m['support'] for m in metrics.values()) / total_support
        weighted_recall = sum(m['recall'] * m['support'] for m in metrics.values()) / total_support
        weighted_f1 = sum(m['f1'] * m['support'] for m in metrics.values()) / total_support
        
        return {
            'precision': weighted_precision,
            'recall': weighted_recall,
            'f1': weighted_f1
        }
    
    def print_results(self, metrics: Dict[str, Dict[str, float]], 
                     macro_avg: Dict[str, float], 
                     weighted_avg: Dict[str, float]):
        """
        Print evaluation results in a formatted table.
        
        Args:
            metrics: Per-class metrics
            macro_avg: Macro-averaged metrics
            weighted_avg: Weighted-averaged metrics
        """
        orange_print("\n" + "="*80)
        orange_print(f"Emotion Classification Evaluation Results")
        orange_print(f"Model: {self.model_name}")
        orange_print(f"Translation: {'Enabled' if self.use_translation else 'Disabled'}")
        orange_print(f"Translations performed: {self.translation_count}")
        orange_print("="*80 + "\n")
        
        # Print valid emotion classes
        orange_print("Valid Emotion Classes (7 classes only):")
        for emotion in EMOTION_LABELS:
            emoji = EMOTION_EMOJIS.get(emotion, '')
            print(f"  {emoji} {emotion}")
        print()
        
        # Print header
        print(f"{'Emotion':<15} {'Precision':<12} {'Recall':<12} {'F1-Score':<12} {'Support':<10}")
        print("-" * 65)
        
        # Print per-class metrics
        for emotion in EMOTION_LABELS:
            m = metrics[emotion]
            emoji = EMOTION_EMOJIS.get(emotion, '')
            emotion_display = f"{emoji} {emotion}"
            print(f"{emotion_display:<15} {m['precision']:<12.4f} {m['recall']:<12.4f} "
                  f"{m['f1']:<12.4f} {m['support']:<10}")
        
        print("-" * 65)
        
        # Print macro average
        print(f"{'📊 Macro Avg':<15} {macro_avg['precision']:<12.4f} {macro_avg['recall']:<12.4f} "
              f"{macro_avg['f1']:<12.4f} {sum(m['support'] for m in metrics.values()):<10}")
        
        # Print weighted average
        print(f"{'⚖️ Weighted Avg':<15} {weighted_avg['precision']:<12.4f} {weighted_avg['recall']:<12.4f} "
              f"{weighted_avg['f1']:<12.4f} {sum(m['support'] for m in metrics.values()):<10}")
        
        print("\n")
        
        # Calculate and print accuracy
        correct = sum(1 for p in self.predictions if p['correct'])
        total = len(self.predictions)
        accuracy = correct / total if total > 0 else 0.0
        green_print(f"✅ Overall Accuracy: {accuracy:.4f} ({correct}/{total})")
        
        # Print best and worst performing emotions
        best_emotion = max(metrics.items(), key=lambda x: x[1]['f1'])
        worst_emotion = min(metrics.items(), key=lambda x: x[1]['f1'])
        
        best_emoji = EMOTION_EMOJIS.get(best_emotion[0], '')
        worst_emoji = EMOTION_EMOJIS.get(worst_emotion[0], '')
        
        green_print(f"\n🏆 Best performing emotion: {best_emoji} {best_emotion[0]} (F1: {best_emotion[1]['f1']:.4f})")
        red_print(f"⚠️  Worst performing emotion: {worst_emoji} {worst_emotion[0]} (F1: {worst_emotion[1]['f1']:.4f})")
        
        orange_print("\n" + "="*80 + "\n")
    
    def save_results(self, metrics: Dict[str, Dict[str, float]], 
                    macro_avg: Dict[str, float], 
                    weighted_avg: Dict[str, float],
                    output_dir: str = "results"):
        """
        Save evaluation results to a JSON file.
        
        Args:
            metrics: Per-class metrics
            macro_avg: Macro-averaged metrics
            weighted_avg: Weighted-averaged metrics
            output_dir: Directory to save results
        """
        # Create output directory if it doesn't exist
        os.makedirs(output_dir, exist_ok=True)
        
        # Prepare results
        results = {
            'model': self.model_name,
            'translation_enabled': self.use_translation,
            'translations_performed': self.translation_count,
            'timestamp': datetime.now().isoformat(),
            'total_samples': len(self.predictions),
            'accuracy': sum(1 for p in self.predictions if p['correct']) / len(self.predictions) if self.predictions else 0.0,
            'per_class_metrics': metrics,
            'macro_avg': macro_avg,
            'weighted_avg': weighted_avg,
            'predictions': self.predictions[:100]  # Save first 100 predictions as samples
        }
        
        # Save to file
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        filename = f"f1_evaluation_{'with' if self.use_translation else 'without'}_translation_{timestamp}.json"
        filepath = os.path.join(output_dir, filename)
        
        with open(filepath, 'w', encoding='utf-8') as f:
            json.dump(results, f, indent=2, ensure_ascii=False)
        
        green_print(f"\nResults saved to: {filepath}")


def load_dataset(dataset_path: str, sample_size: int = -1, seed: int = 42) -> List[Dict[str, str]]:
    """
    Load dataset from TSV file.
    
    Args:
        dataset_path: Path to TSV file
        sample_size: Number of samples to use (-1 for all)
        seed: Random seed for sampling
        
    Returns:
        List of samples with 'emotion' and 'tweet' fields
    """
    with open(dataset_path, encoding="utf-8") as dataset_file:
        reader = list(csv.DictReader(dataset_file, delimiter="\t"))
    
    random.seed(seed)
    if sample_size > 0:
        reader = random.sample(reader, min(sample_size, len(reader)))
    
    return reader


def evaluate_f1(sample_size: int = 50, use_translation: bool = True) -> None:
    """
    Evaluate emotion classification model using F1 score.
    
    Args:
        sample_size: Number of samples to evaluate (-1 for all)
        use_translation: Whether to use translation for non-English text
    """
    # Determine dataset path
    dataset_env = os.getenv("RAG_F1_DATASET")
    if not dataset_env:
        dataset_path = os.path.abspath(
            os.path.join(
                os.path.dirname(__file__),
                "EMOTERA-All-cleaned.tsv"
            )
        )
    else:
        dataset_path = dataset_env
    
    if not os.path.exists(dataset_path):
        red_print(f"Dataset not found at: {dataset_path}")
        return
    
    orange_print(f"\nLoading dataset from: {dataset_path}")
    dataset = load_dataset(dataset_path, sample_size=sample_size)
    orange_print(f"Loaded {len(dataset)} samples\n")
    
    # Initialize evaluator
    evaluator = EmotionF1Evaluator(
        model_name=MODEL_NAME,
        use_translation=use_translation
    )
    
    # Evaluate each sample
    orange_print("Starting evaluation...\n")
    for i, sample in enumerate(dataset, 1):
        text = sample.get('tweet', sample.get('text', ''))
        true_label = sample.get('emotion', 'neutral')
        
        # Predict emotion
        predicted_label = evaluator.predict_emotion(text)
        
        # Update metrics
        evaluator.update_metrics(true_label, predicted_label)
        
        # Print progress
        if i % 10 == 0:
            print(f"Processed {i}/{len(dataset)} samples...")
    
    print()
    
    # Calculate metrics
    metrics = evaluator.calculate_metrics()
    macro_avg = evaluator.calculate_macro_avg(metrics)
    weighted_avg = evaluator.calculate_weighted_avg(metrics)
    
    # Print results
    evaluator.print_results(metrics, macro_avg, weighted_avg)
    
    # Save results
    output_dir = os.path.join(os.path.dirname(__file__), "results")
    evaluator.save_results(metrics, macro_avg, weighted_avg, output_dir)


if __name__ == "__main__":
    # Parse command line arguments
    import argparse
    
    parser = argparse.ArgumentParser(description='Evaluate emotion classification F1 score')
    parser.add_argument('--sample-size', type=int, default=50,
                       help='Number of samples to evaluate (-1 for all)')
    parser.add_argument('--no-translation', action='store_true',
                       help='Disable translation for non-English text')
    parser.add_argument('--compare', action='store_true',
                       help='Run both with and without translation for comparison')
    
    args = parser.parse_args()
    
    if args.compare:
        orange_print("\n" + "="*80)
        orange_print("RUNNING COMPARISON: WITH vs WITHOUT TRANSLATION")
        orange_print("="*80 + "\n")
        
        # Evaluate with translation
        orange_print("\n### EVALUATION WITH TRANSLATION ###\n")
        evaluate_f1(sample_size=args.sample_size, use_translation=True)
        
        # Evaluate without translation
        orange_print("\n### EVALUATION WITHOUT TRANSLATION ###\n")
        evaluate_f1(sample_size=args.sample_size, use_translation=False)
    else:
        # Single evaluation
        evaluate_f1(
            sample_size=args.sample_size,
            use_translation=not args.no_translation
        )
