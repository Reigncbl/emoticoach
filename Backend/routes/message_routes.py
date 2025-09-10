
# backend/routers/telegram_router.py
import json
from typing import Optional
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel

# Import the service functions
from services import messages_services as telegram_svc
from services.emotion_pipeline import analyze_emotion, get_pipeline

message_router = APIRouter()


class ContactRequest(BaseModel):
    phone: str
    first_name: str = ""
    last_name: str = ""

class AuthRequest(BaseModel):
    phone_number: str = "639063450469"

# Default phone number from AuthRequest
DEFAULT_PHONE = AuthRequest().phone_number
    
class CodeRequest(BaseModel):
    phone_number: str = DEFAULT_PHONE
    code: str
    password: Optional[str] = None


@message_router.post("/auth/start")
async def start_auth(data: AuthRequest):
    """Sends a verification code to the user's Telegram."""
    try:
        await telegram_svc.start_auth_session(data.phone_number)
        return {"message": "Code sent"}
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"An unexpected error occurred: {e}")

@message_router.post("/auth/verify")
async def verify_code(data: CodeRequest):
    """Verifies the code and logs the user in."""
    try:
        result = await telegram_svc.verify_auth_code(
            data.phone_number, data.code, data.password
        )
        if "password_required" in result:
            return {"password_required": True}
        return {"message": f"Authenticated as {result['first_name']}", "user_id": result['user_id']}
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"An unexpected error occurred: {e}")

@message_router.get("/status")
async def get_status(phone_number: str = DEFAULT_PHONE):
    """Checks the user's authentication status."""
    try:
        return await telegram_svc.is_user_authenticated(phone_number)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"An unexpected error occurred: {e}")

@message_router.get("/contacts")
async def get_contacts(phone_number: str = DEFAULT_PHONE):
    """Gets the list of user contacts."""
    try:
        contacts = await telegram_svc.get_user_contacts(phone_number)
        return {"contacts": contacts, "total": len(contacts)}
    except PermissionError as e:
        raise HTTPException(status_code=401, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"An unexpected error occurred: {e}")

@message_router.post("/messages")
async def get_messages(data: ContactRequest, phone_number: str = DEFAULT_PHONE):
    """Gets the last 10 messages from a contact."""
    try:
        messages = await telegram_svc.get_contact_messages(
            phone_number, data.dict()
        )
        return messages
    except PermissionError as e:
        raise HTTPException(status_code=401, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"An unexpected error occurred: {e}")

