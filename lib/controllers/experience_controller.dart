import '../models/user_experience.dart';
import '../services/experience_service.dart';
import '../services/session_service.dart';

class ExperienceController {
  final ExperienceService service;
  UserExperience? _experience;

  ExperienceController(this.service);

  UserExperience? get experience => _experience;

  Future<void> loadExperience() async {
    final userId = await SimpleSessionService.getFirebaseUid();
    if (userId != null) {
      print('📱 Loading experience for user: $userId');
      _experience = await service.fetchMyExperience(); // Use fetchMyExperience instead
      print('📱 Experience loaded: ${_experience != null}');
    } else {
      print('❌ No user ID found');
    }
  }

  Future<bool> addXp(int amount) async {
    final result = await service.addXp(amount);
    if (result) {
      await loadExperience();
    }
    return result;
  }
}