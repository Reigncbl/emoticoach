from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, Field
from typing import Optional
from services.email_service import email_service

support_router = APIRouter(prefix="/api/support", tags=["Support"])


class HelpRequest(BaseModel):
    """Help request model - intentionally minimal for anonymity"""
    message: str = Field(..., min_length=10, max_length=5000, description="Help request message")
    subject: Optional[str] = Field(None, max_length=200, description="Optional subject line")
    email: Optional[str] = Field(None, max_length=255, description="Optional email for response")


class FeedbackRequest(BaseModel):
    """Feedback request model - intentionally minimal for anonymity"""
    message: str = Field(..., min_length=10, max_length=5000, description="Feedback message")
    rating: Optional[int] = Field(None, ge=1, le=5, description="Rating from 1 to 5")


@support_router.post("/help-request")
async def submit_help_request(request: HelpRequest):
    """
    Submit an anonymous help request.
    Optional email field allows users to receive a response.
    
    Args:
        request: Help request with message, optional subject, and optional email
        
    Returns:
        Success message
    """
    try:
        # Send email with optional user email for response
        success = email_service.send_help_request(
            message=request.message,
            subject=request.subject,
            user_email=request.email
        )
        
        if not success:
            raise HTTPException(
                status_code=500,
                detail="Failed to send help request. Please try again later."
            )
        
        return {
            "success": True,
            "message": "Help request submitted successfully. We'll get back to you soon!"
        }
        
    except Exception as e:
        print(f"Error in submit_help_request: {e}")
        raise HTTPException(
            status_code=500,
            detail="An error occurred while submitting your help request."
        )


@support_router.post("/feedback")
async def submit_feedback(request: FeedbackRequest):
    """
    Submit anonymous feedback.
    No user information or IP addresses are logged.
    
    Args:
        request: Feedback with message and optional rating
        
    Returns:
        Success message
    """
    try:
        # Send email anonymously
        success = email_service.send_feedback(
            message=request.message,
            rating=request.rating
        )
        
        if not success:
            raise HTTPException(
                status_code=500,
                detail="Failed to send feedback. Please try again later."
            )
        
        return {
            "success": True,
            "message": "Thank you for your feedback!"
        }
        
    except Exception as e:
        print(f"Error in submit_feedback: {e}")
        raise HTTPException(
            status_code=500,
            detail="An error occurred while submitting your feedback."
        )
