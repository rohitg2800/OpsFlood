# backend/routers/dependencies.py
"""
Shared helpers, imports, and singleton instances for all OpsFlood routers.

All routers import from here so that global objects (operational_store,
ScheduledIngestionService, pipeline instances) are created exactly once.
"""

import os
import asyncio
import copy
import re
import hashlib
import json
import datetime
import importlib.util as _importlib_util
import requests
from pathlib import Path
from typing import Dict, Any, Tuple, Optional
from dotenv import load_dotenv
from fastapi import HTTPException
from sklearn.preprocessing import StandardScaler
from sklearn.ensemble import RandomForestClassifier


# ============= ENV BOOTSTRAP =============

def refresh_backend_env(override: bool = False):
    """Load environment variables from multiple .env files."""
    env_paths = [
        Path(".") / ".env",
        Path(".") / ".env.local",
        Path("..") / ".env",
        Path("..") / ".env.local",
        Path("backend") / ".env",
        Path("backend") / ".env.local",
    ]
    for p in env_paths:
        if p.exists():
            load_dotenv(dotenv_path=p, override=override)


refresh_backend_env()


def _is_package_context() -> bool:
    return _importlib_util.find_spec("backend") is not None


# ============= CONDITIONAL IMPORTS =============

if _importlib_util.find_spec("backend") is not None:
    from backend.data_pipeline import IngestionTarget, OperationalDataPipeline, ScheduledIngestionService
    from backend.state_severity_matrix import (
        STATE_SEVERITY_MATRIX,
        get_state_severity_entry,
        severity_from_entry,
        build_effective_state_entry,
        select_best_station_node,
    )
    from backend.postgres_store import PostgresOperationalStore
    from backend.model_metrics import evaluate_and_log_metrics
else:
    from data_pipeline import IngestionTarget, OperationalDataPipeline, ScheduledIngestionService
    from state_severity_matrix import STATE_SEVERITY_MATRIX, get_state_severity_entry, severity_from_entry, build_effective_state_entry, select_best_station_node
    from postgres_store import PostgresOperationalStore
    from model_metrics import evaluate_and_log_metrics

# ============= GLOBAL INSTANCES =============
operational_store = PostgresOperationalStore()
operational_store.initialize()


# ============= CONSTANTS =============
WEATHER_CACHE_TTL_SECONDS = 600


# ============= ENV HELPERS =============

def env_flag(name: str, default: bool = False) -> bool:
    v = os.getenv(name, "").strip().lower()
    if v in ("1", "true", "yes", "on"):
        return True
    if v in ("0", "false", "no", "off"):
        return False
    return default


def get_source_policy_mode() -> str:
    """Get source policy mode from environment."""
    return os.getenv("SOURCE_POLICY_MODE", "open_data_context").strip().lower()


def live_cwc_enabled() -> bool:
    """Whether live CWC telemetry is allowed in-app."""
    return env_flag("ALLOW_LIVE_CWC", default=True)


def get_openweather_api_key() -> str:
    key = os.getenv("OPENWEATHER_API_KEY", "").strip()
    if not key:
        raise HTTPException(status_code=503, detail="OpenWeather API key not configured.")
    return key


# ============= ARTIFACT HELPERS =============

def get_model_artifact_backend() -> str:
    return os.getenv("MODEL_ARTIFACT_BACKEND", "local").strip().lower()


def get_model_artifact_root() -> str:
    root = os.getenv("MODEL_ARTIFACT_ROOT", "").strip()
    if root:
        return root
    # Default: backend/artifacts/models
    base = Path(__file__).resolve().parent.parent  # backend/
    return str(base / "artifacts" / "models")


def backend_path(*parts: str) -> str:
    base = Path(__file__).resolve().parent.parent
    return str(base.joinpath(*parts))


def backend_relative_path(path: str) -> str:
    base = Path(__file__).resolve().parent.parent
    return str(base / path)


def repo_relative_path(path: str) -> str:
    base = Path(__file__).resolve().parent.parent.parent
    return str(base / path)


def resolve_model_artifact_path(path_name: str) -> str:
    """
    Resolve a model artifact path to an absolute path.
    Supports:
      - Absolute paths
      - Paths relative to the backend/ directory
      - Paths relative to the repo root
    """
    p = Path(path_name)
    if p.is_absolute():
        return str(p)
    # Try relative to backend/
    backend_p = Path(__file__).resolve().parent.parent / p
    if backend_p.exists():
        return str(backend_p)
    # Try relative to repo root
    repo_p = Path(__file__).resolve().parent.parent.parent / p
    if repo_p.exists():
        return str(repo_p)
    # Fall back to backend-relative (even if not found)
    return str(backend_p)


def default_model_artifact_paths() -> Tuple[str, str]:
    """Return (model_path, scaler_path) for the default bundle."""
    root = get_model_artifact_root()
    model_path = os.path.join(root, "flood_model.pkl")
    scaler_path = os.path.join(root, "scaler.pkl")
    return model_path, scaler_path


def frontend_dist_ready() -> bool:
    frontend = Path(__file__).resolve().parent.parent.parent / "frontend" / "dist"
    return frontend.exists() and any(frontend.iterdir())


def resolve_frontend_asset(path_name: str) -> str | None:
    frontend = Path(__file__).resolve().parent.parent.parent / "frontend" / "dist"
    p = frontend / path_name.lstrip("/")
    return str(p) if p.exists() else None


# ============= STRING HELPERS =============

def slugify_name(value: str) -> str:
    value = value.lower().strip()
    value = re.sub(r"[^a-z0-9]+", "-", value)
    return value.strip("-")


def normalize_weather_lookup(value: str) -> str:
    return value.strip().lower()


def normalize_origin_url(value: str) -> str:
    """Strip trailing slashes and lowercase the URL."""
    return value.strip().rstrip("/").lower()


def title_case_location_label(value: str) -> str:
    return value.strip().title()


# ============= WEATHER CACHE =============

def _weather_hash_unit(seed: str) -> float:
    digest = hashlib.sha256(seed.encode()).digest()
    return int.from_bytes(digest[:8], "big") / float((1 << 64) - 1)


def _weather_cache_key(path: str, params: Dict[str, Any]) -> str:
    raw = json.dumps({"path": path, "params": params}, sort_keys=True)
    return hashlib.md5(raw.encode()).hexdigest()


_weather_cache: Dict[str, Any] = {}


def get_cached_weather_response(
    path: str, params: Dict[str, Any], max_age: int = WEATHER_CACHE_TTL_SECONDS
) -> Any | None:
    key = _weather_cache_key(path, params)
    entry = _weather_cache.get(key)
    if entry is None:
        return None
    age = (datetime.datetime.utcnow() - entry["ts"]).total_seconds()
    if age > max_age:
        del _weather_cache[key]
        return None
    return entry["data"]


def store_weather_response(path: str, params: Dict[str, Any], data: Any):
    key = _weather_cache_key(path, params)
    _weather_cache[key] = {"ts": datetime.datetime.utcnow(), "data": data}


# ============= CORS ORIGINS =============

def configured_cors_origins() -> list[str]:
    raw = os.getenv("CORS_ORIGINS", "").strip()
    defaults = [
        "http://localhost:3000",
        "http://localhost:8000",
        "http://localhost:8080",
        "http://127.0.0.1:8000",
        "http://127.0.0.1:3000",
    ]
    if not raw:
        return defaults
    parsed = [normalize_origin_url(o) for o in raw.split(",") if o.strip()]
    return list(dict.fromkeys(defaults + parsed))


# ============= AUDIT LOG =============

def current_timestamp_iso() -> str:
    return datetime.datetime.utcnow().isoformat() + "Z"


def write_audit_log(
    event_type: str,
    route: str,
    event_status: str,
    state_name: str = "",
    station_name: str = "",
    severity: str = "",
    details: Dict[str, Any] = None,
) -> None:
    try:
        operational_store.save_audit_log(
            {
                "event_type": event_type,
                "route": route,
                "event_status": event_status,
                "state_name": state_name,
                "station_name": station_name,
                "severity": severity,
                "details": details or {},
            }
        )
    except Exception as exc:
        print(f"⚠️ Audit log write failed (non-fatal): {exc}")


# ============= TELEMETRY HELPERS =============

def persist_telemetry_record(
    state_name: str,
    station_name: str,
    limit: int,
    telemetry: Dict[str, Any],
    route: str,
) -> int | None:
    """Persist telemetry snapshot to storage."""
    node_count = len(telemetry.get("data", [])) if isinstance(telemetry.get("data"), list) else 0
    try:
        snapshot_id = operational_store.save_telemetry_snapshot(
            {
                "state_name": state_name,
                "station_name": station_name,
                "node_count": node_count,
                "snapshot_status": str(telemetry.get("status") or ""),
                "data_source": str(telemetry.get("data_source") or ""),
                "source_policy_mode": str(((telemetry.get("source_policy") or {}).get("mode")) or ""),
                "limit": limit,
                "payload": telemetry,
            }
        )
    except Exception as exc:
        print(f"⚠️ Telemetry persistence failed: {exc}")
        snapshot_id = None

    write_audit_log(
        event_type="telemetry.snapshot",
        route=route,
        event_status="success" if snapshot_id else "skipped",
        state_name=state_name,
        station_name=station_name,
        details={
            "snapshot_id": snapshot_id,
            "telemetry_status": telemetry.get("status"),
            "data_source": telemetry.get("data_source"),
        },
    )
    return snapshot_id


# ============= MODEL HELPERS =============

def model_to_dict(model: Any) -> Dict[str, Any]:
    if hasattr(model, "model_dump"):
        return model.model_dump()
    if hasattr(model, "dict"):
        return model.dict()
    return dict(model)


def calculate_rainfall_total(input_payload: Dict[str, Any]) -> float:
    keys = [f"T{i}d" for i in range(1, 8)]
    return round(sum(float(input_payload.get(k) or 0.0) for k in keys), 2)


def get_pipeline_features(
    state_name: str | None = None,
    station_name: str | None = None,
) -> Optional[Dict[str, Any]]:
    """
    Read the most recent OperationalDataPipeline feature row for this
    (state, station) pair from:

        data/features/weather_water/weather_water_features_latest.csv

    Returns a dict with column names as keys, or None if not available.

    Key columns returned (when present):
      river_level_m   → Peak_Flood_Level_m
      rainfall_1h_mm  → T1d (scaled)
      rainfall_24h_mm
      ...
    """
    try:
        import pandas as pd
        csv_path = backend_relative_path(
            "data/features/weather_water/weather_water_features_latest.csv"
        )
        if not Path(csv_path).exists():
            return None
        df = pd.read_csv(csv_path)
        if df.empty:
            return None

        # Filter by state if present
        if state_name:
            col = next(
                (c for c in df.columns if c.lower() in ("state", "state_name")),
                None,
            )
            if col:
                mask = df[col].str.lower() == state_name.lower()
                if mask.any():
                    df = df[mask]

        # Filter by station if present
        if station_name:
            col = next(
                (c for c in df.columns if c.lower() in ("station", "station_name", "city", "city_name")),
                None,
            )
            if col:
                mask = df[col].str.lower() == station_name.lower()
                if mask.any():
                    df = df[mask]

        import math
        # Take the most recent row
        row = df.iloc[-1].to_dict()
        # Strip NaN values
        return {k: v for k, v in row.items() if not (isinstance(v, float) and math.isnan(v))}
    except Exception as exc:
        print(f"[WARN] get_pipeline_features failed: {exc}")
        return None


def get_pipeline_manifest() -> Optional[Dict[str, Any]]:
    """Read the pipeline run manifest (JSON) if present."""
    try:
        manifest_path = backend_relative_path(
            "data/features/weather_water/pipeline_manifest.json"
        )
        if not Path(manifest_path).exists():
            return None
        with open(manifest_path) as f:
            return json.load(f)
    except Exception:
        return None


def pipeline_autofill_predict_input(
    input_dict: Dict[str, Any],
    state_name: str | None = None,
    station_name: str | None = None,
) -> Dict[str, Any]:
    """
    Auto-fill sentinel default values in input_dict from the pipeline feature CSV.

    Sentinel defaults that get replaced:
      Peak_Flood_Level_m  == 8.5   → replaced with river_level_m
      T1d                 == 10.0  → replaced with scaled rainfall_1h_mm

    Manual overrides from the Flutter UI or API caller are always respected.
    """
    out = copy.deepcopy(input_dict)
    features = get_pipeline_features(state_name, station_name)
    meta = {"applied": False, "source": "none", "fields_replaced": []}

    if not features:
        out["_pipeline_autofill"] = meta
        return out

    def _f(key: str) -> Optional[float]:
        v = features.get(key)
        try:
            return float(v) if v is not None else None
        except (TypeError, ValueError):
            return None

    river_level = _f("river_level_m")
    if river_level is not None and river_level > 0 and float(out.get("Peak_Flood_Level_m", 8.5)) == 8.5:
        out["Peak_Flood_Level_m"] = round(river_level, 3)
        meta["fields_replaced"].append("Peak_Flood_Level_m")
        meta["applied"] = True
        meta["source"] = "pipeline_csv"

    rainfall_1h = _f("rainfall_1h_mm")
    if rainfall_1h is not None and float(out.get("T1d", 10.0)) == 10.0:
        # Scale 1h reading to approximate 24h by × 12 (conservative midday factor)
        t1d_estimate = round(min(rainfall_1h * 12.0, 400.0), 2)
        out["T1d"] = t1d_estimate
        meta["fields_replaced"].append("T1d")
        meta["applied"] = True
        meta["source"] = "pipeline_csv"

    out["_pipeline_autofill"] = meta
    return out


# ============= SOURCE POLICY =============

def get_source_policy_payload() -> Dict[str, Any]:
    mode = get_source_policy_mode()
    allow_live_cwc = live_cwc_enabled()

    if mode == "live_cwc":
        return {
            "mode": "live_cwc",
            "label": "Live CWC Telemetry",
            "allow_live_cwc_in_app": True,
            "allow_live_cwc_in_monitoring": True,
            "prediction_data_source": "Live CWC + Open Data Context" if allow_live_cwc else "Open Data Context + Manual Input",
            "description": "Use live CWC river gauge data for flood predictions.",
        }
    if mode == "manual_only":
        return {
            "mode": "manual_only",
            "label": "Manual Input Only",
            "allow_live_cwc_in_app": False,
            "allow_live_cwc_in_monitoring": False,
            "prediction_data_source": "Fallback Manual Context",
            "description": "Manual input only. No live data sources.",
        }
    # Default: open_data_context
    return {
        "mode": "open_data_context",
        "label": "Open Data Context",
        "allow_live_cwc_in_app": allow_live_cwc,
        "allow_live_cwc_in_monitoring": True,
        "prediction_data_source": "Live CWC Detection + Manual Input" if allow_live_cwc else "Official View Only + Manual Input",
        "description": "Use open/publicly reusable datasets as the legal default. Live CWC telemetry is enabled for automatic operational monitoring.",
    }
