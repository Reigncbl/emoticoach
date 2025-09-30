from sqlmodel import SQLModel, Field
from typing import Optional
from datetime import datetime, date

class OverlayUsageStat(SQLModel, table=True):
    __tablename__ = "overlay_usage_stats"

    id: Optional[int] = Field(default=None, primary_key=True)
    user_id: str = Field(index=True, max_length=255)
    # Stats are stored per UTC date for aggregation across periods
    stat_date: date = Field(index=True, default_factory=lambda: datetime.utcnow().date())

    messages_analyzed: int = Field(default=0, ge=0)
    suggestions_used: int = Field(default=0, ge=0)
    responses_rephrased: int = Field(default=0, ge=0)

    created_at: datetime = Field(default_factory=datetime.utcnow)
    updated_at: datetime = Field(default_factory=datetime.utcnow)
