// lib/services/live_fetch_engine.dart
//
// OpsFlood — LiveFetchEngine
//
// Data sources by platform:
//
//   ALL PLATFORMS:
//     Source 1: Open-Meteo Weather API         (CORS-safe, free)
//     Source 2: Open-Meteo GloFAS River API    (CORS-safe, free)
//
//   MOBILE / DESKTOP only (no CORS restriction):
//     Source 3: OpsFlood backend /api/cwc-ffs  (Render, needs CORS headers)
//     Source 4: OpsFlood backend /api/live-levels
//     Source 5: SACHET NDMA IMD alerts
//
// On Chrome web, Sources 3-5 are skipped (browser blocks them).
// The app still shows real river discharge + weather data on web.
library;

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../data/india_cities.dart';
import '../models/flood_data.dart';
import '../models/river_monitoring.dart';

// ── MlInferenceEngine stub (imported by real_time_service.dart) ────────────
class MlInferenceEngine {
  // All inference is inside LiveFetchEngine._inferRisk()
}

// ── LiveFetchEngine ─────────────────────────────────────────────────────
class LiveFetchEngine {
  static final LiveFetchEngine _instance = LiveFetchEngine._internal();
  factory LiveFetchEngine() => _instance;
  LiveFetchEngine._internal();

  final http.Client _client = http.Client();
  Timer? _timer;
  bool _lock = false;

  // True when running on Chrome/web — evaluated once, not const
  static final bool _isWeb = identical(0, 0.0); // always false on VM/mobile
  // Correct cross-platform web detection:
  static bool get _runningOnWeb => kIsWeb;

  VoidCallback? onStateChanged;

  // ── Status flags ────────────────────────────────────────────────────────
  bool      isLoading          = false;
  bool      isOnline           = false;
  bool      isUsingFallback    = false;
  bool      isWakingUp         = false;
  bool      isUsingCache       = false;
  DateTime? lastFetchTime;
  String?   error;
  int       queuedOfflineCycles = 0;

  // ── Data ────────────────────────────────────────────────────────────────────
  List<FloodData>    liveLevels          = [];
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

  // ── Debug ────────────────────────────────────────────────────────────────────
  Map<String, dynamic> debugLevelsRaw   = {};
  Map<String, dynamic> debugCwcRaw      = {};
  int                  debugRetryCount  = 0;
  int                  debugWakeAttempts = 0;

  // ── Per-city caches ──────────────────────────────────────────────────────────
  final Map<String, List<RiverLevelSnapshot>> _trendCache = {};
  final Map<String, FloodData>                _dataCache  = {};

  // ── Public helpers ──────────────────────────────────────────────────────────

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

  // ── Polling ─────────────────────────────────────────────────────────────────

  Future<void> startPolling() async {
    _timer?.cancel();
    await refreshData();
    _timer = Timer.periodic(AppConfig.realtimeInterval, (_) => refreshData());
  }

  void stopPolling() {
    _timer?.cancel();
    _timer = null;
  }

  // ── Main refresh ─────────────────────────────────────────────────────────────

  Future<void> refreshData() async {
    if (_lock) return;
    _lock     = true;
    isLoading = true;
    if (!isOnline) { isWakingUp = true; debugWakeAttempts++; }
    Future.delayed(Duration.zero, () => onStateChanged?.call());

    try {
      final cities = _priorityCities();
      final snapshots = await Future.wait(
        cities.map((c) => _fetchCity(c)),
        eagerError: false,
      );

      final newLevels    = <FloodData>[];
      final newLocations = <RiverMonitoring>[];
      final newAlerts    = <Map<String, dynamic>>[];
      final newCwc       = <Map<String, dynamic>>[];
      int   healthy      = 0;

      for (var i = 0; i < cities.length; i++) {
        final city = cities[i];
        final snap = snapshots[i];
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
            'title':    '${snap["riskLabel"]} Flood Risk — ${city.name}',
            'source':   (snap['healthySources'] as int? ?? 0) > 2 ? 'Live' : 'Partial',
          });
        }

        if (snap['cwcLevel'] != null) {
          newCwc.add({
            'city':          city.name,
            'state':         city.state,
            'river':         city.river,
            'currentLevel':  snap['cwcLevel'],
            'dangerLevel':   snap['dangerLevel'],
            'warningLevel':  snap['warningLevel'],
            'source':        'CWC',
          });
        }

        final imdList = snap['imdAlerts'];
        if (imdList is List && imdList.isNotEmpty) {
          imdAlerts = imdList;
        }
      }

      liveLevels           = newLevels;
      criticalAlerts       = newAlerts;
      activeCriticalAlerts = newAlerts.where((a) => a['severity'] == 'CRITICAL').toList();
      criticalCount        = activeCriticalAlerts.length;
      cwcStations          = newCwc;
      hasCwcLiveData       = newCwc.isNotEmpty;
      isUsingFallback      = healthy < (cities.length ~/ 2);
      isOnline             = healthy > 0;
      isUsingCache         = false;
      isWakingUp           = false;
      error                = null;
      lastFetchTime        = DateTime.now();

      monitoringData = MultiLocationMonitoring(
        locations: newLocations,
        fetchedAt: lastFetchTime!,
        fromCache: false,
      );

      debugLevelsRaw  = {'cities': newLevels.length, 'healthy': healthy};
      debugCwcRaw     = {'stations': newCwc.length};

      if (kDebugMode) {
        debugPrint('[LiveFetch] ✓ ${newLevels.length} cities | '
            '$healthy/${cities.length} healthy | '
            '${criticalCount} critical | web=$_runningOnWeb');
      }
    } catch (e, st) {
      isOnline    = false;
      isWakingUp  = false;
      error       = e.toString();
      debugRetryCount++;
      if (kDebugMode) debugPrint('[LiveFetch] error: $e\n$st');
    } finally {
      isLoading = false;
      _lock     = false;
      Future.delayed(Duration.zero, () => onStateChanged?.call());
    }
  }

  // ── Per-city fetch ───────────────────────────────────────────────────────────

  Future<Map<String, dynamic>?> _fetchCity(IndiaCity city) async {
    try {
      // Sources 1 & 2 work everywhere (Open-Meteo has CORS headers)
      final weatherFut = _fetchWeather(city);
      final glofasFut  = _fetchGloFas(city);

      // Sources 3, 4, 5 only on mobile/desktop — skipped on web due to CORS
      final cwcFut     = _runningOnWeb ? Future.value(null) : _fetchCwc(city);
      final backendFut = _runningOnWeb ? Future.value(null) : _fetchBackendLevels(city);
      final imdFut     = _runningOnWeb ? Future.value(null) : _fetchImdAlerts(city);

      final results = await Future.wait([
        weatherFut, glofasFut, cwcFut, backendFut, imdFut,
      ], eagerError: false);

      final weather = results[0] as Map<String, dynamic>?;
      final glofas  = results[1] as Map<String, dynamic>?;
      final cwc     = results[2] as Map<String, dynamic>?;
      final backend = results[3] as Map<String, dynamic>?;
      final imd     = results[4] as List<dynamic>?;

      // A city is healthy if Open-Meteo weather OR GloFAS responded
      if (weather == null && glofas == null) return null;

      final healthySources = [
        weather != null, glofas != null,
        cwc != null, backend != null, imd != null,
      ].where((v) => v).length;

      final precipMm     = (weather?['precip_mm']    as num?)?.toDouble() ?? 0.0;
      final dischargeM3s = (glofas?['discharge']     as num?)?.toDouble() ?? 0.0;
      final discharge7d  = (glofas?['discharge7d']   as List?)?.cast<double>() ?? <double>[];

      final cwcLevel    = (cwc?['level']   ?? backend?['level'])   as double?;
      final dangerLevel = (cwc?['danger']  ?? backend?['danger'])  as double?;
      final warnLevel   = (cwc?['warning'] ?? backend?['warning']) as double?;

      final riskLabel = _inferRisk(
        precipMm:     precipMm,
        dischargeM3s: dischargeM3s,
        discharge7d:  discharge7d,
        currentLevel: cwcLevel,
        dangerLevel:  dangerLevel,
      );

      return {
        'precip_mm':      precipMm,
        'discharge':      dischargeM3s,
        'discharge7d':    discharge7d,
        'cwcLevel':       cwcLevel,
        'dangerLevel':    dangerLevel ?? 10.0,
        'warningLevel':   warnLevel   ?? 8.0,
        'riskLabel':      riskLabel,
        'healthySources': healthySources,
        'imdAlerts':      imd ?? <dynamic>[],
      };
    } catch (_) {
      return null;
    }
  }

  // ── Source 1: Open-Meteo Weather (CORS-safe) ─────────────────────────────

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

  // ── Source 2: Open-Meteo GloFAS (CORS-safe) ─────────────────────────────

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

  // ── Source 3: OpsFlood CWC (mobile/desktop only) ────────────────────────

  Future<Map<String, dynamic>?> _fetchCwc(IndiaCity city) async {
    if (city.cwcStation == null) return null;
    try {
      final res = await _client
          .get(Uri.parse('${AppConfig.baseUrl}${AppConfig.epCwcFfs}/${city.cwcStation}'))
          .timeout(const Duration(seconds: 14));
      if (res.statusCode != 200) return null;
      final j = jsonDecode(res.body) as Map<String, dynamic>;
      final d = j['data'] ?? j;
      return {
        'level':   _num(d['current_level'] ?? d['level']),
        'danger':  _num(d['danger_level']  ?? d['danger']),
        'warning': _num(d['warning_level'] ?? d['warning']),
      };
    } catch (e) {
      if (kDebugMode) debugPrint('[LiveFetch] CWC ${city.name}: $e');
      return null;
    }
  }

  // ── Source 4: OpsFlood /api/live-levels (mobile/desktop only) ────────────

  Future<Map<String, dynamic>?> _fetchBackendLevels(IndiaCity city) async {
    try {
      final uri = Uri.parse(
        '${AppConfig.baseUrl}${AppConfig.epLiveLevels}'
        '?city=${Uri.encodeComponent(city.name)}&state=${Uri.encodeComponent(city.state)}',
      );
      final res = await _client.get(uri).timeout(const Duration(seconds: 14));
      if (res.statusCode != 200) return null;
      final j = jsonDecode(res.body) as Map<String, dynamic>;
      final d = _firstItem(j);
      if (d == null) return null;
      return {
        'level':   _num(d['current_level'] ?? d['level']),
        'danger':  _num(d['danger_level']  ?? d['danger']),
        'warning': _num(d['warning_level'] ?? d['warning']),
      };
    } catch (e) {
      if (kDebugMode) debugPrint('[LiveFetch] backend ${city.name}: $e');
      return null;
    }
  }

  // ── Source 5: SACHET NDMA IMD (mobile/desktop only) ─────────────────────

  List<dynamic> _imdCache        = [];
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

  // ── Rule-based risk inference ────────────────────────────────────────────────

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

  // ── FloodData builder ────────────────────────────────────────────────────────

  FloodData _snapToFloodData(IndiaCity city, Map<String, dynamic> snap) {
    final danger  = (snap['dangerLevel']  as num?)?.toDouble() ?? 10.0;
    final warning = (snap['warningLevel'] as num?)?.toDouble() ?? (danger * 0.75);
    final safe    = (warning - 2.0).clamp(0.0, double.infinity);
    final current = (snap['cwcLevel'] as double?) ??
        _dischargeToLevel((snap['discharge'] as num?)?.toDouble() ?? 0);

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
      flowRate:      (snap['discharge'] as num?)?.toDouble(),
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
      level:     _dischargeToLevel(vals[i]),
      flowRate:  vals[i],
      status:    'historical',
    ));
  }

  // ── Priority city list ─────────────────────────────────────────────────────────

  List<IndiaCity> _priorityCities() {
    const ids = [
      'guwahati', 'patna', 'cuttack', 'kolkata', 'varanasi',
      'gorakhpur', 'dhubri', 'supaul', 'jalpaiguri', 'haridwar',
    ];
    return ids.map(cityById).whereType<IndiaCity>().toList();
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  static double _dischargeToLevel(double m3s) => (m3s / 200.0).clamp(0.0, 20.0);

  List<double> _doubles(dynamic raw) {
    if (raw is! List) return [];
    return raw.map((e) => e == null ? 0.0 : (e as num).toDouble()).toList();
  }

  double? _num(dynamic v) => v == null ? null : (v as num).toDouble();

  Map<String, dynamic>? _firstItem(Map<String, dynamic> j) {
    for (final k in ['data', 'items', 'results', 'levels', 'records']) {
      final v = j[k];
      if (v is List && v.isNotEmpty) return v.first as Map<String, dynamic>?;
      if (v is Map<String, dynamic>) return v;
    }
    if (j.containsKey('current_level') || j.containsKey('level')) return j;
    return null;
  }
}
