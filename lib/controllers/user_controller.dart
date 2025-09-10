import 'package:flutter/material.dart';
import '../services/user_api_service.dart';
import '../models/user_model.dart';

class UserController extends ChangeNotifier {
  final UserApiService _userApiService = UserApiServiceSingleton.instance;

  // Current user state
  User? _currentUser;
  bool _isLoading = false;
  String? _errorMessage;

  // Getters
  User? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isLoggedIn => _currentUser != null;

  // ===============================
  // CONTACT LOOKUP METHODS
  // ===============================

  /// Get contact information by mobile number
  /// This is the main method for your use case
  Future<User?> getContactByMobile(String mobileNumber) async {
    _setLoading(true);
    _setError(null);

    try {
      print('UserController: Looking up contact for mobile: $mobileNumber');

      final user = await _userApiService.getContactByMobile(mobileNumber);

      if (user != null) {
        print('UserController: Contact found - ${user.fullName}');
        return user;
      } else {
        print('UserController: No contact found for mobile: $mobileNumber');
        _setError('No user found with mobile number: $mobileNumber');
        return null;
      }
    } catch (e) {
      print('UserController: Error getting contact: $e');
      _setError('Failed to get contact: ${e.toString()}');
      return null;
    } finally {
      _setLoading(false);
    }
  }

  /// Check if a mobile number is registered
  Future<bool> checkMobileExists(String mobileNumber) async {
    _setLoading(true);
    _setError(null);

    try {
      final exists = await _userApiService.checkMobileExists(mobileNumber);
      print('UserController: Mobile $mobileNumber exists: $exists');
      return exists;
    } catch (e) {
      print('UserController: Error checking mobile: $e');
      _setError('Failed to check mobile: ${e.toString()}');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // ===============================
  // AUTHENTICATION METHODS
  // ===============================

  /// Login with mobile number and OTP
  Future<bool> loginWithOTP({
    required String mobileNumber,
    required String otpCode,
  }) async {
    _setLoading(true);
    _setError(null);

    try {
      print('UserController: Attempting login for: $mobileNumber');

      final authResponse = await _userApiService.verifyLoginOTP(
        mobileNumber: mobileNumber,
        otpCode: otpCode,
      );

      if (authResponse.success && authResponse.user != null) {
        _currentUser = authResponse.user;
        print('UserController: Login successful for ${_currentUser!.fullName}');
        notifyListeners();
        return true;
      } else {
        _setError(authResponse.error ?? 'Login failed');
        return false;
      }
    } catch (e) {
      print('UserController: Login error: $e');
      _setError('Login failed: ${e.toString()}');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Send login SMS
  Future<bool> sendLoginSMS(String mobileNumber) async {
    _setLoading(true);
    _setError(null);

    try {
      final smsResponse = await _userApiService.sendLoginSMS(mobileNumber);

      if (smsResponse.success) {
        print('UserController: Login SMS sent to $mobileNumber');
        // In development, you might want to show the OTP
        if (smsResponse.otp != null) {
          print('UserController: Development OTP: ${smsResponse.otp}');
        }
        return true;
      } else {
        _setError(smsResponse.error ?? 'Failed to send SMS');
        return false;
      }
    } catch (e) {
      print('UserController: SMS sending error: $e');
      _setError('Failed to send SMS: ${e.toString()}');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Register new user with OTP
  Future<bool> registerWithOTP({
    required String mobileNumber,
    required String otpCode,
    required String firstName,
    required String lastName,
  }) async {
    _setLoading(true);
    _setError(null);

    try {
      print('UserController: Attempting registration for: $mobileNumber');

      final authResponse = await _userApiService.verifyOTPAndCreateUser(
        mobileNumber: mobileNumber,
        otpCode: otpCode,
        firstName: firstName,
        lastName: lastName,
      );

      if (authResponse.success && authResponse.user != null) {
        _currentUser = authResponse.user;
        print(
          'UserController: Registration successful for ${_currentUser!.fullName}',
        );
        notifyListeners();
        return true;
      } else {
        _setError(authResponse.error ?? 'Registration failed');
        return false;
      }
    } catch (e) {
      print('UserController: Registration error: $e');
      _setError('Registration failed: ${e.toString()}');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Send registration SMS
  Future<bool> sendRegistrationSMS(String mobileNumber) async {
    _setLoading(true);
    _setError(null);

    try {
      final smsResponse = await _userApiService.sendRegistrationSMS(
        mobileNumber,
      );

      if (smsResponse.success) {
        print('UserController: Registration SMS sent to $mobileNumber');
        // In development, you might want to show the OTP
        if (smsResponse.otp != null) {
          print('UserController: Development OTP: ${smsResponse.otp}');
        }
        return true;
      } else {
        _setError(smsResponse.error ?? 'Failed to send SMS');
        return false;
      }
    } catch (e) {
      print('UserController: SMS sending error: $e');
      _setError('Failed to send SMS: ${e.toString()}');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Logout current user
  void logout() {
    _currentUser = null;
    _setError(null);
    print('UserController: User logged out');
    notifyListeners();
  }

  // ===============================
  // FIREBASE METHODS
  // ===============================

  /// Login/Register with Firebase token
  Future<bool> loginWithFirebase({
    required String firebaseIdToken,
    Map<String, dynamic>? additionalInfo,
  }) async {
    _setLoading(true);
    _setError(null);

    try {
      final authResponse = await _userApiService.createFirebaseUser(
        firebaseIdToken: firebaseIdToken,
        additionalInfo: additionalInfo,
      );

      if (authResponse.success && authResponse.user != null) {
        _currentUser = authResponse.user;
        print(
          'UserController: Firebase auth successful for ${_currentUser!.fullName}',
        );
        notifyListeners();
        return true;
      } else {
        _setError(authResponse.error ?? 'Firebase authentication failed');
        return false;
      }
    } catch (e) {
      print('UserController: Firebase auth error: $e');
      _setError('Firebase authentication failed: ${e.toString()}');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Google OAuth login
  Future<bool> loginWithGoogle(String googleToken) async {
    _setLoading(true);
    _setError(null);

    try {
      final authResponse = await _userApiService.googleLogin(googleToken);

      if (authResponse.success && authResponse.user != null) {
        _currentUser = authResponse.user;
        print(
          'UserController: Google login successful for ${_currentUser!.fullName}',
        );
        notifyListeners();
        return true;
      } else {
        _setError(authResponse.error ?? 'Google login failed');
        return false;
      }
    } catch (e) {
      print('UserController: Google login error: $e');
      _setError('Google login failed: ${e.toString()}');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // ===============================
  // HELPER METHODS
  // ===============================

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String? error) {
    _errorMessage = error;
    if (error != null) {
      print('UserController: Error - $error');
    }
    notifyListeners();
  }

  /// Clear any current error message
  void clearError() {
    _setError(null);
  }

  /// Test the API connection
  Future<bool> testConnection() async {
    try {
      return await _userApiService.testConnection();
    } catch (e) {
      print('UserController: Connection test failed: $e');
      return false;
    }
  }

  @override
  void dispose() {
    // Don't dispose the singleton service here
    super.dispose();
  }
}
