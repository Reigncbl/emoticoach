from sqlmodel import SQLModel, Field, Column, String
from typing import Optional
import uuid
from datetime import datetime

class TelegramSession(SQLModel, table=True):
    __tablename__ = "telegram_sessions"

    session_id: uuid.UUID = Field(default_factory=uuid.uuid4, primary_key=True)
    user_id: str = Field(foreign_key="userinfo.UserId", nullable=False)
    phone_number: str = Field(sa_column=Column(String(20), nullable=False))
    session_data: Optional[str] = Field(sa_column=Column(String, nullable=True))
    phone_code_hash: Optional[str] = Field(sa_column=Column(String, nullable=True))
    telegram_username: Optional[str] = Field(sa_column=Column(String(32), nullable=True))
    created_at: datetime = Field(default_factory=datetime.utcnow, nullable=False)
    updated_at: datetime = Field(default_factory=datetime.utcnow, nullable=False)
