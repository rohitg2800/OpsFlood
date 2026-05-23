// lib/services/real_time_river_service.dart
// OpsFlood — Real-Time River Data Service  (Dr. APJ Abdul Kalam Edition v6)
//
// ARCHITECTURE — 5-source cascade per city:
//
//   SOURCE 0: /api/live-telemetry?all_states=true&limit=1000
//             Single bulk call — warms ALL states at once.
//             Cold-start guard: if bulk returns empty, retried once with a
//             50-second timeout before the cascade falls through.
//
//   SOURCE 1: /api/live-telemetry?state=X&limit=500
//             Per-state fallback for cities missed in bulk call.
//
//   SOURCE 2: /api/live-levels
//             OpsFlood aggregated state-wise levels.
//
//   SOURCE 3: /api/cwc-ffs/station?name=CITY&state=STATE
//             CWC Flood Forecasting Service — per-city, authoritative.
//
//   SOURCE 4: /api/cwc-reservoir/state?state=STATE
//             Reservoir level for dam-adjacent cities.
//             Cached per-state for the full cache TTL.
//
// DATA INTEGRITY RULES:
//   1. A level must be > 0 to be used. Never display 0 as a real reading.
//   2. Match confidence >= 0.40 required. Below that → NO_DATA.
//   3. NO_DATA is honest. Phantom values are unacceptable.
//   4. ML prediction only runs with real confirmed levels.
//
// SINGLETON RULE:
//   Always use RealTimeRiverService.instance.
//   All screens (India Map, Stations tab, All Places) share one cache.
//   This means zero duplicate HTTP calls and live data appears everywhere
//   at the same time.

import 'dart:async';
import 'package:flutter/foundation.dart';
import '../constants.dart';
import '../models/river_station.dart';
import 'api_service.dart';

// ── Result model ─────────────────────────────────────────────────────────────
class LiveRiverResult {
  final RiverStation station;
  final String       source;      // 'BULK'|'TELEMETRY'|'LIVE_LEVELS'|'CWC_FFS'|'RESERVOIR'|'NO_DATA'
  final double       confidence;  // 0.0–1.0
  final String?      mlRiskLevel; // 'LOW'|'MODERATE'|'SEVERE'|'CRITICAL'|null
  final double?      mlFloodProb; // 0.0–1.0
  final bool         isStale;     // >30 min old
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

void _log(String msg) {
  if (kDebugMode) debugPrint('[RTRS] $msg');
}

// ── Service ───────────────────────────────────────────────────────────────────
class RealTimeRiverService extends ChangeNotifier {
  // ── True singleton ────────────────────────────────────────────────────────
  static final RealTimeRiverService instance = RealTimeRiverService._internal();
  factory RealTimeRiverService() => instance;
  RealTimeRiverService._internal();

  final ApiService _api = ApiService();

  // ── Shared cache ──────────────────────────────────────────────────────────
  List<dynamic>                    _bulkList       = [];
  final Map<String, List<dynamic>> _stateCache     = {};
  final Map<String, List<dynamic>> _reservoirCache = {};
  List<dynamic>                    _liveLevels     = [];
  DateTime?                        _cacheTime;
  bool                             _warmingUp      = false;
  List<LiveRiverResult>            _lastResults    = [];

  static const Duration _cacheTTL    = Duration(minutes: 5);
  static const _bulkTimeout          = Duration(seconds: 28);
  static const _bulkRetryTimeout     = Duration(seconds: 50); // cold-start retry
  static const _stateTimeout         = Duration(seconds: 16);
  static const _ffsTimeout           = Duration(seconds: 12);
  static const _resTimeout           = Duration(seconds: 10);
  static const _predTimeout          = Duration(seconds: 8);

  bool get _cacheValid =>
      _cacheTime != null &&
      DateTime.now().difference(_cacheTime!) < _cacheTTL;

  // Public: last fetched results (empty until first fetchAll completes)
  List<LiveRiverResult> get lastResults => _lastResults;

  // ══════════════════════════════════════════════════════════════════════════
  // PUBLIC: Fetch all monitored cities
  // ══════════════════════════════════════════════════════════════════════════
  Future<List<LiveRiverResult>> fetchAll() async {
    await _warmCache();
    final futures = AppConstants.monitoredCities.map((mc) =>
        _fetchCity(
          city:         mc['city']  as String,
          state:        mc['state'] as String,
          river:        mc['river'] as String,
          warningLevel: _fp(mc['warning_level']),
          dangerLevel:  _fp(mc['danger_level']),
        ));
    final results = await Future.wait(futures);
    _lastResults = results;
    notifyListeners();
    return results;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // PUBLIC: Fetch single city
  // ══════════════════════════════════════════════════════════════════════════
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

  // ══════════════════════════════════════════════════════════════════════════
  // PUBLIC: Force refresh
  // ══════════════════════════════════════════════════════════════════════════
  Future<List<LiveRiverResult>> refresh() async {
    _invalidateCache();
    return fetchAll();
  }

  void _invalidateCache() {
    _cacheTime = null;
    _bulkList  = [];
    _stateCache.clear();
    _reservoirCache.clear();
    _liveLevels = [];
  }

  // ══════════════════════════════════════════════════════════════════════════
  // CORE: 5-source cascade for one city
  // ══════════════════════════════════════════════════════════════════════════
  Future<LiveRiverResult> _fetchCity({
    required String city,
    required String state,
    required String river,
    required double warningLevel,
    required double dangerLevel,
  }) async {
    final hfl = dangerLevel > 0 ? dangerLevel * 1.10 : warningLevel * 1.25;

    // ── SOURCE 0: Bulk all-states list ────────────────────────────────────
    if (_bulkList.isNotEmpty) {
      final m = _bestMatch(_bulkList, city, state, river);
      if (m != null && m.confidence >= 0.40) {
        final lv = _extractLevel(m.record);
        if (lv > 0) {
          return _buildResult(
            city: city, state: state, river: river,
            wl: warningLevel, dl: dangerLevel, hfl: hfl,
            lv: lv, record: m.record,
            source: 'BULK', confidence: m.confidence,
          );
        }
      }
    }

    // ── SOURCE 1: Per-state telemetry (lazy-fetched) ──────────────────────
    final stKey = _stateKey(state);
    if (!_stateCache.containsKey(stKey)) {
      try {
        final r = await _api.getDashboardData(state: state, limit: 500)
            .timeout(_stateTimeout);
        _stateCache[stKey] = _deepList(r);
      } catch (_) {
        _stateCache[stKey] = [];
      }
    }
    final stData = _stateCache[stKey] ?? [];
    if (stData.isNotEmpty) {
      final m = _bestMatch(stData, city, state, river);
      if (m != null && m.confidence >= 0.40) {
        final lv = _extractLevel(m.record);
        if (lv > 0) {
          return _buildResult(
            city: city, state: state, river: river,
            wl: warningLevel, dl: dangerLevel, hfl: hfl,
            lv: lv, record: m.record,
            source: 'TELEMETRY', confidence: m.confidence,
          );
        }
      }
    }

    // ── SOURCE 2: Live levels (global aggregated list) ────────────────────
    if (_liveLevels.isNotEmpty) {
      final m = _bestMatch(_liveLevels, city, state, river);
      if (m != null && m.confidence >= 0.40) {
        final lv = _extractLevel(m.record);
        if (lv > 0) {
          return _buildResult(
            city: city, state: state, river: river,
            wl: warningLevel, dl: dangerLevel, hfl: hfl,
            lv: lv, record: m.record,
            source: 'LIVE_LEVELS', confidence: m.confidence,
          );
        }
      }
    }

    // ── SOURCE 3: CWC FFS per-city (direct, slower) ───────────────────────
    try {
      final ffs = await _api.getFloodForecast(city: city, state: state)
          .timeout(_ffsTimeout);
      final fl = _deepList(ffs);
      for (final item in fl.whereType<Map<String, dynamic>>()) {
        final lv = _extractLevel(item);
        if (lv > 0) {
          return _buildResult(
            city: city, state: state, river: river,
            wl: warningLevel, dl: dangerLevel, hfl: hfl,
            lv: lv, record: item,
            source: 'CWC_FFS', confidence: 0.85,
          );
        }
      }
    } catch (_) {}

    // ── SOURCE 4: Reservoir levels (dam-adjacent cities) ──────────────────
    if (!_reservoirCache.containsKey(stKey)) {
      try {
        final res = await _api.getReservoirLevels(state: state)
            .timeout(_resTimeout);
        _reservoirCache[stKey] = _deepList(res);
      } catch (_) {
        _reservoirCache[stKey] = [];
      }
    }
    final rl = _reservoirCache[stKey] ?? [];
    if (rl.isNotEmpty) {
      final m = _bestMatch(rl, city, state, river);
      if (m != null && m.confidence >= 0.40) {
        final lv = _fp(
          m.record['current_level_m'] ?? m.record['current_level'] ??
          m.record['wl']              ?? m.record['water_level'],
        );
        if (lv > 0) {
          return _buildResult(
            city: city, state: state, river: river,
            wl: warningLevel, dl: dangerLevel, hfl: hfl,
            lv: lv, record: m.record,
            source: 'RESERVOIR', confidence: m.confidence,
          );
        }
      }
    }

    // ── ALL SOURCES EXHAUSTED — honest NO_DATA ────────────────────────────
    // Only log if we are not in the middle of a cold-start wake-up retry
    // (during retry _warmingUp is true — the per-city message would spam
    //  the log 63 times before the retry result is even known).
    if (!_warmingUp) {
      _log('NO_DATA: $city ($state) — all 5 sources exhausted');
    }
    return LiveRiverResult(
      station: RiverStation(
        city: city, state: state, river: river,
        station: '$city CWC Gauge',
        current: 0, warning: warningLevel,
        danger: dangerLevel, hfl: hfl,
        dataSource: 'NO_DATA', isLive: false,
      ),
      source:     'NO_DATA',
      confidence: 0.0,
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // CACHE WARMER  (with cold-start retry)
  //
  // First attempt uses _bulkTimeout (28 s).  If the Render free-tier pod is
  // sleeping, it may not respond in time and the list comes back empty.
  // In that case we retry once with _bulkRetryTimeout (50 s) while setting
  // _warmingUp = true so per-city NO_DATA log lines are suppressed.
  // ══════════════════════════════════════════════════════════════════════════
  Future<void> _warmCache({bool force = false}) async {
    if (!force && _cacheValid) return;

    // ── First attempt: 28-second bulk fetch ───────────────────────────────
    List<dynamic> bulkResult = [];
    try {
      final bulk = await _api.getAllLiveTelemetry().timeout(_bulkTimeout);
      bulkResult = _deepList(bulk);
    } catch (_) {
      bulkResult = [];
    }

    // ── Cold-start guard: retry with longer timeout if bulk was empty ──────
    if (bulkResult.isEmpty) {
      _log('Bulk empty on first try — Render may be cold-starting. Retrying with 50 s timeout...');
      _warmingUp = true;
      try {
        final bulk2 = await _api.getAllLiveTelemetry().timeout(_bulkRetryTimeout);
        bulkResult = _deepList(bulk2);
        if (bulkResult.isNotEmpty) {
          _log('Cold-start retry succeeded: ${bulkResult.length} stations received');
        } else {
          _log('Cold-start retry also returned empty — backend may be down');
        }
      } catch (e) {
        _log('Cold-start retry failed: $e');
        bulkResult = [];
      } finally {
        _warmingUp = false;
      }
    }

    if (bulkResult.isNotEmpty) {
      _bulkList = bulkResult;
      // Populate per-state sub-caches from bulk data
      for (final item in bulkResult.whereType<Map<String, dynamic>>()) {
        final st = _s(item['state_name'] ?? item['state'] ?? item['stateName'] ?? '');
        if (st.isNotEmpty) {
          _stateCache.putIfAbsent(_stateKey(st), () => []).add(item);
        }
      }
    } else {
      _bulkList = [];
    }

    // ── Live levels (global) ──────────────────────────────────────────────
    try {
      final ll = await _api.getLiveLevels().timeout(_stateTimeout);
      _liveLevels = _deepList(ll);
    } catch (_) {
      _liveLevels = [];
    }

    _cacheTime = DateTime.now();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // BUILD RESULT — constructs RiverStation + runs ML prediction
  // ══════════════════════════════════════════════════════════════════════════
  Future<LiveRiverResult> _buildResult({
    required String city,
    required String state,
    required String river,
    required double wl,
    required double dl,
    required double hfl,
    required double lv,
    required Map<String, dynamic> record,
    required String source,
    required double confidence,
  }) async {
    final wlR = _fp(record['warning_level'] ?? record['warningLevel'] ?? record['wl'])
        .let((v) => v > 0 ? v : wl);
    final dlR = _fp(record['danger_level']  ?? record['dangerLevel']  ?? record['dl'])
        .let((v) => v > 0 ? v : dl);
    final hlR = _fp(record['hfl'] ?? record['highest_flood_level'] ?? record['hfl_level'])
        .let((v) => v > 0 ? v : hfl);
    final rf  = _fp(record['rainfall_last_hour'] ?? record['rainfall'] ?? record['rain_mm']);
    final fl  = _fp(record['flow_rate'] ?? record['discharge'] ?? record['flowRate']);
    final ts  = _s(record['timestamp']  ?? record['updated_at'] ?? record['last_updated']
                   ?? record['lastUpdated']);
    final rawTrend = _s(record['trend'] ?? record['level_trend'] ?? record['water_trend']);
    final trend    = rawTrend.isNotEmpty
        ? rawTrend.toUpperCase()
        : _deriveTrend(lv, wlR, dlR);

    bool stale = false;
    if (ts.isNotEmpty) {
      final dt = DateTime.tryParse(ts);
      if (dt != null) stale = DateTime.now().difference(dt) > const Duration(minutes: 30);
    }

    final stationName = _s(
      record['station'] ?? record['stationName'] ?? record['station_name']
      ?? record['name']  ?? record['gaugeStation'],
    ).let((v) => v.isNotEmpty ? _cap(v) : '$city CWC Gauge');

    final station = RiverStation(
      city:             city,
      state:            state,
      river:            river,
      station:          stationName,
      current:          lv,
      warning:          wlR,
      danger:           dlR,
      hfl:              hlR,
      rainfallLastHour: rf > 0 ? rf : null,
      flowRate:         fl > 0 ? fl : null,
      trend:            trend.isNotEmpty ? trend : null,
      liveStatus:       _s(record['status'] ?? record['alert_status'] ?? record['flood_status'])
                            .let((v) => v.isNotEmpty ? v.toUpperCase() : null),
      lastUpdated:      ts.isNotEmpty ? ts : null,
      dataSource:       source,
      isLive:           true,
    );

    // ── ML Prediction — only with confirmed real level ────────────────────
    String? mlRisk;
    double? mlProb;
    try {
      final pred = await _api.predict({
        'city':          city,
        'state':         state,
        'river_level':   lv,
        'warning_level': wlR,
        'danger_level':  dlR,
        'rainfall':      rf,
        'flow_rate':     fl,
        'trend':         trend,
      }).timeout(_predTimeout);
      final rawRisk = _s(pred['risk_level'] ?? pred['riskLevel'] ?? pred['flood_risk']);
      mlRisk = rawRisk.isNotEmpty ? rawRisk.toUpperCase() : null;
      mlProb = _fp(pred['flood_probability'] ?? pred['probability'] ?? pred['risk_score']);
      if ((mlProb ?? 0) > 1.0) mlProb = (mlProb ?? 0) / 100.0;
      if ((mlProb ?? 0) == 0) mlProb = null;
    } catch (_) {}

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

  // ══════════════════════════════════════════════════════════════════════════
  // MATCHING ENGINE — confidence-scored
  // T0 (1.00): exact city name
  // T1 (0.90): city name contained in station or vice versa
  // T2 (0.85): city token + river + state
  // T3 (0.80): city token match
  // T4 (0.70): river + state both match
  // T5 (0.60): river match only
  // T6 (0.45): state match + partial river token
  // <0.40: rejected
  // ══════════════════════════════════════════════════════════════════════════
  _MatchResult? _bestMatch(
      List<dynamic> list, String city, String state, String river) {
    _MatchResult? best;
    final lc = city.toLowerCase().trim();
    final ls = state.toLowerCase().trim();
    final lr = river.toLowerCase().trim();

    for (final item in list.whereType<Map<String, dynamic>>()) {
      final sc  = _s(item['station']      ?? item['stationName']  ?? item['station_name']
                  ?? item['city']         ?? item['location']     ?? item['name']
                  ?? item['site_name']    ?? item['gaugeStation'] ?? item['gauge_station']);
      final ist = _s(item['state_name']   ?? item['state']        ?? item['stateName']
                  ?? item['State']        ?? '');
      final rv  = _s(item['river_name']   ?? item['river']        ?? item['riverName']
                  ?? item['river_basin']  ?? item['basin']        ?? item['River'] ?? '');

      double conf = 0.0;
      if      (sc == lc || sc.replaceAll(' ', '') == lc.replaceAll(' ', ''))          conf = 1.00;
      else if (sc.contains(lc) || (lc.contains(sc) && sc.length > 3))                conf = 0.90;
      else if (_tok(sc, lc) && lr.isNotEmpty && rv.contains(lr) && ist.contains(ls)) conf = 0.85;
      else if (_tok(sc, lc))                                                          conf = 0.80;
      else if (lr.isNotEmpty && rv.contains(lr) && ist.isNotEmpty && ist.contains(ls)) conf = 0.70;
      else if (lr.isNotEmpty && rv.contains(lr))                                      conf = 0.60;
      else if (ls.isNotEmpty && ist.contains(ls) && lr.isNotEmpty && _rvTok(rv, lr)) conf = 0.45;

      if (conf > (best?.confidence ?? 0)) {
        best = _MatchResult(record: item, confidence: conf);
      }
      if (conf >= 1.0) break;
    }
    return best;
  }

  bool _tok(String source, String target) {
    for (final t in source.split(RegExp(r'[\s_\-,()]+')))
      if (t.length >= 4 && target.contains(t)) return true;
    return false;
  }

  bool _rvTok(String rv, String lr) {
    final tokens = lr.split(RegExp(r'[\s_\-]+'));
    return tokens.any((t) => t.length >= 4 && rv.contains(t));
  }

  // ══════════════════════════════════════════════════════════════════════════
  // LEVEL EXTRACTOR — 35 known field-name variants from CWC/WRIS/OpsFlood
  // ══════════════════════════════════════════════════════════════════════════
  double _extractLevel(Map<String, dynamic> d) => _fp(
    d['river_level']      ?? d['riverLevel']        ?? d['current_level']   ??
    d['water_level']      ?? d['gauge_reading']      ?? d['currentLevel']    ??
    d['level']            ?? d['gauge_level']        ?? d['water_stage']     ??
    d['stage']            ?? d['obs_level']          ?? d['observed_level']  ??
    d['gauge']            ?? d['rl']                 ?? d['wl']              ??
    d['current']          ?? d['present_level']      ?? d['today_level']     ??
    d['live_level']       ?? d['liveLevel']           ?? d['gauge_value']    ??
    d['water_elevation']  ?? d['elevation']           ?? d['obsLevel']       ??
    d['currentObs']       ?? d['river_stage']         ?? d['gaugeReading'],
  );

  // ══════════════════════════════════════════════════════════════════════════
  // TREND DERIVATION
  // ══════════════════════════════════════════════════════════════════════════
  String _deriveTrend(double lv, double wl, double dl) {
    if (wl <= 0) return 'STEADY';
    final ratio = lv / wl;
    if (ratio >= 1.0) return 'RISING';
    if (ratio < 0.75) return 'FALLING';
    return 'STEADY';
  }

  // ══════════════════════════════════════════════════════════════════════════
  // DEEP LIST EXTRACTOR — handles arbitrary JSON nesting (up to depth 8)
  // ══════════════════════════════════════════════════════════════════════════
  List<dynamic> _deepList(dynamic payload, {int depth = 0}) {
    if (depth > 8) return [];
    if (payload is List)                  return payload.where((e) => e != null).toList();
    if (payload is Map<String, dynamic>) {
      for (final k in [
        'data', 'levels', 'stations', 'results', 'items', 'records',
        'telemetry', 'readings', 'gauges', 'observations', 'response',
        'payload', 'body', 'list', 'entries', 'floods', 'alerts',
        'features', 'current', 'forecast', 'reservoir_data',
      ]) {
        final v = payload[k];
        if (v is List && v.isNotEmpty) return v;
        if (v is Map<String, dynamic>) {
          final inner = _deepList(v, depth: depth + 1);
          if (inner.isNotEmpty) return inner;
        }
      }
      if (payload.containsKey('river_level')   ||
          payload.containsKey('water_level')   ||
          payload.containsKey('gauge_reading') ||
          payload.containsKey('obs_level')     ||
          payload.containsKey('obsLevel')      ||
          payload.containsKey('station')       ||
          payload.containsKey('current_level')) {
        return [payload];
      }
    }
    return [];
  }

  // ══════════════════════════════════════════════════════════════════════════
  // HELPERS
  // ══════════════════════════════════════════════════════════════════════════
  String _stateKey(String state) => state.toLowerCase().replaceAll(' ', '_');

  static double _fp(dynamic v) =>
      v == null ? 0.0 : (double.tryParse(v.toString().trim()) ?? 0.0);

  static String _s(dynamic v) => (v?.toString() ?? '').trim().toLowerCase();

  static String _cap(String s) => s.isEmpty
      ? s
      : s.split(' ').map((w) =>
          w.isEmpty ? w : w[0].toUpperCase() + w.substring(1).toLowerCase()).join(' ');
}

// ── Match result ──────────────────────────────────────────────────────────────
class _MatchResult {
  final Map<String, dynamic> record;
  final double               confidence;
  const _MatchResult({required this.record, required this.confidence});
}

// ── Dart let extension ────────────────────────────────────────────────────────
extension _Let<T> on T {
  R let<R>(R Function(T) block) => block(this);
}
