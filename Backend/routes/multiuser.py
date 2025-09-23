
from fastapi import APIRouter, Depends, HTTPException
from sqlmodel import Session, select
from telethon import TelegramClient
from telethon.sessions import StringSession
from telethon.errors import SessionPasswordNeededError
from core.db_connection import get_db
from model.telegram_sessions import TelegramSession
from telethon.tl.functions.contacts import ImportContactsRequest, GetContactsRequest
from telethon.tl.functions.messages import GetHistoryRequest
from pydantic import BaseModel

from services.messages_services import get_contact_messages_by_id

import os

multiuser_router = APIRouter(prefix="/telegram", tags=["Telegram"])

API_ID = int(os.getenv("api_id"))
API_HASH = os.getenv("api_hash")

class ContactRequest(BaseModel):
    contact_id: int  # Telegram user ID of the contact

# -----------------------------------------------------
# Step 1: Request OTP
# -----------------------------------------------------
@multiuser_router.post("/request_code")
async def request_code(user_id: str, phone_number: str, db: Session = Depends(get_db)):
    client = TelegramClient(StringSession(), API_ID, API_HASH)
    await client.connect()
    try:
        sent = await client.send_code_request(phone_number)

        # save in DB
        stmt = select(TelegramSession).where(TelegramSession.user_id == user_id)
        existing = db.exec(stmt).first()

        if not existing:
            session = TelegramSession(
                user_id=user_id,
                phone_number=phone_number,
                session_data=client.session.save(),
                phone_code_hash=sent.phone_code_hash,
            )
            db.add(session)
        else:
            existing.phone_number = phone_number
            existing.session_data = client.session.save()
            existing.phone_code_hash = sent.phone_code_hash

        db.commit()
        return {"message": "OTP sent", "phone_number": phone_number}
    finally:
        await client.disconnect()


# -----------------------------------------------------
# Step 2: Verify OTP
# -----------------------------------------------------
@multiuser_router.post("/verify_code")
async def verify_code(user_id: str, code: str, db: Session = Depends(get_db)):
    stmt = select(TelegramSession).where(TelegramSession.user_id == user_id)
    db_session = db.exec(stmt).first()

    if not db_session or not db_session.session_data or not db_session.phone_code_hash:
        raise HTTPException(status_code=400, detail="No pending verification found")

    client = TelegramClient(StringSession(db_session.session_data), API_ID, API_HASH)
    await client.connect()
    try:
        user = await client.sign_in(
            phone=db_session.phone_number,
            code=code,
            phone_code_hash=db_session.phone_code_hash,
        )

        # save logged-in session
        db_session.session_data = client.session.save()
        db_session.phone_code_hash = None  # clear after successful login
        db.commit()
        db.refresh(db_session)

        return {"message": "Login successful", "user_id": user.id}
    except SessionPasswordNeededError:
        return {"password_required": True}
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Failed verification/login: {e}")
    finally:
        await client.disconnect()


# -----------------------------------------------------
# Step 3: Use saved session
# -----------------------------------------------------
@multiuser_router.get("/me")
async def get_me(user_id: str, db: Session = Depends(get_db)):
    stmt = select(TelegramSession).where(TelegramSession.user_id == user_id)
    db_session = db.exec(stmt).first()

    if not db_session or not db_session.session_data:
        raise HTTPException(status_code=404, detail="Session not found or not verified")

    client = TelegramClient(StringSession(db_session.session_data), API_ID, API_HASH)
    await client.connect()

    try:
        me = await client.get_me()
        return {"id": me.id, "username": me.username, "phone": me.phone}
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Error fetching user: {e}")
    finally:
        await client.disconnect()


@multiuser_router.get("/contacts")
async def get_contacts(user_id: str, db: Session = Depends(get_db)):
    stmt = select(TelegramSession).where(TelegramSession.user_id == user_id)
    db_session = db.exec(stmt).first()

    if not db_session or not db_session.session_data:
        raise HTTPException(status_code=404, detail="Session not found or not verified")

    client = TelegramClient(StringSession(db_session.session_data), API_ID, API_HASH)
    await client.connect()

    try:
        result = await client(GetContactsRequest(hash=0))
        contacts = [
            {
                "id": user.id,
                "first_name": user.first_name,
                "last_name": user.last_name,
                "phone": user.phone,
                "username": user.username,
            }
            for user in result.users
        ]
        return {"contacts": contacts, "total": len(contacts)}
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Error fetching contacts: {e}")
    finally:
        await client.disconnect()


# Refactored endpoint: Get last 10 messages from a contact using contact_id (for multiuser setup)
@multiuser_router.post("/contact_messages")
async def get_contact_messages_multiuser(user_id: str, contact_id: int, db: Session = Depends(get_db)):
    """Gets the last 10 messages from a contact using contact_id, ready for emotion analysis integration."""
    stmt = select(TelegramSession).where(TelegramSession.user_id == user_id)
    db_session = db.exec(stmt).first()

    if not db_session or not db_session.session_data:
        raise HTTPException(status_code=404, detail="Session not found or not verified")

    client = TelegramClient(StringSession(db_session.session_data), API_ID, API_HASH)
    await client.connect()

    try:
        me = await client.get_me()
        receiver = await client.get_entity(contact_id)

        history = await client(GetHistoryRequest(
            peer=contact_id,
            limit=10,
            offset_date=None,
            offset_id=0,
            max_id=0,
            min_id=0,
            add_offset=0,
            hash=0
        ))

        messages = []
        message_texts = []
        for m in history.messages:
            if not m.message:
                continue
            msg_entry = {
                "id": m.id,
                "from": me.first_name if getattr(m.from_id, "user_id", None) == me.id else receiver.first_name,
                "to": receiver.first_name if getattr(m.from_id, "user_id", None) == me.id else me.first_name,
                "date": m.date.isoformat(),
                "text": m.message
            }
            messages.append(msg_entry)
            message_texts.append(m.message)

        # Placeholder for emotion analysis or RAG integration
        # You can call your emotion analysis or RAG pipeline here using message_texts

        conversation_context = f"Conversation between {me.first_name} and {receiver.first_name}"

        return {
            "sender": me.first_name,
            "receiver": receiver.first_name,
            "messages": messages,
            "conversation_context": conversation_context,
            "saved_message_ids": [m["id"] for m in messages]
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error fetching messages: {e}")
    finally:
        await client.disconnect()


# Endpoint: Get last 10 messages from a contact_id with embedding and emotion analysis
@multiuser_router.post("/contact_messages_embed")
async def get_contact_messages_embed(user_id: str, contact_id: int, db: Session = Depends(get_db)):
    """Gets the last 10 messages from a contact (by contact_id), creates semantic and emotion embeddings, saves to DB, and returns results."""
    try:
        result = await get_contact_messages_by_id(user_id, contact_id, db)
        return result
    except PermissionError as e:
        raise HTTPException(status_code=401, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"An unexpected error occurred: {e}")