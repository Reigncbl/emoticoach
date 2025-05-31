import 'dart:convert';
import 'package:http/http.dart' as http;

class APIService {
  final http.Client _client;
  String baseUrl = "http://10.0.2.2:8000"; // Standard for Android emulator

  // Constructor allowing http.Client injection for testing
  APIService({http.Client? client}) : _client = client ?? http.Client();

  Future<Map<String, dynamic>> fetchMessagesAndPath(
    String phone,
    String firstName,
    String lastName,
  ) async {
    final response = await _client.post(
      // Use _client
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
      // Use _client
      Uri.parse(
        '$baseUrl/suggestion?file_path=${Uri.encodeComponent(filePath)}',
      ),
    );

    if (response.statusCode == 200) {
      List<dynamic> decodedList = jsonDecode(response.body);
      List<Map<String, dynamic>> suggestions = [];
      for (int i = 0; i < decodedList.length; i += 2) {
        if (i + 1 < decodedList.length) {
          suggestions.add({
            "analysis": decodedList[i] as String,
            "suggestion": decodedList[i + 1] as String,
          });
        }
      }
      return suggestions;
    } else {
      print('Failed to fetch suggestions: ${response.statusCode}');
      print('Response body: ${response.body}');
      throw Exception('Failed to fetch suggestions');
    }
  }

  Future<Map<String, dynamic>> analyzeMessages(String filePath) async {
    // Signature updated
    final Uri uri = Uri.parse(
      '$baseUrl/analyze_messages?file_path=${Uri.encodeComponent(filePath)}',
    ); // URL updated, using Uri.encodeComponent
    try {
      final response = await _client.get(
        // Use _client
        uri,
      ); // Removed Content-Type header for GET

      if (response.statusCode == 200) {
        return jsonDecode(response.body)
            as Map<String, dynamic>; // Using jsonDecode as elsewhere in file
      } else {
        // More specific error handling
        print(
          'Failed to analyze messages. Status code: ${response.statusCode}',
        );
        print('Response body: ${response.body}');
        throw Exception(
          'Failed to analyze messages. Status code: ${response.statusCode}, Body: ${response.body}',
        );
      }
    } catch (e) {
      // Catch network errors or other exceptions during the request
      print('Error during analyzeMessages request: $e');
      throw Exception('Failed to analyze messages: $e');
    }
  }
}
