# Groq Models Translation Quality Benchmark

## Overview

This benchmark evaluates the translation quality of various Groq models for Filipino/Taglish to English translation using standard Natural Language Generation (NLG) metrics.

## Metrics

### BLEU (Bilingual Evaluation Understudy)

- **BLEU-1 to BLEU-4**: Measures n-gram precision between the translation and reference
- Higher scores indicate better overlap with reference translation
- Range: 0.0 to 1.0
- Widely used in machine translation evaluation

### ROUGE (Recall-Oriented Understudy for Gisting Evaluation)

- **ROUGE-1**: Unigram overlap
- **ROUGE-2**: Bigram overlap
- **ROUGE-L**: Longest common subsequence
- Measures recall (how much of the reference appears in the translation)
- Range: 0.0 to 1.0

### METEOR (Metric for Evaluation of Translation with Explicit ORdering)

- More sophisticated than BLEU
- Considers synonyms, stemming, and word order
- Better correlates with human judgment
- Range: 0.0 to 1.0

## Installation

Install required packages:

```bash
pip install nltk rouge-score groq python-dotenv pandas numpy
```

The script will automatically download required NLTK data (wordnet, punkt, omw-1.4) on first run.

## Setup

1. Ensure you have a `.env` file in the Backend directory with your Groq API key:

```env
api_key=your_groq_api_key_here
model=openai/gpt-oss-120b
```

2. The benchmark will test these Groq models:
   - moonshotai/kimi-k2-instruct-0905
   - meta-llama/llama-4-scout-17b-16e-instruct
   - openai/gpt-oss-120b (**thinking model** - slower but potentially more accurate)

## Important Notes

⚠️ **About Thinking Models**:

- `openai/gpt-oss-120b` is a thinking model that reasons internally before responding
- Thinking models are **significantly slower** (can take 10-30+ seconds per translation)
- The benchmark uses simplified prompts for thinking models (they don't need detailed instructions)
- **Recommended**: Use `meta-llama/llama-4-scout-17b-16e-instruct` as reference model (faster)
- Thinking models should be benchmarked but not used as reference for generating baseline translations

## Usage

### Basic Usage

Run the full benchmark on all models with the EMOTERA dataset:

```bash
cd Backend/Evaluations
python groq_translation_benchmark.py
```

Run with a subset of samples (faster for testing):

```bash
python groq_translation_benchmark.py --max-samples 10
```

Quick test with minimal samples:

```bash
python test_groq_benchmark.py
```

Custom dataset path:

```bash
python groq_translation_benchmark.py --dataset path/to/your/dataset.tsv
```

Specify reference model (recommended: use a fast, non-thinking model):

```bash
python groq_translation_benchmark.py --reference-model "meta-llama/llama-4-scout-17b-16e-instruct"
```

**Note**: Avoid using thinking models (like openai/gpt-oss-120b) as reference models since they are much slower.

### Output Files

The benchmark generates several output files in the `results/` directory:

1. **Summary CSV** (`groq_benchmark_summary_YYYYMMDD_HHMMSS.csv`)

   - Average scores for all models
   - Inference time statistics
   - Easy to compare models

2. **Detailed JSON** (`groq_benchmark_detailed_YYYYMMDD_HHMMSS.json`)

   - Complete results for all samples
   - Individual translations and scores
   - Full benchmark data

3. **Model-specific CSVs** (`groq_benchmark_MODEL_NAME_YYYYMMDD_HHMMSS.csv`)

   - Detailed results for each model
   - All test samples with scores
   - Good for analysis per model

4. **Markdown Report** (`groq_benchmark_report_YYYYMMDD_HHMMSS.md`)
   - Human-readable report
   - Summary tables
   - Sample translations
   - Best model recommendations

## Test Dataset

The benchmark uses the **EMOTERA-7class-cleaned.tsv** dataset containing ~498 Filipino/Taglish tweets covering 7 emotions:

- **Anger**
- **Joy**
- **Sadness**
- **Fear**
- **Disgust**
- **Surprise**
- **Neutral**

Each sample includes:

- Original Filipino/Taglish text
- Emotion label
- Reference English translations are generated using the best-performing Groq model (default: openai/gpt-oss-120b)

The dataset path is configurable via command-line arguments.

## Interpreting Results

### BLEU Scores

- **0.5-1.0**: Excellent translation quality
- **0.3-0.5**: Good translation quality
- **0.1-0.3**: Fair translation quality
- **0.0-0.1**: Poor translation quality

### ROUGE Scores

- Similar interpretation to BLEU
- ROUGE-L is often most informative for overall quality

### METEOR Scores

- **0.7-1.0**: Excellent
- **0.5-0.7**: Good
- **0.3-0.5**: Fair
- **0.0-0.3**: Poor

### Inference Time

- **<100ms**: Very fast (good for real-time applications)
- **100-500ms**: Fast (acceptable for most applications)
- **500-1000ms**: Moderate (may need optimization)
- **>1000ms**: Slow (consider lighter models)

## Example Output

```
================================================================================
🎯 GROQ MODELS TRANSLATION QUALITY BENCHMARK
================================================================================
📅 Date: 2025-01-15 14:30:00
🔬 Metrics: BLEU (1-4), ROUGE (1, 2, L), METEOR
🤖 Models: llama-3.3-70b-versatile, llama-3.1-70b-versatile, ...
================================================================================

================================================================================
🚀 BENCHMARKING: openai/gpt-oss-120b
================================================================================
✅ Completed 35 samples

📊 RESULTS SUMMARY:
   Average Inference Time: 245.32ms per sample
   BLEU-1: 0.7234
   BLEU-2: 0.6512
   BLEU-3: 0.5890
   BLEU-4: 0.5401
   ROUGE-1: 0.7654
   ROUGE-2: 0.6789
   ROUGE-L: 0.7321
   METEOR: 0.6823

...

🏆 BEST MODELS BY METRIC:
   BLEU-4: openai/gpt-oss-120b (0.5401)
   ROUGE-L: meta-llama/llama-4-scout-17b-16e-instruct (0.7456)
   METEOR: openai/gpt-oss-120b (0.6823)
   avg_time: meta-llama/llama-4-scout-17b-16e-instruct (158.23ms)
```

## Customization

### Adding More Test Samples

Edit the `test_dataset` in the `__init__` method of `GroqTranslationBenchmark`:

```python
self.test_dataset = [
    ("Your Filipino text", "emotion", "Reference translation"),
    # Add more samples...
]
```

### Testing Different Models

Modify the `GROQ_MODELS` list at the top of the script:

```python
GROQ_MODELS = [
    "your-model-1",
    "your-model-2",
    # Add more models...
]
```

### Adjusting Translation Parameters

Modify the `translate_with_groq` method to adjust:

- Temperature (currently 0.1 for consistency)
- Max tokens (currently 200)
- System prompt

## Troubleshooting

### API Rate Limits

If you hit rate limits, the script will print an error. You can:

1. Add delays between requests
2. Reduce the number of models tested
3. Use a smaller test dataset

### NLTK Data Not Found

If you get NLTK data errors, manually download:

```python
import nltk
nltk.download('wordnet')
nltk.download('punkt')
nltk.download('omw-1.4')
```

### Missing API Key

Ensure your `.env` file contains:

```env
api_key=your_actual_groq_api_key
```

## Performance Notes

### Expected Benchmark Times

**With Thinking Models (openai/gpt-oss-120b):**

- Per sample: 10-30+ seconds
- Quick test (35 samples): ~20-40 minutes
- Full dataset (498 samples): ~3-6 hours

**Without Thinking Models:**

- Per sample: 0.5-2 seconds
- Quick test (35 samples): ~2-5 minutes
- Full dataset (498 samples): ~15-30 minutes

**Recommendations:**

1. Start with quick test (5 samples per emotion)
2. Use fast models as reference (meta-llama/llama-4-scout-17b-16e-instruct)
3. Run thinking models separately or with smaller datasets
4. Inference time varies by model size, API load, and server location
5. Results are deterministic for non-thinking models (temperature=0.1)

## Citation

If you use this benchmark in research or reports, please cite:

- BLEU: Papineni et al., 2002
- ROUGE: Lin, 2004
- METEOR: Banerjee & Lavie, 2005

## License

Part of the Emoticoach project.
