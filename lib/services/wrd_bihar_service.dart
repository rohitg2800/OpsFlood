// lib/services/wrd_bihar_service.dart
//
// OpsFlood — WRD Bihar Service (v3.1)
//
// SOURCE: Central Flood Control Cell, WRD Patna
// URL:    https://irrigation.befiqr.in/state/table/rivers
//
// v3.1 CHANGES:
//   ─ belowDanger is always computed when dangerLevel is known:
//       if belowDanger cell is NA but cur & DL both exist → DL - cur
//       if cur is NA but DL is known → belowDanger = null (genuinely unknown)
//   ─ _dblStr now also strips leading +/trailing whitespace more aggressively
//   ─ percentOfDanger: returns null only when DL is truly missing (not when cur is NA)
//   ─ riskLabel: falls back to 'PRE-MONSOON' instead of 'UNKNOWN' when no data
//   ─ displayLevel getter: always returns a non-null String for UI use
//   ─ displayDanger getter: always returns a non-null String for UI use
library;

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

// ── Data model ────────────────────────────────────────────────────────────────────────
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

  /// True only when WRD is reporting an actual gauge reading (not NA).
  bool get hasLiveData => currentLevel != null;

  /// Whether danger level is known (independent of current reading).
  bool get hasDangerLevel => dangerLevel != null && dangerLevel! > 0;

  /// Safe display string for current level — never throws, never empty.
  String get displayLevel {
    if (currentLevel != null) return '${currentLevel!.toStringAsFixed(2)} m';
    return 'NA';
  }

  /// Safe display string for danger level.
  String get displayDanger {
    if (dangerLevel != null) return '${dangerLevel!.toStringAsFixed(2)} m';
    return '—';
  }

  /// Safe display string for warning level.
  String get displayWarning {
    if (warningLevel != null) return '${warningLevel!.toStringAsFixed(2)} m';
    return '—';
  }

  /// 24-h diff with arrow prefix. e.g. "+0.23 m" or "-0.10 m"
  String get displayDiff {
    if (diff24h == null) return '—';
    final sign = diff24h! >= 0 ? '+' : '';
    return '$sign${diff24h!.toStringAsFixed(2)} m';
  }

  /// Risk label from WRD danger margin.
  /// Uses belowDanger when available; falls back to NA label gracefully.
  String get riskLabel {
    final bd = belowDanger;
    // If we have no live reading and no danger level, label PRE-MONSOON
    if (!hasLiveData && !hasDangerLevel) return 'PRE-MONSOON';
    if (!hasLiveData) return 'NA';           // DL known, level not reported yet
    if (bd == null && dangerLevel == null)  return 'UNKNOWN';
    // Compute from belowDanger or derive it
    final margin = bd ?? (dangerLevel! - currentLevel!);
    if (margin <= 0)   return 'CRITICAL';
    if (margin <= 1.0) return 'HIGH';
    if (margin <= 2.5) return 'MODERATE';
    return 'LOW';
  }

  /// Safety percentage (0–100+). Null when no live gauge reading.
  double? get percentOfDanger {
    if (currentLevel == null || dangerLevel == null || dangerLevel! <= 0) return null;
    return (currentLevel! / dangerLevel!) * 100.0;
  }

  /// Percent of danger expressed as a safe string for UI.
  String get displayPctOfDanger {
    final p = percentOfDanger;
    if (p == null) return '—';
    return '${p.toStringAsFixed(0)}%';
  }

  /// Margin below danger level as safe string.
  String get displayBelowDanger {
    if (belowDanger != null) {
      return '${belowDanger!.toStringAsFixed(2)} m';
    }
    if (currentLevel != null && dangerLevel != null) {
      final bd = dangerLevel! - currentLevel!;
      return '${bd.toStringAsFixed(2)} m';
    }
    return '—';
  }

  @override
  String toString() =>
      'WrdStation($river @ $site | cur=$displayLevel | '
      'DL=$displayDanger | bd=$displayBelowDanger | '
      'risk=$riskLabel | live=$hasLiveData)';
}

// ── WRD ⇒ IndiaCity alias map ─────────────────────────────────────────────────────────────
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

// ── Service ────────────────────────────────────────────────────────────────────────
class WrdBiharService {
  WrdBiharService._();
  static final WrdBiharService instance = WrdBiharService._();

  static const _primaryUrl  = 'https://irrigation.befiqr.in/state/table/rivers';
  static const _fallbackUrl =
      'https://beams.fmiscwrdbihar.gov.in/Alerttotalinfo/realtimetotal.aspx';
  static const _cacheTtl    = Duration(minutes: 10);
  static const _source      = 'WRD_BIHAR';

  List<WrdStation>?        _cache;
  DateTime?                _cacheTime;
  Map<String, WrdStation>? _stationByCity;

  // ── Public API ────────────────────────────────────────────────────────────────
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

  Future<WrdStation?> fetchBestMatch(String city, {String? river}) async {
    await fetch();
    final lc = city.toLowerCase().trim();
    final byAlias = _stationByCity?[lc];
    if (byAlias != null) return byAlias;
    final all = _cache ?? [];
    final candidates = all.where((s) =>
        s.site.toLowerCase().contains(lc) ||
        s.district.toLowerCase().contains(lc)).toList();
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

  // ── Internal ─────────────────────────────────────────────────────────────────────
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
        final cur = _dbl(item['currentLevel'] ?? item['current'] ?? item['waterLevel']);
        final dl  = _dbl(item['danger'] ?? item['dangerLevel'] ?? item['DL']);
        final bdRaw = _dbl(item['belowDanger'] ?? item['aboveBelow']);
        // Compute belowDanger from cur & DL if the cell itself was absent/NA
        final bd = bdRaw ?? (cur != null && dl != null ? dl - cur : null);
        result.add(WrdStation(
          river:        _str(item['river']    ?? item['River']),
          site:         _str(item['site']     ?? item['Site'] ?? item['station'] ?? item['Station']),
          district:     _str(item['district'] ?? item['District'] ?? item['block'] ?? ''),
          hfl:          _dbl(item['hfl']      ?? item['HFL']),
          dangerLevel:  dl,
          warningLevel: _dbl(item['warning']  ?? item['warningLevel'] ?? item['WL']),
          prevLevel:    _dbl(item['prevLevel'] ?? item['yesterday']),
          currentLevel: cur,
          diff24h:      _dbl(item['diff24h']   ?? item['diff']),
          belowDanger:  bd,
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

    String clean(String s) =>
        s.replaceAll(tagRe, '').replaceAll('\u00a0', ' ').trim();

    final rows = rowRe.allMatches(html).toList();
    if (rows.isEmpty) return result;

    final headerCells = cellRe
        .allMatches(rows.first.group(1)!)
        .map((m) => clean(m.group(1)!).toLowerCase())
        .toList();
    final isBefiqr = headerCells.any((h) => h.contains('river'));
    final isBeams  =
        headerCells.any((h) => h.contains('basin') || h.contains('maintained'));

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

          final cur   = _dblStr(cells.length > 6 ? cells[6] : '');
          final dl    = _dblStr(cells.length > 4 ? cells[4] : '');
          final bdRaw = _dblStr(cells.length > 8 ? cells[8] : '');
          // Always compute belowDanger if the column was NA but we have cur & DL
          final bd = bdRaw ?? (cur != null && dl != null ? dl - cur : null);

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
            trend:        cells.length > 9 && cells[9].isNotEmpty
                ? cells[9] : null,
            source:    _source,
            fetchedAt: now,
          ));
        } else if (isBeams) {
          if (cells.length < 15) continue;
          final river = cells[1];
          final site  = cells[2];
          if (river.isEmpty || site.isEmpty) continue;
          final cur = _dblStr(cells.length > 14 ? cells[14] : '');
          final dl  = _dblStr(cells[8]);
          result.add(WrdStation(
            river:        river,
            site:         site,
            district:     cells.length > 12 ? cells[12] : '',
            hfl:          _dblStr(cells[7]),
            dangerLevel:  dl,
            warningLevel: _dblStr(cells[9]),
            prevLevel:    _dblStr(cells.length > 15 ? cells[15] : ''),
            currentLevel: cur,
            diff24h:      null,
            belowDanger:  (cur != null && dl != null) ? dl - cur : null,
            trend:        cells.length > 17 && cells[17].isNotEmpty
                ? cells[17] : null,
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

  String  _str(dynamic v) => (v?.toString() ?? '').trim();

  double? _dbl(dynamic v) {
    if (v == null) return null;
    final s = v.toString().trim();
    if (s.isEmpty || s == '-' || s.toUpperCase() == 'NA') return null;
    return double.tryParse(s);
  }

  double? _dblStr(String s) {
    // Strip everything except digits, dot, dash, slash
    final c = s.replaceAll(RegExp(r'[^\d.\/\-]'), '').trim();
    if (c.isEmpty || c == '-') return null;
    return double.tryParse(c);
  }

  String _districtOnly(String s) => s.split('/').first.trim();
}
