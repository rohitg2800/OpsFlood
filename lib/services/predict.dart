/// lib/services/predict.dart
/// Public API shim for predict_screen.dart.
///
/// Exposes:
///   FloodPredictionInput  — named-param constructor the screen builds
///   FloodPrediction       — result with all getters the screen reads
///   PredictionException   — typed error the screen catches
///   PredictionService     — const-constructible facade over the singleton
library;

import 'dart:math' as math;

import '../constants.dart';
import 'api_service.dart';
import 'prediction_service.dart';
export 'prediction_service.dart'
    show MonitoringProtocol, PredictionInput;

// ─── Input ────────────────────────────────────────────────────────────────────
// Matches exactly what _PredictScreenState._buildInput() constructs.

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

  /// Converts to the internal PredictionInput used by PredictionServiceImpl.
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
// Wraps the core FloodPrediction from prediction_service.dart and adds
// the extra getters that predict_screen.dart reads.

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
  final double? liveRiverLevelM; // null when no live CWC data was available

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

  // ── Convenience getters used by predict_screen.dart ──────────────────────

  /// Emoji alert indicator shown next to severity label.
  String get alert =>
      severity == 'CRITICAL' || severity == 'SEVERE' ? '🚨' :
      severity == 'MODERATE' ? '⚠️' : '🟢';

  /// True when the result came from the on-device rule engine (no backend).
  bool get isOfflineFallback => !fromBackend;

  /// Short label for the monitoring card header.
  String get monitoringLevel => monitoring.level;

  /// Recommended action text shown in the monitoring card.
  String get monitoringAction => monitoring.action;

  // ── Factory: lift from internal core result ───────────────────────────────
  factory FloodPrediction.fromCore(
    CoreFloodPrediction core, {
    double? liveRiverLevelM,
  }) =>
      FloodPrediction(
        severity:           core.severity,
        confidencePercent:  core.confidencePercent,
        probabilities:      core.probabilities,
        algorithm:          core.algorithm,
        dataSource:         core.dataSource,
        riskScore:          core.riskScore,
        dangerLevel:        core.dangerLevel,
        proximityToDangerM: core.proximityToDangerM,
        monitoring:         core.monitoring,
        ensembleDetails:    core.ensembleDetails,
        fromBackend:        core.fromBackend,
        timestamp:          core.timestamp,
        liveRiverLevelM:    liveRiverLevelM,
      );
}

// ─── Service facade ───────────────────────────────────────────────────────────
// const-constructible so predict_screen can do `const PredictionService()`.
// All work delegates to PredictionServiceImpl.instance.

class PredictionService {
  const PredictionService();

  // ── Live prediction (backend ML + CWC via proxy) ──────────────────────────
  Future<FloodPrediction> predict(FloodPredictionInput input) async {
    // Attempt to fetch live CWC river level via the backend proxy.
    // This replaces the old direct CwcService call (CORS-blocked on device).
    double? liveLevel = await _fetchLiveLevel(input.station, input.state);

    final core = input.toPredictionInput();
    try {
      final result = await PredictionServiceImpl.instance
          .backendPredict(core, liveLevel: liveLevel);
      return FloodPrediction.fromCore(result, liveRiverLevelM: liveLevel);
    } catch (e) {
      // Backend unavailable — fall through to offline rule engine.
      return predictOffline(input, liveLevel: liveLevel);
    }
  }

  // ── Offline prediction (on-device rule engine only) ───────────────────────
  FloodPrediction predictOffline(
    FloodPredictionInput input, {
    double? liveLevel,
  }) {
    final core = PredictionServiceImpl.instance
        .localRuleEnginePredict(input.toPredictionInput(), liveLevel: liveLevel);
    return FloodPrediction.fromCore(core, liveRiverLevelM: liveLevel);
  }

  // ── CWC level via backend proxy ───────────────────────────────────────────
  // Routes through ApiService → backend → CWC  (no direct CWC calls from device).
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
