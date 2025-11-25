# Endpoint: Fetch, analyze, and save the latest message from Telethon using contact_id
from pydantic import BaseModel

from services.messages_services import append_latest_contact_message

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

from services.messages_services import (
    get_contact_messages_by_id,
    get_latest_message_from_db,
)
from services.cache import MessageCache

import os

multiuser_router = APIRouter(prefix="/telegram", tags=["Telegram"])

API_ID = int(os.getenv("api_id"))
API_HASH = os.getenv("api_hash")

# Unified request models for easier input
from fastapi import Query, Body

class AppendLatestContactMessageRequest(BaseModel):
    user_id: str = Query(..., description="User ID")
    contact_id: int = Query(..., description="Contact ID")




class ContactRequest(BaseModel):
    user_id: str = Query(..., description="User ID")
    contact_id: int = Query(..., description="Contact ID")

# -----------------------------------------------------
# Step 1: Request OTP
# -----------------------------------------------------
@multiuser_router.post("/request_code")
async def request_code(
    user_id: str = Query(None),
    phone_number: str = Query(None),
    data: dict = Body(None),
    db: Session = Depends(get_db)
):
    # Prefer body if provided
    if data:
        user_id = data.get("user_id", user_id)
        phone_number = data.get("phone_number", phone_number)
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
async def verify_code(
    user_id: str = Query(None),
    code: str = Query(None),
    data: dict = Body(None),
    db: Session = Depends(get_db)
):
    if data:
        user_id = data.get("user_id", user_id)
        code = data.get("code", code)
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

        # save logged-in session and Telegram username
        db_session.session_data = client.session.save()
        db_session.phone_code_hash = None  # clear after successful login
        # Fetch Telegram username
        telegram_user = await client.get_me()
        db_session.telegram_username = telegram_user.username if hasattr(telegram_user, "username") else None
        db.commit()
        db.refresh(db_session)

        return {"message": "Login successful", "user_id": user.id, "telegram_username": db_session.telegram_username}
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
async def get_me(user_id: str = Query(...), db: Session = Depends(get_db)):
    # Check cache first with specific key for /me endpoint
    cache_key_me = f"telegram_me:{user_id}"
    try:
        from services.cache import r
        import json
        cached_me = r.get(cache_key_me)
        if cached_me:
            print(f"✅ Cache hit for /me endpoint user {user_id}")
            return json.loads(cached_me)
    except Exception as e:
        print(f"Cache read error: {e}")
    
    stmt = select(TelegramSession).where(TelegramSession.user_id == user_id)
    db_session = db.exec(stmt).first()

    if not db_session or not db_session.session_data:
        raise HTTPException(status_code=404, detail="Session not found or not verified")

    client = TelegramClient(StringSession(db_session.session_data), API_ID, API_HASH)
    await client.connect()

    try:
        me = await client.get_me()
        user_data = {"id": user_id, "username": me.username, "phone": me.phone}
        
        # Cache the user data with specific key for /me endpoint
        try:
            import json
            r.setex(cache_key_me, 1200, json.dumps(user_data))  # 20 minutes TTL
            print(f"💾 Cached /me endpoint data for {user_id}")
        except Exception as e:
            print(f"Cache write error: {e}")
        
        return user_data
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Error fetching user: {e}")
    finally:
        await client.disconnect()


@multiuser_router.get("/contacts")
async def get_contacts(user_id: str = Query(...), db: Session = Depends(get_db)):
    # Check cache first
    cache_key = f"contacts_list:{user_id}"
    try:
        from services.cache import r
        cached_contacts = r.get(cache_key)
        if cached_contacts:
            import json
            print(f"✅ Cache hit for contacts list of user {user_id}")
            return json.loads(cached_contacts)
    except Exception as e:
        print(f"Cache read error: {e}")
    
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
        response = {"contacts": contacts, "total": len(contacts)}
        
        # Cache the contacts list for 10 minutes
        try:
            import json
            r.setex(cache_key, 600, json.dumps(response))
            print(f"💾 Cached contacts list for user {user_id}")
        except Exception as e:
            print(f"Cache write error: {e}")
        
        return response
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Error fetching contacts: {e}")
    finally:
        await client.disconnect()


# Refactored endpoint: Get last 3 messages from a contact using contact_id (for multiuser setup)
@multiuser_router.post("/contact_messages")
async def get_contact_messages_multiuser(
    user_id: str = Query(None),
    contact_id: int = Query(None),
    data: dict = Body(None),
    db: Session = Depends(get_db)
):
    if data:
        user_id = data.get("user_id", user_id)
        contact_id = data.get("contact_id", contact_id)
    """Gets the last 3 messages from a contact using contact_id, ready for emotion analysis integration."""
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
            limit=3,
            offset_date=None,
            offset_id=0,
            max_id=0,
            min_id=0,
            add_offset=0,
            hash=0
        ))

        messages = []
        message_texts = []
        # ensure we only handle up to 3 messages, in case Telethon returns more than requested
        history_messages = list(history.messages)[:3]
        for m in history_messages:
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


# Endpoint: Get last 3 messages from a contact_id with embedding and emotion analysis
@multiuser_router.post("/contact_messages_embed")
async def get_contact_messages_embed(
    user_id: str = Query(None),
    contact_id: int = Query(None),
    data: dict = Body(None),
    db: Session = Depends(get_db)
):
    if data:
        user_id = data.get("user_id", user_id)
        contact_id = data.get("contact_id", contact_id)
    """Gets the last 3 messages from a contact (by contact_id), creates semantic and emotion embeddings, saves to DB, and returns results. Includes contact_id in the response."""
    
    # Check cache first
    cached_conversation = MessageCache.get_cached_conversation(user_id, contact_id)
    if cached_conversation:
        print(f"✅ Cache hit for conversation {user_id}:{contact_id}")
        # Format the cached data to match expected response
        result = {
            "messages": cached_conversation,
            "contact_id": contact_id
        }
        for msg in result["messages"]:
            msg["contact_id"] = contact_id
        return result
    
    try:
        result = await get_contact_messages_by_id(user_id, contact_id, db)
        
        # Add contact_id to each message and to the response
        if "messages" in result:
            for msg in result["messages"]:
                msg["contact_id"] = contact_id
            result["contact_id"] = contact_id
            
            # Cache the conversation messages
            MessageCache.cache_conversation_messages(user_id, contact_id, result["messages"])
            print(f"💾 Cached conversation for {user_id}:{contact_id}")
        
        return result
    except PermissionError as e:
        raise HTTPException(status_code=401, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"An unexpected error occurred: {e}")
    
@multiuser_router.post("/append_latest_contact_message")
async def append_latest_contact_message_multiuser(data: AppendLatestContactMessageRequest, db: Session = Depends(get_db)):
    """Fetches the latest message from Telethon for the contact, analyzes it, saves to DB, and returns the analyzed message."""
    from services.messages_services import append_latest_contact_message
    try:
        analyzed_message = await append_latest_contact_message(
            user_id=data.user_id,
            contact_id=data.contact_id,
            db=db
        )
        
        # Note: Cache management is handled within append_latest_contact_message
        # - Latest message is cached
        # - Conversation cache is invalidated
        
        return analyzed_message
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to append and analyze latest contact message: {e}")


@multiuser_router.get("/latest_contact_message")
async def get_latest_contact_message(
    user_id: str = Query(..., description="User ID"),
    contact_id: int = Query(..., description="Contact ID"),
    db: Session = Depends(get_db),
):
    """Retrieve the latest stored message for a user/contact pair from the database."""
    try:
        # Check cache first
        cached_latest = MessageCache.get_cached_latest_message(user_id, contact_id)
        if cached_latest:
            print(f"✅ Cache hit for latest message {user_id}:{contact_id}")
            return cached_latest
        
        # If not in cache, fetch from database
        latest_message = await get_latest_message_from_db(user_id, contact_id, db)
        if not latest_message:
            raise HTTPException(status_code=404, detail="No messages found for this contact")
        
        # Cache the result
        MessageCache.cache_latest_message(user_id, contact_id, latest_message)
        print(f"💾 Cached latest message for {user_id}:{contact_id}")
        
        return latest_message
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to fetch latest message: {e}")