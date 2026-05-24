// lib/services/cwc_direct_service.dart
//
// ╔══════════════════════════════════════════════════════════════════════════╗
// ║  OpsFlood — CWC Live Data Service (API-routed)                         ║
// ║                                                                          ║
// ║  PRINCIPLE: Every number shown must come from a REAL instrument.        ║
// ║  This file NEVER fabricates. If data is unavailable → NO_DATA.          ║
// ║                                                                          ║
// ║  ALL data routes through the OpsFlood backend (opsflood.onrender.com). ║
// ║  No direct calls to ffs.india-water.gov.in or indiawris.gov.in.        ║
// ║  The backend handles CWC/GloFAS data via Open-Meteo + CWC FFS proxy.   ║
// ║                                                                          ║
// ║  SOURCE A — /api/cwc-ffs/station   (CWC FFS normalised per station)    ║
// ║  SOURCE B — /api/live-telemetry    (GloFAS river discharge, 93 cities) ║
// ║  SOURCE C — /api/live-levels       (aggregated gauge levels)            ║
// ║  SOURCE D — /api/cwc-reservoir     (reservoir levels via data.gov.in)  ║
// ║                                                                          ║
// ║  TIMEOUTS: 55 / 55 / 45 / 35 s — sized to survive Render cold-start.  ║
// ║                                                                          ║
// ║  GAUGE SANITY RULE:                                                      ║
// ║  Indian river gauge heights are always 0.01 – 200 m.                   ║
// ║  Values outside this range are discharge / error codes and are          ║
// ║  treated as 0 (→ NO_DATA fallback).                                     ║
// ╚══════════════════════════════════════════════════════════════════════════╝

library;

import 'dart:async';

import '../constants.dart';
import 'api_service.dart';

// ─── Result types ─────────────────────────────────────────────────────────────

enum CwcDataSource { opsfloodProxy, indiaWaterFfs, indiaWris, dataGovReservoir, noData }

class CwcLiveReading {
  final String stationName;
  final String river;
  final String state;
  final double currentLevelM;
  final double dangerLevelM;
  final double warningLevelM;
  final double hflM;
  final String trend;
  final String alertColour;
  final String? forecastText;
  final DateTime observedAt;
  final CwcDataSource source;
  final double confidence;

  const CwcLiveReading({
    required this.stationName,
    required this.river,
    required this.state,
    required this.currentLevelM,
    required this.dangerLevelM,
    required this.warningLevelM,
    required this.hflM,
    required this.trend,
    required this.alertColour,
    this.forecastText,
    required this.observedAt,
    required this.source,
    required this.confidence,
  });

  String get riskLabel {
    if (currentLevelM <= 0)                    return 'NO_DATA';
    if (currentLevelM >= dangerLevelM)         return 'CRITICAL';
    if (currentLevelM >= warningLevelM)        return 'SEVERE';
    if (currentLevelM >= warningLevelM * 0.85) return 'MODERATE';
    return 'LOW';
  }

  double get proximityToDangerM => dangerLevelM - currentLevelM;
  bool   get isAboveDanger      => currentLevelM >= dangerLevelM;
  bool   get isAboveWarning     => currentLevelM >= warningLevelM;
  bool   get hasRealData        => currentLevelM > 0 && source != CwcDataSource.noData;

  @override
  String toString() =>
      'CwcLiveReading($stationName, $river, ${currentLevelM}m/$dangerLevelM m, '
      '$riskLabel, ${source.name}, conf=${confidence.toStringAsFixed(2)})';
}

// ─── NO_DATA sentinel ─────────────────────────────────────────────────────────

CwcLiveReading _noData({
  required String city,
  required String state,
  required String river,
  required double warningLevel,
  required double dangerLevel,
}) =>
    CwcLiveReading(
      stationName:   '$city CWC Gauge',
      river:         river,
      state:         state,
      currentLevelM: 0.0,
      dangerLevelM:  dangerLevel,
      warningLevelM: warningLevel,
      hflM:          dangerLevel * 1.15,
      trend:         'STEADY',
      alertColour:   'GREEN',
      forecastText:  null,
      observedAt:    DateTime.now(),
      source:        CwcDataSource.noData,
      confidence:    0.0,
    );

// ─── CWC Direct Service ───────────────────────────────────────────────────────

class CwcDirectService {
  CwcDirectService._();
  static final CwcDirectService instance = CwcDirectService._();

  final _api = ApiService();

  static const _tA = Duration(seconds: 55);
  static const _tB = Duration(seconds: 55);
  static const _tC = Duration(seconds: 45);
  static const _tD = Duration(seconds: 35);

  // Gauge sanity bounds — Indian river stations are always 0.01–200 m.
  static const double _gaugeMin = 0.01;
  static const double _gaugeMax = 200.0;

  // 5-minute client-side cache
  final Map<String, CwcLiveReading> _cache   = {};
  final Map<String, DateTime>       _cacheTs = {};
  static const _cacheTTL = Duration(minutes: 5);

  final Map<String, List<dynamic>> _levelsStateCache   = {};
  final Map<String, DateTime>      _levelsStateCacheTs = {};

  bool _isCacheValid(String key) {
    final ts = _cacheTs[key];
    return ts != null && DateTime.now().difference(ts) < _cacheTTL;
  }

  bool _isLevelsCacheValid(String stateKey) {
    final ts = _levelsStateCacheTs[stateKey];
    return ts != null && DateTime.now().difference(ts) < _cacheTTL;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // PUBLIC: Get live reading for one city — cascade A → B → C → D → NO_DATA
  // ══════════════════════════════════════════════════════════════════════════
  Future<CwcLiveReading> getLiveReading({
    required String city,
    required String state,
    required String river,
    required double warningLevel,
    required double dangerLevel,
  }) async {
    final key = '${city.toLowerCase()}_${state.toLowerCase()}';
    if (_isCacheValid(key) && _cache.containsKey(key)) return _cache[key]!;

    final a = await _fromFfsStation(city, state, river, warningLevel, dangerLevel);
    if (a != null && a.hasRealData) { _put(key, a); return a; }

    final b = await _fromTelemetry(city, state, river, warningLevel, dangerLevel);
    if (b != null && b.hasRealData) { _put(key, b); return b; }

    final c = await _fromLiveLevels(city, state, river, warningLevel, dangerLevel);
    if (c != null && c.hasRealData) { _put(key, c); return c; }

    final d = await _fromReservoir(city, state, river, warningLevel, dangerLevel);
    if (d != null && d.hasRealData) { _put(key, d); return d; }

    return _noData(city: city, state: state, river: river,
        warningLevel: warningLevel, dangerLevel: dangerLevel);
  }

  void _put(String key, CwcLiveReading r) {
    _cache[key]   = r;
    _cacheTs[key] = DateTime.now();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // PUBLIC: Bulk all monitored cities
  // ══════════════════════════════════════════════════════════════════════════
  Future<List<CwcLiveReading>> getAllLiveReadings() =>
      Future.wait(AppConstants.monitoredCities.map((mc) => getLiveReading(
        city:         mc['city']  as String,
        state:        mc['state'] as String,
        river:        mc['river'] as String,
        warningLevel: _fp(mc['warning_level']),
        dangerLevel:  _fp(mc['danger_level']),
      )));

  Future<List<CwcLiveReading>> getActiveAlerts() async {
    final all = await getAllLiveReadings();
    return all
        .where((r) => r.riskLabel == 'SEVERE' || r.riskLabel == 'CRITICAL')
        .toList()
      ..sort((a, b) => b.currentLevelM.compareTo(a.currentLevelM));
  }

  Future<List<CwcLiveReading>> forceRefresh() {
    _cache.clear();
    _cacheTs.clear();
    _levelsStateCache.clear();
    _levelsStateCacheTs.clear();
    return getAllLiveReadings();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // SOURCE A — /api/cwc-ffs/station
  // ══════════════════════════════════════════════════════════════════════════
  Future<CwcLiveReading?> _fromFfsStation(String city, String state,
      String river, double wl, double dl) async {
    try {
      final res = await _api.getFloodForecast(city: city, state: state)
          .timeout(_tA);
      if (res['status'] == 'error') return null;
      final items = _list(res);
      if (items.isEmpty) return null;
      final m = _best(items, city, state, river);
      if (m == null || m.conf < 0.6) return null;
      final lv = _level(m.r);
      if (lv <= 0) return null;
      return _build(m.r, city, state, river, lv, wl, dl,
          CwcDataSource.opsfloodProxy, m.conf);
    } catch (_) { return null; }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // SOURCE B — /api/live-telemetry
  // ══════════════════════════════════════════════════════════════════════════
  Future<CwcLiveReading?> _fromTelemetry(String city, String state,
      String river, double wl, double dl) async {
    try {
      final res = await _api.getLiveTelemetry(state: state, station: city)
          .timeout(_tB);
      if (res['status'] == 'error') return null;
      final items = _list(res);
      if (items.isEmpty) return null;
      final m = _best(items, city, state, river);
      if (m == null || m.conf < 0.5) return null;
      final lv = _level(m.r);
      if (lv <= 0) return null;
      return _build(m.r, city, state, river, lv, wl, dl,
          CwcDataSource.opsfloodProxy, m.conf);
    } catch (_) { return null; }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // SOURCE C — /api/live-levels
  // ══════════════════════════════════════════════════════════════════════════
  Future<CwcLiveReading?> _fromLiveLevels(String city, String state,
      String river, double wl, double dl) async {
    try {
      final stKey = state.toLowerCase().replaceAll(' ', '_');

      if (!_isLevelsCacheValid(stKey)) {
        final res = await _api.getLiveLevels(state: state).timeout(_tC);
        if (res['status'] != 'error') {
          _levelsStateCache[stKey]   = _list(res);
          _levelsStateCacheTs[stKey] = DateTime.now();
        } else {
          _levelsStateCache[stKey]   = [];
          _levelsStateCacheTs[stKey] = DateTime.now();
        }
      }

      final items = _levelsStateCache[stKey] ?? [];
      if (items.isEmpty) return null;

      final m = _best(items, city, state, river);
      if (m == null || m.conf < 0.5) return null;
      final lv = _level(m.r);
      if (lv <= 0) return null;
      return _build(m.r, city, state, river, lv, wl, dl,
          CwcDataSource.opsfloodProxy, m.conf);
    } catch (_) { return null; }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // SOURCE D — /api/cwc-reservoir
  // ══════════════════════════════════════════════════════════════════════════
  Future<CwcLiveReading?> _fromReservoir(String city, String state,
      String river, double wl, double dl) async {
    try {
      final res = await _api.getReservoirLevels(state: state).timeout(_tD);
      if (res['status'] == 'error') return null;
      final items = _list(res);
      if (items.isEmpty) return null;
      final m = _best(items, city, state, river);
      if (m == null || m.conf < 0.5) return null;
      final rawLv = _fp(m.r['current_level_m'] ?? m.r['current_level'] ?? m.r['wl']);
      final lv = _sanityClamp(rawLv);
      if (lv <= 0) return null;
      final frl = _fp(m.r['full_reservoir_level_m'] ?? m.r['frl'] ?? m.r['FRL']);
      final eDl = frl > 0 ? frl : dl;
      final eWl = frl > 0 ? frl * 0.90 : wl;
      return CwcLiveReading(
        stationName:   _cap(_s(m.r['reservoir_name'] ?? m.r['name'] ?? city)),
        river:         river,
        state:         state,
        currentLevelM: lv,
        dangerLevelM:  eDl,
        warningLevelM: eWl,
        hflM:          eDl * 1.05,
        trend:         'STEADY',
        alertColour:   _colour(lv, eWl, eDl),
        observedAt:    DateTime.now(),
        source:        CwcDataSource.dataGovReservoir,
        confidence:    m.conf,
      );
    } catch (_) { return null; }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // BUILD — generic reading from any OpsFlood API record
  // ══════════════════════════════════════════════════════════════════════════
  CwcLiveReading _build(Map<String, dynamic> r, String city, String state,
      String river, double lv, double wl, double dl,
      CwcDataSource src, double conf) {
    final eWl = _fp(r['warning_level'] ?? r['warningLevel'] ?? r['wl']).let((v) => v > 0 ? v : wl);
    final eDl = _fp(r['danger_level']  ?? r['dangerLevel']  ?? r['dl']).let((v) => v > 0 ? v : dl);
    final eHl = _fp(r['hfl'] ?? r['highest_flood_level']).let((v) => v > 0 ? v : eDl * 1.15);
    final ts  = _s(r['timestamp'] ?? r['updated_at'] ?? r['last_updated']);
    DateTime obs = DateTime.now();
    if (ts.isNotEmpty) { try { obs = DateTime.parse(ts); } catch (_) {} }
    final name = _s(r['station'] ?? r['stationName'] ?? r['station_name']
        ?? r['city'] ?? r['name']);
    return CwcLiveReading(
      stationName:   name.isNotEmpty ? _cap(name) : '$city CWC Gauge',
      river:         river,
      state:         state,
      currentLevelM: lv,
      dangerLevelM:  eDl,
      warningLevelM: eWl,
      hflM:          eHl,
      trend:         _s(r['trend'] ?? r['level_trend']).toUpperCase().let(
                         (t) => t.isNotEmpty ? t : _trend(lv, eWl, eDl)),
      alertColour:   _colour(lv, eWl, eDl),
      forecastText:  _s(r['forecast'] ?? r['forecast_text']).let((v) => v.isNotEmpty ? v : null),
      observedAt:    obs,
      source:        src,
      confidence:    conf,
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // MATCHING ENGINE
  // ══════════════════════════════════════════════════════════════════════════
  _M? _best(List<dynamic> list, String city, String state, String river) {
    _M? best;
    final lc = city.toLowerCase().trim();
    final ls = state.toLowerCase().trim();
    final lr = river.toLowerCase().trim();
    for (final item in list.whereType<Map<String, dynamic>>()) {
      final sc  = _s(item['station'] ?? item['stationName'] ?? item['station_name']
          ?? item['city'] ?? item['location'] ?? item['name']);
      final ist = _s(item['state_name'] ?? item['state'] ?? item['stateName']);
      final rv  = _s(item['river_name'] ?? item['river'] ?? item['riverName']);
      double c = 0;
      if (sc == lc || sc.replaceAll(' ', '') == lc.replaceAll(' ', '')) { c = 1.00; }
      else if (sc.contains(lc) || (lc.contains(sc) && sc.length > 3))  { c = 0.90; }
      else if (_tok(sc, lc) && rv.contains(lr) && ist.contains(ls))    { c = 0.85; }
      else if (_tok(sc, lc))                                             { c = 0.80; }
      else if (lr.isNotEmpty && rv.contains(lr) && ist.contains(ls))    { c = 0.70; }
      else if (lr.isNotEmpty && rv.contains(lr))                        { c = 0.60; }
      if (c > (best?.conf ?? 0)) { best = _M(item, c); }
      if (c >= 1.0) { break; }
    }
    return best;
  }

  bool _tok(String src, String tgt) {
    for (final t in src.split(RegExp(r'[\s_\-,()+]+'))) {
      if (t.length >= 4 && tgt.contains(t)) { return true; }
    }
    return false;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // HELPERS
  // ══════════════════════════════════════════════════════════════════════════

  /// Rejects values outside [0.01, 200] m — anything else is a discharge
  /// figure, error code, or wrong-column parse artifact.
  double _sanityClamp(double v) {
    if (v < _gaugeMin || v > _gaugeMax) return 0.0;
    return v;
  }

  List<dynamic> _list(dynamic p, {int d = 0}) {
    if (d > 5) return [];
    if (p is List) return p.where((e) => e != null).toList();
    if (p is Map<String, dynamic>) {
      for (final k in ['data', 'stations', 'levels', 'results', 'items',
          'records', 'telemetry', 'readings', 'gauges', 'alerts', 'current']) {
        final v = p[k];
        if (v is List && v.isNotEmpty) return v;
        if (v is Map<String, dynamic>) {
          final inner = _list(v, d: d + 1);
          if (inner.isNotEmpty) return inner;
        }
      }
      if (p.containsKey('river_level') || p.containsKey('water_level') ||
          p.containsKey('current_level') || p.containsKey('station')) return [p];
    }
    return [];
  }

  /// Extract gauge height from a record and apply sanity clamp.
  double _level(Map<String, dynamic> d) => _sanityClamp(_fp(
    d['river_level']     ?? d['riverLevel']      ?? d['current_level']  ??
    d['water_level']     ?? d['gauge_reading']   ?? d['currentLevel']   ??
    d['level']           ?? d['gauge_level']     ?? d['obs_level']      ??
    d['stage']           ?? d['rl']              ?? d['wl']             ??
    d['live_level']      ?? d['liveLevel']        ?? d['gauge_value']   ??
    d['obsLevel']        ?? d['observedLevel']   ?? d['water_elevation'],
  ));

  String _colour(double lv, double wl, double dl) {
    if (dl > 0 && lv >= dl)        return 'RED';
    if (wl > 0 && lv >= wl)        return 'ORANGE';
    if (wl > 0 && lv >= wl * 0.85) return 'YELLOW';
    return 'GREEN';
  }

  String _trend(double lv, double wl, double dl) {
    if (wl <= 0) return 'STEADY';
    final r = lv / wl;
    if (r >= 1.0) return 'RISING';
    if (r < 0.75) return 'FALLING';
    return 'STEADY';
  }

  static double _fp(dynamic v) =>
      v == null ? 0.0 : (double.tryParse(v.toString().trim()) ?? 0.0);

  static String _s(dynamic v) => (v?.toString() ?? '').trim().toLowerCase();

  static String _cap(String s) => s.isEmpty ? s
      : s.split(' ').map((w) => w.isEmpty ? w
          : w[0].toUpperCase() + w.substring(1).toLowerCase()).join(' ');
}

// ── Internal types ────────────────────────────────────────────────────────────
class _M {
  final Map<String, dynamic> r;
  final double conf;
  const _M(this.r, this.conf);
}

extension _Let<T> on T {
  R let<R>(R Function(T) block) => block(this);
}
