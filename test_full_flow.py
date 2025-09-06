#!/usr/bin/env python3
"""Simple script to add one scenario and test the API"""

import requests
import json
import sys
import os

# Add the Backend directory to the path
backend_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'Backend')
sys.path.append(backend_path)

from sqlmodel import Session, SQLModel, select
from Backend.core.db_connection import engine
from Backend.model.scenario_with_config import ScenarioWithConfig

def add_and_test_scenario():
    print("=== ADDING SCENARIO TO DATABASE ===")
    
    try:
        # Create tables
        SQLModel.metadata.create_all(engine)
        print("✓ Database tables ready")
        
        # Check existing scenarios
        with Session(engine) as session:
            existing = session.exec(select(ScenarioWithConfig)).all()
            print(f"Existing scenarios: {len(existing)}")
            
            if len(existing) == 0:
                # Add one scenario
                scenario = ScenarioWithConfig(
                    title="Handling Workplace Criticism",
                    description="Learn to respond constructively to criticism from a colleague",
                    category="workplace",
                    difficulty="beginner",
                    estimated_duration=8,
                    character_name="Alex",
                    character_description="A direct colleague",
                    character_config={
                        "roleplay": {
                            "name": "Alex",
                            "description": "You are Alex, a direct colleague who gives feedback.",
                            "first_message": "I have some concerns about your proposal."
                        }
                    },
                    is_active=True,
                    max_turns=8
                )
                
                session.add(scenario)
                session.commit()
                print("✓ Added scenario to database")
            
            # Verify scenarios exist
            all_scenarios = session.exec(select(ScenarioWithConfig)).all()
            print(f"Total scenarios now: {len(all_scenarios)}")
            
            for s in all_scenarios:
                print(f"  - {s.title} (ID: {s.id})")
    
    except Exception as e:
        print(f"Database error: {e}")
        return False
    
    print("\n=== TESTING API ENDPOINT ===")
    
    try:
        # Test API endpoint
        response = requests.get('http://localhost:8000/scenarios/list', timeout=10)
        print(f"API Status: {response.status_code}")
        
        if response.status_code == 200:
            data = response.json()
            print(f"API Response: {json.dumps(data, indent=2)}")
            
            scenarios = data.get('scenarios', [])
            print(f"API returned {len(scenarios)} scenarios")
            
            if len(scenarios) > 0:
                print("✅ SUCCESS: API is returning scenarios!")
                print("The Flutter app should now show scenarios.")
                return True
            else:
                print("❌ API returns empty scenario list")
                return False
        else:
            print(f"❌ API error: {response.status_code}")
            return False
            
    except requests.exceptions.RequestException as e:
        print(f"❌ Connection error: {e}")
        print("Make sure backend server is running on localhost:8000")
        return False

if __name__ == "__main__":
    success = add_and_test_scenario()
    
    if success:
        print("\n🎉 SOLUTION SUMMARY:")
        print("1. ✓ Database has scenarios")
        print("2. ✓ API endpoint works")
        print("3. ✓ Ready for Flutter app testing")
        print("\nNext steps:")
        print("- Run Flutter app")
        print("- Check scenario selection screen")
        print("- If still empty, check Flutter debug logs for API connection errors")
    else:
        print("\n❌ Issues found. Check the errors above.")
