// lib/services/live_fetch_engine.dart  (v2.2 — district propagated)
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../constants/india_geodata.dart';
import '../models/flood_data.dart';
import '../models/river_monitoring.dart';

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

class LiveFetchEngine {
  static const _cacheTtl     = Duration(minutes: 15);
  static const _pollInterval = Duration(seconds: 45);
  static const _httpTimeout  = Duration(seconds: 20);

  final Map<String, LiveCityData> _cache = {};
  DateTime?  _lastFetch;
  Timer?     _pollTimer;
  bool       _isLoading     = false;
  bool       _isOnline      = true;
  bool       _isWakingUp    = false;
  bool       _isUsingCache  = false;
  String?    _error;
  int        _queuedOffline = 0;
  int        _retryCount    = 0;
  int        _wakeAttempts  = 0;

  void Function()? onStateChanged;

  Future<void> startPolling() async {
    if (_pollTimer != null) return;
    await refreshData();
    _pollTimer = Timer.periodic(_pollInterval, (_) => _timerTick());
  }

  void stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

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

  Future<void> _fetchBiharCities() async {
    final biharCities = IndiaGeodata.monitoredCities
        .where((c) => c['state'] == 'Bihar')
        .toList();
    if (biharCities.isEmpty) return;

    final lats = biharCities.map((c) => '${c['lat']}').join(',');
    final lons = biharCities.map((c) => '${c['lon']}').join(',');

    var dischargeMap = <String, List<double?>>{};
    var meanMap      = <String, List<double?>>{};
    try {
      final result = await _fetchGloFAS(lats, lons, biharCities.length);
      dischargeMap = result['discharge']!;
      meanMap      = result['mean']!;
    } catch (e) { _log('GloFAS batch fetch failed: $e'); }

    var rainMap = <String, double?>{};
    try {
      rainMap = await _fetchRainfall(lats, lons, biharCities.length);
    } catch (e) { _log('Open-Meteo batch fetch failed: $e'); }

    final now = DateTime.now();
    for (int i = 0; i < biharCities.length; i++) {
      final mc        = biharCities[i];
      final cityName  = mc['city']          as String;
      final dl        = (mc['danger_level']  as num).toDouble();
      final wl        = (mc['warning_level'] as num).toDouble();
      final key       = cityName.toLowerCase().trim();
      final discharge = dischargeMap[key]?.firstOrNull;
      final mean      = meanMap[key]?.firstOrNull;
      final rain      = rainMap[key];
      final risk      = _deriveRisk(discharge, mean);
      final estLevel  = (discharge != null && mean != null && mean > 0 && dl > 0)
          ? (discharge / mean) * dl * 0.85
          : null;
      _cache[key] = LiveCityData(
        currentLevel: estLevel,
        warningLevel: wl,
        dangerLevel:  dl,
        flowRate:     discharge,
        rainfall24h:  rain,
        riskLevel:    risk,
        lastUpdated:  now,
      );
    }
    _lastFetch = now;
    _log('Bihar cache updated — ${_cache.length} cities');
  }

  Future<Map<String, Map<String, List<double?>>>> _fetchGloFAS(
      String lats, String lons, int count) async {
    final uri = Uri.parse(
      'https://flood-api.open-meteo.com/v1/flood'
      '?latitude=$lats&longitude=$lons'
      '&daily=river_discharge,river_discharge_mean'
      '&forecast_days=1&models=seamless_v4',
    );
    final res = await http.get(uri).timeout(_httpTimeout);
    if (res.statusCode != 200) throw Exception('GloFAS HTTP \${res.statusCode}');
    final body  = jsonDecode(res.body);
    final items = body is List ? body : [body] as List<dynamic>;
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
    if (res.statusCode != 200) throw Exception('Open-Meteo HTTP \${res.statusCode}');
    final body  = jsonDecode(res.body);
    final items = body is List ? body : [body] as List<dynamic>;
    final cities = IndiaGeodata.monitoredCities
        .where((c) => c['state'] == 'Bihar').toList();
    final result = <String, double?>{};
    for (int i = 0; i < items.length && i < cities.length; i++) {
      final key   = (cities[i]['city'] as String).toLowerCase().trim();
      final daily = items[i]['daily'] as Map<String, dynamic>?;
      final vals  = _extractDoubles(daily?['precipitation_sum']);
      result[key] = vals.firstOrNull;
    }
    return result;
  }

  String? _deriveRisk(double? discharge, double? mean) {
    if (discharge == null || mean == null || mean <= 0) return null;
    final ratio = discharge / mean;
    if (ratio >= 2.0) return 'CRITICAL';
    if (ratio >= 1.5) return 'SEVERE';
    if (ratio >= 1.0) return 'MODERATE';
    return 'LOW';
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
      refreshData().catchError((e) => _log('bg refresh error: $e'));
    }
  }

  List<double?> _extractDoubles(dynamic raw) {
    if (raw == null) return [];
    if (raw is List) {
      return raw.map((v) {
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
