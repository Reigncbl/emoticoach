# backend/routers/telegram_router.py
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
    phone_number: str = "+639762325664"

# Default phone number from AuthRequest
DEFAULT_PHONE = AuthRequest().phone_number
    
class CodeRequest(BaseModel):
    phone_number: str = DEFAULT_PHONE
    code: str
    password: Optional[str] = None

class InterpretationRequest(BaseModel):
    user_id: str
    limit: Optional[int] = 50


@message_router.post("/auth/start")
async def start_auth(data: AuthRequest):
    """Sends a verification code to the user's Telegram."""
    try:
        await telegram_svc.start_auth_session(data.phone_number)
        return {"message": "Code sent"}
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"An unexpected error occurred: {e}")

@message_router.post("/auth/verify")
async def verify_code(data: CodeRequest):
    """Verifies the code and logs the user in."""
    try:
        result = await telegram_svc.verify_auth_code(
            data.phone_number, data.code, data.password
        )
        if "password_required" in result:
            return {"password_required": True}
        return {"message": f"Authenticated as {result['first_name']}", "user_id": result['user_id']}
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"An unexpected error occurred: {e}")

@message_router.get("/status")
async def get_status(phone_number: str = DEFAULT_PHONE):
    """Checks the user's authentication status."""
    try:
        return await telegram_svc.is_user_authenticated(phone_number)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"An unexpected error occurred: {e}")

@message_router.get("/contacts")
async def get_contacts(phone_number: str = DEFAULT_PHONE):
    """Gets the list of user contacts."""
    try:
        contacts = await telegram_svc.get_user_contacts(phone_number)
        return {"contacts": contacts, "total": len(contacts)}
    except PermissionError as e:
        raise HTTPException(status_code=401, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"An unexpected error occurred: {e}")

@message_router.post("/messages")
async def get_messages(data: ContactRequest, phone_number: str = DEFAULT_PHONE):
    """Gets the last 10 messages from a contact with emotion analysis and interpretations."""
    try:
        messages = await telegram_svc.get_contact_messages(
            phone_number, data.dict()
        )
        return messages
    except PermissionError as e:
        raise HTTPException(status_code=401, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"An unexpected error occurred: {e}")

@message_router.get("/messages/interpretations/{user_id}")
async def get_messages_with_interpretations(
    user_id: str, 
    limit: int = Query(50, description="Maximum number of messages to retrieve")
):
    """Gets messages with their emotion interpretations for a specific user."""
    try:
        messages = await telegram_svc.get_messages_with_interpretations(user_id, limit)
        return {
            "user_id": user_id,
            "total_messages": len(messages),
            "messages": messages
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"An unexpected error occurred: {e}")

@message_router.post("/messages/analyze")
async def analyze_single_message(message_text: str):
    """Analyze a single message for emotion and get interpretation."""
    try:
        from emotion_pipeline import analyze_emotion, interpretation
        
        # Analyze the message
        emotion_analysis = analyze_emotion(message_text)
        
        if emotion_analysis.get("pipeline_success"):
            # Generate interpretation
            interpretation_text = interpretation(emotion_analysis)
            
            return {
                "success": True,
                "message": message_text,
                "emotion_analysis": {
                    "dominant_emotion": emotion_analysis["dominant_emotion"],
                    "dominant_score": emotion_analysis["dominant_score"],
                    "all_emotion_scores": emotion_analysis["emotion_scores"],
                    "interpretation": interpretation_text
                }
            }
        else:
            raise HTTPException(
                status_code=500, 
                detail=f"Emotion analysis failed: {emotion_analysis.get('error', 'Unknown error')}"
            )
            
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Analysis failed: {e}")

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