// OpsFlood — IMD Integration Service
// ─────────────────────────────────────────────────────────────────────────────
// P2: Authoritative India Meteorological Department integration scaffold.
//
// PURPOSE
//   Provide official India-focused rainfall / weather alert ingestion that can
//   be fused with CWC river levels and local ML predictions.
//
// IMPORTANT
//   IMD has multiple public-facing products and some feeds may change format,
//   require portal access, or be delivered as raster / bulletin / text PDFs.
//   This service therefore uses a layered strategy:
//     1. Backend proxy endpoint on OpsFlood (preferred, stable contract)
//     2. Direct IMD advisory endpoint (when publicly available)
//     3. Graceful no-data fallback
//
// FUTURE BACKEND CONTRACTS
//   GET /api/imd/alerts?state=Maharashtra
//   GET /api/imd/rainfall?state=Maharashtra&days=3
//   GET /api/imd/nowcast?district=Pune
//
//   Response shape expected by app:
//   {
//     "status": "ok",
//     "data": [
//       {
//         "title": "Heavy rainfall warning",
//         "severity": "ORANGE",
//         "state": "Maharashtra",
//         "district": "Pune",
//         "start_time": "2026-05-22T12:00:00Z",
//         "end_time": "2026-05-23T12:00:00Z",
//         "rainfall_mm": 110,
//         "source": "IMD",
//         "message": "Heavy to very heavy rainfall likely at isolated places"
//       }
//     ]
//   }
// ─────────────────────────────────────────────────────────────────────────────
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/env.dart';

class ImdAlert {
  final String title;
  final String severity; // RED | ORANGE | YELLOW | GREEN
  final String state;
  final String district;
  final DateTime? startTime;
  final DateTime? endTime;
  final double rainfallMm;
  final String source;
  final String message;

  const ImdAlert({
    required this.title,
    required this.severity,
    required this.state,
    required this.district,
    required this.startTime,
    required this.endTime,
    required this.rainfallMm,
    required this.source,
    required this.message,
  });

  factory ImdAlert.fromJson(Map<String, dynamic> j) {
    double sf(dynamic v) =>
        v == null ? 0.0 : (double.tryParse(v.toString()) ?? 0.0);
    return ImdAlert(
      title:      (j['title'] ?? j['headline'] ?? 'IMD Alert').toString(),
      severity:   (j['severity'] ?? j['color'] ?? 'YELLOW').toString().toUpperCase(),
      state:      (j['state'] ?? '').toString(),
      district:   (j['district'] ?? '').toString(),
      startTime:  DateTime.tryParse((j['start_time'] ?? j['start'] ?? '').toString()),
      endTime:    DateTime.tryParse((j['end_time'] ?? j['end'] ?? '').toString()),
      rainfallMm: sf(j['rainfall_mm'] ?? j['rainfall'] ?? j['rain_mm']),
      source:     (j['source'] ?? 'IMD').toString(),
      message:    (j['message'] ?? j['description'] ?? '').toString(),
    );
  }

  bool get isSevere => severity == 'RED' || severity == 'ORANGE';
}

class ImdRainfallPoint {
  final String state;
  final String district;
  final DateTime time;
  final double rainfallMm;
  final String source;

  const ImdRainfallPoint({
    required this.state,
    required this.district,
    required this.time,
    required this.rainfallMm,
    required this.source,
  });

  factory ImdRainfallPoint.fromJson(Map<String, dynamic> j) {
    double sf(dynamic v) =>
        v == null ? 0.0 : (double.tryParse(v.toString()) ?? 0.0);
    return ImdRainfallPoint(
      state:      (j['state'] ?? '').toString(),
      district:   (j['district'] ?? '').toString(),
      time:       DateTime.tryParse((j['time'] ?? j['timestamp'] ?? '').toString()) ?? DateTime.now(),
      rainfallMm: sf(j['rainfall_mm'] ?? j['rain_mm'] ?? j['value']),
      source:     (j['source'] ?? 'IMD').toString(),
    );
  }
}

class ImdService {
  ImdService._();
  static final ImdService instance = ImdService._();

  final http.Client _client = http.Client();
  static const _timeout = Duration(seconds: 12);

  // ── Public: fetch state alerts ────────────────────────────────────────────
  Future<List<ImdAlert>> getAlerts({required String state}) async {
    // Preferred path: backend proxy. Stable contract, easier auth/header mgmt.
    final proxy = await _fetchAlertsFromProxy(state: state);
    if (proxy.isNotEmpty) return proxy;

    // Future direct endpoints can be attempted here if IMD publishes a stable
    // JSON feed. For now, fail safely with no data rather than fabricating.
    return const <ImdAlert>[];
  }

  // ── Public: rainfall forecast/observations ────────────────────────────────
  Future<List<ImdRainfallPoint>> getRainfall({
    required String state,
    int days = 3,
  }) async {
    return _fetchRainfallFromProxy(state: state, days: days);
  }

  // ── Proxy fetchers ────────────────────────────────────────────────────────
  Future<List<ImdAlert>> _fetchAlertsFromProxy({required String state}) async {
    try {
      final res = await _client
          .get(Uri.parse('${Env.baseUrl}/api/imd/alerts?state=${Uri.encodeComponent(state)}'))
          .timeout(_timeout);
      if (res.statusCode != 200) return const <ImdAlert>[];
      final payload = jsonDecode(res.body);
      final items = _extractList(payload);
      return items
          .whereType<Map<String, dynamic>>()
          .map(ImdAlert.fromJson)
          .toList(growable: false);
    } catch (e) {
      if (kDebugMode) debugPrint('[IMD] alerts error: $e');
      return const <ImdAlert>[];
    }
  }

  Future<List<ImdRainfallPoint>> _fetchRainfallFromProxy({
    required String state,
    required int days,
  }) async {
    try {
      final res = await _client
          .get(Uri.parse('${Env.baseUrl}/api/imd/rainfall?state=${Uri.encodeComponent(state)}&days=$days'))
          .timeout(_timeout);
      if (res.statusCode != 200) return const <ImdRainfallPoint>[];
      final payload = jsonDecode(res.body);
      final items = _extractList(payload);
      return items
          .whereType<Map<String, dynamic>>()
          .map(ImdRainfallPoint.fromJson)
          .toList(growable: false);
    } catch (e) {
      if (kDebugMode) debugPrint('[IMD] rainfall error: $e');
      return const <ImdRainfallPoint>[];
    }
  }

  List<dynamic> _extractList(dynamic payload, {int depth = 0}) {
    if (depth > 5) return const [];
    if (payload is List) return payload;
    if (payload is Map<String, dynamic>) {
      for (final k in const ['data', 'items', 'results', 'alerts', 'rainfall', 'records']) {
        final v = payload[k];
        if (v is List) return v;
        if (v is Map<String, dynamic>) {
          final inner = _extractList(v, depth: depth + 1);
          if (inner.isNotEmpty) return inner;
        }
      }
    }
    return const [];
  }
}
