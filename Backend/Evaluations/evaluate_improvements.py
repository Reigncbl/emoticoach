"""
Compare F1 scores before and after improvements.
Tests the enhanced emotion classification pipeline.
"""

import os
import sys

sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

from evaluate_f1_translation import evaluate_f1

def orange_print(text: str) -> None:
    print(f"\033[38;5;208m{text}\033[0m")

def green_print(text: str) -> None:
    print(f"\033[92m{text}\033[0m")

if __name__ == "__main__":
    import argparse
    
    parser = argparse.ArgumentParser(description='Compare F1 scores with improvements')
    parser.add_argument('--sample-size', type=int, default=100,
                       help='Number of samples to evaluate')
    
    args = parser.parse_args()
    
    orange_print("\n" + "="*80)
    orange_print("🚀 EVALUATING IMPROVED EMOTION CLASSIFICATION")
    orange_print("="*80)
    orange_print("\nImprovements Applied:")
    orange_print("  ✅ Upgraded to roberta-large (from distilroberta-base)")
    orange_print("  ✅ Enhanced translation prompt with emotion preservation")
    orange_print("  ✅ Lower LLM fallback threshold (0.5 from 0.6)")
    orange_print("  ✅ Improved LLM verification prompt")
    orange_print("  ✅ Class imbalance handling (boost disgust, fear, surprise)")
    orange_print("  ✅ Ensemble method with classifier + LLM voting")
    orange_print("="*80 + "\n")
    
    # Run evaluation with improvements
    evaluate_f1(sample_size=args.sample_size, use_translation=True)
