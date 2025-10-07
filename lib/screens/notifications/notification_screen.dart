import 'package:flutter/material.dart';
import 'notification_card.dart';
import '../../utils/auth_utils.dart';
import '../../controllers/badge_controller.dart';
import '../../controllers/reading_content_controller.dart';
import '../../services/session_service.dart';
import '../../services/api_service.dart';
import '../../services/scenario_service.dart';

enum ActivityType { badgeEarned, moduleCompleted, levelReached, courseStarted, scenarioCompleted }

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  _NotificationScreenState createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final BadgeController _badgeController = BadgeController();
  final ReadingProgressController _progressController = ReadingProgressController();
  final APIService _apiService = APIService();
  List<Map<String, dynamic>> _activities = [];
  bool isLoading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _loadActivities();
  }

  Future<void> _loadActivities() async {
    try {
      setState(() {
        isLoading = true;
        error = null;
      });

      final userId = await AuthUtils.getSafeUserId();
      if (userId == null) {
        setState(() {
          error = 'User not authenticated';
          isLoading = false;
        });
        return;
      }

      // Get user's mobile number for reading progress
      final mobileNumber = await SimpleSessionService.getUserPhone();

      List<Map<String, dynamic>> activityItems = [];

      // 1. Load badge achievements
      final achievements = await _badgeController.getUserBadges(userId);

      // Transform each achievement into activity item with specific titles
      for (var a in achievements) {
        final bool isLevelBadge =
            (a.title.toLowerCase().contains('bronze') ||
             a.title.toLowerCase().contains('silver') ||
             a.title.toLowerCase().contains('gold') ||
             a.title.toLowerCase().contains('level'));

        // All badges from BadgeController should be shown as either level or badge earned
        ActivityType type;
        if (isLevelBadge) {
          type = ActivityType.levelReached;
        } else {
          // All other badges are badge achievements
          type = ActivityType.badgeEarned;
        }

        activityItems.add({
          'type': type,
          'title': a.title,
          'description': a.description,
          'date': a.attainedTime,
        });
      }

      // 2. Load completed books/modules
      if (mobileNumber != null) {
        try {
          final allProgress = await _progressController.fetchAllProgress(mobileNumber);
          
          // Filter only completed readings
          final completedProgress = allProgress.entries
              .where((entry) => entry.value.isCompleted)
              .toList();

          // Fetch all readings once to get book titles
          final allReadings = await _apiService.fetchAllReadings();
          
          // Create a map for quick lookup
          final readingsMap = {
            for (var reading in allReadings) reading.id: reading
          };

          // Fetch reading details for each completed book
          for (var entry in completedProgress) {
            try {
              final readingId = entry.key;
              final progress = entry.value;
              
              // Get the book details from the map
              final reading = readingsMap[readingId];
              
              if (reading != null) {
                // Parse completion date
                DateTime? completedDate;
                if (progress.completedAt != null) {
                  try {
                    completedDate = DateTime.parse(progress.completedAt!);
                  } catch (e) {
                    completedDate = DateTime.now();
                  }
                }

                activityItems.add({
                  'type': ActivityType.moduleCompleted,
                  'title': reading.title,
                  'description': 'Book/Module completed',
                  'date': completedDate ?? DateTime.now(),
                });
              }
            } catch (e) {
              print('Error processing completed reading: $e');
            }
          }
        } catch (e) {
          print('Error loading completed books: $e');
        }
      }

      // 3. Load completed scenarios
      try {
        final completedScenarios = await ScenarioService.getCompletedScenarios(userId);
        
        // Fetch all scenarios to get titles
        final allScenariosResponse = await ScenarioService.getScenarios();
        
        // Create a map for quick lookup - scenarios are returned as Map<String, dynamic>
        final scenariosMap = <int, Map<String, dynamic>>{};
        for (var scenario in allScenariosResponse) {
          final id = scenario['id'] as int?;
          if (id != null) {
            scenariosMap[id] = scenario;
          }
        }

        for (var completion in completedScenarios) {
          try {
            final scenarioId = completion['scenario_id'] as int?;
            final completedAtStr = completion['completed_at'] as String?;
            
            if (scenarioId != null) {
              final scenario = scenariosMap[scenarioId];
              
              // Parse completion date
              DateTime? completedDate;
              if (completedAtStr != null) {
                try {
                  completedDate = DateTime.parse(completedAtStr);
                } catch (e) {
                  completedDate = DateTime.now();
                }
              }

              activityItems.add({
                'type': ActivityType.scenarioCompleted,
                'title': scenario?['title'] as String? ?? 'Scenario $scenarioId',
                'description': 'Scenario completed',
                'date': completedDate ?? DateTime.now(),
              });
            }
          } catch (e) {
            print('Error processing completed scenario: $e');
          }
        }
      } catch (e) {
        print('Error loading completed scenarios: $e');
      }

      // Sort by date (most recent first)
      activityItems.sort((a, b) => (b['date'] as DateTime).compareTo(a['date'] as DateTime));

      setState(() {
        _activities = activityItems;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        error = 'Failed to load activities: ${e.toString()}';
        isLoading = false;
      });
    }
  }

  String _getActivityTitle(ActivityType type) {
    switch (type) {
      case ActivityType.levelReached:
        return 'You Have Leveled Up!';
      case ActivityType.badgeEarned:
        return 'Badge Acquired';
      case ActivityType.moduleCompleted:
        return 'Module Completed';
      case ActivityType.scenarioCompleted:
        return 'Scenario Completed';
      case ActivityType.courseStarted:
        return 'Course Started';
    }
  }

  String _getActivityMessage(ActivityType type, String title, String description) {
    switch (type) {
      case ActivityType.badgeEarned:
        return 'You earned the "$title" badge!';
      case ActivityType.moduleCompleted:
        // Check if it's from a book completion (description contains "Book/Module completed")
        if (description.contains('Book/Module completed')) {
          return "You've completed the module \"$title\"";
        }
        // For badge-based module completions
        if (description.isNotEmpty && !description.contains('Book/Module')) {
          return 'You completed: $title - $description';
        }
        return "You've completed the module \"$title\"";
      case ActivityType.scenarioCompleted:
        return "You've completed the scenario \"$title\"";
      case ActivityType.levelReached:
        return 'You reached $title!';
      case ActivityType.courseStarted:
        return 'You started: $title';
    }
  }

  String _formatTimeAgo(DateTime createdAt) {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inDays >= 14) {
      final weeks = (difference.inDays / 7).floor();
      return '$weeks week${weeks == 1 ? '' : 's'} ago';
    } else if (difference.inDays >= 1) {
      return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
    } else if (difference.inHours >= 1) {
      return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
    } else if (difference.inMinutes >= 1) {
      return '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago';
    } else {
      return 'Just now';
    }
  }

  Widget _buildNotificationsList() {
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Error: $error',
              style: const TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadActivities,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_activities.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadActivities,
        child: ListView(
          children: const [
            SizedBox(height: 100),
            Center(
              child: Text(
                'No notifications yet',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadActivities,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _activities.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final activity = _activities[index];
          final type = activity['type'] as ActivityType;
          final title = activity['title'] as String;
          final description = activity['description'] as String;
          final date = activity['date'] as DateTime;
          
          return NotificationCard(
            title: _getActivityTitle(type),
            description: _getActivityMessage(type, title, description),
            time: _formatTimeAgo(date),
          );
        },
      ),
    );
  }

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
          
          // Main content
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        icon: const Icon(
                          Icons.arrow_back_ios,
                          color: Colors.black,
                          size: 20,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Notifications',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Notifications list
                Expanded(
                  child: _buildNotificationsList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}