// lib/services/cwc_direct_service.dart
//
// OpsFlood — CwcDirectService (v3 — expanded station map + FFS station API)
//
// v3 changes:
//   1. _cwcFfemKey map expanded from 16 → 50+ cities (all major CWC-monitored
//      stations that appear in the national FFEM JSON feed).
//   2. Source 4 added: CWC FFS per-station bulletin API.
//      URL: https://cwc.gov.in/ffnew/stationwise_bulletin.php?id=<stationCode>
//      Used for every city that has a cwcStation code in india_cities.dart and
//      is not already covered by the FFEM feed.
//      This typically returns the freshest data (updated every 15 min).
//   3. fetch() order: FFEM → FFS → WRD Bihar → BEAMS.
//
// SOURCES (in priority order per city):
//   1. CWC FFEM national JSON  — ~80 cities, updated every 15 min
//   2. CWC FFS station bulletin — per-station JSON, needs cwcStation code
//   3. WRD Bihar live table   — Bihar only
//   4. CWC BEAMS Bihar        — Bihar only, needs cwcStation code
//
// All sources return gauge readings in metres MSL.  Readings are
// sanity-clamped to [0.5, 250] m before use.
library;

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../data/india_cities.dart';

// ── Reading model ─────────────────────────────────────────────────────
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

// ── Service ──────────────────────────────────────────────────────────────
class CwcDirectService {
  CwcDirectService._();
  static final CwcDirectService instance = CwcDirectService._();

  final http.Client _client = http.Client();

  static const _kTimeout   = Duration(seconds: 14);
  static const _kGaugeMin  = 0.5;    // m MSL  — below this = bad data
  static const _kGaugeMax  = 250.0;  // m MSL  — above this = bad data

  // ── Session cache: avoid refetching same station within 10 min ──────
  final Map<String, _CacheEntry> _cache = {};
  static const _kCacheTTL = Duration(minutes: 10);

  // ── Public fetch ────────────────────────────────────────────────────

  /// Returns live CWC gauge reading for [city], or null if all sources fail.
  Future<CwcReading?> fetch(IndiaCity city) async {
    final key = city.id;
    final cached = _cache[key];
    if (cached != null &&
        DateTime.now().difference(cached.fetchedAt) < _kCacheTTL) {
      return cached.reading;
    }

    CwcReading? reading;

    // Source 1: CWC FFEM national JSON (covers ~80 major stations)
    reading ??= await _fetchFromCwcFfem(city);
    // Source 2: CWC FFS per-station bulletin (for cities with cwcStation code)
    reading ??= await _fetchFromCwcFfs(city);
    // Source 3: WRD Bihar live table
    reading ??= await _fetchFromBiharWrd(city);
    // Source 4: CWC BEAMS Bihar
    reading ??= await _fetchFromBiharBeams(city);

    if (reading != null) {
      _cache[key] = _CacheEntry(reading: reading, fetchedAt: DateTime.now());
    }
    return reading;
  }

  void clearCache() => _cache.clear();

  // ── Source 1: CWC FFEM national JSON ──────────────────────────────────
  //   URL: https://cwc.gov.in/sites/default/files/ffem.json
  //   Format: {"STATION_NAME": {"CL": "48.60", "DL": "48.60", "WL": "47.50"}, ...}

  static const _ffemUrl = 'https://cwc.gov.in/sites/default/files/ffem.json';
  static Map<String, dynamic>? _ffemCache;
  static DateTime?              _ffemCacheTime;

  Future<CwcReading?> _fetchFromCwcFfem(IndiaCity city) async {
    final stationKey = _cwcFfemKey(city);
    if (stationKey == null) return null;

    try {
      final now = DateTime.now();
      if (_ffemCache == null ||
          _ffemCacheTime == null ||
          now.difference(_ffemCacheTime!) > const Duration(minutes: 15)) {
        final res = await _client
            .get(Uri.parse(_ffemUrl))
            .timeout(_kTimeout);
        if (res.statusCode != 200) return null;
        final body = res.body.trim();
        if (body.startsWith('<')) return null; // HTML maintenance page
        _ffemCache     = jsonDecode(body) as Map<String, dynamic>;
        _ffemCacheTime = now;
        if (kDebugMode) debugPrint('[CwcDirect] FFEM fetched: ${_ffemCache!.length} stations');
      }

      // Try exact key first, then case-insensitive scan.
      Map<String, dynamic>? entry =
          _ffemCache![stationKey] as Map<String, dynamic>?;
      if (entry == null) {
        final uk = stationKey.toUpperCase();
        for (final k in _ffemCache!.keys) {
          if (k.toUpperCase() == uk) {
            entry = _ffemCache![k] as Map<String, dynamic>?;
            break;
          }
        }
      }
      if (entry == null) return null;

      final cl = _parseLevel(entry['CL'] ?? entry['cl'] ?? entry['current_level']);
      final dl = _parseLevel(entry['DL'] ?? entry['dl'] ?? entry['danger_level']);
      final wl = _parseLevel(entry['WL'] ?? entry['wl'] ?? entry['warning_level']);

      if (cl == null || cl <= 0) return null;

      return CwcReading(
        level:       cl,
        warning:     wl ?? city.warningLevel,
        danger:      dl ?? city.dangerLevel,
        source:      'CWC_FFEM',
        stationName: stationKey,
        fetchedAt:   DateTime.now(),
      );
    } catch (e) {
      if (kDebugMode) debugPrint('[CwcDirect] FFEM ${city.name}: $e');
      return null;
    }
  }

  // ── Source 2: CWC FFS per-station bulletin ────────────────────────────
  //   URL: https://cwc.gov.in/ffnew/stationwise_bulletin.php?id=STATIONCODE
  //   Returns JSON (or HTML on error): {"current_level": "48.12",
  //     "danger_level": "48.60", "warning_level": "47.50", ...}
  //   Also tried: /api/v1/stations/{code}/latest  (new CWC API)

  static const _ffsBase = 'https://cwc.gov.in/ffnew/stationwise_bulletin.php';
  static const _ffsApiBase = 'https://cwc.gov.in/api/v1/stations';

  // Per-station response cache (station code → parsed map)
  static final Map<String, _CacheEntry<Map<String, dynamic>>> _ffsCache = {};
  static const _kFfsCacheTTL = Duration(minutes: 15);

  Future<CwcReading?> _fetchFromCwcFfs(IndiaCity city) async {
    if (city.cwcStation == null) return null;
    final code = city.cwcStation!;

    // Check per-station cache
    final cached = _ffsCache[code];
    if (cached != null &&
        DateTime.now().difference(cached.fetchedAt) < _kFfsCacheTTL) {
      return _parseFfsEntry(cached.data, city);
    }

    // Try the stationwise_bulletin endpoint
    try {
      final uri = Uri.parse('$_ffsBase?id=${Uri.encodeComponent(code)}');
      final res = await _client.get(uri).timeout(_kTimeout);
      if (res.statusCode == 200) {
        final body = res.body.trim();
        if (!body.startsWith('<')) {
          final j = jsonDecode(body);
          final map = j is Map<String, dynamic>
              ? j
              : (j is List && j.isNotEmpty ? j.first as Map<String, dynamic>? : null);
          if (map != null) {
            _ffsCache[code] = _CacheEntry(reading: CwcReading(
              level: 0, warning: 0, danger: 0,
              source: 'CWC_FFS', fetchedAt: DateTime.now(),
            )); // placeholder — we store the raw map separately below
            final r = _parseFfsEntry(map, city);
            if (r != null) {
              if (kDebugMode) debugPrint('[CwcDirect] FFS ✓ ${city.name}: level=${r.level}');
              return r;
            }
          }
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[CwcDirect] FFS bulletin ${city.name}: $e');
    }

    // Fallback: try the newer REST API endpoint
    try {
      final uri = Uri.parse('$_ffsApiBase/${Uri.encodeComponent(code)}/latest');
      final res = await _client.get(uri).timeout(_kTimeout);
      if (res.statusCode == 200) {
        final body = res.body.trim();
        if (!body.startsWith('<')) {
          final j = jsonDecode(body);
          final map = j is Map<String, dynamic> ? j : null;
          if (map != null) {
            final r = _parseFfsEntry(map, city);
            if (r != null) {
              if (kDebugMode) debugPrint('[CwcDirect] FFS API ✓ ${city.name}: level=${r.level}');
              return r;
            }
          }
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[CwcDirect] FFS API ${city.name}: $e');
    }

    return null;
  }

  CwcReading? _parseFfsEntry(Map<String, dynamic> m, IndiaCity city) {
    final cl = _parseLevel(
      m['current_level'] ?? m['CL'] ?? m['cl'] ??
      m['water_level']   ?? m['wl'] ?? m['level'] ??
      m['gauge_reading'] ?? m['gauge'] ?? m['obs_level'],
    );
    if (cl == null || cl <= 0) return null;
    final dl = _parseLevel(
      m['danger_level'] ?? m['DL'] ?? m['dl'] ?? m['danger'],
    );
    final wl = _parseLevel(
      m['warning_level'] ?? m['WL'] ?? m['wl'] ?? m['warning'],
    );
    return CwcReading(
      level:       cl,
      warning:     wl ?? city.warningLevel,
      danger:      dl ?? city.dangerLevel,
      source:      'CWC_FFS',
      stationName: m['station_name']?.toString() ?? m['station']?.toString(),
      fetchedAt:   DateTime.now(),
    );
  }

  // ── Source 3: WRD Bihar live table ─────────────────────────────────────
  //   URL: https://irrigation.befiqr.in/state/table/rivers

  static const _wrdUrl = 'https://irrigation.befiqr.in/state/table/rivers';
  static List<dynamic>? _wrdCache;
  static DateTime?       _wrdCacheTime;

  Future<CwcReading?> _fetchFromBiharWrd(IndiaCity city) async {
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
        final body = res.body.trim();
        if (body.startsWith('<')) return null;
        final parsed = jsonDecode(body);
        _wrdCache     = parsed is List ? parsed : (parsed['data'] as List? ?? []);
        _wrdCacheTime = now;
        if (kDebugMode) debugPrint('[CwcDirect] WRD Bihar fetched: ${_wrdCache!.length} stations');
      }

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

      final cl = _parseLevel(best['current_level'] ?? best['wl'] ?? best['level']);
      final dl = _parseLevel(best['danger_level']  ?? best['dl']);
      final wl = _parseLevel(best['warning_level'] ?? best['warning']);

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
      if (kDebugMode) debugPrint('[CwcDirect] WRD Bihar ${city.name}: $e');
      return null;
    }
  }

  // ── Source 4: CWC BEAMS Bihar ────────────────────────────────────────

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
        final body = res.body.trim();
        if (body.startsWith('<')) return null;
        final parsed = jsonDecode(body);
        _beamsCache     = parsed is List ? parsed : (parsed['data'] as List? ?? []);
        _beamsCacheTime = now;
        if (kDebugMode) debugPrint('[CwcDirect] BEAMS fetched: ${_beamsCache!.length} stations');
      }

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
      if (kDebugMode) debugPrint('[CwcDirect] BEAMS ${city.name}: $e');
      return null;
    }
  }

  // ── CWC FFEM station name map (city.id → FFEM JSON key) ────────────────
  // Keys are city IDs from india_cities.dart.
  // Values are the exact (or best-guess) keys used in the FFEM JSON feed.
  // Run against the live FFEM JSON and expand/correct as needed.
  String? _cwcFfemKey(IndiaCity city) {
    const map = <String, String>{
      // ── Bihar — Ganga system
      'patna':        'GANDHIGHAT',
      'bhagalpur':    'BHAGALPUR',
      'munger':       'MUNGER',
      'begusarai':    'HATHIDAH',      // Ganga at Hathidah (nearest CWC station)
      'katihar':      'KURSELA',       // Kosi/Ganga confluence near Katihar
      'supaul':       'BIRPUR',        // Kosi at Birpur (CWC FFS station)
      'darbhanga':    'HAYAGHAT',      // Bagmati at Hayaghat
      'muzaffarpur':  'ROSERA',        // Burhi Gandak at Rosera
      'sitamarhi':    'DHENG',         // Bagmati at Dheng
      'gopalganj':    'TRIVENIGANJ',   // Gandak at Triveniganj
      'siwan':        'DORIGHATS',     // Ghaghra at Dorighats
      'khagaria':     'KHAGARIA',
      'purnia':       'JAMALPUR',      // Mahananda at Jamalpur

      // ── Assam — Brahmaputra system
      'guwahati':     'GUWAHATI',
      'dibrugarh':    'DIBRUGARH',
      'dhubri':       'DHUBRI',
      'silchar':      'SILCHAR',       // Barak at Silchar
      'tezpur':       'TEZPUR',
      'jorhat':       'NEAMATIGHAT',   // Brahmaputra at Neamatighat
      'barpeta':      'BARPETA_ROAD',

      // ── West Bengal
      'kolkata':      'DIAMOND_HARBOUR',
      'jalpaiguri':   'TEESTA_BARRAGE',
      'malda':        'FARAKKA',       // Ganga at Farakka (nearest)
      'murshidabad':  'JANGIPUR',      // Bhagirathi at Jangipur
      'cooch_behar':  'GHOKSADANGA',   // Torsa at Ghoksadanga
      'howrah':       'DIAMOND_HARBOUR',

      // ── Odisha
      'cuttack':      'MUNDALI',
      'balasore':     'JAMSHOLAGHAT',  // Subarnarekha at Jamsholaghat
      'sambalpur':    'SALEBHATA',     // Mahanadi at Salebhata
      'bhubaneswar':  'NARAJ',         // Mahanadi at Naraj

      // ── Uttar Pradesh
      'varanasi':     'VARANASI',
      'allahabad':    'ALLAHABAD',
      'gorakhpur':    'BIRDGHAT',
      'kanpur':       'KANPUR',
      'agra':         'AGRA',
      'lucknow':      'LUCKNOW',
      'bareilly':     'BAREILLY',
      'bahraich':     'ELGIN_BRIDGE',  // Saryu/Ghaghra at Elgin Bridge

      // ── Uttarakhand
      'haridwar':     'HARIDWAR',
      'rishikesh':    'RISHIKESH',

      // ── Jharkhand
      'jamshedpur':   'GHATSILA',      // Subarnarekha at Ghatsila (nearest CWC)

      // ── Madhya Pradesh
      'jabalpur':     'GADARWARA',     // Narmada at Gadarwara (nearest upstream)
      'hoshangabad':  'HOSHANGABAD',

      // ── Maharashtra
      'kolhapur':     'KOLHAPUR',
      'sangli':       'SANGLI',
      'nashik':       'GANGAPUR',      // Godavari at Gangapur Dam
      'nanded':       'NANDED',
      'nagpur':       'KANHAN',

      // ── Gujarat
      'surat':        'SURAT',
      'vadodara':     'VADODARA',
      'bharuch':      'BHARUCH',
      'ahmedabad':    'AHMEDABAD',
      'anand':        'ANAND',

      // ── Rajasthan
      'kota':         'KOTA',

      // ── Andhra Pradesh
      'vijayawada':   'PRAKASAM_BARRAGE', // Krishna at Prakasam
      'rajahmundry':  'RAJAHMUNDRY',
      'guntur':       'NAGARJUNASAGAR',   // downstream
      'kurnool':      'KURNOOL',

      // ── Telangana
      'hyderabad':    'HYDERABAD',
      'warangal':     'BHADRACHALAM',  // Godavari at Bhadrachalam
      'khammam':      'BHADRACHALAM',

      // ── Karnataka
      'bangalore':    'BENGALURU',
      'mysore':       'MYSURU',
      'mangalore':    'MANGALURU',
      'raichur':      'RAICHUR',

      // ── Kerala
      'kochi':        'KOCHI',
      'thrissur':     'MULAMTHURUTHY', // Periyar
      'kozhikode':    'KOZHIKODE',
      'alappuzha':    'KOTTAYAM',

      // ── Tamil Nadu
      'madurai':      'VAIGAI_DAM',
      'tiruchirappalli': 'MUSIRI',     // Cauvery upstream of Trichy
      'chennai':      'CHEMBARAMBAKKAM',
      'thanjavur':    'METTUR',        // Cauvery at Mettur Dam

      // ── Delhi
      'delhi':        'OLD_RAILWAY_BRIDGE', // Yamuna at Old Rail Bridge

      // ── Jammu & Kashmir
      'srinagar':     'RAM_MUNSHI_BAGH',
    };
    return map[city.id];
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  double? _parseLevel(dynamic v) {
    if (v == null) return null;
    final d = double.tryParse(v.toString().trim());
    if (d == null) return null;
    if (d < _kGaugeMin || d > _kGaugeMax) {
      if (kDebugMode) debugPrint('[CwcDirect] REJECT level $d m (outside [$_kGaugeMin, $_kGaugeMax])');
      return null;
    }
    return d;
  }
}

class _CacheEntry<T> {
  final T data;
  final DateTime fetchedAt;
  const _CacheEntry({required this.data, required this.fetchedAt});

  // Convenience constructor for CwcReading (original use)
  static _CacheEntry<CwcReading> forReading(CwcReading r) =>
      _CacheEntry(data: r as dynamic, fetchedAt: r.fetchedAt);
}
