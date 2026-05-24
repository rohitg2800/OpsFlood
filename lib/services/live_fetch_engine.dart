// lib/services/live_fetch_engine.dart
//
// OpsFlood — LiveFetchEngine (v14 — correct backend field extraction)
//
// DATA PIPELINE ANALYSIS (from OpsFlood backend/routers/live_levels.py):
//
//   GET /api/live-levels?state=Bihar
//   └─ Response envelope:
//       { "status": "success", "data_source": "GLOFAS+MATRIX",
//         "total": N, "data": [ ...stations... ] }
//
//   Each station in data[]:
//       city, state, river_name, station
//       current_level (m),  safe_level (m), warning_level (m), danger_level (m)
//       river_discharge (m³/s) — raw GloFAS value
//       capacity_percent (0-100)
//       risk_level ("LOW"|"MODERATE"|"HIGH"|"CRITICAL")
//       status ("RISING"|"STABLE"), alert (emoji)
//       flow_rate (m³/s, same as river_discharge)
//       lat, lon, data_source, timestamp
//
//   NOTE: The backend does NOT filter by city — only by state.
//         Client must match city from the returned data[] array.
//
//   PRIORITY:
//     1. GloFAS in-memory cache (real river discharge → current_level in metres)
//     2. STATE_SEVERITY_MATRIX (fallback for uncovered states)
//
// KEY FIXES IN v14 vs v13:
//   1. URL uses ?state= only (backend ignores ?city=).
//   2. _matchCity() scans data[] for the closest city name match.
//   3. Extracts ALL rich fields: current_level, danger_level, warning_level,
//      safe_level, risk_level, flow_rate (river_discharge), capacity_percent.
//   4. Backend risk_level is passed up and used directly in _snapToFloodData
//      (overrides the locally-inferred risk when backend has GloFAS data).
//   5. Backend flow_rate is passed to FloodData.flowRate so the map shows
//      actual river discharge instead of 0.
library;

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../data/india_cities.dart';
import '../models/flood_data.dart';
import '../models/river_monitoring.dart';
import 'cwc_direct_service.dart';

// ── MlInferenceEngine stub ───────────────────────────────────────────────────
class MlInferenceEngine {}

// ── LiveFetchEngine ──────────────────────────────────────────────────────────
class LiveFetchEngine {
  static final LiveFetchEngine _instance = LiveFetchEngine._internal();
  factory LiveFetchEngine() => _instance;
  LiveFetchEngine._internal();

  final http.Client      _client    = http.Client();
  final CwcDirectService _cwcDirect = CwcDirectService.instance;
  Timer? _timer;
  bool   _lock = false;

  bool _backendAwake = false;

  static bool get _runningOnWeb => kIsWeb;

  VoidCallback? onStateChanged;

  // ── Status flags ─────────────────────────────────────────────────────────────
  bool      isLoading           = false;
  bool      isOnline            = false;
  bool      isUsingFallback     = false;
  bool      isWakingUp          = false;
  bool      isUsingCache        = false;
  DateTime? lastFetchTime;
  String?   error;
  int       queuedOfflineCycles = 0;
  String?   fetchingCity;        // shown in loading UI

  // ── Data ─────────────────────────────────────────────────────────────────────
  List<FloodData>    liveLevels           = [];
  List<dynamic>      activeCriticalAlerts = [];
  List<dynamic>      criticalAlerts       = [];
  int                criticalCount        = 0;
  List<dynamic>      cwcStations          = [];
  bool               hasCwcLiveData       = false;
  List<dynamic>      imdAlerts            = [];
  List<dynamic>      ndmaAdvisories       = [];
  List<dynamic>      emergencyContacts    = [];

  MultiLocationMonitoring monitoringData = MultiLocationMonitoring(
    locations: [], fetchedAt: DateTime.now(),
  );

  Map<String, dynamic> debugLevelsRaw    = {};
  Map<String, dynamic> debugCwcRaw       = {};
  int                  debugRetryCount   = 0;
  int                  debugWakeAttempts = 0;

  final Map<String, List<RiverLevelSnapshot>> _trendCache = {};
  final Map<String, FloodData>                _dataCache  = {};

  // ── Public helpers ────────────────────────────────────────────────────────────

  List<RiverLevelSnapshot> trendForCity(String city) =>
      _trendCache[city.toLowerCase()] ?? [];

  FloodData? dataForCity(String city) {
    final lc = city.toLowerCase();
    return _dataCache[lc] ??
        liveLevels.where((e) => e.city.toLowerCase() == lc).firstOrNull;
  }

  List<dynamic> imdAlertsForState(String state) =>
      imdAlerts.where((e) {
        final s = (e is Map ? e['state'] : null)?.toString() ?? '';
        return s.toLowerCase() == state.toLowerCase();
      }).toList();

  List<dynamic> ndmaAdvisoriesForState(String state) =>
      ndmaAdvisories.where((e) {
        final s = (e is Map ? e['state'] : null)?.toString() ?? '';
        return s.toLowerCase() == state.toLowerCase();
      }).toList();

  List<dynamic> emergencyContactsForState(String state) =>
      emergencyContacts.where((e) {
        final s = (e is Map ? e['state'] : null)?.toString() ?? '';
        return s.toLowerCase() == state.toLowerCase() || s == 'All India';
      }).toList();

  // ── Polling ───────────────────────────────────────────────────────────────────

  Future<void> startPolling() async {
    _timer?.cancel();
    await refreshData();
    _timer = Timer.periodic(AppConfig.realtimeInterval, (_) => refreshData());
  }

  void stopPolling() {
    _timer?.cancel();
    _timer = null;
  }

  // ── Backend wake ──────────────────────────────────────────────────────────────

  Future<bool> _wakeBackend() async {
    if (_runningOnWeb || _backendAwake) return _backendAwake;
    try {
      debugWakeAttempts++;
      if (kDebugMode) debugPrint('[LiveFetch] waking backend…');
      final res = await _client
          .get(Uri.parse('${AppConfig.baseUrl}${AppConfig.epHealth}'))
          .timeout(AppConfig.coldStartTimeout);
      _backendAwake = res.statusCode < 500;
      if (kDebugMode) debugPrint('[LiveFetch] backend awake (${res.statusCode})');
    } catch (e) {
      _backendAwake = false;
      if (kDebugMode) debugPrint('[LiveFetch] backend wake failed: $e');
    }
    return _backendAwake;
  }

  // ── Main refresh (v13+: sequential per-city) ─────────────────────────────────

  Future<void> refreshData() async {
    if (_lock) return;
    _lock     = true;
    isLoading = true;
    if (!isOnline) isWakingUp = true;
    Future.delayed(Duration.zero, () => onStateChanged?.call());

    try {
      await _wakeBackend();
      isWakingUp = false;

      final cities       = _priorityCities();
      final newLevels    = <FloodData>[];
      final newLocations = <RiverMonitoring>[];
      final newAlerts    = <Map<String, dynamic>>[];
      final newCwc       = <Map<String, dynamic>>[];
      int   healthy      = 0;

      for (final city in cities) {
        fetchingCity = city.name;
        Future.delayed(Duration.zero, () => onStateChanged?.call());

        final snap = await _fetchCity(city);
        if (snap == null) continue;
        healthy++;

        final fd = _snapToFloodData(city, snap);
        newLevels.add(fd);
        _dataCache[city.name.toLowerCase()] = fd;

        final trend = _buildTrend(snap['discharge7d']);
        _trendCache[city.name.toLowerCase()] = trend;
        newLocations.add(RiverMonitoring.fromFloodData(fd, trend));

        if (snap['riskLabel'] == 'CRITICAL' || snap['riskLabel'] == 'HIGH') {
          newAlerts.add({
            'city':     city.name,
            'state':    city.state,
            'severity': snap['riskLabel'],
            'title':    '${snap['riskLabel']} Flood Risk — ${city.name}',
            'source':   (snap['healthySources'] as int? ?? 0) > 2 ? 'Live' : 'Partial',
          });
        }

        if (snap['cwcLevel'] != null) {
          newCwc.add({
            'city':         city.name,
            'state':        city.state,
            'river':        city.river,
            'currentLevel': snap['cwcLevel'],
            'dangerLevel':  snap['dangerLevel'],
            'warningLevel': snap['warningLevel'],
            'source':       snap['cwcSource'] ?? 'CWC',
          });
        }

        final imdList = snap['imdAlerts'];
        if (imdList is List && imdList.isNotEmpty) imdAlerts = imdList;

        // Publish partial results so UI fills in live after each city.
        liveLevels           = List.of(newLevels);
        criticalAlerts       = List.of(newAlerts);
        activeCriticalAlerts = newAlerts.where((a) => a['severity'] == 'CRITICAL').toList();
        criticalCount        = activeCriticalAlerts.length;
        cwcStations          = List.of(newCwc);
        hasCwcLiveData       = newCwc.isNotEmpty;
        isOnline             = true;
        error                = null;
        lastFetchTime        = DateTime.now();
        monitoringData = MultiLocationMonitoring(
          locations: List.of(newLocations),
          fetchedAt: lastFetchTime!,
          fromCache: false,
        );
        Future.delayed(Duration.zero, () => onStateChanged?.call());

        if (kDebugMode) {
          debugPrint('[LiveFetch] ✓ ${city.name} | src=${snap['healthySources']} '
              '| risk=${snap['riskLabel']} | level=${snap['cwcLevel']} '
              '| flow=${snap['flowRate']} m³/s | bkSrc=${snap['backendSource']}');
        }
      }

      fetchingCity    = null;
      isUsingFallback = healthy < (cities.length ~/ 2);
      isUsingCache    = false;

      debugLevelsRaw = {'cities': newLevels.length, 'healthy': healthy};
      debugCwcRaw    = {'stations': newCwc.length};

      if (healthy == 0) {
        isOnline = false;
        error    = 'All city fetches failed';
      }

      if (kDebugMode) {
        debugPrint('[LiveFetch] ✓ done | $healthy/${cities.length} healthy | '
            '${criticalCount} critical | cwcLive=${newCwc.length}');
      }
    } catch (e, st) {
      isOnline     = false;
      isWakingUp   = false;
      fetchingCity = null;
      error        = e.toString();
      debugRetryCount++;
      if (kDebugMode) debugPrint('[LiveFetch] error: $e\n$st');
    } finally {
      isLoading    = false;
      fetchingCity = null;
      _lock        = false;
      Future.delayed(Duration.zero, () => onStateChanged?.call());
    }
  }

  // ── Per-city fetch ─────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>?> _fetchCity(IndiaCity city) async {
    try {
      final weatherFut   = _fetchWeather(city);
      final glofasFut    = _fetchGloFas(city);
      final cwcDirectFut = _cwcDirect.fetch(city);
      final backendFut   = _runningOnWeb ? Future.value(null) : _fetchBackendLevels(city);
      final imdFut       = _runningOnWeb ? Future.value(null) : _fetchImdAlerts(city);

      final results = await Future.wait([
        weatherFut, glofasFut, cwcDirectFut, backendFut, imdFut,
      ], eagerError: false);

      final weather   = results[0] as Map<String, dynamic>?;
      final glofas    = results[1] as Map<String, dynamic>?;
      final cwcDirect = results[2] as CwcReading?;
      final backend   = results[3] as Map<String, dynamic>?;
      final imd       = results[4] as List<dynamic>?;

      if (weather == null && glofas == null && backend == null) return null;

      final healthySources = [
        weather != null, glofas != null,
        cwcDirect != null, backend != null, imd != null,
      ].where((v) => v).length;

      final precipMm    = (weather?['precip_mm']  as num?)?.toDouble() ?? 0.0;
      final discharge7d = (glofas?['discharge7d'] as List?)?.cast<double>() ?? <double>[];

      // v14: prefer backend discharge (GloFAS-sourced, state-matched) over
      // direct GloFAS coordinate fetch when available.
      final backendFlow  = (backend?['flow_rate'] as num?)?.toDouble() ?? 0.0;
      final glofasFlow   = (glofas?['discharge']  as num?)?.toDouble() ?? 0.0;
      final dischargeM3s = backendFlow > 0 ? backendFlow : glofasFlow;

      // v14: backend is PRIMARY river-level source on mobile.
      //   current_level, danger_level, warning_level, safe_level are all in metres.
      //   risk_level is already computed by backend (CRITICAL/HIGH/MODERATE/LOW).
      //   CwcDirect overrides level/thresholds if it has a fresher reading.
      double? cwcLevel    = _safeLevel(backend?['current_level']);
      double? dangerLevel = _safeLevel(backend?['danger_level']);
      double? warnLevel   = _safeLevel(backend?['warning_level']);
      double? safeLevel   = _safeLevel(backend?['safe_level']);
      String? backendRisk = (backend?['risk_level'] as String?)?.toUpperCase();
      String? backendSrc  = backend?['data_source'] as String?; // OPEN_METEO_GLOFAS or STATE_SEVERITY_MATRIX
      String? cwcSource   = backend != null ? (backendSrc ?? 'BACKEND') : null;

      if (cwcDirect != null) {
        cwcLevel    = cwcDirect.level    ?? cwcLevel;
        dangerLevel = cwcDirect.danger   ?? dangerLevel;
        warnLevel   = cwcDirect.warning  ?? warnLevel;
        cwcSource   = cwcDirect.source;
        backendRisk = null; // CwcDirect is fresher — re-infer risk below
      }

      dangerLevel ??= city.dangerLevel  > 0 ? city.dangerLevel  : null;
      warnLevel   ??= city.warningLevel > 0 ? city.warningLevel : null;

      // Use backend risk directly when it came from GloFAS (most accurate).
      // Re-infer only when CwcDirect overrode the levels, or backend used matrix.
      final String riskLabel;
      if (backendRisk != null && backendSrc == 'OPEN_METEO_GLOFAS') {
        riskLabel = backendRisk;
      } else {
        riskLabel = _inferRisk(
          precipMm:     precipMm,
          dischargeM3s: dischargeM3s,
          discharge7d:  discharge7d,
          currentLevel: cwcLevel,
          dangerLevel:  dangerLevel,
        );
      }

      return {
        'precip_mm':      precipMm,
        'discharge':      dischargeM3s,
        'discharge7d':    discharge7d,
        'flowRate':       dischargeM3s,  // m³/s — passed to FloodData.flowRate
        'cwcLevel':       cwcLevel,
        'dangerLevel':    dangerLevel,
        'warningLevel':   warnLevel,
        'safeLevel':      safeLevel,
        'cwcSource':      cwcSource,
        'backendSource':  backendSrc,
        'riskLabel':      riskLabel,
        'healthySources': healthySources,
        'imdAlerts':      imd ?? <dynamic>[],
      };
    } catch (_) {
      return null;
    }
  }

  // ── Source 1: Open-Meteo Weather ─────────────────────────────────────────────

  Future<Map<String, dynamic>?> _fetchWeather(IndiaCity city) async {
    try {
      final uri = Uri.parse(
        'https://api.open-meteo.com/v1/forecast'
        '?latitude=${city.lat}&longitude=${city.lon}'
        '&hourly=precipitation,temperature_2m,relative_humidity_2m'
        '&forecast_days=2&timezone=Asia%2FKolkata',
      );
      final res = await _client.get(uri).timeout(const Duration(seconds: 12));
      if (res.statusCode != 200) return null;
      final j      = jsonDecode(res.body) as Map<String, dynamic>;
      final hourly = j['hourly'] as Map<String, dynamic>;
      final precip = _doubles(hourly['precipitation']);
      final last24 = precip.length >= 24 ? precip.sublist(precip.length - 24) : precip;
      return {
        'precip_mm': last24.fold(0.0, (a, b) => a + b),
        'temp_c':    _doubles(hourly['temperature_2m']).lastOrNull ?? 25.0,
        'humidity':  _doubles(hourly['relative_humidity_2m']).lastOrNull ?? 60.0,
      };
    } catch (e) {
      if (kDebugMode) debugPrint('[LiveFetch] weather ${city.name}: $e');
      return null;
    }
  }

  // ── Source 2: Open-Meteo GloFAS ──────────────────────────────────────────────

  Future<Map<String, dynamic>?> _fetchGloFas(IndiaCity city) async {
    try {
      final uri = Uri.parse(
        'https://flood-api.open-meteo.com/v1/flood'
        '?latitude=${city.lat}&longitude=${city.lon}'
        '&daily=river_discharge&past_days=7&forecast_days=1',
      );
      final res = await _client.get(uri).timeout(const Duration(seconds: 12));
      if (res.statusCode != 200) return null;
      final j    = jsonDecode(res.body) as Map<String, dynamic>;
      final vals = _doubles((j['daily'] as Map?)?['river_discharge']);
      if (vals.isEmpty) return null;
      return {'discharge': vals.last, 'discharge7d': vals};
    } catch (e) {
      if (kDebugMode) debugPrint('[LiveFetch] GloFAS ${city.name}: $e');
      return null;
    }
  }

  // ── Source 4 (PRIMARY on mobile): OpsFlood /api/live-levels ─────────────────
  //
  // v14 analysis of backend/routers/live_levels.py:
  //
  //   • Route: GET /api/live-levels?state=<state>
  //   • Filter: ?city= is IGNORED by the backend — only ?state= is supported.
  //   • Response: { status, data_source, total, data: [ ...stations... ] }
  //   • Each station: city, state, river_name, current_level, safe_level,
  //       warning_level, danger_level, river_discharge, capacity_percent,
  //       risk_level, status, alert, flow_rate, lat, lon, data_source, timestamp
  //
  //   • _matchCity() scans data[] for the entry whose 'city' fuzzy-matches
  //     the requested city name (exact → prefix → first result fallback).

  Future<Map<String, dynamic>?> _fetchBackendLevels(IndiaCity city) async {
    try {
      final uri = Uri.parse(
        '${AppConfig.baseUrl}${AppConfig.epLiveLevels}'
        '?state=${Uri.encodeComponent(city.state)}',
      );
      final res = await _client.get(uri).timeout(AppConfig.requestTimeout);
      if (res.statusCode != 200) {
        if (kDebugMode) debugPrint('[LiveFetch] backend ${city.name}: HTTP ${res.statusCode}');
        return null;
      }

      final j    = jsonDecode(res.body) as Map<String, dynamic>;
      final raw  = j['data'];
      if (raw is! List || raw.isEmpty) return null;

      // Find the station matching this city from the list.
      final station = _matchCity(raw.cast<Map<String, dynamic>>(), city.name);
      if (station == null) return null;

      if (kDebugMode) {
        debugPrint('[LiveFetch] backend ✓ ${city.name}: '
            'level=${station['current_level']} danger=${station['danger_level']} '
            'risk=${station['risk_level']} src=${station['data_source']}');
      }

      return {
        'current_level':    _num(station['current_level']),
        'safe_level':       _num(station['safe_level']),
        'warning_level':    _num(station['warning_level']),
        'danger_level':     _num(station['danger_level']),
        'flow_rate':        _num(station['flow_rate'] ?? station['river_discharge']),
        'risk_level':       station['risk_level'] as String?,
        'capacity_percent': _num(station['capacity_percent']),
        'data_source':      station['data_source'] as String?,
      };
    } catch (e) {
      if (kDebugMode) debugPrint('[LiveFetch] backend ${city.name}: $e');
      return null;
    }
  }

  // Match a city name from the backend data[] list.
  // Priority: exact match → starts-with → contains → first item in list.
  Map<String, dynamic>? _matchCity(
    List<Map<String, dynamic>> stations, String cityName,
  ) {
    if (stations.isEmpty) return null;
    final needle = cityName.trim().toLowerCase();

    // 1. Exact match
    for (final s in stations) {
      if ((s['city'] as String? ?? '').toLowerCase() == needle) return s;
    }
    // 2. Starts-with
    for (final s in stations) {
      if ((s['city'] as String? ?? '').toLowerCase().startsWith(needle)) return s;
    }
    // 3. Contains
    for (final s in stations) {
      if ((s['city'] as String? ?? '').toLowerCase().contains(needle)) return s;
    }
    // 4. Fallback: highest capacity station for this state
    return stations.first;
  }

  // ── Source 5: SACHET NDMA IMD (mobile/desktop only) ──────────────────────────

  List<dynamic> _imdCache     = [];
  DateTime?     _imdCacheTime;

  Future<List<dynamic>?> _fetchImdAlerts(IndiaCity city) async {
    final now = DateTime.now();
    if (_imdCacheTime != null &&
        now.difference(_imdCacheTime!) < const Duration(minutes: 10) &&
        _imdCache.isNotEmpty) {
      return _filterImd(city.state);
    }
    try {
      final res = await _client
          .get(Uri.parse(
            'https://sachet.ndma.gov.in/cap_public_website/FetchAllAlertDetails',
          ))
          .timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return null;
      final raw = jsonDecode(res.body);
      List<dynamic> items = [];
      if (raw is List) {
        items = raw;
      } else if (raw is Map) {
        for (final k in ['features', 'alerts', 'data', 'items', 'results']) {
          if (raw[k] is List) { items = raw[k] as List; break; }
        }
      }
      _imdCache     = items;
      _imdCacheTime = now;
      return _filterImd(city.state);
    } catch (e) {
      if (kDebugMode) debugPrint('[LiveFetch] IMD: $e');
      return null;
    }
  }

  List<dynamic> _filterImd(String state) {
    final u = state.toUpperCase();
    return _imdCache.where((item) {
      if (item is! Map) return false;
      final desc = [
        item['info']?['area']?['areaDesc'],
        item['info']?['headline'],
        item['areaDesc'],
      ].whereType<String>().join(' ').toUpperCase();
      return desc.contains(u) || desc.contains('INDIA');
    }).toList();
  }

  // ── Risk inference (used when backend data is matrix-only or CwcDirect overrides) ───

  String _inferRisk({
    required double precipMm,
    required double dischargeM3s,
    required List<double> discharge7d,
    double? currentLevel,
    double? dangerLevel,
  }) {
    double score = 0.0;
    if (precipMm > 150)       score += 0.35;
    else if (precipMm > 80)   score += 0.25;
    else if (precipMm > 40)   score += 0.15;
    else if (precipMm > 15)   score += 0.07;

    if (dischargeM3s > 8000)      score += 0.35;
    else if (dischargeM3s > 4000) score += 0.25;
    else if (dischargeM3s > 1500) score += 0.15;
    else if (dischargeM3s > 500)  score += 0.07;

    if (currentLevel != null && dangerLevel != null && dangerLevel > 0) {
      final r = currentLevel / dangerLevel;
      if (r >= 1.0)       score += 0.30;
      else if (r >= 0.85) score += 0.20;
      else if (r >= 0.70) score += 0.10;
    }

    if (discharge7d.length >= 2 && discharge7d.last > discharge7d.first * 1.3) score += 0.05;

    if (score >= 0.75) return 'CRITICAL';
    if (score >= 0.50) return 'HIGH';
    if (score >= 0.30) return 'MODERATE';
    return 'LOW';
  }

  // ── FloodData builder ─────────────────────────────────────────────────────────

  FloodData _snapToFloodData(IndiaCity city, Map<String, dynamic> snap) {
    final danger  = (snap['dangerLevel']  as num?)?.toDouble() ?? city.dangerLevel;
    final warning = (snap['warningLevel'] as num?)?.toDouble() ?? city.warningLevel;
    // v14: prefer safe_level from backend; fall back to warning-2m.
    final safe    = (snap['safeLevel']    as num?)?.toDouble()
                 ?? (warning - 2.0).clamp(0.0, double.infinity);
    final current = (snap['cwcLevel']     as double?) ?? 0.0;
    final flow    = (snap['flowRate']     as num?)?.toDouble();

    final risk   = snap['riskLabel'] as String? ?? 'LOW';
    final precip = (snap['precip_mm'] as num?)?.toDouble() ?? 0.0;
    final imdSev = precip >= 115 ? 'RED'
        : precip >= 64  ? 'ORANGE'
        : precip >= 15  ? 'YELLOW'
        : 'GREEN';

    return FloodData(
      id:            '${city.id}-live',
      city:          city.name,
      state:         city.state,
      latitude:      city.lat,
      longitude:     city.lon,
      currentLevel:  current,
      dangerLevel:   danger,
      warningLevel:  warning,
      safeLevel:     safe,
      riskLevel:     risk,
      lastUpdated:   DateTime.now(),
      riverName:     city.river,
      flowRate:      flow,         // v14: real river discharge in m³/s from backend
      rainfall24h:   precip,
      status:        (snap['healthySources'] as int? ?? 0) >= 2 ? 'Live' : 'Partial',
      imdRainfallMm: precip,
      imdSeverity:   imdSev,
    );
  }

  // ── Trend builder ─────────────────────────────────────────────────────────────

  List<RiverLevelSnapshot> _buildTrend(dynamic discharge7d) {
    final vals = (discharge7d is List) ? discharge7d.cast<double>() : <double>[];
    if (vals.isEmpty) return [];
    final now = DateTime.now();
    return List.generate(vals.length, (i) => RiverLevelSnapshot(
      timestamp: now.subtract(Duration(days: vals.length - 1 - i)),
      level:     0,
      flowRate:  vals[i],
      status:    'historical',
    ));
  }

  // ── Priority city list ────────────────────────────────────────────────────────

  List<IndiaCity> _priorityCities() {
    const ids = [
      'guwahati', 'patna', 'cuttack', 'kolkata', 'varanasi',
      'gorakhpur', 'dhubri', 'supaul', 'jalpaiguri', 'haridwar',
    ];
    return ids.map(cityById).whereType<IndiaCity>().toList();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────────

  double? _safeLevel(dynamic v) {
    if (v == null) return null;
    final d = double.tryParse(v.toString().trim()) ?? (v is num ? v.toDouble() : null);
    if (d == null) return null;
    return (d >= 0.5 && d <= 250.0) ? d : null;
  }

  List<double> _doubles(dynamic raw) {
    if (raw is! List) return [];
    return raw.map((e) => e == null ? 0.0 : (e as num).toDouble()).toList();
  }

  double? _num(dynamic v) => v == null ? null : (v as num).toDouble();
}
