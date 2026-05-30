// lib/models/river_monitoring.dart
//
// RiverLevelSnapshot — a single timestamped gauge reading.
//
// Used by:
//   • CityDetailScreen  — List<RiverLevelSnapshot> trend (24-hr sparkline)
//   • DashboardScreen   — RealTimeService.trendForCity() return type
//
// Both screens access:
//   snapshot.level     → double  (gauge height in metres)
//   snapshot.timestamp → DateTime

class RiverLevelSnapshot {
  final double   level;     // metres above datum
  final DateTime timestamp;

  const RiverLevelSnapshot({
    required this.level,
    required this.timestamp,
  });

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
