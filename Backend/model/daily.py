from __future__ import annotations
from typing import Optional
from datetime import datetime, date as dt_date
from sqlmodel import SQLModel, Field

class Challenge(SQLModel, table=True):
    __tablename__ = "challenges"
    id: Optional[int] = Field(default=None, primary_key=True)
    code: str
    title: str
    description: Optional[str] = None
    type: str
    xp_reward: int = 5
    min_dwell_secs: int = 0
    require_scroll_pct: int = 0
    min_session_secs: int = 0
    active_from: Optional[datetime] = None
    active_to: Optional[datetime] = None


class DailyChallengeItem(SQLModel, table=True):
    __tablename__ = "daily_challenge_items"
    date: dt_date = Field(primary_key=True)
    challenge_id: int = Field(primary_key=True)


class UserChallengeClaim(SQLModel, table=True):
    __tablename__ = "user_challenge_claims"
    user_id: str = Field(primary_key=True)
    challenge_id: int = Field(primary_key=True)
    date: dt_date = Field(primary_key=True)
    claimed_at: datetime = Field(default_factory=datetime.utcnow)
