from sqlmodel import SQLModel, Field, Relationship
from typing import Optional
from datetime import date

class ReadingProgress(SQLModel, table=True):
    __tablename__ = "readingprogress"

    ProgressID: str = Field(primary_key=True)
    UserID: Optional[int] = Field(default=None)
    ReadingsID: Optional[str] = Field(default=None, foreign_key="readingsinfo.ReadingsID")
    ScrollPosition: Optional[str] = Field(default=None)
    LastReadAt: Optional[date] = Field(default=None)
    CompletedAt: Optional[date] = Field(default=None)

    # Relationship
    reading: Optional["ReadingsInfo"] = Relationship(back_populates="progresses")