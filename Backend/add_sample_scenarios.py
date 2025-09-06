import json
from sqlmodel import Session, SQLModel
from core.db_connection import engine
from model.scenario_with_config import ScenarioWithConfig

# Create the tables
SQLModel.metadata.create_all(engine)

import json
from sqlmodel import Session, SQLModel
from core.db_connection import engine
from model.scenario_with_config import ScenarioWithConfig

# Create the tables
SQLModel.metadata.create_all(engine)

# Sample scenarios to insert (using your provided format)
scenarios = [
    {
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
    },
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
                "description": "You are an experienced HR manager conducting interviews.",
                "first_message": "Hello! I'm Sarah Chen. Please tell me about yourself."
            }
        },
        "is_active": True,
        "max_turns": 10
    },
    {
        "title": "Customer Service Challenge", 
        "description": "Handle a difficult customer complaint professionally",
        "category": "customer_service",
        "difficulty": "advanced",
        "estimated_duration": 12,
        "character_name": "Mark Johnson", 
        "character_description": "A frustrated customer",
        "character_config": {
            "roleplay": {
                "name": "Mark Johnson",
                "description": "You are a frustrated customer with a complaint.",
                "first_message": "I'm really disappointed with my order! It was damaged!"
            }
        },
        "is_active": True,
        "max_turns": 8
    },
    {
        "title": "Team Meeting Participation",
        "description": "Practice contributing ideas in team meetings", 
        "category": "workplace",
        "difficulty": "beginner",
        "estimated_duration": 10,
        "character_name": "Alex Rivera",
        "character_description": "A team leader",
        "character_config": {
            "roleplay": {
                "name": "Alex Rivera", 
                "description": "You are a team leader facilitating a meeting.",
                "first_message": "Good morning! Let's brainstorm ways to improve customer satisfaction."
            }
        },
        "is_active": True,
        "max_turns": 12
    }
]

# Insert scenarios
with Session(engine) as session:
    # Check if scenarios already exist
    existing_count = session.query(ScenarioWithConfig).count()
    print(f"Existing scenarios: {existing_count}")
    
    if existing_count == 0:
        print("Adding sample scenarios...")
        for scenario_data in scenarios:
            scenario = ScenarioWithConfig(**scenario_data)
            session.add(scenario)
        
        session.commit()
        print(f"Added {len(scenarios)} scenarios")
    else:
        print("Scenarios already exist")
    
    # Verify scenarios
    all_scenarios = session.query(ScenarioWithConfig).all()
    print(f"Total scenarios now: {len(all_scenarios)}")
    
    for s in all_scenarios:
        print(f"- {s.id}: {s.title} ({s.category}) - Active: {s.is_active}")

print("Done!")
