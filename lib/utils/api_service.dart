import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/scenario_models.dart';
import 'package:emoticoach/models/reading_model.dart';

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

  Future<Map<String, dynamic>> fetchMessagesAndPath(
    String phone,
    String firstName,
    String lastName,
  ) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/messages'),
      headers: <String, String>{
        'Content-Type': 'application/json; charset=UTF-8',
      },
      body: jsonEncode(<String, String>{
        'phone': phone,
        'first_name': firstName,
        'last_name': lastName,
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

  Future<List<Map<String, dynamic>>> fetchSuggestions(String filePath) async {
    final response = await _client.get(
      Uri.parse(
        '$baseUrl/suggestion?file_path=${Uri.encodeComponent(filePath)}',
      ),
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
      final response = await _client.get(uri);
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

  // ===============================
  // TELEGRAM INTEGRATION METHODS
  // ===============================

  /// Start Telegram authentication - sends OTP to Telegram
  Future<Map<String, dynamic>> startTelegramAuth(String phoneNumber) async {
    try {
      print('Starting Telegram authentication for: $phoneNumber');
      
      final requestBody = {
        'phone_number': phoneNumber,
      };

      final response = await _client
          .post(
            Uri.parse('$baseUrl/auth/start'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(requestBody),
          )
          .timeout(const Duration(seconds: 30));

      print('Telegram auth start response: ${response.statusCode}');
      print('Telegram auth start body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        return {
          'success': true,
          'message': responseData['message'] ?? 'Code sent to Telegram',
        };
      } else {
        final errorData = json.decode(response.body);
        return {
          'success': false,
          'error': errorData['detail'] ?? 'Failed to send Telegram code',
        };
      }
    } catch (e) {
      print('Error starting Telegram auth: $e');
      return {
        'success': false,
        'error': 'Network error: ${e.toString()}',
      };
    }
  }

  /// Verify Telegram authentication code
  Future<Map<String, dynamic>> verifyTelegramAuth({
    required String phoneNumber,
    required String code,
    String? password,
  }) async {
    try {
      print('Verifying Telegram code for: $phoneNumber');
      
      final requestBody = {
        'phone_number': phoneNumber,
        'code': code,
        if (password != null) 'password': password,
      };

      final response = await _client
          .post(
            Uri.parse('$baseUrl/auth/verify'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(requestBody),
          )
          .timeout(const Duration(seconds: 30));

      print('Telegram verify response: ${response.statusCode}');
      print('Telegram verify body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        
        // Check if password is required for 2FA
        if (responseData['password_required'] == true) {
          return {
            'success': false,
            'password_required': true,
            'message': 'Two-factor authentication password required',
          };
        }
        
        return {
          'success': true,
          'message': responseData['message'] ?? 'Telegram authenticated successfully',
          'user_id': responseData['user_id'],
        };
      } else {
        final errorData = json.decode(response.body);
        return {
          'success': false,
          'error': errorData['detail'] ?? 'Failed to verify Telegram code',
        };
      }
    } catch (e) {
      print('Error verifying Telegram auth: $e');
      return {
        'success': false,
        'error': 'Network error: ${e.toString()}',
      };
    }
  }

  /// Check Telegram authentication status
  Future<Map<String, dynamic>> getTelegramStatus(String phoneNumber) async {
    try {
      print('Checking Telegram status for: $phoneNumber');
      
      final response = await _client
          .get(
            Uri.parse('$baseUrl/status?phone_number=$phoneNumber'),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(const Duration(seconds: 15));

      print('Telegram status response: ${response.statusCode}');
      print('Telegram status body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        return {
          'success': true,
          'authenticated': responseData['authenticated'] ?? false,
          'user': responseData['user'],
        };
      } else {
        return {
          'success': false,
          'authenticated': false,
          'error': 'Failed to check Telegram status',
        };
      }
    } catch (e) {
      print('Error checking Telegram status: $e');
      return {
        'success': false,
        'authenticated': false,
        'error': 'Network error: ${e.toString()}',
      };
    }
  }

  /// Get Telegram contacts
  Future<Map<String, dynamic>> getTelegramContacts(String phoneNumber) async {
    try {
      print('Fetching Telegram contacts for: $phoneNumber');
      
      final response = await _client
          .get(
            Uri.parse('$baseUrl/contacts?phone_number=$phoneNumber'),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(const Duration(seconds: 30));

      print('Telegram contacts response: ${response.statusCode}');
      print('Telegram contacts body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        return {
          'success': true,
          'contacts': responseData['contacts'] ?? [],
          'total': responseData['total'] ?? 0,
        };
      } else if (response.statusCode == 401) {
        return {
          'success': false,
          'error': 'Not authenticated with Telegram',
          'auth_required': true,
        };
      } else {
        final errorData = json.decode(response.body);
        return {
          'success': false,
          'error': errorData['detail'] ?? 'Failed to fetch Telegram contacts',
        };
      }
    } catch (e) {
      print('Error fetching Telegram contacts: $e');
      return {
        'success': false,
        'error': 'Network error: ${e.toString()}',
      };
    }
  }

  /// Get messages from a Telegram contact
  Future<Map<String, dynamic>> getTelegramMessages({
    required String phoneNumber,
    required String contactPhone,
    required String firstName,
    required String lastName,
  }) async {
    try {
      print('Fetching Telegram messages for contact: $firstName $lastName');
      
      final requestBody = {
        'phone': contactPhone,
        'first_name': firstName,
        'last_name': lastName,
      };

      final response = await _client
          .post(
            Uri.parse('$baseUrl/messages?phone_number=$phoneNumber'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(requestBody),
          )
          .timeout(const Duration(seconds: 30));

      print('Telegram messages response: ${response.statusCode}');
      print('Telegram messages body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        return {
          'success': true,
          'sender': responseData['sender'],
          'receiver': responseData['receiver'],
          'messages': responseData['messages'] ?? [],
        };
      } else if (response.statusCode == 401) {
        return {
          'success': false,
          'error': 'Not authenticated with Telegram',
          'auth_required': true,
        };
      } else {
        final errorData = json.decode(response.body);
        return {
          'success': false,
          'error': errorData['detail'] ?? 'Failed to fetch messages',
        };
      }
    } catch (e) {
      print('Error fetching Telegram messages: $e');
      return {
        'success': false,
        'error': 'Network error: ${e.toString()}',
      };
    }
  }
}
