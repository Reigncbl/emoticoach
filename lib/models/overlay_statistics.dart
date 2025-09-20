/// Enum representing different types of overlay usage events
enum OverlayEventType { messageAnalyzed, suggestionUsed, responseRephrased }

/// Enum representing different time periods for statistics filtering
enum StatisticsPeriod { today, pastWeek, pastMonth, allTime }

/// Extension to get display names for StatisticsPeriod enum
extension StatisticsPeriodExtension on StatisticsPeriod {
  String get displayName {
    switch (this) {
      case StatisticsPeriod.today:
        return 'Today';
      case StatisticsPeriod.pastWeek:
        return 'Past Week';
      case StatisticsPeriod.pastMonth:
        return 'Past Month';
      case StatisticsPeriod.allTime:
        return 'All Time';
    }
  }

  /// Get the date range for this period
  DateRange get dateRange {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    switch (this) {
      case StatisticsPeriod.today:
        return DateRange(start: today, end: today.add(const Duration(days: 1)));
      case StatisticsPeriod.pastWeek:
        return DateRange(
          start: today.subtract(const Duration(days: 7)),
          end: today.add(const Duration(days: 1)),
        );
      case StatisticsPeriod.pastMonth:
        return DateRange(
          start: today.subtract(const Duration(days: 30)),
          end: today.add(const Duration(days: 1)),
        );
      case StatisticsPeriod.allTime:
        return DateRange(
          start: DateTime(2020), // Far back start date
          end: today.add(const Duration(days: 1)),
        );
    }
  }
}

/// Represents a date range for filtering statistics
class DateRange {
  final DateTime start;
  final DateTime end;

  const DateRange({required this.start, required this.end});

  /// Check if a given date falls within this range
  bool contains(DateTime date) {
    return date.isAfter(start) && date.isBefore(end);
  }
}

/// Represents a single overlay usage event
class OverlayUsageEvent {
  final String id;
  final OverlayEventType type;
  final DateTime timestamp;
  final Map<String, dynamic>? metadata;

  const OverlayUsageEvent({
    required this.id,
    required this.type,
    required this.timestamp,
    this.metadata,
  });

  /// Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'timestamp': timestamp.toIso8601String(),
      'metadata': metadata,
    };
  }

  /// Create from JSON
  factory OverlayUsageEvent.fromJson(Map<String, dynamic> json) {
    return OverlayUsageEvent(
      id: json['id'] as String,
      type: OverlayEventType.values.firstWhere((e) => e.name == json['type']),
      timestamp: DateTime.parse(json['timestamp'] as String),
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  @override
  String toString() {
    return 'OverlayUsageEvent(id: $id, type: $type, timestamp: $timestamp)';
  }
}

/// Represents aggregated statistics for the overlay
class OverlayStatistics {
  final int messagesAnalyzed;
  final int suggestionsUsed;
  final int responsesRephrased;
  final StatisticsPeriod period;
  final DateTime lastUpdated;

  const OverlayStatistics({
    required this.messagesAnalyzed,
    required this.suggestionsUsed,
    required this.responsesRephrased,
    required this.period,
    required this.lastUpdated,
  });

  /// Create empty statistics
  factory OverlayStatistics.empty(StatisticsPeriod period) {
    return OverlayStatistics(
      messagesAnalyzed: 0,
      suggestionsUsed: 0,
      responsesRephrased: 0,
      period: period,
      lastUpdated: DateTime.now(),
    );
  }

  /// Create statistics from a list of events
  factory OverlayStatistics.fromEvents(
    List<OverlayUsageEvent> events,
    StatisticsPeriod period,
  ) {
    final filteredEvents = events.where((event) {
      return period.dateRange.contains(event.timestamp);
    }).toList();

    return OverlayStatistics(
      messagesAnalyzed: filteredEvents
          .where((e) => e.type == OverlayEventType.messageAnalyzed)
          .length,
      suggestionsUsed: filteredEvents
          .where((e) => e.type == OverlayEventType.suggestionUsed)
          .length,
      responsesRephrased: filteredEvents
          .where((e) => e.type == OverlayEventType.responseRephrased)
          .length,
      period: period,
      lastUpdated: DateTime.now(),
    );
  }

  /// Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'messagesAnalyzed': messagesAnalyzed,
      'suggestionsUsed': suggestionsUsed,
      'responsesRephrased': responsesRephrased,
      'period': period.name,
      'lastUpdated': lastUpdated.toIso8601String(),
    };
  }

  /// Create from JSON
  factory OverlayStatistics.fromJson(Map<String, dynamic> json) {
    return OverlayStatistics(
      messagesAnalyzed: json['messagesAnalyzed'] as int,
      suggestionsUsed: json['suggestionsUsed'] as int,
      responsesRephrased: json['responsesRephrased'] as int,
      period: StatisticsPeriod.values.firstWhere(
        (e) => e.name == json['period'],
      ),
      lastUpdated: DateTime.parse(json['lastUpdated'] as String),
    );
  }

  /// Copy with updated values
  OverlayStatistics copyWith({
    int? messagesAnalyzed,
    int? suggestionsUsed,
    int? responsesRephrased,
    StatisticsPeriod? period,
    DateTime? lastUpdated,
  }) {
    return OverlayStatistics(
      messagesAnalyzed: messagesAnalyzed ?? this.messagesAnalyzed,
      suggestionsUsed: suggestionsUsed ?? this.suggestionsUsed,
      responsesRephrased: responsesRephrased ?? this.responsesRephrased,
      period: period ?? this.period,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  @override
  String toString() {
    return 'OverlayStatistics(messagesAnalyzed: $messagesAnalyzed, suggestionsUsed: $suggestionsUsed, responsesRephrased: $responsesRephrased, period: $period)';
  }
}

/// Configuration for overlay statistics display
class OverlayStatsConfig {
  final StatisticsPeriod selectedPeriod;
  final bool showViewGraph;
  final DateTime lastRefresh;

  const OverlayStatsConfig({
    required this.selectedPeriod,
    required this.showViewGraph,
    required this.lastRefresh,
  });

  /// Default configuration
  factory OverlayStatsConfig.defaultConfig() {
    return OverlayStatsConfig(
      selectedPeriod: StatisticsPeriod.pastWeek,
      showViewGraph: false,
      lastRefresh: DateTime.now(),
    );
  }

  /// Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'selectedPeriod': selectedPeriod.name,
      'showViewGraph': showViewGraph,
      'lastRefresh': lastRefresh.toIso8601String(),
    };
  }

  /// Create from JSON
  factory OverlayStatsConfig.fromJson(Map<String, dynamic> json) {
    return OverlayStatsConfig(
      selectedPeriod: StatisticsPeriod.values.firstWhere(
        (e) => e.name == json['selectedPeriod'],
      ),
      showViewGraph: json['showViewGraph'] as bool,
      lastRefresh: DateTime.parse(json['lastRefresh'] as String),
    );
  }

  /// Copy with updated values
  OverlayStatsConfig copyWith({
    StatisticsPeriod? selectedPeriod,
    bool? showViewGraph,
    DateTime? lastRefresh,
  }) {
    return OverlayStatsConfig(
      selectedPeriod: selectedPeriod ?? this.selectedPeriod,
      showViewGraph: showViewGraph ?? this.showViewGraph,
      lastRefresh: lastRefresh ?? this.lastRefresh,
    );
  }
}
