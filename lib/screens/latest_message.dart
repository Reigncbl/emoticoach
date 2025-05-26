import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class LatestMessageBox extends StatelessWidget {
  final String phone;
  final String firstName;
  final String lastName;
  final String messageApiUrl;

  const LatestMessageBox({
    super.key,
    required this.phone,
    required this.firstName,
    required this.lastName,
    required this.messageApiUrl,
  });

  Future<String> _fetchLatestMessage() async {
    final Uri url = Uri.parse(messageApiUrl);
    final Map<String, dynamic> requestBody = {
      "phone": phone,
      "first_name": firstName,
      "last_name": lastName,
    };
    try {
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
          return '${firstMsg["text"]}';
        } else if (data.containsKey("error")) {
          return 'Error: ${data["error"]}';
        } else {
          return 'No messages found.';
        }
      } else {
        return 'Failed to fetch message. Status: ${response.statusCode}';
      }
    } catch (e) {
      return 'Error: $e';
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _fetchLatestMessage(),
      builder: (context, snapshot) {
        String message;
        if (snapshot.connectionState == ConnectionState.waiting) {
          message = "Loading latest message...";
        } else if (snapshot.hasError) {
          message = "Error: ${snapshot.error}";
        } else {
          message = snapshot.data ?? "No message";
        }
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          margin: const EdgeInsets.only(bottom: 16, top: 2),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF6E3),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(message, style: const TextStyle(fontSize: 15)),
        );
      },
    );
  }
}
