from sqlmodel import SQLModel, Field
from typing import Optional
from datetime import datetime

class ScenarioCompletion(SQLModel, table=True):
    __tablename__ = "scenario_completions"

    scenario_completion_id: str = Field(primary_key=True)
    user_id: str = Field(max_length=255, index=True)  # Firebase UID
    scenario_id: int = Field(index=True)
    completed_at: datetime = Field(default_factory=datetime.utcnow)
    completion_time_minutes: Optional[int] = Field(default=None)
    
    # Evaluation scores (1-10 scale)
    clarity_score: Optional[int] = Field(default=None)
    empathy_score: Optional[int] = Field(default=None)
    assertiveness_score: Optional[int] = Field(default=None)
    appropriateness_score: Optional[int] = Field(default=None)
    
    # User rating (1-5 stars)
    user_rating: Optional[int] = Field(default=None)
    
    # Conversation statistics
    total_messages: Optional[int] = Field(default=None)
    
    # Metadata
    created_at: datetime = Field(default_factory=datetime.utcnow)
