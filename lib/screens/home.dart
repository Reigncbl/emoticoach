import 'dart:ui';
import '../utils/colors.dart';
import '../utils/user_data_mixin.dart';
import '../utils/auth_utils.dart';
import '../main.dart';
import '../controllers/learning_navigation_controller.dart';
import '../services/telegram_service.dart';
import '../services/session_service.dart';
import '../controllers/badge_controller.dart';
import '../models/badge_model.dart';
import '../models/dailychallenge_model.dart';
import '../services/daily_challenge_api.dart';
import 'notifications/notification_screen.dart';
import 'profile.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with UserDataMixin {
  final TelegramService _telegramService = TelegramService();
  bool _isTelegramAuthenticated = false;

  // == Badge Initialization ==
  final BadgeController _badgeController = BadgeController();
  List<BadgeModel> _recentBadges = [];
  bool _loadingBadges = true;
  bool _showAllBadges = false;

      // == Daily Challenge ==
  final DailyChallengeApi _dailyApi = DailyChallengeApi();
  DailyChallenge? _dailyChallenge;
  bool _dailyLoading = true;
  bool _dailyClaiming = false;
  bool _dailyClaimed = false;
  int? _dailyAwardedXp;
  String? _dailyError;


  @override
  void initState() {
    super.initState();
    loadUserData(); // Using the mixin method
    _loadRecentBadges();
    _checkTelegramAuthentication();
    _loadDailyChallenge();
  }

  // === NAVIGATION FUNCTIONS ===
  void _navigateToNotifications() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const NotificationScreen()),
    );
  }

  Future<void> _loadRecentBadges() async {
    try {
      final userId = await AuthUtils.getSafeUserId();
      if (userId != null) {
        final allBadges = await _badgeController.getUserBadges(userId);
        setState(() {
          _recentBadges = allBadges.take(3).toList(); // show latest 3
          _loadingBadges = false;
        });
      }
    } catch (e) {
      print("Error loading badges: $e");
      setState(() => _loadingBadges = false);
    }
  }
      // ===============================
  //  DAILY CHALLENGE METHODS
  // ===============================
  Future<void> _loadDailyChallenge() async {
    setState(() {
      _dailyLoading = true;
      _dailyError = null;
      _dailyClaimed = false;
      _dailyAwardedXp = null;
    });

    try {
      final ch = await _dailyApi.getTodayChallenge();
      setState(() {
        _dailyChallenge = ch;
        _dailyLoading = false;
      });
    } catch (e) {
      setState(() {
        _dailyError = e.toString();
        _dailyLoading = false;
      });
    }
  }

  Future<void> _onDailyMarkComplete() async {
    if (_dailyChallenge == null || _dailyClaiming || _dailyClaimed) return;

    setState(() {
      _dailyClaiming = true;
      _dailyError = null;
    });

    try {
      final result = await _dailyApi.claimChallenge(_dailyChallenge!.id);

      setState(() {
        _dailyClaimed = true;
        _dailyClaiming = false;
        _dailyAwardedXp = result.awarded;
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.alreadyClaimed
                ? 'Already claimed today. Total XP: ${result.totalXp ?? '-'}'
                : 'Challenge completed! +${result.awarded} XP (Total: ${result.totalXp ?? '-'})',
          ),
        ),
      );
    } catch (e) {
      setState(() {
        _dailyClaiming = false;
        _dailyError = e.toString();
      });
    }
  }

  String _dailyButtonLabel() {
    if (_dailyChallenge == null) return "Let's do it";

    switch (_dailyChallenge!.type) {
      case 'open_learning_tab':
        return 'Go to Learning';
      case 'open_article':
        return 'Read an Article';
      case 'open_book':
        return 'Read a Book';
      case 'start_simulation':
        return 'Start a Simulation';
      default:
        return "Let's do it";
    }
  }

  Future<void> _onDailyActionPressed() async {
    if (_dailyChallenge == null) return;

    final chType = _dailyChallenge!.type;
    final mainScreenState =
        context.findAncestorStateOfType<MainScreenState>();

    if (mainScreenState != null) {
      if (chType == 'open_learning_tab') {
        LearningNavigationController().goToReadings();
        mainScreenState.changeIndex(2);
      } else if (chType == 'open_article' || chType == 'open_book') {
        // For now, go to Readings tab
        LearningNavigationController().goToReadings();
        mainScreenState.changeIndex(2);

        // TODO: auto-open random article/book here if you want
      } else if (chType == 'start_simulation') {
        LearningNavigationController().goToScenarios();
        mainScreenState.changeIndex(2);

        // TODO: auto-start random scenario here if you want
      } else {
        // Fallback: go to Learn tab
        LearningNavigationController().goToReadings();
        mainScreenState.changeIndex(2);
      }
    }

    // Treat going to the correct area as completing the challenge for now
    await _onDailyMarkComplete();
  }


  Future<void> _checkTelegramAuthentication() async {
    try {
      // Wait a bit to ensure Firebase is fully initialized
      await Future.delayed(const Duration(milliseconds: 500));

      // Get user phone number from session
      final phoneNumber = await SimpleSessionService.getUserPhone();
      if (phoneNumber != null) {
        // Get userId from session first (preferred method)
        String? userId = await AuthUtils.getSafeUserId();

        if (userId != null && userId.isNotEmpty) {
          final result = await _telegramService.getMe(userId: userId);

          setState(() {
            _isTelegramAuthenticated = result['id'] != null;
          });

          // Show modal if not authenticated
          if (!_isTelegramAuthenticated && mounted) {
            _showTelegramAuthModal();
          }
        } else {
          print('No valid userId found in session or Firebase');
          setState(() {
            _isTelegramAuthenticated = false;
          });
        }
      } else {
        // No phone number stored; nothing to do.
      }
    } catch (e) {
      print('Error checking Telegram authentication: $e');
      setState(() {
        _isTelegramAuthenticated = false;
      });
    }
  }

  void _showTelegramAuthModal() {
    showDialog(
      context: context,
      barrierDismissible: false, // Prevent dismissing by tapping outside
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icon
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: kBrightBlue.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.telegram, size: 48, color: kBrightBlue),
                ),
                const SizedBox(height: 20),

                // Title
                Text(
                  'Telegram Authentication Required',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: kBlack,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),

                // Description
                Text(
                  'To access EmotiCoach\'s full features including message analysis and AI suggestions, you need to authenticate with Telegram first.',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),

                // Buttons
                Row(
                  children: [
                    OutlinedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: kBrightBlue),
                        padding: const EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 24,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Later',
                        style: TextStyle(
                          color: kBrightBlue,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),

                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          _redirectToProfileForTelegram();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kBrightBlue,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Authenticate',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _redirectToProfileForTelegram() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final mainScreenState = context
          .findAncestorStateOfType<MainScreenState>();

      if (mainScreenState != null) {
        mainScreenState.changeIndex(3);
      } else {
        Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const ProfileScreen()));
      }
    });
  }

  String _formatTimeAgo(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'Just now';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Background Image
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/images/home_bg.png'),
                fit: BoxFit.cover,
              ),
            ),
          ),
          // Content
          SafeArea(
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          userGreeting,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                            color: kBlack,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: _navigateToNotifications,
                        child: Icon(
                          Icons.notifications_outlined,
                          color: kBlack,
                          size: 28,
                        ),
                      ),
                    ],
                  ),
                ),
                // Scrollable Content
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Daily Challenge Card
                        if (_dailyLoading)
                          const Text(
                            'Loading daily challenge...',
                            style: TextStyle(color: Colors.black54),
                          )
                        else if (_dailyError != null)
                          Text(
                            'Failed to load daily challenge: $_dailyError',
                            style: const TextStyle(color: Colors.red, fontSize: 14),
                          )
                        else if (_dailyChallenge == null)
                          const Text(
                            'No daily challenge for today.',
                            style: TextStyle(color: Colors.black54),
                          )
                        else
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: const BorderRadius.only(
                                topRight: Radius.circular(18),
                                bottomRight: Radius.circular(18),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.15),
                                  blurRadius: 12,
                                  spreadRadius: 2,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: const BorderRadius.only(
                                topRight: Radius.circular(18),
                                bottomRight: Radius.circular(18),
                              ),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.centerLeft,
                                      end: Alignment.centerRight,
                                      colors: [
                                        Colors.white,
                                        Colors.white.withOpacity(0.6),
                                      ],
                                    ),
                                    border: const Border(
                                      left: BorderSide(
                                        color: kDailyChallengeRed,
                                        width: 5,
                                      ),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: const [
                                          Icon(
                                            Icons.flag,
                                            color: kDailyChallengeRed,
                                          ),
                                          SizedBox(width: 8),
                                          Text(
                                            'Daily Challenge',
                                            style: TextStyle(
                                              color: kDailyChallengeRed,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 18,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        _dailyChallenge!.title,
                                        style: const TextStyle(
                                          color: Colors.black87,
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      if (_dailyChallenge!.description != null &&
                                          _dailyChallenge!.description!.isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          _dailyChallenge!.description!,
                                          style: const TextStyle(
                                            color: Colors.black87,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                      const SizedBox(height: 8),
                                      Text(
                                        '+${_dailyChallenge!.xpReward} XP',
                                        style: const TextStyle(
                                          color: Colors.green,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      SizedBox(
                                        width: double.infinity,
                                        child: ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                                _dailyClaimed ? Colors.grey : kDailyChallengeRed,
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 10,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(
                                                12,
                                              ),
                                            ),
                                            elevation: 0,
                                          ),
                                          onPressed:
                                              _dailyClaimed || _dailyClaiming ? null : _onDailyActionPressed,
                                          child: Text(
                                            _dailyClaimed
                                                ? 'Completed${_dailyAwardedXp != null ? ' (+$_dailyAwardedXp XP)' : ''}'
                                                : (_dailyClaiming ? 'Loading...' : _dailyButtonLabel()),
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),

                        const SizedBox(height: 25),


                        const SizedBox(height: 25),


                        // Practice Chat & Learn
                        Row(
                          children: [
                            // Practice Chat Button
                            Expanded(
                              child: GestureDetector(
                                onTap: () {
                                  // Navigate to Learning tab (index 2) - Scenarios
                                  final mainScreenState = context
                                      .findAncestorStateOfType<
                                        MainScreenState
                                      >();
                                  if (mainScreenState != null) {
                                    LearningNavigationController()
                                        .goToScenarios();
                                    mainScreenState.changeIndex(2);
                                  }
                                },
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(18),
                                    child: BackdropFilter(
                                      filter: ImageFilter.blur(
                                        sigmaX: 5,
                                        sigmaY: 5,
                                      ),
                                      child: Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.3),
                                        ),
                                        child: QuickAction(
                                          icon: Icons.chat_bubble_outline,
                                          label: 'Practice Chat',
                                          subtitle: 'Simulate Conversations',
                                          iconBgColor: kPastelBlue,
                                          iconColor: kDarkerBlue,
                                          labelColor: kDarkerBlue,
                                          onTap: () {
                                            // Navigate to Learning tab (index 2) - Scenarios
                                            final mainScreenState = context
                                                .findAncestorStateOfType<
                                                  MainScreenState
                                                >();
                                            if (mainScreenState != null) {
                                              LearningNavigationController()
                                                  .goToScenarios();
                                              mainScreenState.changeIndex(2);
                                            }
                                          },
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            // Learn Button
                            Expanded(
                              child: GestureDetector(
                                onTap: () {
                                  // Navigate to Learn tab (index 2) - Readings
                                  final mainScreenState = context
                                      .findAncestorStateOfType<
                                        MainScreenState
                                      >();
                                  if (mainScreenState != null) {
                                    LearningNavigationController()
                                        .goToReadings();
                                    mainScreenState.changeIndex(2);
                                  }
                                },
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(18),
                                    child: BackdropFilter(
                                      filter: ImageFilter.blur(
                                        sigmaX: 5,
                                        sigmaY: 5,
                                      ),
                                      child: Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.3),
                                        ),
                                        child: QuickAction(
                                          icon: Icons.menu_book_outlined,
                                          label: 'Learn',
                                          subtitle: 'Articles & Books',
                                          iconBgColor: kPastelRed,
                                          iconColor: kBrightOrange,
                                          labelColor: kBrightOrange,
                                          onTap: () {
                                            // Navigate to Learn tab (index 2) - Readings
                                            final mainScreenState = context
                                                .findAncestorStateOfType<
                                                  MainScreenState
                                                >();
                                            if (mainScreenState != null) {
                                              LearningNavigationController()
                                                  .goToReadings();
                                              mainScreenState.changeIndex(2);
                                            }
                                          },
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Your Activity',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Activity Cards
                        SizedBox(
                          height: 220,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            children: [
                              Container(
                                width: 230,
                                margin: const EdgeInsets.only(right: 12),
                                child: _ActivityCard(
                                  gradient: LinearGradient(
                                    begin: Alignment.centerLeft,
                                    end: Alignment.centerRight,
                                    colors: [kDarkBlue, kPastelBlue],
                                  ),
                                  title: 'Dealing with Office Conflict',
                                  type: 'Scenario',
                                  icon: Icons.psychology_alt,
                                  buttonText: 'Replay Scenario',
                                  onButtonPressed: () {},
                                  height: 200,
                                ),
                              ),
                              Container(
                                width: 230,
                                child: _ActivityCard(
                                  gradient: LinearGradient(
                                    begin: Alignment.centerLeft,
                                    end: Alignment.centerRight,
                                    colors: [kDarkOrange, kPastelOrange],
                                  ),
                                  title:
                                      'Developing Effective Communication Skills',
                                  type: 'Article',
                                  icon: Icons.person_search,
                                  buttonText: 'Continue Reading',
                                  progress: 0.6,
                                  onButtonPressed: () {},
                                  height: 200,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        // Recent Achievements Section with slide-down View All
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Recent Achievements',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                    color: Colors.black87,
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _showAllBadges = !_showAllBadges;
                                    });
                                  },
                                  child: Text(
                                    _showAllBadges ? 'Show Less' : 'View All',
                                    style: const TextStyle(
                                      color: kPrimaryBlue,
                                      fontWeight: FontWeight.w500,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            if (_loadingBadges)
                              const Center(child: CircularProgressIndicator())
                            else if (_recentBadges.isEmpty)
                              const Text(
                                'No achievements yet. Complete a reading or scenario!',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 14,
                                ),
                              )
                            else
                              Column(
                                children:
                                    (_showAllBadges
                                            ? _recentBadges
                                            : _recentBadges.take(3).toList())
                                        .map((badge) {
                                          return Padding(
                                            padding: const EdgeInsets.only(
                                              bottom: 12,
                                            ),
                                            child: AchievementCard(
                                              // Use backend badge image if available
                                              icon: Icons.emoji_events,
                                              iconBgColor: const Color(
                                                0xFFCADCF3,
                                              ),
                                              iconColor: kBrightBlue,
                                              title: badge.title,
                                              subtitle: badge.description,
                                              timeAgo: _formatTimeAgo(
                                                badge.attainedTime,
                                              ),
                                            ),
                                          );
                                        })
                                        .toList(),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
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

// Quick Action Button (Practice Chat, Learn)
class QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color iconBgColor;
  final Color iconColor;
  final Color labelColor;
  final VoidCallback onTap;

  const QuickAction({
    super.key,
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.iconBgColor,
    required this.iconColor,
    required this.labelColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircleAvatar(
            backgroundColor: iconBgColor,
            radius: 33,
            child: Icon(icon, color: iconColor, size: 28),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: labelColor,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(fontSize: 13, color: Colors.black87),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// Activity Card
class _ActivityCard extends StatelessWidget {
  final Color? color;
  final Gradient? gradient;
  final String title;
  final String type;
  final IconData icon;
  final String buttonText;
  final double? progress;
  final VoidCallback onButtonPressed;
  final int height;

  const _ActivityCard({
    this.color,
    this.gradient,
    required this.title,
    required this.type,
    required this.icon,
    required this.buttonText,
    required this.onButtonPressed,
    required this.height,
    this.progress,
  }) : assert(
         color != null || gradient != null,
         'Either color or gradient must be provided',
       );

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height.toDouble(),
      decoration: BoxDecoration(
        color: gradient == null ? color : null,
        gradient: gradient,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
          const Spacer(),
          Align(
            alignment: Alignment.bottomRight,
            child: Icon(icon, color: Colors.white, size: 60),
          ),
          Row(
            children: [
              if (progress != null)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "${(progress! * 100).round()}%",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: color ?? kDarkerBlue,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                          vertical: 8,
                          horizontal: 24,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      onPressed: onButtonPressed,
                      child: Text(
                        buttonText,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              if (progress == null)
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: color ?? kDarkerBlue,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  onPressed: onButtonPressed,
                  child: Text(
                    buttonText,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class AchievementCard extends StatelessWidget {
  final IconData icon;
  final Color iconBgColor;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String timeAgo;
  final String? badgeImageUrl;

  const AchievementCard({
    super.key,
    required this.icon,
    required this.iconBgColor,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.timeAgo,
    this.badgeImageUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFCADDF3).withOpacity(0.18),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          // 🟢 Show badge image if available, fallback to icon
          CircleAvatar(
            backgroundColor: iconBgColor,
            radius: 22,
            backgroundImage:
                (badgeImageUrl != null && badgeImageUrl!.isNotEmpty)
                ? NetworkImage(badgeImageUrl!)
                : null,
            child: (badgeImageUrl == null || badgeImageUrl!.isEmpty)
                ? Icon(icon, color: iconColor, size: 26)
                : null,
          ),
          const SizedBox(width: 12),

          // 🟢 Text content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: iconColor,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(color: Colors.black87, fontSize: 13),
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          // 🟢 Time label
          Text(
            timeAgo,
            style: const TextStyle(color: Colors.black54, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
