import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/badge_model.dart';
import '../config/api_config.dart';

class BadgeService {
  Future<List<BadgeModel>> fetchUserBadges(String userId) async {
    final url = ApiConfig.getUserBadges(userId);
    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((item) => BadgeModel.fromJson(item)).toList();
    } else {
      print('❌ BadgeService Error: ${response.body}');
      throw Exception('Failed to fetch badges');
    }
  }
}
