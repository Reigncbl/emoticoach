import 'dart:convert';
import 'package:http/http.dart' as http;

class APIService {
  String baseUrl = "http://10.0.2.2:8000"; // Standard for Android emulator

  Future<Map<String, dynamic>> fetchMessagesAndPath(
    String phone,
    String firstName,
    String lastName,
  ) async {
    final response = await http.post(
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
    final response = await http.get(
      Uri.parse(
        '$baseUrl/suggestion?file_path=${Uri.encodeComponent(filePath)}',
      ),
    );

    if (response.statusCode == 200) {
      List<dynamic> decodedList = jsonDecode(response.body);
      return decodedList.map((item) => item as Map<String, dynamic>).toList();
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
      final response = await http.get(
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
