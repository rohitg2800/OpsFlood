// lib/models/flood_data.dart
//
// FloodData — one city's live flood snapshot.
// v3: added optional lat / lng fields for map pin rendering.

import 'dart:ui' show Color;

class FloodData {
  final String  city;
  final String  district;  // Zila / district name
  final String  state;
  final String? riverName;

  final double currentLevel;
  final double warningLevel;
  final double dangerLevel;
  final double safeLevel;
  final double capacityPercent;
  final String riskLevel;
  final String status;

  final String? imdSeverity;
  final double? imdRainfallMm;
  final double  effectiveRainfallMm;
  final double? flowRate;
  final DateTime lastUpdated;

  // ── Geographic coordinates (optional — used for map pin rendering) ──────
  final double? lat;
  final double? lng;

  const FloodData({
    required this.city,
    this.district = '',
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
    this.lat,
    this.lng,
  });

  int get priorityOrder {
    switch (riskLevel) {
      case 'CRITICAL': return 4;
      case 'SEVERE':   return 3;
      case 'MODERATE': return 2;
      case 'LOW':
      default:         return 1;
    }
  }

  Color get priorityColor {
    switch (riskLevel) {
      case 'CRITICAL': return const Color(0xFFB71C1C);
      case 'SEVERE':   return const Color(0xFFE65100);
      case 'MODERATE': return const Color(0xFFF9A825);
      case 'LOW':
      default:         return const Color(0xFF2E7D32);
    }
  }

  factory FloodData.fromJson(Map<String, dynamic> j) {
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
    final rawCap  = j['capacity_percent'] ?? j['capacityPercent'];
    final cap     = rawCap != null
        ? d(rawCap)
        : (danger > 0 ? (current / danger * 100).clamp(0.0, 100.0) : 0.0);
    final imdRain = dNull(j['imd_rainfall_mm'] ?? j['imdRainfallMm']);
    final cwcRain = d(j['rainfall_24h_mm'] ?? j['effectiveRainfallMm']);
    final raw  = (j['risk_level'] ?? j['riskLevel'] ?? 'LOW').toString().toUpperCase();
    const _valid = {'CRITICAL', 'SEVERE', 'MODERATE', 'LOW'};
    final level = _valid.contains(raw) ? raw : 'LOW';

    return FloodData(
      city:                (j['city']      as String?) ?? '',
      district:            (j['district']  as String?) ?? '',
      state:               (j['state']     as String?) ?? '',
      riverName:            j['river_name'] as String?,
      currentLevel:        current,
      warningLevel:        warning,
      dangerLevel:         danger,
      safeLevel:           d(j['safe_level'] ?? j['safeLevel']),
      capacityPercent:     cap,
      riskLevel:           level,
      status:              (j['status']     as String?) ?? 'ESTIMATED',
      imdSeverity:          j['imd_severity'] as String?,
      imdRainfallMm:       imdRain,
      effectiveRainfallMm: imdRain ?? cwcRain,
      flowRate:            dNull(j['flow_rate'] ?? j['flowRate']),
      lastUpdated:         j['last_updated'] != null
          ? DateTime.tryParse(j['last_updated'] as String) ?? DateTime.now()
          : DateTime.now(),
      lat:                 dNull(j['lat'] ?? j['latitude']),
      lng:                 dNull(j['lng'] ?? j['longitude']),
    );
  }

  Map<String, dynamic> toJson() => {
    'city':                  city,
    'district':              district,
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
    'lat':                   lat,
    'lng':                   lng,
  };

  FloodData copyWith({
    String?   city,
    String?   district,
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
    double?   lat,
    double?   lng,
  }) => FloodData(
    city:                city                ?? this.city,
    district:            district            ?? this.district,
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
    lat:                 lat                 ?? this.lat,
    lng:                 lng                 ?? this.lng,
  );

  @override
  String toString() =>
      'FloodData($city, $district, $state, ${currentLevel}m, $riskLevel, cap=${capacityPercent.toStringAsFixed(1)}%)';
}

class EmergencyContact {
  final String name;
  final String role;
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
}
