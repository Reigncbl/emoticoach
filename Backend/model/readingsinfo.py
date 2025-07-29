from sqlmodel import SQLModel, Field, Relationship
from typing import List, Optional

class ReadingsInfo(SQLModel, table=True):
    __tablename__ = "readingsinfo"

    ReadingsID: str = Field(primary_key=True, max_length=8)
    Title: str = Field(max_length=255)
    Author: str = Field(max_length=255)
    Description: str = Field(max_length=250)
    EstimatedMinutes: int
    XPValue: int
    Rating: int
    ModuleTypeID: str = Field(foreign_key="moduletype.ModuleTypeID", max_length=5)

    # Relationships
    module_type: Optional["ModuleType"] = Relationship(back_populates="readings")
    progresses: List["ReadingProgress"] = Relationship(back_populates="reading")
    blocks: List["ReadingBlock"] = Relationship(back_populates="reading")