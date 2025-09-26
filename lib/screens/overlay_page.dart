import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import '../utils/colors.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import '../models/overlay_statistics.dart';
import '../services/overlay_stats_service.dart';
import '../utils/overlay_stats_tracker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:developer';

class OverlayScreen extends StatefulWidget {
  const OverlayScreen({super.key});

  @override
  State<OverlayScreen> createState() => _OverlayScreenState();
}

class _OverlayScreenState extends State<OverlayScreen>
    implements OverlayStatsListener {
  // Toggle states for each setting
  bool messagingOverlayEnabled = false;
  bool messageAnalysisEnabled = false;
  bool smartSuggestionsEnabled = false;
  bool toneAdjusterEnabled = false;

  // Platform channel for native overlay integration
  static const MethodChannel _platform = MethodChannel('emoticoach_service');
  bool _isNativeOverlayActive = false;
  bool _isOverlayExpanded =
      false; // Track overlay state: false = bubble, true = expanded

  // Add preference keys
  static const String _messageAnalysisKey = 'message_analysis_enabled';
  static const String _smartSuggestionsKey = 'smart_suggestions_enabled';
  static const String _toneAdjusterKey = 'tone_adjuster_enabled';

  // Dynamic statistics state
  StatisticsPeriod _selectedPeriod = StatisticsPeriod.pastWeek;
  OverlayStatistics? _currentStatistics;
  bool _isLoadingStats = true;

  @override
  void initState() {
    super.initState();
    _loadSettingsAndInitialize();
  }

  Future<void> _loadSettingsAndInitialize() async {
    await _loadSavedSettings();
    await _checkPermissions();
    await _initializeStatistics();
  }

  Future<void> _loadSavedSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        messageAnalysisEnabled = prefs.getBool(_messageAnalysisKey) ?? false;
        smartSuggestionsEnabled = prefs.getBool(_smartSuggestionsKey) ?? false;
        toneAdjusterEnabled = prefs.getBool(_toneAdjusterKey) ?? false;
      });
      debugPrint('Settings loaded from preferences');
    } catch (e) {
      debugPrint('Error loading settings: $e');
    }
  }

  Future<void> _saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_messageAnalysisKey, messageAnalysisEnabled);
      await prefs.setBool(_smartSuggestionsKey, smartSuggestionsEnabled);
      await prefs.setBool(_toneAdjusterKey, toneAdjusterEnabled);
      debugPrint('Settings saved to preferences');

      // Update cache data after saving settings
      await _updateCacheData();
    } catch (e) {
      debugPrint('Error saving settings: $e');
    }
  }

  Future<void> _updateCacheData() async {
    try {
      // Update the configuration with current settings
      final statsService = OverlayStatsService.instance;
      final config = await statsService.getConfig();
      final updatedConfig = config.copyWith(lastRefresh: DateTime.now());

      // Save updated config to cache
      await statsService.saveConfig(updatedConfig);

      // Refresh statistics cache to reflect any changes
      await _loadStatistics();

      debugPrint('Cache data updated after settings change');
    } catch (e) {
      debugPrint('Error updating cache data: $e');
    }
  }

  // Native overlay integration methods
  Future<void> _showNativeOverlay() async {
    try {
      await _platform.invokeMethod('showNativeOverlay');
      setState(() {
        _isNativeOverlayActive = true;
      });
      debugPrint('Native overlay shown successfully');
    } catch (e) {
      debugPrint('Error showing native overlay: $e');
    }
  }

  Future<void> _hideNativeOverlay() async {
    try {
      await _platform.invokeMethod('hideNativeOverlay');
      setState(() {
        _isNativeOverlayActive = false;
        _isOverlayExpanded = false; // Reset to bubble state when hidden
      });
      debugPrint('Native overlay hidden successfully');
    } catch (e) {
      debugPrint('Error hiding native overlay: $e');
    }
  }

  Future<void> _makeOverlayFocusable() async {
    try {
      await _platform.invokeMethod('makeOverlayFocusable');
      debugPrint('Overlay made focusable');
    } catch (e) {
      debugPrint('Error making overlay focusable: $e');
    }
  }

  Future<void> _makeOverlayNonFocusable() async {
    try {
      await _platform.invokeMethod('makeOverlayNonFocusable');
      debugPrint('Overlay made non-focusable');
    } catch (e) {
      debugPrint('Error making overlay non-focusable: $e');
    }
  }

  // New methods for two-state overlay system
  Future<void> _expandOverlay() async {
    try {
      await _platform.invokeMethod('expandOverlay');
      setState(() {
        _isOverlayExpanded = true;
      });
      debugPrint('Overlay expanded successfully');
    } catch (e) {
      debugPrint('Error expanding overlay: $e');
    }
  }

  Future<void> _collapseOverlay() async {
    try {
      await _platform.invokeMethod('collapseOverlay');
      setState(() {
        _isOverlayExpanded = false;
      });
      debugPrint('Overlay collapsed successfully');
    } catch (e) {
      debugPrint('Error collapsing overlay: $e');
    }
  }

  Future<void> _toggleOverlayState() async {
    try {
      await _platform.invokeMethod('toggleOverlayState');
      setState(() {
        _isOverlayExpanded = !_isOverlayExpanded;
      });
      debugPrint('Overlay state toggled successfully');
    } catch (e) {
      debugPrint('Error toggling overlay state: $e');
    }
  }

  Future<void> _checkPermissions() async {
    try {
      // Check overlay permission
      final hasOverlayPermission =
          await FlutterOverlayWindow.isPermissionGranted();

      setState(() {
        messagingOverlayEnabled = hasOverlayPermission;
      });

      debugPrint('Permissions checked - Overlay: $hasOverlayPermission');
    } catch (e) {
      debugPrint('Error checking permissions: $e');
    }
  }

  @override
  void dispose() {
    OverlayStatsTracker.removeListener(this);
    super.dispose();
  }

  Future<void> _initializeStatistics() async {
    try {
      debugPrint('Starting statistics initialization...');
      setState(() {
        _isLoadingStats = true;
      });

      await OverlayStatsTracker.initialize();
      debugPrint('OverlayStatsTracker initialized');

      OverlayStatsTracker.addListener(this);
      debugPrint('Added statistics listener');

      await _loadStatistics();
      debugPrint('Statistics initialization completed');
    } catch (e) {
      debugPrint('Error initializing statistics: $e');
      if (mounted) {
        setState(() {
          _isLoadingStats = false;
        });
      }
    }
  }

  Future<void> _loadStatistics() async {
    try {
      debugPrint('Loading statistics for period: ${_selectedPeriod.name}');
      if (mounted) {
        setState(() {
          _isLoadingStats = true;
        });
      }

      final statistics = await OverlayStatsTracker.getStatistics(
        _selectedPeriod,
      );

      debugPrint(
        'Retrieved statistics: Messages=${statistics.messagesAnalyzed}, Suggestions=${statistics.suggestionsUsed}, Rephrased=${statistics.responsesRephrased}',
      );
      debugPrint(
        'Period: ${statistics.period.name}, Last Updated: ${statistics.lastUpdated}',
      );

      if (mounted) {
        setState(() {
          _currentStatistics = statistics;
          _isLoadingStats = false;
        });
        debugPrint('Statistics loaded and UI updated');
      }
    } catch (e) {
      debugPrint('Error loading statistics: $e');
      if (mounted) {
        setState(() {
          _isLoadingStats = false;
        });
      }
    }
  }

  Future<void> _onPeriodChanged(StatisticsPeriod newPeriod) async {
    if (newPeriod != _selectedPeriod) {
      setState(() {
        _selectedPeriod = newPeriod;
      });
      await _loadStatistics();
    }
  }

  // OverlayStatsListener implementation
  @override
  void onEventRecorded(OverlayUsageEvent event) {
    debugPrint(' Event recorded notification: ${event.type.name}');
    // Reload statistics when new events are recorded
    _loadStatistics();
  }

  @override
  void onStatisticsUpdated(OverlayStatistics statistics) {
    debugPrint('Statistics updated notification: ${statistics.period.name}');
    if (statistics.period == _selectedPeriod && mounted) {
      setState(() {
        _currentStatistics = statistics;
      });
      debugPrint('UI updated with new statistics');
    }
  }

  @override
  void onConfigUpdated(OverlayStatsConfig config) {
    // Handle config updates if needed
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
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
                // AppBar mimic
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          "Messaging Coach",
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                      ),
                      Icon(Icons.info_outline, color: Colors.black54),
                    ],
                  ),
                ),
                // Tab Bar (fix overflow with Flexible and SingleChildScrollView)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildPeriodTab(StatisticsPeriod.today, "Today"),
                        SizedBox(width: 8),
                        _buildPeriodTab(StatisticsPeriod.pastWeek, "Past Week"),
                        SizedBox(width: 8),
                        _buildPeriodTab(
                          StatisticsPeriod.pastMonth,
                          "Past Month",
                        ),
                        SizedBox(width: 8),
                        _buildPeriodTab(StatisticsPeriod.allTime, "All Time"),
                        SizedBox(width: 8),
                        _buildTab(
                          "View Graph",
                          selected: false,
                          outlined: true,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                // Stats Card
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 12,
                          spreadRadius: 2,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            color: Colors.white.withOpacity(0.5),
                          ),
                          child: Builder(
                            builder: (context) {
                              debugPrint(
                                'Building stats card - Loading: $_isLoadingStats, Stats: $_currentStatistics',
                              );

                              if (_isLoadingStats) {
                                debugPrint('Showing loading indicator');
                                return Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(20.0),
                                    child: CircularProgressIndicator(
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        kPrimaryBlue,
                                      ),
                                    ),
                                  ),
                                );
                              } else if (_currentStatistics != null) {
                                return Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceEvenly,
                                  children: [
                                    _statColumn(
                                      "${_currentStatistics!.messagesAnalyzed}",
                                      "Messages Analyzed",
                                      kPrimaryBlue,
                                    ),
                                    _statColumn(
                                      "${_currentStatistics!.suggestionsUsed}",
                                      "Suggestions Used",
                                      kDailyChallengeRed,
                                    ),
                                    _statColumn(
                                      "${_currentStatistics!.responsesRephrased}",
                                      "Rephrased Responses",
                                      kQuoteBlue,
                                    ),
                                  ],
                                );
                              } else {
                                debugPrint('No statistics data available');
                                return Padding(
                                  padding: const EdgeInsets.all(20.0),
                                  child: Text(
                                    'No data available',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 14,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                );
                              }
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                // Overlay Status
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  child: Column(
                    children: [
                      // Flutter Overlay Status
                      FutureBuilder<bool>(
                        future: FlutterOverlayWindow.isActive(),
                        builder: (context, snapshot) {
                          final isOverlayActive = snapshot.data ?? false;

                          return Container(
                            decoration: BoxDecoration(
                              color: kPrimaryBlue,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(
                              vertical: 14,
                              horizontal: 16,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Flutter Overlay Status',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                        ),
                                      ),
                                      SizedBox(height: 2),
                                      Text(
                                        isOverlayActive
                                            ? 'Enabled (Tap icon to disable)'
                                            : 'Disabled (Tap icon to enable)',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                _BounceGlowIcon(
                                  isActive: isOverlayActive,
                                  onTap: () async {
                                    final isActive =
                                        await FlutterOverlayWindow.isActive();
                                    if (isActive) {
                                      await FlutterOverlayWindow.closeOverlay();
                                    } else {
                                      await FlutterOverlayWindow.showOverlay(
                                        enableDrag: true,
                                        overlayTitle: "Emoticoach",
                                        overlayContent: 'Overlay Enabled',
                                        flag: OverlayFlag.focusPointer,
                                        alignment: OverlayAlignment.topLeft,
                                        positionGravity: PositionGravity.left,
                                        height: 200,
                                        width: 200,
                                        startPosition: const OverlayPosition(
                                          0,
                                          200,
                                        ),
                                      );
                                    }
                                    setState(() {});
                                  },
                                ),
                              ],
                            ),
                          );
                        },
                      ),

                      const SizedBox(height: 10),

                      // Native Overlay Controls
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.purple[600],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(
                          vertical: 14,
                          horizontal: 16,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Native Overlay (Two-State)',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      SizedBox(height: 2),
                                      Text(
                                        _isNativeOverlayActive
                                            ? _isOverlayExpanded
                                                  ? 'Active - Expanded View'
                                                  : 'Active - Bubble View'
                                            : 'Inactive - Tap to show',
                                        style: TextStyle(
                                          color: Colors.white70,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                _BounceGlowIcon(
                                  isActive: _isNativeOverlayActive,
                                  onTap: () async {
                                    if (_isNativeOverlayActive) {
                                      await _hideNativeOverlay();
                                    } else {
                                      await _showNativeOverlay();
                                    }
                                  },
                                ),
                              ],
                            ),

                            if (_isNativeOverlayActive) ...[
                              const SizedBox(height: 12),

                              // State control buttons
                              Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: _isOverlayExpanded
                                          ? _collapseOverlay
                                          : _expandOverlay,
                                      icon: Icon(
                                        _isOverlayExpanded
                                            ? Icons.compress
                                            : Icons.expand,
                                        size: 16,
                                      ),
                                      label: Text(
                                        _isOverlayExpanded
                                            ? 'Collapse'
                                            : 'Expand',
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: _isOverlayExpanded
                                            ? Colors.orange
                                            : Colors.green,
                                        foregroundColor: Colors.white,
                                        padding: EdgeInsets.symmetric(
                                          vertical: 8,
                                        ),
                                        textStyle: TextStyle(fontSize: 12),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: _toggleOverlayState,
                                      icon: Icon(Icons.swap_vert, size: 16),
                                      label: Text('Toggle State'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.blue,
                                        foregroundColor: Colors.white,
                                        padding: EdgeInsets.symmetric(
                                          vertical: 8,
                                        ),
                                        textStyle: TextStyle(fontSize: 12),
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 8),

                              // Focus control buttons
                              Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: _makeOverlayFocusable,
                                      icon: Icon(Icons.keyboard, size: 16),
                                      label: Text('Make Focusable'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.white,
                                        foregroundColor: Colors.purple[600],
                                        padding: EdgeInsets.symmetric(
                                          vertical: 8,
                                        ),
                                        textStyle: TextStyle(fontSize: 12),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: _makeOverlayNonFocusable,
                                      icon: Icon(
                                        Icons.touch_app_outlined,
                                        size: 16,
                                      ),
                                      label: Text('Non-Focusable'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.white70,
                                        foregroundColor: Colors.purple[600],
                                        padding: EdgeInsets.symmetric(
                                          vertical: 8,
                                        ),
                                        textStyle: TextStyle(fontSize: 12),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // Supported App
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      "Supported App",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Colors.blue[100]!),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircleAvatar(
                                backgroundColor: Colors.blue[50],
                                radius: 20,
                                child: Icon(
                                  Icons.telegram,
                                  color: kPrimaryBlue,
                                  size: 40,
                                ),
                              ),
                              const SizedBox(width: 10),
                              const Text("Telegram"),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      "Settings",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      _settingsTile(
                        icon: Icons.search,
                        title: "Messaging Overlay (Flutter)",
                        subtitle: "Enable floating communication coach",
                        switchValue: messagingOverlayEnabled,
                        onChanged: (v) async {
                          if (v) {
                            // Check if permission is already granted
                            final hasPermission =
                                await FlutterOverlayWindow.isPermissionGranted();

                            if (!hasPermission) {
                              // Request permission
                              final bool? res =
                                  await FlutterOverlayWindow.requestPermission();
                              log("Overlay permission request result: $res");

                              if (res == true) {
                                setState(() => messagingOverlayEnabled = true);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Messaging Overlay enabled! You can now use the floating coach.',
                                    ),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              } else {
                                setState(() => messagingOverlayEnabled = false);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Permission denied. Please enable overlay permission in Settings.',
                                    ),
                                    backgroundColor: Colors.red,
                                    action: SnackBarAction(
                                      label: 'Settings',
                                      textColor: Colors.white,
                                      onPressed: () async {
                                        await FlutterOverlayWindow.requestPermission();
                                      },
                                    ),
                                  ),
                                );
                              }
                            } else {
                              setState(() => messagingOverlayEnabled = true);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Messaging Overlay enabled!'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                          } else {
                            setState(() => messagingOverlayEnabled = false);
                            // Close overlay if it's currently shown
                            final isActive =
                                await FlutterOverlayWindow.isActive();
                            if (isActive) {
                              await FlutterOverlayWindow.closeOverlay();
                            }
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Messaging Overlay disabled'),
                                backgroundColor: Colors.orange,
                              ),
                            );
                          }
                        },
                      ),
                      _settingsTile(
                        icon: Icons.layers,
                        title: "Native Overlay (Two-State)",
                        subtitle:
                            "Bubble & expanded views with keyboard support",
                        switchValue: _isNativeOverlayActive,
                        onChanged: (v) async {
                          if (v) {
                            await _showNativeOverlay();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Native overlay enabled! Starts as bubble - tap to expand, long-press for focus mode.',
                                ),
                                backgroundColor: Colors.green,
                                duration: Duration(seconds: 5),
                              ),
                            );
                          } else {
                            await _hideNativeOverlay();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Native overlay disabled'),
                                backgroundColor: Colors.orange,
                              ),
                            );
                          }
                        },
                      ),
                      _settingsTile(
                        icon: Icons.insights,
                        title: "Message Analysis",
                        subtitle: "Detect tone, intent, & emotional cues",
                        switchValue: messageAnalysisEnabled,
                        onChanged: (v) async {
                          setState(() => messageAnalysisEnabled = v);
                          await _saveSettings();

                          // Track configuration change event
                          await OverlayStatsTracker.trackCustomEvent(
                            type: OverlayEventType.messageAnalyzed,
                            metadata: {
                              'setting_changed': 'message_analysis',
                              'enabled': v,
                              'timestamp': DateTime.now().toIso8601String(),
                            },
                          );

                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                v
                                    ? 'Message Analysis enabled'
                                    : 'Message Analysis disabled',
                              ),
                              backgroundColor: v ? Colors.green : Colors.orange,
                            ),
                          );
                        },
                      ),
                      _settingsTile(
                        icon: Icons.lightbulb_outline,
                        title: "Smart Suggestions",
                        subtitle: "Get response recommendations",
                        switchValue: smartSuggestionsEnabled,
                        onChanged: (v) async {
                          setState(() => smartSuggestionsEnabled = v);
                          await _saveSettings();

                          // Track configuration change event
                          await OverlayStatsTracker.trackCustomEvent(
                            type: OverlayEventType.suggestionUsed,
                            metadata: {
                              'setting_changed': 'smart_suggestions',
                              'enabled': v,
                              'timestamp': DateTime.now().toIso8601String(),
                            },
                          );

                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                v
                                    ? 'Smart Suggestions enabled'
                                    : 'Smart Suggestions disabled',
                              ),
                              backgroundColor: v ? Colors.green : Colors.orange,
                            ),
                          );
                        },
                      ),
                      _settingsTile(
                        icon: Icons.tune,
                        title: "Tone Adjuster",
                        subtitle: "Fine-tune message tone with sliders",
                        switchValue: toneAdjusterEnabled,
                        onChanged: (v) async {
                          setState(() => toneAdjusterEnabled = v);
                          await _saveSettings();

                          // Track configuration change event
                          await OverlayStatsTracker.trackCustomEvent(
                            type: OverlayEventType.responseRephrased,
                            metadata: {
                              'setting_changed': 'tone_adjuster',
                              'enabled': v,
                              'timestamp': DateTime.now().toIso8601String(),
                            },
                          );

                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                v
                                    ? 'Tone Adjuster enabled'
                                    : 'Tone Adjuster disabled',
                              ),
                              backgroundColor: v ? Colors.green : Colors.orange,
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 12),
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

  Widget _buildTab(
    String label, {
    bool selected = false,
    bool outlined = false,
  }) {
    if (outlined) {
      return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey[400]!),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Text(
          label,
          style: TextStyle(
            color: Colors.grey[700],
            fontWeight: FontWeight.normal,
            fontSize: 13,
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: selected ? Colors.blue[100] : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Text(
        label,
        style: TextStyle(
          color: selected ? kPrimaryBlue : Colors.grey[700],
          fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          fontSize: 13,
        ),
      ),
    );
  }

  Widget _buildPeriodTab(StatisticsPeriod period, String label) {
    final isSelected = _selectedPeriod == period;

    return GestureDetector(
      onTap: () => _onPeriodChanged(period),
      child: Container(
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue[100] : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? kPrimaryBlue : Colors.grey[700],
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _statColumn(String value, String label, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(color: Colors.black87, fontSize: 11),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _settingsTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool switchValue,
    required ValueChanged<bool> onChanged,
  }) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 7),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(13),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.grey[100],
          child: Icon(icon, color: kPrimaryBlue),
        ),
        title: Text(title, style: TextStyle(fontWeight: FontWeight.w500)),
        subtitle: Text(subtitle, style: TextStyle(fontSize: 13)),
        trailing: Transform.scale(
          scale: 0.6,
          child: Switch(value: switchValue, onChanged: onChanged),
        ),
      ),
    );
  }
}

class _BounceGlowIcon extends StatefulWidget {
  final bool isActive;
  final VoidCallback onTap;

  const _BounceGlowIcon({required this.isActive, required this.onTap});

  @override
  State<_BounceGlowIcon> createState() => _BounceGlowIconState();
}

class _BounceGlowIconState extends State<_BounceGlowIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.elasticOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _triggerAnimation() {
    _controller.forward(from: 0).then((_) => _controller.reverse());
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _triggerAnimation,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              decoration: const BoxDecoration(shape: BoxShape.circle),
              child: Icon(
                widget.isActive ? Icons.flash_on : Icons.flash_off,
                color: Colors.white,
                size: 28,
              ),
            ),
          );
        },
      ),
    );
  }
}
