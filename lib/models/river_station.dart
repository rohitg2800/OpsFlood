// lib/models/river_station.dart
// Extended model — carries both static CWC thresholds AND live API fields.
// v2:   added lat/lon (nullable) and riskLabel getter.
// v2.1: guard hfl==0 and danger==0 in dangerClass so stations with no
//       seeded thresholds don't falsely show EXTREME/SEVERE.

export 'live_river_result_ext.dart';

class RiverStation {
  final String city;
  final String state;
  final String river;
  final String station;
  final double current;   // m – gauge reading (live or seeded)
  final double warning;   // m – CWC warning level
  final double danger;    // m – CWC danger level
  final double hfl;       // m – highest flood level

  // ── Geographic coordinates (null = not available) ──────────────────────
  final double? lat;
  final double? lon;

  // ── Live fields (null = not yet fetched) ────────────────────────────────
  final double?  rainfallLastHour;
  final double?  flowRate;
  final String?  trend;
  final String?  liveStatus;
  final String?  lastUpdated;
  final String?  dataSource;
  final bool     isLive;

  const RiverStation({
    required this.city,
    required this.state,
    required this.river,
    required this.station,
    required this.current,
    required this.warning,
    required this.danger,
    required this.hfl,
    this.lat,
    this.lon,
    this.rainfallLastHour,
    this.flowRate,
    this.trend,
    this.liveStatus,
    this.lastUpdated,
    this.dataSource,
    this.isLive = false,
  });

  DangerClass get dangerClass {
    // Guard: if hfl or danger are 0 (not seeded) skip those tiers to avoid
    // falsely classifying every station as extreme/severe.
    if (hfl    > 0 && current >= hfl)    return DangerClass.extreme;
    if (danger > 0 && current >= danger) return DangerClass.severe;
    if (warning > 0 && current >= warning) return DangerClass.aboveNormal;
    return DangerClass.normal;
  }

  /// Human-readable risk label — kept in sync with AlertSeverity labels
  /// used across the rest of the app.
  String get riskLabel {
    switch (dangerClass) {
      case DangerClass.extreme:     return 'CRITICAL';
      case DangerClass.severe:      return 'SEVERE';
      case DangerClass.aboveNormal: return 'WARNING';
      case DangerClass.normal:      return 'NORMAL';
    }
  }

  double get progressPct => hfl > 0 ? (current / hfl).clamp(0.0, 1.0) : 0.0;
  int    get riskScore   => dangerClass.index;

  RiverStation copyWith({
    double?  current,
    double?  warning,
    double?  danger,
    double?  hfl,
    double?  lat,
    double?  lon,
    double?  rainfallLastHour,
    double?  flowRate,
    String?  trend,
    String?  liveStatus,
    String?  lastUpdated,
    String?  dataSource,
    bool?    isLive,
  }) => RiverStation(
    city:             city,
    state:            state,
    river:            river,
    station:          station,
    current:          current          ?? this.current,
    warning:          warning          ?? this.warning,
    danger:           danger           ?? this.danger,
    hfl:              hfl              ?? this.hfl,
    lat:              lat              ?? this.lat,
    lon:              lon              ?? this.lon,
    rainfallLastHour: rainfallLastHour ?? this.rainfallLastHour,
    flowRate:         flowRate         ?? this.flowRate,
    trend:            trend            ?? this.trend,
    liveStatus:       liveStatus       ?? this.liveStatus,
    lastUpdated:      lastUpdated      ?? this.lastUpdated,
    dataSource:       dataSource       ?? this.dataSource,
    isLive:           isLive           ?? this.isLive,
  );
}

enum DangerClass { normal, aboveNormal, severe, extreme }

extension DangerClassExt on DangerClass {
  String get label {
    switch (this) {
      case DangerClass.normal:      return 'Normal';
      case DangerClass.aboveNormal: return 'Above Normal';
      case DangerClass.severe:      return 'Severe';
      case DangerClass.extreme:     return 'Extreme';
    }
  }
}
