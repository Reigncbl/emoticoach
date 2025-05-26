# # uvicorn backend.chatInference:app --reload

# from fastapi import FastAPI
# from fastapi.responses import JSONResponse
# import asyncio
# import re
# from ollama import AsyncClient
# import json
# import os

# app = FastAPI()

# SYSTEM_PROMPT = """
# You are an expert emotional analysis assistant. Your task is to analyze input text and assign scores (1-10) to 8 fundamental emotions: **joy, acceptance, fear, surprise, sadness, disgust, anger, and anticipation**.

# For each emotion, provide a concise reason for the assigned score.

# Output your analysis as a valid Python list in the following format:

# [
#     {"analysis": "<REASON>", "dim": "joy", "score": <SCORE>},
#     {"analysis": "<REASON>", "dim": "acceptance", "score": <SCORE>},
#     {"analysis": "<REASON>", "dim": "fear", "score": <SCORE>},
#     {"analysis": "<REASON>", "dim": "surprise", "score": <SCORE>},
#     {"analysis": "<REASON>", "dim": "sadness", "score": <SCORE>},
#     {"analysis": "<REASON>", "dim": "disgust", "score": <SCORE>},
#     {"analysis": "<REASON>", "dim": "anticipation", "score": <SCORE>},
#     {"analysis": "<REASON>", "dim": "anger", "score": <SCORE>}
# ]

# **Rules:**
# * Each of the 8 emotions must be included exactly once.
# * Reasons for scores must be logical, concise, and directly support the assigned intensity.
# * Adhere strictly to the specified JSON output format.
# """

# EMOTIONS = ["joy", "acceptance", "fear", "surprise", "sadness", "disgust", "anger", "anticipation"]
# DEFAULT_MODEL = "gemma3:4b"

# def extract_json_list(text: str) -> str | None:
#     match = re.search(r'\[\s*{.*?}\s*\]', text, re.DOTALL)
#     if match:
#         return match.group(0)
#     return None

# async def analyze_emotion(prompt: str, model: str = DEFAULT_MODEL) -> list[dict] | None:
#     messages = [
#         {'role': 'system', 'content': SYSTEM_PROMPT},
#         {'role': 'user', 'content': prompt}
#     ]
#     try:
#         response = await AsyncClient().chat(model=model, messages=messages)
#         content = response.message.content
#         json_str = extract_json_list(content or "")
#         if not json_str:
#             return None

#         emotion_data = json.loads(json_str)

#         for item in emotion_data:
#             if "score" in item:
#                 try:
#                     score_float = float(item["score"])
#                     item["score"] = max(1.0, min(10.0, score_float))
#                 except (ValueError, TypeError):
#                     item["score"] = 1.0
#         return emotion_data

#     except json.JSONDecodeError:
#         return None
#     except Exception:
#         return None

# async def analyze_json_file(json_path: str) -> list[dict] | None:
#     if not os.path.exists(json_path):
#         return None

#     try:
#         with open(json_path, 'r', encoding='utf-8') as f:
#             data = json.load(f)
#     except Exception:
#         return None

#     texts = []
#     if isinstance(data, dict) and "messages" in data:
#         texts = [m["text"] for m in data["messages"] if isinstance(m, dict) and "text" in m]
#     elif isinstance(data, list):
#         if all(isinstance(obj, dict) and "text" in obj for obj in data):
#             texts = [obj["text"] for obj in data]
#         elif all(isinstance(obj, str) for obj in data):
#             texts = data
#         else:
#             return None
#     else:
#         return None

#     if not texts:
#         return []

#     results = []
#     for msg in texts:
#         analysis = await analyze_emotion(msg)
#         results.append({'text': msg, 'analysis': analysis})
#     return results

# async def textExtraction():
#     json_file_path = r"C:\3rd year sec sem\Capstone\Telegram\telegram\Backend\saved_messages\Carlo_Lorieta.json"
#     analysis_results = await analyze_json_file(json_file_path)

#     if analysis_results:
#         return {"results": analysis_results}
#     else:
#         return {"error": "No analysis results or an error occurred during file analysis."}

# @app.get("/analyze")
# async def analyze_endpoint():
#     result = await textExtraction()
#     return JSONResponse(content=result)
