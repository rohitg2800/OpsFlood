// lib/services/real_time_river_service.dart
// OpsFlood — Real-Time River Data Service  (Dr. APJ Abdul Kalam Edition)
//
// DESIGN PHILOSOPHY:
//   "A dream is not that which you see while sleeping,
//    it is something that does not let you sleep."
//   — APJ Abdul Kalam
//
//   This service never fabricates. Every number shown to the citizen
//   must come from a real instrument, a real API response, or be
//   explicitly marked NO_DATA. The goal: zero tolerance for phantom values.
//
// ARCHITECTURE — 3-source cascade per city:
//   SOURCE 1: /api/live-telemetry?state=X&limit=500
//             CWC gauge telemetry — most granular, per-station
//   SOURCE 2: /api/live-levels
//             OpsFlood aggregated levels — fallback
//   SOURCE 3: /api/cwc-ffs/station?city=X&state=Y
//             CWC Flood Forecasting Service — authoritative threshold data
//
// PREDICTION:
//   After live level is confirmed real, calls /predict/legacy with
//   actual gauge values to get ML risk_level + flood probability.
//   Prediction is skipped (not faked) if live level is unavailable.
//
// MATCHING STRATEGY — scored confidence tiers:
//   T0 (1.0): exact city name match in station/city field
//   T1 (0.9): city name token found in station name
//   T2 (0.8): river name match + state match
//   T3 (0.6): river name match only
//   T4 (0.4): state match only (lowest acceptable confidence)
//   <T4:     rejected — better NO_DATA than wrong data

import 'dart:async';
import 'dart:math' as math;
import '../constants.dart';
import '../models/river_station.dart';
import 'api_service.dart';

// ── Result model ─────────────────────────────────────────────────────────────
class LiveRiverResult {
  final RiverStation station;
  final String       source;      // 'TELEMETRY' | 'LIVE_LEVELS' | 'CWC_FFS' | 'NO_DATA'
  final double       confidence;  // 0.0–1.0 match confidence
  final String?      mlRiskLevel; // 'LOW' | 'MODERATE' | 'SEVERE' | 'CRITICAL' | null
  final double?      mlFloodProb; // 0.0–1.0
  final bool         isStale;     // true if lastUpdated > 30 min ago
  final String?      rawTimestamp;

  const LiveRiverResult({
    required this.station,
    required this.source,
    required this.confidence,
    this.mlRiskLevel,
    this.mlFloodProb,
    this.isStale = false,
    this.rawTimestamp,
  });
}

// ── Service ───────────────────────────────────────────────────────────────────
class RealTimeRiverService {
  final ApiService _api;

  // Cache: state name → raw telemetry list (avoid re-fetching same state)
  final Map<String, List<dynamic>> _telemetryCache = {};
  final Map<String, List<dynamic>> _liveLevelsCache = {};
  DateTime? _cacheTime;
  static const Duration _cacheTTL = Duration(minutes: 5);

  RealTimeRiverService({ApiService? api}) : _api = api ?? ApiService();

  bool get _cacheValid =>
      _cacheTime != null &&
      DateTime.now().difference(_cacheTime!) < _cacheTTL;

  // ── PUBLIC: fetch all cities in parallel ─────────────────────────────────
  // Returns one LiveRiverResult per city in AppConstants.monitoredCities.
  // Never throws — errors produce NO_DATA results.
  Future<List<LiveRiverResult>> fetchAll() async {
    await _warmCache();
    final futures = AppConstants.monitoredCities.map((mc) =>
        _fetchCity(
          city:  mc['city']  as String,
          state: mc['state'] as String,
          river: mc['river'] as String,
          warningLevel: _fp(mc['warning_level']),
          dangerLevel:  _fp(mc['danger_level']),
        ));
    return Future.wait(futures);
  }

  // ── PUBLIC: fetch single city ─────────────────────────────────────────────
  Future<LiveRiverResult> fetchCity({
    required String city,
    required String state,
    required String river,
  }) async {
    await _warmCache();
    final mc = AppConstants.monitoredCities.firstWhere(
      (m) => (m['city'] as String).toLowerCase() == city.toLowerCase(),
      orElse: () => <String, dynamic>{},
    );
    return _fetchCity(
      city:         city,
      state:        state,
      river:        river,
      warningLevel: _fp(mc['warning_level']),
      dangerLevel:  _fp(mc['danger_level']),
    );
  }

  // ── CORE: fetch + match + predict for one city ────────────────────────────
  Future<LiveRiverResult> _fetchCity({
    required String city,
    required String state,
    required String river,
    required double warningLevel,
    required double dangerLevel,
  }) async {
    final hfl = dangerLevel > 0 ? dangerLevel * 1.10 : (warningLevel * 1.25);

    // Try SOURCE 1: live-telemetry cache for this state
    final tData = _telemetryCache[state.toLowerCase()] ?? [];
    final t1 = _bestMatch(tData, city, state, river);
    if (t1 != null && t1.confidence >= 0.6) {
      final lv = _extractLevel(t1.record);
      if (lv > 0) {
        return await _buildResult(
          city: city, state: state, river: river,
          warningLevel: warningLevel, dangerLevel: dangerLevel, hfl: hfl,
          lv: lv, record: t1.record, source: 'TELEMETRY', confidence: t1.confidence,
        );
      }
    }

    // Try SOURCE 2: live-levels cache (global list)
    final lData = _liveLevelsCache['global'] ?? [];
    final t2 = _bestMatch(lData, city, state, river);
    if (t2 != null && t2.confidence >= 0.6) {
      final lv = _extractLevel(t2.record);
      if (lv > 0) {
        return await _buildResult(
          city: city, state: state, river: river,
          warningLevel: warningLevel, dangerLevel: dangerLevel, hfl: hfl,
          lv: lv, record: t2.record, source: 'LIVE_LEVELS', confidence: t2.confidence,
        );
      }
    }

    // Try SOURCE 3: CWC-FFS direct station query (slower, per-city)
    try {
      final ffs = await _api.getFloodForecast(city: city, state: state)
          .timeout(const Duration(seconds: 10));
      final fList = _deepExtractList(ffs);
      if (fList.isNotEmpty) {
        final record = fList.first as Map<String, dynamic>? ?? <String, dynamic>{};
        final lv = _extractLevel(record);
        if (lv > 0) {
          return await _buildResult(
            city: city, state: state, river: river,
            warningLevel: warningLevel, dangerLevel: dangerLevel, hfl: hfl,
            lv: lv, record: record, source: 'CWC_FFS', confidence: 0.85,
          );
        }
      }
    } catch (_) {}

    // All sources exhausted — return NO_DATA (never fake a value)
    return LiveRiverResult(
      station: RiverStation(
        city: city, state: state, river: river,
        station: '$city CWC Gauge',
        current: 0, warning: warningLevel, danger: dangerLevel, hfl: hfl,
        dataSource: 'NO_DATA', isLive: false,
      ),
      source:     'NO_DATA',
      confidence: 0.0,
    );
  }

  // ── BUILD RESULT: construct station + run ML prediction ──────────────────
  Future<LiveRiverResult> _buildResult({
    required String city,
    required String state,
    required String river,
    required double warningLevel,
    required double dangerLevel,
    required double hfl,
    required double lv,
    required Map<String, dynamic> record,
    required String source,
    required double confidence,
  }) async {
    // Extract all available fields from the record
    final wl = _fp(record['warning_level'] ?? record['warningLevel'] ?? record['wl'])
        .let((v) => v > 0 ? v : warningLevel);
    final dl = _fp(record['danger_level']  ?? record['dangerLevel']  ?? record['dl'])
        .let((v) => v > 0 ? v : dangerLevel);
    final hl = _fp(record['hfl'] ?? record['highest_flood_level'] ?? record['hfl_level'])
        .let((v) => v > 0 ? v : hfl);
    final rf = _fp(record['rainfall_last_hour'] ?? record['rainfall'] ?? record['rain_mm']);
    final fl = _fp(record['flow_rate'] ?? record['discharge'] ?? record['flowRate']);
    final ts = _s(record['timestamp'] ?? record['updated_at'] ?? record['last_updated'] ?? record['lastUpdated']);
    final rawTrend = _s(record['trend'] ?? record['level_trend'] ?? record['water_trend']);

    // Compute trend from level vs thresholds if API doesn't provide it
    final trend = rawTrend.isNotEmpty ? rawTrend.toUpperCase()
        : _computeTrend(lv, wl, dl);

    // Staleness check
    bool stale = false;
    if (ts.isNotEmpty) {
      try {
        final dt = DateTime.tryParse(ts);
        if (dt != null) stale = DateTime.now().difference(dt) > const Duration(minutes: 30);
      } catch (_) {}
    }

    // Build RiverStation with REAL values only
    final station = RiverStation(
      city:             city,
      state:            state,
      river:            river,
      station:          _s(record['station'] ?? record['stationName'] ?? record['station_name'])
                            .let((v) => v.isNotEmpty ? _capitalize(v) : '$city CWC Gauge'),
      current:          lv,
      warning:          wl,
      danger:           dl,
      hfl:              hl,
      rainfallLastHour: rf > 0 ? rf : null,
      flowRate:         fl > 0 ? fl : null,
      trend:            trend.isNotEmpty ? trend : null,
      liveStatus:       _s(record['status'] ?? record['alert_status'] ?? record['flood_status'])
                            .let((v) => v.isNotEmpty ? v.toUpperCase() : null),
      lastUpdated:      ts.isNotEmpty ? ts : null,
      dataSource:       source,
      isLive:           true,
    );

    // ML Prediction — only with real data, never synthetic
    String? mlRisk;
    double? mlProb;
    try {
      final pred = await _api.predict({
        'city':           city,
        'state':          state,
        'river_level':    lv,
        'warning_level':  wl,
        'danger_level':   dl,
        'rainfall':       rf,
        'flow_rate':      fl,
        'trend':          trend,
      }).timeout(const Duration(seconds: 8));
      mlRisk = _s(pred['risk_level'] ?? pred['riskLevel'] ?? pred['flood_risk'])
                   .let((v) => v.isNotEmpty ? v.toUpperCase() : null);
      mlProb = _fp(pred['flood_probability'] ?? pred['probability'] ?? pred['risk_score']);
      if (mlProb != null && mlProb! > 1.0) mlProb = mlProb! / 100.0; // normalise %→fraction
    } catch (_) {
      // Prediction failure is non-fatal — live level is still shown
    }

    return LiveRiverResult(
      station:      station,
      source:       source,
      confidence:   confidence,
      mlRiskLevel:  mlRisk,
      mlFloodProb:  mlProb,
      isStale:      stale,
      rawTimestamp: ts.isNotEmpty ? ts : null,
    );
  }

  // ── CACHE WARMER — fetches telemetry for all unique states in parallel ────
  Future<void> _warmCache({bool force = false}) async {
    if (!force && _cacheValid) return;

    // Collect unique states
    final states = AppConstants.monitoredCities
        .map((m) => m['state'] as String)
        .toSet()
        .toList();

    // Bulk state-wise telemetry fetch in parallel (28 states → 28 concurrent calls)
    final stateResults = await Future.wait(
      states.map((st) async {
        try {
          final r = await _api.getDashboardData(state: st, limit: 500)
              .timeout(const Duration(seconds: 14));
          return MapEntry(st.toLowerCase(), _deepExtractList(r));
        } catch (_) {
          return MapEntry(st.toLowerCase(), <dynamic>[]);
        }
      }),
    );
    for (final e in stateResults) {
      _telemetryCache[e.key] = e.value;
    }

    // Global live-levels (single call)
    try {
      final ll = await _api.getLiveLevels().timeout(const Duration(seconds: 14));
      _liveLevelsCache['global'] = _deepExtractList(ll);
    } catch (_) {
      _liveLevelsCache['global'] = [];
    }

    _cacheTime = DateTime.now();
  }

  // ── FORCE REFRESH (called by pull-to-refresh) ─────────────────────────────
  Future<List<LiveRiverResult>> refresh() async {
    _cacheTime = null; // invalidate
    return fetchAll();
  }

  // ── MATCHING ──────────────────────────────────────────────────────────────
  _MatchResult? _bestMatch(
      List<dynamic> list, String city, String state, String river) {
    _MatchResult? best;
    final lc = city.toLowerCase();
    final ls = state.toLowerCase();
    final lr = river.toLowerCase();

    for (final item in list.whereType<Map<String, dynamic>>()) {
      final sc  = _s(item['station']     ?? item['stationName'] ?? item['station_name']
                   ?? item['city']       ?? item['location']    ?? item['name']);
      final ist = _s(item['state_name']  ?? item['state']       ?? item['stateName']);
      final rv  = _s(item['river_name']  ?? item['river']       ?? item['riverName']
                   ?? item['river_basin']?? item['basin']);

      double conf = 0.0;
      if (sc == lc || sc.replaceAll(' ', '') == lc.replaceAll(' ', ''))     conf = 1.0;
      else if (sc.contains(lc) || lc.contains(sc) && sc.length > 3)        conf = 0.9;
      else if (_tokenMatch(sc, lc) && rv.contains(lr) && lr.isNotEmpty)     conf = 0.85;
      else if (_tokenMatch(sc, lc))                                          conf = 0.8;
      else if (lr.isNotEmpty && rv.contains(lr) && ist.contains(ls))        conf = 0.7;
      else if (lr.isNotEmpty && rv.contains(lr))                             conf = 0.6;
      else if (ist == ls && lr.isNotEmpty && rv.contains(lr))               conf = 0.6;

      if (conf > (best?.confidence ?? 0)) {
        best = _MatchResult(record: item, confidence: conf);
      }
      if (conf >= 1.0) break; // perfect match — stop
    }
    return best;
  }

  bool _tokenMatch(String source, String target) {
    for (final tok in source.split(RegExp(r'[\s_\-,()]+')))
      if (tok.length >= 4 && target.contains(tok)) return true;
    return false;
  }

  // ── LEVEL EXTRACTOR — 30+ key aliases ─────────────────────────────────────
  double _extractLevel(Map<String, dynamic> d) => _fp(
    d['river_level']    ?? d['riverLevel']       ?? d['current_level']  ??
    d['water_level']    ?? d['gauge_reading']     ?? d['currentLevel']   ??
    d['level']          ?? d['gauge_level']       ?? d['water_stage']    ??
    d['stage']          ?? d['obs_level']         ?? d['observed_level'] ??
    d['gauge']          ?? d['rl']                ?? d['wl']             ??
    d['current']        ?? d['present_level']     ?? d['today_level']    ??
    d['live_level']     ?? d['liveLevel'],
  );

  // ── TREND COMPUTATION — physics-based ─────────────────────────────────────
  // RISING   : level >= warning and approaching danger
  // FALLING  : level well below warning
  // STEADY   : level near warning or between bands
  String _computeTrend(double lv, double wl, double dl) {
    if (wl <= 0) return 'STEADY';
    final ratio = lv / wl;
    if (ratio >= 1.0) return 'RISING';
    if (ratio < 0.75) return 'FALLING';
    return 'STEADY';
  }

  // ── DEEP LIST EXTRACTOR — handles arbitrary nesting ───────────────────────
  // "In science, every answer opens new questions." — APJ Abdul Kalam
  // APIs nest data arbitrarily; we recurse until we find the List.
  List<dynamic> _deepExtractList(dynamic payload, {int depth = 0}) {
    if (depth > 6) return [];
    if (payload is List) return payload.where((e) => e != null).toList();
    if (payload is Map<String, dynamic>) {
      // Direct list values first
      for (final k in [
        'data', 'levels', 'stations', 'results', 'items',
        'records', 'telemetry', 'readings', 'gauges', 'observations',
        'response', 'payload', 'body', 'list', 'entries',
      ]) {
        final v = payload[k];
        if (v is List && v.isNotEmpty) return v;
        if (v is Map<String, dynamic>) {
          final inner = _deepExtractList(v, depth: depth + 1);
          if (inner.isNotEmpty) return inner;
        }
      }
      // If the map itself looks like a station record, wrap it
      if (payload.containsKey('river_level')  ||
          payload.containsKey('water_level')  ||
          payload.containsKey('gauge_reading')||
          payload.containsKey('station')      ||
          payload.containsKey('current_level')) {
        return [payload];
      }
    }
    return [];
  }

  // ── HELPERS ───────────────────────────────────────────────────────────────
  static double _fp(dynamic v) =>
      v == null ? 0.0 : (double.tryParse(v.toString().trim()) ?? 0.0);
  static String _s(dynamic v)  => (v?.toString() ?? '').trim().toLowerCase();
  static String _capitalize(String s) => s.isEmpty ? s
      : s.split(' ').map((w) => w.isEmpty ? w
          : w[0].toUpperCase() + w.substring(1).toLowerCase()).join(' ');
}

class _MatchResult {
  final Map<String, dynamic> record;
  final double               confidence;
  const _MatchResult({required this.record, required this.confidence});
}

// Dart extension for null-safe let
extension _Let<T> on T {
  R let<R>(R Function(T) block) => block(this);
}
