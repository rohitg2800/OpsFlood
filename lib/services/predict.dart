/// lib/services/predict.dart
/// Public API shim for predict_screen.dart and any other screen.
///
/// ARCHITECTURE
/// ─────────────────────────────────────────────────────────────────────────
/// predict_screen.dart imports ONLY this file.
/// This file re-exports and wraps prediction_facade.dart so there is
/// exactly one class named PredictionService in the entire app.
///
/// HYBRID MERGE STRATEGY (v2 — unified pipeline)
/// ─────────────────────────────────────────────────────────────────────────
/// Online:  Pipeline pre-fill → Backend ML (60%) + Local Rule-Engine (40%)
/// Offline: Local Rule-Engine (100%) with live CWC level when available
/// ─────────────────────────────────────────────────────────────────────────
library;

import 'dart:math' as math;

import 'api_service.dart';
import 'pipeline_service.dart';
import 'prediction_service.dart';

export 'prediction_service.dart' show MonitoringProtocol, PredictionInput;
export 'pipeline_service.dart'   show PipelineFeatures;

// ─── Input ────────────────────────────────────────────────────────────────────

class FloodPredictionInput {
  final double peakFloodLevelM;
  final double eventDurationDays;
  final double timeToPeakDays;
  final double recessionTimeDays;
  final double t1d, t2d, t3d, t4d, t5d, t6d, t7d;
  final String state;
  final String? station;

  const FloodPredictionInput({
    required this.peakFloodLevelM,
    this.eventDurationDays = 1,
    this.timeToPeakDays    = 1,
    this.recessionTimeDays = 1,
    this.t1d = 10, this.t2d = 15, this.t3d = 20,
    this.t4d = 18, this.t5d = 12, this.t6d = 8, this.t7d = 7,
    required this.state,
    this.station,
  });

  double get rainfall7d => t1d + t2d + t3d + t4d + t5d + t6d + t7d;

  PredictionInput toPredictionInput() => PredictionInput(
    peakFloodLevelM:   peakFloodLevelM,
    eventDurationDays: eventDurationDays,
    timeToPeakDays:    timeToPeakDays,
    recessionTimeDays: recessionTimeDays,
    t1d: t1d, t2d: t2d, t3d: t3d,
    t4d: t4d, t5d: t5d, t6d: t6d, t7d: t7d,
    state:   state,
    station: station,
  );
}

// ─── Exception ────────────────────────────────────────────────────────────────

class PredictionException implements Exception {
  final String message;
  const PredictionException(this.message);
  @override
  String toString() => 'PredictionException: $message';
}

// ─── Result ───────────────────────────────────────────────────────────────────

class FloodPrediction {
  final String severity;
  final double confidencePercent;
  final Map<String, double> probabilities;
  final String algorithm;
  final String dataSource;
  final int riskScore;
  final double dangerLevel;
  final double proximityToDangerM;
  final MonitoringProtocol monitoring;
  final Map<String, dynamic> ensembleDetails;
  final bool fromBackend;
  final DateTime timestamp;
  final double? liveRiverLevelM;

  const FloodPrediction({
    required this.severity,
    required this.confidencePercent,
    required this.probabilities,
    required this.algorithm,
    required this.dataSource,
    required this.riskScore,
    required this.dangerLevel,
    required this.proximityToDangerM,
    required this.monitoring,
    required this.ensembleDetails,
    required this.fromBackend,
    required this.timestamp,
    this.liveRiverLevelM,
  });

  String get alert =>
      severity == 'CRITICAL' || severity == 'SEVERE' ? '\uD83D\uDEA8' :
      severity == 'MODERATE' ? '\u26A0\uFE0F' : '\uD83D\uDFE2';

  bool get isOfflineFallback => !fromBackend;
  String get monitoringLevel  => monitoring.level;
  String get monitoringAction => monitoring.action;

  factory FloodPrediction.fromCore(
    CoreFloodPrediction core, {
    double? liveRiverLevelM,
    String? overrideAlgorithm,
    String? overrideDataSource,
    Map<String, dynamic>? overrideEnsemble,
  }) =>
      FloodPrediction(
        severity:           core.severity,
        confidencePercent:  core.confidencePercent,
        probabilities:      core.probabilities,
        algorithm:          overrideAlgorithm  ?? core.algorithm,
        dataSource:         overrideDataSource ?? core.dataSource,
        riskScore:          core.riskScore,
        dangerLevel:        core.dangerLevel,
        proximityToDangerM: core.proximityToDangerM,
        monitoring:         core.monitoring,
        ensembleDetails:    overrideEnsemble   ?? core.ensembleDetails,
        fromBackend:        core.fromBackend,
        timestamp:          core.timestamp,
        liveRiverLevelM:    liveRiverLevelM,
      );
}

// ─── Service facade ───────────────────────────────────────────────────────────
//
// This is the SINGLE PredictionService class visible to the app.
// prediction_facade.dart's PredictionService is NOT imported here to avoid
// a duplicate-class conflict. All logic from that file is inlined below.

class PredictionService {
  const PredictionService();

  // ── Primary: pipeline pre-fill → backend (60%) + rule-engine (40%) ───────
  Future<FloodPrediction> predict(FloodPredictionInput input) async {
    // Step 1 — enrich from pipeline CSV (non-blocking; failures ignored)
    final enriched = await _enrichFromPipeline(input);
    final core     = enriched.toPredictionInput();

    // Step 2 — CWC live level via backend proxy
    final double? liveLevel = await _fetchLiveLevel(enriched.station, enriched.state);

    // Step 3 — always run local rule engine (instant, offline-safe)
    final CoreFloodPrediction localResult =
        PredictionServiceImpl.instance.localRuleEnginePredict(core, liveLevel: liveLevel);

    // Step 4 — try backend ML
    CoreFloodPrediction? backendResult;
    try {
      backendResult = await PredictionServiceImpl.instance
          .backendPredict(core, liveLevel: liveLevel);
    } catch (_) {
      backendResult = null;
    }

    if (backendResult == null) {
      return FloodPrediction.fromCore(
        localResult,
        liveRiverLevelM:    liveLevel,
        overrideAlgorithm:  'Offline Rule-Engine',
        overrideDataSource: liveLevel != null
            ? 'CWC Live + Rule Engine (offline)'
            : 'Rule Engine (offline)',
      );
    }

    // Step 5 — hybrid merge: backend 60% + local 40%
    return _mergeResults(
      backend:       backendResult,
      local:         localResult,
      liveLevel:     liveLevel,
      backendWeight: 0.60,
      localWeight:   0.40,
    );
  }

  // ── Offline-only prediction ───────────────────────────────────────────────
  FloodPrediction predictOffline(
    FloodPredictionInput input, {
    double? liveLevel,
  }) {
    final core = PredictionServiceImpl.instance
        .localRuleEnginePredict(input.toPredictionInput(), liveLevel: liveLevel);
    return FloodPrediction.fromCore(
      core,
      liveRiverLevelM:    liveLevel,
      overrideAlgorithm:  'Offline Rule-Engine',
      overrideDataSource: 'Rule Engine (offline)',
    );
  }

  // ── Pipeline pre-fill ─────────────────────────────────────────────────────
  Future<FloodPredictionInput> _enrichFromPipeline(
      FloodPredictionInput input) async {
    try {
      final features = await PipelineService.instance.fetchFeatures(
        state:   input.state,
        station: input.station,
      );
      if (features == null) return input;

      double peakLevel = input.peakFloodLevelM;
      double t1d       = input.t1d;

      // Replace sentinel defaults only; respect explicit UI values.
      if (peakLevel == 8.5 &&
          features.riverLevelM != null &&
          features.riverLevelM! > 0) {
        peakLevel = features.riverLevelM!;
      }
      final dailyRain = features.bestDailyRainfallMm;
      if (t1d == 10.0 && dailyRain != null && dailyRain > 0) {
        t1d = dailyRain;
      }

      if (peakLevel == input.peakFloodLevelM && t1d == input.t1d) {
        return input;
      }

      return FloodPredictionInput(
        peakFloodLevelM:   peakLevel,
        eventDurationDays: input.eventDurationDays,
        timeToPeakDays:    input.timeToPeakDays,
        recessionTimeDays: input.recessionTimeDays,
        t1d: t1d,
        t2d: input.t2d, t3d: input.t3d, t4d: input.t4d,
        t5d: input.t5d, t6d: input.t6d, t7d: input.t7d,
        state:   input.state,
        station: input.station,
      );
    } catch (_) {
      return input;
    }
  }

  // ── Hybrid merge ──────────────────────────────────────────────────────────
  FloodPrediction _mergeResults({
    required CoreFloodPrediction backend,
    required CoreFloodPrediction local,
    required double backendWeight,
    required double localWeight,
    double? liveLevel,
  }) {
    const labels = ['LOW', 'MODERATE', 'SEVERE', 'CRITICAL'];

    Map<String, double> norm(Map<String, double> p) {
      final sum   = p.values.fold(0.0, (s, v) => s + v);
      if (sum <= 0) return {for (final l in labels) l: 0.25};
      final scale = sum > 2.0 ? 100.0 : 1.0;
      return {for (final l in labels) l: (p[l] ?? 0) / scale};
    }

    final bp = norm(backend.probabilities);
    final lp = norm(local.probabilities);

    final blended = <String, double>{
      for (final l in labels)
        l: bp[l]! * backendWeight + lp[l]! * localWeight
    };

    final total  = blended.values.fold(0.0, (s, v) => s + v);
    final normed = total > 0
        ? blended.map((k, v) => MapEntry(k, v / total))
        : {for (final l in labels) l: 0.25};

    final severity   = normed.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
    final confidence = (normed[severity]! * 100).clamp(0.0, 100.0).roundToDouble();
    final riskScore  = (backend.riskScore * backendWeight +
            local.riskScore * localWeight)
        .round()
        .clamp(0, 100);

    final String finalSeverity = _saferSeverity(severity, local.severity);

    final ensemble = <String, dynamic>{
      'mode':               'hybrid_merge',
      'backend_weight':     backendWeight,
      'local_weight':       localWeight,
      'backend_severity':   backend.severity,
      'local_severity':     local.severity,
      'blended_probs':      normed,
      'backend_confidence': backend.confidencePercent,
      'local_confidence':   local.confidencePercent,
      'live_level_used':    liveLevel != null,
      ...backend.ensembleDetails,
    };

    final merged = CoreFloodPrediction(
      severity:           finalSeverity,
      confidencePercent:  confidence,
      probabilities:      normed.map((k, v) => MapEntry(k, v * 100)),
      algorithm:          'Hybrid (Backend ML 60% + Rule Engine 40%)',
      dataSource:         liveLevel != null
          ? 'CWC Live + OpsFlood API + Rule Engine'
          : 'OpsFlood API + Rule Engine',
      riskScore:          riskScore,
      dangerLevel:        backend.dangerLevel,
      proximityToDangerM: backend.proximityToDangerM,
      monitoring:         backend.monitoring,
      ensembleDetails:    ensemble,
      fromBackend:        true,
      timestamp:          DateTime.now(),
    );

    return FloodPrediction.fromCore(merged, liveRiverLevelM: liveLevel);
  }

  String _saferSeverity(String a, String b) {
    const rank = {'LOW': 0, 'MODERATE': 1, 'SEVERE': 2, 'CRITICAL': 3};
    return (rank[a] ?? 0) >= (rank[b] ?? 0) ? a : b;
  }

  // ── CWC live level via backend proxy ──────────────────────────────────────
  Future<double?> _fetchLiveLevel(String? station, String state) async {
    if (station == null || station.isEmpty) return null;
    try {
      final response = await ApiService().getAllCwcStations();
      final raw = response['data'];
      if (raw is! List) return null;
      final items = raw.whereType<Map<String, dynamic>>().toList();
      final lc = station.toLowerCase();
      for (final item in items) {
        final name = (item['station'] ?? item['stationName'] ?? item['city'] ?? '')
            .toString().toLowerCase();
        if (name.contains(lc) || lc.contains(name)) {
          final level = _sf(item['river_level'] ?? item['riverLevel'] ?? item['current_level']);
          final warn  = _sf(item['warning_level'] ?? item['warningLevel']);
          if (level > 0) return level;
          if (warn  > 0) return warn;
        }
      }
    } catch (_) {}
    return null;
  }

  double _sf(dynamic v) =>
      (v == null || v == '') ? 0.0 : (double.tryParse(v.toString()) ?? 0.0);
}
