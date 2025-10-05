import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class UserService {
  Future<void> deleteAccount(String userId) async {
    final url = Uri.parse(ApiConfig.deleteUser(userId)); 
    final response = await http.delete(url);

    if (response.statusCode != 200) {
      throw Exception('Failed to delete account');
    }
  }
}