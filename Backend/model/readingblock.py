from sqlmodel import SQLModel, Field, Relationship
from typing import Optional, Dict, Any
from sqlalchemy import Column
from sqlalchemy.dialects.postgresql import JSONB
from pydantic import field_validator
import json

class ReadingBlock(SQLModel, table=True):
    __tablename__ = "readingblocks"

    blockid: Optional[int] = Field(default=None, primary_key=True, index=True)
    ReadingsID: str = Field(foreign_key="readingsinfo.ReadingsID", max_length=8)
    orderindex: int = Field()
    blocktype: str = Field(max_length=20)
    content: Optional[str] = Field(default=None)
    imageurl: Optional[str] = Field(default=None)
    pagenumber: int = Field()
    stylejson: Optional[Dict[str, Any]] = Field(default=None, sa_column=Column(JSONB))

    @field_validator('stylejson', mode='before')
    def parse_stylejson(cls, v):
        if isinstance(v, str):
            return json.loads(v)
        return v

    reading: Optional["ReadingsInfo"] = Relationship(back_populates="blocks")