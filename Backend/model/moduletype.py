from sqlmodel import SQLModel, Field, Relationship
from typing import List, Optional

class ModuleType(SQLModel, table=True):
    __tablename__ = "moduletype"

    ModuleTypeID: str = Field(primary_key=True)
    Category: Optional[str] = Field(default=None)
    Description: Optional[str] = Field(default=None)

    # Relationship to readingsinfo
    readings: List["ReadingsInfo"] = Relationship(back_populates="module_type")