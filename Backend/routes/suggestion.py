from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
import sys
import os

# Add the parent directory to the Python path
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

from services.emotion_pipeline import get_pipeline, analyze_emotion

# Create APIRouter
suggestion_router = APIRouter()

# Pydantic models for request/response
class TextAnalysisRequest(BaseModel):
    text: str
    user_name: str = None  # Optional user name for personalized coaching

@suggestion_router.post("/analyze")
async def analyze_emotion_endpoint(request: TextAnalysisRequest):
    """
    Complete emotion analysis pipeline for EmotiCoach
    
    Processes user text through the complete pipeline:
    1. Language detection (English/Tagalog)
    2. Translation (if Tagalog input)
    3. Emotion classification using distilRoBERTa
    4. RAG-based coaching insights and suggestions
    5. Saves complete analysis to message history
    
    Returns comprehensive emotion analysis with personalized coaching advice
    """
    try:
        text = request.text.strip()
        
        if not text:
            raise HTTPException(status_code=400, detail="Text cannot be empty")
        
        # Process through the complete emotion pipeline with user context
        result = analyze_emotion(text, request.user_name)
        
        if result.get("pipeline_success", False):
            return {
                "success": True,
                "data": result
            }
        else:
            raise HTTPException(
                status_code=500, 
                detail=result.get("error", "Emotion pipeline processing failed")
            )
            
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Server error: {str(e)}")


@suggestion_router.post("/analyze-json")
async def analyze_json_messages():
    """
    Analyze messages from the specific JSON file using the emotion pipeline
    
    Analyzes messages from: C:\\Users\\John Carlo\\emoticoach\\emoticoach\\Backend\\saved_messages\\7633614792_reign.json
    
    Returns emotion analysis for each message in the file
    """
    try:
        import json
        
        # Explicitly set the file path
        file_path = r"C:\Users\John Carlo\emoticoach\emoticoach\Backend\saved_messages\7633614792_reign.json"
        
        # Check if file exists
        if not os.path.exists(file_path):
            raise HTTPException(status_code=404, detail=f"File not found: {file_path}")
        
        # Read and parse JSON file
        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                data = json.load(f)
        except json.JSONDecodeError:
            raise HTTPException(status_code=400, detail="Invalid JSON file format")
        
        messages = data.get('messages', [])
        if not messages:
            raise HTTPException(status_code=400, detail="No messages found in the JSON file")
        
        analyzed_messages = []
        
        # Process each message through the emotion pipeline
        for i, message in enumerate(messages):
            text = message.get('text', '').strip()
            sender = message.get('from', 'Unknown')
            date = message.get('date', 'Unknown date')
            
            if text:
                # Analyze the message with sender as user context
                result = analyze_emotion(text, sender)
                
                message_analysis = {
                    "message_index": i + 1,
                    "sender": sender,
                    "date": date,
                    "original_text": text,
                    "analysis": result if result.get("pipeline_success", False) else {"error": result.get("error", "Analysis failed")}
                }
            else:
                message_analysis = {
                    "message_index": i + 1,
                    "sender": sender,
                    "date": date,
                    "original_text": text,
                    "analysis": {"error": "Empty message"}
                }
            
            analyzed_messages.append(message_analysis)
        
        return {
            "success": True,
            "file_info": {
                "file_path": file_path,
                "sender": data.get('sender', 'Unknown'),
                "receiver": data.get('receiver', 'Unknown'),
                "total_messages": len(messages)
            },
            "analyzed_messages": analyzed_messages
        }
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Server error: {str(e)}")