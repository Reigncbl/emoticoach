from sqlmodel import SQLModel, Field
from typing import Optional
from datetime import datetime

class ScenarioCompletion(SQLModel, table=True):
    __tablename__ = "scenario_completions"

    id: Optional[int] = Field(default=None, primary_key=True)
    user_id: str = Field(max_length=255, index=True)  # Firebase UID
    scenario_id: int = Field(index=True)
    completed_at: datetime = Field(default_factory=datetime.utcnow)
    completion_time_minutes: Optional[int] = Field(default=None)
    
    # Evaluation scores (1-10 scale)
    final_clarity_score: Optional[int] = Field(default=None)
    final_empathy_score: Optional[int] = Field(default=None)
    final_assertiveness_score: Optional[int] = Field(default=None)
    final_appropriateness_score: Optional[int] = Field(default=None)
    
    # User rating of the scenario (1-5 stars)
    user_rating: Optional[int] = Field(default=None)
    
    # Conversation statistics
    total_messages: Optional[int] = Field(default=None)
    
    # Metadata
    created_at: datetime = Field(default_factory=datetime.utcnow)
    
    # Composite indexes for efficient queries
    class Config:
        indexes = [
            ("user_id", "scenario_id"),
            ("user_id", "completed_at"),
        ]