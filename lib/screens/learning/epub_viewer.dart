import 'dart:typed_data';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:epubx/epubx.dart' as epubx;
import 'package:url_launcher/url_launcher.dart';
import '../../controllers/reading_content_controller.dart';
import '../../services/session_service.dart';
import '../../services/book_cache_service.dart';
import '../../widgets/reader_widgets.dart';
import 'reading_content_screen.dart' as reading_screen;

class EpubViewer extends StatefulWidget {
  final List<int> epubBytes;
  final String bookId; // unique ID for each book
  final String? title; // Optional title to display in the app bar

  const EpubViewer({
    super.key,
    required this.epubBytes,
    required this.bookId,
    this.title,
  });

  @override
  State<EpubViewer> createState() => _EpubViewerState();
}

class _EpubViewerState extends State<EpubViewer> {
  List<String> _pages = [];
  int _currentPage = 0;
  PageController? _pageController;
  Map<String, Uint8List> _images = {}; // Store extracted images
  Timer? _progressSaveTimer;
  bool _showChrome = true; // controls full vs minimal UI
  String _bookTitle = 'Book'; // Store the actual book title

  @override
  void initState() {
    super.initState();
    // Delay loading until after the first frame is rendered
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadBook();
    });
  }

  @override
  void dispose() {
    _progressSaveTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadBook() async {
    try {
      print('Starting EPUB book loading...');
      
      // Check if book is already cached
      if (BookCacheService.isCached(widget.bookId)) {
        print('📚 Loading book from cache: ${widget.bookId}');
        final cache = BookCacheService.getCachedBook(widget.bookId)!;
        
        // Get saved progress from database
        int savedPage = 0;
        try {
          final mobileNumber = await SimpleSessionService.getUserPhone();
          if (mobileNumber != null && mobileNumber.isNotEmpty) {
            print('Fetching EPUB progress from database for book ${widget.bookId}');
            
            final progressController = ReadingProgressController();
            final progress = await progressController.fetchProgress(mobileNumber, widget.bookId);
            
            if (progress != null && progress.currentPage != null && progress.currentPage! > 0) {
              savedPage = progress.currentPage! - 1; // Convert 1-based page to 0-based page
              print('Database progress: page ${savedPage + 1}');
            } else {
              print('No progress found in database, starting from page 1');
            }
          }
        } catch (e) {
          print('Error fetching progress from database: $e, starting from page 1');
        }
        
        // Load from cache
        if (!mounted) return;
        setState(() {
          _pages = cache.pages;
          _images = Map.from(cache.images); // Create a copy
          _bookTitle = cache.bookTitle;
          _currentPage = savedPage < cache.pages.length ? savedPage : 0;
          _pageController = PageController(initialPage: _currentPage);
        });
        
        print('✅ Book loaded from cache! ${cache.pages.length} pages');
        return;
      }
      
      print('📖 Book not in cache, parsing EPUB...');
      
      // Get saved progress from database
      int savedPage = 0;
      try {
        final mobileNumber = await SimpleSessionService.getUserPhone();
        if (mobileNumber != null && mobileNumber.isNotEmpty) {
          print('Fetching EPUB progress from database for book ${widget.bookId}');
          
          final progressController = ReadingProgressController();
          final progress = await progressController.fetchProgress(mobileNumber, widget.bookId);
          
          if (progress != null && progress.currentPage != null && progress.currentPage! > 0) {
            savedPage = progress.currentPage! - 1; // Convert 1-based page to 0-based page
            print('Database progress: page ${savedPage + 1}');
          } else {
            print('No progress found in database, starting from page 1');
          }
        }
      } catch (e) {
        print('Error fetching progress from database: $e, starting from page 1');
      }

      // Parse the EPUB file
      print('Parsing EPUB file...');
      print('Converting bytes to Uint8List...');
      final bytes = Uint8List.fromList(widget.epubBytes);
      print('Bytes converted. Length: ${bytes.length}');

      // Parse EPUB book with additional error handling
      print('Parsing EPUB book...');
      final book = await epubx.EpubReader.readBook(bytes);
      print('EPUB book parsed successfully');

      if (book.Chapters == null || book.Chapters!.isEmpty) {
        throw Exception('EPUB book has no chapters or chapters are null');
      }

      print('Found ${book.Chapters!.length} chapters');

      // Debug: Print book metadata
      print('Book Title: ${book.Title}');
      print('Book Author: ${book.Author}');
      
      // Store the book title for use in UI - prioritize passed title over EPUB metadata
      _bookTitle = widget.title ?? book.Title ?? 'Book';
      
      // Debug: Print first few chapters to see what's in them
      for (int i = 0; i < book.Chapters!.length && i < 3; i++) {
        final chapter = book.Chapters![i];
        final content = chapter.HtmlContent ?? '';
        print('Chapter $i Title: ${chapter.Title}');
        print('Chapter $i Content Preview (first 200 chars): ${content.length > 200 ? content.substring(0, 200) : content}');
        if (content.contains('/input/import-1/')) {
          print('*** Found /input/import-1/ reference in Chapter $i ***');
        }
      }

      // Extract images from EPUB
      await _extractImages(book);

      // Collect all chapters text
      final buffer = StringBuffer();
      int chapterCount = 0;
      for (var chapter in book.Chapters!) {
        chapterCount++;
        final content = chapter.HtmlContent ?? '';
        print('Processing chapter $chapterCount, content length: ${content.length}');
        buffer.writeln(content);
      }

      print('All chapters processed. Total content length: ${buffer.length}');

      // Clean HTML tags but preserve image markers
      final processedText = _processHtmlContent(buffer.toString());
      print('HTML processed. Final text length: ${processedText.length}');

      if (processedText.trim().isEmpty) {
        throw Exception('EPUB content is empty after processing');
      }

      // If text is very large, use simpler pagination to avoid crashes
      List<String> pages;
      if (processedText.length > 1000000) { // Over 1MB of text
        print('Large text detected (${processedText.length} chars), using simple pagination...');
        pages = _simpleTextPagination(processedText);
        print('Simple pagination complete. Generated ${pages.length} pages');
      } else {
        // Generate pages based on screen size
        print('Starting text pagination...');
        
        // Add timeout to prevent hanging
        pages = await Future.any([
          _paginateText(processedText),
          Future.delayed(const Duration(seconds: 30), () {
            throw TimeoutException('Pagination timed out after 30 seconds', const Duration(seconds: 30));
          }),
        ]);
        
        print('Pagination complete. Generated ${pages.length} pages');
      }

      if (!mounted) return;

      setState(() {
        _pages = pages;
        _currentPage = savedPage < pages.length ? savedPage : 0;
        _pageController = PageController(initialPage: _currentPage);
      });
      
      // Cache the parsed book data for faster subsequent loads
      print('💾 Caching parsed book data for ${widget.bookId}');
      BookCacheService.cacheBook(
        widget.bookId,
        BookCacheEntry(
          pages: pages,
          images: Map.from(_images),
          bookTitle: _bookTitle,
        ),
      );
      
      print('EPUB book loaded successfully!');
      
    } catch (e, stackTrace) {
      print('Error loading EPUB book: $e');
      print('Stack trace: $stackTrace');
      if (!mounted) return;
      
      // Show error and go back
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading book: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
      Navigator.of(context).pop();
    }
  }

  Future<List<String>> _paginateText(String text) async {
  print('Starting word-level pagination for ${text.length} characters...');
  final contextSize = MediaQuery.of(context).size;

  // Calculate available space for content
  final screenHeight = contextSize.height;
  final screenWidth = contextSize.width;
  final statusBarHeight = MediaQuery.of(context).padding.top;
  final bottomSafeArea = MediaQuery.of(context).padding.bottom;
  
  const double estimatedFooterHeight = 50.0;
  
  final availableHeight = screenHeight -
      kToolbarHeight - // app bar (typically 56px)
      statusBarHeight - // status bar (varies by device)
      bottomSafeArea - // bottom safe area
      estimatedFooterHeight - // footer height
      16.0; // padding (16px top only, no bottom padding)

  final availableWidth = screenWidth - 32.0; // Account for horizontal padding

  print('Available space: ${availableWidth.toInt()}x${availableHeight.toInt()}px');
  print('Breakdown: screenHeight=${screenHeight.toInt()}px - appBar=56px - statusBar=${statusBarHeight.toInt()}px - footer=60px - bottomSafe=${bottomSafeArea.toInt()}px - padding=16px');

  // Text style matching the one used in _buildTextWidget
  const textStyle = TextStyle(
    fontSize: 16.0,
    height: 1.5,
    color: Colors.black87,
  );

  // Default image height and margin
  const double defaultImageHeight = 120.0;
  const double imageMargin = 16.0;

  final List<String> pages = [];
  
  // Split text into segments separated by newlines to preserve paragraph structure
  final segments = <String>[];
  final lines = text.split('\n');
  
  for (int i = 0; i < lines.length; i++) {
    final line = lines[i];
    if (line.trim().isEmpty) {
      // Preserve empty lines as paragraph separators
      segments.add('\n');
    } else {
      // Split line into words
      final words = line.split(RegExp(r' +'));
      for (final word in words) {
        if (word.isNotEmpty) {
          segments.add(word);
        }
      }
      // Add newline at end of each line (except the last one if next is also newline)
      if (i < lines.length - 1) {
        segments.add('\n');
      }
    }
  }
  
  int segmentIndex = 0;
  int pageCount = 0;

  while (segmentIndex < segments.length) {
    pageCount++;
    if (pageCount % 10 == 0) {
      print('Processing page $pageCount...');
    }

    List<String> currentPageSegments = [];
    double usedHeight = 0.0;

    // Try to fit as many segments as possible on this page
    while (segmentIndex < segments.length) {
      final segment = segments[segmentIndex];
      
      // Always add newlines to preserve structure
      if (segment == '\n') {
        currentPageSegments.add(segment);
        segmentIndex++;
        continue;
      }
      
      if (segment.trim().isEmpty) {
        segmentIndex++;
        continue;
      }

      // Create test text with the new segment
      List<String> testSegments = [...currentPageSegments, segment];
      String testText = _reconstructText(testSegments);

      // Detect images with optional dimensions [IMAGE:src] or [IMAGE:src:width:height]
      final imageMatches = RegExp(r'\[IMAGE:([^\]]+)\]').allMatches(testText);

      double testHeight = 0.0;

      // Remove image placeholders from text for measurement
      final textWithoutImages = testText.replaceAll(RegExp(r'\[IMAGE:[^\]]*\]'), '');
      if (textWithoutImages.trim().isNotEmpty) {
        final textPainter = TextPainter(
          text: TextSpan(text: textWithoutImages, style: textStyle),
          textDirection: TextDirection.ltr,
          textAlign: TextAlign.justify,
        );
        textPainter.layout(maxWidth: availableWidth);
        testHeight = textPainter.height;
        // ❌ Removed dispose() — not needed
      }

      // Add image heights (support variable height like [IMAGE:src:width:height])
      for (final match in imageMatches) {
        final imageInfo = match.group(1) ?? '';
        final parts = imageInfo.split(':');
        
        double imgHeight = defaultImageHeight;
        if (parts.length >= 3) {
          // Has width:height or :height
          final heightStr = parts[2];
          if (heightStr.isNotEmpty) {
            imgHeight = double.tryParse(heightStr) ?? defaultImageHeight;
          }
        } else if (parts.length >= 2) {
          // Check if second part is a number (could be width or height)
          final widthStr = parts[1];
          if (widthStr.isNotEmpty) {
            // Use width as height estimation if no height specified
            imgHeight = double.tryParse(widthStr) ?? defaultImageHeight;
          }
        }
        
        // Cap image height to avoid extremely tall images breaking pagination
        imgHeight = imgHeight.clamp(60.0, availableHeight * 0.9);
        testHeight += imgHeight + imageMargin;
      }

      // Check if adding this segment would exceed available height
      if (testHeight <= availableHeight) {
        // It fits! Add the segment
        currentPageSegments.add(segment);
        usedHeight = testHeight;
        segmentIndex++;
      } else {
        // It doesn't fit by height, break here
        break;
      }
    }

    // If we couldn't fit anything on this page, force at least one segment
    if (currentPageSegments.isEmpty && segmentIndex < segments.length) {
      currentPageSegments.add(segments[segmentIndex]);
      segmentIndex++;
      print('Warning: Forced single segment on page $pageCount');
    }

    // Create the page content - reconstruct text preserving newlines
    if (currentPageSegments.isNotEmpty) {
      final pageText = _reconstructText(currentPageSegments);
      pages.add(pageText);
      
      // Calculate fill percentage for logging
      final fillPercentage = (usedHeight / availableHeight * 100).toInt();
      print('Page $pageCount: ${currentPageSegments.length} segments, ${pageText.length} chars, ${usedHeight.toInt()}px/${availableHeight.toInt()}px (${fillPercentage}% full)');
    }
  }

  return pages;
}

// Helper function to reconstruct text from segments while preserving newlines
String _reconstructText(List<String> segments) {
  final buffer = StringBuffer();
  for (int i = 0; i < segments.length; i++) {
    final segment = segments[i];
    if (segment == '\n') {
      buffer.write('\n');
    } else {
      buffer.write(segment);
      // Add space after words, but not before newlines
      if (i + 1 < segments.length && segments[i + 1] != '\n') {
        buffer.write(' ');
      }
    }
  }
  return buffer.toString();
}


  // Extract images from EPUB and store them
  Future<void> _extractImages(epubx.EpubBook book) async {
    print('Extracting images from EPUB...');
    
    if (book.Content?.Images != null) {
      for (var imageEntry in book.Content!.Images!.entries) {
        try {
          final imageKey = imageEntry.key;
          final imageFile = imageEntry.value;
          
          if (imageFile.Content != null) {
            // Store with the original key
            _images[imageKey] = Uint8List.fromList(imageFile.Content!);
            
            // Also store with just the filename for easier lookup
            final fileName = imageKey.split('/').last;
            if (fileName.isNotEmpty && fileName != imageKey) {
              _images[fileName] = Uint8List.fromList(imageFile.Content!);
            }
            
            print('Extracted image: $imageKey (${imageFile.Content!.length} bytes)');
          }
        } catch (e) {
          print('Error extracting image ${imageEntry.key}: $e');
        }
      }
    }
    
    print('Total images extracted: ${_images.length}');
    print('Image keys: ${_images.keys.toList()}');
  }

  // Process HTML content to preserve images and links but clean other tags
  // Inspired by Google Play Books approach: normalize HTML structure first, then extract content
  String _processHtmlContent(String html) {
    String processedText = html;

    print('🔧 Processing HTML content (length: ${html.length})...');
    
    // Count images in original HTML
    final imgCount = RegExp(r'<img[^>]*>', caseSensitive: false).allMatches(html).length;
    if (imgCount > 0) {
      print('  Found $imgCount <img> tags in HTML');
    }

    // 1. Images -> markers with size detection
    final imgTagRegex = RegExp(r'<img[^>]*>', caseSensitive: false);
    processedText = processedText.replaceAllMapped(imgTagRegex, (match) {
      final tag = match.group(0) ?? '';
      String src = '';
      String? width;
      String? height;
      
      // Extract src
      final srcMatch1 = RegExp(r'src="([^"]*)"', caseSensitive: false).firstMatch(tag);
      final srcMatch2 = RegExp(r"src='([^']*)'", caseSensitive: false).firstMatch(tag);
      if (srcMatch1 != null) {
        src = srcMatch1.group(1) ?? '';
      } else if (srcMatch2 != null) {
        src = srcMatch2.group(1) ?? '';
      }
      
      // Extract width and height if specified
      final widthMatch = RegExp(r'width[=:]\s*["\x27]?(\d+)', caseSensitive: false).firstMatch(tag);
      final heightMatch = RegExp(r'height[=:]\s*["\x27]?(\d+)', caseSensitive: false).firstMatch(tag);
      if (widthMatch != null) width = widthMatch.group(1);
      if (heightMatch != null) height = heightMatch.group(1);
      
      // Check for style attribute with width/height
      final styleMatch = RegExp(r'style="([^"]*)"', caseSensitive: false).firstMatch(tag);
      if (styleMatch != null) {
        final style = styleMatch.group(1) ?? '';
        final styleWidth = RegExp(r'width:\s*(\d+)px', caseSensitive: false).firstMatch(style);
        final styleHeight = RegExp(r'height:\s*(\d+)px', caseSensitive: false).firstMatch(style);
        if (styleWidth != null) width = styleWidth.group(1);
        if (styleHeight != null) height = styleHeight.group(1);
      }
      
      // Create image marker with optional dimensions
      if (src.isNotEmpty) {
        final marker = width != null || height != null 
            ? '\n[IMAGE:$src:${width ?? ''}:${height ?? ''}]\n'
            : '\n[IMAGE:$src]\n';
        print('  Converted <img src="$src"> to $marker');
        return marker;
      }
      print('  ⚠️ Found <img> tag with no src attribute');
      return '';
    });
    
    // Count image markers after conversion
    final markerCount = RegExp(r'\[IMAGE:[^\]]+\]').allMatches(processedText).length;
    if (markerCount > 0) {
      print('  ✅ Created $markerCount [IMAGE:...] markers');
    }

    // 2. Normalize line breaks for block elements BEFORE processing content
    // Headings need space before and after
    processedText = processedText.replaceAll(RegExp(r'<h[1-6][^>]*>', caseSensitive: false), '\n\n');
    processedText = processedText.replaceAll(RegExp(r'</h[1-6]>', caseSensitive: false), '\n\n');
    
    // Paragraphs -> ensure proper spacing
    processedText = processedText.replaceAll(RegExp(r'<p[^>]*>', caseSensitive: false), '\n');
    processedText = processedText.replaceAll(RegExp(r'</p>', caseSensitive: false), '\n\n');
    
    // Divs also create block-level spacing
    processedText = processedText.replaceAll(RegExp(r'<div[^>]*>', caseSensitive: false), '\n');
    processedText = processedText.replaceAll(RegExp(r'</div>', caseSensitive: false), '\n\n');
    
    // Line breaks
    processedText = processedText.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n');

    // 3. Process headings FIRST - extract content and preserve inline formatting and links
    for (int level = 1; level <= 6; level++) {
      final headingRegex = RegExp('<h$level[^>]*>(.*?)</h$level>', caseSensitive: false, dotAll: true);
      processedText = processedText.replaceAllMapped(headingRegex, (m) {
        String inner = m.group(1) ?? '';
        
        // Process links within heading content FIRST
        inner = _processLinks(inner);
        
        // Process inline styles (bold, italic, etc.) within heading
        inner = _processInlineStyles(inner);
        
        // Strip any remaining HTML tags
        inner = inner.replaceAll(RegExp(r'<[^>]*>'), '');
        
        // Clean up the text
        inner = inner.trim();
        
        return '\n[H$level]$inner[/H$level]\n';
      });
    }

    // 4. Process links in remaining content (must be done BEFORE processing other inline styles)
    processedText = _processLinks(processedText);

    // 5. Blockquotes (process inline styles within blockquotes)
    processedText = processedText.replaceAllMapped(
      RegExp(r'<blockquote[^>]*>(.*?)</blockquote>', caseSensitive: false, dotAll: true),
      (m) {
        String inner = m.group(1) ?? '';
        inner = _processInlineStyles(inner);
        return '\n[Q]${inner.trim()}[/Q]\n';
      },
    );

    // 6. Lists: unordered and ordered. Convert <li> to bullet lines.
    processedText = processedText.replaceAllMapped(
      RegExp(r'<li[^>]*>(.*?)</li>', caseSensitive: false, dotAll: true),
      (m) {
        String inner = m.group(1) ?? '';
        inner = _processInlineStyles(inner);
        return '\n• ${inner.trim()}\n';
      },
    );
    // Remove wrapping <ul>/<ol>
    processedText = processedText.replaceAll(RegExp(r'</?(ul|ol)[^>]*>', caseSensitive: false), '\n');

    // 7. Process remaining inline styles
    processedText = _processInlineStyles(processedText);

    // 8. Strip ALL remaining HTML tags (including orphaned/stray closing tags)
    processedText = processedText.replaceAll(RegExp(r'<[^>]*>'), '');

    // 9. Cleanup special paths / noise and HTML entities
    processedText = processedText
        .replaceAll(RegExp(r'/input/import-\d+/[^\n]*\.(pdf|epub)', caseSensitive: false), '')
        .replaceAll(RegExp(r'/app/public/task/[^\n]*\.(pdf|epub)', caseSensitive: false), '')
        .replaceAll(RegExp(r'^\s*/input/.*$', multiLine: true), '')
        .replaceAll(RegExp(r'^\s*/app/public/.*$', multiLine: true), '')
        .replaceAll(RegExp(r'[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}\.pdf', caseSensitive: false), '')
        // Clean up HTML entities
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&mdash;', '—')
        .replaceAll('&ndash;', '–')
        .replaceAll('&hellip;', '…')
        // Clean up extra spaces and newlines
        .replaceAll(RegExp(r' {2,}'), ' ')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();

    // 10. Clean up orphaned/malformed tokens
    processedText = _cleanupOrphanedTokens(processedText);

    // 11. Clean up duplicate heading tokens and malformed structures
    processedText = _cleanupDuplicateTokens(processedText);

    // 12. Promote inline "Chapter X" occurrences to headings ONLY if not already in headings
    final chapterInlineRegex = RegExp(r'(?:(?<=\.)|(?<=\!)|(?<=\?))\s+(Chapter\s+\d+[^\n]{0,80})', caseSensitive: false);
    processedText = processedText.replaceAllMapped(chapterInlineRegex, (m) {
      final raw = m.group(1)!.trim();
      // Only promote if not already inside heading tokens
      final fullMatch = m.group(0)!;
      if (!fullMatch.contains('[H') && !fullMatch.contains('[/H')) {
        return '\n\n[H3]${_normalizeChapterTitle(raw)}[/H3]\n\n';
      }
      return fullMatch;
    });

    // Also upgrade standalone lines starting with Chapter <number> - but only if not already tokenized
    final chapterLineRegex = RegExp(r'(^|\n)(?!\[H)(Chapter\s+\d+[^\n]{0,80})', caseSensitive: false);
    processedText = processedText.replaceAllMapped(chapterLineRegex, (m) {
      final prefix = m.group(1) ?? '';
      final raw = m.group(2)!.trim();
      return '$prefix[H3]${_normalizeChapterTitle(raw)}[/H3]\n';
    });

    // Final cleanup of duplicate tokens and multiple newlines
    processedText = _cleanupDuplicateTokens(processedText);
    processedText = processedText.replaceAll(RegExp(r'\n{3,}'), '\n\n');

    return processedText;
  }

  // Extract and process links from HTML content
  String _processLinks(String text) {
    String processed = text;
    
    final linkTagRegex = RegExp(r'<a\s+([^>]*?)>(.*?)</a>', caseSensitive: false, dotAll: true);
    processed = processed.replaceAllMapped(linkTagRegex, (match) {
      final attributes = match.group(1) ?? '';
      String linkText = match.group(2) ?? '';
      String href = '';
      
      // Extract href
      final hrefMatch1 = RegExp(r'href="([^"]*)"', caseSensitive: false).firstMatch(attributes);
      final hrefMatch2 = RegExp(r"href='([^']*)'", caseSensitive: false).firstMatch(attributes);
      if (hrefMatch1 != null) {
        href = hrefMatch1.group(1) ?? '';
      } else if (hrefMatch2 != null) {
        href = hrefMatch2.group(1) ?? '';
      }
      
      // Process inline styles FIRST (bold, italic, etc.) before stripping tags
      linkText = _processInlineStyles(linkText);
      
      // Then strip any remaining HTML tags (like <span>, etc.)
      linkText = linkText.replaceAll(RegExp(r'<[^>]*>'), '');
      
      // Return link marker if we have both text and href
      if (linkText.isNotEmpty && href.isNotEmpty) {
        return '[LINK:$href]$linkText[/LINK]';
      } else if (linkText.isNotEmpty) {
        return linkText; // Just return the text if no href
      }
      return '';
    });
    
    return processed;
  }

  // Normalize chapter title spacing like "Chapter 3 :Importance" -> "Chapter 3: Importance"
  String _normalizeChapterTitle(String title) {
    String t = title;
    t = t.replaceAllMapped(RegExp(r'(Chapter\s+\d+)\s*:\s*', caseSensitive: false), (m) => '${m.group(1)}: ');
    // Ensure single spaces
    t = t.replaceAll(RegExp(r'\s{2,}'), ' ');
    return t.trim();
  }

  // Process inline styles like bold, italic, underline
  String _processInlineStyles(String text) {
    String processed = text;
    
    // Process inline styles -> tokens (using backreferences to ensure matching tags)
    processed = processed
      .replaceAllMapped(RegExp(r'<(strong|b)\b[^>]*>(.*?)</\1>', caseSensitive: false, dotAll: true), (match) => '[B]${match.group(2)}[/B]')
      .replaceAllMapped(RegExp(r'<(em|i)\b[^>]*>(.*?)</\1>', caseSensitive: false, dotAll: true), (match) => '[I]${match.group(2)}[/I]')
      .replaceAllMapped(RegExp(r'<u\b[^>]*>(.*?)</u>', caseSensitive: false, dotAll: true), (match) => '[U]${match.group(1)}[/U]');
    
    return processed;
  }

  // Clean up orphaned/stray tokens that don't have matching opening tags
  String _cleanupOrphanedTokens(String text) {
    String cleaned = text;
    
    // Track opening and closing tags to find orphans
    // Remove orphaned closing tags like [/B] without a matching [B]
    final tokens = ['B', 'I', 'U', 'H1', 'H2', 'H3', 'H4', 'H5', 'H6', 'Q', 'LINK'];
    
    for (final token in tokens) {
      // Count opening and closing tags
      final openRegex = RegExp('\\[$token(?::[^\\]]*)?\\]', caseSensitive: false);
      final closeRegex = RegExp('\\[/$token\\]', caseSensitive: false);
      
      final openMatches = openRegex.allMatches(cleaned);
      final closeMatches = closeRegex.allMatches(cleaned);
      
      // If we have more closing tags than opening tags, we have orphans
      if (closeMatches.length > openMatches.length) {
        // Remove extra closing tags from the end
        int toRemove = closeMatches.length - openMatches.length;
        final closeList = closeMatches.toList();
        
        for (int i = closeList.length - 1; i >= 0 && toRemove > 0; i--) {
          final match = closeList[i];
          // Replace this closing tag with empty string
          cleaned = cleaned.substring(0, match.start) + cleaned.substring(match.end);
          toRemove--;
        }
      }
    }
    
    return cleaned;
  }

  // Clean up duplicate tokens and malformed structures
  String _cleanupDuplicateTokens(String text) {
    String cleaned = text;
    
    // Remove duplicate consecutive heading tokens like [H2][H2] -> [H2]
    cleaned = cleaned.replaceAllMapped(RegExp(r'\[H([1-6])\]\[H[1-6]\]', caseSensitive: false), (match) {
      return '[H${match.group(1)}]';
    });
    
    // Remove duplicate consecutive heading closing tokens like [/H2][/H2] -> [/H2]
    cleaned = cleaned.replaceAllMapped(RegExp(r'\[/H([1-6])\]\[/H[1-6]\]', caseSensitive: false), (match) {
      return '[/H${match.group(1)}]';
    });
    
    // Fix malformed patterns where inline styles appear before heading tags
    // Pattern: [B] [H2]text[/H2] -> [H2][B] text[/B][/H2]
    cleaned = cleaned.replaceAllMapped(
      RegExp(r'\[([BIU])\]\s*\[H([1-6])\](.*?)\[/H\2\]', caseSensitive: false, dotAll: true),
      (match) {
        final style = match.group(1);
        final level = match.group(2);
        final content = match.group(3);
        // Move the style inside the heading
        return '[H$level][$style]$content[/$style][/H$level]';
      },
    );
    
    // Fix pattern where heading tags appear inside inline styles
    // Pattern: [B][H2]text[/H2][/B] -> [H2][B]text[/B][/H2]
    cleaned = cleaned.replaceAllMapped(
      RegExp(r'\[([BIU])\]\[H([1-6])\](.*?)\[/H\2\]\[/\1\]', caseSensitive: false, dotAll: true),
      (match) {
        final style = match.group(1);
        final level = match.group(2);
        final content = match.group(3);
        // Swap: heading should be outer, style should be inner
        return '[H$level][$style]$content[/$style][/H$level]';
      },
    );
    
    // Fix pattern like [H2][B]text[/B][/H2][H3] -> [H2][B]text[/B][/H2] (remove trailing heading)
    cleaned = cleaned.replaceAllMapped(RegExp(r'\[/H([1-6])\]\[H[1-6]\]', caseSensitive: false), (match) {
      return '[/H${match.group(1)}]\n\n';
    });
    
    // Remove empty heading tokens like [H2][/H2] or [H2]  [/H2]
    cleaned = cleaned.replaceAll(RegExp(r'\[H([1-6])\]\s*\[/H\1\]', caseSensitive: false), '');
    
    // Remove duplicate inline style tokens [B][B] -> [B]
    cleaned = cleaned.replaceAll(RegExp(r'\[([BIU])\]\[(\1)\]', caseSensitive: false), '[\$1]');
    cleaned = cleaned.replaceAll(RegExp(r'\[/([BIU])\]\[/(\1)\]', caseSensitive: false), '[/\$1]');
    
    // Clean up orphaned tokens that don't have content
    cleaned = cleaned.replaceAll(RegExp(r'\[([BIU])\]\s*\[/\1\]', caseSensitive: false), '');
    
    // Remove orphaned opening tags (opening tags without closing tags)
    // This is a simple approach: remove any [B], [I], [U] that appears alone
    // Match opening tag followed by anything that's NOT its closing tag until end of string or another tag
    final tokens = ['B', 'I', 'U'];
    for (final token in tokens) {
      // Remove orphaned opening tags that don't have a matching closing tag
      // by checking if there are more opening tags than closing tags
      int openCount = RegExp('\\[$token\\]', caseSensitive: false).allMatches(cleaned).length;
      int closeCount = RegExp('\\[/$token\\]', caseSensitive: false).allMatches(cleaned).length;
      
      if (openCount > closeCount) {
        // Remove orphaned opening tags from the end working backwards
        int toRemove = openCount - closeCount;
        while (toRemove > 0) {
          // Find the last orphaned opening tag (one that doesn't have a closing tag after it)
          final matches = RegExp('\\[$token\\]', caseSensitive: false).allMatches(cleaned).toList();
          for (int i = matches.length - 1; i >= 0 && toRemove > 0; i--) {
            final openMatch = matches[i];
            // Check if there's a corresponding closing tag after this opening
            final afterOpen = cleaned.substring(openMatch.end);
            final closeMatch = RegExp('\\[/$token\\]', caseSensitive: false).firstMatch(afterOpen);
            
            if (closeMatch == null) {
              // This is an orphaned opening tag, remove it
              cleaned = cleaned.substring(0, openMatch.start) + cleaned.substring(openMatch.end);
              toRemove--;
              break; // Restart the loop with updated string
            }
          }
          if (toRemove > 0) break; // Safety: avoid infinite loop
        }
      }
    }
    
    return cleaned;
  }

  // Build page content with text, images, and links - optimized for natural flow
  Widget _buildPageContent(String pageText) {
    final List<Widget> contentWidgets = [];

    // Debug: Print page text to see what we're working with
    if (pageText.contains('[IMAGE:')) {
      print('📄 Page contains images. Full text:\n$pageText\n---');
    }

    // Split text by image markers and process each part
    final imagePlaceholderRegex = RegExp(r'\[IMAGE:([^\]]+)\]');
    final matches = imagePlaceholderRegex.allMatches(pageText);

    if (matches.isNotEmpty) {
      print('🖼️ Found ${matches.length} image markers in this page');
    }

    int lastIndex = 0;

    for (final match in matches) {
      // Add text before the image
      if (match.start > lastIndex) {
        final textPart = pageText.substring(lastIndex, match.start).trim();
        if (textPart.isNotEmpty) {
          print('  Adding text before image: "${textPart.substring(0, textPart.length > 50 ? 50 : textPart.length)}..."');
          contentWidgets.add(_buildTextWidget(textPart));
        }
      }

      // Add the image - parse image info (src:width:height)
      final imageInfo = match.group(1) ?? '';
      if (imageInfo.isNotEmpty) {
        final parts = imageInfo.split(':');
        final imageSrc = parts[0];
        String? width = parts.length > 1 && parts[1].isNotEmpty ? parts[1] : null;
        String? height = parts.length > 2 && parts[2].isNotEmpty ? parts[2] : null;
        
        print('  Adding image widget: src="$imageSrc", width=$width, height=$height');
        contentWidgets.add(_buildImageWidget(imageSrc, width: width, height: height));
      }

      lastIndex = match.end;
    }

    // Add remaining text after the last image
    if (lastIndex < pageText.length) {
      final textPart = pageText.substring(lastIndex).trim();
      if (textPart.isNotEmpty) {
        print('  Adding text after images: "${textPart.substring(0, textPart.length > 50 ? 50 : textPart.length)}..."');
        contentWidgets.add(_buildTextWidget(textPart));
      }
    }

    // If no images were found, just add the text
    if (contentWidgets.isEmpty) {
      contentWidgets.add(_buildTextWidget(pageText));
    }

    print('✅ Total widgets in page: ${contentWidgets.length}');

    // Allow vertical scrolling inside a page to avoid overflow when style tokens inflate height
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: EdgeInsets.zero,
          physics: const BouncingScrollPhysics(),
            // If content is shorter than viewport, Column will take only needed space
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: IntrinsicHeight(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: contentWidgets,
              ),
            ),
          ),
        );
      },
    );
  }

  // Build text widget with proper styling and constraints
  Widget _buildTextWidget(String text) {
    // Use a much lighter token cleanup to avoid corrupting well-formed tags.
    // The previous heavy cleanup introduced malformed sequences like [[H2]/B].
    String working = _lightTokenCleanup(text);

    // Ensure proper spacing before headings
    working = working.replaceAllMapped(
      RegExp(r'(?<!\n\n)\n\[(H[1-6])\]', caseSensitive: false),
      (m) => '\n\n[${m.group(1)!.toUpperCase()}]'
    );
    // Ensure proper spacing after closing heading
    working = working.replaceAllMapped(
      RegExp(r'\[/H([1-6])\](?!\n\n)', caseSensitive: false),
      (m) => '[/H${m.group(1)}]\n\n'
    );

    // Final cleanup: remove any remaining orphaned inline style opening tags
    // These are tags that don't have matching closing tags
    working = _removeOrphanedInlineTags(working);

    // Parse the styled spans - this handles all formatting tokens
    final spans = _parseStyledSpans(working);
    
    // If no spans were generated, fall back to plain text
    if (spans.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8.0),
        child: Text(
          working,
          style: const TextStyle(
            fontSize: 16,
            height: 1.6,
            color: Colors.black87,
            letterSpacing: 0.1,
          ),
          textAlign: TextAlign.justify,
          softWrap: true,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(
            fontSize: 16, 
            height: 1.6, 
            color: Colors.black87, 
            letterSpacing: 0.1,
          ), 
          children: spans,
        ),
        textAlign: TextAlign.justify,
        softWrap: true,
      ),
    );
  }

  // Lightweight cleanup that only fixes the most common benign issues without
  // restructuring valid nested tokens. This prevents breaking sequences like
  // [H2][B]Heading[/B][/H2].
  String _lightTokenCleanup(String text) {
    String working = text;

    // Normalize Windows line endings just in case
    working = working.replaceAll('\r\n', '\n');

    // Collapse >2 blank lines
    working = working.replaceAll(RegExp(r'\n{3,}'), '\n\n');

    // Remove duplicated immediate heading opens like [H2][H2] -> [H2]
    working = working.replaceAllMapped(
      RegExp(r'(\[H([1-6])\])\1+', caseSensitive: false),
      (m) => '[H${m.group(2)}]',
    );

    // Remove duplicated immediate heading closes like [/H2][/H2] -> [/H2]
    working = working.replaceAllMapped(
      RegExp(r'(\[/H([1-6])\])\1+', caseSensitive: false),
      (m) => '[/H${m.group(2)}]',
    );

    // Remove empty headings [H2][/H2]
    working = working.replaceAll(RegExp(r'\[H([1-6])\]\s*\[/H\1\]', caseSensitive: false), '');

    // Fix malformed patterns where inline styles appear before heading tags
    // Pattern: [B] [H2]text[/H2] -> [H2]text[/H2] (remove the orphaned style tag)
    working = working.replaceAll(
      RegExp(r'\[([BIU])\]\s*\[H([1-6])\]', caseSensitive: false),
      '[H\$2]',
    );
    
    // Fix pattern where heading tags appear inside inline styles
    // Pattern: [B][H2]text[/H2][/B] -> [H2]text[/H2]
    working = working.replaceAll(
      RegExp(r'\[([BIU])\]\[H([1-6])\](.*?)\[/H\2\]\[/\1\]', caseSensitive: false),
      '[H\$2]\$3[/H\$2]',
    );

    // Fix a specific previously introduced malformed pattern [[H2]/B] -> [/H2]
    working = working.replaceAll(
      RegExp(r'\[\[H([1-6])\]/([BIU])\]', caseSensitive: false),
      '[/H\$1]',
    );

    return working;
  }

  // Remove orphaned inline tags that don't have matching closing tags
  String _removeOrphanedInlineTags(String text) {
    String cleaned = text;
    
    // For each inline style token (B, I, U), count opening and closing tags
    // and remove orphaned tags (both opening and closing)
    final tokens = ['B', 'I', 'U'];
    
    for (final token in tokens) {
      bool changed = true;
      // Keep iterating until no more changes (to handle nested orphans)
      while (changed) {
        final beforeLength = cleaned.length;
        
        // Find all opening and closing tags
        final openMatches = RegExp('\\[$token\\]', caseSensitive: false).allMatches(cleaned).toList();
        final closeMatches = RegExp('\\[/$token\\]', caseSensitive: false).allMatches(cleaned).toList();
        
        // Handle orphaned opening tags (more opens than closes)
        if (openMatches.length > closeMatches.length) {
          // Find the first orphaned opening tag (one without a matching close)
          for (int i = 0; i < openMatches.length; i++) {
            final openPos = openMatches[i].start;
            
            // Count how many opens and closes exist after this position
            int opensAfter = 0;
            int closesAfter = 0;
            
            for (int j = i + 1; j < openMatches.length; j++) {
              if (openMatches[j].start > openPos) opensAfter++;
            }
            
            for (final closeMatch in closeMatches) {
              if (closeMatch.start > openPos) closesAfter++;
            }
            
            // If there are more or equal opens after this position than closes,
            // this opening tag is orphaned
            if (opensAfter >= closesAfter) {
              // Remove this opening tag
              cleaned = cleaned.substring(0, openMatches[i].start) + 
                       cleaned.substring(openMatches[i].end);
              break; // Restart with updated string
            }
          }
        }
        
        // Handle orphaned closing tags (more closes than opens)
        if (closeMatches.length > openMatches.length) {
          // Find the first orphaned closing tag (one without a matching open)
          for (int i = 0; i < closeMatches.length; i++) {
            final closePos = closeMatches[i].start;
            
            // Count how many opens and closes exist before this position
            int opensBefore = 0;
            int closesBefore = 0;
            
            for (final openMatch in openMatches) {
              if (openMatch.start < closePos) opensBefore++;
            }
            
            for (int j = 0; j < i; j++) {
              if (closeMatches[j].start < closePos) closesBefore++;
            }
            
            // If there are more or equal closes before this position than opens,
            // this closing tag is orphaned
            if (closesBefore >= opensBefore) {
              // Remove this closing tag
              cleaned = cleaned.substring(0, closeMatches[i].start) + 
                       cleaned.substring(closeMatches[i].end);
              break; // Restart with updated string
            }
          }
        }
        
        changed = cleaned.length != beforeLength;
      }
    }
    
    return cleaned;
  }

  // Parse tokenized text into styled TextSpans with support for nested formatting and links
  List<InlineSpan> _parseStyledSpans(String source) {
    final List<InlineSpan> spans = [];
    
    // First parse links separately as they can contain other formatting
    final linkRegex = RegExp(r'\[LINK:([^\]]+)\](.*?)\[/LINK\]', dotAll: true, caseSensitive: false);
    final linkMatches = linkRegex.allMatches(source);
    
    if (linkMatches.isEmpty) {
      // No links, process normally
      return _parseFormattingSpans(source);
    }
    
    int lastIndex = 0;
    for (final linkMatch in linkMatches) {
      // Add text before the link
      if (linkMatch.start > lastIndex) {
        final beforeText = source.substring(lastIndex, linkMatch.start);
        spans.addAll(_parseFormattingSpans(beforeText));
      }
      
      // Add the link
      final url = linkMatch.group(1) ?? '';
      final linkText = linkMatch.group(2) ?? '';
      
      // Parse any formatting within the link text
      final linkSpans = _parseFormattingSpans(linkText);
      
      // Wrap link spans with tap recognizer
      for (final span in linkSpans) {
        if (span is TextSpan) {
          spans.add(TextSpan(
            text: span.text,
            style: (span.style ?? const TextStyle()).copyWith(
              color: Colors.blue,
              decoration: TextDecoration.underline,
            ),
            recognizer: TapGestureRecognizer()
              ..onTap = () => _handleLinkTap(url),
            children: span.children,
          ));
        } else {
          spans.add(span);
        }
      }
      
      lastIndex = linkMatch.end;
    }
    
    // Add remaining text
    if (lastIndex < source.length) {
      final remaining = source.substring(lastIndex);
      spans.addAll(_parseFormattingSpans(remaining));
    }
    
    return spans;
  }
  
  // Parse formatting tokens (headings, bold, italic, etc.) - extracted from _parseStyledSpans
  List<InlineSpan> _parseFormattingSpans(String source) {
    return _parseFormattingSpansSafe(source, 0);
  }

  // Helper to prevent infinite recursion
  List<InlineSpan> _parseFormattingSpansSafe(String source, int depth) {
    const int maxDepth = 20;
    if (depth > maxDepth) {
      // Prevent stack overflow
      return [TextSpan(text: source)];
    }
    if (source.isEmpty) {
      return [];
    }
    final List<InlineSpan> spans = [];
    final tokenRegex = RegExp(
      r'\[(H[1-6]|B|I|U|Q)\](.*?)\[/\1\]',
      dotAll: true,
      caseSensitive: false,
    );

    int lastIndex = 0;

    for (final match in tokenRegex.allMatches(source)) {
      if (match.start > lastIndex) {
        final plain = source.substring(lastIndex, match.start);
        // Don't trim plain text to preserve spacing and newlines
        if (plain.isNotEmpty && plain != source) {
          spans.addAll(_parseFormattingSpansSafe(plain, depth + 1));
        } else if (plain.isNotEmpty) {
          spans.add(TextSpan(text: plain));
        }
      }

      final tag = match.group(1)!.toUpperCase();
      String inner = (match.group(2) ?? '');

      // Recursively parse inner content for nested tokens
      List<InlineSpan> innerSpans;
      if (inner.isNotEmpty && inner != source) {
        innerSpans = _parseFormattingSpansSafe(inner, depth + 1);
      } else if (inner.isNotEmpty) {
        innerSpans = [TextSpan(text: inner)];
      } else {
        innerSpans = [];
      }

      if (tag.startsWith('H')) {
        final level = int.parse(tag.substring(1));
        double fontSize;
        switch (level) {
          case 1:
            fontSize = 28;
            break;
          case 2:
            fontSize = 24;
            break;
          case 3:
            fontSize = 21;
            break;
          case 4:
            fontSize = 19;
            break;
          case 5:
            fontSize = 17;
            break;
          default:
            fontSize = 16;
        }
        
        spans.add(TextSpan(
          text: '\n', // Add newline before heading for spacing
        ));
        spans.add(TextSpan(
          children: innerSpans,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
            height: 1.4,
            letterSpacing: 0.2,
          ),
        ));
        spans.add(TextSpan(
          text: '\n\n', // Add double newline after heading for spacing
        ));
      } else if (tag == 'Q') {
        spans.add(TextSpan(
          children: innerSpans,
          style: const TextStyle(
            fontStyle: FontStyle.italic, 
            color: Colors.black54,
            fontSize: 15,
          ),
        ));
      } else if (tag == 'B') {
        spans.add(TextSpan(
          children: innerSpans,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ));
      } else if (tag == 'I') {
        spans.add(TextSpan(
          children: innerSpans,
          style: const TextStyle(fontStyle: FontStyle.italic),
        ));
      } else if (tag == 'U') {
        spans.add(TextSpan(
          children: innerSpans,
          style: const TextStyle(decoration: TextDecoration.underline),
        ));
      } else {
        spans.add(TextSpan(children: innerSpans));
      }

      lastIndex = match.end;
    }

    // Add any remaining text after last token
    if (lastIndex < source.length) {
      final plain = source.substring(lastIndex);
      // Don't trim to preserve spacing and newlines
      if (plain.isNotEmpty && plain != source) {
        spans.addAll(_parseFormattingSpansSafe(plain, depth + 1));
      } else if (plain.isNotEmpty) {
        spans.add(TextSpan(text: plain));
      }
    }

    return spans;
  }
  
  // Handle link taps
  Future<void> _handleLinkTap(String url) async {
    try {
      // Clean up the URL
      String cleanUrl = url.trim();
      
      // If it's a relative URL or anchor, show a message
      if (cleanUrl.startsWith('#') || cleanUrl.startsWith('/') || !cleanUrl.contains('://')) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Internal link: $cleanUrl'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
        return;
      }
      
      // Try to launch the URL
      final uri = Uri.parse(cleanUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Could not open link: $cleanUrl'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      print('Error opening link: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening link: $url'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  // Build image widget from EPUB image data with flexible dimensions
  Widget _buildImageWidget(String imageSrc, {String? width, String? height}) {
    // Clean up the image source path
    String cleanImageSrc = imageSrc;
    
    // Handle different path formats
    if (cleanImageSrc.startsWith('../')) {
      cleanImageSrc = cleanImageSrc.substring(3);
    }
    if (cleanImageSrc.startsWith('./')) {
      cleanImageSrc = cleanImageSrc.substring(2);
    }
    
    print('Looking for image: "$cleanImageSrc"');
    
    // Try to find the image in our extracted images
    Uint8List? imageData;
    
    // Try exact match first
    if (_images.containsKey(cleanImageSrc)) {
      imageData = _images[cleanImageSrc];
      print('Found image with exact match: $cleanImageSrc');
    } else {
      // Try to find by filename only
      final fileName = cleanImageSrc.split('/').last;
      print('Trying filename match: $fileName');
      
      if (_images.containsKey(fileName)) {
        imageData = _images[fileName];
        print('Found image with filename match: $fileName');
      } else {
        // Try partial match (case-insensitive)
        for (var entry in _images.entries) {
          if (entry.key.toLowerCase().endsWith(fileName.toLowerCase())) {
            imageData = entry.value;
            print('Found image with partial match: ${entry.key}');
            break;
          }
        }
      }
      
      if (imageData == null) {
        print('Image not found. Available images: ${_images.keys.toList()}');
      }
    }
    
    if (imageData != null) {
      // Parse dimensions
      double? imgWidth = width != null ? double.tryParse(width) : null;
      double? imgHeight = height != null ? double.tryParse(height) : null;
      
      // Determine if this is a full-page image (large dimensions or no constraints)
      final contextSize = MediaQuery.of(context).size;
      final maxWidth = contextSize.width - 32; // Account for padding
      
      // If no dimensions specified, or if dimensions suggest full-page, make it flexible
      bool isLargeImage = false;
      if (imgHeight == null && imgWidth == null) {
        // No dimensions - let image determine its size up to max
        isLargeImage = true;
      } else if (imgHeight != null && imgHeight > 300) {
        // Large height specified
        isLargeImage = true;
      } else if (imgWidth != null && imgWidth > maxWidth * 0.8) {
        // Large width specified
        isLargeImage = true;
      }
      
      // Default to reasonable size if not specified
      if (imgHeight == null && !isLargeImage) {
        imgHeight = 120; // Default thumbnail size
      }
      
      return ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: maxWidth,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.memory(
            imageData,
            fit: BoxFit.fitWidth,
            errorBuilder: (context, error, stackTrace) {
              return _buildImagePlaceholder('Image load error: $cleanImageSrc', true);
            },
          ),
        ),
      );
    } else {
      // Image not found - show placeholder
      return _buildImagePlaceholder('Image not found: $cleanImageSrc', false);
    }
  }

  // Helper method to build image placeholder with fixed dimensions
  Widget _buildImagePlaceholder(String message, bool isError) {
    return Container(
      height: 120, // Fixed height consistent with images
      width: double.infinity,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
        color: Colors.grey.shade50,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isError ? Icons.broken_image : Icons.image_not_supported, 
            color: Colors.grey.shade400, 
            size: 24,
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(
              message,
              style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // Simple pagination for very large texts - word-level breaking
  List<String> _simpleTextPagination(String text) {
    const int charsPerPage = 1800; // Increased for better page filling
    final List<String> pages = [];
    
    int startIndex = 0;
    
    while (startIndex < text.length) {
      int endIndex = startIndex + charsPerPage;
      
      // If we're not at the end, find a good breaking point
      if (endIndex < text.length) {
        // Try to break at paragraph boundary (double newline)
        int paragraphBreak = text.lastIndexOf('\n\n', endIndex);
        if (paragraphBreak > startIndex && paragraphBreak > endIndex - 500) {
          endIndex = paragraphBreak + 2; // Include the newlines
        } else {
          // Try to break at a sentence boundary
          int sentenceBreak = text.lastIndexOf(RegExp(r'[.!?]\s'), endIndex);
          if (sentenceBreak > startIndex && sentenceBreak > endIndex - 300) {
            endIndex = sentenceBreak + 2;
          } else {
            // Try to break at a word boundary
            int wordBreak = text.lastIndexOf(RegExp(r'\s'), endIndex);
            if (wordBreak > startIndex && wordBreak > endIndex - 100) {
              endIndex = wordBreak + 1;
            }
          }
        }
      } else {
        endIndex = text.length;
      }
      
      if (startIndex < endIndex) {
        pages.add(text.substring(startIndex, endIndex));
      }
      
      startIndex = endIndex;
    }
    
    print('Simple character-based pagination complete! Generated ${pages.length} pages');
    return pages;
  }

  Future<void> _saveProgress(int page) async {
    try {
      // Save to database if user is logged in
      final mobileNumber = await SimpleSessionService.getUserPhone();
      if (mobileNumber != null && mobileNumber.isNotEmpty) {
        print('Saving EPUB progress to database: page ${page + 1} for book ${widget.bookId}');
        
        final progressController = ReadingProgressController();
        await progressController.updateProgress(
          mobileNumber: mobileNumber,
          readingsId: widget.bookId,
          currentPage: page + 1, // Convert 0-based page to 1-based page
          lastReadAt: DateTime.now(),
        );
        
        print('EPUB progress saved to database successfully');
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Progress saved!'), duration: Duration(seconds: 1)),
          );
        }
      } else {
        print('No mobile number found, cannot save progress');
      }
    } catch (e) {
      print('Error saving EPUB progress: $e');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to save progress'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _markAsCompleted() async {
    try {
      final mobileNumber = await SimpleSessionService.getUserPhone();
      if (mobileNumber != null && mobileNumber.isNotEmpty) {
        print('Marking EPUB reading as completed for book ${widget.bookId}');
        
        final progressController = ReadingProgressController();
        await progressController.updateProgress(
          mobileNumber: mobileNumber,
          readingsId: widget.bookId,
          currentPage: _pages.length, // Set to total pages
          lastReadAt: DateTime.now(),
          completedAt: DateTime.now(), // Mark as completed
        );
        
        print('EPUB reading marked as completed successfully');
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('🎉 Congratulations! You have completed this book!'),
              duration: Duration(seconds: 3),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      print('Error marking EPUB reading as completed: $e');
    }
  }

  Future<void> _handleCompleteReading() async {
    // First mark as completed
    await _markAsCompleted();
    
    // Navigate to ReadingCompletionScreen
    if (mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => reading_screen.ReadingCompletionScreen(
            bookId: widget.bookId,
            currentPage: _currentPage + 1,
            totalPages: _pages.length,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_pageController == null || _pages.isEmpty) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final progressPercent = _pages.isNotEmpty ? (_currentPage + 1) / _pages.length : 0.0;

    return Scaffold(
      appBar: _showChrome
          ? BookReaderAppBar(
              title: _bookTitle,
              onBackPressed: () async {
                await _saveProgress(_currentPage);
                final isCompleted = _currentPage >= _pages.length - 1;
                if (mounted) Navigator.of(context).pop(isCompleted);
              },
            )
          : const MinimalAppBar(),
      body: Column(
        children: [
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () {
                setState(() => _showChrome = !_showChrome);
              },
              child: SafeArea(
                top: false,
                bottom: false,
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: (index) {
                    setState(() => _currentPage = index);
                    _progressSaveTimer?.cancel();
                    _progressSaveTimer = Timer(const Duration(seconds: 2), () {
                      _saveProgress(_currentPage);
                      if (_currentPage >= _pages.length - 1) {
                        _markAsCompleted();
                      }
                    });
                  },
                  itemCount: _pages.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 16.0, bottom: 0.0),
                      child: _buildPageContent(_pages[index]),
                    );
                  },
                ),
              ),
            ),
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: _showChrome
                ? PageStatusFooter(
                    key: const ValueKey('pageStatusFooter'),
                    currentPage: _currentPage + 1,
                    totalPages: _pages.length,
                    progressPercent: progressPercent,
                    onCompleteReading: _handleCompleteReading,
                  )
                : MinimalFooter(
                    key: const ValueKey('minimalFooter'),
                    progressPercent: progressPercent,
                  ),
          ),
        ],
      ),
    );
  }
}
