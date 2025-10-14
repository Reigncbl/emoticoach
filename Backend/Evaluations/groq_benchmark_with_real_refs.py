"""
Groq Models Translation Quality Benchmark - WITH PROPER REFERENCES
Evaluates translation quality using the rhyliieee/tagalog-filipino-english-translation dataset
which has REAL human reference translations (not LLM-generated)
"""

import os
import json
import time
import pandas as pd
import numpy as np
from typing import List, Dict, Any, Tuple
from datetime import datetime
from groq import Groq
from dotenv import load_dotenv
from collections import defaultdict
from datasets import load_dataset

# Install required packages if not available
try:
    from nltk.translate.bleu_score import sentence_bleu, corpus_bleu, SmoothingFunction
    from nltk.translate.meteor_score import meteor_score
    from rouge_score import rouge_scorer
    from bert_score import score as bert_score
    import nltk
    import matplotlib.pyplot as plt
    import seaborn as sns
    # Download required NLTK data
    try:
        nltk.data.find('wordnet')
    except LookupError:
        nltk.download('wordnet')
        nltk.download('punkt')
        nltk.download('omw-1.4')
except ImportError:
    print("❌ Missing required packages. Installing...")
    print("Run: pip install nltk rouge-score datasets matplotlib seaborn bert-score")
    exit(1)

# Load environment
load_dotenv()

# Groq models to benchmark
GROQ_MODELS = [
    "moonshotai/kimi-k2-instruct-0905",
    "meta-llama/llama-4-scout-17b-16e-instruct",
    "openai/gpt-oss-120b",
]


class GroqTranslationBenchmarkWithReferences:
    """Benchmark translation quality of Groq models using BLEU, ROUGE, and METEOR with REAL references"""
    
    def __init__(self, api_key: str, max_samples: int = None, use_test_split: bool = True):
        """Initialize the benchmark with Groq API key and load dataset
        
        Args:
            api_key: Groq API key
            max_samples: Maximum samples to use (None = use all)
            use_test_split: Use test split (True) or train split (False)
        """
        self.client = Groq(api_key=api_key)
        self.rouge_scorer = rouge_scorer.RougeScorer(['rouge1', 'rouge2', 'rougeL'], use_stemmer=True)
        self.smoothing = SmoothingFunction().method1
        
        # Load the translation dataset with REAL references
        print(f"📂 Loading translation dataset from HuggingFace...")
        ds = load_dataset("rhyliieee/tagalog-filipino-english-translation")
        
        split = 'test' if use_test_split else 'train'
        dataset = ds[split]
        
        print(f"✅ Loaded {len(dataset)} samples from {split} split")
        
        # Sample if needed
        if max_samples and max_samples < len(dataset):
            dataset = dataset.shuffle(seed=42).select(range(max_samples))
            print(f"📊 Using {max_samples} random samples")
        
        # Convert to list of tuples: (tagalog_text, english_reference)
        self.test_dataset = []
        for item in dataset:
            tagalog = item['tagalog'].strip()
            english = item['english'].strip()
            if tagalog and english:  # Skip empty entries
                self.test_dataset.append((tagalog, english))
        
        print(f"📊 Final dataset size: {len(self.test_dataset)} valid samples")
        print(f"✅ Using REAL human reference translations (not LLM-generated)")
    
    def translate_with_groq(self, text: str, model: str, timeout: int = 60) -> Tuple[str, float]:
        """
        Translate Tagalog/Filipino text to English using Groq model
        
        Args:
            text: Tagalog/Filipino text to translate
            model: Groq model to use
            timeout: Timeout in seconds for the request (default: 60)
            
        Returns:
            Tuple of (translated_text, inference_time_seconds)
        """
        # Check if this is a thinking model
        is_thinking_model = "gpt-oss" in model.lower() or "o1" in model.lower()
        
        if is_thinking_model:
            # Simpler prompt for thinking models - they reason internally
            prompt = f"""Translate this Tagalog/Filipino text to English:

{text}

English translation:"""
            system_content = "You are a Tagalog-English translator. Be concise and accurate."
        else:
            # Detailed prompt for regular models
            prompt = f"""Translate the following Tagalog/Filipino text to natural, fluent English.

Tagalog: {text}

Provide ONLY the English translation, nothing else."""
            system_content = "You are a professional Tagalog-English translator. Output ONLY the translation."

        try:
            start_time = time.time()
            
            # Create request parameters
            request_params = {
                "messages": [
                    {"role": "system", "content": system_content},
                    {"role": "user", "content": prompt}
                ],
                "model": model,
                "max_tokens": 300
            }
            
            # Only add temperature for non-thinking models
            if not is_thinking_model:
                request_params["temperature"] = 0.1
            
            response = self.client.chat.completions.create(**request_params)
            inference_time = time.time() - start_time
            
            translation = response.choices[0].message.content.strip()
            
            # Clean common prefixes
            prefixes = ["Translation:", "English:", "Translated:", "Output:", "Answer:", "English translation:"]
            for prefix in prefixes:
                if translation.startswith(prefix):
                    translation = translation[len(prefix):].strip()
            
            return translation, inference_time
            
        except Exception as e:
            print(f"\n❌ Translation error with {model}: {e}")
            return text, 0.0
    
    def calculate_bleu_scores(self, reference: str, hypothesis: str) -> Dict[str, float]:
        """Calculate BLEU scores (1-gram to 4-gram)"""
        ref_tokens = reference.lower().split()
        hyp_tokens = hypothesis.lower().split()
        
        scores = {}
        for n in range(1, 5):
            weights = [1.0/n] * n + [0.0] * (4 - n)
            try:
                score = sentence_bleu(
                    [ref_tokens],
                    hyp_tokens,
                    weights=weights,
                    smoothing_function=self.smoothing
                )
                scores[f'BLEU-{n}'] = score
            except:
                scores[f'BLEU-{n}'] = 0.0
        
        return scores
    
    def calculate_rouge_scores(self, reference: str, hypothesis: str) -> Dict[str, float]:
        """Calculate ROUGE scores (ROUGE-1, ROUGE-2, ROUGE-L)"""
        scores = self.rouge_scorer.score(reference, hypothesis)
        return {
            'ROUGE-1': scores['rouge1'].fmeasure,
            'ROUGE-2': scores['rouge2'].fmeasure,
            'ROUGE-L': scores['rougeL'].fmeasure
        }
    
    def calculate_meteor_score(self, reference: str, hypothesis: str) -> float:
        """Calculate METEOR score"""
        try:
            ref_tokens = reference.lower().split()
            hyp_tokens = hypothesis.lower().split()
            score = meteor_score([ref_tokens], hyp_tokens)
            return score
        except:
            return 0.0
    
    def calculate_bert_score(self, references: List[str], hypotheses: List[str]) -> Dict[str, float]:
        """
        Calculate BERTScore for a batch of translations
        BERTScore uses contextual embeddings and often correlates better with human judgment
        
        Args:
            references: List of reference translations
            hypotheses: List of model translations
            
        Returns:
            Dictionary with precision, recall, and F1 scores
        """
        try:
            # Calculate BERTScore (returns precision, recall, F1)
            P, R, F1 = bert_score(hypotheses, references, lang='en', verbose=False, device='cpu')
            
            return {
                'BERTScore-P': P.mean().item(),
                'BERTScore-R': R.mean().item(),
                'BERTScore-F1': F1.mean().item()
            }
        except Exception as e:
            print(f"\n⚠️  BERTScore calculation failed: {e}")
            return {
                'BERTScore-P': 0.0,
                'BERTScore-R': 0.0,
                'BERTScore-F1': 0.0
            }
    
    def benchmark_model(self, model: str) -> Dict[str, Any]:
        """Benchmark a single Groq model"""
        print(f"\n{'='*80}")
        print(f"🚀 BENCHMARKING: {model}")
        print(f"{'='*80}")
        
        results = []
        total_inference_time = 0
        
        bleu_scores = defaultdict(list)
        rouge_scores = defaultdict(list)
        meteor_scores = []
        
        # Collect all translations and references for BERTScore batch calculation
        all_references = []
        all_translations = []
        
        for i, (tagalog_text, reference) in enumerate(self.test_dataset, 1):
            print(f"\r⏳ Processing sample {i}/{len(self.test_dataset)}...", end='', flush=True)
            
            # Translate
            translation, inference_time = self.translate_with_groq(tagalog_text, model)
            total_inference_time += inference_time
            
            # Store for BERTScore batch calculation
            all_references.append(reference)
            all_translations.append(translation)
            
            # Calculate metrics against REAL reference
            bleu = self.calculate_bleu_scores(reference, translation)
            rouge = self.calculate_rouge_scores(reference, translation)
            meteor = self.calculate_meteor_score(reference, translation)
            
            # Aggregate scores
            for key, value in bleu.items():
                bleu_scores[key].append(value)
            for key, value in rouge.items():
                rouge_scores[key].append(value)
            meteor_scores.append(meteor)
            
            # Store detailed result (BERTScore will be added later)
            results.append({
                'tagalog': tagalog_text,
                'reference': reference,
                'translation': translation,
                'inference_time': inference_time,
                **bleu,
                **rouge,
                'METEOR': meteor
            })
        
        print(f"\r✅ Completed {len(self.test_dataset)} samples")
        
        # Calculate BERTScore for all samples at once (more efficient)
        print(f"📊 Calculating BERTScore...")
        bert_scores = self.calculate_bert_score(all_references, all_translations)
        
        # Add BERTScore to results (same for all samples in this batch approach)
        # For individual sample scores, we'd need to iterate, but batch average is more stable
        for result in results:
            result.update(bert_scores)
        
        # Calculate average scores
        avg_scores = {
            'model': model,
            'samples': len(self.test_dataset),
            'total_time': total_inference_time,
            'avg_time': total_inference_time / len(self.test_dataset),
            **{key: np.mean(values) for key, values in bleu_scores.items()},
            **{key: np.mean(values) for key, values in rouge_scores.items()},
            'METEOR': np.mean(meteor_scores),
            **bert_scores  # BERTScore is already averaged from batch calculation
        }
        
        # Print summary
        print(f"\n📊 RESULTS SUMMARY:")
        print(f"   Average Inference Time: {avg_scores['avg_time']*1000:.2f}ms per sample")
        print(f"   BLEU-1: {avg_scores['BLEU-1']:.4f}")
        print(f"   BLEU-2: {avg_scores['BLEU-2']:.4f}")
        print(f"   BLEU-3: {avg_scores['BLEU-3']:.4f}")
        print(f"   BLEU-4: {avg_scores['BLEU-4']:.4f}")
        print(f"   ROUGE-1: {avg_scores['ROUGE-1']:.4f}")
        print(f"   ROUGE-2: {avg_scores['ROUGE-2']:.4f}")
        print(f"   ROUGE-L: {avg_scores['ROUGE-L']:.4f}")
        print(f"   METEOR: {avg_scores['METEOR']:.4f}")
        print(f"   BERTScore-P: {avg_scores['BERTScore-P']:.4f}")
        print(f"   BERTScore-R: {avg_scores['BERTScore-R']:.4f}")
        print(f"   BERTScore-F1: {avg_scores['BERTScore-F1']:.4f}")
        
        return {
            'summary': avg_scores,
            'detailed_results': results
        }
    
    def run_full_benchmark(self, output_dir: str = "results") -> Dict[str, Any]:
        """Run benchmark on all Groq models"""
        print("="*80)
        print("🎯 GROQ MODELS TRANSLATION QUALITY BENCHMARK")
        print("   WITH REAL HUMAN REFERENCE TRANSLATIONS")
        print("="*80)
        print(f"📅 Date: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
        print(f"🔬 Metrics: BLEU (1-4), ROUGE (1, 2, L), METEOR")
        print(f"🤖 Models: {', '.join(GROQ_MODELS)}")
        print(f"📚 Dataset: rhyliieee/tagalog-filipino-english-translation")
        print("="*80)
        
        all_results = {}
        summary_data = []
        
        for model in GROQ_MODELS:
            try:
                result = self.benchmark_model(model)
                all_results[model] = result
                summary_data.append(result['summary'])
            except Exception as e:
                print(f"❌ Error benchmarking {model}: {e}")
                continue
        
        # Create summary DataFrame
        summary_df = pd.DataFrame(summary_data)
        
        # Sort by BLEU-4 (common metric for translation quality)
        summary_df = summary_df.sort_values('BLEU-4', ascending=False)
        
        print("\n" + "="*80)
        print("📊 OVERALL BENCHMARK SUMMARY")
        print("="*80)
        print(summary_df.to_string(index=False))
        
        # Find best model for each metric
        print("\n🏆 BEST MODELS BY METRIC:")
        metrics = ['BLEU-1', 'BLEU-2', 'BLEU-3', 'BLEU-4', 'ROUGE-1', 'ROUGE-2', 'ROUGE-L', 'METEOR', 'avg_time']
        for metric in metrics:
            if metric == 'avg_time':
                best_idx = summary_df[metric].idxmin()
                best_value = summary_df.loc[best_idx, metric]
                print(f"   {metric}: {summary_df.loc[best_idx, 'model']} ({best_value*1000:.2f}ms)")
            else:
                best_idx = summary_df[metric].idxmax()
                best_value = summary_df.loc[best_idx, metric]
                print(f"   {metric}: {summary_df.loc[best_idx, 'model']} ({best_value:.4f})")
        
        # Save results
        os.makedirs(output_dir, exist_ok=True)
        timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
        
        # Save summary CSV
        summary_path = os.path.join(output_dir, f'groq_benchmark_with_refs_summary_{timestamp}.csv')
        summary_df.to_csv(summary_path, index=False)
        print(f"\n💾 Summary saved: {summary_path}")
        
        # Save detailed results
        detailed_path = os.path.join(output_dir, f'groq_benchmark_with_refs_detailed_{timestamp}.json')
        with open(detailed_path, 'w', encoding='utf-8') as f:
            json.dump(all_results, f, indent=2, ensure_ascii=False)
        print(f"💾 Detailed results saved: {detailed_path}")
        
        # Save detailed results as CSV for each model
        for model, result in all_results.items():
            model_safe = model.replace('/', '_').replace('.', '_')
            detailed_csv_path = os.path.join(output_dir, f'groq_benchmark_with_refs_{model_safe}_{timestamp}.csv')
            model_df = pd.DataFrame(result['detailed_results'])
            model_df.to_csv(detailed_csv_path, index=False, encoding='utf-8')
            print(f"💾 {model} details saved: {detailed_csv_path}")
        
        # Generate markdown report
        report_path = os.path.join(output_dir, f'groq_benchmark_with_refs_report_{timestamp}.md')
        self._generate_markdown_report(summary_df, all_results, report_path)
        print(f"📄 Markdown report saved: {report_path}")
        
        # Generate visualization graphs
        print("\n📊 Generating comparison graphs...")
        self._generate_graphs(summary_df, all_results, output_dir, timestamp)
        
        return {
            'summary': summary_df.to_dict('records'),
            'detailed': all_results,
            'timestamp': timestamp
        }
    
    def _generate_graphs(self, summary_df: pd.DataFrame, all_results: Dict, output_dir: str, timestamp: str):
        """Generate comparison graphs"""
        # Set style
        sns.set_style("whitegrid")
        plt.rcParams['figure.figsize'] = (14, 10)
        
        # Prepare data - shorten model names for better display
        model_names = [model.split('/')[-1] if '/' in model else model for model in summary_df['model']]
        
        # Create a 2x4 subplot layout
        fig, axes = plt.subplots(2, 4, figsize=(24, 12))
        fig.suptitle('Groq Models Translation Quality Benchmark\n(With Real Human References)', 
                     fontsize=16, fontweight='bold')
        
        # 1. BLEU Scores Comparison (stacked bar)
        ax1 = axes[0, 0]
        bleu_metrics = ['BLEU-1', 'BLEU-2', 'BLEU-3', 'BLEU-4']
        bleu_data = summary_df[bleu_metrics].values
        x = np.arange(len(model_names))
        width = 0.2
        
        for i, metric in enumerate(bleu_metrics):
            ax1.bar(x + i*width, summary_df[metric], width, label=metric)
        
        ax1.set_xlabel('Models', fontweight='bold')
        ax1.set_ylabel('Score', fontweight='bold')
        ax1.set_title('BLEU Scores Comparison (1-4)', fontweight='bold')
        ax1.set_xticks(x + width * 1.5)
        ax1.set_xticklabels(model_names, rotation=45, ha='right')
        ax1.legend()
        ax1.grid(axis='y', alpha=0.3)
        
        # 2. ROUGE Scores Comparison
        ax2 = axes[0, 1]
        rouge_metrics = ['ROUGE-1', 'ROUGE-2', 'ROUGE-L']
        x = np.arange(len(model_names))
        width = 0.25
        
        for i, metric in enumerate(rouge_metrics):
            ax2.bar(x + i*width, summary_df[metric], width, label=metric)
        
        ax2.set_xlabel('Models', fontweight='bold')
        ax2.set_ylabel('Score', fontweight='bold')
        ax2.set_title('ROUGE Scores Comparison', fontweight='bold')
        ax2.set_xticks(x + width)
        ax2.set_xticklabels(model_names, rotation=45, ha='right')
        ax2.legend()
        ax2.grid(axis='y', alpha=0.3)
        
        # 3. METEOR Score Comparison
        ax3 = axes[0, 2]
        colors = sns.color_palette("husl", len(model_names))
        bars = ax3.bar(model_names, summary_df['METEOR'], color=colors)
        ax3.set_xlabel('Models', fontweight='bold')
        ax3.set_ylabel('METEOR Score', fontweight='bold')
        ax3.set_title('METEOR Score Comparison', fontweight='bold')
        ax3.set_xticklabels(model_names, rotation=45, ha='right')
        ax3.grid(axis='y', alpha=0.3)
        
        # Add value labels on bars
        for bar in bars:
            height = bar.get_height()
            ax3.text(bar.get_x() + bar.get_width()/2., height,
                    f'{height:.3f}', ha='center', va='bottom', fontsize=9)
        
        # 4. BERTScore Comparison
        ax4 = axes[0, 3]
        bert_metrics = ['BERTScore-P', 'BERTScore-R', 'BERTScore-F1']
        x = np.arange(len(model_names))
        width = 0.25
        
        for i, metric in enumerate(bert_metrics):
            ax4.bar(x + i*width, summary_df[metric], width, label=metric.replace('BERTScore-', ''))
        
        ax4.set_xlabel('Models', fontweight='bold')
        ax4.set_ylabel('Score', fontweight='bold')
        ax4.set_title('BERTScore Comparison (Contextual Embeddings)', fontweight='bold')
        ax4.set_xticks(x + width)
        ax4.set_xticklabels(model_names, rotation=45, ha='right')
        ax4.legend()
        ax4.grid(axis='y', alpha=0.3)
        
        # 5. Overall Score Comparison (BLEU-4 as primary metric)
        ax5 = axes[1, 0]
        colors = sns.color_palette("coolwarm", len(model_names))
        bars = ax5.barh(model_names, summary_df['BLEU-4'], color=colors)
        ax5.set_xlabel('BLEU-4 Score', fontweight='bold')
        ax5.set_ylabel('Models', fontweight='bold')
        ax5.set_title('Overall Translation Quality (BLEU-4)', fontweight='bold')
        ax5.grid(axis='x', alpha=0.3)
        
        # Add value labels
        for i, bar in enumerate(bars):
            width = bar.get_width()
            ax5.text(width, bar.get_y() + bar.get_height()/2.,
                    f'{width:.3f}', ha='left', va='center', fontsize=10, fontweight='bold')
        
        # 6. Inference Time Comparison
        ax6 = axes[1, 1]
        colors = sns.color_palette("viridis", len(model_names))
        bars = ax6.bar(model_names, summary_df['avg_time'] * 1000, color=colors)  # Convert to ms
        ax6.set_xlabel('Models', fontweight='bold')
        ax6.set_ylabel('Time (milliseconds)', fontweight='bold')
        ax6.set_title('Average Inference Time per Sample', fontweight='bold')
        ax6.set_xticklabels(model_names, rotation=45, ha='right')
        ax6.grid(axis='y', alpha=0.3)
        
        # Add value labels
        for bar in bars:
            height = bar.get_height()
            ax6.text(bar.get_x() + bar.get_width()/2., height,
                    f'{height:.0f}ms', ha='center', va='bottom', fontsize=9)
        
        # 7. Quality vs Speed Trade-off (scatter plot)
        ax7 = axes[1, 2]
        scatter = ax7.scatter(summary_df['avg_time'] * 1000, summary_df['BLEU-4'], 
                             s=200, c=summary_df['METEOR'], cmap='RdYlGn', 
                             alpha=0.6, edgecolors='black', linewidth=2)
        
        # Add model labels
        for i, model in enumerate(model_names):
            ax7.annotate(model, 
                        (summary_df['avg_time'].iloc[i] * 1000, summary_df['BLEU-4'].iloc[i]),
                        xytext=(5, 5), textcoords='offset points', fontsize=8)
        
        ax7.set_xlabel('Inference Time (ms)', fontweight='bold')
        ax7.set_ylabel('BLEU-4 Score', fontweight='bold')
        ax7.set_title('Quality vs Speed Trade-off\n(Color = METEOR Score)', fontweight='bold')
        ax7.grid(True, alpha=0.3)
        
        # Add colorbar
        cbar = plt.colorbar(scatter, ax=ax7)
        cbar.set_label('METEOR Score', fontweight='bold')
        
        # 8. BERTScore F1 Focus
        ax8 = axes[1, 3]
        colors = sns.color_palette("mako", len(model_names))
        bars = ax8.barh(model_names, summary_df['BERTScore-F1'], color=colors)
        ax8.set_xlabel('BERTScore-F1', fontweight='bold')
        ax8.set_ylabel('Models', fontweight='bold')
        ax8.set_title('Contextual Similarity (BERTScore-F1)', fontweight='bold')
        ax8.grid(axis='x', alpha=0.3)
        
        # Add value labels
        for i, bar in enumerate(bars):
            width = bar.get_width()
            ax8.text(width, bar.get_y() + bar.get_height()/2.,
                    f'{width:.3f}', ha='left', va='center', fontsize=10, fontweight='bold')
        
        # Adjust layout
        plt.tight_layout()
        
        # Save the figure
        graph_path = os.path.join(output_dir, f'groq_benchmark_comparison_{timestamp}.png')
        plt.savefig(graph_path, dpi=300, bbox_inches='tight')
        print(f"📊 Comparison graph saved: {graph_path}")
        
        # Create individual metric comparison chart
        self._generate_radar_chart(summary_df, model_names, output_dir, timestamp)
        
        plt.close('all')
    
    def _generate_radar_chart(self, summary_df: pd.DataFrame, model_names: List[str], output_dir: str, timestamp: str):
        """Generate radar chart for multi-metric comparison"""
        from math import pi
        
        # Select metrics for radar chart
        metrics = ['BLEU-4', 'ROUGE-L', 'METEOR', 'BERTScore-F1']
        num_vars = len(metrics)
        
        # Create figure
        fig, ax = plt.subplots(figsize=(10, 10), subplot_kw=dict(projection='polar'))
        
        # Compute angle for each metric
        angles = [n / float(num_vars) * 2 * pi for n in range(num_vars)]
        angles += angles[:1]
        
        # Plot each model
        colors = sns.color_palette("husl", len(model_names))
        
        for idx, (_, row) in enumerate(summary_df.iterrows()):
            values = [row[metric] for metric in metrics]
            values += values[:1]
            
            ax.plot(angles, values, 'o-', linewidth=2, label=model_names[idx], color=colors[idx])
            ax.fill(angles, values, alpha=0.15, color=colors[idx])
        
        # Fix axis to go in the right order and start at 12 o'clock
        ax.set_theta_offset(pi / 2)
        ax.set_theta_direction(-1)
        
        # Draw one axis per metric and add labels
        ax.set_xticks(angles[:-1])
        ax.set_xticklabels(metrics, fontsize=12, fontweight='bold')
        
        # Set y-axis limits
        ax.set_ylim(0, 1)
        
        # Add legend
        plt.legend(loc='upper right', bbox_to_anchor=(1.3, 1.1), fontsize=10)
        
        # Add title
        plt.title('Multi-Metric Performance Comparison\n(Radar Chart)', 
                 size=14, fontweight='bold', pad=20)
        
        # Save
        radar_path = os.path.join(output_dir, f'groq_benchmark_radar_{timestamp}.png')
        plt.savefig(radar_path, dpi=300, bbox_inches='tight')
        print(f"📊 Radar chart saved: {radar_path}")
        
        plt.close()
    
    def _generate_markdown_report(self, summary_df: pd.DataFrame, all_results: Dict, output_path: str):
        """Generate a markdown report of the benchmark results"""
        with open(output_path, 'w', encoding='utf-8') as f:
            f.write("# Groq Models Translation Quality Benchmark Report\n\n")
            f.write("## WITH REAL HUMAN REFERENCE TRANSLATIONS\n\n")
            f.write(f"**Date:** {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n\n")
            f.write("**Dataset:** rhyliieee/tagalog-filipino-english-translation (HuggingFace)\n\n")
            f.write("**Important:** This benchmark uses REAL human-created reference translations, ")
            f.write("not LLM-generated references. This provides more accurate and reliable evaluation.\n\n")
            
            f.write("## Overview\n\n")
            f.write("This benchmark evaluates the translation quality of various Groq models ")
            f.write("for Tagalog/Filipino to English translation using standard NLG metrics:\n\n")
            f.write("- **BLEU (1-4)**: Measures n-gram overlap between translation and reference\n")
            f.write("- **ROUGE (1, 2, L)**: Measures recall-oriented overlap\n")
            f.write("- **METEOR**: Considers synonyms and stemming\n\n")
            
            f.write("## Summary Results\n\n")
            f.write("| Model | BLEU-4 | ROUGE-L | METEOR | Avg Time (ms) |\n")
            f.write("|-------|--------|---------|--------|---------------|\n")
            for _, row in summary_df.iterrows():
                f.write(f"| {row['model']} | {row['BLEU-4']:.4f} | ")
                f.write(f"{row['ROUGE-L']:.4f} | {row['METEOR']:.4f} | ")
                f.write(f"{row['avg_time']*1000:.2f} |\n")
            
            f.write("\n## Detailed Metrics\n\n")
            f.write("| Model | BLEU-1 | BLEU-2 | BLEU-3 | BLEU-4 | ROUGE-1 | ROUGE-2 | ROUGE-L | METEOR |\n")
            f.write("|-------|--------|--------|--------|--------|---------|---------|---------|--------|\n")
            for _, row in summary_df.iterrows():
                f.write(f"| {row['model']} | ")
                for metric in ['BLEU-1', 'BLEU-2', 'BLEU-3', 'BLEU-4', 'ROUGE-1', 'ROUGE-2', 'ROUGE-L', 'METEOR']:
                    f.write(f"{row[metric]:.4f} | ")
                f.write("\n")
            
            f.write("\n## Best Models by Metric\n\n")
            metrics = ['BLEU-4', 'ROUGE-L', 'METEOR', 'avg_time']
            for metric in metrics:
                if metric == 'avg_time':
                    best_idx = summary_df[metric].idxmin()
                    best_value = summary_df.loc[best_idx, metric]
                    f.write(f"- **{metric}**: {summary_df.loc[best_idx, 'model']} ({best_value*1000:.2f}ms)\n")
                else:
                    best_idx = summary_df[metric].idxmax()
                    best_value = summary_df.loc[best_idx, metric]
                    f.write(f"- **{metric}**: {summary_df.loc[best_idx, 'model']} ({best_value:.4f})\n")
            
            f.write("\n## Sample Translations\n\n")
            for model, result in all_results.items():
                f.write(f"### {model}\n\n")
                # Show 3 sample translations
                for i, sample in enumerate(result['detailed_results'][:3], 1):
                    f.write(f"**Sample {i}**\n")
                    f.write(f"- Tagalog: *{sample['tagalog']}*\n")
                    f.write(f"- Reference: *{sample['reference']}*\n")
                    f.write(f"- Translation: *{sample['translation']}*\n")
                    f.write(f"- BLEU-4: {sample['BLEU-4']:.4f}, METEOR: {sample['METEOR']:.4f}\n\n")
            
            f.write("\n## Conclusion\n\n")
            best_overall = summary_df.iloc[0]['model']
            f.write(f"The best performing model overall (by BLEU-4) is **{best_overall}**.\n\n")
            f.write("These results are based on real human reference translations, providing ")
            f.write("reliable evaluation of translation quality.\n")


def main():
    """Main execution function"""
    import argparse
    
    # Parse command-line arguments
    parser = argparse.ArgumentParser(description='Benchmark Groq models for translation quality with real references')
    parser.add_argument(
        '--max-samples',
        type=int,
        default=100,
        help='Maximum samples to use from dataset (default: 100, use higher for full evaluation)'
    )
    parser.add_argument(
        '--use-train',
        action='store_true',
        help='Use train split instead of test split'
    )
    parser.add_argument(
        '--output-dir',
        type=str,
        default='results',
        help='Directory to save results'
    )
    
    args = parser.parse_args()
    
    # Get API key
    api_key = os.getenv('api_key')
    if not api_key:
        print("❌ Error: api_key not found in environment variables")
        print("Please set it in your .env file or environment as 'api_key'")
        return
    
    # Create benchmark instance
    benchmark = GroqTranslationBenchmarkWithReferences(
        api_key=api_key,
        max_samples=args.max_samples,
        use_test_split=not args.use_train
    )
    
    # Run full benchmark
    results = benchmark.run_full_benchmark(output_dir=args.output_dir)
    
    print("\n" + "="*80)
    print("✅ BENCHMARK COMPLETED SUCCESSFULLY")
    print("="*80)
    print("\n💡 Key Points:")
    print("   ✅ Used REAL human reference translations")
    print("   ✅ Accurate BLEU, ROUGE, and METEOR scores")
    print("   ✅ Reliable evaluation of translation quality")


if __name__ == "__main__":
    main()
