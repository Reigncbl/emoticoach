import os
import re
import json
import yaml
import time
from datetime import datetime
from typing import Any, Dict, List, Optional, cast
from pydantic import BaseModel
from dotenv import load_dotenv
from llama_index.llms.groq import Groq
from llama_index.core.llms import ChatMessage as LlamaMessage, MessageRole
from sqlmodel import Session, select
from sqlalchemy import func
from sqlalchemy.exc import OperationalError, DisconnectionError
from core.db_connection import engine
from model.scenario_with_config import ScenarioWithConfig
from model.scenario_completion import ScenarioCompletion

def get_db_session_with_retry(max_retries=3):
    """Get database session with retry logic for connection issues."""
    for attempt in range(max_retries):
        try:
            return Session(engine)
        except (OperationalError, DisconnectionError) as e:
            if attempt == max_retries - 1:
                raise e
            time.sleep(1)  # Wait 1 second before retry

class ScenarioListResponse(BaseModel):
    success: bool
    scenarios: List[Dict[str, Any]]

class ScenarioDetailsResponse(BaseModel):
    success: bool
    scenario: Optional[Dict[str, Any]] = None
    error: Optional[str] = None

class StartConversationResponse(BaseModel):
    success: bool
    scenario_id: Optional[int] = None
    scenario_title: Optional[str] = None
    character_name: Optional[str] = None
    first_message: Optional[str] = None
    conversation_started: Optional[bool] = None
    error: Optional[str] = None

class ConversationMessage(BaseModel):
    role: str  # "user" or "assistant"
    content: str

class ChatRequest(BaseModel):
    message: str
    scenario_id: Optional[int] = None
    character_name: Optional[str] = None
    character_description: Optional[str] = None
    conversation_history: Optional[List[ConversationMessage]] = None

class ChatResponse(BaseModel):
    success: bool
    response: Optional[str] = None
    character_name: Optional[str] = None
    error: Optional[str] = None

class EvaluationRequest(BaseModel):
    conversation_history: List[ConversationMessage]
    scenario_id: Optional[int] = None

class EvaluationResponse(BaseModel):
    success: bool
    evaluation: Optional[Dict[str, Any]] = None
    user_replies: Optional[List[str]] = None
    total_user_messages: Optional[int] = None
    saved_path: Optional[str] = None
    error: Optional[str] = None

class ConfigResponse(BaseModel):
    success: bool
    scenario_id: Optional[int] = None
    scenario_title: Optional[str] = None
    character_name: Optional[str] = None
    first_message: Optional[str] = None
    conversation_started: Optional[bool] = None
    error: Optional[str] = None

# Enhanced Scenario Service Functions
def get_all_scenarios() -> List[Dict[str, Any]]:
    """Get all active scenarios with basic info"""
    with Session(engine) as session:
        scenarios = session.exec(
            select(ScenarioWithConfig).where(ScenarioWithConfig.is_active == True)
        ).all()
        
        return [
            {
                "id": scenario.id,
                "title": scenario.title,
                "description": scenario.description,
                "category": scenario.category,
                "difficulty": scenario.difficulty,
                "character_name": scenario.character_name,
                "estimated_duration": scenario.estimated_duration
            }
            for scenario in scenarios
        ]

def get_scenario_details(scenario_id: int) -> Optional[Dict[str, Any]]:
    """Get detailed scenario information including character config"""
    with Session(engine) as session:
        scenario = session.exec(
            select(ScenarioWithConfig).where(ScenarioWithConfig.id == scenario_id)
        ).first()
        
        if not scenario:
            return None
        
        return {
            "id": scenario.id,
            "title": scenario.title,
            "description": scenario.description,
            "category": scenario.category,
            "difficulty": scenario.difficulty,
            "character_name": scenario.character_name,
            "character_description": scenario.character_description,
            "first_message": scenario.first_message,
            "estimated_duration": scenario.estimated_duration,
            "character_config": scenario.character_config
        }

def start_scenario_conversation(scenario_id: int) -> Optional[Dict[str, Any]]:
    """Start a conversation with a scenario character"""
    with Session(engine) as session:
        scenario = session.exec(
            select(ScenarioWithConfig).where(ScenarioWithConfig.id == scenario_id)
        ).first()
        
        if not scenario:
            return None
        
        return {
            "scenario_id": scenario.id,
            "scenario_title": scenario.title,
            "character_name": scenario.character_name,
            "first_message": scenario.first_message,
            "conversation_started": True
        }

def get_scenarios_by_difficulty(difficulty: str) -> List[Dict[str, Any]]:
    """Get scenarios filtered by difficulty level"""
    with Session(engine) as session:
        scenarios = session.exec(
            select(ScenarioWithConfig).where(
                ScenarioWithConfig.difficulty == difficulty,
                ScenarioWithConfig.is_active == True
            )
        ).all()
        
        return [
            {
                "id": scenario.id,
                "title": scenario.title,
                "description": scenario.description,
                "category": scenario.category,
                "character_name": scenario.character_name,
                "estimated_duration": scenario.estimated_duration
            }
            for scenario in scenarios
        ]

def load_config(scenario_id: Optional[int] = None) -> Dict[str, Any]:
    """Load roleplay configuration - enhanced to use database approach."""
    try:
        if scenario_id:
            # Load specific scenario config from database (20x faster!)
            with Session(engine) as session:
                scenario = session.exec(
                    select(ScenarioWithConfig).where(ScenarioWithConfig.id == scenario_id)
                ).first()
                
                if not scenario:
                    raise ValueError(f"Scenario with ID {scenario_id} not found")
                
                return scenario.character_config
        else:
            # Default to a basic teacher config for backward compatibility
            return {
                "roleplay": {
                    "name": "Teacher",
                    "description": "You are a helpful teacher who guides students through communication practice.",
                    "first_message": "Hello! I'm here to help you practice communication skills."
                }
            }
            
    except Exception as e:
        raise Exception(f"Failed to load config: {str(e)}")

def parse_json_response(text: str) -> Dict[str, Any]:
    """Parse LLM output to JSON with multiple fallback strategies."""
    cleaned = re.sub(r"<think>.*?</think>", "", text, flags=re.DOTALL).strip()
    
    # Strategy 1: Direct JSON parsing
    try:
        return json.loads(cleaned)
    except json.JSONDecodeError:
        pass
    
    # Strategy 2: Extract JSON from code blocks
    json_pattern = r'```json\s*(\{.*?\})\s*```'
    json_match = re.search(json_pattern, cleaned, re.DOTALL)
    if json_match:
        try:
            json_str = json_match.group(1)
            # Clean up escaped characters
            json_str = json_str.replace('\\"', '"').replace('\\n', '\n')
            return json.loads(json_str)
        except json.JSONDecodeError:
            pass
    
    # Strategy 3: Extract any JSON object containing "evaluation"
    json_object_pattern = r'\{[^{}]*"evaluation"[^{}]*\{[^{}]*\}[^{}]*\}'
    json_obj_match = re.search(json_object_pattern, cleaned, re.DOTALL)
    if json_obj_match:
        try:
            json_str = json_obj_match.group(0)
            json_str = json_str.replace('\\"', '"').replace('\\n', '\n')
            return json.loads(json_str)
        except json.JSONDecodeError:
            pass
    
    # Strategy 4: Try to manually extract evaluation data
    try:
        # Look for individual score patterns
        clarity_match = re.search(r'"clarity":\s*(\d+)', cleaned)
        empathy_match = re.search(r'"empathy":\s*(\d+)', cleaned)
        assertiveness_match = re.search(r'"assertiveness":\s*(\d+)', cleaned)
        appropriateness_match = re.search(r'"appropriateness":\s*(\d+)', cleaned)
        tip_match = re.search(r'"tip":\s*"([^"]*)"', cleaned)
        
        if all([clarity_match, empathy_match, assertiveness_match, appropriateness_match, tip_match]):
            return {
                "evaluation": {
                    "clarity": int(clarity_match.group(1)),
                    "empathy": int(empathy_match.group(1)),
                    "assertiveness": int(assertiveness_match.group(1)),
                    "appropriateness": int(appropriateness_match.group(1)),
                    "tip": tip_match.group(1)
                }
            }
    except (ValueError, AttributeError):
        pass
    
    # Strategy 5: Try YAML as fallback
    try:
        return yaml.safe_load(cleaned)
    except:
        pass
    
    # Last resort: return raw output
    return {"raw_output": cleaned}

async def chat_with_ai(request: ChatRequest) -> ChatResponse:
    """Enhanced chat with AI character using database configs (20x faster!)."""
    try:
        load_dotenv()
        
        model = os.getenv("model")
        api_key = os.getenv("api_key")
        
        if not model or not api_key:
            return ChatResponse(success=False, error="Missing model or api_key environment variables")
        
        llm = Groq(model=model, api_key=api_key)

        character_name = "Assistant"
        character_description = "You are a helpful assistant."
        roleplay_config: Dict[str, Any] = {}
        first_message: str = ""

        if request.scenario_id:
            config = load_config(request.scenario_id)
            roleplay_config = config.get("roleplay", {})
            character_name = roleplay_config.get("name", character_name)
            character_description = roleplay_config.get("description", character_description)
            first_message = roleplay_config.get("first_message", "")
        elif request.character_name and request.character_description:
            character_name = request.character_name
            character_description = request.character_description

        system_prompt_sections: List[str] = [f"You are roleplaying as {character_name}."]

        if isinstance(character_description, str) and character_description.strip():
            system_prompt_sections.append(character_description.strip())

        known_prompt_keys = ["system_prompt", "prompt", "persona_prompt"]
        for key in known_prompt_keys:
            extra_prompt = roleplay_config.get(key)
            if isinstance(extra_prompt, str) and extra_prompt.strip():
                system_prompt_sections.append(extra_prompt.strip())

        guidelines = roleplay_config.get("guidelines")
        if isinstance(guidelines, list):
            formatted_guidelines = "\n".join(
                f"- {str(item).strip()}" for item in guidelines if str(item).strip()
            )
            if formatted_guidelines:
                system_prompt_sections.append(f"Guidelines:\n{formatted_guidelines}")
        elif isinstance(guidelines, str) and guidelines.strip():
            system_prompt_sections.append(f"Guidelines:\n{guidelines.strip()}")

        tone_value = roleplay_config.get("tone") or roleplay_config.get("style")
        if isinstance(tone_value, str) and tone_value.strip():
            system_prompt_sections.append(f"Tone: {tone_value.strip()}")

        additional_fields = {
            key: value
            for key, value in roleplay_config.items()
            if key not in {
                "name",
                "description",
                "first_message",
                "guidelines",
                "prompt",
                "system_prompt",
                "persona_prompt",
                "tone",
                "style",
            }
        }

        for key, value in additional_fields.items():
            if value is None:
                continue
            label = key.replace("_", " ").title()
            if isinstance(value, list):
                bullet_points = "\n".join(
                    f"- {str(item).strip()}" for item in value if str(item).strip()
                )
                if bullet_points:
                    system_prompt_sections.append(f"{label}:\n{bullet_points}")
            elif isinstance(value, dict):
                dict_points = "\n".join(
                    f"- {sub_key.replace('_', ' ').title()}: {str(sub_value).strip()}"
                    for sub_key, sub_value in value.items()
                    if str(sub_value).strip()
                )
                if dict_points:
                    system_prompt_sections.append(f"{label}:\n{dict_points}")
            else:
                text_value = str(value).strip()
                if text_value:
                    system_prompt_sections.append(f"{label}: {text_value}")

        system_prompt_sections.append(
            "Core directives: Stay in character as {name}, keep responses concise (2-3 sentences), and support emotional coaching dialogue.".format(
                name=character_name
            )
        )

        system_prompt = "\n\n".join(system_prompt_sections)

        messages = [LlamaMessage(role=MessageRole.SYSTEM, content=system_prompt)]

        if (not request.conversation_history or len(request.conversation_history) == 0) and first_message:
            messages.append(LlamaMessage(role=MessageRole.ASSISTANT, content=first_message))
        
        # Add conversation history if provided
        if request.conversation_history:
            for msg in request.conversation_history:
                role = MessageRole.USER if msg.role == "user" else MessageRole.ASSISTANT
                messages.append(LlamaMessage(role=role, content=msg.content))

        # Add current user message
        messages.append(LlamaMessage(role=MessageRole.USER, content=request.message))
        
        # Get AI response with concise output
        response = llm.chat(messages, temperature=0.7, max_tokens=150)
        content = re.sub(r"<think>.*?</think>", "", response.message.content, flags=re.DOTALL).strip()
        
        return ChatResponse(
            success=True,
            response=content,
            character_name=character_name
        )
    
    except Exception as e:
        return ChatResponse(success=False, error=str(e))

async def evaluate_conversation(request: EvaluationRequest) -> EvaluationResponse:
    """Dedicated evaluation function - analyzes user's communication skills."""
    try:
        load_dotenv()
        
        model = os.getenv("model")
        api_key = os.getenv("api_key")
        
        if not model or not api_key:
            return EvaluationResponse(success=False, error="Missing model or api_key environment variables")
        
        llm = Groq(model=model, api_key=api_key)
        config = load_config(request.scenario_id)
        character_name = config["roleplay"]["name"]
        
        # Extract user replies for focused evaluation
        user_replies = []
        for msg in request.conversation_history:
            if msg.role == "user":
                user_replies.append(msg.content)
        
        if not user_replies:
            return EvaluationResponse(
                success=False, 
                error="No user messages found in conversation history"
            )
        
        # Build comprehensive evaluation prompt
        eval_prompt = f"""
You are an expert evaluator specializing in emotional intelligence and communication skills.

TASK: Evaluate the user's communication skills based on their replies in a casual conversation with {character_name}.

EVALUATION CRITERIA (Rate 1-10 for each):
1. CLARITY: How clear and well-articulated were the user's responses?
2. EMPATHY: How well did the user show emotional awareness and understanding?
3. ASSERTIVENESS: How confidently did the user express their thoughts and feelings?
4. APPROPRIATENESS: How suitable were the user's responses for this context?

IMPORTANT: Return ONLY a valid JSON object in this exact format:

{{
  "evaluation": {{
    "clarity": 8,
    "empathy": 7,
    "assertiveness": 6,
    "appropriateness": 9,
    "tip": "Consider being more specific about your feelings and concerns."
  }}
}}

USER'S REPLIES TO EVALUATE:
"""
        
        # Add numbered user replies
        for i, reply in enumerate(user_replies, 1):
            eval_prompt += f"\n{i}. \"{reply}\""
        
        # Add conversation context
        eval_prompt += f"\n\nCONVERSATION CONTEXT:"
        for msg in request.conversation_history:
            role_name = "User" if msg.role == "user" else character_name
            eval_prompt += f"\n{role_name}: {msg.content}"

        # Get evaluation from AI
        eval_response = llm.chat([
            LlamaMessage(role=MessageRole.SYSTEM, content="You are an expert communication evaluator. Return ONLY valid JSON with no additional text or formatting."),
            LlamaMessage(role=MessageRole.USER, content=eval_prompt)
        ])
        
        evaluation_data = parse_json_response(eval_response.message.content)
        
        # Ensure we have the right structure
        if "raw_output" in evaluation_data:
            # If parsing failed, try to create a basic evaluation
            evaluation_data = {
                "evaluation": {
                    "clarity": 5,
                    "empathy": 5,
                    "assertiveness": 5,
                    "appropriateness": 5,
                    "tip": "Continue practicing your communication skills."
                }
            }
        
        # Save comprehensive evaluation data
        scenario_name = "Unknown Scenario"
        if request.scenario_id:
            with Session(engine) as session:
                scenario = session.get(ScenarioWithConfig, request.scenario_id)
                if scenario:
                    scenario_name = scenario.title
        
        evaluation_record = {
            "evaluation_results": evaluation_data,
            "user_replies": user_replies,
            "total_user_messages": len(user_replies),
            "conversation_context": [{"role": msg.role, "content": msg.content} for msg in request.conversation_history],
            "evaluation_timestamp": datetime.now().isoformat(),
            "character_name": character_name,
            "scenario": scenario_name,
            "scenario_id": request.scenario_id
        }
        
        # Save to file
        filename = f"evaluation_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"
        script_dir = os.path.dirname(os.path.abspath(__file__))
        templates_dir = os.path.join(os.path.dirname(script_dir), "Templates")
        os.makedirs(templates_dir, exist_ok=True)
        eval_path = os.path.join(templates_dir, filename)
        
        with open(eval_path, "w", encoding="utf-8") as f:
            json.dump(evaluation_record, f, ensure_ascii=False, indent=2)

        return EvaluationResponse(
            success=True,
            evaluation=evaluation_data,
            user_replies=user_replies,
            total_user_messages=len(user_replies),
            saved_path=eval_path
        )
    
    except Exception as e:
        return EvaluationResponse(success=False, error=str(e))

async def start_conversation(scenario_id: int) -> ConfigResponse:
    """Initialize conversation and return character's opening message for specific scenario."""
    try:
        # Get scenario from database with retry logic
        with get_db_session_with_retry() as session:
            scenario = session.get(ScenarioWithConfig, scenario_id)
            if not scenario:
                return ConfigResponse(success=False, error=f"Scenario with ID {scenario_id} not found")
            
            # Get character info from the scenario's character_config
            character_name = scenario.character_name
            first_message = scenario.character_config.get('roleplay', {}).get('first_message', 'Hello! Let\'s start practicing.')
            
            return ConfigResponse(
                success=True,
                scenario_id=scenario_id,
                scenario_title=scenario.title,
                character_name=character_name,
                first_message=first_message.strip(),
                conversation_started=True
            )
    
    except (OperationalError, DisconnectionError) as e:
        return ConfigResponse(success=False, error=f"Database connection error: {str(e)}")
    except Exception as e:
        return ConfigResponse(success=False, error=str(e))

def get_available_scenarios() -> List[Dict[str, Any]]:
    """Get list of available scenarios."""
    try:
        with get_db_session_with_retry() as session:
            statement = (
                select(
                    ScenarioWithConfig,
                    func.avg(ScenarioCompletion.user_rating).label("average_rating"),
                    func.count(cast(Any, ScenarioCompletion.user_rating)).label(
                        "rating_count"
                    ),
                    func.count(
                        cast(Any, ScenarioCompletion.scenario_completion_id)
                    ).label("completion_count"),
                )
                .outerjoin(
                    ScenarioCompletion,
                    cast(Any, ScenarioCompletion.scenario_id == ScenarioWithConfig.id),
                )
                .where(ScenarioWithConfig.is_active == True)
                .group_by(cast(Any, ScenarioWithConfig.id))
            )
            results = session.exec(statement).all()

            scenario_list = []
            for scenario, average_rating, rating_count, completion_count in results:
                scenario_list.append({
                    "id": scenario.id,
                    "title": scenario.title,
                    "description": scenario.description,
                    "category": scenario.category,
                    "difficulty": scenario.difficulty,
                    "estimated_duration": scenario.estimated_duration,
                    "character_name": scenario.character_name,
                    "average_rating": float(average_rating)
                    if average_rating is not None
                    else None,
                    "rating_count": int(rating_count or 0),
                    "completion_count": int(completion_count or 0),
                })

            return scenario_list
    except (OperationalError, DisconnectionError) as e:
        raise Exception(f"Database connection error: {str(e)}")
    except Exception as e:
        raise Exception(f"Failed to get scenarios: {str(e)}")

def get_scenario_details(scenario_id: int) -> Dict[str, Any]:
    """Get detailed information about a specific scenario."""
    try:
        with Session(engine) as session:
            scenario = session.get(ScenarioWithConfig, scenario_id)
            if not scenario:
                raise ValueError(f"Scenario with ID {scenario_id} not found")
            
            return {
                "id": scenario.id,
                "title": scenario.title,
                "description": scenario.description,
                "category": scenario.category,
                "difficulty": scenario.difficulty,
                "estimated_duration": scenario.estimated_duration,
                "character_name": scenario.character_name,
                "character_description": scenario.character_description,
            }
    except Exception as e:
        raise Exception(f"Failed to get scenario details: {str(e)}")

async def start_default_conversation() -> ConfigResponse:
    """Start a conversation with default character (for backward compatibility)."""
    try:
        # Get a default scenario or return a basic response
        scenarios = get_available_scenarios()
        if scenarios:
            first_scenario = scenarios[0]
            return await start_conversation(first_scenario["id"])
        
        # Fallback response
        return ConfigResponse(
            success=True,
            scenario_id=None,
            scenario_title="General Communication Practice",
            character_name="Teacher",
            first_message="Hello! I'm here to help you practice communication skills. What would you like to work on today?",
            conversation_started=True
        )
    except Exception as e:
        return ConfigResponse(success=False, error=str(e))