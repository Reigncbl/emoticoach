import 'package:flutter/material.dart';
import '../../models/reading_model.dart';
import 'reading_card.dart';
import './reading_detail_screen.dart';
import '../../utils/api_service.dart';

class ReadingScreen extends StatefulWidget {
  const ReadingScreen({super.key});

  @override
  State<ReadingScreen> createState() => _ReadingScreenState();
}

class _ReadingScreenState extends State<ReadingScreen> {
  final TextEditingController _searchController = TextEditingController();
  final APIService _api = APIService();
  List<Reading> _allReadings = [];
  List<Reading> _filteredReadings = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchReadings();
    _searchController.addListener(_filterReadings);
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterReadings);
    _searchController.dispose();
    super.dispose();
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
                onPressed: _fetchReadings,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

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
                    decoration: InputDecoration(
                      hintText: 'Search for specific chat scenarios...',
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

            // Continue Reading Section
            if (_getContinueReadingItems().isNotEmpty) ...[
              _sectionHeader(
                "Continue Reading",
                onViewAll: () => _showAllReadings('continue'),
              ),
              _continueReadingCard(),
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

  Widget _continueReadingCard() {
    final continueReading = _getContinueReadingItems().first;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.orange.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              continueReading.category,
              style: const TextStyle(fontSize: 12),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            continueReading.title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          Text(
            'by ${continueReading.author}',
            style: const TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 8),
          Text(
            '${continueReading.formattedDuration} • ${continueReading.difficulty} • ${continueReading.progressPercentage} complete',
            style: const TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: continueReading.progress,
            backgroundColor: Colors.grey.shade300,
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () => _navigateToReading(continueReading),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.deepOrange),
            child: const Text(
              "Continue Reading",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _horizontalReadingCards(List<Reading> readings) {
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
          );
        },
      ),
    );
  }

  // Helper methods to filter readings
  List<Reading> _getContinueReadingItems() {
    final items = _filteredReadings
        .where((r) => (r.progress ?? 0) > 0 && (r.progress ?? 0) < 1.0)
        .toList();
    return items;
  }

  List<Reading> _getCatA() {
    return _filteredReadings
        .where((r) => (r.category ?? '').toUpperCase() == 'CAT-A')
        .toList();
  }

  List<Reading> _getCatB() {
    return _filteredReadings
        .where((r) => (r.category ?? '').toUpperCase() == 'CAT-B')
        .toList();
  }

  void _navigateToReading(Reading reading) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ReadingDetailScreen(reading: reading),
      ),
    );
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Filter Readings'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [Text('Filter options will be implemented here')],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  void _showAllReadings(String section) {
    List<Reading> readingsToShow;
    String title;

    switch (section) {
      case 'continue':
        readingsToShow = _getContinueReadingItems();
        title = 'Continue Reading';
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
        builder: (context) =>
            _AllReadingsScreen(readings: readingsToShow, title: title),
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

  const _AllReadingsScreen({required this.readings, required this.title});

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
