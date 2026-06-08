// lib/providers/prediction_provider.dart
// v4 — PredictionPoint + rich FloodPrediction + family predictionProvider
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/river_station.dart';
import '../data/bihar_rivers.dart';
import 'real_time_river_provider.dart';
import 'weather_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PredictionPoint — single hourly forecast step
// Used by _Sparkline, hourly table rows, ai_prediction_panel charts
// ─────────────────────────────────────────────────────────────────────────────

class PredictionPoint {
  final DateTime time;
  final double   level;    // metres (AMSL or local gauge, same datum as station)
  final double?  precipMm; // precipitation forecast for this hour (nullable)

  const PredictionPoint({
    required this.time,
    required this.level,
    this.precipMm,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// FloodPrediction — full prediction result for one station
// ─────────────────────────────────────────────────────────────────────────────

class FloodPrediction {
  // ── Station metadata ──────────────────────────────────────────────────
  final String station;
  final String river;
  final double currentLevel;
  final double dangerLevel;
  final double warningLevel;    // metres — used by chart threshold lines
  final double progressPct;

  // ── Scalar forecasts (backwards compat) ──────────────────────────────
  final double predicted24h;
  final double predicted48h;
  final double predicted72h;

  // ── Hourly forecast series ────────────────────────────────────────────
  final List<PredictionPoint> next24h; // 24 hourly points
  final List<PredictionPoint> next48h; // 48 hourly points
  final List<PredictionPoint> next72h; // 72 hourly points

  // ── Model metadata ──────────────────────────────────────────────────
  final double  riskScore;      // 0–100 (based on predicted24h / danger)
  final double  confidencePct;  // 0–100 heuristic confidence
  final String  modelVersion;   // e.g. 'v3.2'
  final double? cwcRiskScore;   // optional CWC-sourced risk %, null if unavailable
  final String  trend;          // 'rising' | 'falling' | 'stable'
  final String  outlook;        // human-readable one-liner

  const FloodPrediction({
    required this.station,
    required this.river,
    required this.currentLevel,
    required this.dangerLevel,
    required this.warningLevel,
    required this.progressPct,
    required this.predicted24h,
    required this.predicted48h,
    required this.predicted72h,
    required this.next24h,
    required this.next48h,
    required this.next72h,
    required this.riskScore,
    required this.confidencePct,
    required this.modelVersion,
    this.cwcRiskScore,
    required this.trend,
    required this.outlook,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Core prediction engine
// Linear extrapolation modulated by live weather + CWC risk score
// ─────────────────────────────────────────────────────────────────────────────

FloodPrediction _predict(
  RiverStation s,
  double rainfallModifier, {
  List<WeatherDay> forecast = const [],
}) {
  final cur    = s.current;
  final dng    = s.danger > 0 ? s.danger : cur * 1.5;
  final warn   = s.warning > 0 ? s.warning : dng * 0.85;
  final prog   = s.progressPct / 100;
  final now    = DateTime.now();

  // Hourly rise rate (m/h): proportional to progress × rainfall factor.
  // At prog=1.0 (at danger level) + heavy rain → ~0.021 m/h (= 0.5 m/24 h)
  final risePerHour = prog * rainfallModifier * 0.021;

  // Build hourly PredictionPoint series for 72 hours.
  // Rainfall per hour is interpolated from the daily forecast.
  List<PredictionPoint> buildSeries(int hours) {
    return List.generate(hours, (i) {
      final t          = now.add(Duration(hours: i + 1));
      final level      = (cur + risePerHour * (i + 1)).clamp(0.0, dng * 1.5);
      // Find the matching forecast day (if any)
      double? precipMm;
      if (forecast.isNotEmpty) {
        final dayIdx = i ~/ 24;
        if (dayIdx < forecast.length) {
          precipMm = forecast[dayIdx].rainMm / 24; // daily → hourly
        }
      }
      return PredictionPoint(time: t, level: level, precipMm: precipMm);
    });
  }

  final pts72 = buildSeries(72);
  final pts48 = pts72.sublist(0, 48);
  final pts24 = pts72.sublist(0, 24);

  final p24 = pts24.last.level;
  final p48 = pts48.last.level;
  final p72 = pts72.last.level;

  final riskScore = ((p24 / dng) * 100).clamp(0.0, 100.0);

  // Confidence: higher when we have live data and weather data
  final conf = (55.0 + (s.isLive ? 20.0 : 0.0) +
      (forecast.isNotEmpty ? 15.0 : 0.0) +
      (rainfallModifier > 0 ? 10.0 : 0.0)).clamp(0.0, 99.0);

  final String trend;
  if (risePerHour > 0.005)        trend = 'rising';
  else if (risePerHour < -0.005)  trend = 'falling';
  else                            trend = 'stable';

  final String outlook;
  if (p24 >= dng)      outlook = 'Expected to reach or exceed danger level within 24 h';
  else if (p48 >= dng) outlook = 'May reach danger level within 48 h';
  else if (p72 >= dng) outlook = 'Risk of reaching danger level between 48–72 h';
  else                 outlook = 'Likely to remain below danger level for 72 h';

  return FloodPrediction(
    station:      s.station,
    river:        s.river,
    currentLevel: cur,
    dangerLevel:  dng,
    warningLevel: warn,
    progressPct:  s.progressPct,
    predicted24h: p24,
    predicted48h: p48,
    predicted72h: p72,
    next24h:      pts24,
    next48h:      pts48,
    next72h:      pts72,
    riskScore:    riskScore,
    confidencePct: conf,
    modelVersion: 'v3.2',
    cwcRiskScore: null, // wired when CWC backend provides a risk %
    trend:        trend,
    outlook:      outlook,
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// predictionProvider(String stationKey) — FutureProvider.family
//
// Used by:
//   prediction_screen.dart — ref.watch(predictionProvider(_selectedStation))
//   ai_prediction_panel.dart — ref.watch(predictionProvider(widget.stationKey))
//
// stationKey is matched case-insensitively against the merged station list;
// falls back to the highest-risk station if no exact match is found.
// ─────────────────────────────────────────────────────────────────────────────

final predictionProvider =
    FutureProvider.family<FloodPrediction, String>((ref, stationKey) async {
  final stations = ref.watch(mergedStationsProvider);
  final wxState  = ref.watch(weatherProvider);

  // Rainfall modifier 0–1
  double rainfallMod = 0.3;
  if (wxState.current != null) {
    rainfallMod = (wxState.rainfall7dMm / 200).clamp(0.0, 1.0);
  }

  final keyLower = stationKey.toLowerCase();

  // Try exact station name match first, then partial, then first in kBiharGauges
  RiverStation? match;
  if (stations.isNotEmpty) {
    match = stations.firstWhere(
      (s) => s.station.toLowerCase() == keyLower,
      orElse: () => stations.firstWhere(
        (s) => s.station.toLowerCase().contains(keyLower) ||
               keyLower.contains(s.station.toLowerCase()),
        orElse: () => stations.reduce(
            (a, b) => a.progressPct > b.progressPct ? a : b),
      ),
    );
  }

  // Fall back: build a synthetic station from kBiharGauges seed data
  if (match == null) {
    final seed = kBiharGauges.firstWhere(
      (g) => g.station.toLowerCase() == keyLower,
      orElse: () => kBiharGauges.first,
    );
    match = RiverStation(
      station:    seed.station,
      river:      seed.river,
      state:      seed.state,
      current:    seed.currentLevel,
      warning:    seed.warningLevel,
      danger:     seed.dangerLevel,
      isLive:     false,
      dataSource: 'SEED',
    );
  }

  return _predict(match, rainfallMod, forecast: wxState.forecast);
});

// ─────────────────────────────────────────────────────────────────────────────
// Existing bulk providers — kept unchanged for RiverMonitorScreen etc.
// ─────────────────────────────────────────────────────────────────────────────

final floodPredictionsProvider = Provider<List<FloodPrediction>>((ref) {
  final stations = ref.watch(mergedStationsProvider);
  final wxState  = ref.watch(weatherProvider);

  double rainfallMod = 0.3;
  if (wxState.current != null) {
    rainfallMod = (wxState.rainfall7dMm / 200).clamp(0.0, 1.0);
  }

  return stations
      .map((s) => _predict(s, rainfallMod, forecast: wxState.forecast))
      .toList()
    ..sort((a, b) => b.riskScore.compareTo(a.riskScore));
});

final activeFloodPredictionsProvider = Provider<List<FloodPrediction>>((ref) =>
    ref.watch(floodPredictionsProvider)
        .where((p) => p.progressPct >= 50)
        .toList());

final worstPredictionProvider = Provider<FloodPrediction?>((ref) {
  final list = ref.watch(floodPredictionsProvider);
  return list.isNotEmpty ? list.first : null;
});
