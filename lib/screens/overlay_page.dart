import 'package:flutter/material.dart';
import 'dart:ui';
import '../utils/colors.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
// import '../controllers/app_monitor_controller.dart'; // Commented out - only used for auto-launch
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
  // bool autoLaunchEnabled = false; // Commented out - not implementing

  // Add preference keys
  static const String _messagingOverlayKey = 'messaging_overlay_enabled';
  static const String _messageAnalysisKey = 'message_analysis_enabled';
  static const String _smartSuggestionsKey = 'smart_suggestions_enabled';
  static const String _toneAdjusterKey = 'tone_adjuster_enabled';
  // static const String _autoLaunchKey = 'auto_launch_enabled'; // Commented out

  // final AppMonitorController _appMonitor = AppMonitorController(); // Commented out - only used for auto-launch

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
        // autoLaunchEnabled = prefs.getBool(_autoLaunchKey) ?? false; // Commented out
      });
      print('✅ Settings loaded from preferences');
    } catch (e) {
      print('❌ Error loading settings: $e');
    }
  }

  Future<void> _saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_messageAnalysisKey, messageAnalysisEnabled);
      await prefs.setBool(_smartSuggestionsKey, smartSuggestionsEnabled);
      await prefs.setBool(_toneAdjusterKey, toneAdjusterEnabled);
      // await prefs.setBool(_autoLaunchKey, autoLaunchEnabled); // Commented out
      print('✅ Settings saved to preferences');
    } catch (e) {
      print('❌ Error saving settings: $e');
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

      print('✅ Permissions checked - Overlay: $hasOverlayPermission');
    } catch (e) {
      print('❌ Error checking permissions: $e');
    }
  }

  @override
  void dispose() {
    OverlayStatsTracker.removeListener(this);
    super.dispose();
  }

  Future<void> _initializeStatistics() async {
    try {
      print('🔧 Starting statistics initialization...');
      setState(() {
        _isLoadingStats = true;
      });

      await OverlayStatsTracker.initialize();
      print('✅ OverlayStatsTracker initialized');

      OverlayStatsTracker.addListener(this);
      print('✅ Added statistics listener');

      await _loadStatistics();
      print('✅ Statistics initialization completed');
    } catch (e) {
      print('❌ Error initializing statistics: $e');
      if (mounted) {
        setState(() {
          _isLoadingStats = false;
        });
      }
    }
  }

  Future<void> _loadStatistics() async {
    try {
      print('📊 Loading statistics for period: ${_selectedPeriod.name}');
      if (mounted) {
        setState(() {
          _isLoadingStats = true;
        });
      }

      final statistics = await OverlayStatsTracker.getStatistics(
        _selectedPeriod,
      );

      print(
        '📈 Retrieved statistics: Messages=${statistics.messagesAnalyzed}, Suggestions=${statistics.suggestionsUsed}, Rephrased=${statistics.responsesRephrased}',
      );
      print(
        '📅 Period: ${statistics.period.name}, Last Updated: ${statistics.lastUpdated}',
      );

      if (mounted) {
        setState(() {
          _currentStatistics = statistics;
          _isLoadingStats = false;
        });
        print('✅ Statistics loaded and UI updated');
      }
    } catch (e) {
      print('❌ Error loading statistics: $e');
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
    print('🔔 Event recorded notification: ${event.type.name}');
    // Reload statistics when new events are recorded
    _loadStatistics();
  }

  @override
  void onStatisticsUpdated(OverlayStatistics statistics) {
    print('🔔 Statistics updated notification: ${statistics.period.name}');
    if (statistics.period == _selectedPeriod && mounted) {
      setState(() {
        _currentStatistics = statistics;
      });
      print('✅ UI updated with new statistics');
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
                              print(
                                '🎨 Building stats card - Loading: $_isLoadingStats, Stats: $_currentStatistics',
                              );

                              if (_isLoadingStats) {
                                print('🔄 Showing loading indicator');
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
                                print('📊 Showing statistics data');
                                print(
                                  '   Messages: ${_currentStatistics!.messagesAnalyzed}',
                                );
                                print(
                                  '   Suggestions: ${_currentStatistics!.suggestionsUsed}',
                                );
                                print(
                                  '   Rephrased: ${_currentStatistics!.responsesRephrased}',
                                );

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
                                print('❌ No statistics data available');
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

                /*
                // Debug Panel (only in debug mode)
                if (const bool.fromEnvironment('dart.vm.product') == false)
                  _buildDebugPanel(),
                */
                // Overlay Status
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  child: FutureBuilder<bool>(
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
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Overlay Status',
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
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Overlay Disabled')),
                                  );
                                } else {
                                  await FlutterOverlayWindow.showOverlay(
                                    enableDrag: true,
                                    overlayTitle: "Emoticoach",
                                    overlayContent: 'Overlay Enabled',
                                    flag: OverlayFlag
                                        .focusPointer, // Enable keyboard input and focus
                                    alignment: OverlayAlignment.topLeft,
                                    positionGravity: PositionGravity.left,
                                    height: 200,
                                    width: 200,
                                    startPosition: const OverlayPosition(
                                      0,
                                      200,
                                    ),
                                  );
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Overlay Enabled')),
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
                        title: "Messaging Overlay",
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
                        icon: Icons.insights,
                        title: "Message Analysis",
                        subtitle: "Detect tone, intent, & emotional cues",
                        switchValue: messageAnalysisEnabled,
                        onChanged: (v) async {
                          setState(() => messageAnalysisEnabled = v);
                          await _saveSettings();
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
                      // _settingsTile(
                      //   icon: Icons.auto_awesome,
                      //   title: "Auto-Launch on Telegram",
                      //   subtitle: "Automatically show overlay when Telegram opens",
                      //   switchValue: autoLaunchEnabled,
                      //   onChanged: (v) async {
                      //     if (v) {
                      //       // Request usage stats permission
                      //       final bool hasPermission = await _appMonitor
                      //           .requestUsageStatsPermission();
                      //       if (hasPermission) {
                      //         await _appMonitor.startMonitoring();
                      //         _appMonitor.setOverlayEnabled(true);
                      //         setState(() => autoLaunchEnabled = true);
                      //         ScaffoldMessenger.of(context).showSnackBar(
                      //           SnackBar(
                      //             content: Text(
                      //               'Auto-launch enabled! Monitoring service started.',
                      //             ),
                      //           ),
                      //         );
                      //       } else {
                      //         setState(() => autoLaunchEnabled = false);
                      //         ScaffoldMessenger.of(context).showSnackBar(
                      //           SnackBar(
                      //             content: Text(
                      //               'Usage access permission required. Please enable in Settings.',
                      //             ),
                      //           ),
                      //         );
                      //       }
                      //     } else {
                      //       await _appMonitor.stopMonitoring();
                      //       _appMonitor.setOverlayEnabled(false);
                      //       setState(() => autoLaunchEnabled = false);
                      //       ScaffoldMessenger.of(context).showSnackBar(
                      //         SnackBar(
                      //           content: Text(
                      //             'Auto-launch disabled. Monitoring service stopped.',
                      //           ),
                      //         ),
                      //       );
                      //     }
                      //   },
                      // ), // Commented out - auto-launch feature not being implemented
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

  Widget _buildDebugPanel() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange[50],
        border: Border.all(color: Colors.orange[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '🛠️ Debug Panel',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.orange[800],
            ),
          ),
          SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _generateTestData,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange[100],
                    foregroundColor: Colors.orange[800],
                  ),
                  child: Text('Generate Test Data'),
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: _clearAllData,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red[100],
                    foregroundColor: Colors.red[800],
                  ),
                  child: Text('Clear All Data'),
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _testSingleEvent,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[100],
                    foregroundColor: Colors.blue[800],
                  ),
                  child: Text('Add Test Event'),
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: _printStorageInfo,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[100],
                    foregroundColor: Colors.green[800],
                  ),
                  child: Text('Storage Info'),
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _forceRefreshStats,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple[100],
                foregroundColor: Colors.purple[800],
              ),
              child: Text('🔄 Force Refresh Stats'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _generateTestData() async {
    try {
      print('🧪 Generating test data...');
      await OverlayStatsTracker.generateSampleData();
      print('✅ Test data generated');
      await _loadStatistics();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Test data generated successfully!')),
        );
      }
    } catch (e) {
      print('❌ Error generating test data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generating test data: $e')),
        );
      }
    }
  }

  Future<void> _clearAllData() async {
    try {
      print('🗑️ Clearing all data...');
      await OverlayStatsTracker.clearAllData();
      print('✅ All data cleared');
      await _loadStatistics();

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('All data cleared!')));
      }
    } catch (e) {
      print('❌ Error clearing data: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error clearing data: $e')));
      }
    }
  }

  Future<void> _testSingleEvent() async {
    try {
      print('🎯 Adding test event...');
      await OverlayStatsTracker.trackMessageAnalyzed(
        messageContent: 'Test message for debugging',
        analysisType: 'debug_test',
        sessionId: 'debug_session',
      );
      print('✅ Test event added');
      await _loadStatistics();

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Test event added!')));
      }
    } catch (e) {
      print('❌ Error adding test event: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error adding test event: $e')));
      }
    }
  }

  Future<void> _printStorageInfo() async {
    try {
      print('📋 Getting storage info...');
      final info = await OverlayStatsTracker.getStorageInfo();
      print('📊 Storage Info: $info');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Events: ${info['eventsCount']}, Size: ${info['totalSize']} bytes',
            ),
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      print('❌ Error getting storage info: $e');
    }
  }

  Future<void> _forceRefreshStats() async {
    try {
      print('🔄 Force refreshing statistics...');
      setState(() {
        _isLoadingStats = true;
        _currentStatistics = null;
      });

      await _loadStatistics();

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Statistics refreshed!')));
      }
    } catch (e) {
      print('❌ Error force refreshing stats: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error refreshing stats: $e')));
      }
    }
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
