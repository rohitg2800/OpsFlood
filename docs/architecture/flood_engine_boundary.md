# `flood_engine.dart` — Usage Boundary & Non-Duplication Contract

## What It Is

`lib/ml/flood_engine.dart` is the **on-device fallback ML engine**. It runs entirely in Dart, requires no network, and produces a `FloodResult` when the FastAPI backend (`opsflood.onrender.com`) is unreachable.

## What the FastAPI Backend Does (Do Not Duplicate)

| Capability | Backend (`app.py`) | `flood_engine.dart` |
|---|---|---|
| Trained model inference | ✅ XGBoost + RandomForest ensemble loaded from `.pkl` | ❌ Not replicated |
| Real CWC telemetry fetch | ✅ Live river gauge API | ❌ Not available offline |
| Real IMD rainfall fetch | ✅ Live weather API | ❌ Not available offline |
| Prediction via `/predict/legacy` | ✅ Full probability vector | ❌ |
| On-device heuristic estimate | ❌ | ✅ Rule + combinedScore blend |
| State severity matrix lookup | ✅ `state_severity_matrix.py` | ✅ Ported Dart mirror |

## Decision Boundary (call site in `real_time_service.dart`)

```
if (apiAvailable) {
  → call FastAPI /predict/legacy  ← use this result
} else {
  → call runOnDeviceEngine()      ← offline fallback only
  → result.isOfflineEstimate = true (always)
}
```

## What `flood_engine.dart` MUST NOT do

- ❌ Make HTTP requests (use `real_time_service.dart` for that)
- ❌ Read SharedPreferences or platform channels
- ❌ Replace the backend prediction during normal online operation
- ❌ Diverge from the feature column order in `EXPECTED_FEATURE_COLUMNS` (app.py)

## What `flood_engine.dart` MUST do

- ✅ Always set `isOfflineEstimate = true`
- ✅ Return a `FloodResult` within <5ms (pure Dart computation)
- ✅ Stay in sync with `state_severity_matrix.py` thresholds
- ✅ Pass all tests in `test/flood_engine_test.dart`
