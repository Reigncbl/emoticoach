from fastapi import APIRouter, HTTPException
from sqlmodel import select
from model.readingsinfo import ReadingsInfo
from model.readingblock import ReadingBlock
from core.db_connection import SessionDep
from services.scenario import (
    chat_with_ai, 
    evaluate_conversation,
    start_conversation,
    ChatRequest, 
    ChatResponse,
    EvaluationRequest,
    EvaluationResponse,
    ConfigResponse
)


scenario_router = APIRouter()

@scenario_router.get('/start', response_model=ConfigResponse)
async def start():
    """
    Start a new conversation with the AI character.
    
    Returns the character's opening message to begin the conversation.
    """
    try:
        response = await start_conversation()
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

