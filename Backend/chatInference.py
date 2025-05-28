import re
from ollama import AsyncClient
import asyncio
import json
import os

SYSTEM_PROMPT = """
You are an expert emotional analysis assistant. Your task is to analyze input text and assign scores (0.0-10.0) to 8 fundamental emotions: **joy, acceptance, fear, surprise, sadness, disgust, anger, and anticipation**.

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
* Make the analysis short and simple
"""

EMOTIONS = ["joy", "acceptance", "fear", "surprise", "sadness", "disgust", "anger", "anticipation"]
DEFAULT_MODEL = "gemma3:4b"

def extract_json_list(text: str) -> str | None:
    match = re.search(r'\[\s*{.*?}\s*\]', text, re.DOTALL)
    if match:
        return match.group(0)
    return None

async def analyze_emotion(prompt: str, model: str = DEFAULT_MODEL) -> list[dict] | None:
    """
    Emotion Analyzer through LLM Inference
    """
    print(f"Sending prompt to LLM: '{prompt[:70]}...'")
    messages = [
        {'role': 'system', 'content': SYSTEM_PROMPT},
        {'role': 'user', 'content': prompt}
    ]
    try:
        response = await AsyncClient().chat(model=model, messages=messages)
        content = response.message.content
        print("Raw LLM output:\n", content)

        json_str = extract_json_list(content)
        if not json_str:
            print("Error: No valid JSON list found in LLM output.")
            return None

        emotion_data = json.loads(json_str)
        print("Parsed emotion data:\n", json.dumps(emotion_data, indent=2))

        #Score Validation
        for item in emotion_data:
            if "score" in item:
                try:
                    score_float = float(item["score"])
                    if not (0.0 <= score_float <= 10.0):
                        print(f"Warning: Score for '{item.get('dim')}' ({score_float}) is out of expected range (0-10).")
                        item["score"] = max(0.0, min(10.0, score_float))
                    else:
                        item["score"] = score_float
                except (ValueError, TypeError):
                    print(f"Warning: Invalid score type for '{item.get('dim')}'. Expected a number, got '{item['score']}'.")
                    item["score"] = 0.0
        return emotion_data

    except json.JSONDecodeError as e:
        print(f"Error: Failed to decode JSON from LLM output: {e}")
        return None
    except Exception as e:
        print(f"An unexpected error occurred during emotion analysis: {e}")
        return None

async def analyze_json_file(json_path: str) -> list[dict] | None:
    """
    Analyze the json file for the embedding
    """
    if not os.path.exists(json_path):
        return None
    # Open the file and read the data
    try:
        with open(json_path, "r", encoding="utf-8") as f:
            data = json.load(f)
    except Exception:
        return None

    if isinstance(data, dict) and "messages" in data:
        messages = data["messages"]
    elif isinstance(data, list):
        messages = data
    else:
        return None
    results = []
    for m in messages:
        if isinstance(m, dict) and "text" in m:
            text = m["text"]
            ts = m.get("date", None)
        elif isinstance(m, str):
            text = m
            ts = None
        else:
            continue  

        emotion = await analyze_emotion(text)
        results.append({"text": text, "timestamp": ts, "analysis": emotion})
    return results

async def textExtraction():
    file = r"C:\3rd year sec sem\Capstone\Telegram\emoticoach\backend\saved_messages\reign.json"
    print("Analyzing:", file)
    results = await analyze_json_file(file)
    if not results:
        return {"error": "No analysis results or an error occurred during file analysis."}
    out = os.path.splitext(file)[0] + "_analysis.json"
    try:
        with open(out, "w", encoding="utf-8") as f:
            json.dump({"results": results}, f, indent=2, ensure_ascii=False)
        print("Saved:", out)
        return {"results": results, "output_file": out}
    except Exception as e:
        print("Save error:", e)
        return {"error": f"Failed to save analysis results: {e}"}

