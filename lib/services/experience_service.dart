import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/user_experience.dart';
import '../services/session_service.dart';

class ExperienceService {
  /// 🔹 Core method: Fetch experience for any userId
  Future<UserExperience?> fetchExperience(String userId) async {
    try {
      final response = await http.get(
        Uri.parse("${ApiConfig.myExperience}/$userId"),
        headers: {
          "Content-Type": "application/json",
        },
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        return UserExperience.fromJson(json);
      } else {
        print("❌ Error fetching experience: ${response.body}");
        return null;
      }
    } catch (e) {
      print("❌ Exception while fetching experience: $e");
      return null;
    }
  }

  /// 🔹 Wrapper: Fetch current logged-in user’s experience using session UID
  Future<UserExperience?> fetchMyExperience() async {
    final userId = await SimpleSessionService.getFirebaseUid(); // ✅ pull from session
    if (userId == null) {
      print("❌ No UID found. User might not be logged in.");
      return null;
    }
    return fetchExperience(userId); // ✅ call core method
  }

  /// 🔹 Add XP to the current user
  Future<bool> addXp(int amount) async {
    final userId = await SimpleSessionService.getFirebaseUid(); // ✅ pull from session
    if (userId == null) {
      print("❌ No UID found. User might not be logged in.");
      return false;
    }

    try {
      final response = await http.post(
        Uri.parse(ApiConfig.addXp),
        headers: {
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "user_id": userId, // ✅ send UID
          "xp": amount,
        }),
      );

      if (response.statusCode == 200) {
        print("✅ XP added successfully!");
        return true;
      } else {
        print("❌ Failed to add XP: ${response.body}");
        return false;
      }
    } catch (e) {
      print("❌ Exception while adding XP: $e");
      return false;
    }
  }
}
