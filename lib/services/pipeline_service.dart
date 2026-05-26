// lib/services/pipeline_service.dart
// ─────────────────────────────────────────────────────────────────────────────
// PipelineService — single source of truth bridge for the Flutter app.
//
// Replaces the hardcoded _stateMatrix in prediction_service.dart.
// Both the state severity matrix and pipeline features are fetched from
// the OpsFlood backend, keeping Flutter in sync with the Python truth.
//
// USAGE
//   await PipelineService.instance.init();          // call once at app start
//   final matrix = PipelineService.instance.matrix; // cached, never null
//   final features = await PipelineService.instance.fetchFeatures(
//     state: 'Maharashtra', station: 'Kolhapur');

library;

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
// FIX: was importing only app_config.dart which exports AppConfig.
// AppConfig.baseUrl is dotenv-aware (reads .env at runtime) whereas any
// direct reference to AppConstants.baseUrl is a compile-time const string
// that ignores .env.  Using the barrel import lets us keep AppConfig.baseUrl
// while also pulling in the rest of the constants if needed.
import '../constants/constants.dart';

// ── State severity entry (mirrors Python _StateEntry / STATE_SEVERITY_MATRIX) ─

class StateEntry {
  final double dangerLevelM;
  final double warningLevelM;
  final Map<String, double> peakLevelM;
  final Map<String, double> rainfall7dMm;

  const StateEntry({
    required this.dangerLevelM,
    required this.warningLevelM,
    required this.peakLevelM,
    required this.rainfall7dMm,
  });

  factory StateEntry.fromJson(Map<String, dynamic> j) {
    double d(dynamic v, double fallback) {
      try { return (v as num).toDouble(); } catch (_) { return fallback; }
    }
    Map<String, double> m(dynamic raw, Map<String, double> fallback) {
      if (raw is! Map) return fallback;
      return raw.map((k, v) => MapEntry(k.toString(), d(v, 0)));
    }
    return StateEntry(
      dangerLevelM:  d(j['danger_level_m'],  12.0),
      warningLevelM: d(j['warning_level_m'], 10.32),
      peakLevelM:    m(j['peak_level_m'],    {'moderate': 9.0, 'severe': 11.0, 'critical': 13.0}),
      rainfall7dMm:  m(j['rainfall_7d_mm'], {'moderate': 200,  'severe': 400,  'critical': 650}),
    );
  }

  // Built-in fallback so the app never crashes when the backend is cold.
  static const StateEntry fallback = StateEntry(
    dangerLevelM:  12.0,
    warningLevelM: 10.32,
    peakLevelM:    {'moderate': 9.0, 'severe': 11.0, 'critical': 13.0},
    rainfall7dMm:  {'moderate': 200,  'severe': 400,  'critical': 650},
  );
}

// ── Pipeline feature row (mirrors OperationalDataPipeline CSV columns) ────────

class PipelineFeatures {
  final String stateName;
  final String? stationName;
  final double? riverLevelM;
  final double? warningLevelM;
  final double? dangerLevelM;
  final double? rainfall1hMm;
  final double? rainfall3hMm;
  final double? rainfallLastHourMm;
  final double? humidityPct;
  final double? pressureHpa;
  final double? temperatureC;
  final double? warningHeadroomM;
  final double? dangerHeadroomM;
  final double? stressIndex;
  final String? featureReadyAt;

  const PipelineFeatures({
    required this.stateName,
    this.stationName,
    this.riverLevelM,
    this.warningLevelM,
    this.dangerLevelM,
    this.rainfall1hMm,
    this.rainfall3hMm,
    this.rainfallLastHourMm,
    this.humidityPct,
    this.pressureHpa,
    this.temperatureC,
    this.warningHeadroomM,
    this.dangerHeadroomM,
    this.stressIndex,
    this.featureReadyAt,
  });

  factory PipelineFeatures.fromJson(Map<String, dynamic> j) {
    double? d(dynamic v) {
      if (v == null) return null;
      try { return (v as num).toDouble(); } catch (_) { return null; }
    }
    return PipelineFeatures(
      stateName:             j['state_name']?.toString() ?? '',
      stationName:           j['requested_station_name']?.toString(),
      riverLevelM:           d(j['river_level_m']),
      warningLevelM:         d(j['warning_level_m']),
      dangerLevelM:          d(j['danger_level_m']),
      rainfall1hMm:          d(j['rainfall_1h_mm']),
      rainfall3hMm:          d(j['rainfall_3h_mm']),
      rainfallLastHourMm:    d(j['rainfall_last_hour_mm']),
      humidityPct:           d(j['humidity_pct']),
      pressureHpa:           d(j['pressure_hpa']),
      temperatureC:          d(j['temperature_c']),
      warningHeadroomM:      d(j['warning_headroom_m']),
      dangerHeadroomM:       d(j['danger_headroom_m']),
      stressIndex:           d(j['hydro_meteorological_stress_index']),
      featureReadyAt:        j['feature_ready_at']?.toString(),
    );
  }

  /// Best daily rainfall estimate from available pipeline fields (mm/day).
  double? get bestDailyRainfallMm {
    if (rainfall1hMm != null)       return rainfall1hMm! * 24;
    if (rainfallLastHourMm != null) return rainfallLastHourMm! * 24;
    return null;
  }
}

// ── Service singleton ─────────────────────────────────────────────────────────

class PipelineService {
  PipelineService._();
  static final PipelineService instance = PipelineService._();

  final http.Client _client = http.Client();
  static const Duration _timeout = Duration(seconds: 30);

  // ── State severity matrix (loaded once at startup, refreshed hourly) ───────
  Map<String, StateEntry> _matrix = {};
  DateTime? _matrixFetchedAt;
  static const Duration _matrixTtl = Duration(hours: 1);

  Map<String, StateEntry> get matrix => _matrix;

  bool get _matrixStale =>
      _matrixFetchedAt == null ||
      DateTime.now().difference(_matrixFetchedAt!) > _matrixTtl;

  /// Fetch and cache the state severity matrix from the backend.
  /// Call once in main() / app startup. Safe to call repeatedly.
  Future<void> init() async {
    if (!_matrixStale) return;
    try {
      await _refreshMatrix();
    } catch (e) {
      _debugLog('init: matrix fetch failed ($e) — using defaults');
    }
  }

  Future<void> _refreshMatrix() async {
    // FIX: use AppConfig.baseUrl (dotenv-aware) not a hardcoded string.
    final uri = Uri.parse('${AppConfig.baseUrl}/api/state-severity');
    final res = await _client.get(uri).timeout(_timeout);
    if (res.statusCode != 200) {
      throw Exception('state-severity HTTP ${res.statusCode}');
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final raw  = body['matrix'] as Map<String, dynamic>? ?? {};
    _matrix = raw.map(
        (k, v) => MapEntry(k, StateEntry.fromJson(v as Map<String, dynamic>)));
    _matrixFetchedAt = DateTime.now();
  }

  /// Return the severity entry for [state], falling back to a default entry.
  StateEntry entryForState(String state) =>
      _matrix[state] ?? StateEntry.fallback;

  // ── Pipeline features (per request, short TTL cache) ─────────────────────
  final Map<String, ({PipelineFeatures features, DateTime fetchedAt})>
      _featureCache = {};
  static const Duration _featureTtl = Duration(minutes: 10);

  /// Fetch latest pipeline features for [state] / [station].
  /// Returns null when the backend has no feature row yet (pipeline cold).
  Future<PipelineFeatures?> fetchFeatures({
    required String state,
    String? station,
  }) async {
    final cacheKey =
        '${state.toLowerCase()}|${(station ?? '').toLowerCase()}';
    final cached = _featureCache[cacheKey];
    if (cached != null &&
        DateTime.now().difference(cached.fetchedAt) < _featureTtl) {
      return cached.features;
    }

    try {
      final params = <String, String>{'state': state};
      if (station != null && station.isNotEmpty) params['station'] = station;
      // FIX: same dotenv-aware URL.
      final uri = Uri.parse('${AppConfig.baseUrl}/api/pipeline/features')
          .replace(queryParameters: params);

      final res = await _client.get(uri).timeout(_timeout);
      if (res.statusCode == 404) return null;
      if (res.statusCode != 200) {
        throw Exception('pipeline/features HTTP ${res.statusCode}');
      }

      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final data = body['data'] as Map<String, dynamic>?;
      if (data == null) return null;

      final features = PipelineFeatures.fromJson(data);
      _featureCache[cacheKey] =
          (features: features, fetchedAt: DateTime.now());
      return features;
    } catch (e) {
      _debugLog('fetchFeatures: $e');
      return null;
    }
  }

  /// Invalidate all caches (call after manual ingestion trigger).
  void invalidate() {
    _featureCache.clear();
    _matrixFetchedAt = null;
  }

  void _debugLog(String msg) {
    if (kDebugMode) debugPrint('[PipelineService] $msg');
  }
}
