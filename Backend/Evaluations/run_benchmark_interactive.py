"""
Flexible Groq Benchmark Runner
Allows easy selection of models to benchmark
"""

import os
import sys
from dotenv import load_dotenv

# Add parent directory to path
sys.path.insert(0, os.path.dirname(__file__))

load_dotenv()

# Import the benchmark
from groq_translation_benchmark import GroqTranslationBenchmark
import groq_translation_benchmark

def main():
    """Run benchmark with user-selected models"""
    
    print("="*80)
    print("🎯 FLEXIBLE GROQ BENCHMARK RUNNER")
    print("="*80)
    print()
    
    # Get API key
    api_key = os.getenv('api_key')
    if not api_key:
        print("❌ Error: api_key not found in environment variables")
        return
    
    # Available models
    all_models = {
        '1': ('moonshotai/kimi-k2-instruct-0905', 'Standard chat model'),
        '2': ('meta-llama/llama-4-scout-17b-16e-instruct', 'Fast and efficient model'),
        '3': ('openai/gpt-oss-120b', 'THINKING MODEL (very slow, 10-30s per sample)')
    }
    
    # Display model options
    print("Available models:")
    for key, (model, desc) in all_models.items():
        print(f"  {key}. {model}")
        print(f"     {desc}")
    print()
    
    # Get user selection
    print("Select models to benchmark (comma-separated, e.g., '1,2' or 'all'):")
    selection = input("Your selection: ").strip().lower()
    
    if selection == 'all':
        selected_models = [model for model, _ in all_models.values()]
    else:
        try:
            keys = [k.strip() for k in selection.split(',')]
            selected_models = [all_models[k][0] for k in keys if k in all_models]
        except:
            print("❌ Invalid selection")
            return
    
    if not selected_models:
        print("❌ No models selected")
        return
    
    print(f"\n✅ Selected models: {', '.join(selected_models)}")
    
    # Check if thinking model is selected
    has_thinking_model = any('gpt-oss' in m or 'o1' in m for m in selected_models)
    
    # Get sample size
    print("\nHow many samples per emotion? (default: 5, full dataset: leave empty)")
    samples_input = input("Samples per emotion: ").strip()
    
    if samples_input == '':
        max_samples = None
        print("📊 Using full dataset (~498 samples)")
    else:
        try:
            max_samples = int(samples_input)
            print(f"📊 Using {max_samples} samples per emotion (~{max_samples*7} total)")
        except:
            print("❌ Invalid number, using default (5)")
            max_samples = 5
    
    # Estimate time
    if has_thinking_model:
        total_samples = (max_samples * 7) if max_samples else 498
        est_time_min = total_samples * 10 / 60  # 10 seconds per sample minimum
        est_time_max = total_samples * 30 / 60  # 30 seconds per sample maximum
        print(f"\n⏱️  Estimated time: {est_time_min:.1f}-{est_time_max:.1f} minutes (with thinking model)")
        print("⚠️  WARNING: This may take a while!")
        confirm = input("Continue? (y/n): ").strip().lower()
        if confirm != 'y':
            print("❌ Cancelled")
            return
    
    # Get reference model
    print("\nSelect reference model for generating baseline translations:")
    print("  1. meta-llama/llama-4-scout-17b-16e-instruct (RECOMMENDED - fast)")
    print("  2. moonshotai/kimi-k2-instruct-0905")
    if has_thinking_model:
        print("  3. openai/gpt-oss-120b (NOT RECOMMENDED - very slow)")
    
    ref_choice = input("Your choice (default: 1): ").strip()
    if ref_choice == '2':
        reference_model = 'moonshotai/kimi-k2-instruct-0905'
    elif ref_choice == '3' and has_thinking_model:
        reference_model = 'openai/gpt-oss-120b'
        print("⚠️  WARNING: Using thinking model as reference will be VERY slow!")
    else:
        reference_model = 'meta-llama/llama-4-scout-17b-16e-instruct'
    
    print(f"\n✅ Reference model: {reference_model}")
    
    # Dataset path
    dataset_path = r'C:\Users\John Carlo\emoticoach\emoticoach\Backend\Evaluations\EMOTERA-7class-cleaned.tsv'
    
    # Override models list
    original_models = groq_translation_benchmark.GROQ_MODELS
    groq_translation_benchmark.GROQ_MODELS = selected_models
    
    try:
        print("\n" + "="*80)
        print("🚀 STARTING BENCHMARK")
        print("="*80)
        
        # Create benchmark instance
        benchmark = GroqTranslationBenchmark(
            api_key=api_key,
            dataset_path=dataset_path,
            max_samples_per_emotion=max_samples
        )
        
        # Run benchmark
        results = benchmark.run_full_benchmark(
            output_dir="results",
            reference_model=reference_model
        )
        
        print("\n" + "="*80)
        print("✅ BENCHMARK COMPLETED SUCCESSFULLY")
        print("="*80)
        print(f"\n📁 Results saved in: results/")
        
    finally:
        # Restore original models list
        groq_translation_benchmark.GROQ_MODELS = original_models


if __name__ == "__main__":
    main()
