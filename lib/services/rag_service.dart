import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:emoticoach/config/api_config.dart';

class RagService {
  final http.Client _client;
  late String baseUrl;

  RagService({http.Client? client}) : _client = client ?? http.Client() {
    baseUrl = ApiConfig.baseUrl;
  }

  /// Fetch recent emotion context and RAG suggestion for a conversation
  /// corresponding to the provided user and contact within the specified time window.
  Future<Map<String, dynamic>> getRecentEmotionContext({
    required String userId,
    required int contactId,
    int limit = 20,
  }) async {
    final uri = Uri.parse(
      '$baseUrl/rag/recent-emotion-context'
      '?user_id=${Uri.encodeQueryComponent(userId)}'
      '&contact_id=$contactId'
      '&window_minutes=$limit',
    );

    try {
      final response = await _client.get(
        uri,
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map<String, dynamic>) {
          return data;
        }
        return {'success': false, 'error': 'Unexpected response format'};
      } else {
        Map<String, dynamic>? err;
        try {
          err = jsonDecode(response.body) as Map<String, dynamic>?;
        } catch (_) {}
        return {
          'success': false,
          'error': err != null ? (err['detail']?.toString() ?? 'Request failed') : 'Request failed',
          'status': response.statusCode,
        };
      }
    } catch (e) {
      return {'success': false, 'error': 'Network error: ${e.toString()}'};
    }
  }

  Future<Map<String, dynamic>> generateContextualReply({
    required String userId,
    required int contactId,
    required String query,
    String? desiredTone,
    int limit = 10,
    String? startTime,
    String? endTime,
  }) async {
    final params = <String, String>{
      'user_id': userId,
      'contact_id': contactId.toString(),
      'query': query,
      'limit': limit.toString(),
    };

    if (desiredTone != null && desiredTone.isNotEmpty) {
      params['desired_tone'] = desiredTone;
    }
    if (startTime != null && startTime.isNotEmpty) {
      params['start_time'] = startTime;
    }
    if (endTime != null && endTime.isNotEmpty) {
      params['end_time'] = endTime;
    }

    final uri = Uri.parse('$baseUrl/rag/rag-context').replace(
      queryParameters: params,
    );

    try {
      final response = await _client.get(
        uri,
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map<String, dynamic>) {
          return data;
        }
        return {'success': false, 'error': 'Unexpected response format'};
      }

      Map<String, dynamic>? err;
      try {
        err = jsonDecode(response.body) as Map<String, dynamic>?;
      } catch (_) {}
      return {
        'success': false,
        'error': err != null
            ? (err['detail']?.toString() ?? 'Request failed')
            : 'Request failed',
        'status': response.statusCode,
      };
    } catch (e) {
      return {'success': false, 'error': 'Network error: ${e.toString()}'};
    }
  }
}
