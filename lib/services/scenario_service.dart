import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class ScenarioService {
  static Future<List<Map<String, dynamic>>> getScenarios() async {
    try {
      print(
        '🔍 DEBUG: Attempting to fetch scenarios from: ${ApiConfig.scenariosList}',
      );

      final response = await http.get(
        Uri.parse(ApiConfig.scenariosList),
        headers: {'Content-Type': 'application/json'},
      );

      print('🔍 DEBUG: Response status code: ${response.statusCode}');
      print('🔍 DEBUG: Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('🔍 DEBUG: Parsed response data: $data');

        if (data['success'] == true) {
          final scenarios = List<Map<String, dynamic>>.from(data['scenarios']);
          print('🔍 DEBUG: Found ${scenarios.length} scenarios');
          return scenarios;
        } else {
          print('🔍 DEBUG: API returned success=false');
          throw Exception('API returned success=false');
        }
      }
      print('🔍 DEBUG: Non-200 status code received');
      throw Exception(
        'Failed to load scenarios - status: ${response.statusCode}',
      );
    } catch (e) {
      print('🔍 DEBUG: Error fetching scenarios: $e');
      throw Exception('Failed to connect to backend: $e');
    }
  }

  static Future<Map<String, dynamic>> startScenario(int scenarioId) async {
    try {
      final response = await http.get(
        Uri.parse(ApiConfig.scenarioStart(scenarioId)),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return data;
        }
      }
      throw Exception('Failed to start scenario');
    } catch (e) {
      print('Error starting scenario: $e');
      throw Exception('Failed to start scenario');
    }
  }

  static Future<Map<String, dynamic>> getScenarioDetails(int scenarioId) async {
    try {
      final response = await http.get(
        Uri.parse(ApiConfig.scenarioDetails(scenarioId)),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return data['scenario'];
        }
      }
      throw Exception('Failed to load scenario details');
    } catch (e) {
      print('Error fetching scenario details: $e');
      throw Exception('Failed to load scenario details');
    }
  }

  static Future<Map<String, dynamic>> sendMessage({
    required String message,
    required int scenarioId,
    List<Map<String, dynamic>>? conversationHistory,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(ApiConfig.scenarioChat),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'message': message,
          'scenario_id': scenarioId,
          'conversation_history': conversationHistory ?? [],
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return data;
        }
      }
      throw Exception('Failed to send message');
    } catch (e) {
      print('Error sending message: $e');
      throw Exception('Failed to send message');
    }
  }

  static Future<Map<String, dynamic>> evaluateConversation({
    required int scenarioId,
    required List<Map<String, dynamic>> conversationHistory,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(ApiConfig.scenarioEvaluate),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'scenario_id': scenarioId,
          'conversation_history': conversationHistory,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return data;
        }
      }
      throw Exception('Failed to evaluate conversation');
    } catch (e) {
      print('Error evaluating conversation: $e');
      throw Exception('Failed to evaluate conversation');
    }
  }

  static Future<Map<String, dynamic>> completeScenario({
    required String userId,
    required int scenarioId,
    int? completionTimeMinutes,
    int? finalClarityScore,
    int? finalEmpathyScore,
    int? finalAssertivenessScore,
    int? finalAppropriatenessScore,
    int? userRating,
    int? totalMessages,
  }) async {
    try {
      final url = ApiConfig.scenarioComplete;
      final payload = {
        'user_id': userId,
        'scenario_id': scenarioId,
        'completion_time_minutes': completionTimeMinutes,
        'final_clarity_score': finalClarityScore,
        'final_empathy_score': finalEmpathyScore,
        'final_assertiveness_score': finalAssertivenessScore,
        'final_appropriateness_score': finalAppropriatenessScore,
        'user_rating': userRating,
        'total_messages': totalMessages,
      };

      print('DEBUG: POST $url');
      print('DEBUG: completeScenario payload: ${json.encode(payload)}');

      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(payload),
      );

      print('DEBUG: completeScenario response status: ${response.statusCode}');
      print('DEBUG: completeScenario response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return data;
        }
      }
      throw Exception('Failed to mark scenario as complete');
    } catch (e) {
      print('Error completing scenario: $e');
      throw Exception('Failed to complete scenario');
    }
  }

  static Future<List<Map<String, dynamic>>> getCompletedScenarios(
    String userId,
  ) async {
    try {
      final url = ApiConfig.scenarioCompleted(userId);
      print('DEBUG: Fetching completed scenarios from: $url');

      final response = await http.get(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
      );

      print('DEBUG: Completed scenarios response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('DEBUG: Parsed completed scenarios data: $data');

        if (data['success'] == true) {
          final completedScenarios =
              data['completed_scenarios'] ??
              []; // Fixed: backend returns 'completed_scenarios'
          print(
            'DEBUG: Found ${completedScenarios.length} completed scenarios in response',
          );
          return List<Map<String, dynamic>>.from(completedScenarios);
        } else {
          print('DEBUG: API returned success=false for completed scenarios');
        }
      } else {
        print(
          'DEBUG: Non-200 status code for completed scenarios: ${response.statusCode}',
        );
      }
      throw Exception(
        'Failed to load completed scenarios - status: ${response.statusCode}',
      );
    } catch (e) {
      print('DEBUG: Exception in getCompletedScenarios: $e');
      print('Error fetching completed scenarios: $e');
      throw Exception('Failed to load completed scenarios: $e');
    }
  }

  // New method to get specific scenario completion
  static Future<Map<String, dynamic>?> getScenarioCompletion({
    required String userId,
    required int scenarioId,
  }) async {
    try {
      final response = await http.get(
        Uri.parse(ApiConfig.scenarioCompletion(userId, scenarioId)),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          final value = data['completed_scenarios'];
          if (value is Map<String, dynamic>) return value;
        }
      } else if (response.statusCode == 404) {
        // Scenario not completed yet
        return null;
      }
      throw Exception('Failed to load scenario completion');
    } catch (e) {
      print('Error fetching scenario completion: $e');
      throw Exception('Failed to load scenario completion');
    }
  }
}
