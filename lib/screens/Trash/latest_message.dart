import 'package:flutter/material.dart';

class LatestMessageBox extends StatelessWidget {
  final String latestMessageText;

  const LatestMessageBox({super.key, required this.latestMessageText});

  @override
  Widget build(BuildContext context) {
    String messageToDisplay = latestMessageText.isNotEmpty
        ? latestMessageText
        : "Message not available.";

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      margin: const EdgeInsets.only(bottom: 16, top: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF6E3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(messageToDisplay, style: const TextStyle(fontSize: 15)),
    );
  }
}
