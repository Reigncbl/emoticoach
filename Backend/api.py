# uvicorn backend.api:app --reload

from fastapi import FastAPI
from pydantic import BaseModel
from telethon import TelegramClient
from telethon.tl.functions.contacts import ImportContactsRequest
from telethon.tl.types import InputPhoneContact
from fastapi.responses import JSONResponse
import asyncio
import re
from ollama import AsyncClient
import json
import os


# Telegram API credentials
api_id = '21398172'
api_hash = '4bb0f51ffa700b91f87f07742d6f1d33'
session = 'name'
client = TelegramClient(session, api_id, api_hash)

app = FastAPI()

class ContactRequest(BaseModel):
    phone: str
    first_name: str = ""
    last_name: str = ""

# SYSTEM PROMPT for the LLM
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

DEFAULT_MODEL = "gemma3:4b"

def extract_json_list(text: str) -> str | None:
    match = re.search(r'\[\s*{.*?}\s*\]', text, re.DOTALL)
    if match:
        return match.group(0)
    return None

async def analyze_emotion(prompt: str, model: str = DEFAULT_MODEL) -> list[dict] | None:
    full_prompt = SYSTEM_PROMPT + "\n\nHere is the text to analyze:\n" + prompt
    try:
        response = await AsyncClient().chat(model=model, messages=[{'role': 'user', 'content': full_prompt}])
        content = response.message.content
        json_str = extract_json_list(content or "")
        if not json_str:
            return None
        emotion_data = json.loads(json_str)
        for item in emotion_data:
            if "score" in item:
                try:
                    score_float = float(item["score"])
                    item["score"] = max(1.0, min(10.0, score_float))
                except (ValueError, TypeError):
                    item["score"] = 1.0
        return emotion_data
    except Exception as e:
        print("Emotion analysis error:", e)
        return None

@app.on_event("startup")
async def startup_event():
    await client.start()  # Start the client once at startup

@app.on_event("shutdown")
async def shutdown_event():
    await client.disconnect()

@app.post("/messages")
async def get_messages(data: ContactRequest):
    me = await client.get_me()
    sender = f"{me.first_name} {me.last_name or ''}".strip()
    contact = InputPhoneContact(0, f'+63{data.phone}', data.first_name, data.last_name)
    res = await client(ImportContactsRequest([contact]))
    if not res.users:
        return {"error": "User not found."}
    receiver = res.users[0]
    rec_name = f"{receiver.first_name} {receiver.last_name or ''}".strip()
    messages = []
    async for msg in client.iter_messages(receiver.id, limit=10):
        name = sender if msg.out else rec_name
        messages.append({
            "from": name,
            "date": str(msg.date),
            "text": msg.text
        })
    return {
        "sender": sender,
        "receiver": rec_name,
        "messages": messages
    }

@app.post("/analyze_messages")
async def analyze_last_message(data: ContactRequest):
    me = await client.get_me()
    sender = f"{me.first_name} {me.last_name or ''}".strip()
    contact = InputPhoneContact(0, f'+63{data.phone}', data.first_name, data.last_name)
    res = await client(ImportContactsRequest([contact]))
    if not res.users:
        return {"error": "User not found."}
    receiver = res.users[0]
    rec_name = f"{receiver.first_name} {receiver.last_name or ''}".strip()
    messages = []
    async for msg in client.iter_messages(receiver.id, limit=10):
        name = sender if msg.out else rec_name
        messages.append({
            "from": name,
            "date": str(msg.date),
            "text": msg.text
        })

    if not messages:
        return JSONResponse(content={
            "sender": sender,
            "receiver": rec_name,
            "messages": [],
            "last_message_analysis": None,
            "error": "No messages found."
        })

    last_message = messages[0]
    analysis = await analyze_emotion(last_message['text'])

    return JSONResponse(content={
        "sender": sender,
        "receiver": rec_name,
        "messages": messages,
        "last_message_analysis": {
            "text": last_message["text"],
            "from": last_message["from"],
            "date": last_message["date"],
            "analysis": analysis
        }
    })

