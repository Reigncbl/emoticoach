# backend/routers/telegram_router.py
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from services import messages_services as telegram_svc

message_router = APIRouter()

class ContactRequest(BaseModel):
    phone: str
    first_name: str = ""
    last_name: str = ""

class AuthRequest(BaseModel):
    phone_number: str = "639063450469"

DEFAULT_PHONE = AuthRequest().phone_number

class CodeRequest(BaseModel):
    phone_number: str = DEFAULT_PHONE
    code: str
    password: str = None
    firebase_user_id: str = None  # Add Firebase user ID field

@message_router.post("/auth/start")
async def start_auth(data: AuthRequest):
    try:
        await telegram_svc.start_auth_session(data.phone_number)
        return {"message": "Code sent"}
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))

@message_router.post("/auth/verify")
async def verify_code(data: CodeRequest):
    try:
        result = await telegram_svc.verify_auth_code(
            data.phone_number, 
            data.code, 
            data.password, 
            data.firebase_user_id  # Pass Firebase user ID
        )
        if "password_required" in result: 
            return {"password_required": True}
        return {"message": f"Authenticated as {result['first_name']}", "user_id": result['user_id']}
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))

@message_router.get("/status")
async def get_status(phone_number: str = DEFAULT_PHONE):
    try:
        return await telegram_svc.is_user_authenticated(phone_number)
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@message_router.get("/contacts")
async def get_contacts(phone_number: str = DEFAULT_PHONE):
    try:
        contacts = await telegram_svc.get_user_contacts(phone_number)
        return {"contacts": contacts, "total": len(contacts)}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@message_router.post("/messages")
async def get_messages(data: ContactRequest, phone_number: str = DEFAULT_PHONE):
    try:
        messages = await telegram_svc.get_contact_messages(phone_number, data.dict())
        return {
            **messages,
            "database_saved": True,  # Indicates messages were saved to DB
            "rag_embedded": True     # Indicates messages were embedded in RAG
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))