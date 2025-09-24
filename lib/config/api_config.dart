class ApiConfig {
  // Change this IP address when needed
  static const String baseUrl = 'http://192.168.100.199:8000';

  // API endpoints
  static String get checkMobile => '$baseUrl/users/check-mobile';
  static String get createFirebaseUser => '$baseUrl/users/create-firebase-user';
  static String get sendSms => '$baseUrl/users/send-sms';
  static String get verifyOtp => '$baseUrl/users/verify-otp';
  static String get sendLoginOtp => '$baseUrl/users/send-login-otp';
  static String get verifyLoginOtp => '$baseUrl/users/verify-login-otp';
  static String get loginEmail => '$baseUrl/users/login-email';
  static String get loginMobile => '$baseUrl/users/login-mobile';

  // Scenario endpoints
  static String get scenariosList => '$baseUrl/scenarios/list';
  static String scenarioStart(int scenarioId) =>
      '$baseUrl/scenarios/start/$scenarioId';
  static String scenarioDetails(int scenarioId) =>
      '$baseUrl/scenarios/details/$scenarioId';
  static String get scenarioChat => '$baseUrl/scenarios/chat';
  static String get scenarioEvaluate => '$baseUrl/scenarios/evaluate';
  static String get scenarioComplete => '$baseUrl/scenarios/complete';
  static String scenarioCompleted(String userId) =>
      '$baseUrl/scenarios/completed/$userId';
}
