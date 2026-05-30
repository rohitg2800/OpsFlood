// lib/models/flood_data.dart
//
// FloodData — one city's live flood snapshot.
// Fields derived directly from CityDetailScreen + DashboardScreen usage.
//
// Backend riskLevel values : 'CRITICAL' | 'HIGH' | 'MODERATE' | 'LOW'
// Backend imdSeverity values: 'RED' | 'ORANGE' | 'YELLOW' | null

class FloodData {
  final String  city;
  final String  state;
  final String? riverName;

  // Gauge levels (metres)
  final double currentLevel;
  final double warningLevel;
  final double dangerLevel;
  final double safeLevel;

  /// 0–100 — percentage of danger-level capacity currently occupied.
  final double capacityPercent;

  /// 'CRITICAL' | 'HIGH' | 'MODERATE' | 'LOW'
  final String riskLevel;

  /// 'LIVE' (CWC) or 'ESTIMATED'
  final String status;

  // IMD fields (nullable — only present when IMD data is available)
  final String? imdSeverity;   // 'RED' | 'ORANGE' | 'YELLOW'
  final double? imdRainfallMm; // IMD 24-hr rainfall reading

  /// Best-available 24-hr rainfall (IMD when present, otherwise CWC/WRD).
  final double effectiveRainfallMm;

  /// River discharge — null when station doesn't report flow.
  final double? flowRate;

  final DateTime lastUpdated;

  const FloodData({
    required this.city,
    required this.state,
    this.riverName,
    required this.currentLevel,
    required this.warningLevel,
    required this.dangerLevel,
    required this.safeLevel,
    required this.capacityPercent,
    required this.riskLevel,
    required this.status,
    this.imdSeverity,
    this.imdRainfallMm,
    required this.effectiveRainfallMm,
    this.flowRate,
    required this.lastUpdated,
  });

  factory FloodData.fromJson(Map<String, dynamic> j) {
    // Helper: safely parse any JSON numeric value to double.
    double d(dynamic v, [double fallback = 0.0]) {
      if (v == null) return fallback;
      if (v is double) return v;
      if (v is int)    return v.toDouble();
      return double.tryParse(v.toString()) ?? fallback;
    }

    double? dNull(dynamic v) {
      if (v == null) return null;
      if (v is double) return v;
      if (v is int)    return v.toDouble();
      return double.tryParse(v.toString());
    }

    final warning = d(j['warning_level'] ?? j['warningLevel']);
    final danger  = d(j['danger_level']  ?? j['dangerLevel']);
    final current = d(j['current_level'] ?? j['currentLevel']);

    // capacity_percent may come pre-computed from backend or we derive it.
    final rawCap = j['capacity_percent'] ?? j['capacityPercent'];
    final cap    = rawCap != null
        ? d(rawCap)
        : (danger > 0 ? (current / danger * 100).clamp(0.0, 100.0) : 0.0);

    final imdRain = dNull(j['imd_rainfall_mm'] ?? j['imdRainfallMm']);
    final cwcRain = d(j['rainfall_24h_mm'] ?? j['effectiveRainfallMm']);

    return FloodData(
      city:                 (j['city']      as String?  ) ?? '',
      state:                (j['state']     as String?  ) ?? '',
      riverName:             j['river_name'] as String?,
      currentLevel:         current,
      warningLevel:         warning,
      dangerLevel:          danger,
      safeLevel:            d(j['safe_level'] ?? j['safeLevel']),
      capacityPercent:      cap,
      riskLevel:            (j['risk_level'] ?? j['riskLevel'] ?? 'LOW') as String,
      status:               (j['status']     as String?  ) ?? 'ESTIMATED',
      imdSeverity:           j['imd_severity'] as String?,
      imdRainfallMm:        imdRain,
      effectiveRainfallMm:  imdRain ?? cwcRain,
      flowRate:             dNull(j['flow_rate'] ?? j['flowRate']),
      lastUpdated:          j['last_updated'] != null
          ? DateTime.tryParse(j['last_updated'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'city':                  city,
    'state':                 state,
    'river_name':            riverName,
    'current_level':         currentLevel,
    'warning_level':         warningLevel,
    'danger_level':          dangerLevel,
    'safe_level':            safeLevel,
    'capacity_percent':      capacityPercent,
    'risk_level':            riskLevel,
    'status':                status,
    'imd_severity':          imdSeverity,
    'imd_rainfall_mm':       imdRainfallMm,
    'rainfall_24h_mm':       effectiveRainfallMm,
    'flow_rate':             flowRate,
    'last_updated':          lastUpdated.toIso8601String(),
  };

  FloodData copyWith({
    String?   city,
    String?   state,
    String?   riverName,
    double?   currentLevel,
    double?   warningLevel,
    double?   dangerLevel,
    double?   safeLevel,
    double?   capacityPercent,
    String?   riskLevel,
    String?   status,
    String?   imdSeverity,
    double?   imdRainfallMm,
    double?   effectiveRainfallMm,
    double?   flowRate,
    DateTime? lastUpdated,
  }) =>
      FloodData(
        city:                city                ?? this.city,
        state:               state               ?? this.state,
        riverName:           riverName           ?? this.riverName,
        currentLevel:        currentLevel        ?? this.currentLevel,
        warningLevel:        warningLevel        ?? this.warningLevel,
        dangerLevel:         dangerLevel         ?? this.dangerLevel,
        safeLevel:           safeLevel           ?? this.safeLevel,
        capacityPercent:     capacityPercent     ?? this.capacityPercent,
        riskLevel:           riskLevel           ?? this.riskLevel,
        status:              status              ?? this.status,
        imdSeverity:         imdSeverity         ?? this.imdSeverity,
        imdRainfallMm:       imdRainfallMm       ?? this.imdRainfallMm,
        effectiveRainfallMm: effectiveRainfallMm ?? this.effectiveRainfallMm,
        flowRate:            flowRate            ?? this.flowRate,
        lastUpdated:         lastUpdated         ?? this.lastUpdated,
      );

  @override
  String toString() =>
      'FloodData($city, $state, ${currentLevel}m, $riskLevel, cap=${capacityPercent.toStringAsFixed(1)}%)';
}

// ─────────────────────────────────────────────────────────────────────────────
// EmergencyContact
// Used by CityDetailScreen._EmergencyContactsCard
// ─────────────────────────────────────────────────────────────────────────────

class EmergencyContact {
  final String name;
  final String role;  // e.g. 'District Collector', 'SDO'
  final String phone;

  const EmergencyContact({
    required this.name,
    required this.role,
    required this.phone,
  });

  factory EmergencyContact.fromJson(Map<String, dynamic> j) =>
      EmergencyContact(
        name:  (j['name']  as String?) ?? '',
        role:  (j['role']  as String?) ?? '',
        phone: (j['phone'] as String?) ?? '',
      );

  Map<String, dynamic> toJson() => {
    'name':  name,
    'role':  role,
    'phone': phone,
  };

  @override
  String toString() => 'EmergencyContact($role: $name, $phone)';
}
