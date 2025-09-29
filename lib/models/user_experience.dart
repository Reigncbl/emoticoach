class UserExperience {
  final String userId;
  final int xp;
  final int level;
  final String levelName;
  final String imageUrl;
  final int? nextLevel;
  final int? nextLevelXp;
  final double progress;

  const UserExperience({
    required this.userId,
    required this.xp,
    required this.level,
    required this.levelName,
    required this.imageUrl,
    this.nextLevel,
    this.nextLevelXp,
    required this.progress,
  });

  /// Create from JSON
  factory UserExperience.fromJson(Map<String, dynamic> json) {
    return UserExperience(
      userId: json['user_id']?.toString() ?? '',
      xp: (json['xp'] as num?)?.toInt() ?? 0,
      level: (json['level'] as num?)?.toInt() ?? 0,
      levelName: json['level_name'] ?? 'Unknown',
      imageUrl: json['image_url'] ?? '',
      nextLevel: json['next_level'] != null
          ? (json['next_level'] as num).toInt()
          : null,
      nextLevelXp: json['next_level_xp'] != null
          ? (json['next_level_xp'] as num).toInt()
          : null,
      progress: (json['progress'] as num?)?.toDouble() ?? 0.0,
    );
  }

  /// Convert to JSON (if needed for saving locally or sending back)
  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'xp': xp,
      'level': level,
      'level_name': levelName,
      'image_url': imageUrl,
      'next_level': nextLevel,
      'next_level_xp': nextLevelXp,
      'progress': progress,
    };
  }

  @override
  String toString() {
    return 'UserExperience(userId: $userId, xp: $xp, level: $level, '
        'levelName: $levelName, progress: $progress)';
  }
}
