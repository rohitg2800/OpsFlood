// lib/services/backend_api_service.dart
//
// OpsFlood — Single backend HTTP client (v1.0)
//
// ALL external data (BeFIQR/WRD scraping, GloFAS river discharge,
// Open-Meteo rainfall) is fetched from our own backend server.
// The Flutter app NEVER calls BeFIQR, GloFAS or Open-Meteo directly.
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
  // Returns a list of station objects:
  // [
  //   {
  //     "city": "Gandhighat",
  //     "river": "Ganga",
  //     "district": "Patna",
  //     "currentLevel": 45.23,
  //     "dangerLevel": 48.60,
  //     "warningLevel": 47.50,
  //     "prevLevel": 44.91,
  //     "diff24h": 0.32,
  //     "belowDanger": 3.37,
  //     "forecast24h": 46.10,
  //     "trend": "↑",
  //     "riskLabel": "MODERATE",
  //     "source": "WRD_BIHAR_LIVE",
  //     "fetchedAt": "2026-06-09T10:00:00Z"
  //   }, ...
  // ]
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
    // Backend may wrap in { "stations": [...] }
    if (body is Map && body['stations'] is List) {
      return (body['stations'] as List)
          .whereType<Map<String, dynamic>>()
          .toList();
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
