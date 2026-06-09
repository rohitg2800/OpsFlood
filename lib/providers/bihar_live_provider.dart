// lib/providers/bihar_live_provider.dart
//
// OpsFlood — Bihar live data provider (Riverpod AsyncNotifier)
//
// Fetches all three data layers for Bihar from our Railway backend:
//   1. /api/live-levels?state=Bihar  → 31 WRD gauge stations
//   2. /api/glofas                   → river discharge per station
//   3. /api/rainfall                 → 24h rainfall per station
//
// The three lists are merged by city key (lowercase) into BiharStationData.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/backend_api_service.dart';

// ── Data model ───────────────────────────────────────────────────────────────
class BiharStationData {
  final String city;
  final String river;
  final String district;
  final double? currentLevel;
  final double? dangerLevel;
  final double? warningLevel;
  final double? diff24h;
  final double? forecast24h;
  final String trend;
  final String riskLabel;
  final String source;
  final String fetchedAt;

  // GloFAS
  final double? discharge;
  final double? dischargeMean;

  // Rainfall
  final double? rainfall24h;

  const BiharStationData({
    required this.city,
    required this.river,
    required this.district,
    this.currentLevel,
    this.dangerLevel,
    this.warningLevel,
    this.diff24h,
    this.forecast24h,
    required this.trend,
    required this.riskLabel,
    required this.source,
    required this.fetchedAt,
    this.discharge,
    this.dischargeMean,
    this.rainfall24h,
  });

  /// Danger percent (0–100) for the level gauge bar
  double get dangerPercent {
    final cur = currentLevel;
    final dan = dangerLevel;
    if (cur == null || dan == null || dan <= 0) return 0;
    return ((cur / dan) * 100).clamp(0, 100);
  }

  bool get isCritical => riskLabel == 'CRITICAL' || riskLabel == 'DANGER';
  bool get isWarning  => riskLabel == 'WARNING'  || riskLabel == 'HIGH';
}

// ── State ────────────────────────────────────────────────────────────────────
class BiharLiveState {
  final List<BiharStationData> stations;
  final DateTime? lastFetched;

  const BiharLiveState({this.stations = const [], this.lastFetched});
}

// ── Notifier ─────────────────────────────────────────────────────────────────
class BiharLiveNotifier extends AsyncNotifier<BiharLiveState> {
  @override
  Future<BiharLiveState> build() => _fetch();

  Future<BiharLiveState> _fetch() async {
    final api = BackendApiService.instance;

    // 1. Live levels (always fetch — this is the primary list)
    final levels = await api.fetchLiveLevels('Bihar');
    if (levels.isEmpty) {
      return const BiharLiveState(stations: []);
    }

    // Extract lat/lon/city from the live-levels response.
    // WRD Bihar returns lat/lon when available; fall back to 0,0 (GloFAS
    // will still return the nearest grid cell, which is close enough for
    // state-level discharge context).
    final lats     = levels.map((s) => _toDouble(s['lat'] ?? s['latitude'])  ?? 25.5).toList();
    final lons     = levels.map((s) => _toDouble(s['lon'] ?? s['longitude']) ?? 85.1).toList();
    final cityKeys = levels.map((s) => _str(s['city'] ?? s['station_name']).toLowerCase()).toList();

    // 2 & 3: fan out GloFAS + rainfall in parallel
    final results = await Future.wait([
      api.fetchGloFAS(lats: lats, lons: lons, cityKeys: cityKeys)
          .catchError((_) => <Map<String, dynamic>>[]),
      api.fetchRainfall(lats: lats, lons: lons, cityKeys: cityKeys)
          .catchError((_) => <Map<String, dynamic>>[]),
    ]);

    final glofasMap  = _indexBy(results[0], 'city');
    final rainfallMap = _indexBy(results[1], 'city');

    final stations = levels.asMap().entries.map((entry) {
      final s    = entry.value;
      final key  = cityKeys[entry.key];
      final glo  = glofasMap[key]  ?? {};
      final rain = rainfallMap[key] ?? {};

      return BiharStationData(
        city:         _str(s['city'] ?? s['station_name']),
        river:        _str(s['river'] ?? s['river_name']),
        district:     _str(s['district']),
        currentLevel: _toDouble(s['currentLevel'] ?? s['current_level']),
        dangerLevel:  _toDouble(s['dangerLevel']  ?? s['danger_level']),
        warningLevel: _toDouble(s['warningLevel'] ?? s['warning_level']),
        diff24h:      _toDouble(s['diff24h']      ?? s['diff_24h']),
        forecast24h:  _toDouble(s['forecast24h']  ?? s['forecast_24h']),
        trend:        _str(s['trend'] ?? '—'),
        riskLabel:    _str(s['riskLabel'] ?? s['risk_label'] ?? 'NORMAL').toUpperCase(),
        source:       _str(s['source'] ?? 'WRD_BIHAR'),
        fetchedAt:    _str(s['fetchedAt'] ?? s['fetched_at']),
        discharge:     _toDouble(glo['discharge']),
        dischargeMean: _toDouble(glo['discharge_mean']),
        rainfall24h:   _toDouble(rain['rainfall24h']),
      );
    }).toList();

    // Sort: critical first, then warning, then normal
    stations.sort((a, b) {
      int rank(BiharStationData s) {
        if (s.isCritical) return 0;
        if (s.isWarning)  return 1;
        return 2;
      }
      return rank(a).compareTo(rank(b));
    });

    return BiharLiveState(
      stations: stations,
      lastFetched: DateTime.now(),
    );
  }

  /// Manual refresh triggered by pull-to-refresh or tap.
  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetch);
  }

  // ── helpers ────────────────────────────────────────────────────────────────
  static double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  static String _str(dynamic v) => v?.toString() ?? '';

  static Map<String, Map<String, dynamic>> _indexBy(
      List<Map<String, dynamic>> list, String key) {
    return {for (final item in list) (item[key] ?? '').toString(): item};
  }
}

// ── Provider ─────────────────────────────────────────────────────────────────
final biharLiveProvider =
    AsyncNotifierProvider<BiharLiveNotifier, BiharLiveState>(
  BiharLiveNotifier.new,
);
