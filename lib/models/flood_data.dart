import '../constants.dart';

// ─────────────────────────────────────────────────────────────────────────────
// FLOOD RISK ENGINE
// Multi-factor weighted scoring model for statistically differentiated
// capacity estimates when live telemetry is unavailable.
//
// Score (0–100) = Σ weight_i × factor_i
//
// Factor                  Weight  Source
// ─────────────────────────────  ───────
// seasonal_baseline         0.30  IMD monsoon calendar + river_type
// historical_flood_freq     0.25  NDMA flood hazard atlas (flood_freq field)
// gauge_ratio               0.25  (warning_level / danger_level) band tightness
// geographic_vulnerability  0.15  zone × river_type interaction
// baseline_risk_tag         0.05  CWC risk label (LOW/MODERATE/HIGH/CRITICAL)
// ─────────────────────────────────────────────────────────────────────────────
class FloodRiskEngine {
  /// Compute a realistic capacity percent [0–100] for a city in the
  /// monitored-cities registry when no live gauge reading is available.
  static double computeFallbackCapacity(Map<String, dynamic> city) {
    final risk       = (city['risk']       as String? ?? 'LOW').toUpperCase();
    final zone       = (city['zone']       as String? ?? 'peninsular').toLowerCase();
    final riverType  = (city['river_type'] as String? ?? 'perennial').toLowerCase();
    final floodFreq  = (city['flood_freq'] as double? ?? 0.4).clamp(0.0, 1.0);
    final danger     = (city['danger_level']  as double? ?? AppConstants.defaultDangerLevel);
    final warning    = (city['warning_level'] as double? ?? AppConstants.defaultWarningLevel);

    // ── Factor 1: Seasonal baseline (30%) ─────────────────────────────
    final month = DateTime.now().month;
    final seasonal = _seasonalFactor(zone, riverType, month);

    // ── Factor 2: Historical flood frequency (25%) ────────────────────
    final freqScore = floodFreq;

    // ── Factor 3: Gauge band ratio (25%) ─────────────────────────────
    final band       = danger - warning;
    final gaugeScore = band <= 0 ? 0.5
        : (1.0 - (band / (danger * 0.3)).clamp(0.0, 1.0));

    // ── Factor 4: Geographic vulnerability (15%) ─────────────────────
    final geoScore = _geoVulnerability(zone, riverType);

    // ── Factor 5: Baseline risk tag (5%) ─────────────────────────────
    final tagScore = switch (risk) {
      'CRITICAL' => 1.00,
      'HIGH'     => 0.75,
      'MODERATE' => 0.50,
      _          => 0.20,
    };

    final raw = (seasonal   * 0.30)
              + (freqScore  * 0.25)
              + (gaugeScore * 0.25)
              + (geoScore   * 0.15)
              + (tagScore   * 0.05);

    final jitter = _deterministicJitter(city['city'] as String? ?? '');
    return (raw * 100.0 + jitter).clamp(5.0, 98.0);
  }

  static double _seasonalFactor(String zone, String riverType, int month) {
    if (riverType == 'glacier') {
      return _bellCurve(month, peak: 7, width: 2.5);
    }
    switch (zone) {
      case 'northeastern':
        return _bellCurve(month, peak: 7.5, width: 2.0);
      case 'coastal':
        final sw = _bellCurve(month, peak: 7.0, width: 2.0);
        final ne = _bellCurve(month, peak: 11.0, width: 1.5);
        return (sw + ne) / 2.0;
      case 'himalayan':
        final monsoon  = _bellCurve(month, peak: 8.0, width: 2.0);
        final snowmelt = _bellCurve(month, peak: 4.0, width: 1.5);
        return (monsoon * 0.7 + snowmelt * 0.3);
      case 'arid':
        return _bellCurve(month, peak: 7.5, width: 1.5) * 0.6;
      case 'central':
        return _bellCurve(month, peak: 8.0, width: 2.5);
      default:
        return _bellCurve(month, peak: 7.5, width: 2.0);
    }
  }

  static double _bellCurve(int month, {required double peak, required double width}) {
    final diff = month.toDouble() - peak;
    return _exp(-(diff * diff) / (2.0 * width * width));
  }

  static double _exp(double x) {
    if (x < -10) return 0.0;
    return 1.0 / (1.0 + (-x) + 0.5 * x * x * (1 + x / 3.0 + x * x / 24.0).abs());
  }

  static double _geoVulnerability(String zone, String riverType) {
    const zoneBase = <String, double>{
      'northeastern': 0.85,
      'himalayan':    0.75,
      'coastal':      0.70,
      'central':      0.55,
      'peninsular':   0.50,
      'arid':         0.30,
    };
    const typeBonus = <String, double>{
      'glacier':   0.10,
      'perennial': 0.05,
      'coastal':   0.08,
      'seasonal':  0.00,
    };
    final base  = zoneBase[zone]  ?? 0.50;
    final bonus = typeBonus[riverType] ?? 0.0;
    return (base + bonus).clamp(0.0, 1.0);
  }

  static double _deterministicJitter(String cityName) {
    var hash = 0;
    for (final c in cityName.codeUnits) {
      hash = (hash * 31 + c) & 0xFFFFFFFF;
    }
    return ((hash % 600) - 300) / 100.0;
  }
}

// ─────────────────────────────────────────────────────────────────────────────

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

  // Backend prediction metadata
  final int? riskScore;
  final double? confidencePercent;
  final String? monitoringLevel;
  final String? monitoringAction;

  // ── IMD enrichment fields (Pass 4) ─────────────────────────────────
  // imdRainfallMm: authoritative 24-hr IMD rainfall for this city's district.
  //   When present, flood_engine.dart should prefer this over any backend
  //   rainfall estimate for the rainfall axis in severityFromEntry().
  // imdSeverity: IMD colour-code for the district (RED | ORANGE | YELLOW | GREEN).
  //   Screens can overlay this as a badge on city cards.
  final double? imdRainfallMm;
  final String? imdSeverity;

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
    this.riskScore,
    this.confidencePercent,
    this.monitoringLevel,
    this.monitoringAction,
    this.imdRainfallMm,
    this.imdSeverity,
  });

  double get capacityPercent {
    if (dangerLevel <= safeLevel) return 0;
    final percent =
        ((currentLevel - safeLevel) / (dangerLevel - safeLevel)) * 100;
    return percent.clamp(0, 100);
  }

  bool get isCritical => capacityPercent >= AppConstants.criticalThreshold;
  bool get isHigh => capacityPercent >= AppConstants.highThreshold;

  /// UI-derived priority tier for chips/badges/list emphasis.
  String get priorityTier => switch (riskLevel.toUpperCase()) {
    'CRITICAL' => 'P1',
    'SEVERE' => 'P1',
    'HIGH' => 'P2',
    'MODERATE' => 'P3',
    _ => 'P4',
  };

  /// UI-derived semantic color token name.
  String get priorityColor => switch (riskLevel.toUpperCase()) {
    'CRITICAL' => 'red',
    'SEVERE' => 'red',
    'HIGH' => 'orange',
    'MODERATE' => 'yellow',
    _ => 'green',
  };

  /// Whether this data point has been enriched with authoritative IMD data.
  bool get hasImdData => imdRainfallMm != null && imdRainfallMm! > 0;

  /// The best available rainfall figure: IMD authoritative if present,
  /// otherwise the backend-provided 24-hour rainfall value.
  double get effectiveRainfallMm => imdRainfallMm ?? rainfall24h ?? 0.0;

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
    int? riskScore,
    double? confidencePercent,
    String? monitoringLevel,
    String? monitoringAction,
    double? imdRainfallMm,
    String? imdSeverity,
  }) {
    return FloodData(
      id:                id               ?? this.id,
      city:              city             ?? this.city,
      state:             state            ?? this.state,
      latitude:          latitude         ?? this.latitude,
      longitude:         longitude        ?? this.longitude,
      currentLevel:      currentLevel     ?? this.currentLevel,
      dangerLevel:       dangerLevel      ?? this.dangerLevel,
      warningLevel:      warningLevel     ?? this.warningLevel,
      safeLevel:         safeLevel        ?? this.safeLevel,
      riskLevel:         riskLevel        ?? this.riskLevel,
      lastUpdated:       lastUpdated      ?? this.lastUpdated,
      riverName:         riverName        ?? this.riverName,
      flowRate:          flowRate         ?? this.flowRate,
      rainfall24h:       rainfall24h      ?? this.rainfall24h,
      status:            status           ?? this.status,
      expectedPeakTime:  expectedPeakTime ?? this.expectedPeakTime,
      expectedPeakLevel: expectedPeakLevel ?? this.expectedPeakLevel,
      riskScore:         riskScore        ?? this.riskScore,
      confidencePercent: confidencePercent ?? this.confidencePercent,
      monitoringLevel:   monitoringLevel  ?? this.monitoringLevel,
      monitoringAction:  monitoringAction ?? this.monitoringAction,
      imdRainfallMm:     imdRainfallMm    ?? this.imdRainfallMm,
      imdSeverity:       imdSeverity      ?? this.imdSeverity,
    );
  }

  static double _asDouble(dynamic value, double fallback) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? fallback;
    return fallback;
  }

  static int? _asIntOrNull(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  static DateTime _asDateTime(dynamic value) {
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    return DateTime.now();
  }

  static String _normalizeRisk(String? raw, double capacityPercent) {
    final value = (raw ?? '').trim().toUpperCase();
    if (AppConstants.riskColors.containsKey(value)) return value;
    if (value == 'SEVERE') return 'CRITICAL';
    if (capacityPercent >= AppConstants.criticalThreshold) return 'CRITICAL';
    if (capacityPercent >= AppConstants.highThreshold) return 'HIGH';
    if (capacityPercent >= AppConstants.moderateThreshold) return 'MODERATE';
    return 'LOW';
  }

  factory FloodData.fromJson(Map<String, dynamic> json) {
    final currentLevel = _asDouble(
      json['river_level'] ?? json['current_level'] ?? json['level'], 0,
    );
    final dangerLevel =
        _asDouble(json['danger_level'], AppConstants.defaultDangerLevel);
    final safeLevel =
        _asDouble(json['safe_level'], AppConstants.defaultSafeLevel);
    final warningLevel = _asDouble(
      json['warning_level'], AppConstants.defaultWarningLevel,
    );

    final capacityPercent = dangerLevel <= safeLevel
        ? 0
        : ((currentLevel - safeLevel) / (dangerLevel - safeLevel) * 100)
            .clamp(0, 100);

    final cityName = (json['station'] ?? json['city'] ?? '').toString();

    return FloodData(
      id: (json['id'] ?? '${cityName}-${json['state'] ?? 'na'}').toString(),
      city: cityName,
      state: (json['state'] ?? '').toString(),
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
      riskScore: _asIntOrNull(json['risk_score']),
      confidencePercent: json['confidence_percent'] == null
          ? null
          : _asDouble(json['confidence_percent'], 0),
      monitoringLevel: (json['monitoring_level'] ?? json['monitoring']?['level'])?.toString(),
      monitoringAction: (json['monitoring_action'] ?? json['monitoring']?['action'])?.toString(),
      // IMD fields: only present after Pass 4 enrichment (null safe)
      imdRainfallMm: json['imd_rainfall_mm'] == null
          ? null
          : _asDouble(json['imd_rainfall_mm'], 0),
      imdSeverity: json['imd_severity']?.toString(),
    );
  }

  factory FloodData.fromMonitoredCity(Map<String, dynamic> cityData) {
    final dangerLevel  = _asDouble(cityData['danger_level'],  AppConstants.defaultDangerLevel);
    final warningLevel = _asDouble(cityData['warning_level'], AppConstants.defaultWarningLevel);
    final safeLevel    = (warningLevel - 2.0).clamp(0.0, double.infinity);
    final risk         = (cityData['risk'] as String? ?? 'LOW').toUpperCase();

    final capacity = FloodRiskEngine.computeFallbackCapacity(cityData);
    final currentLevel = safeLevel + (dangerLevel - safeLevel) * (capacity / 100.0);

    final computedRisk = capacity >= AppConstants.criticalThreshold ? 'CRITICAL'
        : capacity >= AppConstants.highThreshold     ? 'HIGH'
        : capacity >= AppConstants.moderateThreshold ? 'MODERATE'
        : 'LOW';

    final finalRisk = _worstCase(risk, computedRisk);

    return FloodData(
      id:           '${cityData['city']}-${cityData['state']}',
      city:         (cityData['city'] as String? ?? ''),
      state:        (cityData['state'] as String? ?? ''),
      latitude:     _asDouble(cityData['lat'], 0),
      longitude:    _asDouble(cityData['lon'], 0),
      currentLevel: currentLevel,
      dangerLevel:  dangerLevel,
      warningLevel: warningLevel,
      safeLevel:    safeLevel,
      riskLevel:    finalRisk,
      lastUpdated:  DateTime.now(),
      riverName:    cityData['river']?.toString(),
      flowRate:     null,
      rainfall24h:  null,
      status:       'Estimated',
      riskScore:    null,
      confidencePercent: null,
      monitoringLevel: null,
      monitoringAction: null,
      // IMD fields not available at fallback construction time;
      // enriched later by RealTimeService._enrichWithImd()
      imdRainfallMm: null,
      imdSeverity:   null,
    );
  }

  static String _worstCase(String a, String b) {
    const order = ['LOW', 'MODERATE', 'HIGH', 'CRITICAL'];
    final ai = order.indexOf(a);
    final bi = order.indexOf(b);
    return ai >= bi ? a : b;
  }

  Map<String, dynamic> toJson() => {
        'id':                   id,
        'city':                 city,
        'state':                state,
        'latitude':             latitude,
        'longitude':            longitude,
        'current_level':        currentLevel,
        'danger_level':         dangerLevel,
        'warning_level':        warningLevel,
        'safe_level':           safeLevel,
        'risk_level':           riskLevel,
        'last_updated':         lastUpdated.toIso8601String(),
        'river_name':           riverName,
        'flow_rate':            flowRate,
        'rainfall_24h':         rainfall24h,
        'status':               status,
        'expected_peak_time':   expectedPeakTime?.toIso8601String(),
        'expected_peak_level':  expectedPeakLevel,
        'risk_score':           riskScore,
        'confidence_percent':   confidencePercent,
        'monitoring_level':     monitoringLevel,
        'monitoring_action':    monitoringAction,
        'priority_tier':        priorityTier,
        'priority_color':       priorityColor,
        // IMD fields — null if not yet enriched
        'imd_rainfall_mm':      imdRainfallMm,
        'imd_severity':         imdSeverity,
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
