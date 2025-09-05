import 'session_service.dart';

class SimpleApiService {
  // Simple client-side verification - no backend needed
  static Future<bool> verifyOTP({
    required String phoneNumber,
    required String otp,
    String? firstName,
    String? lastName,
    String? email,
    String? firebaseUid,
    String loginMethod = 'phone',
    Map<String, dynamic>? additionalData,
  }) async {
    // For demo purposes, accept any 6-digit OTP
    if (otp.length == 6 && otp.contains(RegExp(r'^[0-9]+$'))) {
      // Save comprehensive session locally
      await SimpleSessionService.saveSession(
        phoneNumber: phoneNumber,
        firstName: firstName,
        lastName: lastName,
        email: email,
        firebaseUid: firebaseUid,
        loginMethod: loginMethod,
        additionalData: additionalData,
      );
      return true;
    }
    return false;
  }

  // Save Google login session
  static Future<bool> saveGoogleSession({
    required String email,
    required String firebaseUid,
    String? phoneNumber,
    String? firstName,
    String? lastName,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      await SimpleSessionService.saveSession(
        phoneNumber: phoneNumber ?? email, // Use email as fallback for phone
        firstName: firstName,
        lastName: lastName,
        email: email,
        firebaseUid: firebaseUid,
        loginMethod: 'google',
        additionalData: additionalData,
      );
      return true;
    } catch (e) {
      print('Error saving Google session: $e');
      return false;
    }
  }

  // Save email login session
  static Future<bool> saveEmailSession({
    required String email,
    String? phoneNumber,
    String? firstName,
    String? lastName,
    String? firebaseUid,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      await SimpleSessionService.saveSession(
        phoneNumber: phoneNumber ?? email, // Use email as fallback for phone
        firstName: firstName,
        lastName: lastName,
        email: email,
        firebaseUid: firebaseUid,
        loginMethod: 'email',
        additionalData: additionalData,
      );
      return true;
    } catch (e) {
      print('Error saving email session: $e');
      return false;
    }
  }

  // Check if user is authenticated
  static Future<bool> isAuthenticated() async {
    return await SimpleSessionService.isLoggedIn();
  }

  // Check if session is still valid
  static Future<bool> isSessionValid({Duration? maxAge}) async {
    return await SimpleSessionService.isSessionValid(maxAge: maxAge);
  }

  // Simple logout
  static Future<void> logout() async {
    await SimpleSessionService.clearSession();
  }

  // Get current user info
  static Future<Map<String, String?>> getCurrentUser() async {
    return {
      'phone': await SimpleSessionService.getUserPhone(),
      'name': await SimpleSessionService.getUserName(),
      'firstName': await SimpleSessionService.getUserFirstName(),
      'lastName': await SimpleSessionService.getUserLastName(),
      'email': await SimpleSessionService.getUserEmail(),
    };
  }

  // Get complete user profile
  static Future<Map<String, dynamic>> getUserProfile() async {
    return await SimpleSessionService.getUserProfile();
  }

  // Update user profile information
  static Future<void> updateUserProfile({
    String? firstName,
    String? lastName,
    String? email,
    Map<String, dynamic>? additionalData,
  }) async {
    if (firstName != null) {
      await SimpleSessionService.updateSessionData(
        'user_first_name',
        firstName,
      );
    }
    if (lastName != null) {
      await SimpleSessionService.updateSessionData('user_last_name', lastName);
    }
    if (firstName != null && lastName != null) {
      await SimpleSessionService.updateSessionData(
        'user_name',
        '$firstName $lastName',
      );
    }
    if (email != null) {
      await SimpleSessionService.updateSessionData('user_email', email);
    }
    if (additionalData != null) {
      await SimpleSessionService.updateSessionData('user_data', additionalData);
    }
  }
}
