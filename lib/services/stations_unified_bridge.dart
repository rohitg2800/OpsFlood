// lib/services/stations_unified_bridge.dart
//
// StationsUnifiedBridge — single source of truth for both MapScreen and
// MonitoredStationsScreen.  Previously those two screens read from different
// lists (IndiaGeodata.monitoredCities vs LiveFetchEngine.liveFloodData),
// causing map pins and the monitored-stations list to diverge.
//
// Usage:
//   final bridge = StationsUnifiedBridge.instance;
//   bridge.attach(engine);          // call once in your provider/init
//   bridge.allStations;             // List<FloodData> — map + monitored
//   bridge.markersForMap;           // List<StationMarker>
//   bridge.monitoredStations;       // same list, alias for monitored screen

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
  final String  riskLevel;       // CRITICAL / SEVERE / MODERATE / LOW / UNKNOWN
  final double  capacityPercent; // 0–150
  final double? currentLevel;
  final double  warningLevel;
  final double  dangerLevel;
  final double? rainfall24h;
  final double? flowRate;
  final bool    hasLiveData;
  final DateTime? lastUpdated;

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
// StationsUnifiedBridge
// ─────────────────────────────────────────────────────────────────────────────
class StationsUnifiedBridge {
  StationsUnifiedBridge._();
  static final StationsUnifiedBridge instance = StationsUnifiedBridge._();

  LiveFetchEngine? _engine;

  /// Call this once when your provider/state is initialised.
  void attach(LiveFetchEngine engine) {
    _engine = engine;
  }

  // —— Core merge logic ——————————————————————————————————————————————————————
  //
  // For every station in IndiaGeodata.monitoredCities:
  //  • If LiveFetchEngine has live data  → use it (FloodData from engine)
  //  • Otherwise                         → synthesise a FloodData from geodata
  //    with riskLevel='UNKNOWN' so the map can still show a grey pin.

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

      // Synthetic fallback — static geodata, no live reading
      final dl = (mc['danger_level']  as num).toDouble();
      final wl = (mc['warning_level'] as num).toDouble();
      return FloodData(
        city:            mc['city']     as String,
        district:        (mc['district'] as String?) ?? '',
        state:           mc['state']    as String,
        riverName:       mc['river']    as String?,
        currentLevel:    0.0,
        warningLevel:    wl,
        dangerLevel:     dl,
        safeLevel:       wl * 0.8,
        capacityPercent: 0.0,
        riskLevel:       'UNKNOWN',
        status:          'NO_DATA',
        effectiveRainfallMm: 0.0,
        flowRate:        null,
        lastUpdated:     null,
      );
    }).toList();
  }

  /// Alias for MonitoredStationsScreen — same live-enriched list.
  List<FloodData> get monitoredStations => allStations;

  /// Map-ready markers.  Colour/icon logic lives in the map widget;
  /// this just provides the data layer.
  List<StationMarker> get markersForMap {
    return allStations.map((fd) {
      final mc = IndiaGeodata.monitoredCities.firstWhere(
        (c) => (c['city'] as String).toLowerCase() == fd.city.toLowerCase(),
        orElse: () => {
          'city': fd.city, 'state': fd.state,
          'district': fd.district, 'river': fd.riverName,
          'lat': 25.0, 'lon': 85.0,
          'danger_level': fd.dangerLevel, 'warning_level': fd.warningLevel,
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
        lastUpdated:     fd.lastUpdated,
      );
    }).toList();
  }

  // Convenience counters used by dashboard KPI widgets
  int get totalCount    => allStations.length;
  int get criticalCount => allStations.where((s) => s.riskLevel == 'CRITICAL').length;
  int get severeCount   => allStations.where((s) => s.riskLevel == 'SEVERE').length;
  int get warningCount  => allStations.where((s) => s.riskLevel == 'MODERATE').length;
  // v5.4: safe = LOW or UNKNOWN (station exists but no alert level)
  int get safeCount     => allStations.where((s) =>
      s.riskLevel == 'LOW' || s.riskLevel == 'UNKNOWN').length;
  int get noDataCount   => allStations.where((s) => s.status == 'NO_DATA').length;
}
