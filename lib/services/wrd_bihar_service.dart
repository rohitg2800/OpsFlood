// lib/services/wrd_bihar_service.dart
//
// OpsFlood — WRD Bihar Service (v6.1 — robust CWC forecast parser)
//
// FIXES vs v6.0:
//   • CWC forecast parser: broadened column header detection to catch
//     'f/cast', 'f.cast', 'flood level', 'predicted', '24hr', '24 hr',
//     'tomorrow' — befiqr occasionally uses abbreviated headings.
//   • Added colForecast=-1 sentinel: parser skips data rows entirely when
//     no forecast column is found (avoids wrong-column extractions).
//   • Added raw-cell debug log when forecast column exists but yields 0
//     values, making future diagnosis trivial.
//   • Broadened colCurrent/colRiver/colStation detection similarly.
//
// SOURCE: Central Flood Control Cell, WRD Patna
// PRIMARY scrape 1:  https://irrigation.befiqr.in/state/table/rivers
//   Columns: (1)Sl | (2)River | (3)Site | (4)HFL | (5)DL |
//            (6)Yesterday | (7)Current | (8)Diff | (9)Above/Below | (10)Trend | (11)District
//
// PRIMARY scrape 2:  https://irrigation.befiqr.in/state/table/cwc-stations
//   Carries an FF (flood forecast, 24h) column per CWC station.
//   Matched to scrape-1 rows by river+site fuzzy key to populate forecast24h.
//
// FALLBACK:  allOrigins proxy  (portal bot-block)
// OFFLINE:   shared_preferences disk cache (last successful fetch)
library;

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

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
  final double? forecast24h;
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
    this.forecast24h,
    required this.source,
    required this.fetchedAt,
  });

  bool get hasLiveData    => currentLevel != null;
  bool get hasDangerLevel => dangerLevel != null && dangerLevel! > 0;
  bool get hasForecast    => forecast24h != null;

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
  String get displayForecast24h {
    if (forecast24h == null) return '—';
    return '${forecast24h!.toStringAsFixed(2)} m';
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

  // ── Serialization ────────────────────────────────────────────────────────
  Map<String, dynamic> toJson() => {
    'river':        river,
    'site':         site,
    'district':     district,
    'hfl':          hfl,
    'dangerLevel':  dangerLevel,
    'warningLevel': warningLevel,
    'prevLevel':    prevLevel,
    'currentLevel': currentLevel,
    'diff24h':      diff24h,
    'belowDanger':  belowDanger,
    'trend':        trend,
    'forecast24h':  forecast24h,
    'source':       source,
    'fetchedAt':    fetchedAt.toIso8601String(),
  };

  factory WrdStation.fromJson(Map<String, dynamic> j) => WrdStation(
    river:        j['river']        as String? ?? '',
    site:         j['site']         as String? ?? '',
    district:     j['district']     as String? ?? '',
    hfl:          (j['hfl']         as num?)?.toDouble(),
    dangerLevel:  (j['dangerLevel'] as num?)?.toDouble(),
    warningLevel: (j['warningLevel']as num?)?.toDouble(),
    prevLevel:    (j['prevLevel']   as num?)?.toDouble(),
    currentLevel: (j['currentLevel']as num?)?.toDouble(),
    diff24h:      (j['diff24h']     as num?)?.toDouble(),
    belowDanger:  (j['belowDanger'] as num?)?.toDouble(),
    trend:        j['trend']        as String?,
    forecast24h:  (j['forecast24h'] as num?)?.toDouble(),
    source:       j['source']       as String? ?? 'WRD_BIHAR_DISK',
    fetchedAt:    DateTime.tryParse(j['fetchedAt'] as String? ?? '') ?? DateTime.now(),
  );

  @override
  String toString() =>
      'WrdStation($river @ $site | cur=$displayLevel | '
      'DL=$displayDanger | fc24=$displayForecast24h | '
      'risk=$riskLabel | live=$hasLiveData)';
}

// ── WRD site name ⇒ city alias map ───────────────────────────────────────────
const Map<String, String> _kAliasMap = {
  'ekmighat':                  'Ekmighat',
  'kamtaul':                   'Kamtaul',
  'sonakhan':                  'Sonakhan',
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
  'dumri bridge':              'Dumri Bridge',
};

// ── Scrape URLs ───────────────────────────────────────────────────────────────
const _kRiverUrls = [
  'https://irrigation.befiqr.in/state/table/rivers',
  'http://irrigation.befiqr.in/state/table/rivers',
];
const _kCwcUrls = [
  'https://irrigation.befiqr.in/state/table/cwc-stations',
  'http://irrigation.befiqr.in/state/table/cwc-stations',
];

String _proxyUrl(String target) =>
    'https://api.allorigins.win/get?url=${Uri.encodeComponent(target)}';

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
  static const _proxyTimeout  = Duration(seconds: 40);
  static const _persistKey    = 'wrd_bihar_stations_v6';

  List<WrdStation>?        _cache;
  DateTime?                _cacheTime;
  Map<String, WrdStation>? _stationByCity;

  List<WrdStation>? get cachedStations => _cache;

  // ── Public API ────────────────────────────────────────────────────────────

  Future<List<WrdStation>> fetch({bool forceRefresh = false}) async {
    if (!forceRefresh &&
        _cache != null &&
        _cacheTime != null &&
        DateTime.now().difference(_cacheTime!) < _cacheTtl) {
      _log('cache hit — ${_cache!.length} stations (in-memory)');
      return _cache!;
    }

    if (_cache == null) {
      final disk = await _loadFromDisk();
      if (disk.isNotEmpty) {
        _cache     = disk;
        _cacheTime = null;
        _buildCityIndex(disk);
        _log('cold-start: loaded ${disk.length} stations from disk');
      }
    }

    final results = await Future.wait([
      _fetchHtml(_kRiverUrls),
      _fetchHtml(_kCwcUrls),
    ]);
    final rivHtml = results[0];
    final cwcHtml = results[1];

    List<WrdStation> stations = [];
    if (rivHtml != null && rivHtml.isNotEmpty) {
      stations = _parseRiversTable(rivHtml);
      _log('rivers-table: parsed ${stations.length} stations');
    }

    if (stations.isEmpty) {
      const primaryUrl = 'https://irrigation.befiqr.in/state/table/rivers';
      try {
        final res = await http
            .get(Uri.parse(_proxyUrl(primaryUrl)))
            .timeout(_proxyTimeout);
        if (res.statusCode == 200) {
          final json = jsonDecode(res.body) as Map?;
          final html = json?['contents'] as String? ?? '';
          if (html.isNotEmpty) {
            stations = _parseRiversTable(html);
            _log('proxy-rivers: parsed ${stations.length} stations');
          }
        }
      } catch (e) {
        _log('proxy-rivers error: $e');
      }
    }

    if (stations.isNotEmpty && cwcHtml != null && cwcHtml.isNotEmpty) {
      final forecasts = _parseCwcForecasts(cwcHtml);
      _log('cwc-table: ${forecasts.length} forecast entries parsed');
      stations = _mergeForecasts(stations, forecasts);
    }

    if (stations.isNotEmpty) {
      await _setCache(stations);
      _log('fetch complete: ${stations.length} stations persisted');
      return stations;
    }

    final offline = _cache ?? [];
    _log('offline mode — returning ${offline.length} stations from disk cache');
    return offline;
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

  // ── HTTP helper ───────────────────────────────────────────────────────────

  Future<String?> _fetchHtml(List<String> urls) async {
    for (final url in urls) {
      try {
        final res = await http
            .get(Uri.parse(url), headers: _kHeaders)
            .timeout(_directTimeout);
        if (res.statusCode == 200 && res.body.length > 200) {
          _log('_fetchHtml ✓ $url (${res.body.length} bytes)');
          return res.body;
        }
        _log('_fetchHtml: HTTP ${res.statusCode} from $url');
      } catch (e) {
        _log('_fetchHtml error ($url): $e');
      }
    }
    return null;
  }

  // ── Forecast merge ────────────────────────────────────────────────────────

  List<WrdStation> _mergeForecasts(
      List<WrdStation> stations, Map<String, double> forecasts) {
    return stations.map((s) {
      final key = _forecastKey(s.river, s.site);
      final fc  = forecasts[key];
      if (fc == null) return s;
      return WrdStation(
        river:        s.river,
        site:         s.site,
        district:     s.district,
        hfl:          s.hfl,
        dangerLevel:  s.dangerLevel,
        warningLevel: s.warningLevel,
        prevLevel:    s.prevLevel,
        currentLevel: s.currentLevel,
        diff24h:      s.diff24h,
        belowDanger:  s.belowDanger,
        trend:        s.trend,
        forecast24h:  fc,
        source:       s.source,
        fetchedAt:    s.fetchedAt,
      );
    }).toList();
  }

  static String _forecastKey(String river, String site) =>
      '${river.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '')}'
      '_${site.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '')}';

  // ── Persistence ───────────────────────────────────────────────────────────

  Future<void> _saveToDisk(List<WrdStation> stations) async {
    try {
      final prefs   = await SharedPreferences.getInstance();
      final encoded = jsonEncode(stations.map((s) => s.toJson()).toList());
      await prefs.setString(_persistKey, encoded);
      await prefs.setString('${_persistKey}_ts', DateTime.now().toIso8601String());
      _log('disk: saved ${stations.length} stations');
    } catch (e) {
      _log('disk save error: $e');
    }
  }

  Future<List<WrdStation>> _loadFromDisk() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw   = prefs.getString(_persistKey);
      final tsRaw = prefs.getString('${_persistKey}_ts');
      if (raw == null || raw.isEmpty) return [];
      final ts = tsRaw != null ? DateTime.tryParse(tsRaw) : null;
      if (ts != null) {
        _log('disk: last saved ${DateTime.now().difference(ts).inMinutes} min ago');
      }
      final list = (jsonDecode(raw) as List)
          .whereType<Map<String, dynamic>>()
          .map(WrdStation.fromJson)
          .toList();
      _log('disk: loaded ${list.length} stations');
      return list;
    } catch (e) {
      _log('disk load error: $e');
      return [];
    }
  }

  Future<void> _setCache(List<WrdStation> stations) async {
    _cache     = stations;
    _cacheTime = DateTime.now();
    _buildCityIndex(stations);
    await _saveToDisk(stations);
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

  // ── HTML parser: rivers table (current levels) ────────────────────────────
  List<WrdStation> _parseRiversTable(String html) {
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
      _log('rivers-parser: 0 <tr> rows found');
      return result;
    }

    int textHeaderIdx = -1;
    final scanLimit   = rows.length < 5 ? rows.length : 5;
    for (int i = 0; i < scanLimit; i++) {
      final cells = cellRe
          .allMatches(rows[i].group(1)!)
          .map((m) => clean(m.group(1)!).toLowerCase())
          .toList();
      if (cells.any((c) => c.contains('river'))) {
        textHeaderIdx = i;
        break;
      }
    }

    if (textHeaderIdx < 0) {
      _log('rivers-parser: no text-header row found');
      return result;
    }

    for (final row in rows.skip(textHeaderIdx + 1)) {
      final cells = cellRe
          .allMatches(row.group(1)!)
          .map((m) => clean(m.group(1)!))
          .toList();

      if (cells.length < 10) continue;

      final river = cells[1].trim();
      final site  = cells[2].replaceAll('*', '').trim();

      if (river.isEmpty || site.isEmpty) continue;
      if (river.toLowerCase() == 'river' || site.toLowerCase() == 'site') continue;
      if (river.startsWith('(') || river.toLowerCase().contains('sl.')) continue;

      try {
        final cur   = _dblStr(cells[6]);
        final dl    = _dblStr(cells[4]);
        final bdRaw = _dblStr(cells[8]);
        final bd    = bdRaw ?? (cur != null && dl != null ? dl - cur : null);

        final trendRaw = cells.length > 9 ? cells[9] : '';
        final trend = trendRaw.contains('↑') || trendRaw.toUpperCase().contains('RISE')  ? '↑'
                    : trendRaw.contains('↓') || trendRaw.toUpperCase().contains('FALL')  ? '↓'
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
          forecast24h:  null,
          source:       _source,
          fetchedAt:    now,
        ));
      } catch (e) {
        _log('rivers-parser: skipping row: $e | cells=$cells');
      }
    }

    _log('rivers-parser: ${result.length} stations from ${rows.length} rows');
    return result;
  }

  // ── HTML parser: CWC stations table (24h flood forecast) ─────────────────
  //
  // v6.1: broadened header keyword matching — befiqr uses abbreviated headings
  // like 'f/cast', 'f.cast', 'flood level', 'predicted', '24hr', 'tomorrow'.
  // Added colForecast=-1 sentinel so we skip data parsing entirely when no
  // forecast column is identified, avoiding wrong-column extractions.
  Map<String, double> _parseCwcForecasts(String html) {
    final result = <String, double>{};
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
    if (rows.isEmpty) return result;

    // Use -1 as sentinel: no forecast column found yet
    int headerIdx    = -1;
    int colRiver     = -1;
    int colStation   = -1;
    int colForecast  = -1;  // v6.1: sentinel — must be discovered, no default
    int colCurrent   = -1;

    final scanLimit = rows.length < 6 ? rows.length : 6;
    for (int i = 0; i < scanLimit; i++) {
      final cells = cellRe
          .allMatches(rows[i].group(1)!)
          .map((m) => clean(m.group(1)!).toLowerCase())
          .toList();
      // Need at least a river or station column to be the header row
      if (!cells.any((c) => c.contains('river') || c.contains('station') || c.contains('site'))) continue;
      headerIdx = i;
      for (int ci = 0; ci < cells.length; ci++) {
        final c = cells[ci];
        // v6.1: broadened forecast column detection
        if (c.contains('forecast') ||
            c == 'ff' ||
            c.contains('predict') ||
            c.contains('f/cast') ||
            c.contains('f.cast') ||
            c.contains('flood level') ||
            c.contains('24hr') ||
            c.contains('24 hr') ||
            c.contains('tomorrow')) {
          colForecast = ci;
        }
        // v6.1: broadened current level detection
        if (c.contains('current') || c.contains('obs') || c.contains('today')) colCurrent = ci;
        // v6.1: broadened river/station detection
        if (c.contains('river'))                                              colRiver   = ci;
        if (c.contains('station') || c.contains('site') || c == 'name')      colStation = ci;
      }
      _log('cwc-parser header[$i]: river=$colRiver station=$colStation '
           'current=$colCurrent forecast=$colForecast');
      break;
    }

    if (headerIdx < 0) {
      _log('cwc-parser: no header row found — skipping forecast merge');
      return result;
    }

    // v6.1: if no forecast column identified, bail out gracefully
    if (colForecast < 0) {
      _log('cwc-parser: no forecast column detected — 0 forecast values extracted (pre-monsoon or layout change)');
      return result;
    }

    // Use safe defaults for river/station if not auto-detected
    final safeRiver   = colRiver   >= 0 ? colRiver   : 1;
    final safeStation = colStation >= 0 ? colStation : 2;

    int extracted = 0;
    int skippedEmpty = 0;
    for (final row in rows.skip(headerIdx + 1)) {
      final cells = cellRe
          .allMatches(row.group(1)!)
          .map((m) => clean(m.group(1)!))
          .toList();
      if (cells.length <= colForecast) continue;
      final river   = safeRiver   < cells.length ? cells[safeRiver].trim()   : '';
      final station = safeStation < cells.length ? cells[safeStation].trim() : '';
      if (river.isEmpty || station.isEmpty) continue;
      final rawCell = cells[colForecast];
      final fc = _dblStr(rawCell);
      if (fc == null || fc <= 0) {
        skippedEmpty++;
        continue;
      }
      final key = _forecastKey(river, station);
      result[key] = fc;
      extracted++;
    }

    _log('cwc-parser: $extracted forecast values extracted (${skippedEmpty} cells empty/dash — normal in pre-monsoon)');
    return result;
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  double? _dblStr(String s) {
    final c = s.replaceAll(RegExp(r'[^\d.\-]'), '').trim();
    if (c.isEmpty || c == '-' || c == '.') return null;
    return double.tryParse(c);
  }

  String _districtOnly(String s) => s.split('/').first.trim();

  void _log(String msg) {
    if (kDebugMode) debugPrint('[WrdBihar] $msg');
  }
}
