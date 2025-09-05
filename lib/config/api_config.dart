class ApiConfig {
  // Change this IP address when needed
  static const String baseUrl = 'http://192.168.1.3:8000';

  // API endpoints
  static String get checkMobile => '$baseUrl/users/check-mobile';
  static String get createFirebaseUser => '$baseUrl/users/create-firebase-user';
  static String get sendSms => '$baseUrl/users/send-sms';
  static String get verifyOtp => '$baseUrl/users/verify-otp';
  static String get sendLoginOtp => '$baseUrl/users/send-login-otp';
  static String get verifyLoginOtp => '$baseUrl/users/verify-login-otp';
  static String get loginEmail => '$baseUrl/users/login-email';
  static String get loginMobile => '$baseUrl/users/login-mobile';
}
