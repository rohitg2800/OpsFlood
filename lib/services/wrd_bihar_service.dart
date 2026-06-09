// lib/services/wrd_bihar_service.dart
//
// OpsFlood — WRD Bihar Service (v7.0 — backend-only)
//
// All BeFIQR HTML scraping has been moved to the Python backend.
// This service is now a thin wrapper that:
//   1. Calls GET /api/live-levels?state=Bihar on the backend.
//   2. Deserialises the JSON into WrdStation objects.
//   3. Caches results in memory (15 min TTL) and on disk via
//      shared_preferences for offline fallback.
//
// The backend handles:
//   • Direct BeFIQR scrape + allOrigins proxy fallback
//   • CWC forecast merge
//   • Risk label computation (CRITICAL / HIGH / MODERATE / LOW)
library;

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'backend_api_service.dart';

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
  bool get hasDangerLevel => dangerLevel  != null && dangerLevel! > 0;
  bool get hasForecast    => forecast24h  != null;

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

  // ── Risk label — aligned with backend thresholds ─────────────────────────
  // Backend: CRITICAL=<=0m, HIGH=<=3m, MODERATE=<=6m, LOW=>6m
  String get riskLabel {
    final bd = belowDanger;
    if (!hasLiveData && !hasDangerLevel) return 'PRE-MONSOON';
    if (!hasLiveData) return 'NA';
    if (bd == null && dangerLevel == null) return 'UNKNOWN';
    final margin = bd ?? (dangerLevel! - currentLevel!);
    if (margin <= 0)   return 'CRITICAL';
    if (margin <= 3.0) return 'HIGH';
    if (margin <= 6.0) return 'MODERATE';
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

  // ── Serialization ─────────────────────────────────────────────────────────
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
    site:         j['site']         as String? ?? j['city'] as String? ?? '',
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
    source:       j['source']       as String? ?? 'WRD_BIHAR_BACKEND',
    fetchedAt:    DateTime.tryParse(j['fetchedAt'] as String? ?? '') ?? DateTime.now(),
  );

  @override
  String toString() =>
      'WrdStation($river @ $site | cur=$displayLevel | '
      'DL=$displayDanger | fc24=$displayForecast24h | '
      'risk=$riskLabel | live=$hasLiveData)';
}

// ── WrdBiharService ───────────────────────────────────────────────────────────
class WrdBiharService {
  WrdBiharService._();
  static final WrdBiharService instance = WrdBiharService._();

  static const _cacheTtl   = Duration(minutes: 15);
  static const _persistKey = 'wrd_bihar_stations_v7';

  List<WrdStation>?        _cache;
  DateTime?                _cacheTime;
  Map<String, WrdStation>? _stationByKey; // lowercase site/city → station

  List<WrdStation>? get cachedStations => _cache;

  // ── Public API ────────────────────────────────────────────────────────────

  Future<List<WrdStation>> fetch({bool forceRefresh = false}) async {
    // In-memory cache hit
    if (!forceRefresh &&
        _cache != null &&
        _cacheTime != null &&
        DateTime.now().difference(_cacheTime!) < _cacheTtl) {
      _log('cache hit — ${_cache!.length} stations (in-memory)');
      return _cache!;
    }

    // Cold start: load from disk while we wait for network
    if (_cache == null) {
      final disk = await _loadFromDisk();
      if (disk.isNotEmpty) {
        _cache     = disk;
        _cacheTime = null;
        _buildIndex(disk);
        _log('cold-start: ${disk.length} stations from disk');
      }
    }

    // Fetch from backend
    try {
      final raw      = await BackendApiService.instance.fetchLiveLevels('Bihar');
      final stations = raw.map(WrdStation.fromJson).toList();
      _log('backend returned ${stations.length} stations');
      if (stations.isNotEmpty) {
        await _setCache(stations);
        return stations;
      }
    } catch (e) {
      _log('backend fetch error: $e — falling back to disk cache');
    }

    final offline = _cache ?? [];
    _log('offline mode — ${offline.length} stations');
    return offline;
  }

  Future<WrdStation?> fetchBestMatch(String city, {String? river}) async {
    await fetch();
    final lc    = city.toLowerCase().trim();
    WrdStation? hit = _stationByKey?[lc];
    if (hit != null) return hit;

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

  // ── Persistence ───────────────────────────────────────────────────────────

  Future<void> _saveToDisk(List<WrdStation> stations) async {
    try {
      final prefs   = await SharedPreferences.getInstance();
      final encoded = jsonEncode(stations.map((s) => s.toJson()).toList());
      await prefs.setString(_persistKey, encoded);
      await prefs.setString(
          '${_persistKey}_ts', DateTime.now().toIso8601String());
      _log('disk: saved ${stations.length} stations');
    } catch (e) {
      _log('disk save error: $e');
    }
  }

  Future<List<WrdStation>> _loadFromDisk() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw   = prefs.getString(_persistKey);
      if (raw == null || raw.isEmpty) return [];
      final tsRaw = prefs.getString('${_persistKey}_ts');
      final ts    = tsRaw != null ? DateTime.tryParse(tsRaw) : null;
      if (ts != null) {
        _log('disk: last saved ${DateTime.now().difference(ts).inMinutes} min ago');
      }
      return (jsonDecode(raw) as List)
          .whereType<Map<String, dynamic>>()
          .map(WrdStation.fromJson)
          .toList();
    } catch (e) {
      _log('disk load error: $e');
      return [];
    }
  }

  Future<void> _setCache(List<WrdStation> stations) async {
    _cache     = stations;
    _cacheTime = DateTime.now();
    _buildIndex(stations);
    await _saveToDisk(stations);
  }

  void _buildIndex(List<WrdStation> stations) {
    final map = <String, WrdStation>{};
    for (final s in stations) {
      map[s.site.toLowerCase().trim()]     = s;
      map[s.district.toLowerCase().trim()] = s;
      // Also index by city field if present (backend may use 'city' key)
      final cityKey = s.site.toLowerCase().trim();
      if (cityKey.isNotEmpty) map[cityKey] = s;
    }
    _stationByKey = map;
    _log('index built: ${map.length} keys for ${stations.length} stations');
  }

  void _log(String msg) {
    if (kDebugMode) debugPrint('[WrdBihar] $msg');
  }
}
