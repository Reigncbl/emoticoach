// models/reading_model.dart
import 'dart:convert';

// New model for chapter response
class ChapterPage {
  final String title;
  final String chapterTitle;
  final int chapterNumber;
  final List<ReadingBlock> blocks;

  ChapterPage({
    required this.title,
    required this.chapterTitle,
    required this.chapterNumber,
    required this.blocks,
  });

  factory ChapterPage.fromJson(Map<String, dynamic> json) {
    return ChapterPage(
      title: json['title'] ?? '',
      chapterTitle: json['chapter_title'] ?? '',
      chapterNumber: json['chapter_number'] ?? 0,
      blocks: (json['blocks'] as List<dynamic>? ?? [])
          .map((blockJson) => ReadingBlock.fromJson(blockJson))
          .toList(),
    );
  }
}

// Model for individual blocks
class ReadingBlock {
  final int blockId;
  final String readingsId;
  final int orderIndex;
  final String blockType;
  final String content;
  final String? imageUrl;
  final String? styleJson;

  ReadingBlock({
    required this.blockId,
    required this.readingsId,
    required this.orderIndex,
    required this.blockType,
    required this.content,
    this.imageUrl,
    this.styleJson,
  });

  factory ReadingBlock.fromJson(Map<String, dynamic> json) {
    return ReadingBlock(
      blockId: json['blockid'] ?? 0,
      readingsId: json['ReadingsID']?.toString() ?? '',
      orderIndex: json['orderindex'] ?? 0,
      blockType: json['blocktype']?.toString() ?? '',
      content: json['content']?.toString() ?? '',
      imageUrl: json['imageurl']?.toString(),
      styleJson: _parseStyleJsonToString(json['stylejson']),
    );
  }

  // Helper method to safely parse styleJson
  static String? _parseStyleJsonToString(dynamic styleJson) {
    if (styleJson == null) return null;
    if (styleJson is String) return styleJson;
    if (styleJson is Map<String, dynamic>) {
      try {
        return jsonEncode(styleJson);
      } catch (e) {
        return null;
      }
    }
    return styleJson.toString();
  }

  // Check if this block is a chapter
  bool get isChapter => blockType.toLowerCase() == 'chapter';
  
  // Check if this block is a paragraph
  bool get isParagraph => blockType.toLowerCase() == 'paragraph';
}

// READING
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
  final int duration; // reading time in minutes
  final double progress; // reading progress (0.0 to 1.0)
  final String chapter;
  final List<String> skills;
  final String? epubFilePath; // New field for EPUB file path

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
    required this.chapter,
    required this.skills,
    this.epubFilePath,
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
      chapter: json['chapter'] ?? 'Chapter' ?? '',
      skills: json['skills'] != null ? List<String>.from(json['skills']) : [],
      epubFilePath: json['epubFilePath'] ?? json['EpubFilePath'],
    );
  }

  Reading copyWith({
    String? id,
    String? title,
    String? description,
    String? synopsis,
    String? content,
    String? category,
    String? imageUrl,
    String? author,
    String? difficulty,
    int? xpPoints,
    double? rating,
    int? duration,
    double? progress = 0.0,
    String? chapter,
    List<String>? skills,
    String? epubFilePath,
  }) {
    return Reading(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      synopsis: synopsis ?? this.synopsis,
      content: content ?? this.content,
      category: category ?? this.category,
      imageUrl: imageUrl ?? this.imageUrl,
      author: author ?? this.author,
      difficulty: difficulty ?? this.difficulty,
      xpPoints: xpPoints ?? this.xpPoints,
      rating: rating ?? this.rating,
      duration: duration ?? this.duration,
      chapter: chapter ?? this.chapter,
      progress: progress ?? this.progress,
      skills: skills ?? this.skills,
      epubFilePath: epubFilePath ?? this.epubFilePath,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title, // reuse for AppBar
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
      'progress': progress, // percentage // reuse for AppBar
      'chapter': chapter,
      'skills': skills,
      'epubFilePath': epubFilePath,
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

  // Helper method to check if reading has an EPUB file
  bool get hasEpubFile => epubFilePath != null && epubFilePath!.isNotEmpty;
}

// Reading Progress Model
class ReadingProgress {
  final String progressId;
  final String readingsId;
  final int? currentPage;
  final String? lastReadAt;
  final String? completedAt;
  final String mobileNumber;

  ReadingProgress({
    required this.progressId,
    required this.readingsId,
    this.currentPage,
    this.lastReadAt,
    this.completedAt,
    required this.mobileNumber,
  });

  factory ReadingProgress.fromJson(Map<String, dynamic> json) {
    return ReadingProgress(
      progressId: json['ProgressID'] ?? '',
      readingsId: json['ReadingsID'] ?? '',
      currentPage: json['CurrentPage'],
      lastReadAt: json['LastReadAt'],
      completedAt: json['CompletedAt'],
      mobileNumber: json['MobileNumber'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'ProgressID': progressId,
      'ReadingsID': readingsId,
      'CurrentPage': currentPage,
      'LastReadAt': lastReadAt,
      'CompletedAt': completedAt,
      'MobileNumber': mobileNumber,
    };
  }

  // Helper method to check if reading is completed
  bool get isCompleted => completedAt != null;

  // Helper method to check if reading has been started
  bool get isStarted => currentPage != null && currentPage! > 0;

  // Helper method to get progress percentage (assuming total pages is known)
  double getProgressPercentage(int totalPages) {
    if (totalPages <= 0 || currentPage == null) return 0.0;
    if (isCompleted) return 1.0;
    return (currentPage! / totalPages).clamp(0.0, 1.0);
  }
}

// Combined model for Reading with Progress
class ReadingWithProgress {
  final Reading reading;
  final ReadingProgress? progress;

  ReadingWithProgress({
    required this.reading,
    this.progress,
  });

  // Helper method to get the reading with updated progress values
  Reading get readingWithProgress {
    if (progress == null) return reading;
    
    // Calculate progress percentage based on current page
    // For now, we'll use a simple calculation - you might want to get total pages from API
    double progressValue = 0.0;
    if (progress!.isCompleted) {
      progressValue = 1.0;
    } else if (progress!.currentPage != null && progress!.currentPage! > 0) {
      // Assume 10 pages as default - you can improve this by fetching actual page count
      progressValue = (progress!.currentPage! / 10).clamp(0.0, 1.0);
    }

    return reading.copyWith(progress: progressValue);
  }

  // Helper methods
  bool get hasProgress => progress != null;
  bool get isStarted => progress?.isStarted ?? false;
  bool get isCompleted => progress?.isCompleted ?? false;
  int? get currentPage => progress?.currentPage;
  String? get lastReadAt => progress?.lastReadAt;
}