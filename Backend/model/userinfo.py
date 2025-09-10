from sqlmodel import SQLModel, Field
from typing import Optional
from datetime import date

class UserInfo(SQLModel, table=True):
    __tablename__ = "userinfo"

    UserId: str = Field(primary_key=True)  # Firebase UID as primary key (varchar)
    FirstName: str = Field(max_length=100)  # Required field
    LastName: str = Field(max_length=100)   # Required field
    MobileNumber: Optional[str] = Field(default=None, max_length=20)
    PasswordHash: Optional[str] = Field(default=None)  # TEXT field
    CreatedAt: date = Field()  # Required field