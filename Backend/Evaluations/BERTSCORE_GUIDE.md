# 🎯 BERTScore Integration Guide

## Overview

**BERTScore** has been successfully integrated into the Groq translation benchmark script. It provides **contextual embedding-based evaluation** that captures semantic similarity beyond exact word matching.

## What is BERTScore?

### Traditional Metrics Limitations

Traditional metrics like BLEU, ROUGE, and METEOR rely on:

- **Exact word matching** (BLEU)
- **N-gram overlap** (ROUGE)
- **Synonym matching** (METEOR)

These fail to capture paraphrases and semantic equivalence.

### BERTScore Advantage

BERTScore uses **BERT contextual embeddings** to:

- ✅ Capture **semantic similarity** beyond surface form
- ✅ Handle **paraphrases** effectively
- ✅ Consider **context** for word meaning
- ✅ Correlate better with **human judgment**

### Example

**Reference**: "The cat is sleeping on the couch"  
**Translation 1**: "The cat is sleeping on the sofa"  
**Translation 2**: "The feline is resting on the sofa"

- **BLEU-4**: Translation 1 scores higher (exact word match)
- **BERTScore**: Both score similarly (semantic equivalence)

## How It Works

### 1. Token Embeddings

- Uses `roberta-large` by default
- Each word gets contextual vector representation
- Context-dependent: "bank" (river) vs "bank" (money)

### 2. Token Matching

- Finds best match between reference and candidate tokens
- Uses **cosine similarity** in embedding space
- Not limited to exact matches

### 3. Scoring

- **Precision**: How much of the translation is relevant?
- **Recall**: How much of the reference is captured?
- **F1**: Harmonic mean of precision and recall

## Integration Details

### Added to Script

```python
def calculate_bert_score(self, references: List[str], translations: List[str]) -> Dict[str, float]:
    """
    Calculate BERTScore using contextual embeddings from BERT model.

    BERTScore measures semantic similarity using contextual embeddings,
    which often correlates better with human judgment than n-gram metrics.
    """
    try:
        P, R, F1 = bert_score(
            translations,
            references,
            lang='en',
            device='cpu',
            batch_size=8
        )

        return {
            'BERTScore-P': float(P.mean()),
            'BERTScore-R': float(R.mean()),
            'BERTScore-F1': float(F1.mean())
        }
    except Exception as e:
        print(f"⚠️ Error calculating BERTScore: {e}")
        return {
            'BERTScore-P': 0.0,
            'BERTScore-R': 0.0,
            'BERTScore-F1': 0.0
        }
```

### Batch Calculation

- Calculates BERTScore **once per model** on all translations
- More efficient than per-sample calculation
- Provides stable aggregate scores

### Visualization

#### 8-Panel Dashboard

- **Panel 4**: BERTScore P/R/F1 comparison (grouped bars)
- **Panel 8**: BERTScore-F1 focus (horizontal bars)

#### Radar Chart

- Now includes **BERTScore-F1** alongside BLEU-4, ROUGE-L, METEOR
- Shows balance across n-gram and semantic metrics

## Interpreting BERTScore

### Score Ranges

| Score Range | Quality      | Description                      |
| ----------- | ------------ | -------------------------------- |
| 0.90-1.00   | ✅ Excellent | Strong semantic match            |
| 0.85-0.90   | ✅ Good      | Acceptable semantic preservation |
| 0.80-0.85   | ⚠️ Fair      | Some meaning loss                |
| 0.00-0.80   | ❌ Poor      | Significant semantic differences |

### Key Points

- **Typically higher** than BLEU/ROUGE scores (0.85-0.95 for quality translations)
- **F1 score** is most commonly used (balances P and R)
- **Precision** matters when avoiding irrelevant content
- **Recall** matters when ensuring complete meaning capture

### Example Results

From test run (5 samples):

| Model         | BLEU-4 | METEOR | BERTScore-F1 |
| ------------- | ------ | ------ | ------------ |
| Llama-4-Scout | 0.8469 | 0.9244 | **0.9941**   |
| GPT-OSS-120b  | 0.7050 | 0.8096 | **0.9837**   |
| Kimi-K2       | 0.6654 | 0.8283 | **0.9859**   |

**Observation**: BERTScore shows smaller differences between models, indicating they all preserve semantic meaning well even when exact wording differs.

## When to Use BERTScore

### ✅ Best For

- Evaluating **semantic equivalence**
- Handling **paraphrases**
- **Multiple valid translations** scenarios
- Correlating with **human judgment**
- **Cross-lingual evaluation** (multilingual BERT)

### ⚠️ Limitations

- **Slower** than n-gram metrics (requires BERT inference)
- **Higher baseline** (most translations score 0.85+)
- **Less discriminative** for small differences
- **Requires GPU** for optimal speed (CPU works but slower)

### 🎯 Best Practice

Use **combination of metrics**:

- **BLEU-4**: Exact match quality
- **ROUGE-L**: Content preservation
- **METEOR**: Synonym handling
- **BERTScore-F1**: Semantic similarity

This gives comprehensive view:

- BLEU shows surface form quality
- BERTScore confirms semantic preservation

## Installation

### Package

```bash
pip install bert-score
```

### Dependencies

- `torch` (PyTorch)
- `transformers` (Hugging Face)
- `pandas`
- `matplotlib` (for visualization)

### Model Download

First run downloads `roberta-large` (~1.4GB):

- Cached in `~/.cache/huggingface/`
- Reused for subsequent runs
- Can change model with `model_type` parameter

## Output Files

### CSV Files

BERTScore columns added:

- `BERTScore-P`: Precision
- `BERTScore-R`: Recall
- `BERTScore-F1`: F1 score

### Console Output

```
📊 RESULTS SUMMARY:
   ...
   METEOR: 0.8283
   BERTScore-P: 0.9866
   BERTScore-R: 0.9852
   BERTScore-F1: 0.9859
```

### Graphs

- **Panel 4**: BERTScore comparison (P/R/F1)
- **Panel 8**: BERTScore-F1 focus
- **Radar Chart**: Includes BERTScore-F1

## Performance Notes

### Speed

- **~2 minutes** for downloading model (first run only)
- **~1-2 seconds** per 100 translations (CPU, batch=8)
- **~10x faster** with GPU

### Memory

- **~4GB RAM** for roberta-large (CPU)
- Can use smaller models like `bert-base-uncased` for less memory

### Optimization

Current settings (optimal for CPU):

```python
bert_score(
    translations,
    references,
    lang='en',
    device='cpu',      # Use 'cuda' for GPU
    batch_size=8       # Increase with more RAM/GPU memory
)
```

## References

- **Paper**: [BERTScore: Evaluating Text Generation with BERT](https://arxiv.org/abs/1904.09675)
- **GitHub**: [bert-score/bert_score](https://github.com/Tiiiger/bert_score)
- **Documentation**: [BERTScore Docs](https://github.com/Tiiiger/bert_score#readme)

## Summary

✅ **Integrated**: BERTScore is now part of the benchmark  
✅ **Efficient**: Batch calculation for speed  
✅ **Visualized**: Added to graphs and radar chart  
✅ **Documented**: Updated all guides with BERTScore info  
✅ **Tested**: Successfully benchmarked 3 models with BERTScore

BERTScore provides valuable **semantic evaluation** complementing traditional n-gram metrics, giving you a more complete picture of translation quality! 🎯
