# 📊 Benchmark Visualization Guide

## Overview

The benchmark script now automatically generates **comprehensive comparison graphs** to help you visualize and compare the performance of different Groq models.

## Generated Graphs

### 1. Main Comparison Dashboard (`groq_benchmark_comparison_TIMESTAMP.png`)

A comprehensive 8-panel dashboard showing:

#### Panel 1: BLEU Scores Comparison (1-4)

- **Type**: Grouped bar chart
- **Shows**: All BLEU metrics (1-gram to 4-gram) for each model
- **Purpose**: See how models perform across different n-gram levels
- **Interpretation**:
  - Higher bars = better translation quality
  - BLEU-4 is most important for overall quality

#### Panel 2: ROUGE Scores Comparison

- **Type**: Grouped bar chart
- **Shows**: ROUGE-1, ROUGE-2, and ROUGE-L scores
- **Purpose**: Compare recall-oriented metrics
- **Interpretation**:
  - ROUGE-L (longest common subsequence) is often most informative
  - Higher scores = better content preservation

#### Panel 3: METEOR Score Comparison

- **Type**: Bar chart with value labels
- **Shows**: METEOR scores for each model
- **Purpose**: Compare sophisticated translation quality
- **Interpretation**:
  - METEOR considers synonyms and word order
  - Often correlates best with human judgment

#### Panel 4: BERTScore Comparison

- **Type**: Grouped bar chart
- **Shows**: BERTScore Precision, Recall, and F1 scores
- **Purpose**: Compare contextual embedding-based similarity
- **Interpretation**:
  - Uses BERT embeddings to measure semantic similarity
  - Captures meaning beyond exact word matching
  - F1 score typically 0.85-0.95 for good translations
  - Higher scores = better semantic preservation

#### Panel 5: Overall Translation Quality (BLEU-4)

- **Type**: Horizontal bar chart
- **Shows**: Primary metric (BLEU-4) for quick comparison
- **Purpose**: Quick visual ranking of models
- **Interpretation**:
  - Sorted from best to worst
  - Color-coded for easy identification

#### Panel 6: Average Inference Time

- **Type**: Bar chart with millisecond labels
- **Shows**: Speed performance of each model
- **Purpose**: Identify fastest models
- **Interpretation**:
  - Lower = faster (better for real-time applications)
  - Consider trade-off with quality

#### Panel 7: Quality vs Speed Trade-off

- **Type**: Scatter plot with color coding
- **Shows**: BLEU-4 score vs inference time
- **Color**: Represents METEOR score
- **Purpose**: Find optimal balance between quality and speed
- **Interpretation**:
  - Top-left = best (high quality, fast speed)
  - Bottom-right = worst (low quality, slow speed)
  - Green colors = higher METEOR scores

#### Panel 8: Contextual Similarity (BERTScore-F1)

- **Type**: Horizontal bar chart
- **Shows**: BERTScore-F1 (balanced semantic similarity)
- **Purpose**: Quick ranking by semantic quality
- **Interpretation**:
  - F1 balances precision and recall
  - Higher scores indicate better semantic preservation
  - Typically ranges 0.85-0.95 for quality translations

### 2. Radar Chart (`groq_benchmark_radar_TIMESTAMP.png`)

#### Multi-Metric Performance Comparison

- **Type**: Radar/Spider chart
- **Metrics**: BLEU-4, ROUGE-L, METEOR, BERTScore-F1
- **Purpose**: Holistic view of model performance across key metrics
- **Interpretation**:
  - Larger area = better overall performance
  - Shape shows where model excels or lacks
  - Easy to spot models with balanced vs specialized performance
  - Includes both n-gram (BLEU) and semantic (BERTScore) metrics

## File Locations

All graphs are saved in the `results/` directory with timestamps:

```
results/
├── groq_benchmark_comparison_20251012_213045.png  # Main dashboard
├── groq_benchmark_radar_20251012_213045.png       # Radar chart
├── groq_benchmark_with_refs_summary_20251012_213045.csv
├── groq_benchmark_with_refs_detailed_20251012_213045.json
└── groq_benchmark_with_refs_report_20251012_213045.md
```

## How to Use the Graphs

### 1. Quick Model Selection

**Look at Panel 4 (Overall Quality)**

- Shows BLEU-4 scores in descending order
- Pick the top model for best quality

### 2. Speed-Sensitive Applications

**Look at Panel 5 (Inference Time)**

- Find the fastest model
- Then check Panel 4 to see quality trade-off

### 3. Balanced Performance

**Look at Panel 6 (Quality vs Speed)**

- Find models in the top-left area
- These offer good quality with reasonable speed

### 4. Comprehensive Analysis

**Look at Radar Chart**

- Models with larger, more circular shapes are more balanced
- Models with irregular shapes excel in specific areas

## Example Interpretations

### Scenario 1: Real-Time Translation

**Priority**: Speed > Quality

1. Check Panel 5: Find fastest model
2. Check Panel 4: Ensure quality is acceptable (BLEU-4 > 0.30)
3. Verify in Panel 6: Model is in left-side area

### Scenario 2: Batch Translation

**Priority**: Quality > Speed

1. Check Panel 4: Pick highest BLEU-4
2. Check Panel 3: Verify good METEOR score
3. Check Panel 6: Acceptable speed for batch processing

### Scenario 3: Production Deployment

**Priority**: Balanced performance

1. Check Panel 6: Find models in top-left quadrant
2. Check Radar Chart: Look for large, balanced shapes
3. Check Panel 2: Verify consistent ROUGE scores

## Reading the Numbers

### BLEU-4 (Main Quality Metric)

- **0.40-1.00**: ✅ Excellent - Production ready
- **0.30-0.40**: ✅ Good - Acceptable for most uses
- **0.20-0.30**: ⚠️ Fair - Needs improvement
- **0.00-0.20**: ❌ Poor - Not recommended

### ROUGE-L (Content Preservation)

- **0.50-1.00**: ✅ Excellent
- **0.40-0.50**: ✅ Good
- **0.30-0.40**: ⚠️ Fair
- **0.00-0.30**: ❌ Poor

### METEOR (Human Correlation)

- **0.50-1.00**: ✅ Excellent
- **0.40-0.50**: ✅ Good
- **0.30-0.40**: ⚠️ Fair
- **0.00-0.30**: ❌ Poor

### BERTScore-F1 (Semantic Similarity)

- **0.90-1.00**: ✅ Excellent - Strong semantic match
- **0.85-0.90**: ✅ Good - Acceptable semantic preservation
- **0.80-0.85**: ⚠️ Fair - Some meaning loss
- **0.00-0.80**: ❌ Poor - Significant semantic differences

**Note**: BERTScore uses contextual embeddings from BERT to measure semantic similarity. It captures meaning beyond exact word matching and typically ranges higher than traditional metrics (0.85-0.95 for quality translations).

### Inference Time

- **< 500ms**: ✅ Very Fast - Real-time capable
- **500-2000ms**: ✅ Fast - Good for most apps
- **2000-5000ms**: ⚠️ Moderate - Batch only
- **> 5000ms**: ❌ Slow - Limited use cases

## Graph Features

### High Resolution

- Saved at 300 DPI for publication quality
- Suitable for reports and presentations

### Color Coding

- Consistent color schemes across panels
- Easy to track same model across charts

### Value Labels

- Important values labeled directly on charts
- No need to estimate from axes

### Professional Styling

- Clean, modern appearance
- Grid lines for easy reading
- Bold labels for clarity

## Customization

If you want to customize the graphs, you can modify the `_generate_graphs()` and `_generate_radar_chart()` methods in the script:

```python
# Adjust figure size
plt.rcParams['figure.figsize'] = (18, 12)  # width, height

# Change color schemes
colors = sns.color_palette("viridis", len(model_names))

# Adjust DPI for different resolutions
plt.savefig(graph_path, dpi=300, bbox_inches='tight')
```

## Tips for Presentations

1. **Use the Main Dashboard** for comprehensive overview
2. **Use the Radar Chart** for executive summaries
3. **Extract Panel 4** for simple quality rankings
4. **Extract Panel 6** for explaining trade-offs

## Troubleshooting

### Graphs Not Generated?

Check that matplotlib and seaborn are installed:

```bash
pip install matplotlib seaborn
```

### Labels Overlapping?

This can happen with long model names. The script automatically rotates labels and uses abbreviations.

### Want Different Metrics?

Edit the `_generate_graphs()` method to include/exclude metrics in the visualization.

## Examples

### Best Model Decision Flow

```
Start
  ↓
Check Panel 4 (BLEU-4) → Top model has BLEU > 0.40? → ✅ Consider this model
  ↓                                                          ↓
  ❌                                                    Check Panel 5 (Speed)
  ↓                                                          ↓
Check Panel 6 (Trade-off) → Find top-left models      Speed acceptable? → ✅ SELECT MODEL
  ↓                                                          ↓
Select best balance                                      ❌ Check next best model
```

## Summary

The benchmark now provides:

- ✅ **6 comprehensive comparison charts**
- ✅ **1 radar chart for holistic view**
- ✅ **Automatic generation** (no manual work)
- ✅ **High-quality images** (300 DPI)
- ✅ **Professional styling** (ready for reports)
- ✅ **Clear interpretations** (easy decision making)

Use these visualizations to make informed decisions about which Groq model to use for your translation needs!
