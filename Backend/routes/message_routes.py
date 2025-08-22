import os
import json
import re
from typing import Optional
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from telethon import TelegramClient
from telethon.tl.functions.contacts import ImportContactsRequest, GetContactsRequest
from telethon.tl.types import InputPhoneContact
from telethon.errors import PhoneNumberBannedError, SessionPasswordNeededError, PhoneCodeInvalidError
from dotenv import load_dotenv

load_dotenv()

message_router = APIRouter()

# Config
API_ID = os.getenv('api_id')
API_HASH = os.getenv('api_hash')
SESSION_NAME = 'telegram_session'

# Models
class ContactRequest(BaseModel):
    phone: str
    first_name: str = ""
    last_name: str = ""

class AuthRequest(BaseModel):
    phone_number: str
    
class CodeRequest(BaseModel):
    phone_number: str
    code: str
    password: Optional[str] = None

def get_client() -> TelegramClient:
    return TelegramClient(SESSION_NAME, API_ID, API_HASH)

@message_router.get("/status")
async def get_status():
    """Check if authenticated"""
    try:
        async with get_client() as client:
            if await client.is_user_authorized():
                me = await client.get_me()
                return {"authenticated": True, "user": me.first_name}
            return {"authenticated": False}
    except Exception as e:
        return {"error": str(e)}

@message_router.post("/auth/start")
async def start_auth(data: AuthRequest):
    """Send verification code"""
    try:
        async with get_client() as client:
            await client.send_code_request(data.phone_number)
            return {"message": "Code sent"}
    except PhoneNumberBannedError:
        raise HTTPException(400, "Phone number banned")
    except Exception as e:
        raise HTTPException(500, str(e))

@message_router.post("/auth/verify")
async def verify_code(data: CodeRequest):
    """Verify code and login"""
    try:
        async with get_client() as client:
            await client.sign_in(data.phone_number, data.code, password=data.password)
            return {"message": "Authenticated"}
    except SessionPasswordNeededError:
        return {"password_required": True}
    except PhoneCodeInvalidError:
        raise HTTPException(400, "Invalid code")
    except Exception as e:
        raise HTTPException(500, str(e))

@message_router.get("/contacts")
async def get_contacts():
    """Get list of user contacts"""
    try:
        async with get_client() as client:
            if not await client.is_user_authorized():
                raise HTTPException(401, "Not authenticated")
            
            # Use GetContactsRequest to get contacts
            result = await client(GetContactsRequest(hash=0))
            contacts = []
            
            # Check if we have contacts
            if hasattr(result, 'users'):
                for user in result.users:
                    contacts.append({
                        "id": user.id,
                        "name": f"{user.first_name or ''} {user.last_name or ''}".strip(),
                        "username": getattr(user, 'username', None),
                        "phone": getattr(user, 'phone', None),
                        "is_contact": True,
                        "is_mutual_contact": getattr(user, 'mutual_contact', False),
                        "status": str(type(user.status).__name__) if hasattr(user, 'status') else None
                    })
            
            return {
                "contacts": contacts,
                "total": len(contacts)
            }
            
    except Exception as e:
        raise HTTPException(500, str(e))

@message_router.post("/messages")
async def get_messages(data: ContactRequest):
    """Get messages from contact"""
    try:
        async with get_client() as client:
            if not await client.is_user_authorized():
                raise HTTPException(401, "Not authenticated")
            
            # Import contact
            contact = InputPhoneContact(0, f'+63{data.phone}', data.first_name, data.last_name)
            result = await client(ImportContactsRequest([contact]))
            
            if not result.users:
                return {"error": "User not found"}

            user = result.users[0]
            me = await client.get_me()
            
            # Get messages
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
            filename = f"saved_messages/{re.sub(r'[^a-zA-Z0-9_-]', '_', user.first_name)}.json"
            
            response = {
                "sender": me.first_name,
                "receiver": user.first_name,
                "messages": messages
            }
            
            with open(filename, "w", encoding="utf-8") as f:
                json.dump(response, f, indent=2)

            return response
            
    except Exception as e:
        raise HTTPException(500, str(e))

@message_router.delete("/session")
async def clear_session():
    """Clear session files"""
    try:
        files = [f"{SESSION_NAME}.session", f"{SESSION_NAME}.session-journal"]
        removed = [f for f in files if os.path.exists(f) and not os.remove(f)]
        return {"cleared": True, "files": removed}
    except Exception as e:
        raise HTTPException(500, str(e))