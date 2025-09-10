import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../config/api_config.dart';

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

  // Check if mobile number exists
  static Future<bool> checkMobileExists(String mobileNumber) async {
    try {
      final response = await http.get(
        Uri.parse(
          '${ApiConfig.baseUrl}/users/check-mobile?mobile_number=$mobileNumber',
        ),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['exists'] ?? false;
      }
      return false;
    } catch (e) {
      print('Error checking mobile: $e');
      return false;
    }
  }

  // Create Firebase user
  static Future<Map<String, dynamic>?> createFirebaseUser({
    required String firebaseIdToken,
    String? firstName,
    String? lastName,
    String? mobileNumber,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(ApiConfig.createFirebaseUser),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'firebase_id_token': firebaseIdToken,
          'additional_info': {
            'first_name': firstName,
            'last_name': lastName,
            'mobile_number': mobileNumber,
          },
        }),
      );

      print('Create user response: ${response.statusCode}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body);
      } else {
        print('Failed to create user: ${response.body}');
        return null;
      }
    } catch (e) {
      print('Error creating user: $e');
      return null;
    }
  }

  // Login with email
  static Future<Map<String, dynamic>?> loginWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(ApiConfig.loginEmail),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        print('Login failed: ${response.body}');
        return null;
      }
    } catch (e) {
      print('Error during login: $e');
      return null;
    }
  }
}
