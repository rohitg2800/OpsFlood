// OpsFlood — IMD Integration Service
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

  Future<List<ImdAlert>> getAlerts({required String state}) async {
    final proxy = await _fetchAlertsFromProxy(state: state);
    if (proxy.isNotEmpty) return proxy;
    return const <ImdAlert>[];
  }

  Future<List<ImdRainfallPoint>> getRainfall({
    required String state,
    int days = 3,
  }) async {
    return _fetchRainfallFromProxy(state: state, days: days);
  }

  Future<List<ImdAlert>> _fetchAlertsFromProxy({required String state}) async {
    try {
      final res = await _client
          .get(Uri.parse('${Env.baseUrl}/api/imd/alerts?state=${Uri.encodeComponent(state)}'))
          .timeout(_timeout);
      // Guard: backend not yet live → returns HTML 404 page, not JSON.
      if (res.statusCode != 200) return const <ImdAlert>[];
      final ct = res.headers['content-type'] ?? '';
      if (!ct.contains('application/json') && !ct.contains('text/json')) {
        if (kDebugMode) debugPrint('[IMD] alerts: non-JSON response ($ct) — endpoint not live yet');
        return const <ImdAlert>[];
      }
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
      final ct = res.headers['content-type'] ?? '';
      if (!ct.contains('application/json') && !ct.contains('text/json')) {
        return const <ImdRainfallPoint>[];
      }
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
