from sqlmodel import SQLModel, Field
from typing import Optional

class BadgeInfo(SQLModel, table=True):
    __tablename__ = "badgeinfo"

    BadgeId: str = Field(primary_key=True, max_length=50)  # Badge ID (e.g., "B-00001")
    Title: str = Field(max_length=100)  # Badge title (e.g., "Scenario Beginner")
    Description: str = Field(max_length=500)  # Badge description
    RequiredProgress: int  # Required progress to earn the badge
    Image_url: str = Field(max_length=500)  # URL for badge image