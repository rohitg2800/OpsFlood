// lib/providers/prediction_provider.dart
// v3 — feature extraction from mergedStationsProvider
// (was using dummy FloodData values that were always 0)
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/river_station.dart';
import 'real_time_river_provider.dart';
import 'weather_provider.dart';

// ─── Prediction output model ──────────────────────────────────────────────────
class FloodPrediction {
  final String station;
  final String river;
  final double currentLevel;
  final double dangerLevel;
  final double progressPct;
  final double predicted24h;  // estimated level in 24 h
  final double predicted48h;
  final double predicted72h;
  final double riskScore;     // 0–100
  final String trend;         // 'rising' | 'falling' | 'stable'
  final String outlook;       // human-readable one-liner

  const FloodPrediction({
    required this.station,
    required this.river,
    required this.currentLevel,
    required this.dangerLevel,
    required this.progressPct,
    required this.predicted24h,
    required this.predicted48h,
    required this.predicted72h,
    required this.riskScore,
    required this.trend,
    required this.outlook,
  });
}

// ─── Simple linear extrapolation with weather modulation ─────────────────────
FloodPrediction _predict(RiverStation s, double rainfallModifier) {
  final cur   = s.current;
  final dng   = s.danger;
  final prog  = s.progressPct / 100;

  // Rainfall modifier: 0 = dry, 1 = heavy rain
  // Rising rate: proportional to (progress × rainfall factor)
  final riseRate = prog * rainfallModifier * 0.5; // m per 24 h

  final p24 = (cur + riseRate).clamp(0.0, dng * 1.5);
  final p48 = (cur + riseRate * 1.8).clamp(0.0, dng * 1.5);
  final p72 = (cur + riseRate * 2.4).clamp(0.0, dng * 1.5);

  final riskScore = ((p24 / (dng > 0 ? dng : 1)) * 100).clamp(0.0, 100.0);

  String trend;
  if (riseRate > 0.05)       trend = 'rising';
  else if (riseRate < -0.05) trend = 'falling';
  else                       trend = 'stable';

  String outlook;
  if (p24 >= dng)  outlook = 'Expected to reach or exceed danger level within 24 h';
  else if (p48 >= dng) outlook = 'May reach danger level within 48 h';
  else             outlook = 'Likely to remain below danger level for 72 h';

  return FloodPrediction(
    station:      s.station,
    river:        s.river,
    currentLevel: cur,
    dangerLevel:  dng,
    progressPct:  s.progressPct,
    predicted24h: p24,
    predicted48h: p48,
    predicted72h: p72,
    riskScore:    riskScore,
    trend:        trend,
    outlook:      outlook,
  );
}

// ─── Provider: predictions for all merged stations ───────────────────────────
final floodPredictionsProvider = Provider<List<FloodPrediction>>((ref) {
  final stations = ref.watch(mergedStationsProvider);
  final wxState  = ref.watch(weatherProvider);

  // Rainfall modifier from live weather (0–1)
  double rainfallMod = 0.3; // default moderate
  if (wxState.current != null) {
    final rain7d = wxState.rainfall7dMm;
    rainfallMod  = (rain7d / 200).clamp(0.0, 1.0);
  }

  return stations.map((s) => _predict(s, rainfallMod)).toList()
    ..sort((a, b) => b.riskScore.compareTo(a.riskScore));
});

/// Predictions for only above-normal or worse stations.
final activeFloodPredictionsProvider = Provider<List<FloodPrediction>>((ref) =>
    ref.watch(floodPredictionsProvider)
        .where((p) => p.progressPct >= 50)
        .toList());

/// Single prediction for the highest-risk station.
final worstPredictionProvider = Provider<FloodPrediction?>((ref) {
  final list = ref.watch(floodPredictionsProvider);
  return list.isNotEmpty ? list.first : null;
});
