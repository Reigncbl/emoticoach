import 'package:firebase_auth/firebase_auth.dart';
import '../services/session_service.dart';

class AuthUtils {
  /// Safely get userId prioritizing session data over Firebase Auth
  ///
  /// This method provides a reliable way to get the Firebase UID by:
  /// 1. First checking session storage (faster and more reliable)
  /// 2. Falling back to Firebase Auth if session doesn't have it
  /// 3. Saving to session if retrieved from Firebase Auth for future use
  ///
  /// Returns null if no valid userId is found
  static Future<String?> getSafeUserId() async {
    try {
      // Priority 1: Try to get Firebase UID from session storage
      String? userId = await SimpleSessionService.getFirebaseUid();
      if (userId != null && userId.trim().isNotEmpty) {
        print('Using userId from session: $userId');
        return userId.trim();
      }

      // Priority 2: Try to get from Firebase Auth (only if Firebase is initialized)
      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null && user.uid.isNotEmpty) {
          print('Using userId from Firebase Auth: ${user.uid}');
          // Also save it to session for future use
          await SimpleSessionService.updateSessionData(
            'firebase_uid',
            user.uid,
          );
          return user.uid;
        }
      } catch (firebaseError) {
        print('Firebase Auth not available or not initialized: $firebaseError');
      }

      print('No valid userId found');
      return null;
    } catch (e) {
      print('Error getting safe user ID: $e');
      return null;
    }
  }

  /// Check if user is authenticated (has valid Firebase UID)
  static Future<bool> isUserAuthenticated() async {
    final userId = await getSafeUserId();
    return userId != null && userId.isNotEmpty;
  }

  /// Get user ID with fallback to a default error message
  static Future<String> getUserIdOrThrow() async {
    final userId = await getSafeUserId();
    if (userId == null || userId.isEmpty) {
      throw Exception('User not authenticated. Please log in again.');
    }
    return userId;
  }
}
