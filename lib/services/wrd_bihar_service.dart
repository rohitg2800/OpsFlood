// lib/services/wrd_bihar_service.dart
//
// OpsFlood — WRD Bihar Service
//
// SOURCE: Central Flood Control Cell, WRD Patna
// URL:    https://irrigation.befiqr.in/state/table/rivers
//         (mirrors https://fmis.bih.nic.in / beams.fmiscwrdbihar.gov.in)
//
// COVERAGE: 31 stations across Bihar rivers:
//   Ganga, Kosi, Gandak, Ghaghra, Bagmati, Burhi Gandak,
//   Adhwara, Mahananda, Kamla, Kamalabalan, Punpun
//
// USAGE:
//   final svc     = WrdBiharService.instance;
//   final records = await svc.fetch();           // all 31 stations
//   final patna   = await svc.fetchForCity('Patna');   // by city/district
//   final ganga   = await svc.fetchForRiver('Ganga');  // by river
//
// DATA MODEL: WrdStation
//   river, site, district, hfl, dangerLevel, warningLevel,
//   currentLevel, prevLevel, diff24h, belowDanger, trend
//
// CACHING: 10-minute TTL (flood data changes slowly pre-monsoon)
// CORS: Server-side scrape via befiqr proxy — no CORS issues on Android.
library;

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

// ── Data model ────────────────────────────────────────────────────────────────

class WrdStation {
  final String river;
  final String site;
  final String district;
  final double? hfl;           // Highest Flood Level (m)
  final double? dangerLevel;   // Danger Level (m)
  final double? warningLevel;  // Warning Level (m)
  final double? prevLevel;     // Yesterday observed (m)
  final double? currentLevel;  // Current observed (m)
  final double? diff24h;       // Diff last 24h (m)
  final double? belowDanger;   // metres below danger (positive = safe)
  final String? trend;         // Steady / Rising / Falling
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

  /// Risk label derived from belowDanger margin.
  String get riskLabel {
    final bd = belowDanger;
    if (bd == null || dangerLevel == null) return 'UNKNOWN';
    if (bd <= 0)    return 'CRITICAL';   // at or above danger
    if (bd <= 1.0)  return 'HIGH';       // within 1 m of danger
    if (bd <= 2.5)  return 'MODERATE';
    return 'LOW';
  }

  /// Percentage of danger level (0–100+).
  double? get percentOfDanger {
    if (currentLevel == null || dangerLevel == null || dangerLevel! <= 0) return null;
    return (currentLevel! / dangerLevel!) * 100.0;
  }

  @override
  String toString() =>
      'WrdStation($river @ $site | cur=${currentLevel}m | danger=${dangerLevel}m '
      '| belowDanger=${belowDanger}m | risk=$riskLabel | trend=$trend)';
}

// ── Service ───────────────────────────────────────────────────────────────────

class WrdBiharService {
  WrdBiharService._();
  static final WrdBiharService instance = WrdBiharService._();

  // BeFIQR mirror — updated daily from WRD Patna's FMIS portal.
  // Falls back to direct BEAMS endpoint if mirror fails.
  static const _primaryUrl   = 'https://irrigation.befiqr.in/state/table/rivers';
  static const _fallbackUrl  = 'https://beams.fmiscwrdbihar.gov.in/Alerttotalinfo/realtimetotal.aspx';
  static const _cacheTtl     = Duration(minutes: 10);
  static const _source       = 'WRD_BIHAR';

  List<WrdStation>? _cache;
  DateTime?         _cacheTime;

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Fetch all 31 Bihar flood stations.
  Future<List<WrdStation>> fetch({bool forceRefresh = false}) async {
    if (!forceRefresh && _cache != null && _cacheTime != null &&
        DateTime.now().difference(_cacheTime!) < _cacheTtl) {
      if (kDebugMode) debugPrint('[WrdBihar] cache hit (${_cache!.length} stations)');
      return _cache!;
    }
    try {
      final stations = await _fetchFromPrimary();
      if (stations.isNotEmpty) {
        _cache     = stations;
        _cacheTime = DateTime.now();
        if (kDebugMode) debugPrint('[WrdBihar] ✓ fetched ${stations.length} stations');
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
        if (kDebugMode) debugPrint('[WrdBihar] ✓ fallback: ${stations.length} stations');
        return stations;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[WrdBihar] fallback failed: $e');
    }
    return _cache ?? [];
  }

  /// Fetch stations matching a city or district name.
  Future<List<WrdStation>> fetchForCity(String city) async {
    final all = await fetch();
    final lc  = city.toLowerCase().trim();
    return all.where((s) =>
      s.district.toLowerCase().contains(lc) ||
      s.site.toLowerCase().contains(lc)
    ).toList();
  }

  /// Fetch stations on a specific river.
  Future<List<WrdStation>> fetchForRiver(String river) async {
    final all = await fetch();
    final lc  = river.toLowerCase().trim();
    return all.where((s) => s.river.toLowerCase().contains(lc)).toList();
  }

  /// Fetch the single best-matching station for a city (for autofill).
  Future<WrdStation?> fetchBestMatch(String city, {String? river}) async {
    final candidates = await fetchForCity(city);
    if (candidates.isEmpty) return null;
    if (river != null) {
      final rv = river.toLowerCase();
      final byRiver = candidates.where(
        (s) => s.river.toLowerCase().contains(rv)).toList();
      if (byRiver.isNotEmpty) return byRiver.first;
    }
    // Prefer stations with live current level
    final withLevel = candidates.where((s) => s.currentLevel != null).toList();
    return withLevel.isNotEmpty ? withLevel.first : candidates.first;
  }

  // ── Primary scraper (BeFIQR JSON/HTML) ────────────────────────────────────

  Future<List<WrdStation>> _fetchFromPrimary() async {
    final res = await http.get(Uri.parse(_primaryUrl))
        .timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) {
      throw Exception('[WrdBihar] primary HTTP ${res.statusCode}');
    }
    // Try JSON first
    try {
      final j = jsonDecode(res.body);
      if (j is List) return _parseJsonList(j);
      if (j is Map && j['data'] is List) return _parseJsonList(j['data'] as List);
    } catch (_) {}
    // Fall back to HTML table parsing
    return _parseHtmlTable(res.body);
  }

  // ── Fallback scraper (BEAMS direct) ───────────────────────────────────────

  Future<List<WrdStation>> _fetchFromFallback() async {
    final res = await http.get(Uri.parse(_fallbackUrl))
        .timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) {
      throw Exception('[WrdBihar] fallback HTTP ${res.statusCode}');
    }
    return _parseHtmlTable(res.body);
  }

  // ── JSON parser ────────────────────────────────────────────────────────────

  List<WrdStation> _parseJsonList(List raw) {
    final now = DateTime.now();
    final result = <WrdStation>[];
    for (final item in raw.whereType<Map>()) {
      try {
        result.add(WrdStation(
          river:        _str(item['river']   ?? item['River']),
          site:         _str(item['site']    ?? item['Site']  ?? item['station'] ?? item['Station']),
          district:     _str(item['district']?? item['District'] ?? item['block'] ?? ''),
          hfl:          _dbl(item['hfl']     ?? item['HFL']),
          dangerLevel:  _dbl(item['danger']  ?? item['dangerLevel']  ?? item['DL']),
          warningLevel: _dbl(item['warning'] ?? item['warningLevel'] ?? item['WL']),
          prevLevel:    _dbl(item['prevLevel']   ?? item['yesterday']),
          currentLevel: _dbl(item['currentLevel']?? item['current']  ?? item['waterLevel']),
          diff24h:      _dbl(item['diff24h']     ?? item['diff']),
          belowDanger:  _dbl(item['belowDanger'] ?? item['aboveBelow']),
          trend:        _str(item['trend']       ?? item['Trend']).isEmpty
                            ? null : _str(item['trend'] ?? item['Trend']),
          source:       _source,
          fetchedAt:    now,
        ));
      } catch (_) {}
    }
    return result;
  }

  // ── HTML table parser ──────────────────────────────────────────────────────
  //
  // WRD Patna table columns (befiqr.in mirror):
  //  0=SL, 1=River, 2=Site, 3=HFL, 4=DL, 5=Yesterday, 6=Current,
  //  7=Diff24h, 8=BelowDanger, 9=Trend, 10=District
  //
  // BEAMS direct columns:
  //  Basin, River, Station, Type, MaintainedBy, OtherID, Year,
  //  HFL, DangerLevel, WarningLevel, Height, Block, District,
  //  ObsDate, CurrentLevel, PrevLevel, TYPE, Trend, Status

  List<WrdStation> _parseHtmlTable(String html) {
    final now     = DateTime.now();
    final result  = <WrdStation>[];

    // Extract all <tr> rows
    final rowRe   = RegExp(r'<tr[^>]*>(.*?)</tr>', dotAll: true, caseSensitive: false);
    final cellRe  = RegExp(r'<t[dh][^>]*>(.*?)</t[dh]>', dotAll: true, caseSensitive: false);
    final tagRe   = RegExp(r'<[^>]+>');

    String clean(String s) => s.replaceAll(tagRe, '').trim();

    final rows = rowRe.allMatches(html).toList();
    if (rows.isEmpty) return result;

    // Detect format by header row
    final headerRow = rows.first;
    final headerCells = cellRe.allMatches(headerRow.group(1)!).map(
      (m) => clean(m.group(1)!).toLowerCase()).toList();

    final isBefiqr = headerCells.any((h) => h.contains('river'));
    final isBeams  = headerCells.any((h) => h.contains('basin') || h.contains('maintained'));

    for (final row in rows.skip(1)) {
      final cells = cellRe.allMatches(row.group(1)!)
          .map((m) => clean(m.group(1)!)).toList();
      if (cells.length < 6) continue;

      try {
        if (isBefiqr && !isBeams) {
          // BeFIQR format: SL|River|Site|HFL|DL|Yesterday|Current|Diff|BelowDanger|Trend|District
          if (cells.length < 10) continue;
          final river   = cells[1];
          final site    = cells[2].replaceAll('*','').trim();
          if (river.isEmpty || site.isEmpty) continue;

          final cur     = _dblStr(cells.length > 6  ? cells[6]  : '');
          final dl      = _dblStr(cells.length > 4  ? cells[4]  : '');
          final bd      = _dblStr(cells.length > 8  ? cells[8]  : '');

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
            source:       _source,
            fetchedAt:    now,
          ));
        } else if (isBeams) {
          // BEAMS direct format
          // Basin|River|Station|Type|MaintBy|OtherID|Year|HFL|DL|WL|Height|Block|District|
          // ObsDate|CurrentLevel|PrevLevel|TYPE|Trend|Status
          if (cells.length < 15) continue;
          final river   = cells[1];
          final site    = cells[2];
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
            source:       _source,
            fetchedAt:    now,
          ));
        }
      } catch (_) {}
    }

    if (kDebugMode) debugPrint('[WrdBihar] parsed ${result.length} stations from HTML');
    return result;
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  String _str(dynamic v)    => (v?.toString() ?? '').trim();
  double? _dbl(dynamic v)   => v == null ? null : double.tryParse(v.toString().trim());
  double? _dblStr(String s) {
    final clean = s.replaceAll(RegExp(r'[^\d.\-]'), '').trim();
    if (clean.isEmpty || clean == '-' || clean == 'NA') return null;
    return double.tryParse(clean);
  }

  /// Extract just the district name from "District / Block" cell.
  String _districtOnly(String s) {
    final parts = s.split('/');
    return parts.first.trim();
  }
}
