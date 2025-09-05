import 'package:flutter/material.dart';

// ResponseSuggestionCard Widget
class ResponseSuggestionCard extends StatelessWidget {
  final String title;
  final String tone;
  final String message;
  final VoidCallback onUse;

  const ResponseSuggestionCard({
    super.key,
    required this.title,
    required this.tone,
    required this.message,
    required this.onUse,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2.0,
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18.0,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8.0),
            Text(
              'Tone: $tone',
              style: const TextStyle(fontStyle: FontStyle.italic),
            ),
            const SizedBox(height: 8.0),
            Text(message),
            const SizedBox(height: 16.0),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton(
                onPressed: onUse,
                child: const Text('Use this'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
