"""
Groq Models Translation Quality Benchmark - BLEU, ROUGE, METEOR
Evaluates translation quality for different Groq models using standard NLG metrics
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

# Install required packages if not available
try:
    from nltk.translate.bleu_score import sentence_bleu, corpus_bleu, SmoothingFunction
    from nltk.translate.meteor_score import meteor_score
    from rouge_score import rouge_scorer
    import nltk
    # Download required NLTK data
    try:
        nltk.data.find('wordnet')
    except LookupError:
        nltk.download('wordnet')
        nltk.download('punkt')
        nltk.download('omw-1.4')
except ImportError:
    print("❌ Missing required packages. Installing...")
    print("Run: pip install nltk rouge-score")
    exit(1)

# Load environment
load_dotenv()

# Groq models to benchmark
GROQ_MODELS = [
    "moonshotai/kimi-k2-instruct-0905",
    "meta-llama/llama-4-scout-17b-16e-instruct",
    "openai/gpt-oss-120b",
]

# Emotion labels for context
EMOTIONS = ['anger', 'disgust', 'fear', 'joy', 'neutral', 'sadness', 'surprise']

class GroqTranslationBenchmark:
    """Benchmark translation quality of Groq models using BLEU, ROUGE, and METEOR"""
    
    def __init__(self, api_key: str, dataset_path: str = None, max_samples_per_emotion: int = None):
        """Initialize the benchmark with Groq API key
        
        Args:
            api_key: Groq API key
            dataset_path: Path to EMOTERA TSV dataset (optional)
            max_samples_per_emotion: Maximum samples per emotion to use (None = use all)
        """
        self.client = Groq(api_key=api_key)
        self.rouge_scorer = rouge_scorer.RougeScorer(['rouge1', 'rouge2', 'rougeL'], use_stemmer=True)
        self.smoothing = SmoothingFunction().method1
        
        # Load test dataset
        if dataset_path and os.path.exists(dataset_path):
            self.test_dataset = self._load_emotera_dataset(dataset_path, max_samples_per_emotion)
            print(f"✅ Loaded EMOTERA dataset from: {dataset_path}")
        else:
            # Fallback to hardcoded dataset
            self.test_dataset = self._get_default_dataset()
            print(f"✅ Using default hardcoded dataset")
        
        print(f"📊 Test dataset size: {len(self.test_dataset)} samples")
        
        # Count samples per emotion
        emotion_counts = defaultdict(int)
        for _, emotion, _ in self.test_dataset:
            emotion_counts[emotion] += 1
        print(f"🎭 Emotion distribution:")
        for emotion in sorted(emotion_counts.keys()):
            print(f"   {emotion.capitalize()}: {emotion_counts[emotion]} samples")
    
    def _load_emotera_dataset(self, dataset_path: str, max_samples_per_emotion: int = None) -> List[Tuple[str, str, str]]:
        """Load EMOTERA-7class-cleaned.tsv dataset
        
        Args:
            dataset_path: Path to the TSV file
            max_samples_per_emotion: Maximum samples per emotion (None = use all)
            
        Returns:
            List of tuples: (filipino_text, emotion, reference_translation)
        """
        print(f"📂 Loading EMOTERA dataset from: {dataset_path}")
        
        # Read TSV file
        df = pd.read_csv(dataset_path, sep='\t', encoding='utf-8')
        
        # Normalize column names
        df.columns = [col.strip().lower() for col in df.columns]
        
        # Check columns
        if 'emotion' not in df.columns or 'tweet' not in df.columns:
            print(f"❌ Error: Expected 'emotion' and 'tweet' columns, found: {df.columns.tolist()}")
            return self._get_default_dataset()
        
        # Normalize emotion labels to lowercase
        df['emotion'] = df['emotion'].str.strip().str.lower()
        df['tweet'] = df['tweet'].str.strip()
        
        # Remove any empty rows
        df = df.dropna(subset=['emotion', 'tweet'])
        df = df[df['tweet'].str.len() > 0]
        
        # Sample data per emotion if max_samples_per_emotion is specified
        if max_samples_per_emotion:
            sampled_dfs = []
            for emotion in df['emotion'].unique():
                emotion_df = df[df['emotion'] == emotion]
                if len(emotion_df) > max_samples_per_emotion:
                    emotion_df = emotion_df.sample(n=max_samples_per_emotion, random_state=42)
                sampled_dfs.append(emotion_df)
            df = pd.concat(sampled_dfs, ignore_index=True)
        
        # For EMOTERA dataset, we don't have reference translations
        # We'll generate them using the first model (as a baseline) or use back-translation
        # For now, we'll use the original text as reference (will be translated later)
        dataset = []
        for _, row in df.iterrows():
            filipino_text = row['tweet']
            emotion = row['emotion']
            # We'll generate reference translations on-the-fly during benchmarking
            # For now, use empty string as placeholder
            dataset.append((filipino_text, emotion, ""))
        
        print(f"✅ Loaded {len(dataset)} samples from EMOTERA dataset")
        return dataset
    
    def _get_default_dataset(self) -> List[Tuple[str, str, str]]:
        """Get default hardcoded dataset with reference translations"""
        return [
            # Anger
            ("Galit na galit ako sa'yo!", "anger", "I am very angry at you!"),
            ("Nakakainis ka talaga!", "anger", "You are really annoying!"),
            ("Sobrang badtrip ako ngayon!", "anger", "I am extremely upset right now!"),
            ("Ang gago mo naman!", "anger", "You are such an idiot!"),
            ("Putangina naman, ang hassle!", "anger", "Damn it, this is such a hassle!"),
            
            # Joy
            ("Sobrang saya ko ngayon!", "joy", "I am so happy right now!"),
            ("Masaya ako na nandito ka!", "joy", "I am happy that you are here!"),
            ("Grabe, ang sarap ng feeling!", "joy", "Wow, this feeling is amazing!"),
            ("Salamat sa lahat! Happy ako!", "joy", "Thank you for everything! I am happy!"),
            ("Best day ever talaga!", "joy", "This is truly the best day ever!"),
            
            # Sadness
            ("Malungkot ako ngayon.", "sadness", "I am sad right now."),
            ("Namimiss kita talaga.", "sadness", "I really miss you."),
            ("Ang sakit ng nararamdaman ko.", "sadness", "What I am feeling really hurts."),
            ("Umiiyak ako dahil sa'yo.", "sadness", "I am crying because of you."),
            ("Nakakalungkot yung nangyari.", "sadness", "What happened is saddening."),
            
            # Fear
            ("Takot ako sa dilim.", "fear", "I am afraid of the dark."),
            ("Kinakabahan ako sa exam.", "fear", "I am nervous about the exam."),
            ("Natatakot akong mag-isa.", "fear", "I am scared to be alone."),
            ("Grabe, nakakatakot yung tunog!", "fear", "Wow, that sound is frightening!"),
            ("Paranoid na ako ngayon.", "fear", "I am paranoid now."),
            
            # Disgust
            ("Kadiri naman yan!", "disgust", "That is disgusting!"),
            ("Nakakasuklam yung amoy!", "disgust", "The smell is nauseating!"),
            ("Yuck, ang pangit naman!", "disgust", "Yuck, that is so ugly!"),
            ("Nakakasuka yung lasa.", "disgust", "The taste is sickening."),
            ("Kadiri ka naman!", "disgust", "You are disgusting!"),
            
            # Surprise
            ("Wow, hindi ko inaasahan yan!", "surprise", "Wow, I did not expect that!"),
            ("Gulat na gulat ako!", "surprise", "I am very surprised!"),
            ("Grabe, shocking naman!", "surprise", "Wow, that is shocking!"),
            ("Hindi ko alam na ganyan pala!", "surprise", "I did not know it was like that!"),
            ("Nakakabiglang balita!", "surprise", "This is surprising news!"),
            
            # Neutral
            ("Pumunta ako sa mall.", "neutral", "I went to the mall."),
            ("Kumain ako ng tanghalian.", "neutral", "I ate lunch."),
            ("Nagbabasa ako ng libro.", "neutral", "I am reading a book."),
            ("Maglalakad ako papunta doon.", "neutral", "I will walk there."),
            ("Nandito lang ako.", "neutral", "I am just here."),
        ]
    
    def translate_with_groq(self, text: str, emotion: str, model: str, timeout: int = 60) -> Tuple[str, float]:
        """
        Translate Filipino/Taglish text to English using Groq model
        
        Args:
            text: Filipino/Taglish text to translate
            emotion: Emotion context for translation
            model: Groq model to use
            timeout: Timeout in seconds for the request (default: 60)
            
        Returns:
            Tuple of (translated_text, inference_time_seconds)
        """
        # Check if this is a thinking model
        is_thinking_model = "gpt-oss" in model.lower() or "o1" in model.lower()
        
        if is_thinking_model:
            # Simpler prompt for thinking models - they reason internally
            prompt = f"""Translate this Filipino/Taglish text to English while preserving the emotional tone ({emotion}):

{text}

English translation:"""
            system_content = "You are a Filipino-English translator. Be concise."
        else:
            # Detailed prompt for regular models
            prompt = f"""You are an expert Filipino-English translator specializing in emotional expressions.

Translate this Filipino/Taglish text to English while:
1. Preserving the EXACT emotional intensity ({emotion})
2. Keeping informal language informal (slang → slang, casual → casual)
3. Maintaining cultural context of Filipino emotional expressions
4. Preserving punctuation that indicates emotion (!!!, ???, etc.)

Text: {text}

Provide ONLY the English translation, nothing else."""
            system_content = "You are a Filipino-English emotion-preserving translator. Output ONLY the translation."

        try:
            start_time = time.time()
            
            # Create request parameters
            request_params = {
                "messages": [
                    {"role": "system", "content": system_content},
                    {"role": "user", "content": prompt}
                ],
                "model": model,
                "max_tokens": 200
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
        """
        Calculate BLEU scores (1-gram to 4-gram)
        
        Args:
            reference: Reference translation
            hypothesis: Model-generated translation
            
        Returns:
            Dictionary with BLEU-1, BLEU-2, BLEU-3, BLEU-4 scores
        """
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
        """
        Calculate ROUGE scores (ROUGE-1, ROUGE-2, ROUGE-L)
        
        Args:
            reference: Reference translation
            hypothesis: Model-generated translation
            
        Returns:
            Dictionary with ROUGE scores (F1 scores)
        """
        scores = self.rouge_scorer.score(reference, hypothesis)
        return {
            'ROUGE-1': scores['rouge1'].fmeasure,
            'ROUGE-2': scores['rouge2'].fmeasure,
            'ROUGE-L': scores['rougeL'].fmeasure
        }
    
    def calculate_meteor_score(self, reference: str, hypothesis: str) -> float:
        """
        Calculate METEOR score
        
        Args:
            reference: Reference translation
            hypothesis: Model-generated translation
            
        Returns:
            METEOR score
        """
        try:
            ref_tokens = reference.lower().split()
            hyp_tokens = hypothesis.lower().split()
            score = meteor_score([ref_tokens], hyp_tokens)
            return score
        except:
            return 0.0
    
    def benchmark_model(self, model: str, reference_model: str = None) -> Dict[str, Any]:
        """
        Benchmark a single Groq model
        
        Args:
            model: Groq model name
            reference_model: Model to use for generating reference translations (if not provided in dataset)
            
        Returns:
            Dictionary with benchmark results
        """
        print(f"\n{'='*80}")
        print(f"🚀 BENCHMARKING: {model}")
        print(f"{'='*80}")
        
        results = []
        total_inference_time = 0
        
        bleu_scores = defaultdict(list)
        rouge_scores = defaultdict(list)
        meteor_scores = []
        
        # Check if we need to generate reference translations
        need_references = any(ref == "" for _, _, ref in self.test_dataset)
        references_cache = {}
        
        if need_references and reference_model:
            print(f"📝 Generating reference translations using {reference_model}...")
            for i, (filipino_text, emotion, _) in enumerate(self.test_dataset, 1):
                print(f"\r⏳ Generating references {i}/{len(self.test_dataset)}...", end='', flush=True)
                ref_translation, _ = self.translate_with_groq(filipino_text, emotion, reference_model)
                references_cache[filipino_text] = ref_translation
            print(f"\r✅ Generated {len(references_cache)} reference translations")
        
        for i, (filipino_text, emotion, reference) in enumerate(self.test_dataset, 1):
            print(f"\r⏳ Processing sample {i}/{len(self.test_dataset)}...", end='', flush=True)
            
            # Translate
            translation, inference_time = self.translate_with_groq(filipino_text, emotion, model)
            total_inference_time += inference_time
            
            # Use cached reference if available
            if reference == "" and filipino_text in references_cache:
                reference = references_cache[filipino_text]
            
            # Skip metric calculation if no reference available
            if reference == "":
                print(f"\n⚠️  Warning: No reference translation for sample {i}, skipping metrics")
                results.append({
                    'filipino': filipino_text,
                    'emotion': emotion,
                    'reference': 'N/A',
                    'translation': translation,
                    'inference_time': inference_time,
                    'BLEU-1': 0.0,
                    'BLEU-2': 0.0,
                    'BLEU-3': 0.0,
                    'BLEU-4': 0.0,
                    'ROUGE-1': 0.0,
                    'ROUGE-2': 0.0,
                    'ROUGE-L': 0.0,
                    'METEOR': 0.0
                })
                continue
            
            # Calculate metrics
            bleu = self.calculate_bleu_scores(reference, translation)
            rouge = self.calculate_rouge_scores(reference, translation)
            meteor = self.calculate_meteor_score(reference, translation)
            
            # Aggregate scores
            for key, value in bleu.items():
                bleu_scores[key].append(value)
            for key, value in rouge.items():
                rouge_scores[key].append(value)
            meteor_scores.append(meteor)
            
            # Store detailed result
            results.append({
                'filipino': filipino_text,
                'emotion': emotion,
                'reference': reference,
                'translation': translation,
                'inference_time': inference_time,
                **bleu,
                **rouge,
                'METEOR': meteor
            })
        
        print(f"\r✅ Completed {len(self.test_dataset)} samples")
        
        # Calculate average scores
        avg_scores = {
            'model': model,
            'samples': len(self.test_dataset),
            'total_time': total_inference_time,
            'avg_time': total_inference_time / len(self.test_dataset),
            **{key: np.mean(values) for key, values in bleu_scores.items()},
            **{key: np.mean(values) for key, values in rouge_scores.items()},
            'METEOR': np.mean(meteor_scores)
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
        
        return {
            'summary': avg_scores,
            'detailed_results': results
        }
    
    def run_full_benchmark(self, output_dir: str = "results", reference_model: str = None) -> Dict[str, Any]:
        """
        Run benchmark on all Groq models
        
        Args:
            output_dir: Directory to save results
            reference_model: Model to use for generating reference translations (default: first model in list)
            
        Returns:
            Dictionary with all benchmark results
        """
        print("="*80)
        print("🎯 GROQ MODELS TRANSLATION QUALITY BENCHMARK")
        print("="*80)
        print(f"📅 Date: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
        print(f"🔬 Metrics: BLEU (1-4), ROUGE (1, 2, L), METEOR")
        print(f"🤖 Models: {', '.join(GROQ_MODELS)}")
        print("="*80)
        
        # Use first model as reference if not specified
        if reference_model is None:
            reference_model = GROQ_MODELS[0]
            print(f"📝 Using {reference_model} to generate reference translations")
        
        all_results = {}
        summary_data = []
        
        for model in GROQ_MODELS:
            try:
                result = self.benchmark_model(model, reference_model=reference_model)
                all_results[model] = result
                summary_data.append(result['summary'])
            except Exception as e:
                print(f"❌ Error benchmarking {model}: {e}")
                continue
        
        # Create summary DataFrame
        summary_df = pd.DataFrame(summary_data)
        
        # Sort by average BLEU-4 (common metric for translation quality)
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
        summary_path = os.path.join(output_dir, f'groq_benchmark_summary_{timestamp}.csv')
        summary_df.to_csv(summary_path, index=False)
        print(f"\n💾 Summary saved: {summary_path}")
        
        # Save detailed results
        detailed_path = os.path.join(output_dir, f'groq_benchmark_detailed_{timestamp}.json')
        with open(detailed_path, 'w', encoding='utf-8') as f:
            json.dump(all_results, f, indent=2, ensure_ascii=False)
        print(f"💾 Detailed results saved: {detailed_path}")
        
        # Save detailed results as CSV for each model
        for model, result in all_results.items():
            model_safe = model.replace('/', '_').replace('.', '_')
            detailed_csv_path = os.path.join(output_dir, f'groq_benchmark_{model_safe}_{timestamp}.csv')
            model_df = pd.DataFrame(result['detailed_results'])
            model_df.to_csv(detailed_csv_path, index=False, encoding='utf-8')
            print(f"💾 {model} details saved: {detailed_csv_path}")
        
        # Generate markdown report
        report_path = os.path.join(output_dir, f'groq_benchmark_report_{timestamp}.md')
        self._generate_markdown_report(summary_df, all_results, report_path)
        print(f"📄 Markdown report saved: {report_path}")
        
        return {
            'summary': summary_df.to_dict('records'),
            'detailed': all_results,
            'timestamp': timestamp
        }
    
    def _generate_markdown_report(self, summary_df: pd.DataFrame, all_results: Dict, output_path: str):
        """Generate a markdown report of the benchmark results"""
        with open(output_path, 'w', encoding='utf-8') as f:
            f.write("# Groq Models Translation Quality Benchmark Report\n\n")
            f.write(f"**Date:** {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n\n")
            f.write("## Overview\n\n")
            f.write("This benchmark evaluates the translation quality of various Groq models ")
            f.write("for Filipino/Taglish to English translation using standard NLG metrics:\n\n")
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
                    f.write(f"**Sample {i}** ({sample['emotion']})\n")
                    f.write(f"- Filipino: *{sample['filipino']}*\n")
                    f.write(f"- Reference: *{sample['reference']}*\n")
                    f.write(f"- Translation: *{sample['translation']}*\n")
                    f.write(f"- BLEU-4: {sample['BLEU-4']:.4f}, METEOR: {sample['METEOR']:.4f}\n\n")
            
            f.write("\n## Conclusion\n\n")
            best_overall = summary_df.iloc[0]['model']
            f.write(f"The best performing model overall (by BLEU-4) is **{best_overall}**.\n")
            f.write("For specific use cases, consider the trade-offs between translation quality ")
            f.write("and inference speed.\n")


def main():
    """Main execution function"""
    import argparse
    
    # Parse command-line arguments
    parser = argparse.ArgumentParser(description='Benchmark Groq models for translation quality')
    parser.add_argument(
        '--dataset',
        type=str,
        default=r'C:\Users\John Carlo\emoticoach\emoticoach\Backend\Evaluations\EMOTERA-7class-cleaned.tsv',
        help='Path to EMOTERA dataset TSV file'
    )
    parser.add_argument(
        '--max-samples',
        type=int,
        default=None,
        help='Maximum samples per emotion to use (default: use all)'
    )
    parser.add_argument(
        '--reference-model',
        type=str,
        default='meta-llama/llama-4-scout-17b-16e-instruct',
        help='Model to use for generating reference translations (use fast model, not thinking model)'
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
        print("❌ Error: GROQ_API_KEY not found in environment variables")
        print("Please set it in your .env file or environment as 'api_key'")
        return
    
    # Create benchmark instance
    benchmark = GroqTranslationBenchmark(
        api_key=api_key,
        dataset_path=args.dataset,
        max_samples_per_emotion=args.max_samples
    )
    
    # Run full benchmark
    results = benchmark.run_full_benchmark(
        output_dir=args.output_dir,
        reference_model=args.reference_model
    )
    
    print("\n" + "="*80)
    print("✅ BENCHMARK COMPLETED SUCCESSFULLY")
    print("="*80)


if __name__ == "__main__":
    main()
