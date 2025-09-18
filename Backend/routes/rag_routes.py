# backend/routes/messages.py
from fastapi import APIRouter, Query, HTTPException
from services.RAGPipeline import rag
from sqlmodel import Session, select, or_
from core.db_connection import engine
from model.message import Message

rag_router = APIRouter(prefix="/rag", tags=["RAG"])

def get_messages_for_conversation(user_id: str, contact_name: str, limit: int = 10, start_time=None, end_time=None) -> str:
    """Fetch last N messages between this user and a specific contact."""
    with Session(engine) as session:
        stmt = (
            select(Message)
            .where(
                Message.UserId == user_id,
                or_(
                    Message.Sender == contact_name,
                    Message.Receiver == contact_name,
                )
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

        return "\n".join([f"{m.Sender}: {m.MessageContent}" for m in messages])


@rag_router.get("/rag-context")
def rag_sender_context(
    user_id: str = Query(..., description="The Firebase user ID"),
    contact_name: str = Query(..., description="Name of the contact (Sender or Receiver)"),
    query: str = Query(..., description="User query"),
    limit: int = Query(10, description="Number of messages to fetch"),
    start_time: str = Query(None, description="Start timestamp (YYYY-MM-DD HH:MM:SS)"),
    end_time: str = Query(None, description="End timestamp (YYYY-MM-DD HH:MM:SS)"),
):
    context = get_messages_for_conversation(user_id, contact_name, limit, start_time, end_time)
    enhanced_query = f"Conversation context:\n{context}\n\nUser query: {query}"

    response = rag.generate_response(enhanced_query)

    return {
        "user_id": user_id,
        "contact_name": contact_name,
        "query": query,
        "context_used": context,
        "rag_response": response,
    }
