import os
import re
import json
import json
import yaml
from datetime import datetime
from typing import Any, Dict, List, Optional
from pydantic import BaseModel
from dotenv import load_dotenv
from llama_index.llms.groq import Groq
from llama_index.core.llms import ChatMessage as LlamaMessage, MessageRole

class ConversationMessage(BaseModel):
    role: str  # "user" or "assistant"
    content: str

class ChatRequest(BaseModel):
    message: str
    conversation_history: Optional[List[ConversationMessage]] = None

class ChatResponse(BaseModel):
    success: bool
    response: Optional[str] = None
    character_name: Optional[str] = None
    error: Optional[str] = None

class EvaluationRequest(BaseModel):
    conversation_history: List[ConversationMessage]

class EvaluationResponse(BaseModel):
    success: bool
    evaluation: Optional[Dict[str, Any]] = None
    user_replies: Optional[List[str]] = None
    total_user_messages: Optional[int] = None
    saved_path: Optional[str] = None
    error: Optional[str] = None

class ConfigResponse(BaseModel):
    success: bool
    character_name: Optional[str] = None
    first_message: Optional[str] = None
    conversation_started: Optional[bool] = None
    error: Optional[str] = None

def load_config() -> Dict[str, Any]:
    """Load the teacher roleplay configuration."""
    try:
        script_dir = os.path.dirname(os.path.abspath(__file__))
        config_path = os.path.join(os.path.dirname(script_dir), "Templates", "teacher_config.yaml")
        
        if not os.path.exists(config_path):
            raise FileNotFoundError(f"Config file not found at: {config_path}")
            
        with open(config_path, "r", encoding="utf-8") as f:
            config = yaml.safe_load(f)
            
        if not config or "roleplay" not in config:
            raise ValueError("Invalid config structure")
            
        return config
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
    """Pure chat function - only handles conversation with AI character."""
    try:
        load_dotenv()
        
        model = os.getenv("model")
        api_key = os.getenv("api_key")
        
        if not model or not api_key:
            return ChatResponse(success=False, error="Missing model or api_key environment variables")
        
        llm = Groq(model=model, api_key=api_key)
        config = load_config()
        character_name = config["roleplay"]["name"]
        
        # Build system prompt with strong roleplay instructions
        system_prompt = f"""
{config["roleplay"]["description"]}

REMINDER: Stay in character as {character_name}. This is a casual chat conversation for emotional coaching practice.
"""
        
        messages = [LlamaMessage(role=MessageRole.SYSTEM, content=system_prompt)]
        
        # Add conversation history if provided
        if request.conversation_history:
            for msg in request.conversation_history:
                role = MessageRole.USER if msg.role == "user" else MessageRole.ASSISTANT
                messages.append(LlamaMessage(role=role, content=msg.content))

        # Add current user message
        messages.append(LlamaMessage(role=MessageRole.USER, content=request.message))
        
        # Get AI response
        response = llm.chat(messages)
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
        config = load_config()
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
        evaluation_record = {
            "evaluation_results": evaluation_data,
            "user_replies": user_replies,
            "total_user_messages": len(user_replies),
            "conversation_context": [{"role": msg.role, "content": msg.content} for msg in request.conversation_history],
            "evaluation_timestamp": datetime.now().isoformat(),
            "character_name": character_name,
            "scenario": "Casual Chat with Professor"
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

async def start_conversation() -> ConfigResponse:
    """Initialize conversation and return character's opening message."""
    try:
        config = load_config()
        
        return ConfigResponse(
            success=True,
            character_name=config["roleplay"]["name"],
            first_message=config["roleplay"]["first_message"],
            conversation_started=True
        )
    
    except Exception as e:
        return ConfigResponse(success=False, error=str(e))


