import 'package:flutter/material.dart';
import './response.dart';
import '../utils/colors.dart';
import './emotion_analysis_loader.dart';
import './latest_message.dart'; // <-- import your new widget

class OverlayScreen extends StatefulWidget {
  const OverlayScreen({super.key});

  @override
  State<OverlayScreen> createState() => _OverlayScreenState();
}

class _OverlayScreenState extends State<OverlayScreen> {
  int _selectedTab = 0; // 0=Emotion, 1=Response, 2=Tone

  // These are your contact details used for both /messages and /analyze_messages
  final String phone = "9615365763";
  final String firstName = "Carlo";
  final String lastName = "Lorieta";

  @override
  Widget build(BuildContext context) {
    Widget content;
    if (_selectedTab == 0) {
      content = EmotionAnalysis(
        phone: phone,
        firstName: firstName,
        lastName: lastName,
      );
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
            LatestMessageBox(
              messageApiUrl: 'http://10.0.2.2:8000/analyze_messages',
              phone: phone,
              firstName: firstName,
              lastName: lastName,
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

// Separated Emotion Analysis widget, now takes contact info from parent
class EmotionAnalysis extends StatelessWidget {
  final String phone;
  final String firstName;
  final String lastName;

  const EmotionAnalysis({
    super.key,
    required this.phone,
    required this.firstName,
    required this.lastName,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: EmotionAnalysisLoader(
        analysisApiUrl: 'http://10.0.2.2:8000/analyze_messages',
        phone: phone,
        firstName: firstName,
        lastName: lastName,
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

// Response suggestion screen (unchanged)
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
