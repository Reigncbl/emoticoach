# Thinking Model Support in Groq Benchmark

## What is a Thinking Model?

**openai/gpt-oss-120b** is a **thinking model** (also known as reasoning models). These models:

- Take significantly longer to respond (10-30+ seconds per request)
- Perform internal reasoning before generating output
- Generally produce more thoughtful and accurate responses
- Don't need detailed instructions (they figure things out internally)
- Cannot use the `temperature` parameter (reasoning is deterministic)

## How the Benchmark Handles Thinking Models

The benchmark script automatically detects thinking models and adjusts behavior:

### 1. **Prompt Simplification**

- **Regular models**: Get detailed, structured prompts with step-by-step instructions
- **Thinking models**: Get simple, concise prompts (they reason internally)

### 2. **Parameter Adjustment**

- **Regular models**: Use `temperature=0.1` for consistency
- **Thinking models**: No temperature parameter (not supported)

### 3. **Detection Logic**

```python
is_thinking_model = "gpt-oss" in model.lower() or "o1" in model.lower()
```

## Performance Impact

### Time Comparison

| Model Type                       | Per Sample | 35 Samples | 498 Samples (Full) |
| -------------------------------- | ---------- | ---------- | ------------------ |
| Regular (meta-llama, moonshotai) | 0.5-2s     | 2-5 min    | 15-30 min          |
| Thinking (openai/gpt-oss-120b)   | 10-30s     | 20-40 min  | 3-6 hours          |

### Example Scenario

If you benchmark all 3 models with full dataset:

- **moonshotai/kimi-k2-instruct-0905**: ~20 minutes
- **meta-llama/llama-4-scout-17b-16e-instruct**: ~15 minutes
- **openai/gpt-oss-120b**: ~4 hours
- **Total**: ~4.5-5 hours

## Recommended Usage Strategies

### Strategy 1: Benchmark Non-Thinking Models First ✅ RECOMMENDED

```bash
# 1. Test fast models with full dataset
python groq_translation_benchmark.py

# 2. Then benchmark thinking model separately with small sample
python groq_translation_benchmark.py --max-samples 5
```

This lets you get quick results for regular models, then evaluate the thinking model separately.

### Strategy 2: Use Interactive Runner

```bash
python run_benchmark_interactive.py
```

This script lets you:

- Select which models to benchmark
- Choose sample size
- Get time estimates
- Confirm before starting long benchmarks

### Strategy 3: Edit Models List

Temporarily modify `groq_translation_benchmark.py`:

```python
# Comment out thinking model for faster benchmarking
GROQ_MODELS = [
    "moonshotai/kimi-k2-instruct-0905",
    "meta-llama/llama-4-scout-17b-16e-instruct",
    # "openai/gpt-oss-120b",  # Uncomment when ready for slow benchmark
]
```

### Strategy 4: Use Quick Test First

```bash
# Test with minimal samples first
python test_groq_benchmark.py
```

This runs only 2 models with 5 samples per emotion to verify everything works.

## Reference Model Selection

⚠️ **IMPORTANT**: Do NOT use thinking models as reference models!

### Why?

The benchmark needs to generate reference translations for all samples first. If you use a thinking model as reference:

- **With 35 samples**: 10-30 minutes just for references
- **With 498 samples**: 2-4 hours just for references
- **Then** all other models still need to be benchmarked

### Recommended Reference Models

1. **meta-llama/llama-4-scout-17b-16e-instruct** ✅ (Default, fast)
2. **moonshotai/kimi-k2-instruct-0905** ✅ (Also fast)
3. **openai/gpt-oss-120b** ❌ (Too slow, not recommended)

## Command Examples

### Quick test without thinking model

```bash
python run_benchmark_interactive.py
# Select: 1,2 (skip model 3)
# Samples: 5
# Reference: 1
```

### Full benchmark of regular models

```bash
python groq_translation_benchmark.py
# Edit script to comment out openai/gpt-oss-120b first
```

### Small benchmark including thinking model

```bash
python groq_translation_benchmark.py --max-samples 5 --reference-model "meta-llama/llama-4-scout-17b-16e-instruct"
# This benchmarks all 3 models but with only 35 samples total
# Estimated time: ~30-45 minutes
```

### Thinking model only, minimal samples

```bash
python run_benchmark_interactive.py
# Select: 3 (only openai/gpt-oss-120b)
# Samples: 3
# Reference: 1 (use fast model for references)
```

## Understanding the Results

### Translation Quality vs Speed Trade-off

Thinking models may produce:

- Better contextual understanding
- More natural translations
- Better emotional nuance preservation

But at the cost of:

- 10-20x slower inference
- Higher API costs
- Not suitable for real-time applications

### When to Use Each Model

**meta-llama/llama-4-scout-17b-16e-instruct**:

- Real-time translation
- High-volume processing
- When speed matters
- Quick prototyping

**moonshotai/kimi-k2-instruct-0905**:

- Balanced performance
- Production applications
- Good quality-speed trade-off

**openai/gpt-oss-120b** (thinking model):

- Highest quality translations
- Batch processing
- When accuracy is critical
- Not time-sensitive applications

## Troubleshooting

### Benchmark Taking Too Long?

1. **Check if thinking model is included**: Look at terminal output
2. **Cancel and restart**: Ctrl+C, then use interactive runner
3. **Use smaller sample**: `--max-samples 3` for very quick test

### Reference Generation Stuck?

If you see "Generating reference translations..." for a long time:

- You may have accidentally used a thinking model as reference
- Cancel (Ctrl+C) and restart with fast reference model
- Use: `--reference-model "meta-llama/llama-4-scout-17b-16e-instruct"`

### Want to Skip Thinking Model?

Edit `groq_translation_benchmark.py`:

```python
GROQ_MODELS = [
    "moonshotai/kimi-k2-instruct-0905",
    "meta-llama/llama-4-scout-17b-16e-instruct",
    # "openai/gpt-oss-120b",  # Comment out temporarily
]
```

## Summary

✅ **DO**:

- Use fast models as reference
- Test with small samples first
- Use interactive runner for control
- Benchmark thinking models separately

❌ **DON'T**:

- Use thinking models as reference
- Run full dataset benchmark with thinking models without time planning
- Expect fast results from thinking models

## Additional Resources

- See `GROQ_BENCHMARK_README.md` for complete documentation
- See `BENCHMARK_SUMMARY.md` for quick reference
- Use `run_benchmark_interactive.py` for guided benchmarking
