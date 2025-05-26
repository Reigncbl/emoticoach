import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
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
  final String analysisApiUrl;
  final String phone;
  final String firstName;
  final String lastName;

  const EmotionAnalysisLoader({
    super.key,
    required this.analysisApiUrl,
    required this.phone,
    required this.firstName,
    required this.lastName,
  });

  @override
  State<EmotionAnalysisLoader> createState() => _EmotionAnalysisLoaderState();
}

class _EmotionAnalysisLoaderState extends State<EmotionAnalysisLoader> {
  late Future<List<EmotionAnalysis>> _futureEmotions;
  String? _selectedEmotion; // null means show all

  @override
  void initState() {
    super.initState();
    _futureEmotions = fetchEmotions();
  }

  Future<List<EmotionAnalysis>> fetchEmotions() async {
    final url = Uri.parse(widget.analysisApiUrl);
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'phone': widget.phone,
        'first_name': widget.firstName,
        'last_name': widget.lastName,
      }),
    );
    if (response.statusCode == 200) {
      final body = json.decode(response.body);
      if (body['last_message_analysis'] == null ||
          body['last_message_analysis']['analysis'] == null) {
        throw Exception('No analysis found for last message.');
      }

      final List<dynamic> analysis = body['last_message_analysis']['analysis'];
      return analysis.map((item) => EmotionAnalysis.fromJson(item)).toList();
    } else {
      throw Exception('Failed to load emotion analysis: ${response.body}');
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
