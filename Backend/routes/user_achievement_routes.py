from fastapi import APIRouter, Depends
from sqlmodel import Session, select
from sqlalchemy.sql import text
from core.db_connection import get_db as get_session

achievement_router = APIRouter(prefix="/achievements", tags=["Achievements"])

@achievement_router.get("/user/{user_id}")
def get_user_achievements(user_id: str, session: Session = Depends(get_session)):
    """
    Fetch all achievements for a given user with badge details.
    """
    query = text("""
        SELECT ua.*, b."Title", b."Description", b."Image_url"
        FROM user_achievements ua
        JOIN badgeinfo b ON ua."BadgeId" = b."BadgeID"
        WHERE ua."UserId" = :user_id
        ORDER BY ua.attained_time DESC
    """)

    results = session.execute(query, {"user_id": user_id}).all()
    return [dict(row._mapping) for row in results]
