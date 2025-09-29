from fastapi import APIRouter, Depends, HTTPException
from sqlmodel import Session
from core.db_connection import get_db as get_session
from services.experience_service import get_user_level_info

experience_router = APIRouter(prefix="/experience", tags=["Experience"])

@experience_router.get("/{user_id}")
async def get_user_experience(user_id: str, session: Session = Depends(get_session)):
    """
    Get XP, level, and progress for the given userId.
    """
    try:
        data = get_user_level_info(user_id, session)
        if "error" in data:
            raise HTTPException(status_code=404, detail=data["error"])
        return data
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error fetching experience: {str(e)}")
