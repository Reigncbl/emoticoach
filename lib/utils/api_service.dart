import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:emoticoach/screens/learning/models/reading_model.dart';

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
}