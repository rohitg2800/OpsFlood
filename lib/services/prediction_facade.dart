// lib/services/prediction_facade.dart
// ────────────────────────────────────────────────────────────────────────────────
// Public façade for the flood-prediction subsystem.
//
// Screens import this file only — never prediction_service.dart directly.
// This keeps the surface area small and lets us swap the engine later
// without touching any screen code.
//
// EXPORTS
//   FloodPredictionInput  — UI → engine input DTO
//   FloodPrediction       — engine → UI result (re-exported from core)
//   PredictionService     — façade singleton with predict() + livePredict()
//
// UNIFIED PIPELINE FLOW (new)
//   predict() now runs a 3-step pipeline:
//     1. Fetch PipelineFeatures from /api/pipeline/features
//        - Pre-fills peakFloodLevelM from river_level_m
//        - Pre-fills t1d from rainfall_1h_mm * 24
//     2. Call /predict/v2 on the backend (which also does its own pipeline autofill)
//     3. Fall back to local rule engine on any network failure
//        (uses PipelineService.entryForState — no hardcoded matrix)
library;

import 'prediction_service.dart';
import 'pipeline_service.dart';

export 'prediction_service.dart'
    show FloodPrediction, MonitoringProtocol, PredictionInput;
export 'pipeline_service.dart' show PipelineFeatures;

typedef FloodPredictionInput = PredictionInput;

class PredictionService {
  PredictionService._();
  static final PredictionService instance = PredictionService._();

  final _engine = PredictionServiceImpl.instance;

  /// Primary predict: pipeline pre-fill → backend → local rule engine fallback.
  ///
  /// [input] fields still at their sentinel defaults (peakFloodLevelM=8.5,
  /// t1d=10.0) are overwritten with pipeline data when available.
  /// Explicitly set values from the UI are always respected.
  Future<FloodPrediction> predict(
    FloodPredictionInput input, {
    double? liveLevel,
  }) async {
    // Step 1: Try to enrich input from the pipeline feature row
    final enriched = await _enrichFromPipeline(input);

    // Step 2: Backend predict (pipeline will also auto-fill on server side)
    try {
      return await _engine.backendPredict(enriched, liveLevel: liveLevel);
    } catch (_) {
      // Step 3: Offline rule engine with backend-sourced thresholds
      return _engine.localRuleEnginePredict(enriched, liveLevel: liveLevel);
    }
  }

  /// Offline-only rule engine — no network call.
  FloodPrediction localPredict(
    FloodPredictionInput input, {
    double? liveLevel,
  }) =>
      _engine.localRuleEnginePredict(input, liveLevel: liveLevel);

  // ── Private ──────────────────────────────────────────────────────────────

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

      // Only replace sentinel defaults, never override explicit user input
      if (peakLevel == 8.5 && features.riverLevelM != null && features.riverLevelM! > 0) {
        peakLevel = features.riverLevelM!;
      }
      final dailyRain = features.bestDailyRainfallMm;
      if (t1d == 10.0 && dailyRain != null && dailyRain > 0) {
        t1d = dailyRain;
      }

      if (peakLevel == input.peakFloodLevelM && t1d == input.t1d) {
        return input; // nothing to enrich
      }

      return PredictionInput(
        peakFloodLevelM:   peakLevel,
        eventDurationDays: input.eventDurationDays,
        timeToPeakDays:    input.timeToPeakDays,
        recessionTimeDays: input.recessionTimeDays,
        t1d: t1d,
        t2d: input.t2d,
        t3d: input.t3d,
        t4d: input.t4d,
        t5d: input.t5d,
        t6d: input.t6d,
        t7d: input.t7d,
        state:   input.state,
        station: input.station,
      );
    } catch (_) {
      return input; // never crash the prediction flow
    }
  }
}
