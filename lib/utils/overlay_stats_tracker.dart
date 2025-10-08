import '../models/overlay_statistics.dart';
import '../services/overlay_stats_service.dart';

/// Utility class for easily tracking overlay usage events throughout the app
class OverlayStatsTracker {
  static final OverlayStatsService _service = OverlayStatsService.instance;

  /// Track when a message is analyzed
  static Future<void> trackMessageAnalyzed({
    String? messageContent,
    String? analysisType,
    String? sessionId,
  }) async {
    final event = OverlayUsageEvent(
      id: _generateEventId(),
      type: OverlayEventType.messageAnalyzed,
      timestamp: DateTime.now(),
      metadata: {
        if (messageContent != null) 'messageLength': messageContent.length,
        if (analysisType != null) 'analysisType': analysisType,
        if (sessionId != null) 'sessionId': sessionId,
        'source': 'overlay_tracker',
      },
    );

    await _service.recordEvent(event);
  }

  /// Track when a suggestion is used
  static Future<void> trackSuggestionUsed({
    String? suggestionType,
    String? originalMessage,
    String? suggestedMessage,
    String? sessionId,
  }) async {
    final event = OverlayUsageEvent(
      id: _generateEventId(),
      type: OverlayEventType.suggestionUsed,
      timestamp: DateTime.now(),
      metadata: {
        if (suggestionType != null) 'suggestionType': suggestionType,
        if (originalMessage != null) 'originalLength': originalMessage.length,
        if (suggestedMessage != null)
          'suggestedLength': suggestedMessage.length,
        if (sessionId != null) 'sessionId': sessionId,
        'source': 'overlay_tracker',
      },
    );

    await _service.recordEvent(event);
  }

  /// Track when a response is rephrased
  static Future<void> trackResponseRephrased({
    String? originalText,
    String? rephrasedText,
    String? toneAdjustment,
    String? sessionId,
  }) async {
    final event = OverlayUsageEvent(
      id: _generateEventId(),
      type: OverlayEventType.responseRephrased,
      timestamp: DateTime.now(),
      metadata: {
        if (originalText != null) 'originalLength': originalText.length,
        if (rephrasedText != null) 'rephrasedLength': rephrasedText.length,
        if (toneAdjustment != null) 'toneAdjustment': toneAdjustment,
        if (sessionId != null) 'sessionId': sessionId,
        'source': 'overlay_tracker',
      },
    );

    await _service.recordEvent(event);
  }

  /// Track custom overlay events with flexible metadata
  static Future<void> trackCustomEvent({
    required OverlayEventType type,
    Map<String, dynamic>? metadata,
  }) async {
    final event = OverlayUsageEvent(
      id: _generateEventId(),
      type: type,
      timestamp: DateTime.now(),
      metadata: {...?metadata, 'source': 'overlay_tracker_custom'},
    );

    await _service.recordEvent(event);
  }

  /// Generate a unique event ID
  static String _generateEventId() {
    return '${DateTime.now().millisecondsSinceEpoch}_${DateTime.now().microsecond}';
  }

  /// Get current statistics for a specific period
  static Future<OverlayStatistics> getStatistics(
    StatisticsPeriod period,
  ) async {
    return await _service.getStatisticsForPeriod(period);
  }

  /// Get all period statistics at once
  static Future<Map<StatisticsPeriod, OverlayStatistics>>
  getAllStatistics() async {
    return await _service.getAllPeriodStatistics();
  }

  /// Get daily usage points for a period
  static Future<List<OverlayDailyUsagePoint>> getDailyUsagePoints(
    StatisticsPeriod period,
  ) async {
    return await _service.getDailyUsagePoints(period);
  }

  /// Initialize the tracking service
  static Future<void> initialize() async {
    await _service.initialize();
  }

  /// Generate sample data for testing/demo purposes
  static Future<void> generateSampleData() async {
    await _service.generateSampleData();
  }

  /// Clear all tracking data
  static Future<void> clearAllData() async {
    await _service.clearAllData();
  }

  /// Add listener for real-time updates
  static void addListener(OverlayStatsListener listener) {
    _service.addListener(listener);
  }

  /// Remove listener
  static void removeListener(OverlayStatsListener listener) {
    _service.removeListener(listener);
  }

  /// Get storage information
  static Future<Map<String, dynamic>> getStorageInfo() async {
    return await _service.getStorageInfo();
  }

  /// Export data for backup
  static Future<Map<String, dynamic>> exportData() async {
    return await _service.exportData();
  }

  /// Import data from backup
  static Future<void> importData(Map<String, dynamic> data) async {
    await _service.importData(data);
  }
}
