from sqlmodel import SQLModel, Field
from typing import Optional
from datetime import date

class UserInfo(SQLModel, table=True):
    __tablename__ = "userinfo"

    UserId: Optional[int] = Field(default=None, primary_key=True)
    FirstName: Optional[str] = Field(default=None, max_length=50)
    LastName: Optional[str] = Field(default=None, max_length=20)
    MobileNumber: Optional[str] = Field(default=None, max_length=30)
    PasswordHash: Optional[str] = Field(default=None, max_length=60)
    CreatedAt: Optional[date] = Field(default=None)