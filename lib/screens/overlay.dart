import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import './response.dart';
import '../utils/colors.dart';
import './emotion_analysis_loader.dart';

class OverlayScreen extends StatefulWidget {
  const OverlayScreen({super.key});

  @override
  State<OverlayScreen> createState() => _OverlayScreenState();
}

class _OverlayScreenState extends State<OverlayScreen> {
  String _latestMessage = 'Loading latest message...';
  int _selectedTab = 0; // 0=Emotion, 1=Response, 2=Tone

  @override
  void initState() {
    super.initState();
    _fetchLatestMessage();
  }

  Future<void> _fetchLatestMessage() async {
    try {
      final url = Uri.parse(
        'https://976d4bbc4a7f64092bb74e2b011a0e71.serveo.net/messages',
      );
      final Map<String, dynamic> requestBody = {
        "phone": "9762325664",
        "first_name": "Carlo",
        "last_name": "Lorieta",
      };

      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data.containsKey("messages") &&
            (data["messages"] as List).isNotEmpty) {
          final firstMsg = data["messages"][0];
          setState(() => _latestMessage = '${firstMsg["text"]}');
        } else if (data.containsKey("error")) {
          setState(() => _latestMessage = 'Error: ${data["error"]}');
        } else {
          setState(() => _latestMessage = 'No messages found.');
        }
      } else {
        setState(
          () => _latestMessage =
              'Failed to fetch message. Status: ${response.statusCode}',
        );
      }
    } catch (e) {
      setState(() => _latestMessage = 'Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget content;
    if (_selectedTab == 0) {
      content = const EmotionAnalysis();
    } else if (_selectedTab == 1) {
      content = const ResponseSuggestionScreen();
    } else {
      content = const Center(child: Text("Tone Adjuster Coming Soon!"));
    }

    return Scaffold(
      backgroundColor: kBgCream,
      appBar: AppBar(
        title: const Text(
          'Chat Analysis',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: Colors.black87,
          ),
        ),
        elevation: 0,
        backgroundColor: kBgCream,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Message from Carlo:",
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              margin: const EdgeInsets.only(bottom: 16, top: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF6E3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(_latestMessage, style: const TextStyle(fontSize: 15)),
            ),
            Row(
              children: [
                _TabButton(
                  text: "Emotion\nAnalysis",
                  selected: _selectedTab == 0,
                  onTap: () => setState(() => _selectedTab = 0),
                ),
                _TabButton(
                  text: "Response\nSuggestion",
                  selected: _selectedTab == 1,
                  onTap: () => setState(() => _selectedTab = 1),
                ),
                _TabButton(
                  text: "Tone Adjuster",
                  selected: _selectedTab == 2,
                  onTap: () => setState(() => _selectedTab = 2),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(child: content),
          ],
        ),
      ),
    );
  }
}

// Separated Emotion Analysis widget
class EmotionAnalysis extends StatelessWidget {
  const EmotionAnalysis({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Scaffold(
        appBar: AppBar(title: Text('Emotion Analysis')),
        body: EmotionAnalysisLoader(
          analysisApiUrl: 'http://localhost:11434', // Your API endpoint
        ),
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  final String text;
  final bool selected;
  final VoidCallback onTap;
  const _TabButton({
    required this.text,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Flexible(
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 2),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          decoration: BoxDecoration(
            color: selected ? Colors.blue : Colors.grey[200],
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: selected ? Colors.white : Colors.black87,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
        ),
      ),
    );
  }
}

// Response suggestion screen
class ResponseSuggestionScreen extends StatelessWidget {
  const ResponseSuggestionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBgCream,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          ResponseSuggestionCard(
            title: "Polite",
            tone: "Friendly",
            message:
                "Thank you for letting me know. I appreciate your honesty!",
          ),
          ResponseSuggestionCard(
            title: "Curious",
            tone: "Inquisitive",
            message: "Oh really? What changed your mind?",
          ),
        ],
      ),
    );
  }
}
