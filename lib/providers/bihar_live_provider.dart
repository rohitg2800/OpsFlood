// lib/providers/bihar_live_provider.dart  (v2.0)
//
// OpsFlood — All-Stations Live Provider
//
// v1.x → v2.0:
//   SOURCE: was backend fetchLiveLevels('Bihar') only.
//   NOW:    reads StationsUnifiedBridge.allStations which merges
//           LiveFetchEngine (GloFAS + WRD + IMD, all states) with
//           IndiaGeodata.monitoredCities geodata fallback.
//
//   SAFE-PARSING: every numeric field is guarded against null / NaN / Inf
//   / string-encoded numbers so the screen never throws.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/flood_data.dart';
import '../services/stations_unified_bridge.dart';

// ─────────────────────────────────────────────────────────────────────────────
// BiharStationData (model consumed by LiveStationsScreen)
// ─────────────────────────────────────────────────────────────────────────────
class BiharStationData {
  final String  city;
  final String  river;
  final String  district;
  final String  state;
  final double? currentLevel;
  final double? dangerLevel;
  final double? warningLevel;
  final double? diff24h;
  final double? forecast24h;
  final String  trend;       // '↑' / '↓' / '→'
  final String  riskLabel;   // CRITICAL / SEVERE / HIGH / MODERATE / LOW / NORMAL
  final String  source;      // LIVE / STATIC
  final String  fetchedAt;   // ISO-8601 string

  // GloFAS
  final double? discharge;
  final double? dischargeMean;

  // Rainfall
  final double? rainfall24h;

  const BiharStationData({
    required this.city,
    required this.river,
    required this.district,
    required this.state,
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

  // ── Accurate safe-parsing factory ────────────────────────────────────────
  factory BiharStationData.fromFloodData(FloodData fd) {
    // currentLevel: safe double, clamp ≥ 0, guard NaN/Inf
    final cur = _safeLevel(fd.currentLevel);

    // dangerLevel / warningLevel: never return 0 (use 99.0 sentinel)
    final dan = _safeThreshold(fd.dangerLevel, fallback: 99.0);
    final war = _safeThreshold(fd.warningLevel, fallback: dan * 0.85);

    // diff24h from flowRate if not directly available (FloodData has no diff field)
    // We use flowRate as a proxy sign; null is fine.
    final diff = _safeLevel(fd.flowRate != null && fd.flowRate! > 0
        ? null   // can't derive diff from a single snapshot
        : null);

    // trend derived from riskLabel / level vs warning threshold
    String trend = '→';
    if (cur != null && war > 0) {
      if (cur > war)  trend = '↑';
      if (cur < war * 0.9) trend = '↓';
    }

    // riskLabel: normalise all edge cases
    final rawRisk = fd.riskLevel.trim().toUpperCase();
    final risk = _normaliseRisk(rawRisk);

    // source tag
    final src = (fd.status == 'LIVE') ? 'LIVE' : 'STATIC';

    // fetchedAt
    final fetchedAt = fd.lastUpdated != null
        ? fd.lastUpdated!.toIso8601String()
        : '';

    return BiharStationData(
      city:          fd.city,
      river:         fd.riverName ?? '',
      district:      fd.district,
      state:         fd.state,
      currentLevel:  cur,
      dangerLevel:   dan,
      warningLevel:  war,
      diff24h:       diff,
      forecast24h:   null,   // not available in FloodData snapshot
      trend:         trend,
      riskLabel:     risk,
      source:        src,
      fetchedAt:     fetchedAt,
      discharge:     _safeLevel(fd.flowRate),
      dischargeMean: null,
      rainfall24h:   _safeLevel(fd.effectiveRainfallMm > 0 ? fd.effectiveRainfallMm : null),
    );
  }

  // ── Gauge helpers ────────────────────────────────────────────────────────
  /// 0–150 range: allows above-danger rendering (> 100 = over danger)
  double get dangerPercent {
    final cur = currentLevel;
    final dan = dangerLevel;
    if (cur == null || dan == null || dan <= 0) return 0;
    return ((cur / dan) * 100).clamp(0, 150).toDouble();
  }

  bool get isCritical => riskLabel == 'CRITICAL';
  bool get isSevere   => riskLabel == 'SEVERE';
  bool get isWarning  => riskLabel == 'HIGH' || riskLabel == 'WARNING' || riskLabel == 'MODERATE';
  bool get isSafe     => riskLabel == 'LOW'  || riskLabel == 'NORMAL';
  bool get hasNoData  => riskLabel == 'UNKNOWN' || source == 'STATIC';

  // ── Private safe-parse helpers ───────────────────────────────────────────
  static double? _safeLevel(dynamic v) {
    if (v == null) return null;
    double? d;
    if (v is num) {
      d = v.toDouble();
    } else {
      d = double.tryParse(v.toString());
    }
    if (d == null || d.isNaN || d.isInfinite) return null;
    return d.clamp(0.0, double.maxFinite);
  }

  static double _safeThreshold(dynamic v, {required double fallback}) {
    final d = _safeLevel(v);
    if (d == null || d <= 0) return fallback;
    return d;
  }

  static String _normaliseRisk(String raw) {
    switch (raw) {
      case 'CRITICAL':    return 'CRITICAL';
      case 'SEVERE':      return 'SEVERE';
      case 'HIGH':        return 'HIGH';
      case 'WARNING':     return 'HIGH';      // alias
      case 'DANGER':      return 'CRITICAL';  // alias
      case 'MODERATE':    return 'MODERATE';
      case 'LOW':         return 'LOW';
      case 'SAFE':        return 'LOW';       // alias
      case 'PRE-MONSOON': return 'LOW';
      case 'UNKNOWN':
      case 'NO_DATA':
      case 'NA':
      case '':            return 'NORMAL';
      default:            return 'NORMAL';
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// State
// ─────────────────────────────────────────────────────────────────────────────
class BiharLiveState {
  final List<BiharStationData> stations;
  final DateTime? lastFetched;

  const BiharLiveState({this.stations = const [], this.lastFetched});

  // Convenience counts for the summary header
  int get criticalCount => stations.where((s) => s.isCritical).length;
  int get severeCount   => stations.where((s) => s.isSevere).length;
  int get warningCount  => stations.where((s) => s.isWarning).length;
  int get safeCount     => stations.where((s) => s.isSafe).length;
  int get noDataCount   => stations.where((s) => s.hasNoData).length;
}

// ─────────────────────────────────────────────────────────────────────────────
// Notifier  (v2.0 — reads StationsUnifiedBridge)
// ─────────────────────────────────────────────────────────────────────────────
class BiharLiveNotifier extends AsyncNotifier<BiharLiveState> {
  @override
  Future<BiharLiveState> build() => _build();

  Future<BiharLiveState> _build() async {
    // Pull all stations from the unified bridge (same data the dashboard uses)
    final bridge   = StationsUnifiedBridge.instance;
    final allFlood = bridge.allStations; // List<FloodData>

    if (allFlood.isEmpty) {
      return const BiharLiveState(stations: []);
    }

    // Convert every FloodData → BiharStationData with accurate safe-parsing
    final stations = allFlood
        .map(BiharStationData.fromFloodData)
        .toList();

    // Sort: CRITICAL → SEVERE → HIGH/WARNING → MODERATE → LOW → NORMAL → UNKNOWN
    const _order = {
      'CRITICAL': 0,
      'SEVERE':   1,
      'HIGH':     2,
      'MODERATE': 3,
      'LOW':      4,
      'NORMAL':   5,
      'UNKNOWN':  6,
    };
    stations.sort((a, b) =>
        (_order[a.riskLabel] ?? 5).compareTo(_order[b.riskLabel] ?? 5));

    return BiharLiveState(
      stations:    stations,
      lastFetched: DateTime.now(),
    );
  }

  /// Manual refresh: re-reads the bridge (which already calls
  /// LiveFetchEngine.refreshData internally).
  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_build);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Provider
// ─────────────────────────────────────────────────────────────────────────────
final biharLiveProvider =
    AsyncNotifierProvider<BiharLiveNotifier, BiharLiveState>(
  BiharLiveNotifier.new,
);
