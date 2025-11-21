import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/stats_model.dart';

class StatsService {
  static Future<StatsModel> getStats(String userId) async {
    final response = await http.get(
      Uri.parse(ApiConfig.stats(userId)),
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      return StatsModel.fromJson(json);
    } else {
      throw Exception('Failed to load user stats');
    }
  }
}
