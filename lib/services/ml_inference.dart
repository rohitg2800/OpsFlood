// lib/services/ml_inference.dart
//
// ╔══════════════════════════════════════════════════════════════════════════╗
// ║  OpsFlood — LAYER 5: ML Inference via OpsFlood /predict               ║
// ║                                                                          ║
// ║  Takes a LiveSnapshot, extracts the ~15 features the OpsFlood          ║
// ║  ensemble (RandomForest + XGBoost) expects, and POSTs to /predict.     ║
// ║                                                                          ║
// ║  Feature mapping is derived from the OpsFlood pipeline manifest.       ║
// ║  Fallback values are used when a source is unavailable.                ║
// ╚══════════════════════════════════════════════════════════════════════════╝
library;

import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../data/direct_sources.dart';
import 'live_fetch_engine.dart';

// ─── Inference result ─────────────────────────────────────────────────────────

enum FloodRisk { low, medium, high, extreme }

class InferenceResult {
  final FloodRisk risk;
  final double probability;    // 0.0–1.0
  final String label;          // e.g. 'HIGH'
  final Map<String, double> featureVector; // what was sent
  final Map<String, dynamic> rawResponse;  // full /predict JSON
  final DateTime inferredAt;
  final bool ok;
  final String? error;

  const InferenceResult({
    required this.risk,
    required this.probability,
    required this.label,
    required this.featureVector,
    required this.rawResponse,
    required this.inferredAt,
    this.ok = true,
    this.error,
  });

  factory InferenceResult.failed(String err) => InferenceResult(
    risk: FloodRisk.low,
    probability: 0.0,
    label: 'UNKNOWN',
    featureVector: {},
    rawResponse: {},
    inferredAt: DateTime.now(),
    ok: false,
    error: err,
  );

  factory InferenceResult.fromJson(
    Map<String, dynamic> j,
    Map<String, double> sent,
  ) {
    final prob = (j['flood_probability'] as num?)?.toDouble() ??
                 (j['probability'] as num?)?.toDouble() ?? 0.0;
    final labelRaw = (j['flood_risk'] ?? j['risk_label'] ?? 'LOW').toString().toUpperCase();
    final risk = _riskFromLabel(labelRaw);
    return InferenceResult(
      risk: risk,
      probability: prob,
      label: labelRaw,
      featureVector: sent,
      rawResponse: j,
      inferredAt: DateTime.now(),
    );
  }

  static FloodRisk _riskFromLabel(String l) {
    if (l.contains('EXTREME')) return FloodRisk.extreme;
    if (l.contains('HIGH'))    return FloodRisk.high;
    if (l.contains('MED'))     return FloodRisk.medium;
    return FloodRisk.low;
  }
}

// ─── Feature extractor ────────────────────────────────────────────────────────

/// Converts a LiveSnapshot into the flat feature map that /predict expects.
Map<String, double> extractFeatures(LiveSnapshot snap) {
  final w = snap.weather;
  final r = snap.river;
  final cwc = snap.cwc;

  // 24h total precipitation from hourly forecast
  final precip24h = w.hourlyPrecip.take(24).fold(0.0, (a, b) => a + b);
  // Max hourly precipitation in next 6 hours
  final precipMax6h = w.hourlyPrecip.take(6).fold(0.0, (a, b) => a > b ? a : b);
  // Mean precipitation probability next 12 hours
  final precip12hProb = w.hourlyPrecipProb.take(12).isEmpty
      ? 0.0
      : w.hourlyPrecipProb.take(12).reduce((a, b) => a + b) / 12;

  // River trend: (last value - 7-day mean) / 7-day mean
  double riverTrend = 0.0;
  if (r.discharge7d.length >= 2) {
    final mean = r.discharge7d.reduce((a, b) => a + b) / r.discharge7d.length;
    if (mean > 0) riverTrend = ((r.discharge7d.last - mean) / mean);
  }

  // CWC level ratio: current / danger (0 when unavailable)
  final cwcRatio = (cwc.ok && cwc.currentLevel != null && cwc.dangerLevel != null && cwc.dangerLevel! > 0)
      ? cwc.currentLevel! / cwc.dangerLevel!
      : 0.0;

  return {
    // Weather features
    'precipitation_mm':       w.precipitationMm     ?? 0.0,
    'temperature_c':          w.temperatureC         ?? 28.0,
    'humidity_pct':           w.humidity             ?? 70.0,
    'windspeed_kmh':          w.windspeedKmh         ?? 10.0,
    'weather_code':           (w.weatherCode ?? 0).toDouble(),

    // Derived precipitation
    'precip_24h_total_mm':    precip24h,
    'precip_max_6h_mm':       precipMax6h,
    'precip_prob_12h_mean':   precip12hProb,

    // River features
    'river_discharge_m3s':    r.dischargeM3s         ?? 0.0,
    'river_discharge_7d_max': r.discharge7d.isEmpty ? 0.0
        : r.discharge7d.reduce((a, b) => a > b ? a : b),
    'river_trend_pct':        riverTrend,

    // CWC gauge features
    'cwc_level_m':            cwc.currentLevel       ?? 0.0,
    'cwc_danger_ratio':       cwcRatio,

    // Location features
    'latitude':               snap.city.lat,
    'longitude':              snap.city.lon,
  };
}

// ─── Service ──────────────────────────────────────────────────────────────────

class MlInferenceService {
  MlInferenceService._();
  static final MlInferenceService instance = MlInferenceService._();

  final _client = http.Client();
  static const _timeout = Duration(seconds: 30); // /predict may cold-start

  /// Given a [LiveSnapshot], build features and call OpsFlood /predict.
  Future<InferenceResult> infer(LiveSnapshot snap) async {
    final features = extractFeatures(snap);
    return _callPredict(features);
  }

  /// Direct call with a pre-built feature map (for testing / manual override).
  Future<InferenceResult> inferFromFeatures(Map<String, double> features) =>
      _callPredict(features);

  Future<InferenceResult> _callPredict(Map<String, double> features) async {
    try {
      final url = OpsFloodUrls.predict;
      final body = jsonEncode({'features': features});
      final resp = await _client
          .post(
            Uri.parse(url),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: body,
          )
          .timeout(_timeout);

      if (AppConfig.isDebugLogging) {
        // ignore: avoid_print
        print('[MlInference] POST $url → ${resp.statusCode}');
        // ignore: avoid_print
        print('[MlInference] body: ${resp.body.substring(0, resp.body.length.clamp(0, 500))}');
      }

      if (resp.statusCode == 200) {
        final j = jsonDecode(resp.body) as Map<String, dynamic>;
        return InferenceResult.fromJson(j, features);
      } else if (resp.statusCode == 422) {
        // Unprocessable entity — feature mismatch, return failed
        return InferenceResult.failed('feature_mismatch:${resp.body}');
      } else {
        return InferenceResult.failed('HTTP ${resp.statusCode}');
      }
    } on TimeoutException {
      return InferenceResult.failed('timeout');
    } catch (e) {
      return InferenceResult.failed(e.toString());
    }
  }
}
