import 'dart:convert';
import 'package:http/http.dart' as http;

class APIService {
  final http.Client _client;
  String baseUrl = "http://10.0.2.2:8000"; // Standard for Android emulator

  APIService({http.Client? client}) : _client = client ?? http.Client();

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
      if (decoded is List) {
        List<Map<String, dynamic>> suggestions = [];
        for (int i = 0; i < decoded.length; i += 2) {
          if (i + 1 < decoded.length) {
            suggestions.add({
              "analysis": decoded[i] as String,
              "suggestion": decoded[i + 1] as String,
            });
          }
        }
        return suggestions;
      } else if (decoded is String) {
        // The backend sent a string (error or empty)
        print('Suggestion endpoint returned a string: $decoded');
        return []; // Just return an empty list
      } else {
        print('Unexpected suggestions response type: ${decoded.runtimeType}');
        return [];
      }
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
}
