// lib/services/live_fetch_engine.dart  (v3.0 — backend-only)
//
// KEY CHANGE from v2.7:
//   ALL external HTTP calls (BeFIQR/WRD, GloFAS, Open-Meteo) are now routed
//   through the OpsFlood backend via BackendApiService.  The Flutter app
//   makes zero direct calls to third-party APIs.
//
//   Backend endpoints used:
//     GET /api/live-levels?state=Bihar   → WRD station gauge readings
//     GET /api/glofas?lats=&lons=&cities= → GloFAS river discharge
//     GET /api/rainfall?lats=&lons=&cities= → Open-Meteo precipitation

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../constants/india_geodata.dart';
import '../models/flood_data.dart';
import '../models/river_monitoring.dart';
import 'backend_api_service.dart';
import 'wrd_bihar_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SourceHealth
// ─────────────────────────────────────────────────────────────────────────────
class SourceHealth {
  final bool      healthy;
  final int?      latencyMs;
  final DateTime? lastSuccessAt;
  final String?   lastError;

  const SourceHealth({
    required this.healthy,
    this.latencyMs,
    this.lastSuccessAt,
    this.lastError,
  });

  const SourceHealth.unknown()
      : healthy       = false,
        latencyMs     = null,
        lastSuccessAt = null,
        lastError     = null;

  SourceHealth copyWith({
    bool?     healthy,
    int?      latencyMs,
    DateTime? lastSuccessAt,
    String?   lastError,
  }) =>
      SourceHealth(
        healthy:       healthy       ?? this.healthy,
        latencyMs:     latencyMs     ?? this.latencyMs,
        lastSuccessAt: lastSuccessAt ?? this.lastSuccessAt,
        lastError:     lastError     ?? this.lastError,
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// LiveCityData
// ─────────────────────────────────────────────────────────────────────────────
class LiveCityData {
  final double?   currentLevel;
  final double    warningLevel;
  final double    dangerLevel;
  final double?   flowRate;
  final double?   rainfall24h;
  final String?   riskLevel;
  final DateTime  lastUpdated;

  const LiveCityData({
    this.currentLevel,
    required this.warningLevel,
    required this.dangerLevel,
    this.flowRate,
    this.rainfall24h,
    this.riskLevel,
    required this.lastUpdated,
  });

  @override
  String toString() =>
      'LiveCityData(flow=$flowRate m³/s, risk=$riskLevel, '
      'rain=${rainfall24h}mm, level=$currentLevel m)';

  LiveCityData copyWith({
    double?   currentLevel,
    double?   warningLevel,
    double?   dangerLevel,
    double?   flowRate,
    double?   rainfall24h,
    String?   riskLevel,
    DateTime? lastUpdated,
  }) =>
      LiveCityData(
        currentLevel: currentLevel ?? this.currentLevel,
        warningLevel: warningLevel ?? this.warningLevel,
        dangerLevel:  dangerLevel  ?? this.dangerLevel,
        flowRate:     flowRate     ?? this.flowRate,
        rainfall24h:  rainfall24h  ?? this.rainfall24h,
        riskLevel:    riskLevel    ?? this.riskLevel,
        lastUpdated:  lastUpdated  ?? this.lastUpdated,
      );

  FloodData toFloodData(String city, String state,
      {String? riverName, String district = ''}) {
    final level  = currentLevel ?? 0.0;
    final capPct = dangerLevel > 0
        ? (level / dangerLevel * 100).clamp(0.0, 150.0)
        : 0.0;
    return FloodData(
      city:                city,
      district:            district,
      state:               state,
      riverName:           riverName,
      currentLevel:        level,
      warningLevel:        warningLevel,
      dangerLevel:         dangerLevel,
      safeLevel:           warningLevel * 0.8,
      capacityPercent:     capPct,
      riskLevel:           riskLevel ?? 'LOW',
      status:              'LIVE',
      effectiveRainfallMm: rainfall24h ?? 0.0,
      flowRate:            flowRate,
      lastUpdated:         lastUpdated,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LiveFetchEngine
// ─────────────────────────────────────────────────────────────────────────────
class LiveFetchEngine {
  static const _cacheTtl     = Duration(minutes: 15);
  static const _pollInterval = Duration(seconds: 45);

  final Map<String, LiveCityData> _cache = {};
  DateTime?  _lastFetch;
  Timer?     _pollTimer;
  bool       _isLoading    = false;
  bool       _isOnline     = true;
  bool       _isWakingUp   = false;
  bool       _isUsingCache = false;
  String?    _error;
  int        _queuedOffline = 0;
  int        _retryCount    = 0;
  int        _wakeAttempts  = 0;

  int _wrdLiveCount = 0;
  int _wrdDiskCount = 0;

  SourceHealth _backendHealth = const SourceHealth.unknown();
  SourceHealth _glofasHealth  = const SourceHealth.unknown();
  SourceHealth _imdHealth     = const SourceHealth.unknown();
  SourceHealth _wrdHealth     = const SourceHealth.unknown();

  // cwcHealth mirrors wrdHealth — WRD Bihar IS the CWC Bihar source
  SourceHealth get _cwcHealth => _wrdHealth;

  void Function()? onStateChanged;

  // ── Lifecycle ─────────────────────────────────────────────────────────────
  Future<void> startPolling() async {
    if (_pollTimer != null) return;
    await refreshData();
    _pollTimer = Timer.periodic(_pollInterval, (_) => _timerTick());
  }

  void stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  // ── Status getters ────────────────────────────────────────────────────────
  bool      get isLoading           => _isLoading;
  bool      get isOnline            => _isOnline;
  bool      get isUsingFallback     => !_isOnline && _cache.isNotEmpty;
  bool      get isWakingUp          => _isWakingUp;
  bool      get isUsingCache        => _isUsingCache;
  DateTime? get lastFetchTime       => _lastFetch;
  String?   get error               => _error;
  int       get queuedOfflineCycles => _queuedOffline;
  int       get debugRetryCount     => _retryCount;
  int       get debugWakeAttempts   => _wakeAttempts;

  int get wrdLiveCount  => _wrdLiveCount;
  int get wrdDiskCount  => _wrdDiskCount;
  int get wrdTotalCount => _wrdLiveCount + _wrdDiskCount;

  // ── Source health getters ─────────────────────────────────────────────────
  SourceHealth get backendHealth => _backendHealth;
  SourceHealth get glofasHealth  => _glofasHealth;
  SourceHealth get imdHealth     => _imdHealth;
  SourceHealth get wrdHealth     => _wrdHealth;
  SourceHealth get cwcHealth     => _cwcHealth;

  bool get backendHealthy => _backendHealth.healthy;
  bool get glofasHealthy  => _glofasHealth.healthy;
  bool get imdHealthy     => _imdHealth.healthy;
  bool get wrdHealthy     => _wrdHealth.healthy;
  bool get cwcHealthy     => _cwcHealth.healthy;

  int? get backendLatencyMs => _backendHealth.latencyMs;
  int? get glofasLatencyMs  => _glofasHealth.latencyMs;
  int? get imdLatencyMs     => _imdHealth.latencyMs;
  int? get wrdLatencyMs     => _wrdHealth.latencyMs;
  int? get cwcLatencyMs     => _cwcHealth.latencyMs;

  // ── Data getters ──────────────────────────────────────────────────────────
  List<LiveCityData?> get liveLevels => _cache.values.toList();

  List<FloodData> get liveFloodData {
    return _cache.entries.map((e) {
      final city = e.key;
      final data = e.value;
      final mc   = IndiaGeodata.monitoredCities.firstWhere(
        (c) => (c['city'] as String).toLowerCase() == city,
        orElse: () => {'city': city, 'district': '', 'state': 'Bihar'},
      );
      return data.toFloodData(
        mc['city']     as String,
        mc['state']    as String,
        riverName:  mc['river']    as String?,
        district:  (mc['district'] as String?) ?? '',
      );
    }).toList();
  }

  List<dynamic> get activeCriticalAlerts => _buildCriticalAlerts();
  List<dynamic> get criticalAlerts       => _buildCriticalAlerts();
  int           get criticalCount        => _buildCriticalAlerts().length;

  List<dynamic> get cwcStations    => liveFloodData;
  bool          get hasCwcLiveData => _cache.isNotEmpty;

  MultiLocationMonitoring get monitoringData => MultiLocationMonitoring(
    locations:   liveFloodData,
    lastUpdated: _lastFetch,
  );

  List<dynamic> get imdAlerts         => const [];
  List<dynamic> get ndmaAdvisories    => const [];
  List<dynamic> get emergencyContacts => const [];

  Map<String, dynamic> get debugLevelsRaw => {
    for (final e in _cache.entries) e.key: e.value.toString()
  };
  Map<String, dynamic> get debugCwcRaw => {
    'wrdLive':   _wrdLiveCount,
    'wrdDisk':   _wrdDiskCount,
    'cacheSize': _cache.length,
    'backend':   BackendApiService.instance.baseUrl,
  };

  // ── Per-city helpers ──────────────────────────────────────────────────────
  LiveCityData? dataForCity(String city) {
    _maybeBackgroundRefresh();
    return _cache[city.toLowerCase().trim()];
  }

  FloodData? floodDataForCity(String city) {
    final d = dataForCity(city);
    if (d == null) return null;
    final mc = IndiaGeodata.monitoredCities.firstWhere(
      (c) => (c['city'] as String).toLowerCase() == city.toLowerCase(),
      orElse: () => {'city': city, 'district': '', 'state': 'Bihar'},
    );
    return d.toFloodData(
      mc['city']     as String,
      mc['state']    as String,
      riverName:  mc['river']    as String?,
      district:  (mc['district'] as String?) ?? '',
    );
  }

  List<dynamic> imdAlertsForState(String state)         => const [];
  List<dynamic> ndmaAdvisoriesForState(String state)    => const [];
  List<dynamic> emergencyContactsForState(String state) => const [];
  List<dynamic> trendForCity(String city)               => const [];

  // ── Refresh ───────────────────────────────────────────────────────────────
  Future<void> refreshData() async {
    _isLoading = true;
    _notify();
    try {
      await _fetchAllCities();
      _isOnline      = true;
      _isUsingCache  = false;
      _error         = null;
      _queuedOffline = 0;
    } catch (e) {
      _isOnline = false;
      _error    = e.toString();
      _retryCount++;
      if (_cache.isNotEmpty) _isUsingCache = true;
      _log('refreshData error: $e');
    } finally {
      _isLoading  = false;
      _isWakingUp = false;
      _notify();
    }
  }

  Future<void> _timerTick() async {
    if (_isLoading) return;
    if (!_isOnline) _queuedOffline++;
    await refreshData();
  }

  // ── Core fetch — ALL via backend ──────────────────────────────────────────
  Future<void> _fetchAllCities() async {
    final allCities = IndiaGeodata.monitoredCities;
    if (allCities.isEmpty) return;

    final lats     = allCities.map((c) => (c['lat']  as num).toDouble()).toList();
    final lons     = allCities.map((c) => (c['lon']  as num).toDouble()).toList();
    final cityKeys = allCities.map((c) => (c['city'] as String).toLowerCase().trim()).toList();

    // ── 1. WRD Bihar — station gauge readings from backend ────────────────
    final wrdStart = DateTime.now();
    Map<String, WrdStation> wrdByKey = {};
    _wrdLiveCount = 0;
    _wrdDiskCount = 0;

    try {
      final stations = await WrdBiharService.instance.fetch();
      for (final s in stations) {
        final isLive = s.source.contains('LIVE') || s.source.contains('BACKEND');
        if (isLive) _wrdLiveCount++; else _wrdDiskCount++;
        wrdByKey[s.site.toLowerCase().trim()]     = s;
        wrdByKey[s.district.toLowerCase().trim()] = s;
      }
      _wrdHealth = SourceHealth(
        healthy:       stations.isNotEmpty,
        latencyMs:     DateTime.now().difference(wrdStart).inMilliseconds,
        lastSuccessAt: _wrdLiveCount > 0 ? DateTime.now() : _wrdHealth.lastSuccessAt,
        lastError:     _wrdLiveCount > 0
            ? null
            : stations.isNotEmpty
                ? 'WRD serving disk-cache (${_wrdDiskCount} stations)'
                : 'WRD returned 0 stations',
      );
      _log('WRD: ${stations.length} stations (live=$_wrdLiveCount disk=$_wrdDiskCount)');
    } catch (e) {
      _wrdHealth = SourceHealth(
        healthy:       false,
        latencyMs:     DateTime.now().difference(wrdStart).inMilliseconds,
        lastSuccessAt: _wrdHealth.lastSuccessAt,
        lastError:     e.toString(),
      );
      _log('WRD fetch failed: $e');
    }

    // ── 2. GloFAS — river discharge from backend ──────────────────────────
    var dischargeMap = <String, double?>{};
    var meanMap      = <String, double?>{};
    final glofasStart = DateTime.now();
    try {
      final rows = await BackendApiService.instance.fetchGloFAS(
        lats:     lats,
        lons:     lons,
        cityKeys: cityKeys,
      );
      for (final r in rows) {
        final key = (r['city'] as String? ?? '').toLowerCase().trim();
        dischargeMap[key] = (r['discharge']      as num?)?.toDouble();
        meanMap[key]      = (r['discharge_mean'] as num?)?.toDouble();
      }
      _glofasHealth = SourceHealth(
        healthy:       true,
        latencyMs:     DateTime.now().difference(glofasStart).inMilliseconds,
        lastSuccessAt: DateTime.now(),
      );
    } catch (e) {
      _glofasHealth = SourceHealth(
        healthy:       false,
        latencyMs:     DateTime.now().difference(glofasStart).inMilliseconds,
        lastSuccessAt: _glofasHealth.lastSuccessAt,
        lastError:     e.toString(),
      );
      _log('GloFAS fetch failed: $e');
    }

    // ── 3. Rainfall — Open-Meteo precipitation from backend ───────────────
    var rainMap = <String, double?>{};
    final imdStart = DateTime.now();
    try {
      final rows = await BackendApiService.instance.fetchRainfall(
        lats:     lats,
        lons:     lons,
        cityKeys: cityKeys,
      );
      for (final r in rows) {
        final key = (r['city'] as String? ?? '').toLowerCase().trim();
        rainMap[key] = (r['rainfall24h'] as num?)?.toDouble();
      }
      _imdHealth = SourceHealth(
        healthy:       true,
        latencyMs:     DateTime.now().difference(imdStart).inMilliseconds,
        lastSuccessAt: DateTime.now(),
      );
    } catch (e) {
      _imdHealth = SourceHealth(
        healthy:       false,
        latencyMs:     DateTime.now().difference(imdStart).inMilliseconds,
        lastSuccessAt: _imdHealth.lastSuccessAt,
        lastError:     e.toString(),
      );
      _log('Rainfall fetch failed: $e');
    }

    // ── 4. Assemble cache ─────────────────────────────────────────────────
    final now = DateTime.now();
    for (int i = 0; i < allCities.length; i++) {
      final mc       = allCities[i];
      final cityName = mc['city']          as String;
      final dl       = (mc['danger_level'] as num).toDouble();
      final wl       = (mc['warning_level']as num).toDouble();
      final key      = cityName.toLowerCase().trim();

      final discharge = dischargeMap[key];
      final mean      = meanMap[key];
      final rain      = rainMap[key];
      final risk      = _deriveGlofasRisk(discharge, mean);
      final estLevel  = (discharge != null && mean != null && mean > 0 && dl > 0)
          ? (discharge / mean) * dl * 0.85
          : null;

      // WRD match: exact key → word-token scan
      WrdStation? wrd = wrdByKey[key];
      if (wrd == null) {
        for (final word in key.split(RegExp(r'\s+'))) {
          if (word.length < 4) continue;
          wrd = wrdByKey[word];
          if (wrd != null) break;
          for (final s in (WrdBiharService.instance.cachedStations ?? [])) {
            if (s.site.toLowerCase().contains(word) ||
                s.district.toLowerCase().contains(word)) {
              wrd = s;
              break;
            }
          }
          if (wrd != null) break;
        }
      }

      _cache[key] = LiveCityData(
        currentLevel: wrd?.currentLevel ?? estLevel,
        warningLevel: (wrd?.warningLevel != null && wrd!.warningLevel! > 0)
            ? wrd.warningLevel! : wl,
        dangerLevel:  (wrd?.dangerLevel != null && wrd!.dangerLevel! > 0)
            ? wrd.dangerLevel!  : dl,
        flowRate:     discharge,
        rainfall24h:  rain,
        riskLevel:    _mergeRisk(wrd?.riskLabel, risk),
        lastUpdated:  now,
      );
    }

    _lastFetch = now;
    _log('cache updated — ${_cache.length} cities '
        '(wrd=${_wrdHealth.healthy} [live=$_wrdLiveCount disk=$_wrdDiskCount], '
        'glofas=${_glofasHealth.healthy}, '
        'rainfall=${_imdHealth.healthy})');
    _notify();
  }

  // ── Risk helpers ──────────────────────────────────────────────────────────
  String? _deriveGlofasRisk(double? discharge, double? mean) {
    if (discharge == null || mean == null || mean <= 0) return null;
    final ratio = discharge / mean;
    if (ratio >= 2.0) return 'CRITICAL';
    if (ratio >= 1.5) return 'SEVERE';
    if (ratio >= 1.0) return 'MODERATE';
    return 'LOW';
  }

  String? _mergeRisk(String? wrd, String? glofas) {
    const severity = {
      'CRITICAL': 5, 'HIGH': 4, 'SEVERE': 4,
      'MODERATE': 3, 'LOW': 2, 'PRE-MONSOON': 1, 'NA': 0,
    };
    if (wrd == null && glofas == null) return null;
    if (wrd    == null) return glofas;
    if (glofas == null) return wrd;
    final ws = severity[wrd.toUpperCase()]    ?? 0;
    final gs = severity[glofas.toUpperCase()] ?? 0;
    final winner = ws >= gs ? wrd : glofas;
    return winner == 'HIGH' ? 'SEVERE' : winner;
  }

  List<Map<String, dynamic>> _buildCriticalAlerts() {
    return _cache.entries
        .where((e) =>
            e.value.riskLevel == 'CRITICAL' ||
            e.value.riskLevel == 'SEVERE')
        .map((e) => {
              'city':      e.key,
              'riskLevel': e.value.riskLevel,
              'level':     e.value.currentLevel,
            })
        .toList();
  }

  void _maybeBackgroundRefresh() {
    if (_lastFetch == null ||
        DateTime.now().difference(_lastFetch!) > _cacheTtl) {
      refreshData().catchError((Object e) => _log('bg refresh error: $e'));
    }
  }

  void _notify() => onStateChanged?.call();
  void _log(String msg) {
    if (kDebugMode) debugPrint('[LiveFetchEngine] $msg');
  }
}
