import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/user_model.dart';
import 'session_service.dart';
import '../config/api_config.dart';

class UserApiService {
  final http.Client _client;
  late String baseUrl;

  UserApiService({http.Client? client}) : _client = client ?? http.Client() {
    // Single source of truth for API base URL
    if (kIsWeb) {
      baseUrl = "http://localhost:8000"; // Web
    } else if (Platform.isAndroid) {
      baseUrl =
          "http://192.168.100.195:8000"; // Android - matches your login.dart
    } else if (Platform.isIOS) {
      baseUrl = "http://localhost:8000"; // iOS simulator
    } else {
      baseUrl = "http://localhost:8000"; // Desktop/other
    }

    print('UserApiService initialized with baseUrl: $baseUrl');
  }

  // ===============================
  // REGISTRATION METHODS
  // ===============================

  /// Check if mobile number already exists during registration
  Future<bool> checkMobileExists(String mobileNumber) async {
    try {
      print('Checking if mobile exists: $mobileNumber');
      final response = await _client
          .get(
            Uri.parse(
              '$baseUrl/users/check-mobile?mobile_number=$mobileNumber',
            ),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(const Duration(seconds: 15));

      print('Check mobile response: ${response.statusCode}');
      print('Check mobile body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        return responseData['exists'] ?? false;
      }
      return false;
    } catch (e) {
      print('Error checking mobile exists: $e');
      return false; // Assume doesn't exist on error to allow registration attempt
    }
  }

  /// Send SMS OTP for registration
  Future<SMSResponse> sendRegistrationSMS(String mobileNumber) async {
    try {
      print('Sending registration SMS to: $mobileNumber');

      final request = SMSRequest(mobileNumber: mobileNumber);
      final response = await _client
          .post(
            Uri.parse('$baseUrl/users/send-sms'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(request.toJson()),
          )
          .timeout(const Duration(seconds: 30));

      print('Registration SMS response: ${response.statusCode}');
      print('Registration SMS body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        return SMSResponse.fromJson(responseData);
      } else {
        final errorData = json.decode(response.body);
        return SMSResponse.error(errorData['detail'] ?? 'Failed to send SMS');
      }
    } catch (e) {
      print('Error sending registration SMS: $e');
      return SMSResponse.error('Network error: ${e.toString()}');
    }
  }

  /// Verify OTP and create user account
  Future<AuthResponse> verifyOTPAndCreateUser({
    required String mobileNumber,
    required String otpCode,
    required String firstName,
    required String lastName,
  }) async {
    try {
      print('Verifying OTP and creating user for: $mobileNumber');

      final request = OTPVerificationRequest(
        mobileNumber: mobileNumber,
        otpCode: otpCode,
        firstName: firstName,
        lastName: lastName,
      );

      final response = await _client
          .post(
            Uri.parse('$baseUrl/users/verify-otp'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(request.toJson()),
          )
          .timeout(const Duration(seconds: 30));

      print('OTP verification response: ${response.statusCode}');
      print('OTP verification body: ${response.body}');

      if (response.statusCode == 201) {
        final responseData = json.decode(response.body);
        return AuthResponse.fromJson(responseData);
      } else {
        final errorData = json.decode(response.body);
        return AuthResponse.error(
          errorData['detail'] ?? 'OTP verification failed',
        );
      }
    } catch (e) {
      print('Error verifying OTP: $e');
      return AuthResponse.error('Network error: ${e.toString()}');
    }
  }

  // ===============================
  // LOGIN METHODS
  // ===============================

  /// Send SMS OTP for login (mobile number must exist)
  Future<SMSResponse> sendLoginSMS(String mobileNumber) async {
    try {
      print('Sending login SMS to: $mobileNumber');

      final request = SMSRequest(mobileNumber: mobileNumber);
      final response = await _client
          .post(
            Uri.parse('$baseUrl/users/send-login-otp'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(request.toJson()),
          )
          .timeout(const Duration(seconds: 30));

      print('Login SMS response: ${response.statusCode}');
      print('Login SMS body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        return SMSResponse.fromJson(responseData);
      } else {
        final errorData = json.decode(response.body);
        return SMSResponse.error(
          errorData['detail'] ?? 'Failed to send login SMS',
        );
      }
    } catch (e) {
      print('Error sending login SMS: $e');
      return SMSResponse.error('Network error: ${e.toString()}');
    }
  }

  /// Verify OTP for login (user must exist)
  Future<AuthResponse> verifyLoginOTP({
    required String mobileNumber,
    required String otpCode,
  }) async {
    try {
      print('Verifying login OTP for: $mobileNumber');

      // For login OTP, we only need mobile and OTP, but backend expects full request
      final request = OTPVerificationRequest(
        mobileNumber: mobileNumber,
        otpCode: otpCode,
        firstName: '', // Not used for login
        lastName: '', // Not used for login
      );

      final response = await _client
          .post(
            Uri.parse('$baseUrl/users/verify-login-otp'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(request.toJson()),
          )
          .timeout(const Duration(seconds: 30));

      print('Login OTP verification response: ${response.statusCode}');
      print('Login OTP verification body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        return AuthResponse.fromJson(responseData);
      } else {
        final errorData = json.decode(response.body);
        return AuthResponse.error(
          errorData['detail'] ?? 'Login OTP verification failed',
        );
      }
    } catch (e) {
      print('Error verifying login OTP: $e');
      return AuthResponse.error('Network error: ${e.toString()}');
    }
  }

  /// Login with mobile number (direct login without OTP)
  Future<AuthResponse> loginWithMobile(String mobileNumber) async {
    try {
      print('Login with mobile: $mobileNumber');

      final request = LoginRequest(mobileNumber: mobileNumber);
      final response = await _client
          .post(
            Uri.parse('$baseUrl/users/login-mobile'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(request.toJson()),
          )
          .timeout(const Duration(seconds: 30));

      print('Mobile login response: ${response.statusCode}');
      print('Mobile login body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        return AuthResponse.fromJson(responseData);
      } else {
        final errorData = json.decode(response.body);
        return AuthResponse.error(errorData['detail'] ?? 'Mobile login failed');
      }
    } catch (e) {
      print('Error during mobile login: $e');
      return AuthResponse.error('Network error: ${e.toString()}');
    }
  }

  // ===============================
  // USER MANAGEMENT METHODS
  // ===============================

  /// Get user by ID
  Future<User?> getUserById(int userId) async {
    try {
      print('Fetching user by ID: $userId');

      final response = await _client
          .get(
            Uri.parse('$baseUrl/users/$userId'),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(const Duration(seconds: 15));

      print('Get user response: ${response.statusCode}');
      print('Get user body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        return User.fromJson(responseData);
      } else {
        print('User not found or error: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Error fetching user: $e');
      return null;
    }
  }

  /// Get contact/user info by mobile number
  /// This is the main method you requested for accessing contact info
  Future<User?> getContactByMobile(String mobileNumber) async {
    try {
      print('Fetching contact by mobile: $mobileNumber');

      // First check if mobile exists and get basic info
      final response = await _client
          .get(
            Uri.parse(
              '$baseUrl/users/check-mobile?mobile_number=$mobileNumber',
            ),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(const Duration(seconds: 15));

      print('Get contact response: ${response.statusCode}');
      print('Get contact body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);

        if (responseData['exists'] == true) {
          // If user exists, try to login to get full user details
          final loginResult = await loginWithMobile(mobileNumber);
          if (loginResult.success && loginResult.user != null) {
            return loginResult.user;
          }
        }
        return null;
      } else {
        print('Error checking contact: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Error fetching contact: $e');
      return null;
    }
  }

  // ===============================
  // FIREBASE INTEGRATION METHODS
  // ===============================

  /// Create user via Firebase ID token (for Firebase Auth flow)
  Future<AuthResponse> createFirebaseUser({
    required String firebaseIdToken,
    Map<String, dynamic>? additionalInfo,
  }) async {
    try {
      print('Creating Firebase user with ID token');

      final requestBody = {
        'firebase_id_token': firebaseIdToken,
        'additional_info': additionalInfo ?? {},
      };

      final response = await _client
          .post(
            Uri.parse('$baseUrl/users/create-firebase-user'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(requestBody),
          )
          .timeout(const Duration(seconds: 30));

      print('Firebase user creation response: ${response.statusCode}');
      print('Firebase user creation body: ${response.body}');

      if (response.statusCode == 201) {
        final responseData = json.decode(response.body);
        return AuthResponse.fromJson(responseData);
      } else {
        final errorData = json.decode(response.body);
        return AuthResponse.error(
          errorData['detail'] ?? 'Firebase user creation failed',
        );
      }
    } catch (e) {
      print('Error creating Firebase user: $e');
      return AuthResponse.error('Network error: ${e.toString()}');
    }
  }

  /// Google OAuth login
  Future<AuthResponse> googleLogin(String googleToken) async {
    try {
      print('Google OAuth login');

      final requestBody = {'google_token': googleToken};

      final response = await _client
          .post(
            Uri.parse('$baseUrl/users/auth/google-login'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(requestBody),
          )
          .timeout(const Duration(seconds: 30));

      print('Google login response: ${response.statusCode}');
      print('Google login body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        return AuthResponse.fromJson(responseData);
      } else {
        final errorData = json.decode(response.body);
        return AuthResponse.error(errorData['detail'] ?? 'Google login failed');
      }
    } catch (e) {
      print('Error during Google login: $e');
      return AuthResponse.error('Network error: ${e.toString()}');
    }
  }

  // ===============================
  // SESSION MANAGEMENT METHODS (Merged from UserService)
  // ===============================

  /// Get current user ID from session (prioritize Firebase UID, fallback to phone)
  static Future<String> getCurrentUserId() async {
    // Try to get Firebase UID first
    final firebaseUid = await SimpleSessionService.getFirebaseUid();
    if (firebaseUid != null && firebaseUid.isNotEmpty) {
      return firebaseUid;
    }

    // Fallback to phone number
    final phone = await SimpleSessionService.getUserPhone();
    if (phone != null && phone.isNotEmpty) {
      return phone;
    }

    // If no session data, throw error
    throw Exception('No user session found. Please log in again.');
  }

  /// Check if user is logged in using session service
  static Future<bool> isUserLoggedIn() async {
    return await SimpleSessionService.isLoggedIn();
  }

  /// Logout using session service
  static Future<void> logout() async {
    await SimpleSessionService.clearSession();
  }

  /// Get user profile information from session
  static Future<Map<String, dynamic>> getUserProfile() async {
    return await SimpleSessionService.getUserProfile();
  }

  /// Check if session is still valid
  static Future<bool> isSessionValid({Duration? maxAge}) async {
    return await SimpleSessionService.isSessionValid(maxAge: maxAge);
  }

  /// Get current user details from backend using session info
  static Future<User?> getCurrentUser() async {
    try {
      final userId = await getCurrentUserId();

      // If userId is numeric (database ID), use getUserById
      if (RegExp(r'^\d+$').hasMatch(userId)) {
        return await UserApiServiceSingleton.instance.getUserById(
          int.parse(userId),
        );
      }

      // If userId is phone number, use getContactByMobile
      if (RegExp(r'^\+?[\d\s\-\(\)]+$').hasMatch(userId)) {
        return await UserApiServiceSingleton.instance.getContactByMobile(
          userId,
        );
      }

      // For Firebase UID or other formats, we might need a different endpoint
      // For now, try phone fallback
      final phone = await SimpleSessionService.getUserPhone();
      if (phone != null && phone.isNotEmpty) {
        return await UserApiServiceSingleton.instance.getContactByMobile(phone);
      }

      return null;
    } catch (e) {
      print('Error getting current user: $e');
      return null;
    }
  }

  // ===============================
  // UTILITY METHODS
  // ===============================

  /// Test connection to user service
  Future<bool> testConnection() async {
    try {
      print('Testing connection to user service: $baseUrl/users/');
      final response = await _client
          .get(
            Uri.parse('$baseUrl/users/check-mobile?mobile_number=test'),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(const Duration(seconds: 5));

      print('Test connection response status: ${response.statusCode}');
      return response.statusCode == 200;
    } catch (e) {
      print('User service connection test failed: $e');
      return false;
    }
  }

  /// Dispose resources
  void dispose() {
    _client.close();
  }
}

/// Singleton instance for easy access throughout the app
class UserApiServiceSingleton {
  static UserApiService? _instance;

  static UserApiService get instance {
    _instance ??= UserApiService();
    return _instance!;
  }

  static void dispose() {
    _instance?.dispose();
    _instance = null;
  }
}
