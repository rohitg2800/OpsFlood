"""
Shared dependencies, utilities, and configuration for all routers.
This module contains:
- Global instances (predictor, operational_store, cwc_scraper, etc.)
- Utility functions for paths, weather, models, and artifacts
- Database and storage dependencies
- Constants and configuration
"""

import os
import asyncio
import copy
import re
import hashlib
import json
import datetime
import requests
from typing import Dict, Any, Tuple
from dotenv import load_dotenv
from fastapi import HTTPException
from sklearn.preprocessing import StandardScaler
from sklearn.ensemble import RandomForestClassifier

# ============= PATH CONFIGURATION =============
BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
REPO_DIR = os.path.abspath(os.path.join(BASE_DIR, os.pardir))
FRONTEND_DIST_DIR = os.path.join(REPO_DIR, "frontend", "dist")
FRONTEND_INDEX_PATH = os.path.join(FRONTEND_DIST_DIR, "index.html")
DEFAULT_MODEL_ARTIFACTS_DIR = os.path.join(REPO_DIR, "artifacts", "dvc", "models")
MODEL_ARTIFACT_BACKENDS = {"DVC", "FILESYSTEM"}
DEFAULT_MODEL_ARTIFACT_FILES = ("flood_model.pkl", "flood_scaler.pkl")

# ============= WEATHER CONFIGURATION =============
WEATHER_CACHE_TTL_SECONDS = 20 * 60
WEATHER_TIMEZONE_OFFSET = 19800
WEATHER_TIMEZONE_NAME = "Asia/Kolkata"
WEATHER_CACHE: Dict[str, Dict[str, Any]] = {}
WEATHER_QUERY_NOISE_PATTERN = re.compile(
    r"\b(sector|region|lowlands?|basin|banks?|bridge|barrage|ghats?|control|command|high[-\s]?ground|coastal|delta|island|catchment|console)\b",
    re.IGNORECASE,
)

# ============= MODEL ARTIFACTS =============
FLOOD_ARTIFACT_KEYWORDS = ("flood", "scaler", "feature", "indo")
INDOFLOODS_STATE_KEYS = {
    "andhra_pradesh",
    "karnataka",
    "kerala",
    "tamil_nadu",
    "telangana",
}

# ============= SOURCE POLICY MODES =============
SOURCE_POLICY_MODES = {"OPEN_DATA", "OFFICIAL_VIEW_ONLY", "FALLBACK"}

# ============= ENVIRONMENT LOADING =============
def refresh_backend_env(override: bool = False):
    """Load environment variables from multiple .env files."""
    load_dotenv(os.path.join(REPO_DIR, ".env"), override=override)
    load_dotenv(os.path.join(REPO_DIR, ".env.local"), override=override)
    load_dotenv(os.path.join(BASE_DIR, ".env"), override=override)
    load_dotenv(os.path.join(BASE_DIR, ".env.local"), override=override)

refresh_backend_env(override=False)

# ============= IMPORTS AFTER ENV SETUP =============
try:
    from backend.data_pipeline import IngestionTarget, OperationalDataPipeline, ScheduledIngestionService
    from backend.state_severity_matrix import (
        STATE_SEVERITY_MATRIX,
        get_state_severity_entry,
        severity_from_entry,
    )
    from backend.postgres_store import PostgresOperationalStore
    from backend.model_metrics import evaluate_and_log_metrics
except ImportError:
    from data_pipeline import IngestionTarget, OperationalDataPipeline, ScheduledIngestionService
    from state_severity_matrix import STATE_SEVERITY_MATRIX, get_state_severity_entry, severity_from_entry
    from postgres_store import PostgresOperationalStore
    from model_metrics import evaluate_and_log_metrics

# ============= GLOBAL INSTANCES =============
operational_store = PostgresOperationalStore()
operational_store.initialize()

# ============= PATH UTILITIES =============
def backend_path(*parts: str) -> str:
    return os.path.join(BASE_DIR, *parts)

def backend_relative_path(path: str) -> str:
    return os.path.relpath(path, BASE_DIR)

def repo_relative_path(path: str) -> str:
    return os.path.relpath(path, REPO_DIR)

# ============= ENVIRONMENT UTILITIES =============
def env_flag(name: str, default: bool = False) -> bool:
    """Parse environment variable as boolean flag."""
    raw = (os.getenv(name) or "").strip().lower()
    if not raw:
        return default
    return raw in {"1", "true", "yes", "on"}

def get_source_policy_mode() -> str:
    """Get source policy mode from environment."""
    refresh_backend_env(override=True)
    configured = (os.getenv("FLOOD_SOURCE_POLICY") or "OFFICIAL_VIEW_ONLY").strip().upper()
    return configured if configured in SOURCE_POLICY_MODES else "OFFICIAL_VIEW_ONLY"

def live_cwc_enabled() -> bool:
    """Whether live CWC telemetry is allowed in-app."""
    return env_flag("ENABLE_LIVE_CWC_IN_APP", default=True)

def get_openweather_api_key() -> str:
    """Get OpenWeather API key from environment."""
    refresh_backend_env(override=True)
    return (
        os.getenv("OPENWEATHER_API_KEY")
        or os.getenv("WEATHER_API_KEY")
        or os.getenv("VITE_WEATHER_API_KEY")
        or ""
    ).strip().strip('"').strip("'")

# ============= MODEL ARTIFACT UTILITIES =============
def get_model_artifact_backend() -> str:
    """Get configured model artifact backend (DVC or FILESYSTEM)."""
    refresh_backend_env(override=True)
    configured = (os.getenv("MODEL_ARTIFACTS_BACKEND") or "DVC").strip().upper()
    return configured if configured in MODEL_ARTIFACT_BACKENDS else "DVC"

def get_model_artifact_root() -> str:
    """Get root directory for model artifacts."""
    refresh_backend_env(override=True)
    configured = (os.getenv("MODEL_ARTIFACTS_DIR") or "").strip()
    if configured:
        resolved = configured if os.path.isabs(configured) else os.path.join(REPO_DIR, configured)
    else:
        resolved = DEFAULT_MODEL_ARTIFACTS_DIR

    root = os.path.abspath(resolved)
    os.makedirs(root, exist_ok=True)
    return root

def resolve_model_artifact_path(path_name: str) -> str:
    """Safely resolve model artifact path."""
    normalized = os.path.normpath((path_name or "").strip()).lstrip(os.sep)
    root = get_model_artifact_root()
    if not normalized or normalized == ".":
        return root

    repo_candidate = os.path.abspath(os.path.join(REPO_DIR, normalized))
    if repo_candidate == root or repo_candidate.startswith(f"{root}{os.sep}"):
        return repo_candidate

    rooted_candidate = os.path.abspath(os.path.join(root, normalized))
    if rooted_candidate == root or rooted_candidate.startswith(f"{root}{os.sep}"):
        return rooted_candidate

    raise ValueError(f"Invalid model artifact path: {path_name}")

def default_model_artifact_paths() -> Tuple[str, str]:
    """Get default model and scaler artifact paths."""
    model_path, scaler_path = [
        repo_relative_path(resolve_model_artifact_path(filename))
        for filename in DEFAULT_MODEL_ARTIFACT_FILES
    ]
    return model_path, scaler_path

# ============= FRONTEND UTILITIES =============
def frontend_dist_ready() -> bool:
    """Check if frontend dist is available."""
    return os.path.isfile(FRONTEND_INDEX_PATH)

def resolve_frontend_asset(path_name: str) -> str | None:
    """Safely resolve frontend asset path."""
    if not frontend_dist_ready():
        return None

    requested_path = (path_name or "").strip().lstrip("/")
    if not requested_path:
        return FRONTEND_INDEX_PATH

    candidate_path = os.path.abspath(os.path.join(FRONTEND_DIST_DIR, requested_path))
    dist_root = os.path.abspath(FRONTEND_DIST_DIR)

    if not candidate_path.startswith(f"{dist_root}{os.sep}"):
        return None
    if os.path.isfile(candidate_path):
        return candidate_path
    return None

# ============= STRING UTILITIES =============
def slugify_name(value: str) -> str:
    """Convert name to slug format."""
    cleaned = "".join(ch if ch.isalnum() else "_" for ch in (value or "").strip().lower())
    return "_".join(part for part in cleaned.split("_") if part)

def normalize_weather_lookup(value: str) -> str:
    """Normalize weather lookup string."""
    return re.sub(r"\s+", " ", re.sub(r"[^a-z0-9\s]", " ", (value or "").lower())).strip()

def normalize_origin_url(value: str) -> str:
    """Normalize origin URL for CORS."""
    trimmed = (value or "").strip().rstrip("/")
    if not trimmed:
        return ""
    if trimmed.startswith(("http://", "https://")):
        return trimmed
    return f"https://{trimmed}"

def title_case_location_label(value: str) -> str:
    """Convert to title case location label."""
    parts = normalize_weather_lookup(value).split()
    return " ".join(part.capitalize() for part in parts) or "Selected Region"

# ============= WEATHER UTILITIES =============
def _weather_hash_unit(seed: str) -> float:
    """Generate deterministic float from seed for weather generation."""
    digest = hashlib.sha256(seed.encode("utf-8")).digest()
    return int.from_bytes(digest[:8], "big") / float((1 << 64) - 1)

def _weather_cache_key(path: str, params: Dict[str, Any]) -> str:
    """Generate cache key for weather response."""
    return json.dumps({"path": path, "params": params}, sort_keys=True, default=str)

def get_cached_weather_response(path: str, params: Dict[str, Any], max_age: int = WEATHER_CACHE_TTL_SECONDS) -> Any | None:
    """Retrieve cached weather response if available and fresh."""
    entry = WEATHER_CACHE.get(_weather_cache_key(path, params))
    if not entry:
        return None

    age_seconds = int((datetime.datetime.utcnow() - entry["timestamp"]).total_seconds())
    if age_seconds > max_age:
        WEATHER_CACHE.pop(_weather_cache_key(path, params), None)
        return None

    cached_payload = copy.deepcopy(entry["data"])
    if isinstance(cached_payload, dict):
        cached_payload.setdefault("_weather_meta", {})
        cached_payload["_weather_meta"].update(
            {
                "source": "CACHE",
                "cache_age_seconds": age_seconds,
            }
        )
    return cached_payload

def store_weather_response(path: str, params: Dict[str, Any], data: Any):
    """Store weather response in cache."""
    WEATHER_CACHE[_weather_cache_key(path, params)] = {
        "timestamp": datetime.datetime.utcnow(),
        "data": copy.deepcopy(data),
    }

# ============= CORS UTILITIES =============
def configured_cors_origins() -> list[str]:
    """Get CORS origins from configuration."""
    defaults = [
        "http://localhost:5173",
        "http://127.0.0.1:5173",
        "http://localhost:4173",
        "http://127.0.0.1:4173",
    ]
    configured = []
    for env_key in ("CORS_ORIGINS", "FRONTEND_ORIGIN", "FRONTEND_URL"):
        raw_value = os.getenv(env_key, "")
        if not raw_value.strip():
            continue
        configured.extend(
            normalize_origin_url(part)
            for part in raw_value.split(",")
            if normalize_origin_url(part)
        )

    deduped: list[str] = []
    for origin in [*defaults, *configured]:
        if origin and origin not in deduped:
            deduped.append(origin)
    return deduped

# ============= TELEMETRY UTILITIES =============
def current_timestamp_iso() -> str:
    """Get current timestamp in ISO format."""
    return datetime.datetime.now(datetime.timezone.utc).isoformat()

def write_audit_log(
    *,
    event_type: str,
    route: str,
    event_status: str,
    state_name: str | None = None,
    station_name: str | None = None,
    severity: str | None = None,
    details: Dict[str, Any] | None = None,
) -> int | None:
    """Write audit log to storage."""
    try:
        return operational_store.save_audit_log(
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
        print(f"⚠️ Audit log persistence failed: {exc}")
        return None

def persist_telemetry_record(state_name: str, station_name: str, limit: int, telemetry: Dict[str, Any], route: str) -> int | None:
    """Persist telemetry snapshot to storage."""
    node_count = len(telemetry.get("data", [])) if isinstance(telemetry.get("data"), list) else 0

    try:
        snapshot_id = operational_store.save_telemetry_snapshot(
            {
                "state_name": state_name,
                "station_name": station_name,
                "request_limit": int(limit),
                "snapshot_status": str(telemetry.get("status") or ""),
                "data_source": str(telemetry.get("data_source") or ""),
                "source_policy_mode": str(((telemetry.get("source_policy") or {}).get("mode")) or ""),
                "node_count": node_count,
                "payload": telemetry,
            }
        )
    except Exception as exc:
        print(f"⚠️ Telemetry snapshot persistence failed: {exc}")
        snapshot_id = None

    write_audit_log(
        event_type="telemetry.snapshot",
        route=route,
        event_status="success" if snapshot_id else "skipped",
        state_name=state_name,
        station_name=station_name,
        details={
            "snapshot_id": snapshot_id,
            "node_count": node_count,
            "telemetry_status": telemetry.get("status"),
            "data_source": telemetry.get("data_source"),
            "storage_ready": operational_store.status().get("ready"),
        },
    )
    return snapshot_id

def model_to_dict(model: Any) -> Dict[str, Any]:
    """Convert Pydantic model to dict."""
    if hasattr(model, "model_dump"):
        return model.model_dump()
    if hasattr(model, "dict"):
        return model.dict()
    return dict(model)

def calculate_rainfall_total(input_payload: Dict[str, Any]) -> float:
    """Calculate total rainfall from daily values."""
    return round(
        sum(float(input_payload.get(key) or 0.0) for key in ("T1d", "T2d", "T3d", "T4d", "T5d", "T6d", "T7d")),
        3,
    )

def get_source_policy_payload() -> Dict[str, Any]:
    """Get source policy configuration."""
    mode = get_source_policy_mode()
    allow_live_cwc = live_cwc_enabled() and mode != "FALLBACK"
    base_sources = [
        {
            "label": "Open Data",
            "title": "data.gov.in Reservoir Levels",
            "url": "https://www.data.gov.in/resource/daily-data-reservoir-level-central-water-commission-cwc",
            "usage": "Safest public reuse path",
        },
        {
            "label": "Official Monitor",
            "title": "CWC Flood Forecast Portal",
            "url": "https://ffs.india-water.gov.in/",
            "usage": "Authoritative public viewing",
        },
        {
            "label": "Advisory",
            "title": "CWC 7-Day Forecast",
            "url": "https://aff.india-water.gov.in/home.php",
            "usage": "Forward-looking official advisories",
        },
    ]

    if mode == "OPEN_DATA":
        return {
            "mode": mode,
            "label": "Open Data",
            "description": "Use open/publicly reusable datasets as the legal default. Live CWC telemetry is enabled for automatic operational monitoring."
            if allow_live_cwc
            else "Use open/publicly reusable datasets as the legal default. Live in-app CWC scraping is disabled.",
            "allow_live_cwc_in_app": allow_live_cwc,
            "telemetry_mode": "LIVE_CWC_CONTEXT" if allow_live_cwc else "OPEN_DATA_CONTEXT",
            "prediction_data_source": "Live CWC + Open Data Context" if allow_live_cwc else "Open Data Context + Manual Input",
            "public_sources": base_sources,
        }

    if mode == "FALLBACK":
        return {
            "mode": mode,
            "label": "Fallback",
            "description": "Operate on tactical registry context and manual thresholds only. No official live ingestion is attempted in-app.",
            "allow_live_cwc_in_app": False,
            "telemetry_mode": "TACTICAL_FALLBACK",
            "prediction_data_source": "Fallback Manual Context",
            "public_sources": base_sources,
        }

    return {
        "mode": "OFFICIAL_VIEW_ONLY",
        "label": "Official View Only",
        "description": "Official CWC telemetry is enabled for fully automatic in-app danger-level detection."
        if allow_live_cwc
        else "Use official CWC portals for public monitoring, but keep in-app telemetry on manual or tactical context unless explicit reuse rights are obtained.",
        "allow_live_cwc_in_app": allow_live_cwc,
        "telemetry_mode": "OFFICIAL_LIVE_IN_APP" if allow_live_cwc else "OFFICIAL_VIEW_ONLY",
        "prediction_data_source": "Live CWC Detection + Manual Input" if allow_live_cwc else "Official View Only + Manual Input",
        "public_sources": base_sources,
    }
