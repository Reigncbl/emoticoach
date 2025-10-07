import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class SupportService {
  /// Submit an anonymous help request
  /// No user information or IP addresses are logged
  /// Optional email parameter allows users to receive responses
  static Future<bool> submitHelpRequest(String message, {String? subject, String? email}) async {
    try {
      final response = await http.post(
        Uri.parse(ApiConfig.submitHelpRequest),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'message': message,
          if (subject != null) 'subject': subject,
          if (email != null && email.isNotEmpty) 'email': email,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['success'] ?? false;
      } else {
        print('Failed to submit help request: ${response.statusCode}');
        print('Response body: ${response.body}');
        return false;
      }
    } catch (e) {
      print('Error submitting help request: $e');
      return false;
    }
  }

  /// Submit anonymous feedback
  /// No user information or IP addresses are logged
  static Future<bool> submitFeedback(String message, {int? rating}) async {
    try {
      final response = await http.post(
        Uri.parse(ApiConfig.submitFeedback),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'message': message,
          if (rating != null) 'rating': rating,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['success'] ?? false;
      } else {
        print('Failed to submit feedback: ${response.statusCode}');
        print('Response body: ${response.body}');
        return false;
      }
    } catch (e) {
      print('Error submitting feedback: $e');
      return false;
    }
  }
}
