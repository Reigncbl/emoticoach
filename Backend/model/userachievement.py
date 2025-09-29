from sqlmodel import SQLModel, Field
from typing import Optional
from datetime import datetime

class UserAchievement(SQLModel, table=True):
    __tablename__ = "user_achievements"

    id: Optional[int] = Field(default=None, primary_key=True)
    UserId: str = Field(max_length=100, index=True)
    BadgeId: str = Field(max_length=50)
    attained_time: datetime = Field(default_factory=datetime.utcnow)