import 'package:flutter/material.dart';
import 'package:iconify_flutter/iconify_flutter.dart';
import 'package:iconify_flutter/icons/ic.dart';
import '../utils/colors.dart';
import '../utils/auth_utils.dart';
import 'settings.dart';
import 'dart:ui';
import '../widgets/telegram_verification_widget.dart';
import '../utils/user_data_mixin.dart';
import '../services/session_service.dart';
import '../services/telegram_service.dart';
import '../controllers/experience_controller.dart';
import '../services/experience_service.dart';
import '../models/user_experience.dart';
late final ExperienceController _xpController;

enum ActivityType { badgeEarned, moduleCompleted, levelReached, courseStarted }

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with UserDataMixin {
  final TelegramService _telegramService = TelegramService();
  final ExperienceController _xpController = ExperienceController(ExperienceService());

  // === TELEGRAM INTEGRATION STATE ===
  bool _isTelegramVerified = false; // Track verification status
  bool _isCheckingTelegramAuth = true; // Track loading state
  String? _userMobileNumber; // Will be loaded from session

  // === NAVIGATION FUNCTIONS ===
  void _navigateToSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SettingsScreen()),
    );
  }

  void _editProfile() {
    print("Edit Profile tapped");
    // Navigate to Edit Profile screen here
  }

  // === TELEGRAM INTEGRATION FUNCTIONS ===
  void _showTelegramVerificationDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          margin: const EdgeInsets.all(16),
          child: TelegramVerificationWidget(
            userMobileNumber: _userMobileNumber,
            onVerificationSuccess: () {
              Navigator.of(context).pop();
              setState(() {
                _isTelegramVerified = true; // Update verification status
              });
              // Refresh the page or show success message
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Telegram connected successfully!'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            onCancel: () {
              Navigator.of(context).pop();
            },
          ),
        ),
      ),
    );
  }
  Future<void> _checkTelegramAuthentication() async {
    try {
      // Get user phone number from session
      final phoneNumber = await SimpleSessionService.getUserPhone();
      if (phoneNumber != null) {
        setState(() {
          _userMobileNumber = phoneNumber;
        });

        print('📞 Checking Telegram status for: $phoneNumber');

        // Get userId using safe method that prioritizes session data
        String? userId = await AuthUtils.getSafeUserId();

        if (userId == null || userId.isEmpty) {
          setState(() {
            _isTelegramVerified = false;
            _isCheckingTelegramAuth = false;
          });
          return;
        }

        // Check Telegram authentication status with timeout handling
        final result = await _telegramService
            .getMe(userId: userId)
            .timeout(
              const Duration(seconds: 10),
              onTimeout: () {
                print('⏰ Telegram status check timed out');
                return {
                  'success': false,
                  'authenticated': false,
                  'error': 'Request timed out',
                };
              },
            );

        print('✅ Telegram status result: $result');

        setState(() {
          _isTelegramVerified = result['id'] != null;
          _isCheckingTelegramAuth = false;
        });
      } else {
        print('❌ No phone number found in session');
        setState(() {
          _isCheckingTelegramAuth = false;
        });
      }
    } catch (e) {
      print('❌ Error checking Telegram authentication: $e');
      setState(() {
        _isTelegramVerified = false;
        _isCheckingTelegramAuth = false;
      });
    }
  }

  void _disconnectTelegram() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Disconnect Telegram'),
        content: const Text(
          'Are you sure you want to disconnect your Telegram account? You will lose access to enhanced features.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              setState(() {
                _isTelegramVerified = false; // Update verification status
              });
              // TODO: Implement actual disconnect logic
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Telegram disconnected'),
                  backgroundColor: Colors.orange,
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text(
              'Disconnect',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  // == SPECIFIC FUNCTIONS ===

  // Keep track of selected badge details
  IconData? selectedIcon;
  String? selectedName;
  String? selectedDescription;
  DateTime? selectedDate;
  String? selectedRarity;

  void _updateSelectedBadge({
    required IconData iconData,
    required String badgeName,
    required String badgeDescription,
    required DateTime dateEarned,
    required String rarityText,
  }) {
    setState(() {
      selectedIcon = iconData;
      selectedName = badgeName;
      selectedDescription = badgeDescription;
      selectedDate = dateEarned;
      selectedRarity = rarityText;
    });
  }

  @override
  void initState() {
    super.initState();
    loadUserData(); // Using the mixin method


    _loadExperience();
    _checkTelegramAuthentication(); // Check Telegram authentication status
  }
   // 👇 place this here
  Future<void> _loadExperience() async {
    await _xpController.loadExperience();
    setState(() {}); 
  }

  // Activity Section Subtitle
  String _formatSubtitle(ActivityType type, String subtitle) {
    switch (type) {
      case ActivityType.badgeEarned:
        return 'Earned "$subtitle" Badge'; // "Apology Master"
      case ActivityType.moduleCompleted:
        return 'Completed "$subtitle" Module'; // "Completed Communication Skills Module"
      case ActivityType.levelReached:
        return 'Reached Level $subtitle'; // "Reached Level 5"
      case ActivityType.courseStarted:
        return 'Started "$subtitle" Course'; // "Started Leadership Course"
    }
  }

  IconData _getActivityIcon(ActivityType type) {
    switch (type) {
      case ActivityType.badgeEarned:
        return Icons.emoji_events; // Trophy icon
      case ActivityType.moduleCompleted:
        return Icons.check_circle; // Checkmark
      case ActivityType.levelReached:
        return Icons.star; // Star for level up
      case ActivityType.courseStarted:
        return Icons.school; // Graduation cap
    }
  }

  // == GLOBAL FUNCTIONS ===

  String _formatDate(DateTime date, {String? action}) {
    final now = DateTime.now();
    final difference = now.difference(date);

    final actionText = action != null ? '$action ' : '';

    if (difference.inDays >= 14) {
      final weeks = (difference.inDays / 7).floor();
      return '$actionText$weeks week${weeks == 1 ? '' : 's'} ago';
    } else if (difference.inDays >= 1) {
      return '$actionText${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
    } else if (difference.inHours >= 1) {
      return '$actionText${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
    } else if (difference.inMinutes >= 1) {
      return '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago';
    } else {
      return 'Just now';
    }
  }

  // === UI HELPERS ===

  // profile card
  Widget _profileCard({required String name, required int level, required String levelName, String? imageUrl,}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [kBrightBlue, kDarkerBlue],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Color(0xFF4A90E2).withOpacity(0.3),
            blurRadius: 15,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          // Profile Avatar
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: CircleAvatar(
              radius: 35,
              backgroundColor: Colors.white.withOpacity(0.3),
              child: Icon(Icons.person_outline, size: 40, color: Colors.white),
            ),
          ),
          const SizedBox(width: 12),

          // Right side content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Name and Telegram Button Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),

                    // Telegram Verification Button
                    GestureDetector(
                      onTap: _isCheckingTelegramAuth
                          ? null
                          : (_isTelegramVerified
                                ? _disconnectTelegram
                                : _showTelegramVerificationDialog),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: _isCheckingTelegramAuth
                              ? Colors.grey.withOpacity(0.2)
                              : (_isTelegramVerified
                                    ? Colors.green.withOpacity(0.2)
                                    : Colors.orange.withOpacity(0.2)),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: _isCheckingTelegramAuth
                                ? Colors.grey.withOpacity(0.5)
                                : (_isTelegramVerified
                                      ? Colors.green.withOpacity(0.5)
                                      : Colors.orange.withOpacity(0.5)),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_isCheckingTelegramAuth)
                              SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.grey.shade100,
                                  ),
                                ),
                              )
                            else
                              Icon(
                                _isTelegramVerified
                                    ? Icons.verified
                                    : Icons.telegram,
                                size: 14,
                                color: _isTelegramVerified
                                    ? Colors.green.shade100
                                    : Colors.orange.shade100,
                              ),
                            const SizedBox(width: 4),
                            Text(
                              _isCheckingTelegramAuth
                                  ? 'Checking...'
                                  : (_isTelegramVerified
                                        ? 'Verified'
                                        : 'Verify'),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: _isCheckingTelegramAuth
                                    ? Colors.grey.shade100
                                    : (_isTelegramVerified
                                          ? Colors.green.shade100
                                          : Colors.orange.shade100),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                // Level Badge
                // Level Badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Use backend image if available, else fallback to star icon
                      if (imageUrl != null)
                      Image.network(
                        imageUrl,
                        height: 20,
                        width: 20,
                      )
                    else
                      Icon(Icons.star_outline, size: 16, color: Colors.white),

                      const SizedBox(width: 6),

                      // Dynamic font color based on level
                      Text(
                        "Level $level: $levelName",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: () {
                            if (level >= 1 && level <= 3) return Colors.brown[400]; // Bronze
                            if (level >= 4 && level <= 6) return Colors.grey[300];  // Silver
                            if (level >= 7 && level <= 10) return Colors.amber[400]; // Gold
                            return Colors.white;
                          }(),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Progress Dashboard
  Widget _progressDashboard({
    required String progressXp,
    required String totalXp,
  }) {
    // Parse XP values for calculation
    int currentXp = int.tryParse(progressXp.replaceAll(',', '')) ?? 0;
    int nextLevelXp = int.tryParse(totalXp.replaceAll(',', '')) ?? 1;
    double progress = currentXp / nextLevelXp;

    return Container(
      padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 20),
      decoration: BoxDecoration(
        color: kWhite.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // XP Values Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'XP: $progressXp',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
              ),
              Text(
                'Next Level: $totalXp',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Progress Bar
          Container(
            height: 8,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              color: Colors.grey.shade300,
            ),
            child: Row(
              children: [
                Expanded(
                  flex: (progress * 100).round(),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      gradient: const LinearGradient(
                        colors: [Colors.orange, Colors.deepOrange],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  flex: 100 - (progress * 100).round(),
                  child: const SizedBox(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Yung 3 cards
  Widget _buildStatCard({
    required String title,
    required String value,
    required Color color,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: 20,
          ),
          decoration: BoxDecoration(
            color: kWhite.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color),
          ),
          child: Column(
            children: [
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: kBlack,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Feedback over time graph
  Widget _feedbackGraph({
    required String feedbackScore,
    required DateTime date,
  }) {
    return Container();
  }

  // Main container widget for the skills graph/progress bar
  Widget _skillsGraphWidget() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: kBrightBlue),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _skillItemWidget(
                skillTitle: 'Active Listening',
                progress: 0.85,
                skillLevel: 'Advanced',
              ),
              const SizedBox(height: 20),
              _skillItemWidget(
                skillTitle: 'Conflict Resolution',
                progress: 0.6,
                skillLevel: 'Intermediate',
              ),
              const SizedBox(height: 20),
              _skillItemWidget(
                skillTitle: 'Empathetic Response',
                progress: 0.95,
                skillLevel: 'Expert',
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Individual skill item component
  Widget _skillItemWidget({
    required String skillTitle,
    required double progress,
    required String skillLevel,
  }) {
    // For right level color
    Color getLevelColor() {
      switch (skillLevel.toLowerCase()) {
        case 'expert':
          return const Color(0xFF4CAF50);
        case 'advanced':
          return const Color(0xFF2196F3);
        case 'intermediate':
          return const Color(0xFFFF9800);
        default:
          return const Color(0xFF757575);
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              skillTitle,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: kBlack,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: getLevelColor().withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                skillLevel,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: getLevelColor(),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          height: 8,
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: progress,
            child: Container(
              decoration: BoxDecoration(
                color: kBrightBlue,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Badge Info Widget
  Widget _badgeInfo({
    required IconData iconData,
    required String badgeName,
    required String badgeDescription,
    required DateTime dateEarned,
    required String rarityText,
    required double rarityPercentage,
    Color? backgroundColor,
    Color? iconColor,
  }) {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: kBrightBlue),
          ),
          child: Column(
            children: [
              // Top row with icon and content
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Icon section
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color:
                          iconColor?.withOpacity(0.1) ??
                          Colors.blue.withOpacity(0.1),
                    ),
                    child: Icon(
                      iconData,
                      size: 24,
                      color: iconColor ?? Colors.blue.shade600,
                    ),
                  ),

                  const SizedBox(width: 16),

                  // Content section
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Badge name and share icon row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              badgeName,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                            Icon(
                              Icons.share_outlined,
                              size: 20,
                              color: Colors.grey.shade600,
                            ),
                          ],
                        ),

                        const SizedBox(height: 4),

                        // Badge description
                        Text(
                          badgeDescription,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade700,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Bottom row with date and rarity (now aligned with icon)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _formatDate(
                      dateEarned,
                      action: 'Earned',
                    ), // e.g. "Earned 1 hour ago",
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    rarityText,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Badge Component
  Widget _badgeComponent({
    required Icon icon,
    required String badgeName,
    required bool status,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: status ? onTap : null, // Only allow tap if badge is earned
      child: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: SizedBox(
            width: 80,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 10),
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: status
                        ? const Color(
                            0xFFE3F2FD,
                          ) // Light blue background when owned
                        : const Color(
                            0xFFE0E0E0,
                          ), // Grey background when unowned
                  ),
                  child: Center(
                    child: Icon(
                      icon.icon,
                      size: 28,
                      color: status
                          ? const Color(0xFF1976D2) // Blue icon when owned
                          : const Color(0xFF9E9E9E), // Grey icon when unowned
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  badgeName,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: status
                        ? const Color(0xFF333333) // Dark text when owned
                        : const Color(0xFF9E9E9E), // Grey text when unowned
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Activity Component
  Widget _activityComponent({
    required Icon icon,
    required ActivityType activityType,
    required String subtitle,
    required DateTime date,
    Color? backgroundColor,
    Color? accentColor,
  }) {
    return ClipRRect(
      // Needed to clip the blur effect properly
      borderRadius: BorderRadius.zero, // No border radius
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          margin: const EdgeInsets.only(
            left: 0,
            right: 0,
          ), // to cancel global padding
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1), // Glass background
            border: Border.all(
              color: Colors.white.withOpacity(0.2), // Light border
              width: 1,
            ),
          ),
          child: Row(
            children: [
              // Icon container
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color:
                      accentColor?.withOpacity(0.8) ??
                      Colors.green.withOpacity(0.8),
                ),
                child: Icon(icon.icon, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 16),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _formatSubtitle(activityType, subtitle),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: kBlack,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatDate(date),
                      style: TextStyle(
                        fontSize: 12,
                        color: kBlack.withOpacity(0.7),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Title Component
  Widget _title({required String title}) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: kBlack,
        ),
      ),
    );
  }

  // === MAIN UI ===
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // === BACKGROUND IMAGE ===
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage("assets/images/bg.png"),
                fit: BoxFit.cover,
              ),
            ),
          ),

          // === MAIN CONTENT ===
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              child: Column(
                children: [
                  // === SETTINGS + EDIT ICONS ===
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      GestureDetector(
                        onTap: _editProfile,
                        child: const Iconify(Ic.edit, size: 28, color: kBlack),
                      ),

                      const SizedBox(width: 4),

                      GestureDetector(
                        onTap: _navigateToSettings,
                        child: const Iconify(
                          Ic.settings,
                          size: 28,
                          color: kBlack,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // === PROFILE HEADER ===
                  _profileCard(
                    name: displayName,
                    level: _xpController.experience?.level ?? 0,
                    levelName: _xpController.experience?.levelName ?? "Unknown",
                    imageUrl: _xpController.experience?.imageUrl,
                  ),



                  const SizedBox(height: 24),

                  // === PROGRESS DASHBOARD ===
                  _title(title: 'Progress Dashboard'),
                  // Progress Dashboard Widget
                  if (_xpController.experience != null)
                    _progressDashboard(
                      progressXp: _xpController.experience!.xp.toString(),
                      totalXp: _xpController.experience!.nextLevelXp?.toString() ?? _xpController.experience!.xp.toString(),
                    )
                  else
                    const CircularProgressIndicator(),

                  // === STATS ROW 1 ===
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          title: 'Scenarios',
                          value: '12',
                          color: kBrightBlue,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildStatCard(
                          title: 'Articles',
                          value: '12',
                          color: kBrightOrange,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildStatCard(
                          title: 'Avg. Score',
                          value: '5',
                          color: kBrightBlue,
                        ),
                      ),
                      const SizedBox(width: 10),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // === BIG GRAPH ===

                  // === KEY SKILLS SECTION ===
                  const SizedBox(height: 12),

                  _title(title: 'Key Skills'),

                  const SizedBox(height: 12),

                  _skillsGraphWidget(),

                  const SizedBox(height: 24),

                  // === BADGES SECTION ===
                  _title(title: 'Badges'),

                  const SizedBox(height: 12),

                  // Badge Component ROW 1
                  Row(
                    children: [
                      Expanded(
                        child: _badgeComponent(
                          icon: const Icon(Icons.emoji_emotions),
                          badgeName: 'Top Performer',
                          status: true,
                          onTap: () => _updateSelectedBadge(
                            iconData: Icons.psychology_outlined,
                            badgeName: 'Top Performer',
                            badgeDescription:
                                'Successfully demonstrated exceptional empathy in 10 difficult scenarios.',
                            dateEarned: DateTime.now().subtract(
                              const Duration(days: 14),
                            ),
                            rarityText: 'Only 12% of users have this',
                          ),
                        ),
                      ),
                      Expanded(
                        child: _badgeComponent(
                          icon: const Icon(Icons.emoji_emotions),
                          badgeName: 'Top Performer',
                          status: true,
                          onTap: () => _updateSelectedBadge(
                            iconData: Icons.psychology_outlined,
                            badgeName: 'Badge 3',
                            badgeDescription:
                                'Successfully demonstrated exceptional empathy in 10 difficult scenarios.',
                            dateEarned: DateTime.now().subtract(
                              const Duration(days: 14),
                            ),
                            rarityText: 'Only 12% of users have this',
                          ),
                        ),
                      ),
                      Expanded(
                        child: _badgeComponent(
                          icon: const Icon(Icons.emoji_emotions),
                          badgeName: 'Top Performer',
                          status: true,
                          onTap: () => _updateSelectedBadge(
                            iconData: Icons.psychology_outlined,
                            badgeName: 'Badge 4',
                            badgeDescription:
                                'Successfully demonstrated exceptional empathy in 10 difficult scenarios.',
                            dateEarned: DateTime.now().subtract(
                              const Duration(days: 14),
                            ),
                            rarityText: 'Only 12% of users have this',
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Badge Component ROW 2
                  Row(
                    children: [
                      Expanded(
                        child: _badgeComponent(
                          icon: const Icon(Icons.emoji_emotions),
                          badgeName: 'Top Performer',
                          status: true,
                          onTap: () => _updateSelectedBadge(
                            iconData: Icons.psychology_outlined,
                            badgeName: 'Badge 6',
                            badgeDescription:
                                'Successfully demonstrated exceptional empathy in 10 difficult scenarios.',
                            dateEarned: DateTime.now().subtract(
                              const Duration(days: 14),
                            ),
                            rarityText: 'Only 12% of users have this',
                          ),
                        ),
                      ),
                      Expanded(
                        child: _badgeComponent(
                          icon: const Icon(Icons.emoji_emotions),
                          badgeName: 'Top Performer',
                          status: true,
                          onTap: () => _updateSelectedBadge(
                            iconData: Icons.psychology_outlined,
                            badgeName: 'Badge 1',
                            badgeDescription:
                                'Successfully demonstrated exceptional empathy in 10 difficult scenarios.',
                            dateEarned: DateTime.now().subtract(
                              const Duration(days: 14),
                            ),
                            rarityText: 'Only 12% of users have this',
                          ),
                        ),
                      ),
                      Expanded(
                        child: _badgeComponent(
                          icon: const Icon(Icons.emoji_emotions),
                          badgeName: 'Top Performer',
                          status: true,
                          onTap: () => _updateSelectedBadge(
                            iconData: Icons.psychology_outlined,
                            badgeName: 'Badge 8',
                            badgeDescription:
                                'Successfully demonstrated exceptional empathy in 10 difficult scenarios.',
                            dateEarned: DateTime.now().subtract(
                              const Duration(days: 14),
                            ),
                            rarityText: 'Only 12% of users have this',
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Badge Info - Show badge info below when selected
                  if (selectedIcon != null &&
                      selectedName != null &&
                      selectedDescription != null &&
                      selectedDate != null &&
                      selectedRarity != null)
                    _badgeInfo(
                      iconData: selectedIcon!,
                      badgeName: selectedName!,
                      badgeDescription: selectedDescription!,
                      dateEarned: selectedDate!,
                      rarityText: selectedRarity!,
                      rarityPercentage: 0,
                    ),

                  const SizedBox(height: 24),

                  // === ACTIVITY SECTION ===
                  _title(title: 'Activity'),

                  const SizedBox(height: 12),

                  _activityComponent(
                    icon: const Icon(Icons.emoji_events),
                    activityType: ActivityType.levelReached,
                    subtitle: 'Level 7',
                    date: DateTime.now().subtract(const Duration(hours: 1)),
                    backgroundColor: Colors.amber.shade50,
                    accentColor: Colors.amber.shade600,
                  ),

                  _activityComponent(
                    icon: const Icon(Icons.emoji_events),
                    activityType: ActivityType.badgeEarned,
                    subtitle: 'Apology Master',
                    date: DateTime.now().subtract(const Duration(hours: 1)),
                    backgroundColor: Colors.amber.shade50,
                    accentColor: Colors.amber.shade600,
                  ),

                  _activityComponent(
                    icon: const Icon(Icons.emoji_events),
                    activityType: ActivityType.badgeEarned,
                    subtitle: 'Apology Master',
                    date: DateTime.now().subtract(const Duration(hours: 1)),
                    backgroundColor: Colors.amber.shade50,
                    accentColor: Colors.amber.shade600,
                  ),

                  _activityComponent(
                    icon: const Icon(Icons.emoji_events),
                    activityType: ActivityType.badgeEarned,
                    subtitle: 'Apology Master',
                    date: DateTime.now().subtract(const Duration(hours: 1)),
                    backgroundColor: Colors.amber.shade50,
                    accentColor: Colors.amber.shade600,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _telegramService.dispose();
    super.dispose();
  }
}
