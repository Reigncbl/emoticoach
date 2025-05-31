import 'package:flutter/material.dart';
import '../utils/api_service.dart';

class LatestMessageBox extends StatelessWidget {
  final String filePath; // Changed constructor parameter
  final APIService _apiService = APIService(); // Added APIService instance

  LatestMessageBox({
    // Constructor updated
    super.key,
    required this.filePath,
  });

  Future<String> _fetchAnalyzedMessageText() async {
    // Method renamed and logic updated
    try {
      final Map<String, dynamic> data = await _apiService.analyzeMessages(
        filePath,
      );

      if (data.containsKey("results")) {
        // Ensure "results" is a List
        if (data["results"] is! List) {
          return 'Error: "results" field is not a list.';
        }
        final List<dynamic> resultsList = data["results"] as List;

        if (resultsList.isNotEmpty) {
          // Ensure the first item is a Map
          if (resultsList.first is! Map<String, dynamic>) {
            return 'Error: First item in "results" is not a valid map.';
          }
          final Map<String, dynamic> firstResult =
              resultsList.first as Map<String, dynamic>;

          if (firstResult.containsKey("text")) {
            return firstResult["text"]?.toString() ?? 'No message text found.';
          } else {
            return 'No message text found in the first result.';
          }
        } else {
          return 'No results found.';
        }
      } else if (data.containsKey("error")) {
        return 'Error from API: ${data["error"]}';
      } else {
        // Check if the entire response is an error structure from APIService itself
        // (e.g. if APIService throws and something catches it and returns a map)
        // This part might be redundant if APIService always throws on HTTP error.
        return 'No message data found in API response.';
      }
    } catch (e) {
      // This will catch errors thrown by APIService (e.g., network issues, HTTP errors)
      // or any other issue within the try block.
      return 'Error fetching message: $e';
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _fetchAnalyzedMessageText(), // Updated future method
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
