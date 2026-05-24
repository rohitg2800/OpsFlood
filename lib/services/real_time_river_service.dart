// lib/services/real_time_river_service.dart
// OpsFlood — Real-Time River Data Service (v9 — Web-bridge + 55-city fix)
//
// ARCHITECTURE — Platform-aware 5-source cascade:
//
//   ON WEB (kIsWeb = true):
//     Sources 0-4 all hit opsflood.onrender.com which lacks CORS headers.
//     Instead, we bridge from LiveFetchEngine which already has real
//     Open-Meteo weather + GloFAS river-discharge data for every city.
//     The bridge converts FloodData → LiveRiverResult so the rest of the
//     UI (providers, screens) works identically on all platforms.
//
//   ON MOBILE / DESKTOP:
//     Original 5-source backend cascade unchanged.

import 'dart:async';
import 'package:flutter/foundation.dart';
import '../constants.dart';
import '../models/river_station.dart';
import 'api_service.dart';
import 'live_fetch_engine.dart';

// ── Result model ─────────────────────────────────────────────────────────────
class LiveRiverResult {
  final RiverStation station;
  final String       source;      // 'BULK'|'TELEMETRY'|'LIVE_LEVELS'|'CWC_FFS'|'RESERVOIR'|'GLOFAS'|'NO_DATA'
  final double       confidence;  // 0.0–1.0
  final String?      mlRiskLevel; // 'LOW'|'MODERATE'|'SEVERE'|'CRITICAL'|null
  final double?      mlFloodProb; // 0.0–1.0
  final bool         isStale;
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
  static final RealTimeRiverService instance = RealTimeRiverService._internal();
  factory RealTimeRiverService() => instance;
  RealTimeRiverService._internal();

  final ApiService        _api    = ApiService();
  final LiveFetchEngine   _lfe    = LiveFetchEngine();

  // ── Cache ─────────────────────────────────────────────────────────────────
  List<dynamic>                    _bulkList       = [];
  bool                             _bulkAttempted  = false;
  bool                             _bulkSucceeded  = false;
  final Map<String, List<dynamic>> _stateCache     = {};
  final Map<String, List<dynamic>> _reservoirCache = {};
  List<dynamic>                    _liveLevels     = [];
  DateTime?                        _cacheTime;
  List<LiveRiverResult>            _lastResults    = [];
  final Set<String>                _noDataLogged   = {};

  static const Duration _cacheTTL        = Duration(minutes: 5);
  static const _bulkTimeout              = Duration(seconds: 30);
  static const _bulkRetryTimeout         = Duration(seconds: 55);
  static const _stateTimeout             = Duration(seconds: 18);
  static const _ffsTimeout               = Duration(seconds: 14);
  static const _resTimeout               = Duration(seconds: 12);
  static const _predTimeout              = Duration(seconds: 8);
  static const double _minConfidence     = 0.35;

  bool get _cacheValid =>
      _cacheTime != null &&
      DateTime.now().difference(_cacheTime!) < _cacheTTL;

  List<LiveRiverResult> get lastResults => _lastResults;

  // ══════════════════════════════════════════════════════════════════════════
  // PUBLIC: Fetch all monitored cities
  // ══════════════════════════════════════════════════════════════════════════
  Future<List<LiveRiverResult>> fetchAll() async {
    // ── Web bridge: use LiveFetchEngine (Open-Meteo + GloFAS, CORS-safe) ────
    if (kIsWeb) {
      return _fetchAllWeb();
    }
    return _fetchAllMobile();
  }

  // ── Web: build results from LiveFetchEngine ─────────────────────────────
  Future<List<LiveRiverResult>> _fetchAllWeb() async {
    // Make sure LFE has run at least once
    if (_lfe.liveLevels.isEmpty) {
      await _lfe.refreshData();
    }

    final results = <LiveRiverResult>[];
    for (final mc in AppConstants.monitoredCities) {
      final city  = mc['city']  as String;
      final state = mc['state'] as String;
      final river = mc['river'] as String;
      final wl    = _fp(mc['warning_level']);
      final dl    = _fp(mc['danger_level']);
      final hfl   = dl > 0 ? dl * 1.10 : wl * 1.25;

      // Try LFE cache first (fast, no HTTP)
      final fd = _lfe.dataForCity(city);
      if (fd != null) {
        final lv = fd.currentLevel ?? 0.0;
        final risk = fd.riskLevel ?? 'LOW';
        results.add(LiveRiverResult(
          station: RiverStation(
            city:             city,
            state:            state,
            river:            river,
            station:          '$city GloFAS',
            current:          lv,
            warning:          fd.warningLevel > 0 ? fd.warningLevel : wl,
            danger:           fd.dangerLevel  > 0 ? fd.dangerLevel  : dl,
            hfl:              hfl,
            rainfallLastHour: fd.rainfall24h != null && fd.rainfall24h! > 0
                ? fd.rainfall24h! / 24
                : null,
            flowRate:         fd.flowRate,
            trend:            lv > (fd.warningLevel > 0 ? fd.warningLevel : wl)
                ? 'RISING'
                : 'STEADY',
            liveStatus:       risk,
            lastUpdated:      fd.lastUpdated.toIso8601String(),
            dataSource:       'GLOFAS',
            isLive:           true,
          ),
          source:      'GLOFAS',
          confidence:  0.75,
          mlRiskLevel: risk,
          mlFloodProb: _riskToProb(risk),
          isStale:     DateTime.now().difference(fd.lastUpdated) >
                       const Duration(minutes: 30),
        ));
        continue;
      }

      // City not yet in LFE cache — enqueue an individual fetch
      results.add(await _fetchCityGloFas(
        city: city, state: state, river: river,
        warningLevel: wl, dangerLevel: dl,
      ));
    }

    final live = results.where((r) => r.source != 'NO_DATA').length;
    _log('fetchAll(web) done: $live/${results.length} with live data');
    _lastResults = results;
    notifyListeners();
    return results;
  }

  // ── Per-city GloFAS fetch (web fallback for cities not in LFE cache) ────
  Future<LiveRiverResult> _fetchCityGloFas({
    required String city,
    required String state,
    required String river,
    required double warningLevel,
    required double dangerLevel,
  }) async {
    final hfl = dangerLevel > 0 ? dangerLevel * 1.10 : warningLevel * 1.25;
    // Find lat/lon from monitoredCities
    final mc = AppConstants.monitoredCities.firstWhere(
      (m) => (m['city'] as String).toLowerCase() == city.toLowerCase(),
      orElse: () => <String, dynamic>{},
    );
    final lat = _fp(mc['lat']);
    final lon = _fp(mc['lon']);
    if (lat == 0 && lon == 0) return _noData(city, state, river, warningLevel, dangerLevel, hfl);

    try {
      // Reuse LFE's GloFAS fetcher indirectly via a direct HTTP call
      // (Open-Meteo flood API is CORS-safe)
      final uri = Uri.parse(
        'https://flood-api.open-meteo.com/v1/flood'
        '?latitude=$lat&longitude=$lon'
        '&daily=river_discharge&past_days=7&forecast_days=1',
      );
      // Use Dart's built-in Uri approach — no need to import http again,
      // LiveFetchEngine._client is private; just call lfe.refreshData for this city.
      // Simpler: trigger LFE refresh which covers all cities, then re-read.
      await _lfe.refreshData();
      final fd2 = _lfe.dataForCity(city);
      if (fd2 != null) {
        final lv = fd2.currentLevel ?? 0.0;
        final risk = fd2.riskLevel ?? 'LOW';
        return LiveRiverResult(
          station: RiverStation(
            city: city, state: state, river: river,
            station: '$city GloFAS',
            current: lv,
            warning: fd2.warningLevel > 0 ? fd2.warningLevel : warningLevel,
            danger:  fd2.dangerLevel  > 0 ? fd2.dangerLevel  : dangerLevel,
            hfl:     hfl,
            rainfallLastHour: fd2.rainfall24h != null && fd2.rainfall24h! > 0
                ? fd2.rainfall24h! / 24 : null,
            flowRate:   fd2.flowRate,
            trend:      lv > warningLevel ? 'RISING' : 'STEADY',
            liveStatus: risk,
            lastUpdated: fd2.lastUpdated.toIso8601String(),
            dataSource: 'GLOFAS',
            isLive: true,
          ),
          source: 'GLOFAS', confidence: 0.75,
          mlRiskLevel: risk, mlFloodProb: _riskToProb(risk),
        );
      }
    } catch (e) {
      _log('GloFAS fetch error for $city: $e');
    }
    return _noData(city, state, river, warningLevel, dangerLevel, hfl);
  }

  LiveRiverResult _noData(String city, String state, String river,
      double wl, double dl, double hfl) {
    return LiveRiverResult(
      station: RiverStation(
        city: city, state: state, river: river,
        station: '$city CWC Gauge',
        current: 0, warning: wl, danger: dl, hfl: hfl,
        dataSource: 'NO_DATA', isLive: false,
      ),
      source: 'NO_DATA', confidence: 0.0,
    );
  }

  double _riskToProb(String risk) {
    switch (risk.toUpperCase()) {
      case 'CRITICAL': return 0.92;
      case 'HIGH':     return 0.72;
      case 'MODERATE': return 0.48;
      default:         return 0.15;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // MOBILE: original backend cascade
  // ══════════════════════════════════════════════════════════════════════════
  Future<List<LiveRiverResult>> _fetchAllMobile() async {
    await _warmCache();

    final firstPass = await Future.wait(
      AppConstants.monitoredCities.map((mc) => _fetchCity(
        city:         mc['city']  as String,
        state:        mc['state'] as String,
        river:        mc['river'] as String,
        warningLevel: _fp(mc['warning_level']),
        dangerLevel:  _fp(mc['danger_level']),
        allowFfsCall: false,
      )),
    );

    final noDataIndices = <int>[];
    for (int i = 0; i < firstPass.length; i++) {
      if (firstPass[i].source == 'NO_DATA') noDataIndices.add(i);
    }

    List<LiveRiverResult> results = List.of(firstPass);

    if (noDataIndices.isNotEmpty) {
      _log('Pass3-FFS: firing for ${noDataIndices.length} NO_DATA cities in parallel');
      final ffsFutures = noDataIndices.map((i) {
        final mc = AppConstants.monitoredCities[i];
        return _fetchCity(
          city:         mc['city']  as String,
          state:        mc['state'] as String,
          river:        mc['river'] as String,
          warningLevel: _fp(mc['warning_level']),
          dangerLevel:  _fp(mc['danger_level']),
          allowFfsCall: true,
        );
      });
      final ffsResults = await Future.wait(ffsFutures);
      for (int k = 0; k < noDataIndices.length; k++) {
        results[noDataIndices[k]] = ffsResults[k];
      }
    }

    final stillNoData = results.where((r) => r.source == 'NO_DATA').toList();
    final live        = results.length - stillNoData.length;
    final noDataNames = stillNoData.map((r) => r.station.city).join(', ');
    _log('fetchAll done: $live/${results.length} with live data'
        '${stillNoData.isNotEmpty ? " | NO_DATA: $noDataNames" : ""}');

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
    if (kIsWeb) {
      final mc = AppConstants.monitoredCities.firstWhere(
        (m) => (m['city'] as String).toLowerCase() == city.toLowerCase(),
        orElse: () => <String, dynamic>{},
      );
      return _fetchCityGloFas(
        city: city, state: state, river: river,
        warningLevel: _fp(mc['warning_level']),
        dangerLevel:  _fp(mc['danger_level']),
      );
    }
    await _warmCache();
    final mc = AppConstants.monitoredCities.firstWhere(
      (m) => (m['city'] as String).toLowerCase() == city.toLowerCase(),
      orElse: () => <String, dynamic>{},
    );
    return _fetchCity(
      city: city, state: state, river: river,
      warningLevel: _fp(mc['warning_level']),
      dangerLevel:  _fp(mc['danger_level']),
      allowFfsCall: true,
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
    _cacheTime     = null;
    _bulkList      = [];
    _bulkAttempted = false;
    _bulkSucceeded = false;
    _stateCache.clear();
    _reservoirCache.clear();
    _liveLevels    = [];
    _noDataLogged.clear();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // MOBILE ONLY: 5-source cascade for one city
  // ══════════════════════════════════════════════════════════════════════════
  Future<LiveRiverResult> _fetchCity({
    required String city,
    required String state,
    required String river,
    required double warningLevel,
    required double dangerLevel,
    bool allowFfsCall = true,
  }) async {
    final hfl = dangerLevel > 0 ? dangerLevel * 1.10 : warningLevel * 1.25;

    if (_bulkList.isNotEmpty) {
      final m = _bestMatch(_bulkList, city, state, river);
      if (m != null && m.confidence >= _minConfidence) {
        final lv = _extractLevel(m.record);
        if (lv > 0) {
          return _buildResult(city: city, state: state, river: river,
              wl: warningLevel, dl: dangerLevel, hfl: hfl,
              lv: lv, record: m.record, source: 'BULK', confidence: m.confidence);
        }
      }
    }

    final stKey = _stateKey(state);
    if (!_bulkSucceeded && !_stateCache.containsKey(stKey)) {
      try {
        final r = await _api.getLiveTelemetry(state: state, limit: 500).timeout(_stateTimeout);
        _stateCache[stKey] = _deepList(r);
      } catch (_) { _stateCache[stKey] = []; }
    }
    final stData = _stateCache[stKey] ?? [];
    if (stData.isNotEmpty) {
      final m = _bestMatch(stData, city, state, river);
      if (m != null && m.confidence >= _minConfidence) {
        final lv = _extractLevel(m.record);
        if (lv > 0) {
          return _buildResult(city: city, state: state, river: river,
              wl: warningLevel, dl: dangerLevel, hfl: hfl,
              lv: lv, record: m.record, source: 'TELEMETRY', confidence: m.confidence);
        }
      }
    }

    if (_liveLevels.isNotEmpty) {
      final m = _bestMatch(_liveLevels, city, state, river);
      if (m != null && m.confidence >= _minConfidence) {
        final lv = _extractLevel(m.record);
        if (lv > 0) {
          return _buildResult(city: city, state: state, river: river,
              wl: warningLevel, dl: dangerLevel, hfl: hfl,
              lv: lv, record: m.record, source: 'LIVE_LEVELS', confidence: m.confidence);
        }
      }
    }

    if (allowFfsCall) {
      try {
        final ffs = await _api.getFloodForecast(city: city, state: state).timeout(_ffsTimeout);
        final fl  = _deepList(ffs);
        for (final item in fl.whereType<Map<String, dynamic>>()) {
          final lv = _extractLevel(item);
          if (lv > 0) {
            return _buildResult(city: city, state: state, river: river,
                wl: warningLevel, dl: dangerLevel, hfl: hfl,
                lv: lv, record: item, source: 'CWC_FFS', confidence: 0.85);
          }
        }
      } catch (_) {}
    }

    if (allowFfsCall) {
      if (!_reservoirCache.containsKey(stKey)) {
        try {
          final res = await _api.getReservoirLevels(state: state).timeout(_resTimeout);
          _reservoirCache[stKey] = _deepList(res);
        } catch (_) { _reservoirCache[stKey] = []; }
      }
      final rl = _reservoirCache[stKey] ?? [];
      if (rl.isNotEmpty) {
        final m = _bestMatch(rl, city, state, river);
        if (m != null && m.confidence >= _minConfidence) {
          final lv = _fp(
            m.record['current_level_m'] ?? m.record['current_level'] ??
            m.record['wl']              ?? m.record['water_level'],
          );
          if (lv > 0) {
            return _buildResult(city: city, state: state, river: river,
                wl: warningLevel, dl: dangerLevel, hfl: hfl,
                lv: lv, record: m.record, source: 'RESERVOIR', confidence: m.confidence);
          }
        }
      }
    }

    _noDataLogged.add('${city.toLowerCase()}-${state.toLowerCase()}');
    return LiveRiverResult(
      station: RiverStation(
        city: city, state: state, river: river,
        station: '$city CWC Gauge',
        current: 0, warning: warningLevel, danger: dangerLevel, hfl: hfl,
        dataSource: 'NO_DATA', isLive: false,
      ),
      source: 'NO_DATA', confidence: 0.0,
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // MOBILE ONLY: Cache warmer
  // ══════════════════════════════════════════════════════════════════════════
  Future<void> _warmCache({bool force = false}) async {
    if (!force && _cacheValid) return;

    List<dynamic> bulkResult = [];
    try {
      final bulk = await _api.getAllLiveTelemetry(limit: 1000).timeout(_bulkTimeout);
      bulkResult = _deepList(bulk);
      _log('Bulk attempt 1: ${bulkResult.length} records');
    } catch (e) { _log('Bulk attempt 1 failed: $e'); }

    if (bulkResult.isEmpty) {
      _log('Bulk empty — Render cold-starting. Retrying (55 s)…');
      try {
        final bulk2 = await _api.getAllLiveTelemetry(limit: 1000).timeout(_bulkRetryTimeout);
        bulkResult  = _deepList(bulk2);
        _log(bulkResult.isNotEmpty
            ? 'Cold-start retry OK: ${bulkResult.length} records'
            : 'Cold-start retry also empty');
      } catch (e) { _log('Cold-start retry failed: $e'); }
    }

    _bulkAttempted = true;
    _bulkSucceeded = bulkResult.isNotEmpty;

    if (_bulkSucceeded) {
      _bulkList = bulkResult;
      for (final item in bulkResult.whereType<Map<String, dynamic>>()) {
        final st = _s(item['state_name'] ?? item['state'] ?? item['stateName'] ?? '');
        if (st.isNotEmpty) {
          _stateCache.putIfAbsent(_stateKey(st), () => []).add(item);
        }
      }
    } else {
      _bulkList = [];
    }

    try {
      final ll = await _api.getLiveLevels().timeout(_stateTimeout);
      _liveLevels = _deepList(ll);
      _log('Live levels: ${_liveLevels.length} records');
    } catch (e) {
      _log('Live levels fetch failed: $e');
      _liveLevels = [];
    }

    _noDataLogged.clear();
    _cacheTime = DateTime.now();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // BUILD RESULT (mobile only)
  // ══════════════════════════════════════════════════════════════════════════
  Future<LiveRiverResult> _buildResult({
    required String city, required String state, required String river,
    required double wl, required double dl, required double hfl,
    required double lv, required Map<String, dynamic> record,
    required String source, required double confidence,
  }) async {
    final wlR = _fp(record['warning_level'] ?? record['warningLevel'] ?? record['wl'])
        .let((v) => v > 0 ? v : wl);
    final dlR = _fp(record['danger_level']  ?? record['dangerLevel']  ?? record['dl'])
        .let((v) => v > 0 ? v : dl);
    final hlR = _fp(record['hfl'] ?? record['highest_flood_level'] ?? record['hfl_level'])
        .let((v) => v > 0 ? v : hfl);
    final rf  = _fp(record['rainfall_last_hour'] ?? record['rainfall'] ?? record['rain_mm']);
    final fl  = _fp(record['flow_rate'] ?? record['discharge'] ?? record['flowRate']);
    final ts  = _s(record['timestamp'] ?? record['updated_at'] ?? record['last_updated']
                   ?? record['lastUpdated']);
    final rawTrend = _s(record['trend'] ?? record['level_trend'] ?? record['water_trend']);
    final trend    = rawTrend.isNotEmpty ? rawTrend.toUpperCase() : _deriveTrend(lv, wlR, dlR);

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
      city: city, state: state, river: river, station: stationName,
      current: lv, warning: wlR, danger: dlR, hfl: hlR,
      rainfallLastHour: rf > 0 ? rf : null, flowRate: fl > 0 ? fl : null,
      trend: trend.isNotEmpty ? trend : null,
      liveStatus: _s(record['status'] ?? record['alert_status'] ?? record['flood_status'])
          .let((v) => v.isNotEmpty ? v.toUpperCase() : null),
      lastUpdated: ts.isNotEmpty ? ts : null,
      dataSource: source, isLive: true,
    );

    String? mlRisk;
    double? mlProb;
    try {
      final pred = await _api.predict({
        'city': city, 'state': state,
        'river_level': lv, 'warning_level': wlR, 'danger_level': dlR,
        'rainfall': rf, 'flow_rate': fl, 'trend': trend,
      }).timeout(_predTimeout);
      final rawRisk = _s(pred['risk_level'] ?? pred['riskLevel'] ?? pred['flood_risk']);
      mlRisk = rawRisk.isNotEmpty ? rawRisk.toUpperCase() : null;
      mlProb = _fp(pred['flood_probability'] ?? pred['probability'] ?? pred['risk_score']);
      if ((mlProb ?? 0) > 1.0) mlProb = (mlProb ?? 0) / 100.0;
      if ((mlProb ?? 0) == 0)  mlProb = null;
    } catch (_) {}

    return LiveRiverResult(
      station: station, source: source, confidence: confidence,
      mlRiskLevel: mlRisk, mlFloodProb: mlProb,
      isStale: stale, rawTimestamp: ts.isNotEmpty ? ts : null,
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // MATCHING ENGINE
  // ══════════════════════════════════════════════════════════════════════════
  _MatchResult? _bestMatch(List<dynamic> list, String city, String state, String river) {
    _MatchResult? best;
    final lc = city.toLowerCase().trim();
    final ls = state.toLowerCase().trim();
    final lr = river.toLowerCase().trim();

    for (final item in list.whereType<Map<String, dynamic>>()) {
      final sc  = _s(item['station'] ?? item['stationName'] ?? item['station_name']
                  ?? item['city']   ?? item['location']    ?? item['name']
                  ?? item['site_name'] ?? item['gaugeStation'] ?? item['gauge_station']);
      final ist = _s(item['state_name'] ?? item['state'] ?? item['stateName'] ?? item['State'] ?? '');
      final rv  = _s(item['river_name'] ?? item['river'] ?? item['riverName']
                  ?? item['river_basin'] ?? item['basin'] ?? item['River'] ?? '');

      double conf = 0.0;
      if      (sc == lc || sc.replaceAll(' ', '') == lc.replaceAll(' ', ''))          conf = 1.00;
      else if (sc.contains(lc) || (lc.contains(sc) && sc.length > 3))                conf = 0.90;
      else if (_tok(sc, lc) && lr.isNotEmpty && rv.contains(lr) && ist.contains(ls)) conf = 0.85;
      else if (_tok(sc, lc))                                                          conf = 0.80;
      else if (lr.isNotEmpty && rv.contains(lr) && ist.isNotEmpty && ist.contains(ls)) conf = 0.70;
      else if (lr.isNotEmpty && rv.contains(lr))                                      conf = 0.60;
      else if (ls.isNotEmpty && ist.contains(ls) && lr.isNotEmpty && _rvTok(rv, lr)) conf = 0.45;
      else if (ls.isNotEmpty && ist.contains(ls))                                     conf = 0.38;

      if (conf > (best?.confidence ?? 0)) best = _MatchResult(record: item, confidence: conf);
      if (conf >= 1.0) break;
    }
    return best;
  }

  bool _tok(String source, String target) {
    for (final t in source.split(RegExp(r'[\s_\-,()]+'))) {
      if (t.length >= 4 && target.contains(t)) return true;
    }
    return false;
  }

  bool _rvTok(String rv, String lr) {
    return lr.split(RegExp(r'[\s_\-]+')).any((t) => t.length >= 4 && rv.contains(t));
  }

  // ── Level extractor ──────────────────────────────────────────────────────
  double _extractLevel(Map<String, dynamic> d) => _fp(
    d['river_level']     ?? d['riverLevel']      ?? d['current_level']  ??
    d['water_level']     ?? d['gauge_reading']    ?? d['currentLevel']   ??
    d['level']           ?? d['gauge_level']      ?? d['water_stage']    ??
    d['stage']           ?? d['obs_level']        ?? d['observed_level'] ??
    d['gauge']           ?? d['rl']               ?? d['wl']             ??
    d['current']         ?? d['present_level']    ?? d['today_level']    ??
    d['live_level']      ?? d['liveLevel']         ?? d['gauge_value']   ??
    d['water_elevation'] ?? d['elevation']         ?? d['obsLevel']      ??
    d['currentObs']      ?? d['river_stage']       ?? d['gaugeReading'],
  );

  String _deriveTrend(double lv, double wl, double dl) {
    if (wl <= 0) return 'STEADY';
    final ratio = lv / wl;
    if (ratio >= 1.0) return 'RISING';
    if (ratio < 0.75) return 'FALLING';
    return 'STEADY';
  }

  // ── Deep list ──────────────────────────────────────────────────────────────
  List<dynamic> _deepList(dynamic payload, {int depth = 0}) {
    if (depth > 8) return [];
    if (payload is List) return payload.where((e) => e != null).toList();
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
          payload.containsKey('current_level')) return [payload];
    }
    return [];
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  String _stateKey(String state) => state.toLowerCase().replaceAll(' ', '_');
  static double _fp(dynamic v) =>
      v == null ? 0.0 : (double.tryParse(v.toString().trim()) ?? 0.0);
  static String _s(dynamic v) => (v?.toString() ?? '').trim().toLowerCase();
  static String _cap(String s) => s.isEmpty ? s
      : s.split(' ').map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1).toLowerCase()).join(' ');
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
