from sqlmodel import SQLModel, Field
from typing import Optional
from datetime import date
from typing import List
from sqlmodel import Relationship
class Message(SQLModel, table=True):
    __tablename__ = "messages"
    
    MessageId: str = Field(primary_key=True)  # Firebase UID as primary key (varchar)
    UserId: str = Field(foreign_key="userinfo.TelegramUserId", max_length=100)  # Foreign key to UserInfo
    Sender: str = Field(max_length=100)  # Sender of the message (varchar)
    Receiver: str = Field(max_length=100)  # Receiver of the message (varchar
    DateSent: date = Field(default=date.today())  # Date the message was sent (date)
    MessageContent: str = Field(max_length=500)  # Content of the message (varchar)
    
