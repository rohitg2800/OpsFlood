/// lib/services/predict.dart
/// Public API shim for predict_screen.dart.
///
/// Exposes:
///   FloodPredictionInput  — named-param constructor the screen builds
///   FloodPrediction       — result with all getters the screen reads
///   PredictionException   — typed error the screen catches
///   PredictionService     — const-constructible facade over the singleton
///
/// HYBRID MERGE STRATEGY (v2)
/// ─────────────────────────────────────────────────────────────────────
/// Online:  Backend ML (60%) + Local Rule-Engine (40%) → blended result
/// Offline: Local Rule-Engine (100%) with live CWC level if available
/// ─────────────────────────────────────────────────────────────────────
library;

import 'dart:math' as math;

import '../constants.dart';
import 'api_service.dart';
import 'prediction_service.dart';
export 'prediction_service.dart'
    show MonitoringProtocol, PredictionInput;

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
    peakFloodLevelM:    peakFloodLevelM,
    eventDurationDays:  eventDurationDays,
    timeToPeakDays:     timeToPeakDays,
    recessionTimeDays:  recessionTimeDays,
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
      severity == 'CRITICAL' || severity == 'SEVERE' ? '🚨' :
      severity == 'MODERATE' ? '⚠️' : '🟢';

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
        algorithm:          overrideAlgorithm   ?? core.algorithm,
        dataSource:         overrideDataSource  ?? core.dataSource,
        riskScore:          core.riskScore,
        dangerLevel:        core.dangerLevel,
        proximityToDangerM: core.proximityToDangerM,
        monitoring:         core.monitoring,
        ensembleDetails:    overrideEnsemble    ?? core.ensembleDetails,
        fromBackend:        core.fromBackend,
        timestamp:          core.timestamp,
        liveRiverLevelM:    liveRiverLevelM,
      );
}

// ─── Service facade ───────────────────────────────────────────────────────────

class PredictionService {
  const PredictionService();

  // ── Hybrid predict: backend ML (60%) + rule engine (40%) ─────────────────
  Future<FloodPrediction> predict(FloodPredictionInput input) async {
    final double? liveLevel = await _fetchLiveLevel(input.station, input.state);
    final core = input.toPredictionInput();

    // Always run local rule engine (instant, no network needed)
    final CoreFloodPrediction localResult =
        PredictionServiceImpl.instance.localRuleEnginePredict(core, liveLevel: liveLevel);

    CoreFloodPrediction? backendResult;
    try {
      backendResult = await PredictionServiceImpl.instance
          .backendPredict(core, liveLevel: liveLevel);
    } catch (_) {
      // Backend unreachable — pure offline mode
      backendResult = null;
    }

    if (backendResult == null) {
      // OFFLINE MODE: rule engine only
      return FloodPrediction.fromCore(
        localResult,
        liveRiverLevelM: liveLevel,
        overrideAlgorithm:  'Offline Rule-Engine',
        overrideDataSource: liveLevel != null
            ? 'CWC Live + Rule Engine (offline)'
            : 'Rule Engine (offline)',
      );
    }

    // HYBRID MODE: blend backend (60%) + rule engine (40%)
    return _mergeResults(
      backend: backendResult,
      local:   localResult,
      liveLevel: liveLevel,
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
      liveRiverLevelM: liveLevel,
      overrideAlgorithm:  'Offline Rule-Engine',
      overrideDataSource: 'Rule Engine (offline)',
    );
  }

  // ── Hybrid merge logic ────────────────────────────────────────────────────
  // Blends probabilities from backend ML + rule engine using configurable weights.
  // Final severity is taken from the highest blended probability.
  // Confidence = weighted average of both confidences.
  // Risk score  = weighted average of both risk scores.
  FloodPrediction _mergeResults({
    required CoreFloodPrediction backend,
    required CoreFloodPrediction local,
    required double backendWeight,
    required double localWeight,
    double? liveLevel,
  }) {
    const labels = ['LOW', 'MODERATE', 'SEVERE', 'CRITICAL'];

    // Normalise both probability maps to 0-1 scale
    Map<String, double> _norm(Map<String, double> p) {
      final sum = p.values.fold(0.0, (s, v) => s + v);
      if (sum <= 0) return {for (final l in labels) l: 0.25};
      // If already 0-1, keep; if 0-100, divide by 100
      final scale = sum > 2.0 ? 100.0 : 1.0;
      return {for (final l in labels) l: (p[l] ?? 0) / scale};
    }

    final bp = _norm(backend.probabilities);
    final lp = _norm(local.probabilities);

    // Weighted blend
    final blended = <String, double>{
      for (final l in labels)
        l: bp[l]! * backendWeight + lp[l]! * localWeight
    };

    // Re-normalise to sum = 1.0
    final total = blended.values.fold(0.0, (s, v) => s + v);
    final normed = total > 0
        ? blended.map((k, v) => MapEntry(k, v / total))
        : {for (final l in labels) l: 0.25};

    // Pick winner
    final severity = normed.entries
        .reduce((a, b) => a.value >= b.value ? a : b)
        .key;

    final confidence = (normed[severity]! * 100)
        .clamp(0.0, 100.0)
        .roundToDouble();

    final riskScore = (backend.riskScore * backendWeight +
            local.riskScore * localWeight)
        .round()
        .clamp(0, 100);

    // Elevation: if rule engine says CRITICAL but backend says SEVERE,
    // trust the higher severity to be safe (flood safety bias).
    final String finalSeverity = _saferSeverity(severity, local.severity);

    final ensemble = {
      'mode':           'hybrid_merge',
      'backend_weight': backendWeight,
      'local_weight':   localWeight,
      'backend_severity': backend.severity,
      'local_severity':   local.severity,
      'blended_probs':    normed,
      'backend_confidence': backend.confidencePercent,
      'local_confidence':   local.confidencePercent,
      'live_level_used':    liveLevel != null,
      ...backend.ensembleDetails,
    };

    // Build a synthetic CoreFloodPrediction to reuse fromCore factory
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

  /// Safety bias: always return the higher (more severe) of the two severities.
  String _saferSeverity(String a, String b) {
    const rank = {'LOW': 0, 'MODERATE': 1, 'SEVERE': 2, 'CRITICAL': 3};
    return (rank[a] ?? 0) >= (rank[b] ?? 0) ? a : b;
  }

  // ── CWC level via backend proxy ───────────────────────────────────────────
  Future<double?> _fetchLiveLevel(String? station, String state) async {
    if (station == null || station.isEmpty) return null;
    try {
      final response = await ApiService().getAllCwcStations();
      final raw = response['data'];
      final List<Map<String, dynamic>> items;
      if (raw is List) {
        items = raw.whereType<Map<String, dynamic>>().toList();
      } else {
        return null;
      }
      final lc = station.toLowerCase();
      for (final item in items) {
        final name = (item['station'] ?? item['stationName'] ?? item['city'] ?? '')
            .toString()
            .toLowerCase();
        if (name.contains(lc) || lc.contains(name)) {
          final wl  = _sf(item['warning_level'] ?? item['warningLevel']);
          final abw = _sf(item['river_level']   ?? item['riverLevel'] ?? item['current_level']);
          if (abw > 0) return abw;
          if (wl  > 0) return wl;
        }
      }
    } catch (_) {}
    return null;
  }

  double _sf(dynamic v) =>
      (v == null || v == '') ? 0.0 : (double.tryParse(v.toString()) ?? 0.0);
}
