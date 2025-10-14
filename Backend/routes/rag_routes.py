
from datetime import datetime, timedelta
from typing import List, Optional

from fastapi import APIRouter, Query, HTTPException
from pydantic import BaseModel
from services.RAGPipeline import rag
from services.emotion_pipeline import analyze_emotion
from sqlmodel import Session, select, or_
from core.db_connection import engine
from model.message import Message
from model.userinfo import UserInfo
from services.cache import MessageCache

rag_router = APIRouter(prefix="/rag", tags=["RAG"])


class ManualAnalysisRequest(BaseModel):
    user_id: str
    message: str
    sender_name: Optional[str] = None
    desired_tone: Optional[str] = None
    user_display_name: Optional[str] = None

def get_messages_for_conversation(
    user_id: str,
    contact_id: int,
    limit: int = 10,
    start_time=None,
    end_time=None,
) -> List[Message]:
    """Fetch last N messages between this user and a specific contact by contact_id."""
    with Session(engine) as session:
        stmt = (
            select(Message)
            .where(
                Message.Contact_id == contact_id,
                or_(Message.UserId == user_id, Message.Receiver == user_id, Message.Sender == user_id)
            )
            .order_by(Message.DateSent.desc())  # type: ignore[attr-defined]
            .limit(limit)
        )
        if start_time:
            stmt = stmt.where(Message.DateSent >= start_time)
        if end_time:
            stmt = stmt.where(Message.DateSent <= end_time)

        messages = list(session.exec(stmt).all())

        if not messages:
            raise HTTPException(status_code=404, detail="No messages found")

        return messages

def get_expected_replier(messages, user_true_name):
    """
    Given a list of messages (latest first), determine if the user should reply.
    Returns True if user_true_name is NOT the Sender of the last message.
    """
    if not messages:
        return None
    last_message = messages[0]
    return last_message.Sender != user_true_name

def get_true_name_from_userid(user_id):
    """
    Fetch true name (FirstName LastName) from userinfo table using UserId.
    """
    # Check cache first
    cached_user = MessageCache.get_cached_user_info(user_id)
    if cached_user and "first_name" in cached_user and "last_name" in cached_user:
        return f"{cached_user['first_name']} {cached_user['last_name']}"
    
    with Session(engine) as session:
        user = session.exec(select(UserInfo).where(UserInfo.UserId == user_id)).first()
        if user:
            # Cache user info for future use
            user_data = {
                "user_id": user_id,
                "first_name": user.FirstName,
                "last_name": user.LastName,
                "mobile_number": user.MobileNumber if hasattr(user, 'MobileNumber') else None
            }
            MessageCache.cache_user_info(user_id, user_data)
            return f"{user.FirstName} {user.LastName}"
        return user_id  # fallback to user_id if not found


@rag_router.get("/rag-context")
def rag_sender_context(
    user_id: str = Query(..., description="The Firebase user ID"),
    contact_id: int = Query(..., description="Contact ID of the contact (Sender or Receiver)"),
    query: str = Query("", description="Optional user instruction or query"),
    limit: int = Query(10, description="Number of messages to fetch"),
    start_time: str = Query(None, description="Start timestamp (YYYY-MM-DD HH:MM:SS)"),
    end_time: str = Query(None, description="End timestamp (YYYY-MM-DD HH:MM:SS)"),
    desired_tone: str | None = Query(
        None,
        description="Desired tone for the generated reply (e.g., Formal, Casual)",
    ),
):
    try:
        messages = get_messages_for_conversation(
            user_id, contact_id, limit, start_time, end_time
        )
    except HTTPException as exc:
        if exc.status_code == 404:
            messages = []
        else:
            raise

    context = "\n".join([f"{m.Sender}: {m.MessageContent}" for m in messages])

    # Get user's previous messages for style
    user_true_name = get_true_name_from_userid(user_id)
    user_messages = [m.MessageContent for m in messages if m.Sender == user_true_name]

    # Reply to the last message in the conversation
    if messages:
        last_message = messages[0]
        reply_query = last_message.MessageContent
        last_sender = last_message.Sender
    else:
        reply_query = query or ""
        last_sender = "Contact"

    tone_instruction = ""
    if desired_tone:
        tone_instruction = (
            f"\nDesired reply tone: Respond in a {desired_tone.lower()} tone while remaining genuine and helpful."
        )

    user_instruction = ""
    if query:
        user_instruction = f"\nAdditional user instructions: {query}"

    # Determine if user should reply or not
    should_reply = last_sender != user_true_name
    
    if should_reply:
        enhanced_query = (
            f"You are helping {user_true_name} craft a reply.\n\n"
            "Conversation context:\n"
            f"{context if context else 'No prior context available.'}\n\n"
            f"Last message from {last_sender}: {reply_query or 'No message to reply to.'}\n\n"
            f"Generate a reply AS {user_true_name} responding to {last_sender}'s message."
            f"{tone_instruction}{user_instruction}\n\n"
            f"Remember: You are crafting a reply for {user_true_name}, mimicking their communication style."
        )
    else:
        enhanced_query = (
            f"You are helping {user_true_name}.\n\n"
            "Conversation context:\n"
            f"{context if context else 'No prior context available.'}\n\n"
            f"The last message was sent by {user_true_name} themselves: {reply_query}\n\n"
            "Provide feedback or suggestions about their message, or wait for the other person's response."
            f"{tone_instruction}{user_instruction}"
        )

    try:
        response = rag.generate_response(
            enhanced_query, 
            user_messages=user_messages,
            top_k=3,
            use_reranker=True
        )
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"Failed to generate response: {exc}")

    emotion_analysis = analyze_emotion(response or "", user_name=user_id)
    return {
        "success": True,
        "response": response,
        "emotion_analysis": emotion_analysis,
        "requested_tone": desired_tone,
        "context_used": context,
    }




@rag_router.get("/recent-emotion-context")
def recent_emotion_context(
    user_id: str = Query(..., description="The Firebase user ID"),
    contact_id: int = Query(..., description="Contact ID of the contact (Sender or Receiver)"),
    window_minutes: int = Query(20, description="Time window in minutes for context"),
):
    # Step 1: Get the absolute latest message
    latest_messages = get_messages_for_conversation(user_id, contact_id, limit=1)
    latest_message = latest_messages[0] if latest_messages else None
    if not latest_message:
        return {"detail": "No messages found"}
    latest_time = latest_message.DateSent
    now = datetime.utcnow()
    # Step 2: Get all messages in the previous window_minutes before the latest message
    window_start = latest_time - timedelta(minutes=window_minutes)
    with Session(engine) as session:
        stmt = (
            select(Message)
            .where(
                Message.Contact_id == contact_id,
                or_(Message.UserId == user_id, Message.Receiver == user_id, Message.Sender == user_id),
                Message.DateSent >= window_start,
                Message.DateSent < latest_time
            )
            .order_by(Message.DateSent.desc())  # type: ignore[attr-defined]
        )
        context_msgs = session.exec(stmt).all()
    context = "\n".join([f"{m.Sender}: {m.MessageContent}" for m in context_msgs])
    # Analyze emotion for each message
    emotion_context = [
        {
            "Sender": m.Sender,
            "MessageContent": m.MessageContent,
            "DateSent": m.DateSent,
            "emotion_analysis": analyze_emotion(m.MessageContent, user_name=m.Sender)
        }
        for m in context_msgs
    ]

    # Prepare user style examples
    user_true_name = get_true_name_from_userid(user_id)
    user_messages = [m.MessageContent for m in context_msgs if m.Sender == user_true_name]

    # Always include the latest message in the response
    last_message = {
        "Sender": latest_message.Sender if latest_message else None,
        "MessageContent": latest_message.MessageContent if latest_message else None,
        "DateSent": latest_message.DateSent if latest_message else None,
        "emotion_analysis": analyze_emotion(latest_message.MessageContent, user_name=latest_message.Sender) if latest_message else None
    }

    # Determine if user should reply
    last_sender = last_message['Sender']
    should_reply = last_sender != user_true_name
    
    # Use RAG to generate a suggestion based on the context window and last message
    if should_reply:
        rag_query = (
            f"You are helping {user_true_name} craft a reply.\n\n"
            f"Conversation context (last {window_minutes} minutes):\n{context}\n\n"
            f"Last message from {last_sender}: {last_message['MessageContent']}\n\n"
            f"Generate a reply AS {user_true_name} responding to {last_sender}'s message. "
            f"Use the previous {window_minutes} minutes of conversation as context.\n\n"
            f"Remember: You are crafting a reply for {user_true_name}, mimicking their communication style."
        )
    else:
        rag_query = (
            f"You are helping {user_true_name}.\n\n"
            f"Conversation context (last {window_minutes} minutes):\n{context}\n\n"
            f"The last message was sent by {user_true_name} themselves: {last_message['MessageContent']}\n\n"
            f"Provide feedback about their message or suggest waiting for the other person's response."
        )
    rag_response = rag.generate_response(
        rag_query, 
        user_messages=user_messages,
        top_k=3,
        use_reranker=True
    )
    rag_emotion = analyze_emotion(rag_response or "", user_name=user_true_name)

    return {
        "context_window": context,
        "messages": emotion_context,
        "window_start": window_start,
        "window_end": now,
        "last_message": last_message,
        "rag_suggestion": rag_response,
        "rag_suggestion_emotion": rag_emotion
    }


@rag_router.post("/manual-emotion-context")
def manual_emotion_context(payload: ManualAnalysisRequest):
    """Generate analysis and suggestions for user-provided message input."""
    context = payload.message

    user_display_name: str = (
        payload.user_display_name or get_true_name_from_userid(payload.user_id)
    )

    user_messages: List[str] = []

    last_sender = payload.sender_name or "Contact"
    last_message = {
        "Sender": last_sender,
        "MessageContent": payload.message,
        "DateSent": datetime.utcnow(),
        "emotion_analysis": analyze_emotion(
            payload.message, user_name=last_sender
        ),
    }

    tone_instruction = ""
    if payload.desired_tone:
        tone_instruction = (
            f"\nDesired reply tone: Respond in a {payload.desired_tone.lower()} tone"
            " while remaining genuine and helpful."
        )

    # Determine if user should reply
    should_reply = last_sender != user_display_name
    
    if should_reply:
        rag_query = (
            f"You are helping {user_display_name} craft a reply.\n\n"
            "Conversation context:\n"
            f"{context if context else 'No prior context available.'}\n\n"
            f"Last message from {last_sender}: {payload.message}\n\n"
            f"Generate a reply AS {user_display_name} responding to {last_sender}'s message."
            f"{tone_instruction}\n\n"
            f"Remember: You are crafting a reply for {user_display_name}, mimicking their communication style."
        )
    else:
        rag_query = (
            f"You are helping {user_display_name}.\n\n"
            "Conversation context:\n"
            f"{context if context else 'No prior context available.'}\n\n"
            f"The last message was sent by {user_display_name} themselves: {payload.message}\n\n"
            "Provide feedback about their message or suggest improvements."
            f"{tone_instruction}"
        )

    try:
        rag_response = rag.generate_response(
            rag_query, 
            user_messages=user_messages,
            top_k=3,
            use_reranker=True
        )
    except Exception as exc:  # noqa: BLE001
        raise HTTPException(status_code=500, detail=f"Failed to generate response: {exc}")

    rag_emotion = analyze_emotion(
        rag_response or "", user_name=user_display_name
    )

    message_entry = {
        "Sender": last_sender,
        "MessageContent": payload.message,
        "DateSent": last_message["DateSent"],
        "emotion_analysis": last_message["emotion_analysis"],
    }

    return {
        "context_window": context,
        "messages": [message_entry],
        "window_start": None,
        "window_end": datetime.utcnow(),
        "last_message": last_message,
        "rag_suggestion": rag_response,
        "rag_suggestion_emotion": rag_emotion,
    }

# Get the latest message and its emotional analysis
@rag_router.get("/latest-message")
def get_latest_message(
    user_id: str = Query(..., description="The Firebase user ID"),
    contact_id: int = Query(..., description="Contact ID of the contact (Sender or Receiver)"),
):
    messages = get_messages_for_conversation(user_id, contact_id, limit=1)
    latest_message = messages[0] if messages else None
    if not latest_message:
        return {"detail": "No messages found"}
    return {
        "Sender": latest_message.Sender,
        "MessageContent": latest_message.MessageContent,
        "DateSent": latest_message.DateSent,
        "emotion_analysis": analyze_emotion(latest_message.MessageContent, user_name=latest_message.Sender)
    }