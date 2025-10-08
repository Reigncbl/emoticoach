# Service function to fetch, analyze, and save the latest message from Telethon using contact_id


# New: Multiuser/contact_id version for embedding, emotion, and DB save

from http.client import HTTPException
import os
import re
import json
import uuid
import asyncio
from typing import Dict, Optional
from datetime import datetime, date
from telethon import TelegramClient
from telethon.tl.functions.contacts import ImportContactsRequest, GetContactsRequest
from telethon.tl.functions.messages import GetHistoryRequest
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
from model.telegram_sessions import TelegramSession
import http.client
from services.cache import MessageCache

from telethon.sessions import StringSession
# Config
API_ID = os.getenv('api_id')
API_HASH = os.getenv('api_hash')
SESSION_DIR = "sessions"
os.makedirs(SESSION_DIR, exist_ok=True)

active_clients: Dict[str, TelegramClient] = {}
user_cache: Dict[str, str] = {}  # phone_number -> firebase_uid cache
client_locks: Dict[str, asyncio.Lock] = {}  # Locks for thread-safe client access
cache_lock: asyncio.Lock = asyncio.Lock()  # Lock for user cache access

async def get_client(user_id: str, db: Session) -> TelegramClient:
    """
    Returns an active TelegramClient loaded from DB session_data.
    Caches it in memory for reuse. Thread-safe with per-user lock.
    """
    # Ensure lock exists
    if user_id not in client_locks:
        client_locks[user_id] = asyncio.Lock()

    async with client_locks[user_id]:
        if user_id in active_clients:
            return active_clients[user_id]

        # Look up DB session
        stmt = select(TelegramSession).where(TelegramSession.user_id == user_id)
        db_session = db.exec(stmt).first()

        if not db_session or not db_session.session_data:
            raise HTTPException(status_code=404, detail="No saved Telegram session found")

        # Create client from DB session
        client = TelegramClient(StringSession(db_session.session_data), API_ID, API_HASH)
        await client.connect()

        if not await client.is_user_authorized():
            await client.disconnect()
            raise HTTPException(status_code=401, detail="Session expired, please log in again")

        # Cache for reuse
        active_clients[user_id] = client
        return client
    
    
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
    client = await get_client(phone_number)
    await client.connect()
    
    if await client.is_user_authorized():
        me = await client.get_me()
        return {"authenticated": True, "user": getattr(me, 'first_name', 'Unknown')}
    
    return {"authenticated": False}


async def find_firebase_user_by_phone(phone_number: str) -> str:
    # Check cache first with lock
    async with cache_lock:
        if phone_number in user_cache:
            return user_cache[phone_number]
    
    try:
        with Session(engine) as session:
            from model.userinfo import UserInfo
            
            stmt = select(UserInfo).where(UserInfo.MobileNumber == phone_number)
            user = session.exec(stmt).first()
            if user and user.UserId:
                # Cache the result before returning with lock
                async with cache_lock:
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
        # Use user_id directly for saving messages
        firebase_user_id = phone_number  # phone_number param is now user_id
        from model.userinfo import UserInfo
        with Session(engine) as session:
            user = session.get(UserInfo, firebase_user_id)
            if not user:
                print(f"No UserInfo found for user_id {firebase_user_id}, skipping database save")
                return []

            message_ids = []


            for idx, msg_data in enumerate(messages):
                from model.message import Message
                try:
                    sent_time = datetime.fromisoformat(msg_data["date"])
                except Exception as e:
                    print(f"Error parsing date: {e}, using current time")
                    sent_time = datetime.utcnow()
                existing = session.exec(
                    select(Message)
                    .where((Message.UserId == firebase_user_id) &
                           (Message.Contact_id == msg_data.get("Contact_id")) &
                           (Message.MessageContent == msg_data["text"]) &
                           (Message.DateSent == sent_time))
                ).first()
                if existing:
                    print(f"Duplicate message detected, skipping embed/emotion: {msg_data['text']}")
                    message_ids.append(existing.MessageId)
                    continue

                # Only run embedding/emotion if not duplicate
                sem_embed = embeddings[idx]
                emo_out = emotion_outputs[idx]
                print(f"DEBUG - sem_embed type: {type(sem_embed)}, value: {sem_embed}")
                print(f"DEBUG - emo_out type: {type(emo_out)}, value: {emo_out}")
                if isinstance(sem_embed, (list, tuple)) and all(isinstance(x, str) for x in sem_embed):
                    print(f"ERROR - Semantic embedding contains strings: {sem_embed}")
                    sem_vector = [0.0] * 1024
                else:
                    sem_vector = sem_embed.tolist() if hasattr(sem_embed, "tolist") else list(sem_embed)
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
                    if emo_out.get("processed_text") and emo_out["processed_text"] != emo_out["original_text"]:
                        print(f"Message translated: '{emo_out['original_text']}' -> '{emo_out['processed_text']}'")

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
                    Interpretation=interpretation_text,
                    Contact_id=msg_data.get("Contact_id")
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
    client = await get_client(phone_number)
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
            
            
async def get_latest_message_from_db(user_id: str, contact_id: int, db: Optional[Session] = None) -> Optional[dict]:
    """Fetch the latest stored message for a user/contact pair from the database."""
    local_db = db is None
    if local_db:
        db = Session(engine)

    try:
        stmt = (
            select(Message)
            .where((Message.UserId == user_id) & (Message.Contact_id == contact_id))
            .order_by(Message.DateSent.desc())
            .limit(1)
        )
        latest_message: Optional[Message] = db.exec(stmt).first()

        if not latest_message:
            return None

        emotion_labels = latest_message.Emotion_labels
        if hasattr(emotion_labels, "items"):
            emotion_labels = dict(emotion_labels)

        embedding = latest_message.Emotion_Embedding
        if hasattr(embedding, "tolist"):
            embedding = embedding.tolist()

        return {
            "message_id": latest_message.MessageId,
            "sender": latest_message.Sender,
            "receiver": latest_message.Receiver,
            "date_sent": latest_message.DateSent.isoformat() if latest_message.DateSent else None,
            "content": latest_message.MessageContent,
            "detected_emotion": latest_message.Detected_emotion,
            "emotion_labels": emotion_labels,
            "emotion_embedding": embedding,
            "interpretation": latest_message.Interpretation,
            "contact_id": latest_message.Contact_id,
        }
    finally:
        if local_db and db:
            db.close()


async def append_latest_contact_message(user_id: str, contact_id: int, db: Session = None):
    """
    Fetches the latest message from Telethon for the contact, analyzes it, saves to DB, and returns the analyzed message.
    """
    local_db = db is None
    if local_db:
        db = Session(engine)
    try:
        client = await get_client(user_id, db)
        await client.connect()
        if not await client.is_user_authorized():
            raise PermissionError("User not authenticated.")

        me = await client.get_me()
        receiver = await client.get_entity(contact_id)

        # Find last saved message ID for this contact
        last_message_id = None
        with Session(engine) as session:
            from model.message import Message
            last_msg = session.exec(
                select(Message)
                .where((Message.UserId == user_id) & (Message.Contact_id == contact_id))
                .order_by(Message.DateSent.desc())
            ).first()
            if last_msg:
                last_message_id = last_msg.MessageId

        # Fetch all new messages after last_message_id
        history = await client(GetHistoryRequest(
            peer=contact_id,
            limit=20,
            offset_id=0,
            offset_date=None,
            max_id=0,
            min_id=0,
            add_offset=0,
            hash=0
        ))

        new_messages = []
        for m in history.messages:
            # Skip if already saved
            if last_message_id and str(m.id) == str(last_message_id):
                break
            if not m.message:
                continue
            sender = me.first_name if getattr(m.from_id, "user_id", None) == me.id else receiver.first_name
            receiver_name = receiver.first_name if getattr(m.from_id, "user_id", None) == me.id else me.first_name
            new_messages.append({
                "from": sender,
                "to": receiver_name,
                "date": m.date.isoformat(),
                "text": m.message,
                "Contact_id": contact_id
            })

        if not new_messages:
            return {"error": "No new messages found for this contact."}

        # Analyze and save all new messages
        embeddings = []
        emotions = []
        for msg in new_messages:
            try:
                embedding = rag._embed(msg["text"])
            except Exception as e:
                print(f"ERROR - Failed to create embedding: {e}")
                embedding = [0.0] * 1024
            embeddings.append(embedding)
            
            # Check cache first for emotion analysis
            cached_emotion = MessageCache.get_cached_emotion_analysis(msg["text"])
            if cached_emotion:
                print(f"✅ Cache hit for emotion analysis in append_latest")
                emotions.append(cached_emotion)
                continue
            
            try:
                emotion_data = rag.get_emotion_data(msg["text"])
                from services.emotion_pipeline import analyze_emotion, interpretation
                emotion_analysis = analyze_emotion(msg["text"])
                if emotion_analysis.get("pipeline_success"):
                    interpretation_text = interpretation(emotion_analysis)
                    emotion_data["interpretation"] = interpretation_text
                else:
                    emotion_data["interpretation"] = "Failed to analyze emotion for this message."
                
                # Cache the emotion analysis result
                MessageCache.cache_emotion_analysis(msg["text"], emotion_data)
                print(f"💾 Cached emotion analysis in append_latest")
                
            except Exception as e:
                print(f"ERROR - Failed to analyze emotion: {e}")
                emotion_data = {
                    "vector": [0.0] * 7,
                    "labels": {
                        "joy": 0.0, "sadness": 0.0, "anger": 0.0,
                        "fear": 0.0, "surprise": 0.0, "disgust": 0.0,
                        "neutral": 1.0
                    },
                    "top": "neutral",
                    "interpretation": "Unable to analyze emotion for this message."
                }
            emotions.append(emotion_data)

        message_ids = await save_messages_to_db(new_messages, user_id, embeddings, emotions)

        # Prepare response: return all analyzed messages
        analyzed_messages = []
        for i, msg in enumerate(new_messages):
            analyzed_messages.append({
                "message_id": message_ids[i] if message_ids else None,
                "sender": msg["from"],
                "receiver": msg["to"],
                "date_sent": msg["date"],
                "content": msg["text"],
                "detected_emotion": emotions[i].get("top"),
                "emotion_labels": emotions[i].get("labels"),
                "interpretation": emotions[i].get("interpretation")
            })
        
        # Cache the latest message
        if analyzed_messages:
            MessageCache.cache_latest_message(user_id, contact_id, analyzed_messages[0])
            print(f"💾 Cached latest message for {user_id}:{contact_id}")
        
        # Invalidate conversation cache since new messages were added
        MessageCache.invalidate_conversation(user_id, contact_id)
        print(f"🗑️ Invalidated conversation cache for {user_id}:{contact_id}")
        
        return {"messages": analyzed_messages}
    finally:
        if local_db:
            db.close()
          
            
            
            
            

async def get_contact_messages_by_id(user_id: str, contact_id: int, db: Session = None) -> dict:
    """
    Fetch last 10 messages with a contact (by contact_id), create semantic and emotion embeddings, save to DB, and return results.
    """
    # Use provided db session or create one
    local_db = db is None
    if local_db:
        db = Session(engine)
    try:
        client = await get_client(user_id, db)
        await client.connect()
        if not await client.is_user_authorized():
            raise PermissionError("User not authenticated.")

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
            sender = me.first_name if getattr(m.from_id, "user_id", None) == me.id else receiver.first_name
            receiver_name = receiver.first_name if getattr(m.from_id, "user_id", None) == me.id else me.first_name
            message_data = {
                "from": sender,
                "to": receiver_name,
                "date": m.date.isoformat(),
                "text": m.message,
                "Contact_id": contact_id
            }
            messages.append(message_data)
            message_texts.append(m.message)

        message_ids = []
        if message_texts:
            try:
                embedding_vectors = []
                for text in message_texts:
                    try:
                        embed = rag._embed(text)
                        embedding_vectors.append(embed)
                    except Exception as e:
                        print(f"ERROR - Failed to create embedding for text '{text[:50]}...': {e}")
                        embedding_vectors.append([0.0] * 1024)

                emotion_outputs = []
                for text in message_texts:
                    # Check cache first for emotion analysis
                    cached_emotion = MessageCache.get_cached_emotion_analysis(text)
                    if cached_emotion:
                        print(f"✅ Cache hit for emotion analysis")
                        emotion_outputs.append(cached_emotion)
                        continue
                    
                    try:
                        emotion_data = rag.get_emotion_data(text)
                        from services.emotion_pipeline import analyze_emotion, interpretation
                        emotion_analysis = analyze_emotion(text)
                        if emotion_analysis.get("pipeline_success"):
                            interpretation_text = interpretation(emotion_analysis)
                            emotion_data["interpretation"] = interpretation_text
                        else:
                            emotion_data["interpretation"] = "Failed to analyze emotion for this message."
                        
                        # Cache the emotion analysis result
                        MessageCache.cache_emotion_analysis(text, emotion_data)
                        print(f"💾 Cached emotion analysis")
                        
                        emotion_outputs.append(emotion_data)
                    except Exception as e:
                        print(f"ERROR - Failed to create emotion data for text '{text[:50]}...': {e}")
                        emotion_result = {
                            "vector": [0.0] * 7,
                            "labels": {
                                "joy": 0.0, "sadness": 0.0, "anger": 0.0,
                                "fear": 0.0, "surprise": 0.0, "disgust": 0.0,
                                "neutral": 1.0
                            },
                            "top": "neutral",
                            "interpretation": "Unable to analyze emotion for this message."
                        }
                        emotion_outputs.append(emotion_result)

                message_ids = await save_messages_to_db(messages, user_id, embedding_vectors, emotion_outputs)

                # Add to RAG system in batch only if save was successful
                if message_ids:
                    rag_documents = []
                    for i, (msg, embedding) in enumerate(zip(messages, embedding_vectors)):
                        try:
                            msg_id = message_ids[i]
                            metadata = {
                                "sender": msg["from"],
                                "receiver": msg["to"],
                                "date": msg["date"],
                                "message_id": msg_id
                            }
                            rag_documents.append((message_texts[i], metadata))
                        except IndexError:
                            continue
                    for doc, metadata in rag_documents:
                        rag.add_document(doc, metadata=metadata)
            except Exception as e:
                print(f"ERROR - Failed to process embeddings: {e}")

        conversation_context = get_conversation_context(me.first_name, receiver.first_name, 50)

        return {
            "sender": me.first_name,
            "receiver": receiver.first_name,
            "messages": messages,
            "conversation_context": conversation_context,
            "saved_message_ids": message_ids
        }
    finally:
        if local_db:
            db.close()        
            
            
  
            
            
            
            
            
            
            
            
            
            
            

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