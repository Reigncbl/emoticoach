# uvicorn backend.api:app --reload

from fastapi import FastAPI
from pydantic import BaseModel
from telethon import TelegramClient
from telethon.tl.functions.contacts import ImportContactsRequest
from telethon.tl.types import InputPhoneContact

api_id = '21398172'
api_hash = '4bb0f51ffa700b91f87f07742d6f1d33'
session = 'name'

client = TelegramClient(session, api_id, api_hash)

app = FastAPI()

class ContactRequest(BaseModel):
    phone: str
    first_name: str = ""
    last_name: str = ""

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

        return {
            "sender": sender,
            "receiver": rec_name,
            "messages": messages
        }
