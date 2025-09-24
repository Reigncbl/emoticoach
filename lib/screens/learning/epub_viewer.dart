import 'dart:typed_data';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:epubx/epubx.dart' as epubx;
import 'package:shared_preferences/shared_preferences.dart';
import '../../controllers/reading_content_controller.dart';
import '../../services/session_service.dart';
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
      
      // Get saved progress from local storage
      final prefs = await SharedPreferences.getInstance();
      int savedPage = prefs.getInt("progress_${widget.bookId}") ?? 0;
      
      // Try to get progress from database as well
      try {
        final mobileNumber = await SimpleSessionService.getUserPhone();
        if (mobileNumber != null && mobileNumber.isNotEmpty) {
          print('Fetching EPUB progress from database for book ${widget.bookId}');
          
          final progressController = ReadingProgressController();
          final progress = await progressController.fetchProgress(mobileNumber, widget.bookId);
          
          if (progress != null && progress.currentPage != null && progress.currentPage! > 0) {
            final dbPage = progress.currentPage! - 1; // Convert 1-based page to 0-based page
            print('Database progress: page ${dbPage + 1}, Local progress: page ${savedPage + 1}');
            
            // Use the higher progress value
            savedPage = savedPage > dbPage ? savedPage : dbPage;
            print('Using progress: page ${savedPage + 1}');
          } else {
            print('No progress found in database, using local progress: page ${savedPage + 1}');
          }
        }
      } catch (e) {
        print('Error fetching progress from database: $e, using local progress');
      }

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
      
      // Store total pages for progress calculation
      await prefs.setInt("total_pages_${widget.bookId}", pages.length);
      
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
  
  final availableHeight = screenHeight -
      kToolbarHeight - // app bar
      statusBarHeight - // status bar
      bottomSafeArea - // bottom safe area
      32.0; // single padding margin instead of double (cleaner)

  final availableWidth = screenWidth - 32.0; // Account for horizontal padding

  print('Available space: ${availableWidth.toInt()}x${availableHeight.toInt()}');

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
  
  // Split text into words for proper flow
  final words = text.split(RegExp(r'\s+'));
  
  int wordIndex = 0;
  int pageCount = 0;

  while (wordIndex < words.length) {
    pageCount++;
    if (pageCount % 10 == 0) {
      print('Processing page $pageCount...');
    }

    List<String> currentPageWords = [];
    double usedHeight = 0.0;

    // Try to fit as many words as possible on this page
    while (wordIndex < words.length) {
      final word = words[wordIndex].trim();
      if (word.isEmpty) {
        wordIndex++;
        continue;
      }

      // Create test text with the new word
      List<String> testWords = [...currentPageWords, word];
      String testText = testWords.join(' ');

      // Detect images
  final imageMatches = RegExp(r'\[IMAGE:(\d+)?\]').allMatches(testText);

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

      // Add image heights (support variable height like [IMAGE:200])
      for (final match in imageMatches) {
        final heightGroup = match.group(1);
        final imgHeight = heightGroup != null ? double.tryParse(heightGroup) ?? defaultImageHeight : defaultImageHeight;
        testHeight += imgHeight + imageMargin;
      }

      // Check if adding this word would exceed available height
      if (testHeight <= availableHeight) {
        // It fits! Add the word
        currentPageWords.add(word);
        usedHeight = testHeight;
        wordIndex++;
      } else {
        // It doesn't fit, break here
        break;
      }
    }

    // If we couldn't fit anything on this page, force at least one word
    if (currentPageWords.isEmpty && wordIndex < words.length) {
      currentPageWords.add(words[wordIndex]);
      wordIndex++;
      print('Warning: Forced single word on page $pageCount');
    }

    // Create the page content
    if (currentPageWords.isNotEmpty) {
      final pageText = currentPageWords.join(' ');
      pages.add(pageText);
      
      // Calculate fill percentage for logging
      final fillPercentage = (usedHeight / availableHeight * 100).toInt();
      print('Page $pageCount: ${currentPageWords.length} words, ${pageText.length} chars, ${usedHeight.toInt()}px/${availableHeight.toInt()}px (${fillPercentage}% full)');
    }
  }

  return pages;
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
            _images[imageKey] = Uint8List.fromList(imageFile.Content!);
            print('Extracted image: $imageKey (${imageFile.Content!.length} bytes)');
          }
        } catch (e) {
          print('Error extracting image ${imageEntry.key}: $e');
        }
      }
    }
    
    print('Total images extracted: ${_images.length}');
  }

  // Process HTML content to preserve images but clean other tags
  String _processHtmlContent(String html) {
    String processedText = html;

    // 1. Images -> markers
    final imgTagRegex = RegExp(r'<img[^>]*>', caseSensitive: false);
    processedText = processedText.replaceAllMapped(imgTagRegex, (match) {
      final tag = match.group(0) ?? '';
      String src = '';
      final srcMatch1 = RegExp(r'src="([^"]*)"', caseSensitive: false).firstMatch(tag);
      final srcMatch2 = RegExp(r"src='([^']*)'", caseSensitive: false).firstMatch(tag);
      if (srcMatch1 != null) {
        src = srcMatch1.group(1) ?? '';
      } else if (srcMatch2 != null) {
        src = srcMatch2.group(1) ?? '';
      }
      return src.isNotEmpty ? '\n[IMAGE:$src]\n' : '';
    });

    // 2. Normalize line breaks for block elements BEFORE tokenizing styles
    // Paragraphs -> ensure an empty line AFTER each paragraph for spacing
    processedText = processedText.replaceAll(RegExp(r'<p[^>]*>', caseSensitive: false), '\n');
    processedText = processedText.replaceAll(RegExp(r'</p>', caseSensitive: false), '\n\n');
    // Line breaks
    processedText = processedText.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n');

    // 3. Process headings FIRST to handle nested inline tags properly
    for (int level = 1; level <= 6; level++) {
      final headingRegex = RegExp('<h$level[^>]*>(.*?)</h$level>', caseSensitive: false, dotAll: true);
      processedText = processedText.replaceAllMapped(headingRegex, (m) {
        String inner = m.group(1) ?? '';
        
        // Debug: Log heading processing
        if (inner.toLowerCase().contains('chapter')) {
          print('Processing H$level heading: "$inner"');
        }
        
        // Process inline styles within headings before converting to heading tokens
        inner = _processInlineStyles(inner);
        
        if (inner.toLowerCase().contains('chapter')) {
          print('After inline styles: "$inner"');
        }
        
        final result = '\n[H$level]${inner.trim()}[/H$level]\n';
        
        if (inner.toLowerCase().contains('chapter')) {
          print('Final heading token: "$result"');
        }
        
        return result;
      });
    }

    // 4. Blockquotes (process inline styles within blockquotes)
    processedText = processedText.replaceAllMapped(
      RegExp(r'<blockquote[^>]*>(.*?)</blockquote>', caseSensitive: false, dotAll: true),
      (m) {
        String inner = m.group(1) ?? '';
        inner = _processInlineStyles(inner);
        return '\n[Q]${inner.trim()}[/Q]\n';
      },
    );

    // 5. Lists: unordered and ordered. Convert <li> to bullet lines.
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

    // 6. Process remaining inline styles
    processedText = _processInlineStyles(processedText);

    // 7. Strip remaining tags
    processedText = processedText.replaceAll(RegExp(r'<[^>]*>'), '');

    // 8. Cleanup special paths / noise and HTML entities
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

    // 9. Clean up duplicate heading tokens and malformed structures
    processedText = _cleanupDuplicateTokens(processedText);

    // 10. Promote inline "Chapter X" occurrences to headings ONLY if not already in headings
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
    
    // Process inline styles -> tokens
    processed = processed
      .replaceAllMapped(RegExp(r'<(strong|b)[^>]*>(.*?)</(strong|b)>', caseSensitive: false, dotAll: true), (match) => '[B]${match.group(2)}[/B]')
      .replaceAllMapped(RegExp(r'<(em|i)[^>]*>(.*?)</(em|i)>', caseSensitive: false, dotAll: true), (match) => '[I]${match.group(2)}[/I]')
      .replaceAllMapped(RegExp(r'<u[^>]*>(.*?)</u>', caseSensitive: false, dotAll: true), (match) => '[U]${match.group(1)}[/U]');
    
    return processed;
  }

  // Clean up duplicate tokens and malformed structures
  String _cleanupDuplicateTokens(String text) {
    String cleaned = text;
    
    // Debug: Check for problematic patterns
    if (text.contains('[H2][H2]') || text.contains('Chapter')) {
      print('Before duplicate cleanup: ${text.substring(0, 200)}...');
    }
    
    // Remove duplicate consecutive heading tokens like [H2][H2] -> [H2]
    cleaned = cleaned.replaceAllMapped(RegExp(r'\[H([1-6])\]\[H[1-6]\]', caseSensitive: false), (match) {
      print('Found duplicate heading tokens: ${match.group(0)} -> [H${match.group(1)}]');
      return '[H${match.group(1)}]';
    });
    
    // Remove duplicate consecutive heading closing tokens like [/H2][/H2] -> [/H2]
    cleaned = cleaned.replaceAllMapped(RegExp(r'\[/H([1-6])\]\[/H[1-6]\]', caseSensitive: false), (match) {
      print('Found duplicate closing tokens: ${match.group(0)} -> [/H${match.group(1)}]');
      return '[/H${match.group(1)}]';
    });
    
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
    
    // Debug: Check result
    if (text.contains('[H2][H2]') || text.contains('Chapter')) {
      print('After duplicate cleanup: ${cleaned.substring(0, 200)}...');
    }
    
    return cleaned;
  }

  // Build page content with text and images - optimized for natural flow
  Widget _buildPageContent(String pageText) {
    final List<Widget> contentWidgets = [];

    // Split text by image markers and process each part
    final imagePlaceholderRegex = RegExp(r'\[IMAGE:([^\]]*)\]');
    final matches = imagePlaceholderRegex.allMatches(pageText);

    int lastIndex = 0;

    for (final match in matches) {
      // Add text before the image
      if (match.start > lastIndex) {
        final textPart = pageText.substring(lastIndex, match.start).trim();
        if (textPart.isNotEmpty) {
          contentWidgets.add(_buildTextWidget(textPart));
        }
      }

      // Add the image
      final imageSrc = match.group(1) ?? '';
      if (imageSrc.isNotEmpty) {
        contentWidgets.add(_buildImageWidget(imageSrc));
      }

      lastIndex = match.end;
    }

    // Add remaining text after the last image
    if (lastIndex < pageText.length) {
      final textPart = pageText.substring(lastIndex).trim();
      if (textPart.isNotEmpty) {
        contentWidgets.add(_buildTextWidget(textPart));
      }
    }

    // If no images were found, just add the text
    if (contentWidgets.isEmpty) {
      contentWidgets.add(_buildTextWidget(pageText));
    }

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
      (m) => '[/H${m.group(1)}]\n'
    );

    // Fast exit if no (case-insensitive) tokens present
    if (!RegExp(r'\[(?:H[1-6]|B|I|U|Q)\]', caseSensitive: false).hasMatch(working)) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 4.0),
        child: Text(
          working.replaceAll(RegExp(r'\[(?:h[1-6]|b|i|u|q)\]', caseSensitive: false), ''),
          style: const TextStyle(
            fontSize: 16,
            height: 1.5,
            color: Colors.black87,
            letterSpacing: 0.1,
          ),
          textAlign: TextAlign.justify,
          softWrap: true,
        ),
      );
    }

    final spans = _parseStyledSpans(working);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: RichText(
        text: TextSpan(style: const TextStyle(fontSize: 16, height: 1.5, color: Colors.black87, letterSpacing: 0.1), children: spans),
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

    // Fix a specific previously introduced malformed pattern [[H2]/B] -> [/B][/H2]
    working = working.replaceAllMapped(
      RegExp(r'\[\[H([1-6])\]/B\]', caseSensitive: false),
      (m) => '[/B][/H${m.group(1)}]',
    );

    // Do NOT attempt to reshuffle sequences like [B]text[/B][/H2]; only patch if the
    // opening heading is clearly missing (start of line or preceded by newline) to avoid duplication.
    working = working.replaceAllMapped(
      RegExp(r'(?<!\[H[1-6]\])(?<=^|\n)\[B\](.*?)\[/B\]\[/H([1-6])\]', caseSensitive: false, dotAll: true),
      (m) => '[H${m.group(2)}][B]${m.group(1)}[/B][/H${m.group(2)}]',
    );

    return working;
  }

  // Parse tokenized text into styled TextSpans with support for nested formatting
  List<InlineSpan> _parseStyledSpans(String source) {
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
        if (plain.trim().isNotEmpty) {
          spans.add(TextSpan(text: plain));
        }
      }

      final tag = match.group(1)!.toUpperCase();
      String inner = (match.group(2) ?? '').trim();

      // Handle block-level tags (headings and blockquotes)
      if (tag.startsWith('H')) {
        spans.add(WidgetSpan(
          alignment: PlaceholderAlignment.baseline,
          baseline: TextBaseline.alphabetic,
          child: Container(
            width: double.infinity,
            margin: EdgeInsets.only(
              top: tag == 'H1' ? 24.0 : (tag == 'H2' ? 20.0 : 16.0),
              bottom: tag == 'H1' ? 16.0 : (tag == 'H2' ? 12.0 : 8.0),
            ),
            child: RichText(
              text: TextSpan(
                style: _getHeadingStyle(tag),
                children: _parseNestedSpans(inner, _getHeadingStyle(tag)),
              ),
              textAlign: TextAlign.left,
            ),
          ),
        ));
      } else if (tag == 'Q') {
        spans.add(WidgetSpan(
          alignment: PlaceholderAlignment.baseline,
          baseline: TextBaseline.alphabetic,
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 8.0),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              border: Border(left: BorderSide(color: Colors.grey.shade400, width: 4)),
              color: Colors.grey.shade100,
            ),
            child: RichText(
              text: TextSpan(
                style: const TextStyle(fontSize: 15, height: 1.4, fontStyle: FontStyle.italic, color: Colors.black87),
                children: _parseNestedSpans(inner, const TextStyle(fontSize: 15, height: 1.4, fontStyle: FontStyle.italic, color: Colors.black87)),
              ),
            ),
          ),
        ));
      } else {
        // Inline styles - recursively parse nested formatting
        final baseStyle = _getInlineStyle(tag);
        final nestedSpans = _parseNestedSpans(inner, baseStyle);
        
        if (nestedSpans.length == 1 && nestedSpans.first is TextSpan) {
          // Simple case - just text with style
          final textSpan = nestedSpans.first as TextSpan;
          spans.add(TextSpan(
            text: textSpan.text,
            style: baseStyle.merge(textSpan.style),
          ));
        } else {
          // Complex case - has nested formatting
          spans.addAll(nestedSpans.map((span) {
            if (span is TextSpan) {
              return TextSpan(
                text: span.text,
                style: baseStyle.merge(span.style),
                children: span.children,
              );
            }
            return span;
          }));
        }
      }

      lastIndex = match.end;
    }

    // Add trailing text
    if (lastIndex < source.length) {
      final tail = source.substring(lastIndex);
      if (tail.trim().isNotEmpty) {
        spans.add(TextSpan(text: tail));
      }
    }

    return spans;
  }

  // Parse nested formatting within a span
  List<InlineSpan> _parseNestedSpans(String text, TextStyle baseStyle) {
    final List<InlineSpan> spans = [];
    final nestedRegex = RegExp(r'\[(B|I|U)\](.*?)\[/\1\]', caseSensitive: false, dotAll: true);
    
    int lastIndex = 0;
    
    for (final match in nestedRegex.allMatches(text)) {
      // Add text before the nested tag
      if (match.start > lastIndex) {
        final plainText = text.substring(lastIndex, match.start);
        if (plainText.trim().isNotEmpty) {
          spans.add(TextSpan(text: plainText, style: baseStyle));
        }
      }
      
      // Add the nested formatted text
      final nestedTag = match.group(1)!.toUpperCase();
      final nestedContent = match.group(2) ?? '';
      final nestedStyle = _getInlineStyle(nestedTag);
      
      // Recursively handle further nesting
      final furtherNested = _parseNestedSpans(nestedContent, baseStyle.merge(nestedStyle));
      spans.addAll(furtherNested);
      
      lastIndex = match.end;
    }
    
    // Add remaining text
    if (lastIndex < text.length) {
      final remainingText = text.substring(lastIndex);
      if (remainingText.trim().isNotEmpty) {
        spans.add(TextSpan(text: remainingText, style: baseStyle));
      }
    }
    
    // If no nested formatting was found, return the original text
    if (spans.isEmpty) {
      spans.add(TextSpan(text: text, style: baseStyle));
    }
    
    return spans;
  }

  // Get heading style based on level
  TextStyle _getHeadingStyle(String tag) {
    const baseStyle = TextStyle(color: Colors.black87);
    
    switch (tag) {
      case 'H1': return baseStyle.copyWith(fontSize: 26, fontWeight: FontWeight.bold, height: 1.25);
      case 'H2': return baseStyle.copyWith(fontSize: 22, fontWeight: FontWeight.bold, height: 1.3, letterSpacing: 0.5);
      case 'H3': return baseStyle.copyWith(fontSize: 20, fontWeight: FontWeight.w600, height: 1.35);
      case 'H4': return baseStyle.copyWith(fontSize: 18, fontWeight: FontWeight.w600, height: 1.4);
      case 'H5': return baseStyle.copyWith(fontSize: 16, fontWeight: FontWeight.bold, height: 1.4);
      case 'H6': return baseStyle.copyWith(fontSize: 16, fontStyle: FontStyle.italic, height: 1.4);
      default: return baseStyle;
    }
  }

  // Get inline style based on tag
  TextStyle _getInlineStyle(String tag) {
    const baseStyle = TextStyle(color: Colors.black87);
    
    switch (tag) {
      case 'B': return baseStyle.copyWith(fontWeight: FontWeight.bold);
      case 'I': return baseStyle.copyWith(fontStyle: FontStyle.italic);
      case 'U': return baseStyle.copyWith(decoration: TextDecoration.underline);
      default: return baseStyle;
    }
  }

  // Build image widget from EPUB image data with fixed dimensions
  Widget _buildImageWidget(String imageSrc) {
    // Clean up the image source path
    String cleanImageSrc = imageSrc;
    
    // Handle different path formats
    if (cleanImageSrc.startsWith('../')) {
      cleanImageSrc = cleanImageSrc.substring(3);
    }
    if (cleanImageSrc.startsWith('./')) {
      cleanImageSrc = cleanImageSrc.substring(2);
    }
    
    // Try to find the image in our extracted images
    Uint8List? imageData;
    
    // Try exact match first
    if (_images.containsKey(cleanImageSrc)) {
      imageData = _images[cleanImageSrc];
    } else {
      // Try to find by filename only
      final fileName = cleanImageSrc.split('/').last;
      for (var entry in _images.entries) {
        if (entry.key.endsWith(fileName)) {
          imageData = entry.value;
          break;
        }
      }
    }
    
    if (imageData != null) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 8.0),
        height: 120, // Fixed height for consistent layout calculation
        width: double.infinity,
        child: Center(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.memory(
              imageData,
              height: 120,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return _buildImagePlaceholder('Image load error: $cleanImageSrc', true);
              },
            ),
          ),
        ),
      );
    } else {
      // Image not found - show placeholder with same dimensions
      return _buildImagePlaceholder('Image not found: $cleanImageSrc', false);
    }
  }

  // Helper method to build image placeholder with fixed dimensions
  Widget _buildImagePlaceholder(String message, bool isError) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
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
    
    // Split into words for better flow
    final words = text.split(RegExp(r'\s+'));
    int wordIndex = 0;
    
    while (wordIndex < words.length) {
      List<String> currentPageWords = [];
      int currentLength = 0;
      
      // Add words until we reach the character limit
      while (wordIndex < words.length && 
             currentLength + words[wordIndex].length + 1 <= charsPerPage) {
        if (currentPageWords.isNotEmpty) {
          currentLength += 1; // Space character
        }
        currentPageWords.add(words[wordIndex]);
        currentLength += words[wordIndex].length;
        wordIndex++;
      }
      
      // If we couldn't fit any words (very long word), force at least one
      if (currentPageWords.isEmpty && wordIndex < words.length) {
        currentPageWords.add(words[wordIndex]);
        wordIndex++;
      }
      
      if (currentPageWords.isNotEmpty) {
        pages.add(currentPageWords.join(' '));
      }
    }
    
    print('Simple word-level pagination complete! Generated ${pages.length} pages');
    return pages;
  }

  Future<void> _saveProgress(int page) async {
    try {
      // Save to SharedPreferences for local storage
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt("progress_${widget.bookId}", page);
      
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
      } else {
        print('No mobile number found, only saving progress locally');
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Progress saved!'), duration: Duration(seconds: 1)),
        );
      }
    } catch (e) {
      print('Error saving EPUB progress: $e');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Progress saved locally, but failed to sync to server'),
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
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
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
