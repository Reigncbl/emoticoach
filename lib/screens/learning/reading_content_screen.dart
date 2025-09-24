import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:emoticoach/utils/colors.dart';
import 'package:emoticoach/controllers/reading_content_controller.dart'; // Reading Content Controller
import 'package:emoticoach/models/reading_model.dart'; // Reading Model
import 'package:emoticoach/services/session_service.dart'; // Session Service
import 'package:visibility_detector/visibility_detector.dart';
import 'package:emoticoach/utils/api_service.dart'; // API Service to fetch reading info
import 'epub_viewer.dart'; // EPUB Viewer

// === MAIN SCREEN ===
class ReadingContentScreen extends StatefulWidget {
  final String? bookId;
  final String? chapterId; // Changed from pageId to chapterId (kept for backward compatibility)
  final int? startingPage; // New parameter to specify which page to start from
  

  const ReadingContentScreen({super.key, this.bookId, this.chapterId, this.startingPage});

  @override
  State<ReadingContentScreen> createState() => _ReadingContentScreenState();
}

class _ReadingContentScreenState extends State<ReadingContentScreen> {
  String? _lastValidChapter;
  final ScrollController _scrollController = ScrollController();
  
  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  bool _minimalMode = false;
  late int _currentPage;
  late Future<ChapterPage> _chapterDataFuture;
  
  int _totalPages = 1; // Will be loaded from API
  final ReadingContentController controller = ReadingContentController();
  final ReadingProgressController _progressController = ReadingProgressController();
  
  String _chapterTitle = "";
  ChapterPage? _currentChapterData;

  // Helper to load epub bytes from assets (local file)
  Future<List<int>> _loadEpubBytes(String assetPath) async {
    try {
      print('Attempting to load EPUB from path: $assetPath');
      
      // Use rootBundle to load asset as bytes
      final byteData = await DefaultAssetBundle.of(context).load(assetPath);
      final bytes = byteData.buffer.asUint8List();
      
      print('Successfully loaded EPUB file. Size: ${bytes.length} bytes');
      return bytes;
    } catch (e) {
      print('Error loading EPUB asset: $e');
      throw Exception('Failed to load EPUB file: $e');
    }
  }

  // Check if this reading has an EPUB file and redirect to EPUB viewer
  Future<void> _checkForEpubAndRedirect() async {
    try {
      final bookId = widget.bookId ?? 'R-00002';
      print('Checking for EPUB file for book: $bookId');

      // Create API service to fetch reading info
      final apiService = APIService();
      
      // Fetch all readings and find the one with matching ID
      final readings = await apiService.fetchAllReadings();
      final reading = readings.firstWhere(
        (r) => r.id == bookId,
        orElse: () => readings.first, // fallback to first reading
      );
      
      print('Found reading: ${reading.title}');
      print('EPUB file path: ${reading.epubFilePath}');
      
      // Check if this reading has an EPUB file
      if (reading.hasEpubFile) {
        print('Reading has EPUB file: ${reading.epubFilePath}');
        
        // Load EPUB bytes and redirect to EPUB viewer
        try {
          final bytes = await _loadEpubBytes(reading.epubFilePath!);
          
          if (mounted) {
            // Navigate to EPUB viewer instead of regular content
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => EpubViewer(
                  epubBytes: bytes,
                  bookId: bookId,
                ),
              ),
            );
            return;
          }
        } catch (e) {
          print('Failed to load EPUB file from ${reading.epubFilePath}: $e');
          // Continue with regular content view
        }
      } else {
        print('Reading does not have an EPUB file, using regular content view');
      }
    } catch (e) {
      print('Error checking for EPUB file: $e');
      // Continue with regular content view
    }
  }

  @override
  void initState() {
    super.initState();
    
    // Check if this reading has an EPUB file and redirect if needed
    _checkForEpubAndRedirect();
    
    // Determine starting page: use startingPage if provided, otherwise use chapterId, otherwise default to 1
    int initialPage = 1;
    if (widget.startingPage != null && widget.startingPage! > 0) {
      initialPage = widget.startingPage!;
      print('ReadingContentScreen: Starting from page ${widget.startingPage} (provided via startingPage)');
    } else if (widget.chapterId != null) {
      initialPage = int.tryParse(widget.chapterId!) ?? 1;
      print('ReadingContentScreen: Starting from page $initialPage (parsed from chapterId: ${widget.chapterId})');
    } else {
      print('ReadingContentScreen: Starting from page 1 (default)');
    }
    
    _currentPage = initialPage;
    _chapterDataFuture = fetchChapterData();
    _loadTotalChapters();
  }

  Future<ChapterPage> fetchChapterData() async {
    try {
      final bookId = widget.bookId ?? 'R-00002';
      print('fetchChapterData: Fetching page $_currentPage for book $bookId');
      
      final chapterPage = await controller.fetchChapter(bookId, _currentPage);
      
      print('fetchChapterData: Received page with ${chapterPage.blocks.length} blocks');
      print('fetchChapterData: Chapter title: "${chapterPage.chapterTitle}"');
      
      setState(() {
        _currentChapterData = chapterPage;
        _chapterTitle = chapterPage.chapterTitle;
        if (_chapterTitle.trim().isNotEmpty) {
          _lastValidChapter = _chapterTitle;
        }
      });

      return chapterPage;
    } catch (e) {
      print('fetchChapterData: Error - $e');
      // If this is the last chapter or chapter doesn't exist, show completion
      if (_currentPage > _totalPages) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => ReadingCompletionScreen(
              bookId: widget.bookId,
              currentPage: _currentPage,
              totalPages: _totalPages,
            )),
          );
        });
      }
      rethrow;
    }
  }

  Future<void> _loadTotalChapters() async {
    try {
      final bookId = widget.bookId ?? 'R-00002';
      final total = await controller.getTotalChapters(bookId);
      setState(() {
        _totalPages = total;
      });
    } catch (e) {
      // Use fallback if API call fails
      setState(() {
        _totalPages = 10; // Default fallback
      });
    }
  }

  void _nextChapter() {
    if (_currentPage >= _totalPages) {
      // Already at last chapter, show completion
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => ReadingCompletionScreen(
          bookId: widget.bookId,
          currentPage: _currentPage,
          totalPages: _totalPages,
        )),
      );
      return;
    }
    setState(() {
      _currentPage++;
      _chapterDataFuture = fetchChapterData();
    });
  }

  void _previousChapter() {
    if (_currentPage > 1) {
      setState(() {
        _currentPage--;
        _chapterDataFuture = fetchChapterData();
      });
    }
  }

  double get _progress {
    if (_totalPages == 0) return 0.0;
    return (_currentPage / _totalPages) * 100;
  }

  Map<String, dynamic> _parseStyleJson(dynamic styleJson) {
    if (styleJson == null) return {};
    if (styleJson is Map<String, dynamic>) return styleJson;
    if (styleJson is String && styleJson.isNotEmpty) {
      try {
        return json.decode(styleJson) as Map<String, dynamic>;
      } catch (_) {}
    }
    return {};
  }

  // === PROGRESS SAVING ===
  Future<void> _saveReadingProgress() async {
    try {
      // Get mobile number from session
      final mobileNumber = await SimpleSessionService.getUserPhone();
      
      if (mobileNumber == null || mobileNumber.isEmpty) {
        print('No mobile number available, cannot save progress');
        return;
      }

      // Get the current reading ID
      final readingId = widget.bookId ?? 'R-00002';
      
      print('Saving progress: mobile=$mobileNumber, reading=$readingId, page=$_currentPage');
      
      // Call the upsert API
      final progressResult = await _progressController.updateProgress(
        mobileNumber: mobileNumber,
        readingsId: readingId,
        currentPage: _currentPage,
        lastReadAt: DateTime.now(),
        // Don't set completedAt unless we're at the last page
        completedAt: _currentPage >= _totalPages ? DateTime.now() : null,
      );

      if (progressResult != null) {
        print('Progress saved successfully: ${progressResult.progressId}');
      } else {
        print('Failed to save progress');
      }
    } catch (e) {
      print('Error saving reading progress: $e');
    }
  }

  // === NAVIGATION HANDLING ===
  Future<void> _handleBackPressed() async {
    // Save progress before navigating back
    await _saveReadingProgress();
    
    // Navigate back to reading screen (pop twice to skip reading detail screen)
    if (mounted) {
      // Pop back to reading detail screen first
      Navigator.pop(context);
      // Then pop back to reading screen and indicate data might have changed
      if (mounted) {
        Navigator.pop(context, true);
      }
    }
  }

  // === MAIN BUILD ===
  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // Prevent default back behavior
      onPopInvoked: (didPop) async {
        if (!didPop) {
          await _handleBackPressed();
        }
      },
      child: Scaffold(
        appBar: null,
        body: Stack(
        children: [
          Column(
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                transitionBuilder: (child, animation) => SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, -0.2),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
                child: _minimalMode
                    ? const SizedBox(height: 36)
                    : BookReaderAppBar(
                        key: const ValueKey('fullAppBar'),
                        title: _currentChapterData?.title ?? "Loading...",
                        chapterBlockType: 
                          (_lastValidChapter != null && _lastValidChapter!.trim().isNotEmpty)
                              ? _lastValidChapter!
                              : (_currentChapterData?.chapterTitle ?? "..."),
                        currentPage: _currentPage,
                        totalPages: _totalPages,
                        onBackPressed: _handleBackPressed,
                      ),
              ),
              Expanded(
                child: FutureBuilder<ChapterPage>(
                  future: _chapterDataFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return Center(child: Text("Error: ${snapshot.error}"));
                    }
                    if (!snapshot.hasData || snapshot.data!.blocks.isEmpty) {
                      return const SizedBox.shrink();
                    }
                    
                    final chapterPage = snapshot.data!;
                    final blocks = chapterPage.blocks;
                    
                    print('Build: Displaying page ${chapterPage.chapterNumber} with ${blocks.length} blocks');
                    
                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        setState(() {
                          _minimalMode = !_minimalMode;
                        });
                      },
                      child: NotificationListener<ScrollNotification>(
                        onNotification: (notification) {
                          if (notification is ScrollUpdateNotification) {
                            final max = _scrollController.position.maxScrollExtent;
                            final current = _scrollController.position.pixels;
                            final dy = notification.scrollDelta ?? 0;
                            // At bottom: exit minimal mode
                            if (_minimalMode && current >= max - 2) {
                              setState(() {
                                _minimalMode = false;
                              });
                            }
                            // Scrolling up anywhere: enter minimal mode
                            else if (!_minimalMode && dy < 0) {
                              setState(() {
                                _minimalMode = true;
                              });
                            }
                          }
                          return false;
                        },
                        child: ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.all(16),
                          itemCount: blocks.length + 1, // Always one extra for navigation
                          itemBuilder: (context, index) {
                            if (index == blocks.length) {
                              // Last item is spacing for the NextChapterWidget
                              return const SizedBox(height: 110);
                            }
                            
                            final block = blocks[index];
                            final type = block.blockType;
                            final content = block.content;
                            final imageUrl = block.imageUrl;
                            final styleJson = _parseStyleJson(block.styleJson);
                            
                            // Debug: Print block info
                            if (index < 5) { // Only print first few blocks to avoid spam
                              print('Build: Block $index - Type: $type, Content: ${content.length > 50 ? content.substring(0, 50) + "..." : content}');
                            }
                            
                            // Chapter
                            if (type == 'chapter') {
                              // Update _lastValidChapter when a chapter block is visible
                              return VisibilityDetector(
                                key: Key('chapter_$index'),
                                onVisibilityChanged: (info) {
                                  if (info.visibleFraction > 0.5) {
                                    setState(() {
                                      if (content.trim().isNotEmpty) {
                                        _lastValidChapter = content;
                                      }
                                    });
                                  }
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                                  child: Text(
                                    content,
                                    textAlign: _parseTextAlign(styleJson['align']),
                                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                          fontWeight: _parseFontWeight(styleJson['fontWeight']),
                                          fontSize: (styleJson['fontSize'] as num?)?.toDouble(),
                                        ),
                                  ),
                                ),
                              );
                            }
                            
                            switch (type) {
                              case 'heading':
                                return Padding(
                                  padding: const EdgeInsets.only(
                                    top: 24.0,
                                    bottom: 8.0,
                                  ),
                                  child: Text(
                                    content,
                                    textAlign: _parseTextAlign(styleJson['align']),
                                    style: Theme.of(context).textTheme.titleLarge
                                        ?.copyWith(
                                          fontWeight: _parseFontWeight(
                                            styleJson['fontWeight'],
                                          ),
                                          fontSize: (styleJson['fontSize'] as num?)
                                              ?.toDouble(),
                                        ),
                                  ),
                                );
                              case 'paragraph':
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 16.0),
                                  child: Text(
                                    content,
                                    textAlign: _parseTextAlign(styleJson['align']),
                                    style: Theme.of(context).textTheme.bodyMedium
                                        ?.copyWith(
                                          height: 1.6,
                                          fontSize: (styleJson['fontSize'] as num?)
                                              ?.toDouble(),
                                          fontWeight: _parseFontWeight(
                                            styleJson['fontWeight'],
                                          ),
                                        ),
                                  ),
                                );
                              case 'image':
                                if (imageUrl == null || imageUrl.isEmpty) {
                                  return const SizedBox.shrink();
                                }
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: Image.network(imageUrl),
                                  ),
                                );
                              default:
                                return const SizedBox.shrink();
                            }
                          },
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          // MinimalFooter is always present, but slides in/out
          AnimatedPositioned(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            left: 0,
            right: 0,
            bottom: _minimalMode ? 0 : -60,
            child: MinimalFooter(
              chapterBlockType: 
                (_lastValidChapter != null && _lastValidChapter!.trim().isNotEmpty)
                    ? _lastValidChapter!
                    : (_currentChapterData?.chapterTitle ?? "..."),
              progressPercent: _progress / 100,
            ),
          ),
          // Main footer (NextChapterWidget) only when not minimal
          if (!_minimalMode)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: NextChapterWidget(
                onTap: _nextChapter,
                text: _currentPage >= _totalPages ? 'Complete Reading' : 'Next Page',
                showBackButton: _currentPage > 1,
                onBackPressed: _currentPage > 1 ? _previousChapter : null,
                currentPage: _currentPage,
                totalPages: _totalPages,
              ),
            ),
          ],
        ),
      ),
    );
  }

// Function
  TextAlign _parseTextAlign(String? value) {
    switch (value?.toLowerCase()) {
      case 'center':
        return TextAlign.center;
      case 'right':
        return TextAlign.right;
      case 'justify':
        return TextAlign.justify;
      default:
        return TextAlign.left;
    }
  }

// Function
  FontWeight _parseFontWeight(String? value) {
    switch (value?.toLowerCase()) {
      case 'bold':
        return FontWeight.bold;
      case 'w500':
        return FontWeight.w500;
      case 'w300':
        return FontWeight.w300;
      default:
        return FontWeight.normal;
    }
  }
}

// === CUSTOM WIDGETS ===

// Custom AppBar
class BookReaderAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final String chapterBlockType;
  final int? currentPage;
  final int? totalPages;
  final VoidCallback? onBackPressed;

  const BookReaderAppBar({
    Key? key,
    required this.title,
    required this.chapterBlockType,
    this.currentPage,
    this.totalPages,
    this.onBackPressed,
  }) : super(key: key);

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    // Create page info string
    String pageInfo = '';
    if (currentPage != null && totalPages != null) {
      pageInfo = ' • Page $currentPage of $totalPages';
    }
    
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios, color: Colors.black, size: 24),
        onPressed: onBackPressed ?? () => Navigator.pop(context),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.black,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            chapterBlockType + pageInfo,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
              fontWeight: FontWeight.normal,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// Bottom Next Chapter Widget
class NextChapterWidget extends StatelessWidget {
  final VoidCallback? onTap;
  final String text;
  final bool showBackButton;
  final VoidCallback? onBackPressed;
  final int currentPage;
  final int totalPages;

  const NextChapterWidget({
    Key? key,
    this.onTap,
    this.text = 'Next Chapter',
    this.showBackButton = false,
    this.onBackPressed,
    this.currentPage = 1,
    this.totalPages = 1,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(top: 8.0, left: 16.0, right: 16.0, bottom: 12.0),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Progress indicator
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Page $currentPage of $totalPages',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                    fontWeight: FontWeight.normal,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                // Menu icon
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: kBrightOrange,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.menu,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
                const SizedBox(width: 12),
                // Back button (only if showBackButton)
                if (showBackButton) ...[
                  SizedBox(
                    width: 80,
                    height: 48,
                    child: TextButton(
                      onPressed: onBackPressed,
                      style: TextButton.styleFrom(
                        backgroundColor: kLightGrey,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Back',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                // Next Chapter button
                Expanded(
                  child: GestureDetector(
                    onTap: onTap,
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: kBrightOrange,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          text,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Minimal AppBar widget - when user taps center to hide
class MinimalAppBar extends StatelessWidget implements PreferredSizeWidget {

  @override
  Size get preferredSize => const Size.fromHeight(36);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: Container(
        color: Colors.white,
      ),
    );
  }
}

// Minimal Footer widget - when user taps center to hide
class MinimalFooter extends StatelessWidget {
  final String chapterBlockType;
  final double progressPercent;

  const MinimalFooter({Key? key, required this.chapterBlockType, required this.progressPercent}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              chapterBlockType,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
                fontWeight: FontWeight.normal,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            '${(progressPercent * 100).toStringAsFixed(0)}%',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
              fontWeight: FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}

// If completed na
class ReadingCompletionScreen extends StatelessWidget {
  final String? bookId;
  final int? currentPage;
  final int? totalPages;

  const ReadingCompletionScreen({
    super.key,
    this.bookId,
    this.currentPage,
    this.totalPages,
  });

  Future<void> _markAsCompleted(BuildContext context) async {
    try {
      // Get mobile number from session
      final mobileNumber = await SimpleSessionService.getUserPhone();
      
      if (mobileNumber == null || mobileNumber.isEmpty) {
        print('No mobile number available, cannot mark as completed');
        return;
      }

      // Get the reading ID
      final readingId = bookId ?? 'R-00002';
      final finalPage = totalPages ?? currentPage ?? 1;
      
      print('Marking as completed: mobile=$mobileNumber, reading=$readingId, page=$finalPage');
      
      // Create a progress controller instance
      final progressController = ReadingProgressController();
      
      // Call the upsert API with completedAt set to current time
      final progressResult = await progressController.updateProgress(
        mobileNumber: mobileNumber,
        readingsId: readingId,
        currentPage: 1,
        lastReadAt: DateTime.now(),
        completedAt: DateTime.now(), // Mark as completed
      );

      if (progressResult != null) {
        print('Reading marked as completed successfully: ${progressResult.progressId}');
      } else {
        print('Failed to mark reading as completed');
      }
    } catch (e) {
      print('Error marking reading as completed: $e');
    }
  }

  Future<void> _handleBackToModules(BuildContext context) async {
    // Mark the reading as completed first
    await _markAsCompleted(context);
    
    if (context.mounted) {
      // Navigate back to reading screen (pop twice to skip reading detail screen)
      // Pop back to reading detail screen first
      Navigator.pop(context);
      // Then pop back to reading screen and indicate data might have changed
      if (context.mounted) {
        Navigator.pop(context, true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Completed")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle, size: 80, color: Colors.green),
            const SizedBox(height: 20),
            const Text(
              "Congratulations!\nYou've completed this reading.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: () => _handleBackToModules(context),
              child: const Text("Back to Modules"),
            ),
          ],
        ),
      ),
    );
  }
}