from sqlmodel import SQLModel, Field
from typing import Optional

class ExperienceInfo(SQLModel, table=True):
    __tablename__ = "Experienceinfo"

    UserId: str = Field(max_length=100, index=True, primary_key=True) 
    Xp: int = Field(default=0)  
