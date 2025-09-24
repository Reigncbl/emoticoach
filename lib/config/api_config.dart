class ApiConfig {
  // Change this IP address when needed
  static const String baseUrl = 'http://192.168.1.5:8000';

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
  // Suggestion endpoints
  static String get analyzeSuggestion => '$baseUrl/suggestion/analyze';

  // RAG endpoints
  static String get ragContext => '$baseUrl/rag/rag-context';

  // Telegram endpoints
  static String get telegramRequestCode => '$baseUrl/telegram/request_code';
  // Add more Telegram endpoints as needed

  // Messages endpoints
  static String get getMessages => '$baseUrl/messages/messages';
  // Add more Messages endpoints as needed

  // Books endpoints
  static String get getAllBooks => '$baseUrl/books/resources/all';
  static String getBookPage(String readingsId, int page) =>
      '$baseUrl/books/book/$readingsId/$page';
  static String getBookResource(String resourceId) =>
      '$baseUrl/books/resources/$resourceId';
}
