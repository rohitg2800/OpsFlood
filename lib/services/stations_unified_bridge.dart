// lib/services/stations_unified_bridge.dart
//
// StationsUnifiedBridge — single source of truth for both MapScreen and
// MonitoredStationsScreen.  Previously those two screens read from different
// lists (IndiaGeodata.monitoredCities vs LiveFetchEngine.liveFloodData),
// causing map pins and the monitored-stations list to diverge.
//
// fix(v1.1): FloodData.lastUpdated is required non-nullable DateTime.
//   Static-fallback now passes DateTime.fromMillisecondsSinceEpoch(0)
//   (epoch sentinel = "no live data") instead of null.
//   markersForMap maps epoch → null for StationMarker.lastUpdated which IS nullable.

import '../constants/india_geodata.dart';
import '../models/flood_data.dart';
import 'live_fetch_engine.dart';

// ─────────────────────────────────────────────────────────────────────────────
// StationMarker — lightweight struct consumed by map widgets
// ─────────────────────────────────────────────────────────────────────────────
class StationMarker {
  final String  city;
  final String  state;
  final String  district;
  final String? river;
  final double  lat;
  final double  lon;
  final String  riskLevel;
  final double  capacityPercent;
  final double? currentLevel;
  final double  warningLevel;
  final double  dangerLevel;
  final double? rainfall24h;
  final double? flowRate;
  final bool    hasLiveData;
  final DateTime? lastUpdated;   // nullable — null means no live timestamp

  const StationMarker({
    required this.city,
    required this.state,
    required this.district,
    this.river,
    required this.lat,
    required this.lon,
    required this.riskLevel,
    required this.capacityPercent,
    this.currentLevel,
    required this.warningLevel,
    required this.dangerLevel,
    this.rainfall24h,
    this.flowRate,
    required this.hasLiveData,
    this.lastUpdated,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Epoch sentinel: a non-null DateTime that signals "no live data was fetched".
// Callers that need to display a timestamp should treat epoch as absent.
// ─────────────────────────────────────────────────────────────────────────────
final _kEpoch = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

// Helper: returns null when the datetime is the epoch sentinel.
DateTime? _liveTs(DateTime dt) => dt == _kEpoch ? null : dt;

// ─────────────────────────────────────────────────────────────────────────────
// StationsUnifiedBridge
// ─────────────────────────────────────────────────────────────────────────────
class StationsUnifiedBridge {
  StationsUnifiedBridge._();
  static final StationsUnifiedBridge instance = StationsUnifiedBridge._();

  LiveFetchEngine? _engine;

  /// Call this once when your provider/state is initialised.
  void attach(LiveFetchEngine engine) => _engine = engine;

  // ── Core merge ──────────────────────────────────────────────────────────────
  List<FloodData> get allStations {
    final liveMap = <String, FloodData>{};
    if (_engine != null) {
      for (final fd in _engine!.liveFloodData) {
        liveMap[fd.city.toLowerCase().trim()] = fd;
      }
    }

    return IndiaGeodata.monitoredCities.map((mc) {
      final key = (mc['city'] as String).toLowerCase().trim();
      if (liveMap.containsKey(key)) return liveMap[key]!;

      // Synthetic fallback: static geodata, no live reading.
      // lastUpdated = _kEpoch (epoch sentinel) satisfies the non-nullable
      // requirement while signalling to consumers that no live fetch occurred.
      final dl = (mc['danger_level']  as num).toDouble();
      final wl = (mc['warning_level'] as num).toDouble();
      return FloodData(
        city:                mc['city']              as String,
        district:            (mc['district'] as String?) ?? '',
        state:               mc['state']             as String,
        riverName:           mc['river']             as String?,
        currentLevel:        0.0,
        warningLevel:        wl,
        dangerLevel:         dl,
        safeLevel:           wl * 0.8,
        capacityPercent:     0.0,
        riskLevel:           'UNKNOWN',
        status:              'NO_DATA',
        effectiveRainfallMm: 0.0,
        flowRate:            null,
        lastUpdated:         _kEpoch,   // ← fix: epoch sentinel, NOT null
      );
    }).toList();
  }

  /// Alias for MonitoredStationsScreen.
  List<FloodData> get monitoredStations => allStations;

  /// Map-ready markers.
  List<StationMarker> get markersForMap {
    return allStations.map((fd) {
      final mc = IndiaGeodata.monitoredCities.firstWhere(
        (c) => (c['city'] as String).toLowerCase() == fd.city.toLowerCase(),
        orElse: () => {
          'city': fd.city,  'state': fd.state,
          'district': fd.district, 'river': fd.riverName,
          'lat': 25.0, 'lon': 85.0,
          'danger_level': fd.dangerLevel,
          'warning_level': fd.warningLevel,
        },
      );
      return StationMarker(
        city:            fd.city,
        state:           fd.state,
        district:        fd.district,
        river:           fd.riverName,
        lat:             (mc['lat'] as num).toDouble(),
        lon:             (mc['lon'] as num).toDouble(),
        riskLevel:       fd.riskLevel,
        capacityPercent: fd.capacityPercent,
        currentLevel:    fd.currentLevel,
        warningLevel:    fd.warningLevel,
        dangerLevel:     fd.dangerLevel,
        rainfall24h:     fd.effectiveRainfallMm > 0 ? fd.effectiveRainfallMm : null,
        flowRate:        fd.flowRate,
        hasLiveData:     fd.status == 'LIVE',
        lastUpdated:     _liveTs(fd.lastUpdated), // null when no live data
      );
    }).toList();
  }

  // Convenience counters
  int get totalCount    => allStations.length;
  int get criticalCount => allStations.where((s) => s.riskLevel == 'CRITICAL').length;
  int get severeCount   => allStations.where((s) => s.riskLevel == 'SEVERE').length;
  int get warningCount  => allStations.where((s) => s.riskLevel == 'MODERATE').length;
  int get safeCount     => allStations.where((s) =>
      s.riskLevel == 'LOW' || s.riskLevel == 'UNKNOWN').length;
  int get noDataCount   => allStations.where((s) => s.status == 'NO_DATA').length;
}
