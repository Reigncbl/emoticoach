
import redis
import json
from typing import Optional, Dict, List, Any
from datetime import datetime, timedelta
from dotenv import load_dotenv
import os

load_dotenv()


def _get_env_bool(name: str, default: bool = False) -> bool:
    """Interpret common truthy strings from environment values."""
    value = os.getenv(name)
    if value is None:
        return default
    return value.strip().lower() in {"1", "true", "yes", "on"}


# Redis connection
_redis_url = os.getenv("REDIS_URL")
if _redis_url:
    r = redis.from_url(_redis_url, decode_responses=True)
else:
    r = redis.Redis(
        host=os.getenv("REDIS_HOST", "localhost"),
        port=int(os.getenv("REDIS_PORT", "6379")),
        username=os.getenv("REDIS_USERNAME") or None,
        password=os.getenv("REDIS_PASSWORD") or None,
        decode_responses=_get_env_bool("REDIS_DECODE_RESPONSES", True),
        ssl=_get_env_bool("REDIS_USE_SSL", False),
    )

# Cache TTL settings (in seconds)
MESSAGE_CACHE_TTL = 300  # 5 minutes
USER_INFO_CACHE_TTL = 3600  # 1 hour
EMOTION_CACHE_TTL = 600  # 10 minutes
CONVERSATION_CACHE_TTL = 180  # 3 minutes

class MessageCache:
    """Cache service for Message model operations"""
    
    @staticmethod
    def _serialize_message(message_data: Dict) -> str:
        """Serialize message data to JSON string for Redis storage"""
        # Convert datetime objects to ISO format strings
        serialized = message_data.copy()
        if isinstance(serialized.get('DateSent'), datetime):
            serialized['DateSent'] = serialized['DateSent'].isoformat()
        
        # Convert embeddings to lists if they're numpy arrays
        if 'Semantic_Embedding' in serialized and serialized['Semantic_Embedding'] is not None:
            if hasattr(serialized['Semantic_Embedding'], 'tolist'):
                serialized['Semantic_Embedding'] = serialized['Semantic_Embedding'].tolist()
        
        if 'Emotion_Embedding' in serialized and serialized['Emotion_Embedding'] is not None:
            if hasattr(serialized['Emotion_Embedding'], 'tolist'):
                serialized['Emotion_Embedding'] = serialized['Emotion_Embedding'].tolist()
        
        return json.dumps(serialized)
    
    @staticmethod
    def _deserialize_message(message_str: str) -> Dict:
        """Deserialize message data from JSON string"""
        data = json.loads(message_str)
        
        # Convert ISO format strings back to datetime
        if 'DateSent' in data and isinstance(data['DateSent'], str):
            data['DateSent'] = datetime.fromisoformat(data['DateSent'])
        
        return data
    
    # ===================== Message Caching =====================
    
    @staticmethod
    def cache_message(message_id: str, message_data: Dict, ttl: int = MESSAGE_CACHE_TTL):
        """Cache a single message by MessageId"""
        try:
            key = f"message:{message_id}"
            serialized = MessageCache._serialize_message(message_data)
            r.setex(key, ttl, serialized)
            return True
        except Exception as e:
            print(f"Error caching message {message_id}: {e}")
            return False
    
    @staticmethod
    def get_cached_message(message_id: str) -> Optional[Dict]:
        """Retrieve a cached message by MessageId"""
        try:
            key = f"message:{message_id}"
            cached = r.get(key)
            if cached:
                return MessageCache._deserialize_message(cached)
            return None
        except Exception as e:
            print(f"Error retrieving cached message {message_id}: {e}")
            return None
    
    @staticmethod
    def cache_conversation_messages(user_id: str, contact_id: int, messages: List[Dict], ttl: int = CONVERSATION_CACHE_TTL):
        """Cache messages for a specific conversation (user_id + contact_id)"""
        try:
            key = f"conversation:{user_id}:{contact_id}"
            serialized = json.dumps([MessageCache._serialize_message(msg) if isinstance(msg, dict) else msg for msg in messages])
            r.setex(key, ttl, serialized)
            return True
        except Exception as e:
            print(f"Error caching conversation for user {user_id} and contact {contact_id}: {e}")
            return False
    
    @staticmethod
    def get_cached_conversation(user_id: str, contact_id: int) -> Optional[List[Dict]]:
        """Retrieve cached conversation messages"""
        try:
            key = f"conversation:{user_id}:{contact_id}"
            cached = r.get(key)
            if cached:
                messages = json.loads(cached)
                return [MessageCache._deserialize_message(msg) if isinstance(msg, str) else msg for msg in messages]
            return None
        except Exception as e:
            print(f"Error retrieving cached conversation for user {user_id} and contact {contact_id}: {e}")
            return None
    
    @staticmethod
    def cache_latest_message(user_id: str, contact_id: int, message_data: Dict, ttl: int = MESSAGE_CACHE_TTL):
        """Cache the latest message for a conversation"""
        try:
            key = f"latest_message:{user_id}:{contact_id}"
            serialized = MessageCache._serialize_message(message_data)
            r.setex(key, ttl, serialized)
            return True
        except Exception as e:
            print(f"Error caching latest message: {e}")
            return False
    
    @staticmethod
    def get_cached_latest_message(user_id: str, contact_id: int) -> Optional[Dict]:
        """Retrieve the cached latest message for a conversation"""
        try:
            key = f"latest_message:{user_id}:{contact_id}"
            cached = r.get(key)
            if cached:
                return MessageCache._deserialize_message(cached)
            return None
        except Exception as e:
            print(f"Error retrieving cached latest message: {e}")
            return None
    
    # ===================== Emotion Analysis Caching =====================
    
    @staticmethod
    def cache_emotion_analysis(message_content: str, emotion_data: Dict, ttl: int = EMOTION_CACHE_TTL):
        """Cache emotion analysis results for a message content"""
        try:
            # Use hash of message content as key to avoid duplicates
            import hashlib
            content_hash = hashlib.sha256(message_content.encode()).hexdigest()
            key = f"emotion:{content_hash}"
            r.setex(key, ttl, json.dumps(emotion_data))
            return True
        except Exception as e:
            print(f"Error caching emotion analysis: {e}")
            return False
    
    @staticmethod
    def get_cached_emotion_analysis(message_content: str) -> Optional[Dict]:
        """Retrieve cached emotion analysis for a message content"""
        try:
            import hashlib
            content_hash = hashlib.sha256(message_content.encode()).hexdigest()
            key = f"emotion:{content_hash}"
            cached = r.get(key)
            if cached:
                return json.loads(cached)
            return None
        except Exception as e:
            print(f"Error retrieving cached emotion analysis: {e}")
            return None
    
    # ===================== User Info Caching =====================
    
    @staticmethod
    def cache_user_info(user_id: str, user_data: Dict, ttl: int = USER_INFO_CACHE_TTL):
        """Cache user information"""
        try:
            key = f"user_info:{user_id}"
            r.setex(key, ttl, json.dumps(user_data))
            return True
        except Exception as e:
            print(f"Error caching user info: {e}")
            return False
    
    @staticmethod
    def get_cached_user_info(user_id: str) -> Optional[Dict]:
        """Retrieve cached user information"""
        try:
            key = f"user_info:{user_id}"
            cached = r.get(key)
            if cached:
                return json.loads(cached)
            return None
        except Exception as e:
            print(f"Error retrieving cached user info: {e}")
            return None
    
    # ===================== Cache Invalidation =====================
    
    @staticmethod
    def invalidate_message(message_id: str):
        """Invalidate a specific message cache"""
        try:
            key = f"message:{message_id}"
            r.delete(key)
            return True
        except Exception as e:
            print(f"Error invalidating message cache: {e}")
            return False
    
    @staticmethod
    def invalidate_conversation(user_id: str, contact_id: int):
        """Invalidate conversation cache and latest message cache"""
        try:
            keys_to_delete = [
                f"conversation:{user_id}:{contact_id}",
                f"latest_message:{user_id}:{contact_id}"
            ]
            r.delete(*keys_to_delete)
            return True
        except Exception as e:
            print(f"Error invalidating conversation cache: {e}")
            return False
    
    @staticmethod
    def invalidate_conversation_only(user_id: str, contact_id: int):
        """Invalidate only the conversation cache, keeping latest message cache"""
        try:
            key = f"conversation:{user_id}:{contact_id}"
            r.delete(key)
            return True
        except Exception as e:
            print(f"Error invalidating conversation cache: {e}")
            return False
    
    @staticmethod
    def invalidate_user_messages(user_id: str):
        """Invalidate all cached messages for a user"""
        try:
            # Find all keys matching pattern
            pattern = f"conversation:{user_id}:*"
            cursor = 0
            keys_to_delete = []
            
            while True:
                cursor, keys = r.scan(cursor, match=pattern, count=100)
                keys_to_delete.extend(keys)
                if cursor == 0:
                    break
            
            if keys_to_delete:
                r.delete(*keys_to_delete)
            
            return True
        except Exception as e:
            print(f"Error invalidating user messages cache: {e}")
            return False
    
    # ===================== Utility Methods =====================
    
    @staticmethod
    def clear_all_caches():
        """Clear all message-related caches (use with caution)"""
        try:
            patterns = [
                "message:*",
                "conversation:*",
                "latest_message:*",
                "emotion:*",
                "user_info:*"
            ]
            
            for pattern in patterns:
                cursor = 0
                while True:
                    cursor, keys = r.scan(cursor, match=pattern, count=100)
                    if keys:
                        r.delete(*keys)
                    if cursor == 0:
                        break
            
            return True
        except Exception as e:
            print(f"Error clearing all caches: {e}")
            return False
    
    @staticmethod
    def get_cache_stats() -> Dict[str, int]:
        """Get statistics about cached data"""
        try:
            stats = {
                "messages": 0,
                "conversations": 0,
                "emotions": 0,
                "user_info": 0,
                "total_keys": 0
            }
            
            patterns = {
                "messages": "message:*",
                "conversations": "conversation:*",
                "emotions": "emotion:*",
                "user_info": "user_info:*"
            }
            
            for stat_name, pattern in patterns.items():
                cursor = 0
                count = 0
                while True:
                    cursor, keys = r.scan(cursor, match=pattern, count=100)
                    count += len(keys)
                    if cursor == 0:
                        break
                stats[stat_name] = count
            
            stats["total_keys"] = r.dbsize()
            return stats
        except Exception as e:
            print(f"Error getting cache stats: {e}")
            return {}


# Convenience function exports
cache_message = MessageCache.cache_message
get_cached_message = MessageCache.get_cached_message
cache_conversation = MessageCache.cache_conversation_messages
get_cached_conversation = MessageCache.get_cached_conversation
cache_latest_message = MessageCache.cache_latest_message
get_cached_latest_message = MessageCache.get_cached_latest_message
cache_emotion = MessageCache.cache_emotion_analysis
get_cached_emotion = MessageCache.get_cached_emotion_analysis
cache_user_info = MessageCache.cache_user_info
get_cached_user_info = MessageCache.get_cached_user_info
invalidate_conversation = MessageCache.invalidate_conversation
invalidate_conversation_only = MessageCache.invalidate_conversation_only
get_cache_stats = MessageCache.get_cache_stats



