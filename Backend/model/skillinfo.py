from sqlmodel import SQLModel, Field
from typing import Optional

class SkillInfo(SQLModel, table=True):
    __tablename__ = "skillinfo"

    skillid: Optional[int] = Field(default=None, primary_key=True)
    name: str = Field(max_length=255)
    description: str = Field(max_length=500) 