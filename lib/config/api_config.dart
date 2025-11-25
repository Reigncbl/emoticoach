class ApiConfig {
  // Change this IP address when needed
  static const String baseUrl = 'https://192.168.1.7:8000';

  // === USER ENDPOINTS ===
  static String get checkMobile => '$baseUrl/users/check-mobile';
  static String get createFirebaseUser => '$baseUrl/users/create-firebase-user';
  static String get sendSms => '$baseUrl/users/send-sms';
  static String get verifyOtp => '$baseUrl/users/verify-otp';
  static String get sendLoginOtp => '$baseUrl/users/send-login-otp';
  static String get verifyLoginOtp => '$baseUrl/users/verify-login-otp';
  static String get loginEmail => '$baseUrl/users/login-email';
  static String get loginMobile => '$baseUrl/users/login-mobile';

  // === Delete User Endpoint ===
  static String deleteUser(String userId) => '$baseUrl/users/delete/$userId';

  // === Badge ENDPOINTS ===
  static String getUserBadges(String userId) =>
      '$baseUrl/achievements/user/$userId';

  // === EXPERIENCE ENDPOINTS ===
  static String get myExperience => '$baseUrl/experience';
  static String get addXp => '$baseUrl/experience/add';

  // === SCENARIO ENDPOINTS ===
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

  // === SUGGESTIONS ===
  static String get analyzeSuggestion => '$baseUrl/suggestion/analyze';

  // === RAG ===
  static String get ragContext => '$baseUrl/rag/rag-context';

  // === TELEGRAM ===
  static String get telegramRequestCode => '$baseUrl/telegram/request_code';

  // === MESSAGES ===
  static String get getMessages => '$baseUrl/messages/messages';

  // === BOOKS ===
  static String get getAllBooks => '$baseUrl/books/resources/all';
  static String getBookPage(String readingsId, int page) =>
      '$baseUrl/books/book/$readingsId/$page';
  static String getBookResource(String resourceId) =>
      '$baseUrl/books/resources/$resourceId';
  static String updateProgress({
    required String userId,
    required String bookId,
    required int progress,
  }) => '$baseUrl/books/progress/update/$userId/$bookId/$progress';
  static String bulkFetchProgress(String mobileNumber) =>
      '$baseUrl/books/progress-bulk/$mobileNumber';

  // === SUPPORT ===
  static String get submitHelpRequest => '$baseUrl/api/support/help-request';
  static String get submitFeedback => '$baseUrl/api/support/feedback';

  // === NOTIFICATIONS ===

  // === DAILY CHALLENGE ===
  static String get dailyChallenge => '$baseUrl/daily/challenge';
  static String get dailyClaim => '$baseUrl/daily/claim';

  // === STATS ===
  static String stats(String userId) => '$baseUrl/stats/$userId';
}
