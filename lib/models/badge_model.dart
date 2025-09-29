class BadgeModel {
  final String badgeId;
  final String title;
  final String description;
  final String imageUrl;
  final DateTime attainedTime;

  BadgeModel({
    required this.badgeId,
    required this.title,
    required this.description,
    required this.imageUrl,
    required this.attainedTime,
  });

  factory BadgeModel.fromJson(Map<String, dynamic> json) {
    return BadgeModel(
      badgeId: json['BadgeId'] ?? '',
      title: json['Title'] ?? '',
      description: json['Description'] ?? '',
      imageUrl: json['Image_url'] ?? '',
      attainedTime: DateTime.tryParse(json['attained_time'] ?? '') ?? DateTime.now(),
    );
  }
}
