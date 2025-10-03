import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';
import '../models/overlay_statistics.dart';
import 'session_service.dart';

/// Abstract interface for overlay statistics storage and retrieval
abstract class OverlayStatsRepository {
  /// Record a new usage event
  Future<void> recordEvent(OverlayUsageEvent event);

  /// Get all usage events
  Future<List<OverlayUsageEvent>> getAllEvents();

  /// Get events for a specific time period
  Future<List<OverlayUsageEvent>> getEventsForPeriod(StatisticsPeriod period);

  /// Get aggregated statistics for a specific period
  Future<OverlayStatistics> getStatisticsForPeriod(StatisticsPeriod period);

  /// Get current configuration
  Future<OverlayStatsConfig> getConfig();

  /// Save configuration
  Future<void> saveConfig(OverlayStatsConfig config);

  /// Clear all statistics data
  Future<void> clearAllData();

  /// Get statistics for all periods at once
  Future<Map<StatisticsPeriod, OverlayStatistics>> getAllPeriodStatistics();
}

/// Event listener interface for real-time statistics updates
abstract class OverlayStatsListener {
  /// Called when a new event is recorded
  void onEventRecorded(OverlayUsageEvent event);

  /// Called when statistics are updated
  void onStatisticsUpdated(OverlayStatistics statistics);

  /// Called when configuration changes
  void onConfigUpdated(OverlayStatsConfig config);
}

/// SharedPreferences-based implementation of overlay statistics storage
class OverlayStatsService implements OverlayStatsRepository {
  static const String _eventsKey = 'overlay_usage_events';
  static const String _configKey = 'overlay_stats_config';
  static const String _cacheKey = 'overlay_stats_cache';

  // Singleton pattern
  static OverlayStatsService? _instance;
  static OverlayStatsService get instance =>
      _instance ??= OverlayStatsService._();
  OverlayStatsService._();

  SharedPreferences? _prefs;
  final http.Client _httpClient = http.Client();
  final List<OverlayStatsListener> _listeners = [];
  bool _isInitializing = false;
  bool _isInitialized = false;

  // In-memory cache for better performance
  List<OverlayUsageEvent>? _eventsCache;
  OverlayStatsConfig? _configCache;
  Map<StatisticsPeriod, OverlayStatistics>? _statisticsCache;

  /// Initialize the service
  Future<void> initialize() async {
    print('OverlayStatsService.initialize() called');

    // Prevent multiple simultaneous initializations
    if (_isInitialized || _isInitializing) {
      return;
    }

    _isInitializing = true;
    try {
      _prefs ??= await SharedPreferences.getInstance();
      print('SharedPreferences ready');

      await _loadCaches();

      _isInitialized = true;
    } catch (e) {
      throw e;
    } finally {
      _isInitializing = false;
    }
  }

  /// Add a listener for real-time updates
  void addListener(OverlayStatsListener listener) {
    _listeners.add(listener);
  }

  /// Remove a listener
  void removeListener(OverlayStatsListener listener) {
    _listeners.remove(listener);
  }

  /// Notify all listeners of an event
  void _notifyEventRecorded(OverlayUsageEvent event) {
    for (final listener in _listeners) {
      listener.onEventRecorded(event);
    }
  }

  /// Notify all listeners of statistics update
  void _notifyStatisticsUpdated(OverlayStatistics statistics) {
    for (final listener in _listeners) {
      listener.onStatisticsUpdated(statistics);
    }
  }

  /// Notify all listeners of config update
  void _notifyConfigUpdated(OverlayStatsConfig config) {
    for (final listener in _listeners) {
      listener.onConfigUpdated(config);
    }
  }

  /// Load all caches from storage
  Future<void> _loadCaches() async {
    await _loadEventsCache();
    await _loadConfigCache();
    await _refreshStatisticsCache();
    print('All caches loaded');
  }

  /// Load events cache from SharedPreferences
  Future<void> _loadEventsCache() async {
    try {
      final eventsJson = _prefs?.getStringList(_eventsKey) ?? [];

      _eventsCache = eventsJson
          .map((json) => OverlayUsageEvent.fromJson(jsonDecode(json)))
          .toList();

      // Sort by timestamp (newest first)
      _eventsCache!.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      print('Events cache loaded: ${_eventsCache!.length} events');
    } catch (e) {
      _eventsCache = [];
    }
  }

  /// Load config cache from SharedPreferences
  Future<void> _loadConfigCache() async {
    try {
      final configJson = _prefs?.getString(_configKey);
      if (configJson != null) {
        _configCache = OverlayStatsConfig.fromJson(jsonDecode(configJson));
      } else {
        _configCache = OverlayStatsConfig.defaultConfig();
        // Save directly to SharedPreferences without calling saveConfig to avoid circular dependency
        final configJsonToSave = jsonEncode(_configCache!.toJson());
        await _prefs!.setString(_configKey, configJsonToSave);
      }
    } catch (e) {
      print('❌ Error loading config cache: $e');
      _configCache = OverlayStatsConfig.defaultConfig();
    }
  }

  /// Refresh statistics cache for all periods
  Future<void> _refreshStatisticsCache({bool preferBackend = true}) async {
    try {
      _statisticsCache = {};

      for (final period in StatisticsPeriod.values) {
        OverlayStatistics? stats;
        if (preferBackend) {
          stats = await _fetchStatisticsFromBackend(period);
        }

        stats ??= OverlayStatistics.fromEvents(
          await getEventsForPeriod(period),
          period,
        );

        _statisticsCache![period] = stats;
      }
      print('Statistics cache refreshed for all periods');
    } catch (e) {
      print('Error refreshing statistics cache: $e');
      _statisticsCache = {};
    }
  }

  Future<String?> _getCurrentUserId() async {
    try {
      final firebaseUid = await SimpleSessionService.getFirebaseUid();
      if (firebaseUid != null && firebaseUid.isNotEmpty) {
        return firebaseUid;
      }

      final phoneNumber = await SimpleSessionService.getUserPhone();
      if (phoneNumber != null && phoneNumber.isNotEmpty) {
        return phoneNumber;
      }
    } catch (e) {
      print('Error retrieving user identifier for overlay stats: $e');
    }
    return null;
  }

  String _periodToApiValue(StatisticsPeriod period) {
    switch (period) {
      case StatisticsPeriod.today:
        return 'today';
      case StatisticsPeriod.pastWeek:
        return 'past_week';
      case StatisticsPeriod.pastMonth:
        return 'past_month';
      case StatisticsPeriod.allTime:
        return 'all_time';
    }
  }

  Future<OverlayStatistics?> _fetchStatisticsFromBackend(
    StatisticsPeriod period,
  ) async {
    final userId = await _getCurrentUserId();
    if (userId == null) {
      return null;
    }

    final uri = Uri.parse('${ApiConfig.baseUrl}/overlay-stats/aggregate')
        .replace(
          queryParameters: {
            'user_id': userId,
            'period': _periodToApiValue(period),
          },
        );

    try {
      final response = await _httpClient.get(uri);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final dynamic body = jsonDecode(response.body);
        if (body is Map<String, dynamic> && body['success'] == true) {
          final data = body['data'];
          if (data is Map<String, dynamic>) {
            return OverlayStatistics(
              messagesAnalyzed:
                  (data['messagesAnalyzed'] as num?)?.toInt() ?? 0,
              suggestionsUsed: (data['suggestionsUsed'] as num?)?.toInt() ?? 0,
              responsesRephrased:
                  (data['responsesRephrased'] as num?)?.toInt() ?? 0,
              period: period,
              lastUpdated:
                  DateTime.tryParse(data['lastUpdated'] as String? ?? '') ??
                  DateTime.now(),
            );
          }
        }
      } else {
        print(
          'Failed to fetch overlay statistics for period ${period.name}: ${response.statusCode} ${response.body}',
        );
      }
    } catch (e) {
      print('Error fetching overlay statistics from backend: $e');
    }

    return null;
  }

  Future<void> _syncEventToBackend(OverlayUsageEvent event) async {
    final userId = await _getCurrentUserId();
    if (userId == null) {
      return;
    }

    final int messagesAnalyzedIncrement =
        event.type == OverlayEventType.messageAnalyzed ? 1 : 0;
    final int suggestionsUsedIncrement =
        event.type == OverlayEventType.suggestionUsed ? 1 : 0;
    final int responsesRephrasedIncrement =
        event.type == OverlayEventType.responseRephrased ? 1 : 0;

    final uri = Uri.parse('${ApiConfig.baseUrl}/overlay-stats/upsert').replace(
      queryParameters: {
        'user_id': userId,
        'messages_analyzed': messagesAnalyzedIncrement.toString(),
        'suggestions_used': suggestionsUsedIncrement.toString(),
        'responses_rephrased': responsesRephrasedIncrement.toString(),
      },
    );

    try {
      final response = await _httpClient.post(uri);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        print(
          'Failed to sync overlay event with backend: ${response.statusCode} ${response.body}',
        );
      }
    } catch (e) {
      print('Error syncing overlay event with backend: $e');
    }
  }

  @override
  Future<void> recordEvent(OverlayUsageEvent event) async {
    // Only initialize if not already initialized
    if (!_isInitialized) {
      await initialize();
    }

    try {
      // Add to cache
      _eventsCache ??= [];
      _eventsCache!.insert(0, event); // Insert at beginning (newest first)

      // Save to SharedPreferences
      final eventsJson = _eventsCache!
          .map((event) => jsonEncode(event.toJson()))
          .toList();

      await _prefs!.setStringList(_eventsKey, eventsJson);

      await _syncEventToBackend(event);

      // Refresh statistics cache
      await _refreshStatisticsCache(preferBackend: true);

      // Notify listeners
      _notifyEventRecorded(event);

      // Notify with updated statistics for current period
      final currentPeriod =
          _configCache?.selectedPeriod ?? StatisticsPeriod.pastWeek;
      final updatedStats = _statisticsCache?[currentPeriod];
      if (updatedStats != null) {
        _notifyStatisticsUpdated(updatedStats);
      }

      print('Recorded overlay event: ${event.type.name}');
    } catch (e) {
      print('Error recording event: $e');
      rethrow;
    }
  }

  @override
  Future<List<OverlayUsageEvent>> getAllEvents() async {
    if (!_isInitialized) await initialize();
    return List.from(_eventsCache ?? []);
  }

  @override
  Future<List<OverlayUsageEvent>> getEventsForPeriod(
    StatisticsPeriod period,
  ) async {
    if (!_isInitialized) await initialize();

    final allEvents = _eventsCache ?? [];
    final dateRange = period.dateRange;

    return allEvents.where((event) {
      return dateRange.contains(event.timestamp);
    }).toList();
  }

  @override
  Future<OverlayStatistics> getStatisticsForPeriod(
    StatisticsPeriod period,
  ) async {
    if (!_isInitialized) await initialize();

    final remoteStats = await _fetchStatisticsFromBackend(period);
    if (remoteStats != null) {
      _statisticsCache ??= {};
      _statisticsCache![period] = remoteStats;
      return remoteStats;
    }

    if (_statisticsCache?.containsKey(period) == true) {
      return _statisticsCache![period]!;
    }

    final events = await getEventsForPeriod(period);
    final statistics = OverlayStatistics.fromEvents(events, period);

    _statisticsCache ??= {};
    _statisticsCache![period] = statistics;

    return statistics;
  }

  @override
  Future<OverlayStatsConfig> getConfig() async {
    if (!_isInitialized) await initialize();
    return _configCache ?? OverlayStatsConfig.defaultConfig();
  }

  @override
  Future<void> saveConfig(OverlayStatsConfig config) async {
    // Only initialize if not already initialized
    if (!_isInitialized) {
      await initialize();
    }

    try {
      _configCache = config;
      final configJson = jsonEncode(config.toJson());
      await _prefs!.setString(_configKey, configJson);

      _notifyConfigUpdated(config);
      print('Saved overlay config: ${config.selectedPeriod.displayName}');
    } catch (e) {
      print('Error saving config: $e');
      rethrow;
    }
  }

  @override
  Future<void> clearAllData() async {
    await initialize();

    try {
      await _prefs!.remove(_eventsKey);
      await _prefs!.remove(_configKey);
      await _prefs!.remove(_cacheKey);

      _eventsCache = [];
      _configCache = OverlayStatsConfig.defaultConfig();
      _statisticsCache = {};

      await _refreshStatisticsCache(preferBackend: false);

      print('Cleared all overlay statistics data');
    } catch (e) {
      print('Error clearing data: $e');
      rethrow;
    }
  }

  @override
  Future<Map<StatisticsPeriod, OverlayStatistics>>
  getAllPeriodStatistics() async {
    await initialize();

    await _refreshStatisticsCache(preferBackend: true);
    return Map.from(_statisticsCache ?? {});
  }

  /// Generate sample data for testing (only in debug mode)
  Future<void> generateSampleData() async {
    if (!const bool.fromEnvironment('dart.vm.product')) {
      await initialize();

      final random = Random();
      final now = DateTime.now();

      // Generate events over the past month
      for (int i = 0; i < 100; i++) {
        final daysAgo = random.nextInt(30);
        final hoursAgo = random.nextInt(24);
        final minutesAgo = random.nextInt(60);

        final eventTime = now.subtract(
          Duration(days: daysAgo, hours: hoursAgo, minutes: minutesAgo),
        );

        final eventTypes = OverlayEventType.values;
        final randomEventType = eventTypes[random.nextInt(eventTypes.length)];

        final event = OverlayUsageEvent(
          id: '${DateTime.now().millisecondsSinceEpoch}_$i',
          type: randomEventType,
          timestamp: eventTime,
          metadata: {
            'source': 'sample_data',
            'session_id': 'session_${random.nextInt(10)}',
          },
        );

        await recordEvent(event);
      }

      print('Generated 100 sample overlay events');
    }
  }

  /// Get data export for backup/debugging
  Future<Map<String, dynamic>> exportData() async {
    await initialize();

    return {
      'events': _eventsCache?.map((e) => e.toJson()).toList() ?? [],
      'config': _configCache?.toJson() ?? {},
      'statistics':
          _statisticsCache?.map(
            (key, value) => MapEntry(key.name, value.toJson()),
          ) ??
          {},
      'exportTimestamp': DateTime.now().toIso8601String(),
    };
  }

  /// Import data from backup
  Future<void> importData(Map<String, dynamic> data) async {
    await initialize();

    try {
      // Clear existing data
      await clearAllData();

      // Import events
      if (data['events'] is List) {
        for (final eventJson in data['events']) {
          if (eventJson is Map<String, dynamic>) {
            final event = OverlayUsageEvent.fromJson(eventJson);
            await recordEvent(event);
          }
        }
      }

      // Import config
      if (data['config'] is Map<String, dynamic>) {
        final config = OverlayStatsConfig.fromJson(data['config']);
        await saveConfig(config);
      }

      print('Imported overlay statistics data');
    } catch (e) {
      print('Error importing data: $e');
      rethrow;
    }
  }

  /// Get storage size information
  Future<Map<String, dynamic>> getStorageInfo() async {
    await initialize();

    final eventsJson = _prefs?.getStringList(_eventsKey) ?? [];
    final configJson = _prefs?.getString(_configKey) ?? '';

    return {
      'eventsCount': _eventsCache?.length ?? 0,
      'eventsSize': eventsJson.join().length,
      'configSize': configJson.length,
      'totalSize': eventsJson.join().length + configJson.length,
      'lastUpdated': DateTime.now().toIso8601String(),
    };
  }
}
