import 'package:flutter/foundation.dart';
import '../utils/temp_api_service.dart'; // Adjust import path as needed

class SuggestionLoader with ChangeNotifier {
  final APIService _apiService = APIService(); // Or pass as dependency

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  List<Map<String, dynamic>> _suggestions = [];
  List<Map<String, dynamic>> get suggestions => _suggestions;

  String? _error;
  String? get error => _error;

  Future<void> loadSuggestions({required String messageFilePath}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _apiService.fetchSuggestions(messageFilePath);
      _suggestions = result.whereType<Map<String, dynamic>>().toList();
      _error = null;
    } catch (e) {
      print('Error in loadSuggestions: $e');
      _error = e.toString();
      _suggestions = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
