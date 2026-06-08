// lib/providers/prediction_provider.dart
// v5 — fixes: RiverStation city+hfl fields; late match; ChangeNotifier removed
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/river_station.dart';
import '../data/bihar_rivers.dart';
import 'real_time_river_provider.dart';
import 'weather_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PredictionPoint — single hourly forecast step
// ─────────────────────────────────────────────────────────────────────────────

class PredictionPoint {
  final DateTime time;
  final double   level;    // metres
  final double?  precipMm; // hourly precipitation forecast (nullable)

  const PredictionPoint({
    required this.time,
    required this.level,
    this.precipMm,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// FloodPrediction — full result for one station
// ─────────────────────────────────────────────────────────────────────────────

class FloodPrediction {
  // Station metadata
  final String station;
  final String river;
  final double currentLevel;
  final double dangerLevel;
  final double warningLevel;
  final double progressPct;

  // Scalar forecasts (backwards compat)
  final double predicted24h;
  final double predicted48h;
  final double predicted72h;

  // Hourly forecast series
  final List<PredictionPoint> next24h;
  final List<PredictionPoint> next48h;
  final List<PredictionPoint> next72h;

  // Model metadata
  final double  riskScore;
  final double  confidencePct;
  final String  modelVersion;
  final double? cwcRiskScore;  // nullable — wired when CWC provides a %
  final String  trend;         // 'rising' | 'falling' | 'stable'
  final String  outlook;

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
// ─────────────────────────────────────────────────────────────────────────────

FloodPrediction _predict(
  RiverStation s,
  double rainfallModifier, {
  List<WeatherDay> forecast = const [],
}) {
  final cur  = s.current;
  final dng  = s.danger  > 0 ? s.danger  : cur * 1.5;
  final warn = s.warning > 0 ? s.warning : dng * 0.85;
  final prog = s.progressPct / 100;
  final now  = DateTime.now();

  // Hourly rise rate (m/h): proportional to progress × rainfall factor
  final risePerHour = prog * rainfallModifier * 0.021;

  List<PredictionPoint> buildSeries(int hours) {
    return List.generate(hours, (i) {
      final t     = now.add(Duration(hours: i + 1));
      final level = (cur + risePerHour * (i + 1)).clamp(0.0, dng * 1.5);
      double? precipMm;
      if (forecast.isNotEmpty) {
        final dayIdx = i ~/ 24;
        if (dayIdx < forecast.length) {
          precipMm = forecast[dayIdx].rainMm / 24;
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

  final riskScore  = ((p24 / dng) * 100).clamp(0.0, 100.0);
  final conf       = (55.0
      + (s.isLive ? 20.0 : 0.0)
      + (forecast.isNotEmpty ? 15.0 : 0.0)
      + (rainfallModifier > 0 ? 10.0 : 0.0)).clamp(0.0, 99.0);

  final String trend;
  if (risePerHour > 0.005)       trend = 'rising';
  else if (risePerHour < -0.005) trend = 'falling';
  else                           trend = 'stable';

  final String outlook;
  if (p24 >= dng)       outlook = 'Expected to reach or exceed danger level within 24 h';
  else if (p48 >= dng)  outlook = 'May reach danger level within 48 h';
  else if (p72 >= dng)  outlook = 'Risk of reaching danger level between 48–72 h';
  else                  outlook = 'Likely to remain below danger level for 72 h';

  return FloodPrediction(
    station:       s.station,
    river:         s.river,
    currentLevel:  cur,
    dangerLevel:   dng,
    warningLevel:  warn,
    progressPct:   s.progressPct,
    predicted24h:  p24,
    predicted48h:  p48,
    predicted72h:  p72,
    next24h:       pts24,
    next48h:       pts48,
    next72h:       pts72,
    riskScore:     riskScore,
    confidencePct: conf,
    modelVersion:  'v3.2',
    cwcRiskScore:  null,
    trend:         trend,
    outlook:       outlook,
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// predictionProvider(String stationKey) — FutureProvider.family
//
// Used by prediction_screen.dart and ai_prediction_panel.dart.
// Station matching: exact → partial → highest-risk → seed data fallback.
// ─────────────────────────────────────────────────────────────────────────────

final predictionProvider =
    FutureProvider.family<FloodPrediction, String>((ref, stationKey) async {
  final stations = ref.watch(mergedStationsProvider);
  final wxState  = ref.watch(weatherProvider);

  double rainfallMod = 0.3;
  if (wxState.current != null) {
    rainfallMod = (wxState.rainfall7dMm / 200).clamp(0.0, 1.0);
  }

  final keyLower = stationKey.toLowerCase();

  // ── Station resolution ──────────────────────────────────────────────────
  // Uses `late` so Dart knows `match` is definitely assigned before use.
  late RiverStation match;

  if (stations.isNotEmpty) {
    // 1. Exact name match
    final exact = stations.where(
        (s) => s.station.toLowerCase() == keyLower).toList();
    if (exact.isNotEmpty) {
      match = exact.first;
    } else {
      // 2. Partial match
      final partial = stations.where(
          (s) => s.station.toLowerCase().contains(keyLower) ||
                 keyLower.contains(s.station.toLowerCase())).toList();
      if (partial.isNotEmpty) {
        match = partial.first;
      } else {
        // 3. Highest-risk fallback
        match = stations.reduce(
            (a, b) => a.progressPct > b.progressPct ? a : b);
      }
    }
  } else {
    // 4. No live stations yet — build synthetic from kBiharGauges seed data
    final seed = kBiharGauges.firstWhere(
      (g) => g.station.toLowerCase() == keyLower,
      orElse: () => kBiharGauges.first,
    );
    // RiverStation requires city, state, river, station, current,
    // warning, danger, hfl  (hfl = highest flood level; estimate as
    // danger × 1.15 when the seed table doesn't carry a real HFL).
    match = RiverStation(
      city:    seed.station,       // city ≈ station name for seed data
      state:   seed.state,
      river:   seed.river,
      station: seed.station,
      current: seed.currentLevel,
      warning: seed.warningLevel,
      danger:  seed.dangerLevel,
      hfl:     seed.dangerLevel * 1.15,
      isLive:  false,
      dataSource: 'SEED',
    );
  }

  return _predict(match, rainfallMod, forecast: wxState.forecast);
});

// ─────────────────────────────────────────────────────────────────────────────
// Bulk providers — unchanged, kept for RiverMonitorScreen etc.
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
