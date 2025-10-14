#!/bin/bash
# Quick benchmark and evaluation runner

echo "🚀 Emotion Classification Evaluation Suite"
echo "=========================================="
echo ""
echo "Select an option:"
echo "1. Quick F1 Evaluation (50 samples)"
echo "2. Quick Performance Benchmark (50 samples)"
echo "3. Full F1 Evaluation with Comparison (100 samples)"
echo "4. Full Performance Benchmark with Comparison (100 samples)"
echo "5. Production Test - All Samples (F1 + Benchmark)"
echo ""
read -p "Enter your choice (1-5): " choice

case $choice in
    1)
        echo ""
        echo "🔬 Running Quick F1 Evaluation..."
        python Backend/Evaluations/evaluate_f1_translation.py --sample-size 50
        ;;
    2)
        echo ""
        echo "⚡ Running Quick Performance Benchmark..."
        python Backend/Evaluations/benchmark_translation_classification.py --sample-size 50
        ;;
    3)
        echo ""
        echo "🔬 Running Full F1 Evaluation with Comparison..."
        python Backend/Evaluations/evaluate_f1_translation.py --compare --sample-size 100
        ;;
    4)
        echo ""
        echo "⚡ Running Full Performance Benchmark with Comparison..."
        python Backend/Evaluations/benchmark_translation_classification.py --compare --sample-size 100
        ;;
    5)
        echo ""
        echo "🏭 Running Production Test on All Samples..."
        echo ""
        echo "Step 1/2: F1 Evaluation"
        python Backend/Evaluations/evaluate_f1_translation.py --sample-size -1
        echo ""
        echo "Step 2/2: Performance Benchmark"
        python Backend/Evaluations/benchmark_translation_classification.py --sample-size -1
        ;;
    *)
        echo "Invalid choice. Exiting."
        exit 1
        ;;
esac

echo ""
echo "✅ Done! Check Backend/Evaluations/results/ for detailed results."
