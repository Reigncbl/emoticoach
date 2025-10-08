import 'dart:convert';

import 'package:emoticoach/config/api_config.dart';
import 'package:http/http.dart' as http;

class ManualAnalysisService {
  final http.Client _client;
  late final String _baseUrl;

  ManualAnalysisService({http.Client? client})
      : _client = client ?? http.Client() {
    _baseUrl = ApiConfig.baseUrl;
  }

  /// Sends the latest user-entered message to the backend manual analysis endpoint
  /// and returns the structured response containing emotion analysis and RAG suggestion.
  Future<Map<String, dynamic>> analyzeMessage({
    required String userId,
    required String message,
    String? senderName,
    String? desiredTone,
    String? userDisplayName,
  }) async {
    final uri = Uri.parse('$_baseUrl/rag/manual-emotion-context');

    final payload = <String, dynamic>{
      'user_id': userId,
      'message': message,
      if (senderName != null && senderName.isNotEmpty) 'sender_name': senderName,
      if (desiredTone != null && desiredTone.isNotEmpty)
        'desired_tone': desiredTone,
      if (userDisplayName != null && userDisplayName.isNotEmpty)
        'user_display_name': userDisplayName,
    };

    try {
      final response = await _client.post(
        uri,
        headers: const {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(payload),
      );

      final decoded = jsonDecode(response.body);
      if (response.statusCode == 200) {
        if (decoded is Map<String, dynamic>) {
          return decoded;
        }
        return {
          'success': false,
          'error': 'Unexpected response format',
        };
      }

      return {
        'success': false,
        'status': response.statusCode,
        'error': decoded is Map<String, dynamic>
            ? (decoded['detail']?.toString() ?? 'Request failed')
            : 'Request failed',
      };
    } catch (e) {
      return {
        'success': false,
        'error': 'Network error: ${e.toString()}',
      };
    }
  }

  void dispose() {
    _client.close();
  }
}
