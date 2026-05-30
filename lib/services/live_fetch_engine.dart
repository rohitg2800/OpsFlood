// lib/services/live_fetch_engine.dart
//
// OpsFlood — LiveFetchEngine  (v1.0 — Bihar GloFAS fallback)
//
// PURPOSE
//   Provides GloFAS / Open-Meteo river-discharge data for Bihar cities
//   when WrdBiharService has no matching station for a city.
//   Called by RealTimeRiverService as Source 2.
//
// CONTRACT (expected by RealTimeRiverService)
//   • liveLevels          → List&lt;LiveCityData?&gt;  (non-empty after first fetch)
//   • refreshData()       → Future&lt;void&gt;           (force re-fetch)
//   • dataForCity(city)   → LiveCityData?           (null = no data)
//
// DATA SOURCES
//   • GloFAS  : flood-api.open-meteo.com  — river_discharge (m³/s)
//               + river_discharge_mean    — 2-yr return period baseline
//   • Open-Meteo: api.open-meteo.com      — precipitation_sum (mm/day)
//
// SCOPE (v1.0)
//   Only the 31 Bihar cities from IndiaGeodata.monitoredCities are
//   fetched. Non-Bihar cities return null (NO_DATA) until v1.1.
//
// BATCHING
//   All 31 cities are fetched in ONE GloFAS call and ONE Open-Meteo
//   call using comma-separated lat/lon — not 31 individual calls.
//
// CACHE
//   15-minute in-memory TTL. The 45-s polling loop hits cache on
//   most ticks; a real network round-trip fires only when stale.
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../constants/india_geodata.dart';

// ── Value object returned by dataForCity() ────────────────────────────────────
class LiveCityData {
  /// Estimated gauge-equivalent level in metres (derived from discharge ratio).
  /// May be null when GloFAS returns no discharge value.
  final double? currentLevel;

  /// Warning level from IndiaGeodata (metres MSL).
  final double warningLevel;

  /// Danger level from IndiaGeodata (metres MSL).
  final double dangerLevel;

  /// Raw GloFAS river discharge in m³/s.
  final double? flowRate;

  /// Open-Meteo 24-h precipitation sum in mm.
  final double? rainfall24h;

  /// CRITICAL / HIGH / MODERATE / LOW — derived from discharge vs. mean.
  final String? riskLevel;

  final DateTime lastUpdated;

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
}

// ── Engine ────────────────────────────────────────────────────────────────────
class LiveFetchEngine {
  static const _cacheTtl     = Duration(minutes: 15);
  static const _httpTimeout  = Duration(seconds: 20);

  // Internal cache: city name (lowercase) → LiveCityData
  final Map<String, LiveCityData> _cache = {};
  DateTime? _lastFetch;

  // ── Public contract ───────────────────────────────────────────────────────

  /// Non-empty list after the first successful fetch.
  /// RealTimeRiverService checks `_lfe.liveLevels.isEmpty` as a warmup guard.
  List<LiveCityData?> get liveLevels => _cache.values.toList();

  /// Force a fresh fetch from GloFAS + Open-Meteo for all Bihar cities.
  Future<void> refreshData() async {
    await _fetchBiharCities();
  }

  /// Returns cached data for [city], or null if unavailable / not yet fetched.
  LiveCityData? dataForCity(String city) {
    _maybeBackgroundRefresh();
    return _cache[city.toLowerCase().trim()];
  }

  // ── Core fetch ────────────────────────────────────────────────────────────

  Future<void> _fetchBiharCities() async {
    final biharCities = IndiaGeodata.monitoredCities
        .where((c) => c['state'] == 'Bihar')
        .toList();

    if (biharCities.isEmpty) return;

    final lats = biharCities.map((c) => '${c['lat']}').join(',');
    final lons = biharCities.map((c) => '${c['lon']}').join(',');

    // Fetch GloFAS discharge + 2-yr mean baseline in one call
    final Map<String, List<double?>> dischargeMap;
    final Map<String, List<double?>> meanMap;
    try {
      final result = await _fetchGloFAS(lats, lons, biharCities.length);
      dischargeMap = result['discharge']!;
      meanMap      = result['mean']!;
    } catch (e) {
      _log('GloFAS batch fetch failed: $e');
      dischargeMap = {};
      meanMap      = {};
    }

    // Fetch Open-Meteo precipitation in one call
    final Map<String, double?> rainMap;
    try {
      rainMap = await _fetchRainfall(lats, lons, biharCities.length);
    } catch (e) {
      _log('Open-Meteo batch fetch failed: $e');
      rainMap = {};
    }

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

      final risk     = _deriveRisk(discharge, mean);
      // Estimated level: scale discharge as fraction of mean against DL.
      // When mean is unknown, fall back to null (screen shows NA).
      final estLevel = (discharge != null && mean != null && mean > 0 && dl > 0)
          ? (discharge / mean) * dl * 0.85   // conservative scalar
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

  // ── GloFAS batch call ─────────────────────────────────────────────────────

  Future<Map<String, Map<String, List<double?>>>> _fetchGloFAS(
    String lats,
    String lons,
    int count,
  ) async {
    final uri = Uri.parse(
      'https://flood-api.open-meteo.com/v1/flood'
      '?latitude=$lats'
      '&longitude=$lons'
      '&daily=river_discharge,river_discharge_mean'
      '&forecast_days=1',
    );

    final res = await http.get(uri).timeout(_httpTimeout);
    if (res.statusCode != 200) {
      throw Exception('GloFAS HTTP ${res.statusCode}');
    }

    final body    = jsonDecode(res.body);
    final cities  = IndiaGeodata.monitoredCities
        .where((c) => c['state'] == 'Bihar')
        .toList();

    // GloFAS returns a List when multiple locations are requested,
    // or a single Map when only one location is requested.
    final List<dynamic> locations = body is List ? body : [body];

    final discharge = <String, List<double?>>{};
    final mean      = <String, List<double?>>{};

    for (int i = 0; i < locations.length && i < cities.length; i++) {
      final loc  = locations[i] as Map<String, dynamic>;
      final key  = (cities[i]['city'] as String).toLowerCase().trim();
      final daily = loc['daily'] as Map<String, dynamic>?;

      discharge[key] = _extractDoubles(daily?['river_discharge']);
      mean[key]      = _extractDoubles(daily?['river_discharge_mean']);
    }

    return {'discharge': discharge, 'mean': mean};
  }

  // ── Open-Meteo rainfall batch call ───────────────────────────────────────

  Future<Map<String, double?>> _fetchRainfall(
    String lats,
    String lons,
    int count,
  ) async {
    final uri = Uri.parse(
      'https://api.open-meteo.com/v1/forecast'
      '?latitude=$lats'
      '&longitude=$lons'
      '&daily=precipitation_sum'
      '&forecast_days=1'
      '&timezone=Asia%2FKolkata',
    );

    final res = await http.get(uri).timeout(_httpTimeout);
    if (res.statusCode != 200) {
      throw Exception('Open-Meteo HTTP ${res.statusCode}');
    }

    final body   = jsonDecode(res.body);
    final cities = IndiaGeodata.monitoredCities
        .where((c) => c['state'] == 'Bihar')
        .toList();

    final List<dynamic> locations = body is List ? body : [body];
    final result = <String, double?>{};

    for (int i = 0; i < locations.length && i < cities.length; i++) {
      final loc   = locations[i] as Map<String, dynamic>;
      final key   = (cities[i]['city'] as String).toLowerCase().trim();
      final daily = loc['daily'] as Map<String, dynamic>?;
      final vals  = _extractDoubles(daily?['precipitation_sum']);
      result[key] = vals.firstOrNull;
    }

    return result;
  }

  // ── Risk derivation ───────────────────────────────────────────────────────
  //
  // Compares current discharge to the 2-yr return-period mean.
  // Mirrors the riskLabel bands in WrdBiharService for consistency:
  //   ≥ 150% of mean → CRITICAL
  //   ≥ 110% of mean → HIGH
  //   ≥  80% of mean → MODERATE
  //          else    → LOW

  String? _deriveRisk(double? discharge, double? mean) {
    if (discharge == null) return null;
    if (mean == null || mean <= 0) {
      // No baseline — use absolute discharge as rough proxy
      if (discharge > 5000) return 'CRITICAL';
      if (discharge > 2000) return 'HIGH';
      if (discharge > 500)  return 'MODERATE';
      return 'LOW';
    }
    final ratio = discharge / mean;
    if (ratio >= 1.50) return 'CRITICAL';
    if (ratio >= 1.10) return 'HIGH';
    if (ratio >= 0.80) return 'MODERATE';
    return 'LOW';
  }

  // ── Background refresh guard ──────────────────────────────────────────────

  void _maybeBackgroundRefresh() {
    if (_lastFetch == null ||
        DateTime.now().difference(_lastFetch!) > _cacheTtl) {
      _fetchBiharCities().catchError((e) {
        _log('background refresh error: $e');
        return;
      });
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  List<double?> _extractDoubles(dynamic raw) {
    if (raw is! List) return [];
    return raw.map<double?>((v) {
      if (v == null) return null;
      return double.tryParse(v.toString());
    }).toList();
  }

  void _log(String msg) {
    if (kDebugMode) debugPrint('[LiveFetchEngine] $msg');
  }
}
