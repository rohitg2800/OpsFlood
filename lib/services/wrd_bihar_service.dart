// lib/services/wrd_bihar_service.dart
//
// OpsFlood — WRD Bihar Service (v4.0)
//
// SOURCE: OpsFlood FastAPI backend → Central Flood Control Cell, WRD Patna
// BACKEND ENDPOINT: /api/wrd-bihar/stations
// FALLBACK: https://irrigation.befiqr.in/state/table/rivers (direct scrape)
//
// v4.0 CHANGES:
//   ─ Primary source is now the FastAPI backend (/api/wrd-bihar/stations)
//   ─ Backend returns pre-parsed JSON — no HTML scraping needed for primary path
//   ─ Direct BeFIQR scrape is kept as fallback only
//   ─ Cache TTL aligned with backend scheduler (15 min)
//   ─ forceRefresh=true hits backend /api/wrd-bihar/refresh first, then /stations
library;

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';

// ── Data model ────────────────────────────────────────────────────────────────
class WrdStation {
  final String  river;
  final String  site;
  final String  district;
  final double? hfl;
  final double? dangerLevel;
  final double? warningLevel;
  final double? prevLevel;
  final double? currentLevel;
  final double? diff24h;
  final double? belowDanger;
  final String? trend;
  final String  source;
  final DateTime fetchedAt;

  const WrdStation({
    required this.river,
    required this.site,
    required this.district,
    this.hfl,
    this.dangerLevel,
    this.warningLevel,
    this.prevLevel,
    this.currentLevel,
    this.diff24h,
    this.belowDanger,
    this.trend,
    required this.source,
    required this.fetchedAt,
  });

  bool get hasLiveData   => currentLevel != null;
  bool get hasDangerLevel => dangerLevel != null && dangerLevel! > 0;

  String get displayLevel {
    if (currentLevel != null) return '${currentLevel!.toStringAsFixed(2)} m';
    return 'NA';
  }

  String get displayDanger {
    if (dangerLevel != null) return '${dangerLevel!.toStringAsFixed(2)} m';
    return '—';
  }

  String get displayWarning {
    if (warningLevel != null) return '${warningLevel!.toStringAsFixed(2)} m';
    return '—';
  }

  String get displayDiff {
    if (diff24h == null) return '—';
    final sign = diff24h! >= 0 ? '+' : '';
    return '$sign${diff24h!.toStringAsFixed(2)} m';
  }

  String get riskLabel {
    final bd = belowDanger;
    if (!hasLiveData && !hasDangerLevel) return 'PRE-MONSOON';
    if (!hasLiveData) return 'NA';
    if (bd == null && dangerLevel == null) return 'UNKNOWN';
    final margin = bd ?? (dangerLevel! - currentLevel!);
    if (margin <= 0)   return 'CRITICAL';
    if (margin <= 1.0) return 'HIGH';
    if (margin <= 2.5) return 'MODERATE';
    return 'LOW';
  }

  double? get percentOfDanger {
    if (currentLevel == null || dangerLevel == null || dangerLevel! <= 0) return null;
    return (currentLevel! / dangerLevel!) * 100.0;
  }

  String get displayPctOfDanger {
    final p = percentOfDanger;
    if (p == null) return '—';
    return '${p.toStringAsFixed(0)}%';
  }

  String get displayBelowDanger {
    if (belowDanger != null) return '${belowDanger!.toStringAsFixed(2)} m';
    if (currentLevel != null && dangerLevel != null) {
      return '${(dangerLevel! - currentLevel!).toStringAsFixed(2)} m';
    }
    return '—';
  }

  @override
  String toString() =>
      'WrdStation($river @ $site | cur=$displayLevel | '
      'DL=$displayDanger | bd=$displayBelowDanger | '
      'risk=$riskLabel | live=$hasLiveData)';
}

// ── WRD ⇒ alias map ───────────────────────────────────────────────────────────
const Map<String, String> _kAliasMap = {
  'ekmighat':                  'Ekmighat',
  'kamtaul':                   'Kamtaul',
  'sonbarsa':                  'Sonbarsa',
  'benibad':                   'Benibad',
  'dheng bridge':              'Dheng Bridge',
  'hayaghat':                  'Hayaghat',
  'khagaria':                  'Khagaria',
  'rosera':                    'Rosera',
  'samastipur':                'Samastipur',
  'sikandarpur (muzzafarpur)': 'Sikandarpur',
  'sikandarpur':               'Sikandarpur',
  'chatia':                    'Chatia',
  'dumariaghat':               'Dumariaghat',
  'hajipur':                   'Hajipur',
  'rewaghat':                  'Rewaghat',
  'bhagalpur':                 'Bhagalpur',
  'buxar':                     'Buxar',
  'dighaghat':                 'Dighaghat',
  'gandhighat':                'Gandhighat',
  'hathidah':                  'Hathidah',
  'kahalgaon':                 'Kahalgaon',
  'munger':                    'Munger',
  'darauli':                   'Darauli',
  'gangpur siswan':            'Gangpur Siswan',
  'jhanjharpur':               'Jhanjharpur',
  'jainagar':                  'Jainagar',
  'baltara':                   'Baltara',
  'basua':                     'Basua',
  'kursela':                   'Kursela',
  'dhengraghat':               'Dhengraghat',
  'taibpur':                   'Taibpur',
  'sripalpur':                 'Sripalpur',
};

// ── Service ───────────────────────────────────────────────────────────────────
class WrdBiharService {
  WrdBiharService._();
  static final WrdBiharService instance = WrdBiharService._();

  // Backend endpoint (primary) — same server the Flutter app talks to
  static String get _backendStationsUrl =>
      '${AppConfig.baseUrl}/api/wrd-bihar/stations';
  static String get _backendRefreshUrl =>
      '${AppConfig.baseUrl}/api/wrd-bihar/refresh';

  // Direct BeFIQR scrape (fallback only)
  static const _fallbackUrl =
      'https://irrigation.befiqr.in/state/table/rivers';

  // Cache TTL aligned with backend APScheduler (15 min)
  static const _cacheTtl = Duration(minutes: 15);
  static const _source   = 'WRD_BIHAR';

  List<WrdStation>?        _cache;
  DateTime?                _cacheTime;
  Map<String, WrdStation>? _stationByCity;

  // ── Public API ────────────────────────────────────────────────────────────
  Future<List<WrdStation>> fetch({bool forceRefresh = false}) async {
    // Serve from in-memory cache if still fresh
    if (!forceRefresh &&
        _cache != null &&
        _cacheTime != null &&
        DateTime.now().difference(_cacheTime!) < _cacheTtl) {
      if (kDebugMode) debugPrint('[WrdBihar] serving ${_cache!.length} stations from cache');
      return _cache!;
    }

    // If force-refresh, tell the backend to scrape fresh data first
    if (forceRefresh) {
      try {
        await http
            .get(Uri.parse(_backendRefreshUrl))
            .timeout(const Duration(seconds: 10));
        if (kDebugMode) debugPrint('[WrdBihar] backend refresh triggered');
      } catch (e) {
        if (kDebugMode) debugPrint('[WrdBihar] backend refresh skipped: $e');
      }
    }

    // Primary: FastAPI backend JSON
    try {
      final stations = await _fetchFromBackend();
      if (stations.isNotEmpty) {
        _cache     = stations;
        _cacheTime = DateTime.now();
        _buildCityIndex(stations);
        if (kDebugMode) debugPrint('[WrdBihar] ✓ ${stations.length} stations (backend)');
        return stations;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[WrdBihar] backend failed: $e');
    }

    // Fallback: direct BeFIQR HTML scrape
    try {
      final stations = await _fetchFromFallback();
      if (stations.isNotEmpty) {
        _cache     = stations;
        _cacheTime = DateTime.now();
        _buildCityIndex(stations);
        if (kDebugMode) debugPrint('[WrdBihar] ✓ ${stations.length} stations (direct fallback)');
        return stations;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[WrdBihar] fallback failed: $e');
    }

    return _cache ?? [];
  }

  Future<WrdStation?> fetchBestMatch(String city, {String? river}) async {
    await fetch();
    final lc     = city.toLowerCase().trim();
    final byAlias = _stationByCity?[lc];
    if (byAlias != null) return byAlias;
    final all        = _cache ?? [];
    final candidates = all
        .where((s) =>
            s.site.toLowerCase().contains(lc) ||
            s.district.toLowerCase().contains(lc))
        .toList();
    if (candidates.isEmpty) return null;
    if (river != null) {
      final rv      = river.toLowerCase();
      final byRiver = candidates
          .where((s) => s.river.toLowerCase().contains(rv))
          .toList();
      if (byRiver.isNotEmpty) return byRiver.first;
    }
    final withLevel = candidates.where((s) => s.hasLiveData).toList();
    return withLevel.isNotEmpty ? withLevel.first : candidates.first;
  }

  Future<List<WrdStation>> fetchForRiver(String river) async {
    final all = await fetch();
    final lc  = river.toLowerCase();
    return all.where((s) => s.river.toLowerCase().contains(lc)).toList();
  }

  Future<Map<String, List<WrdStation>>> fetchGroupedByRiver() async {
    final all = await fetch();
    final map = <String, List<WrdStation>>{};
    for (final s in all) {
      map.putIfAbsent(s.river, () => []).add(s);
    }
    for (final list in map.values) {
      list.sort((a, b) {
        if (a.hasLiveData && !b.hasLiveData) return -1;
        if (!a.hasLiveData && b.hasLiveData) return 1;
        final al = a.currentLevel ?? 0;
        final bl = b.currentLevel ?? 0;
        return bl.compareTo(al);
      });
    }
    return map;
  }

  // ── Internal ──────────────────────────────────────────────────────────────

  /// Fetch from FastAPI backend — returns pre-parsed station JSON.
  Future<List<WrdStation>> _fetchFromBackend() async {
    final res = await http
        .get(Uri.parse(_backendStationsUrl))
        .timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) {
      throw Exception('[WrdBihar] backend HTTP ${res.statusCode}');
    }
    final j = jsonDecode(res.body);
    final List raw = j is Map ? (j['stations'] as List? ?? []) : (j as List);
    return _parseBackendJson(raw);
  }

  /// Parse the JSON shape returned by /api/wrd-bihar/stations
  List<WrdStation> _parseBackendJson(List raw) {
    final now    = DateTime.now();
    final result = <WrdStation>[];
    for (final item in raw.whereType<Map>()) {
      try {
        final cur = _dbl(item['current_level_m'] ?? item['currentLevel']);
        final dl  = _dbl(item['danger_level_m']  ?? item['dangerLevel']);
        final bdRaw = _dbl(item['above_below_danger_m'] ?? item['belowDanger']);
        // above_below_danger_m from backend is positive when BELOW danger
        final bd = bdRaw ?? (cur != null && dl != null ? dl - cur : null);

        // Map backend trend string → display
        final trendRaw = (item['trend'] ?? '').toString().trim();
        final trend = trendRaw == 'RISING'  ? '↑'
                    : trendRaw == 'FALLING' ? '↓'
                    : trendRaw == 'STEADY'  ? '→'
                    : trendRaw.isNotEmpty   ? trendRaw
                    : null;

        result.add(WrdStation(
          river:        _str(item['river']    ?? item['River']),
          site:         _str(item['station']  ?? item['site'] ?? item['Site']),
          district:     _str(item['district'] ?? item['District'] ?? ''),
          hfl:          _dbl(item['hfl_m']    ?? item['hfl']),
          dangerLevel:  dl,
          warningLevel: null,
          prevLevel:    _dbl(item['yesterday_level_m'] ?? item['prevLevel']),
          currentLevel: cur,
          diff24h:      _dbl(item['change_24h_m'] ?? item['diff24h']),
          belowDanger:  bd,
          trend:        trend,
          source:       _source,
          fetchedAt:    now,
        ));
      } catch (_) {}
    }
    return result;
  }

  Future<List<WrdStation>> _fetchFromFallback() async {
    final res = await http
        .get(Uri.parse(_fallbackUrl))
        .timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) {
      throw Exception('[WrdBihar] fallback HTTP ${res.statusCode}');
    }
    return _parseHtmlTable(res.body);
  }

  void _buildCityIndex(List<WrdStation> stations) {
    final map = <String, WrdStation>{};
    for (final s in stations) {
      final alias = _kAliasMap[s.site.toLowerCase().trim()];
      if (alias != null) map[alias.toLowerCase()] = s;
    }
    _stationByCity = map;
    if (kDebugMode) {
      debugPrint('[WrdBihar] city index: ${map.length}/${stations.length} resolved');
    }
  }

  // Column layout (BeFIQR HTML fallback):
  // 0=SL 1=River 2=Site 3=HFL 4=DL 5=Yesterday 6=Current 7=Diff 8=BelowDanger 9=Trend 10=District
  List<WrdStation> _parseHtmlTable(String html) {
    final now    = DateTime.now();
    final result = <WrdStation>[];
    final rowRe  = RegExp(r'<tr[^>]*>(.*?)</tr>', dotAll: true, caseSensitive: false);
    final cellRe = RegExp(r'<t[dh][^>]*>(.*?)</t[dh]>', dotAll: true, caseSensitive: false);
    final tagRe  = RegExp(r'<[^>]+>');

    String clean(String s) =>
        s.replaceAll(tagRe, '').replaceAll('\u00a0', ' ').trim();

    final rows = rowRe.allMatches(html).toList();
    if (rows.isEmpty) return result;

    final headerCells = cellRe
        .allMatches(rows.first.group(1)!)
        .map((m) => clean(m.group(1)!).toLowerCase())
        .toList();
    final isBefiqr = headerCells.any((h) => h.contains('river'));

    for (final row in rows.skip(1)) {
      final cells = cellRe
          .allMatches(row.group(1)!)
          .map((m) => clean(m.group(1)!))
          .toList();
      if (cells.length < 6) continue;
      try {
        if (isBefiqr) {
          if (cells.length < 10) continue;
          final river = cells[1];
          final site  = cells[2].replaceAll('*', '').trim();
          if (river.isEmpty || site.isEmpty) continue;

          final cur   = _dblStr(cells.length > 6 ? cells[6] : '');
          final dl    = _dblStr(cells.length > 4 ? cells[4] : '');
          final bdRaw = _dblStr(cells.length > 8 ? cells[8] : '');
          final bd    = bdRaw ?? (cur != null && dl != null ? dl - cur : null);

          // Map arrow characters to trend strings
          final trendRaw = cells.length > 9 ? cells[9] : '';
          final trend = trendRaw.contains('↑') ? '↑'
                      : trendRaw.contains('↓') ? '↓'
                      : trendRaw.contains('→') ? '→'
                      : trendRaw.isNotEmpty    ? trendRaw
                      : null;

          result.add(WrdStation(
            river:        river,
            site:         site,
            district:     cells.length > 10 ? _districtOnly(cells[10]) : '',
            hfl:          _dblStr(cells[3]),
            dangerLevel:  dl,
            warningLevel: null,
            prevLevel:    _dblStr(cells.length > 5 ? cells[5] : ''),
            currentLevel: cur,
            diff24h:      _dblStr(cells.length > 7 ? cells[7] : ''),
            belowDanger:  bd,
            trend:        trend,
            source:       _source,
            fetchedAt:    now,
          ));
        }
      } catch (_) {}
    }
    if (kDebugMode) {
      debugPrint('[WrdBihar] parsed ${result.length} stations from HTML fallback');
    }
    return result;
  }

  String  _str(dynamic v) => (v?.toString() ?? '').trim();

  double? _dbl(dynamic v) {
    if (v == null) return null;
    final s = v.toString().trim();
    if (s.isEmpty || s == '-' || s.toUpperCase() == 'NA') return null;
    return double.tryParse(s);
  }

  double? _dblStr(String s) {
    final c = s.replaceAll(RegExp(r'[^\d.\/\-]'), '').trim();
    if (c.isEmpty || c == '-') return null;
    return double.tryParse(c);
  }

  String _districtOnly(String s) => s.split('/').first.trim();
}
