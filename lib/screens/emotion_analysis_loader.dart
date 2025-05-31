import 'package:flutter/material.dart';
// import 'package:http/http.dart' as http; // No longer needed directly here
import '../utils/api_service.dart'; // Added APIService import
import './analysis.dart'; // For EmotionAnalysisCard

// DATA MODEL
class EmotionAnalysis {
  final String emotion;
  final double score;
  final String analysis;

  EmotionAnalysis({
    required this.emotion,
    required this.score,
    required this.analysis,
  });

  factory EmotionAnalysis.fromJson(Map<String, dynamic> json) {
    return EmotionAnalysis(
      emotion: json['dim'],
      score: (json['score'] as num).toDouble(),
      analysis: json['analysis'] ?? '',
    );
  }
}

// TAG WIDGET (pill style, clickable)
class EmotionTagPill extends StatelessWidget {
  final String text;
  final bool selected;
  final VoidCallback onTap;

  const EmotionTagPill({
    super.key,
    required this.text,
    this.selected = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFBDD6F6) : const Color(0xFFDDE6F7),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: selected ? Colors.white : const Color(0xFF4A5B77),
            fontWeight: FontWeight.normal,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}

// LOADER WIDGET WITH CLICKABLE FILTER TABS
class EmotionAnalysisLoader extends StatefulWidget {
  final String filePath; // Changed constructor

  const EmotionAnalysisLoader({
    super.key,
    required this.filePath, // Store filePath
  });

  @override
  State<EmotionAnalysisLoader> createState() => _EmotionAnalysisLoaderState();
}

class _EmotionAnalysisLoaderState extends State<EmotionAnalysisLoader> {
  late Future<List<EmotionAnalysis>> _futureEmotions;
  String? _selectedEmotion; // null means show all
  final APIService _apiService = APIService(); // Added APIService instance

  @override
  void initState() {
    super.initState();
    _futureEmotions = fetchEmotions();
  }

  Future<List<EmotionAnalysis>> fetchEmotions() async {
    try {
      final Map<String, dynamic> body = await _apiService.analyzeMessages(
        widget.filePath,
      );

      // Check for 'results' key and if it's a non-empty list
      if (body['results'] == null ||
          body['results'] is! List ||
          (body['results'] as List).isEmpty) {
        // Check for an error message from the backend if results are not as expected
        if (body['error'] != null) {
          throw Exception('Failed to load emotion analysis: ${body['error']}');
        }
        throw Exception(
          'No results found in analysis response or results key is missing/empty.',
        );
      }

      final List<dynamic> resultsList = body['results'] as List;

      // Find the first result item that contains an 'analysis' list.
      // This assumes we are interested in the analysis of the first message/segment that has one.
      final Map<String, dynamic>? firstResultWithAnalysis = resultsList
          .firstWhere(
            (item) =>
                item is Map<String, dynamic> &&
                item['analysis'] != null &&
                (item['analysis'] is List),
            orElse: () => null, // Return null if no such item is found
          );

      if (firstResultWithAnalysis == null) {
        throw Exception('No valid analysis data found in any of the results.');
      }

      final List<dynamic> analysisList =
          firstResultWithAnalysis['analysis'] as List;
      if (analysisList.isEmpty) {
        // This case might be valid (e.g. text had no discernible emotions by the model)
        // but for now, let's treat it as "no data to display" or an issue if we expect emotions.
        // Depending on requirements, you might return an empty list or throw.
        // For now, returning an empty list to avoid breaking UI that expects a list.
        print(
          "Warning: Analysis list is empty for filePath: ${widget.filePath}",
        );
        return [];
      }

      return analysisList
          .map((item) => EmotionAnalysis.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      // Catch errors from APIService or from parsing logic above
      print('Error in fetchEmotions: $e for filePath: ${widget.filePath}');
      throw Exception('Failed to load emotion analysis: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<EmotionAnalysis>>(
      future: _futureEmotions,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        final emotions = snapshot.data!;
        final highest = emotions.reduce((a, b) => a.score > b.score ? a : b);

        // Sort by score descending for tag order
        final sortedEmotions = List<EmotionAnalysis>.from(emotions)
          ..sort((a, b) => b.score.compareTo(a.score));

        // Tag Row (All + each emotion)
        final tagRow = SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              EmotionTagPill(
                text: "All",
                selected: _selectedEmotion == null,
                onTap: () {
                  setState(() {
                    _selectedEmotion = null;
                  });
                },
              ),
              ...sortedEmotions.map(
                (e) => EmotionTagPill(
                  text:
                      '${e.emotion[0].toUpperCase()}${e.emotion.substring(1)} (${e.score.toInt()}/10)',
                  selected:
                      _selectedEmotion?.toLowerCase() ==
                      e.emotion.toLowerCase(),
                  onTap: () {
                    setState(() {
                      _selectedEmotion = e.emotion;
                    });
                  },
                ),
              ),
            ],
          ),
        );

        // Filtered emotions for cards
        final filtered = _selectedEmotion == null
            ? emotions
            : emotions
                  .where(
                    (e) =>
                        e.emotion.toLowerCase() ==
                        _selectedEmotion!.toLowerCase(),
                  )
                  .toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            tagRow,
            ...filtered.map(
              (e) => EmotionAnalysisCard(
                emotion: e.emotion,
                percent: (e.score * 10).toInt(),
                description: e.analysis,
                highlighted: e.emotion == highest.emotion,
              ),
            ),
          ],
        );
      },
    );
  }
}
