import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

/// Telegram service following the multiuser backend format
/// This service handles all Telegram-related API calls including
/// authentication, contacts, and message operations
class TelegramService {
  final http.Client _client;
  late String baseUrl;

  TelegramService({http.Client? client}) : _client = client ?? http.Client() {
    baseUrl = ApiConfig.baseUrl;
    print('TelegramService initialized with baseUrl: $baseUrl');
  }

  // AUTHENTICATION METHODS

  /// Request OTP code for Telegram authentication
  /// Corresponds to /telegram/request_code endpoint
  Future<Map<String, dynamic>> requestCode({
    required String userId,
    required String phoneNumber,
  }) async {
    try {
      print('Requesting Telegram OTP for userId: $userId, phone: $phoneNumber');

      final requestBody = {'user_id': userId, 'phone_number': phoneNumber};

      final response = await _client
          .post(
            Uri.parse('$baseUrl/telegram/request_code'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(requestBody),
          )
          .timeout(const Duration(seconds: 30));

      print('Request code response: ${response.statusCode}');
      print('Request code body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        return {
          'success': true,
          'message': responseData['message'] ?? 'OTP sent',
          'phone_number': responseData['phone_number'],
        };
      } else {
        final errorData = jsonDecode(response.body);
        return {
          'success': false,
          'error': errorData['detail'] ?? 'Failed to send OTP',
        };
      }
    } catch (e) {
      print('Error requesting OTP: $e');
      return {'success': false, 'error': 'Network error: ${e.toString()}'};
    }
  }

  /// Verify OTP code for Telegram authentication
  /// Corresponds to /telegram/verify_code endpoint
  Future<Map<String, dynamic>> verifyCode({
    required String userId,
    required String code,
  }) async {
    try {
      print('Verifying Telegram code for userId: $userId');

      final requestBody = {'user_id': userId, 'code': code};

      final response = await _client
          .post(
            Uri.parse('$baseUrl/telegram/verify_code'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(requestBody),
          )
          .timeout(const Duration(seconds: 30));

      print('Verify code response: ${response.statusCode}');
      print('Verify code body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);

        // Check if password is required for 2FA
        if (responseData['password_required'] == true) {
          return {
            'success': false,
            'password_required': true,
            'message': 'Two-factor authentication password required',
          };
        }

        return {
          'success': true,
          'message': responseData['message'] ?? 'Login successful',
          'user_id': responseData['user_id'],
          'telegram_username': responseData['telegram_username'],
        };
      } else {
        final errorData = jsonDecode(response.body);
        return {
          'success': false,
          'error': errorData['detail'] ?? 'Failed to verify code',
        };
      }
    } catch (e) {
      print('Error verifying code: $e');
      return {'success': false, 'error': 'Network error: ${e.toString()}'};
    }
  }

  // USER INFO METHODS

  /// Get current user information
  /// Corresponds to /telegram/me endpoint
  Future<Map<String, dynamic>> getMe({required String userId}) async {
    try {
      print('Getting user info for userId: $userId');

      final response = await _client
          .get(
            Uri.parse('$baseUrl/telegram/me?user_id=$userId'),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(const Duration(seconds: 15));

      print('Get me response: ${response.statusCode}');
      print('Get me body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        return {
          'success': true,
          'id': responseData['id'],
          'username': responseData['username'],
          'phone': responseData['phone'],
        };
      } else if (response.statusCode == 404) {
        return {
          'success': false,
          'error': 'Session not found or not verified',
          'auth_required': true,
        };
      } else {
        final errorData = jsonDecode(response.body);
        return {
          'success': false,
          'error': errorData['detail'] ?? 'Failed to get user info',
        };
      }
    } catch (e) {
      print('Error getting user info: $e');
      return {'success': false, 'error': 'Network error: ${e.toString()}'};
    }
  }

  // CONTACTS METHODS

  /// Get Telegram contacts for a user
  /// Corresponds to /telegram/contacts endpoint
  Future<Map<String, dynamic>> getContacts({required String userId}) async {
    try {
      print('Fetching Telegram contacts for userId: $userId');

      final response = await _client
          .get(
            Uri.parse('$baseUrl/telegram/contacts?user_id=$userId'),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(const Duration(seconds: 90));

      print('Get contacts response: ${response.statusCode}');
      print('Get contacts body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        return {
          'success': true,
          'contacts': responseData['contacts'] ?? [],
          'total': responseData['total'] ?? 0,
        };
      } else if (response.statusCode == 404) {
        return {
          'success': false,
          'error': 'Session not found or not verified',
          'auth_required': true,
        };
      } else {
        final errorData = jsonDecode(response.body);
        return {
          'success': false,
          'error': errorData['detail'] ?? 'Failed to fetch contacts',
        };
      }
    } catch (e) {
      print('Error fetching contacts: $e');
      return {'success': false, 'error': 'Network error: ${e.toString()}'};
    }
  }

  // MESSAGE METHODS

  /// Get messages from a contact using contact_id
  /// Corresponds to /telegram/contact_messages endpoint
  Future<Map<String, dynamic>> getContactMessages({
    required String userId,
    required int contactId,
  }) async {
    try {
      print('Fetching messages for userId: $userId, contactId: $contactId');

      final requestBody = {'user_id': userId, 'contact_id': contactId};

      final response = await _client
          .post(
            Uri.parse('$baseUrl/telegram/contact_messages'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(requestBody),
          )
          .timeout(const Duration(seconds: 90));

      print('Get contact messages response: ${response.statusCode}');
      print('Get contact messages body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        return {
          'success': true,
          'sender': responseData['sender'],
          'receiver': responseData['receiver'],
          'messages': responseData['messages'] ?? [],
          'conversation_context': responseData['conversation_context'],
          'saved_message_ids': responseData['saved_message_ids'] ?? [],
        };
      } else if (response.statusCode == 404) {
        return {
          'success': false,
          'error': 'Session not found or not verified',
          'auth_required': true,
        };
      } else {
        final errorData = jsonDecode(response.body);
        return {
          'success': false,
          'error': errorData['detail'] ?? 'Failed to fetch messages',
        };
      }
    } catch (e) {
      print('Error fetching contact messages: $e');
      return {'success': false, 'error': 'Network error: ${e.toString()}'};
    }
  }

  /// Get messages with embedding and emotion analysis
  /// Corresponds to /telegram/contact_messages_embed endpoint
  Future<Map<String, dynamic>> getContactMessagesWithEmbedding({
    required String userId,
    required int contactId,
  }) async {
    try {
      print(
        'Fetching messages with embedding for userId: $userId, contactId: $contactId',
      );

      final requestBody = {'user_id': userId, 'contact_id': contactId};

      final response = await _client
          .post(
            Uri.parse('$baseUrl/telegram/contact_messages_embed'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(requestBody),
          )
          .timeout(const Duration(seconds: 120));

      print('Get contact messages embed response: ${response.statusCode}');
      print('Get contact messages embed body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        return {'success': true, 'data': responseData};
      } else if (response.statusCode == 401) {
        return {
          'success': false,
          'error': 'Unauthorized access',
          'auth_required': true,
        };
      } else if (response.statusCode == 404) {
        return {
          'success': false,
          'error': 'Session not found or not verified',
          'auth_required': true,
        };
      } else {
        final errorData = jsonDecode(response.body);
        return {
          'success': false,
          'error':
              errorData['detail'] ?? 'Failed to fetch messages with embedding',
        };
      }
    } catch (e) {
      print('Error fetching contact messages with embedding: $e');
      return {'success': false, 'error': 'Network error: ${e.toString()}'};
    }
  }

  /// Append and analyze the latest message from a contact
  /// Corresponds to /telegram/append_latest_contact_message endpoint
  Future<Map<String, dynamic>> appendLatestContactMessage({
    required String userId,
    required int contactId,
  }) async {
    try {
      print(
        'Appending latest message for userId: $userId, contactId: $contactId',
      );

      final requestBody = {'user_id': userId, 'contact_id': contactId};

      final response = await _client
          .post(
            Uri.parse('$baseUrl/telegram/append_latest_contact_message'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(requestBody),
          )
          .timeout(const Duration(seconds: 120));

      print('Append latest message response: ${response.statusCode}');
      print('Append latest message body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        return {'success': true, 'data': responseData};
      } else {
        final errorData = jsonDecode(response.body);
        return {
          'success': false,
          'error': errorData['detail'] ?? 'Failed to append latest message',
        };
      }
    } catch (e) {
      print('Error appending latest message: $e');
      return {'success': false, 'error': 'Network error: ${e.toString()}'};
    }
  }

  // UTILITY METHODS

  /// Test connection to Telegram service
  Future<bool> testConnection() async {
    try {
      print('Testing Telegram service connection to: $baseUrl/telegram/');
      final response = await _client
          .get(
            Uri.parse('$baseUrl/'),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(const Duration(seconds: 5));

      print('Telegram service test response: ${response.statusCode}');
      return response.statusCode == 200;
    } catch (e) {
      print('Telegram service connection test failed: $e');
      return false;
    }
  }

  /// Dispose resources
  void dispose() {
    _client.close();
  }
}
