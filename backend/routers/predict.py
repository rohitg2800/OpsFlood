"""
Prediction router: ML model predictions, artifacts, and state severity matrix endpoints.
"""

import asyncio
from fastapi import APIRouter
from pydantic import BaseModel

from .dependencies import (
    get_source_policy_payload,
    model_to_dict,
    write_audit_log,
    calculate_rainfall_total,
    operational_store,
    STATE_SEVERITY_MATRIX,
    get_state_severity_entry,
)
from .model_artifacts import discover_model_artifacts, discover_model_bundles, discover_legacy_artifacts_outside_store

router = APIRouter(tags=["prediction"])

# Importing FloodPredictionInput from backend.app creates a circular import
# (backend.app imports this router at module import-time). Define a local
# compatible Pydantic model instead.
from pydantic import BaseModel


class FloodPredictionInput(BaseModel):
    Peak_Flood_Level_m: float = 8.5
    Event_Duration_days: float = 1
    Time_to_Peak_days: float = 1
    Recession_Time_day: float = 1
    T1d: float = 10.0
    T2d: float = 15.0
    T3d: float = 20.0
    T4d: float = 18.0
    T5d: float = 12.0
    T6d: float = 8.0
    T7d: float = 7.0
    state: str = "Maharashtra"
    station: str | None = None


# ============= PYDANTIC SCHEMA =============


def persist_prediction_record(input_data, result):
    """Persist prediction record to storage."""
    try:
        input_payload = model_to_dict(input_data)
        station_name = str(input_payload.get("station") or "").strip() or None
        state_name = str(input_payload.get("state") or "Maharashtra").strip()
        rainfall_total = calculate_rainfall_total(input_payload)

        prediction_id = operational_store.save_prediction(
            {
                "state_name": state_name,
                "city_name": station_name,
                "station_name": station_name,
                "peak_level_m": float(input_payload.get("Peak_Flood_Level_m") or 0.0),
                "rainfall_total_mm": rainfall_total,
                "severity": str(result.get("severity") or "UNKNOWN"),
                "confidence_percent": float(result.get("confidence_percent") or 0.0),
                "risk_score": int(result.get("risk_score") or 0),
                "data_source": str(result.get("data_source") or ""),
                "algorithm": str(result.get("algorithm") or ""),
                "model_version": str(result.get("algorithm") or ""),
                "monitoring_level": str((result.get("monitoring") or {}).get("level") or ""),
                "monitoring_action": str((result.get("monitoring") or {}).get("action") or ""),
                "source_policy_mode": str((result.get("source_policy") or {}).get("mode") or ""),
                "source_policy_label": str((result.get("source_policy") or {}).get("label") or ""),
                "input_payload": input_payload,
                "prediction_payload": result,
            }
        )
    except Exception as exc:
        print(f"⚠️ Prediction persistence failed: {exc}")
        prediction_id = None

    write_audit_log(
        event_type="prediction.inference",
        route="/predict",
        event_status="success" if prediction_id else "skipped",
        state_name=state_name,
        station_name=station_name,
        severity=str(result.get("severity") or "UNKNOWN"),
        details={
            "prediction_id": prediction_id,
            "data_source": result.get("data_source"),
            "confidence_percent": result.get("confidence_percent"),
            "risk_score": result.get("risk_score"),
            "storage_ready": operational_store.status().get("ready"),
        },
    )
    return prediction_id

# ============= MODEL ARTIFACTS ENDPOINTS =============
@router.get("/model-artifacts")
async def get_model_artifacts(predictor=None):
    """Get available model artifacts."""
    ignored_legacy_artifacts = discover_legacy_artifacts_outside_store()
    if predictor:
        predictor.refresh_artifact_catalog()
        return {
            "status": "success",
            "base_dir": predictor.artifact_store_dir,
            "storage_backend": predictor.artifact_storage_backend,
            "artifact_count": len(predictor.artifact_catalog),
            "bundle_count": len(predictor.artifact_bundles),
            "default_bundle_key": predictor.default_bundle_key,
            "default_model": {
                "model": predictor.default_model_paths[0],
                "scaler": predictor.default_model_paths[1],
            },
            "bundles": predictor.artifact_bundles,
            "artifacts": predictor.artifact_catalog,
            "ignored_legacy_artifacts": ignored_legacy_artifacts,
        }

    # Fallback if predictor not initialized
    artifacts = discover_model_artifacts()
    bundles = discover_model_bundles(artifacts)
    return {
        "status": "success",
        "artifact_count": len(artifacts),
        "bundle_count": len(bundles),
        "bundles": bundles,
        "artifacts": artifacts,
        "ignored_legacy_artifacts": ignored_legacy_artifacts,
    }


@router.get("/model-artifacts/{state_name}")
async def get_model_artifacts_for_state(state_name: str, predictor=None):
    """Get model artifacts for a specific state."""
    if predictor:
        return {
            "status": "success",
            "selection": predictor.describe_state_model_artifacts(state_name),
        }

    return {
        "status": "success",
        "state": state_name,
        "message": "Predictor not initialized",
    }


# ============= MODEL METRICS ENDPOINT =============
@router.get("/model-metrics")
async def get_model_metrics(predictor=None):
    """
    Return model quality metrics for the active bundle.
    Used by the Flutter Dashboard to display a model confidence card.

    Returns:
        {
          "status": "success",
          "model_trained": bool,
          "algorithm": str,
          "bundle_key": str,
          "metrics": {
            "accuracy": float,       # 0.0 - 1.0
            "f1_score": float,       # macro-averaged
            "precision": float,
            "recall": float,
            "training_samples": int,
          }
        }
    """
    if predictor and hasattr(predictor, "get_metrics"):
        try:
            metrics = predictor.get_metrics()
            return {
                "status": "success",
                "model_trained": True,
                "algorithm": getattr(predictor, "algorithm_name", "Ensemble"),
                "bundle_key": getattr(predictor, "default_bundle_key", "default"),
                "metrics": metrics,
            }
        except Exception as exc:
            return {
                "status": "warning",
                "model_trained": True,
                "message": f"Metrics unavailable: {exc}",
                "metrics": {},
            }

    # Predictor not loaded or metrics not available — return graceful degradation
    return {
        "status": "unavailable",
        "model_trained": False,
        "message": "Predictor not initialized or metrics not computed yet.",
        "metrics": {},
    }


# ============= STATE SEVERITY MATRIX ENDPOINTS =============
@router.get("/state-severity-matrix")
async def get_state_severity_matrix():
    """Get state severity matrix."""
    return {
        "status": "success",
        "states": STATE_SEVERITY_MATRIX,
        "note": "CWC-calibrated thresholds with Option-A danger_level_override_guard active.",
    }


@router.get("/state-severity-matrix/{state_name}")
async def get_state_severity_matrix_for_state(state_name: str):
    """Get severity matrix for a specific state."""
    return {
        "status": "success",
        "state": state_name,
        "matrix": get_state_severity_entry(state_name),
        "note": "CWC-calibrated thresholds with Option-A danger_level_override_guard active.",
    }


# ============= PREDICTION ENDPOINT (LEGACY) =============
@router.post("/predict/legacy")
async def predict_flood_legacy(
    input_data: FloodPredictionInput, predictor=None, cwc_scraper=None
):
    """Predict flood risk for given input."""
    try:
        source_policy = get_source_policy_payload()
        data_source = str(source_policy["prediction_data_source"])

        # FIX: always initialise river_level_m before conditional branches
        # so the Option-A guard is reliably invoked regardless of
        # allow_live_cwc_in_app or cwc_scraper availability.
        river_level_m: float | None = None

        if source_policy.get("allow_live_cwc_in_app") and cwc_scraper:
            print("🔄 Fetching live data from Central Water Commission...")
            try:
                live_data = await asyncio.to_thread(
                    cwc_scraper.get_live_river_level,
                    input_data.station or "Kolhapur",
                )
                if live_data.get("status") in ["success", "success_fallback"]:
                    data_source = "Live CWC Data"
                    # CWC scraper returns current_level_m; this feeds Option-A guard.
                    river_level_m = live_data.get("current_level_m")
            except Exception as e:
                print(f"⚠️ Live CWC fetch failed, falling back: {e}")

        if predictor:
            result = await asyncio.to_thread(
                predictor.predict_flood,
                input_data,
                source=data_source,
                river_level_m=river_level_m,
            )
        else:
            # Fallback to simple prediction if predictor not available
            result = {
                "severity": "MODERATE",
                "confidence_percent": 75.0,
                "probabilities": {"SEVERE": 25, "MODERATE": 75, "LOW": 0, "CRITICAL": 0},
                "alert": "⚠️",
                "algorithm": "Fallback",
                "data_source": data_source,
                "model_trained": False,
                "risk_score": 50,
                "state": input_data.state,
            }

        result["source_policy"] = source_policy

        # Persist prediction record
        persist_prediction_record(input_data, result)

        return result

    except Exception as e:
        return {
            "status": "error",
            "message": str(e),
            "severity": "UNKNOWN",
            "risk_score": 0,
            "source_policy": get_source_policy_payload(),
        }


# ============= PREDICTION ENDPOINT V2 (AUTO-FILL FROM CWC) =============
@router.post("/predict/v2")
async def predict_flood_v2(
    input_data: FloodPredictionInput, predictor=None, cwc_scraper=None
):
    """
    Auto-fill prediction: fetches live CWC telemetry for the requested
    state/station before running inference.

    This endpoint allows zero-manual-input predictions from the Flutter app:
    the app sends state + station only; Peak_Flood_Level_m, rainfall T1d-T7d
    are auto-populated from the live CWC scraper when available.

    Falls back to the provided input values if live data is unavailable.
    """
    try:
        source_policy = get_source_policy_payload()
        data_source = str(source_policy["prediction_data_source"])
        river_level_m: float | None = None
        autofill_applied = False

        if cwc_scraper:
            try:
                station_query = input_data.station or input_data.state
                live_data = await asyncio.to_thread(
                    cwc_scraper.get_live_river_level,
                    station_query,
                )
                if live_data.get("status") in ["success", "success_fallback"]:
                    river_level_m = live_data.get("current_level_m")
                    # Auto-fill Peak_Flood_Level_m from live gauge if not manually set
                    if river_level_m and input_data.Peak_Flood_Level_m == 8.5:
                        input_data = input_data.model_copy(
                            update={"Peak_Flood_Level_m": float(river_level_m)}
                        )
                        autofill_applied = True
                    data_source = "Live CWC Data (auto-fill)"
            except Exception as e:
                print(f"⚠️ V2 CWC auto-fill failed, using manual input: {e}")

        if predictor:
            result = await asyncio.to_thread(
                predictor.predict_flood,
                input_data,
                source=data_source,
                river_level_m=river_level_m,
            )
        else:
            result = {
                "severity": "MODERATE",
                "confidence_percent": 75.0,
                "probabilities": {"SEVERE": 25, "MODERATE": 75, "LOW": 0, "CRITICAL": 0},
                "alert": "⚠️",
                "algorithm": "Fallback",
                "data_source": data_source,
                "model_trained": False,
                "risk_score": 50,
                "state": input_data.state,
            }

        result["source_policy"] = source_policy
        result["autofill_applied"] = autofill_applied
        result["live_river_level_m"] = river_level_m

        persist_prediction_record(input_data, result)

        return result

    except Exception as e:
        return {
            "status": "error",
            "message": str(e),
            "severity": "UNKNOWN",
            "risk_score": 0,
            "source_policy": get_source_policy_payload(),
        }


@router.get("/prediction-history")
async def get_prediction_history(state: str | None = None, limit: int = 50):
    """Get recent prediction history."""
    records = operational_store.list_predictions(limit=limit, state_name=state)
    return {
        "status": "success",
        "storage": operational_store.status(),
        "total_records": len(records),
        "records": [
            {
                "id": record["id"],
                "timestamp": record["created_at"].isoformat() if record.get("created_at") else None,
                "state": record.get("state_name"),
                "city": record.get("city_name"),
                "station": record.get("station_name"),
                "peak_level": float(record.get("peak_level_m") or 0.0),
                "rainfall": float(record.get("rainfall_total_mm") or 0.0),
                "severity": record.get("severity"),
                "confidence": float(record.get("confidence_percent") or 0.0),
                "risk_score": record.get("risk_score"),
                "data_source": record.get("data_source"),
                "algorithm": record.get("algorithm"),
                "model_version": record.get("model_version"),
                "monitoring_level": record.get("monitoring_level"),
                "monitoring_action": record.get("monitoring_action"),
                "source_policy_mode": record.get("source_policy_mode"),
                "source_policy_label": record.get("source_policy_label"),
            }
            for record in records
        ],
    }
