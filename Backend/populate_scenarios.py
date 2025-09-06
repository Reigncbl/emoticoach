#!/usr/bin/env python3
"""Script to check scenarios and write results to a file"""
import sys
import os
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from services.scenario import get_available_scenarios
from core.db_connection import engine
from sqlmodel import Session
from model.scenario_with_config import ScenarioWithConfig

def check_and_populate_scenarios():
    results = []
    results.append("=== SCENARIO DATABASE CHECK ===")
    
    try:
        # Check database connection
        with Session(engine) as session:
            results.append("✓ Database connection successful")
            
            # Count scenarios
            count = session.query(ScenarioWithConfig).count()
            results.append(f"✓ Total scenarios in database: {count}")
            
            if count == 0:
                results.append("⚠ Database is empty! Creating sample scenarios...")
                
                # Create sample scenarios
                sample_scenarios = [
                    {
                        "title": "Job Interview Practice",
                        "description": "Practice answering common job interview questions with confidence",
                        "category": "workplace",
                        "difficulty": "intermediate",
                        "estimated_duration": 15,
                        "character_name": "Sarah Chen",
                        "character_description": "An experienced HR manager who conducts professional interviews",
                        "character_config": {
                            "roleplay": {
                                "name": "Sarah Chen",
                                "description": "You are Sarah Chen, an experienced HR manager. You conduct professional interviews and ask thoughtful questions to assess candidates. You are friendly but professional, and provide constructive feedback.",
                                "first_message": "Hello! I'm Sarah Chen, and I'll be conducting your interview today. Please have a seat and tell me a little about yourself."
                            }
                        },
                        "is_active": True,
                        "max_turns": 10
                    },
                    {
                        "title": "Customer Service Challenge",
                        "description": "Handle a difficult customer complaint with empathy and professionalism",
                        "category": "customer_service",
                        "difficulty": "advanced",
                        "estimated_duration": 12,
                        "character_name": "Mark Johnson",
                        "character_description": "A frustrated customer with a legitimate complaint",
                        "character_config": {
                            "roleplay": {
                                "name": "Mark Johnson",
                                "description": "You are Mark Johnson, a customer who is frustrated because your recent order was delayed and arrived damaged. You want a resolution but are initially upset. You can be convinced with good customer service.",
                                "first_message": "I'm really disappointed with my recent order! It arrived three days late and the package was damaged. This is unacceptable!"
                            }
                        },
                        "is_active": True,
                        "max_turns": 8
                    },
                    {
                        "title": "Team Meeting Participation",
                        "description": "Practice speaking up and contributing ideas in a team meeting",
                        "category": "workplace",
                        "difficulty": "beginner",
                        "estimated_duration": 10,
                        "character_name": "Alex Rivera",
                        "character_description": "A team leader facilitating a brainstorming meeting",
                        "character_config": {
                            "roleplay": {
                                "name": "Alex Rivera",
                                "description": "You are Alex Rivera, a team leader running a brainstorming meeting about improving customer satisfaction. You encourage participation and ask for ideas from team members.",
                                "first_message": "Good morning everyone! Today we're brainstorming ways to improve our customer satisfaction scores. I'd love to hear your ideas and thoughts."
                            }
                        },
                        "is_active": True,
                        "max_turns": 12
                    }
                ]
                
                # Insert sample scenarios
                for scenario_data in sample_scenarios:
                    scenario = ScenarioWithConfig(**scenario_data)
                    session.add(scenario)
                
                session.commit()
                results.append(f"✓ Created {len(sample_scenarios)} sample scenarios")
            
            # List all scenarios after potential creation
            all_scenarios = session.query(ScenarioWithConfig).all()
            results.append(f"\nScenarios in database ({len(all_scenarios)}):")
            for scenario in all_scenarios:
                results.append(f"  - ID: {scenario.id}, Title: {scenario.title}, Active: {scenario.is_active}")
                
        # Test service function
        results.append("\n=== TESTING SERVICE FUNCTION ===")
        scenarios = get_available_scenarios()
        results.append(f"✓ get_available_scenarios() returned {len(scenarios)} scenarios")
        
        for scenario in scenarios:
            results.append(f"  - {scenario['title']} (ID: {scenario['id']}, Category: {scenario.get('category', 'unknown')})")
            
        results.append("\n=== RECOMMENDATION ===")
        if len(scenarios) > 0:
            results.append("✓ Database has scenarios! The Flutter app should now show them.")
            results.append("If the Flutter app still shows no scenarios, check:")
            results.append("  1. Network connectivity from Flutter app to backend")
            results.append("  2. API URL configuration in Flutter (currently using 10.0.2.2:8000)")
            results.append("  3. Backend server is running and accessible")
        else:
            results.append("✗ Still no scenarios available. Check database configuration.")
            
    except Exception as e:
        results.append(f"✗ Error: {e}")
        import traceback
        results.append(traceback.format_exc())
    
    # Write results to file
    with open("scenario_check_results.txt", "w") as f:
        f.write("\n".join(results))
    
    print("Results written to scenario_check_results.txt")

if __name__ == "__main__":
    check_and_populate_scenarios()
