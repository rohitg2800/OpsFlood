// lib/services/backend_api_service.dart  v3.0
//
// OpsFlood — Single backend HTTP client
//
// v3.0 adds PUSH endpoints:
//   POST /api/gauge-telemetry   — full station snapshot from DataFetchEngine
//   POST /api/rtdas-thresholds  — scraped RTDAS thresholds from sync service
//   POST /api/flood-events      — critical / danger station events
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

// ── Backend URL ────────────────────────────────────────────────────────────────
const String _kBackendBase = String.fromEnvironment(
  'BACKEND_URL',
  defaultValue: 'https://android-flood-app-production.up.railway.app',
);

// ── Timeouts ──────────────────────────────────────────────────────────────────
const Duration _kConnectTimeout = Duration(seconds: 30);
const Duration _kPushTimeout    = Duration(seconds: 20); // push can be fire-and-forget

// ── BackendApiService ───────────────────────────────────────────────────────────
class BackendApiService {
  BackendApiService._();
  static final BackendApiService instance = BackendApiService._();

  String get baseUrl => _kBackendBase;

  // ─────────────────────────────────────────────────────────────────────────────
  // PULL endpoints (unchanged from v2.1)
  // ─────────────────────────────────────────────────────────────────────────────

  // GET /api/live-levels?state=Bihar
  Future<List<Map<String, dynamic>>> fetchLiveLevels(String state) async {
    final uri = Uri.parse('$_kBackendBase/api/live-levels'
        '?state=${Uri.encodeComponent(state)}');
    _log('GET $uri');
    final res = await http.get(uri).timeout(_kConnectTimeout);
    _assertOk(res, 'live-levels');
    final body = jsonDecode(res.body);
    if (body is List) return body.whereType<Map<String, dynamic>>().toList();
    if (body is Map) {
      if (body['data']     is List) return (body['data']     as List).whereType<Map<String,dynamic>>().toList();
      if (body['stations'] is List) return (body['stations'] as List).whereType<Map<String,dynamic>>().toList();
    }
    throw FormatException('live-levels: unexpected response shape');
  }

  // GET /api/glofas?lats=...&lons=...&cities=...
  Future<List<Map<String, dynamic>>> fetchGloFAS({
    required List<double> lats,
    required List<double> lons,
    required List<String> cityKeys,
  }) async {
    final uri = Uri.parse('$_kBackendBase/api/glofas'
        '?lats=${lats.join(',')}&lons=${lons.join(',')}&cities=${cityKeys.join(',').toLowerCase()}');
    _log('GET $uri');
    final res = await http.get(uri).timeout(_kConnectTimeout);
    _assertOk(res, 'glofas');
    final body = jsonDecode(res.body);
    if (body is List) return body.whereType<Map<String, dynamic>>().toList();
    throw FormatException('glofas: unexpected response shape');
  }

  // GET /api/rainfall?lats=...&lons=...&cities=...
  Future<List<Map<String, dynamic>>> fetchRainfall({
    required List<double> lats,
    required List<double> lons,
    required List<String> cityKeys,
  }) async {
    final uri = Uri.parse('$_kBackendBase/api/rainfall'
        '?lats=${lats.join(',')}&lons=${lons.join(',')}&cities=${cityKeys.join(',').toLowerCase()}');
    _log('GET $uri');
    final res = await http.get(uri).timeout(_kConnectTimeout);
    _assertOk(res, 'rainfall');
    final body = jsonDecode(res.body);
    if (body is List) return body.whereType<Map<String, dynamic>>().toList();
    throw FormatException('rainfall: unexpected response shape');
  }

  // GET /api/news?state=...
  Future<List<Map<String, dynamic>>> fetchNews({required String state}) async {
    final uri = Uri.parse('$_kBackendBase/api/news'
        '?state=${Uri.encodeComponent(state)}');
    _log('GET $uri');
    final res = await http.get(uri).timeout(_kConnectTimeout);
    _assertOk(res, 'news');
    final body = jsonDecode(res.body);
    if (body is List) return body.whereType<Map<String, dynamic>>().toList();
    if (body is Map && body['items'] is List) {
      return (body['items'] as List).whereType<Map<String, dynamic>>().toList();
    }
    throw FormatException('news: unexpected response shape');
  }

  // GET /api/cwc-stations?codes=...
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
    if (body is List) return body.whereType<Map<String, dynamic>>().toList();
    throw FormatException('cwc-stations: unexpected response shape');
  }

  // GET /health
  Future<Map<String, dynamic>> checkHealth() async {
    final uri = Uri.parse('$_kBackendBase/health');
    final res  = await http.get(uri).timeout(_kConnectTimeout);
    _assertOk(res, 'health');
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // PUSH endpoints (NEW v3.0)
  // ─────────────────────────────────────────────────────────────────────────────

  // POST /api/gauge-telemetry
  //
  // Payload shape:
  // {
  //   "ts":           1718000000000,          // epoch ms
  //   "source_counts": { "WRD_LIVE": 12, "CWC_FFS": 8, ... },
  //   "stations": [
  //     { "n":"Gandhighat", "r":"Ganga", ..., "cl":47.82, "dl":48.60, ... }
  //   ]
  // }
  //
  // Backend MUST implement: POST /api/gauge-telemetry
  // Expected response: { "ok": true, "accepted": N }
  Future<Map<String, dynamic>> postGaugeTelemetry(Map<String, dynamic> payload) async {
    return _post('gauge-telemetry', payload);
  }

  // POST /api/rtdas-thresholds
  //
  // Payload shape:
  // {
  //   "synced_at": 1718000000000,
  //   "thresholds": [
  //     {
  //       "station":    "Gandhighat",
  //       "wl":         47.50,
  //       "dl":         48.60,
  //       "hfl":        50.52,
  //       "source":     "RTDAS/WRD",
  //       "fetched_at": 1718000000000
  //     }, ...
  //   ]
  // }
  //
  // Backend MUST implement: POST /api/rtdas-thresholds
  // Expected response: { "ok": true, "upserted": N }
  Future<Map<String, dynamic>> postRtdasThresholds(Map<String, dynamic> payload) async {
    return _post('rtdas-thresholds', payload);
  }

  // POST /api/flood-events
  //
  // Payload shape:
  // {
  //   "ts": 1718000000000,
  //   "events": [
  //     {
  //       "station":     "Birpur (CWC)",
  //       "river":       "Kosi",
  //       "level":       74.95,
  //       "danger_level":74.70,
  //       "hfl":         76.02,
  //       "risk":        "CRITICAL",
  //       "source":      "CWC_FFS",
  //       "ts":          1718000000000
  //     }, ...
  //   ]
  // }
  //
  // Backend MUST implement: POST /api/flood-events
  // Expected response: { "ok": true, "recorded": N }
  Future<Map<String, dynamic>> postFloodEvents(Map<String, dynamic> payload) async {
    return _post('flood-events', payload);
  }

  // ── internal POST helper ───────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> _post(
      String path, Map<String, dynamic> payload) async {
    final uri = Uri.parse('$_kBackendBase/api/$path');
    _log('POST $uri (${jsonEncode(payload).length} bytes)');
    final res = await http
        .post(uri,
            headers: {
              'Content-Type': 'application/json; charset=utf-8',
              'X-App-Source': 'OpsFlood-Android/3',
            },
            body: jsonEncode(payload))
        .timeout(_kPushTimeout);
    if (res.statusCode >= 200 && res.statusCode < 300) {
      try {
        return jsonDecode(res.body) as Map<String, dynamic>;
      } catch (_) {
        return {'ok': true};
      }
    }
    _log('POST /$path → HTTP ${res.statusCode} (non-fatal)');
    return {'ok': false, 'status': res.statusCode};
  }

  // ── helpers ─────────────────────────────────────────────────────────────────────
  void _assertOk(http.Response res, String tag) {
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('[$tag] HTTP ${res.statusCode}: '
          '${res.body.substring(0, res.body.length.clamp(0, 200))}');
    }
  }

  void _log(String msg) {
    if (kDebugMode) debugPrint('[BackendApi] $msg');
  }
}
