import '../constants.dart';

class FloodData {
  final String id;
  final String city;
  final String state;
  final double latitude;
  final double longitude;
  final double currentLevel;
  final double dangerLevel;
  final double warningLevel;
  final double safeLevel;
  final String riskLevel;
  final DateTime lastUpdated;
  final String? riverName;
  final double? flowRate;
  final double? rainfall24h;
  final String status;
  final DateTime? expectedPeakTime;
  final double? expectedPeakLevel;

  const FloodData({
    required this.id,
    required this.city,
    required this.state,
    required this.latitude,
    required this.longitude,
    required this.currentLevel,
    required this.dangerLevel,
    required this.warningLevel,
    required this.safeLevel,
    required this.riskLevel,
    required this.lastUpdated,
    required this.status,
    this.riverName,
    this.flowRate,
    this.rainfall24h,
    this.expectedPeakTime,
    this.expectedPeakLevel,
  });

  double get capacityPercent {
    if (dangerLevel <= safeLevel) return 0;
    final percent =
        ((currentLevel - safeLevel) / (dangerLevel - safeLevel)) * 100;
    return percent.clamp(0, 100);
  }

  bool get isCritical => capacityPercent >= AppConstants.criticalThreshold;
  bool get isHigh => capacityPercent >= AppConstants.highThreshold;

  FloodData copyWith({
    String? id,
    String? city,
    String? state,
    double? latitude,
    double? longitude,
    double? currentLevel,
    double? dangerLevel,
    double? warningLevel,
    double? safeLevel,
    String? riskLevel,
    DateTime? lastUpdated,
    String? riverName,
    double? flowRate,
    double? rainfall24h,
    String? status,
    DateTime? expectedPeakTime,
    double? expectedPeakLevel,
  }) {
    return FloodData(
      id: id ?? this.id,
      city: city ?? this.city,
      state: state ?? this.state,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      currentLevel: currentLevel ?? this.currentLevel,
      dangerLevel: dangerLevel ?? this.dangerLevel,
      warningLevel: warningLevel ?? this.warningLevel,
      safeLevel: safeLevel ?? this.safeLevel,
      riskLevel: riskLevel ?? this.riskLevel,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      riverName: riverName ?? this.riverName,
      flowRate: flowRate ?? this.flowRate,
      rainfall24h: rainfall24h ?? this.rainfall24h,
      status: status ?? this.status,
      expectedPeakTime: expectedPeakTime ?? this.expectedPeakTime,
      expectedPeakLevel: expectedPeakLevel ?? this.expectedPeakLevel,
    );
  }

  static double _asDouble(dynamic value, double fallback) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? fallback;
    return fallback;
  }

  static DateTime _asDateTime(dynamic value) {
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    return DateTime.now();
  }

  static String _normalizeRisk(String? raw, double capacityPercent) {
    final value = (raw ?? '').trim().toUpperCase();
    if (AppConstants.riskColors.containsKey(value)) return value;
    if (capacityPercent >= AppConstants.criticalThreshold) return 'CRITICAL';
    if (capacityPercent >= AppConstants.highThreshold) return 'HIGH';
    if (capacityPercent >= AppConstants.moderateThreshold) return 'MODERATE';
    return 'LOW';
  }

  factory FloodData.fromJson(Map<String, dynamic> json) {
    // FIX: Backend sends river_level (not current_level). Priority: river_level > current_level > level
    final currentLevel = _asDouble(
      json['river_level'] ?? json['current_level'] ?? json['level'],
      0,
    );
    final dangerLevel =
        _asDouble(json['danger_level'], AppConstants.defaultDangerLevel);
    final safeLevel =
        _asDouble(json['safe_level'], AppConstants.defaultSafeLevel);
    final warningLevel = _asDouble(
      json['warning_level'],
      AppConstants.defaultWarningLevel,
    );

    final capacityPercent = dangerLevel <= safeLevel
        ? 0
        : ((currentLevel - safeLevel) / (dangerLevel - safeLevel) * 100)
            .clamp(0, 100);

    // FIX: Backend sends 'station' field not 'city'. Try station first, then city.
    final cityName = (json['station'] ?? json['city'] ?? '').toString();

    return FloodData(
      id: (json['id'] ??
              '${cityName}-${json['state'] ?? 'na'}')
          .toString(),
      city: cityName,
      state: (json['state'] ?? '').toString(),
      // FIX: Backend does not send lat/lon in live-telemetry; default to 0.0 (map overlay skips zero-coord pins)
      latitude:  _asDouble(json['latitude']  ?? json['lat'], 0),
      longitude: _asDouble(json['longitude'] ?? json['lon'], 0),
      currentLevel: currentLevel,
      dangerLevel: dangerLevel,
      warningLevel: warningLevel,
      safeLevel: safeLevel,
      riskLevel: _normalizeRisk(
          (json['risk_level'] ?? json['severity'])?.toString(),
          capacityPercent.toDouble()),
      lastUpdated: _asDateTime(json['last_updated'] ?? json['timestamp']),
      riverName: (json['river_name'] ?? json['river'])?.toString(),
      flowRate:
          json['flow_rate'] == null ? null : _asDouble(json['flow_rate'], 0),
      rainfall24h: json['rainfall_24h'] == null
          ? null
          : _asDouble(json['rainfall_24h'], 0),
      status: (json['status'] ?? 'Stable').toString(),
      expectedPeakTime: json['expected_peak_time'] == null
          ? null
          : DateTime.tryParse(json['expected_peak_time'].toString()),
      expectedPeakLevel: json['expected_peak_level'] == null
          ? null
          : _asDouble(json['expected_peak_level'], 0),
    );
  }

  factory FloodData.fromMonitoredCity(Map<String, dynamic> cityData) {
    // FIX: Use city-specific danger/warning levels from the monitoredCities map.
    // Previously used hardcoded defaultDangerLevel=12 / defaultSafeLevel=8 for ALL cities,
    // which made capacityPercent wildly wrong for cities like Guwahati (51.75m),
    // Patna (48.6m), Kanpur (111.5m) etc.
    final risk = (cityData['risk'] ?? 'LOW').toString().toUpperCase();
    final dangerLevel  = _asDouble(cityData['danger_level'],  AppConstants.defaultDangerLevel);
    final warningLevel = _asDouble(cityData['warning_level'], AppConstants.defaultWarningLevel);
    // safeLevel = warning_level - 2m is a reasonable CWC approximation
    final safeLevel    = warningLevel - 2.0;

    final capacity = switch (risk) {
      'CRITICAL' => 92.0,
      'HIGH'     => 78.0,
      'MODERATE' => 58.0,
      _          => 36.0,
    };
    // Derive a plausible currentLevel from city-specific danger/safe band
    final effectiveSafe = safeLevel < 0 ? 0.0 : safeLevel;
    final currentLevel  = effectiveSafe + (dangerLevel - effectiveSafe) * (capacity / 100);

    return FloodData(
      id:           '${cityData['city']}-${cityData['state']}',
      city:         cityData['city'].toString(),
      state:        cityData['state'].toString(),
      latitude:     _asDouble(cityData['lat'], 0),
      longitude:    _asDouble(cityData['lon'], 0),
      currentLevel: currentLevel,
      dangerLevel:  dangerLevel,
      warningLevel: warningLevel,
      safeLevel:    effectiveSafe,
      riskLevel:    risk,
      lastUpdated:  DateTime.now(),
      riverName:    cityData['river']?.toString(),
      flowRate:     null,
      rainfall24h:  null,
      status:       'Stable',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'city': city,
        'state': state,
        'latitude': latitude,
        'longitude': longitude,
        'current_level': currentLevel,
        'danger_level': dangerLevel,
        'warning_level': warningLevel,
        'safe_level': safeLevel,
        'risk_level': riskLevel,
        'last_updated': lastUpdated.toIso8601String(),
        'river_name': riverName,
        'flow_rate': flowRate,
        'rainfall_24h': rainfall24h,
        'status': status,
        'expected_peak_time': expectedPeakTime?.toIso8601String(),
        'expected_peak_level': expectedPeakLevel,
      };
}

class FloodAlert {
  final String id;
  final String city;
  final String state;
  final String severity;
  final String title;
  final String message;
  final DateTime timestamp;
  final bool resolved;
  final String? riverName;
  final double? currentLevel;
  final double? dangerLevel;
  final String? recommendation;

  const FloodAlert({
    required this.id,
    required this.city,
    required this.state,
    required this.severity,
    required this.title,
    required this.message,
    required this.timestamp,
    required this.resolved,
    this.riverName,
    this.currentLevel,
    this.dangerLevel,
    this.recommendation,
  });

  static String _normalizeSeverity(String? raw) {
    final value = (raw ?? '').toUpperCase();
    if (AppConstants.riskColors.containsKey(value)) return value;
    if (value == 'SEVERE') return 'CRITICAL';
    return 'MODERATE';
  }

  static double? _nullableDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  factory FloodAlert.fromJson(Map<String, dynamic> json) {
    final city = (json['city'] ?? json['station'] ?? '').toString();
    final state = (json['state'] ?? '').toString();
    final timestamp = DateTime.tryParse(
            (json['timestamp'] ?? json['created_at'] ?? '').toString()) ??
        DateTime.now();

    return FloodAlert(
      id: (json['id'] ?? '${city}_${state}_${timestamp.millisecondsSinceEpoch}')
          .toString(),
      city: city,
      state: state,
      severity:
          _normalizeSeverity((json['severity'] ?? json['risk'])?.toString()),
      title: (json['title'] ?? 'Flood Alert').toString(),
      message: (json['message'] ?? json['desc'] ?? '').toString(),
      timestamp: timestamp,
      resolved: json['resolved'] == true,
      riverName: (json['river_name'] ?? json['river'])?.toString(),
      currentLevel: _nullableDouble(json['current_level']),
      dangerLevel: _nullableDouble(json['danger_level']),
      recommendation: json['recommendation']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'city': city,
        'state': state,
        'severity': severity,
        'title': title,
        'message': message,
        'timestamp': timestamp.toIso8601String(),
        'resolved': resolved,
        'river_name': riverName,
        'current_level': currentLevel,
        'danger_level': dangerLevel,
        'recommendation': recommendation,
      };
}
