import 'dart:async';
import 'dart:developer';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:emoticoach/utils/overlay_bubble_helper.dart';
import 'dart:ui' as ui;

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

      await hideBubble();

      final platformDispatcher = WidgetsBinding.instance.platformDispatcher;
      final ui.FlutterView? view = platformDispatcher.views.isNotEmpty
          ? platformDispatcher.views.first
          : platformDispatcher.implicitView;
      final double deviceWidth = view != null
          ? view.physicalSize.width / view.devicePixelRatio
          : 480.0;
      final double deviceHeight = view != null
          ? view.physicalSize.height / view.devicePixelRatio
          : 800.0;

      final double desiredWidth = (deviceWidth * 0.95).clamp(400.0, 520.0);
      final int overlayWidth = desiredWidth.round();
      const int overlayHeight = 550;

      int startX = ((deviceWidth - desiredWidth) / 2).round();
      if (startX < 0) {
        startX = 0;
      }
      int startY = (deviceHeight * 0.15).round();
      if (startY < 0) {
        startY = 0;
      }
      final int maxY = (deviceHeight - overlayHeight).round();
      if (maxY >= 0 && startY > maxY) {
        startY = maxY;
      }

      // Show the overlay with the proper entry point
      await FlutterOverlayWindow.showOverlay(
        enableDrag: false,
        overlayTitle: "Emoticoach",
        overlayContent: 'Overlay Enabled',
        flag: OverlayFlag.defaultFlag,
        visibility: NotificationVisibility.visibilityPublic,
        alignment: OverlayAlignment.center,
        positionGravity: PositionGravity.left,
        height: overlayHeight,
        width: overlayWidth,
        startPosition: OverlayPosition(startX.toDouble(), startY.toDouble()),
      );

      log('✅ Overlay shown successfully for Telegram!');
    } catch (e) {
      log('❌ Error showing overlay: $e');
      log('Error type: ${e.runtimeType}');
      await showBubble();
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
