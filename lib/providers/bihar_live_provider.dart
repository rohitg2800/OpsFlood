// lib/providers/bihar_live_provider.dart  (v3.0)
//
// OpsFlood — All-Stations Live Provider
//
// v2.x → v3.0:
//   ROOT FIX: The notifier was a one-shot AsyncNotifier — it called
//   StationsUnifiedBridge.allStations once on build() and never again unless
//   the user manually tapped Refresh.  Even if LiveFetchEngine fetched new
//   data every 30 s, the UI never updated.
//
//   NOW:
//   • BiharLiveNotifier wires itself directly to LiveFetchEngine.instance.
//   • On build() it:
//       1. Attaches itself as onStateChanged listener.
//       2. Calls LiveFetchEngine.startPolling() so the 30 s ticker is running.
//       3. Builds state from the engine's current cache (instant first paint).
//   • Every time the engine finishes a fetch it fires onStateChanged →
//     the notifier calls _rebuild() → AsyncNotifier state is replaced →
//     LiveStationsScreen, BiharDashboardProvider counts, and the Map all
//     get the fresh data automatically.
//   • ref.onDispose() removes the listener so there are no leaks.
//
//   DASHBOARD COUNTS (biharStationCountProvider, biharCriticalCountProvider,
//   biharWarningCountProvider, biharAvgRainfallProvider, etc.) are derived
//   from biharLiveProvider — they update for free with no changes needed.
//
//   MAP (BiharRiverMapScreen) watches biharLiveProvider — it also updates
//   for free; no changes needed there either.
//
//   SAFE-PARSING: every numeric field is guarded against null / NaN / Inf
//   / string-encoded numbers so the screen never throws.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/flood_data.dart';
import '../services/live_fetch_engine.dart';
import '../services/stations_unified_bridge.dart';

// ─────────────────────────────────────────────────────────────────────────────
// BiharStationData (model consumed by LiveStationsScreen + Map)
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
  final String  trend;        // '↑' / '↓' / '→'
  final String  riskLabel;    // CRITICAL / SEVERE / HIGH / MODERATE / LOW / NORMAL
  final String  source;       // LIVE / STATIC
  final String  fetchedAt;    // ISO-8601 string

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

  // ── Factory: FloodData → BiharStationData ──────────────────────────────
  factory BiharStationData.fromFloodData(FloodData fd) {
    final cur = _safeLevel(fd.currentLevel);
    final dan = _safeThreshold(fd.dangerLevel,  fallback: 99.0);
    final war = _safeThreshold(fd.warningLevel, fallback: dan * 0.85);

    // Trend from level vs warning threshold
    String trend = '→';
    if (cur != null && war > 0) {
      if (cur > war)          trend = '↑';
      if (cur < war * 0.9)   trend = '↓';
    }

    final risk      = _normaliseRisk(fd.riskLevel.trim().toUpperCase());
    final src       = (fd.status == 'LIVE') ? 'LIVE' : 'STATIC';
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
      diff24h:       null,   // single-snapshot — no prior level to diff
      forecast24h:   null,
      trend:         trend,
      riskLabel:     risk,
      source:        src,
      fetchedAt:     fetchedAt,
      discharge:     _safeLevel(fd.flowRate),
      dischargeMean: null,
      rainfall24h:   _safeLevel(
          fd.effectiveRainfallMm > 0 ? fd.effectiveRainfallMm : null),
    );
  }

  // ── Gauge helpers ────────────────────────────────────────────────────────
  double get dangerPercent {
    final cur = currentLevel;
    final dan = dangerLevel;
    if (cur == null || dan == null || dan <= 0) return 0;
    return ((cur / dan) * 100).clamp(0, 150).toDouble();
  }

  bool get isCritical => riskLabel == 'CRITICAL';
  bool get isSevere   => riskLabel == 'SEVERE';
  bool get isWarning  =>
      riskLabel == 'HIGH' || riskLabel == 'WARNING' || riskLabel == 'MODERATE';
  bool get isSafe     => riskLabel == 'LOW' || riskLabel == 'NORMAL';
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
      case 'WARNING':     return 'HIGH';       // alias
      case 'DANGER':      return 'CRITICAL';   // alias
      case 'MODERATE':    return 'MODERATE';
      case 'LOW':         return 'LOW';
      case 'SAFE':        return 'LOW';        // alias
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
// BiharLiveState
// ─────────────────────────────────────────────────────────────────────────────
class BiharLiveState {
  final List<BiharStationData> stations;
  final DateTime? lastFetched;

  const BiharLiveState({this.stations = const [], this.lastFetched});

  // Convenience counts — drive both the summary header and DashboardProvider
  int get criticalCount => stations.where((s) => s.isCritical).length;
  int get severeCount   => stations.where((s) => s.isSevere).length;
  int get warningCount  => stations.where((s) => s.isWarning).length;
  int get safeCount     => stations.where((s) => s.isSafe).length;
  int get noDataCount   => stations.where((s) => s.hasNoData).length;
}

// ─────────────────────────────────────────────────────────────────────────────
// Notifier  (v3.0 — wired to LiveFetchEngine, auto-rebuilds on every push)
// ─────────────────────────────────────────────────────────────────────────────

const _kRiskOrder = {
  'CRITICAL': 0,
  'SEVERE':   1,
  'HIGH':     2,
  'MODERATE': 3,
  'LOW':      4,
  'NORMAL':   5,
  'UNKNOWN':  6,
};

class BiharLiveNotifier extends AsyncNotifier<BiharLiveState> {
  // Keep a reference to the engine so we can remove the listener on dispose.
  late final LiveFetchEngine _engine;

  @override
  Future<BiharLiveState> build() async {
    _engine = LiveFetchEngine.instance;

    // ── 1. Make sure StationsUnifiedBridge is attached to the same engine ──
    //    (required so the map-screen helper markersForMap stays in sync too)
    StationsUnifiedBridge.instance.attach(_engine);

    // ── 2. Register ourselves as the engine's change listener ──────────────
    //    Any previous listener is replaced; that's fine because there is only
    //    ever one biharLiveProvider instance.
    _engine.onStateChanged = _onEngineUpdate;

    // ── 3. Remove listener when the provider is disposed ───────────────────
    ref.onDispose(() {
      if (_engine.onStateChanged == _onEngineUpdate) {
        _engine.onStateChanged = null;
      }
    });

    // ── 4. Kick off the 30 s polling loop (idempotent — safe to call N times)
    _engine.startPolling(); // returns Future<void> but we don't await it here;
                             // the first result fires _onEngineUpdate shortly.

    // ── 5. Build state from whatever is already in the engine cache ─────────
    //    This gives an instant first paint even before the first HTTP call
    //    completes.  If cache is empty we return an empty state — the loading
    //    spinner in LiveStationsScreen covers this.
    return _buildState();
  }

  // Called by the engine after every successful fetch (≈every 30 s).
  void _onEngineUpdate() {
    state = AsyncData(_buildState());
  }

  // Convert engine's current cache → BiharLiveState.
  BiharLiveState _buildState() {
    final floodList = _engine.liveFloodData; // List<FloodData> — all states

    if (floodList.isEmpty) {
      return BiharLiveState(lastFetched: _engine.lastFetchTime);
    }

    final stations = floodList
        .map(BiharStationData.fromFloodData)
        .toList()
      ..sort((a, b) =>
          (_kRiskOrder[a.riskLabel] ?? 5)
              .compareTo(_kRiskOrder[b.riskLabel] ?? 5));

    return BiharLiveState(
      stations:    stations,
      lastFetched: _engine.lastFetchTime ?? DateTime.now(),
    );
  }

  // ── Public API ────────────────────────────────────────────────────────────

  /// Force an immediate re-fetch (e.g. user taps the refresh button).
  Future<void> refresh() async {
    state = const AsyncLoading();
    try {
      await _engine.refreshData(); // engine will call _onEngineUpdate when done
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Provider
// ─────────────────────────────────────────────────────────────────────────────
final biharLiveProvider =
    AsyncNotifierProvider<BiharLiveNotifier, BiharLiveState>(
  BiharLiveNotifier.new,
);
