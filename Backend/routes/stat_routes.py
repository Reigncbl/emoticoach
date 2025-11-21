from fastapi import APIRouter, Depends
from sqlmodel import Session
from core.db_connection import get_db as get_session
from services.stat_service import StatsService

router = APIRouter()

@router.get("/stats/{user_id}")
def get_stats(user_id: str, session: Session = Depends(get_session)):
    return StatsService.get_user_stats(user_id, session)
