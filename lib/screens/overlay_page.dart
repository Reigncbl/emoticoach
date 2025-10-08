import 'dart:math' as math;
import 'dart:ui';
import '../utils/colors.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import '../models/overlay_statistics.dart';
import '../services/manual_analysis_service.dart';
import '../services/overlay_stats_service.dart';
import '../services/session_service.dart';
import '../utils/overlay_stats_tracker.dart';
import '../widgets/overlay_tutorial.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:developer';
import 'package:flutter/services.dart';
import 'package:fl_chart/fl_chart.dart';

enum _UsageMetric { messagesAnalyzed, suggestionsUsed, responsesRephrased }

class OverlayScreen extends StatefulWidget {
  const OverlayScreen({super.key});

  @override
  State<OverlayScreen> createState() => _OverlayScreenState();
}

class _OverlayScreenState extends State<OverlayScreen>
    with WidgetsBindingObserver
    implements OverlayStatsListener {
  // Toggle states for each setting
  bool messagingOverlayEnabled = false;
  bool messageAnalysisEnabled = false;
  bool smartSuggestionsEnabled = false;
  bool toneAdjusterEnabled = false;
  // bool autoLaunchEnabled = false; // Commented out - not implementing

  // Add preference keys
  static const String _messageAnalysisKey = 'message_analysis_enabled';
  static const String _smartSuggestionsKey = 'smart_suggestions_enabled';
  static const String _toneAdjusterKey = 'tone_adjuster_enabled';
  static const String _ragContextLimitKey = 'rag_context_limit';

  // RAG context limit state
  int _ragContextLimit = 20;

  // Dynamic statistics state
  StatisticsPeriod _selectedPeriod = StatisticsPeriod.pastWeek;
  OverlayStatistics? _currentStatistics;
  bool _isLoadingStats = true;

  final TextEditingController _manualMessageController =
      TextEditingController();
  bool _isManualAnalyzing = false;
  Map<String, dynamic>? _manualAnalysisResult;
  String? _manualAnalysisError;
  late final ManualAnalysisService _manualAnalysisService;
  bool _isLoadingDailyUsage = false;
  String? _dailyUsageError;
  List<OverlayDailyUsagePoint> _dailyUsagePoints = [];
  _UsageMetric _selectedUsageMetric = _UsageMetric.messagesAnalyzed;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _manualAnalysisService = ManualAnalysisService();
    _loadSettingsAndInitialize();
  }

  Future<void> _loadSettingsAndInitialize() async {
    await _loadSavedSettings();
    await _checkPermissions();
    await _refreshOverlayPermission();
    await _initializeStatistics();
  }

  Future<void> _loadSavedSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        messageAnalysisEnabled = prefs.getBool(_messageAnalysisKey) ?? false;
        smartSuggestionsEnabled = prefs.getBool(_smartSuggestionsKey) ?? false;
        toneAdjusterEnabled = prefs.getBool(_toneAdjusterKey) ?? false;
        _ragContextLimit = prefs.getInt(_ragContextLimitKey) ?? 20;
        // autoLaunchEnabled = prefs.getBool(_autoLaunchKey) ?? false; // Commented out
      });
      debugPrint('Settings loaded from preferences');
    } catch (e) {
      debugPrint('Error loading settings: $e');
    }
  }

  Future<void> _refreshOverlayPermission() async {
    final hasOverlayPermission =
        await FlutterOverlayWindow.isPermissionGranted();
    if (mounted) {
      setState(() => messagingOverlayEnabled = hasOverlayPermission);
    }
  }

  Future<void> _saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_messageAnalysisKey, messageAnalysisEnabled);
      await prefs.setBool(_smartSuggestionsKey, smartSuggestionsEnabled);
      await prefs.setBool(_toneAdjusterKey, toneAdjusterEnabled);
      await prefs.setInt(_ragContextLimitKey, _ragContextLimit);
      // await prefs.setBool(_autoLaunchKey, autoLaunchEnabled); // Commented out
      debugPrint(' Settings saved to preferences');
    } catch (e) {
      debugPrint('Error saving settings: $e');
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

      debugPrint(' Permissions checked - Overlay: $hasOverlayPermission');
    } catch (e) {
      debugPrint('Error checking permissions: $e');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // User came back from Settings → refresh permission state
      _refreshOverlayPermission();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    OverlayStatsTracker.removeListener(this);
    _manualMessageController.dispose();
    _manualAnalysisService.dispose();
    super.dispose();
  }

  Future<void> _initializeStatistics() async {
    try {
      debugPrint('🔧 Starting statistics initialization...');
      setState(() {
        _isLoadingStats = true;
      });

      await OverlayStatsTracker.initialize();
      debugPrint(' OverlayStatsTracker initialized');

      OverlayStatsTracker.addListener(this);
      debugPrint(' Added statistics listener');

      await _loadStatistics();
      await _loadDailyUsageData();
      debugPrint(' Statistics initialization completed');
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
        debugPrint(' Statistics loaded and UI updated');
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
      await _loadDailyUsageData();
    }
  }

  Future<void> _loadDailyUsageData() async {
    setState(() {
      _isLoadingDailyUsage = true;
      _dailyUsageError = null;
    });

    try {
      final points = await OverlayStatsTracker.getDailyUsagePoints(
        _selectedPeriod,
      );

      if (!mounted) return;

      setState(() {
        _dailyUsagePoints = points;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _dailyUsageError = 'Unable to load usage data: $e';
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _isLoadingDailyUsage = false;
      });
    }
  }

  Future<void> _submitManualAnalysis() async {
    final message = _manualMessageController.text.trim();
    if (message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a message to analyze.')),
      );
      return;
    }

    final userId = await SimpleSessionService.getFirebaseUid();
    if (userId == null || userId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'We could not find your user ID. Please sign in again.',
          ),
        ),
      );
      return;
    }

    setState(() {
      _isManualAnalyzing = true;
      _manualAnalysisError = null;
    });

    try {
      final response = await _manualAnalysisService.analyzeMessage(
        userId: userId,
        message: message,
      );

      if (!mounted) return;

      if (response['success'] == false) {
        setState(() {
          _manualAnalysisError =
              response['error']?.toString() ?? 'Failed to analyze message.';
          _manualAnalysisResult = null;
        });
      } else {
        setState(() {
          _manualAnalysisResult = response;
          _manualAnalysisError = null;
        });
        FocusScope.of(context).unfocus();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _showManualAnalysisResultsModal();
          }
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _manualAnalysisError = 'Unexpected error: $e';
        _manualAnalysisResult = null;
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _isManualAnalyzing = false;
      });
    }
  }

  void _showSettingsModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) {
        return StatefulBuilder(
          builder: (context, modalSetState) {
            final bottomInset = MediaQuery.of(
              bottomSheetContext,
            ).viewInsets.bottom;
            return Padding(
              padding: EdgeInsets.only(bottom: bottomInset),
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
                child: Container(
                  color: Colors.white,
                  child: SafeArea(
                    top: false,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Center(
                            child: Container(
                              width: 40,
                              height: 4,
                              decoration: BoxDecoration(
                                color: Colors.grey[300],
                                borderRadius: BorderRadius.circular(40),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Overlay Settings',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 16),

                          ..._buildSettingsModalContent(modalSetState),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showTutorialModal() {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Overlay tutorial',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        return OverlayTutorialModal(
          onClose: () => Navigator.of(dialogContext).pop(),
        );
      },
    );
  }

  String _capitalize(String? value) {
    if (value == null || value.isEmpty) return '';
    if (value.length == 1) return value.toUpperCase();
    return value[0].toUpperCase() + value.substring(1);
  }

  Widget _buildMessageBubble(String text, {bool isReply = false}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isReply ? kPrimaryBlue.withOpacity(0.08) : Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isReply ? kPrimaryBlue.withOpacity(0.35) : Colors.grey[200]!,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            text,
            style: TextStyle(
              fontSize: 13,
              color: isReply ? kPrimaryBlue : Colors.black87,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: _copyManualAnalysisResult,
            icon: const Icon(Icons.copy_rounded, size: 18),
            label: const Text('Copy'),
            style: TextButton.styleFrom(
              foregroundColor: kPrimaryBlue,
              padding: EdgeInsets.zero,
              minimumSize: const Size(0, 0),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildManualAnalysisResult() {
    final result = _manualAnalysisResult;
    if (result == null) return const SizedBox.shrink();

    final lastMessage = result['last_message'] as Map<String, dynamic>?;
    final lastMessageText = lastMessage != null
        ? lastMessage['MessageContent']?.toString()
        : null;
    final lastEmotion = lastMessage != null
        ? lastMessage['emotion_analysis'] as Map<String, dynamic>?
        : null;
    final lastEmotionName = lastEmotion?['dominant_emotion']?.toString();
    final num? lastEmotionScore =
        lastEmotion != null && lastEmotion['dominant_score'] is num
        ? lastEmotion['dominant_score'] as num
        : null;
    final interpretation = lastEmotion?['interpretation']?.toString();

    final suggestion = result['rag_suggestion']?.toString();
    final suggestionEmotion =
        result['rag_suggestion_emotion'] as Map<String, dynamic>?;
    final suggestionEmotionName = suggestionEmotion?['dominant_emotion']
        ?.toString();

    if (suggestion == null || suggestion.trim().isEmpty) {
      return Text(
        'No suggestion available for this message.',
        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Message',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13,
            color: Colors.grey[800],
          ),
        ),
        const SizedBox(height: 6),
        _buildMessageBubble(lastMessageText ?? '—'),
        if (lastEmotionName != null && lastEmotionName.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            'Detected emotion: ${_capitalize(lastEmotionName)}'
            '${lastEmotionScore != null ? ' (${(lastEmotionScore * 100).clamp(0, 100).toStringAsFixed(0)}%)' : ''}',
            style: TextStyle(fontSize: 12, color: Colors.grey[700]),
          ),
        ],
        if (interpretation != null && interpretation.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            interpretation,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              height: 1.35,
            ),
          ),
        ],
        if (suggestion != null && suggestion.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            'Suggested reply',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 6),
          _buildMessageBubble(suggestion, isReply: true),
        ],
        if (suggestionEmotionName != null && suggestionEmotionName.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'Suggestion tone: ${_capitalize(suggestionEmotionName)}',
              style: TextStyle(fontSize: 12, color: Colors.grey[700]),
            ),
          ),
      ],
    );
  }

  Widget _buildManualAnalysisCard() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withOpacity(0.85),
                  Colors.white.withOpacity(0.55),
                ],
              ),
              border: Border.all(
                color: Colors.white.withOpacity(0.45),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.analytics_outlined, color: kPrimaryBlue),
                    const SizedBox(width: 8),
                    Text(
                      'Try Manual Analysis',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _manualMessageController,
                  minLines: 3,
                  maxLines: 6,
                  style: const TextStyle(fontSize: 13, height: 1.4),
                  decoration: InputDecoration(
                    hintText:
                        'Type or paste a message you want to analyze here...',
                    hintStyle: TextStyle(fontSize: 13, color: Colors.grey[500]),
                    filled: true,
                    fillColor: kWhite,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: kPrimaryBlue.withOpacity(0.6),
                      ),
                    ),
                  ),
                  onChanged: (_) {
                    if (_manualAnalysisError != null) {
                      setState(() {
                        _manualAnalysisError = null;
                      });
                    }
                  },
                ),
                const SizedBox(height: 14),
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton(
                    onPressed: _isManualAnalyzing
                        ? null
                        : _submitManualAnalysis,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kPrimaryBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 22,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isManualAnalyzing
                        ? SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : const Text('Analyze message'),
                  ),
                ),
                if (_manualAnalysisError != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      _manualAnalysisError!,
                      style: TextStyle(color: Colors.red[700], fontSize: 12),
                    ),
                  ),
                ],
                if (_manualAnalysisResult != null) ...[
                  const SizedBox(height: 12),
                  TextButton.icon(
                    onPressed: _showManualAnalysisResultsModal,
                    icon: const Icon(Icons.visibility_outlined),
                    label: const Text('View latest analysis'),
                    style: TextButton.styleFrom(foregroundColor: kPrimaryBlue),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showManualAnalysisResultsModal() {
    if (_manualAnalysisResult == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Run an analysis first to view results.')),
      );
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final bottomInset = MediaQuery.of(sheetContext).viewInsets.bottom;
        return Padding(
          padding: EdgeInsets.only(bottom: bottomInset),
          child: GestureDetector(
            onTap: () => FocusScope.of(sheetContext).unfocus(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFE8F1FF), Color(0xFFF5F8FF)],
                ),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withOpacity(0.6)),
                    ),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Center(
                            child: Container(
                              width: 40,
                              height: 4,
                              decoration: BoxDecoration(
                                color: Colors.grey.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              const Icon(
                                Icons.analytics_outlined,
                                color: kPrimaryBlue,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Manual Message Analysis',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: Text(
                                  'Suggested reply',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const Divider(),
                          const SizedBox(height: 12),
                          _buildManualAnalysisResult(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _copyManualAnalysisResult() async {
    final suggestion = _manualAnalysisResult?['rag_suggestion']?.toString();
    if (suggestion == null || suggestion.trim().isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No suggestion available to copy.')),
      );
      return;
    }

    await Clipboard.setData(ClipboardData(text: suggestion.trim()));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Suggestion copied to clipboard.')),
    );
  }

  Widget _buildUsageGraphCard() {
    final maxValue = _dailyUsagePoints.isEmpty
        ? 0
        : _dailyUsagePoints.map(_valueForMetric).reduce(math.max);
    final maxY = maxValue == 0 ? 1.0 : (maxValue * 1.2).ceilToDouble();
    final leftInterval = maxValue <= 5 ? 1.0 : (maxValue / 5).ceilToDouble();
    final labelStep = _dailyUsagePoints.isEmpty
        ? 1
        : math.max(1, (_dailyUsagePoints.length / 6).ceil());

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            height: 320,
            padding: const EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: 0,
            ),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.45)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Usage trend',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      onPressed: _isLoadingDailyUsage
                          ? null
                          : _loadDailyUsageData,
                      tooltip: 'Refresh graph',
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 240,
                  child: Builder(
                    builder: (context) {
                      if (_isLoadingDailyUsage) {
                        return Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                              kPrimaryBlue,
                            ),
                          ),
                        );
                      }

                      if (_dailyUsageError != null) {
                        return Center(
                          child: Text(
                            _dailyUsageError!,
                            style: TextStyle(color: Colors.red[600]),
                            textAlign: TextAlign.center,
                          ),
                        );
                      }

                      if (_dailyUsagePoints.isEmpty) {
                        return Center(
                          child: Text(
                            'No usage recorded for this period yet.',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        );
                      }

                      final lineColor = _metricColor(_selectedUsageMetric);
                      final spots = _dailyUsagePoints.asMap().entries.map((
                        entry,
                      ) {
                        final index = entry.key.toDouble();
                        final value = _valueForMetric(entry.value).toDouble();
                        return FlSpot(index, value);
                      }).toList();

                      final gradientColors = [
                        lineColor.withOpacity(0.25),
                        lineColor.withOpacity(0.05),
                      ];

                      return LineChart(
                        LineChartData(
                          minX: 0,
                          maxX: (spots.length - 1).toDouble(),
                          minY: 0,
                          maxY: maxY,
                          lineTouchData: LineTouchData(
                            enabled: true,
                            touchTooltipData: LineTouchTooltipData(
                              getTooltipItems: (touchedSpots) {
                                return touchedSpots.map((barSpot) {
                                  final dateIndex = barSpot.x.round().clamp(
                                    0,
                                    _dailyUsagePoints.length - 1,
                                  );
                                  final date =
                                      _dailyUsagePoints[dateIndex].date;
                                  return LineTooltipItem(
                                    '${_formatDateLabel(date)}\n'
                                    '${barSpot.y.toStringAsFixed(0)} ${_metricLabel(_selectedUsageMetric).toLowerCase()}',
                                    const TextStyle(color: Colors.white),
                                  );
                                }).toList();
                              },
                            ),
                          ),
                          gridData: FlGridData(
                            show: true,
                            drawVerticalLine: false,
                            horizontalInterval: leftInterval,
                            getDrawingHorizontalLine: (value) =>
                                FlLine(color: Colors.grey[300], strokeWidth: 1),
                          ),
                          titlesData: FlTitlesData(
                            topTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            rightTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 40,
                                interval: leftInterval,
                                getTitlesWidget: (value, meta) {
                                  if (value < 0) {
                                    return const SizedBox.shrink();
                                  }
                                  return Text(
                                    value.toInt().toString(),
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 11,
                                    ),
                                  );
                                },
                              ),
                            ),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                interval: 1,
                                reservedSize: 46,
                                getTitlesWidget: (value, meta) {
                                  final index = value.toInt();
                                  if (index < 0 ||
                                      index >= _dailyUsagePoints.length) {
                                    return const SizedBox.shrink();
                                  }

                                  final showLabel =
                                      index == 0 ||
                                      index == _dailyUsagePoints.length - 1 ||
                                      index % labelStep == 0;

                                  if (!showLabel) {
                                    return const SizedBox.shrink();
                                  }

                                  final date = _dailyUsagePoints[index].date;
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 6),
                                    child: Text(
                                      _formatDateLabel(date),
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 10,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                          borderData: FlBorderData(show: false),
                          lineBarsData: [
                            LineChartBarData(
                              spots: spots,
                              isCurved: true,
                              color: lineColor,
                              barWidth: 3,
                              isStrokeCapRound: true,
                              dotData: FlDotData(show: spots.length <= 12),
                              belowBarData: BarAreaData(
                                show: true,
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: gradientColors,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _metricLabel(_UsageMetric metric) {
    switch (metric) {
      case _UsageMetric.messagesAnalyzed:
        return 'Analyses';
      case _UsageMetric.suggestionsUsed:
        return 'Suggestions';
      case _UsageMetric.responsesRephrased:
        return 'Rephrased';
    }
  }

  Color _metricColor(_UsageMetric metric) {
    switch (metric) {
      case _UsageMetric.messagesAnalyzed:
        return kPrimaryBlue;
      case _UsageMetric.suggestionsUsed:
        return kDailyChallengeRed;
      case _UsageMetric.responsesRephrased:
        return kQuoteBlue;
    }
  }

  int _valueForMetric(OverlayDailyUsagePoint point) {
    switch (_selectedUsageMetric) {
      case _UsageMetric.messagesAnalyzed:
        return point.messagesAnalyzed;
      case _UsageMetric.suggestionsUsed:
        return point.suggestionsUsed;
      case _UsageMetric.responsesRephrased:
        return point.responsesRephrased;
    }
  }

  String _formatDateLabel(DateTime date) {
    final monthNames = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final month = monthNames[date.month - 1];
    return '$month ${date.day}';
  }

  List<Widget> _buildSettingsModalContent(
    void Function(void Function()) modalSetState,
  ) {
    return [
      _buildRagContextSetting(),
      const SizedBox(height: 12),
      _settingsTile(
        icon: Icons.search,
        title: "Messaging Overlay",
        subtitle: "Enable floating communication coach",
        switchValue: messagingOverlayEnabled,
        onChanged: (v) async {
          setState(() => messagingOverlayEnabled = v);
          modalSetState(() {});
          if (v) {
            final hasPermission =
                await FlutterOverlayWindow.isPermissionGranted();

            if (!hasPermission) {
              final bool? res = await FlutterOverlayWindow.requestPermission();
              log("Overlay permission request result: $res");

              if (res == true) {
                setState(() => messagingOverlayEnabled = true);
                modalSetState(() {});
              } else {
                setState(() => messagingOverlayEnabled = false);
                modalSetState(() {});
              }
            } else {
              setState(() => messagingOverlayEnabled = true);
              modalSetState(() {});
            }
          } else {
            setState(() => messagingOverlayEnabled = false);
            modalSetState(() {});

            final isActive = await FlutterOverlayWindow.isActive();
            if (isActive) {
              await FlutterOverlayWindow.closeOverlay();
            }

            const channel = MethodChannel("emoticoach_service");
            try {
              await channel.invokeMethod("openOverlaySettings");
            } catch (e) {
              log("Failed to open overlay settings: $e");
            }
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
          modalSetState(() {});
          await _saveSettings();
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                v ? 'Message Analysis enabled' : 'Message Analysis disabled',
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
          modalSetState(() {});
          await _saveSettings();
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                v ? 'Smart Suggestions enabled' : 'Smart Suggestions disabled',
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
          modalSetState(() {});
          await _saveSettings();
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                v ? 'Tone Adjuster enabled' : 'Tone Adjuster disabled',
              ),
              backgroundColor: v ? Colors.green : Colors.orange,
            ),
          );
        },
      ),
    ];
  }

  Widget _buildRagContextSetting() {
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
          child: Icon(Icons.format_list_numbered, color: kPrimaryBlue),
        ),
        title: Text(
          "RAG Context Window (min)",
          style: TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Text(
          "How many recent minutes to include in analysis",
          style: TextStyle(fontSize: 13),
        ),
        trailing: SizedBox(
          width: 90,
          child: TextField(
            controller: TextEditingController(
              text: _ragContextLimit.toString(),
            ),
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              border: OutlineInputBorder(),
            ),
            onSubmitted: (value) async {
              final v = int.tryParse(value);
              if (v != null && v > 0) {
                setState(() => _ragContextLimit = v);
                await _saveSettings();
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('RAG context limit set to $v'),
                    backgroundColor: Colors.green,
                  ),
                );
              } else {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter a valid positive number'),
                    backgroundColor: Colors.orange,
                  ),
                );
              }
            },
          ),
        ),
      ),
    );
  }

  // OverlayStatsListener implementation
  @override
  void onEventRecorded(OverlayUsageEvent event) {
    debugPrint('Event recorded notification: ${event.type.name}');
    // Reload statistics when new events are recorded
    _loadStatistics();
    _loadDailyUsageData();
  }

  @override
  void onStatisticsUpdated(OverlayStatistics statistics) {
    debugPrint('🔔 Statistics updated notification: ${statistics.period.name}');
    if (statistics.period == _selectedPeriod && mounted) {
      setState(() {
        _currentStatistics = statistics;
      });
      debugPrint(' UI updated with new statistics');
    }
    _loadDailyUsageData();
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
                      IconButton(
                        icon: Icon(Icons.settings, color: Colors.black),
                        tooltip: 'Overlay settings',
                        onPressed: _showSettingsModal,
                      ),
                      IconButton(
                        icon: Icon(Icons.info_outline, color: Colors.black),
                        tooltip: 'Tutorial',
                        onPressed: _showTutorialModal,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
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
                                filter: ImageFilter.blur(
                                  sigmaX: 10,
                                  sigmaY: 10,
                                ),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 20,
                                  ),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(16),
                                    color: Colors.white.withOpacity(0.5),
                                  ),
                                  child: Builder(
                                    builder: (context) {
                                      if (_isLoadingStats) {
                                        return Center(
                                          child: Padding(
                                            padding: const EdgeInsets.all(20.0),
                                            child: CircularProgressIndicator(
                                              valueColor:
                                                  AlwaysStoppedAnimation<Color>(
                                                    kPrimaryBlue,
                                                  ),
                                            ),
                                          ),
                                        );
                                      } else if (_currentStatistics != null) {
                                        debugPrint('Showing statistics data');

                                        return Row(
                                          children: [
                                            Expanded(
                                              child: _statColumn(
                                                "${_currentStatistics!.messagesAnalyzed}",
                                                "Messages\nAnalyzed",
                                                _UsageMetric.messagesAnalyzed,
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: _statColumn(
                                                "${_currentStatistics!.suggestionsUsed}",
                                                "Suggestions\nUsed",
                                                _UsageMetric.suggestionsUsed,
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: _statColumn(
                                                "${_currentStatistics!.responsesRephrased}",
                                                "Rephrased\nResponses",
                                                _UsageMetric.responsesRephrased,
                                              ),
                                            ),
                                          ],
                                        );
                                      } else {
                                        debugPrint(
                                          'No statistics data available',
                                        );
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
                        const SizedBox(height: 8),
                        // Period Tabs
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _buildPeriodTab(StatisticsPeriod.today, "Today"),
                              _buildPeriodTab(
                                StatisticsPeriod.pastWeek,
                                "Past Week",
                              ),
                              _buildPeriodTab(
                                StatisticsPeriod.pastMonth,
                                "Past Month",
                              ),
                              _buildPeriodTab(
                                StatisticsPeriod.allTime,
                                "All Time",
                              ),
                            ],
                          ),
                        ),
                        // Usage Graph
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          child: _buildUsageGraphCard(),
                        ),

                        const SizedBox(height: 12),

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
                                  borderRadius: BorderRadius.circular(12),
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: isOverlayActive
                                        ? [
                                            const Color(0xFFD3E6FF),
                                            const Color(0xFFF7F7F7),
                                          ]
                                        : [kWhite, const Color(0xFFB7B7B7)],
                                  ),
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
                                            'Overlay Status',
                                            style: TextStyle(
                                              color: isOverlayActive
                                                  ? Colors.black
                                                  : Colors.black87,
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          SizedBox(height: 2),
                                          Text(
                                            isOverlayActive
                                                ? 'Enabled'
                                                : 'Disabled',
                                            style: TextStyle(
                                              color: isOverlayActive
                                                  ? Colors.black
                                                  : Colors.black87,
                                              fontWeight: FontWeight.w600,
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
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text('Overlay Disabled'),
                                            ),
                                          );
                                        } else {
                                          await FlutterOverlayWindow.showOverlay(
                                            enableDrag: true,
                                            overlayTitle: "Emoticoach",
                                            overlayContent: 'Overlay Enabled',
                                            flag: OverlayFlag.defaultFlag,
                                            alignment: OverlayAlignment.topLeft,
                                            positionGravity:
                                                PositionGravity.auto,
                                            height: 200,
                                            width: 200,
                                            startPosition:
                                                const OverlayPosition(0, 200),
                                          );
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text('Overlay Enabled'),
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
                        ),

                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              "Try Message Analysis",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),

                        // Padding(
                        //   padding: const EdgeInsets.symmetric(horizontal: 16),
                        //   child: Row(
                        //     mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        //     children: [
                        //       Card(
                        //         elevation: 0,
                        //         shape: RoundedRectangleBorder(
                        //           borderRadius: BorderRadius.circular(12),
                        //           side: BorderSide(color: Colors.blue[100]!),
                        //         ),
                        //         child: Padding(
                        //           padding: const EdgeInsets.all(12),
                        //           child: Row(
                        //             mainAxisSize: MainAxisSize.min,
                        //             children: [
                        //               CircleAvatar(
                        //                 backgroundColor: Colors.blue[50],
                        //                 radius: 20,
                        //                 child: Icon(
                        //                   Icons.telegram,
                        //                   color: kPrimaryBlue,
                        //                   size: 40,
                        //                 ),
                        //               ),
                        //               const SizedBox(width: 10),
                        //               const Text("Telegram"),
                        //             ],
                        //           ),
                        //         ),
                        //       ),
                        //     ],
                        //   ),
                        // ),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          child: _buildManualAnalysisCard(),
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

  Widget _buildPeriodTab(StatisticsPeriod period, String label) {
    final isSelected = _selectedPeriod == period;

    return GestureDetector(
      onTap: () => _onPeriodChanged(period),
      child: Container(
        decoration: BoxDecoration(
          color: isSelected ? kDarkerBlue : kLightGrey,
          borderRadius: BorderRadius.circular(50),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? kWhite : Colors.black,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w600,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _statColumn(String value, String label, _UsageMetric metric) {
    final isSelected = _selectedUsageMetric == metric;
    final Color accentColor = isSelected ? kDailyChallengeRed : kDarkerBlue;
    final Color fontColor = isSelected ? kDailyChallengeRed : kBlack;

    return GestureDetector(
      onTap: () {
        if (!isSelected) {
          setState(() {
            _selectedUsageMetric = metric;
          });
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              style: TextStyle(
                color: accentColor,
                fontWeight: FontWeight.bold,
                fontSize: 32,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: fontColor,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
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
      duration: const Duration(milliseconds: 200),
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
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.isActive ? kDarkBlue : kDarkGrey,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                widget.isActive ? Icons.flash_on : Icons.flash_off,
                color: kWhite,
                size: 28,
              ),
            ),
          );
        },
      ),
    );
  }
}
