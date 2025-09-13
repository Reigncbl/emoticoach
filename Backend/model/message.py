from sqlmodel import SQLModel, Field, Column
from sqlalchemy import Text
from typing import Optional, List, Any
from datetime import date
from sqlmodel import Relationship
import sqlalchemy.types as types

# Custom PostgreSQL vector type for SQLAlchemy
class Vector(types.TypeDecorator):
    impl = Text
    
    def process_bind_param(self, value, dialect):
        if value is None:
            return None
        return str(value)  # Convert list to string representation for PostgreSQL vector
    
    def process_result_value(self, value, dialect):
        if value is None:
            return None
        return eval(value)  # Convert string back to list when retrieving

class Message(SQLModel, table=True):
    __tablename__ = "messages"
    
    MessageId: str = Field(primary_key=True)  # Firebase UID as primary key (varchar)
    UserId: str = Field(foreign_key="userinfo.TelegramUserId", max_length=100)  # Foreign key to UserInfo
    Sender: str = Field(max_length=100)  # Sender of the message (varchar)
    Receiver: str = Field(max_length=100)  # Receiver of the message (varchar)
    DateSent: date = Field(default=date.today())  # Date the message was sent (date)
    MessageContent: str = Field(max_length=500)  # Content of the message (varchar)
    Embedding: Optional[List[float]] = Field(sa_column=Column(Vector), default=None)  # Vector embedding for RAG
    
