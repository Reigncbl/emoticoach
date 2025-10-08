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
from uuid import uuid4
import logging
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


class ScenarioCompletionResponse(BaseModel):
    scenario_completion_id: str
    user_id: str
    scenario_id: int
    completed_at: datetime
    completion_time_minutes: Optional[int] = None
    clarity_score: Optional[int] = None
    empathy_score: Optional[int] = None
    assertiveness_score: Optional[int] = None
    appropriateness_score: Optional[int] = None
    user_rating: Optional[int] = None
    total_messages: Optional[int] = None
    created_at: datetime

    class Config:
        from_attributes = True
        
    @classmethod
    def from_scenario_completion(cls, completion: ScenarioCompletion):
        """Convert ScenarioCompletion to response model with proper type conversion"""
        return cls(
            scenario_completion_id=str(completion.scenario_completion_id),  # Ensure string conversion
            user_id=completion.user_id,
            scenario_id=completion.scenario_id,
            completed_at=completion.completed_at,
            completion_time_minutes=completion.completion_time_minutes,
            clarity_score=completion.clarity_score,
            empathy_score=completion.empathy_score,
            assertiveness_score=completion.assertiveness_score,
            appropriateness_score=completion.appropriateness_score,
            user_rating=completion.user_rating,
            total_messages=completion.total_messages,
            created_at=completion.created_at
        )


logger = logging.getLogger(__name__)
scenario_router = APIRouter(prefix="/scenarios", tags=["Scenarios"])


@scenario_router.get('/start/{scenario_id}', response_model=ConfigResponse)
async def start(scenario_id: int):
    try:
        response = await start_conversation(scenario_id)
        if not response.success:
            raise HTTPException(status_code=500, detail=response.error)
        return response
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@scenario_router.post('/chat', response_model=ChatResponse)
async def chat(request: ChatRequest):
    try:
        response = await chat_with_ai(request)
        if not response.success:
            raise HTTPException(status_code=500, detail=response.error)
        return response
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@scenario_router.post('/check-flow')
async def check_conversation_flow(request: ChatRequest):
    try:
        from services.conversation_tracker import should_end_conversation
        from services.scenario import load_config

        if not request.conversation_history:
            raise HTTPException(status_code=400, detail="Conversation history required")

        conversation_dict = [
            {"role": msg.role, "content": msg.content}
            for msg in request.conversation_history
        ]

        config = load_config(request.scenario_id) if request.scenario_id else {}

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
    try:
        response = await evaluate_conversation(request)
        if not response.success:
            raise HTTPException(status_code=500, detail=response.error)
        return response
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@scenario_router.get('/list')
async def list_scenarios():
    try:
        scenarios = get_available_scenarios()
        return {"success": True, "scenarios": scenarios}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@scenario_router.get('/details/{scenario_id}')
async def get_details(scenario_id: int):
    try:
        details = get_scenario_details(scenario_id)
        return {"success": True, "scenario": details}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@scenario_router.post('/complete')
async def complete_scenario(request: CompleteScenarioRequest, session: SessionDep):
    try:
        # Log incoming request payload
        try:
            req_payload = request.model_dump() if hasattr(request, "model_dump") else request.dict()
        except Exception:
            req_payload = str(request)
        logger.info(f"[scenarios.complete] incoming payload: {req_payload}")
        # Check if completion already exists
        existing_completion = session.exec(
            select(ScenarioCompletion).where(
                ScenarioCompletion.user_id == request.user_id,
                ScenarioCompletion.scenario_id == request.scenario_id
            )
        ).first()
        
        if existing_completion:
            # Update existing completion instead of throwing error (similar to reading progress upsert)
            # Only overwrite values if they are provided; otherwise keep existing values
            if request.completion_time_minutes is not None:
                existing_completion.completion_time_minutes = request.completion_time_minutes
            if request.final_clarity_score is not None:
                existing_completion.clarity_score = request.final_clarity_score
            if request.final_empathy_score is not None:
                existing_completion.empathy_score = request.final_empathy_score
            if request.final_assertiveness_score is not None:
                existing_completion.assertiveness_score = request.final_assertiveness_score
            if request.final_appropriateness_score is not None:
                existing_completion.appropriateness_score = request.final_appropriateness_score
            if request.user_rating is not None:
                existing_completion.user_rating = request.user_rating
            if request.total_messages is not None:
                existing_completion.total_messages = request.total_messages
            existing_completion.completed_at = datetime.utcnow()  # Update completion time
            completion = existing_completion
            operation = "updated"
        else:
            # Create new completion record - same pattern as ReadingProgress
            # UID is auto-generated here, not provided by user
            completion = ScenarioCompletion(
                scenario_completion_id=str(uuid4()),  # Auto-generated UID
                user_id=request.user_id,
                scenario_id=request.scenario_id,
                # Default numeric fields to 0 if not provided
                completion_time_minutes=(0 if request.completion_time_minutes is None else request.completion_time_minutes),
                clarity_score=(0 if request.final_clarity_score is None else request.final_clarity_score),
                empathy_score=(0 if request.final_empathy_score is None else request.final_empathy_score),
                assertiveness_score=(0 if request.final_assertiveness_score is None else request.final_assertiveness_score),
                appropriateness_score=(0 if request.final_appropriateness_score is None else request.final_appropriateness_score),
                user_rating=(0 if request.user_rating is None else request.user_rating),
                total_messages=(0 if request.total_messages is None else request.total_messages),
                completed_at=datetime.utcnow()
            )
            session.add(completion)
            operation = "created"

        session.commit()
        session.refresh(completion)

        # Post-commit sanity logs
        try:
            same_user_rows = session.exec(
                select(ScenarioCompletion).where(
                    ScenarioCompletion.user_id == request.user_id
                )
            ).all()
            same_user_same_scenario_rows = [
                r for r in same_user_rows if r.scenario_id == request.scenario_id
            ]
            logger.info(
                f"[scenarios.complete] op={operation} id={completion.scenario_completion_id} "
                f"user={completion.user_id} scenario={completion.scenario_id} "
                f"user_rows={len(same_user_rows)} user_scenario_rows={len(same_user_same_scenario_rows)}"
            )
        except Exception:
            logger.warning("[scenarios.complete] post-commit logging failed")

        return {
            "success": True,
            "message": "Scenario completion saved successfully",
            "operation": operation,
            "completed_scenarios": ScenarioCompletionResponse.from_scenario_completion(completion)  # Use custom conversion
        }
    except HTTPException:
        raise
    except Exception as e:
        logger.exception("[scenarios.complete] error")
        raise HTTPException(status_code=500, detail=str(e))

@scenario_router.get('/completed/{user_id}')
async def get_completed_scenarios(user_id: str, session: SessionDep):
    try:
        completed_scenarios = session.exec(
            select(ScenarioCompletion)
            .where(ScenarioCompletion.user_id == user_id)
            .order_by(desc(ScenarioCompletion.completed_at))
        ).all()

        completion_responses = [
            ScenarioCompletionResponse.from_scenario_completion(completion)
            for completion in completed_scenarios
        ]

        return {
            "success": True,
            "completed_scenarios": completion_responses,
            "total": len(completion_responses)
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@scenario_router.post('/create')
async def create_scenario(request: CreateScenarioRequest, session: SessionDep):
    try:
        if not request.config_file.endswith('.yaml'):
            raise HTTPException(status_code=400, detail="Config file must be a .yaml file")

        storage = SupabaseStorage()
        upload_success = storage.upload_yaml(request.config_file, request.yaml_content)

        if not upload_success:
            raise HTTPException(status_code=500, detail="Failed to upload YAML configuration")

        import yaml
        try:
            yaml_config = yaml.safe_load(request.yaml_content)
        except yaml.YAMLError:
            raise HTTPException(status_code=400, detail="Invalid YAML content")

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
    try:
        # Validate filename presence and extension
        if not file.filename:
            raise HTTPException(status_code=400, detail="Missing filename")
        fname = file.filename
        if not fname.lower().endswith('.yaml') and not fname.lower().endswith('.yml'):
            raise HTTPException(status_code=400, detail="File must be a YAML file (.yaml or .yml)")

        content = await file.read()
        yaml_content = content.decode('utf-8')

        storage = SupabaseStorage()
        upload_success = storage.upload_yaml(fname, yaml_content)

        if not upload_success:
            raise HTTPException(status_code=500, detail="Failed to upload file to storage")

        return {
            "success": True,
            "message": "YAML file uploaded successfully",
            "filename": fname,
            "size": len(content)
        }

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
