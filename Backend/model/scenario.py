from sqlmodel import SQLModel, Field
from typing import Optional
import yaml
import os
from core.supabase_config import SupabaseStorage

class Scenario(SQLModel, table=True):
    __tablename__ = "scenarios"
    
    # Primary key
    id: Optional[int] = Field(default=None, primary_key=True)
    
    # Basic scenario information
    title: str = Field(max_length=200)
    description: str = Field(max_length=500)
    category: str = Field(max_length=50)  # e.g., "workplace", "family", "friendship"
    difficulty: str = Field(max_length=20, default="beginner")  # beginner, intermediate, advanced
    
    # Reference to YAML configuration file in Supabase Storage
    config_file: str = Field(max_length=100)  # filename in Supabase Storage bucket
    
    # Settings
    estimated_duration: int = Field(default=10)  # minutes
    max_turns: int = Field(default=10)  # maximum conversation turns
    is_active: bool = Field(default=True)
    
    def load_config(self) -> dict:
        """Load the YAML configuration from Supabase Storage"""
        try:
            storage = SupabaseStorage()
            yaml_content = storage.download_yaml(self.config_file)
            
            if yaml_content:
                return yaml.safe_load(yaml_content)
            else:
                # Fallback to local file if Supabase fails
                config_path = os.path.join(os.path.dirname(__file__), '..', 'Templates', self.config_file)
                if os.path.exists(config_path):
                    with open(config_path, 'r', encoding='utf-8') as file:
                        return yaml.safe_load(file)
                else:
                    raise FileNotFoundError(f"Config file {self.config_file} not found in Supabase Storage or local Templates folder")
        except Exception as e:
            raise Exception(f"Failed to load config {self.config_file}: {str(e)}")
    
    @property
    def character_name(self) -> str:
        """Get character name from YAML config"""
        config = self.load_config()
        return config.get('roleplay', {}).get('name', 'Unknown')
    
    @property
    def opening_message(self) -> str:
        """Get opening message from YAML config"""
        config = self.load_config()
        return config.get('roleplay', {}).get('first_message', '').strip()
