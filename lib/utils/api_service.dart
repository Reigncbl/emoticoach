import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/scenario_models.dart';
import 'package:emoticoach/screens/learning/models/reading_model.dart';

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

  Future<Map<String, dynamic>> fetchMessagesAndPath(String phone) async {
    try {
      final response = await _client.get(
        Uri.parse('$baseUrl/messages/$phone'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        throw Exception('Failed to fetch messages: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to fetch messages: $e');
    }
  }

  // Scenario API Methods
  Future<ConfigResponse> startConversation() async {
    print('Starting conversation - calling: $baseUrl/start');
    try {
      final response = await _client.get(
        Uri.parse('$baseUrl/start'),
        headers: {'Content-Type': 'application/json'},
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
    print('Sending message - calling: $baseUrl/chat');
    print('Request body: ${jsonEncode(request.toJson())}');

    try {
      final response = await _client.post(
        Uri.parse('$baseUrl/chat'),
        headers: {'Content-Type': 'application/json'},
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
    print('Evaluating conversation - calling: $baseUrl/evaluate');
    print('Request body: ${jsonEncode(request.toJson())}');

    try {
      final response = await _client.post(
        Uri.parse('$baseUrl/evaluate'),
        headers: {'Content-Type': 'application/json'},
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

  Future<List<Reading>> fetchAllReadings() async {
    try {
      final response = await _client.get(Uri.parse('$baseUrl/resources/all'));
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

  Future<Map<String, dynamic>> fetchSuggestions(String input) async {
    try {
      final response = await _client.post(
        Uri.parse('$baseUrl/suggestions'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'input': input}),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        throw Exception('Failed to fetch suggestions: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to fetch suggestions: $e');
    }
  }

  Future<Map<String, dynamic>> analyzeMessages(
    String phone,
    String contactName,
    int messageCount,
  ) async {
    try {
      final response = await _client.post(
        Uri.parse('$baseUrl/analyze'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'phone': phone,
          'contact_name': contactName,
          'message_count': messageCount,
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        throw Exception('Failed to analyze messages: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to analyze messages: $e');
    }
  }

  // Test connection method
  Future<bool> testConnection() async {
    try {
      print('Testing connection to: $baseUrl/');
      final response = await _client
          .get(
            Uri.parse('$baseUrl/'),
            headers: {'Content-Type': 'application/json'},
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
}
