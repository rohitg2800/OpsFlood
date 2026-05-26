// lib/services/wrd_bihar_service.dart
//
// OpsFlood — WRD Bihar Service (v3.0)
//
// SOURCE: Central Flood Control Cell, WRD Patna
// URL:    https://irrigation.befiqr.in/state/table/rivers
//
// v3.0 CHANGES:
//   ─ Added _kAliasMap: exact WRD site names → IndiaCity.name
//     Fixes all 0.00 m readings caused by fuzzy match failures.
//   ─ Added _stationByAlias cache: O(1) lookup after first fetch.
//   ─ fetchBestMatch() now resolves via alias first, then fuzzy.
//   ─ Added hasLiveData getter on WrdStation.
//   ─ fetch() warms _stationByAlias map automatically.
//
// WRD DATA SNAPSHOT (27 Mar 2026, 14:00):
//   LIVE (22 stations): Ekmighat→NA, Kamtaul→NA, Sonbarsa→NA,
//     Benibad→NA, Dheng Bridge→68.20, Hayaghat→NA,
//     Khagaria→30.32, Rosera→36.65, Samastipur→39.50,
//     Sikandarpur→45.60, Chatia→65.13, Dumariaghat→59.50,
//     Hajipur→44.72, Rewaghat→49.94, Bhagalpur→25.71,
//     Buxar→50.02, Dighaghat→42.94, Gandhighat→42.27,
//     Hathidah→34.06, Kahalgaon→24.53, Munger→30.81,
//     Darauli→55.69, Gangpur Siswan→51.45, Jhanjharpur→NA,
//     Jainagar→NA, Baltara→30.56, Basua→45.39,
//     Birpur→74.86, Kursela→23.99, Dhengraghat→33.12,
//     Taibpur→62.84, Sripalpur→45.46
library;

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

// ── Data model ──────────────────────────────────────────────────────────────────────────

class WrdStation {
  final String river;
  final String site;         // exact WRD portal site name
  final String district;
  final double? hfl;
  final double? dangerLevel;
  final double? warningLevel;
  final double? prevLevel;
  final double? currentLevel;
  final double? diff24h;
  final double? belowDanger;
  final String? trend;
  final String source;
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

  /// True only when WRD is reporting an actual gauge reading (not NA).
  bool get hasLiveData => currentLevel != null;

  /// Risk label from WRD danger margin.
  String get riskLabel {
    final bd = belowDanger;
    if (bd == null || dangerLevel == null) return 'UNKNOWN';
    if (bd <= 0)   return 'CRITICAL';
    if (bd <= 1.0) return 'HIGH';
    if (bd <= 2.5) return 'MODERATE';
    return 'LOW';
  }

  /// Safety percentage (0–100+). Null when no live data.
  double? get percentOfDanger {
    if (currentLevel == null || dangerLevel == null || dangerLevel! <= 0) return null;
    return (currentLevel! / dangerLevel!) * 100.0;
  }

  @override
  String toString() =>
      'WrdStation($river @ $site | cur=${currentLevel}m | '
      'danger=${dangerLevel}m | below=${belowDanger}m | '
      'risk=$riskLabel | live=$hasLiveData)';
}

// ── WRD ⇒ IndiaCity alias map ─────────────────────────────────────────────────────────
//
// Key   = exact site name on WRD portal (lowercased)
// Value = IndiaCity.name (exact as in india_cities.dart)
//
// Data sourced from:
//   https://irrigation.befiqr.in/state/table/rivers (27 Mar 2026)

const Map<String, String> _kAliasMap = {
  // Adhwara
  'ekmighat':                    'Ekmighat',
  'kamtaul':                     'Kamtaul',
  'sonbarsa':                    'Sonbarsa',
  // Bagmati
  'benibad':                     'Benibad',
  'dheng bridge':                'Dheng Bridge',
  'hayaghat':                    'Hayaghat',
  // Burhi Gandak
  'khagaria':                    'Khagaria',
  'rosera':                      'Rosera',
  'samastipur':                  'Samastipur',
  'sikandarpur (muzzafarpur)':   'Sikandarpur',
  'sikandarpur':                 'Sikandarpur',
  // Gandak
  'chatia':                      'Chatia',
  'dumariaghat':                 'Dumariaghat',
  'hajipur':                     'Hajipur',
  'rewaghat':                    'Rewaghat',
  // Ganga
  'bhagalpur':                   'Bhagalpur',
  'buxar':                       'Buxar',
  'dighaghat':                   'Dighaghat',
  'gandhighat':                  'Gandhighat',
  'hathidah':                    'Hathidah',
  'kahalgaon':                   'Kahalgaon',
  'munger':                      'Munger',
  // Ghaghra
  'darauli':                     'Darauli',
  'gangpur siswan':              'Gangpur Siswan',
  // Kamalabalan
  'jhanjharpur':                 'Jhanjharpur',
  // Kamla
  'jainagar':                    'Jainagar',
  // Kosi
  'baltara':                     'Baltara',
  'basua':                       'Basua',
  'birpur':                      'Birpur',
  'kursela':                     'Kursela',
  // Mahananda
  'dhengraghat':                 'Dhengraghat',
  'taibpur':                     'Taibpur',
  // Punpun
  'sripalpur':                   'Sripalpur',
};

// ── Service ──────────────────────────────────────────────────────────────────────────

class WrdBiharService {
  WrdBiharService._();
  static final WrdBiharService instance = WrdBiharService._();

  static const _primaryUrl  = 'https://irrigation.befiqr.in/state/table/rivers';
  static const _fallbackUrl =
      'https://beams.fmiscwrdbihar.gov.in/Alerttotalinfo/realtimetotal.aspx';
  static const _cacheTtl    = Duration(minutes: 10);
  static const _source      = 'WRD_BIHAR';

  List<WrdStation>?           _cache;
  DateTime?                   _cacheTime;
  // O(1) lookup: IndiaCity.name.toLowerCase() → WrdStation
  Map<String, WrdStation>?    _stationByCity;

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Fetch all 31 Bihar WRD stations.
  Future<List<WrdStation>> fetch({bool forceRefresh = false}) async {
    if (!forceRefresh &&
        _cache != null &&
        _cacheTime != null &&
        DateTime.now().difference(_cacheTime!) < _cacheTtl) {
      return _cache!;
    }
    try {
      final stations = await _fetchFromPrimary();
      if (stations.isNotEmpty) {
        _cache     = stations;
        _cacheTime = DateTime.now();
        _buildCityIndex(stations);
        if (kDebugMode) debugPrint('[WrdBihar] ✓ ${stations.length} stations (primary)');
        return stations;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[WrdBihar] primary failed: $e');
    }
    try {
      final stations = await _fetchFromFallback();
      if (stations.isNotEmpty) {
        _cache     = stations;
        _cacheTime = DateTime.now();
        _buildCityIndex(stations);
        if (kDebugMode) debugPrint('[WrdBihar] ✓ ${stations.length} stations (fallback)');
        return stations;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[WrdBihar] fallback failed: $e');
    }
    return _cache ?? [];
  }

  /// Best match for a city name: alias lookup first, then fuzzy.
  Future<WrdStation?> fetchBestMatch(String city, {String? river}) async {
    await fetch(); // ensure cache is warm
    final lc = city.toLowerCase().trim();

    // 1. Direct alias lookup (O(1))
    final byAlias = _stationByCity?[lc];
    if (byAlias != null) return byAlias;

    // 2. Fuzzy fallback: site or district contains city name
    final all = _cache ?? [];
    final candidates = all.where((s) =>
        s.site.toLowerCase().contains(lc) ||
        s.district.toLowerCase().contains(lc)).toList();
    if (candidates.isEmpty) return null;

    if (river != null) {
      final rv = river.toLowerCase();
      final byRiver =
          candidates.where((s) => s.river.toLowerCase().contains(rv)).toList();
      if (byRiver.isNotEmpty) return byRiver.first;
    }
    final withLevel = candidates.where((s) => s.hasLiveData).toList();
    return withLevel.isNotEmpty ? withLevel.first : candidates.first;
  }

  /// All stations on a specific river.
  Future<List<WrdStation>> fetchForRiver(String river) async {
    final all = await fetch();
    final lc  = river.toLowerCase();
    return all.where((s) => s.river.toLowerCase().contains(lc)).toList();
  }

  /// Stations grouped by river basin name.
  Future<Map<String, List<WrdStation>>> fetchGroupedByRiver() async {
    final all = await fetch();
    final map = <String, List<WrdStation>>{};
    for (final s in all) {
      map.putIfAbsent(s.river, () => []).add(s);
    }
    // Sort each group by current level descending (live first)
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

  // ── Internal ─────────────────────────────────────────────────────────────────────

  void _buildCityIndex(List<WrdStation> stations) {
    final map = <String, WrdStation>{};
    for (final s in stations) {
      final alias = _kAliasMap[s.site.toLowerCase().trim()];
      if (alias != null) {
        map[alias.toLowerCase()] = s;
      }
    }
    _stationByCity = map;
    if (kDebugMode) {
      debugPrint('[WrdBihar] city index: ${map.length}/${stations.length} resolved');
    }
  }

  Future<List<WrdStation>> _fetchFromPrimary() async {
    final res = await http
        .get(Uri.parse(_primaryUrl))
        .timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) {
      throw Exception('[WrdBihar] primary HTTP ${res.statusCode}');
    }
    try {
      final j = jsonDecode(res.body);
      if (j is List) return _parseJsonList(j);
      if (j is Map && j['data'] is List) return _parseJsonList(j['data'] as List);
    } catch (_) {}
    return _parseHtmlTable(res.body);
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

  List<WrdStation> _parseJsonList(List raw) {
    final now    = DateTime.now();
    final result = <WrdStation>[];
    for (final item in raw.whereType<Map>()) {
      try {
        result.add(WrdStation(
          river:        _str(item['river']    ?? item['River']),
          site:         _str(item['site']     ?? item['Site'] ?? item['station'] ?? item['Station']),
          district:     _str(item['district'] ?? item['District'] ?? item['block'] ?? ''),
          hfl:          _dbl(item['hfl']      ?? item['HFL']),
          dangerLevel:  _dbl(item['danger']   ?? item['dangerLevel']  ?? item['DL']),
          warningLevel: _dbl(item['warning']  ?? item['warningLevel'] ?? item['WL']),
          prevLevel:    _dbl(item['prevLevel']    ?? item['yesterday']),
          currentLevel: _dbl(item['currentLevel'] ?? item['current']  ?? item['waterLevel']),
          diff24h:      _dbl(item['diff24h']      ?? item['diff']),
          belowDanger:  _dbl(item['belowDanger']  ?? item['aboveBelow']),
          trend:        _str(item['trend'] ?? item['Trend']).isEmpty
              ? null : _str(item['trend'] ?? item['Trend']),
          source:    _source,
          fetchedAt: now,
        ));
      } catch (_) {}
    }
    return result;
  }

  // Column layout (BeFIQR):
  // 0=SL 1=River 2=Site 3=HFL 4=DL 5=Yesterday 6=Current 7=Diff 8=BelowDanger 9=Trend 10=District
  List<WrdStation> _parseHtmlTable(String html) {
    final now    = DateTime.now();
    final result = <WrdStation>[];
    final rowRe  = RegExp(r'<tr[^>]*>(.*?)</tr>', dotAll: true, caseSensitive: false);
    final cellRe = RegExp(r'<t[dh][^>]*>(.*?)</t[dh]>', dotAll: true, caseSensitive: false);
    final tagRe  = RegExp(r'<[^>]+>');

    String clean(String s) => s.replaceAll(tagRe, '').replaceAll('\u00a0', ' ').trim();

    final rows = rowRe.allMatches(html).toList();
    if (rows.isEmpty) return result;

    final headerCells = cellRe
        .allMatches(rows.first.group(1)!)
        .map((m) => clean(m.group(1)!).toLowerCase())
        .toList();
    final isBefiqr = headerCells.any((h) => h.contains('river'));
    final isBeams  = headerCells.any((h) => h.contains('basin') || h.contains('maintained'));

    for (final row in rows.skip(1)) {
      final cells = cellRe
          .allMatches(row.group(1)!)
          .map((m) => clean(m.group(1)!))
          .toList();
      if (cells.length < 6) continue;
      try {
        if (isBefiqr && !isBeams) {
          if (cells.length < 10) continue;
          final river = cells[1];
          final site  = cells[2].replaceAll('*', '').trim();
          if (river.isEmpty || site.isEmpty) continue;
          final cur = _dblStr(cells.length > 6 ? cells[6] : '');
          final dl  = _dblStr(cells.length > 4 ? cells[4] : '');
          final bd  = _dblStr(cells.length > 8 ? cells[8] : '');
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
            belowDanger:  bd ?? (cur != null && dl != null ? dl - cur : null),
            trend:        cells.length > 9 && cells[9].isNotEmpty ? cells[9] : null,
            source:    _source,
            fetchedAt: now,
          ));
        } else if (isBeams) {
          if (cells.length < 15) continue;
          final river = cells[1];
          final site  = cells[2];
          if (river.isEmpty || site.isEmpty) continue;
          result.add(WrdStation(
            river:        river,
            site:         site,
            district:     cells.length > 12 ? cells[12] : '',
            hfl:          _dblStr(cells[7]),
            dangerLevel:  _dblStr(cells[8]),
            warningLevel: _dblStr(cells[9]),
            prevLevel:    _dblStr(cells.length > 15 ? cells[15] : ''),
            currentLevel: _dblStr(cells.length > 14 ? cells[14] : ''),
            diff24h:      null,
            belowDanger:  null,
            trend:        cells.length > 17 && cells[17].isNotEmpty ? cells[17] : null,
            source:    _source,
            fetchedAt: now,
          ));
        }
      } catch (_) {}
    }
    if (kDebugMode) {
      debugPrint('[WrdBihar] parsed ${result.length} stations from HTML');
    }
    return result;
  }

  String  _str(dynamic v)    => (v?.toString() ?? '').trim();
  double? _dbl(dynamic v)    => v == null ? null : double.tryParse(v.toString().trim());
  double? _dblStr(String s) {
    final c = s.replaceAll(RegExp(r'[^\d.\/\-]'), '').trim();
    if (c.isEmpty || c == '-' || c == 'NA') return null;
    return double.tryParse(c);
  }
  String _districtOnly(String s) => s.split('/').first.trim();
}
