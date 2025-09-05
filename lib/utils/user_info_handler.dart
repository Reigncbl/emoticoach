import 'package:firebase_auth/firebase_auth.dart';
import 'api_handler/user_api.dart';
import '../services/session_service.dart';

class UserInfoHandler {
  static Future<String> getDisplayName() async {
    try {
      print('🔍 Getting display name...');

      // First, try to get name from session storage
      if (await SimpleSessionService.isLoggedIn()) {
        print('   ✅ User is logged in, checking session data...');

        final sessionName = await SimpleSessionService.getUserName();
        print('   Session full name: $sessionName');

        if (sessionName != null && sessionName.trim().isNotEmpty) {
          print('   ✅ Found full name in session: $sessionName');
          return sessionName;
        }

        // If full name is not available, try to construct from first and last name
        final firstName = await SimpleSessionService.getUserFirstName();
        final lastName = await SimpleSessionService.getUserLastName();
        print('   Session first name: $firstName');
        print('   Session last name: $lastName');

        if (firstName != null && firstName.trim().isNotEmpty) {
          final fullName = lastName != null && lastName.trim().isNotEmpty
              ? '$firstName $lastName'
              : firstName;
          print('   ✅ Constructed name from session: $fullName');
          return fullName.trim();
        }

        print('   ⚠️ No name data found in session');
      } else {
        print('   ❌ User is not logged in');
      }

      // Fallback to Firebase/backend if session doesn't have name
      print('   🔄 Falling back to Firebase/backend...');
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        print('   ✅ Firebase user found: ${user.uid}');
        final userData = await UserApi.getUserById(user.uid);
        if (userData != null) {
          final firstName = userData['FirstName'] ?? '';
          final lastName = userData['LastName'] ?? '';
          final backendName = '$firstName $lastName'.trim();
          print('   Backend first name: $firstName');
          print('   Backend last name: $lastName');
          print('   Backend full name: $backendName');

          // Save the name to session for future use
          if (backendName.isNotEmpty &&
              await SimpleSessionService.isLoggedIn()) {
            print('   💾 Saving backend name to session...');
            await SimpleSessionService.updateSessionData(
              'user_first_name',
              firstName,
            );
            await SimpleSessionService.updateSessionData(
              'user_last_name',
              lastName,
            );
            await SimpleSessionService.updateSessionData(
              'user_name',
              backendName,
            );
          }

          return backendName.isNotEmpty ? backendName : 'User';
        } else {
          print('   ❌ No user data found in backend');
        }
      } else {
        print('   ❌ No Firebase user found');
      }

      print('   🔄 Returning default: User');
      return 'User';
    } catch (e) {
      print('❌ Error getting display name: $e');
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
