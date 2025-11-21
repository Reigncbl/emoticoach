import 'package:flutter/material.dart';
import '../services/stats_service.dart';
import '../models/stats_model.dart';

class StatsController extends ChangeNotifier {
  StatsModel? stats;
  bool loading = false;

  Future<void> loadStats(String userId) async {
    loading = true;
    notifyListeners();

    stats = await StatsService.getStats(userId);

    loading = false;
    notifyListeners();
  }
}
