from sqlmodel import SQLModel, Field
from typing import Optional
from datetime import datetime

class LevelSystem(SQLModel, table=True):
    __tablename__ = "levelsystem"

    id: Optional[int] = Field(default=None, primary_key=True)
    LVL: int = Field(index=True)
    Image_url: str = Field(max_length=500)
    Description: str = Field(max_length=255)
    Exp: int = Field(ge=0)