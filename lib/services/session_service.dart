import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class SimpleSessionService {
  static const String _isLoggedInKey = 'is_logged_in';
  static const String _userPhoneKey = 'user_phone';
  static const String _userNameKey = 'user_name';
  static const String _userFirstNameKey = 'user_first_name';
  static const String _userLastNameKey = 'user_last_name';
  static const String _userEmailKey = 'user_email';
  static const String _loginTimestampKey = 'login_timestamp';
  static const String _loginMethodKey = 'login_method';
  static const String _firebaseUidKey = 'firebase_uid';
  static const String _userDataKey = 'user_data';

  static SharedPreferences? _prefs;

  // Initialize
  static Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  // Check if logged in
  static Future<bool> isLoggedIn() async {
    await init();
    return _prefs?.getBool(_isLoggedInKey) ?? false;
  }

  // Save comprehensive session information
  static Future<void> saveSession({
    required String phoneNumber,
    String? firstName,
    String? lastName,
    String? email,
    String? firebaseUid,
    String loginMethod = 'phone',
    Map<String, dynamic>? additionalData,
  }) async {
    await init();

    // Save basic session info
    await _prefs?.setBool(_isLoggedInKey, true);
    await _prefs?.setString(_userPhoneKey, phoneNumber);
    await _prefs?.setString(
      _loginTimestampKey,
      DateTime.now().toIso8601String(),
    );
    await _prefs?.setString(_loginMethodKey, loginMethod);

    // Save individual name components (only if provided and not empty)
    if (firstName != null && firstName.trim().isNotEmpty) {
      await _prefs?.setString(_userFirstNameKey, firstName.trim());
    }
    if (lastName != null && lastName.trim().isNotEmpty) {
      await _prefs?.setString(_userLastNameKey, lastName.trim());
    }

    // Save full name for backward compatibility (only if we have valid names)
    if (firstName != null && firstName.trim().isNotEmpty) {
      final fullName = lastName != null && lastName.trim().isNotEmpty
          ? '${firstName.trim()} ${lastName.trim()}'
          : firstName.trim();
      await _prefs?.setString(_userNameKey, fullName);
    }

    // Save email if provided
    if (email != null && email.trim().isNotEmpty) {
      await _prefs?.setString(_userEmailKey, email.trim());
    }

    // Save Firebase UID if provided
    if (firebaseUid != null && firebaseUid.trim().isNotEmpty) {
      await _prefs?.setString(_firebaseUidKey, firebaseUid.trim());
    }

    // Save additional user data as JSON
    if (additionalData != null && additionalData.isNotEmpty) {
      await _prefs?.setString(_userDataKey, jsonEncode(additionalData));
    }

    print('Session saved: $phoneNumber, Method: $loginMethod');
    if (firstName != null && firstName.trim().isNotEmpty) {
      print('   Names: $firstName ${lastName ?? ""}');
    } else {
      print('   Names: NOT PROVIDED (will fetch later)');
    }
  }

  // Get user phone
  static Future<String?> getUserPhone() async {
    await init();
    return _prefs?.getString(_userPhoneKey);
  }

  // Get user name (full name)
  static Future<String?> getUserName() async {
    await init();
    return _prefs?.getString(_userNameKey);
  }

  // Get user first name
  static Future<String?> getUserFirstName() async {
    await init();
    return _prefs?.getString(_userFirstNameKey);
  }

  // Get user last name
  static Future<String?> getUserLastName() async {
    await init();
    return _prefs?.getString(_userLastNameKey);
  }

  // Get user email
  static Future<String?> getUserEmail() async {
    await init();
    return _prefs?.getString(_userEmailKey);
  }

  // Get Firebase UID
  static Future<String?> getFirebaseUid() async {
    await init();
    return _prefs?.getString(_firebaseUidKey);
  }

  // Get login method
  static Future<String?> getLoginMethod() async {
    await init();
    return _prefs?.getString(_loginMethodKey);
  }

  // Get login timestamp
  static Future<DateTime?> getLoginTimestamp() async {
    await init();
    final timestamp = _prefs?.getString(_loginTimestampKey);
    if (timestamp != null) {
      return DateTime.tryParse(timestamp);
    }
    return null;
  }

  // Get additional user data
  static Future<Map<String, dynamic>?> getUserData() async {
    await init();
    final dataString = _prefs?.getString(_userDataKey);
    if (dataString != null) {
      try {
        return jsonDecode(dataString) as Map<String, dynamic>;
      } catch (e) {
        print('Error parsing user data: $e');
        return null;
      }
    }
    return null;
  }

  // Get complete user profile
  static Future<Map<String, dynamic>> getUserProfile() async {
    await init();
    return {
      'isLoggedIn': await isLoggedIn(),
      'phone': await getUserPhone(),
      'firstName': await getUserFirstName(),
      'lastName': await getUserLastName(),
      'fullName': await getUserName(),
      'email': await getUserEmail(),
      'firebaseUid': await getFirebaseUid(),
      'loginMethod': await getLoginMethod(),
      'loginTimestamp': (await getLoginTimestamp())?.toIso8601String(),
      'additionalData': await getUserData(),
    };
  }

  // Update specific session data
  static Future<void> updateSessionData(String key, dynamic value) async {
    await init();
    if (value is String) {
      await _prefs?.setString(key, value);
    } else if (value is bool) {
      await _prefs?.setBool(key, value);
    } else if (value is int) {
      await _prefs?.setInt(key, value);
    } else if (value is double) {
      await _prefs?.setDouble(key, value);
    } else if (value is List<String>) {
      await _prefs?.setStringList(key, value);
    } else {
      // Store as JSON string for complex types
      await _prefs?.setString(key, jsonEncode(value));
    }
  }

  // Check if session is still valid (not expired)
  static Future<bool> isSessionValid({Duration? maxAge}) async {
    if (!await isLoggedIn()) return false;

    final loginTime = await getLoginTimestamp();
    if (loginTime == null) return false;

    final age = maxAge ?? const Duration(days: 30); // Default 30 days
    return DateTime.now().difference(loginTime) < age;
  }

  // Clear session
  static Future<void> clearSession() async {
    await init();
    await _prefs?.clear();
    print('Session cleared');
  }

  // Clear specific session data
  static Future<void> clearSessionData(String key) async {
    await init();
    await _prefs?.remove(key);
  }
}
