import json
import sys
import os
from sqlmodel import Session, SQLModel, select
from core.db_connection import engine
from model.scenario_with_config import ScenarioWithConfig

def add_scenarios():
    results = []
    
    try:
        # Create the tables
        SQLModel.metadata.create_all(engine)
        results.append("✓ Database tables created/verified")
        
        # Check if scenarios already exist
        with Session(engine) as session:
            existing_count = len(session.exec(select(ScenarioWithConfig)).all())
            results.append(f"Existing scenarios in database: {existing_count}")
            
            if existing_count == 0:
                # Sample scenario using your provided format
                scenario_data = {
                    "title": "Handling Workplace Criticism",
                    "description": "Learn to respond constructively to criticism from a colleague without getting defensive",
                    "category": "workplace",
                    "difficulty": "beginner",
                    "estimated_duration": 8,
                    "character_name": "Alex",
                    "character_description": "A direct and sometimes blunt colleague who works on the same team",
                    "character_config": {
                        "roleplay": {
                            "name": "Alex",
                            "description": "You are Alex, a direct and sometimes blunt colleague who works on the same team. You care about the project's success but tend to be critical when you see potential problems.\n\nPERSONALITY:\n- Direct and straightforward in communication\n- Sometimes comes across as harsh but means well\n- Values efficiency and practical solutions\n- Gets frustrated with approaches that seem risky or unproven\n- Willing to speak up when concerned about project direction\n- Respected team member with good technical judgment\n\nCOMMUNICATION STYLE:\n- Speaks plainly and directly\n- Doesn't sugarcoat concerns or criticism\n- Uses professional but firm language\n- Backs up opinions with logical reasoning\n- Can be persistent when convinced something is wrong\n- Expects others to defend their ideas with facts\n\nSCENARIO CONTEXT:\nYou've just reviewed your colleague's project proposal and have identified several issues that concern you. The approach seems risky and you're not convinced it will work given the timeline and resources available. You want to express your concerns clearly and get them to reconsider their approach.\n\nSPECIFIC CONCERNS:\n- The proposed timeline seems too aggressive for the complexity involved\n- The technical approach has potential failure points that aren't addressed\n- Similar approaches have failed in other projects you've seen\n- You think a more conservative, proven approach would be safer\n\nRULES:\n- Be direct but professional in expressing concerns\n- Focus on project success, not personal criticism\n- Use specific examples when possible\n- Be open to hearing their reasoning\n- Show that you want the project to succeed\n- Don't back down easily if you believe you're right\n\nRemember: You're being critical because you care about the project's success, not to be difficult.",
                            "first_message": "I've looked at your proposal and I have to say, I'm not convinced this approach will work. There are several issues I can see right away that concern me."
                        }
                    },
                    "is_active": True,
                    "max_turns": 8
                }
                
                # Create scenario object
                scenario = ScenarioWithConfig(**scenario_data)
                session.add(scenario)
                session.commit()
                results.append("✓ Added 'Handling Workplace Criticism' scenario")
                
                # Add a few more scenarios for variety
                additional_scenarios = [
                    {
                        "title": "Job Interview Practice",
                        "description": "Practice answering common job interview questions with confidence",
                        "category": "workplace",
                        "difficulty": "intermediate", 
                        "estimated_duration": 15,
                        "character_name": "Sarah Chen",
                        "character_description": "An experienced HR manager",
                        "character_config": {
                            "roleplay": {
                                "name": "Sarah Chen",
                                "description": "You are Sarah Chen, an experienced HR manager who conducts professional interviews. You ask thoughtful questions and provide constructive feedback.",
                                "first_message": "Hello! I'm Sarah Chen, and I'll be conducting your interview today. Please have a seat and tell me a little about yourself."
                            }
                        },
                        "is_active": True,
                        "max_turns": 10
                    },
                    {
                        "title": "Customer Complaint Resolution",
                        "description": "Handle a difficult customer complaint with empathy and professionalism",
                        "category": "customer_service",
                        "difficulty": "advanced",
                        "estimated_duration": 12,
                        "character_name": "Mark Johnson",
                        "character_description": "A frustrated customer with a legitimate complaint",
                        "character_config": {
                            "roleplay": {
                                "name": "Mark Johnson",
                                "description": "You are Mark Johnson, a customer who is frustrated because your recent order was delayed and arrived damaged. You want a resolution but are initially upset.",
                                "first_message": "I'm really disappointed with my recent order! It arrived three days late and the package was damaged. This is unacceptable!"
                            }
                        },
                        "is_active": True,
                        "max_turns": 8
                    }
                ]
                
                for additional_scenario in additional_scenarios:
                    scenario_obj = ScenarioWithConfig(**additional_scenario)
                    session.add(scenario_obj)
                
                session.commit()
                results.append(f"✓ Added {len(additional_scenarios)} additional scenarios")
            else:
                results.append("Scenarios already exist, skipping creation")
            
            # Verify final count
            final_count = len(session.exec(select(ScenarioWithConfig)).all())
            results.append(f"Total scenarios in database: {final_count}")
            
            # List all scenarios
            scenarios = session.exec(select(ScenarioWithConfig)).all()
            results.append("\nScenarios in database:")
            for scenario in scenarios:
                results.append(f"  - ID: {scenario.id}, Title: {scenario.title}, Active: {scenario.is_active}")
        
        results.append("\n✓ SUCCESS: Database populated with scenarios!")
        results.append("The Flutter app should now show these scenarios.")
        
    except Exception as e:
        results.append(f"✗ ERROR: {e}")
        import traceback
        results.append(traceback.format_exc())
    
    # Write results to file
    with open("scenario_creation_log.txt", "w", encoding="utf-8") as f:
        f.write("\n".join(results))
    
    return results

if __name__ == "__main__":
    results = add_scenarios()
    print("Scenario creation completed. Check scenario_creation_log.txt for details.")
    for result in results:
        print(result)
