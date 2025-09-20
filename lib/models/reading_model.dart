// models/reading_model.dart

class Reading {
  final String id;
  final String title;
  final String description;
  final String synopsis;
  final String content;
  final String category;
  final String imageUrl;
  final String author;
  final String difficulty;
  final int xpPoints;
  final double rating;
  final int duration;
  final double progress; 
  final List<String> skills;

  Reading({
    required this.id,
    required this.title,
    required this.description,
    required this.synopsis,
    required this.content,
    required this.category,
    required this.imageUrl,
    required this.author,
    required this.difficulty,
    required this.xpPoints,
    required this.rating,
    required this.duration,
    this.progress = 0.0,
    required this.skills,
  });

  factory Reading.fromJson(Map<String, dynamic> json) {
    return Reading(
      id: json['id'] ?? json['ReadingsID'] ?? '',
      title: json['title'] ?? json['Title'] ?? '',
      description: json['description'] ?? json['Description'] ?? '',
      synopsis:
          json['synopsis'] ?? json['description'] ?? json['Description'] ?? '',
      content: json['content'] ?? '',
      category: json['category'] ?? json['ModuleTypeID'] ?? '',
      imageUrl: json['imageUrl'] ?? json['image_url'] ?? '',
      author: json['author'] ?? json['Author'] ?? '',
      difficulty: json['difficulty'] ?? 'Beginner',
      xpPoints: json['xpPoints'] ?? json['xp_points'] ?? json['XPValue'] ?? 0,
      rating: (json['rating'] ?? json['Rating'] ?? 0).toDouble(),
      duration:
          json['duration'] ??
          json['readTime'] ??
          json['read_time'] ??
          json['EstimatedMinutes'] ??
          0,
      progress: (json['progress'] ?? 0.0).toDouble(),
      skills: json['skills'] != null ? List<String>.from(json['skills']) : [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'synopsis': synopsis,
      'content': content,
      'category': category,
      'imageUrl': imageUrl,
      'author': author,
      'difficulty': difficulty,
      'xpPoints': xpPoints,
      'rating': rating,
      'duration': duration,
      'progress': progress,
      'skills': skills,
    };
  }

  // Helper method to get formatted reading time
  String get formattedDuration => '$duration';

  // Helper method to get formatted rating
  String get formattedRating => '${rating.toStringAsFixed(1)} ';

  // Helper method to check if reading is completed
  bool get isCompleted => progress >= 1.0;

  // Helper method to get progress percentage
  String get progressPercentage => '${(progress * 100).round()}%';
}
