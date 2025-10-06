from sqlmodel import SQLModel, Field
from typing import Optional
from datetime import date

class Notifications(SQLModel, table=True):
    __tablename__ = "notifications"

    id: int = Field(primary_key=True)
    user_id: str = Field(foreign_key="userinfo.UserId")
    type: str = Field(max_length=50)
    title: str = Field(max_length=100)
    message: str = Field(max_length=255)
    created_at: date = Field(default_factory=date.today)