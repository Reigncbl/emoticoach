from fastapi import APIRouter, HTTPException, UploadFile, File
from sqlmodel import select, desc
from pydantic import BaseModel
from model.readingsinfo import ReadingsInfo
from model.readingblock import ReadingBlock
from model.scenario_completion import ScenarioCompletion
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
from typing import Optional
from datetime import datetime

class CreateScenarioRequest(BaseModel):
    title: str
    description: str
    category: str
    difficulty: str = "beginner"
    estimated_duration: int = 10
    config_file: str
    yaml_content: str

class CompleteScenarioRequest(BaseModel):
    user_id: str
    scenario_id: int
    completion_time_minutes: Optional[int] = None
    final_clarity_score: Optional[int] = None
    final_empathy_score: Optional[int] = None
    final_assertiveness_score: Optional[int] = None
    final_appropriateness_score: Optional[int] = None
    user_rating: Optional[int] = None
    total_messages: Optional[int] = None


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

@scenario_router.post('/complete')
async def complete_scenario(request: CompleteScenarioRequest, session: SessionDep):
    """
    Mark a scenario as completed by a user.
    
    Saves completion data including scores and metrics.
    """
    try:
        # Check if user already completed this scenario
        existing_completion = session.exec(
            select(ScenarioCompletion)
            .where(ScenarioCompletion.user_id == request.user_id)
            .where(ScenarioCompletion.scenario_id == request.scenario_id)
        ).first()
        
        if existing_completion:
            # Update existing completion with new scores
            existing_completion.completion_time_minutes = request.completion_time_minutes
            existing_completion.final_clarity_score = request.final_clarity_score
            existing_completion.final_empathy_score = request.final_empathy_score
            existing_completion.final_assertiveness_score = request.final_assertiveness_score
            existing_completion.final_appropriateness_score = request.final_appropriateness_score
            existing_completion.user_rating = request.user_rating
            existing_completion.total_messages = request.total_messages
            existing_completion.completed_at = datetime.utcnow()
            
            session.commit()
            session.refresh(existing_completion)
            
            return {
                "success": True,
                "message": "Scenario completion updated successfully",
                "completion_id": existing_completion.id,
                "is_repeat": True
            }
        else:
            # Create new completion record
            completion = ScenarioCompletion(
                user_id=request.user_id,
                scenario_id=request.scenario_id,
                completion_time_minutes=request.completion_time_minutes,
                final_clarity_score=request.final_clarity_score,
                final_empathy_score=request.final_empathy_score,
                final_assertiveness_score=request.final_assertiveness_score,
                final_appropriateness_score=request.final_appropriateness_score,
                user_rating=request.user_rating,
                total_messages=request.total_messages
            )
            
            session.add(completion)
            session.commit()
            session.refresh(completion)
            
            return {
                "success": True,
                "message": "Scenario completed successfully",
                "completion_id": completion.id,
                "is_repeat": False
            }
            
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@scenario_router.get('/completed/{user_id}')
async def get_completed_scenarios(user_id: str, session: SessionDep):
    """
    Get all completed scenarios for a user.
    
    Returns list of completed scenarios with completion stats.
    """
    try:
        # Get completed scenarios with scenario details
        completed_query = (
            select(ScenarioCompletion, ScenarioWithConfig)
            .join(ScenarioWithConfig)
            .where(ScenarioCompletion.user_id == user_id)
            .where(ScenarioCompletion.scenario_id == ScenarioWithConfig.id)
            .order_by(desc(ScenarioCompletion.completed_at))
        )
        
        results = session.exec(completed_query).all()
        
        completed_scenarios = []
        for completion, scenario in results:
            # Calculate average score
            scores = [
                completion.final_clarity_score,
                completion.final_empathy_score,
                completion.final_assertiveness_score,
                completion.final_appropriateness_score
            ]
            valid_scores = [s for s in scores if s is not None]
            avg_score = sum(valid_scores) / len(valid_scores) if valid_scores else None
            
            completed_scenarios.append({
                "scenario_id": scenario.id,
                "title": scenario.title,
                "description": scenario.description,
                "category": scenario.category,
                "difficulty": scenario.difficulty,
                "estimated_duration": scenario.estimated_duration,
                "completed_at": completion.completed_at.isoformat(),
                "completion_time_minutes": completion.completion_time_minutes,
                "final_clarity_score": completion.final_clarity_score,
                "final_empathy_score": completion.final_empathy_score,
                "final_assertiveness_score": completion.final_assertiveness_score,
                "final_appropriateness_score": completion.final_appropriateness_score,
                "average_score": avg_score,
                "user_rating": completion.user_rating,
                "total_messages": completion.total_messages,
                "completion_count": 1  # For now, just 1. Can be enhanced to count multiple attempts
            })
            
        return {
            "success": True,
            "completed_scenarios": completed_scenarios,
            "total_completed": len(completed_scenarios)
        }
        
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
