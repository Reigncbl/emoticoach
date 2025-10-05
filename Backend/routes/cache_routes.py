"""
Cache management and monitoring routes
"""

from fastapi import APIRouter, HTTPException, Query
from services.cache import MessageCache

cache_router = APIRouter(prefix="/cache", tags=["Cache Management"])


@cache_router.get("/stats")
async def get_cache_statistics():
    """Get statistics about cached data"""
    try:
        stats = MessageCache.get_cache_stats()
        return {
            "status": "success",
            "statistics": stats,
            "message": "Cache statistics retrieved successfully"
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error retrieving cache stats: {e}")


@cache_router.delete("/invalidate/conversation")
async def invalidate_conversation_cache(
    user_id: str = Query(..., description="User ID"),
    contact_id: int = Query(..., description="Contact ID")
):
    """Invalidate cache for a specific conversation"""
    try:
        success = MessageCache.invalidate_conversation(user_id, contact_id)
        if success:
            return {
                "status": "success",
                "message": f"Cache invalidated for conversation {user_id}:{contact_id}"
            }
        else:
            return {
                "status": "error",
                "message": "Failed to invalidate cache"
            }
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error invalidating cache: {e}")


@cache_router.delete("/invalidate/user")
async def invalidate_user_cache(
    user_id: str = Query(..., description="User ID")
):
    """Invalidate all cached data for a specific user"""
    try:
        success = MessageCache.invalidate_user_messages(user_id)
        if success:
            return {
                "status": "success",
                "message": f"All caches invalidated for user {user_id}"
            }
        else:
            return {
                "status": "error",
                "message": "Failed to invalidate user caches"
            }
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error invalidating user cache: {e}")


@cache_router.delete("/clear")
async def clear_all_caches(
    confirm: bool = Query(False, description="Confirmation flag - must be True to clear all caches")
):
    """Clear all message-related caches (use with caution!)"""
    if not confirm:
        raise HTTPException(
            status_code=400,
            detail="Confirmation required. Set confirm=true to clear all caches"
        )
    
    try:
        success = MessageCache.clear_all_caches()
        if success:
            return {
                "status": "success",
                "message": "All caches cleared successfully"
            }
        else:
            return {
                "status": "error",
                "message": "Failed to clear caches"
            }
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error clearing caches: {e}")


@cache_router.get("/message/{message_id}")
async def get_cached_message(message_id: str):
    """Retrieve a specific cached message by ID"""
    try:
        cached_message = MessageCache.get_cached_message(message_id)
        if cached_message:
            return {
                "status": "success",
                "cached": True,
                "message": cached_message
            }
        else:
            return {
                "status": "success",
                "cached": False,
                "message": "Message not found in cache"
            }
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error retrieving cached message: {e}")


@cache_router.get("/latest-message")
async def get_latest_cached_message(
    user_id: str = Query(..., description="User ID"),
    contact_id: int = Query(..., description="Contact ID")
):
    """Retrieve the latest cached message for a conversation"""
    try:
        cached_message = MessageCache.get_cached_latest_message(user_id, contact_id)
        if cached_message:
            return {
                "status": "success",
                "cached": True,
                "message": cached_message
            }
        else:
            return {
                "status": "success",
                "cached": False,
                "message": "Latest message not found in cache"
            }
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error retrieving latest cached message: {e}")
