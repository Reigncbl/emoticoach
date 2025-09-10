class AppBarData {
  final String title;
  final String chapter;
  final double percentage;

  AppBarData({
    required this.title,
    required this.chapter,
    required this.percentage,
  });

  factory AppBarData.fromJson(Map<String, dynamic> json) {
    return AppBarData(
      title: json['title'] as String,
      chapter: json['chapter'] as String,
      percentage: (json['percentage'] as num).toDouble(),
    );
  }

  AppBarData copyWith({
    String? title,
    String? chapter,
    double? percentage,
  }) {
    return AppBarData(
      title: title ?? this.title,
      chapter: chapter ?? this.chapter,
      percentage: percentage ?? this.percentage,
    );
  }
}