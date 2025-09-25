import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/reading_model.dart';
import '../config/api_config.dart';

class ReadingContentController {
  final String baseUrl = ApiConfig.baseUrl;

  // Fetch all blocks and organize by pages client-side
  Future<List<ChapterPage>> fetchAllPages(String readingsId) async {
    // First get all blocks from the book
    final url = Uri.parse('$baseUrl/books/book/$readingsId/all-blocks');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final List<dynamic> allBlocks = data['blocks'] ?? [];
      final String bookTitle = data['title'] ?? '';

      return _organizeBlocksIntoPages(allBlocks, bookTitle);
    } else {
      throw Exception('Failed to load book content');
    }
  }

  // Get a specific page (chapter)
  Future<ChapterPage> fetchPage(String readingsId, int pageNumber) async {
    final allPages = await fetchAllPages(readingsId);

    print(
      'fetchPage: Requested page $pageNumber, total pages: ${allPages.length}',
    );

    if (pageNumber <= 0 || pageNumber > allPages.length) {
      throw Exception(
        'Page $pageNumber not found (total pages: ${allPages.length})',
      );
    }

    final page = allPages[pageNumber - 1]; // Convert to 0-based index
    print(
      'fetchPage: Returning page ${page.chapterNumber} with ${page.blocks.length} blocks',
    );

    return page;
  }

  // Backward compatibility: alias for fetchPage
  Future<ChapterPage> fetchChapter(String readingsId, int chapterNumber) async {
    return fetchPage(readingsId, chapterNumber);
  }

  // Method to get total number of pages for a book
  Future<int> getTotalPages(String readingsId) async {
    try {
      final allPages = await fetchAllPages(readingsId);
      return allPages.length;
    } catch (e) {
      return 1; // Fallback
    }
  }

  // Backward compatibility: alias for getTotalPages
  Future<int> getTotalChapters(String readingsId) async {
    return getTotalPages(readingsId);
  }

  // Organize blocks into pages where each chapter becomes a separate page
  List<ChapterPage> _organizeBlocksIntoPages(
    List<dynamic> allBlocks,
    String bookTitle,
  ) {
    List<ChapterPage> pages = [];
    List<ReadingBlock> currentPageBlocks = [];
    String currentChapterTitle = "";
    int currentPageNumber = 0;

    print(
      '_organizeBlocksIntoPages: Processing ${allBlocks.length} total blocks',
    );

    // Convert all blocks to ReadingBlock objects first
    List<ReadingBlock> blocks = allBlocks
        .map(
          (blockJson) =>
              ReadingBlock.fromJson(blockJson as Map<String, dynamic>),
        )
        .toList();

    for (ReadingBlock block in blocks) {
      if (block.blockType.toLowerCase() == 'chapter') {
        // Save previous page if it has content
        if (currentPageBlocks.isNotEmpty) {
          print(
            '_organizeBlocksIntoPages: Creating page $currentPageNumber with ${currentPageBlocks.length} blocks',
          );
          pages.add(
            ChapterPage(
              title: bookTitle,
              chapterTitle: currentChapterTitle.isNotEmpty
                  ? currentChapterTitle
                  : "Chapter $currentPageNumber",
              chapterNumber: currentPageNumber,
              blocks: List.from(currentPageBlocks), // Create a copy
            ),
          );
        }

        // Start new page with this chapter
        currentPageNumber++;
        currentChapterTitle = block.content;
        currentPageBlocks = [block]; // Start with the chapter block itself
        print(
          '_organizeBlocksIntoPages: Started new page $currentPageNumber: "$currentChapterTitle"',
        );
      } else {
        // Add non-chapter blocks to current page
        currentPageBlocks.add(block);
      }
    }

    // Add the last page if it has content
    if (currentPageBlocks.isNotEmpty) {
      print(
        '_organizeBlocksIntoPages: Creating final page $currentPageNumber with ${currentPageBlocks.length} blocks',
      );
      pages.add(
        ChapterPage(
          title: bookTitle,
          chapterTitle: currentChapterTitle.isNotEmpty
              ? currentChapterTitle
              : "Chapter $currentPageNumber",
          chapterNumber: currentPageNumber,
          blocks: currentPageBlocks,
        ),
      );
    }

    // If no chapters were found but there are blocks, create a single page
    if (pages.isEmpty && blocks.isNotEmpty) {
      print(
        '_organizeBlocksIntoPages: No chapters found, creating single page with all ${blocks.length} blocks',
      );
      pages.add(
        ChapterPage(
          title: bookTitle,
          chapterTitle: "Chapter 1",
          chapterNumber: 1,
          blocks: blocks,
        ),
      );
    }

    print('_organizeBlocksIntoPages: Created ${pages.length} total pages');
    return pages;
  }

  // Convert ChapterPage to your existing Reading model for backward compatibility
  Reading convertChapterToReading(ChapterPage chapter) {
    // Combine all paragraph blocks into content
    String combinedContent = chapter.blocks
        .where((block) => block.isParagraph)
        .map((block) => block.content)
        .join('\n\n');

    return Reading(
      id: chapter.blocks.isNotEmpty ? chapter.blocks.first.readingsId : '',
      title: chapter.title,
      description: chapter.chapterTitle,
      synopsis: chapter.chapterTitle,
      content: combinedContent,
      category: '', // You might need to get this from another endpoint
      imageUrl:
          chapter.blocks
              .firstWhere(
                (block) => block.imageUrl != null && block.imageUrl!.isNotEmpty,
                orElse: () => ReadingBlock(
                  blockId: 0,
                  readingsId: '',
                  orderIndex: 0,
                  blockType: '',
                  content: '',
                ),
              )
              .imageUrl ??
          '',
      author: '', // You might need to get this from another endpoint
      difficulty: 'Beginner',
      xpPoints: 0,
      rating: 0.0,
      duration: 0,
      progress: 0.0,
      skills: [],
    );
  }

  // Updated method that maintains your existing interface
  Future<Reading> fetchReadingContent(
    String readingsId,
    int chapterNumber,
  ) async {
    final chapterPage = await fetchChapter(readingsId, chapterNumber);
    return convertChapterToReading(chapterPage);
  }
}

// Reading Progress Controller
class ReadingProgressController {
  final String baseUrl = ApiConfig.baseUrl;

  // Fetch reading progress by mobile number
  Future<ReadingProgress?> fetchProgress(
    String mobileNumber,
    String readingsId,
  ) async {
    // URL encode the mobile number to handle special characters
    final encodedMobile = Uri.encodeComponent(mobileNumber);
    final encodedReadingsId = Uri.encodeComponent(readingsId);
    final url = Uri.parse(
      '$baseUrl/books/progress/$encodedMobile/$encodedReadingsId',
    );

    print(
      'Fetching progress for mobile: $mobileNumber, readingsId: $readingsId',
    );
    print('Request URL: $url');

    try {
      final response = await http.get(
        url,
        headers: {'Content-Type': 'application/json'},
      );

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        return ReadingProgress.fromJson(json.decode(response.body));
      } else if (response.statusCode == 404) {
        // No progress found - this is normal for new readings
        print(
          'No progress found for mobile $mobileNumber and reading $readingsId',
        );
        return null;
      } else {
        print('Error fetching progress: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Error fetching progress: $e');
      return null;
    }
  }

  // Bulk fetch all progress for a mobile number (efficient method)
  Future<Map<String, ReadingProgress>> fetchAllProgress(
    String mobileNumber,
  ) async {
    final encodedMobile = Uri.encodeComponent(mobileNumber);
    final url = Uri.parse('$baseUrl/books/progress-bulk/$encodedMobile');

    print('Bulk fetching all progress for mobile: $mobileNumber');
    print('Request URL: $url');

    try {
      final response = await http.get(
        url,
        headers: {'Content-Type': 'application/json'},
      );

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final List<dynamic> progressList = json.decode(response.body);
        Map<String, ReadingProgress> progressMap = {};

        for (var progressJson in progressList) {
          final progress = ReadingProgress.fromJson(progressJson);
          progressMap[progress.readingsId] = progress;
        }

        print('Found progress for ${progressMap.length} readings');
        return progressMap;
      } else {
        print('Error fetching bulk progress: ${response.statusCode}');
        return {};
      }
    } catch (e) {
      print('Error fetching bulk progress: $e');
      return {};
    }
  }

  // Update or create reading progress
  Future<ReadingProgress?> updateProgress({
    required String mobileNumber,
    required String readingsId,
    required int currentPage,
    DateTime? lastReadAt,
    DateTime? completedAt,
  }) async {
    final url = Uri.parse('$baseUrl/books/progress/');

    try {
      final requestBody = {
        'mobile_number': mobileNumber,
        'readings_id': readingsId,
        'current_page': currentPage,
        'last_read_at': lastReadAt?.toIso8601String(),
        'completed_at': completedAt?.toIso8601String(),
      };

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode(requestBody),
      );

      if (response.statusCode == 200) {
        return ReadingProgress.fromJson(json.decode(response.body));
      } else {
        print('Error updating progress: ${response.statusCode}');
        print('Response body: ${response.body}');
        return null;
      }
    } catch (e) {
      print('Error updating progress: $e');
      return null;
    }
  }

  // Get all readings with progress for a mobile number (INEFFICIENT - kept for backward compatibility)
  Future<List<ReadingWithProgress>> fetchReadingsWithProgress(
    String mobileNumber,
    List<Reading> readings,
  ) async {
    List<ReadingWithProgress> readingsWithProgress = [];

    for (Reading reading in readings) {
      try {
        final progress = await fetchProgress(mobileNumber, reading.id);
        readingsWithProgress.add(
          ReadingWithProgress(reading: reading, progress: progress),
        );
      } catch (e) {
        // If progress fetch fails, add reading without progress
        readingsWithProgress.add(
          ReadingWithProgress(reading: reading, progress: null),
        );
      }
    }

    return readingsWithProgress;
  }

  // EFFICIENT: Get all readings with progress using bulk fetch
  Future<List<ReadingWithProgress>> fetchReadingsWithProgressEfficient(
    String mobileNumber,
    List<Reading> readings,
  ) async {
    List<ReadingWithProgress> readingsWithProgress = [];

    try {
      // Fetch all progress in one API call
      final progressMap = await fetchAllProgress(mobileNumber);

      // Map progress to readings
      for (Reading reading in readings) {
        final progress = progressMap[reading.id];
        readingsWithProgress.add(
          ReadingWithProgress(reading: reading, progress: progress),
        );
      }
    } catch (e) {
      print('Error in efficient progress fetch: $e');
      // Fallback: add readings without progress
      for (Reading reading in readings) {
        readingsWithProgress.add(
          ReadingWithProgress(reading: reading, progress: null),
        );
      }
    }

    return readingsWithProgress;
  }
}
