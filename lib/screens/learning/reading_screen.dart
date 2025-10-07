import 'package:flutter/material.dart';
import '../../models/reading_model.dart';
import 'reading_card.dart';
import './reading_detail_screen.dart';
import '../../controllers/reading_content_controller.dart';
import '../../services/session_service.dart';
import '../../services/api_service.dart';

class ReadingScreen extends StatefulWidget {
  const ReadingScreen({super.key});

  @override
  State<ReadingScreen> createState() => _ReadingScreenState();
}

class _ReadingScreenState extends State<ReadingScreen> {
  final TextEditingController _searchController = TextEditingController();
  final APIService _api = APIService();
  final ReadingProgressController _progressController =
      ReadingProgressController();
  final ReadingContentController _contentController =
      ReadingContentController();

  List<Reading> _allReadings = [];
  List<Reading> _filteredReadings = [];
  List<ReadingWithProgress> _readingsWithProgress = [];
  bool _isLoading = true;
  String? _error;
  String? _mobileNumber;

  @override
  void initState() {
    super.initState();
    _initializeUser();
    _searchController.addListener(_filterReadings);
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterReadings);
    _searchController.dispose();
    super.dispose();
  }

  // Method to refresh the screen (can be called when returning from other screens)
  Future<void> refreshScreen() async {
    print('Refreshing reading screen...');
    if (_mobileNumber != null) {
      await _fetchReadingsWithProgress();
    } else {
      await _fetchReadings();
    }
  }

  Future<void> _initializeUser() async {
    try {
      // Get mobile number from session - this is now our primary identifier
      final userPhone = await SimpleSessionService.getUserPhone();
      print('Phone number from session: $userPhone');

      if (userPhone != null && userPhone.isNotEmpty) {
        _mobileNumber = userPhone;
        print('Using phone number as mobile identifier: $_mobileNumber');
        await _fetchReadingsWithProgress();
      } else {
        print('No mobile number available, fetching readings without progress');
        // No mobile number available, just fetch readings without progress
        await _fetchReadings();
      }
    } catch (e) {
      print('Error initializing user: $e');
      await _fetchReadings();
    }
  }

  Future<void> _fetchReadingsWithProgress() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // First fetch all readings
      final readings = await _api.fetchAllReadings();

      if (_mobileNumber != null) {
        // Then fetch progress for each reading using mobile number (EFFICIENT METHOD)
        final readingsWithProgress = await _progressController
            .fetchReadingsWithProgressEfficient(_mobileNumber!, readings);

        // Calculate accurate progress percentages by fetching total chapters
        List<ReadingWithProgress> updatedReadingsWithProgress = [];

        for (var rwp in readingsWithProgress) {
          if (rwp.progress != null &&
              rwp.progress!.currentPage != null &&
              rwp.progress!.currentPage! > 0) {
            try {
              double progressPercentage = 0.0;
              final currentPage = rwp.progress!.currentPage!;

              if (rwp.progress!.isCompleted) {
                progressPercentage = 1.0;
              } else {
                // Check if this reading has an EPUB file
                if (rwp.reading.hasEpubFile) {
                  // For EPUB files, use a simple estimation based on current page
                  // Assuming most EPUB books have 100-300 pages
                  progressPercentage = (currentPage / 150).clamp(0.0, 0.95);
                  print(
                    'EPUB file detected for ${rwp.reading.title}, estimated progress: ${(progressPercentage * 100).toStringAsFixed(1)}%',
                  );
                } else {
                  // For regular content, fetch total pages
                  final totalPages = await _contentController.getTotalPages(
                    rwp.reading.id,
                  );
                  progressPercentage = (currentPage / totalPages).clamp(
                    0.0,
                    1.0,
                  );
                  print(
                    'Regular content ${rwp.reading.title}: Page $currentPage/$totalPages = ${(progressPercentage * 100).toStringAsFixed(1)}%',
                  );
                }
              }

              // Create new reading with updated progress
              final updatedReading = rwp.reading.copyWith(
                progress: progressPercentage,
              );
              updatedReadingsWithProgress.add(
                ReadingWithProgress(
                  reading: updatedReading,
                  progress: rwp.progress,
                ),
              );
            } catch (e) {
              print('Error calculating progress for ${rwp.reading.id}: $e');
              // Fallback to original reading if API fails
              updatedReadingsWithProgress.add(rwp);
            }
          } else {
            // No progress or not started, keep original
            updatedReadingsWithProgress.add(rwp);
          }
        }

        if (!mounted) return;
        setState(() {
          _readingsWithProgress = updatedReadingsWithProgress;
          _allReadings = updatedReadingsWithProgress
              .map((rwp) => rwp.reading)
              .toList();
          _filteredReadings = List.from(_allReadings);
          _isLoading = false;
        });
      } else {
        // No mobile number, just use readings without progress
        if (!mounted) return;
        setState(() {
          _allReadings = readings;
          _filteredReadings = List.from(_allReadings);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _fetchReadings() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final readings = await _api.fetchAllReadings();
      if (!mounted) return;
      setState(() {
        _allReadings = readings;
        _filteredReadings = List.from(_allReadings);
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  void _filterReadings() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredReadings = _allReadings.where((reading) {
        final t = reading.title.toLowerCase();
        final a = reading.author.toLowerCase();
        final hasSkill = reading.skills.any(
          (s) => s.toLowerCase().contains(query),
        );
        return t.contains(query) || a.contains(query) || hasSkill;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading readings...'),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.redAccent),
              const SizedBox(height: 12),
              Text(
                'Failed to load readings',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.red.shade700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  if (_mobileNumber != null) {
                    _fetchReadingsWithProgress();
                  } else {
                    _fetchReadings();
                  }
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final isSearching = _searchController.text.isNotEmpty;
    final catA = _getCatA();
    final catB = _getCatB();
    final hasAny = _filteredReadings.isNotEmpty;

    return Scaffold(
      backgroundColor: Colors.white, // White background
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: ListView(
          children: [
            const SizedBox(height: 12),

            // Search bar with filter icon
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search by title, author, or skill...',
                      suffixIcon: const Icon(Icons.search),
                      filled: true,
                      fillColor: const Color(0xFFF0F0F0),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(50),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 0,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
              ],
            ),
            const SizedBox(height: 24),

            // Show search results when user is searching
            if (isSearching) ...[
              _sectionHeader(
                "Search Results (${_filteredReadings.length})",
                onViewAll: () => _showAllReadings('search'),
              ),
              if (_filteredReadings.isEmpty)
                _emptyState()
              else
                _searchResultsGrid(_filteredReadings),
              const SizedBox(height: 24),
            ],

            // Show categorized sections when not searching
            if (!isSearching) ...[
              // Continue Reading Section
              if (_getContinueReadingItems().isNotEmpty) ...[
                _sectionHeader(
                  "Continue Reading",
                  onViewAll: () => _showAllReadings('continue'),
                ),
                _horizontalReadingCards(
                  _getContinueReadingItems(),
                  isContinueReading: true,
                ),
                const SizedBox(height: 24),
              ],

              // Cat-A (Articles)
              _sectionHeader(
                "Articles",
                onViewAll: () => _showAllReadings('CAT-A'),
              ),
              _horizontalReadingCards(catA),
              const SizedBox(height: 24),

              // Cat-B (Books)
              _sectionHeader("Books", onViewAll: () => _showAllReadings('CAT-B')),
              _horizontalReadingCards(catB),
              const SizedBox(height: 24),

              // Completed Section
              if (_getCompletedItems().isNotEmpty) ...[
                _sectionHeader(
                  "Completed",
                  onViewAll: () => _showAllReadings('completed'),
                ),
                _horizontalReadingCards(_getCompletedItems()),
                const SizedBox(height: 24),
              ],

              // Fallback: if both Cat-A and Cat-B are empty but we do have data, show all
              if (catA.isEmpty && catB.isEmpty && hasAny) ...[
                _sectionHeader(
                  "All Readings",
                  onViewAll: () => _showAllReadings('all'),
                ),
                _horizontalReadingCards(_filteredReadings),
                const SizedBox(height: 24),
              ],

              // Absolute empty state
              if (!hasAny) _emptyState(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String title, {required VoidCallback onViewAll}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
          ),
          TextButton(onPressed: onViewAll, child: const Text("View All")),
        ],
      ),
    );
  }

  Widget _horizontalReadingCards(
    List<Reading> readings, {
    bool isContinueReading = false,
  }) {
    if (readings.isEmpty) {
      return _categoryEmpty();
    }
    return SizedBox(
      height: 280,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: readings.length,
        separatorBuilder: (context, index) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final reading = readings[index];
          return ReadingCard(
            reading: reading,
            onTap: () => _navigateToReading(reading),
            isContinueReading: isContinueReading,
          );
        },
      ),
    );
  }

  Widget _searchResultsGrid(List<Reading> readings) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.7,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: readings.length,
      itemBuilder: (context, index) {
        final reading = readings[index];
        return ReadingCard(
          reading: reading,
          onTap: () => _navigateToReading(reading),
          isContinueReading: false,
        );
      },
    );
  }

  // Helper methods to filter readings
  List<Reading> _getContinueReadingItems() {
    if (_readingsWithProgress.isEmpty) return [];

    List<Reading> continueItems = [];

    for (var rwp in _readingsWithProgress) {
      if (rwp.progress != null &&
          rwp.progress!.currentPage != null &&
          rwp.progress!.currentPage! > 0 &&
          !rwp.isCompleted) {
        // This item has progress and is not completed - the progress percentage is already calculated accurately
        continueItems.add(rwp.reading);
      }
    }

    return continueItems;
  }

  List<Reading> _getCompletedItems() {
    if (_readingsWithProgress.isEmpty) return [];

    final items = _readingsWithProgress
        .where(
          (rwp) => rwp.isCompleted,
        ) // Use the isCompleted getter from ReadingWithProgress
        .map((rwp) => rwp.readingWithProgress) // Get the Reading object
        .toList();
    return items;
  }

  List<Reading> _getCatA() {
    return _filteredReadings
        .where((r) => r.category.toUpperCase() == 'CAT-A')
        .where((r) => r.progress == 0) // Only show items without progress
        .toList();
  }

  List<Reading> _getCatB() {
    return _filteredReadings
        .where((r) => r.category.toUpperCase() == 'CAT-B')
        .where((r) => r.progress == 0) // Only show items without progress
        .toList();
  }

  void _navigateToReading(Reading reading) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ReadingDetailScreen(reading: reading),
      ),
    );

    // If result is true, it means data might have changed, so refresh
    if (result == true) {
      print('Refreshing reading screen after returning from detail screen');
      if (_mobileNumber != null) {
        await _fetchReadingsWithProgress();
      } else {
        await _fetchReadings();
      }
    }
  }

  void _showAllReadings(String section) {
    List<Reading> readingsToShow;
    String title;
    bool isContinueReading = false;

    switch (section) {
      case 'search':
        readingsToShow = _filteredReadings;
        title = 'Search Results';
        break;
      case 'continue':
        readingsToShow = _getContinueReadingItems();
        title = 'Continue Reading';
        isContinueReading = true;
        break;
      case 'completed':
        readingsToShow = _getCompletedItems();
        title = 'Completed';
        break;
      case 'CAT-A':
        readingsToShow = _getCatA();
        title = 'CAT-A (Articles)';
        break;
      case 'CAT-B':
        readingsToShow = _getCatB();
        title = 'CAT-B (Books)';
        break;
      case 'all':
        readingsToShow = _filteredReadings;
        title = 'All Readings';
        break;
      default:
        readingsToShow = _filteredReadings;
        title = 'All Readings';
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _AllReadingsScreen(
          readings: readingsToShow,
          title: title,
          isContinueReading: isContinueReading,
        ),
      ),
    );
  }

  Widget _categoryEmpty() {
    return Container(
      height: 120,
      alignment: Alignment.center,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: const Text(
        'No items in this category.',
        style: TextStyle(color: Colors.grey),
      ),
    );
  }

  Widget _emptyState() {
    return Column(
      children: const [
        SizedBox(height: 48),
        Icon(Icons.menu_book_outlined, size: 64, color: Colors.grey),
        SizedBox(height: 12),
        Text(
          'No readings found',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        SizedBox(height: 4),
        Text(
          'Try adjusting your filters or search.',
          style: TextStyle(color: Colors.grey),
        ),
        SizedBox(height: 48),
      ],
    );
  }
}

class _AllReadingsScreen extends StatelessWidget {
  final List<Reading> readings;
  final String title;
  final bool isContinueReading;

  const _AllReadingsScreen({
    required this.readings,
    required this.title,
    this.isContinueReading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: readings.isEmpty
            ? const Center(child: Text('No items to show.'))
            : GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.7,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: readings.length,
                itemBuilder: (context, index) {
                  return ReadingCard(
                    reading: readings[index],
                    isContinueReading: isContinueReading,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              ReadingDetailScreen(reading: readings[index]),
                        ),
                      );
                    },
                  );
                },
              ),
      ),
    );
  }
}
