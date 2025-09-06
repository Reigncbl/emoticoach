import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/scenario_models.dart';
import 'package:emoticoach/screens/learning/models/reading_model.dart';
import '../services/session_service.dart';

class APIService {
  final http.Client _client;
  late String baseUrl;

  APIService({http.Client? client}) : _client = client ?? http.Client() {
    // Set base URL based on platform
    if (kIsWeb) {
      baseUrl = "http://localhost:8000"; // Web
    } else if (Platform.isAndroid) {
      baseUrl = "http://10.0.2.2:8000"; // Android emulator
    } else if (Platform.isIOS) {
      baseUrl = "http://localhost:8000"; // iOS simulator
    } else {
      baseUrl = "http://localhost:8000"; // Desktop/other
    }

    print('APIService initialized with baseUrl: $baseUrl');
  }

  // Get authenticated headers with user session info
  Future<Map<String, String>> _getAuthenticatedHeaders() async {
    final headers = <String, String>{
      'Content-Type': 'application/json; charset=UTF-8',
    };

    // Add user session information if logged in
    if (await SimpleSessionService.isLoggedIn()) {
      final userPhone = await SimpleSessionService.getUserPhone();
      final firebaseUid = await SimpleSessionService.getFirebaseUid();
      final loginMethod = await SimpleSessionService.getLoginMethod();

      if (userPhone != null) {
        headers['X-User-Phone'] = userPhone;
      }
      if (firebaseUid != null) {
        headers['X-Firebase-Uid'] = firebaseUid;
      }
      if (loginMethod != null) {
        headers['X-Login-Method'] = loginMethod;
      }

      headers['X-User-Authenticated'] = 'true';
    }

    return headers;
  }

  // Enhanced fetchMessagesAndPath with automatic user info inclusion
  Future<Map<String, dynamic>> fetchMessagesAndPath(
    String? phone,
    String? firstName,
    String? lastName,
  ) async {
    // Use session data if parameters are null and user is logged in
    String? actualPhone = phone;
    String? actualFirstName = firstName;
    String? actualLastName = lastName;

    if (await SimpleSessionService.isLoggedIn()) {
      actualPhone ??= await SimpleSessionService.getUserPhone();
      actualFirstName ??= await SimpleSessionService.getUserFirstName();
      actualLastName ??= await SimpleSessionService.getUserLastName();
    }

    if (actualPhone == null) {
      throw Exception('No phone number available. Please login first.');
    }

    final response = await _client.post(
      Uri.parse('$baseUrl/messages'),
      headers: await _getAuthenticatedHeaders(),
      body: jsonEncode(<String, String>{
        'phone': actualPhone,
        'first_name': actualFirstName ?? '',
        'last_name': actualLastName ?? '',
      }),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      print('Failed to fetch messages and path: ${response.statusCode}');
      print('Response body: ${response.body}');
      throw Exception('Failed to fetch messages and path');
    }
  }

  // Convenience method to fetch messages using session data
  Future<Map<String, dynamic>> fetchMessagesFromSession() async {
    if (!await SimpleSessionService.isLoggedIn()) {
      throw Exception('User not logged in');
    }

    return fetchMessagesAndPath(null, null, null);
  }

  Future<List<Map<String, dynamic>>> fetchSuggestions(String filePath) async {
    final response = await _client.get(
      Uri.parse(
        '$baseUrl/suggestion?file_path=${Uri.encodeComponent(filePath)}',
      ),
      headers: await _getAuthenticatedHeaders(),
    );

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);

      // Expect the backend to always return a Map with a 'suggestions' key
      if (decoded is Map<String, dynamic> &&
          decoded.containsKey('suggestions')) {
        final suggestions = decoded['suggestions'];
        if (suggestions is List) {
          // Ensure each item is a Map
          return suggestions.cast<Map<String, dynamic>>();
        }
      }
      // fallback: no suggestions key found, return empty list
      return [];
    } else {
      print('Failed to fetch suggestions: ${response.statusCode}');
      print('Response body: ${response.body}');
      return [];
    }
  }

  Future<Map<String, dynamic>> analyzeMessages(String filePath) async {
    final Uri uri = Uri.parse(
      '$baseUrl/analyze_messages?file_path=${Uri.encodeComponent(filePath)}',
    );
    try {
      final response = await _client.get(
        uri,
        headers: await _getAuthenticatedHeaders(),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        print(
          'Failed to analyze messages. Status code: ${response.statusCode}',
        );
        print('Response body: ${response.body}');
        throw Exception(
          'Failed to analyze messages. Status code: ${response.statusCode}, Body: ${response.body}',
        );
      }
    } catch (e) {
      print('Error during analyzeMessages request: $e');
      throw Exception('Failed to analyze messages: $e');
    }
  }

  // Scenario API Methods
  Future<ConfigResponse> startConversation(int scenarioId) async {
    print(
      'Starting conversation - calling: $baseUrl/scenarios/start/$scenarioId',
    );
    try {
      final response = await _client.get(
        Uri.parse('$baseUrl/scenarios/start/$scenarioId'),
        headers: await _getAuthenticatedHeaders(),
      );

      print('Start conversation response status: ${response.statusCode}');
      print('Start conversation response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return ConfigResponse.fromJson(data);
      } else {
        print('Failed to start conversation: ${response.statusCode}');
        print('Response body: ${response.body}');
        throw Exception('Failed to start conversation: ${response.statusCode}');
      }
    } catch (e) {
      print('Error during startConversation request: $e');
      throw Exception('Failed to start conversation: $e');
    }
  }

  Future<ChatResponse> sendMessage(ChatRequest request) async {
    print('Sending message - calling: $baseUrl/scenarios/chat');
    print('Request body: ${jsonEncode(request.toJson())}');

    try {
      final response = await _client.post(
        Uri.parse('$baseUrl/scenarios/chat'),
        headers: await _getAuthenticatedHeaders(),
        body: jsonEncode(request.toJson()),
      );

      print('Send message response status: ${response.statusCode}');
      print('Send message response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return ChatResponse.fromJson(data);
      } else {
        print('Failed to send message: ${response.statusCode}');
        print('Response body: ${response.body}');
        throw Exception('Failed to send message: ${response.statusCode}');
      }
    } catch (e) {
      print('Error during sendMessage request: $e');
      throw Exception('Failed to send message: $e');
    }
  }

  Future<EvaluationResponse> evaluateConversation(
    EvaluationRequest request,
  ) async {
    print('Evaluating conversation - calling: $baseUrl/scenarios/evaluate');
    print('Request body: ${jsonEncode(request.toJson())}');

    try {
      final response = await _client.post(
        Uri.parse('$baseUrl/scenarios/evaluate'),
        headers: await _getAuthenticatedHeaders(),
        body: jsonEncode(request.toJson()),
      );

      print('Evaluate conversation response status: ${response.statusCode}');
      print('Evaluate conversation response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return EvaluationResponse.fromJson(data);
      } else {
        print('Failed to evaluate conversation: ${response.statusCode}');
        print('Response body: ${response.body}');
        throw Exception(
          'Failed to evaluate conversation: ${response.statusCode}',
        );
      }
    } catch (e) {
      print('Error during evaluateConversation request: $e');
      throw Exception('Failed to evaluate conversation: $e');
    }
  }

  // Test connection method
  Future<bool> testConnection() async {
    try {
      print('Testing connection to: $baseUrl/');
      final response = await _client
          .get(
            Uri.parse('$baseUrl/'),
            headers: await _getAuthenticatedHeaders(),
          )
          .timeout(const Duration(seconds: 5));

      print('Test connection response status: ${response.statusCode}');
      print('Test connection response body: ${response.body}');

      return response.statusCode == 200;
    } catch (e) {
      print('Connection test failed: $e');
      return false;
    }
  }

  Future<List<Reading>> fetchAllReadings() async {
    try {
      final response = await _client.get(
        Uri.parse('$baseUrl/resources/all'),
        headers: await _getAuthenticatedHeaders(),
      );
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is List) {
          return decoded
              .map<Reading>((e) => Reading.fromJson(e as Map<String, dynamic>))
              .toList();
        } else if (decoded is Map && decoded['data'] is List) {
          final list = decoded['data'] as List;
          return list
              .map<Reading>((e) => Reading.fromJson(e as Map<String, dynamic>))
              .toList();
        }
        return [];
      } else {
        throw Exception(
          'Failed to fetch readings: ${response.statusCode} ${response.body}',
        );
      }
    } catch (e) {
      throw Exception('Failed to fetch readings: $e');
    }
  }

  // Session management methods
  Future<bool> isUserLoggedIn() async {
    return await SimpleSessionService.isLoggedIn();
  }

  Future<Map<String, dynamic>> getCurrentUserProfile() async {
    return await SimpleSessionService.getUserProfile();
  }

  Future<void> logoutUser() async {
    await SimpleSessionService.clearSession();
  }

  // Helper method to ensure user is authenticated before making API calls
  Future<void> _ensureAuthenticated() async {
    if (!await SimpleSessionService.isLoggedIn()) {
      throw Exception('User not authenticated. Please login first.');
    }
  }

  // Enhanced API methods with authentication check
  Future<List<Map<String, dynamic>>> fetchSuggestionsAuthenticated(
    String filePath,
  ) async {
    await _ensureAuthenticated();
    return fetchSuggestions(filePath);
  }

  Future<Map<String, dynamic>> analyzeMessagesAuthenticated(
    String filePath,
  ) async {
    await _ensureAuthenticated();
    return analyzeMessages(filePath);
  }

  Future<ConfigResponse> startConversationAuthenticated(int scenarioId) async {
    await _ensureAuthenticated();
    return startConversation(scenarioId);
  }

  Future<ChatResponse> sendMessageAuthenticated(ChatRequest request) async {
    await _ensureAuthenticated();
    return sendMessage(request);
  }

  Future<EvaluationResponse> evaluateConversationAuthenticated(
    EvaluationRequest request,
  ) async {
    await _ensureAuthenticated();
    return evaluateConversation(request);
  }

  Future<List<Reading>> fetchAllReadingsAuthenticated() async {
    await _ensureAuthenticated();
    return fetchAllReadings();
  }
}
