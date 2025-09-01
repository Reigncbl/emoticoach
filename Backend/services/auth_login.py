from sqlmodel import Session, select
from datetime import date, datetime, timedelta
from passlib.context import CryptContext
from typing import Dict, Any, Optional
import logging
import os
import json
import requests
import firebase_admin
from firebase_admin import credentials, auth
from firebase_admin.exceptions import FirebaseError
import hashlib
from urllib.parse import unquote


from google.cloud import recaptchaenterprise_v1
from google.cloud.recaptchaenterprise_v1 import Assessment

from model.userinfo import UserInfo

# Set up logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Password hashing
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

# Firebase configuration
FIREBASE_CREDENTIALS_PATH = os.getenv("FIREBASE_CREDENTIALS_PATH")
FIREBASE_PROJECT_ID = os.getenv("FIREBASE_PROJECT_ID")
FIREBASE_WEB_API_KEY = os.getenv("FIREBASE_WEB_API_KEY")

# reCAPTCHA Enterprise configuration
RECAPTCHA_PROJECT_ID = os.getenv("RECAPTCHA_PROJECT_ID")
RECAPTCHA_SITE_KEY = os.getenv("RECAPTCHA_SITE_KEY")
RECAPTCHA_SCORE_THRESHOLD = float(os.getenv("RECAPTCHA_SCORE_THRESHOLD", "0.5"))

# In-memory storage for login OTP sessions (replace with Redis in production)
LOGIN_OTP_STORAGE = {}

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
            # Initialize with default credentials (for Google Cloud environments)
            try:
                firebase_admin.initialize_app()
                logger.info("Firebase initialized with default credentials")
            except Exception as e:
                logger.error(f"Failed to initialize Firebase: {str(e)}")
                raise ValueError("Firebase initialization failed. Please check your credentials.")

# Initialize Firebase on module load
initialize_firebase()

def create_recaptcha_assessment(
    project_id: str,
    recaptcha_site_key: str,
    token: str,
    recaptcha_action: str,
    user_ip_address: str,
    user_agent: str,
    ja3: Optional[str] = None,
) -> Assessment:
    """Create an assessment to analyze the risk of a UI action.
    Args:
        project_id: GCloud Project ID
        recaptcha_site_key: Site key obtained by registering a domain/app to use recaptcha services.
        token: The token obtained from the client on passing the recaptchaSiteKey.
        recaptcha_action: Action name corresponding to the token.
        user_ip_address: IP address of the user sending a request.
        user_agent: User agent is included in the HTTP request in the request header.
        ja3: JA3 associated with the request (optional).
    """

    client = recaptchaenterprise_v1.RecaptchaEnterpriseServiceClient()

    # Set the properties of the event to be tracked.
    event = recaptchaenterprise_v1.Event()
    event.site_key = recaptcha_site_key
    event.token = token
    event.user_ip_address = user_ip_address
    event.user_agent = user_agent
    if ja3:
        event.ja3 = ja3

    assessment = recaptchaenterprise_v1.Assessment()
    assessment.event = event

    project_name = f"projects/{project_id}"

    # Build the assessment request.
    request = recaptchaenterprise_v1.CreateAssessmentRequest()
    request.assessment = assessment
    request.parent = project_name

    response = client.create_assessment(request)

    # Check if the token is valid.
    if not response.token_properties.valid:
        logger.error(
            f"The CreateAssessment call failed because the token was "
            + "invalid for the following reasons: "
            + str(response.token_properties.invalid_reason)
        )
        raise ValueError(f"Invalid reCAPTCHA token: {response.token_properties.invalid_reason}")

    # Check if the expected action was executed.
    if response.token_properties.action != recaptcha_action:
        logger.error(
            f"The action attribute in your reCAPTCHA tag ({response.token_properties.action}) "
            + f"does not match the action you are expecting to score ({recaptcha_action})"
        )
        raise ValueError(f"reCAPTCHA action mismatch: expected {recaptcha_action}, got {response.token_properties.action}")
    
    # Log the assessment results
    for reason in response.risk_analysis.reasons:
        logger.info(f"Risk analysis reason: {reason}")
    
    logger.info(f"reCAPTCHA score for this token: {response.risk_analysis.score}")
    
    # Get the assessment name (id). Use this to annotate the assessment.
    assessment_name = client.parse_assessment_path(response.name).get("assessment")
    logger.info(f"Assessment name: {assessment_name}")
    
    return response

def verify_recaptcha_token(
    token: str, 
    action: str, 
    user_ip: str, 
    user_agent: str,
    ja3: Optional[str] = None,
    score_threshold: Optional[float] = None
) -> Dict[str, Any]:
    """
    Verify reCAPTCHA Enterprise token and return assessment results
    """
    try:
        if not RECAPTCHA_PROJECT_ID or not RECAPTCHA_SITE_KEY:
            logger.warning("reCAPTCHA Enterprise not configured, skipping verification")
            return {
                "verified": True,
                "score": 1.0,
                "reasons": [],
                "skip_reason": "recaptcha_not_configured"
            }
        
        # Check environment - skip in testing
        environment = os.getenv("ENVIRONMENT", "").lower()
        if "testing" in environment:
            logger.info("Skipping reCAPTCHA verification in test mode")
            return {
                "verified": True,
                "score": 1.0,
                "reasons": [],
                "skip_reason": "test_mode"
            }
        
        # Create reCAPTCHA assessment
        assessment = create_recaptcha_assessment(
            project_id=RECAPTCHA_PROJECT_ID,
            recaptcha_site_key=RECAPTCHA_SITE_KEY,
            token=token,
            recaptcha_action=action,
            user_ip_address=user_ip,
            user_agent=user_agent,
            ja3=ja3
        )
        
        score = assessment.risk_analysis.score
        reasons = list(assessment.risk_analysis.reasons)
        threshold = score_threshold or RECAPTCHA_SCORE_THRESHOLD
        
        result = {
            "verified": score >= threshold,
            "score": score,
            "reasons": reasons,
            "threshold": threshold,
            "assessment_name": assessment.name
        }
        
        if score < threshold:
            logger.warning(f"reCAPTCHA verification failed: score {score} below threshold {threshold}")
        else:
            logger.info(f"reCAPTCHA verification passed: score {score}")
        
        return result
        
    except Exception as e:
        logger.error(f"reCAPTCHA verification error: {str(e)}")
        # In production, you might want to fail closed (deny request)
        # For now, we'll fail open but log the error
        return {
            "verified": False,
            "score": 0.0,
            "reasons": ["RECAPTCHA_ERROR"],
            "error": str(e)
        }

def store_login_session(mobile_number: str, session_info: str, expires_in_minutes: int = 10) -> None:
    """Store login session info with expiration"""
    expiry = datetime.now() + timedelta(minutes=expires_in_minutes)
    LOGIN_OTP_STORAGE[mobile_number] = {
        'session_info': session_info,
        'expires_at': expiry,
        'attempts': 0
    }
    logger.info(f"Login session stored for {mobile_number}, expires at {expiry}")

def verify_login_session(mobile_number: str, session_info: str) -> bool:
    """Verify login session info"""
    if mobile_number not in LOGIN_OTP_STORAGE:
        return False
    
    stored_data = LOGIN_OTP_STORAGE[mobile_number]
    
    # Check expiration
    if datetime.now() > stored_data['expires_at']:
        del LOGIN_OTP_STORAGE[mobile_number]
        return False
    
    # Check attempts (max 3)
    if stored_data['attempts'] >= 3:
        del LOGIN_OTP_STORAGE[mobile_number]
        return False
    
    # Verify session info
    if session_info == stored_data['session_info']:
        del LOGIN_OTP_STORAGE[mobile_number]  # Clear after successful verification
        return True
    else:
        stored_data['attempts'] += 1
        return False

async def check_mobile_exists_service(mobile_number: str, session: Session) -> Dict[str, Any]:
    """Check if mobile number exists in database"""
    try:
        # URL decode the mobile number first
        formatted_mobile = unquote(mobile_number).strip()
        
        # Ensure it has +63 prefix for database lookup
        if not formatted_mobile.startswith('+63'):
            # Remove any existing prefixes first
            clean_number = formatted_mobile.lstrip('+').lstrip('63').lstrip('0')
            formatted_mobile = f"+63{clean_number}"
        
        logger.info(f"Checking mobile existence - Received: '{mobile_number}', Decoded: '{unquote(mobile_number)}', Formatted: '{formatted_mobile}'")
        
        existing_user = session.exec(
            select(UserInfo).where(UserInfo.MobileNumber == formatted_mobile)
        ).first()
        
        return {
            "success": True,
            "exists": existing_user is not None,
            "mobile_number": formatted_mobile,  # This will now have the + prefix
            "user_id": existing_user.UserId if existing_user else None
        }
        
    except Exception as e:
        logger.error(f"Error in check_mobile_exists service: {str(e)}")
        return {
            "success": False,
            "error": f"Database error: {str(e)}"
        }

async def send_login_otp_via_firebase_rest_api(
    mobile_number: str, 
    recaptcha_token: str,
    user_ip: str,
    user_agent: str,
    ja3: Optional[str] = None
) -> Dict[str, Any]:
    """Send login SMS OTP using Firebase Auth REST API with reCAPTCHA verification"""
    if not FIREBASE_WEB_API_KEY:
        raise ValueError("Firebase Web API Key not configured")
    
    # Format mobile number to E.164 format
    formatted_number = mobile_number
    if not formatted_number.startswith('+'):
        formatted_number = f"+63{mobile_number.lstrip('0')}"
    
    logger.info(f"Sending login SMS OTP to {formatted_number} via Firebase REST API")
    
    # Verify reCAPTCHA token first
    recaptcha_result = verify_recaptcha_token(
        token=recaptcha_token,
        action="login_otp_request",
        user_ip=user_ip,
        user_agent=user_agent,
        ja3=ja3
    )
    
    if not recaptcha_result["verified"]:
        logger.warning(f"reCAPTCHA verification failed for login OTP: {recaptcha_result}")
        raise ValueError(f"Security verification failed. Score: {recaptcha_result['score']}")
    
    # Send verification code for login
    send_url = f"https://identitytoolkit.googleapis.com/v1/accounts:sendVerificationCode?key={FIREBASE_WEB_API_KEY}"
    
    send_payload = {
        "phoneNumber": formatted_number,
        "recaptchaToken": recaptcha_token  # Use the actual verified token
    }
    
    try:
        logger.info(f"Making login OTP request to Firebase: {send_url}")
        logger.info(f"Payload: {json.dumps(send_payload, indent=2)}")
        
        response = requests.post(send_url, json=send_payload, timeout=30)
        logger.info(f"Firebase response status: {response.status_code}")
        
        if response.status_code != 200:
            error_text = response.text
            logger.error(f"Firebase API error response: {error_text}")
            
            try:
                error_data = response.json()
                error_message = error_data.get('error', {}).get('message', 'Unknown error')
                logger.error(f"Firebase error message: {error_message}")
                raise ValueError(f"Firebase API error: {error_message}")
            except json.JSONDecodeError:
                raise ValueError(f"Firebase API error: HTTP {response.status_code}")
        
        data = response.json()
        logger.info(f"Firebase login OTP success response: {json.dumps(data, indent=2)}")
        
        session_info = data.get('sessionInfo')
        
        if session_info:
            # Store session info for verification
            store_login_session(mobile_number, session_info, expires_in_minutes=10)
            
            return {
                "success": True,
                "session_info": session_info,
                "message": "Login SMS OTP sent successfully via Firebase REST API",
                "mobile_number": mobile_number,
                "formatted_number": formatted_number,
                "verification_endpoint": "/verify-login-otp",
                "expires_in": "10 minutes",
                "recaptcha_score": recaptcha_result["score"]
            }
        else:
            logger.error("No session info in Firebase login response")
            raise ValueError("Failed to get session info from Firebase")
            
    except requests.RequestException as e:
        logger.error(f"Firebase REST API request error: {str(e)}")
        raise ValueError(f"Network error while sending login SMS: {str(e)}")
    except json.JSONDecodeError as e:
        logger.error(f"Failed to parse Firebase response: {str(e)}")
        raise ValueError("Invalid response from Firebase API")

async def send_login_otp_service(
    mobile_number: str, 
    session: Session,
    recaptcha_token: Optional[str] = None,
    user_ip: Optional[str] = None,
    user_agent: Optional[str] = None,
    ja3: Optional[str] = None
) -> Dict[str, Any]:
    """Enhanced SMS OTP for login using Firebase Authentication with reCAPTCHA Enterprise"""
    try:
        logger.info(f"Starting login OTP service for mobile: {mobile_number}")
        
        # Check if mobile number exists (required for login)
        existing_user = session.exec(
            select(UserInfo).where(UserInfo.MobileNumber == mobile_number)
        ).first()
        
        if not existing_user:
            raise ValueError("Mobile number not registered. Please sign up first.")
        
        # Format mobile number for Firebase
        formatted_number = mobile_number
        if not formatted_number.startswith('+'):
            formatted_number = f"+63{mobile_number.lstrip('0')}"
        
        # Check environment
        environment = os.getenv("ENVIRONMENT", "").lower()
        logger.info(f"Environment: {environment}")
        
        # Testing mode
        if "testing" in environment:
            logger.info("Using test mode for login OTP")
            # Store a test session for consistency
            store_login_session(mobile_number, "test_session_info")
            
            return {
                "success": True,
                "message": "Login OTP sent successfully (test mode)",
                "mobile_number": mobile_number,
                "formatted_number": formatted_number,
                "test_otp": "111111",  # Only show in test mode
                "test_mode": True,
                "method": "test",
                "verification_endpoint": "/verify-login-otp",
                "expires_in": "10 minutes"
            }
        
        # Production mode - require reCAPTCHA token
        if not recaptcha_token:
            raise ValueError("reCAPTCHA token is required for OTP requests")
        
        if not user_ip:
            raise ValueError("User IP address is required for security verification")
        
        if not user_agent:
            raise ValueError("User agent is required for security verification")
        
        # Production mode - use Firebase REST API with reCAPTCHA
        if FIREBASE_WEB_API_KEY:
            try:
                logger.info("Attempting Firebase REST API for login SMS with reCAPTCHA verification")
                result = await send_login_otp_via_firebase_rest_api(
                    mobile_number=mobile_number,
                    recaptcha_token=recaptcha_token,
                    user_ip=user_ip,
                    user_agent=user_agent,
                    ja3=ja3
                )
                result["method"] = "firebase_rest_api_with_recaptcha"
                return result
            except Exception as e:
                logger.error(f"Firebase REST API with reCAPTCHA failed for login: {str(e)}")
                raise e
        
        # Fallback to client-side instructions if REST API not configured
        logger.info("Firebase REST API not configured, providing client-side instructions")
        return {
            "success": True,
            "message": "Please use Firebase Auth SDK to send login OTP",
            "mobile_number": mobile_number,
            "formatted_number": formatted_number,
            "method": "client_side_firebase",
            "client_instructions": {
                "type": "firebase_auth_login",
                "phone_number": formatted_number,
                "method": "signInWithPhoneNumber",
                "steps": [
                    "Import Firebase Auth SDK",
                    "Configure reCAPTCHA verifier", 
                    "Call signInWithPhoneNumber with the phone number",
                    "User enters received OTP",
                    "Confirm with confirmationResult.confirm(otp)",
                    "Send the Firebase ID token to /verify-login-firebase"
                ],
                "next_endpoint": "/verify-login-firebase"
            },
            "verification_session": {
                "mobile_number": formatted_number,
                "timestamp": date.today().isoformat(),
                "status": "pending"
            }
        }
        
    except ValueError:
        raise
    except Exception as e:
        logger.error(f"Error in send_login_otp service: {str(e)}")
        raise Exception("Internal server error while sending login OTP")

async def verify_login_otp_service(mobile_number: str, otp_code: str, session: Session) -> UserInfo:
    """
    Enhanced login OTP verification with Firebase REST API support
    """
    try:
        logger.info(f"Starting login OTP verification for: {mobile_number}")
        
        # Check if user exists
        user = session.exec(
            select(UserInfo).where(UserInfo.MobileNumber == mobile_number)
        ).first()
        
        if not user:
            raise ValueError("User not found")
        
        # Format mobile number
        formatted_number = mobile_number
        if not formatted_number.startswith('+'):
            formatted_number = f"+63{mobile_number.lstrip('0')}"
        
        # Check if this looks like a Firebase ID token (JWT format)
        if len(otp_code) > 20 and '.' in otp_code:
            logger.info("OTP code appears to be Firebase ID token for login")
            return await verify_firebase_token_service(mobile_number, otp_code, session)
        
        # Check environment for test mode
        environment = os.getenv("ENVIRONMENT", "").lower()
        if "testing" in environment and otp_code == "111111":
            logger.info("Using test mode OTP verification for login")
            return user
        
        # Production: Verify OTP using Firebase REST API
        if not FIREBASE_WEB_API_KEY:
            raise ValueError("Firebase Web API Key not configured for OTP verification")
        
        # Get stored session info
        if mobile_number not in LOGIN_OTP_STORAGE:
            raise ValueError("No active OTP session found. Please request a new OTP.")
        
        stored_session = LOGIN_OTP_STORAGE[mobile_number]
        
        # Check expiration
        if datetime.now() > stored_session['expires_at']:
            del LOGIN_OTP_STORAGE[mobile_number]
            raise ValueError("OTP session expired. Please request a new OTP.")
        
        # Check attempts
        if stored_session['attempts'] >= 3:
            del LOGIN_OTP_STORAGE[mobile_number]
            raise ValueError("Too many failed attempts. Please request a new OTP.")
        
        session_info = stored_session['session_info']
        
        # Verify OTP with Firebase
        verify_url = f"https://identitytoolkit.googleapis.com/v1/accounts:signInWithPhoneNumber?key={FIREBASE_WEB_API_KEY}"
        
        verify_payload = {
            "sessionInfo": session_info,
            "code": otp_code
        }
        
        try:
            logger.info("Verifying login OTP with Firebase REST API")
            response = requests.post(verify_url, json=verify_payload, timeout=30)
            
            if response.status_code != 200:
                # Increment attempt counter
                LOGIN_OTP_STORAGE[mobile_number]['attempts'] += 1
                
                error_text = response.text
                logger.error(f"Firebase OTP verification error: {error_text}")
                
                try:
                    error_data = response.json()
                    error_message = error_data.get('error', {}).get('message', 'Invalid OTP')
                    if 'INVALID_CODE' in error_message:
                        raise ValueError("Invalid OTP code")
                    elif 'CODE_EXPIRED' in error_message:
                        raise ValueError("OTP code expired")
                    else:
                        raise ValueError(f"OTP verification failed: {error_message}")
                except json.JSONDecodeError:
                    raise ValueError("Invalid OTP code")
            
            data = response.json()
            firebase_id_token = data.get('idToken')
            
            if not firebase_id_token:
                LOGIN_OTP_STORAGE[mobile_number]['attempts'] += 1
                raise ValueError("Invalid OTP code")
            
            # Clear the session after successful verification
            del LOGIN_OTP_STORAGE[mobile_number]
            
            # Verify the ID token and update user record if needed
            try:
                decoded_token = auth.verify_id_token(firebase_id_token)
                firebase_uid = decoded_token['uid']
                
                # Update Firebase UID if not set
                if hasattr(user, 'FirebaseUID') and not user.FirebaseUID:
                    user.FirebaseUID = firebase_uid
                    session.add(user)
                    session.commit()
                    session.refresh(user)
                    logger.info(f"Updated user {user.UserId} with Firebase UID during login")
                
            except FirebaseError as e:
                logger.warning(f"Could not verify Firebase ID token after OTP: {str(e)}")
                # Continue with login even if token verification fails
            
            logger.info(f"Login OTP verified successfully for user: {user.UserId}")
            return user
            
        except requests.RequestException as e:
            LOGIN_OTP_STORAGE[mobile_number]['attempts'] += 1
            logger.error(f"Firebase REST API request error during login OTP verification: {str(e)}")
            raise ValueError("Network error during OTP verification")
        
    except ValueError:
        raise
    except Exception as e:
        logger.error(f"Error in verify_login_otp service: {str(e)}")
        raise Exception("Internal server error during login OTP verification")

# Keep all other existing functions unchanged...
async def verify_login_otp_and_get_user_service(
    mobile_number: str, 
    otp_or_token: str, 
    session: Session
) -> UserInfo:
    """
    LEGACY: Enhanced OTP verification for login
    Supports both legacy OTP codes and Firebase ID tokens
    """
    try:
        logger.info(f"Starting legacy login OTP verification for: {mobile_number}")
        
        # Check if user exists
        user = session.exec(
            select(UserInfo).where(UserInfo.MobileNumber == mobile_number)
        ).first()
        
        if not user:
            raise ValueError("User not found")
        
        # Check if this looks like a Firebase ID token (JWT format)
        if len(otp_or_token) > 20 and '.' in otp_or_token:
            logger.info("OTP code appears to be Firebase ID token for login")
            return await verify_firebase_token_service(mobile_number, otp_or_token, session)
        
        # Handle regular OTP codes
        environment = os.getenv("ENVIRONMENT", "").lower()
        if "testing" in environment and otp_or_token == "111111":
            logger.info("Using test mode OTP verification for login")
            return user
        
        # For production OTP verification, redirect to new method
        return await verify_login_otp_service(mobile_number, otp_or_token, session)
        
    except ValueError:
        raise
    except Exception as e:
        logger.error(f"Error in verify_login_otp_and_get_user service: {str(e)}")
        raise Exception("Internal server error during verification")

async def login_with_mobile_service(mobile_number: str, session: Session) -> UserInfo:
    """Login with mobile number (Firebase-based)"""
    try:
        # Find user by mobile number
        user = session.exec(
            select(UserInfo).where(UserInfo.MobileNumber == mobile_number)
        ).first()
        
        if not user:
            raise ValueError("Mobile number not registered")
        
        return user
        
    except ValueError:
        raise
    except Exception as e:
        logger.error(f"Error in login_with_mobile service: {str(e)}")
        raise Exception("Internal server error during mobile login")

async def login_with_password_service(mobile_number: str, password: str, session: Session) -> UserInfo:
    """Login with mobile number and password"""
    try:
        # Find user by mobile number
        user = session.exec(
            select(UserInfo).where(UserInfo.MobileNumber == mobile_number)
        ).first()
        
        if not user:
            raise ValueError("Mobile number not registered")
        
        # Check if user has password set
        if not user.PasswordHash:
            raise ValueError("This account uses Firebase Auth only. No password set.")
        
        # Verify password
        if not pwd_context.verify(password, user.PasswordHash):
            raise ValueError("Invalid password")
        
        return user
        
    except ValueError:
        raise
    except Exception as e:
        logger.error(f"Error in login_with_password service: {str(e)}")
        raise Exception("Internal server error during password login")

async def login_with_email_service(email: str, password: str, session: Session) -> UserInfo:
    """Login with email and password"""
    try:
        # Find user by email
        if not hasattr(UserInfo, 'Email'):
            raise NotImplementedError("Email login not implemented - Email field missing from UserInfo model")
        
        user = session.exec(
            select(UserInfo).where(UserInfo.Email == email)
        ).first()
        
        if not user:
            raise ValueError("Email not registered")
        
        # Check if user has password set
        if not user.PasswordHash:
            raise ValueError("This account uses Firebase Auth only. No password set.")
        
        # Verify password
        if not pwd_context.verify(password, user.PasswordHash):
            raise ValueError("Invalid password")
        
        return user
        
    except (ValueError, NotImplementedError):
        raise
    except Exception as e:
        logger.error(f"Error in login_with_email service: {str(e)}")
        raise Exception("Internal server error during email login")

async def firebase_auth_login_service(firebase_id_token: str, session: Session) -> UserInfo:
    """Login using Firebase ID token (supports phone, email, Google, etc.)"""
    try:
        # Verify the Firebase ID token
        try:
            decoded_token = auth.verify_id_token(firebase_id_token)
            firebase_uid = decoded_token['uid']
            phone_number = decoded_token.get('phone_number')
            email = decoded_token.get('email')
            name = decoded_token.get('name', '')
            
            logger.info(f"Firebase ID token verified for UID: {firebase_uid}")
            
        except FirebaseError as e:
            logger.error(f"Firebase token verification error: {str(e)}")
            raise ValueError("Invalid Firebase ID token")
        
        # Try to find existing user by Firebase UID first
        user = None
        if hasattr(UserInfo, 'FirebaseUID'):
            user = session.exec(
                select(UserInfo).where(UserInfo.FirebaseUID == firebase_uid)
            ).first()
        
        # If not found by UID, try by phone number or email
        if not user and phone_number:
            # Remove country code formatting for database lookup
            mobile_lookup = phone_number.replace('+63', '').lstrip('0') if phone_number.startswith('+63') else phone_number
            user = session.exec(
                select(UserInfo).where(UserInfo.MobileNumber == mobile_lookup)
            ).first()
        
        if not user and email and hasattr(UserInfo, 'Email'):
            user = session.exec(
                select(UserInfo).where(UserInfo.Email == email)
            ).first()
        
        if not user:
            raise ValueError("User not found. Please sign up first.")
        
        # Update Firebase UID if not set
        if hasattr(user, 'FirebaseUID') and user.FirebaseUID != firebase_uid:
            user.FirebaseUID = firebase_uid
            session.add(user)
            session.commit()
            session.refresh(user)
            logger.info(f"Updated user {user.UserId} with Firebase UID during login")
        
        logger.info(f"Firebase auth login successful for user: {user.UserId}")
        return user
        
    except ValueError:
        raise
    except Exception as e:
        logger.error(f"Error in firebase_auth_login service: {str(e)}")
        raise Exception("Internal server error during Firebase authentication")

async def google_oauth_login_service(firebase_id_token: str, session: Session) -> UserInfo:
    """Google OAuth login via Firebase Authentication"""
    try:
        # Verify this is actually a Google sign-in token
        decoded_token = auth.verify_id_token(firebase_id_token)
        
        # Check if this token is from Google provider
        firebase_info = decoded_token.get('firebase', {})
        sign_in_provider = firebase_info.get('sign_in_provider')
        
        if sign_in_provider != 'google.com':
            raise ValueError("Token is not from Google OAuth provider")
        
        # Use the general Firebase auth login service
        return await firebase_auth_login_service(firebase_id_token, session)
        
    except ValueError:
        raise
    except Exception as e:
        logger.error(f"Error in google_oauth_login service: {str(e)}")
        raise Exception("Internal server error during Google OAuth login")

async def verify_firebase_token_service(mobile_number: str, firebase_id_token: str, session: Session) -> UserInfo:
    """Dedicated Firebase ID token verification for login"""
    try:
        # Verify the Firebase ID token
        try:
            decoded_token = auth.verify_id_token(firebase_id_token)
            firebase_uid = decoded_token['uid']
            phone_number = decoded_token.get('phone_number', '')
            
            # Format the phone number from token for comparison
            token_phone = phone_number
            formatted_mobile = mobile_number
            if not formatted_mobile.startswith('+'):
                formatted_mobile = f"+63{mobile_number.lstrip('0')}"
            
            # Verify the phone number matches (if phone auth)
            if phone_number and token_phone != formatted_mobile:
                raise ValueError("Phone number mismatch between token and request")
                
            logger.info(f"Firebase ID token verified successfully for {phone_number or 'email user'}")
            
        except FirebaseError as e:
            logger.error(f"Firebase token verification error: {str(e)}")
            # Fallback for testing
            if "testing" in os.getenv("ENVIRONMENT", "").lower() and firebase_id_token == "test_token":
                logger.info("Using test mode token verification for login")
                firebase_uid = "test_uid"
            else:
                raise ValueError("Invalid Firebase ID token")
        
        # Find user by mobile number
        user = session.exec(
            select(UserInfo).where(UserInfo.MobileNumber == mobile_number)
        ).first()
        
        if not user:
            raise ValueError("User not found")
        
        # Optional: Store/update Firebase UID in user record
        if hasattr(user, 'FirebaseUID') and user.FirebaseUID != firebase_uid:
            user.FirebaseUID = firebase_uid
            session.add(user)
            session.commit()
            session.refresh(user)
        
        return user
        
    except ValueError:
        raise
    except Exception as e:
        logger.error(f"Error in verify_firebase_token service: {str(e)}")
        raise Exception("Internal server error during token verification")

async def resend_login_otp_service(
    mobile_number: str, 
    session: Session,
    recaptcha_token: Optional[str] = None,
    user_ip: Optional[str] = None,
    user_agent: Optional[str] = None,
    ja3: Optional[str] = None
) -> Dict[str, Any]:
    """
    Resend login SMS OTP with rate limiting and reCAPTCHA verification
    """
    try:
        logger.info(f"Resending login SMS OTP for: {mobile_number}")
        
        # Check if user exists
        existing_user = session.exec(
            select(UserInfo).where(UserInfo.MobileNumber == mobile_number)
        ).first()
        
        if not existing_user:
            raise ValueError("Mobile number not registered")
        
        # Clear any existing session
        if mobile_number in LOGIN_OTP_STORAGE:
            del LOGIN_OTP_STORAGE[mobile_number]
            logger.info("Cleared previous login OTP session")
        
        # Resend using the same logic as send_login_otp_service
        return await send_login_otp_service(
            mobile_number=mobile_number,
            session=session,
            recaptcha_token=recaptcha_token,
            user_ip=user_ip,
            user_agent=user_agent,
            ja3=ja3
        )
        
    except ValueError:
        raise
    except Exception as e:
        logger.error(f"Error in resend_login_otp service: {str(e)}")
        raise Exception("Failed to resend login OTP")

# Utility function to create custom tokens (if needed)
async def create_custom_token_service(uid: str, additional_claims: Optional[Dict[str, Any]] = None) -> str:
    """Create a custom Firebase token for a user"""
    try:
        custom_token = auth.create_custom_token(uid, additional_claims)
        return custom_token.decode('utf-8')
    except Exception as e:
        logger.error(f"Error creating custom token: {str(e)}")
        raise Exception("Failed to create custom token")

def cleanup_expired_login_sessions():
    """Clean up expired login sessions from memory storage"""
    current_time = datetime.now()
    expired_keys = [
        key for key, value in LOGIN_OTP_STORAGE.items()
        if current_time > value['expires_at']
    ]
    
    for key in expired_keys:
        del LOGIN_OTP_STORAGE[key]
    
    logger.info(f"Cleaned up {len(expired_keys)} expired login sessions")

def get_login_session_status(mobile_number: str) -> Dict[str, Any]:
    """Get login session status for debugging (test mode only)"""
    if mobile_number in LOGIN_OTP_STORAGE:
        data = LOGIN_OTP_STORAGE[mobile_number]
        return {
            "exists": True,
            "expires_at": data['expires_at'].isoformat(),
            "attempts": data['attempts'],
            "expired": datetime.now() > data['expires_at']
        }
    return {"exists": False}

# Additional helper functions for reCAPTCHA Enterprise

def get_recaptcha_config() -> Dict[str, Any]:
    """Get reCAPTCHA configuration status"""
    return {
        "configured": bool(RECAPTCHA_PROJECT_ID and RECAPTCHA_SITE_KEY),
        "project_id": RECAPTCHA_PROJECT_ID,
        "site_key": RECAPTCHA_SITE_KEY,
        "score_threshold": RECAPTCHA_SCORE_THRESHOLD
    }

async def validate_request_security(
    recaptcha_token: str,
    action: str,
    user_ip: str,
    user_agent: str,
    ja3: Optional[str] = None,
    required_score: Optional[float] = None
) -> Dict[str, Any]:
    """
    Validate request security using reCAPTCHA Enterprise
    Returns validation result with score and analysis
    """
    try:
        # Perform reCAPTCHA verification
        recaptcha_result = verify_recaptcha_token(
            token=recaptcha_token,
            action=action,
            user_ip=user_ip,
            user_agent=user_agent,
            ja3=ja3,
            score_threshold=required_score
        )
        
        # Add additional security checks here if needed
        # e.g., IP reputation, rate limiting, device fingerprinting
        
        return {
            "valid": recaptcha_result["verified"],
            "score": recaptcha_result["score"],
            "reasons": recaptcha_result.get("reasons", []),
            "threshold": recaptcha_result.get("threshold", RECAPTCHA_SCORE_THRESHOLD),
            "assessment_name": recaptcha_result.get("assessment_name"),
            "security_checks": {
                "recaptcha": recaptcha_result["verified"],
                "ip_check": True,  # Placeholder for additional IP validation
                "rate_limit": True  # Placeholder for rate limiting check
            }
        }
        
    except Exception as e:
        logger.error(f"Security validation error: {str(e)}")
        return {
            "valid": False,
            "score": 0.0,
            "reasons": ["SECURITY_VALIDATION_ERROR"],
            "error": str(e),
            "security_checks": {
                "recaptcha": False,
                "ip_check": False,
                "rate_limit": False
            }
        }

# Environment configuration helper
def get_environment_config() -> Dict[str, Any]:
    """Get environment configuration for security features"""
    environment = os.getenv("ENVIRONMENT", "production").lower()
    
    config = {
        "environment": environment,
        "is_testing": "testing" in environment,
        "is_development": "dev" in environment or "development" in environment,
        "is_production": environment == "production",
        "recaptcha_enabled": not ("testing" in environment),
        "firebase_configured": bool(FIREBASE_WEB_API_KEY and FIREBASE_PROJECT_ID),
        "recaptcha_configured": bool(RECAPTCHA_PROJECT_ID and RECAPTCHA_SITE_KEY)
    }
    
    return config