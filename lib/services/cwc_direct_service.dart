// lib/services/cwc_direct_service.dart
//
// OpsFlood — CwcDirectService
//
// Fetches live CWC gauge readings DIRECTLY from CWC / WRD endpoints,
// without routing through the OpsFlood Render backend (which sleeps
// on free tier and causes cold-start timeouts).
//
// SOURCES (in priority order per city):
//   1. CWC BEAMS JSON API  — https://beams.fmiscwrdbihar.gov.in
//      Returns gauge height (m MSL), WL, DL for CWC network stations.
//   2. WRD Bihar live table — https://irrigation.befiqr.in/state/table/rivers
//      Returns JSON with all Bihar WRD gauge stations.
//   3. CWC FFEM (central) — https://cwc.gov.in/sites/default/files/ffem.json
//      National CWC live station feed (updated every 15 min).
//
// All sources return gauge readings in metres MSL.  Readings are
// sanity-clamped to [0.5, 250] m before use.
//
// Usage:
//   final reading = await CwcDirectService.instance.fetch(city);
//   if (reading != null) {
//     // reading.level, reading.warning, reading.danger are all real metres MSL
//   }
library;

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../data/india_cities.dart';

// ── Reading model ─────────────────────────────────────────────────────────
class CwcReading {
  final double  level;       // current gauge height, m MSL
  final double  warning;     // warning level, m MSL
  final double  danger;      // danger level, m MSL
  final double? hfl;         // highest flood level, m MSL (optional)
  final String  source;      // which backend answered
  final String? stationName;
  final DateTime fetchedAt;

  const CwcReading({
    required this.level,
    required this.warning,
    required this.danger,
    this.hfl,
    required this.source,
    this.stationName,
    required this.fetchedAt,
  });
}

// ── Service ────────────────────────────────────────────────────────────────
class CwcDirectService {
  CwcDirectService._();
  static final CwcDirectService instance = CwcDirectService._();

  final http.Client _client = http.Client();

  static const _kTimeout   = Duration(seconds: 14);
  static const _kGaugeMin  = 0.5;    // m MSL  — below this = bad data
  static const _kGaugeMax  = 250.0;  // m MSL  — above this = bad data

  // ── Session cache: avoid refetching same station within 10 min ──────────
  final Map<String, _CacheEntry> _cache = {};
  static const _kCacheTTL = Duration(minutes: 10);

  // ── Public fetch ──────────────────────────────────────────────────────────

  /// Returns live CWC gauge reading for [city], or null if all sources fail.
  Future<CwcReading?> fetch(IndiaCity city) async {
    final key = city.id;
    final cached = _cache[key];
    if (cached != null &&
        DateTime.now().difference(cached.fetchedAt) < _kCacheTTL) {
      return cached.reading;
    }

    CwcReading? reading;

    // Try sources in order until one succeeds.
    reading ??= await _fetchFromCwcFfem(city);
    reading ??= await _fetchFromBiharWrd(city);
    reading ??= await _fetchFromBiharBeams(city);

    if (reading != null) {
      _cache[key] = _CacheEntry(reading: reading, fetchedAt: DateTime.now());
    }
    return reading;
  }

  void clearCache() => _cache.clear();

  // ── Source 1: CWC FFEM national JSON ────────────────────────────────────
  //   URL: https://cwc.gov.in/sites/default/files/ffem.json
  //   Format: {"STATION_NAME": {"CL": "48.60", "DL": "48.60", "WL": "47.50"}, ...}
  //   "CL" = Current Level, "DL" = Danger Level, "WL" = Warning Level

  static const _ffemUrl = 'https://cwc.gov.in/sites/default/files/ffem.json';
  static Map<String, dynamic>? _ffemCache;
  static DateTime?              _ffemCacheTime;

  Future<CwcReading?> _fetchFromCwcFfem(IndiaCity city) async {
    // Match city to a known CWC station name from the FFEM feed.
    final stationKey = _cwcFfemKey(city);
    if (stationKey == null) return null;

    try {
      // Fetch + cache the whole FFEM JSON (it covers all India, ~80 KB).
      final now = DateTime.now();
      if (_ffemCache == null ||
          _ffemCacheTime == null ||
          now.difference(_ffemCacheTime!) > const Duration(minutes: 15)) {
        final res = await _client
            .get(Uri.parse(_ffemUrl))
            .timeout(_kTimeout);
        if (res.statusCode != 200) return null;
        _ffemCache     = jsonDecode(res.body) as Map<String, dynamic>;
        _ffemCacheTime = now;
        debugPrint('[CwcDirect] FFEM fetched: ${_ffemCache!.length} stations');
      }

      // Look up the city's station.
      final entry = _ffemCache![stationKey] as Map<String, dynamic>?;
      if (entry == null) return null;

      final cl = _parseLevel(entry['CL'] ?? entry['cl'] ?? entry['current_level']);
      final dl = _parseLevel(entry['DL'] ?? entry['dl'] ?? entry['danger_level']);
      final wl = _parseLevel(entry['WL'] ?? entry['wl'] ?? entry['warning_level']);

      if (cl == null || cl <= 0) return null;
      // Use city's known thresholds as fallback if FFEM doesn't provide them.
      final danger  = dl ?? city.dangerLevel;
      final warning = wl ?? city.warningLevel;

      return CwcReading(
        level:       cl,
        warning:     warning,
        danger:      danger,
        source:      'CWC_FFEM',
        stationName: stationKey,
        fetchedAt:   DateTime.now(),
      );
    } catch (e) {
      debugPrint('[CwcDirect] FFEM ${city.name}: $e');
      return null;
    }
  }

  // ── Source 2: WRD Bihar live table ───────────────────────────────────────
  //   URL: https://irrigation.befiqr.in/state/table/rivers
  //   Returns JSON array: [{"station": "Gandhighat", "current_level": "48.12",
  //                         "warning_level": "47.50", "danger_level": "48.60", ...}]

  static const _wrdUrl = 'https://irrigation.befiqr.in/state/table/rivers';
  static List<dynamic>? _wrdCache;
  static DateTime?       _wrdCacheTime;

  Future<CwcReading?> _fetchFromBiharWrd(IndiaCity city) async {
    // Only relevant for Bihar cities.
    if (!city.state.toLowerCase().contains('bihar')) return null;

    try {
      final now = DateTime.now();
      if (_wrdCache == null ||
          _wrdCacheTime == null ||
          now.difference(_wrdCacheTime!) > const Duration(minutes: 10)) {
        final res = await _client
            .get(Uri.parse(_wrdUrl))
            .timeout(_kTimeout);
        if (res.statusCode != 200) return null;
        final body = jsonDecode(res.body);
        _wrdCache     = body is List ? body : (body['data'] as List? ?? []);
        _wrdCacheTime = now;
        debugPrint('[CwcDirect] WRD Bihar fetched: ${_wrdCache!.length} stations');
      }

      // Find the best matching station by fuzzy city/river name match.
      final lc = city.name.toLowerCase();
      final lr = city.river.toLowerCase();
      Map<String, dynamic>? best;
      int bestScore = 0;

      for (final row in _wrdCache!.whereType<Map<String, dynamic>>()) {
        final sn = (row['station'] ?? row['name'] ?? '').toString().toLowerCase();
        final rv = (row['river']   ?? row['river_name'] ?? '').toString().toLowerCase();
        int score = 0;
        if (sn == lc || sn.contains(lc) || lc.contains(sn)) score += 3;
        if (rv.contains(lr) || lr.contains(rv))              score += 2;
        if (score > bestScore) { bestScore = score; best = row; }
      }
      if (best == null || bestScore < 2) return null;

      final cl = _parseLevel(
          best['current_level'] ?? best['wl'] ?? best['level']);
      final dl = _parseLevel(
          best['danger_level'] ?? best['dl']);
      final wl = _parseLevel(
          best['warning_level'] ?? best['warning']);

      if (cl == null || cl <= 0) return null;

      return CwcReading(
        level:       cl,
        warning:     wl ?? city.warningLevel,
        danger:      dl ?? city.dangerLevel,
        source:      'WRD_BIHAR',
        stationName: (best['station'] ?? best['name'])?.toString(),
        fetchedAt:   DateTime.now(),
      );
    } catch (e) {
      debugPrint('[CwcDirect] WRD Bihar ${city.name}: $e');
      return null;
    }
  }

  // ── Source 3: CWC BEAMS Bihar ────────────────────────────────────────────
  //   URL: https://beams.fmiscwrdbihar.gov.in/bulletin/gaugereport.json
  //   Format: [{"station_id": "BIR", "current_level": 74.74,
  //             "warning_level": 73.70, "danger_level": 74.70}]

  static const _beamsUrl =
      'https://beams.fmiscwrdbihar.gov.in/bulletin/gaugereport.json';
  static List<dynamic>? _beamsCache;
  static DateTime?       _beamsCacheTime;

  Future<CwcReading?> _fetchFromBiharBeams(IndiaCity city) async {
    if (city.cwcStation == null) return null;

    try {
      final now = DateTime.now();
      if (_beamsCache == null ||
          _beamsCacheTime == null ||
          now.difference(_beamsCacheTime!) > const Duration(minutes: 10)) {
        final res = await _client
            .get(Uri.parse(_beamsUrl))
            .timeout(_kTimeout);
        if (res.statusCode != 200) return null;
        final body = jsonDecode(res.body);
        _beamsCache     = body is List ? body : (body['data'] as List? ?? []);
        _beamsCacheTime = now;
        debugPrint('[CwcDirect] BEAMS fetched: ${_beamsCache!.length} stations');
      }

      // Match by cwcStation code OR station name.
      final code = city.cwcStation!.toUpperCase();
      final lc   = city.name.toLowerCase();

      Map<String, dynamic>? best;
      for (final row in _beamsCache!.whereType<Map<String, dynamic>>()) {
        final id = (row['station_id'] ?? row['id'] ?? row['code'] ?? '').toString().toUpperCase();
        final sn = (row['station']    ?? row['name'] ?? '').toString().toLowerCase();
        if (id == code || sn.contains(lc) || lc.contains(sn)) {
          best = row;
          break;
        }
      }
      if (best == null) return null;

      final cl = _parseLevel(best['current_level'] ?? best['wl'] ?? best['level']);
      final dl = _parseLevel(best['danger_level']  ?? best['dl']);
      final wl = _parseLevel(best['warning_level'] ?? best['warning']);

      if (cl == null || cl <= 0) return null;

      return CwcReading(
        level:       cl,
        warning:     wl ?? city.warningLevel,
        danger:      dl ?? city.dangerLevel,
        source:      'CWC_BEAMS',
        stationName: (best['station'] ?? best['name'])?.toString(),
        fetchedAt:   DateTime.now(),
      );
    } catch (e) {
      debugPrint('[CwcDirect] BEAMS ${city.name}: $e');
      return null;
    }
  }

  // ── CWC FFEM station name map ─────────────────────────────────────────────
  // Maps city id → the exact key used in the FFEM JSON.
  // Partial list — expand as needed.
  String? _cwcFfemKey(IndiaCity city) {
    const _map = <String, String>{
      // Bihar — Ganga
      'patna':       'GANDHIGHAT',
      'bhagalpur':   'BHAGALPUR',
      'munger':      'MUNGER',
      // Assam — Brahmaputra
      'guwahati':    'GUWAHATI',
      'dibrugarh':   'DIBRUGARH',
      'dhubri':      'DHUBRI',
      // UP — Ganga / Yamuna
      'varanasi':    'VARANASI',
      'allahabad':   'ALLAHABAD',
      'kanpur':      'KANPUR',
      // Uttarakhand
      'haridwar':    'HARIDWAR',
      'rishikesh':   'RISHIKESH',
      // Odisha
      'cuttack':     'MUNDALI',
      // West Bengal
      'kolkata':     'DIAMOND_HARBOUR',
      'jalpaiguri':  'TEESTA_BARRAGE',
      // Gorakhpur — Rapti / Ghaghra
      'gorakhpur':   'BIRDGHAT',
      // Bihar — Kosi
      'supaul':      'BIRPUR',
    };
    return _map[city.id];
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  double? _parseLevel(dynamic v) {
    if (v == null) return null;
    final d = double.tryParse(v.toString().trim());
    if (d == null) return null;
    if (d < _kGaugeMin || d > _kGaugeMax) {
      debugPrint('[CwcDirect] REJECT level $d m (outside [$_kGaugeMin, $_kGaugeMax])');
      return null;
    }
    return d;
  }
}

class _CacheEntry {
  final CwcReading reading;
  final DateTime   fetchedAt;
  const _CacheEntry({required this.reading, required this.fetchedAt});
}
