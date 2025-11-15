class DailyChallenge {
  final int id;
  final String code;
  final String title;
  final String? description;
  final String type;
  final int xpReward;

  DailyChallenge({
    required this.id,
    required this.code,
    required this.title,
    required this.type,
    required this.xpReward,
    this.description,
  });

  factory DailyChallenge.fromJson(Map<String, dynamic> json) {
    return DailyChallenge(
      id: json['id'] as int,
      code: json['code'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      type: json['type'] as String,
      xpReward: json['xp_reward'] as int,
    );
  }
}

class ClaimResult {
  final bool ok;
  final int awarded;
  final int? totalXp;
  final bool alreadyClaimed;

  ClaimResult({
    required this.ok,
    required this.awarded,
    this.totalXp,
    this.alreadyClaimed = false,
  });

  factory ClaimResult.fromJson(Map<String, dynamic> json) {
    return ClaimResult(
      ok: json['ok'] as bool? ?? false,
      awarded: json['awarded'] as int? ?? 0,
      totalXp: json['totalXp'] as int?,
      alreadyClaimed: json['alreadyClaimed'] as bool? ?? false,
    );
  }
}