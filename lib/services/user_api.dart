import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class UserApi {
  // Get user by Firebase UID
  static Future<Map<String, dynamic>?> getUserById(String userId) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/users/$userId'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        print('Failed to get user: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Error getting user: $e');
      return null;
    }
  }

  // Update user profile
  static Future<bool> updateUser(
    String userId,
    Map<String, dynamic> userData,
  ) async {
    try {
      final response = await http.put(
        Uri.parse('${ApiConfig.baseUrl}/users/$userId'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(userData),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Error updating user: $e');
      return false;
    }
  }

  // Check if user exists
  static Future<bool> userExists(String userId) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/users/$userId'),
        headers: {'Content-Type': 'application/json'},
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Error checking user existence: $e');
      return false;
    }
  }
}
