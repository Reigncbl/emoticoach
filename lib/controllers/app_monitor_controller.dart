import 'dart:async';
import 'dart:developer';
import 'package:flutter/services.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

class AppMonitorController {
  static final AppMonitorController _instance =
      AppMonitorController._internal();
  factory AppMonitorController() => _instance;
  AppMonitorController._internal() {
    _setupMethodChannel();
  }

  static const MethodChannel _platform = MethodChannel('emoticoach_service');
  static const MethodChannel _overlayChannel = MethodChannel(
    'emoticoach_overlay_channel',
  );

  bool _isMonitoring = false;
  bool _overlayEnabled = true;

  // Telegram package names to monitor
  static const List<String> telegramPackages = [
    'org.telegram.messenger',
    'org.telegram.plus',
    'org.thunderdog.challegram',
    'nekox.messenger',
    'org.telegram.messenger.web',
  ];

  bool get isMonitoring => _isMonitoring;
  bool get overlayEnabled => _overlayEnabled;

  void _setupMethodChannel() {
    // Listen for overlay trigger from native service
    _overlayChannel.setMethodCallHandler((call) async {
      if (call.method == 'showOverlay') {
        log('Received overlay trigger from native service');
        await _onTelegramOpened();
      }
    });
  }

  void setOverlayEnabled(bool enabled) {
    _overlayEnabled = enabled;
    log('Overlay enabled set to: $enabled');
  }

  Future<bool> requestUsageStatsPermission() async {
    try {
      final bool hasPermission = await _platform.invokeMethod(
        'hasUsageStatsPermission',
      );
      if (!hasPermission) {
        await _platform.invokeMethod('requestUsageStatsPermission');
        return await _platform.invokeMethod('hasUsageStatsPermission');
      }
      return true;
    } catch (e) {
      log('Error requesting usage stats permission: $e');
      return false;
    }
  }

  Future<void> startMonitoring() async {
    if (_isMonitoring) {
      log('Already monitoring apps');
      return;
    }

    try {
      final bool hasPermission = await requestUsageStatsPermission();
      if (!hasPermission) {
        log('Usage stats permission not granted');
        return;
      }

      // Start the native foreground service
      await _platform.invokeMethod('startMonitoringService');
      _isMonitoring = true;
      log('Started native monitoring service for Telegram app launches');
    } catch (e) {
      log('Error starting app monitoring: $e');
    }
  }

  Future<void> _onTelegramOpened() async {
    log('_onTelegramOpened called - overlayEnabled: $_overlayEnabled');

    if (!_overlayEnabled) {
      log('Overlay is disabled, not showing');
      return;
    }

    try {
      // Check if overlay is already active
      final bool isActive = await FlutterOverlayWindow.isActive();
      log('Checking if overlay is active: $isActive');

      if (isActive) {
        log('Overlay already active, not showing again');
        return;
      }

      log('Attempting to show overlay...');

      // Show the overlay with the proper entry point
      await FlutterOverlayWindow.showOverlay(
        enableDrag: true,
        overlayTitle: "Emoticoach",
        overlayContent: 'Overlay Enabled',
        flag: OverlayFlag.defaultFlag,
        visibility: NotificationVisibility.visibilityPublic,
        alignment: OverlayAlignment.topLeft,
        positionGravity: PositionGravity.left,
        height: 200,
        width: 200,
        startPosition: const OverlayPosition(0, 300),
      );

      log('✅ Overlay shown successfully for Telegram!');
    } catch (e) {
      log('❌ Error showing overlay: $e');
      log('Error type: ${e.runtimeType}');
    }
  }

  Future<void> stopMonitoring() async {
    if (!_isMonitoring) {
      return;
    }

    try {
      await _platform.invokeMethod('stopMonitoringService');
      _isMonitoring = false;
      log('Stopped native monitoring service');
    } catch (e) {
      log('Error stopping app monitoring: $e');
    }
  }

  // Method to manually trigger Telegram detection for testing
  Future<void> simulateTelegramLaunch() async {
    log('Simulating Telegram launch for testing');
    await _onTelegramOpened();
  }

  // Method to trigger overlay from external calls (like method channel)
  Future<void> triggerOverlay() async {
    log('Overlay triggered externally');
    await _onTelegramOpened();
  }

  void dispose() {
    stopMonitoring();
  }
}
