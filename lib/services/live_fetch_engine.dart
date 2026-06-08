// lib/services/live_fetch_engine.dart  (v2.6 — boot crash fix)
// Removed bare `library;` directive — two unnamed library declarations in the
// same package cause a duplicate-library compile error that kills the isolate.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../constants/india_geodata.dart';
import '../models/flood_data.dart';
import '../models/river_monitoring.dart';
import 'wrd_bihar_service.dart';

// ───────────────────────────────────────────────────────────────────────────
// SourceHealth — immutable snapshot for one data source
// ───────────────────────────────────────────────────────────────────────────
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

// ───────────────────────────────────────────────────────────────────────────
// LiveCityData
// ───────────────────────────────────────────────────────────────────────────
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
      status:              'ESTIMATED',
      effectiveRainfallMm: rainfall24h ?? 0.0,
      flowRate:            flowRate,
      lastUpdated:         lastUpdated,
    );
  }
}

// ───────────────────────────────────────────────────────────────────────────
// LiveFetchEngine
// ───────────────────────────────────────────────────────────────────────────
class LiveFetchEngine {
  static const _cacheTtl     = Duration(minutes: 15);
  static const _pollInterval = Duration(seconds: 45);
  static const _httpTimeout  = Duration(seconds: 20);

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

  SourceHealth _glofasHealth = const SourceHealth.unknown();
  SourceHealth _imdHealth    = const SourceHealth.unknown();
  SourceHealth _wrdHealth    = const SourceHealth.unknown();
  SourceHealth _cwcHealth    = const SourceHealth.unknown();

  void Function()? onStateChanged;

  // ── Lifecycle ───────────────────────────────────────────────────────────
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

  // ── Source health getters ──────────────────────────────────────────────
  SourceHealth get glofasHealth => _glofasHealth;
  SourceHealth get imdHealth    => _imdHealth;
  SourceHealth get wrdHealth    => _wrdHealth;
  SourceHealth get cwcHealth    => _cwcHealth;

  bool get glofasHealthy => _glofasHealth.healthy;
  bool get imdHealthy    => _imdHealth.healthy;
  bool get wrdHealthy    => _wrdHealth.healthy;
  bool get cwcHealthy    => _cwcHealth.healthy;

  int? get glofasLatencyMs => _glofasHealth.latencyMs;
  int? get imdLatencyMs    => _imdHealth.latencyMs;
  int? get wrdLatencyMs    => _wrdHealth.latencyMs;
  int? get cwcLatencyMs    => _cwcHealth.latencyMs;

  // ── Data getters ─────────────────────────────────────────────────────────
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
  List<dynamic> get cwcStations          => liveFloodData;
  bool          get hasCwcLiveData       => _cache.isNotEmpty;

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
  Map<String, dynamic> get debugCwcRaw => const {};

  // ── Per-city helpers ────────────────────────────────────────────────────
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

  List<RiverLevelSnapshot> trendForCity(String city) => const [];
  List<dynamic> imdAlertsForState(String state)         => const [];
  List<dynamic> ndmaAdvisoriesForState(String state)    => const [];
  List<dynamic> emergencyContactsForState(String state) => const [];

  // ── Refresh ─────────────────────────────────────────────────────────────
  Future<void> refreshData() async {
    _isLoading = true;
    _notify();
    try {
      await _fetchBiharCities();
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

  // ── Core fetch ────────────────────────────────────────────────────────────
  Future<void> _fetchBiharCities() async {
    final biharCities = IndiaGeodata.monitoredCities
        .where((c) => c['state'] == 'Bihar')
        .toList();
    if (biharCities.isEmpty) return;

    final lats = biharCities.map((c) => '${c["lat"]}').join(',');
    final lons = biharCities.map((c) => '${c["lon"]}').join(',');

    // ── GloFAS ────────────────────────────────────────────────────────────
    var dischargeMap = <String, List<double?>>{};
    var meanMap      = <String, List<double?>>{};
    final glofasStart = DateTime.now();
    try {
      final result = await _fetchGloFAS(lats, lons, biharCities.length);
      dischargeMap = result['discharge']!;
      meanMap      = result['mean']!;
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

    // ── IMD / Open-Meteo rainfall ─────────────────────────────────────────
    var rainMap = <String, double?>{};
    final imdStart = DateTime.now();
    try {
      rainMap = await _fetchRainfall(lats, lons, biharCities.length);
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
      _log('Open-Meteo fetch failed: $e');
    }

    // ── WRD Bihar scraper ─────────────────────────────────────────────────
    final wrdStart = DateTime.now();
    Map<String, WrdStation> wrdByCity = {};
    try {
      final stations = await WrdBiharService.instance.fetch();
      final liveFetch = stations.isNotEmpty &&
          stations.any((s) => s.source == 'WRD_BIHAR_LIVE');
      _wrdHealth = SourceHealth(
        healthy:       liveFetch,
        latencyMs:     DateTime.now().difference(wrdStart).inMilliseconds,
        lastSuccessAt: liveFetch ? DateTime.now() : _wrdHealth.lastSuccessAt,
        lastError:     liveFetch ? null : 'WRD returned disk-cache only',
      );
      for (final s in stations) {
        wrdByCity[s.site.toLowerCase().trim()] = s;
        final dist = s.district.toLowerCase().trim();
        if (dist.isNotEmpty) wrdByCity.putIfAbsent(dist, () => s);
      }
      _log('WRD Bihar: ${stations.length} stations (live=$liveFetch)');
    } catch (e) {
      _wrdHealth = SourceHealth(
        healthy:       false,
        latencyMs:     DateTime.now().difference(wrdStart).inMilliseconds,
        lastSuccessAt: _wrdHealth.lastSuccessAt,
        lastError:     e.toString(),
      );
      _log('WRD Bihar fetch failed: $e');
    }

    // ── CWC — stub ──────────────────────────────────────────────────────
    // TODO: wire real CWC fetch and update _cwcHealth.

    // ── Assemble / merge cache ───────────────────────────────────────────────
    final now = DateTime.now();
    for (int i = 0; i < biharCities.length; i++) {
      final mc       = biharCities[i];
      final cityName = (mc['city']          as String);
      final dl       = (mc['danger_level']  as num).toDouble();
      final wl       = (mc['warning_level'] as num).toDouble();
      final key      = cityName.toLowerCase().trim();
      final discharge = dischargeMap[key]?.firstOrNull;
      final mean      = meanMap[key]?.firstOrNull;
      final rain      = rainMap[key];
      final risk      = _deriveRisk(discharge, mean);
      final estLevel  = (discharge != null && mean != null && mean > 0 && dl > 0)
          ? (discharge / mean) * dl * 0.85
          : null;

      WrdStation? wrd = wrdByCity[key];
      if (wrd == null) {
        for (final word in key.split(RegExp(r'\s+'))) {
          if (word.length < 4) continue;
          wrd = wrdByCity[word];
          if (wrd != null) break;
        }
      }

      _cache[key] = LiveCityData(
        currentLevel: wrd?.currentLevel ?? estLevel,
        warningLevel: (wrd?.warningLevel != null && wrd!.warningLevel! > 0)
            ? wrd.warningLevel! : wl,
        dangerLevel:  (wrd?.dangerLevel  != null && wrd!.dangerLevel!  > 0)
            ? wrd.dangerLevel!  : dl,
        flowRate:     discharge,
        rainfall24h:  rain,
        riskLevel:    _mergeRisk(wrd?.riskLabel, risk),
        lastUpdated:  now,
      );
    }
    _lastFetch = now;
    _log('cache updated — ${_cache.length} cities '
        '(glofas=${_glofasHealth.healthy}, '
        'imd=${_imdHealth.healthy}, '
        'wrd=${_wrdHealth.healthy})');
    _notify();
  }

  // ── HTTP helpers ────────────────────────────────────────────────────────
  Future<Map<String, Map<String, List<double?>>>> _fetchGloFAS(
      String lats, String lons, int count) async {
    final uri = Uri.parse(
      'https://flood-api.open-meteo.com/v1/flood'
      '?latitude=$lats&longitude=$lons'
      '&daily=river_discharge,river_discharge_mean'
      '&forecast_days=1&models=seamless_v4',
    );
    final res = await http.get(uri).timeout(_httpTimeout);
    if (res.statusCode != 200) throw Exception('GloFAS HTTP ${res.statusCode}');
    final body   = jsonDecode(res.body);
    final items  = body is List ? body : [body];
    final cities = IndiaGeodata.monitoredCities
        .where((c) => c['state'] == 'Bihar').toList();
    final discharge = <String, List<double?>>{};
    final mean      = <String, List<double?>>{};
    for (int i = 0; i < items.length && i < cities.length; i++) {
      final key   = (cities[i]['city'] as String).toLowerCase().trim();
      final daily = items[i]['daily'] as Map<String, dynamic>?;
      discharge[key] = _extractDoubles(daily?['river_discharge']);
      mean[key]      = _extractDoubles(daily?['river_discharge_mean']);
    }
    return {'discharge': discharge, 'mean': mean};
  }

  Future<Map<String, double?>> _fetchRainfall(
      String lats, String lons, int count) async {
    final uri = Uri.parse(
      'https://api.open-meteo.com/v1/forecast'
      '?latitude=$lats&longitude=$lons'
      '&daily=precipitation_sum'
      '&forecast_days=1&timezone=Asia%2FKolkata',
    );
    final res = await http.get(uri).timeout(_httpTimeout);
    if (res.statusCode != 200) throw Exception('Open-Meteo HTTP ${res.statusCode}');
    final body   = jsonDecode(res.body);
    final items  = body is List ? body : [body];
    final cities = IndiaGeodata.monitoredCities
        .where((c) => c['state'] == 'Bihar').toList();
    final result = <String, double?>{};
    for (int i = 0; i < items.length && i < cities.length; i++) {
      final key   = (cities[i]['city'] as String).toLowerCase().trim();
      final daily = items[i]['daily'] as Map<String, dynamic>?;
      result[key] = _extractDoubles(daily?['precipitation_sum']).firstOrNull;
    }
    return result;
  }

  // ── Internal helpers ────────────────────────────────────────────────────
  String? _deriveRisk(double? discharge, double? mean) {
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

  List<double?> _extractDoubles(dynamic raw) {
    if (raw == null) return [];
    if (raw is List) {
      return raw.map<double?>((v) {
        if (v == null)   return null;
        if (v is double) return v;
        if (v is int)    return v.toDouble();
        return double.tryParse(v.toString());
      }).toList();
    }
    return [];
  }

  void _notify() => onStateChanged?.call();
  void _log(String msg) {
    if (kDebugMode) debugPrint('[LiveFetchEngine] $msg');
  }
}
