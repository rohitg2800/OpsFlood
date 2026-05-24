// lib/services/ml_inference.dart
//
// OpsFlood — Real LiveSnapshot + MlInferenceService
//
// LiveSnapshot holds actual fetched data from all 5 sources.
// MlInferenceService calls /predict on the OpsFlood backend;
// falls back to a local rule-based ensemble if backend is cold.
library;

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../data/india_cities.dart';

// ── Data containers ──────────────────────────────────────────────────────────

class WeatherData {
  final double precipitationMm;   // total last 24 h (mm)
  final double temperatureC;
  final double relativeHumidity;
  final List<double> hourlyPrecip; // last 24 h, one value per hour

  const WeatherData({
    required this.precipitationMm,
    required this.temperatureC,
    required this.relativeHumidity,
    required this.hourlyPrecip,
  });

  static const WeatherData empty = WeatherData(
    precipitationMm: 0, temperatureC: 25,
    relativeHumidity: 60, hourlyPrecip: [],
  );
}

class RiverData {
  final double? dischargeM3s;   // GloFAS latest discharge
  final List<double> discharge7d; // last 7 daily values (oldest first)

  const RiverData({this.dischargeM3s, this.discharge7d = const []});

  static const RiverData empty = RiverData();
}

class CwcData {
  final double? currentLevel;  // metres above datum
  final double? dangerLevel;
  final double? warningLevel;
  final bool    ok;            // true = live CWC data received

  const CwcData({this.currentLevel, this.dangerLevel, this.warningLevel, this.ok = false});

  static const CwcData empty = CwcData();
}

class LiveSnapshot {
  final IndiaCity city;
  final WeatherData weather;
  final RiverData   river;
  final CwcData     cwc;
  final int         healthySourceCount; // 0-5
  final DateTime    fetchedAt;

  const LiveSnapshot({
    required this.city,
    required this.weather,
    required this.river,
    required this.cwc,
    required this.healthySourceCount,
    required this.fetchedAt,
  });
}

// ── Risk enum ─────────────────────────────────────────────────────────────────

enum FloodRisk { low, medium, high, extreme }

// ── Inference result ──────────────────────────────────────────────────────────

class InferenceResult {
  final FloodRisk risk;
  final double    probability;  // 0.0 – 1.0
  final String    label;        // 'LOW' | 'MEDIUM' | 'HIGH' | 'EXTREME'
  final String    source;       // 'backend' | 'local'

  const InferenceResult({
    required this.risk,
    required this.probability,
    required this.label,
    required this.source,
  });
}

// ── MlInferenceService ────────────────────────────────────────────────────────

class MlInferenceService {
  MlInferenceService._();
  static final MlInferenceService instance = MlInferenceService._();

  static const _timeout = Duration(seconds: 8);

  Future<InferenceResult> infer(LiveSnapshot snap) async {
    // Try OpsFlood /predict endpoint first
    try {
      final body = jsonEncode({
        'city':            snap.city.name,
        'state':           snap.city.state,
        'lat':             snap.city.lat,
        'lon':             snap.city.lon,
        'discharge_m3s':   snap.river.dischargeM3s ?? 0,
        'precipitation_mm': snap.weather.precipitationMm,
        'temperature_c':   snap.weather.temperatureC,
        'humidity':        snap.weather.relativeHumidity,
        'current_level':   snap.cwc.currentLevel ?? 0,
        'danger_level':    snap.cwc.dangerLevel ?? 10,
        'warning_level':   snap.cwc.warningLevel ?? 8,
      });

      final res = await http
          .post(
            Uri.parse('${AppConfig.baseUrl}${AppConfig.epPredict}'),
            headers: {'Content-Type': 'application/json'},
            body: body,
          )
          .timeout(_timeout);

      if (res.statusCode == 200) {
        final j = jsonDecode(res.body) as Map<String, dynamic>;
        final prob  = (j['probability'] as num?)?.toDouble() ?? 0.0;
        final label = (j['risk_level'] ?? j['label'] ?? 'LOW').toString().toUpperCase();
        return InferenceResult(
          risk:        _labelToRisk(label),
          probability: prob.clamp(0.0, 1.0),
          label:       label,
          source:      'backend',
        );
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[ML] backend unavailable, using local ensemble: $e');
    }

    // Local rule-based fallback
    return _localEnsemble(snap);
  }

  // Rule-based ensemble: discharge + rainfall + level vs danger level
  InferenceResult _localEnsemble(LiveSnapshot snap) {
    double score = 0.0;

    // 1. Rainfall contribution (0–0.35)
    final rain = snap.weather.precipitationMm;
    if (rain > 150) score += 0.35;
    else if (rain > 80)  score += 0.25;
    else if (rain > 40)  score += 0.15;
    else if (rain > 15)  score += 0.07;

    // 2. River discharge contribution (0–0.35)
    final q = snap.river.dischargeM3s ?? 0;
    if (q > 8000) score += 0.35;
    else if (q > 4000) score += 0.25;
    else if (q > 1500) score += 0.15;
    else if (q > 500)  score += 0.07;

    // 3. Level vs danger level (0–0.30)
    final level  = snap.cwc.currentLevel;
    final danger = snap.cwc.dangerLevel;
    if (level != null && danger != null && danger > 0) {
      final ratio = level / danger;
      if (ratio >= 1.0)       score += 0.30;
      else if (ratio >= 0.85) score += 0.20;
      else if (ratio >= 0.70) score += 0.10;
    }

    // 4. Trend bonus: rising 7-day discharge
    final d7 = snap.river.discharge7d;
    if (d7.length >= 2 && d7.last > d7.first * 1.3) score += 0.05;

    final prob = score.clamp(0.0, 1.0);
    String label;
    FloodRisk risk;
    if (prob >= 0.75)      { label = 'EXTREME'; risk = FloodRisk.extreme; }
    else if (prob >= 0.50) { label = 'HIGH';    risk = FloodRisk.high;    }
    else if (prob >= 0.30) { label = 'MEDIUM';  risk = FloodRisk.medium;  }
    else                   { label = 'LOW';     risk = FloodRisk.low;     }

    return InferenceResult(risk: risk, probability: prob, label: label, source: 'local');
  }

  static FloodRisk _labelToRisk(String label) {
    switch (label) {
      case 'EXTREME':  return FloodRisk.extreme;
      case 'HIGH':     return FloodRisk.high;
      case 'MEDIUM':   return FloodRisk.medium;
      default:         return FloodRisk.low;
    }
  }
}
