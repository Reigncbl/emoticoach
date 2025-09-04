import 'session_service.dart';

class SimpleApiService {
  // Simple client-side verification - no backend needed
  static Future<bool> verifyOTP({
    required String phoneNumber,
    required String otp,
    String? firstName,
    String? lastName,
  }) async {
    // For demo purposes, accept any 6-digit OTP
    if (otp.length == 6 && otp.contains(RegExp(r'^[0-9]+$'))) {
      // Save session locally
      await SimpleSessionService.saveSession(
        phoneNumber: phoneNumber,
        firstName: firstName,
        lastName: lastName,
      );
      return true;
    }
    return false;
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
    };
  }
}
