from fastapi import APIRouter, HTTPException
from typing import Dict, Any
import os
import logging
from datetime import datetime

logger = logging.getLogger(__name__)

# Create the router
router = APIRouter(prefix="/config", tags=["configuration"])

@router.get("/environment")
async def get_environment_config() -> Dict[str, Any]:
    """
    Get environment configuration for the mobile app
    This helps the Flutter app know what security features are enabled
    """
    try:
        environment = os.getenv("ENVIRONMENT", "production").lower()
        
        config = {
            "environment": environment,
            "is_testing": "testing" in environment,
            "is_development": "dev" in environment or "development" in environment,
            "is_production": environment == "production",
            "recaptcha_enabled": not ("testing" in environment),
            "firebase_configured": bool(
                os.getenv("FIREBASE_WEB_API_KEY") and 
                os.getenv("FIREBASE_PROJECT_ID")
            ),
            "recaptcha_configured": bool(
                os.getenv("RECAPTCHA_PROJECT_ID") and 
                os.getenv("RECAPTCHA_SITE_KEY")
            ),
            "features": {
                "sms_login": True,
                "email_login": True,
                "google_login": True,
                "password_login": True
            },
            "version": "1.0.0",
            "server_time": datetime.now().isoformat()
        }
        
        logger.info(f"Environment config requested: {config['environment']}")
        return config
        
    except Exception as e:
        logger.error(f"Error getting environment config: {str(e)}")
        raise HTTPException(status_code=500, detail="Failed to get configuration")

# Health check router (can be at root level)
health_router = APIRouter(tags=["health"])

@health_router.get("/health")
async def health_check() -> Dict[str, Any]:
    """
    Simple health check endpoint for the mobile app to test connectivity
    """
    return {
        "status": "healthy",
        "message": "Backend is running",
        "timestamp": datetime.now().isoformat(),
        "environment": os.getenv("ENVIRONMENT", "production")
    }