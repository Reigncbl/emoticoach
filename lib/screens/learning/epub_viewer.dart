import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_epub_viewer/flutter_epub_viewer.dart' as epub;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../controllers/reading_content_controller.dart';
import '../../services/session_service.dart';
import '../../widgets/reader_widgets.dart';
import '../../utils/colors.dart';

class EpubViewer extends StatefulWidget {
  final List<int> epubBytes;
  final String bookId;
  final String? title;

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
  final epub.EpubController _epubController = epub.EpubController();
  String? _epubFilePath;
  bool _isLoading = true;
  String? _loadingError;
  String? _initialCfi;
  List<epub.EpubChapter> _chapters = [];
  bool _showToc = false;
  double _progressPercent = 0.0; // Track reading progress as percentage (0.0 to 1.0)
  bool _isRestoringPosition = false; // Flag to prevent interference during restoration
  String? _currentCfi; // Track the last known exact CFI to store in DB
  bool _epubReady = false; // Guard to ensure navigation only after EPUB is fully ready
  bool _restoreSkipLogged = false; // Throttle skip logs during initial restoration
  bool _completionLocked = false; // Lock progress at 100% to prevent layout-triggered resets
  bool _isPopping = false; // Prevent multiple simultaneous pop operations
  bool _isSavingDialogVisible = false; // Track custom saving overlay visibility
  // ignore: unused_field
  double _loadingProgress = 0.0; // Track loading progress for large files
  bool _shouldShowTutorial = false; // Track if first-time tutorial should be shown

  @override
  void initState() {
    super.initState();
    _checkFirstTimeUser();
    _loadBook();
  }

  Future<void> _checkFirstTimeUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      const tutorialKey = 'epub_navigation_tutorial_shown';
      final hasSeenTutorial = prefs.getBool(tutorialKey) ?? false;
      
      if (!hasSeenTutorial) {
        setState(() {
          _shouldShowTutorial = true;
        });
        // Mark tutorial as shown
        await prefs.setBool(tutorialKey, true);
      }
    } catch (e) {
      print('Error checking first-time user: $e');
    }
  }

  void _showNavigationTutorial() {
    if (!mounted) return;
    
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.swipe,
                  size: 48,
                  color: Colors.blue,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Navigation Tip',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Swipe or tap left and right to navigate through pages',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.black54,
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Got it!',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    // Don't delete cached EPUB files - they're persistent for reuse
    super.dispose();
  }

  // Get cached EPUB file path if it exists
  Future<String?> _getCachedEpubPath() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedHash = prefs.getString('epub_cache_${widget.bookId}');
      
      if (cachedHash != null) {
        final appDocDir = await getApplicationDocumentsDirectory();
        final cachedFilePath = '${appDocDir.path}/epub_cache/$cachedHash.epub';
        final cachedFile = File(cachedFilePath);
        
        if (await cachedFile.exists()) {
          print('✅ Found cached EPUB: $cachedFilePath');
          return cachedFilePath;
        } else {
          print('⚠️ Cache reference exists but file missing, will re-cache');
          // Clean up stale reference
          await prefs.remove('epub_cache_${widget.bookId}');
        }
      }
    } catch (e) {
      print('Error checking EPUB cache: $e');
    }
    return null;
  }

  // CFI is now persisted via backend only; no local persistence

  Future<void> _loadBook() async {
    try {
      print('Starting EPUB book loading...');
      final fileSizeMB = (widget.epubBytes.length / 1024 / 1024).toStringAsFixed(2);
      print('EPUB size: ${widget.epubBytes.length} bytes ($fileSizeMB MB)');
      
      setState(() {
        _loadingProgress = 0.1; // Started loading
      });
      
      // Check if EPUB is already cached
      final cachedPath = await _getCachedEpubPath();
      if (cachedPath != null) {
        print('📚 Using cached EPUB from: $cachedPath');
        _epubFilePath = cachedPath;
        setState(() { _loadingProgress = 0.85; });
      } else {
        print('💾 Caching EPUB for first time...');
        // Create cache directory in application documents (persistent storage)
        final appDocDir = await getApplicationDocumentsDirectory();
        final cacheDir = Directory('${appDocDir.path}/epub_cache');
        if (!await cacheDir.exists()) {
          await cacheDir.create(recursive: true);
        }

        // Generate hash from EPUB bytes for unique identification
        final bytes = widget.epubBytes is Uint8List
            ? widget.epubBytes as Uint8List
            : Uint8List.fromList(widget.epubBytes);
        
        final hash = sha256.convert(bytes).toString();
        final cachedFilePath = '${cacheDir.path}/$hash.epub';

        setState(() { _loadingProgress = 0.2; });

        // Write EPUB to cache
        await File(cachedFilePath).writeAsBytes(bytes, flush: false);
        
        // Save mapping in SharedPreferences (bookId -> hash)
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('epub_cache_${widget.bookId}', hash);
        
        _epubFilePath = cachedFilePath;
        setState(() { _loadingProgress = 0.85; });
        print('EPUB cached to: $_epubFilePath with hash: $hash');
      }

      // WebView paginated renderer

      // Get saved progress from database to restore reading position
      try {
        final mobileNumber = await SimpleSessionService.getUserPhone();
        if (mobileNumber != null && mobileNumber.isNotEmpty) {
          print('Fetching EPUB progress from database for book ${widget.bookId}');
          
          final progressController = ReadingProgressController();
          final progress = await progressController.fetchProgress(mobileNumber, widget.bookId);
          
          if (progress != null && progress.currentPage != null && progress.currentPage! > 0) {
            // Calculate progress percentage from saved page (0-100 stored in DB)
            final savedProgress = (progress.currentPage! / 100.0).clamp(0.0, 1.0);
            
            // Store the saved progress to restore after EPUB loads
            _progressPercent = savedProgress; // Initialize the display progress
            
            print('Database progress: ${progress.currentPage}% will be restored after EPUB loads');
          }

          // Load saved CFI from backend for precise position restoration
          if (progress != null && progress.currentCfi != null && progress.currentCfi!.isNotEmpty) {
            _initialCfi = progress.currentCfi;
            _currentCfi = progress.currentCfi;
            print('🔖 Loaded CFI from backend for exact restore: ${progress.currentCfi}');
          }
        }
      } catch (e) {
        print('Error fetching progress from database: $e');
      }

      setState(() {
        _loadingProgress = 1.0; // Complete
        _isLoading = false;
      });
      
      print('EPUB book prepared successfully!');
      
    } catch (e, stackTrace) {
      print('Error loading EPUB book: $e');
      print('Stack trace: $stackTrace');
      
      setState(() {
        _loadingError = 'Failed to load book: ${e.toString()}';
        _isLoading = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading book: $e'),
            backgroundColor: Colors.white,
            duration: const Duration(seconds: 5),
          ),
        );
        // Don't automatically pop - let user see the error
      }
    }
  }

  // No CSS injection helper: all EPUB content is rendered with publisher CSS

  Future<void> _saveProgress() async {
    try {
      final mobileNumber = await SimpleSessionService.getUserPhone();
      if (mobileNumber != null && mobileNumber.isNotEmpty) {
        // Save progress as percentage (0.0-100.0) with decimal precision
        final progressValue = _progressPercent * 100; // Keep decimal precision
        
        // Check if book is completed (reached 100% or very close to it)
        final isCompleted = progressValue >= 99.5; // Consider 99.5% as complete
        
        print('Saving EPUB reading progress: ${progressValue.toStringAsFixed(2)}% for book ${widget.bookId}');
        if (isCompleted) {
          print('📚 Book reached 100%, marking as completed!');
        }
        if (_currentCfi != null) {
          print('Also saving CFI: $_currentCfi');
        }
        
        final progressController = ReadingProgressController();
        await progressController.updateProgress(
          mobileNumber: mobileNumber,
          readingsId: widget.bookId,
          currentPage: progressValue, // Store percentage with decimals (e.g., 89.5)
          currentCfi: _currentCfi, // Store exact CFI for precise resume
          lastReadAt: DateTime.now(),
          completedAt: isCompleted ? DateTime.now() : null, // ✅ Mark as completed when reaching 100%
        );
        
        print('EPUB progress saved to database successfully');
      }
    } catch (e) {
      print('Error saving EPUB progress: $e');
    }
  }

  Future<void> _markAsComplete() async {
    try {
      final mobileNumber = await SimpleSessionService.getUserPhone();
      if (mobileNumber != null && mobileNumber.isNotEmpty) {
        print('📚 Manually marking EPUB as complete for book ${widget.bookId}');
        
        final progressController = ReadingProgressController();
        await progressController.updateProgress(
          mobileNumber: mobileNumber,
          readingsId: widget.bookId,
          currentPage: 100.0, // Mark as 100% complete
          currentCfi: _currentCfi, // Store last known CFI
          lastReadAt: DateTime.now(),
          completedAt: DateTime.now(), // Mark as completed NOW
        );
        
        // Update local state to reflect completion
        setState(() {
          _progressPercent = 1.0;
          _completionLocked = true;
        });
        
        print('✅ EPUB marked as complete and saved to database');
      }
    } catch (e) {
      print('Error marking EPUB as complete: $e');
    }
  }

  void _presentSavingProgressDialog() {
    if (!mounted || _isSavingDialogVisible) {
      return;
    }

    _isSavingDialogVisible = true;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      useRootNavigator: true,
      builder: (_) => WillPopScope(
        onWillPop: () async => false,
        child: Material(
          type: MaterialType.transparency,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  SizedBox(
                    width: 36,
                    height: 36,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Saving progress...',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleNavigationExit({required bool markComplete}) async {
    if (!mounted) {
      _isPopping = false;
      return;
    }

    _presentSavingProgressDialog();
    bool saveSucceeded = false;

    try {
      if (markComplete) {
        await _markAsComplete();
      } else {
        await _saveProgress();
      }
      saveSucceeded = true;
    } catch (e, stackTrace) {
      print('Error while saving reading progress: $e');
      print('Stack trace: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to save your progress. Please try again.'),
            backgroundColor: Colors.white,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted && _isSavingDialogVisible) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      _isSavingDialogVisible = false;
    }

    if (!mounted) {
      return;
    }

    if (saveSucceeded && Navigator.of(context).canPop()) {
      final bool completed = markComplete || _progressPercent >= 0.995;
      Navigator.of(context).pop(completed);
    } else {
      _isPopping = false;
    }
  }

  void _triggerNavigationExit({required bool markComplete}) {
    if (_isPopping) {
      return;
    }
    _isPopping = true;
    unawaited(_handleNavigationExit(markComplete: markComplete));
  }

  double _getProgressPercent() {
    return _progressPercent;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text(
                'Loading Epub',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_epubFilePath == null || _loadingError != null) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: kWhite,
          title: const Text('Error'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 64,
                  color: Colors.red,
                ),
                const SizedBox(height: 16),
                Text(
                  _loadingError ?? 'Failed to load EPUB file',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text('Go Back'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final progressPercent = _getProgressPercent();

    // Native renderer branch (removed): always use WebView paginated renderer

    return WillPopScope(
      onWillPop: () async {
        _triggerNavigationExit(markComplete: false);
        return false; // We handle the pop ourselves
      },
      child: Scaffold(
        backgroundColor: kWhite,
        appBar: AppBar(
          backgroundColor: kWhite,
          title: Text(widget.title ?? 'EPUB Reader'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              _triggerNavigationExit(markComplete: false);
            },
          ),
          actions: [
            // Table of Contents button
            IconButton(
              icon: const Icon(Icons.list),
              onPressed: () {
                setState(() {
                  _showToc = !_showToc;
                });
              },
              tooltip: 'Table of Contents',
            ),
          ],
        ),
        body: Stack(
          children: [
            Column(
              children: [
                Expanded(
                  child: SafeArea(
                    top: false,
                    bottom: false,
                    child: Stack(
                  children: [
                    epub.EpubViewer(
                        epubSource: epub.EpubSource.fromFile(File(_epubFilePath!)),
                        epubController: _epubController,
                        // For very large books prefer scrolled flow and disable snapping
                        displaySettings: epub.EpubDisplaySettings(
                          // Always paginate, even for large files, per request (CFI unsupported in scrolled mode)
                          flow: epub.EpubFlow.paginated,
                          // Enable snapping for consistent page boundaries
                          snap: true,
                        ),
                        initialCfi: _initialCfi,
                        onChaptersLoaded: (chapters) {
                          setState(() {
                            _chapters = chapters;
                          });
                          print('Loaded ${chapters.length} chapters');
                        },
                        onEpubLoaded: () {
                          if (_epubReady) {
                            // Some devices may trigger onEpubLoaded more than once; ignore duplicates
                            print('EPUB already ready, ignoring duplicate onEpubLoaded');
                            return;
                          }
                          print('EPUB loaded successfully');
                          
                          // Restoration strategy:
                          // 1. Let the widget handle initialCfi (already passed in initialCfi parameter)
                          // 2. If no initialCfi but we have a saved percentage, restore by percentage.
                          // Avoid double-calling display when initialCfi is provided to prevent flicker.
                          if (_initialCfi == null || _initialCfi!.isEmpty) {
                            if (_progressPercent > 0) {
                              print('🧭 Restoring by saved percentage ${(_progressPercent * 100).toStringAsFixed(2)}%');
                              _isRestoringPosition = true;
                              _restoreSkipLogged = false;
                              Future.delayed(const Duration(milliseconds: 350), () {
                                if (!mounted) return;
                                _epubController.toProgressPercentage(_progressPercent);
                                Future.delayed(const Duration(milliseconds: 600), () {
                                  if (mounted) _isRestoringPosition = false;
                                  // allow future restoration sequences to log once again if they occur
                                  _restoreSkipLogged = false;
                                });
                              });
                            }
                          } else {
                            print('📌 initialCfi provided. Skipping manual display() to avoid redundant jump.');
                          }

                          // Mark ready and clear initialCfi to avoid re-applying on rebuilds
                          if (mounted) {
                            setState(() {
                              _epubReady = true;
                              _initialCfi = null;
                            });
                            
                            // Show tutorial for first-time users after a short delay
                            if (_shouldShowTutorial) {
                              Future.delayed(const Duration(milliseconds: 500), () {
                                if (mounted) {
                                  _showNavigationTutorial();
                                  _shouldShowTutorial = false; // Prevent showing again on rebuild
                                }
                              });
                            }
                          } else {
                            _epubReady = true;
                            _initialCfi = null;
                          }
                        },
                        onRelocated: (location) {
                          // Track current location
                          final newProgress = location.progress;
                          
                          // Don't update progress if we're currently restoring position
                          if (_isRestoringPosition) {
                            if (!_restoreSkipLogged) {
                              print('⏸️  Skipping progress update during restoration (at ${(newProgress * 100).toStringAsFixed(2)}%)');
                              _restoreSkipLogged = true;
                            }
                            return;
                          }

                          // Lock progress at 100% once reached to prevent layout changes from resetting it
                          if (_completionLocked && newProgress < 0.995) {
                            print('Progress locked at 100%, ignoring backward jump to ${(newProgress * 100).toStringAsFixed(2)}%');
                            return;
                          }

                          // Lock completion when we reach 100%
                          if (!_completionLocked && newProgress >= 0.995) {
                            print('Reached 100%! Locking progress to prevent resets.');
                            _completionLocked = true;
                          }
                          
                          // Reduce noisy logs: only print when progress actually changes meaningfully
                          if ((newProgress - _progressPercent).abs() > 0.001) {
                            print('Location changed to ${(newProgress * 100).toStringAsFixed(2)}%');
                          }
                          
                          setState(() {
                            _progressPercent = newProgress;
                          });

                          // Capture the exact CFI for precise position restoration
                          // EpubLocation has startCfi and endCfi properties
                          if (location.startCfi.isNotEmpty) {
                            _currentCfi = location.startCfi;
                            print('Captured CFI: ${location.startCfi}');
                          }
                        },
                        onTextSelected: (selection) {
                          print('Text selected');
                          // You can show a context menu or handle the selection
                        },
                      ),
                      // Left Tap Zone (Previous Page)
                      Positioned(
                        left: 0,
                        width: MediaQuery.of(context).size.width * 0.3,
                        top: 0,
                        bottom: 0,
                        child: GestureDetector(
                          behavior: HitTestBehavior.translucent,
                          onTap: () {
                            print('Tap Left Detected - Going to Previous Page');
                            _epubController.prev();
                          },
                          onHorizontalDragEnd: (details) {
                            if (details.primaryVelocity == null) return;
                            if (details.primaryVelocity!.abs() < 500) return;

                            if (details.primaryVelocity! < 0) {
                              print('Swipe Left Detected - Going to Next Page');
                              _epubController.next();
                            } else if (details.primaryVelocity! > 0) {
                              print('Swipe Right Detected - Going to Previous Page');
                              _epubController.prev();
                            }
                          },
                          child: Container(color: Colors.transparent),
                        ),
                      ),

                      // Right Tap Zone (Next Page)
                      Positioned(
                        right: 0,
                        width: MediaQuery.of(context).size.width * 0.3,
                        top: 0,
                        bottom: 0,
                        child: GestureDetector(
                          behavior: HitTestBehavior.translucent,
                          onTap: () {
                            print('Tap Right Detected - Going to Next Page');
                            _epubController.next();
                          },
                          onHorizontalDragEnd: (details) {
                            if (details.primaryVelocity == null) return;
                            if (details.primaryVelocity!.abs() < 500) return;

                            if (details.primaryVelocity! < 0) {
                              print('Swipe Left Detected - Going to Next Page');
                              _epubController.next();
                            } else if (details.primaryVelocity! > 0) {
                              print('Swipe Right Detected - Going to Previous Page');
                              _epubController.prev();
                            }
                          },
                          child: Container(color: Colors.transparent),
                        ),
                      ),

                      // Center Tap Zone (Toggle Chrome)
                      Positioned(
                        left: MediaQuery.of(context).size.width * 0.3,
                        right: MediaQuery.of(context).size.width * 0.3,
                        top: 0,
                        bottom: 0,
                        child: GestureDetector(
                          behavior: HitTestBehavior.translucent,
                          onDoubleTap: () {
                            // Consume double tap to prevent unwanted navigation/zoom
                          },
                          onHorizontalDragEnd: (details) {
                            if (details.primaryVelocity == null) return;

                            // Add threshold to prevent accidental swipes during taps
                            if (details.primaryVelocity!.abs() < 500) return;

                            if (details.primaryVelocity! < 0) {
                              // Swipe Left -> Next Page
                              print('Swipe Left Detected - Going to Next Page');
                              _epubController.next();
                            } else if (details.primaryVelocity! > 0) {
                              // Swipe Right -> Previous Page
                              print('Swipe Right Detected - Going to Previous Page');
                              _epubController.prev();
                            }
                          },
                          child: Container(
                            color: Colors.transparent,
                          ),
                        ),
                      ),
                      // Table of Contents overlay
                      if (_showToc)
                        Positioned.fill(
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _showToc = false;
                              });
                            },
                            child: Container(
                              color: Colors.black54,
                              child: Center(
                                child: GestureDetector(
                                  onTap: () {}, // Prevent closing when tapping the card
                                  child: Container(
                                    width: MediaQuery.of(context).size.width * 0.85,
                                    height: MediaQuery.of(context).size.height * 0.7,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Column(
                                      children: [
                                        // Header
                                        Container(
                                          padding: const EdgeInsets.all(16),
                                          decoration: BoxDecoration(
                                            color: Theme.of(context).primaryColor,
                                            borderRadius: const BorderRadius.only(
                                              topLeft: Radius.circular(12),
                                              topRight: Radius.circular(12),
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              const Text(
                                                'Table of Contents',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              IconButton(
                                                icon: const Icon(Icons.close, color: Colors.white),
                                                onPressed: () {
                                                  setState(() {
                                                    _showToc = false;
                                                  });
                                                },
                                              ),
                                            ],
                                          ),
                                        ),
                                        // Chapters list
                                        Expanded(
                                          child: _chapters.isEmpty
                                              ? const Center(
                                                  child: Text('No chapters available'),
                                                )
                                              : ListView.builder(
                                                  itemCount: _chapters.length,
                                                  itemBuilder: (context, index) {
                                                    final chapter = _chapters[index];
                                                    return ListTile(
                                                      leading: CircleAvatar(
                                                        backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
                                                        child: Text(
                                                          '${index + 1}',
                                                          style: TextStyle(
                                                            color: Theme.of(context).primaryColor,
                                                            fontWeight: FontWeight.bold,
                                                          ),
                                                        ),
                                                      ),
                                                      title: Text(
                                                        chapter.title.isNotEmpty 
                                                            ? chapter.title 
                                                            : 'Chapter ${index + 1}',
                                                        style: const TextStyle(
                                                          fontSize: 16,
                                                        ),
                                                      ),
                                                      onTap: () async {
                                                        // Prevent early taps before viewer is fully ready
                                                        if (!_epubReady) {
                                                          print('⏳ EPUB not ready yet; ignoring chapter tap for index ${index + 1}');
                                                          return;
                                                        }

                                                        final target = chapter.href;
                                                        print('📑 Attempting chapter navigation to: $target (index ${index + 1})');

                                                        // Small delay gives time for pagination/snap layout to settle
                                                        await Future.delayed(const Duration(milliseconds: 80));
                                                        try {
                                                          // Navigate to chapter via its href (package accepts href or CFI)
                                                          await _epubController.display(cfi: target);
                                                        } catch (e) {
                                                          // Fallback: approximate by percentage if bridge throws
                                                          print('⚠️ display() error: $e. Falling back to percentage.');
                                                          final total = _chapters.isEmpty ? 1 : _chapters.length;
                                                          final fallback = (index / total).clamp(0.0, 0.99);
                                                          _epubController.toProgressPercentage(fallback);
                                                        }

                                                        // Update current CFI for precise resume
                                                        _currentCfi = target;
                                                        if (mounted) {
                                                          setState(() {
                                                            _showToc = false;
                                                          });
                                                        }
                                                      },
                                                    );
                                                  },
                                                ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      // Loading overlay - shown until EPUB is fully loaded
                      if (!_epubReady)
                        Positioned.fill(
                          child: Container(
                            color: Colors.white,
                            child: const Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  CircularProgressIndicator(),
                                  SizedBox(height: 16),
                                  Text(
                                    'Loading Content',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            // Footer - always show full status (Progress only)
            Container(
              width: double.infinity,
              color: Colors.white,
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 12,
                bottom: 12 + (MediaQuery.of(context).padding.bottom > 0 ? MediaQuery.of(context).padding.bottom : 0),
              ),
              child: Center(
                child: Text(
                  '${(progressPercent * 100).toStringAsFixed(0)}%',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                    fontWeight: FontWeight.normal,
                  ),
                ),
              ),
            ),
          ],
        ),
            // Floating "Complete Reading" button
            if (progressPercent >= 1.0)
              Positioned(
                left: 16,
                right: 16,
                bottom: 10 + (MediaQuery.of(context).padding.bottom > 0 ? MediaQuery.of(context).padding.bottom : 0),
                child: SafeArea(
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        _triggerNavigationExit(markComplete: true);
                      },
                      label: const Text('Complete Reading'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 4,
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
