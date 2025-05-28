
import re
from ollama import AsyncClient
import asyncio
import json
import os

SYSTEM_PROMPT = """
You are an expert emotional analysis assistant. Your task is to analyze input text and assign scores (1-10) to 8 fundamental emotions: **joy, acceptance, fear, surprise, sadness, disgust, anger, and anticipation**.

For each emotion, provide a concise reason for the assigned score.

Output your analysis as a valid Python list in the following format:

[
    {"analysis": "<REASON>", "dim": "joy", "score": <SCORE>},
    {"analysis": "<REASON>", "dim": "acceptance", "score": <SCORE>},
    {"analysis": "<REASON>", "dim": "fear", "score": <SCORE>},
    {"analysis": "<REASON>", "dim": "surprise", "score": <SCORE>},
    {"analysis": "<REASON>", "dim": "sadness", "score": <SCORE>},
    {"analysis": "<REASON>", "dim": "disgust", "score": <SCORE>},
    {"analysis": "<REASON>", "dim": "anticipation", "score": <SCORE>},
    {"analysis": "<REASON>", "dim": "anger", "score": <SCORE>}
]

**Rules:**
* Each of the 8 emotions must be included exactly once.
* Reasons for scores must be logical, concise, and directly support the assigned intensity.
* Adhere strictly to the specified JSON output format.
"""

EMOTIONS = ["joy", "acceptance", "fear", "surprise", "sadness", "disgust", "anger", "anticipation"]
DEFAULT_MODEL = "gemma3:4b"

def extract_json_list(text: str) -> str | None:
    match = re.search(r'\[\s*{.*?}\s*\]', text, re.DOTALL)
    if match:
        return match.group(0)
    return None

async def analyze_emotion(prompt: str, model: str = DEFAULT_MODEL) -> list[dict] | None:
    print(f"Sending prompt to LLM: '{prompt[:70]}...'")
    messages = [
        {'role': 'system', 'content': SYSTEM_PROMPT},
        {'role': 'user', 'content': prompt}
    ]
    try:
        response = await AsyncClient().chat(model=model, messages=messages)
        content = response.message.content
        print("Raw LLM output:\n", content)

        json_str = extract_json_list(content or "")
        if not json_str:
            print("Error: No valid JSON list found in LLM output.")
            return None

        emotion_data = json.loads(json_str)
        print("Parsed emotion data:\n", json.dumps(emotion_data, indent=2))

        # Optionally, validate and clamp scores here if needed
        for item in emotion_data:
            if "score" in item:
                try:
                    score_float = float(item["score"])
                    if not (1 <= score_float <= 10):
                        print(f"Warning: Score for '{item.get('dim')}' ({score_float}) is out of expected range (1-10).")
                        item["score"] = max(1.0, min(10.0, score_float))
                    else:
                        item["score"] = score_float
                except (ValueError, TypeError):
                    print(f"Warning: Invalid score type for '{item.get('dim')}'. Expected a number, got '{item['score']}'.")
                    item["score"] = 1.0
        return emotion_data

    except json.JSONDecodeError as e:
        print(f"Error: Failed to decode JSON from LLM output: {e}")
        return None
    except Exception as e:
        print(f"An unexpected error occurred during emotion analysis: {e}")
        return None

async def analyze_json_file(json_path: str) -> list[dict] | None:
    if not os.path.exists(json_path):
        print(f"Error: JSON file not found at '{json_path}'")
        return None

    try:
        with open(json_path, 'r', encoding='utf-8') as f:
            data = json.load(f)
    except json.JSONDecodeError as e:
        print(f"Error: Invalid JSON format in '{json_path}': {e}")
        return None
    except Exception as e:
        print(f"Error reading file '{json_path}': {e}")
        return None

    texts = []
    if isinstance(data, dict) and "messages" in data and isinstance(data["messages"], list):
        texts = [m["text"] for m in data["messages"] if isinstance(m, dict) and "text" in m]
    elif isinstance(data, list):
        if all(isinstance(obj, dict) and "text" in obj for obj in data):
            texts = [obj["text"] for obj in data]
        elif all(isinstance(obj, str) for obj in data):
            texts = data
        else:
            print(f"Warning: JSON file '{json_path}' contains a list with unrecognized object types. "
                  "Expected list of strings or dicts with 'text' key.")
            return None
    else:
        print(f"Error: Unrecognized JSON structure in '{json_path}'. "
              "Expected a list of messages or a dictionary with a 'messages' array.")
        return None

    if not texts:
        print(f"No messages found to analyze in '{json_path}'.")
        return []

    results = []
    for i, msg in enumerate(texts):
        print(f"\n--- Analyzing Message {i+1}/{len(texts)} ---")
        print(f"Message: {msg}")
        analysis = await analyze_emotion(msg)
        results.append({'text': msg, 'analysis': analysis})
    return results

async def textExtraction():
    outputs =[]
    json_file_path = r"C:\3rd year sec sem\Capstone\Telegram\telegram\Backend\saved_messages\Carlo_Lorieta.json"
    print(f"Automatically analyzing JSON file: {json_file_path}")
    analysis_results = await analyze_json_file(json_file_path)

    if analysis_results:
         return {"results": analysis_results}
          
    else:
        return("No analysis results or an error occurred during file analysis.")

asyncio.run(textExtraction())