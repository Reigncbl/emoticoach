"""
Visualize Benchmark Results
Creates bar charts and comparison graphs for emotion classification models
"""

import pandas as pd
import matplotlib.pyplot as plt
import numpy as np
from pathlib import Path
import os

def parse_results_file(file_path):
    """Parse the benchmark summary report"""
    results = []
    
    with open(file_path, 'r', encoding='utf-8') as f:
        lines = f.readlines()
    
    # Find the data section
    data_started = False
    for line in lines:
        if 'model_name' in line:
            data_started = True
            continue
        
        if data_started and line.strip():
            parts = line.split()
            if len(parts) >= 7:
                # Handle multi-word model names
                # Count from the end - we know last 6 parts are data
                data_parts = parts[-6:]
                model_name = ' '.join(parts[:-6])
                
                if not model_name:  # Single word name
                    continue
                
                results.append({
                    'model_name': model_name,
                    'accuracy': float(data_parts[0].rstrip('%')),
                    'precision': float(data_parts[1].rstrip('%')),
                    'recall': float(data_parts[2].rstrip('%')),
                    'f1_score': float(data_parts[3].rstrip('%')),
                    'inference_time': float(data_parts[4].rstrip('s')),
                    'load_time': float(data_parts[5])
                })
    
    return pd.DataFrame(results)

def create_metric_comparison_chart(df, output_dir):
    """Create a grouped bar chart comparing accuracy, precision, recall, and F1"""
    metrics = ['accuracy', 'precision', 'recall', 'f1_score']
    x = np.arange(len(df['model_name']))
    width = 0.2
    
    fig, ax = plt.subplots(figsize=(14, 8))
    
    colors = ['#FF6B6B', '#4ECDC4', '#45B7D1', '#96CEB4']
    
    for i, metric in enumerate(metrics):
        offset = width * (i - 1.5)
        bars = ax.bar(x + offset, df[metric], width, label=metric.replace('_', ' ').title(), 
                      color=colors[i], alpha=0.8, edgecolor='black', linewidth=1.2)
        
        # Add value labels on bars
        for bar in bars:
            height = bar.get_height()
            ax.text(bar.get_x() + bar.get_width()/2., height,
                   f'{height:.1f}%',
                   ha='center', va='bottom', fontsize=9, fontweight='bold')
    
    ax.set_xlabel('Models', fontsize=14, fontweight='bold')
    ax.set_ylabel('Score (%)', fontsize=14, fontweight='bold')
    ax.set_title('Emotion Classification Model Comparison\n(All Metrics)', 
                 fontsize=16, fontweight='bold', pad=20)
    ax.set_xticks(x)
    ax.set_xticklabels(df['model_name'], rotation=15, ha='right')
    ax.legend(loc='upper right', fontsize=11)
    ax.grid(axis='y', alpha=0.3, linestyle='--')
    ax.set_ylim(0, 100)
    
    plt.tight_layout()
    output_path = os.path.join(output_dir, 'metrics_comparison.png')
    plt.savefig(output_path, dpi=300, bbox_inches='tight')
    print(f"✓ Saved: {output_path}")
    plt.close()

def create_inference_time_chart(df, output_dir):
    """Create a bar chart for inference time comparison"""
    fig, ax = plt.subplots(figsize=(12, 7))
    
    colors = plt.cm.viridis(np.linspace(0.3, 0.9, len(df)))
    bars = ax.bar(df['model_name'], df['inference_time'], color=colors, 
                  alpha=0.8, edgecolor='black', linewidth=1.2)
    
    # Add value labels
    for bar in bars:
        height = bar.get_height()
        ax.text(bar.get_x() + bar.get_width()/2., height,
               f'{height:.2f}s',
               ha='center', va='bottom', fontsize=11, fontweight='bold')
    
    ax.set_xlabel('Models', fontsize=14, fontweight='bold')
    ax.set_ylabel('Time (seconds)', fontsize=14, fontweight='bold')
    ax.set_title('Inference Time Comparison\n(350 samples)', 
                 fontsize=16, fontweight='bold', pad=20)
    ax.set_xticklabels(df['model_name'], rotation=15, ha='right')
    ax.grid(axis='y', alpha=0.3, linestyle='--')
    
    plt.tight_layout()
    output_path = os.path.join(output_dir, 'inference_time.png')
    plt.savefig(output_path, dpi=300, bbox_inches='tight')
    print(f"✓ Saved: {output_path}")
    plt.close()

def create_f1_ranking_chart(df, output_dir):
    """Create a horizontal bar chart ranking models by F1 score"""
    df_sorted = df.sort_values('f1_score', ascending=True)
    
    fig, ax = plt.subplots(figsize=(12, 8))
    
    colors = plt.cm.RdYlGn(np.linspace(0.3, 0.9, len(df_sorted)))
    bars = ax.barh(df_sorted['model_name'], df_sorted['f1_score'], 
                   color=colors, alpha=0.8, edgecolor='black', linewidth=1.2)
    
    # Add value labels
    for i, (bar, f1) in enumerate(zip(bars, df_sorted['f1_score'])):
        ax.text(f1 + 1, bar.get_y() + bar.get_height()/2.,
               f'{f1:.2f}%',
               ha='left', va='center', fontsize=12, fontweight='bold')
    
    ax.set_xlabel('F1 Score (%)', fontsize=14, fontweight='bold')
    ax.set_ylabel('Models', fontsize=14, fontweight='bold')
    ax.set_title('Model Ranking by F1 Score', 
                 fontsize=16, fontweight='bold', pad=20)
    ax.grid(axis='x', alpha=0.3, linestyle='--')
    ax.set_xlim(0, 100)
    
    plt.tight_layout()
    output_path = os.path.join(output_dir, 'f1_ranking.png')
    plt.savefig(output_path, dpi=300, bbox_inches='tight')
    print(f"✓ Saved: {output_path}")
    plt.close()

def create_speed_vs_accuracy_scatter(df, output_dir):
    """Create a scatter plot showing speed vs accuracy trade-off"""
    fig, ax = plt.subplots(figsize=(12, 8))
    
    # Calculate samples per second
    df['samples_per_sec'] = 350 / df['inference_time']
    
    colors = ['#FF6B6B', '#4ECDC4', '#45B7D1', '#96CEB4']
    
    for i, row in df.iterrows():
        ax.scatter(row['samples_per_sec'], row['f1_score'], 
                  s=500, alpha=0.7, color=colors[i % len(colors)],
                  edgecolor='black', linewidth=2)
        ax.annotate(row['model_name'], 
                   (row['samples_per_sec'], row['f1_score']),
                   xytext=(10, 10), textcoords='offset points',
                   fontsize=11, fontweight='bold',
                   bbox=dict(boxstyle='round,pad=0.5', facecolor='yellow', alpha=0.3))
    
    ax.set_xlabel('Speed (samples/second)', fontsize=14, fontweight='bold')
    ax.set_ylabel('F1 Score (%)', fontsize=14, fontweight='bold')
    ax.set_title('Model Performance: Speed vs Accuracy Trade-off', 
                 fontsize=16, fontweight='bold', pad=20)
    ax.grid(True, alpha=0.3, linestyle='--')
    
    plt.tight_layout()
    output_path = os.path.join(output_dir, 'speed_vs_accuracy.png')
    plt.savefig(output_path, dpi=300, bbox_inches='tight')
    print(f"✓ Saved: {output_path}")
    plt.close()

def create_load_time_chart(df, output_dir):
    """Create a bar chart for model load time comparison"""
    fig, ax = plt.subplots(figsize=(12, 7))
    
    colors = plt.cm.plasma(np.linspace(0.3, 0.9, len(df)))
    bars = ax.bar(df['model_name'], df['load_time'], color=colors, 
                  alpha=0.8, edgecolor='black', linewidth=1.2)
    
    # Add value labels
    for bar in bars:
        height = bar.get_height()
        ax.text(bar.get_x() + bar.get_width()/2., height,
               f'{height:.2f}s',
               ha='center', va='bottom', fontsize=11, fontweight='bold')
    
    ax.set_xlabel('Models', fontsize=14, fontweight='bold')
    ax.set_ylabel('Time (seconds)', fontsize=14, fontweight='bold')
    ax.set_title('Model Load Time Comparison', 
                 fontsize=16, fontweight='bold', pad=20)
    ax.set_xticklabels(df['model_name'], rotation=15, ha='right')
    ax.grid(axis='y', alpha=0.3, linestyle='--')
    
    plt.tight_layout()
    output_path = os.path.join(output_dir, 'load_time.png')
    plt.savefig(output_path, dpi=300, bbox_inches='tight')
    print(f"✓ Saved: {output_path}")
    plt.close()

def main():
    """Main function"""
    print("="*80)
    print("BENCHMARK VISUALIZATION GENERATOR")
    print("="*80)
    
    # Paths
    script_dir = os.path.dirname(os.path.abspath(__file__))
    results_file = os.path.join(script_dir, '..', '..', 'benchmark_summary_report.txt')
    output_dir = os.path.join(script_dir, 'results')
    
    # Create output directory
    os.makedirs(output_dir, exist_ok=True)
    
    # Check if results file exists
    if not os.path.exists(results_file):
        print(f"❌ Error: Results file not found: {results_file}")
        return
    
    print(f"\n📊 Reading results from: {results_file}")
    
    # Parse results
    df = parse_results_file(results_file)
    
    if df.empty:
        print("❌ Error: No data found in results file")
        return
    
    print(f"✓ Found {len(df)} models")
    print("\nModels:")
    for i, name in enumerate(df['model_name'], 1):
        print(f"  {i}. {name}")
    
    # Generate charts
    print(f"\n📈 Generating visualizations...")
    print(f"Output directory: {output_dir}\n")
    
    create_metric_comparison_chart(df, output_dir)
    create_f1_ranking_chart(df, output_dir)
    create_inference_time_chart(df, output_dir)
    create_load_time_chart(df, output_dir)
    create_speed_vs_accuracy_scatter(df, output_dir)
    
    print("\n" + "="*80)
    print("✓ ALL VISUALIZATIONS GENERATED SUCCESSFULLY!")
    print("="*80)
    print(f"\nFiles saved to: {os.path.abspath(output_dir)}")

if __name__ == "__main__":
    main()
