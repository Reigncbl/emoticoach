from fastapi import APIRouter, Depends
from sqlmodel import Session, select
from sqlalchemy.sql import text
from model.notifications import Notifications
from core.db_connection import get_db as get_session
from pydantic import BaseModel

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

# === NOTIFICATIONS ===

# Endpoint for fetching user notifications
@achievement_router.get("/user/{user_id}/notifications")
async def get_user_notifications(user_id: str, session: Session = Depends(get_session)):
    """
    Fetch all notifications for a given user.
    """
    query = text("""
        SELECT *
        FROM notifications
        WHERE "user_id" = :user_id
        ORDER BY "created_at" DESC
    """)

    results = session.execute(query, {"user_id": user_id}).all()
    return [dict(row._mapping) for row in results]

# Endpoint for creating a new notification for a user
class NotificationCreate(BaseModel):
    type: str
    title: str
    message: str

@achievement_router.post("/user/{user_id}/notifications")
def create_notification(
    user_id: str,
    notification: NotificationCreate,
    session: Session = Depends(get_session)
):
    new_notification = Notifications(
        user_id=user_id,
        type=notification.type,
        title=notification.title,
        message=notification.message
    )
    
    session.add(new_notification)
    session.commit()
    session.refresh(new_notification)
    
    return new_notification