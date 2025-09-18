import '../services/session_service.dart';
import '../services/api_service.dart';

/// A utility class that provides session-aware API calls
/// This demonstrates how to use the enhanced session management system
class SessionAwareApiClient {
  static APIService? _apiService;

  static APIService get apiService {
    _apiService ??= APIService();
    return _apiService!;
  }

  /// Check if user is currently logged in
  static Future<bool> isLoggedIn() async {
    return await SimpleSessionService.isLoggedIn();
  }

  /// Get current user's complete profile
  static Future<Map<String, dynamic>> getCurrentUserProfile() async {
    return await SimpleSessionService.getUserProfile();
  }

  /// Get user's basic information for API calls
  static Future<Map<String, String?>> getUserInfo() async {
    if (!await isLoggedIn()) {
      throw Exception('User not logged in');
    }

    return {
      'phone': await SimpleSessionService.getUserPhone(),
      'firstName': await SimpleSessionService.getUserFirstName(),
      'lastName': await SimpleSessionService.getUserLastName(),
      'email': await SimpleSessionService.getUserEmail(),
      'firebaseUid': await SimpleSessionService.getFirebaseUid(),
      'loginMethod': await SimpleSessionService.getLoginMethod(),
    };
  }

  /// Fetch messages using current session user information
  /// This is a convenience method that automatically uses logged-in user's data
  static Future<Map<String, dynamic>> fetchUserMessages() async {
    if (!await isLoggedIn()) {
      throw Exception('User not logged in. Please login first.');
    }

    // This will automatically use session data since we're passing null parameters
    return await apiService.fetchMessagesAndPath(null, null, null);
  }

  /// Fetch messages with specific user info (overrides session data)
  static Future<Map<String, dynamic>> fetchMessagesForUser({
    required String phone,
    String? firstName,
    String? lastName,
  }) async {
    return await apiService.fetchMessagesAndPath(phone, firstName, lastName);
  }

  /// Example of how to make authenticated API calls
  static Future<List<Map<String, dynamic>>> getSuggestions(
    String filePath,
  ) async {
    // This will automatically include user session info in headers
    return await apiService.fetchSuggestions(filePath);
  }

  /// Example of making an API call with explicit authentication check
  static Future<Map<String, dynamic>> analyzeMessagesSecurely(
    String filePath,
  ) async {
    if (!await isLoggedIn()) {
      throw Exception('Authentication required for this operation');
    }

    // Check if session is still valid (not expired)
    if (!await SimpleSessionService.isSessionValid()) {
      throw Exception('Session expired. Please login again.');
    }

    return await apiService.analyzeMessages(filePath);
  }

  /// Update user profile information
  static Future<void> updateUserProfile({
    String? firstName,
    String? lastName,
    String? email,
    Map<String, dynamic>? additionalData,
  }) async {
    if (!await isLoggedIn()) {
      throw Exception('User not logged in');
    }

    // Update local session data
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

    print('User profile updated successfully');
  }

  /// Logout user and clear all session data
  static Future<void> logout() async {
    await SimpleSessionService.clearSession();
    print('User logged out successfully');
  }

  /// Check if the current session is valid and not expired
  static Future<bool> isSessionValid({Duration? maxAge}) async {
    return await SimpleSessionService.isSessionValid(maxAge: maxAge);
  }

  /// Get session metadata
  static Future<Map<String, dynamic>> getSessionMetadata() async {
    if (!await isLoggedIn()) {
      return {'isLoggedIn': false};
    }

    final loginTime = await SimpleSessionService.getLoginTimestamp();
    final loginMethod = await SimpleSessionService.getLoginMethod();

    return {
      'isLoggedIn': true,
      'loginTimestamp': loginTime?.toIso8601String(),
      'loginMethod': loginMethod,
      'sessionAge': loginTime != null
          ? DateTime.now().difference(loginTime).inMinutes
          : null,
      'isSessionValid': await isSessionValid(),
    };
  }

  /// Helper method to ensure API calls are made by authenticated users
  static Future<T> executeWithAuth<T>(Future<T> Function() apiCall) async {
    if (!await isLoggedIn()) {
      throw Exception('Authentication required');
    }

    if (!await isSessionValid()) {
      throw Exception('Session expired. Please login again.');
    }

    try {
      return await apiCall();
    } catch (e) {
      print('Authenticated API call failed: $e');
      rethrow;
    }
  }

  /// Example usage method that demonstrates the session-aware features
  static Future<Map<String, dynamic>> demonstrateSessionAwareUsage() async {
    final results = <String, dynamic>{};

    // Check login status
    results['isLoggedIn'] = await isLoggedIn();

    if (results['isLoggedIn']) {
      // Get user profile
      results['userProfile'] = await getCurrentUserProfile();

      // Get session metadata
      results['sessionMetadata'] = await getSessionMetadata();

      // Try to fetch user messages (this will use session data automatically)
      try {
        results['userMessages'] = await fetchUserMessages();
        results['messagesStatus'] = 'success';
      } catch (e) {
        results['messagesStatus'] = 'failed';
        results['messagesError'] = e.toString();
      }
    } else {
      results['message'] = 'User not logged in';
    }

    return results;
  }
}
