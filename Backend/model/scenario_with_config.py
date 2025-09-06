"""
Enhanced Scenario model with embedded character configuration
"""
from sqlmodel import SQLModel, Field, Column, JSON
from typing import Optional, Dict, Any
import json

class ScenarioWithConfig(SQLModel, table=True):
    """Enhanced scenario model with embedded character configuration"""
    __tablename__ = "scenarios_with_config"
    
    id: Optional[int] = Field(default=None, primary_key=True)
    title: str = Field(max_length=200)
    description: str = Field(max_length=500)
    category: str = Field(max_length=50)
    difficulty: str = Field(max_length=20)  # beginner, intermediate, advanced
    estimated_duration: int = Field(description="Estimated duration in minutes")
    max_turns: int = Field(description="Maximum conversation turns")
    is_active: bool = Field(default=True)
    
    # Character configuration stored as JSON
    character_config: Dict[str, Any] = Field(sa_column=Column(JSON))
    
    @property
    def character_name(self) -> str:
        """Get character name from config"""
        return self.character_config.get('roleplay', {}).get('name', 'Unknown')
    
    @property
    def character_description(self) -> str:
        """Get character description from config"""
        return self.character_config.get('roleplay', {}).get('description', '')
    
    @property
    def first_message(self) -> str:
        """Get character's first message"""
        return self.character_config.get('roleplay', {}).get('first_message', '')
    
    def set_character_config(self, name: str, description: str, first_message: str):
        """Set character configuration"""
        self.character_config = {
            "roleplay": {
                "name": name,
                "description": description,
                "first_message": first_message
            }
        }
    
    @classmethod
    def from_yaml_config(cls, title: str, description: str, category: str, 
                        difficulty: str, duration: int, max_turns: int, 
                        yaml_config: Dict[str, Any]) -> "ScenarioWithConfig":
        """Create scenario from YAML config"""
        scenario = cls(
            title=title,
            description=description,
            category=category,
            difficulty=difficulty,
            estimated_duration=duration,
            max_turns=max_turns,
            character_config=yaml_config
        )
        return scenario
