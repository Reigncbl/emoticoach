import 'package:shared_preferences/shared_preferences.dart';

class SimpleSessionService {
  static const String _isLoggedInKey = 'is_logged_in';
  static const String _userPhoneKey = 'user_phone';
  static const String _userNameKey = 'user_name';

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

  // Save simple session (just mark as logged in)
  static Future<void> saveSession({
    required String phoneNumber,
    String? firstName,
    String? lastName,
  }) async {
    await init();
    await _prefs?.setBool(_isLoggedInKey, true);
    await _prefs?.setString(_userPhoneKey, phoneNumber);

    if (firstName != null && lastName != null) {
      await _prefs?.setString(_userNameKey, '$firstName $lastName');
    }
  }

  // Get user phone
  static Future<String?> getUserPhone() async {
    await init();
    return _prefs?.getString(_userPhoneKey);
  }

  // Get user name
  static Future<String?> getUserName() async {
    await init();
    return _prefs?.getString(_userNameKey);
  }

  // Clear session
  static Future<void> clearSession() async {
    await init();
    await _prefs?.clear();
  }
}
