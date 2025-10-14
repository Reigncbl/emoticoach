# Groq Translation Benchmark - Summary

## 📋 Overview

Created a comprehensive benchmarking script to evaluate **BLEU, ROUGE, and METEOR** metrics for Groq models on Filipino/Taglish to English translation tasks.

## 🎯 Models Being Tested

The benchmark evaluates these Groq models:

1. **moonshotai/kimi-k2-instruct-0905** - Standard chat model
2. **meta-llama/llama-4-scout-17b-16e-instruct** - Fast and efficient model
3. **openai/gpt-oss-120b** - ⚡ **Thinking model** (slower, reasons internally)

### ⚠️ Important Note About Thinking Models

`openai/gpt-oss-120b` is a **thinking model** that:

- Takes **10-30+ seconds per translation** (vs 0.5-2 seconds for regular models)
- Reasons internally before responding
- Uses simplified prompts (no need for detailed instructions)
- Should **NOT be used as reference model** (too slow for generating baselines)
- **Recommended**: Use `meta-llama/llama-4-scout-17b-16e-instruct` as reference model

## 📊 Metrics Evaluated

### BLEU (1-4)

- Measures n-gram precision between translation and reference
- BLEU-1: Unigram overlap
- BLEU-2: Bigram overlap
- BLEU-3: Trigram overlap
- BLEU-4: 4-gram overlap (most commonly cited)

### ROUGE (1, 2, L)

- Measures recall-oriented overlap
- ROUGE-1: Unigram recall
- ROUGE-2: Bigram recall
- ROUGE-L: Longest common subsequence

### METEOR

- More sophisticated metric considering synonyms and stemming
- Better correlates with human judgment

## 📁 Files Created

### Main Scripts

1. **`groq_translation_benchmark.py`**

   - Main benchmarking script
   - Loads EMOTERA-7class-cleaned.tsv dataset (~498 samples)
   - Tests all 3 Groq models
   - Generates comprehensive reports

2. **`test_groq_benchmark.py`**
   - Quick test script with limited samples (5 per emotion)
   - Tests only 2 models for faster results
   - Good for initial testing

### Documentation

3. **`GROQ_BENCHMARK_README.md`**
   - Complete documentation
   - Installation instructions
   - Usage examples
   - Metrics interpretation guide
   - Troubleshooting section

### Dependencies

4. **Updated `requirements.txt`**
   - Added `nltk` for BLEU and METEOR
   - Added `rouge-score` for ROUGE metrics

## 🚀 How to Run

### Quick Test (Recommended First)

```bash
cd Backend/Evaluations
python test_groq_benchmark.py
```

- Tests 2 models with 5 samples per emotion (~35 samples total)
- Takes approximately **2-3 minutes** (without thinking models)
- Takes approximately **20-40 minutes** (with openai/gpt-oss-120b)
- Good for verifying everything works

### Full Benchmark (All Models, All Data)

```bash
cd Backend/Evaluations
python groq_translation_benchmark.py
```

- Tests all 3 models with full EMOTERA dataset (~498 samples)
- Takes approximately **15-30 minutes** (without thinking models)
- Takes approximately **3-6 hours** (with openai/gpt-oss-120b)
- Generates comprehensive results

### Limited Samples (Faster) - RECOMMENDED

```bash
python groq_translation_benchmark.py --max-samples 10
```

- Tests all 3 models with 10 samples per emotion (~70 samples)
- Takes approximately **5-10 minutes** (without thinking models)
- Takes approximately **1-2 hours** (with openai/gpt-oss-120b)

### Custom Configuration

```bash
python groq_translation_benchmark.py \
    --dataset "path/to/dataset.tsv" \
    --max-samples 20 \
    --reference-model "openai/gpt-oss-120b" \
    --output-dir "my_results"
```

## 📈 Output Files

All results are saved in the `results/` directory:

1. **Summary CSV** - Quick comparison of all models
2. **Detailed JSON** - Complete data with all translations
3. **Model-specific CSVs** - Individual model results
4. **Markdown Report** - Human-readable report with analysis

### Example Output Structure

```
results/
├── groq_benchmark_summary_20251012_143000.csv
├── groq_benchmark_detailed_20251012_143000.json
├── groq_benchmark_moonshotai_kimi-k2-instruct-0905_20251012_143000.csv
├── groq_benchmark_meta-llama_llama-4-scout-17b-16e-instruct_20251012_143000.csv
├── groq_benchmark_openai_gpt-oss-120b_20251012_143000.csv
└── groq_benchmark_report_20251012_143000.md
```

## 🎭 Dataset Information

**Source:** EMOTERA-7class-cleaned.tsv
**Location:** `Backend/Evaluations/EMOTERA-7class-cleaned.tsv`
**Size:** ~498 samples
**Languages:** Filipino/Taglish → English translation

**Emotion Distribution:**

- Anger
- Joy
- Sadness
- Fear
- Disgust
- Surprise
- Neutral

## 🔧 Key Features

1. **Reference Translation Generation**

   - Uses the best Groq model (default: openai/gpt-oss-120b) to generate reference translations
   - Compares all other models against this reference

2. **Emotion-Aware Translation**

   - Prompts specifically designed to preserve emotional tone
   - Maintains intensity and cultural context

3. **Comprehensive Metrics**

   - Multiple standard NLG evaluation metrics
   - Inference time tracking
   - Per-emotion analysis

4. **Flexible Configuration**

   - Adjustable sample sizes
   - Custom dataset support
   - Configurable reference model

5. **Detailed Reporting**

   - Multiple output formats (CSV, JSON, Markdown)
   - Sample translations included
   - Statistical summaries

6. **Thinking Model Support**
   - Automatically detects thinking models (gpt-oss, o1)
   - Uses simplified prompts for thinking models
   - Adjusts parameters appropriately

## 🎯 Recommended Testing Strategy

Given that `openai/gpt-oss-120b` is a thinking model and very slow:

### Strategy 1: Test Fast Models First

```bash
# Temporarily comment out thinking model in the script
# Or benchmark non-thinking models separately
python groq_translation_benchmark.py --max-samples 10
```

### Strategy 2: Benchmark Thinking Model Separately

```bash
# 1. First benchmark fast models with full dataset
python groq_translation_benchmark.py

# 2. Then benchmark thinking model with small sample
python groq_translation_benchmark.py --max-samples 5 --reference-model "meta-llama/llama-4-scout-17b-16e-instruct"
```

### Strategy 3: Quick Test Without Thinking Model

Edit the script temporarily to exclude thinking models from GROQ_MODELS list.

## 📊 Interpreting Results

### Good Translation Quality

- BLEU-4: > 0.3
- ROUGE-L: > 0.5
- METEOR: > 0.5

### Acceptable Quality

- BLEU-4: 0.1-0.3
- ROUGE-L: 0.3-0.5
- METEOR: 0.3-0.5

### Needs Improvement

- BLEU-4: < 0.1
- ROUGE-L: < 0.3
- METEOR: < 0.3

## ⚙️ Environment Setup

Ensure your `.env` file contains:

```env
api_key=your_groq_api_key_here
model=openai/gpt-oss-120b
```

## 🔍 Next Steps

1. **Run Quick Test First**

   ```bash
   python test_groq_benchmark.py
   ```

2. **Review Results**

   - Check the markdown report
   - Compare model performance
   - Analyze sample translations

3. **Run Full Benchmark** (if quick test succeeds)

   ```bash
   python groq_translation_benchmark.py
   ```

4. **Analyze Results**
   - Which model has best BLEU scores?
   - Which is fastest?
   - Trade-offs between quality and speed?

## 📝 Notes

- First run will download NLTK data automatically (wordnet, punkt, omw-1.4)
- API rate limits may affect benchmark speed
- Results are saved with timestamps to prevent overwriting
- Temperature is set to 0.1 for reproducible translations

## 🐛 Troubleshooting

If you encounter issues:

1. Verify API key is set in `.env`
2. Check internet connection
3. Ensure all packages are installed: `pip install nltk rouge-score groq python-dotenv pandas numpy`
4. Run quick test first to validate setup

## 📞 Support

For issues or questions, refer to `GROQ_BENCHMARK_README.md` for detailed documentation.
