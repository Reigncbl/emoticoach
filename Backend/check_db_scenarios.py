import sys
import os

# Add the Backend directory to the path
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from sqlmodel import Session, select
from core.db_connection import engine
from model.scenario_with_config import ScenarioWithConfig

def check_scenarios_in_db():
    """Check what scenarios exist in the database."""
    try:
        with Session(engine) as session:
            # Get all scenarios
            statement = select(ScenarioWithConfig)
            scenarios = session.exec(statement).all()
            
            print(f"Total scenarios in database: {len(scenarios)}")
            
            if scenarios:
                print("\nScenarios found:")
                for i, scenario in enumerate(scenarios, 1):
                    print(f"{i}. ID: {scenario.id}")
                    print(f"   Title: {scenario.title}")
                    print(f"   Category: {scenario.category}")
                    print(f"   Active: {scenario.is_active}")
                    print(f"   Character: {scenario.character_name}")
                    print()
            else:
                print("No scenarios found in database!")
                print("\nThis explains why the Flutter app shows no scenarios.")
                print("You need to populate the database with scenario data.")
                
    except Exception as e:
        print(f"Error checking database: {e}")

if __name__ == "__main__":
    check_scenarios_in_db()
