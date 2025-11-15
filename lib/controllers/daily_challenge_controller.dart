// lib/controllers/daily_challenge_controller.dart

import '../models/dailychallenge_model.dart';
import '../services/daily_challenge_api.dart';

class DailyChallengeController {
  final DailyChallengeApi api;

  DailyChallenge? challenge;
  bool loading = false;
  bool claiming = false;
  bool claimed = false;
  int? awardedXp;
  String? error;

  DailyChallengeController({required this.api});

  /// Load today's challenge from backend
  Future<void> loadTodayChallenge() async {
    loading = true;
    error = null;
    claimed = false;
    awardedXp = null;

    try {
      final ch = await api.getTodayChallenge();
      challenge = ch;
    } catch (e) {
      error = e.toString();
    } finally {
      loading = false;
    }
  }

  /// Claim today's challenge
  Future<ClaimResult?> claimToday() async {
    if (challenge == null || claiming || claimed) return null;

    claiming = true;
    error = null;

    try {
      final result = await api.claimChallenge(challenge!.id);
      claimed = true;
      awardedXp = result.awarded;
      return result;
    } catch (e) {
      error = e.toString();
      return null;
    } finally {
      claiming = false;
    }
  }
}
