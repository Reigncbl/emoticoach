import os
import re
import json
import uuid
import asyncio
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
API_ID = os.getenv('api_id')
API_HASH = os.getenv('api_hash')
SESSION_DIR = "sessions"
os.makedirs(SESSION_DIR, exist_ok=True)

active_clients: Dict[str, TelegramClient] = {}
user_cache: Dict[str, str] = {}  # phone_number -> firebase_uid cache

def get_client(phone: str) -> TelegramClient:
    # Use SESSION_DIR for storing session files
    normalized_phone = phone.replace('+', '').replace('-', '').replace(' ', '')
    session_file = os.path.join(SESSION_DIR, normalized_phone)
    
    if normalized_phone in active_clients:
        return active_clients[normalized_phone]
    
    # Create new client with session file in SESSION_DIR
    client = TelegramClient(session_file, API_ID, API_HASH)
    active_clients[normalized_phone] = client
    return client

async def start_auth_session(phone_number: str):
    client = get_client(phone_number)
    await client.connect()
    try:
        await client.send_code_request(phone_number)
    except PhoneNumberBannedError:
        raise ValueError("Phone number is banned.")

async def verify_auth_code(phone_number: str, code: str = None, password: str = None, firebase_user_id: str = None):
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

async def save_phone_user_mapping(firebase_uid:str, phone_number: str, first_name: str):
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

async def is_user_authenticated(phone_number: str) -> dict:
    client = get_client(phone_number)
    await client.connect()
    
    if await client.is_user_authorized():
        me = await client.get_me()
        return {"authenticated": True, "user": getattr(me, 'first_name', 'Unknown')}
    
    return {"authenticated": False}

async def get_user_contacts(phone_number: str ) -> list:
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
    # Check cache first
    if phone_number in user_cache:
        return user_cache[phone_number]
        
    try:
        with Session(engine) as session:
            from model.userinfo import UserInfo
            
            stmt = select(UserInfo).where(UserInfo.MobileNumber == phone_number)
            user = session.exec(stmt).first()
            if user and user.UserId:
                # Cache the result before returning
                user_cache[phone_number] = user.UserId
                return user.UserId
            return None
    except Exception as e:
        print(f"Error finding user: {e}")
        return None

async def save_messages_to_db(messages: list, phone_number: str, embeddings: list, emotion_outputs: list):
    """
    Save messages to DB with semantic + emotion embeddings and interpretations.
    - embeddings: semantic embeddings (np.array, dim=1024)
    - emotion_outputs: list of dicts {"vector": [...], "labels": {...}, "top": "joy", "interpretation": "..."}
    """
    try:
        firebase_user_id = await find_firebase_user_by_phone(phone_number)
        if not firebase_user_id:
            print(f"No Firebase user found for phone {phone_number}, skipping database save")
            return []

        message_ids = []
        with Session(engine) as session:
            for msg_data, sem_embed, emo_out in zip(messages, embeddings, emotion_outputs):
                # Debug print to check what we're getting
                print(f"DEBUG - sem_embed type: {type(sem_embed)}, value: {sem_embed}")
                print(f"DEBUG - emo_out type: {type(emo_out)}, value: {emo_out}")
                
                # Ensure we have valid numeric embeddings
                if isinstance(sem_embed, (list, tuple)) and all(isinstance(x, str) for x in sem_embed):
                    print(f"ERROR - Semantic embedding contains strings: {sem_embed}")
                    # Skip this message or create a default embedding
                    sem_vector = [0.0] * 1024  # Default embedding
                else:
                    # Convert embeddings to lists for pgvector
                    sem_vector = sem_embed.tolist() if hasattr(sem_embed, "tolist") else list(sem_embed)
                
                # Validate emotion output structure
                if not isinstance(emo_out, dict) or "vector" not in emo_out:
                    print(f"ERROR - Invalid emotion output: {emo_out}")
                    emo_vector = [0.0] * 7
                    emo_labels = {"joy": 0.0, "sadness": 0.0, "anger": 0.0, "fear": 0.0, "surprise": 0.0, "disgust": 0.0, "neutral": 1.0}
                    top_emotion = "neutral"
                    interpretation_text = "Unable to analyze emotion for this message."
                else:
                    emo_vector = emo_out["vector"]
                    emo_labels = emo_out["labels"]
                    top_emotion = emo_out["top"]
                    interpretation_text = emo_out.get("interpretation", "No interpretation available.")
                    
                    # Log translation info if available
                    if emo_out.get("processed_text") and emo_out["processed_text"] != emo_out["original_text"]:
                        print(f"Message translated: '{emo_out['original_text']}' -> '{emo_out['processed_text']}'")

                # Parse the ISO format string back to datetime
                try:
                    sent_time = datetime.fromisoformat(msg_data["date"])
                except Exception as e:
                    print(f"Error parsing date: {e}, using current time")
                    sent_time = datetime.utcnow()

                message_id = str(uuid.uuid4())
                message = Message(
                   MessageId=message_id,
                    UserId=firebase_user_id,
                    Sender=msg_data["from"],
                    Receiver=msg_data["to"],
                    DateSent=sent_time,
                    MessageContent=msg_data["text"],
                    Semantic_Embedding=sem_vector,
                    Emotion_Embedding=emo_vector,
                    Emotion_labels=emo_labels,
                    Detected_emotion=top_emotion,
                    Interpretation=interpretation_text  # Now includes the interpretation
                )
                session.add(message)
                message_ids.append(message_id)

            # Commit once for efficiency
            session.commit()
            return message_ids

    except Exception as e:
        print(f"Error saving messages to database: {e}")
        return []

def get_conversation_context(sender: str, receiver: str, limit: int ) -> str:
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

async def get_contact_messages(phone_number: str , contact_data: dict = None) -> dict:
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
    message_texts = []
    
    # First, collect all messages
    async for msg in client.iter_messages(user.id, limit=10):
        if not msg.text:
            continue
            
        sender = me.first_name if msg.out else user.first_name
        receiver = user.first_name if msg.out else me.first_name
        
        # Telethon msg.date is already a datetime object with timezone info
        message_data = {
            "from": sender,
            "to": receiver,
            "date": msg.date.isoformat(),  # Convert to ISO format string for JSON
            "text": msg.text
        }
        messages.append(message_data)
        message_texts.append(msg.text)
        
    # Batch process embeddings
    message_ids = []
    if message_texts:
        try:
            # Create embeddings in batch - FIXED: Ensure this returns actual numeric vectors
            print(f"DEBUG - Creating embeddings for {len(message_texts)} messages")
            embedding_vectors = []
            for text in message_texts:
                try:
                    embed = rag._embed(text)  # This now returns numpy array
                    print(f"DEBUG - Embedding type for '{text[:50]}...': {type(embed)}")
                    embedding_vectors.append(embed)
                except Exception as e:
                    print(f"ERROR - Failed to create embedding for text '{text[:50]}...': {e}")
                    # Create a default embedding vector
                    embedding_vectors.append([0.0] * 1024)
            
            # Create emotion outputs using the new method with interpretations
            emotion_outputs = []
            for text in message_texts:
                try:
                    # Get emotion data from RAG pipeline
                    emotion_data = rag.get_emotion_data(text)
                    
                    # Generate interpretation using the emotion pipeline
                    from services.emotion_pipeline import analyze_emotion, interpretation
                    emotion_analysis = analyze_emotion(text)
                    
                    if emotion_analysis.get("pipeline_success"):
                        interpretation_text = interpretation(emotion_analysis)
                        emotion_data["interpretation"] = interpretation_text
                        print(f"Generated interpretation for '{text[:30]}...': {interpretation_text[:100]}...")
                    else:
                        emotion_data["interpretation"] = "Failed to analyze emotion for this message."
                    
                    emotion_outputs.append(emotion_data)
                except Exception as e:
                    print(f"ERROR - Failed to create emotion data for text '{text[:50]}...': {e}")
                    emotion_result = {
                        "vector": [0.0] * 7,  # 7-dimensional emotion vector
                        "labels": {
                            "joy": 0.0, "sadness": 0.0, "anger": 0.0,
                            "fear": 0.0, "surprise": 0.0, "disgust": 0.0,
                            "neutral": 1.0
                        },
                        "top": "neutral",
                        "interpretation": "Unable to analyze emotion for this message."
                    }
                    emotion_outputs.append(emotion_result)
            
            print(f"DEBUG - Created {len(embedding_vectors)} embeddings and {len(emotion_outputs)} emotion outputs with interpretations")
            
            # Save messages with embeddings, emotion data, and interpretations
            message_ids = await save_messages_to_db(messages, phone_number, embedding_vectors, emotion_outputs)
            print(f"DEBUG - Saved {len(message_ids)} messages to database with interpretations")
            
            # Add to RAG system in batch only if save was successful
            if message_ids:
                rag_documents = []
                for i, (msg, embedding) in enumerate(zip(messages, embedding_vectors)):
                    try:
                        msg_id = message_ids[i]  # Use the actual saved message ID
                        metadata = {
                            "sender": msg["from"],
                            "receiver": msg["to"],
                            "date": msg["date"],
                            "message_id": msg_id
                        }
                        rag_documents.append((message_texts[i], metadata))
                    except IndexError:
                        print(f"Warning: No message_id for index {i}")
                        continue
                        
                # Bulk add to RAG system
                for doc, metadata in rag_documents:
                    rag.add_document(doc, metadata=metadata)
                    
        except Exception as e:
            print(f"ERROR - Failed to process embeddings: {e}")
            # Continue without embeddings if there's an error
        
    # Get conversation context for RAG
    conversation_context = get_conversation_context(me.first_name, user.first_name, 50)
    
    response = {
        "sender": me.first_name,
        "receiver": user.first_name,
        "messages": messages,
        "conversation_context": conversation_context,
        "saved_message_ids": message_ids
    }
    
    # Save to file in background (don't await)
    async def save_to_file():
        try:
            os.makedirs("saved_messages", exist_ok=True)
            filename = f"saved_messages/{user.id}_{re.sub(r'[^a-zA-Z0-9_-]', '_', user.first_name)}.json"
            with open(filename, "w", encoding="utf-8") as f:
                json.dump(response, f, indent=2)
        except Exception as e:
            print(f"Error saving to file: {e}")
            
    asyncio.create_task(save_to_file())
    
    return response

async def embed_messages(messages: list, metadata: dict = None):
    """Add messages to the RAG system with embeddings"""
    for message in messages:
        if isinstance(message, dict) and 'text' in message and message['text']:
            # Create embedding and add to RAG system
            msg_metadata = metadata.copy() if metadata else {}
            msg_metadata.update({
                "sender": message.get('from', 'Unknown'),
                "receiver": message.get('to', 'Unknown'),
                "date": message.get('date', str(datetime.now())),
                "message_id": str(uuid.uuid4())
            })
            rag.add_document(message['text'], metadata=msg_metadata)

# New helper function to get messages with interpretations
async def get_messages_with_interpretations(user_id: str, limit: int = 50) -> list:
    """
    Retrieve messages with their emotion interpretations from the database.
    
    Args:
        user_id: Firebase user ID
        limit: Maximum number of messages to retrieve
        
    Returns:
        List of message dictionaries with interpretations
    """
    try:
        with Session(engine) as session:
            messages = session.exec(
                select(Message)
                .where(Message.UserId == user_id)
                .order_by(Message.DateSent.desc())
                .limit(limit)
            ).all()
            
            result = []
            for msg in messages:
                result.append({
                    "message_id": msg.MessageId,
                    "sender": msg.Sender,
                    "receiver": msg.Receiver,
                    "date_sent": msg.DateSent.isoformat(),
                    "content": msg.MessageContent,
                    "detected_emotion": msg.Detected_emotion,
                    "emotion_labels": msg.Emotion_labels,
                    "interpretation": msg.Interpretation
                })
            
            return result
    except Exception as e:
        print(f"Error retrieving messages with interpretations: {e}")
        return []