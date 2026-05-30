class Station {
  final String id;
  final String name;
  final String river;
  final String district;
  final double lat;
  final double lon;
  final double currentLevel;
  final double dangerLevel;
  final double warningLevel;
  final double safeLevel;
  final double hfl;
  final String status; // normal | warning | danger
  final String trend;  // rising | falling | stable
  final double pctToDanger;
  final String riskLevel;
  final String dataSource;
  final String lastUpdated;
  final double aboveDangerM;
  final bool alertActive;

  const Station({
    required this.id,
    required this.name,
    required this.river,
    required this.district,
    required this.lat,
    required this.lon,
    required this.currentLevel,
    required this.dangerLevel,
    required this.warningLevel,
    required this.safeLevel,
    required this.hfl,
    required this.status,
    required this.trend,
    required this.pctToDanger,
    required this.riskLevel,
    required this.dataSource,
    required this.lastUpdated,
    required this.aboveDangerM,
    required this.alertActive,
  });

  factory Station.fromJson(Map<String, dynamic> j) => Station(
    id:           j['id'] ?? '',
    name:         j['name'] ?? '',
    river:        j['river'] ?? '',
    district:     j['district'] ?? '',
    lat:          (j['lat'] ?? 0).toDouble(),
    lon:          (j['lon'] ?? 0).toDouble(),
    currentLevel: (j['current_level'] ?? 0).toDouble(),
    dangerLevel:  (j['danger_level'] ?? 0).toDouble(),
    warningLevel: (j['warning_level'] ?? 0).toDouble(),
    safeLevel:    (j['safe_level'] ?? 0).toDouble(),
    hfl:          (j['hfl'] ?? 0).toDouble(),
    status:       j['status'] ?? 'normal',
    trend:        j['trend'] ?? 'stable',
    pctToDanger:  (j['pct_to_danger'] ?? 0).toDouble().clamp(0, 100),
    riskLevel:    j['risk_level'] ?? 'LOW',
    dataSource:   j['data_source'] ?? '',
    lastUpdated:  j['last_updated'] ?? '',
    aboveDangerM: (j['above_danger_m'] ?? 0).toDouble(),
    alertActive:  j['alert_active'] ?? false,
  );

  bool get isDanger  => status == 'danger';
  bool get isWarning => status == 'warning';
  bool get isNormal  => status == 'normal';
  bool get isLive    => dataSource.contains('LIVE') || dataSource.contains('RTDAS');

  /// How full is the gauge 0.0–1.0, clamped to safe range
  double get fillFraction {
    final range = dangerLevel - safeLevel;
    if (range <= 0) return 0.5;
    return ((currentLevel - safeLevel) / range).clamp(0.0, 1.0);
  }
}

class Summary {
  final int total;
  final int biharTotal;
  final int normal;
  final int warning;
  final int danger;
  final List<String> dangerStations;

  const Summary({
    required this.total,
    required this.biharTotal,
    required this.normal,
    required this.warning,
    required this.danger,
    required this.dangerStations,
  });

  factory Summary.fromJson(Map<String, dynamic> j) => Summary(
    total:          j['total'] ?? 0,
    biharTotal:     j['bihar_total'] ?? 0,
    normal:         j['normal'] ?? 0,
    warning:        j['warning'] ?? 0,
    danger:         j['danger'] ?? 0,
    dangerStations: List<String>.from(j['danger_stations'] ?? []),
  );
}
