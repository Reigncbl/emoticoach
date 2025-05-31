import 'package:flutter/foundation.dart';
import '../utils/api_service.dart'; // Adjust import path as needed

class SuggestionLoader with ChangeNotifier {
  final APIService _apiService = APIService(); // Or pass as dependency

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  List<Map<String, dynamic>> _suggestions = [];
  List<Map<String, dynamic>> get suggestions => _suggestions;

  String? _error;
  String? get error => _error;

  // Variables to hold message data
  // We no longer need _filePath here as it's passed in loadSuggestions
  // String? _filePath;
  // String? get filePath => _filePath; // Getter for filePath
  // Map<String, dynamic>? _messageData; // Uncomment if needed

  // Modified loadSuggestions to accept messageFilePath
  Future<void> loadSuggestions({
    required String messageFilePath, // Accept messageFilePath
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // We already have the file path, no need to fetch messages again
      // Use the provided messageFilePath to fetch suggestions
      _suggestions = await _apiService.fetchSuggestions(messageFilePath);
    } catch (e) {
      print('Error in loadSuggestions: $e');
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
