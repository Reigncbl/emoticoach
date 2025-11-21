class StatsModel {
  final int scenarioCount;
  final int articleCount;
  final double overallAvgScore;

  StatsModel({
    required this.scenarioCount,
    required this.articleCount,
    required this.overallAvgScore,
  });

  factory StatsModel.fromJson(Map<String, dynamic> json) {
    return StatsModel(
      scenarioCount: json['scenario_count'] ?? 0,
      articleCount: json['article_count'] ?? 0,
      overallAvgScore: (json['overall_avg_score'] ?? 0).toDouble(),
    );
  }
}
