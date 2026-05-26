// lib/services/live_fetch_engine.dart
//
// OpsFlood — LiveFetchEngine (v17.2 — OpsClient migration)
//
// CHANGES in v17.2:
//
//   1. Rogue http.Client REMOVED for OpsFlood backend calls:
//      - _wakeBackend()         → FloodApi.instance.healthCheck()
//      - _fetchBackendLevels()  → FloodApi.instance.levelsByState()
//      Auth headers, retry policy, and timeout caps from OpsClient now
//      apply to every per-city backend fetch (110 cities × 45s poll cycle).
//
//   2. _externalClient introduced for THIRD-PARTY APIs only:
//      - open-meteo.com  (weather)
//      - flood-api.open-meteo.com  (GloFAS)
//      - sachet.ndma.gov.in  (IMD alerts)
//      These are free public APIs — OpsClient auth/retry does NOT apply.
//
//   3. Cache TTL unified: hardcoded _kCacheTtl (20 min) replaced with
//      AppConfig.cacheTtl (5 min). Both caches now expire at the same rate.
//
// v17.1 fixes retained:
//   • _matchCity() returns null on no-match.
//   • Synthetic source guard (STATE_SEVERITY_MATRIX, FALLBACK, etc.).
//   • CWC HTML maintenance page guard.
//   • 429-backoff + 300 ms inter-city delay.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:math' show Random;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../data/india_cities.dart';
import '../models/flood_data.dart';
import '../models/river_monitoring.dart';
import 'cwc_direct_service.dart';
import 'flood_api.dart';

class MlInferenceEngine {}

class _CacheEntry<T> {
  final T data;
  final DateTime at;
  _CacheEntry(this.data) : at = DateTime.now();
  // TTL is now driven by AppConfig.cacheTtl (default 5 min)
  bool get valid => DateTime.now().difference(at) < AppConfig.cacheTtl;
}

final _weatherCache = <String, _CacheEntry<Map<String, dynamic>>>{};
final _glofasCache  = <String, _CacheEntry<Map<String, dynamic>>>{};

String _tileKey(double lat, double lon) =>
    '${lat.toStringAsFixed(2)}:${lon.toStringAsFixed(2)}';

// Sources that are synthetic/computed averages, NOT live gauge readings.
const _kSyntheticSources = {
  'STATE_SEVERITY_MATRIX',
  'FALLBACK',
  'ESTIMATED',
  'SYNTHETIC',
  'DEFAULT',
};

class LiveFetchEngine {
  static final LiveFetchEngine _instance = LiveFetchEngine._internal();
  factory LiveFetchEngine() => _instance;
  LiveFetchEngine._internal();

  // OpsFlood backend calls → FloodApi (routed through OpsClient)
  final _api = FloodApi.instance;

  // Third-party public APIs (open-meteo, GloFAS, NDMA) — no auth/retry
  final http.Client _externalClient = http.Client();

  final CwcDirectService _cwcDirect = CwcDirectService.instance;
  final Random           _rng       = Random();

  Map<String, dynamic>? _matchCity(List<Map<String, dynamic>> raw, String cityName) {
    final target = cityName.toLowerCase().trim();
    for (final station in raw) {
      final name = (station['station'] ?? station['stationName'] ?? station['city'] ?? station['name'] ?? '').toString().toLowerCase().trim();
      if (name.contains(target) || target.contains(name)) return station;
    }
    return null;
  }
  Timer? _timer;
  bool   _lock = false;

  bool _backendAwake = false;

  static bool get _runningOnWeb => kIsWeb;

  VoidCallback? onStateChanged;

  bool      isLoading           = false;
  bool      isOnline            = false;
  bool      isUsingFallback     = false;
  bool      isWakingUp          = false;
  bool      isUsingCache        = false;
  DateTime? lastFetchTime;
  String?   error;
  int       queuedOfflineCycles = 0;
  String?   fetchingCity;

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

  Future<void> startPolling() async {
    _timer?.cancel();
    await refreshData();
    _timer = Timer.periodic(AppConfig.realtimeInterval, (_) => refreshData());
  }

  void stopPolling() {
    _timer?.cancel();
    _timer = null;
  }

  // ── Backend wake using FloodApi (OpsClient) ────────────────────────────────
  Future<bool> _wakeBackend() async {
    if (_runningOnWeb || _backendAwake) return _backendAwake;
    try {
      debugWakeAttempts++;
      if (kDebugMode) debugPrint('[LiveFetch] waking backend…');
      final res = await _api.healthCheck(coldStart: true);
      _backendAwake = res['status'] != 'error';
      if (kDebugMode) debugPrint('[LiveFetch] backend awake: $_backendAwake');
    } catch (e) {
      _backendAwake = false;
      if (kDebugMode) debugPrint('[LiveFetch] backend wake failed: $e');
    }
    return _backendAwake;
  }

  // ── External-only 429 retry (open-meteo / GloFAS) ─────────────────────────
  Future<http.Response> _externalGet(
    Uri uri, {
    Duration timeout = const Duration(seconds: 12),
  }) async {
    var res = await _externalClient.get(uri).timeout(timeout);
    if (res.statusCode == 429) {
      final retryAfter = int.tryParse(
            res.headers['retry-after'] ?? '',
          ) ?? 60;
      final wait = Duration(seconds: retryAfter) +
          Duration(milliseconds: _rng.nextInt(3000));
      if (kDebugMode) {
        debugPrint('[LiveFetch] 429 on $uri — waiting ${wait.inSeconds}s');
      }
      await Future.delayed(wait);
      res = await _externalClient.get(uri).timeout(timeout);
    }
    return res;
  }

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

        if (city != cities.last) {
          await Future.delayed(const Duration(milliseconds: 300));
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

      final backendFlow  = (backend?['flow_rate']  as num?)?.toDouble() ?? 0.0;
      final glofasFlow   = (glofas?['discharge']   as num?)?.toDouble() ?? 0.0;
      final dischargeM3s = backendFlow > 0 ? backendFlow : glofasFlow;

      double? cwcLevel    = _safeLevel(backend?['current_level']);
      double? dangerLevel = _safeLevel(backend?['danger_level']);
      double? warnLevel   = _safeLevel(backend?['warning_level']);
      double? safeLevel   = _safeLevel(backend?['safe_level']);
      String? backendSrc  = backend?['data_source'] as String?;

      final isSyntheticBackend =
          backendSrc != null && _kSyntheticSources.contains(backendSrc.toUpperCase());

      String? backendRisk;
      if (!isSyntheticBackend) {
        backendRisk = (backend?['risk_level'] as String?)?.toUpperCase();
      } else {
        cwcLevel    = null;
        dangerLevel = null;
        warnLevel   = null;
        safeLevel   = null;
        if (kDebugMode) {
          debugPrint('[LiveFetch] ${city.name}: skipping synthetic bkSrc=$backendSrc');
        }
      }
      String? cwcSource = (!isSyntheticBackend && backend != null)
          ? (backendSrc ?? 'BACKEND')
          : null;

      if (cwcDirect != null) {
        cwcLevel    = cwcDirect.level    ?? cwcLevel;
        dangerLevel = cwcDirect.danger   ?? dangerLevel;
        warnLevel   = cwcDirect.warning  ?? warnLevel;
        cwcSource   = cwcDirect.source;
        backendRisk = null;
      }

      dangerLevel ??= city.dangerLevel  > 0 ? city.dangerLevel  : null;
      warnLevel   ??= city.warningLevel > 0 ? city.warningLevel : null;

      final String riskLabel;
      if (backendRisk != null && backendRisk.isNotEmpty) {
        riskLabel = _upgradeRiskFromLevel(
          backendRisk, cwcLevel, dangerLevel, warnLevel,
        );
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
        'flowRate':       dischargeM3s,
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

  String _upgradeRiskFromLevel(
    String base, double? current, double? danger, double? warning,
  ) {
    const rank = {'CRITICAL': 4, 'HIGH': 3, 'MODERATE': 2, 'LOW': 1, 'NORMAL': 1};
    int score = rank[base] ?? 1;
    if (current != null && danger != null && danger > 0) {
      final r = current / danger;
      if (r >= 1.0  && score < 4) score = 4;
      else if (r >= 0.85 && score < 3) score = 3;
      else if (r >= 0.70 && score < 2) score = 2;
    } else if (current != null && warning != null && warning > 0) {
      final r = current / warning;
      if (r >= 1.0 && score < 3) score = 3;
    }
    return score >= 4 ? 'CRITICAL'
         : score == 3 ? 'HIGH'
         : score == 2 ? 'MODERATE'
         : 'LOW';
  }

  // ── Weather — external API (open-meteo.com) ────────────────────────────────
  Future<Map<String, dynamic>?> _fetchWeather(IndiaCity city) async {
    final key = _tileKey(city.lat, city.lon);
    final cached = _weatherCache[key];
    if (cached != null && cached.valid) {
      if (kDebugMode) debugPrint('[LiveFetch] weather cache hit: ${city.name}');
      return cached.data;
    }
    try {
      final uri = Uri.parse(
        'https://api.open-meteo.com/v1/forecast'
        '?latitude=${city.lat}&longitude=${city.lon}'
        '&hourly=precipitation,temperature_2m,relative_humidity_2m'
        '&forecast_days=2&timezone=Asia%2FKolkata',
      );
      final res = await _externalGet(uri);
      if (res.statusCode != 200) {
        if (kDebugMode) debugPrint('[LiveFetch] weather ${city.name}: HTTP ${res.statusCode}');
        return null;
      }
      final j      = jsonDecode(res.body) as Map<String, dynamic>;
      final hourly = j['hourly'] as Map<String, dynamic>;
      final precip = _doubles(hourly['precipitation']);
      final last24 = precip.length >= 24 ? precip.sublist(precip.length - 24) : precip;
      final result = {
        'precip_mm': last24.fold(0.0, (a, b) => a + b),
        'temp_c':    _doubles(hourly['temperature_2m']).lastOrNull ?? 25.0,
        'humidity':  _doubles(hourly['relative_humidity_2m']).lastOrNull ?? 60.0,
      };
      _weatherCache[key] = _CacheEntry(result);
      return result;
    } catch (e) {
      if (kDebugMode) debugPrint('[LiveFetch] weather ${city.name}: $e');
      return null;
    }
  }

  // ── GloFAS discharge — external API (flood-api.open-meteo.com) ────────────
  Future<Map<String, dynamic>?> _fetchGloFas(IndiaCity city) async {
    final key = _tileKey(city.lat, city.lon);
    final cached = _glofasCache[key];
    if (cached != null && cached.valid) {
      if (kDebugMode) debugPrint('[LiveFetch] GloFAS cache hit: ${city.name}');
      return cached.data;
    }
    try {
      final uri = Uri.parse(
        'https://flood-api.open-meteo.com/v1/flood'
        '?latitude=${city.lat}&longitude=${city.lon}'
        '&daily=river_discharge&past_days=4&forecast_days=1',
      );
      final res = await _externalGet(uri);
      if (res.statusCode != 200) {
        if (kDebugMode) debugPrint('[LiveFetch] GloFAS ${city.name}: HTTP ${res.statusCode}');
        return null;
      }
      final j    = jsonDecode(res.body) as Map<String, dynamic>;
      final vals = _doubles((j['daily'] as Map?)?['river_discharge']);
      if (vals.isEmpty) return null;
      final result = {'discharge': vals.last, 'discharge7d': vals};
      _glofasCache[key] = _CacheEntry(result);
      return result;
    } catch (e) {
      if (kDebugMode) debugPrint('[LiveFetch] GloFAS ${city.name}: $e');
      return null;
    }
  }

  // ── Backend gauge levels — via FloodApi (OpsClient, auth-aware) ───────────
  Future<Map<String, dynamic>?> _fetchBackendLevels(IndiaCity city) async {
    try {
      final resp = await _api.levelsByState(city.state, limit: 200);
      if (resp['status'] == 'error') {
        if (kDebugMode) debugPrint('[LiveFetch] backend ${city.name}: ${resp['error']}');
        return null;
      }

      // Unwrap the data list (OpsClient normalises list responses to {status, data:[...]})
      final raw = resp['data'];
      if (raw is! List || raw.isEmpty) return null;

      // Guard: HTML maintenance page
      if (raw is String && (raw as String).trimLeft().startsWith('<')) {
        if (kDebugMode) debugPrint('[LiveFetch] backend ${city.name}: HTML response (maintenance?)');
        return null;
      }

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

  // ── IMD alerts — external API (sachet.ndma.gov.in) ────────────────────────
  List<dynamic> _imdCache     = [];
  DateTime?     _imdCacheTime;

  Future<List<dynamic>?> _fetchImdAlerts(IndiaCity city) async {
    final now = DateTime.now();
    if (_imdCacheTime != null &&
        now.difference(_imdCacheTime!) < AppConfig.cacheTtl &&
        _imdCache.isNotEmpty) {
      return _filterImd(city.state);
    }
    try {
      final res = await _externalClient
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

  FloodData _snapToFloodData(IndiaCity city, Map<String, dynamic> snap) {
    final danger  = (snap['dangerLevel']  as num?)?.toDouble() ?? city.dangerLevel;
    final warning = (snap['warningLevel'] as num?)?.toDouble() ?? city.warningLevel;
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
      flowRate:      flow,
      rainfall24h:   precip,
      status:        (snap['healthySources'] as int? ?? 0) >= 2 ? 'Live' : 'Partial',
      imdRainfallMm: precip,
      imdSeverity:   imdSev,
    );
  }

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

  List<IndiaCity> _priorityCities() {
    final cwcFirst   = kIndiaCities.where((c) => c.cwcStation != null).toList();
    final remaining  = kIndiaCities.where((c) => c.cwcStation == null).toList();
    return [...cwcFirst, ...remaining];
  }

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

// Added by patch — restores _matchCity used at line 523
extension _LiveFetchEngineMatch on LiveFetchEngine {
  // ignore: unused_element
}
