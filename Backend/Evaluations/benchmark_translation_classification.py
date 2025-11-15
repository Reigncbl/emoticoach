"""
Benchmark script for translation and emotion classification performance.
Uses existing functions from RAGPipeline and EmotionPipeline.
Measures speed and accuracy of the emotion analysis pipeline.
"""

import csv
import os
import sys
import time
import random
from typing import Dict, List
from collections import defaultdict
import json
from datetime import datetime
import statistics

sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

from services.emotion_pipeline import EmotionEmbedder
from services.RAGPipeline import SimpleRAG
from dotenv import load_dotenv

load_dotenv()

# Valid emotion classes (7 classes only)
VALID_EMOTIONS = ['anger', 'disgust', 'fear', 'joy', 'neutral', 'sadness', 'surprise']

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

# Label mapping for common variations
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
    """Print text in orange color."""
    print(f"\033[38;5;208m{text}\033[0m")


def green_print(text: str) -> None:
    """Print text in green color."""
    print(f"\033[92m{text}\033[0m")


def blue_print(text: str) -> None:
    """Print text in blue color."""
    print(f"\033[94m{text}\033[0m")


def red_print(text: str) -> None:
    """Print text in red color."""
    print(f"\033[91m{text}\033[0m")


class TranslationClassificationBenchmark:
    """Benchmark translation and classification performance using existing pipeline functions."""
    
    def __init__(self):
        """Initialize the benchmark with emotion pipeline."""
        self.emotion_pipeline = EmotionEmbedder()
        
        # Metrics storage
        self.translation_times = []
        self.classification_times = []
        self.total_times = []
        self.translation_needed_count = 0
        self.classification_results = []
        
    def benchmark_single_text(self, text: str, true_label: str = None) -> Dict:
        """
        Benchmark a single text through the pipeline.
        
        Args:
            text: Input text to process
            true_label: Ground truth label (optional)
            
        Returns:
            Dictionary with timing and results
        """
        result = {
            'original_text': text,
            'true_label': true_label,
            'translation_time': 0.0,
            'classification_time': 0.0,
            'total_time': 0.0,
            'was_translated': False,
            'processed_text': None,
            'predicted_emotion': None,
            'emotion_scores': {},
            'correct': None
        }
        
        # Start total timer
        total_start = time.time()
        
        # Step 1: Translation (if needed) - Uses EmotionEmbedder._translate_text()
        translation_start = time.time()
        processed_text = self.emotion_pipeline._translate_text(text)
        translation_end = time.time()
        
        result['translation_time'] = translation_end - translation_start
        result['processed_text'] = processed_text
        result['was_translated'] = (processed_text != text)
        
        if result['was_translated']:
            self.translation_needed_count += 1
        
        # Step 2: Classification - Uses EmotionEmbedder.analyze_text_full()
        classification_start = time.time()
        analysis = self.emotion_pipeline.analyze_text_full(
            processed_text, 
            translate_if_needed=False  # Already translated
        )
        classification_end = time.time()
        
        result['classification_time'] = classification_end - classification_start
        result['predicted_emotion'] = analysis['dominant_emotion']
        result['emotion_scores'] = analysis['emotion_scores']
        
        # End total timer
        total_end = time.time()
        result['total_time'] = total_end - total_start
        
        # Check correctness if true label provided
        if true_label:
            result['correct'] = (result['predicted_emotion'].lower() == true_label.lower())
        
        # Store metrics
        if result['was_translated']:
            self.translation_times.append(result['translation_time'])
        self.classification_times.append(result['classification_time'])
        self.total_times.append(result['total_time'])
        self.classification_results.append(result)
        
        return result
    
    def calculate_statistics(self, times: List[float]) -> Dict[str, float]:
        """Calculate statistics for a list of times."""
        if not times:
            return {
                'mean': 0.0,
                'median': 0.0,
                'min': 0.0,
                'max': 0.0,
                'std': 0.0,
                'total': 0.0
            }
        
        return {
            'mean': statistics.mean(times),
            'median': statistics.median(times),
            'min': min(times),
            'max': max(times),
            'std': statistics.stdev(times) if len(times) > 1 else 0.0,
            'total': sum(times)
        }
    
    def _calculate_per_class_metrics(self) -> Dict[str, Dict[str, float]]:
        """
        Calculate precision, recall, and F1-score for each emotion class.
        
        Returns:
            Dictionary mapping emotion to metrics (precision, recall, f1, support, tp, fp, fn)
        """
        per_class_metrics = {}
        
        for emotion in VALID_EMOTIONS:
            # Count true positives, false positives, false negatives
            tp = sum(1 for r in self.classification_results 
                    if r['true_label'] and r['true_label'].lower() == emotion 
                    and r['predicted_emotion'].lower() == emotion)
            
            fp = sum(1 for r in self.classification_results 
                    if r['true_label'] and r['true_label'].lower() != emotion 
                    and r['predicted_emotion'].lower() == emotion)
            
            fn = sum(1 for r in self.classification_results 
                    if r['true_label'] and r['true_label'].lower() == emotion 
                    and r['predicted_emotion'].lower() != emotion)
            
            support = tp + fn  # Total actual instances of this class
            
            # Calculate metrics
            precision = tp / (tp + fp) if (tp + fp) > 0 else 0.0
            recall = tp / (tp + fn) if (tp + fn) > 0 else 0.0
            f1 = 2 * (precision * recall) / (precision + recall) if (precision + recall) > 0 else 0.0
            
            per_class_metrics[emotion] = {
                'precision': precision,
                'recall': recall,
                'f1': f1,
                'support': support,
                'tp': tp,
                'fp': fp,
                'fn': fn
            }
        
        return per_class_metrics
    
    def print_summary(self):
        """Print benchmark summary statistics."""
        orange_print("\n" + "="*80)
        orange_print("📊 TRANSLATION & CLASSIFICATION BENCHMARK RESULTS")
        orange_print("="*80 + "\n")
        
        total_samples = len(self.classification_results)
        translated_samples = self.translation_needed_count
        non_translated = total_samples - translated_samples
        
        # Overall stats
        blue_print("📈 OVERALL STATISTICS:")
        print(f"  Total samples processed: {total_samples}")
        print(f"  Samples requiring translation: {translated_samples} ({translated_samples/total_samples*100:.1f}%)")
        print(f"  Samples without translation: {non_translated} ({non_translated/total_samples*100:.1f}%)")
        print()
        
        # Translation timing (only for samples that needed it)
        if self.translation_times:
            blue_print("🌐 TRANSLATION PERFORMANCE:")
            trans_stats = self.calculate_statistics(self.translation_times)
            print(f"  Number of translations: {len(self.translation_times)}")
            print(f"  Mean time: {trans_stats['mean']*1000:.2f} ms")
            print(f"  Median time: {trans_stats['median']*1000:.2f} ms")
            print(f"  Min time: {trans_stats['min']*1000:.2f} ms")
            print(f"  Max time: {trans_stats['max']*1000:.2f} ms")
            print(f"  Std deviation: {trans_stats['std']*1000:.2f} ms")
            print(f"  Total translation time: {trans_stats['total']:.2f} s")
            print()
        
        # Classification timing (all samples)
        blue_print("🎯 CLASSIFICATION PERFORMANCE:")
        class_stats = self.calculate_statistics(self.classification_times)
        print(f"  Number of classifications: {len(self.classification_times)}")
        print(f"  Mean time: {class_stats['mean']*1000:.2f} ms")
        print(f"  Median time: {class_stats['median']*1000:.2f} ms")
        print(f"  Min time: {class_stats['min']*1000:.2f} ms")
        print(f"  Max time: {class_stats['max']*1000:.2f} ms")
        print(f"  Std deviation: {class_stats['std']*1000:.2f} ms")
        print(f"  Total classification time: {class_stats['total']:.2f} s")
        print()
        
        # Total pipeline timing
        blue_print("⚡ TOTAL PIPELINE PERFORMANCE:")
        total_stats = self.calculate_statistics(self.total_times)
        print(f"  Mean time: {total_stats['mean']*1000:.2f} ms")
        print(f"  Median time: {total_stats['median']*1000:.2f} ms")
        print(f"  Min time: {total_stats['min']*1000:.2f} ms")
        print(f"  Max time: {total_stats['max']*1000:.2f} ms")
        print(f"  Std deviation: {total_stats['std']*1000:.2f} ms")
        print(f"  Total processing time: {total_stats['total']:.2f} s")
        print(f"  Throughput: {total_samples/total_stats['total']:.2f} samples/second")
        print()
        
        # Time breakdown
        if self.translation_times:
            avg_trans_time = statistics.mean(self.translation_times)
            avg_class_time = statistics.mean(self.classification_times)
            total_avg = avg_trans_time + avg_class_time
            
            blue_print("⏱️  AVERAGE TIME BREAKDOWN (for translated samples):")
            print(f"  Translation: {avg_trans_time*1000:.2f} ms ({avg_trans_time/total_avg*100:.1f}%)")
            print(f"  Classification: {avg_class_time*1000:.2f} ms ({avg_class_time/total_avg*100:.1f}%)")
            print()
        
        # Calculate accuracy, precision, recall (if true labels provided)
        correct_predictions = [r for r in self.classification_results if r['correct'] is True]
        if any(r['correct'] is not None for r in self.classification_results):
            total_with_labels = sum(1 for r in self.classification_results if r['correct'] is not None)
            accuracy = len(correct_predictions) / total_with_labels if total_with_labels > 0 else 0
            
            # Calculate per-class metrics
            per_class_metrics = self._calculate_per_class_metrics()
            
            # Calculate weighted averages
            total_true_positives = sum(metrics['tp'] for metrics in per_class_metrics.values())
            total_false_positives = sum(metrics['fp'] for metrics in per_class_metrics.values())
            total_false_negatives = sum(metrics['fn'] for metrics in per_class_metrics.values())
            
            # Overall precision and recall
            overall_precision = total_true_positives / (total_true_positives + total_false_positives) if (total_true_positives + total_false_positives) > 0 else 0
            overall_recall = total_true_positives / (total_true_positives + total_false_negatives) if (total_true_positives + total_false_negatives) > 0 else 0
            overall_f1 = 2 * (overall_precision * overall_recall) / (overall_precision + overall_recall) if (overall_precision + overall_recall) > 0 else 0
            
            blue_print("✅ OVERALL METRICS:")
            print(f"  Correct predictions: {len(correct_predictions)}/{total_with_labels}")
            print(f"  Accuracy:  {accuracy*100:.2f}%")
            print(f"  Precision: {overall_precision*100:.2f}%")
            print(f"  Recall:    {overall_recall*100:.2f}%")
            print(f"  F1-Score:  {overall_f1*100:.2f}%")
            print()
            
            # Per-class metrics
            blue_print("📊 PER-CLASS METRICS:")
            print(f"  {'Emotion':<12} {'Precision':<12} {'Recall':<12} {'F1-Score':<12} {'Support':<10}")
            print(f"  {'-'*12} {'-'*12} {'-'*12} {'-'*12} {'-'*10}")
            
            for emotion in sorted(VALID_EMOTIONS):
                if emotion in per_class_metrics:
                    metrics = per_class_metrics[emotion]
                    emoji = EMOTION_EMOJIS.get(emotion, '')
                    print(f"  {emoji} {emotion:<9} "
                          f"{metrics['precision']*100:>6.2f}%     "
                          f"{metrics['recall']*100:>6.2f}%     "
                          f"{metrics['f1']*100:>6.2f}%     "
                          f"{metrics['support']:>6}")
            print()
        
        # Emotion distribution
        emotion_counts = defaultdict(int)
        for result in self.classification_results:
            emotion = result['predicted_emotion']
            emotion_counts[emotion] += 1
        
        blue_print("📊 PREDICTED EMOTION DISTRIBUTION:")
        for emotion in sorted(emotion_counts.keys()):
            emoji = EMOTION_EMOJIS.get(emotion, '')
            count = emotion_counts[emotion]
            percentage = count / total_samples * 100
            print(f"  {emoji} {emotion:<10}: {count:>4} ({percentage:>5.1f}%)")
        
        orange_print("\n" + "="*80 + "\n")
    
    def save_results(self, output_dir: str = "results"):
        """Save benchmark results to JSON file."""
        os.makedirs(output_dir, exist_ok=True)
        
        # Prepare results
        results = {
            'benchmark_type': 'translation_classification',
            'timestamp': datetime.now().isoformat(),
            'total_samples': len(self.classification_results),
            'translation_needed': self.translation_needed_count,
            'translation_stats': self.calculate_statistics(self.translation_times),
            'classification_stats': self.calculate_statistics(self.classification_times),
            'total_pipeline_stats': self.calculate_statistics(self.total_times),
            'throughput': len(self.classification_results) / sum(self.total_times) if self.total_times else 0,
            'detailed_results': self.classification_results[:100]  # First 100 samples
        }
        
        # Calculate accuracy and other metrics if available
        correct_predictions = [r for r in self.classification_results if r['correct'] is True]
        total_with_labels = sum(1 for r in self.classification_results if r['correct'] is not None)
        if total_with_labels > 0:
            results['accuracy'] = len(correct_predictions) / total_with_labels
            
            # Calculate per-class metrics
            per_class_metrics = self._calculate_per_class_metrics()
            results['per_class_metrics'] = per_class_metrics
            
            # Calculate overall metrics
            total_true_positives = sum(metrics['tp'] for metrics in per_class_metrics.values())
            total_false_positives = sum(metrics['fp'] for metrics in per_class_metrics.values())
            total_false_negatives = sum(metrics['fn'] for metrics in per_class_metrics.values())
            
            overall_precision = total_true_positives / (total_true_positives + total_false_positives) if (total_true_positives + total_false_positives) > 0 else 0
            overall_recall = total_true_positives / (total_true_positives + total_false_negatives) if (total_true_positives + total_false_negatives) > 0 else 0
            overall_f1 = 2 * (overall_precision * overall_recall) / (overall_precision + overall_recall) if (overall_precision + overall_recall) > 0 else 0
            
            results['overall_precision'] = overall_precision
            results['overall_recall'] = overall_recall
            results['overall_f1'] = overall_f1
        
        # Save to file
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        filename = f"benchmark_translation_classification_{timestamp}.json"
        filepath = os.path.join(output_dir, filename)
        
        with open(filepath, 'w', encoding='utf-8') as f:
            json.dump(results, f, indent=2, ensure_ascii=False)
        
        green_print(f"\n✅ Results saved to: {filepath}")


def load_dataset(dataset_path: str, sample_size: int = -1, seed: int = 42, filter_valid_only: bool = True) -> List[Dict[str, str]]:
    """
    Load dataset from TSV file and optionally filter for valid emotion classes.
    
    Args:
        dataset_path: Path to the TSV file
        sample_size: Number of samples to load (-1 for all)
        seed: Random seed for sampling
        filter_valid_only: If True, only keep samples with valid emotion labels
        
    Returns:
        List of samples with 'emotion' and 'tweet' fields
    """
    with open(dataset_path, encoding="utf-8") as dataset_file:
        reader = list(csv.DictReader(dataset_file, delimiter="\t"))
    
    # Filter for valid emotion classes only
    if filter_valid_only:
        original_count = len(reader)
        reader = [
            sample for sample in reader 
            if sample.get('emotion', '').lower() in VALID_EMOTIONS or 
               LABEL_MAPPING.get(sample.get('emotion', '').lower()) in VALID_EMOTIONS
        ]
        filtered_count = original_count - len(reader)
        if filtered_count > 0:
            orange_print(f"Filtered out {filtered_count} samples with invalid emotion labels")
    
    random.seed(seed)
    if sample_size > 0:
        reader = random.sample(reader, min(sample_size, len(reader)))
    
    return reader


def run_benchmark(sample_size: int = 100, verbose: bool = False):
    """
    Run the translation and classification benchmark.
    
    Args:
        sample_size: Number of samples to benchmark (-1 for all)
        verbose: Whether to print individual results
    """
    # Load dataset
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
        red_print(f"❌ Dataset not found at: {dataset_path}")
        return
    
    orange_print(f"\n📁 Loading dataset from: {dataset_path}")
    dataset = load_dataset(dataset_path, sample_size=sample_size, filter_valid_only=True)
    orange_print(f"✅ Loaded {len(dataset)} samples (valid emotions only)\n")
    
    # Initialize benchmark
    benchmark = TranslationClassificationBenchmark()
    
    # Process each sample
    orange_print("🚀 Starting benchmark...\n")
    for i, sample in enumerate(dataset, 1):
        text = sample.get('tweet', sample.get('text', ''))
        true_label = sample.get('emotion', None)
        
        # Normalize label to valid emotion class
        if true_label:
            true_label = true_label.lower()
            true_label = LABEL_MAPPING.get(true_label, true_label)
            # Skip if still not valid after mapping
            if true_label not in VALID_EMOTIONS:
                if verbose:
                    red_print(f"⚠️  Skipping sample {i} with invalid label: {sample.get('emotion')}")
                continue
        
        # Benchmark this sample
        result = benchmark.benchmark_single_text(text, true_label)
        
        # Print progress
        if verbose:
            emoji = EMOTION_EMOJIS.get(result['predicted_emotion'], '')
            status = "✅" if result['correct'] else "❌" if result['correct'] is not None else "⚪"
            trans_marker = "🌐" if result['was_translated'] else "  "
            print(f"{status} {trans_marker} Sample {i}/{len(dataset)}: "
                  f"{emoji} {result['predicted_emotion']} "
                  f"(trans: {result['translation_time']*1000:.1f}ms, "
                  f"class: {result['classification_time']*1000:.1f}ms, "
                  f"total: {result['total_time']*1000:.1f}ms)")
        elif i % 10 == 0:
            print(f"⏳ Processed {i}/{len(dataset)} samples...")
    
    print()
    
    # Print summary
    benchmark.print_summary()
    
    # Save results
    output_dir = os.path.join(os.path.dirname(__file__), "results")
    benchmark.save_results(output_dir)


if __name__ == "__main__":
    import argparse
    
    parser = argparse.ArgumentParser(
        description='Benchmark translation and emotion classification performance'
    )
    parser.add_argument(
        '--sample-size', 
        type=int, 
        default=100,
        help='Number of samples to benchmark (-1 for all)'
    )
    parser.add_argument(
        '--verbose', 
        action='store_true',
        help='Print detailed results for each sample'
    )
    
    args = parser.parse_args()
    
    # Run benchmark
    orange_print("\n" + "="*80)
    orange_print("🚀 TRANSLATION & CLASSIFICATION BENCHMARK")
    orange_print("="*80 + "\n")
    
    run_benchmark(
        sample_size=args.sample_size,
        verbose=args.verbose
    )
