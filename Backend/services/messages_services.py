# backend/services/telegram_service.py
import os
import re
from typing import Dict
from telethon import TelegramClient
from telethon.tl.functions.contacts import ImportContactsRequest, GetContactsRequest
from telethon.tl.types import InputPhoneContact
from telethon.errors import (
    PhoneNumberBannedError,
    SessionPasswordNeededError,
    PhoneCodeInvalidError,
)

# Config
API_ID = int(os.getenv('api_id'))
API_HASH = os.getenv('api_hash')
SESSION_DIR = "sessions"
os.makedirs(SESSION_DIR, exist_ok=True)

# In-memory storage of active clients
active_clients: Dict[str, TelegramClient] = {}

def get_client(phone: str) -> TelegramClient:
    """Returns a TelegramClient for the given phone."""
    if phone in active_clients:
        return active_clients[phone]
    
    session_path = os.path.join(SESSION_DIR, phone)
    client = TelegramClient(session_path, API_ID, API_HASH)
    active_clients[phone] = client
    return client

async def start_auth_session(phone_number: str):
    """Sends a verification code to the user's Telegram."""
    try:
        client = get_client(phone_number)
        await client.connect()
        await client.send_code_request(phone_number)
    except PhoneNumberBannedError:
        raise ValueError("Phone number is banned.")

async def verify_auth_code(phone_number: str, code: str, password: str = None):
    """Verifies the code and signs the user in."""
    client = get_client(phone_number)
    await client.connect()
    try:
        user = await client.sign_in(phone_number, code, password=password)
        return {"user_id": user.id, "first_name": user.first_name}
    except SessionPasswordNeededError:
        return {"password_required": True}
    except PhoneCodeInvalidError:
        raise ValueError("Invalid code.")

async def is_user_authenticated(phone_number: str) -> dict:
    """Checks if the user is authenticated."""
    client = get_client(phone_number)
    await client.connect()
    if await client.is_user_authorized():
        me = await client.get_me()
        return {"authenticated": True, "user": me.first_name}
    return {"authenticated": False}

async def get_user_contacts(phone_number: str) -> list:
    """Fetches the list of user contacts."""
    client = get_client(phone_number)
    await client.connect()
    if not await client.is_user_authorized():
        raise PermissionError("User not authenticated.")

    result = await client(GetContactsRequest(hash=0))
    contacts = []
    if hasattr(result, 'users'):
        for user in result.users:
            contacts.append({
                "id": user.id,
                "name": f"{user.first_name or ''} {user.last_name or ''}".strip(),
                "username": getattr(user, 'username', None),
                "phone": getattr(user, 'phone', None),
            })
    return contacts

async def get_contact_messages(phone_number: str, contact_data: dict) -> dict:
    """Fetches the last 10 messages from a specific contact."""
    client = get_client(phone_number)
    await client.connect()
    if not await client.is_user_authorized():
        raise PermissionError("User not authenticated.")
    
    contact = InputPhoneContact(0, f'+63{contact_data["phone"]}', contact_data["first_name"], contact_data["last_name"])
    result = await client(ImportContactsRequest([contact]))
    
    if not result.users:
        return {"error": "User not found"}
        
    user = result.users[0]
    me = await client.get_me()
    
    messages = []
    async for msg in client.iter_messages(user.id, limit=10):
        sender = me.first_name if msg.out else user.first_name
        messages.append({
            "from": sender,
            "date": str(msg.date),
            "text": msg.text
        })
    
    # Save to file
    os.makedirs("saved_messages", exist_ok=True)
    filename = f"saved_messages/{user.id}_{re.sub(r'[^a-zA-Z0-9_-]', '_', user.first_name)}.json"
    
    response = {
        "sender": me.first_name,
        "receiver": user.first_name,
        "messages": messages
    }
    
    # In a real app, you might use a database instead of a file
    # with open(filename, "w", encoding="utf-8") as f:
    #     json.dump(response, f, indent=2)

    return response