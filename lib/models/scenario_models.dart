import 'dart:convert';

class Scenario {
  final int id;
  final String title;
  final String description;
  final String category;
  final String difficulty;
  final String? configFile;
  final int? estimatedDuration;
  final bool isActive;
  final double? averageRating;
  final int? ratingCount;
  final int? completionCount;

  Scenario({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.difficulty,
    this.configFile,
    this.estimatedDuration,
    required this.isActive,
    this.averageRating,
    this.ratingCount,
    this.completionCount,
  });

  factory Scenario.fromJson(Map<String, dynamic> json) {
    return Scenario(
      id: json['id'] as int,
      title: json['title'] as String,
      description: json['description'] as String,
      category: json['category'] as String,
      difficulty: json['difficulty'] as String,
      configFile: json['config_file'] as String?,
      estimatedDuration: json['estimated_duration'] as int?,
      isActive: json['is_active'] as bool? ?? true,
      averageRating: (json['average_rating'] as num?)?.toDouble(),
      ratingCount: json['rating_count'] as int?,
      completionCount: json['completion_count'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'category': category,
      'difficulty': difficulty,
      'config_file': configFile,
      'estimated_duration': estimatedDuration,
      'is_active': isActive,
      'average_rating': averageRating,
      'rating_count': ratingCount,
      'completion_count': completionCount,
    };
  }

  String get formattedDuration {
    if (estimatedDuration == null) return '10-15 min';
    return '${estimatedDuration! - 2}-${estimatedDuration! + 3} min';
  }

  bool get hasRatings =>
      averageRating != null && ratingCount != null && ratingCount! > 0;
}

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

class ConversationFlowResponse {
  final bool success;
  final bool shouldEnd;
  final double confidence;
  final String reason;
  final String? suggestedEndingMessage;
  final Map<String, double> conversationQuality;

  ConversationFlowResponse({
    required this.success,
    required this.shouldEnd,
    required this.confidence,
    required this.reason,
    this.suggestedEndingMessage,
    required this.conversationQuality,
  });

  factory ConversationFlowResponse.fromJson(Map<String, dynamic> json) {
    return ConversationFlowResponse(
      success: json['success'] as bool,
      shouldEnd: json['should_end'] as bool,
      confidence: (json['confidence'] as num).toDouble(),
      reason: json['reason'] as String,
      suggestedEndingMessage: json['suggested_ending_message'] as String?,
      conversationQuality: Map<String, double>.from(
        (json['conversation_quality'] as Map<String, dynamic>).map(
          (key, value) => MapEntry(key, (value as num).toDouble()),
        ),
      ),
    );
  }
}

class CompletedScenario {
  final int scenarioId;
  final String title;
  final String description;
  final String category;
  final String difficulty;
  final int? estimatedDuration;
  final DateTime completedAt;
  final int? completionTimeMinutes;
  final int? finalClarityScore;
  final int? finalEmpathyScore;
  final int? finalAssertivenessScore;
  final int? finalAppropriatenessScore;
  final double? averageScore;
  final int? userRating;
  final int? totalMessages;
  final int completionCount;

  CompletedScenario({
    required this.scenarioId,
    required this.title,
    required this.description,
    required this.category,
    required this.difficulty,
    this.estimatedDuration,
    required this.completedAt,
    this.completionTimeMinutes,
    this.finalClarityScore,
    this.finalEmpathyScore,
    this.finalAssertivenessScore,
    this.finalAppropriatenessScore,
    this.averageScore,
    this.userRating,
    this.totalMessages,
    required this.completionCount,
  });

  factory CompletedScenario.fromJson(Map<String, dynamic> json) {
    int? _toInt(dynamic v) {
      if (v is int) return v;
      if (v is double) return v.toInt();
      if (v is String) return int.tryParse(v);
      return null;
    }

    double? _toDouble(dynamic v) {
      if (v is double) return v;
      if (v is int) return v.toDouble();
      if (v is String) return double.tryParse(v);
      return null;
    }

    final scenarioId = _toInt(json['scenario_id']) ?? _toInt(json['id']) ?? 0;

    Map<String, dynamic>? scenarioJson;
    final rawScenario = json['scenario'];
    if (rawScenario is Map<String, dynamic>) {
      scenarioJson = Map<String, dynamic>.from(rawScenario);
    }

    String? _extractString(List<String> keys) {
      for (final key in keys) {
        final value = json[key];
        if (value != null && value.toString().trim().isNotEmpty) {
          return value.toString();
        }
        if (scenarioJson != null) {
          final nestedValue = scenarioJson[key];
          if (nestedValue != null && nestedValue.toString().trim().isNotEmpty) {
            return nestedValue.toString();
          }
        }
      }
      return null;
    }

    int? _extractInt(List<String> keys) {
      for (final key in keys) {
        final direct = _toInt(json[key]);
        if (direct != null) {
          return direct;
        }
        if (scenarioJson != null) {
          final nested = _toInt(scenarioJson[key]);
          if (nested != null) {
            return nested;
          }
        }
      }
      return null;
    }

    final title =
        _extractString(['title', 'scenario_title', 'name']) ??
        'Scenario #$scenarioId';
    final description =
        _extractString(['description', 'scenario_description', 'summary']) ??
        'No description available.';
    final category =
        _extractString(['category', 'scenario_category']) ?? 'general';
    final difficulty =
        _extractString(['difficulty', 'scenario_difficulty', 'level']) ??
        'easy';
    final estimatedDuration = _extractInt([
      'estimated_duration',
      'scenario_estimated_duration',
      'duration',
    ]);

    DateTime completedAt;
    final completedAtRaw = json['completed_at'];
    if (completedAtRaw is String) {
      completedAt = DateTime.tryParse(completedAtRaw) ?? DateTime.now();
    } else if (completedAtRaw is DateTime) {
      completedAt = completedAtRaw;
    } else {
      completedAt = DateTime.now();
    }

    final clarity = _toInt(json['final_clarity_score'] ?? json['clarity_score']);
    final empathy = _toInt(json['final_empathy_score'] ?? json['empathy_score']);
    final assertiveness = _toInt(json['final_assertiveness_score'] ?? json['assertiveness_score']);
    final appropriateness = _toInt(json['final_appropriateness_score'] ?? json['appropriateness_score']);

    double? averageScore = _toDouble(json['average_score']);
    if (averageScore == null) {
      final scores = [clarity, empathy, assertiveness, appropriateness]
          .where((e) => e != null)
          .cast<int>()
          .toList();
      if (scores.isNotEmpty) {
        averageScore = scores.reduce((a, b) => a + b) / scores.length;
      }
    }

    return CompletedScenario(
      scenarioId: scenarioId,
      title: title,
      description: description,
      category: category,
      difficulty: difficulty,
      estimatedDuration: estimatedDuration,
      completedAt: completedAt,
      completionTimeMinutes: _toInt(json['completion_time_minutes']),
      finalClarityScore: clarity,
      finalEmpathyScore: empathy,
      finalAssertivenessScore: assertiveness,
      finalAppropriatenessScore: appropriateness,
      averageScore: averageScore,
      userRating: _toInt(json['user_rating']),
      totalMessages: _toInt(json['total_messages']),
      completionCount: _toInt(json['completion_count']) ?? 1,
    );
  }

  CompletedScenario copyWith({
    String? title,
    String? description,
    String? category,
    String? difficulty,
    int? estimatedDuration,
  }) {
    return CompletedScenario(
      scenarioId: scenarioId,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      difficulty: difficulty ?? this.difficulty,
      estimatedDuration: estimatedDuration ?? this.estimatedDuration,
      completedAt: completedAt,
      completionTimeMinutes: completionTimeMinutes,
      finalClarityScore: finalClarityScore,
      finalEmpathyScore: finalEmpathyScore,
      finalAssertivenessScore: finalAssertivenessScore,
      finalAppropriatenessScore: finalAppropriatenessScore,
      averageScore: averageScore,
      userRating: userRating,
      totalMessages: totalMessages,
      completionCount: completionCount,
    );
  }

  String get formattedDuration {
    if (estimatedDuration == null) return '10-15 min';
    return '${estimatedDuration! - 2}-${estimatedDuration! + 3} min';
  }

  String get formattedCompletionTime {
    if (completionTimeMinutes == null) return 'Unknown';
    return '$completionTimeMinutes min';
  }

  String get formattedAverageScore {
    if (averageScore == null) return 'N/A';
    return '${averageScore!.toStringAsFixed(1)}/10';
  }

  String get formattedRating {
    if (userRating == null) return 'Not rated';
    return '$userRating/5 ⭐';
  }
}
