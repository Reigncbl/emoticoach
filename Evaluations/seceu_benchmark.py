import os
import time
import argparse
from groq import Groq
from dotenv import load_dotenv # <--- ADDED
from docx import Document # <--- ADDED

# Load environment variables from a .env file
load_dotenv() # <--- ADDED

# ==============================================================================
# 1. SECEU TEST CONTENT
# ==============================================================================

def load_seceu_from_docx(docx_path):
    """
    Reads the SECEU test from a DOCX file and extracts individual questions.
    Returns a list of question dictionaries.
    """
    doc = Document(docx_path)
    
    # Collect all non-empty paragraphs
    paragraphs = []
    for paragraph in doc.paragraphs:
        text = paragraph.text.strip()
        if text:
            paragraphs.append(text)
    
    # Parse individual questions
    questions = []
    current_question = None
    
    # Skip the title (first paragraph)
    i = 1
    while i < len(paragraphs):
        line = paragraphs[i]
        
        if line.startswith("Item "):
            # Start a new question
            if current_question:
                questions.append(current_question)
            current_question = {
                "item_number": line,
                "story": "",
                "choices": []
            }
        elif line.startswith("Options:"):
            # This is the choices line in format: Options: (1) Choice1; (2) Choice2; (3) Choice3; (4) Choice4
            if current_question:
                # Extract choices from the options line
                options_text = line.replace("Options:", "").strip()
                # Split by numbered options and extract the emotion words
                import re
                # Find all patterns like "(1) Emotion" and extract just the emotion
                matches = re.findall(r'\(\d+\)\s*([^;]+)', options_text)
                choices = [match.strip() for match in matches]
                current_question["choices"] = choices
        elif line.startswith("Story:"):
            # This is the story line
            if current_question:
                current_question["story"] = line.replace("Story:", "").strip()
        else:
            # This might be continuation of story
            if current_question and current_question["story"]:
                current_question["story"] += " " + line
        
        i += 1
    
    # Add the last question if it exists
    if current_question:
        questions.append(current_question)
    
    return questions

def create_single_question_prompt(question_data):
    """
    Creates a prompt for a single SECEU question, with a more empathetic and supportive tone.
    """
    prompt = [
        "You are gently supporting someone as they reflect on a story from the Situational Evaluation of Complex Emotional Understanding (SECEU).",
        "",
        "INSTRUCTIONS:",
        "- Please read the story below with care and empathy.",
        "- Kindly select the ONE emotion that best fits the story from the 4 choices provided.",
        "- You MUST choose ONLY from the 4 given options, respecting the choices as written.",
        "- Please copy the emotion word EXACTLY as it appears (same spelling, same capitalization).",
        "",
        f"{question_data['item_number']}",
        f"{question_data['story']}",
        "",
        f"Choices: {question_data['choices']}",
        "",
        "IMPORTANT: Respond with ONLY the chosen emotion word, nothing else.",
        "Do not add explanations, quotes, or any other text."
    ]
    
    return "\n".join(prompt)# ==============================================================================
# 2. ARGUMENT PARSING
# ==============================================================================

def parse_args():
    """Parses command-line arguments for the script."""
    parser = argparse.ArgumentParser(
        description="Groq benchmark for the SECEU test (measures speed/latency and token throughput).",
        formatter_class=argparse.RawTextHelpFormatter
    )
    
    parser.add_argument(
        "--model",
        type=str,
        required=True,
        help="Specify the AI model to benchmark (e.g., 'meta-llama/llama-4-maverick-17b-128e-instruct', 'moonshotai/kimi-k2-instruct-0905', etc.)"
    )
    parser.add_argument(
        "--runs",
        type=int,
        default=5,
        help="The number of benchmark runs to perform."
    )
    
    return parser.parse_args()

# ==============================================================================
# 3. BENCHMARK FUNCTION
# ==============================================================================

def run_seceu_benchmark(model_name, num_runs):
    """
    Runs the SECEU benchmark, processing questions one at a time.
    """
    print(f"\n🧠 Starting SECEU benchmark for model: {model_name} 🧠")
    print("-" * 60)
    
    # Load SECEU questions from DOCX file
    docx_path = os.path.join(os.path.dirname(__file__), "SECEU_40items_English.docx")
    if not os.path.exists(docx_path):
        print(f"FATAL ERROR: SECEU DOCX file not found at {docx_path}")
        return
    
    questions = load_seceu_from_docx(docx_path)
    print(f"Loaded {len(questions)} SECEU questions")
    
    # Initialize Groq client using the environment variable loaded by dotenv
    api_key = os.getenv("api_key")
    if not api_key:
        print("FATAL ERROR: GROQ_API_KEY not found. Make sure it's in your .env file.")
        return

    try:
        client = Groq(api_key=api_key)
    except Exception as e:
        print(f"ERROR: Groq client failed to initialize: {e}")
        return

    all_run_results = []  # Store results for each complete run
    
    for run_num in range(num_runs):
        print(f"\nRun {run_num+1}/{num_runs}:")
        print("-" * 40)
        
        run_answers = []
        run_start_time = time.time()
        total_tokens = 0
        failed_questions = 0
        
        # Process each question individually
        for q_idx, question in enumerate(questions):
            question_prompt = create_single_question_prompt(question)
            
            try:
                # Get response for single question
                response = client.chat.completions.create(
                    model=model_name,
                    messages=[
                        {"role": "user", "content": question_prompt}
                    ],
                    max_tokens=10,  # Only need one emotion word
                    temperature=0.1  # Low temperature for consistency
                )
                
                answer = response.choices[0].message.content.strip()
                # If using gpt-oss-120b, extract the emotion after any '[THINKING MODE]' or reasoning
                if model_name == "openai/gpt-oss-120b":
                    import re
                    # Remove [THINKING MODE] tag if present
                    answer = re.sub(r"^\\[THINKING MODE\\]\\s*", "", answer)
                    # Extract the first valid emotion from the answer
                    for choice in question["choices"]:
                        if choice in answer:
                            answer = choice
                            break
                # Validate answer is from the choices
                if answer in question["choices"]:
                    run_answers.append(answer)
                    print(f"  Q{q_idx+1}: {answer} ✓")
                else:
                    # Try to find a close match
                    answer_lower = answer.lower()
                    matched = False
                    for choice in question["choices"]:
                        if choice.lower() == answer_lower:
                            run_answers.append(choice)
                            print(f"  Q{q_idx+1}: {choice} ✓ (corrected from '{answer}')")
                            matched = True
                            break
                    if not matched:
                        # Use first choice as fallback
                        run_answers.append(question["choices"][0])
                        print(f"  Q{q_idx+1}: {question['choices'][0]} ⚠️ (fallback, got '{answer}')")
                        failed_questions += 1
                total_tokens += response.usage.total_tokens if response.usage else 1
                
            except Exception as e:
                print(f"  Q{q_idx+1}: ERROR - {e}")
                # Use first choice as fallback
                run_answers.append(question["choices"][0])
                failed_questions += 1
        
        run_end_time = time.time()
        run_duration = run_end_time - run_start_time
        
        # Store run results
        run_result = {
            "answers": run_answers,
            "duration": run_duration,
            "tokens": total_tokens,
            "failed_questions": failed_questions
        }
        all_run_results.append(run_result)
        
        print(f"  Completed in {run_duration:.2f}s | Tokens: {total_tokens} | Failed: {failed_questions}/40")
    
    # Calculate overall statistics
    if not all_run_results:
        print("\nBenchmark failed to complete any runs successfully.")
        return
    
    avg_duration = sum(r["duration"] for r in all_run_results) / len(all_run_results)
    avg_tokens = sum(r["tokens"] for r in all_run_results) / len(all_run_results)
    avg_failed = sum(r["failed_questions"] for r in all_run_results) / len(all_run_results)
    
    print("\n" + "=" * 60)
    print("✨ SECEU Benchmark Results ✨")
    print(f"Model: {model_name}")
    print(f"Successful Runs: {len(all_run_results)}")
    print(f"Average Duration: {avg_duration:.2f} seconds")
    print(f"Average Tokens: {avg_tokens:.1f}")
    print(f"Average Failed Questions: {avg_failed:.1f}/40")
    print("=" * 60)
    
    # Print the last run's answers in the expected format
    if all_run_results:
        last_answers = all_run_results[-1]["answers"]
        print("\n📝 Last Run Answers (Python format):")
        print("llm_answers = [")
        
        # Format as 10 emotions per line
        for i in range(0, len(last_answers), 10):
            line_emotions = last_answers[i:i+10]
            formatted_emotions = ",".join(f'"{emotion}"' for emotion in line_emotions)
            if i + 10 < len(last_answers):
                print(f"    {formatted_emotions},")
            else:
                print(f"    {formatted_emotions}")
        
        print("]")
        print("-" * 60)

# ==============================================================================
# 5. MAIN EXECUTION
# ==============================================================================

if __name__ == "__main__":
    args = parse_args()
    run_seceu_benchmark(args.model, args.runs)