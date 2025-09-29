import '../models/badge_model.dart';
import '../services/badge_service.dart';

class BadgeController {
  final BadgeService _service = BadgeService();

  Future<List<BadgeModel>> getUserBadges(String userId) async {
    return await _service.fetchUserBadges(userId);
  }
}
