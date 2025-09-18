from fastapi import APIRouter, HTTPException, UploadFile, File
from sqlmodel import select
from pydantic import BaseModel
from model.readingsinfo import ReadingsInfo
from model.readingblock import ReadingBlock
from core.db_connection import SessionDep
from core.supabase_config import SupabaseStorage
from model.scenario_with_config import ScenarioWithConfig
from services.scenario import (
    chat_with_ai, 
    evaluate_conversation,
    start_conversation,
    get_available_scenarios,
    get_scenario_details,
    ChatRequest, 
    ChatResponse,
    EvaluationRequest,
    EvaluationResponse,
    ConfigResponse
)

class CreateScenarioRequest(BaseModel):
    title: str
    description: str
    category: str
    difficulty: str = "beginner"
    estimated_duration: int = 10
    config_file: str
    yaml_content: str


scenario_router = APIRouter(prefix="/scenarios",tags=["Scenarios"])

@scenario_router.get('/start/{scenario_id}', response_model=ConfigResponse)
async def start(scenario_id: int):
    """
    Start a new conversation with the AI character for a specific scenario.
    
    Returns the character's opening message to begin the conversation.
    """
    try:
        response = await start_conversation(scenario_id)
        if not response.success:
            raise HTTPException(status_code=500, detail=response.error)
        return response
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@scenario_router.post('/chat', response_model=ChatResponse)
async def chat(request: ChatRequest):
    """
    Chat with AI character for emotional coaching scenarios.
    
    - **message**: User's message to send to the AI
    - **conversation_history**: Optional previous conversation messages
    
    Pure chat functionality - no automatic evaluation.
    """
    try:
        response = await chat_with_ai(request)
        if not response.success:
            raise HTTPException(status_code=500, detail=response.error)
        return response
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@scenario_router.post('/check-flow')
async def check_conversation_flow(request: ChatRequest):
    """
    Check if conversation should naturally end based on flow analysis.
    
    - **conversation_history**: Current conversation to analyze
    - **scenario_id**: ID of the current scenario
    
    Returns analysis of conversation flow and ending recommendations.
    """
    try:
        from services.conversation_tracker import should_end_conversation
        from services.scenario import load_config
        
        if not request.conversation_history:
            raise HTTPException(status_code=400, detail="Conversation history required")
        
        # Convert to dict format for analysis
        conversation_dict = [
            {"role": msg.role, "content": msg.content} 
            for msg in request.conversation_history
        ]
        
        # Load scenario config
        config = load_config(request.scenario_id) if request.scenario_id else {}
        
        # Analyze conversation flow
        analysis = await should_end_conversation(conversation_dict, config)
        
        return {
            "success": True,
            "should_end": analysis.should_end,
            "confidence": analysis.confidence,
            "reason": analysis.reason,
            "suggested_ending_message": analysis.suggested_ending_message,
            "conversation_quality": analysis.conversation_quality
        }
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@scenario_router.post('/evaluate', response_model=EvaluationResponse)
async def evaluate(request: EvaluationRequest):
    """
    Evaluate user's communication skills from a conversation.
    
    - **conversation_history**: Complete conversation history to analyze
    
    Analyzes user replies on: Clarity, Empathy, Assertiveness, Appropriateness.
    Provides scores (1-10) and improvement tip.
    """
    try:
        response = await evaluate_conversation(request)
        if not response.success:
            raise HTTPException(status_code=500, detail=response.error)
        return response
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@scenario_router.get('/list')
async def list_scenarios():
    """
    Get list of available scenarios.
    
    Returns all active scenarios with basic information.
    """
    try:
        scenarios = get_available_scenarios()
        return {"success": True, "scenarios": scenarios}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@scenario_router.get('/details/{scenario_id}')
async def get_details(scenario_id: int):
    """
    Get detailed information about a specific scenario.
    
    Returns comprehensive scenario details including character info.
    """
    try:
        details = get_scenario_details(scenario_id)
        return {"success": True, "scenario": details}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@scenario_router.post('/create')
async def create_scenario(request: CreateScenarioRequest, session: SessionDep):
    """
    Create a new scenario with YAML configuration.
    
    - **title**: Scenario title
    - **description**: Scenario description
    - **category**: Category (workplace, family, friendship, social, etc.)
    - **difficulty**: beginner, intermediate, or advanced
    - **estimated_duration**: Estimated time in minutes
    - **config_file**: YAML filename (should end with .yaml)
    - **yaml_content**: Complete YAML configuration content
    """
    try:
        # Validate YAML filename
        if not request.config_file.endswith('.yaml'):
            raise HTTPException(status_code=400, detail="Config file must be a .yaml file")
        
        # Upload YAML to Supabase Storage
        storage = SupabaseStorage()
        upload_success = storage.upload_yaml(request.config_file, request.yaml_content)
        
        if not upload_success:
            raise HTTPException(status_code=500, detail="Failed to upload YAML configuration")
        
        # Parse YAML content to get character config
        import yaml
        try:
            yaml_config = yaml.safe_load(request.yaml_content)
        except yaml.YAMLError:
            raise HTTPException(status_code=400, detail="Invalid YAML content")
        
        # Create scenario record in database
        scenario = ScenarioWithConfig(
            title=request.title,
            description=request.description,
            category=request.category,
            difficulty=request.difficulty,
            estimated_duration=request.estimated_duration,
            character_config=yaml_config
        )
        
        session.add(scenario)
        session.commit()
        session.refresh(scenario)
        
        return {
            "success": True,
            "message": "Scenario created successfully",
            "scenario_id": scenario.id,
            "config_uploaded": True
        }
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@scenario_router.post('/upload-yaml')
async def upload_yaml_file(file: UploadFile = File(...)):
    """
    Upload a YAML configuration file to Supabase Storage.
    
    - **file**: YAML file to upload
    
    Returns the filename and upload status.
    """
    try:
        # Validate file type
        if not file.filename.endswith('.yaml') and not file.filename.endswith('.yml'):
            raise HTTPException(status_code=400, detail="File must be a YAML file (.yaml or .yml)")
        
        # Read file content
        content = await file.read()
        yaml_content = content.decode('utf-8')
        
        # Upload to Supabase Storage
        storage = SupabaseStorage()
        upload_success = storage.upload_yaml(file.filename, yaml_content)
        
        if not upload_success:
            raise HTTPException(status_code=500, detail="Failed to upload file to storage")
        
        return {
            "success": True,
            "message": "YAML file uploaded successfully",
            "filename": file.filename,
            "size": len(content)
        }
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
