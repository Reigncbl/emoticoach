import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class LocalNotificationService {
  LocalNotificationService._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;
  static const String _channelId = 'activity_updates';
  static const String _channelName = 'Activity Updates';
  static const String _channelDescription =
      'Notifications triggered by new Emoticoach activity.';

  static Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');

    final initSettings =
        const InitializationSettings(android: androidInit);

    await _plugin.initialize(initSettings);
    await _ensurePlatformPermissions();
    _initialized = true;
  }

  static Future<void> _ensurePlatformPermissions() async {
    if (!kIsWeb) {
      switch (defaultTargetPlatform) {
        case TargetPlatform.android:
          final androidSpecific =
              _plugin.resolvePlatformSpecificImplementation<
                  AndroidFlutterLocalNotificationsPlugin>();
          await androidSpecific?.requestNotificationsPermission();
          await androidSpecific?.createNotificationChannel(
            const AndroidNotificationChannel(
              _channelId,
              _channelName,
              description: _channelDescription,
              importance: Importance.high,
            ),
          );
          break;
        case TargetPlatform.iOS:
          final appleSpecific = _plugin
              .resolvePlatformSpecificImplementation<
                  IOSFlutterLocalNotificationsPlugin>();
          await appleSpecific?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );
          break;
        default:
          break;
      }
    }
  }

  static Future<void> showActivityNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    await initialize();

    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.high,
      priority: Priority.high,
    );

    const notificationDetails =
        NotificationDetails(android: androidDetails);

    await _plugin.show(id, title, body, notificationDetails);
  }
}
