// lib/services/live_fetch_engine.dart
//
// OpsFlood — LiveFetchEngine v16
//
// CHANGES FROM v15:
//   • _fetchBackendLevels() now calls /api/stations (not /api/live-levels)
//     which is the WRD Bihar scraper endpoint.
//   • On first call, fetches ALL stations once and caches them (10 min TTL)
//     instead of fetching per-city with ?state= filter — avoids N backend
//     calls and the station list is small (23 stations).
//   • _matchCity() now also tries station 'name' field, not just 'city'.
//   • _priorityCities() expanded with all Bihar WRD station cities.
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

// ── MlInferenceEngine stub ───────────────────────────────────────────────────
class MlInferenceEngine {}

// ── Tile-level cache for Open-Meteo (20 min TTL) ────────────────────────────
const Duration _kCacheTtl = Duration(minutes: 20);

class _CacheEntry<T> {
  final T data;
  final DateTime at;
  _CacheEntry(this.data) : at = DateTime.now();
  bool get valid => DateTime.now().difference(at) < _kCacheTtl;
}

final _weatherCache = <String, _CacheEntry<Map<String, dynamic>>>{};
final _glofasCache  = <String, _CacheEntry<Map<String, dynamic>>>{};

// ── Backend station cache (shared, 10 min TTL) ──────────────────────────────
List<Map<String, dynamic>> _stationCache    = [];
DateTime?                  _stationCacheAt;
const Duration             _kStationTtl = Duration(minutes: 10);

String _tileKey(double lat, double lon) =>
    '${lat.toStringAsFixed(2)}:${lon.toStringAsFixed(2)}';

// ── LiveFetchEngine ──────────────────────────────────────────────────────────
class LiveFetchEngine {
  static final LiveFetchEngine _instance = LiveFetchEngine._internal();
  factory LiveFetchEngine() => _instance;
  LiveFetchEngine._internal();

  final http.Client      _client    = http.Client();
  final CwcDirectService _cwcDirect = CwcDirectService.instance;
  final Random           _rng       = Random();
  Timer? _timer;
  bool   _lock = false;
  bool   _backendAwake = false;

  static bool get _runningOnWeb => kIsWeb;

  VoidCallback? onStateChanged;

  // ── Status ───────────────────────────────────────────────────────────────────
  bool      isLoading           = false;
  bool      isOnline            = false;
  bool      isUsingFallback     = false;
  bool      isWakingUp          = false;
  bool      isUsingCache        = false;
  DateTime? lastFetchTime;
  String?   error;
  int       queuedOfflineCycles = 0;
  String?   fetchingCity;

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

  // ── Public helpers ───────────────────────────────────────────────────────────
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

  // ── Polling ──────────────────────────────────────────────────────────────────
  Future<void> startPolling() async {
    _timer?.cancel();
    await refreshData();
    _timer = Timer.periodic(AppConfig.realtimeInterval, (_) => refreshData());
  }

  void stopPolling() {
    _timer?.cancel();
    _timer = null;
  }

  // ── Backend wake ─────────────────────────────────────────────────────────────
  Future<bool> _wakeBackend() async {
    if (_runningOnWeb || _backendAwake) return _backendAwake;
    try {
      debugWakeAttempts++;
      final res = await _client
          .get(Uri.parse('${AppConfig.baseUrl}${AppConfig.epHealth}'))
          .timeout(AppConfig.coldStartTimeout);
      _backendAwake = res.statusCode < 500;
    } catch (_) {
      _backendAwake = false;
    }
    return _backendAwake;
  }

  // ── 429-aware HTTP fetch ──────────────────────────────────────────────────────
  Future<http.Response> _fetchWithRetry(
    Uri uri, {
    Duration timeout = const Duration(seconds: 12),
  }) async {
    var res = await _client.get(uri).timeout(timeout);
    if (res.statusCode == 429) {
      final retryAfter = int.tryParse(res.headers['retry-after'] ?? '') ?? 60;
      final wait = Duration(seconds: retryAfter) +
          Duration(milliseconds: _rng.nextInt(3000));
      await Future.delayed(wait);
      res = await _client.get(uri).timeout(timeout);
    }
    return res;
  }

  // ── Fetch ALL backend stations once and cache ─────────────────────────────────
  // Called once per refresh cycle, not once per city.
  Future<List<Map<String, dynamic>>> _fetchAllStations() async {
    final now = DateTime.now();
    if (_stationCacheAt != null &&
        now.difference(_stationCacheAt!) < _kStationTtl &&
        _stationCache.isNotEmpty) {
      if (kDebugMode) debugPrint('[LiveFetch] station cache hit (${_stationCache.length} stations)');
      return _stationCache;
    }
    try {
      // PRIMARY: /api/stations  (WRD Bihar scraper + national synthetic)
      final uri = Uri.parse('${AppConfig.baseUrl}${AppConfig.epLiveTelemetry}');
      final res = await _client.get(uri).timeout(AppConfig.requestTimeout);
      if (res.statusCode == 200) {
        final j = jsonDecode(res.body) as Map<String, dynamic>;
        final raw = j['data'];
        if (raw is List && raw.isNotEmpty) {
          _stationCache   = raw.cast<Map<String, dynamic>>();
          _stationCacheAt = now;
          if (kDebugMode) {
            debugPrint('[LiveFetch] ✓ loaded ${_stationCache.length} stations '
                'from ${AppConfig.baseUrl}${AppConfig.epLiveTelemetry}');
          }
          return _stationCache;
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[LiveFetch] _fetchAllStations error: $e');
    }
    return [];
  }

  // ── Main refresh ─────────────────────────────────────────────────────────────
  Future<void> refreshData() async {
    if (_lock) return;
    _lock     = true;
    isLoading = true;
    if (!isOnline) isWakingUp = true;
    Future.delayed(Duration.zero, () => onStateChanged?.call());

    try {
      await _wakeBackend();
      isWakingUp = false;

      // Load all WRD/backend stations ONCE for this refresh cycle
      final allStations = _runningOnWeb ? <Map<String, dynamic>>[] : await _fetchAllStations();

      final cities       = _priorityCities();
      final newLevels    = <FloodData>[];
      final newLocations = <RiverMonitoring>[];
      final newAlerts    = <Map<String, dynamic>>[];
      final newCwc       = <Map<String, dynamic>>[];
      int   healthy      = 0;

      for (final city in cities) {
        fetchingCity = city.name;
        Future.delayed(Duration.zero, () => onStateChanged?.call());

        final snap = await _fetchCity(city, allStations);
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
            'source':       snap['cwcSource'] ?? 'WRD Bihar',
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

  // ── Per-city fetch ────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>?> _fetchCity(
    IndiaCity city,
    List<Map<String, dynamic>> allStations,
  ) async {
    try {
      final weatherFut   = _fetchWeather(city);
      final glofasFut    = _fetchGloFas(city);
      final cwcDirectFut = _cwcDirect.fetch(city);
      final imdFut       = _runningOnWeb ? Future.value(null) : _fetchImdAlerts(city);

      final results = await Future.wait(
        [weatherFut, glofasFut, cwcDirectFut, imdFut],
        eagerError: false,
      );

      final weather   = results[0] as Map<String, dynamic>?;
      final glofas    = results[1] as Map<String, dynamic>?;
      final cwcDirect = results[2] as CwcReading?;
      final imd       = results[3] as List<dynamic>?;

      // Resolve backend station from the pre-loaded list
      final backend = allStations.isNotEmpty
          ? _matchCity(allStations, city.name)
          : null;

      if (weather == null && glofas == null && backend == null) return null;

      final healthySources = [
        weather != null, glofas != null,
        cwcDirect != null, backend != null,
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
      String? backendRisk = (backend?['risk_level'] as String?)?.toUpperCase();
      String? backendSrc  = backend?['data_source'] as String?;
      String? cwcSource   = backend != null ? (backendSrc ?? 'WRD_BIHAR') : null;

      if (cwcDirect != null) {
        cwcLevel    = cwcDirect.level    ?? cwcLevel;
        dangerLevel = cwcDirect.danger   ?? dangerLevel;
        warnLevel   = cwcDirect.warning  ?? warnLevel;
        cwcSource   = cwcDirect.source;
        backendRisk = null;
      }

      dangerLevel ??= city.dangerLevel  > 0 ? city.dangerLevel  : null;
      warnLevel   ??= city.warningLevel > 0 ? city.warningLevel : null;

      final String riskLabel = _inferRisk(
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

  // ── Open-Meteo Weather ────────────────────────────────────────────────────────
  Future<Map<String, dynamic>?> _fetchWeather(IndiaCity city) async {
    final key    = _tileKey(city.lat, city.lon);
    final cached = _weatherCache[key];
    if (cached != null && cached.valid) return cached.data;
    try {
      final uri = Uri.parse(
        'https://api.open-meteo.com/v1/forecast'
        '?latitude=${city.lat}&longitude=${city.lon}'
        '&hourly=precipitation,temperature_2m,relative_humidity_2m'
        '&forecast_days=2&timezone=Asia%2FKolkata',
      );
      final res = await _fetchWithRetry(uri);
      if (res.statusCode != 200) return null;
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

  // ── Open-Meteo GloFAS ─────────────────────────────────────────────────────────
  Future<Map<String, dynamic>?> _fetchGloFas(IndiaCity city) async {
    final key    = _tileKey(city.lat, city.lon);
    final cached = _glofasCache[key];
    if (cached != null && cached.valid) return cached.data;
    try {
      final uri = Uri.parse(
        'https://flood-api.open-meteo.com/v1/flood'
        '?latitude=${city.lat}&longitude=${city.lon}'
        '&daily=river_discharge&past_days=4&forecast_days=1',
      );
      final res = await _fetchWithRetry(uri);
      if (res.statusCode != 200) return null;
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

  // ── Station matcher (name + city + partial) ──────────────────────────────────
  Map<String, dynamic>? _matchCity(
    List<Map<String, dynamic>> stations, String cityName,
  ) {
    if (stations.isEmpty) return null;
    final needle = cityName.trim().toLowerCase();
    // exact match on 'city' field
    for (final s in stations) {
      if ((s['city'] as String? ?? '').toLowerCase() == needle) return s;
    }
    // exact match on 'name' field (e.g. "Gandhi Setu (Patna)" → 'patna')
    for (final s in stations) {
      if ((s['name'] as String? ?? '').toLowerCase().contains(needle)) return s;
    }
    // prefix match
    for (final s in stations) {
      if ((s['city'] as String? ?? '').toLowerCase().startsWith(needle)) return s;
    }
    // substring match
    for (final s in stations) {
      if ((s['city'] as String? ?? '').toLowerCase().contains(needle)) return s;
    }
    return null;   // don't fall back to stations.first — return null so city is skipped
  }

  // ── IMD / SACHET alerts ───────────────────────────────────────────────────────
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
      final raw   = jsonDecode(res.body);
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

  // ── Risk inference ────────────────────────────────────────────────────────────
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
    final safe    = (snap['safeLevel']    as num?)?.toDouble()
                 ?? (warning - 2.0).clamp(0.0, double.infinity);
    final current = (snap['cwcLevel']     as double?) ?? 0.0;
    final flow    = (snap['flowRate']     as num?)?.toDouble();
    final risk    = snap['riskLabel']     as String? ?? 'LOW';
    final precip  = (snap['precip_mm']    as num?)?.toDouble() ?? 0.0;
    final imdSev  = precip >= 115 ? 'RED'
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

  // ── Priority cities — Bihar WRD stations first, then national ────────────────
  List<IndiaCity> _priorityCities() {
    // Bihar WRD stations match city IDs in india_cities.dart
    const ids = [
      // Bihar WRD (12 stations — live from wrdb.bih.nic.in)
      'patna', 'hajipur', 'muzaffarpur', 'darbhanga', 'sitamarhi',
      'supaul', 'bhagalpur', 'munger', 'gaya', 'purnea',
      'bettiah', 'motihari',
      // National (open-meteo + synthetic)
      'guwahati', 'cuttack', 'kolkata', 'varanasi',
      'gorakhpur', 'dhubri', 'jalpaiguri', 'haridwar',
    ];
    return ids.map(cityById).whereType<IndiaCity>().toList();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────────
  double? _safeLevel(dynamic v) {
    if (v == null) return null;
    final d = double.tryParse(v.toString().trim()) ?? (v is num ? v.toDouble() : null);
    if (d == null) return null;
    return (d >= 0.5 && d <= 400.0) ? d : null;
  }

  List<double> _doubles(dynamic raw) {
    if (raw is! List) return [];
    return raw.map((e) => e == null ? 0.0 : (e as num).toDouble()).toList();
  }

  double? _num(dynamic v) => v == null ? null : (v as num).toDouble();
}
