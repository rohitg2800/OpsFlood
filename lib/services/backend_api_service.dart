// lib/services/backend_api_service.dart
//
// OpsFlood — Single backend HTTP client (v2.1)
//
// ALL external data (BeFIQR/WRD scraping, GloFAS river discharge,
// Open-Meteo rainfall, news feed) is fetched from our own backend server.
// The Flutter app NEVER calls BeFIQR, GloFAS, Open-Meteo, or news APIs directly.
//
// Backend base URL is set via the compile-time dart-define:
//   --dart-define=BACKEND_URL=https://your-backend.com
// Falls back to the constant below for local dev / production builds.

library;

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

// ── Backend URL ──────────────────────────────────────────────────────────────
const String _kBackendBase = String.fromEnvironment(
  'BACKEND_URL',
  defaultValue: 'https://android-flood-app-production.up.railway.app',
);

// ── Timeouts ─────────────────────────────────────────────────────────────────
const Duration _kConnectTimeout = Duration(seconds: 30);

// ── BackendApiService ────────────────────────────────────────────────────────
class BackendApiService {
  BackendApiService._();
  static final BackendApiService instance = BackendApiService._();

  String get baseUrl => _kBackendBase;

  // ── /api/live-levels?state=Bihar ─────────────────────────────────────────
  // Backend returns a wrapped envelope:
  // {
  //   "status": "success",
  //   "data": [ { "city": ..., "current_level": ..., ... }, ... ],
  //   "total": N,
  //   ...
  // }
  // Legacy shapes also accepted: bare List, or { "stations": [...] }.
  Future<List<Map<String, dynamic>>> fetchLiveLevels(String state) async {
    final uri = Uri.parse('$_kBackendBase/api/live-levels'
        '?state=${Uri.encodeComponent(state)}');
    _log('GET $uri');
    final res = await http.get(uri).timeout(_kConnectTimeout);
    _assertOk(res, 'live-levels');
    final body = jsonDecode(res.body);
    if (body is List) {
      return body.whereType<Map<String, dynamic>>().toList();
    }
    if (body is Map) {
      // Primary envelope used by /api/live-levels: { "data": [...] }
      if (body['data'] is List) {
        return (body['data'] as List)
            .whereType<Map<String, dynamic>>()
            .toList();
      }
      // Legacy envelope: { "stations": [...] }
      if (body['stations'] is List) {
        return (body['stations'] as List)
            .whereType<Map<String, dynamic>>()
            .toList();
      }
    }
    throw FormatException('live-levels: unexpected response shape');
  }

  // ── /api/glofas?lats=...&lons=... ────────────────────────────────────────
  // Returns a list (one entry per coordinate, same order as input):
  // [
  //   {
  //     "city": "gandhighat",
  //     "discharge": 1234.5,
  //     "discharge_mean": 950.0
  //   }, ...
  // ]
  Future<List<Map<String, dynamic>>> fetchGloFAS({
    required List<double> lats,
    required List<double> lons,
    required List<String> cityKeys,
  }) async {
    assert(lats.length == lons.length && lons.length == cityKeys.length);
    final uri = Uri.parse('$_kBackendBase/api/glofas'
        '?lats=${lats.join(',')}&lons=${lons.join(',')}&cities=${cityKeys.join(',').toLowerCase()}');
    _log('GET $uri');
    final res = await http.get(uri).timeout(_kConnectTimeout);
    _assertOk(res, 'glofas');
    final body = jsonDecode(res.body);
    if (body is List) {
      return body.whereType<Map<String, dynamic>>().toList();
    }
    throw FormatException('glofas: unexpected response shape');
  }

  // ── /api/rainfall?lats=...&lons=... ──────────────────────────────────────
  // Returns a list (one entry per coordinate, same order as input):
  // [
  //   { "city": "gandhighat", "rainfall24h": 12.4 }, ...
  // ]
  Future<List<Map<String, dynamic>>> fetchRainfall({
    required List<double> lats,
    required List<double> lons,
    required List<String> cityKeys,
  }) async {
    assert(lats.length == lons.length && lons.length == cityKeys.length);
    final uri = Uri.parse('$_kBackendBase/api/rainfall'
        '?lats=${lats.join(',')}&lons=${lons.join(',')}&cities=${cityKeys.join(',').toLowerCase()}');
    _log('GET $uri');
    final res = await http.get(uri).timeout(_kConnectTimeout);
    _assertOk(res, 'rainfall');
    final body = jsonDecode(res.body);
    if (body is List) {
      return body.whereType<Map<String, dynamic>>().toList();
    }
    throw FormatException('rainfall: unexpected response shape');
  }

  // ── /api/news?state=... ───────────────────────────────────────────────────
  // Returns a list of news/alert items:
  // [
  //   {
  //     "title": "...",
  //     "source": "IMD",
  //     "severity": "ORANGE",
  //     "url": "...",
  //     "published_at": "2026-06-09T...",
  //     "summary": "..."
  //   }, ...
  // ]
  Future<List<Map<String, dynamic>>> fetchNews({required String state}) async {
    final uri = Uri.parse('$_kBackendBase/api/news'
        '?state=${Uri.encodeComponent(state)}');
    _log('GET $uri');
    final res = await http.get(uri).timeout(_kConnectTimeout);
    _assertOk(res, 'news');
    final body = jsonDecode(res.body);
    if (body is List) {
      return body.whereType<Map<String, dynamic>>().toList();
    }
    if (body is Map && body['items'] is List) {
      return (body['items'] as List).whereType<Map<String, dynamic>>().toList();
    }
    throw FormatException('news: unexpected response shape');
  }

  // ── /api/cwc-stations?codes=... ──────────────────────────────────────────
  // Returns a list of CWC station readings keyed by station code:
  // [
  //   { "code": "KOSI-BIRPUR", "level": 74.82, "fetchedAt": "..." }, ...
  // ]
  Future<List<Map<String, dynamic>>> fetchCwcStations({
    required List<String> codes,
  }) async {
    if (codes.isEmpty) return [];
    final uri = Uri.parse('$_kBackendBase/api/cwc-stations'
        '?codes=${codes.join(',')}');
    _log('GET $uri');
    final res = await http.get(uri).timeout(_kConnectTimeout);
    _assertOk(res, 'cwc-stations');
    final body = jsonDecode(res.body);
    if (body is List) {
      return body.whereType<Map<String, dynamic>>().toList();
    }
    throw FormatException('cwc-stations: unexpected response shape');
  }

  // ── /health ───────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> checkHealth() async {
    final uri = Uri.parse('$_kBackendBase/health');
    final res  = await http.get(uri).timeout(_kConnectTimeout);
    _assertOk(res, 'health');
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  // ── helpers ───────────────────────────────────────────────────────────────
  void _assertOk(http.Response res, String tag) {
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('[$tag] HTTP ${res.statusCode}: ${res.body.substring(0, res.body.length.clamp(0, 200))}');
    }
  }

  void _log(String msg) {
    if (kDebugMode) debugPrint('[BackendApi] $msg');
  }
}
