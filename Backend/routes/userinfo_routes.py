from fastapi import APIRouter, HTTPException, Depends
from sqlmodel import Session, select
from typing import Optional
from datetime import date
from passlib.context import CryptContext
from pydantic import BaseModel
import logging

from model.userinfo import UserInfo
from core.db_connection import get_db as get_session
from services.auth_signup import create_firebase_user_service
from services.auth_service import (
    create_auth_tokens, 
    verify_token, 
    get_current_user,
    AuthTokens
)
from firebase_admin.exceptions import FirebaseError
import traceback
# Import services
from firebase_admin import auth

# Set up logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

userinfo_router = APIRouter(prefix="/users", tags=["users"])

# Password hashing (you might not need this for mobile-only registration)
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

class FirebaseUserCreateRequest(BaseModel):
    """For creating users via Firebase ID token"""
    firebase_id_token: str
    additional_info: Optional[dict] = None

# Pydantic models for request/response - MATCHING YOUR FLUTTER APP
class UserCreateRequest(BaseModel):
    FirstName: str
    LastName: str
    MobileNumber: str

class UserResponse(BaseModel):
    UserId: str  # Firebase UID
    FirstName: str
    LastName: str
    MobileNumber: Optional[str]
    CreatedAt: date

class FirebaseUserResponse(BaseModel):
    """Response for Firebase user creation with tokens"""
    user_id: str  # Firebase UID
    first_name: str
    last_name: str
    mobile_number: Optional[str]
    access_token: str
    refresh_token: str
    token_type: str = "bearer"

class SMSRequest(BaseModel):
    """For sending SMS OTP"""
    mobile_number: str

class OTPVerificationRequest(BaseModel):
    """For OTP verification"""
    mobile_number: str
    otp_code: str
    first_name: str
    last_name: str

# === NEW MODELS FOR LOGIN FUNCTIONALITY ===
class MobileLoginRequest(BaseModel):
    """For mobile-based login"""
    mobile_number: str

class PasswordLoginRequest(BaseModel):
    """For password-based login"""
    mobile_number: str
    password: str

class EmailLoginRequest(BaseModel):
    """For email-based login"""
    email: str
    password: str

class GoogleLoginRequest(BaseModel):
    """For Google OAuth login"""
    google_token: str

# === REGISTRATION ENDPOINTS ===
@userinfo_router.post("/create-firebase-user", response_model=FirebaseUserResponse, status_code=201)
async def create_firebase_user(
    request: FirebaseUserCreateRequest,
    session: Session = Depends(get_session)
):
    """Create user from Firebase ID token - matches your Flutter Firebase auth flow"""
    
    try:

        # Call your existing service function
        new_user = await create_firebase_user_service(
            firebase_id_token=request.firebase_id_token,
            session=session,
            additional_info=request.additional_info
        )
        
        # Create JWT tokens for the new user
        auth_tokens = create_auth_tokens(
            user_id=new_user.UserId,  # Firebase UID
            mobile_number=new_user.MobileNumber,
            extra_data={
                "signup_time": new_user.CreatedAt.isoformat() if new_user.CreatedAt else None
            }
        )
        
        return FirebaseUserResponse(
            user_id=new_user.UserId,
            first_name=new_user.FirstName,
            last_name=new_user.LastName,
            mobile_number=new_user.MobileNumber,
            access_token=auth_tokens.access_token,
            refresh_token=auth_tokens.refresh_token,
            token_type=auth_tokens.token_type
        )
    except FirebaseError as e:
        logger.error(f"Firebase token verification failed: {str(e)}")
        raise ValueError(f"Invalid Firebase ID token: {str(e)}")

    except ValueError as e:
        session.rollback()
        raise HTTPException(
            status_code=400,
            detail=str(e)
        )
    except Exception as e:
        session.rollback()
        logger.error(f"Error in create_firebase_user: {str(e)}")
        logger.error(f"Unexpected error in create_firebase_user: {str(e)}")
        logger.error(f"Traceback: {traceback.format_exc()}")
        raise HTTPException(
            status_code=500,
            detail="Failed to create Firebase user"
        )

@userinfo_router.post("/send-sms", status_code=200)
async def send_sms_otp(
    request: SMSRequest,
    session: Session = Depends(get_session)
):
    """Send SMS OTP to mobile number - matches your Flutter _sendSMS() function"""
    
    try:
        # Check if mobile number already exists
        existing_user = session.exec(
            select(UserInfo).where(UserInfo.MobileNumber == request.mobile_number)
        ).first()
        
        if existing_user:
            raise HTTPException(
                status_code=400,
                detail="Mobile number already registered"
            )
        
        # For testing: always return success with hardcoded OTP "111111"
        # In production, this is where you'd send actual SMS
        
        return {
            "message": "OTP sent successfully",
            "mobile_number": request.mobile_number,
            "otp": "111111"  # Only for testing - remove this in production!
        }
    
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error in send_sms_otp: {str(e)}")
        raise HTTPException(
            status_code=500,
            detail="Internal server error while sending OTP"
        )

@userinfo_router.post("/verify-otp", response_model=UserResponse, status_code=201)
async def verify_otp_and_create_user(
    request: OTPVerificationRequest,
    session: Session = Depends(get_session)
):
    """Verify OTP and create user - matches your Flutter OTP verification flow"""
    
    try:
        # Verify OTP code - hardcoded to "111111" for now
        if request.otp_code != "111111":
            raise HTTPException(
                status_code=400,
                detail="Invalid OTP code"
            )
        
        # Check if mobile already exists (double-check)
        existing_user = session.exec(
            select(UserInfo).where(UserInfo.MobileNumber == request.mobile_number)
        ).first()
        
        if existing_user:
            raise HTTPException(
                status_code=400,
                detail="Mobile number already registered"
            )
        
        # Create new user
        new_user = UserInfo(
            FirstName=request.first_name,
            LastName=request.last_name,
            MobileNumber=request.mobile_number,
            PasswordHash=None,  # No password for mobile registration
            CreatedAt=date.today()
        )
        
        session.add(new_user)
        session.commit()
        session.refresh(new_user)
        
        return UserResponse(
            UserId=new_user.UserId,
            FirstName=new_user.FirstName,
            LastName=new_user.LastName,
            MobileNumber=new_user.MobileNumber,
            CreatedAt=new_user.CreatedAt
        )
        
    except HTTPException:
        session.rollback()
        raise
    except Exception as e:
        session.rollback()
        logger.error(f"Error in verify_otp_and_create_user: {str(e)}")
        raise HTTPException(
            status_code=500,
            detail="Failed to create user"
        )

# === NEW LOGIN ENDPOINTS ===

@userinfo_router.get("/check-mobile")
async def check_mobile_exists(
    mobile_number: str,
    session: Session = Depends(get_session)
):
    """Check if mobile number exists in database - for Flutter login validation"""
    
    try:
        existing_user = session.exec(
            select(UserInfo).where(UserInfo.MobileNumber == mobile_number)
        ).first()
        
        return {
            "success": True,
            "exists": existing_user is not None,
            "mobile_number": mobile_number
        }
        
    except Exception as e:
        logger.error(f"Error in check_mobile_exists: {str(e)}")
        return {
            "success": False,
            "error": f"Database error: {str(e)}"
        }

@userinfo_router.post("/send-login-otp", status_code=200)
async def send_login_otp(
    request: SMSRequest,
    session: Session = Depends(get_session)
):
    """Send SMS OTP for login - matches your Flutter login flow"""
    
    try:
        # Check if mobile number exists (opposite of registration)
        existing_user = session.exec(
            select(UserInfo).where(UserInfo.MobileNumber == request.mobile_number)
        ).first()
        
        if not existing_user:
            raise HTTPException(
                status_code=404,
                detail="Mobile number not registered. Please sign up first."
            )
        
        # For testing: always return success with hardcoded OTP "111111"
        # In production, this is where you'd send actual SMS
        
        return {
            "message": "Login OTP sent successfully",
            "mobile_number": request.mobile_number,
            "otp": "111111"  # Only for testing - remove this in production!
        }
    
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error in send_login_otp: {str(e)}")
        raise HTTPException(
            status_code=500,
            detail="Internal server error while sending login OTP"
        )

@userinfo_router.post("/verify-login-otp", response_model=UserResponse)
async def verify_login_otp(
    request: OTPVerificationRequest,
    session: Session = Depends(get_session)
):
    """Verify OTP and login user - matches your Flutter OTP login flow"""
    
    try:
        # Verify OTP code - hardcoded to "111111" for now
        if request.otp_code != "111111":
            raise HTTPException(
                status_code=400,
                detail="Invalid OTP code"
            )
        
        # Find user by mobile number
        user = session.exec(
            select(UserInfo).where(UserInfo.MobileNumber == request.mobile_number)
        ).first()
        
        if not user:
            raise HTTPException(
                status_code=404,
                detail="User not found"
            )
        
        # Return user data for successful login
        return UserResponse(
            UserId=user.UserId,
            FirstName=user.FirstName,
            LastName=user.LastName,
            MobileNumber=user.MobileNumber,
            CreatedAt=user.CreatedAt
        )
    
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error in verify_login_otp: {str(e)}")
        raise HTTPException(
            status_code=500,
            detail="Internal server error during OTP verification"
        )

@userinfo_router.post("/login-mobile", response_model=UserResponse)
async def login_with_mobile(
    request: MobileLoginRequest,
    session: Session = Depends(get_session)
):
    """Login with mobile number (OTP-based) - matches your Flutter mobile login"""
    
    try:
        # Find user by mobile number
        user = session.exec(
            select(UserInfo).where(UserInfo.MobileNumber == request.mobile_number)
        ).first()
        
        if not user:
            raise HTTPException(
                status_code=404,
                detail="Mobile number not registered"
            )
        
        # Return user data
        return UserResponse(
            UserId=user.UserId,
            FirstName=user.FirstName,
            LastName=user.LastName,
            MobileNumber=user.MobileNumber,
            CreatedAt=user.CreatedAt
        )
    
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error in login_with_mobile: {str(e)}")
        raise HTTPException(
            status_code=500,
            detail="Internal server error during mobile login"
        )

@userinfo_router.post("/login-password", response_model=UserResponse)
async def login_with_password(
    request: PasswordLoginRequest,
    session: Session = Depends(get_session)
):
    """Login with mobile number and password - matches your Flutter password login"""
    
    try:
        # Find user by mobile number
        user = session.exec(
            select(UserInfo).where(UserInfo.MobileNumber == request.mobile_number)
        ).first()
        
        if not user:
            raise HTTPException(
                status_code=404,
                detail="Mobile number not registered"
            )
        
        # Check if user has password set
        if not user.PasswordHash:
            raise HTTPException(
                status_code=400,
                detail="This account uses OTP login only. No password set."
            )
        
        # Verify password
        if not pwd_context.verify(request.password, user.PasswordHash):
            raise HTTPException(
                status_code=400,
                detail="Invalid password"
            )
        
        # Return user data for successful login
        return UserResponse(
            UserId=user.UserId,
            FirstName=user.FirstName,
            LastName=user.LastName,
            MobileNumber=user.MobileNumber,
            CreatedAt=user.CreatedAt
        )
    
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error in login_with_password: {str(e)}")
        raise HTTPException(
            status_code=500,
            detail="Internal server error during password login"
        )

@userinfo_router.post("/login-email", response_model=UserResponse)
async def login_with_email(
    request: EmailLoginRequest,
    session: Session = Depends(get_session)
):
    """Login with email and password - matches your Flutter email login"""
    
    try:
        # Find user by email (you'll need to add Email field to UserInfo model if using this)
        # NOTE: This will fail if UserInfo doesn't have an Email field
        if not hasattr(UserInfo, 'Email'):
            raise HTTPException(
                status_code=501,
                detail="Email login not implemented - Email field missing from UserInfo model"
            )
        
        user = session.exec(
            select(UserInfo).where(UserInfo.Email == request.email)
        ).first()
        
        if not user:
            raise HTTPException(
                status_code=404,
                detail="Email not registered"
            )
        
        # Check if user has password set
        if not user.PasswordHash:
            raise HTTPException(
                status_code=400,
                detail="This account uses OTP login only. No password set."
            )
        
        # Verify password
        if not pwd_context.verify(request.password, user.PasswordHash):
            raise HTTPException(
                status_code=400,
                detail="Invalid password"
            )
        
        # Return user data for successful login
        return UserResponse(
            UserId=user.UserId,
            FirstName=user.FirstName,
            LastName=user.LastName,
            MobileNumber=user.MobileNumber,
            CreatedAt=user.CreatedAt
        )
    
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error in login_with_email: {str(e)}")
        raise HTTPException(
            status_code=500,
            detail="Internal server error during email login"
        )

# === GOOGLE OAUTH ENDPOINT ===
@userinfo_router.post("/auth/google-login", response_model=UserResponse)
async def google_oauth_login(
    request: GoogleLoginRequest,
    session: Session = Depends(get_session)
):
    """Google OAuth login - matches your Flutter Google login"""
    
    try:
        # TODO: Implement actual Google OAuth token verification
        # For now, this is a placeholder
        
        # In production, you would:
        # 1. Verify the Google OAuth token
        # 2. Extract user info from Google
        # 3. Create user if doesn't exist, or login if exists
        
        # For testing purposes, return a mock response
        if request.google_token == "mock_google_token":
            # Check if user exists or create new one
            mock_mobile = "1234567890"  # Changed from email to mobile
            
            existing_user = session.exec(
                select(UserInfo).where(UserInfo.MobileNumber == mock_mobile)
            ).first()
            
            if existing_user:
                return UserResponse(
                    UserId=existing_user.UserId,
                    FirstName=existing_user.FirstName,
                    LastName=existing_user.LastName,
                    MobileNumber=existing_user.MobileNumber,
                    CreatedAt=existing_user.CreatedAt
                )
            else:
                # Create new Google user
                new_user = UserInfo(
                    FirstName="Google",
                    LastName="User",
                    MobileNumber=mock_mobile,
                    PasswordHash=None,  # No password for OAuth
                    CreatedAt=date.today()
                )
                
                session.add(new_user)
                session.commit()
                session.refresh(new_user)
                
                return UserResponse(
                    UserId=new_user.UserId,
                    FirstName=new_user.FirstName,
                    LastName=new_user.LastName,
                    MobileNumber=new_user.MobileNumber,
                    CreatedAt=new_user.CreatedAt
                )
        else:
            raise HTTPException(
                status_code=400,
                detail="Invalid Google OAuth token"
            )
    
    except HTTPException:
        session.rollback()
        raise
    except Exception as e:
        session.rollback()
        logger.error(f"Error in google_oauth_login: {str(e)}")
        raise HTTPException(
            status_code=500,
            detail="Internal server error during Google login"
        )

# === EXISTING ENDPOINTS ===

@userinfo_router.post("/", response_model=UserResponse, status_code=201)
async def create_user_direct(
    user_data: UserCreateRequest,
    session: Session = Depends(get_session)
):
    """Direct user creation (if you want to bypass OTP for testing)"""
    
    try:
        # Check if mobile number already exists
        existing_user = session.exec(
            select(UserInfo).where(UserInfo.MobileNumber == user_data.MobileNumber)
        ).first()
        
        if existing_user:
            raise HTTPException(
                status_code=400,
                detail="Mobile number already registered"
            )
        
        # Create new user
        new_user = UserInfo(
            FirstName=user_data.FirstName,
            LastName=user_data.LastName,
            MobileNumber=user_data.MobileNumber,
            PasswordHash=None,
            CreatedAt=date.today()
        )
        
        session.add(new_user)
        session.commit()
        session.refresh(new_user)
        
        return UserResponse(
            UserId=new_user.UserId,
            FirstName=new_user.FirstName,
            LastName=new_user.LastName,
            MobileNumber=new_user.MobileNumber,
            CreatedAt=new_user.CreatedAt
        )
        
    except HTTPException:
        session.rollback()
        raise
    except Exception as e:
        session.rollback()
        logger.error(f"Error in create_user_direct: {str(e)}")
        raise HTTPException(
            status_code=500,
            detail="Failed to create user"
        )

@userinfo_router.get("/{user_id}", response_model=UserResponse)
async def get_user(
    user_id: int,
    session: Session = Depends(get_session)
):
    """Get a user by ID"""
    
    try:
        user = session.get(UserInfo, user_id)
        if not user:
            raise HTTPException(
                status_code=404,
                detail="User not found"
            )
        
        return UserResponse(
            UserId=user.UserId,
            FirstName=user.FirstName,
            LastName=user.LastName,
            MobileNumber=user.MobileNumber,
            CreatedAt=user.CreatedAt
        )
    
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error in get_user: {str(e)}")
        raise HTTPException(
            status_code=500,
            detail="Internal server error while fetching user"
        )