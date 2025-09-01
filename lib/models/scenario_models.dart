import 'dart:convert';

class ConversationMessage {
  final String role;
  final String content;

  ConversationMessage({required this.role, required this.content});

  Map<String, dynamic> toJson() {
    return {'role': role, 'content': content};
  }

  factory ConversationMessage.fromJson(Map<String, dynamic> json) {
    return ConversationMessage(
      role: json['role'] as String,
      content: json['content'] as String,
    );
  }
}

class ChatRequest {
  final String message;
  final List<ConversationMessage>? conversationHistory;

  ChatRequest({required this.message, this.conversationHistory});

  Map<String, dynamic> toJson() {
    return {
      'message': message,
      'conversation_history': conversationHistory
          ?.map((e) => e.toJson())
          .toList(),
    };
  }
}

class ChatResponse {
  final bool success;
  final String? response;
  final String? characterName;
  final String? error;

  ChatResponse({
    required this.success,
    this.response,
    this.characterName,
    this.error,
  });

  factory ChatResponse.fromJson(Map<String, dynamic> json) {
    return ChatResponse(
      success: json['success'] as bool,
      response: json['response'] as String?,
      characterName: json['character_name'] as String?,
      error: json['error'] as String?,
    );
  }
}

class EvaluationRequest {
  final List<ConversationMessage> conversationHistory;

  EvaluationRequest({required this.conversationHistory});

  Map<String, dynamic> toJson() {
    return {
      'conversation_history': conversationHistory
          .map((e) => e.toJson())
          .toList(),
    };
  }
}

class EvaluationData {
  final int clarity;
  final int empathy;
  final int assertiveness;
  final int appropriateness;
  final String tip;

  EvaluationData({
    required this.clarity,
    required this.empathy,
    required this.assertiveness,
    required this.appropriateness,
    required this.tip,
  });

  factory EvaluationData.fromJson(Map<String, dynamic> json) {
    return EvaluationData(
      clarity: _parseIntSafely(json['clarity']),
      empathy: _parseIntSafely(json['empathy']),
      assertiveness: _parseIntSafely(json['assertiveness']),
      appropriateness: _parseIntSafely(json['appropriateness']),
      tip:
          json['tip']?.toString() ??
          'Continue practicing your communication skills.',
    );
  }

  static int _parseIntSafely(dynamic value) {
    if (value is int) return value;
    if (value is String) {
      final parsed = int.tryParse(value);
      if (parsed != null) return parsed;
    }
    if (value is double) return value.round();
    return 5; // Default fallback value
  }
}

class EvaluationResponse {
  final bool success;
  final EvaluationData? evaluation;
  final List<String>? userReplies;
  final int? totalUserMessages;
  final String? savedPath;
  final String? error;

  EvaluationResponse({
    required this.success,
    this.evaluation,
    this.userReplies,
    this.totalUserMessages,
    this.savedPath,
    this.error,
  });

  factory EvaluationResponse.fromJson(Map<String, dynamic> json) {
    EvaluationData? evaluationData;

    try {
      if (json['evaluation'] != null) {
        final evalJson = json['evaluation'];

        if (evalJson is Map<String, dynamic>) {
          // Handle nested evaluation structure
          if (evalJson.containsKey('evaluation')) {
            // Structure: {"evaluation": {"evaluation": {...}}}
            final innerEval = evalJson['evaluation'];
            if (innerEval is Map<String, dynamic>) {
              evaluationData = EvaluationData.fromJson(innerEval);
            }
          } else if (evalJson.containsKey('clarity')) {
            // Structure: {"evaluation": {"clarity": ..., "empathy": ...}}
            evaluationData = EvaluationData.fromJson(evalJson);
          } else if (evalJson.containsKey('raw_output')) {
            // Handle raw_output case - try to parse it
            final rawOutput = evalJson['raw_output'] as String?;
            if (rawOutput != null) {
              evaluationData = _parseRawOutput(rawOutput);
            }
          }
        }
      }
    } catch (e) {
      print('Error parsing evaluation data: $e');
    }

    // Fallback to default values if parsing failed
    evaluationData ??= EvaluationData(
      clarity: 5,
      empathy: 5,
      assertiveness: 5,
      appropriateness: 5,
      tip: "Continue practicing your communication skills.",
    );

    return EvaluationResponse(
      success: json['success'] as bool,
      evaluation: evaluationData,
      userReplies: (json['user_replies'] as List<dynamic>?)?.cast<String>(),
      totalUserMessages: json['total_user_messages'] as int?,
      savedPath: json['saved_path'] as String?,
      error: json['error'] as String?,
    );
  }

  static EvaluationData? _parseRawOutput(String rawOutput) {
    try {
      // Try to extract JSON from raw output
      final jsonMatch = RegExp(
        r'\{[^{}]*"evaluation"[^{}]*\{[^{}]*\}[^{}]*\}',
      ).firstMatch(rawOutput);
      if (jsonMatch != null) {
        final extractedJson = jsonMatch.group(0);
        if (extractedJson != null) {
          final cleanedJson = extractedJson
              .replaceAll(r'\"', '"')
              .replaceAll(r'\\n', '\n');
          final parsed = jsonDecode(cleanedJson);
          if (parsed is Map<String, dynamic> &&
              parsed.containsKey('evaluation')) {
            return EvaluationData.fromJson(parsed['evaluation']);
          }
        }
      }

      // Try to extract individual values using regex
      final clarityMatch = RegExp(r'"clarity":\s*(\d+)').firstMatch(rawOutput);
      final empathyMatch = RegExp(r'"empathy":\s*(\d+)').firstMatch(rawOutput);
      final assertivenessMatch = RegExp(
        r'"assertiveness":\s*(\d+)',
      ).firstMatch(rawOutput);
      final appropriatenessMatch = RegExp(
        r'"appropriateness":\s*(\d+)',
      ).firstMatch(rawOutput);
      final tipMatch = RegExp(r'"tip":\s*"([^"]*)"').firstMatch(rawOutput);

      if (clarityMatch != null &&
          empathyMatch != null &&
          assertivenessMatch != null &&
          appropriatenessMatch != null &&
          tipMatch != null) {
        return EvaluationData(
          clarity: int.parse(clarityMatch.group(1)!),
          empathy: int.parse(empathyMatch.group(1)!),
          assertiveness: int.parse(assertivenessMatch.group(1)!),
          appropriateness: int.parse(appropriatenessMatch.group(1)!),
          tip: tipMatch.group(1)!,
        );
      }
    } catch (e) {
      print('Failed to parse raw_output: $e');
    }

    return null;
  }
}

class ConfigResponse {
  final bool success;
  final String? characterName;
  final String? firstMessage;
  final bool? conversationStarted;
  final String? error;

  ConfigResponse({
    required this.success,
    this.characterName,
    this.firstMessage,
    this.conversationStarted,
    this.error,
  });

  factory ConfigResponse.fromJson(Map<String, dynamic> json) {
    return ConfigResponse(
      success: json['success'] as bool,
      characterName: json['character_name'] as String?,
      firstMessage: json['first_message'] as String?,
      conversationStarted: json['conversation_started'] as bool?,
      error: json['error'] as String?,
    );
  }
}
