import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:emoticoach/utils/colors.dart';
import 'package:http/http.dart' as http;
import 'package:emoticoach/controllers/reading_content_controller.dart'; // AppBar Controller
import 'package:emoticoach/models/readings_models.dart'; // AppBar Model
import 'package:visibility_detector/visibility_detector.dart';

// === MAIN SCREEN ===
class ReadingContentScreen extends StatefulWidget {
  final String? bookId;
  final String? pageId;
  

  const ReadingContentScreen({super.key, this.bookId, this.pageId});

  @override
  State<ReadingContentScreen> createState() => _ReadingContentScreenState();
}

class _ReadingContentScreenState extends State<ReadingContentScreen> {
  String? _lastValidChapter;
  double _lastScrollOffset = 0;
  bool _wasAtBottom = false;
  final ScrollController _scrollController = ScrollController();
  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
  bool _minimalMode = false;
  late int _currentPage;
  late Future<List<Map<String, dynamic>>> _pageDataFuture;

  // Simulated total pages for now (you should fetch from API)
  final int _totalPages = 10;
  // dar
  final AppBarController controller = AppBarController();

  String _chapterTitle = "";

  AppBarData? _appBarData;

  @override
  void initState() {
    super.initState();
    _currentPage = int.tryParse(widget.pageId ?? '1') ?? 1;
    _pageDataFuture = fetchReadingPage();
    fetchAppBarData(); // load title, chapter, progress
  }

  String get baseUrl {
    final bookId = widget.bookId ?? 'R-00002';
    return 'http://10.0.2.2:8000/book/$bookId/$_currentPage';
  }

  Future<List<Map<String, dynamic>>> fetchReadingPage() async {
    final response = await http.get(Uri.parse(baseUrl));
    if (response.statusCode == 200) {
      final List<dynamic> jsonList = json.decode(response.body);

      if (jsonList.isEmpty) {
        // Delay navigation until after build
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const ReadingCompletionScreen()),
          );
        });
      } else {
        setState(() {
          _chapterTitle = "Chapter $_currentPage";
          // Optionally update _lastValidChapter if this is a valid chapter
          if (_chapterTitle.trim().isNotEmpty) {
            _lastValidChapter = _chapterTitle;
          }
        });

        // Refresh AppBar
        fetchAppBarData();
      }

      return jsonList.cast<Map<String, dynamic>>();
    } else {
      throw Exception("Failed to load page");
    }
  }

  void _nextPage() {
    setState(() {
      _currentPage++;
      _pageDataFuture = fetchReadingPage();
    });
    fetchAppBarData(); // Refresh AppBar Info
  }

  double get _progress {
    if (_totalPages == 0) return 0.0;
    return (_currentPage / _totalPages) * 100;
  }

  // For AppBar Info
  Future<void> fetchAppBarData() async {
    try {
      final bookId = widget.bookId ?? 'R-00002';
      final data = await controller.fetchAppBar(bookId, _currentPage);
      setState(() {
        _appBarData = data;
        // if ((_appBarData?.chapter ?? '').trim().isNotEmpty) {
        //   _lastValidChapter = _appBarData!.chapter;
        // }
      });
    } catch (e) {
      print("Error fetching AppBar: $e");
    }
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

  // === MAIN BUILD ===
  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                        title: _appBarData?.title ?? "Loading...",
                        chapterBlockType: 
                          (_lastValidChapter != null && _lastValidChapter!.trim().isNotEmpty)
                              ? _lastValidChapter!
                              : (_appBarData?.chapter ?? "..."),
                        onBackPressed: () => Navigator.pop(context),
                      ),
              ),
              Expanded(
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: _pageDataFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return Center(child: Text("Error: ${snapshot.error}"));
                    }
                    if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return const SizedBox.shrink();
                    }
                    final blocks = snapshot.data!;
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
                              _wasAtBottom = true;
                            }
                            // Scrolling up anywhere: enter minimal mode
                            else if (!_minimalMode && dy < 0) {
                              setState(() {
                                _minimalMode = true;
                              });
                            }
                            _lastScrollOffset = current;
                          }
                          return false;
                        },
                        child: ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.all(16),
                          itemCount: blocks.length + 1, // Always one extra
                          itemBuilder: (context, index) {
                            if (index == blocks.length) {
                              // Last item is the NextChapterWidget
                              return const SizedBox(height: 110);
                            }
                            final block = blocks[index];
                            final type = block['blocktype']?.toString() ?? '';
                            final content = block['content']?.toString();
                            final imageUrl = block['imageurl']?.toString();
                            final styleJson = _parseStyleJson(block['stylejson']);
                            // Chapter
                            if (type == 'chapter') {
                              // Update _lastValidChapter when a chapter block is visible
                              return VisibilityDetector(
                                key: Key('chapter_$index'),
                                onVisibilityChanged: (info) {
                                  if (info.visibleFraction > 0.5) {
                                    setState(() {
                                      // Update only the chapter field in _appBarData
                                      _appBarData = _appBarData?.copyWith(
                                        chapter: content ?? "Unknown Chapter",
                                      );
                                      if ((content ?? '').trim().isNotEmpty) {
                                        _lastValidChapter = content;
                                      }
                                    });
                                  }
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                                  child: Text(
                                    content ?? '',
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
                                    content ?? '',
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
                                    content ?? '',
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
                    : (_appBarData?.chapter ?? "..."),
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
                onTap: _nextPage,
                text: 'Next Page',
              ),
            ),
        ],
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
  final VoidCallback? onBackPressed;

  const BookReaderAppBar({
    Key? key,
    required this.title,
    required this.chapterBlockType,
    this.onBackPressed,
  }) : super(key: key);

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
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
            chapterBlockType,
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

  const NextChapterWidget({
    Key? key,
    this.onTap,
    this.text = 'Next Chapter',
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(top: 0, left: 16.0, right: 16.0, bottom: 12.0),
      decoration: const BoxDecoration(
        color: Colors.white,
      ),
      child: SafeArea(
        child: Row(
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
          Text(
            chapterBlockType,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
              fontWeight: FontWeight.normal,
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

// If ompleted na
class ReadingCompletionScreen extends StatelessWidget {
  const ReadingCompletionScreen({super.key});

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
              onPressed: () => Navigator.pop(context),
              child: const Text("Back to Modules"),
            ),
          ],
        ),
      ),
    );
  }
}