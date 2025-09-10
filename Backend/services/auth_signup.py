from sqlmodel import Session, select
from datetime import date, datetime, timedelta
from typing import Dict, Any, Optional
import logging
import os
import firebase_admin
from firebase_admin import credentials, auth
from firebase_admin.exceptions import FirebaseError
import requests
import json
import secrets
import hashlib
import time
import re

from model.userinfo import UserInfo

# Set up logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Firebase configuration
FIREBASE_CREDENTIALS_PATH = os.getenv("FIREBASE_CREDENTIALS_PATH")
FIREBASE_PROJECT_ID = os.getenv("FIREBASE_PROJECT_ID")
FIREBASE_WEB_API_KEY = os.getenv("FIREBASE_WEB_API_KEY")

# In-memory storage for OTP verification (replace with Redis in production)
OTP_STORAGE = {}

def format_mobile_number(mobile_number: str) -> str:
    """
    Format and validate Philippine mobile number
    Accepts various formats and normalizes to +63 international format for DB storage
    """
    if not mobile_number:
        raise ValueError("Mobile number cannot be empty")
    
    # Remove all non-digit characters
    cleaned = re.sub(r'\D', '', mobile_number)
    
    # Handle different input formats
    if cleaned.startswith('63'):
        # Already has country code, just add +
        if len(cleaned) != 12:
            raise ValueError("Invalid Philippine mobile number format")
        return f"+{cleaned}"
    elif cleaned.startswith('0'):
        # Remove leading 0 and add +63
        cleaned = cleaned[1:]
        if len(cleaned) != 10 or not cleaned.startswith('9'):
            raise ValueError("Invalid Philippine mobile number format")
        return f"+63{cleaned}"
    else:
        # Assume it's 10-digit format starting with 9
        if len(cleaned) != 10 or not cleaned.startswith('9'):
            raise ValueError("Invalid Philippine mobile number format")
        return f"+63{cleaned}"

# Initialize Firebase Admin SDK
def initialize_firebase():
    """Initialize Firebase Admin SDK"""
    try:
        # Check if Firebase is already initialized
        firebase_admin.get_app()
        logger.info("Firebase already initialized")
    except ValueError:
        # Firebase not initialized, initialize it
        if FIREBASE_CREDENTIALS_PATH and os.path.exists(FIREBASE_CREDENTIALS_PATH):
            # Initialize with service account key file
            cred = credentials.Certificate(FIREBASE_CREDENTIALS_PATH)
            firebase_admin.initialize_app(cred, {
                'projectId': FIREBASE_PROJECT_ID
            })
            logger.info("Firebase initialized with service account")
        else:
            # Initialize with default credentials but explicitly set project ID
            try:
                firebase_admin.initialize_app(options={
                    'projectId': FIREBASE_PROJECT_ID
                })
                logger.info("Firebase initialized with default credentials and explicit project ID")
            except Exception as e:
                logger.error(f"Failed to initialize Firebase: {str(e)}")
                raise ValueError("Firebase initialization failed. Please check your credentials.")

# Initialize Firebase on module load
initialize_firebase()

def generate_otp() -> str:
    """Generate a 6-digit OTP"""
    return f"{secrets.randbelow(1000000):06d}"

def store_otp(mobile_number: str, otp: str, expires_in_minutes: int = 5) -> None:
    """Store OTP with expiration time"""
    expiry = datetime.now() + timedelta(minutes=expires_in_minutes)
    OTP_STORAGE[mobile_number] = {
        'otp': hashlib.sha256(otp.encode()).hexdigest(),  # Store hashed OTP
        'expires_at': expiry,
        'attempts': 0
    }
    logger.info(f"OTP stored for {mobile_number}, expires at {expiry}")

def verify_stored_otp(mobile_number: str, otp: str) -> bool:
    """Verify OTP from storage"""
    if mobile_number not in OTP_STORAGE:
        return False
    
    stored_data = OTP_STORAGE[mobile_number]
    
    # Check expiration
    if datetime.now() > stored_data['expires_at']:
        del OTP_STORAGE[mobile_number]
        return False
    
    # Check attempts (max 3)
    if stored_data['attempts'] >= 3:
        del OTP_STORAGE[mobile_number]
        return False
    
    # Verify OTP
    hashed_input = hashlib.sha256(otp.encode()).hexdigest()
    if hashed_input == stored_data['otp']:
        del OTP_STORAGE[mobile_number]  # Clear after successful verification
        return True
    else:
        stored_data['attempts'] += 1
        return False

async def create_firebase_user_service(
    firebase_id_token: str,
    session: Session,
    additional_info: Optional[Dict[str, Any]] = None
) -> UserInfo:
    time.sleep(6)
    """
    Create Firebase user from ID token - for signup
    """
    try:
        logger.info("Starting Firebase user creation from ID token")
        
        # Verify Firebase ID token
        try:
            decoded_token = auth.verify_id_token(firebase_id_token)
            firebase_uid = decoded_token['uid']
            phone_number = decoded_token.get('phone_number')
            email = decoded_token.get('email')
            name = decoded_token.get('name', '')
            
            logger.info(f"Firebase token verified for UID: {firebase_uid}")
            
        except FirebaseError as e:
            logger.error(f"Firebase token verification error: {str(e)}")
            raise ValueError("Invalid Firebase ID token")
        
        # Format mobile number
        mobile_for_db = None
        try:
            if phone_number:
                mobile_for_db = format_mobile_number(phone_number)
            elif additional_info and additional_info.get('mobile_number'):
                mobile_for_db = format_mobile_number(additional_info['mobile_number'])
        except ValueError as e:
            logger.error(f"Mobile number formatting error: {str(e)}")
            # Continue without mobile number if formatting fails
            mobile_for_db = None
        
        # Check if user already exists by Firebase UID
        existing_user = session.exec(
            select(UserInfo).where(UserInfo.UserId == firebase_uid)
        ).first()
        if existing_user:
            logger.info(f"User already exists with Firebase UID: {firebase_uid}")
            return existing_user
        
        # Check if mobile number already exists (secondary check)
        if mobile_for_db:
            existing_mobile_user = session.exec(
                select(UserInfo).where(UserInfo.MobileNumber == mobile_for_db)
            ).first()
            if existing_mobile_user:
                raise ValueError("User already registered with this phone number")
        
        # Extract name parts
        name_parts = name.split(' ', 1) if name else ['', '']
        first_name = additional_info.get('first_name') if additional_info else (name_parts[0] or 'User')
        last_name = additional_info.get('last_name') if additional_info else (name_parts[1] if len(name_parts) > 1 else '')
        
        # Create new user with Firebase UID as UserId primary key
        new_user = UserInfo(
            UserId=firebase_uid,  # Firebase UID as primary key
            FirstName=first_name,
            LastName=last_name,
            MobileNumber=mobile_for_db,  # This can be None
            PasswordHash=None,  # Firebase auth, no local password
            CreatedAt=date.today()
        )
        
        session.add(new_user)
        session.commit()
        session.refresh(new_user)
        
        logger.info(f"Firebase user created successfully with UID: {new_user.UserId}")
        return new_user
        
    except ValueError:
        session.rollback()
        raise
    except Exception as e:
        session.rollback()
        logger.error(f"Error in create_firebase_user service: {str(e)}")
        import traceback
        logger.error(f"Traceback: {traceback.format_exc()}")
        raise Exception("Failed to create Firebase user")

async def send_sms_otp_service(mobile_number: str, session: Session) -> Dict[str, Any]:
    """
    Enhanced SMS OTP service - primarily for testing or fallback
    In production, Firebase handles SMS sending
    """
    try:
        logger.info(f"Starting send_sms_otp_service for mobile: {mobile_number}")
        
        # Format mobile number
        formatted_mobile = format_mobile_number(mobile_number)
        
        # Check if mobile number already exists
        logger.info(f"Checking if mobile number exists: {formatted_mobile}")
        existing_user = session.exec(
            select(UserInfo).where(UserInfo.MobileNumber == formatted_mobile)
        ).first()
        
        if existing_user:
            logger.warning(f"Mobile number already registered: {formatted_mobile}")
            raise ValueError("Mobile number already registered")
        
        # Check environment
        environment = os.getenv("ENVIRONMENT", "").lower()
        logger.info(f"Environment: {environment}")
        
        # Testing mode - generate test OTP
        if "testing" in environment or "development" in environment:
            logger.info("Using test mode - generating test OTP")
            test_otp = "111111"
            store_otp(formatted_mobile, test_otp)
            
            return {
                "success": True,
                "message": "Test OTP generated successfully",
                "mobile_number": formatted_mobile,
                "formatted_number": formatted_mobile,
                "test_otp": test_otp,  # Only show in test mode
                "test_mode": True,
                "method": "test",
                "instructions": "Use OTP: 111111 for testing"
            }
        
        # Production - instruct to use Firebase
        return {
            "success": True,
            "message": "Please use Firebase Auth SDK to send OTP",
            "mobile_number": formatted_mobile,
            "formatted_number": formatted_mobile,
            "method": "firebase_required",
            "instructions": "This endpoint is for testing only. Use Firebase Auth SDK in production."
        }
        
    except ValueError as e:
        logger.error(f"ValueError in send_sms_otp service: {str(e)}")
        raise
    except Exception as e:
        logger.error(f"Unexpected error in send_sms_otp service: {str(e)}")
        import traceback
        logger.error(f"Traceback: {traceback.format_exc()}")
        raise Exception(f"Internal server error while initiating OTP: {str(e)}")

async def verify_otp_and_create_user_service(
    mobile_number: str, 
    otp_code: str, 
    first_name: str, 
    last_name: str, 
    session: Session
) -> UserInfo:
    try:
        logger.info(f"Starting OTP verification for: {mobile_number}")
        
        formatted_mobile = format_mobile_number(mobile_number)
        
        # Check if this looks like a Firebase ID token
        if len(otp_code) > 20 and '.' in otp_code:
            logger.info("OTP code appears to be Firebase ID token")
            return await create_firebase_user_service(
                firebase_id_token=otp_code,
                session=session,
                additional_info={
                    'first_name': first_name,
                    'last_name': last_name,
                    'mobile_number': formatted_mobile
                }
            )
        
        # Check if this is a stored OTP
        if verify_stored_otp(formatted_mobile, otp_code):
            logger.info("Using stored OTP verification")
            
            existing_user = session.exec(
                select(UserInfo).where(UserInfo.MobileNumber == formatted_mobile)
            ).first()
            
            if existing_user:
                raise ValueError("Mobile number already registered")
            
            # Create new user WITHOUT specifying UserId
            new_user = UserInfo(
                # UserId is NOT specified - PostgreSQL will auto-generate it
                FirstName=first_name,
                LastName=last_name,
                MobileNumber=formatted_mobile,
                PasswordHash=None,
                CreatedAt=date.today()
            )
            
            session.add(new_user)
            session.commit()
            session.refresh(new_user)  # This will populate the auto-generated UserId
            
            logger.info(f"User created successfully with stored OTP verification, ID: {new_user.UserId}")
            return new_user
        
        # Legacy test mode support
        environment = os.getenv("ENVIRONMENT", "").lower()
        if ("testing" in environment or "development" in environment) and otp_code == "111111":
            logger.info("Using legacy test mode OTP verification")
            
            existing_user = session.exec(
                select(UserInfo).where(UserInfo.MobileNumber == formatted_mobile)
            ).first()
            
            if existing_user:
                raise ValueError("Mobile number already registered")
            
            # Create new user WITHOUT specifying UserId
            new_user = UserInfo(
                # UserId is NOT specified - PostgreSQL will auto-generate it
                FirstName=first_name,
                LastName=last_name,
                MobileNumber=formatted_mobile,
                PasswordHash=None,
                CreatedAt=date.today()
            )
            
            session.add(new_user)
            session.commit()
            session.refresh(new_user)  # This will populate the auto-generated UserId
            
            logger.info(f"User created successfully (legacy test mode) with ID: {new_user.UserId}")
            return new_user
        
        raise ValueError("Invalid or expired OTP code")
        
    except ValueError:
        session.rollback()
        raise
    except Exception as e:
        session.rollback()
        logger.error(f"Error in verify_otp_and_create_user service: {str(e)}")
        import traceback
        logger.error(f"Traceback: {traceback.format_exc()}")
        raise Exception("Failed to create user")

# Login services
async def send_login_otp_service(mobile_number: str, session: Session) -> Dict[str, Any]:
    """Send OTP for login - primarily uses Firebase"""
    try:
        logger.info(f"Starting send_login_otp for: {mobile_number}")
        
        formatted_mobile = format_mobile_number(mobile_number)
        
        # Check if user exists
        existing_user = session.exec(
            select(UserInfo).where(UserInfo.MobileNumber == formatted_mobile)
        ).first()
        
        if not existing_user:
            raise ValueError("Mobile number not registered")
        
        # Return Firebase instructions
        return {
            "success": True,
            "message": "Use Firebase Auth SDK to send login OTP",
            "mobile_number": formatted_mobile,
            "formatted_number": formatted_mobile,
            "method": "firebase_auth",
            "user_exists": True
        }
        
    except ValueError:
        raise
    except Exception as e:
        logger.error(f"Error in send_login_otp service: {str(e)}")
        raise Exception("Failed to initiate login OTP")

async def verify_login_otp_service(
    mobile_number: str, 
    otp_or_token: str, 
    session: Session
) -> Dict[str, Any]:
    """Verify login OTP or Firebase token"""
    try:
        logger.info(f"Starting login verification for: {mobile_number}")
        
        formatted_mobile = format_mobile_number(mobile_number)
        
        # Check if user exists
        existing_user = session.exec(
            select(UserInfo).where(UserInfo.MobileNumber == formatted_mobile)
        ).first()
        
        if not existing_user:
            raise ValueError("Mobile number not registered")
        
        # Check if this looks like a Firebase ID token
        if len(otp_or_token) > 20 and '.' in otp_or_token:
            logger.info("Verifying Firebase ID token for login")
            
            try:
                decoded_token = auth.verify_id_token(otp_or_token)
                firebase_uid = decoded_token['uid']
                phone_number = decoded_token.get('phone_number')
                
                # Verify phone number matches
                if phone_number:
                    token_mobile = format_mobile_number(phone_number)
                    if token_mobile != formatted_mobile:
                        raise ValueError("Phone number mismatch")
                
                logger.info(f"Login successful for user: {existing_user.UserId}")
                
                return {
                    "success": True,
                    "message": "Login successful",
                    "user": {
                        "id": existing_user.UserId,
                        "first_name": existing_user.FirstName,
                        "last_name": existing_user.LastName,
                        "mobile_number": existing_user.MobileNumber
                    },
                    "firebase_uid": firebase_uid
                }
                
            except FirebaseError as e:
                logger.error(f"Firebase login verification error: {str(e)}")
                raise ValueError("Invalid login token")
        
        # Fallback: test mode OTP
        environment = os.getenv("ENVIRONMENT", "").lower()
        if ("testing" in environment or "development" in environment) and otp_or_token == "111111":
            logger.info("Using test mode login verification")
            
            return {
                "success": True,
                "message": "Login successful (test mode)",
                "user": {
                    "id": existing_user.UserId,
                    "first_name": existing_user.FirstName,
                    "last_name": existing_user.LastName,
                    "mobile_number": existing_user.MobileNumber
                },
                "test_mode": True
            }
        
        raise ValueError("Invalid OTP or token")
        
    except ValueError:
        raise
    except Exception as e:
        logger.error(f"Error in verify_login_otp service: {str(e)}")
        raise Exception("Failed to verify login")

# Utility functions
def cleanup_expired_otps():
    """Clean up expired OTPs from memory storage"""
    current_time = datetime.now()
    expired_keys = [
        key for key, value in OTP_STORAGE.items()
        if current_time > value['expires_at']
    ]
    
    for key in expired_keys:
        del OTP_STORAGE[key]
    
    logger.info(f"Cleaned up {len(expired_keys)} expired OTPs")

def get_otp_status(mobile_number: str) -> Dict[str, Any]:
    """Get OTP status for debugging (test mode only)"""
    formatted_mobile = format_mobile_number(mobile_number)
    if formatted_mobile in OTP_STORAGE:
        data = OTP_STORAGE[formatted_mobile]
        return {
            "exists": True,
            "expires_at": data['expires_at'].isoformat(),
            "attempts": data['attempts'],
            "expired": datetime.now() > data['expires_at']
        }
    return {"exists": False}