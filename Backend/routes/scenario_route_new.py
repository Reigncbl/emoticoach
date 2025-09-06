from fastapi import APIRouter, HTTPException
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

scenario_router = APIRouter()

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
    Send a message to the AI character and get a response.
    
    - **user_message**: The user's message
    - **scenario_id**: Optional scenario ID for context
    - **character_name**: Optional character name for direct character interaction
    - **character_description**: Optional character description for direct character interaction
    """
    try:
        response = chat_with_ai(request)
        if not response.success:
            raise HTTPException(status_code=500, detail=response.error)
        return response
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@scenario_router.post('/evaluate', response_model=EvaluationResponse)
async def evaluate(request: EvaluationRequest):
    """
    Evaluate the user's conversation performance.
    
    - **conversation_history**: List of conversation messages
    - **scenario_id**: The scenario being evaluated
    """
    try:
        response = evaluate_conversation(request)
        if not response.success:
            raise HTTPException(status_code=500, detail=response.error)
        return response
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@scenario_router.get('/list')
async def list_scenarios():
    """
    Get a list of all available scenarios.
    
    Returns a list of scenarios with basic information.
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
    
    Returns scenario details including character information.
    """
    try:
        details = get_scenario_details(scenario_id)
        return {"success": True, "scenario": details}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
