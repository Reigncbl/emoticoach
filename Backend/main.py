
import os
import json
import re
from chatInference import textExtraction
from fastapi.responses import JSONResponse
from fastapi import FastAPI,Query
from pydantic import BaseModel
from telethon import TelegramClient
from telethon.tl.functions.contacts import ImportContactsRequest
from telethon.tl.types import InputPhoneContact

api_id = os.getenv('TELEGRAM_API_ID')
api_hash = os.getenv('TELEGRAM_API_HASH')

session = 'name'
client = TelegramClient(session, api_id, api_hash)
app = FastAPI()

class ContactRequest(BaseModel):
    phone: str
    first_name: str = ""
    last_name: str = ""
    
@app.get("/")
async def get_messages():
    return {"message": "hello"}
    
@app.post("/messages")
async def get_messages(data: ContactRequest):
    async with client:
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

        response_data = {
            "sender": sender,
            "receiver": rec_name,
            "messages": messages
        }

        # Ensure the directory exists
        save_dir = "saved_messages"
        os.makedirs(save_dir, exist_ok=True)

        # Sanitize receiver name for filename
        safe_rec_name = re.sub(r'[^a-zA-Z0-9_-]', '_', rec_name)
        filename = f"{safe_rec_name}.json"
        file_path = os.path.join(save_dir, filename)
        with open(file_path, "w", encoding="utf-8") as f:
            json.dump(response_data, f, ensure_ascii=False, indent=2)

        return {
            "message": "Messages retrieved and saved as JSON.",
            "file_path": file_path,
            **response_data
        }
@app.get("/generate")
async def generate():
    result = await textExtraction()
   
    return JSONResponse(result)
