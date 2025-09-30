
from datetime import datetime, timedelta
from fastapi import APIRouter, Query, HTTPException
from services.RAGPipeline import rag
from services.emotion_pipeline import analyze_emotion
from sqlmodel import Session, select, or_
from core.db_connection import engine
from model.message import Message
from model.userinfo import UserInfo

rag_router = APIRouter(prefix="/rag", tags=["RAG"])

def get_messages_for_conversation(user_id: str, contact_id: int, limit: int = 10, start_time=None, end_time=None) -> str:
    """Fetch last N messages between this user and a specific contact by contact_id."""
    with Session(engine) as session:
        stmt = (
            select(Message)
            .where(
                Message.Contact_id == contact_id,
                or_(Message.UserId == user_id, Message.Receiver == user_id, Message.Sender == user_id)
            )
            .order_by(Message.DateSent.desc())
            .limit(limit)
        )
        if start_time:
            stmt = stmt.where(Message.DateSent >= start_time)
        if end_time:
            stmt = stmt.where(Message.DateSent <= end_time)

        messages = session.exec(stmt).all()

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
    with Session(engine) as session:
        user = session.exec(select(UserInfo).where(UserInfo.UserId == user_id)).first()
        if user:
            return f"{user.FirstName} {user.LastName}"
        return user_id  # fallback to user_id if not found


@rag_router.get("/rag-context")
def rag_sender_context(
    user_id: str = Query(..., description="The Firebase user ID"),
    contact_id: int = Query(..., description="Contact ID of the contact (Sender or Receiver)"),
    query: str = Query(..., description="User query"),
    limit: int = Query(10, description="Number of messages to fetch"),
    start_time: str = Query(None, description="Start timestamp (YYYY-MM-DD HH:MM:SS)"),
    end_time: str = Query(None, description="End timestamp (YYYY-MM-DD HH:MM:SS)"),
):
    messages = get_messages_for_conversation(user_id, contact_id, limit, start_time, end_time)
    context = "\n".join([f"{m.Sender}: {m.MessageContent}" for m in messages])

    # Get user's previous messages for style
    user_true_name = get_true_name_from_userid(user_id)
    user_messages = [m.MessageContent for m in messages if m.Sender == user_true_name]

    # Reply to the last message in the conversation
    if messages:
        last_message = messages[0]
        reply_query = last_message.MessageContent
    else:
        reply_query = query

    enhanced_query = f"Conversation context:\n{context}\n\nReply to the last message: {reply_query}"
    response = rag.generate_response(enhanced_query, user_messages=user_messages)
    emotion_analysis = analyze_emotion(response, user_name=user_id)
    return emotion_analysis




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
            .order_by(Message.DateSent.desc())
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

    # Use RAG to generate a suggestion based on the context window and last message
    rag_query = f"Conversation context:\n{context}\n\nLast message from {last_message['Sender']}: {last_message['MessageContent']}\n\nSuggest a helpful reply or action to the last message, using only the previous 20 minutes of conversation as context."
    rag_response = rag.generate_response(rag_query, user_messages=user_messages)
    rag_emotion = analyze_emotion(rag_response, user_name=user_true_name)

    return {
        "context_window": context,
        "messages": emotion_context,
        "window_start": window_start,
        "window_end": now,
        "last_message": last_message,
        "rag_suggestion": rag_response,
        "rag_suggestion_emotion": rag_emotion
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