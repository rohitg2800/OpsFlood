// lib/services/cwc_direct_service.dart
//
// OpsFlood — CwcDirectService  (v2 — backend-proxied)
//
// ARCHITECTURE NOTE:
//   All data now flows through the OpsFlood FastAPI backend.
//   Direct scraping of WRD Bihar / CWC FFEM / BEAMS from Flutter is DISABLED
//   because those sites return HTML (not JSON) when called from a mobile
//   client, causing FormatException on jsonDecode.
//
//   The backend handles scraping server-side and exposes clean JSON via
//     GET /api/stations          — all stations
//     GET /api/stations/{id}     — single station
//
//   CwcDirectService now delegates every fetch to OpsClient (which calls
//   the backend), giving us:
//     • No CORS / HTML-response issues
//     • 10-min server-side cache so the backend isn't hammered
//     • Consistent data shapes across the whole app
//
// Usage (unchanged from callers' perspective):
//   final reading = await CwcDirectService.instance.fetch(city);
library;

import 'package:flutter/foundation.dart';

import '../data/india_cities.dart';
import 'ops_client.dart';

// ── Reading model (kept identical so callers compile unchanged) ────────────
class CwcReading {
  final double  level;
  final double  warning;
  final double  danger;
  final double? hfl;
  final String  source;
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

// ── Service ────────────────────────────────────────────────────────────────
class CwcDirectService {
  CwcDirectService._();
  static final CwcDirectService instance = CwcDirectService._();

  // Session cache — avoid re-fetching the same city within 10 min.
  final Map<String, _CacheEntry> _cache = {};
  static const _kCacheTTL = Duration(minutes: 10);

  /// Returns a [CwcReading] for [city] sourced from the OpsFlood backend,
  /// or null if the backend is unreachable or has no data for this city.
  Future<CwcReading?> fetch(IndiaCity city) async {
    final key = city.id;

    // Return cached result if still fresh.
    final cached = _cache[key];
    if (cached != null &&
        DateTime.now().difference(cached.fetchedAt) < _kCacheTTL) {
      return cached.reading;
    }

    try {
      // Ask the backend for this specific station.
      // The backend station IDs are city IDs upper-cased (e.g. "PATNA").
      final resp = await OpsClient.instance
          .get('/api/stations/${city.id.toUpperCase()}');

      if (resp['status'] == 'error') {
        // Try the list endpoint and fuzzy-match by name as fallback.
        return await _fetchFromList(city);
      }

      final data = resp['data'] as Map<String, dynamic>?;
      if (data == null) return await _fetchFromList(city);

      return _toReading(data, city);
    } catch (e) {
      debugPrint('[CwcDirect] fetch ${city.name}: $e');
      return null;
    }
  }

  /// Fetches the full station list and fuzzy-matches to [city].
  Future<CwcReading?> _fetchFromList(IndiaCity city) async {
    try {
      final resp = await OpsClient.instance.get('/api/stations');
      final list = (resp['data'] as List? ?? []).cast<Map<String, dynamic>>();

      final lc = city.name.toLowerCase();
      final lr = city.river.toLowerCase();

      Map<String, dynamic>? best;
      int bestScore = 0;

      for (final row in list) {
        final sn = (row['name']     ?? '').toString().toLowerCase();
        final rv = (row['river']    ?? '').toString().toLowerCase();
        final st = (row['state']    ?? '').toString().toLowerCase();
        int score = 0;
        if (sn == lc || sn.contains(lc) || lc.contains(sn)) score += 3;
        if (rv.contains(lr) || lr.contains(rv))              score += 2;
        if (st.contains(city.state.toLowerCase()))            score += 1;
        if (score > bestScore) { bestScore = score; best = row; }
      }

      if (best == null || bestScore < 2) return null;
      return _toReading(best, city);
    } catch (e) {
      debugPrint('[CwcDirect] fetchFromList ${city.name}: $e');
      return null;
    }
  }

  /// Converts a backend station map to a [CwcReading].
  CwcReading? _toReading(Map<String, dynamic> data, IndiaCity city) {
    final cl = _parseLevel(data['current_level'] ?? data['level']);
    if (cl == null || cl <= 0) return null;

    final dl = _parseLevel(data['danger_level']  ?? data['danger'])  ?? city.dangerLevel;
    final wl = _parseLevel(data['warning_level'] ?? data['warning']) ?? city.warningLevel;

    final reading = CwcReading(
      level:       cl,
      warning:     wl,
      danger:      dl,
      source:      (data['data_source'] ?? 'BACKEND').toString(),
      stationName: data['name']?.toString(),
      fetchedAt:   DateTime.now(),
    );

    _cache[city.id] = _CacheEntry(reading: reading, fetchedAt: DateTime.now());
    return reading;
  }

  double? _parseLevel(dynamic v) {
    if (v == null) return null;
    final d = double.tryParse(v.toString().trim());
    if (d == null || d < 0.5 || d > 250) return null;
    return d;
  }

  void clearCache() => _cache.clear();
}

class _CacheEntry {
  final CwcReading reading;
  final DateTime   fetchedAt;
  const _CacheEntry({required this.reading, required this.fetchedAt});
}
