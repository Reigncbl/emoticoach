from sqlmodel import SQLModel, Field, Column, JSON
from typing import Optional, Dict, List
from datetime import datetime
from pgvector.sqlalchemy import Vector 

class Message(SQLModel, table=True):
    __tablename__ = "messages"

    MessageId: str = Field(primary_key=True, max_length=100)  # UUID
    UserId: str = Field(foreign_key="userinfo.UserId", max_length=100)
    Sender: str = Field(max_length=100)
    Receiver: str = Field(max_length=100)
    DateSent: datetime = Field(default_factory=datetime.utcnow)
    MessageContent: str = Field()

    # 🔹 Separate embeddings
    Semantic_Embedding: Optional[List[float]] = Field(
        sa_column=Column(Vector(1024)), default=None  # BGE-M3 is 1024-dim
    )
    Emotion_Embedding: Optional[List[float]] = Field(
        sa_column=Column(Vector(7)), default=None     # 7 emotion classes
    )

    # 🔹 Store full emotion distribution for readability/analytics
    Emotion_labels: Optional[Dict[str, float]] = Field(
        sa_column=Column(JSON), default=None
    )

    # 🔹 Store top emotion label for fast filtering
    Detected_emotion: Optional[str] = Field(max_length=100, default=None)
    Interpretation : Optional[str] = Field(default=None)
    Contact_id: Optional[int] = Field(default=None)