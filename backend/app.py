from fastapi import FastAPI, HTTPException, Request, status
from fastapi.staticfiles import StaticFiles
import asyncio
import copy
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse, JSONResponse, Response
from pydantic import BaseModel
import numpy as np
import joblib
from typing import Dict, Any
import uvicorn
from sklearn.ensemble import RandomForestClassifier
from sklearn.preprocessing import StandardScaler
from sklearn.model_selection import train_test_split
from sklearn.metrics import accuracy_score
import warnings
import os
import re
import hashlib
import json
from dotenv import load_dotenv
from cachetools import TTLCache
import logging  # add near other imports

logger = logging.getLogger("opsflood")


# Resolve data/model paths relative to this backend folder (works regardless of CWD)
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
REPO_DIR = os.path.abspath(os.path.join(BASE_DIR, os.pardir))
FRONTEND_DIST_DIR = os.path.join(REPO_DIR, "frontend", "dist")
FRONTEND_INDEX_PATH = os.path.join(FRONTEND_DIST_DIR, "index.html")
DEFAULT_MODEL_ARTIFACTS_DIR = os.path.join(REPO_DIR, "artifacts", "dvc", "models")
MODEL_ARTIFACT_BACKENDS = {"DVC", "FILESYSTEM"}
DEFAULT_MODEL_ARTIFACT_FILES = ("flood_model.pkl", "flood_scaler.pkl")

def refresh_backend_env(override: bool = False):
    load_dotenv(os.path.join(REPO_DIR, ".env"), override=override)
    load_dotenv(os.path.join(REPO_DIR, ".env.local"), override=override)
    load_dotenv(os.path.join(BASE_DIR, ".env"), override=override)
    load_dotenv(os.path.join(BASE_DIR, ".env.local"), override=override)


refresh_backend_env(override=False)

# --- NEW IMPORTS FOR SCRAPING ---
import requests
from bs4 import BeautifulSoup
import datetime

import importlib.util as _importlib_util


def _is_package_context() -> bool:
    """True when running as `uvicorn backend.app:app` (Render/production)."""
    return _importlib_util.find_spec("backend") is not None


if _is_package_context():
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
    from backend.cwc_scraper import CWCRiverScraper
    from backend.routers.core import router as core_router
    from backend.routers.predict import router as predict_router
    from backend.routers.weather import router as weather_router
    from backend.routers.telemetry import router as telemetry_router
    from backend.routers.ingestion import router as ingestion_router
    from backend.routers.live_levels import router as live_levels_router
    from backend.routers.wrd_bihar import router as wrd_bihar_router
else:
    # When running from within the backend folder: `uvicorn app:app`
    from data_pipeline import IngestionTarget, OperationalDataPipeline, ScheduledIngestionService
    from state_severity_matrix import (
        STATE_SEVERITY_MATRIX,
        get_state_severity_entry,
        severity_from_entry,
        build_effective_state_entry,
        select_best_station_node,
    )
    from postgres_store import PostgresOperationalStore
    from model_metrics import evaluate_and_log_metrics
    from cwc_scraper import CWCRiverScraper
    from routers.core import router as core_router
    from routers.predict import router as predict_router
    from routers.weather import router as weather_router
    from routers.telemetry import router as telemetry_router
    from routers.ingestion import router as ingestion_router
    from routers.live_levels import router as live_levels_router
    from routers.wrd_bihar import router as wrd_bihar_router


warnings.filterwarnings('ignore')
operational_store = PostgresOperationalStore()
operational_store.initialize()

SOURCE_POLICY_MODES = {"OPEN_DATA", "OFFICIAL_VIEW_ONLY", "FALLBACK"}


def get_source_policy_mode() -> str:
    refresh_backend_env(override=True)
    configured = (os.getenv("FLOOD_SOURCE_POLICY") or "OFFICIAL_VIEW_ONLY").strip().upper()
    return configured if configured in SOURCE_POLICY_MODES else "OFFICIAL_VIEW_ONLY"


def live_cwc_enabled() -> bool:
    return env_flag("ENABLE_LIVE_CWC_IN_APP", default=True)


def get_source_policy_payload() -> Dict[str, Any]:
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


def current_timestamp_iso() -> str:
    return datetime.datetime.now(datetime.timezone.utc).isoformat()


def model_to_dict(model: Any) -> Dict[str, Any]:
    if hasattr(model, "model_dump"):
        return model.model_dump()
    if hasattr(model, "dict"):
        return model.dict()
    return dict(model)


def calculate_rainfall_total(input_payload: Dict[str, Any]) -> float:
    return round(
        sum(float(input_payload.get(key) or 0.0) for key in ("T1d", "T2d", "T3d", "T4d", "T5d", "T6d", "T7d")),
        3,
    )


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


def persist_prediction_record(input_data: Any, result: Dict[str, Any]) -> int | None:
    input_payload = model_to_dict(input_data)
    station_name = str(input_payload.get("station") or "").strip() or None
    state_name = str(input_payload.get("state") or "Maharashtra").strip()
    rainfall_total = calculate_rainfall_total(input_payload)

    try:
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


def persist_telemetry_record(state_name: str, station_name: str, limit: int, telemetry: Dict[str, Any], route: str) -> int | None:
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


def build_policy_bound_telemetry(state_name: str = "Maharashtra", station_name: str = "Kolhapur", limit: int = 6) -> Dict[str, Any]:
    policy = get_source_policy_payload()
    if policy.get("allow_live_cwc_in_app"):
        live_payload = cwc_scraper.get_live_telemetry(
            state_name=state_name,
            station_name=station_name,
            limit=limit,
        )
        if isinstance(live_payload, dict):
            live_payload["source_policy"] = policy
            return live_payload

    tactical_fallback = cwc_scraper._build_tactical_telemetry(
        state_name=state_name,
        station_name=station_name,
        limit=limit,
    )

    return {
        "status": "POLICY_LOCKED",
        "message": policy["description"],
        "data_source": "TACTICAL_REGISTRY",
        "source_policy": policy,
        "timestamp": datetime.datetime.now().isoformat(),
        "data": tactical_fallback[:limit],
    }

FLOOD_ARTIFACT_KEYWORDS = ("flood", "scaler", "feature", "indo")
CLASS_LABEL_MAP = {
    0: "LOW",
    1: "MODERATE",
    2: "SEVERE",
    3: "CRITICAL",
    "LOW": "LOW",
    "MODERATE": "MODERATE",
    "SEVERE": "SEVERE",
    "CRITICAL": "CRITICAL",
}
EXPECTED_FEATURE_COLUMNS = [
    "river_level_m",
    "warning_level_m",
    "danger_level_m",
    "flow_rate",
    "rainfall_last_hour_mm",
    "level_to_danger",
    "level_to_warning",
    "danger_ratio",
    "warning_ratio",
    "trend_encoded",
    "status_encoded",
]
_FEATURE_ALIAS_MAP = {
    "peakfloodlevelm": "Peak_Flood_Level_m",
    "peakfloodlevel": "Peak_Flood_Level_m",
    "eventdurationdays": "Event_Duration_days",
    "eventdurationday": "Event_Duration_days",
    "timetopeakdays": "Time_to_Peak_days",
    "timetopeakday": "Time_to_Peak_days",
    "recessiontimeday": "Recession_Time_day",
    "recessiontimedays": "Recession_Time_day",
    "t1d": "T1d",
    "t2d": "T2d",
    "t3d": "T3d",
    "t4d": "T4d",
    "t5d": "T5d",
    "t6d": "T6d",
    "t7d": "T7d",
}
INDOFLOODS_STATE_KEYS = {
    "andhra_pradesh",
    "karnataka",
    "kerala",
    "tamil_nadu",
    "telangana",
}
WEATHER_QUERY_NOISE_PATTERN = re.compile(
    r"\b(sector|region|lowlands?|basin|banks?|bridge|barrage|ghats?|control|command|high[-\s]?ground|coastal|delta|island|catchment|console)\b",
    re.IGNORECASE,
)
WEATHER_LOCATION_HINTS = [
    {
        "name": "Kolhapur",
        "state": "Maharashtra",
        "lat": 16.705,
        "lon": 74.2433,
        "aliases": [
            "kolhapur",
            "maharashtra",
            "shirol",
            "shirol sector",
            "irwin bridge",
            "kagal",
            "kagal high ground",
            "kurundwad",
            "rajaram barrage",
            "panchganga",
        ],
    },
    {
        "name": "Patna",
        "state": "Bihar",
        "lat": 25.5941,
        "lon": 85.1376,
        "aliases": [
            "patna",
            "bihar",
            "patna lowlands",
            "darbhanga",
            "darbhanga sector",
            "koshi barrage",
            "dumariaghat",
            "basantpur",
        ],
    },
    {
        "name": "Kochi",
        "state": "Kerala",
        "lat": 9.9312,
        "lon": 76.2673,
        "aliases": [
            "kochi",
            "kerala",
            "kuttanad",
            "kuttanad region",
            "vembanad",
            "vembanad lowlands",
            "periyar",
            "periyar banks",
            "aranmula",
        ],
    },
    {
        "name": "Guwahati",
        "state": "Assam",
        "lat": 26.1445,
        "lon": 91.7362,
        "aliases": [
            "guwahati",
            "assam",
            "majuli island",
            "kaziranga sector",
            "brahmaputra banks",
        ],
    },
    {
        "name": "Dehradun",
        "state": "Uttarakhand",
        "lat": 30.3165,
        "lon": 78.0322,
        "aliases": [
            "dehradun",
            "uttarakhand",
            "joshimath sector",
            "rishikesh ghats",
            "mandakini basin",
        ],
    },
    {
        "name": "Surat",
        "state": "Gujarat",
        "lat": 21.1702,
        "lon": 72.8311,
        "aliases": [
            "surat",
            "gujarat",
            "surat lowlands",
            "ukai dam sector",
            "tapi river banks",
            "ukai",
            "tapi",
        ],
    },
    {
        "name": "Bhubaneswar",
        "state": "Odisha",
        "lat": 20.2961,
        "lon": 85.8245,
        "aliases": [
            "bhubaneswar",
            "odisha",
            "orissa",
            "mahanadi delta",
            "cuttack sector",
            "cuttack",
            "puri coastal",
            "puri",
        ],
    },
    {
        "name": "Kolkata",
        "state": "West Bengal",
        "lat": 22.5726,
        "lon": 88.3639,
        "aliases": [
            "kolkata",
            "west bengal",
            "sundarbans delta",
            "hooghly banks",
            "siliguri sector",
            "hooghly",
            "sundarbans",
            "siliguri",
        ],
    },
    {
        "name": "Lucknow",
        "state": "Uttar Pradesh",
        "lat": 26.8467,
        "lon": 80.9462,
        "aliases": [
            "lucknow",
            "uttar pradesh",
            "varanasi ghats",
            "prayagraj lowlands",
            "ghaghara basin",
            "varanasi",
            "prayagraj",
            "ghaghara",
        ],
    },
    {
        "name": "Chandigarh",
        "state": "Punjab",
        "lat": 30.7333,
        "lon": 76.7794,
        "aliases": [
            "punjab",
            "sutlej banks",
            "ludhiana sector",
            "ludhiana",
            "ravi basin",
            "ravi",
            "sutlej",
        ],
    },
    {
        "name": "Chennai",
        "state": "Tamil Nadu",
        "lat": 13.0827,
        "lon": 80.2707,
        "aliases": [
            "chennai",
            "tamil nadu",
            "chennai lowlands",
            "kaveri delta",
            "madurai sector",
            "kaveri",
            "madurai",
        ],
    },
]
WEATHER_CACHE_TTL_SECONDS = 20 * 60
WEATHER_CACHE_MAX_SIZE = 1000  # Limit to 1000 cached entries
WEATHER_TIMEZONE_OFFSET = 19800
WEATHER_TIMEZONE_NAME = "Asia/Kolkata"
WEATHER_CACHE: TTLCache = TTLCache(maxsize=WEATHER_CACHE_MAX_SIZE, ttl=WEATHER_CACHE_TTL_SECONDS)


def canonical_feature_name(value: Any) -> str:
    raw_value = str(value or "").strip().lower()
    compact = re.sub(r"[^a-z0-9]", "", raw_value)
    return _FEATURE_ALIAS_MAP.get(compact, "")


def canonical_feature_set(values: list[Any]) -> set[str]:
    return {feature for feature in (canonical_feature_name(item) for item in values) if feature}


def backend_path(*parts: str) -> str:
    return os.path.join(BASE_DIR, *parts)


def backend_relative_path(path: str) -> str:
    return os.path.relpath(path, BASE_DIR)


def repo_relative_path(path: str) -> str:
    return os.path.relpath(path, REPO_DIR)


def get_model_artifact_backend() -> str:
    refresh_backend_env(override=True)
    configured = (os.getenv("MODEL_ARTIFACTS_BACKEND") or "DVC").strip().upper()
    return configured if configured in MODEL_ARTIFACT_BACKENDS else "DVC"


def get_model_artifact_root() -> str:
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


def default_model_artifact_paths() -> tuple[str, str]:
    model_path, scaler_path = [
        repo_relative_path(resolve_model_artifact_path(filename))
        for filename in DEFAULT_MODEL_ARTIFACT_FILES
    ]
    return model_path, scaler_path


def frontend_dist_ready() -> bool:
    return os.path.isfile(FRONTEND_INDEX_PATH)


def resolve_frontend_asset(path_name: str) -> str | None:
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


def slugify_name(value: str) -> str:
    cleaned = "".join(ch if ch.isalnum() else "_" for ch in (value or "").strip().lower())
    return "_".join(part for part in cleaned.split("_") if part)


def normalize_weather_lookup(value: str) -> str:
    return re.sub(r"\s+", " ", re.sub(r"[^a-z0-9\s]", " ", (value or "").lower())).strip()


def normalize_origin_url(value: str) -> str:
    trimmed = (value or "").strip().rstrip("/")
    if not trimmed:
        return ""
    if trimmed.startswith(("http://", "https://")):
        return trimmed
    return f"https://{trimmed}"


def configured_cors_origins() -> list[str]:
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


def _weather_hash_unit(seed: str) -> float:
    digest = hashlib.sha256(seed.encode("utf-8")).digest()
    return int.from_bytes(digest[:8], "big") / float((1 << 64) - 1)


def _weather_cache_key(path: str, params: Dict[str, Any]) -> str:
    return json.dumps({"path": path, "params": params}, sort_keys=True, default=str)


def get_cached_weather_response(path: str, params: Dict[str, Any], max_age: int = WEATHER_CACHE_TTL_SECONDS) -> Any | None:
    cache_key = _weather_cache_key(path, params)
    if cache_key not in WEATHER_CACHE:
        return None

    entry = WEATHER_CACHE.get(cache_key)
    if not entry:
        return None

    cached_payload = copy.deepcopy(entry["data"])
    age_seconds = int((datetime.datetime.utcnow() - entry["timestamp"]).total_seconds())
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
    WEATHER_CACHE[_weather_cache_key(path, params)] = {
        "timestamp": datetime.datetime.utcnow(),
        "data": copy.deepcopy(data),
    }


def resilient_openweather(
    path: str,
    params: Dict[str, Any],
    fallback_factory=None,
    cache_ttl: int = WEATHER_CACHE_TTL_SECONDS,
):
    try:
        return proxy_openweather(path, params)
    except HTTPException as exc:
        cached_payload = get_cached_weather_response(path, params, max_age=cache_ttl)
        if cached_payload is not None:
            return cached_payload
        if fallback_factory is not None:
            return fallback_factory(exc)
        raise


def title_case_location_label(value: str) -> str:
    parts = normalize_weather_lookup(value).split()
    return " ".join(part.capitalize() for part in parts) or "Selected Region"


def synthetic_coords_from_query(query: str) -> tuple[float, float]:
    normalized_query = normalize_weather_lookup(query) or "india"
    lat = 8.0 + _weather_hash_unit(f"{normalized_query}|lat") * 28.0
    lon = 68.0 + _weather_hash_unit(f"{normalized_query}|lon") * 29.0
    return round(lat, 4), round(lon, 4)


def nearest_weather_hint(lat: float, lon: float) -> Dict[str, Any]:
    return min(
        WEATHER_LOCATION_HINTS,
        key=lambda entry: (float(entry["lat"]) - lat) ** 2 + (float(entry["lon"]) - lon) ** 2,
    )


def build_local_weather_location(
    query: str | None = None,
    lat: float | None = None,
    lon: float | None = None,
) -> Dict[str, Any]:
    if lat is not None and lon is not None:
        nearest_hint = nearest_weather_hint(lat, lon)
        return {
            "name": nearest_hint["name"],
            "state": nearest_hint["state"],
            "country": "IN",
            "lat": round(float(lat), 4),
            "lon": round(float(lon), 4),
        }

    cleaned_query = (query or "").strip()
    if cleaned_query:
        hinted_location = get_weather_location_hint(cleaned_query)
        if hinted_location:
            return {
                "name": hinted_location["name"],
                "state": hinted_location["state"],
                "country": "IN",
                "lat": round(float(hinted_location["lat"]), 4),
                "lon": round(float(hinted_location["lon"]), 4),
            }

        fallback_label = next(iter(build_weather_lookup_candidates(cleaned_query)), cleaned_query)
        pseudo_lat, pseudo_lon = synthetic_coords_from_query(fallback_label)
        return {
            "name": title_case_location_label(fallback_label),
            "state": None,
            "country": "IN",
            "lat": pseudo_lat,
            "lon": pseudo_lon,
        }

    default_hint = WEATHER_LOCATION_HINTS[0]
    return {
        "name": default_hint["name"],
        "state": default_hint["state"],
        "country": "IN",
        "lat": round(float(default_hint["lat"]), 4),
        "lon": round(float(default_hint["lon"]), 4),
    }


def build_weather_descriptor(
    rainfall_mm: float,
    cloud_cover: int,
    humidity: int,
    is_daytime: bool,
) -> Dict[str, str]:
    if rainfall_mm >= 6:
        return {"main": "Rain", "description": "steady monsoon rain", "icon": "10d" if is_daytime else "10n"}
    if rainfall_mm >= 1.5:
        return {"main": "Drizzle", "description": "light rain bands", "icon": "09d" if is_daytime else "09n"}
    if humidity >= 88 and cloud_cover >= 68:
        return {"main": "Mist", "description": "humid mist", "icon": "50d" if is_daytime else "50n"}
    if cloud_cover >= 55:
        return {"main": "Clouds", "description": "broken clouds", "icon": "03d" if is_daytime else "03n"}
    return {"main": "Clear", "description": "clear sky", "icon": "01d" if is_daytime else "01n"}


def build_fallback_current_weather(
    city: str | None = None,
    lat: float | None = None,
    lon: float | None = None,
    reason: str = "LOCAL_FALLBACK",
) -> Dict[str, Any]:
    location = build_local_weather_location(query=city, lat=lat, lon=lon)
    local_now = datetime.datetime.now(datetime.timezone(datetime.timedelta(seconds=WEATHER_TIMEZONE_OFFSET)))
    seed_base = f"{location['name']}|{location['lat']}|{location['lon']}|{local_now.date().isoformat()}"
    cloud_cover = int(18 + _weather_hash_unit(f"{seed_base}|clouds") * 75)
    humidity = int(54 + _weather_hash_unit(f"{seed_base}|humidity") * 42)
    rainfall_mm = round(max(0.0, (cloud_cover - 58) / 14 + _weather_hash_unit(f"{seed_base}|rain") * 3.4 - 1.2), 1)
    temperature = round(21 + _weather_hash_unit(f"{seed_base}|temp") * 15 - abs(float(location["lat"]) - 20) * 0.06, 1)
    feels_like = round(temperature + humidity / 100 * 2.8 + rainfall_mm * 0.15, 1)
    pressure = int(1002 + _weather_hash_unit(f"{seed_base}|pressure") * 16)
    wind_speed = round(3 + _weather_hash_unit(f"{seed_base}|wind_speed") * 16, 1)
    wind_direction = int(_weather_hash_unit(f"{seed_base}|wind_deg") * 360)
    visibility = int(max(3200, 10000 - cloud_cover * 48 - rainfall_mm * 420))
    sunrise = int(local_now.replace(hour=6, minute=7, second=0, microsecond=0).timestamp())
    sunset = int(local_now.replace(hour=18, minute=36, second=0, microsecond=0).timestamp())
    is_daytime = sunrise <= int(local_now.timestamp()) <= sunset
    descriptor = build_weather_descriptor(rainfall_mm, cloud_cover, humidity, is_daytime)

    payload: Dict[str, Any] = {
        "coord": {"lon": location["lon"], "lat": location["lat"]},
        "weather": [
            {
                "id": 800 if descriptor["main"] == "Clear" else 801 if descriptor["main"] == "Clouds" else 701 if descriptor["main"] == "Mist" else 500,
                "main": descriptor["main"],
                "description": descriptor["description"],
                "icon": descriptor["icon"],
            }
        ],
        "base": "fallback",
        "main": {
            "temp": temperature,
            "feels_like": feels_like,
            "temp_min": round(temperature - 1.8, 1),
            "temp_max": round(temperature + 2.4, 1),
            "pressure": pressure,
            "humidity": humidity,
        },
        "visibility": visibility,
        "wind": {"speed": wind_speed, "deg": wind_direction},
        "clouds": {"all": cloud_cover},
        "dt": int(local_now.timestamp()),
        "sys": {
            "country": location["country"],
            "sunrise": sunrise,
            "sunset": sunset,
        },
        "timezone": WEATHER_TIMEZONE_OFFSET,
        "id": int(_weather_hash_unit(f"{seed_base}|id") * 100000),
        "name": location["name"],
        "cod": 200,
        "_weather_meta": {
            "source": "LOCAL_FALLBACK",
            "reason": reason,
            "state": location.get("state"),
        },
    }

    if rainfall_mm > 0:
        payload["rain"] = {
            "1h": rainfall_mm,
            "3h": round(rainfall_mm * (1.7 + _weather_hash_unit(f"{seed_base}|rain_3h") * 0.6), 1),
        }

    return payload


def build_fallback_forecast(city: str | None = None, lat: float | None = None, lon: float | None = None) -> Dict[str, Any]:
    location = build_local_weather_location(query=city, lat=lat, lon=lon)
    base_weather = build_fallback_current_weather(city=location["name"], lat=location["lat"], lon=location["lon"])
    local_now = datetime.datetime.now(datetime.timezone(datetime.timedelta(seconds=WEATHER_TIMEZONE_OFFSET)))
    forecast_rows = []

    for day_index in range(5):
        day_seed = f"{location['name']}|forecast|{local_now.date().isoformat()}|{day_index}"
        midday = (local_now + datetime.timedelta(days=day_index)).replace(hour=12, minute=0, second=0, microsecond=0)
        temp_base = float(base_weather["main"]["temp"]) + (day_index - 1.5) * 0.5 + (_weather_hash_unit(f"{day_seed}|temp") - 0.5) * 3.2
        temp_min = round(temp_base - (1.4 + _weather_hash_unit(f"{day_seed}|temp_min") * 1.8), 1)
        temp_max = round(temp_base + (1.8 + _weather_hash_unit(f"{day_seed}|temp_max") * 2.2), 1)
        humidity = int(52 + _weather_hash_unit(f"{day_seed}|humidity") * 40)
        cloud_cover = int(20 + _weather_hash_unit(f"{day_seed}|clouds") * 70)
        rainfall_mm = round(max(0.0, (cloud_cover - 55) / 12 + _weather_hash_unit(f"{day_seed}|rain") * 4.2 - 1.5), 1)
        descriptor = build_weather_descriptor(rainfall_mm, cloud_cover, humidity, True)

        forecast_rows.append(
            {
                "dt": int(midday.timestamp()),
                "main": {
                    "temp_min": temp_min,
                    "temp_max": temp_max,
                    "humidity": humidity,
                    "pressure": int(1001 + _weather_hash_unit(f"{day_seed}|pressure") * 18),
                },
                "weather": [
                    {
                        "main": descriptor["main"],
                        "description": descriptor["description"],
                        "icon": descriptor["icon"],
                    }
                ],
                "wind": {"speed": round(3 + _weather_hash_unit(f"{day_seed}|wind") * 14, 1)},
                "pop": min(1.0, round(rainfall_mm / 12, 2)),
                "rain": {"3h": rainfall_mm},
            }
        )

    return {
        "cod": "200",
        "list": forecast_rows,
        "city": {
            "name": location["name"],
            "country": location["country"],
            "timezone": WEATHER_TIMEZONE_OFFSET,
            "coord": {"lat": location["lat"], "lon": location["lon"]},
        },
        "_weather_meta": {
            "source": "LOCAL_FALLBACK",
            "state": location.get("state"),
        },
    }


def build_fallback_air_quality(lat: float, lon: float) -> Dict[str, Any]:
    seed_base = f"{round(lat, 3)}|{round(lon, 3)}|air"
    aqi = min(5, max(1, int(1 + _weather_hash_unit(f"{seed_base}|aqi") * 3.4)))
    pm25 = round(18 + _weather_hash_unit(f"{seed_base}|pm25") * 46, 1)
    pm10 = round(pm25 + 12 + _weather_hash_unit(f"{seed_base}|pm10") * 35, 1)
    return {
        "coord": {"lat": lat, "lon": lon},
        "list": [
            {
                "main": {"aqi": aqi},
                "components": {
                    "pm2_5": pm25,
                    "pm10": pm10,
                    "no2": round(9 + _weather_hash_unit(f"{seed_base}|no2") * 28, 1),
                    "so2": round(4 + _weather_hash_unit(f"{seed_base}|so2") * 14, 1),
                    "o3": round(24 + _weather_hash_unit(f"{seed_base}|o3") * 52, 1),
                    "co": round(180 + _weather_hash_unit(f"{seed_base}|co") * 420, 1),
                },
                "dt": int(datetime.datetime.utcnow().timestamp()),
            }
        ],
        "_weather_meta": {"source": "LOCAL_FALLBACK"},
    }


def build_fallback_uv_index(lat: float, lon: float) -> float:
    base = 4.2 + _weather_hash_unit(f"{round(lat, 3)}|{round(lon, 3)}|uv") * 5.4
    return round(min(11.0, max(0.8, base)), 1)


def build_fallback_historical_weather(lat: float, lon: float, timestamp: int) -> Dict[str, Any]:
    local_weather = build_fallback_current_weather(lat=lat, lon=lon, reason="LOCAL_HISTORY")
    return {
        "lat": lat,
        "lon": lon,
        "timezone": WEATHER_TIMEZONE_NAME,
        "timezone_offset": WEATHER_TIMEZONE_OFFSET,
        "data": [
            {
                "dt": timestamp,
                "sunrise": local_weather["sys"]["sunrise"],
                "sunset": local_weather["sys"]["sunset"],
                "temp": local_weather["main"]["temp"],
                "feels_like": local_weather["main"]["feels_like"],
                "pressure": local_weather["main"]["pressure"],
                "humidity": local_weather["main"]["humidity"],
                "dew_point": round(local_weather["main"]["temp"] - 3.2, 1),
                "clouds": local_weather["clouds"]["all"],
                "visibility": local_weather["visibility"],
                "wind_speed": local_weather["wind"]["speed"],
                "wind_deg": local_weather["wind"]["deg"],
                "weather": local_weather["weather"],
                "rain": local_weather.get("rain", {}),
            }
        ],
        "_weather_meta": {"source": "LOCAL_FALLBACK"},
    }


def build_fallback_search_results(query: str, limit: int = 5) -> list[Dict[str, Any]]:
    results: list[Dict[str, Any]] = []
    seen: set[tuple[str, float, float]] = set()

    for candidate in build_weather_lookup_candidates(query):
        location = build_local_weather_location(query=candidate)
        identity = (location["name"], location["lat"], location["lon"])
        if identity in seen:
            continue
        seen.add(identity)
        results.append(
            {
                "name": location["name"],
                "lat": location["lat"],
                "lon": location["lon"],
                "country": location["country"],
                "state": location.get("state"),
                "_weather_meta": {"source": "LOCAL_FALLBACK"},
            }
        )
        if len(results) >= limit:
            break

    if not results:
        location = build_local_weather_location(query=query)
        results.append(
            {
                "name": location["name"],
                "lat": location["lat"],
                "lon": location["lon"],
                "country": location["country"],
                "state": location.get("state"),
                "_weather_meta": {"source": "LOCAL_FALLBACK"},
            }
        )

    return results[:limit]


def build_fallback_reverse_geocode(lat: float, lon: float, limit: int = 1) -> list[Dict[str, Any]]:
    location = build_local_weather_location(lat=lat, lon=lon)
    return [
        {
            "name": location["name"],
            "lat": round(float(lat), 4),
            "lon": round(float(lon), 4),
            "country": location["country"],
            "state": location.get("state"),
            "_weather_meta": {"source": "LOCAL_FALLBACK"},
        }
    ][:limit]


def get_weather_location_hint(query: str) -> Dict[str, Any] | None:
    normalized_query = normalize_weather_lookup(query)
    if not normalized_query:
        return None

    for entry in WEATHER_LOCATION_HINTS:
        for alias in entry["aliases"]:
            normalized_alias = normalize_weather_lookup(alias)
            if (
                normalized_query == normalized_alias
                or normalized_query in normalized_alias
                or normalized_alias in normalized_query
            ):
                return {
                    "name": entry["name"],
                    "state": entry["state"],
                    "lat": entry["lat"],
                    "lon": entry["lon"],
                }

    return None


def build_weather_lookup_candidates(query: str) -> list[str]:
    trimmed = (query or "").strip()
    if not trimmed:
        return []

    candidates: list[str] = []
    seen: set[str] = set()

    def add_candidate(value: str):
        next_value = value.strip()
        next_key = normalize_weather_lookup(next_value)
        if next_value and next_key and next_key not in seen:
            seen.add(next_key)
            candidates.append(next_value)

    add_candidate(trimmed)
    for part in trimmed.split(","):
        add_candidate(part)

    stripped = WEATHER_QUERY_NOISE_PATTERN.sub(" ", trimmed)
    stripped = re.sub(r"\s+", " ", stripped).strip(" ,")
    if stripped and stripped != trimmed:
        add_candidate(stripped)
        for part in stripped.split(","):
            add_candidate(part)

    hint = get_weather_location_hint(trimmed)
    if hint:
        add_candidate(hint["name"])
        add_candidate(f'{hint["name"]}, {hint["state"]}')

    return candidates[:8]


def classify_backend_artifact(filename: str) -> str:
    lower_name = filename.lower()
    if "model" in lower_name:
        return "model"
    if "scaler" in lower_name:
        return "scaler"
    if "feature" in lower_name:
        return "features"
    return "artifact"


def read_model_artifact_preview(path: str) -> Any | None:
    lower_name = os.path.basename(path).lower()

    try:
        if lower_name.endswith(".txt"):
            with open(path, "r", encoding="utf-8") as handle:
                return [line.strip() for line in handle if line.strip()]

        if "feature" in lower_name and lower_name.endswith(".pkl"):
            loaded = joblib.load(path)
            if isinstance(loaded, dict):
                return list(loaded.keys())
            if isinstance(loaded, (list, tuple)):
                return list(loaded)
            return type(loaded).__name__
    except Exception as exc:
        return {"error": str(exc)}

    return None


def discover_model_artifacts() -> list[Dict[str, Any]]:
    artifacts: list[Dict[str, Any]] = []
    artifact_root = get_model_artifact_root()

    if not os.path.isdir(artifact_root):
        return artifacts

    for current_root, _dirs, filenames in os.walk(artifact_root):
        for filename in sorted(filenames):
            full_path = os.path.join(current_root, filename)
            lower_name = filename.lower()

            if not any(keyword in lower_name for keyword in FLOOD_ARTIFACT_KEYWORDS):
                continue

            artifact: Dict[str, Any] = {
                "name": filename,
                "relative_path": repo_relative_path(full_path),
                "storage_relative_path": os.path.relpath(full_path, artifact_root),
                "kind": classify_backend_artifact(filename),
                "size_bytes": os.path.getsize(full_path),
            }

            preview = read_model_artifact_preview(full_path)
            if preview is not None:
                artifact["preview"] = preview

            artifacts.append(artifact)

    return sorted(artifacts, key=lambda artifact: artifact["relative_path"])


def discover_legacy_artifacts_outside_store() -> list[str]:
    artifact_root = os.path.abspath(get_model_artifact_root())
    repo_artifacts_root = os.path.abspath(os.path.join(REPO_DIR, "artifacts"))
    if not os.path.isdir(repo_artifacts_root):
        return []

    ignored: list[str] = []
    for current_root, _dirs, filenames in os.walk(repo_artifacts_root):
        current_root_abs = os.path.abspath(current_root)
        if current_root_abs == artifact_root or current_root_abs.startswith(f"{artifact_root}{os.sep}"):
            continue

        for filename in sorted(filenames):
            lower_name = filename.lower()
            if not any(keyword in lower_name for keyword in FLOOD_ARTIFACT_KEYWORDS):
                continue
            ignored.append(repo_relative_path(os.path.join(current_root_abs, filename)))

    return sorted(ignored)


def artifact_bundle_key(filename: str) -> str:
    stem, _ = os.path.splitext(filename.lower())

    if stem.endswith("_production_model"):
        return stem.removesuffix("_production_model")

    for suffix in ("_model", "_scaler", "_features"):
        if stem.endswith(suffix):
            return stem.removesuffix(suffix)

    return stem


def discover_model_bundles(artifacts: list[Dict[str, Any]]) -> Dict[str, Dict[str, Any]]:
    bundles: Dict[str, Dict[str, Any]] = {}

    for artifact in artifacts:
        bundle_key = artifact_bundle_key(artifact["name"])
        bundle = bundles.setdefault(
            bundle_key,
            {
                "bundle_key": bundle_key,
                "model": None,
                "scaler": None,
                "features": [],
                "artifacts": [],
            },
        )

        bundle["artifacts"].append(artifact["relative_path"])

        if artifact["kind"] == "model":
            bundle["model"] = artifact["relative_path"]
        elif artifact["kind"] == "scaler":
            bundle["scaler"] = artifact["relative_path"]
        elif artifact["kind"] == "features":
            bundle["features"].append(artifact["relative_path"])

    for bundle in bundles.values():
        bundle["artifacts"].sort()
        bundle["features"].sort()
        bundle["is_complete"] = bool(bundle["model"] and bundle["scaler"])

    return dict(sorted(bundles.items()))

# ============= 1. PYDANTIC SCHEMA =============
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


# ============= 2. FASTAPI SETUP =============
app = FastAPI(title="🌧️ INDIA_FLOODS ML API", version="8.5")

origins = configured_cors_origins()

app.add_middleware(
    CORSMiddleware,
    allow_origins=origins,
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    print(f"CRITICAL ERROR: {exc}")
    return JSONResponse(
        status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
        content={"message": "Internal Server Error", "detail": str(exc)}
    )


# ============= REGISTER ROUTERS =============
app.include_router(core_router)
app.include_router(predict_router)
app.include_router(weather_router)
app.include_router(telemetry_router)
app.include_router(ingestion_router)
app.include_router(live_levels_router)
app.include_router(wrd_bihar_router)  # WRD Bihar live station data


# ============= 3. DATA ACQUISITION (CWC SCRAPER) =============
cwc_scraper = CWCRiverScraper()


def get_openweather_api_key() -> str:
    refresh_backend_env(override=True)
    return (
        os.getenv("OPENWEATHER_API_KEY")
        or os.getenv("WEATHER_API_KEY")
        or os.getenv("VITE_WEATHER_API_KEY")
        or ""
    ).strip().strip('"').strip("'")


def request_openweather(path: str, params: Dict[str, Any], base_url: str = "https://api.openweathermap.org") -> requests.Response:
    api_key = get_openweather_api_key()
    if not api_key:
        raise HTTPException(status_code=503, detail="Missing server weather API key")

    merged_params = dict(params)
    merged_params["appid"] = api_key

    try:
        return requests.get(f"{base_url}{path}", params=merged_params, timeout=10)
    except requests.RequestException as exc:
        raise HTTPException(status_code=502, detail=f"Weather upstream request failed: {exc}") from exc


def proxy_openweather(path: str, params: Dict[str, Any], base_url: str = "https://api.openweathermap.org"):
    response = request_openweather(path, params, base_url=base_url)
    if not response.ok:
        detail = response.text[:200] if response.text else "Unknown weather service error"
        raise HTTPException(status_code=response.status_code, detail=detail)

    data = response.json()
    store_weather_response(path, params, data)
    return data


def resolve_weather_location(query: str) -> Dict[str, Any] | None:
    hint = get_weather_location_hint(query)
    if hint:
        return {
            "name": hint["name"],
            "state": hint["state"],
            "country": "IN",
            "lat": hint["lat"],
            "lon": hint["lon"],
        }

    for candidate in build_weather_lookup_candidates(query):
        try:
            results = proxy_openweather(
                "/geo/1.0/direct",
                {"q": candidate, "limit": 1},
            )
        except HTTPException:
            results = get_cached_weather_response("/geo/1.0/direct", {"q": candidate, "limit": 1}) or []

        if results:
            return results[0]

    return build_local_weather_location(query=query)


def env_flag(name: str, default: bool = False) -> bool:
    raw = (os.getenv(name) or "").strip().lower()
    if not raw:
        return default
    return raw in {"1", "true", "yes", "on"}


def get_data_ingestion_targets() -> list[IngestionTarget]:
    refresh_backend_env(override=True)
    configured = (os.getenv("DATA_INGESTION_TARGETS") or "").strip()
    configured_targets: list[IngestionTarget] = []

    if configured:
        for item in configured.split(";"):
            parts = [part.strip() for part in item.split("|")]
            if len(parts) < 2:
                continue

            state_name = parts[0]
            station_name = parts[1]
            weather_query = parts[2] if len(parts) > 2 and parts[2] else f"{station_name}, {state_name}"

            try:
                lat = float(parts[3]) if len(parts) > 3 and parts[3] else None
            except ValueError:
                lat = None

            try:
                lon = float(parts[4]) if len(parts) > 4 and parts[4] else None
            except ValueError:
                lon = None

            configured_targets.append(
                IngestionTarget(
                    state_name=state_name,
                    station_name=station_name,
                    weather_query=weather_query,
                    lat=lat,
                    lon=lon,
                )
            )

    if configured_targets:
        return configured_targets

    return [
        IngestionTarget(state_name="Maharashtra", station_name="Kolhapur", weather_query="Kolhapur, Maharashtra", lat=16.705, lon=74.2433),
        IngestionTarget(state_name="Bihar", station_name="Patna", weather_query="Patna, Bihar", lat=25.5941, lon=85.1376),
        IngestionTarget(state_name="Kerala", station_name="Kochi", weather_query="Kochi, Kerala", lat=9.9312, lon=76.2673),
        IngestionTarget(state_name="Assam", station_name="Guwahati", weather_query="Guwahati, Assam", lat=26.1445, lon=91.7362),
        IngestionTarget(state_name="Uttarakhand", station_name="Dehradun", weather_query="Dehradun, Uttarakhand", lat=30.3165, lon=78.0322),
    ]


def build_weather_ingestion_snapshot(
    target: IngestionTarget,
    limit: int = 1,
) -> Dict[str, Any]:
    city = target.weather_query or f"{target.station_name}, {target.state_name}"
    lat = target.lat
    lon = target.lon

    def _fallback(_exc=None):
        return build_fallback_current_weather(city=city, lat=lat, lon=lon, reason="INGESTION_FALLBACK")

    try:
        if lat is not None and lon is not None:
            params = {"lat": lat, "lon": lon, "units": "metric"}
        else:
            params = {"q": city, "units": "metric"}

        return resilient_openweather("/data/2.5/weather", params, fallback_factory=_fallback)
    except Exception:
        return _fallback()


def build_water_level_ingestion_snapshot(
    target: IngestionTarget,
    limit: int = 6,
) -> Dict[str, Any]:
    telemetry = build_policy_bound_telemetry(
        state_name=target.state_name,
        station_name=target.station_name,
        limit=limit,
    )
    return {
        "state_name": target.state_name,
        "station_name": target.station_name,
        "water_node_limit": limit,
        "telemetry": telemetry,
    }


data_pipeline = OperationalDataPipeline(
    repo_dir=REPO_DIR,
    weather_fetcher=build_weather_ingestion_snapshot,
    water_level_fetcher=build_water_level_ingestion_snapshot,
    audit_logger=write_audit_log,
    targets=get_data_ingestion_targets(),
)
data_ingestion_scheduler = ScheduledIngestionService(
    pipeline=data_pipeline,
    interval_seconds=max(60, int(float(os.getenv("DATA_INGESTION_INTERVAL_MINUTES") or 60) * 60)),
    enabled=env_flag("ENABLE_DATA_INGESTION_SCHEDULER", default=False),
    run_on_startup=env_flag("DATA_INGESTION_RUN_ON_STARTUP", default=True),
)


@app.on_event("startup")
async def startup_ingestion_scheduler():
    data_pipeline.update_targets(get_data_ingestion_targets())
    data_ingestion_scheduler.start()


@app.on_event("shutdown")
async def shutdown_ingestion_scheduler():
    data_ingestion_scheduler.stop()


@app.get("/weather/status")
async def get_weather_status():
    has_key = bool(get_openweather_api_key())
    return {
        "status": "SECURE" if has_key else "DEGRADED",
        "mode": "SECURE_PROXY" if has_key else "RESILIENT_FALLBACK",
        "provider": "OpenWeatherMap" if has_key else "Local Fallback Weather Engine",
        "backend_proxy": True,
        "key_configured": has_key,
        "fallback_enabled": True,
        "cache_ttl_minutes": WEATHER_CACHE_TTL_SECONDS // 60,
    }


@app.get("/weather/current")
async def get_current_weather(city: str = "Kolhapur", lat: float | None = None, lon: float | None = None):
    def _fallback(_exc=None):
        return build_fallback_current_weather(city=city, lat=lat, lon=lon, reason="API_UNAVAILABLE")

    cached = get_cached_weather_response("/data/2.5/weather", {"city": city, "lat": lat, "lon": lon})
    if cached:
        return cached

    try:
        if lat is not None and lon is not None:
            params = {"lat": lat, "lon": lon, "units": "metric"}
        else:
            location = resolve_weather_location(city)
            if location and location.get("lat") and location.get("lon"):
                params = {"lat": location["lat"], "lon": location["lon"], "units": "metric"}
            else:
                params = {"q": city, "units": "metric"}

        result = resilient_openweather("/data/2.5/weather", params, fallback_factory=_fallback)
        store_weather_response("/data/2.5/weather", {"city": city, "lat": lat, "lon": lon}, result)
        return result
    except HTTPException:
        return _fallback()


@app.get("/weather/forecast")
async def get_weather_forecast(city: str = "Kolhapur", lat: float | None = None, lon: float | None = None, days: int = 5):
    def _fallback(_exc=None):
        return build_fallback_forecast(city=city, lat=lat, lon=lon)

    try:
        if lat is not None and lon is not None:
            params = {"lat": lat, "lon": lon, "units": "metric", "cnt": days * 8}
        else:
            location = resolve_weather_location(city)
            if location and location.get("lat") and location.get("lon"):
                params = {"lat": location["lat"], "lon": location["lon"], "units": "metric", "cnt": days * 8}
            else:
                params = {"q": city, "units": "metric", "cnt": days * 8}

        return resilient_openweather("/data/2.5/forecast", params, fallback_factory=_fallback)
    except HTTPException:
        return _fallback()


@app.get("/weather/air-quality")
async def get_air_quality(lat: float = 16.705, lon: float = 74.2433):
    def _fallback(_exc=None):
        return build_fallback_air_quality(lat, lon)

    try:
        return resilient_openweather("/data/2.5/air_pollution", {"lat": lat, "lon": lon}, fallback_factory=_fallback)
    except HTTPException:
        return _fallback()


@app.get("/weather/uv-index")
async def get_uv_index(lat: float = 16.705, lon: float = 74.2433):
    fallback_uv = build_fallback_uv_index(lat, lon)
    try:
        result = resilient_openweather("/data/2.5/uvi", {"lat": lat, "lon": lon})
        return {"uvi": result.get("value", fallback_uv), "_weather_meta": {"source": "OPENWEATHER"}}
    except HTTPException:
        return {"uvi": fallback_uv, "_weather_meta": {"source": "LOCAL_FALLBACK"}}


@app.get("/weather/history")
async def get_weather_history(lat: float = 16.705, lon: float = 74.2433, timestamp: int | None = None):
    if timestamp is None:
        timestamp = int((datetime.datetime.now() - datetime.timedelta(days=1)).timestamp())

    def _fallback(_exc=None):
        return build_fallback_historical_weather(lat, lon, timestamp)

    try:
        return resilient_openweather(
            "/data/3.0/onecall/timemachine",
            {"lat": lat, "lon": lon, "dt": timestamp, "units": "metric"},
            fallback_factory=_fallback,
        )
    except HTTPException:
        return _fallback()


@app.get("/weather/search")
async def search_weather_location(q: str, limit: int = 5):
    def _fallback(_exc=None):
        return build_fallback_search_results(q, limit)

    try:
        candidates = build_weather_lookup_candidates(q)
        all_results: list[Dict[str, Any]] = []
        seen_names: set[str] = set()

        for candidate in candidates:
            try:
                results = resilient_openweather("/geo/1.0/direct", {"q": candidate, "limit": limit})
                if isinstance(results, list):
                    for r in results:
                        name_key = f"{r.get('name', '')}|{r.get('lat', '')}|{r.get('lon', '')}"
                        if name_key not in seen_names:
                            seen_names.add(name_key)
                            all_results.append(r)
            except HTTPException:
                pass

            if len(all_results) >= limit:
                break

        return all_results[:limit] if all_results else _fallback()
    except HTTPException:
        return _fallback()


@app.get("/weather/reverse-geocode")
async def reverse_geocode(lat: float, lon: float, limit: int = 1):
    def _fallback(_exc=None):
        return build_fallback_reverse_geocode(lat, lon, limit)

    try:
        return resilient_openweather("/geo/1.0/reverse", {"lat": lat, "lon": lon, "limit": limit}, fallback_factory=_fallback)
    except HTTPException:
        return _fallback()


@app.get("/source-policy")
async def get_source_policy():
    return get_source_policy_payload()


@app.get("/artifacts")
async def list_artifacts(include_legacy: bool = False):
    artifacts = discover_model_artifacts()
    bundles = discover_model_bundles(artifacts)
    result: Dict[str, Any] = {
        "artifact_backend": get_model_artifact_backend(),
        "artifact_root": repo_relative_path(get_model_artifact_root()),
        "artifacts": artifacts,
        "bundles": bundles,
        "artifact_count": len(artifacts),
        "bundle_count": len(bundles),
        "complete_bundle_count": sum(1 for b in bundles.values() if b.get("is_complete")),
    }
    if include_legacy:
        result["legacy_artifacts_outside_store"] = discover_legacy_artifacts_outside_store()
    return result


@app.get("/model-paths")
async def get_model_paths():
    model_path, scaler_path = default_model_artifact_paths()
    artifacts = discover_model_artifacts()
    bundles = discover_model_bundles(artifacts)
    return {
        "model_path": model_path,
        "scaler_path": scaler_path,
        "artifact_backend": get_model_artifact_backend(),
        "artifact_root": repo_relative_path(get_model_artifact_root()),
        "bundles": bundles,
    }


@app.get("/ingestion/status")
async def get_ingestion_status():
    return {
        "pipeline": data_pipeline.status(),
        "ingestion": data_ingestion_scheduler.status(),
    }


@app.get("/ingestion/config")
async def get_ingestion_config():
    return {
        "scheduler_enabled": env_flag("ENABLE_DATA_INGESTION_SCHEDULER", default=False),
        "run_on_startup": env_flag("DATA_INGESTION_RUN_ON_STARTUP", default=True),
        "interval_minutes": max(1, int(float(os.getenv("DATA_INGESTION_INTERVAL_MINUTES") or 60))),
        "targets": [
            {
                "state_name": t.state_name,
                "station_name": t.station_name,
                "weather_query": t.weather_query,
                "lat": t.lat,
                "lon": t.lon,
            }
            for t in get_data_ingestion_targets()
        ],
    }


@app.post("/ingestion/trigger")
async def trigger_ingestion():
    data_pipeline.update_targets(get_data_ingestion_targets())
    result = await asyncio.to_thread(data_ingestion_scheduler.trigger_now)
    return {"triggered": True, "result": result}


@app.get("/operational-store/status")
async def get_operational_store_status():
    return operational_store.status()


@app.get("/operational-store/recent-predictions")
async def get_recent_predictions(limit: int = 20):
    try:
        records = operational_store.get_recent_predictions(limit=limit)
        return {"predictions": records, "count": len(records)}
    except Exception as exc:
        return {"predictions": [], "count": 0, "error": str(exc)}


@app.get("/operational-store/recent-telemetry")
async def get_recent_telemetry_snapshots(limit: int = 20):
    try:
        records = operational_store.get_recent_telemetry_snapshots(limit=limit)
        return {"snapshots": records, "count": len(records)}
    except Exception as exc:
        return {"snapshots": [], "count": 0, "error": str(exc)}


@app.get("/operational-store/audit-log")
async def get_audit_log(limit: int = 50):
    try:
        records = operational_store.get_audit_log(limit=limit)
        return {"audit_log": records, "count": len(records)}
    except Exception as exc:
        return {"audit_log": [], "count": 0, "error": str(exc)}


# Serve frontend build if present
if frontend_dist_ready():
    app.mount("/assets", StaticFiles(directory=os.path.join(FRONTEND_DIST_DIR, "assets")), name="assets")

    @app.get("/{full_path:path}", include_in_schema=False)
    async def serve_frontend(full_path: str):
        asset_path = resolve_frontend_asset(full_path)
        if asset_path:
            return FileResponse(asset_path)
        return FileResponse(FRONTEND_INDEX_PATH)


if __name__ == "__main__":
    uvicorn.run("app:app", host="0.0.0.0", port=8000, reload=True)
