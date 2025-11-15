"""
Simplified Model Comparison Benchmark - MELD Dataset
Compares emotion classification models on MELD test dataset
"""

from transformers import pipeline, AutoTokenizer, AutoModelForSequenceClassification
import torch
import pandas as pd
from sklearn.metrics import accuracy_score, precision_score, recall_score, f1_score, classification_report
import time
import warnings
import sys
import os

warnings.filterwarnings('ignore')

# Add parent directory to path to import AI_inferenece
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

# Emotion labels
EMOTION_LABELS = ['anger', 'disgust', 'fear', 'joy', 'neutral', 'sadness', 'surprise']

# Models to compare
MODELS = [
    {
        'name': 'Custom Local Model',
        'model_id': 'local',  # Special identifier for local model
        'params': '~82M',
        'is_local': True
    },
    {
        'name': 'RoBERTa-Large',
        'model_id': 'j-hartmann/emotion-english-roberta-large',
        'params': '~355M',
        'is_local': False
    },
    {
        'name': 'DistilRoBERTa-Base',
        'model_id': 'j-hartmann/emotion-english-distilroberta-base',
        'params': '~82M',
        'is_local': False
    },
    {
        'name': 'DeBERTa-v3-Large',
        'model_id': 'Tanneru/Emotion-Classification-DeBERTa-v3-Large',
        'params': '~434M',
        'is_local': False
    }
]

def print_header():
    """Print benchmark header"""
    print("="*80)
    print("EMOTION CLASSIFICATION MODEL COMPARISON - UNDERSAMPLED VALIDATION")
    print("="*80)
    print(f"Device: {'GPU (CUDA)' if torch.cuda.is_available() else 'CPU'}")
    print(f"Dataset: undersampled_val.json (7 emotion classes, 50 per class)")
    print("\nModels:")
    for i, model in enumerate(MODELS, 1):
        print(f"  {i}. {model['name']} ({model['params']})")
    print("="*80)

def evaluate_local_model(model_info, texts, true_labels):
    """Evaluate the local custom model"""
    print(f"\n{'='*80}")
    print(f"Evaluating: {model_info['name']} (Local)")
    print(f"{'='*80}")
    
    try:
        from services.AI_inferenece import predict_batch, load_local_model
        
        # Load model
        print("Loading local model...")
        start_load = time.time()
        load_local_model()
        load_time = time.time() - start_load
        print(f"Model loaded in {load_time:.2f}s")
        
        # Run predictions
        print(f"Running predictions on {len(texts)} samples...")
        start_time = time.time()
        predictions = predict_batch(texts, top_k=1, batch_size=32)
        inference_time = time.time() - start_time
        
        # Extract predicted labels and convert to lowercase
        predicted_labels = [p['label'].lower() for p in predictions]
        
        # Calculate metrics
        accuracy = accuracy_score(true_labels, predicted_labels)
        precision = precision_score(true_labels, predicted_labels, average='weighted', zero_division=0)
        recall = recall_score(true_labels, predicted_labels, average='weighted', zero_division=0)
        f1 = f1_score(true_labels, predicted_labels, average='weighted', zero_division=0)
        
        print(f"\nResults:")
        print(f"  Accuracy:  {accuracy*100:.2f}%")
        print(f"  Precision: {precision*100:.2f}%")
        print(f"  Recall:    {recall*100:.2f}%")
        print(f"  F1-Score:  {f1*100:.2f}%")
        print(f"  Time:      {inference_time:.2f}s ({inference_time/len(texts)*1000:.2f}ms/sample)")
        
        # Per-class metrics
        print(f"\nPer-Class Performance:")
        report = classification_report(true_labels, predicted_labels, output_dict=True, zero_division=0)
        
        for emotion in sorted(set(true_labels)):
            if emotion in report:
                p = report[emotion]['precision']
                r = report[emotion]['recall']
                f = report[emotion]['f1-score']
                s = int(report[emotion]['support'])
                print(f"  {emotion:8s}: P={p:.3f} R={r:.3f} F1={f:.3f} (n={s})")
        
        return {
            'model_name': model_info['name'],
            'accuracy': accuracy,
            'precision': precision,
            'recall': recall,
            'f1_score': f1,
            'inference_time': inference_time,
            'load_time': load_time
        }
        
    except Exception as e:
        print(f"Error: {str(e)}")
        import traceback
        traceback.print_exc()
        return None

def evaluate_model(model_info, texts, true_labels):
    """Evaluate a single model"""
    # Check if it's a local model
    if model_info.get('is_local', False):
        return evaluate_local_model(model_info, texts, true_labels)
    
    print(f"\n{'='*80}")
    print(f"Evaluating: {model_info['name']}")
    print(f"{'='*80}")
    
    try:
        # Load model
        print("Loading model...")
        start_load = time.time()
        
        # Force GPU usage
        device = "cuda" if torch.cuda.is_available() else "cpu"
        print(f"Using device: {device}")
        
        tokenizer = AutoTokenizer.from_pretrained(model_info['model_id'])
        model = AutoModelForSequenceClassification.from_pretrained(model_info['model_id'])
        model = model.to(device)
        
        device_id = 0 if device == "cuda" else -1
        classifier = pipeline("text-classification", model=model, tokenizer=tokenizer, device=device_id)
        load_time = time.time() - start_load
        print(f"Model loaded in {load_time:.2f}s")
        
        # Run predictions
        print(f"Running predictions on {len(texts)} samples...")
        start_time = time.time()
        predictions = classifier(texts, batch_size=32)
        inference_time = time.time() - start_time
        
        # Extract predicted labels
        predicted_labels = [p['label'].lower() for p in predictions]
        
        # Calculate metrics
        accuracy = accuracy_score(true_labels, predicted_labels)
        precision = precision_score(true_labels, predicted_labels, average='weighted', zero_division=0)
        recall = recall_score(true_labels, predicted_labels, average='weighted', zero_division=0)
        f1 = f1_score(true_labels, predicted_labels, average='weighted', zero_division=0)
        
        print(f"\nResults:")
        print(f"  Accuracy:  {accuracy*100:.2f}%")
        print(f"  Precision: {precision*100:.2f}%")
        print(f"  Recall:    {recall*100:.2f}%")
        print(f"  F1-Score:  {f1*100:.2f}%")
        print(f"  Time:      {inference_time:.2f}s ({inference_time/len(texts)*1000:.2f}ms/sample)")
        
        # Per-class metrics
        print(f"\nPer-Class Performance:")
        report = classification_report(true_labels, predicted_labels, output_dict=True, zero_division=0)
        
        for emotion in sorted(set(true_labels)):
            if emotion in report:
                p = report[emotion]['precision']
                r = report[emotion]['recall']
                f = report[emotion]['f1-score']
                s = int(report[emotion]['support'])
                print(f"  {emotion:8s}: P={p:.3f} R={r:.3f} F1={f:.3f} (n={s})")
        
        # Cleanup
        del model, classifier
        if torch.cuda.is_available():
            torch.cuda.empty_cache()
        
        return {
            'model_name': model_info['name'],
            'accuracy': accuracy,
            'precision': precision,
            'recall': recall,
            'f1_score': f1,
            'inference_time': inference_time,
            'load_time': load_time
        }
        
    except Exception as e:
        print(f"Error: {str(e)}")
        return None

def main():
    """Main function"""
    print_header()
    
    # Label to emotion mapping (7 classes)
    ID_TO_LABEL = {
        0: "anger",
        1: "disgust",
        2: "fear",
        3: "happiness",
        4: "neutral",
        5: "sadness",
        6: "surprise"
    }
    
    # Load undersampled validation dataset (JSON)
    print("\nLoading undersampled validation dataset...")
    import os
    # Get the directory where this script is located
    script_dir = os.path.dirname(os.path.abspath(__file__))
    json_path = os.path.join(script_dir, "undersampled_val.json")
    
    try:
        import json
        with open(json_path, 'r', encoding='utf-8') as f:
            data = json.load(f)
        
        print(f"Loaded {len(data['texts'])} samples")
        
        # Create dataframe
        df = pd.DataFrame({
            'text': data['texts'],
            'label': data['labels'],
            'emotion': data['emotions']
        })
        
        # Convert emotion names to lowercase for consistency
        df['emotion'] = df['emotion'].str.lower()
        
        # Undersample to 50 samples per class
        samples_per_class = 50
        print(f"\nUndersampling to {samples_per_class} samples per class...")
        df_sampled = df.groupby('emotion', group_keys=False).apply(
            lambda x: x.sample(n=min(samples_per_class, len(x)), random_state=42)
        ).reset_index(drop=True)
        
        # Show emotion distribution
        print(f"\nEmotion distribution:")
        for emotion, count in df_sampled['emotion'].value_counts().items():
            print(f"  {emotion}: {count}")
        print(f"Total samples: {len(df_sampled)}")
        
        # Prepare data
        texts = df_sampled['text'].tolist()
        true_labels = df_sampled['emotion'].tolist()
        
    except FileNotFoundError:
        print(f"Error: Could not find {json_path}")
        return
    except Exception as e:
        print(f"Error loading JSON: {str(e)}")
        return
    
    # Evaluate all models
    results = []
    for i, model_info in enumerate(MODELS, 1):
        print(f"\n\n{'#'*80}")
        print(f"# MODEL {i}/{len(MODELS)}")
        print(f"{'#'*80}")
        
        result = evaluate_model(model_info, texts, true_labels)
        if result:
            results.append(result)
        time.sleep(1)
    
    # Summary comparison
    if results:
        print(f"\n\n{'='*80}")
        print("SUMMARY COMPARISON")
        print(f"{'='*80}")
        
        # Create comparison table
        summary_df = pd.DataFrame(results)
        summary_df['accuracy'] = summary_df['accuracy'].apply(lambda x: f"{x*100:.2f}%")
        summary_df['precision'] = summary_df['precision'].apply(lambda x: f"{x*100:.2f}%")
        summary_df['recall'] = summary_df['recall'].apply(lambda x: f"{x*100:.2f}%")
        summary_df['f1_score'] = summary_df['f1_score'].apply(lambda x: f"{x*100:.2f}%")
        summary_df['inference_time'] = summary_df['inference_time'].apply(lambda x: f"{x:.2f}s")
        
        print("\n" + summary_df.to_string(index=False))
        
        # Save results
        output_file = "benchmark_summary_report.txt"
        with open(output_file, 'w', encoding='utf-8') as f:
            f.write("EMOTION CLASSIFICATION MODEL COMPARISON\n")
            f.write("="*80 + "\n")
            f.write(f"Dataset: meld-test.csv ({len(texts)} samples)\n")
            f.write(f"Device: {'GPU (CUDA)' if torch.cuda.is_available() else 'CPU'}\n\n")
            f.write(summary_df.to_string(index=False))
        
        print(f"\nResults saved to: {output_file}")
    
    print(f"\n{'='*80}")
    print("BENCHMARK COMPLETE")
    print(f"{'='*80}")

if __name__ == "__main__":
    main()
