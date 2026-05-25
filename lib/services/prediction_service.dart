// lib/services/prediction_service.dart
//
// ── RE-EXPORT SHIM ────────────────────────────────────────────────────────────
// This file previously contained a 350-line duplicate of the prediction engine
// that had diverged from predict.dart (different class names for the same
// logic, duplicate FloodPrediction / MonitoringProtocol types, same backend
// endpoint /predict/v2 called twice from different paths).
//
// The canonical prediction stack is:
//   lib/services/predict.dart           — PredictionService (backend + local rule engine)
//   lib/services/prediction_facade.dart — FloodPredictionFacade (orchestrator for screens)
//
// Screens should import prediction_facade.dart directly.
// This shim keeps legacy imports from breaking.
//
// DO NOT add anything new here.
// ─────────────────────────────────────────────────────────────────────────────
export 'predict.dart';
export 'prediction_facade.dart';
