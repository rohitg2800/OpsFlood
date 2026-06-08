// lib/services/befiqr_cwc_service.dart
//
// Live CWC + WRD Bihar station data — unified scraper
//
// SOURCE PRIORITY (tried in order, first success wins):
//
//   1. BEAMS Bihar (beams.fmiscwrdbihar.gov.in/Alerttotalinfo/realtimetotal.aspx)
//      Plain HTML table, no JS rendering, updated every 3 hours by Bihar WRD.
//      Covers ALL major Bihar river stations (32+).
//      Datum: Bihar WRD local (converted → CWC AMSL via per-river offset table)
//
//   2. irrigation.befiqr.in/state/table/cwc-stations
//      Bihar irrigation dept mirror. Datum: CWC AMSL already.
//
//   3. Embedded 32-station seed snapshot (CWC official levels, June 2026)
//      Never fails. Used when both live sources are unreachable.
//
// DATUM CONVERSION:
//   BEAMS reports water levels in Bihar WRD local datum.
//   Each river/station has a fixed gauge-zero offset vs CWC AMSL.
//   Offset table below is calibrated from CWC flood bulletin cross-refs.
//   Formula: AMSL = WRD_reading + WRD_offset
//
library;

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;

// ─────────────────────────────────────────────────────────────────────────────
// WRD → AMSL offset table (metres)
// Derived by cross-referencing: CWC Bihar flood bulletin danger levels (AMSL)
// vs BEAMS Bihar danger levels (WRD local) for the same stations.
// e.g. Kosi/Birpur: BEAMS danger=74.70m, CWC danger=214.00m → offset=+139.30
// ─────────────────────────────────────────────────────────────────────────────
const Map<String, double> _kWrdToAmslOffset = {
  // River name (lowercase) → gauge-zero offset in metres
  'kosi':         139.30,  // Birpur: 74.70+139.30=214.00 ✓
  'gandak':         0.00,  // Gandak stations already in AMSL on BEAMS
  'ganga':          0.00,  // Ganga stations already in AMSL
  'ghaghra':        0.00,
  'bagmati':        0.00,
  'burhi gandak':   0.00,
  'mahananda':      0.00,
  'kamla':          0.00,
  'kamalabalan':    0.00,
  'adhwara':        0.00,
  'punpun':         0.00,
  'son':            0.00,
  'budhi gandak':   0.00,  // alt spelling
  'buri gandak':    0.00,
};

/// Returns 0.0 for any river not in the table (safe default — no conversion)
double _wrdOffset(String river) {
  final key = river.toLowerCase().trim();
  for (final entry in _kWrdToAmslOffset.entries) {
    if (key.contains(entry.key)) return entry.value;
  }
  return 0.0;
}

// ─────────────────────────────────────────────────────────────────────────────
// CwcStation model
// ─────────────────────────────────────────────────────────────────────────────

class CwcStation {
  final String river;
  final String site;
  final double currentLevel;   // metres AMSL
  final double dangerLevel;    // metres AMSL
  final double? warningLevel;  // metres AMSL (null if unknown)
  final String? trend;         // 'Rising' | 'Falling' | 'Steady' | null
  final String? status;        // raw status string from source
  final String  source;        // 'BEAMS' | 'befiqr' | 'SEED'
  final DateTime fetchedAt;

  const CwcStation({
    required this.river,
    required this.site,
    required this.currentLevel,
    required this.dangerLevel,
    this.warningLevel,
    this.trend,
    this.status,
    this.source = 'SEED',
    required this.fetchedAt,
  });

  double get gap        => dangerLevel - currentLevel;
  bool   get isDanger   => gap <= 0;
  bool   get isWarning  => gap > 0 && gap <= 1.5;
  bool   get isElevated => gap > 1.5 && gap <= 3.0;

  String get statusLabel {
    if (isDanger)   return 'DANGER';
    if (isWarning)  return 'WARNING';
    if (isElevated) return 'ELEVATED';
    return 'NORMAL';
  }

  double get fillFraction =>
      (currentLevel / dangerLevel).clamp(0.0, 1.0);

  Map<String, dynamic> toJson() => {
    'river':        river,
    'site':         site,
    'currentLevel': currentLevel,
    'dangerLevel':  dangerLevel,
    if (warningLevel != null) 'warningLevel': warningLevel,
    if (trend  != null) 'trend':  trend,
    if (status != null) 'status': status,
    'source':    source,
    'fetchedAt': fetchedAt.toIso8601String(),
  };

  factory CwcStation.fromJson(Map<String, dynamic> j) => CwcStation(
    river:        j['river']  as String,
    site:         j['site']   as String,
    currentLevel: (j['currentLevel'] as num).toDouble(),
    dangerLevel:  (j['dangerLevel']  as num).toDouble(),
    warningLevel: j['warningLevel'] != null
        ? (j['warningLevel'] as num).toDouble() : null,
    trend:    j['trend']  as String?,
    status:   j['status'] as String?,
    source:   (j['source'] as String?) ?? 'SEED',
    fetchedAt: DateTime.parse(j['fetchedAt'] as String),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// 32-station seed snapshot (CWC official, June 2026)
// ─────────────────────────────────────────────────────────────────────────────

List<CwcStation> get _seedStations {
  final now = DateTime.now();
  return [
    CwcStation(river: 'Adhwara',      site: 'Ekmighat',                  currentLevel: 40.62, dangerLevel: 46.94, fetchedAt: now),
    CwcStation(river: 'Adhwara',      site: 'Kamtaul',                   currentLevel: 46.54, dangerLevel: 50.00, fetchedAt: now),
    CwcStation(river: 'Adhwara',      site: 'Sonbarsa',                  currentLevel: 78.78, dangerLevel: 81.85, fetchedAt: now),
    CwcStation(river: 'Bagmati',      site: 'Benibad',                   currentLevel: 46.25, dangerLevel: 48.68, fetchedAt: now),
    CwcStation(river: 'Bagmati',      site: 'Dheng Bridge',              currentLevel: 68.35, dangerLevel: 71.00, fetchedAt: now),
    CwcStation(river: 'Bagmati',      site: 'Hayaghat',                  currentLevel: 39.26, dangerLevel: 45.72, fetchedAt: now),
    CwcStation(river: 'Burhi Gandak', site: 'Khagaria',                  currentLevel: 29.99, dangerLevel: 36.58, fetchedAt: now),
    CwcStation(river: 'Burhi Gandak', site: 'Rosera',                    currentLevel: 36.31, dangerLevel: 42.63, fetchedAt: now),
    CwcStation(river: 'Burhi Gandak', site: 'Samastipur',                currentLevel: 39.28, dangerLevel: 46.00, fetchedAt: now),
    CwcStation(river: 'Burhi Gandak', site: 'Sikandarpur (Muzzafarpur)', currentLevel: 45.18, dangerLevel: 52.53, fetchedAt: now),
    CwcStation(river: 'Gandak',       site: 'Chatia',                    currentLevel: 64.99, dangerLevel: 69.15, fetchedAt: now),
    CwcStation(river: 'Gandak',       site: 'Dumariaghat',               currentLevel: 60.46, dangerLevel: 62.22, fetchedAt: now),
    CwcStation(river: 'Gandak',       site: 'Hajipur',                   currentLevel: 44.54, dangerLevel: 50.32, fetchedAt: now),
    CwcStation(river: 'Gandak',       site: 'Rewaghat',                  currentLevel: 51.12, dangerLevel: 54.41, fetchedAt: now),
    CwcStation(river: 'Ganga',        site: 'Bhagalpur',                 currentLevel: 25.74, dangerLevel: 33.68, fetchedAt: now),
    CwcStation(river: 'Ganga',        site: 'Buxar',                     currentLevel: 49.19, dangerLevel: 60.30, fetchedAt: now),
    CwcStation(river: 'Ganga',        site: 'Dighaghat',                 currentLevel: 43.05, dangerLevel: 50.45, fetchedAt: now),
    CwcStation(river: 'Ganga',        site: 'Gandhighat',                currentLevel: 42.61, dangerLevel: 48.60, fetchedAt: now),
    CwcStation(river: 'Ganga',        site: 'Hathidah',                  currentLevel: 34.60, dangerLevel: 41.76, fetchedAt: now),
    CwcStation(river: 'Ganga',        site: 'Kahalgaon',                 currentLevel: 24.64, dangerLevel: 31.09, fetchedAt: now),
    CwcStation(river: 'Ganga',        site: 'Munger',                    currentLevel: 30.76, dangerLevel: 39.33, fetchedAt: now),
    CwcStation(river: 'Ghaghra',      site: 'Darauli',                   currentLevel: 56.20, dangerLevel: 60.82, fetchedAt: now),
    CwcStation(river: 'Ghaghra',      site: 'Gangpur Siswan',            currentLevel: 51.89, dangerLevel: 57.04, fetchedAt: now),
    CwcStation(river: 'Kamalabalan',  site: 'Jhanjharpur',               currentLevel: 48.15, dangerLevel: 50.00, fetchedAt: now),
    CwcStation(river: 'Kamla',        site: 'Jainagar',                  currentLevel: 66.28, dangerLevel: 67.75, fetchedAt: now),
    CwcStation(river: 'Kosi',         site: 'Baltara',                   currentLevel: 31.28, dangerLevel: 33.85, fetchedAt: now),
    CwcStation(river: 'Kosi',         site: 'Basua',                     currentLevel: 45.82, dangerLevel: 47.75, fetchedAt: now),
    CwcStation(river: 'Kosi',         site: 'Birpur',                    currentLevel: 212.05, dangerLevel: 214.00, fetchedAt: now),
    CwcStation(river: 'Kosi',         site: 'Kursela',                   currentLevel: 24.40, dangerLevel: 30.00, fetchedAt: now),
    CwcStation(river: 'Mahananda',    site: 'Dhengraghat',               currentLevel: 33.30, dangerLevel: 35.65, fetchedAt: now),
    CwcStation(river: 'Mahananda',    site: 'Taibpur',                   currentLevel: 63.72, dangerLevel: 66.00, fetchedAt: now),
    CwcStation(river: 'Punpun',       site: 'Sripalpur',                 currentLevel: 44.81, dangerLevel: 50.60, fetchedAt: now),
  ];
}

// ─────────────────────────────────────────────────────────────────────────────
// BefiqrCwcService — unified Bihar station scraper
// ─────────────────────────────────────────────────────────────────────────────

class BefiqrCwcService {
  static const _befiqrUrl =
      'https://irrigation.befiqr.in/state/table/cwc-stations';
  static const _beamsUrl =
      'https://beams.fmiscwrdbihar.gov.in/Alerttotalinfo/realtimetotal.aspx';
  static const _timeout = Duration(seconds: 12);

  /// Fetch all Bihar stations — BEAMS first, befiqr fallback, then seed.
  /// Never throws.
  Future<List<CwcStation>> fetchStations() async {
    // 1️⃣  BEAMS Bihar — most authoritative, plain HTML, no auth
    try {
      final beams = await _fetchBeams();
      if (beams.isNotEmpty) {
        debugPrint('[BefiqrCwcService] BEAMS ✅ ${beams.length} stations');
        return beams;
      }
    } catch (e) {
      debugPrint('[BefiqrCwcService] BEAMS failed: $e');
    }

    // 2️⃣  irrigation.befiqr.in
    try {
      final resp = await http
          .get(Uri.parse(_befiqrUrl),
              headers: {'Accept': 'text/html,application/xhtml+xml'})
          .timeout(_timeout);
      if (resp.statusCode == 200) {
        final parsed = parseHtmlTable(resp.body);
        if (parsed.isNotEmpty) {
          debugPrint('[BefiqrCwcService] befiqr ✅ ${parsed.length} stations');
          return parsed;
        }
      }
    } catch (e) {
      debugPrint('[BefiqrCwcService] befiqr failed: $e');
    }

    // 3️⃣  Seed
    debugPrint('[BefiqrCwcService] ⚠️ all sources failed — using seed');
    return _seedStations;
  }

  // ── BEAMS scraper ──────────────────────────────────────────────────────────
  // Table columns (0-based, from BEAMS Bihar realtimetotal.aspx):
  //  0  = Basin
  //  1  = River
  //  2  = Station Name
  //  3  = Type (CWC/WRD)
  //  4  = Maintained By
  //  5  = Other Station ID
  //  6  = Year Estd
  //  7  = HFL (m)
  //  8  = Danger Level (m)       ← WRD local datum
  //  9  = Warning Level (m)      ← WRD local datum
  //  10 = Height (emb/bridge)
  //  11 = Block
  //  12 = District
  //  13 = Current Observed Date  e.g. "04-Jun-2026 09 HRS"
  //  14 = Current Observed WL (m) ← WRD local datum
  //  15 = WL 1hr Before (m)
  //  16 = Type2
  //  17 = Trend                  "Rising" | "Falling" | "Steady"
  //  18 = Status                 "Above Danger" | "Above Warning" | "Normal" …

  Future<List<CwcStation>> _fetchBeams() async {
    final resp = await http.get(
      Uri.parse(_beamsUrl),
      headers: {
        'Accept':          'text/html,application/xhtml+xml',
        'User-Agent':      'Mozilla/5.0 (OpsFlood/2.0)',
        'Accept-Language': 'en-IN,en;q=0.9',
      },
    ).timeout(_timeout);

    if (resp.statusCode != 200) {
      debugPrint('[BEAMS] HTTP ${resp.statusCode}');
      return [];
    }

    return _parseBeamsHtml(resp.body);
  }

  static List<CwcStation> _parseBeamsHtml(String htmlBody) {
    final stations = <CwcStation>[];
    final now      = DateTime.now();

    final doc  = html_parser.parse(htmlBody);
    final rows = doc.querySelectorAll('table tr');

    bool headerSkipped = false;
    for (final row in rows) {
      final cells = row
          .querySelectorAll('td')
          .map((td) => td.text.trim())
          .toList();

      // Need at least 15 columns
      if (cells.length < 15) continue;

      // Skip header row(s)
      if (!headerSkipped) {
        headerSkipped = true;
        continue;
      }

      final riverRaw   = cells[1].trim();
      final siteRaw    = cells[2].trim();
      if (riverRaw.isEmpty || siteRaw.isEmpty) continue;

      // Column 14 = Current Observed Water Level (WRD local datum)
      final wrdLevel   = _parseDbl(cells[14]);
      // Column 8  = Danger Level (WRD local datum)
      final wrdDanger  = _parseDbl(cells[8]);
      // Column 9  = Warning Level (WRD local datum)
      final wrdWarning = _parseDbl(cells[9]);
      // Column 17 = Trend
      final trend  = cells.length > 17 ? cells[17].trim() : null;
      // Column 18 = Status
      final status = cells.length > 18 ? cells[18].trim() : null;
      // Column 13 = Observed date string
      final obsDate = cells.length > 13
          ? (_parseBEAMSDate(cells[13]) ?? now)
          : now;

      if (wrdLevel == null || wrdLevel <= 0) continue;
      if (wrdDanger == null || wrdDanger <= 0) continue;

      // Convert WRD local datum → CWC AMSL
      final offset   = _wrdOffset(riverRaw);
      final amslLevel   = wrdLevel   + offset;
      final amslDanger  = wrdDanger  + offset;
      final amslWarning = wrdWarning != null ? wrdWarning + offset : null;

      stations.add(CwcStation(
        river:        riverRaw,
        site:         siteRaw,
        currentLevel: amslLevel,
        dangerLevel:  amslDanger,
        warningLevel: amslWarning,
        trend:        trend?.isNotEmpty == true ? trend : null,
        status:       status?.isNotEmpty == true ? status : null,
        source:       'BEAMS',
        fetchedAt:    obsDate,
      ));
    }

    debugPrint('[BEAMS] parsed ${stations.length} stations from HTML');
    return stations;
  }

  // ── befiqr HTML parser (legacy, kept for fallback) ────────────────────────
  // Public so KosiBirpurService can reuse it directly.
  // Columns on befiqr table: 0=River, 1=Site, 2=CurrentLevel, 3=DangerLevel

  static List<CwcStation> parseHtmlTable(String html) {
    final stations = <CwcStation>[];
    final now      = DateTime.now();

    final rowRe  = RegExp(r'<tr[^>]*>(.*?)</tr>',  dotAll: true);
    final cellRe = RegExp(r'<t[dh][^>]*>(.*?)</t[dh]>', dotAll: true);
    final tagRe  = RegExp(r'<[^>]+>');

    bool headerSkipped = false;
    for (final rowMatch in rowRe.allMatches(html)) {
      final cells = cellRe
          .allMatches(rowMatch.group(1)!)
          .map((m) => m.group(1)!.replaceAll(tagRe, '').trim())
          .toList();

      if (cells.length < 4) continue;
      if (!headerSkipped) { headerSkipped = true; continue; }

      final current = double.tryParse(cells[2].replaceAll(',', ''));
      final danger  = double.tryParse(cells[3].replaceAll(',', ''));
      if (current == null || danger == null) continue;

      stations.add(CwcStation(
        river:        cells[0],
        site:         cells[1],
        currentLevel: current,
        dangerLevel:  danger,
        source:       'befiqr',
        fetchedAt:    now,
      ));
    }
    return stations;
  }

  // ── Utilities ─────────────────────────────────────────────────────────────

  /// Parse BEAMS date string: "04-Jun-2026 09 HRS" → DateTime
  static DateTime? _parseBEAMSDate(String s) {
    try {
      const months = {
        'Jan': '01', 'Feb': '02', 'Mar': '03', 'Apr': '04',
        'May': '05', 'Jun': '06', 'Jul': '07', 'Aug': '08',
        'Sep': '09', 'Oct': '10', 'Nov': '11', 'Dec': '12',
      };
      // "04-Jun-2026 09 HRS" → "04-06-2026 09:00"
      var cleaned = s.replaceAll(RegExp(r'\s+HRS?', caseSensitive: false), ':00');
      for (final e in months.entries) {
        cleaned = cleaned.replaceAll(e.key, e.value);
      }
      final parts = cleaned.split(' ');
      if (parts.length >= 2) {
        final dp = parts[0].split('-');
        if (dp.length == 3) {
          return DateTime.tryParse(
              '${dp[2]}-${dp[1]}-${dp[0]}T${parts[1]}:00');
        }
      }
    } catch (_) {}
    return null;
  }

  static double? _parseDbl(String? v) {
    if (v == null || v.isEmpty) return null;
    return double.tryParse(
        v.replaceAll(RegExp(r'[^\d.]'), '').trim());
  }

  // ── Analytics helpers ─────────────────────────────────────────────────────

  static double riskScore(CwcStation s) =>
      (s.currentLevel / s.dangerLevel * 100).clamp(0, 100);

  static List<CwcStation> topRisk(List<CwcStation> stations, {int n = 5}) {
    final sorted = [...stations]
      ..sort((a, b) => riskScore(b).compareTo(riskScore(a)));
    return sorted.take(n).toList();
  }

  static String toJsonString(List<CwcStation> list) =>
      jsonEncode(list.map((s) => s.toJson()).toList());

  static List<CwcStation> fromJsonString(String raw) {
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => CwcStation.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
