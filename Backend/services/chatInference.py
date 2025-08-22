import re
from ollama import AsyncClient
import asyncio
import json
import os

SYSTEM_PROMPT = """

Below is the instruction that 

*MANDATORY EMOTION LIST - ONLY THESE 28 ALLOWED:*

0. admiration    1. amusement     2. anger         3. annoyance     4. approval
5. caring        6. confusion     7. curiosity     8. desire        9. disappointment
10. disapproval  11. disgust      12. embarrassment 13. excitement   14. fear
15. gratitude    16. grief        17. joy          18. love         19. nervousness
20. optimism     21. pride        22. realization  23. relief       24. remorse
25. sadness      26. surprise     27. neutral

*ABSOLUTE RULE:* 
You MUST always respond with valid JSON. If unsure about emotion, use "neutral".

*CRITICAL:* Your response must be EXACTLY this format with no extra text:
[
    {"analysis": "brief reason here", "dim": "emotion_name", "score": 5.0}
]

*PROCESS:*
1. Read the input text
2. Pick the best emotion from the 28 above (or "neutral" if none fit)
3. Write a brief analysis explaining why
4. Give a score 0.0-10.0
5. Format as JSON array with one object

*EXAMPLES:*
Text: "You know the answer man, you are programmed to capture those codes they send you, don't avoid them!"
Response: [{"analysis": "Text shows confrontational and accusatory tone", "dim": "annoyance", "score": 7.5}]

Text: "I miss the old days"
Response: [{"analysis": "Nostalgic feeling not in list, using fallback", "dim": "neutral", "score": 5.0}]

Text: "This is amazing!"
Response: [{"analysis": "Text expresses strong positive reaction", "dim": "joy", "score": 8.0}]

*REQUIREMENTS:*
- Always output valid JSON array format
- Use only emotions from the numbered list 0-27
- Keep analysis brief (under 15 words)
- Score must be between 0.0 and 10.0
- No extra text before or after the JSON
"""

DEFAULT_MODEL = "gemma3n:e2b"

def extract_json_list(text: str) -> str | None:
    match = re.search(r'\[\s*{.*?}\s*\]', text, re.DOTALL)
    return match.group(0) if match else None

async def analyze_emotion(text: str, model: str = DEFAULT_MODEL) -> dict | None:
    """Analyze emotion of a single text"""
    messages = [
        {'role': 'system', 'content': SYSTEM_PROMPT},
        {'role': 'user', 'content': text}
    ]
    
    try:
        response = await AsyncClient().chat(model=model, messages=messages)
        json_str = extract_json_list(response.message.content)
        
        if not json_str:
            return None
            
        emotion_data = json.loads(json_str)
        
        # Validate and fix score
        if emotion_data and len(emotion_data) > 0:
            item = emotion_data[0]
            score = float(item.get("score", 0))
            item["score"] = max(0.0, min(10.0, score))
            return item
            
    except Exception as e:
        print(f"Error analyzing emotion: {e}")
        
    return None

async def analyze_file(file_path: str) -> list[dict]:
    """Analyze emotions in a JSON file containing messages"""
    try:
        with open(file_path, "r", encoding="utf-8") as f:
            data = json.load(f)
    except Exception as e:
        print(f"Error reading file: {e}")
        return []

    # Extract messages
    if isinstance(data, dict) and "messages" in data:
        messages = data["messages"]
    elif isinstance(data, list):
        messages = data
    else:
        print("Invalid file format")
        return []
    
    results = []
    for msg in messages:
        # Extract text from message
        if isinstance(msg, dict) and "text" in msg:
            text = msg["text"]
            timestamp = msg.get("date")
        elif isinstance(msg, str):
            text = msg
            timestamp = None
        else:
            continue
            
        # Analyze emotion
        emotion = await analyze_emotion(text)
        if emotion:
            results.append({
                "text": text,
                "timestamp": timestamp,
                "emotion": emotion["dim"],
                "score": emotion["score"],
                "analysis": emotion["analysis"]
            })
    
    return results

async def main():
    file_path = r"C:\Users\John Carlo\telegram\Backend\saved_messages\reign.json"
    
    print(f"Analyzing: {file_path}")
    results = await analyze_file(file_path)
    
    if not results:
        print("No results found")
        return
    
    # Save results
    output_path = os.path.splitext(file_path)[0] + "_analysis.json"
    try:
        with open(output_path, "w", encoding="utf-8") as f:
            json.dump(results, f, indent=2, ensure_ascii=False)
        print(f"Saved {len(results)} results to: {output_path}")
    except Exception as e:
        print(f"Error saving results: {e}")

if __name__ == "_main_":

    asyncio.run(main())