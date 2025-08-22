import os
from nltk.translate.bleu_score import sentence_bleu, SmoothingFunction
from nltk.translate.meteor_score import meteor_score
from llama_index.llms.groq import Groq
from llama_index.core.llms import ChatMessage, MessageRole
from datasets import load_dataset
import warnings
from dotenv import load_dotenv

load_dotenv()

api_key = os.getenv("api_key")
model = os.getenv("model")

# -----------------------------
# 1. Setup Groq GPT-oss 120B
# -----------------------------

groq_client = Groq(api_key=api_key, model=model)

# -----------------------------
# 2. Load HuggingFace dataset properly
# -----------------------------
try:
    # Load the dataset using the datasets library
    dataset = load_dataset("rhyliieee/tagalog-filipino-english-translation")
    
    # Use the test split if available, otherwise use train split
    if 'test' in dataset:
        data_split = dataset['test']
    elif 'train' in dataset:
        data_split = dataset['train']
    else:
        # If no specific splits, use the first available split
        data_split = dataset[list(dataset.keys())[0]]
    
    tagalog_texts = []
    english_refs = []
    
    # Extract the text pairs from the dataset
    for item in data_split:
        # Adjust these field names based on the actual dataset structure
        if 'tagalog' in item and 'english' in item:
            tagalog_texts.append(item['tagalog'])
            english_refs.append(item['english'])
        elif 'tl' in item and 'en' in item:
            tagalog_texts.append(item['tl'])
            english_refs.append(item['en'])
        elif 'source' in item and 'target' in item:
            tagalog_texts.append(item['source'])
            english_refs.append(item['target'])
        else:
            # Print available keys to debug
            print(f"Available keys in dataset: {list(item.keys())}")
            break
    
    print(f"Loaded {len(tagalog_texts)} sentence pairs")
    
except Exception as e:
    print(f"Error loading dataset: {e}")
    print("Attempting to load from local cache...")
    
    # Fallback: try to load from the arrow file directly
    import pyarrow.parquet as pq
    import pandas as pd
    
    try:
        # Try to read the test arrow file
        arrow_file_path = r"C:\Users\John Carlo\.cache\huggingface\datasets\rhyliieee___tagalog-filipino-english-translation\default\0.0.0\ec607ec9607b367da81ca0634f30652f74280930\tagalog-filipino-english-translation-test.arrow"
        
        # Read the arrow file using pandas
        df = pd.read_feather(arrow_file_path)
        
        tagalog_texts = []
        english_refs = []
        
        # Extract data based on column names
        columns = df.columns.tolist()
        print(f"Available columns: {columns}")
        
        # Try different possible column name combinations
        if 'tagalog' in columns and 'english' in columns:
            tagalog_texts = df['tagalog'].tolist()
            english_refs = df['english'].tolist()
        elif 'tl' in columns and 'en' in columns:
            tagalog_texts = df['tl'].tolist()
            english_refs = df['en'].tolist()
        elif 'source' in columns and 'target' in columns:
            tagalog_texts = df['source'].tolist()
            english_refs = df['target'].tolist()
        elif len(columns) >= 2:
            # Use first two columns as fallback
            tagalog_texts = df[columns[0]].tolist()
            english_refs = df[columns[1]].tolist()
        
        print(f"Loaded {len(tagalog_texts)} sentence pairs from arrow file")
        
    except Exception as arrow_error:
        print(f"Error reading arrow file: {arrow_error}")
        # Create some sample data as final fallback
        tagalog_texts = [
            "Kumusta ka?",
            "Salamat sa tulong mo.",
            "Magandang umaga sa lahat."
        ]
        english_refs = [
            "How are you?",
            "Thank you for your help.",
            "Good morning everyone."
        ]
        print(f"Using sample data: {len(tagalog_texts)} sentence pairs")
# -----------------------------
# 3. Evaluation function using Groq with improved metrics
# -----------------------------
def evaluate_translation_groq(tagalog_text, reference_text):
    prompt = f"Translate the following Taglish/Tagalog text to English:\n\n{tagalog_text}"
    
    try:
        response = groq_client.chat([ChatMessage(role=MessageRole.USER, content=prompt)])
        translated_text = response.message.content.strip()
    except Exception as e:
        print(f"Error in translation API call: {e}")
        translated_text = "Translation failed"

    # Tokenize for BLEU/METEOR (simple split by space)
    reference_tokens = [reference_text.split()]
    candidate_tokens = translated_text.split()

    # Initialize smoothing function to handle n-gram overlap issues
    smoothing_function = SmoothingFunction()
    
    # Suppress BLEU warnings temporarily
    with warnings.catch_warnings():
        warnings.simplefilter("ignore")
        # Use smoothing method 4 (add-epsilon smoothing) to handle zero n-gram overlaps
        bleu = sentence_bleu(
            reference_tokens, 
            candidate_tokens, 
            smoothing_function=smoothing_function.method4
        )
    
    # Calculate METEOR score with error handling
    try:
        meteor = meteor_score([reference_text.split()], candidate_tokens)
    except Exception as e:
        print(f"Error calculating METEOR score: {e}")
        meteor = 0.0

    return translated_text, bleu, meteor

# -----------------------------
# 4. Loop through first 50 samples with improved progress tracking
# -----------------------------
bleu_scores = []
meteor_scores = []
failed_translations = 0

print("Starting translation evaluation...")
print("=" * 60)

for i, (tagalog, english_ref) in enumerate(zip(tagalog_texts, english_refs)):
    if i >= 50:
        break

    try:
        translated, bleu, meteor = evaluate_translation_groq(tagalog, english_ref)
        
        # Check for failed translations
        if translated == "Translation failed":
            failed_translations += 1
            continue
            
        bleu_scores.append(bleu)
        meteor_scores.append(meteor)

        # Show progress every 10 iterations or for first few samples
        if i % 10 == 0 or i < 3:
            print(f"[{i+1}/50] BLEU: {bleu:.4f}, METEOR: {meteor:.4f}")
            print(f"Tagalog:  {tagalog}")
            print(f"Translated: {translated}")
            print(f"Reference: {english_ref}")
            print("-" * 60)
        elif i % 5 == 0:
            # Show abbreviated progress for other samples
            print(f"[{i+1}/50] BLEU: {bleu:.4f}, METEOR: {meteor:.4f}")
            
    except Exception as e:
        print(f"Error processing sample {i+1}: {e}")
        failed_translations += 1
        continue

# -----------------------------
# 5. Aggregate results with detailed statistics
# -----------------------------
if bleu_scores and meteor_scores:
    avg_bleu = sum(bleu_scores) / len(bleu_scores)
    avg_meteor = sum(meteor_scores) / len(meteor_scores)
    
    # Calculate additional statistics
    max_bleu = max(bleu_scores)
    min_bleu = min(bleu_scores)
    max_meteor = max(meteor_scores)
    min_meteor = min(meteor_scores)
    
    print("=" * 60)
    print("EVALUATION RESULTS")
    print("=" * 60)
    print(f"Successfully evaluated: {len(bleu_scores)} samples")
    print(f"Failed translations: {failed_translations}")
    print(f"Success rate: {(len(bleu_scores)/(len(bleu_scores)+failed_translations))*100:.1f}%")
    print()
    print("BLEU SCORES:")
    print(f"  Average: {avg_bleu:.4f}")
    print(f"  Maximum: {max_bleu:.4f}")
    print(f"  Minimum: {min_bleu:.4f}")
    print()
    print("METEOR SCORES:")
    print(f"  Average: {avg_meteor:.4f}")
    print(f"  Maximum: {max_meteor:.4f}")
    print(f"  Minimum: {min_meteor:.4f}")
    print("=" * 60)
else:
    print("No successful translations to evaluate!")
