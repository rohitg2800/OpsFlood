// lib/models/river_monitoring.dart
import '../models/flood_data.dart';

class RiverLevelSnapshot {
  final double   level;
  final DateTime timestamp;

  const RiverLevelSnapshot({required this.level, required this.timestamp});

  factory RiverLevelSnapshot.fromJson(Map<String, dynamic> j) {
    double d(dynamic v) {
      if (v == null) return 0.0;
      if (v is double) return v;
      if (v is int)    return v.toDouble();
      return double.tryParse(v.toString()) ?? 0.0;
    }
    return RiverLevelSnapshot(
      level: d(j['level'] ?? j['river_level'] ?? j['water_level']),
      timestamp: j['timestamp'] != null
          ? DateTime.tryParse(j['timestamp'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'level':     level,
    'timestamp': timestamp.toIso8601String(),
  };

  @override
  String toString() =>
      'RiverLevelSnapshot(${level}m @ ${timestamp.toIso8601String()})';
}

/// Thin wrapper returned by LiveFetchEngine.monitoringData.
class MultiLocationMonitoring {
  final List<FloodData> locations;
  final DateTime?       lastUpdated;

  const MultiLocationMonitoring({
    required this.locations,
    this.lastUpdated,
  });

  int get totalLocations   => locations.length;
  int get criticalCount    => locations.where((l) => l.riskLevel == 'CRITICAL').length;
  int get severeCount      => locations.where((l) => l.riskLevel == 'SEVERE').length;
  int get moderateCount    => locations.where((l) => l.riskLevel == 'MODERATE').length;
  bool get hasCritical     => criticalCount > 0;
}
