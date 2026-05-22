// lib/services/prediction_facade.dart
// ─────────────────────────────────────────────────────────────────────────────
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
// USAGE (predict_screen.dart)
//   import '../services/prediction_facade.dart';
//   final result = await PredictionService.instance.predict(input);
library;

import 'prediction_service.dart';

// Re-export public types so screens never need to import prediction_service.dart
export 'prediction_service.dart'
    show FloodPrediction, MonitoringProtocol, PredictionInput;

// ── Input DTO exposed to UI ────────────────────────────────────────────────
// FloodPredictionInput is a thin alias over PredictionInput.
// Keeping the name distinct from the engine type prevents UI code from
// accidentally depending on internal engine fields.
typedef FloodPredictionInput = PredictionInput;

// ── Façade singleton ───────────────────────────────────────────────────────
class PredictionService {
  PredictionService._();
  static final PredictionService instance = PredictionService._();

  final _engine = PredictionServiceImpl.instance;

  /// Primary predict: tries backend first, falls back to local rule engine.
  Future<FloodPrediction> predict(
    FloodPredictionInput input, {
    double? liveLevel,
  }) async {
    try {
      return await _engine.backendPredict(input, liveLevel: liveLevel);
    } catch (_) {
      return _engine.localRuleEnginePredict(input, liveLevel: liveLevel);
    }
  }

  /// Offline-only rule engine — no network call.
  FloodPrediction localPredict(
    FloodPredictionInput input, {
    double? liveLevel,
  }) =>
      _engine.localRuleEnginePredict(input, liveLevel: liveLevel);
}
