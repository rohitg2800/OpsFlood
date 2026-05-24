import '../constants.dart';
import 'flood_data.dart';

class CwcStationData {
  final String stationName;
  final String riverName;
  final String stateName;
  final double riverLevel;
  final double warningLevel;
  final double dangerLevel;
  final String trend; // 'RISING', 'FALLING', 'FLAT'
  final String status; // 'CRITICAL', 'WARNING', 'NORMAL'

  CwcStationData({
    required this.stationName,
    required this.riverName,
    required this.stateName,
    required this.riverLevel,
    required this.warningLevel,
    required this.dangerLevel,
    required this.trend,
    required this.status,
  });
}

class RiverLevelSnapshot {
  final DateTime timestamp;
  final double level;
  final double? flowRate;
  final String? status;

  const RiverLevelSnapshot({
    required this.timestamp,
    required this.level,
    this.flowRate,
    this.status,
  });

  factory RiverLevelSnapshot.fromJson(Map<String, dynamic> json) {
    return RiverLevelSnapshot(
      timestamp: DateTime.tryParse((json['timestamp'] ?? '').toString()) ??
          DateTime.now(),
      level: (json['level'] as num?)?.toDouble() ?? 0,
      flowRate: (json['flow_rate'] as num?)?.toDouble(),
      status: json['status']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'timestamp': timestamp.toIso8601String(),
        'level': level,
        'flow_rate': flowRate,
        'status': status,
      };
}

class RiverMonitoring {
  final String id;
  final String city;
  final String state;
  final String riverName;
  final double latitude;
  final double longitude;
  final double currentLevel;
  final double dangerLevel;
  final double warningLevel;
  final double safeLevel;
  final List<RiverLevelSnapshot> history;
  final DateTime lastUpdated;
  final String trend;
  final double? hourlyChange;
  final Duration? timeToPeak;
  final double? expectedPeakLevel;

  const RiverMonitoring({
    required this.id,
    required this.city,
    required this.state,
    required this.riverName,
    required this.latitude,
    required this.longitude,
    required this.currentLevel,
    required this.dangerLevel,
    required this.warningLevel,
    required this.safeLevel,
    required this.history,
    required this.lastUpdated,
    required this.trend,
    this.hourlyChange,
    this.timeToPeak,
    this.expectedPeakLevel,
  });

  double get capacityPercent {
    if (dangerLevel <= safeLevel) return 0;
    return ((currentLevel - safeLevel) / (dangerLevel - safeLevel) * 100)
        .clamp(0, 100);
  }

  String get riskLevel {
    if (capacityPercent >= AppConstants.criticalThreshold) return 'CRITICAL';
    if (capacityPercent >= AppConstants.highThreshold) return 'HIGH';
    if (capacityPercent >= AppConstants.moderateThreshold) return 'MODERATE';
    return 'LOW';
  }

  bool get isDangerZone => currentLevel >= dangerLevel;

  factory RiverMonitoring.fromFloodData(
    FloodData data,
    List<RiverLevelSnapshot> history,
  ) {
    return RiverMonitoring(
      id: data.id,
      city: data.city,
      state: data.state,
      riverName: data.riverName ?? 'River',
      latitude: data.latitude,
      longitude: data.longitude,
      currentLevel: data.currentLevel,
      dangerLevel: data.dangerLevel,
      warningLevel: data.warningLevel,
      safeLevel: data.safeLevel,
      history: history,
      lastUpdated: data.lastUpdated,
      trend: data.status,
      hourlyChange: _estimateHourlyChange(history),
      timeToPeak: data.expectedPeakTime == null
          ? null
          : data.expectedPeakTime!.difference(DateTime.now()),
      expectedPeakLevel: data.expectedPeakLevel,
    );
  }

  static double? _estimateHourlyChange(List<RiverLevelSnapshot> history) {
    if (history.length < 2) return null;
    final sorted = List<RiverLevelSnapshot>.from(history)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    final latest = sorted.last;
    final oneHourBack = sorted.lastWhere(
      (item) => latest.timestamp.difference(item.timestamp).inMinutes >= 60,
      orElse: () => sorted.first,
    );

    final hours =
        latest.timestamp.difference(oneHourBack.timestamp).inMinutes / 60;
    if (hours <= 0) return null;
    return (latest.level - oneHourBack.level) / hours;
  }
}

class MultiLocationMonitoring {
  final List<RiverMonitoring> locations;
  final DateTime fetchedAt;
  final bool fromCache;
  final String? errorMessage;

  const MultiLocationMonitoring({
    required this.locations,
    required this.fetchedAt,
    this.fromCache = false,
    this.errorMessage,
  });

  int get criticalCount =>
      locations.where((l) => l.riskLevel == 'CRITICAL').length;
  int get highRiskCount => locations.where((l) => l.riskLevel == 'HIGH').length;

  List<RiverMonitoring> get sortedByRisk {
    final riskOrder = {'CRITICAL': 0, 'HIGH': 1, 'MODERATE': 2, 'LOW': 3};
    final sorted = List<RiverMonitoring>.from(locations);
    sorted.sort((a, b) =>
        (riskOrder[a.riskLevel] ?? 10).compareTo(riskOrder[b.riskLevel] ?? 10));
    return sorted;
  }
}
