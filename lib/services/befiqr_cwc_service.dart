// lib/services/befiqr_cwc_service.dart
// Fetches live CWC Bihar station data from irrigation.befiqr.in
// Strategy:
//   1. Try live HTTP scrape of https://irrigation.befiqr.in/state/table/cwc-stations
//   2. On failure / timeout → fall back to the embedded 31-station seed snapshot
// The parsed data is exposed as a List<CwcStation> and fed into the
// existing flood_providers so the whole app benefits automatically.
library;

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

// ── model ─────────────────────────────────────────────────────────────────────

class CwcStation {
  final String river;
  final String site;
  final double currentLevel;  // metres
  final double dangerLevel;   // metres
  final DateTime fetchedAt;

  const CwcStation({
    required this.river,
    required this.site,
    required this.currentLevel,
    required this.dangerLevel,
    required this.fetchedAt,
  });

  double get gap         => dangerLevel - currentLevel; // positive = below danger
  bool   get isDanger    => gap <= 0;
  bool   get isWarning   => gap > 0 && gap <= 1.5;
  bool   get isElevated  => gap > 1.5 && gap <= 3.0;

  String get statusLabel {
    if (isDanger)   return 'DANGER';
    if (isWarning)  return 'WARNING';
    if (isElevated) return 'ELEVATED';
    return 'NORMAL';
  }

  /// 0-1 fill fraction toward danger level (clamped)
  double get fillFraction =>
      (currentLevel / dangerLevel).clamp(0.0, 1.0);

  Map<String, dynamic> toJson() => {
    'river':        river,
    'site':         site,
    'currentLevel': currentLevel,
    'dangerLevel':  dangerLevel,
    'fetchedAt':    fetchedAt.toIso8601String(),
  };

  factory CwcStation.fromJson(Map<String, dynamic> j) => CwcStation(
    river:        j['river'] as String,
    site:         j['site']  as String,
    currentLevel: (j['currentLevel'] as num).toDouble(),
    dangerLevel:  (j['dangerLevel']  as num).toDouble(),
    fetchedAt:    DateTime.parse(j['fetchedAt'] as String),
  );
}

// ── 31-station seed (snapshot from irrigation.befiqr.in, June 2026) ───────────

List<CwcStation> get _seedStations {
  final now = DateTime.now();
  return [
    CwcStation(river: 'Adhwara',      site: 'Ekmighat',                 currentLevel: 40.62, dangerLevel: 46.94, fetchedAt: now),
    CwcStation(river: 'Adhwara',      site: 'Kamtaul',                  currentLevel: 46.54, dangerLevel: 50.00, fetchedAt: now),
    CwcStation(river: 'Adhwara',      site: 'Sonbarsa',                 currentLevel: 78.78, dangerLevel: 81.85, fetchedAt: now),
    CwcStation(river: 'Bagmati',      site: 'Benibad',                  currentLevel: 46.25, dangerLevel: 48.68, fetchedAt: now),
    CwcStation(river: 'Bagmati',      site: 'Dheng Bridge',             currentLevel: 68.35, dangerLevel: 71.00, fetchedAt: now),
    CwcStation(river: 'Bagmati',      site: 'Hayaghat',                 currentLevel: 39.26, dangerLevel: 45.72, fetchedAt: now),
    CwcStation(river: 'Burhi Gandak', site: 'Khagaria',                 currentLevel: 29.99, dangerLevel: 36.58, fetchedAt: now),
    CwcStation(river: 'Burhi Gandak', site: 'Rosera',                   currentLevel: 36.31, dangerLevel: 42.63, fetchedAt: now),
    CwcStation(river: 'Burhi Gandak', site: 'Samastipur',               currentLevel: 39.28, dangerLevel: 46.00, fetchedAt: now),
    CwcStation(river: 'Burhi Gandak', site: 'Sikandarpur (Muzzafarpur)',currentLevel: 45.18, dangerLevel: 52.53, fetchedAt: now),
    CwcStation(river: 'Gandak',       site: 'Chatia',                   currentLevel: 64.99, dangerLevel: 69.15, fetchedAt: now),
    CwcStation(river: 'Gandak',       site: 'Dumariaghat',              currentLevel: 60.46, dangerLevel: 62.22, fetchedAt: now),
    CwcStation(river: 'Gandak',       site: 'Hajipur',                  currentLevel: 44.54, dangerLevel: 50.32, fetchedAt: now),
    CwcStation(river: 'Gandak',       site: 'Rewaghat',                 currentLevel: 51.12, dangerLevel: 54.41, fetchedAt: now),
    CwcStation(river: 'Ganga',        site: 'Bhagalpur',                currentLevel: 25.74, dangerLevel: 33.68, fetchedAt: now),
    CwcStation(river: 'Ganga',        site: 'Buxar',                    currentLevel: 49.19, dangerLevel: 60.30, fetchedAt: now),
    CwcStation(river: 'Ganga',        site: 'Dighaghat',                currentLevel: 43.05, dangerLevel: 50.45, fetchedAt: now),
    CwcStation(river: 'Ganga',        site: 'Gandhighat',               currentLevel: 42.61, dangerLevel: 48.60, fetchedAt: now),
    CwcStation(river: 'Ganga',        site: 'Hathidah',                 currentLevel: 34.60, dangerLevel: 41.76, fetchedAt: now),
    CwcStation(river: 'Ganga',        site: 'Kahalgaon',                currentLevel: 24.64, dangerLevel: 31.09, fetchedAt: now),
    CwcStation(river: 'Ganga',        site: 'Munger',                   currentLevel: 30.76, dangerLevel: 39.33, fetchedAt: now),
    CwcStation(river: 'Ghaghra',      site: 'Darauli',                  currentLevel: 56.20, dangerLevel: 60.82, fetchedAt: now),
    CwcStation(river: 'Ghaghra',      site: 'Gangpur Siswan',           currentLevel: 51.89, dangerLevel: 57.04, fetchedAt: now),
    CwcStation(river: 'Kamalabalan', site: 'Jhanjharpur',              currentLevel: 48.15, dangerLevel: 50.00, fetchedAt: now),
    CwcStation(river: 'Kamla',        site: 'Jainagar',                 currentLevel: 66.28, dangerLevel: 67.75, fetchedAt: now),
    CwcStation(river: 'Kosi',         site: 'Baltara',                  currentLevel: 31.28, dangerLevel: 33.85, fetchedAt: now),
    CwcStation(river: 'Kosi',         site: 'Basua',                    currentLevel: 45.82, dangerLevel: 47.75, fetchedAt: now),
    CwcStation(river: 'Kosi',         site: 'Kursela',                  currentLevel: 24.40, dangerLevel: 30.00, fetchedAt: now),
    CwcStation(river: 'Mahananda',    site: 'Dhengraghat',              currentLevel: 33.30, dangerLevel: 35.65, fetchedAt: now),
    CwcStation(river: 'Mahananda',    site: 'Taibpur',                  currentLevel: 63.72, dangerLevel: 66.00, fetchedAt: now),
    CwcStation(river: 'Punpun',       site: 'Sripalpur',                currentLevel: 44.81, dangerLevel: 50.60, fetchedAt: now),
  ];
}

// ── service ───────────────────────────────────────────────────────────────────

class BefiqrCwcService {
  static const _url =
      'https://irrigation.befiqr.in/state/table/cwc-stations';
  static const _timeout = Duration(seconds: 10);

  /// Fetch live data; falls back to seed on any error.
  Future<List<CwcStation>> fetchStations() async {
    try {
      final resp = await http
          .get(Uri.parse(_url),
              headers: {'Accept': 'text/html,application/xhtml+xml'})
          .timeout(_timeout);
      if (resp.statusCode == 200) {
        final parsed = _parseHtmlTable(resp.body);
        if (parsed.isNotEmpty) return parsed;
      }
    } catch (e) {
      debugPrint('[BefiqrCwcService] live fetch failed: $e — using seed');
    }
    return _seedStations;
  }

  // ── HTML table parser ──────────────────────────────────────────────────────
  // Parses <tr> rows from the CWC table on irrigation.befiqr.in.
  // Expected columns (0-indexed): 0=River, 1=Site, 2=CurrentLevel, 3=DangerLevel
  static List<CwcStation> _parseHtmlTable(String html) {
    final stations = <CwcStation>[];
    final now = DateTime.now();

    // Match <tr>...</tr> blocks (non-greedy)
    final rowRe = RegExp(r'<tr[^>]*>(.*?)</tr>', dotAll: true);
    final cellRe = RegExp(r'<t[dh][^>]*>(.*?)</t[dh]>', dotAll: true);
    final tagRe  = RegExp(r'<[^>]+>');

    bool headerSkipped = false;
    for (final rowMatch in rowRe.allMatches(html)) {
      final cells = cellRe
          .allMatches(rowMatch.group(1)!)
          .map((m) => m.group(1)!.replaceAll(tagRe, '').trim())
          .toList();

      if (cells.length < 4) continue;
      if (!headerSkipped) { headerSkipped = true; continue; } // skip header row

      final current = double.tryParse(cells[2].replaceAll(',', ''));
      final danger  = double.tryParse(cells[3].replaceAll(',', ''));
      if (current == null || danger == null) continue;

      stations.add(CwcStation(
        river:        cells[0],
        site:         cells[1],
        currentLevel: current,
        dangerLevel:  danger,
        fetchedAt:    now,
      ));
    }
    return stations;
  }

  // ── ML-style risk score (simple linear rule, 0-100) ───────────────────────
  // score = (currentLevel / dangerLevel) * 100, clamped to 0-100
  // Feeds the prediction engine as a real-time feature input.
  static double riskScore(CwcStation s) =>
      (s.currentLevel / s.dangerLevel * 100).clamp(0, 100);

  /// Returns the top-N stations closest to or above danger level.
  static List<CwcStation> topRisk(List<CwcStation> stations, {int n = 5}) {
    final sorted = [...stations]..sort(
        (a, b) => riskScore(b).compareTo(riskScore(a)));
    return sorted.take(n).toList();
  }

  /// Converts station list to JSON string (for offline cache).
  static String toJsonString(List<CwcStation> list) =>
      jsonEncode(list.map((s) => s.toJson()).toList());

  /// Parses JSON string back to station list.
  static List<CwcStation> fromJsonString(String raw) {
    final list = jsonDecode(raw) as List<dynamic>;
    return list.map((e) => CwcStation.fromJson(e as Map<String, dynamic>)).toList();
  }
}
