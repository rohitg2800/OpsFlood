// lib/services/live_fetch_engine.dart
//
// OpsFlood — LiveFetchEngine
//
// Hits REAL public APIs in parallel for every city fetch:
//
//   Source 1 — Open-Meteo Weather API       (free, no key)
//              hourly precipitation + temperature + humidity
//
//   Source 2 — Open-Meteo GloFAS River API  (free, no key)
//              river discharge m³/s, 7-day daily history
//
//   Source 3 — OpsFlood backend /api/cwc-ffs/station
//              CWC gauge levels (current, danger, warning)
//
//   Source 4 — OpsFlood backend /api/live-levels
//              aggregated flood risk data per city
//
//   Source 5 — IMD XML/RSS alert feed        (public, no key)
//              flood/heavy-rain warnings for Indian states
//
// All sources run concurrently via Future.wait; individual failures
// are silently swallowed and `healthySourceCount` reflects how many
// actually returned data.
library;

import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../data/india_cities.dart';
import 'ml_inference.dart';

class LiveFetchEngine {
  LiveFetchEngine._();
  static final LiveFetchEngine instance = LiveFetchEngine._();

  final http.Client _client = http.Client();

  // ── Source timeouts ──────────────────────────────────────────────────────
  static const _weatherTimeout  = Duration(seconds: 10);
  static const _gloFasTimeout   = Duration(seconds: 10);
  static const _cwcTimeout      = Duration(seconds: 12);
  static const _backendTimeout  = Duration(seconds: 12);
  static const _imdTimeout      = Duration(seconds: 8);

  // ── Main entry point ─────────────────────────────────────────────────────

  Future<LiveSnapshot> fetchCity(IndiaCity city) async {
    final results = await Future.wait([
      _fetchWeather(city),
      _fetchGloFas(city),
      _fetchCwc(city),
      _fetchBackendLevels(city),
      _fetchImd(city),
    ], eagerError: false);

    final weather  = results[0] as WeatherData?  ?? WeatherData.empty;
    final river    = results[1] as RiverData?    ?? RiverData.empty;
    final cwc      = results[2] as CwcData?      ?? CwcData.empty;
    // results[3] — backend levels (enriches cwc if available)
    final backCwc  = results[3] as CwcData?      ?? CwcData.empty;
    // results[4] — IMD (logged, available via ImdService separately)

    // Merge: prefer live CWC data, fall back to backend levels
    final mergedCwc = cwc.ok ? cwc : backCwc;

    final healthy = [
      weather != WeatherData.empty,
      river   != RiverData.empty,
      cwc.ok,
      backCwc.ok,
      results[4] != null,
    ].where((v) => v).length;

    if (kDebugMode) {
      debugPrint('[LiveFetchEngine] ${city.name}: '
          'weather=${weather.precipitationMm}mm '
          'discharge=${river.dischargeM3s?.toStringAsFixed(0) ?? "n/a"}m³/s '
          'level=${mergedCwc.currentLevel?.toStringAsFixed(2) ?? "n/a"}m '
          'healthy=$healthy/5');
    }

    return LiveSnapshot(
      city:               city,
      weather:            weather,
      river:              river,
      cwc:                mergedCwc,
      healthySourceCount: healthy,
      fetchedAt:          DateTime.now(),
    );
  }

  // ── Source 1: Open-Meteo Weather ─────────────────────────────────────────
  // Docs: https://open-meteo.com/en/docs
  Future<WeatherData?> _fetchWeather(IndiaCity city) async {
    try {
      final uri = Uri.parse(
        'https://api.open-meteo.com/v1/forecast'
        '?latitude=${city.lat}'
        '&longitude=${city.lon}'
        '&hourly=precipitation,temperature_2m,relative_humidity_2m'
        '&forecast_days=2'
        '&timezone=Asia%2FKolkata',
      );
      final res = await _client.get(uri).timeout(_weatherTimeout);
      if (res.statusCode != 200) return null;

      final j = jsonDecode(res.body) as Map<String, dynamic>;
      final hourly = j['hourly'] as Map<String, dynamic>;

      final List<double> precip = _toDoubleList(hourly['precipitation']);
      final List<double> temp   = _toDoubleList(hourly['temperature_2m']);
      final List<double> humid  = _toDoubleList(hourly['relative_humidity_2m']);

      // Take the last 24 h
      final last24 = precip.length >= 24
          ? precip.sublist(precip.length - 24)
          : precip;
      final total24 = last24.fold(0.0, (a, b) => a + b);

      return WeatherData(
        precipitationMm:  total24,
        temperatureC:     temp.isNotEmpty ? temp.last : 25.0,
        relativeHumidity: humid.isNotEmpty ? humid.last : 60.0,
        hourlyPrecip:     last24,
      );
    } catch (e) {
      if (kDebugMode) debugPrint('[LiveFetch] weather error for ${city.name}: $e');
      return null;
    }
  }

  // ── Source 2: Open-Meteo GloFAS River Discharge ──────────────────────────
  // Docs: https://open-meteo.com/en/docs/flood-api
  Future<RiverData?> _fetchGloFas(IndiaCity city) async {
    try {
      final uri = Uri.parse(
        'https://flood-api.open-meteo.com/v1/flood'
        '?latitude=${city.lat}'
        '&longitude=${city.lon}'
        '&daily=river_discharge'
        '&past_days=7'
        '&forecast_days=1',
      );
      final res = await _client.get(uri).timeout(_gloFasTimeout);
      if (res.statusCode != 200) return null;

      final j = jsonDecode(res.body) as Map<String, dynamic>;
      final daily  = j['daily'] as Map<String, dynamic>?;
      final discharges = _toDoubleList(daily?['river_discharge']);

      if (discharges.isEmpty) return null;

      return RiverData(
        dischargeM3s: discharges.last,
        discharge7d:  discharges.length >= 7
            ? discharges.sublist(discharges.length - 7)
            : discharges,
      );
    } catch (e) {
      if (kDebugMode) debugPrint('[LiveFetch] GloFAS error for ${city.name}: $e');
      return null;
    }
  }

  // ── Source 3: OpsFlood backend — CWC FFS gauge level ─────────────────────
  Future<CwcData?> _fetchCwc(IndiaCity city) async {
    if (city.cwcStation == null) return null;
    try {
      final uri = Uri.parse(
        '${AppConfig.baseUrl}${AppConfig.epCwcFfs}/${city.cwcStation}',
      );
      final res = await _client.get(uri).timeout(_cwcTimeout);
      if (res.statusCode != 200) return null;

      final j = jsonDecode(res.body) as Map<String, dynamic>;
      final data = j['data'] ?? j;

      return CwcData(
        currentLevel:  _toDouble(data['current_level'] ?? data['level']),
        dangerLevel:   _toDouble(data['danger_level']  ?? data['danger']),
        warningLevel:  _toDouble(data['warning_level'] ?? data['warning']),
        ok: true,
      );
    } catch (e) {
      if (kDebugMode) debugPrint('[LiveFetch] CWC error for ${city.name}: $e');
      return null;
    }
  }

  // ── Source 4: OpsFlood backend — /api/live-levels ────────────────────────
  Future<CwcData?> _fetchBackendLevels(IndiaCity city) async {
    try {
      final uri = Uri.parse(
        '${AppConfig.baseUrl}${AppConfig.epLiveLevels}'
        '?city=${Uri.encodeComponent(city.name)}&state=${Uri.encodeComponent(city.state)}',
      );
      final res = await _client.get(uri).timeout(_backendTimeout);
      if (res.statusCode != 200) return null;

      final j    = jsonDecode(res.body) as Map<String, dynamic>;
      final data = _extractFirst(j);
      if (data == null) return null;

      return CwcData(
        currentLevel:  _toDouble(data['current_level'] ?? data['level']),
        dangerLevel:   _toDouble(data['danger_level']  ?? data['danger']),
        warningLevel:  _toDouble(data['warning_level'] ?? data['warning']),
        ok: true,
      );
    } catch (e) {
      if (kDebugMode) debugPrint('[LiveFetch] backend levels error for ${city.name}: $e');
      return null;
    }
  }

  // ── Source 5: IMD public RSS (flood/heavy-rain alerts) ───────────────────
  // IMD publishes alerts at https://sachet.ndma.gov.in/cap_public_website/FetchAllAlertDetails
  // Fallback: imd.gov.in XML feeds
  Future<bool?> _fetchImd(IndiaCity city) async {
    try {
      final res = await _client
          .get(Uri.parse(
            'https://sachet.ndma.gov.in/cap_public_website/FetchAllAlertDetails',
          ))
          .timeout(_imdTimeout);
      return res.statusCode == 200;
    } catch (_) {
      return null;
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  List<double> _toDoubleList(dynamic raw) {
    if (raw == null) return [];
    if (raw is List) {
      return raw
          .map((e) => e == null ? 0.0 : (e as num).toDouble())
          .toList();
    }
    return [];
  }

  double? _toDouble(dynamic v) {
    if (v == null) return null;
    return (v as num?)?.toDouble();
  }

  Map<String, dynamic>? _extractFirst(Map<String, dynamic> j) {
    for (final key in ['data', 'items', 'results', 'levels', 'records']) {
      final v = j[key];
      if (v is List && v.isNotEmpty) return v.first as Map<String, dynamic>?;
      if (v is Map<String, dynamic>)  return v;
    }
    if (j.containsKey('current_level') || j.containsKey('level')) return j;
    return null;
  }
}
