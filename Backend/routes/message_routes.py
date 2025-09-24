
import json
from typing import Optional
from fastapi import APIRouter, HTTPException, Query
from pydantic import BaseModel

# Import the service functions
from services import messages_services as telegram_svc


message_router = APIRouter(prefix="/messages",tags=["Messages"])


class ContactRequest(BaseModel):
    phone: str
    first_name: str = ""
    last_name: str = ""

class AuthRequest(BaseModel):
    phone_number: str = ""

# Default phone number from AuthRequest
DEFAULT_PHONE = AuthRequest().phone_number
    
class CodeRequest(BaseModel):
    phone_number: str = DEFAULT_PHONE
    code: str
    password: Optional[str] = None


class AppendMessageRequest(BaseModel):
    user_id: str
    sender: str
    receiver: str
    text: str


@message_router.get("/messages/emotions/{user_id}")
async def get_emotion_summary(
    user_id: str,
    limit: int = Query(100, description="Number of recent messages to analyze")
):
    """Get emotion summary statistics for a user's messages."""
    try:
        messages = await telegram_svc.get_messages_with_interpretations(user_id, limit)
        
        # Calculate emotion statistics
        emotion_counts = {}
        total_messages = len(messages)
        
        for msg in messages:
            emotion = msg.get("detected_emotion", "unknown")
            emotion_counts[emotion] = emotion_counts.get(emotion, 0) + 1
        
        # Calculate percentages
        emotion_percentages = {
            emotion: (count / total_messages) * 100 
            for emotion, count in emotion_counts.items()
        } if total_messages > 0 else {}
        
        return {
            "user_id": user_id,
            "total_messages_analyzed": total_messages,
            "emotion_distribution": {
                "counts": emotion_counts,
                "percentages": emotion_percentages
            },
            "most_common_emotion": max(emotion_counts.items(), key=lambda x: x[1])[0] if emotion_counts else "unknown"
        }
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to generate emotion summary: {e}")