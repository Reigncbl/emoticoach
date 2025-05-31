import 'package:flutter/material.dart';
import './analysis.dart';

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
  final Map<String, dynamic> analysisData;

  const EmotionAnalysisLoader({super.key, required this.analysisData});

  @override
  State<EmotionAnalysisLoader> createState() => _EmotionAnalysisLoaderState();
}

class _EmotionAnalysisLoaderState extends State<EmotionAnalysisLoader> {
  List<EmotionAnalysis>? _emotionsList;
  String? _parsingError;
  String? _selectedEmotion; // null means show all

  @override
  void initState() {
    super.initState();
    _parseAnalysisData();
  }

  void _parseAnalysisData() {
    try {
      final Map<String, dynamic> body = widget.analysisData;

      if (body['results'] == null ||
          body['results'] is! List ||
          (body['results'] as List).isEmpty) {
        if (body['error'] != null) {
          throw Exception('Analysis data error: ${body['error']}');
        }
        throw Exception(
          'No results found in analysis data or results key is missing/empty.',
        );
      }

      final List<dynamic> resultsList = body['results'] as List;

      final Map<String, dynamic>? firstResultWithAnalysis = resultsList
          .firstWhere(
            (item) =>
                item is Map<String, dynamic> &&
                item['analysis'] != null &&
                (item['analysis'] is List) &&
                (item['analysis'] as List).isNotEmpty,
            orElse: () => null,
          );

      if (firstResultWithAnalysis == null) {
        setState(() {
          _emotionsList = [];
          _parsingError = null;
        });
        return;
      }

      final List<dynamic> analysisList =
          firstResultWithAnalysis['analysis'] as List;

      if (analysisList.isEmpty) {
        setState(() {
          _emotionsList = [];
          _parsingError = null;
        });
        return;
      }

      final parsedEmotions = analysisList
          .map((item) => EmotionAnalysis.fromJson(item as Map<String, dynamic>))
          .toList();

      setState(() {
        _emotionsList = parsedEmotions;
        _parsingError = null;
      });
    } catch (e) {
      print('Error parsing analysis data: $e');
      setState(() {
        _parsingError = 'Failed to parse emotion analysis: $e';
        _emotionsList = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_parsingError != null) {
      return Center(child: Text('Error: $_parsingError'));
    }

    if (_emotionsList == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_emotionsList!.isEmpty) {
      return const Center(child: Text('No emotion analysis available.'));
    }

    final emotions = _emotionsList!;
    final highest = emotions.reduce((a, b) => a.score > b.score ? a : b);

    final sortedEmotions = List<EmotionAnalysis>.from(emotions)
      ..sort((a, b) => b.score.compareTo(a.score));

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
                  _selectedEmotion?.toLowerCase() == e.emotion.toLowerCase(),
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

    final filtered = _selectedEmotion == null
        ? emotions
        : emotions
              .where(
                (e) =>
                    e.emotion.toLowerCase() == _selectedEmotion!.toLowerCase(),
              )
              .toList();

    if (filtered.isEmpty && _selectedEmotion != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          tagRow,
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Center(child: Text('No emotions found for this filter.')),
          ),
        ],
      );
    }

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
  }
}
