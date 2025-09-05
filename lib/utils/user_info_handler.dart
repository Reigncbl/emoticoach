import 'package:firebase_auth/firebase_auth.dart';
import 'api_handler/user_api.dart';

class UserInfoHandler {
  static Future<String> getDisplayName() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final userData = await UserApi.getUserById(user.uid);
        if (userData != null) {
          final firstName = userData['FirstName'] ?? '';
          final lastName = userData['LastName'] ?? '';
          return '$firstName $lastName'.trim();
        }
      }
      return 'User';
    } catch (e) {
      print('Error getting display name: $e');
      return 'User';
    }
  }

  static String getGreeting(String userName) {
    final hour = DateTime.now().hour;
    String greeting;

    if (hour < 12) {
      greeting = 'Good morning';
    } else if (hour < 17) {
      greeting = 'Good afternoon';
    } else {
      greeting = 'Good evening';
    }

    return '$greeting, $userName!';
  }
}
