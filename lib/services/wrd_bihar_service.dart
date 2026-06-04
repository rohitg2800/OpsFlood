// lib/services/wrd_bihar_service.dart
//
// OpsFlood — WRD Bihar Service (v5.1 — 100% on-device, no backend)
//
// SOURCE: Central Flood Control Cell, WRD Patna
// PRIMARY:  https://irrigation.befiqr.in/state/table/rivers  (direct scrape)
// FALLBACK: allOrigins proxy  (for portal bot-blocks)
//
// BeFIQR table layout (two header rows!):
//   Row 0: (1) (2) (3) ... (11)   ← column numbers, ignored
//   Row 1: River | Site | HFL | DL | Yesterday | Current | Diff | Above/Below | Trend | District
//   Rows 2-32: 31 live data rows
library;

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

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

  bool get hasLiveData    => currentLevel != null;
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

// ── WRD site name ⇒ city alias map ───────────────────────────────────────────
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

// ── Scrape URLs (tried in order) ──────────────────────────────────────────────
const _kDirectUrls = [
  'https://irrigation.befiqr.in/state/table/rivers',
  'http://irrigation.befiqr.in/state/table/rivers',
];

String _proxyUrl(String target) =>
    'https://api.allorigins.win/get?url=${Uri.encodeComponent(target)}';

// Full Android browser UA — portal rejects bare Dart http-client UA
const _kHeaders = {
  'User-Agent':
      'Mozilla/5.0 (Linux; Android 14; Pixel 8) '
      'AppleWebKit/537.36 (KHTML, like Gecko) '
      'Chrome/124.0.0.0 Mobile Safari/537.36',
  'Accept':
      'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
  'Accept-Language': 'en-IN,en;q=0.9,hi;q=0.8',
  'Referer':         'https://irrigation.befiqr.in/',
  'Cache-Control':   'no-cache',
};

// ── Service ───────────────────────────────────────────────────────────────────
class WrdBiharService {
  WrdBiharService._();
  static final WrdBiharService instance = WrdBiharService._();

  static const _cacheTtl      = Duration(minutes: 15);
  static const _source        = 'WRD_BIHAR_LIVE';
  static const _directTimeout = Duration(seconds: 25);
  static const _proxyTimeout  = Duration(seconds: 40); // proxy chains 2 HTTP calls

  List<WrdStation>?        _cache;
  DateTime?                _cacheTime;
  Map<String, WrdStation>? _stationByCity;

  // ── Public API ────────────────────────────────────────────────────────────
  Future<List<WrdStation>> fetch({bool forceRefresh = false}) async {
    if (!forceRefresh &&
        _cache != null &&
        _cacheTime != null &&
        DateTime.now().difference(_cacheTime!) < _cacheTtl) {
      _log('cache hit — ${_cache!.length} stations');
      return _cache!;
    }

    // 1️⃣ Direct scrape with browser headers
    for (final url in _kDirectUrls) {
      try {
        final res = await http
            .get(Uri.parse(url), headers: _kHeaders)
            .timeout(_directTimeout);
        if (res.statusCode == 200) {
          final stations = _parseHtmlTable(res.body);
          if (stations.isNotEmpty) {
            _setCache(stations);
            _log('direct-scrape ✓ ${stations.length} stations');
            return stations;
          }
          _log('direct-scrape: HTTP 200 but 0 stations from $url');
        } else {
          _log('direct-scrape: HTTP ${res.statusCode} from $url');
        }
      } catch (e) {
        _log('direct-scrape error ($url): $e');
      }
    }

    // 2️⃣ allOrigins proxy fallback
    const primaryUrl = 'https://irrigation.befiqr.in/state/table/rivers';
    try {
      final res = await http
          .get(Uri.parse(_proxyUrl(primaryUrl)))
          .timeout(_proxyTimeout);
      if (res.statusCode == 200) {
        final json = jsonDecode(res.body) as Map?;
        final html = json?['contents'] as String? ?? '';
        if (html.isNotEmpty) {
          final stations = _parseHtmlTable(html);
          if (stations.isNotEmpty) {
            _setCache(stations);
            _log('proxy-scrape ✓ ${stations.length} stations');
            return stations;
          }
          _log('proxy-scrape: 0 stations parsed from proxy HTML');
        }
      } else {
        _log('proxy-scrape: HTTP ${res.statusCode}');
      }
    } catch (e) {
      _log('proxy-scrape error: $e');
    }

    _log('all sources failed — stale cache: ${_cache?.length ?? 0} stations');
    return _cache ?? [];
  }

  Future<WrdStation?> fetchBestMatch(String city, {String? river}) async {
    await fetch();
    final lc      = city.toLowerCase().trim();
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
        return (b.currentLevel ?? 0).compareTo(a.currentLevel ?? 0);
      });
    }
    return map;
  }

  // ── Internals ────────────────────────────────────────────────────────────

  void _setCache(List<WrdStation> stations) {
    _cache     = stations;
    _cacheTime = DateTime.now();
    _buildCityIndex(stations);
  }

  void _buildCityIndex(List<WrdStation> stations) {
    final map = <String, WrdStation>{};
    for (final s in stations) {
      final alias = _kAliasMap[s.site.toLowerCase().trim()];
      if (alias != null) map[alias.toLowerCase()] = s;
    }
    _stationByCity = map;
    _log('city index: ${map.length}/${stations.length} resolved');
  }

  // ── HTML table parser ─────────────────────────────────────────────────────
  //
  // BeFIQR uses TWO header rows:
  //   Row 0 → (1)(2)(3)...(11)   [column number labels — NOT text]
  //   Row 1 → River|Site|HFL|DL|Yesterday|Current|Diff|Above/Below|Trend|District
  //   Rows 2..N → data
  //
  // Strategy: scan first 4 rows looking for one containing the word "river".
  // That is the real text-header row. Data starts on the row AFTER it.
  List<WrdStation> _parseHtmlTable(String html) {
    final now    = DateTime.now();
    final result = <WrdStation>[];
    final rowRe  = RegExp(r'<tr[^>]*>(.*?)<\/tr>',  dotAll: true, caseSensitive: false);
    final cellRe = RegExp(r'<t[dh][^>]*>(.*?)<\/t[dh]>', dotAll: true, caseSensitive: false);
    final tagRe  = RegExp(r'<[^>]+>');

    String clean(String s) => s
        .replaceAll(tagRe, '')
        .replaceAll('\u00a0', ' ')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .trim();

    final rows = rowRe.allMatches(html).toList();
    if (rows.isEmpty) {
      _log('HTML parser: 0 <tr> rows found — page may be JS-rendered or empty');
      return result;
    }

    // Find the real text-header row (the one containing the word "river")
    // BeFIQR wraps the real headers in a second <tr> after a numeric-label row
    int textHeaderIdx = -1;
    final scanLimit   = rows.length < 5 ? rows.length : 5;
    for (int i = 0; i < scanLimit; i++) {
      final rowText = rows[i].group(1)!;
      final cells   = cellRe
          .allMatches(rowText)
          .map((m) => clean(m.group(1)!).toLowerCase())
          .toList();
      _log('HTML parser row[$i] cells: $cells');
      if (cells.any((c) => c.contains('river'))) {
        textHeaderIdx = i;
        break;
      }
    }

    _log('HTML parser: ${rows.length} total rows, text-header at row $textHeaderIdx');

    if (textHeaderIdx < 0) {
      _log('HTML parser: no text-header row found — cannot determine column layout');
      return result;
    }

    // Parse data rows: everything after the text-header row
    for (final row in rows.skip(textHeaderIdx + 1)) {
      final cells = cellRe
          .allMatches(row.group(1)!)
          .map((m) => clean(m.group(1)!))
          .toList();

      if (cells.length < 10) continue;

      final river = cells[1].trim();
      final site  = cells[2].replaceAll('*', '').trim();

      // Skip blank rows, repeat-header rows, or label rows
      if (river.isEmpty || site.isEmpty) continue;
      if (river.toLowerCase() == 'river' || site.toLowerCase() == 'site') continue;
      if (river.toLowerCase().contains('sl.') || river.startsWith('(')) continue;

      try {
        final cur   = _dblStr(cells[6]);
        final dl    = _dblStr(cells[4]);
        final bdRaw = _dblStr(cells[8]);
        // above_below_danger_m: positive = below danger, negative = above danger
        final bd    = bdRaw ?? (cur != null && dl != null ? dl - cur : null);

        final trendRaw = cells.length > 9 ? cells[9] : '';
        final trend = trendRaw.contains('↑') || trendRaw.toUpperCase().contains('RISE') ? '↑'
                    : trendRaw.contains('↓') || trendRaw.toUpperCase().contains('FALL') ? '↓'
                    : trendRaw.contains('→') || trendRaw.toUpperCase().contains('STEAD') ? '→'
                    : trendRaw.isNotEmpty ? trendRaw
                    : null;

        result.add(WrdStation(
          river:        river,
          site:         site,
          district:     cells.length > 10 ? _districtOnly(cells[10]) : '',
          hfl:          _dblStr(cells[3]),
          dangerLevel:  dl,
          warningLevel: null,
          prevLevel:    _dblStr(cells[5]),
          currentLevel: cur,
          diff24h:      _dblStr(cells[7]),
          belowDanger:  bd,
          trend:        trend,
          source:       _source,
          fetchedAt:    now,
        ));
      } catch (e) {
        _log('HTML parser: skipping row (parse error): $e | cells=$cells');
      }
    }

    _log('HTML parser: parsed ${result.length} stations from ${rows.length} rows');
    return result;
  }

  double? _dblStr(String s) {
    // Strip everything except digits, dot, minus
    final c = s.replaceAll(RegExp(r'[^\d.\-]'), '').trim();
    if (c.isEmpty || c == '-' || c == '.') return null;
    return double.tryParse(c);
  }

  String _districtOnly(String s) => s.split('/').first.trim();

  void _log(String msg) {
    if (kDebugMode) debugPrint('[WrdBihar] $msg');
  }
}
