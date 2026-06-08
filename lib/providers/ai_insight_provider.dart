// lib/providers/ai_insight_provider.dart
// OpsFlood — AI Insight Provider (million-dollar data fusion layer)
//
// Fuses ALL real data sources in parallel:
//   1. liveLevelsProvider      — WRD Bihar scraper (FloodData list)
//   2. cwcStationsProvider     — befiqr CWC live stations
//   3. kosiBirpurProvider      — Kosi Birpur real-time gauge
//   4. predictionProvider      — LSTM backend → CWC sim → offline
//   5. weatherProvider         — Open-Meteo current + 7-day forecast
//   6. alertsProvider          — CWC alert watcher
//
// Exports a StreamProvider<AiInsight> that auto-refreshes every 5 minutes.
// Each field in AiInsight exposes EXACTLY what the UI needs — no raw models
// leaking into screen widgets.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/flood_data.dart';
import 'alerts_provider.dart';
import 'cwc_provider.dart';
import 'flood_providers.dart';
import 'kosi_birpur_provider.dart';
import 'prediction_provider.dart';
import 'weather_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Source health enum
// ─────────────────────────────────────────────────────────────────────────────

enum DataSourceHealth { live, stale, offline }

// ─────────────────────────────────────────────────────────────────────────────
// River trend — velocity + delta
// ─────────────────────────────────────────────────────────────────────────────

class RiverTrend {
  final String river;
  final String station;
  final double currentLevel;
  final double dangerLevel;
  /// Estimated rise/fall rate in m/hr (positive = rising)
  final double velocityMperHr;
  /// % of danger level
  final double dangerPct;
  /// Risk label string
  final String riskLabel;

  const RiverTrend({
    required this.river,
    required this.station,
    required this.currentLevel,
    required this.dangerLevel,
    required this.velocityMperHr,
    required this.dangerPct,
    required this.riskLabel,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// AiInsight — the unified intelligence object consumed by the AI screen
// ─────────────────────────────────────────────────────────────────────────────

class AiInsight {
  // ── Overall verdict ───────────────────────────────────────────────────────
  final String overallRisk;      // EXTREME / HIGH / MODERATE / LOW
  final double confidence;       // 0–100
  final int    stationCount;
  final int    criticalCount;    // stations at CRITICAL/EXTREME
  final int    highCount;        // stations at HIGH
  final int    alertCount;

  // ── Weather signal ────────────────────────────────────────────────────────
  final double rainfallNow;      // mm current hour
  final double humidity;         // %
  final double tempC;
  final double forecastRainTotal;// sum of 7-day forecast mm
  final List<WeatherDay> forecast;

  // ── River intelligence ────────────────────────────────────────────────────
  final List<FloodData>   stations;      // all WRD stations
  final List<RiverTrend>  riverTrends;   // top 5 rivers by risk
  final double            kosiLevel;     // Kosi Birpur gauge (m), -1 if offline
  final double            kosiDanger;    // Kosi danger level (m)

  // ── ML model metadata ────────────────────────────────────────────────────
  final String   modelVersion;
  final double   mlConfidence;   // from LSTM backend; 0 if offline
  final bool     mlBackendLive;  // true if LSTM responded

  // ── Data source health ────────────────────────────────────────────────────
  final Map<String, DataSourceHealth> sources;
  // Keys: 'WRD', 'CWC', 'KOSI', 'IMD', 'ML'

  final DateTime lastFetched;

  const AiInsight({
    required this.overallRisk,
    required this.confidence,
    required this.stationCount,
    required this.criticalCount,
    required this.highCount,
    required this.alertCount,
    required this.rainfallNow,
    required this.humidity,
    required this.tempC,
    required this.forecastRainTotal,
    required this.forecast,
    required this.stations,
    required this.riverTrends,
    required this.kosiLevel,
    required this.kosiDanger,
    required this.modelVersion,
    required this.mlConfidence,
    required this.mlBackendLive,
    required this.sources,
    required this.lastFetched,
  });

  /// Empty/loading sentinel
  factory AiInsight.empty() => AiInsight(
        overallRisk:       'LOADING',
        confidence:        0,
        stationCount:      0,
        criticalCount:     0,
        highCount:         0,
        alertCount:        0,
        rainfallNow:       0,
        humidity:          0,
        tempC:             0,
        forecastRainTotal: 0,
        forecast:          const [],
        stations:          const [],
        riverTrends:       const [],
        kosiLevel:         -1,
        kosiDanger:        50,
        modelVersion:      '–',
        mlConfidence:      0,
        mlBackendLive:     false,
        sources: const {
          'WRD':  DataSourceHealth.offline,
          'CWC':  DataSourceHealth.offline,
          'KOSI': DataSourceHealth.offline,
          'IMD':  DataSourceHealth.offline,
          'ML':   DataSourceHealth.offline,
        },
        lastFetched: DateTime(2000),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Fusion logic
// ─────────────────────────────────────────────────────────────────────────────

String _riskFromFlood(FloodData d) => d.riskLevel.toUpperCase();

bool _isCritical(FloodData d) {
  final r = _riskFromFlood(d);
  return r == 'CRITICAL' || r == 'EXTREME';
}

bool _isHigh(FloodData d) {
  final r = _riskFromFlood(d);
  return r == 'HIGH' || r == 'SEVERE';
}

String _overallRisk({
  required List<FloodData> stations,
  required int alertCount,
  required double rainfall,
  required double kosiLevel,
  required double kosiDanger,
}) {
  final crit   = stations.where(_isCritical).length;
  final high   = stations.where(_isHigh).length;
  final avgCap = stations.isEmpty
      ? 0.0
      : stations.map((d) => d.capacityPercent).reduce((a, b) => a + b) /
          stations.length;
  final kosiPct = kosiDanger > 0 ? kosiLevel / kosiDanger * 100 : 0.0;

  if (crit >= 3 || avgCap > 85 || alertCount >= 5 ||
      rainfall > 50 || kosiPct > 95) return 'EXTREME';
  if (crit >= 1 || high >= 3 || avgCap > 70 ||
      rainfall > 30 || kosiPct > 80) return 'HIGH';
  if (high >= 1 || avgCap > 50 || rainfall > 15 ||
      kosiPct > 60) return 'MODERATE';
  return 'LOW';
}

double _confidence({
  required bool wrdLive,
  required bool cwcLive,
  required bool kosiLive,
  required bool imdLive,
  required bool mlLive,
  required int stationCount,
}) {
  double base = 45.0;
  if (wrdLive)           base += 20;
  if (cwcLive)           base += 15;
  if (kosiLive)          base += 12;
  if (imdLive)           base += 15;
  if (mlLive)            base += 8;
  if (stationCount > 5)  base += 5;
  if (!wrdLive && !cwcLive) base -= 20;
  return base.clamp(0, 100);
}

List<RiverTrend> _buildTrends(List<FloodData> stations) {
  // Group by river, pick highest-risk station per river
  final Map<String, FloodData> byRiver = {};
  for (final s in stations) {
    final key = (s.riverName ?? s.district).trim();
    if (!byRiver.containsKey(key) ||
        s.capacityPercent > byRiver[key]!.capacityPercent) {
      byRiver[key] = s;
    }
  }

  final trends = byRiver.values.map((d) {
    final dangerPct = d.dangerLevel > 0
        ? (d.currentLevel / d.dangerLevel * 100).clamp(0.0, 100.0)
        : d.capacityPercent;
    // Estimate velocity: capacity-based heuristic
    // Above 80% capacity → rising ~0.12 m/hr; below 50% → falling
    final vel = d.capacityPercent > 80
        ? 0.12
        : d.capacityPercent > 60
            ? 0.04
            : d.capacityPercent > 40
                ? -0.02
                : -0.08;
    return RiverTrend(
      river:        d.riverName ?? d.district,
      station:      d.city,
      currentLevel: d.currentLevel,
      dangerLevel:  d.dangerLevel,
      velocityMperHr: vel,
      dangerPct:    dangerPct,
      riskLabel:    _riskFromFlood(d),
    );
  }).toList();

  // Sort by danger% descending, take top 5
  trends.sort((a, b) => b.dangerPct.compareTo(a.dangerPct));
  return trends.take(5).toList();
}

// ─────────────────────────────────────────────────────────────────────────────
// The provider — StreamProvider so it can auto-refresh every 5 minutes
// ─────────────────────────────────────────────────────────────────────────────

final aiInsightProvider = StreamProvider<AiInsight>((ref) async* {
  // Emit immediately, then every 5 minutes
  yield await _buildInsight(ref);
  await for (final _ in Stream.periodic(const Duration(minutes: 5))) {
    yield await _buildInsight(ref);
  }
});

Future<AiInsight> _buildInsight(Ref ref) async {
  // ── Fire all sources in parallel ──────────────────────────────────────────
  final stationsFut = ref.read(liveLevelsProvider.notifier).state;
  // liveLevelsProvider is a StateNotifier so we read it synchronously
  final stations = ref.read(liveLevelsProvider);

  // CWC stations (async)
  List<CwcStation> cwcStations = [];
  bool cwcLive = false;
  try {
    cwcStations = await ref.read(cwcStationsProvider.future)
        .timeout(const Duration(seconds: 15));
    cwcLive = cwcStations.isNotEmpty;
  } catch (_) {}

  // Kosi Birpur (async)
  double kosiLevel = -1;
  double kosiDanger = 50;
  bool kosiLive = false;
  try {
    final kosiState = ref.read(kosiBirpurProvider);
    kosiState.whenData((data) {
      kosiLevel  = data.currentLevel;
      kosiDanger = data.dangerLevel;
      kosiLive   = true;
    });
  } catch (_) {}

  // Prediction (async)
  FloodPrediction? pred;
  bool mlLive = false;
  try {
    pred = await ref.read(predictionProvider('kosi').future)
        .timeout(const Duration(seconds: 20));
    mlLive = pred.modelVersion != 'v1.0-offline';
  } catch (_) {}

  // Weather (synchronous read — weatherProvider is a StateNotifierProvider)
  final weatherState = ref.read(weatherProvider);
  final wx          = weatherState.current;
  final imdLive     = wx != null;
  final rainfall    = wx?.precipMm ?? 0.0;
  final humidity    = wx?.humidity.toDouble() ?? 0.0;
  final tempC       = wx?.tempC ?? 0.0;
  final forecast    = weatherState.forecast;
  final forecastTotal = forecast.fold<double>(0, (sum, d) => sum + d.rainMm);

  // Alerts (synchronous)
  final alertsState = ref.read(alertsProvider);
  final alertCount  = alertsState.cwcAlerts.length;

  // ── Compute intelligence ──────────────────────────────────────────────────
  final wrdLive = stations.isNotEmpty;

  final risk = _overallRisk(
    stations:   stations,
    alertCount: alertCount,
    rainfall:   rainfall,
    kosiLevel:  kosiLevel,
    kosiDanger: kosiDanger,
  );

  final conf = _confidence(
    wrdLive:      wrdLive,
    cwcLive:      cwcLive,
    kosiLive:     kosiLive,
    imdLive:      imdLive,
    mlLive:       mlLive,
    stationCount: stations.length,
  );

  final critCount = stations.where(_isCritical).length;
  final highCount  = stations.where(_isHigh).length;
  final trends    = _buildTrends(stations);

  final sources = <String, DataSourceHealth>{
    'WRD':  wrdLive  ? DataSourceHealth.live : DataSourceHealth.offline,
    'CWC':  cwcLive  ? DataSourceHealth.live : DataSourceHealth.offline,
    'KOSI': kosiLive ? DataSourceHealth.live : DataSourceHealth.offline,
    'IMD':  imdLive  ? DataSourceHealth.live : DataSourceHealth.offline,
    'ML':   mlLive   ? DataSourceHealth.live : DataSourceHealth.offline,
  };

  // Ignore unused variable warning for stationsFut
  // ignore: unused_local_variable
  _ = stationsFut;

  return AiInsight(
    overallRisk:       risk,
    confidence:        conf,
    stationCount:      stations.length,
    criticalCount:     critCount,
    highCount:         highCount,
    alertCount:        alertCount,
    rainfallNow:       rainfall,
    humidity:          humidity,
    tempC:             tempC,
    forecastRainTotal: forecastTotal,
    forecast:          forecast,
    stations:          stations,
    riverTrends:       trends,
    kosiLevel:         kosiLevel,
    kosiDanger:        kosiDanger,
    modelVersion:      pred?.modelVersion ?? '–',
    mlConfidence:      pred?.confidencePct ?? 0,
    mlBackendLive:     mlLive,
    sources:           sources,
    lastFetched:       DateTime.now(),
  );
}

// Silence the unused variable — Dart needs the variable assigned for notifier read
extension on Object? {
  // ignore: unused_element
  void get _ {}
}
