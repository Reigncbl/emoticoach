import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/readings_models.dart';

class AppBarController {
  final String baseUrl = "http://10.0.2.2:8000";
  Future<AppBarData> fetchAppBar(String readingsId, int currentPage) async {
    final url = Uri.parse('$baseUrl/appbar/$readingsId/$currentPage');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      return AppBarData.fromJson(json.decode(response.body));
    } else {
      throw Exception('Failed to load app bar data');
    }
  }
}