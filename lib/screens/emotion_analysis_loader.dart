import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import './analysis.dart';

// DATA MODEL to match your backend API structure
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
      score: (json['score'] as num).toDouble(), // Use double for percent/score
      analysis: json['analysis'] ?? '',
    );
  }
}

// WIDGET THAT LOADS emotion analysis from API and dislays with EmotionAnalysisCard
class EmotionAnalysisLoader extends StatefulWidget {
  final String analysisApiUrl;
  const EmotionAnalysisLoader({super.key, required this.analysisApiUrl});

  @override
  State<EmotionAnalysisLoader> createState() => _EmotionAnalysisLoaderState();
}

class _EmotionAnalysisLoaderState extends State<EmotionAnalysisLoader> {
  late Future<List<EmotionAnalysis>> _futureEmotions;

  Future<List<EmotionAnalysis>> fetchEmotions() async {
    // Replace with your backend endpoint, e.g. Flask/FastAPI/Django etc.
    final response = await http.get(Uri.parse(widget.analysisApiUrl));
    if (response.statusCode == 200) {
      final List<dynamic> body = json.decode(response.body);
      return body.map((item) => EmotionAnalysis.fromJson(item)).toList();
    } else {
      throw Exception('Failed to load emotion analysis');
    }
  }

  @override
  void initState() {
    super.initState();
    _futureEmotions = fetchEmotions();
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
        // Find the emotion with highest score
        final highest = emotions.reduce((a, b) => a.score > b.score ? a : b);

        return ListView(
          children: emotions.map((e) {
            // Highlight the card with the highest score
            return EmotionAnalysisCard(
              emotion: e.emotion,
              percent: (e.score * 10)
                  .toInt(), // If you want 0-100% (else, just use e.score*10)
              description: e.analysis,
              highlighted: e.emotion == highest.emotion,
            );
          }).toList(),
        );
      },
    );
  }
}

// --- Use this widget in your page:
/*
Scaffold(
  appBar: AppBar(title: Text('Emotion Analysis')),
  body: EmotionAnalysisLoader(
    analysisApiUrl: 'http://YOUR-BACKEND-HOST/emotion_analysis', // Your API endpoint
  ),
)
*/

// --- Make sure to import EmotionAnalysisCard from analysis.dart
// import 'package:your_package/screens/analysis.dart';
