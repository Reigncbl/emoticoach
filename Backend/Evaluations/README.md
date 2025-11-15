# Emotion Classification Evaluation & Benchmarking Suite

This directory contains tools for evaluating and benchmarking the emotion classification pipeline, including translation and classification components.

## Files

### 1. `evaluate_f1_translation.py` - F1 Score Evaluation

Evaluates the accuracy of emotion classification using F1 scores, precision, recall, and other metrics.

**Features:**

- ✅ Evaluates all 7 emotion classes with emojis (🤬 anger, 🤢 disgust, 😨 fear, 😀 joy, 😐 neutral, 😭 sadness, 😲 surprise)
- ✅ Tests with/without translation
- ✅ Per-class and aggregate metrics
- ✅ Saves results to JSON

**Usage:**

```bash
# Evaluate 50 samples with translation (default)
python Backend/Evaluations/evaluate_f1_translation.py

# Evaluate 100 samples
python Backend/Evaluations/evaluate_f1_translation.py --sample-size 100

# Evaluate all samples
python Backend/Evaluations/evaluate_f1_translation.py --sample-size -1

# Evaluate without translation
python Backend/Evaluations/evaluate_f1_translation.py --no-translation

# Compare with and without translation
python Backend/Evaluations/evaluate_f1_translation.py --compare --sample-size 100
```

**Output:**

- Detailed F1 scores per emotion
- Macro and weighted averages
- Overall accuracy
- Best/worst performing emotions
- Results saved to `results/f1_evaluation_*.json`

---

### 2. `benchmark_translation_classification.py` - Performance Benchmarking

Measures performance metrics for translation and classification operations.

**Features:**

- ⚡ Translation speed and overhead
- ⚡ Classification speed
- ⚡ End-to-end pipeline performance
- ⚡ Memory usage tracking
- ⚡ Throughput (operations per second)
- ⚡ Comparison mode: with vs without translation

**Usage:**

```bash
# Benchmark 50 samples (default)
python Backend/Evaluations/benchmark_translation_classification.py

# Benchmark 100 samples
python Backend/Evaluations/benchmark_translation_classification.py --sample-size 100

# Benchmark all samples
python Backend/Evaluations/benchmark_translation_classification.py --sample-size -1

# Compare with and without translation
python Backend/Evaluations/benchmark_translation_classification.py --compare --sample-size 100
```

**Metrics Tracked:**

- **Translation Metrics:**
  - Average/min/max time (ms)
  - Throughput (ops/sec)
  - Memory usage
  - Translation rate (how many texts needed translation)
- **Classification Metrics:**
  - Average/min/max time (ms)
  - Throughput (ops/sec)
  - Memory usage
  - Success/failure rate
- **End-to-End Pipeline:**
  - Total processing time
  - Combined throughput
  - Translation overhead percentage

**Output:**

- Performance tables for each component
- Translation statistics
- Performance breakdown
- Comparison analysis (if --compare used)
- Results saved to `results/benchmark_results_*.json`

---

## Dataset

Both scripts use the **EMOTERA-All-cleaned.tsv** dataset, which contains Taglish (Tagalog-English mix) tweets with emotion labels.

**Columns:**

- `emotion`: The ground truth emotion label (anger, disgust, fear, joy, neutral, sadness, surprise)
- `tweet`: The text content

**Dataset Location:**

- Default: `Backend/Evaluations/EMOTERA-All-cleaned.tsv`
- Can be overridden with `RAG_F1_DATASET` environment variable

---

## Environment Variables Required

Make sure these are set in your `.env` file:

```bash
# HuggingFace API Token
HF_TOKEN=your_huggingface_token

# Groq API (for translation)
api_key=your_groq_api_key
model=llama-3.3-70b-versatile  # or your preferred model
```

---

## Example Workflows

### Quick Evaluation

```bash
# Quick F1 score check on 50 samples
python Backend/Evaluations/evaluate_f1_translation.py

# Quick performance benchmark on 50 samples
python Backend/Evaluations/benchmark_translation_classification.py
```

### Comprehensive Analysis

```bash
# Full evaluation with comparison
python Backend/Evaluations/evaluate_f1_translation.py --compare --sample-size 200

# Full benchmark with comparison
python Backend/Evaluations/benchmark_translation_classification.py --compare --sample-size 200
```

### Production-Ready Testing

```bash
# Test on entire dataset for accuracy
python Backend/Evaluations/evaluate_f1_translation.py --sample-size -1

# Test on entire dataset for performance
python Backend/Evaluations/benchmark_translation_classification.py --sample-size -1
```

---

## Interpreting Results

### F1 Evaluation Results

**High F1 Score (>0.8):** Excellent performance for that emotion
**Medium F1 Score (0.6-0.8):** Good performance, some confusion
**Low F1 Score (<0.6):** Poor performance, needs improvement

**Key Metrics:**

- **Precision:** How many predicted emotions were correct?
- **Recall:** How many actual emotions were detected?
- **F1 Score:** Harmonic mean of precision and recall
- **Macro Avg:** Simple average across all classes
- **Weighted Avg:** Weighted by number of instances per class

### Benchmark Results

**Good Performance:**

- Translation: <500ms average
- Classification: <200ms average
- End-to-end: <700ms average
- Throughput: >1.5 ops/sec

**Translation Overhead:**

- Typically 30-60% of total pipeline time
- Higher for non-English texts
- Can be skipped for English-only scenarios

---

## Results Directory

All results are saved to `Backend/Evaluations/results/`:

- `f1_evaluation_*.json` - F1 score evaluations
- `benchmark_results_*.json` - Performance benchmarks

Results include timestamps and full configuration for reproducibility.

---

## Tips

1. **Start Small:** Use `--sample-size 50` for quick tests
2. **Use Comparison Mode:** `--compare` gives you both scenarios in one run
3. **Monitor Memory:** Large datasets may require more memory
4. **Check Logs:** Watch for translation/classification errors
5. **Save Results:** All results are auto-saved with timestamps

---

## Troubleshooting

**Error: HF_TOKEN not found**

- Make sure `.env` file has `HF_TOKEN=your_token`

**Error: Dataset not found**

- Check that `EMOTERA-All-cleaned.tsv` exists in the Evaluations directory

**Slow Performance**

- API rate limits may slow down processing
- Consider using smaller sample sizes for testing

**High Memory Usage**

- Use smaller `--sample-size` values
- Close other applications

---

## Models Used

**Emotion Classification:**

- `j-hartmann/emotion-english-distilroberta-base`
- 7 emotion classes
- Trained on English text

**Translation:**

- Groq API with LLama models
- Translates non-English text to English before classification

---

## Valid Emotion Classes

Only these 7 emotions are recognized:

- 🤬 **anger** - Angry, frustrated, irritated
- 🤢 **disgust** - Disgusted, repulsed
- 😨 **fear** - Scared, anxious, worried
- 😀 **joy** - Happy, excited, pleased
- 😐 **neutral** - Neutral, factual
- 😭 **sadness** - Sad, depressed, disappointed
- 😲 **surprise** - Surprised, shocked, amazed
