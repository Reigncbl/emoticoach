import 'package:flutter/material.dart';

class ResponseSuggestionCard extends StatelessWidget {
  final String title;
  final String tone;
  final String message;
  final VoidCallback? onUse;

  const ResponseSuggestionCard({
    super.key,
    required this.title,
    required this.tone,
    required this.message,
    this.onUse,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                Text(
                  tone,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(message),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: onUse,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: const [
                  Icon(Icons.edit, color: Colors.blue, size: 16),
                  SizedBox(width: 4),
                  Text(
                    'Use this',
                    style: TextStyle(color: Colors.blue, fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
