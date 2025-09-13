# backend/services/telegram_service.py
import os
import re
import json
import uuid
from typing import Dict
from datetime import datetime, date
from telethon import TelegramClient
from telethon.tl.functions.contacts import ImportContactsRequest, GetContactsRequest
from telethon.tl.types import InputPhoneContact
from telethon.errors import (
    PhoneNumberBannedError,
    SessionPasswordNeededError,
    PhoneCodeInvalidError,
)
from services.RAGPipeline import rag
from model.message import Message
from core.db_connection import engine
from sqlmodel import Session, select

# Config
API_ID = int(os.getenv('api_id'))
API_HASH = os.getenv('api_hash')
SESSION_DIR = "sessions"
os.makedirs(SESSION_DIR, exist_ok=True)

active_clients: Dict[str, TelegramClient] = {}

def get_client(phone: str) -> TelegramClient:
    specific_session_path = r"C:\Users\John Carlo\emoticoach\emoticoach\Backend\sessions\639063450469"
    normalized_phone = phone.replace('+', '').replace('-', '').replace(' ', '')
    
    if normalized_phone in active_clients:
        return active_clients[normalized_phone]
    
    client = TelegramClient(specific_session_path, API_ID, API_HASH)
    active_clients[normalized_phone] = client
    return client

async def start_auth_session(phone_number: str = "639063450469"):
    client = get_client(phone_number)
    await client.connect()
    try:
        await client.send_code_request(phone_number)
    except PhoneNumberBannedError:
        raise ValueError("Phone number is banned.")

async def verify_auth_code(phone_number: str = "639063450469", code: str = None, password: str = None, firebase_user_id: str = None):
    client = get_client(phone_number)
    await client.connect()
    try:
        user = await client.sign_in(phone_number, code, password=password)
        
        if firebase_user_id:
            await save_phone_user_mapping(firebase_user_id, phone_number, user.first_name)
        
        return {"user_id": user.id, "first_name": user.first_name}
    except SessionPasswordNeededError:
        return {"password_required": True}
    except PhoneCodeInvalidError:
        raise ValueError("Invalid code.")

async def save_phone_user_mapping(firebase_uid: str, phone_number: str, first_name: str):
    try:
        with Session(engine) as session:
            from model.userinfo import UserInfo
            user = session.get(UserInfo, firebase_uid)
            if user:
                user.MobileNumber = phone_number
            else:
                user = UserInfo(
                    UserId=firebase_uid,
                    FirstName=first_name,
                    LastName="",
                    MobileNumber=phone_number,
                    CreatedAt=date.today()
                )
                session.add(user)
            session.commit()
    except Exception as e:
        print(f"Error saving user mapping: {e}")

async def is_user_authenticated(phone_number: str = "639063450469") -> dict:
    client = get_client(phone_number)
    await client.connect()
    
    if await client.is_user_authorized():
        me = await client.get_me()
        return {"authenticated": True, "user": getattr(me, 'first_name', 'Unknown')}
    
    return {"authenticated": False}

async def get_user_contacts(phone_number: str = "639063450469") -> list:
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

async def find_firebase_user_by_phone(phone_number: str) -> str:
    try:
        with Session(engine) as session:
            from model.userinfo import UserInfo
            
            stmt = select(UserInfo).where(UserInfo.MobileNumber == phone_number)
            user = session.exec(stmt).first()
            return user.UserId if user else None
    except Exception as e:
        print(f"Error finding user: {e}")
        return None

async def save_message_to_db(message_data: dict, phone_number: str, msg_date: datetime, embedding: list = None):
    try:
        firebase_user_id = await find_firebase_user_by_phone(phone_number)
        if not firebase_user_id:
            print(f"No Firebase user found for phone {phone_number}, skipping database save")
            return None
            
        with Session(engine) as session:
            message_id = str(uuid.uuid4())
            message = Message(
                MessageId=message_id,
                UserId=firebase_user_id,
                Sender=message_data['from'],
                Receiver=message_data['to'],  # Fixed receiver logic
                DateSent=msg_date,  # Use actual message timestamp
                MessageContent=message_data['text'],
                Embedding=embedding
            )
            session.add(message)
            session.commit()
            return message_id
    except Exception as e:
        print(f"Error saving to database: {e}")
        return None

def get_conversation_context(sender: str, receiver: str, limit: int = 10) -> str:
    try:
        with Session(engine) as session:
            messages = session.exec(
                select(Message).where(
                    ((Message.Sender == sender) & (Message.Receiver == receiver)) |
                    ((Message.Sender == receiver) & (Message.Receiver == sender))
                ).order_by(Message.DateSent).limit(limit)  # Order by actual timestamp
            ).all()
            
            context = "\n".join([f"{msg.Sender}: {msg.MessageContent}" for msg in messages])
            return context
    except Exception as e:
        print(f"Error getting conversation context: {e}")
        return ""

async def get_contact_messages(phone_number: str = "639063450469", contact_data: dict = None) -> dict:
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
    message_ids = []
    
    async for msg in client.iter_messages(user.id, limit=10):
        sender = me.first_name if msg.out else user.first_name
        receiver = user.first_name if msg.out else me.first_name  # Fixed receiver logic
        
        message_data = {
            "from": sender,
            "to": receiver,
            "date": str(msg.date),
            "text": msg.text
        }
        messages.append(message_data)
        
        if msg.text:
            # Create embedding
            embedding_vector = rag._embed(msg.text)
            
            # Save to database with proper timestamp and embedding
            saved_message_id = await save_message_to_db(
                message_data=message_data,
                phone_number=phone_number,
                msg_date=msg.date,  # Use actual message timestamp
                embedding=embedding_vector.tolist() if hasattr(embedding_vector, 'tolist') else embedding_vector
            )
            if saved_message_id:
                message_ids.append(saved_message_id)
    
    # Get conversation context for RAG
    conversation_context = get_conversation_context(me.first_name, user.first_name)
    
    # Save to file
    os.makedirs("saved_messages", exist_ok=True)
    filename = f"saved_messages/{user.id}_{re.sub(r'[^a-zA-Z0-9_-]', '_', user.first_name)}.json"
    
    response = {
        "sender": me.first_name,
        "receiver": user.first_name,
        "messages": messages,
        "conversation_context": conversation_context,
        "saved_message_ids": message_ids
    }
    
    with open(filename, "w", encoding="utf-8") as f:
        json.dump(response, f, indent=2)

    return response

async def embed_messages(messages: list, metadata: dict = None):
    """Legacy function - now handled in save_message_to_db"""
    pass

def search_similar_messages(query: str, top_k: int = 5):
    return rag.search(query, top_k)

def generate_response_with_context(query: str, sender: str = None, receiver: str = None):
    if sender and receiver:
        context = get_conversation_context(sender, receiver)
        enhanced_query = f"Conversation context:\n{context}\n\nQuery: {query}"
        return rag.generate_response(enhanced_query)
    else:
        return rag.generate_response(query)