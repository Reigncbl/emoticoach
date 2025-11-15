// lib/services/daily_challenge_api.dart

import 'dart:convert';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/dailychallenge_model.dart';
import 'session_service.dart';

class DailyChallengeApi {
  DailyChallengeApi();

  Future<Map<String, String>> _headers() async {
    final uid = await SimpleSessionService.getFirebaseUid();
    final phone = await SimpleSessionService.getUserPhone();
    final userId = (uid != null && uid.isNotEmpty) ? uid : (phone ?? '');

    if (userId.isEmpty) {
      throw Exception('No user id in session');
    }

    return {
      'Content-Type': 'application/json',
      'X-UID': userId, // backend expects this
    };
  }

  /// GET /daily/challenge
  Future<DailyChallenge?> getTodayChallenge() async {
    final res = await http.get(
      Uri.parse(ApiConfig.dailyChallenge),
      headers: await _headers(),
    );

    if (res.statusCode == 404) {
      // No challenge for today
      return null;
    }

    if (res.statusCode != 200) {
      throw Exception('Failed to load daily challenge: ${res.body}');
    }

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return DailyChallenge.fromJson(data);
  }

  /// POST /daily/claim
  Future<ClaimResult> claimChallenge(int challengeId) async {
    final body = jsonEncode({'challenge_id': challengeId});

    final res = await http.post(
      Uri.parse(ApiConfig.dailyClaim),
      headers: await _headers(),
      body: body,
    );

    if (res.statusCode != 200) {
      throw Exception('Failed to claim challenge: ${res.body}');
    }

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return ClaimResult.fromJson(data);
  }
}
