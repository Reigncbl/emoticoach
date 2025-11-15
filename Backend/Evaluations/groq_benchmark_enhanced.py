"""
Enhanced Groq Translation Benchmark with LLM-as-Judge
Includes both reference-based metrics (BLEU, ROUGE, METEOR) 
and LLM-based evaluation (no references needed)
"""

import os
import json
import time
import pandas as pd
import numpy as np
from typing import List, Dict, Any, Tuple, Optional
from datetime import datetime
from groq import Groq
from dotenv import load_dotenv
from collections import defaultdict

# Traditional metrics
try:
    from nltk.translate.bleu_score import sentence_bleu, SmoothingFunction
    from nltk.translate.meteor_score import meteor_score
    from rouge_score import rouge_scorer
    import nltk
    METRICS_AVAILABLE = True
except ImportError:
    METRICS_AVAILABLE = False
    print("⚠️  Warning: nltk/rouge-score not available. Only LLM-as-judge evaluation will be used.")

load_dotenv()

# Groq models to benchmark
GROQ_MODELS = [
    "moonshotai/kimi-k2-instruct-0905",
    "meta-llama/llama-4-scout-17b-16e-instruct",
    "openai/gpt-oss-120b",
]

# Judge model (use best available)
JUDGE_MODEL = "meta-llama/llama-4-scout-17b-16e-instruct"

EMOTIONS = ['anger', 'disgust', 'fear', 'joy', 'neutral', 'sadness', 'surprise']


class EnhancedGroqBenchmark:
    """Enhanced benchmark with both reference-based and LLM-as-judge evaluation"""
    
    def __init__(self, api_key: str, dataset_path: str = None, 
                 max_samples_per_emotion: int = None,
                 use_llm_judge: bool = True,
                 use_reference_metrics: bool = True):
        """
        Initialize benchmark
        
        Args:
            api_key: Groq API key
            dataset_path: Path to EMOTERA TSV dataset
            max_samples_per_emotion: Max samples per emotion
            use_llm_judge: Use LLM-as-judge evaluation
            use_reference_metrics: Use BLEU/ROUGE/METEOR (requires references)
        """
        self.client = Groq(api_key=api_key)
        self.use_llm_judge = use_llm_judge
        self.use_reference_metrics = use_reference_metrics and METRICS_AVAILABLE
        
        if self.use_reference_metrics:
            self.rouge_scorer = rouge_scorer.RougeScorer(['rouge1', 'rouge2', 'rougeL'], use_stemmer=True)
            self.smoothing = SmoothingFunction().method1
        
        # Load dataset
        if dataset_path and os.path.exists(dataset_path):
            self.test_dataset = self._load_dataset(dataset_path, max_samples_per_emotion)
        else:
            print("❌ No dataset provided")
            self.test_dataset = []
    
    def _load_dataset(self, dataset_path: str, max_samples: int = None) -> List[Tuple[str, str]]:
        """Load dataset (Filipino text, emotion) - no references needed"""
        df = pd.read_csv(dataset_path, sep='\t', encoding='utf-8')
        df.columns = [col.strip().lower() for col in df.columns]
        df['emotion'] = df['emotion'].str.strip().str.lower()
        df['tweet'] = df['tweet'].str.strip()
        df = df.dropna(subset=['emotion', 'tweet'])
        
        if max_samples:
            sampled_dfs = []
            for emotion in df['emotion'].unique():
                emotion_df = df[df['emotion'] == emotion]
                if len(emotion_df) > max_samples:
                    emotion_df = emotion_df.sample(n=max_samples, random_state=42)
                sampled_dfs.append(emotion_df)
            df = pd.concat(sampled_dfs, ignore_index=True)
        
        dataset = [(row['tweet'], row['emotion']) for _, row in df.iterrows()]
        return dataset
    
    def translate_with_groq(self, text: str, emotion: str, model: str) -> Tuple[str, float]:
        """Translate text using Groq model"""
        is_thinking_model = "gpt-oss" in model.lower() or "o1" in model.lower()
        
        if is_thinking_model:
            prompt = f"""Translate this Filipino/Taglish text to English while preserving the emotional tone ({emotion}):

{text}

English translation:"""
            system_content = "You are a Filipino-English translator. Be concise."
        else:
            prompt = f"""Translate this Filipino/Taglish text to English preserving the {emotion} emotion:

{text}

Provide ONLY the English translation."""
            system_content = "You are a Filipino-English translator. Output ONLY the translation."
        
        try:
            start_time = time.time()
            request_params = {
                "messages": [
                    {"role": "system", "content": system_content},
                    {"role": "user", "content": prompt}
                ],
                "model": model,
                "max_tokens": 200
            }
            
            if not is_thinking_model:
                request_params["temperature"] = 0.1
            
            response = self.client.chat.completions.create(**request_params)
            inference_time = time.time() - start_time
            
            translation = response.choices[0].message.content.strip()
            
            # Clean prefixes
            for prefix in ["Translation:", "English:", "Translated:", "Output:", "Answer:", "English translation:"]:
                if translation.startswith(prefix):
                    translation = translation[len(prefix):].strip()
            
            return translation, inference_time
        except Exception as e:
            print(f"\n❌ Translation error: {e}")
            return text, 0.0
    
    def evaluate_with_llm_judge(self, original: str, translation: str, emotion: str) -> Dict[str, float]:
        """
        Evaluate translation quality using LLM as judge
        No reference translation needed!
        """
        evaluation_prompt = f"""You are an expert bilingual Filipino-English evaluator.

Original (Filipino/Taglish): {original}
Translation (English): {translation}
Expected emotion: {emotion}

Evaluate the translation on these criteria (0-10 scale):

1. ACCURACY: Does it preserve the meaning of the original?
2. NATURALNESS: Does it sound natural in English?
3. EMOTION: Is the emotional tone ({emotion}) preserved?
4. COMPLETENESS: Is all information translated?

Respond in JSON format:
{{
    "accuracy": <score>,
    "naturalness": <score>,
    "emotion_preservation": <score>,
    "completeness": <score>,
    "overall": <average_score>,
    "explanation": "<brief explanation>"
}}"""
        
        try:
            response = self.client.chat.completions.create(
                messages=[
                    {"role": "system", "content": "You are a translation quality evaluator. Respond in JSON format."},
                    {"role": "user", "content": evaluation_prompt}
                ],
                model=JUDGE_MODEL,
                temperature=0.1,
                max_tokens=300
            )
            
            result = response.choices[0].message.content.strip()
            
            # Extract JSON
            if "```json" in result:
                result = result.split("```json")[1].split("```")[0].strip()
            elif "```" in result:
                result = result.split("```")[1].split("```")[0].strip()
            
            scores = json.loads(result)
            return scores
        except Exception as e:
            print(f"\n⚠️  LLM judge error: {e}")
            return {
                "accuracy": 0,
                "naturalness": 0,
                "emotion_preservation": 0,
                "completeness": 0,
                "overall": 0,
                "explanation": "Error in evaluation"
            }
    
    def calculate_reference_metrics(self, reference: str, hypothesis: str) -> Dict[str, float]:
        """Calculate BLEU, ROUGE, METEOR (requires reference)"""
        if not self.use_reference_metrics:
            return {}
        
        ref_tokens = reference.lower().split()
        hyp_tokens = hypothesis.lower().split()
        
        metrics = {}
        
        # BLEU scores
        for n in range(1, 5):
            weights = [1.0/n] * n + [0.0] * (4 - n)
            try:
                metrics[f'BLEU-{n}'] = sentence_bleu([ref_tokens], hyp_tokens, 
                                                      weights=weights, 
                                                      smoothing_function=self.smoothing)
            except:
                metrics[f'BLEU-{n}'] = 0.0
        
        # ROUGE scores
        rouge = self.rouge_scorer.score(reference, hypothesis)
        metrics['ROUGE-1'] = rouge['rouge1'].fmeasure
        metrics['ROUGE-2'] = rouge['rouge2'].fmeasure
        metrics['ROUGE-L'] = rouge['rougeL'].fmeasure
        
        # METEOR
        try:
            metrics['METEOR'] = meteor_score([ref_tokens], hyp_tokens)
        except:
            metrics['METEOR'] = 0.0
        
        return metrics
    
    def benchmark_model(self, model: str, reference_model: str = None) -> Dict[str, Any]:
        """Benchmark a single model"""
        print(f"\n{'='*80}")
        print(f"🚀 BENCHMARKING: {model}")
        print(f"{'='*80}")
        
        results = []
        total_inference_time = 0
        
        # Metrics aggregation
        llm_judge_scores = defaultdict(list)
        reference_metrics = defaultdict(list) if self.use_reference_metrics else None
        
        # Generate references if using reference metrics
        references_cache = {}
        if self.use_reference_metrics and reference_model:
            print(f"📝 Generating reference translations using {reference_model}...")
            for i, (filipino_text, emotion) in enumerate(self.test_dataset, 1):
                print(f"\r⏳ Generating references {i}/{len(self.test_dataset)}...", end='', flush=True)
                ref_translation, _ = self.translate_with_groq(filipino_text, emotion, reference_model)
                references_cache[filipino_text] = ref_translation
            print(f"\r✅ Generated {len(references_cache)} reference translations")
        
        # Benchmark translations
        for i, (filipino_text, emotion) in enumerate(self.test_dataset, 1):
            print(f"\r⏳ Processing sample {i}/{len(self.test_dataset)}...", end='', flush=True)
            
            # Translate
            translation, inference_time = self.translate_with_groq(filipino_text, emotion, model)
            total_inference_time += inference_time
            
            result = {
                'filipino': filipino_text,
                'emotion': emotion,
                'translation': translation,
                'inference_time': inference_time
            }
            
            # LLM-as-judge evaluation
            if self.use_llm_judge:
                llm_scores = self.evaluate_with_llm_judge(filipino_text, translation, emotion)
                result.update({f'llm_{k}': v for k, v in llm_scores.items()})
                for k, v in llm_scores.items():
                    if isinstance(v, (int, float)):
                        llm_judge_scores[k].append(v)
            
            # Reference-based metrics
            if self.use_reference_metrics and filipino_text in references_cache:
                reference = references_cache[filipino_text]
                result['reference'] = reference
                ref_metrics = self.calculate_reference_metrics(reference, translation)
                result.update(ref_metrics)
                for k, v in ref_metrics.items():
                    reference_metrics[k].append(v)
            
            results.append(result)
        
        print(f"\r✅ Completed {len(self.test_dataset)} samples")
        
        # Calculate averages
        summary = {
            'model': model,
            'samples': len(self.test_dataset),
            'total_time': total_inference_time,
            'avg_time': total_inference_time / len(self.test_dataset)
        }
        
        # Add LLM judge averages
        if self.use_llm_judge:
            for k, values in llm_judge_scores.items():
                summary[f'avg_llm_{k}'] = np.mean(values)
        
        # Add reference metric averages
        if self.use_reference_metrics and reference_metrics:
            for k, values in reference_metrics.items():
                summary[f'avg_{k}'] = np.mean(values)
        
        # Print summary
        print(f"\n📊 RESULTS SUMMARY:")
        print(f"   Average Inference Time: {summary['avg_time']*1000:.2f}ms")
        
        if self.use_llm_judge:
            print(f"\n   LLM-as-Judge Scores (0-10):")
            for k in ['accuracy', 'naturalness', 'emotion_preservation', 'completeness', 'overall']:
                if f'avg_llm_{k}' in summary:
                    print(f"   - {k.replace('_', ' ').title()}: {summary[f'avg_llm_{k}']:.2f}")
        
        if self.use_reference_metrics and reference_metrics:
            print(f"\n   Reference-Based Metrics (0-1):")
            for k in ['BLEU-4', 'ROUGE-L', 'METEOR']:
                if f'avg_{k}' in summary:
                    print(f"   - {k}: {summary[f'avg_{k}']:.4f}")
        
        return {'summary': summary, 'detailed_results': results}
    
    def run_full_benchmark(self, output_dir: str = "results", 
                          reference_model: str = None) -> Dict[str, Any]:
        """Run full benchmark on all models"""
        print("="*80)
        print("🎯 ENHANCED GROQ TRANSLATION BENCHMARK")
        print("="*80)
        print(f"📅 Date: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
        print(f"🔬 Evaluation Methods:")
        if self.use_llm_judge:
            print(f"   ✅ LLM-as-Judge (no references needed)")
        if self.use_reference_metrics:
            print(f"   ✅ Reference-based (BLEU, ROUGE, METEOR)")
        print(f"🤖 Models: {', '.join(GROQ_MODELS)}")
        print("="*80)
        
        if self.use_reference_metrics and not reference_model:
            reference_model = GROQ_MODELS[0]
            print(f"📝 Using {reference_model} for reference translations")
        
        all_results = {}
        summary_data = []
        
        for model in GROQ_MODELS:
            try:
                result = self.benchmark_model(model, reference_model if self.use_reference_metrics else None)
                all_results[model] = result
                summary_data.append(result['summary'])
            except Exception as e:
                print(f"❌ Error benchmarking {model}: {e}")
                continue
        
        # Create summary
        summary_df = pd.DataFrame(summary_data)
        
        print("\n" + "="*80)
        print("📊 OVERALL BENCHMARK SUMMARY")
        print("="*80)
        print(summary_df.to_string(index=False))
        
        # Save results
        os.makedirs(output_dir, exist_ok=True)
        timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
        
        summary_path = os.path.join(output_dir, f'enhanced_benchmark_summary_{timestamp}.csv')
        summary_df.to_csv(summary_path, index=False)
        print(f"\n💾 Summary saved: {summary_path}")
        
        detailed_path = os.path.join(output_dir, f'enhanced_benchmark_detailed_{timestamp}.json')
        with open(detailed_path, 'w', encoding='utf-8') as f:
            json.dump(all_results, f, indent=2, ensure_ascii=False)
        print(f"💾 Detailed results saved: {detailed_path}")
        
        return {'summary': summary_df.to_dict('records'), 'detailed': all_results}


def main():
    """Main execution"""
    import argparse
    
    parser = argparse.ArgumentParser(description='Enhanced Groq Translation Benchmark')
    parser.add_argument('--dataset', type=str, 
                       default=r'C:\Users\John Carlo\emoticoach\emoticoach\Backend\Evaluations\EMOTERA-7class-cleaned.tsv')
    parser.add_argument('--max-samples', type=int, default=None)
    parser.add_argument('--reference-model', type=str, 
                       default='meta-llama/llama-4-scout-17b-16e-instruct')
    parser.add_argument('--no-llm-judge', action='store_true', 
                       help='Disable LLM-as-judge evaluation')
    parser.add_argument('--no-reference-metrics', action='store_true',
                       help='Disable BLEU/ROUGE/METEOR (faster, no references needed)')
    parser.add_argument('--output-dir', type=str, default='results')
    
    args = parser.parse_args()
    
    api_key = os.getenv('api_key')
    if not api_key:
        print("❌ Error: api_key not found in environment")
        return
    
    benchmark = EnhancedGroqBenchmark(
        api_key=api_key,
        dataset_path=args.dataset,
        max_samples_per_emotion=args.max_samples,
        use_llm_judge=not args.no_llm_judge,
        use_reference_metrics=not args.no_reference_metrics
    )
    
    benchmark.run_full_benchmark(
        output_dir=args.output_dir,
        reference_model=args.reference_model if not args.no_reference_metrics else None
    )
    
    print("\n" + "="*80)
    print("✅ BENCHMARK COMPLETED")
    print("="*80)


if __name__ == "__main__":
    main()
