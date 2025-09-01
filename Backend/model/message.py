import sqlmodel
from typing import List, Optional
import datetime

class Message(sqlmodel.SQLModel, table=True):
    __tablename__ = "messages"
    Messageid: int = sqlmodel.Field(default=None, primary_key=True)
    Content: str
    Timestamp: datetime = sqlmodel.Field(default_factory=datetime.utcnow)
    Userid: int
