import 'package:flutter/material.dart';
import 'notification_card.dart';
import '../../controllers/notification_controller.dart';
import '../../models/notification_model.dart';
import '../../utils/auth_utils.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  _NotificationScreenState createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  List<NotificationModel> notifications = [];
  bool isLoading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
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

      final fetchedNotifications = await NotificationService.getUserNotifications(userId);
      setState(() {
        notifications = fetchedNotifications;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        error = 'Failed to load notifications: ${e.toString()}';
        isLoading = false;
      });
    }
  }

  String _getNotificationTitle(String type) {
    switch (type.toLowerCase()) {
      case 'level':
        return 'You Have Leveled Up!';
      case 'badge':
        return 'Badge Acquired';
      case 'module':
        return 'Module Completed';
      default:
        return 'Notification';
    }
  }

  String _getNotificationMessage(String type, String originalMessage) {
    // The originalMessage from the API should already contain the formatted message
    // but we can parse it to extract values if needed
    return originalMessage;
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
              onPressed: _loadNotifications,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (notifications.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadNotifications,
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
      onRefresh: _loadNotifications,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: notifications.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final notification = notifications[index];
          return NotificationCard(
            title: _getNotificationTitle(notification.type),
            description: _getNotificationMessage(notification.type, notification.message),
            time: NotificationService.formatTimeAgo(notification.createdAt),
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