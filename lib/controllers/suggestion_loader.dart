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
  String? _filePath;
  String? get filePath => _filePath; // Getter for filePath
  // Map<String, dynamic>? _messageData; // Uncomment if needed

  Future<void> loadSuggestions(
    String phone,
    String firstName,
    String lastName,
  ) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Step 1: Fetch messages and path
      final messageDataResponse = await _apiService.fetchMessagesAndPath(
        phone,
        firstName,
        lastName,
      );
      _filePath = messageDataResponse['file_path'];
      // _messageData = messageDataResponse; // Store if needed elsewhere

      if (_filePath == null) {
        _error = "File path not found in /messages response";
        throw Exception(_error);
      }

      // Step 2: Fetch suggestions using the file_path
      _suggestions = await _apiService.fetchSuggestions(_filePath!);
    } catch (e) {
      print('Error in loadSuggestions: $e');
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Optional: A method to load analysis data if needed separately
  // For now, analyzeMessages doesn't need filePath based on current backend
  // Future<Map<String, dynamic>?> loadAnalysis() async {
  //    // _isLoading = true; // Manage loading state for analysis separately if needed
  //    // _error = null;
  //    // notifyListeners();
  //    try {
  //        final analysisData = await _apiService.analyzeMessages();
  //        return analysisData;
  //    } catch (e) {
  //        _error = e.toString(); // Or a specific error state for analysis
  //        // notifyListeners();
  //        return null;
  //    } finally {
  //        // _isLoading = false;
  //        // notifyListeners();
  //    }
  // }
}
