"""
Authentication utilities for JWT token management
Provides stateless authentication for the EmotiCoach app
"""

import jwt
import os
from datetime import datetime, timedelta
from typing import Optional, Dict, Any
from fastapi import HTTPException, Depends, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from sqlmodel import Session, select
from model.userinfo import UserInfo
from core.db_connection import get_db as get_session
import logging

logger = logging.getLogger(__name__)

# JWT Configuration
JWT_SECRET_KEY = os.getenv("JWT_SECRET_KEY", "your-secret-key-change-in-production")
JWT_ALGORITHM = "HS256"
JWT_ACCESS_TOKEN_EXPIRE_HOURS = 24 * 7  # 7 days
JWT_REFRESH_TOKEN_EXPIRE_DAYS = 30  # 30 days

# HTTP Bearer token scheme
security = HTTPBearer()

class AuthTokens:
    """Data class for authentication tokens"""
    def __init__(self, access_token: str, refresh_token: str, token_type: str = "bearer"):
        self.access_token = access_token
        self.refresh_token = refresh_token
        self.token_type = token_type

def create_access_token(user_id: int, mobile_number: str, extra_data: Optional[Dict[str, Any]] = None) -> str:
    """
    Create JWT access token for user authentication
    
    Args:
        user_id: The user's unique ID
        mobile_number: The user's mobile number
        extra_data: Additional data to include in token payload
        
    Returns:
        JWT access token string
    """
    try:
        now = datetime.utcnow()
        expire = now + timedelta(hours=JWT_ACCESS_TOKEN_EXPIRE_HOURS)
        
        payload = {
            "sub": str(user_id),  # Subject (user ID)
            "mobile": mobile_number,
            "type": "access",
            "iat": now,  # Issued at
            "exp": expire,  # Expiration
        }
        
        # Add extra data if provided
        if extra_data:
            payload.update(extra_data)
            
        token = jwt.encode(payload, JWT_SECRET_KEY, algorithm=JWT_ALGORITHM)
        logger.info(f"Created access token for user {user_id}")
        return token
        
    except Exception as e:
        logger.error(f"Error creating access token: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Could not create access token"
        )

def create_refresh_token(user_id: int, mobile_number: str) -> str:
    """
    Create JWT refresh token for token renewal
    
    Args:
        user_id: The user's unique ID
        mobile_number: The user's mobile number
        
    Returns:
        JWT refresh token string
    """
    try:
        now = datetime.utcnow()
        expire = now + timedelta(days=JWT_REFRESH_TOKEN_EXPIRE_DAYS)
        
        payload = {
            "sub": str(user_id),
            "mobile": mobile_number,
            "type": "refresh",
            "iat": now,
            "exp": expire,
        }
        
        token = jwt.encode(payload, JWT_SECRET_KEY, algorithm=JWT_ALGORITHM)
        logger.info(f"Created refresh token for user {user_id}")
        return token
        
    except Exception as e:
        logger.error(f"Error creating refresh token: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Could not create refresh token"
        )

def create_auth_tokens(user_id: int, mobile_number: str, extra_data: Optional[Dict[str, Any]] = None) -> AuthTokens:
    """
    Create both access and refresh tokens for a user
    
    Args:
        user_id: The user's unique ID
        mobile_number: The user's mobile number  
        extra_data: Additional data to include in access token
        
    Returns:
        AuthTokens object containing both tokens
    """
    access_token = create_access_token(user_id, mobile_number, extra_data)
    refresh_token = create_refresh_token(user_id, mobile_number)
    
    return AuthTokens(
        access_token=access_token,
        refresh_token=refresh_token
    )

def verify_token(token: str, token_type: str = "access") -> Dict[str, Any]:
    """
    Verify and decode JWT token
    
    Args:
        token: JWT token string
        token_type: Expected token type ("access" or "refresh")
        
    Returns:
        Decoded token payload
        
    Raises:
        HTTPException: If token is invalid or expired
    """
    try:
        payload = jwt.decode(token, JWT_SECRET_KEY, algorithms=[JWT_ALGORITHM])
        
        # Check token type
        if payload.get("type") != token_type:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail=f"Invalid token type. Expected {token_type}"
            )
            
        # Check expiration
        exp_timestamp = payload.get("exp")
        if exp_timestamp and datetime.utcnow().timestamp() > exp_timestamp:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Token has expired"
            )
            
        return payload
        
    except jwt.ExpiredSignatureError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token has expired"
        )
    except jwt.InvalidTokenError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid token"
        )
    except Exception as e:
        logger.error(f"Token verification error: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Could not validate token"
        )

async def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(security),
    session: Session = Depends(get_session)
) -> UserInfo:
    """
    FastAPI dependency to get current authenticated user from JWT token
    
    Args:
        credentials: HTTP Bearer token from request
        session: Database session
        
    Returns:
        UserInfo object of authenticated user
        
    Raises:
        HTTPException: If authentication fails
    """
    try:
        # Verify the access token
        payload = verify_token(credentials.credentials, "access")
        user_id = int(payload.get("sub"))
        
        # Get user from database
        user = session.get(UserInfo, user_id)
        if not user:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="User not found"
            )
            
        return user
        
    except ValueError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid user ID in token"
        )
    except Exception as e:
        logger.error(f"Authentication error: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Could not validate credentials"
        )

async def get_current_user_optional(
    credentials: Optional[HTTPAuthorizationCredentials] = Depends(HTTPBearer(auto_error=False)),
    session: Session = Depends(get_session)
) -> Optional[UserInfo]:
    """
    FastAPI dependency to optionally get current authenticated user
    Returns None if no valid token is provided
    
    Args:
        credentials: Optional HTTP Bearer token from request
        session: Database session
        
    Returns:
        UserInfo object or None
    """
    if not credentials:
        return None
        
    try:
        payload = verify_token(credentials.credentials, "access")
        user_id = int(payload.get("sub"))
        
        user = session.get(UserInfo, user_id)
        return user
        
    except Exception as e:
        logger.warning(f"Optional authentication failed: {str(e)}")
        return None

def extract_user_id_from_token(token: str) -> int:
    """
    Extract user ID from token without full verification (for refresh tokens)
    
    Args:
        token: JWT token string
        
    Returns:
        User ID
        
    Raises:
        HTTPException: If token format is invalid
    """
    try:
        # Decode without verification for user ID extraction
        payload = jwt.decode(token, options={"verify_signature": False})
        return int(payload.get("sub"))
    except Exception as e:
        logger.error(f"Error extracting user ID from token: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid token format"
        )
