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

try:
    # When running as a package (recommended): `uvicorn backend.app:app`
    from backend.data_pipeline import IngestionTarget, OperationalDataPipeline, ScheduledIngestionService
    from backend.state_severity_matrix import (
        STATE_SEVERITY_MATRIX,
        get_state_severity_entry,
        severity_from_entry,
    )
    from backend.postgres_store import PostgresOperationalStore
except ImportError:
    # When running from within the backend folder: `uvicorn app:app`
    from data_pipeline import IngestionTarget, OperationalDataPipeline, ScheduledIngestionService
    from state_severity_matrix import STATE_SEVERITY_MATRIX, get_state_severity_entry, severity_from_entry
    from postgres_store import PostgresOperationalStore

warnings.filterwarnings('ignore')
operational_store = PostgresOperationalStore()
operational_store.initialize()

SOURCE_POLICY_MODES = {"OPEN_DATA", "OFFICIAL_VIEW_ONLY", "FALLBACK"}


def get_source_policy_mode() -> str:
    refresh_backend_env(override=True)
    configured = (os.getenv("FLOOD_SOURCE_POLICY") or "OFFICIAL_VIEW_ONLY").strip().upper()
    return configured if configured in SOURCE_POLICY_MODES else "OFFICIAL_VIEW_ONLY"


def get_source_policy_payload() -> Dict[str, Any]:
    mode = get_source_policy_mode()
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
            "description": "Use open/publicly reusable datasets as the legal default. Live in-app CWC scraping is disabled.",
            "allow_live_cwc_in_app": False,
            "telemetry_mode": "OPEN_DATA_CONTEXT",
            "prediction_data_source": "Open Data Context + Manual Input",
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
        "description": "Use official CWC portals for public monitoring, but keep in-app telemetry on manual or tactical context unless explicit reuse rights are obtained.",
        "allow_live_cwc_in_app": False,
        "telemetry_mode": "OFFICIAL_VIEW_ONLY",
        "prediction_data_source": "Official View Only + Manual Input",
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
    tactical_fallback = cwc_scraper._build_tactical_telemetry(state_name=state_name, station_name=station_name, limit=limit)

    return {
        "status": "POLICY_LOCKED",
        "message": policy["description"],
        "data_source": "TACTICAL_REGISTRY",
        "source_policy": policy,
        "timestamp": datetime.datetime.now().isoformat(),
        "data": tactical_fallback[:limit],
    }

FLOOD_ARTIFACT_KEYWORDS = ("flood", "scaler", "feature", "indo")
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
WEATHER_TIMEZONE_OFFSET = 19800
WEATHER_TIMEZONE_NAME = "Asia/Kolkata"
WEATHER_CACHE: Dict[str, Dict[str, Any]] = {}


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
        # "https://floodredfl.onrender.com",
        # "https://kolhapurfloodred.onrender.com",
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
    Peak_Flood_Level_m: float = 12.74
    Event_Duration_days: float = 3
    Time_to_Peak_days: float = 2
    Recession_Time_day: float = 2
    T1d: float = 156.4
    T2d: float = 299.2
    T3d: float = 384.4
    T4d: float = 384.4
    T5d: float = 384.4
    T6d: float = 384.4
    T7d: float = 455.6
    state: str = "Maharashtra"

# ============= 2. FASTAPI SETUP =============
app = FastAPI(title="🌧️ INDIA_FLOODS ML API", version="8.5")

# 🛡️ SECURE PRODUCTION CORS
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


@app.on_event("startup")
async def startup_ingestion_scheduler():
    data_pipeline.update_targets(get_data_ingestion_targets())
    data_ingestion_scheduler.start()


@app.on_event("shutdown")
async def shutdown_ingestion_scheduler():
    data_ingestion_scheduler.stop()

# ============= 3. DATA ACQUISITION (CWC SCRAPER) =============
class CWCRiverScraper:
    def __init__(self):
        self.headers = {
            "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
            "Accept": "application/json, text/plain, */*",
            "Referer": "https://ffs.india-water.gov.in/"
        }
        self.cwc_api_base = "https://ffs.india-water.gov.in/iam/api"
        self._station_feed_retry_after: datetime.datetime | None = None
        self._station_feed_failure_message: str = ""
        self._last_telemetry_error_log_at: datetime.datetime | None = None
        self._last_telemetry_error_message: str = ""

    def _remember_station_feed_failure(self, message: str, cooldown_seconds: int):
        self._station_feed_failure_message = message
        self._station_feed_retry_after = datetime.datetime.now() + datetime.timedelta(seconds=max(30, cooldown_seconds))

    def _clear_station_feed_failure(self):
        self._station_feed_retry_after = None
        self._station_feed_failure_message = ""

    def _log_telemetry_error(self, message: str):
        now = datetime.datetime.now()
        if (
            self._last_telemetry_error_message == message
            and self._last_telemetry_error_log_at
            and (now - self._last_telemetry_error_log_at).total_seconds() < 300
        ):
            return

        self._last_telemetry_error_message = message
        self._last_telemetry_error_log_at = now
        print(f"❌ CWC Telemetry Error: {message}")

    def _safe_float(self, value, default=0.0):
        try:
            if value is None or value == "":
                return float(default)
            return float(value)
        except (TypeError, ValueError):
            return float(default)

    def _normalize_key(self, value: str | None) -> str:
        key = (value or "").strip().lower()
        key = " ".join(key.split())
        if key == "orissa":
            return "odisha"
        if key in {"nct of delhi", "new delhi"}:
            return "delhi"
        if key == "uttaranchal":
            return "uttarakhand"
        return key

    def _hash_value(self, input_value: str) -> int:
        hash_value = 0
        for char in input_value:
            hash_value = (hash_value << 5) - hash_value + ord(char)
            hash_value |= 0
        return abs(hash_value)

    def _seeded_unit(self, seed: str) -> float:
        return (self._hash_value(seed) % 1000) / 1000

    def _status_from_levels(self, current_level: float, warning_level: float, danger_level: float) -> str:
        if danger_level > 0 and current_level >= danger_level:
            return "CRITICAL"
        if warning_level > 0 and current_level >= warning_level:
            return "WARNING"
        return "ACTIVE"

    def _build_update_time(self, offset_ms: float) -> str:
        timestamp = datetime.datetime.now() - datetime.timedelta(milliseconds=float(offset_ms))
        return timestamp.isoformat()

    def _build_tactical_station_profiles(self, state_name: str, station_name: str):
        state_entry = get_state_severity_entry(state_name)
        clean_state = (state_name or "Active Region").strip() or "Active Region"
        preferred_station = (station_name or "").strip() or f"{clean_state} Central Gauge"
        danger_level = float(state_entry["danger_level_m"])
        primary_warning = round(max(danger_level - 1.4, danger_level * 0.86), 2)
        secondary_danger = round(max(danger_level - 0.4, primary_warning + 0.7), 2)
        secondary_warning = round(max(primary_warning - 0.6, 0.6), 2)
        tertiary_danger = round(max(danger_level - 1.1, secondary_warning + 0.8), 2)
        tertiary_warning = round(max(primary_warning - 1.2, 0.5), 2)

        return [
            {
                "station": preferred_station,
                "river": f"{clean_state} Primary Basin",
                "warning_level": primary_warning,
                "danger_level": round(danger_level, 2),
            },
            {
                "station": f"{clean_state} Downstream Sector",
                "river": f"{clean_state} Downstream Reach",
                "warning_level": secondary_warning,
                "danger_level": secondary_danger,
            },
            {
                "station": f"{clean_state} Catchment Control",
                "river": f"{clean_state} Catchment Basin",
                "warning_level": tertiary_warning,
                "danger_level": tertiary_danger,
            },
        ]

    def _build_tactical_telemetry(self, state_name="Maharashtra", station_name="Kolhapur", limit=6):
        profiles = self._build_tactical_station_profiles(state_name, station_name)
        state_key = self._normalize_key(state_name) or "active-region"
        station_key = self._normalize_key(station_name)
        time_bucket = int(datetime.datetime.now().timestamp() // (30 * 60))
        telemetry = []

        for index, profile in enumerate(profiles[: max(1, limit)]):
            seed = f"{state_key}|{self._normalize_key(profile['station'])}|{time_bucket}|{index}"
            threat = self._seeded_unit(f"{seed}|threat")
            warning_level = float(profile["warning_level"])
            danger_level = float(profile["danger_level"])

            current_level = warning_level - (0.45 + self._seeded_unit(f"{seed}|safe") * 1.55)
            if threat > 0.84:
                current_level = danger_level + self._seeded_unit(f"{seed}|critical") * 0.45
            elif threat > 0.58:
                current_level = warning_level + self._seeded_unit(f"{seed}|warning") * max(danger_level - warning_level, 0.6)

            current_level = round(current_level, 2)
            rainfall_last_hour = round(self._seeded_unit(f"{seed}|rain") * 18, 1)
            trend_roll = self._seeded_unit(f"{seed}|trend")
            trend = "RISING" if trend_roll > 0.66 else "FALLING" if trend_roll > 0.33 else "STEADY"

            telemetry.append({
                "station": profile["station"],
                "state_name": state_name,
                "state": state_name,
                "river": profile["river"],
                "river_level": current_level,
                "danger_level": danger_level,
                "warning_level": warning_level,
                "flow_rate": round(max(current_level, 0.0) * (10.8 + self._seeded_unit(f"{seed}|flow") * 4.4), 1),
                "rainfall_last_hour": rainfall_last_hour,
                "status": self._status_from_levels(current_level, warning_level, danger_level),
                "trend": trend,
                "source": "TACTICAL_REGISTRY",
                "last_update": self._build_update_time(self._seeded_unit(f"{seed}|time") * 55 * 60 * 1000),
            })

        if station_key:
            telemetry.sort(
                key=lambda site: (
                    0 if station_key in self._normalize_key(site["station"]) or station_key in self._normalize_key(site["river"]) else 1,
                    -float(site["river_level"]),
                )
            )

        return telemetry

    def _fetch_live_station_feed(self):
        if self._station_feed_retry_after and datetime.datetime.now() < self._station_feed_retry_after:
            raise RuntimeError(self._station_feed_failure_message or "CWC live telemetry endpoints are temporarily unavailable.")

        candidate_paths = [
            "/new-warning-station",
            "/warning-station",
        ]
        failures = []

        for path in candidate_paths:
            try:
                response = requests.get(
                    f"{self.cwc_api_base}{path}",
                    headers=self.headers,
                    timeout=8,
                )
                if response.status_code == 404:
                    failures.append(f"{path}: 404")
                    continue

                response.raise_for_status()
                payload = response.json()
                if isinstance(payload, list):
                    self._clear_station_feed_failure()
                    return path, payload

                failures.append(f"{path}: unexpected payload {type(payload).__name__}")
            except Exception as exc:
                failures.append(f"{path}: {exc}")

        failure_summary = " ; ".join(failures)
        cooldown_seconds = 900 if failures and all(": 404" in failure for failure in failures) else 180
        self._remember_station_feed_failure(failure_summary, cooldown_seconds)
        raise RuntimeError(failure_summary)

    def _site_priority(self, site: Dict[str, Any], target_state: str, target_station: str) -> int:
        station_match = bool(target_station) and (
            target_station in self._normalize_key(site.get("station"))
            or target_station in self._normalize_key(site.get("river"))
        )
        state_match = bool(target_state) and target_state in self._normalize_key(site.get("state_name"))

        if station_match and state_match:
            return 0
        if station_match:
            return 1
        if state_match:
            return 2
        return 3

    def get_live_river_level(self, station_name="Kolhapur"):
        print(f"📡 Initiating secure connection to CWC Servers for {station_name}...")
        try:
            _path, data = self._fetch_live_station_feed()
            for station in data:
                if station_name.lower() in station.get('stationName', '').lower():
                    level = station.get('waterLevel')
                    print(f"✅ SUCCESS: Live data fetched for {station['stationName']} ({level}m)")
                    return {
                        "status": "success",
                        "current_level_m": level,
                        "source": "CWC API"
                    }
            print("⚠️ API returned empty. Executing BeautifulSoup Fallback...")
            return self._beautifulsoup_fallback(station_name)
        except Exception as e:
            print(f"❌ CWC Scraper Error: {e}")
            return {"status": "error"}

    def _beautifulsoup_fallback(self, station_name):
        try:
            fallback_url = "https://ffs.india-water.gov.in/iam/api/report/state/Maharashtra"
            res = requests.get(fallback_url, headers=self.headers, verify=False, timeout=5)
            soup = BeautifulSoup(res.text, 'html.parser')
            rows = soup.find_all('tr')
            for row in rows:
                if station_name.lower() in row.text.lower():
                    columns = row.find_all('td')
                    if len(columns) > 3:
                        return {
                            "status": "success_fallback",
                            "current_level_m": float(columns[3].text.strip()),
                            "source": "HTML Scrape"
                        }
            return {"status": "error"}
        except Exception:
            return {"status": "error"}

    def get_live_telemetry(self, state_name="Maharashtra", station_name="Kolhapur", limit=6):
        target_state = self._normalize_key(state_name)
        target_station = self._normalize_key(station_name)
        tactical_fallback = self._build_tactical_telemetry(state_name=state_name, station_name=station_name, limit=limit)

        try:
            endpoint_path, raw_data = self._fetch_live_station_feed()

            formatted_telemetry = []
            for site in raw_data:
                water_level = self._safe_float(site.get("waterLevel"))
                danger_level = self._safe_float(site.get("dangerLevel"))
                warning_level = self._safe_float(site.get("warningLevel"))
                rainfall_last_hour = self._safe_float(
                    site.get("rainfall")
                    or site.get("rainfallLastHour")
                    or site.get("rainfall1Hr")
                )

                status_label = self._status_from_levels(water_level, warning_level, danger_level)

                formatted_telemetry.append({
                    "station": site.get("stationName") or site.get("name") or "UNKNOWN_SECTOR",
                    "state_name": site.get("stateName") or site.get("state") or "",
                    "state": site.get("stateName") or site.get("state") or state_name,
                    "river": site.get("riverName") or site.get("river") or "",
                    "river_level": round(water_level, 2),
                    "danger_level": round(danger_level, 2),
                    "warning_level": round(warning_level, 2),
                    "flow_rate": round(self._safe_float(site.get("discharge") or site.get("flowRate")), 1),
                    "rainfall_last_hour": round(rainfall_last_hour, 2),
                    "status": status_label,
                    "trend": site.get("trend") or "STEADY",
                    "source": "CWC_API",
                    "endpoint_path": endpoint_path,
                    "last_update": site.get("dateTime") or site.get("lastUpdate") or datetime.datetime.now().isoformat(),
                })

            ranked = sorted(
                formatted_telemetry,
                key=lambda site: (self._site_priority(site, target_state, target_station), -float(site["river_level"])),
            )
            filtered = [site for site in ranked if self._site_priority(site, target_state, target_station) < 3][:limit]

            if filtered:
                return {
                    "status": "SECURED",
                    "data_source": "CWC_API",
                    "endpoint_path": endpoint_path,
                    "timestamp": datetime.datetime.now().isoformat(),
                    "data": filtered,
                }

            return {
                "status": "PARTIAL_FALLBACK",
                "data_source": "TACTICAL_REGISTRY",
                "error": f"No targeted live telemetry found for {state_name}/{station_name}.",
                "timestamp": datetime.datetime.now().isoformat(),
                "data": tactical_fallback,
            }
        except Exception as exc:
            self._log_telemetry_error(str(exc))
            return {
                "status": "FALLBACK_MODE",
                "error": "Central Water Commission servers offline or blocking requests.",
                "data_source": "TACTICAL_REGISTRY",
                "timestamp": datetime.datetime.now().isoformat(),
                "data": tactical_fallback,
            }

# Initialize the scraper
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
        IngestionTarget(
            state_name=str(entry["state"]),
            station_name=str(entry["name"]),
            weather_query=f"{entry['name']}, {entry['state']}",
            lat=float(entry["lat"]),
            lon=float(entry["lon"]),
        )
        for entry in WEATHER_LOCATION_HINTS
    ]


def build_weather_ingestion_snapshot(target: IngestionTarget) -> Dict[str, Any]:
    location = resolve_weather_location(target.weather_query) or build_local_weather_location(
        query=target.weather_query,
        lat=target.lat,
        lon=target.lon,
    )
    lat = float(target.lat if target.lat is not None else location["lat"])
    lon = float(target.lon if target.lon is not None else location["lon"])

    payload = resilient_openweather(
        "/data/2.5/weather",
        {"lat": lat, "lon": lon, "units": "metric"},
        fallback_factory=lambda exc: build_fallback_current_weather(
            city=str(location.get("name") or target.station_name),
            lat=lat,
            lon=lon,
            reason=f"INGESTION_FALLBACK_AFTER_{getattr(exc, 'status_code', 'ERROR')}",
        ),
    )

    if isinstance(payload, dict):
        payload.setdefault("_pipeline_meta", {})
        payload["_pipeline_meta"].update(
            {
                "target_state": target.state_name,
                "target_station": target.station_name,
                "weather_query": target.weather_query,
            }
        )

    return payload


def build_water_level_ingestion_snapshot(target: IngestionTarget) -> Dict[str, Any]:
    limit = max(3, int(os.getenv("DATA_INGESTION_WATER_NODE_LIMIT") or 6))
    payload = build_policy_bound_telemetry(
        state_name=target.state_name,
        station_name=target.station_name,
        limit=limit,
    )
    payload.setdefault("_pipeline_meta", {})
    payload["_pipeline_meta"].update(
        {
            "target_state": target.state_name,
            "target_station": target.station_name,
            "water_node_limit": limit,
        }
    )
    return payload


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
        "cache_entries": len(WEATHER_CACHE),
    }

# ============= 4. MACHINE LEARNING CORE =============
class KolhapurFloodPredictor:
    def __init__(self):
        self.base_dir = BASE_DIR
        self.model = RandomForestClassifier(n_estimators=150, max_depth=12, min_samples_split=5, min_samples_leaf=2, random_state=42, class_weight='balanced')
        self.scaler = StandardScaler()
        self.feature_importance = {}
        self.is_trained = False
        self.state_models = {}
        self.bundle_models = {}
        self.artifact_catalog = []
        self.artifact_bundles = {}
        self.artifact_store_dir = get_model_artifact_root()
        self.artifact_storage_backend = get_model_artifact_backend()
        self.default_bundle_key = "flood"
        self.default_model_paths = default_model_artifact_paths()
        self.refresh_artifact_catalog()
        self.load_pretrained_model()

    def refresh_artifact_catalog(self):
        self.artifact_store_dir = get_model_artifact_root()
        self.artifact_storage_backend = get_model_artifact_backend()
        self.artifact_catalog = discover_model_artifacts()
        self.artifact_bundles = discover_model_bundles(self.artifact_catalog)
        self.bundle_models = {}
        self.state_models = {}
        self.default_bundle_key = self._resolve_default_bundle_key()
        default_bundle = self.artifact_bundles.get(self.default_bundle_key, {})
        fallback_model_path, fallback_scaler_path = default_model_artifact_paths()
        self.default_model_paths = (
            default_bundle.get("model") or fallback_model_path,
            default_bundle.get("scaler") or fallback_scaler_path,
        )
        return self.artifact_catalog

    def resolve_model_artifact(self, relative_path: str) -> str:
        return resolve_model_artifact_path(relative_path)

    def _resolve_default_bundle_key(self) -> str:
        flood_bundle = self.artifact_bundles.get("flood")
        if flood_bundle and flood_bundle.get("is_complete"):
            return "flood"

        for bundle_key, bundle in self.artifact_bundles.items():
            if bundle.get("is_complete"):
                return bundle_key

        return "flood"

    def _bundle_candidates_for_state(self, state_name: str) -> list[str]:
        state_key = slugify_name(state_name)
        if not state_key:
            return [self.default_bundle_key]

        candidates = [
            f"{state_key}_flood",
            state_key,
        ]

        compact_key = state_key.replace("_", "")
        if compact_key and compact_key != state_key:
            candidates.append(compact_key)

        if state_key == "maharashtra":
            candidates.extend(["kolhapur_flood", "kolhapur"])

        if state_key in INDOFLOODS_STATE_KEYS:
            candidates.append("indofloods")

        # Remove duplicates while preserving order.
        deduped: list[str] = []
        for candidate in candidates:
            if candidate and candidate not in deduped:
                deduped.append(candidate)

        return deduped

    def resolve_bundle_for_state(self, state_name: str) -> tuple[str, Dict[str, Any]]:
        for candidate in self._bundle_candidates_for_state(state_name):
            bundle = self.artifact_bundles.get(candidate)
            if bundle and bundle.get("is_complete"):
                return candidate, bundle

        state_tokens = [token for token in slugify_name(state_name).split("_") if token and token != "and"]
        for bundle_key, bundle in self.artifact_bundles.items():
            if bundle.get("is_complete") and state_tokens and all(token in bundle_key for token in state_tokens):
                return bundle_key, bundle

        default_bundle = self.artifact_bundles.get(self.default_bundle_key, {})
        return self.default_bundle_key, default_bundle
    
    def load_pretrained_model(self):
        model_path = self.resolve_model_artifact(self.default_model_paths[0])
        scaler_path = self.resolve_model_artifact(self.default_model_paths[1])
        if os.path.exists(model_path) and os.path.exists(scaler_path):
            try:
                self.model = joblib.load(model_path)
                self.scaler = joblib.load(scaler_path)
                self.bundle_models[self.default_bundle_key] = (self.model, self.scaler)
                self.is_trained = True
                print("✅ ML model loaded successfully from artifact storage!")
            except Exception:
                self.train_with_real_data()
        else:
            self.train_with_real_data()

    def load_bundle_model(self, bundle_key: str) -> tuple[Any, Any] | None:
        if bundle_key in self.bundle_models:
            return self.bundle_models[bundle_key]

        bundle = self.artifact_bundles.get(bundle_key) or {}
        model_path_rel = bundle.get("model")
        scaler_path_rel = bundle.get("scaler")
        if not model_path_rel or not scaler_path_rel:
            self.bundle_models[bundle_key] = None
            return None

        model_path = self.resolve_model_artifact(model_path_rel)
        scaler_path = self.resolve_model_artifact(scaler_path_rel)
        if not (os.path.exists(model_path) and os.path.exists(scaler_path)):
            self.bundle_models[bundle_key] = None
            return None

        try:
            mdl = joblib.load(model_path)
            sclr = joblib.load(scaler_path)
            self.bundle_models[bundle_key] = (mdl, sclr)
            return mdl, sclr
        except Exception as exc:
            print(f"⚠️ Failed loading bundle '{bundle_key}': {exc}")
            self.bundle_models[bundle_key] = None
            return None

    def get_model_for_state(self, state_name: str):
        key = (state_name or '').strip().lower()
        if key in self.state_models:
            return self.state_models[key]

        bundle_key, _bundle = self.resolve_bundle_for_state(state_name)
        loaded = self.load_bundle_model(bundle_key)
        if loaded:
            self.state_models[key] = loaded
            print(f"✅ Loaded model bundle '{bundle_key}' for {key.title()}")
            return loaded

        self.state_models[key] = (self.model, self.scaler)
        return self.model, self.scaler

    def candidate_bundle_keys_for_state(self, state_name: str) -> list[str]:
        primary_bundle_key, _bundle = self.resolve_bundle_for_state(state_name)
        candidates = [primary_bundle_key]

        if primary_bundle_key != self.default_bundle_key:
            candidates.append(self.default_bundle_key)

        if slugify_name(state_name) in INDOFLOODS_STATE_KEYS and "indofloods" not in candidates:
            candidates.insert(1, "indofloods")

        deduped: list[str] = []
        for candidate in candidates:
            bundle = self.artifact_bundles.get(candidate)
            if candidate and candidate not in deduped and bundle and bundle.get("is_complete"):
                deduped.append(candidate)

        return deduped

    def bundle_weight_plan(self, bundle_keys: list[str]) -> Dict[str, float]:
        if not bundle_keys:
            return {}
        if len(bundle_keys) == 1:
            weights = [1.0]
        elif len(bundle_keys) == 2:
            weights = [0.68, 0.32]
        else:
            weights = [0.56, 0.24, 0.20]

        return {
            bundle_key: weight
            for bundle_key, weight in zip(bundle_keys, weights)
        }

    def build_feature_vector(self, input_data: FloodPredictionInput) -> np.ndarray:
        return np.array([[
            float(input_data.Peak_Flood_Level_m),
            float(input_data.Event_Duration_days),
            float(input_data.Time_to_Peak_days),
            float(input_data.Recession_Time_day),
            float(input_data.T1d),
            float(input_data.T2d),
            float(input_data.T3d),
            float(input_data.T4d),
            float(input_data.T5d),
            float(input_data.T6d),
            float(input_data.T7d),
        ]], dtype=float)

    def normalize_probability_map(self, probabilities: Dict[str, float]) -> Dict[str, float]:
        labels = ["LOW", "MODERATE", "SEVERE", "CRITICAL"]
        normalized = {label: max(0.0, float(probabilities.get(label, 0.0))) for label in labels}
        total = sum(normalized.values())
        if total <= 0:
            return {"LOW": 1.0, "MODERATE": 0.0, "SEVERE": 0.0, "CRITICAL": 0.0}
        return {label: value / total for label, value in normalized.items()}

    def model_probability_map(self, model: Any, scaler: Any, features: np.ndarray) -> Dict[str, float]:
        features_scaled = scaler.transform(features)
        probs = model.predict_proba(features_scaled)[0]
        classes = list(getattr(model, "classes_", []))

        label_map = {
            0: "LOW",
            1: "MODERATE",
            2: "SEVERE",
            "LOW": "LOW",
            "MODERATE": "MODERATE",
            "SEVERE": "SEVERE",
            "CRITICAL": "CRITICAL",
        }

        probability_map = {"LOW": 0.0, "MODERATE": 0.0, "SEVERE": 0.0, "CRITICAL": 0.0}
        for cls, prob in zip(classes, probs):
            label = label_map.get(cls)
            if label:
                probability_map[label] = float(prob)

        return self.normalize_probability_map(probability_map)

    def rule_engine_probability_map(
        self,
        input_data: FloodPredictionInput,
        state_entry: Dict[str, Any],
    ) -> tuple[Dict[str, float], Dict[str, float]]:
        daily_rainfall = [
            float(input_data.T1d),
            float(input_data.T2d),
            float(input_data.T3d),
            float(input_data.T4d),
            float(input_data.T5d),
            float(input_data.T6d),
            float(input_data.T7d),
        ]
        peak = float(input_data.Peak_Flood_Level_m)
        total_rainfall = float(sum(daily_rainfall))
        avg_rainfall = total_rainfall / max(len(daily_rainfall), 1)
        max_daily_rainfall = max(daily_rainfall)
        rainfall_delta = daily_rainfall[-1] - daily_rainfall[0]

        peak_thresholds = state_entry["peak_level_m"]
        rain_thresholds = state_entry["rainfall_7d_mm"]

        peak_moderate_ratio = peak / max(float(peak_thresholds["moderate"]), 0.001)
        peak_severe_ratio = peak / max(float(peak_thresholds["severe"]), 0.001)
        peak_critical_ratio = peak / max(float(peak_thresholds["critical"]), 0.001)

        rain_moderate_ratio = total_rainfall / max(float(rain_thresholds["moderate"]), 0.001)
        rain_severe_ratio = total_rainfall / max(float(rain_thresholds["severe"]), 0.001)
        rain_critical_ratio = total_rainfall / max(float(rain_thresholds["critical"]), 0.001)

        danger_ratio = peak / max(float(state_entry["danger_level_m"]), 0.001)
        concentration_ratio = max_daily_rainfall / max(avg_rainfall, 1.0)
        duration_ratio = float(input_data.Event_Duration_days) / 4.0
        flash_ratio = max(0.0, (2.5 - float(input_data.Time_to_Peak_days)) / 2.5)
        slow_recession_ratio = min(1.5, float(input_data.Recession_Time_day) / 3.0)
        trend_ratio = max(-1.0, min(1.0, rainfall_delta / max(total_rainfall, 1.0) * 7.0))

        threshold_severity = severity_from_entry(
            peak_level_m=peak,
            rainfall_7d_mm=total_rainfall,
            entry=state_entry,
        )

        scores = {
            "LOW": max(0.05, 1.25 - max(peak_moderate_ratio, rain_moderate_ratio) - max(0.0, danger_ratio - 0.88)),
            "MODERATE": max(0.05, 0.82 * rain_moderate_ratio + 0.78 * peak_moderate_ratio + 0.12 * duration_ratio - 0.82),
            "SEVERE": max(
                0.05,
                0.95 * rain_severe_ratio
                + 0.96 * peak_severe_ratio
                + 0.20 * concentration_ratio
                + 0.12 * duration_ratio
                + 0.10 * max(0.0, trend_ratio)
                - 1.12,
            ),
            "CRITICAL": max(
                0.02,
                1.08 * rain_critical_ratio
                + 1.12 * peak_critical_ratio
                + 0.34 * max(0.0, danger_ratio - 1.0)
                + 0.18 * max(0.0, concentration_ratio - 1.35)
                + 0.18 * flash_ratio
                + 0.10 * slow_recession_ratio
                + 0.12 * max(0.0, trend_ratio)
                - 1.25,
            ),
        }

        threshold_boost = {
            "LOW": ("LOW", 0.0),
            "MODERATE": ("MODERATE", 0.22),
            "SEVERE": ("SEVERE", 0.32),
            "CRITICAL": ("CRITICAL", 0.42),
        }
        boosted_label, boost_value = threshold_boost[threshold_severity]
        scores[boosted_label] += boost_value

        signals = {
            "peak_moderate_ratio": round(peak_moderate_ratio, 3),
            "peak_severe_ratio": round(peak_severe_ratio, 3),
            "peak_critical_ratio": round(peak_critical_ratio, 3),
            "rain_moderate_ratio": round(rain_moderate_ratio, 3),
            "rain_severe_ratio": round(rain_severe_ratio, 3),
            "rain_critical_ratio": round(rain_critical_ratio, 3),
            "danger_ratio": round(danger_ratio, 3),
            "concentration_ratio": round(concentration_ratio, 3),
            "duration_ratio": round(duration_ratio, 3),
            "flash_ratio": round(flash_ratio, 3),
            "slow_recession_ratio": round(slow_recession_ratio, 3),
            "trend_ratio": round(trend_ratio, 3),
            "threshold_severity": threshold_severity,
        }

        return self.normalize_probability_map(scores), signals

    def apply_threshold_floor(
        self,
        probabilities: Dict[str, float],
        threshold_severity: str,
    ) -> Dict[str, float]:
        floors = {
            "LOW": 0.0,
            "MODERATE": 0.30,
            "SEVERE": 0.42,
            "CRITICAL": 0.54,
        }
        adjusted = dict(probabilities)
        adjusted[threshold_severity] = max(adjusted.get(threshold_severity, 0.0), floors.get(threshold_severity, 0.0))
        return self.normalize_probability_map(adjusted)

    def promote_severity(
        self,
        probabilities: Dict[str, float],
        severity_label: str,
    ) -> Dict[str, float]:
        adjusted = dict(probabilities)
        current_max = max(adjusted.values())
        adjusted[severity_label] = max(adjusted.get(severity_label, 0.0), min(0.84, current_max + 0.06))
        return self.normalize_probability_map(adjusted)

    def complex_predict_flood(self, input_data: FloodPredictionInput, source: str = "Manual Input") -> Dict[str, Any]:
        state_entry = get_state_severity_entry(input_data.state)
        features = self.build_feature_vector(input_data)
        bundle_keys = self.candidate_bundle_keys_for_state(input_data.state)
        bundle_weights = self.bundle_weight_plan(bundle_keys)

        bundle_predictions = []
        ml_probabilities = {"LOW": 0.0, "MODERATE": 0.0, "SEVERE": 0.0, "CRITICAL": 0.0}
        total_bundle_weight = 0.0

        for bundle_key in bundle_keys:
            loaded = self.load_bundle_model(bundle_key)
            if not loaded:
                continue

            model, scaler = loaded
            probability_map = self.model_probability_map(model, scaler, features)
            bundle_weight = bundle_weights.get(bundle_key, 0.0)
            total_bundle_weight += bundle_weight

            for severity_label in ml_probabilities:
                ml_probabilities[severity_label] += probability_map.get(severity_label, 0.0) * bundle_weight

            bundle_predictions.append({
                "bundle_key": bundle_key,
                "weight": round(bundle_weight, 3),
                "probabilities": {label: round(probability_map[label] * 100, 1) for label in probability_map},
            })

        if total_bundle_weight <= 0:
            raise RuntimeError("No loadable ML model bundles available for ensemble prediction.")

        ml_probabilities = self.normalize_probability_map(ml_probabilities)
        rule_probabilities, rule_signals = self.rule_engine_probability_map(input_data, state_entry)

        ml_total_weight = min(0.75, 0.5 + 0.1 * len(bundle_predictions))
        rule_weight = 1.0 - ml_total_weight

        final_probabilities = {
            label: (ml_probabilities.get(label, 0.0) * ml_total_weight) + (rule_probabilities.get(label, 0.0) * rule_weight)
            for label in ["LOW", "MODERATE", "SEVERE", "CRITICAL"]
        }

        final_probabilities = self.apply_threshold_floor(
            self.normalize_probability_map(final_probabilities),
            str(rule_signals["threshold_severity"]),
        )

        severity_rank = {"LOW": 0, "MODERATE": 1, "SEVERE": 2, "CRITICAL": 3}
        severity = max(final_probabilities, key=final_probabilities.get)
        threshold_severity = str(rule_signals["threshold_severity"])
        if severity_rank.get(threshold_severity, 0) > severity_rank.get(severity, 0):
            final_probabilities = self.promote_severity(final_probabilities, threshold_severity)
            severity = threshold_severity

        confidence = round(final_probabilities[severity] * 100, 1)
        risk_weights = {"LOW": 16, "MODERATE": 46, "SEVERE": 78, "CRITICAL": 96}
        risk_score = round(sum(final_probabilities[label] * risk_weights[label] for label in final_probabilities))

        return {
            "severity": severity,
            "confidence_percent": confidence,
            "probabilities": {label: round(prob * 100, 1) for label, prob in final_probabilities.items()},
            "alert": "🚨" if severity in {"SEVERE", "CRITICAL"} else "⚠️" if severity == "MODERATE" else "🟢",
            "algorithm": "Hybrid Multi-Bundle Ensemble v2",
            "data_source": source,
            "model_trained": True,
            "danger_level": state_entry["danger_level_m"],
            "critical_threshold": state_entry["peak_level_m"]["critical"],
            "risk_score": int(max(0, min(100, risk_score))),
            "state": input_data.state,
            "state_matrix": state_entry,
            "ensemble": {
                "primary_bundle": bundle_keys[0] if bundle_keys else self.default_bundle_key,
                "bundle_predictions": bundle_predictions,
                "ml_weight": round(ml_total_weight, 3),
                "rule_weight": round(rule_weight, 3),
                "ml_probabilities": {label: round(prob * 100, 1) for label, prob in ml_probabilities.items()},
                "rule_probabilities": {label: round(prob * 100, 1) for label, prob in rule_probabilities.items()},
                "rule_signals": rule_signals,
            },
        }

    def describe_state_model_artifacts(self, state_name: str) -> Dict[str, Any]:
        key = (state_name or '').strip().lower()
        bundle_key, bundle = self.resolve_bundle_for_state(state_name)
        model_path_rel = bundle.get("model") or self.default_model_paths[0]
        scaler_path_rel = bundle.get("scaler") or self.default_model_paths[1]
        model_path = self.resolve_model_artifact(model_path_rel)
        scaler_path = self.resolve_model_artifact(scaler_path_rel)

        return {
            "state": state_name,
            "state_key": key,
            "bundle_key": bundle_key,
            "bundle_complete": bool(bundle.get("is_complete")),
            "artifact_root": repo_relative_path(self.artifact_store_dir),
            "storage_backend": self.artifact_storage_backend,
            "model": {
                "relative_path": model_path_rel,
                "exists": os.path.exists(model_path),
            },
            "scaler": {
                "relative_path": scaler_path_rel,
                "exists": os.path.exists(scaler_path),
            },
            "features": bundle.get("features", []),
            "fallback_default": bundle_key == self.default_bundle_key,
        }
    
    def get_training_data(self):
        real_events = [
            [13.5, 5, 2, 4, 180, 320, 420, 450, 480, 490, 550, 2],
            [12.8, 4, 2, 3, 160, 280, 380, 420, 450, 460, 480, 2],
            [11.8, 3, 2, 2, 120, 200, 280, 320, 350, 380, 400, 1],
            [11.2, 2, 1, 2, 100, 180, 250, 290, 320, 350, 370, 1],
            [9.5,  1, 1, 1,  50,  80, 100, 120, 150, 160, 180, 0],
            [8.0,  0, 0, 1,  10,  20,  30,  40,  50,  60,  80, 0],
        ]
        synthetic_data = []
        for _ in range(1000): 
            rand = np.random.random()
            if rand > 0.66: 
                peak, rain_7d, dur, label = np.random.uniform(12.2, 14.5), np.random.uniform(450, 700), np.random.uniform(3, 7), 2
            elif rand > 0.33: 
                peak, rain_7d, dur, label = np.random.uniform(10.5, 12.1), np.random.uniform(250, 449), np.random.uniform(2, 4), 1
            else: 
                peak, rain_7d, dur, label = np.random.uniform(5.0, 10.4), np.random.uniform(50, 249), np.random.uniform(0, 2), 0
            
            rain_dist = np.random.dirichlet(np.ones(7), size=1)[0] * rain_7d
            synthetic_data.append([peak, dur, np.random.uniform(1, 3), np.random.uniform(1, 4), rain_dist[0], rain_dist[1], rain_dist[2], rain_dist[3], rain_dist[4], rain_dist[5], rain_dist[6], label])
        
        all_data = real_events + synthetic_data
        return np.array([event[:-1] for event in all_data]), np.array([event[-1] for event in all_data])
    
    def train_with_real_data(self):
        print("🔄 Training Multi-Class Flood Matrix...")
        X, y = self.get_training_data()
        X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=42, stratify=y)
        
        X_train_scaled = self.scaler.fit_transform(X_train)
        self.model.fit(X_train_scaled, y_train)

        self.is_trained = True
        fallback_model_path, fallback_scaler_path = default_model_artifact_paths()
        joblib.dump(self.model, self.resolve_model_artifact(fallback_model_path))
        joblib.dump(self.scaler, self.resolve_model_artifact(fallback_scaler_path))
        self.refresh_artifact_catalog()
        print("✅ ML Matrix trained and saved to artifact storage!")
    
    def predict_flood(self, input_data: FloodPredictionInput, source: str = "Manual Input") -> Dict[str, Any]:
        try:
            return self.complex_predict_flood(input_data, source=source)
        except Exception as e:
            return self.fallback_prediction(input_data)
    
    def fallback_prediction(self, input_data: FloodPredictionInput) -> Dict[str, Any]:
        peak = float(input_data.Peak_Flood_Level_m)
        rain = float(
            float(input_data.T1d)
            + float(input_data.T2d)
            + float(input_data.T3d)
            + float(input_data.T4d)
            + float(input_data.T5d)
            + float(input_data.T6d)
            + float(input_data.T7d)
        )
        state_entry = get_state_severity_entry(input_data.state)
        sev = severity_from_entry(peak_level_m=peak, rainfall_7d_mm=rain, entry=state_entry)
        conf_map = {"LOW": 85.0, "MODERATE": 78.3, "SEVERE": 92.5, "CRITICAL": 97.5}
        conf = conf_map.get(sev, 85.0)
            
        return {
            "severity": sev,
            "confidence_percent": conf,
            "probabilities": {"SEVERE": conf if sev in ["SEVERE", "CRITICAL"] else 5, "MODERATE": conf if sev=="MODERATE" else 15, "LOW": conf if sev=="LOW" else 5},
            "alert": "🚨" if sev in ["SEVERE", "CRITICAL"] else "⚠️" if sev == "MODERATE" else "🟢",
            "algorithm": "Python Heuristic Fallback",
            "data_source": "Manual Input",
            "model_trained": False,
            "danger_level": state_entry["danger_level_m"],
            "critical_threshold": state_entry["peak_level_m"]["critical"],
            "risk_score": int(conf),
            "state": input_data.state,
            "state_matrix": state_entry,
        }

predictor = KolhapurFloodPredictor()

# ============= 5. API ENDPOINTS =============
@app.get("/")
async def root():
    if frontend_dist_ready():
        return FileResponse(FRONTEND_INDEX_PATH)

    return {
        "service": "INDIA_FLOODS ML Server",
        "status": "Online",
        "model_ready": predictor.is_trained,
        "source_policy": get_source_policy_payload(),
    }

@app.get("/health")
def health():
    return {
        "status": "ok",
        "service": "INDIA_FLOODS ML Server",
        "model_ready": predictor.is_trained,
        "database": operational_store.status(),
        "ingestion": data_ingestion_scheduler.status(),
        "artifact_count": len(predictor.artifact_catalog),
        "bundle_count": len(predictor.artifact_bundles),
        "version": app.version,
        "source_policy": get_source_policy_payload(),
        "time": datetime.datetime.now().isoformat(),
    }


@app.get("/source-policy")
async def get_source_policy():
    return {
        "status": "success",
        "source_policy": get_source_policy_payload(),
        "time": datetime.datetime.now().isoformat(),
    }


@app.get("/ingestion/status")
async def get_ingestion_status():
    data_pipeline.update_targets(get_data_ingestion_targets())
    return {
        "status": "success",
        "scheduler": data_ingestion_scheduler.status(),
        "time": current_timestamp_iso(),
    }


@app.post("/ingestion/run")
async def run_ingestion_now():
    data_pipeline.update_targets(get_data_ingestion_targets())
    result = await asyncio.to_thread(data_ingestion_scheduler.trigger_now)
    return {
        "status": "success" if result.get("status") == "success" else result.get("status"),
        "result": result,
        "time": current_timestamp_iso(),
    }


@app.get("/model-artifacts")
async def get_model_artifacts():
    predictor.refresh_artifact_catalog()
    return {
        "status": "success",
        "base_dir": repo_relative_path(predictor.artifact_store_dir),
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
    }


@app.get("/model-artifacts/{state_name}")
async def get_model_artifacts_for_state(state_name: str):
    return {
        "status": "success",
        "selection": predictor.describe_state_model_artifacts(state_name),
    }

@app.get("/state-severity-matrix")
async def get_state_severity_matrix():
    return {
        "status": "success",
        "states": STATE_SEVERITY_MATRIX,
        "note": "Heuristic calibration thresholds (not official CWC danger levels).",
    }

@app.get("/state-severity-matrix/{state_name}")
async def get_state_severity_matrix_for_state(state_name: str):
    return {
        "status": "success",
        "state": state_name,
        "matrix": get_state_severity_entry(state_name),
        "note": "Heuristic calibration thresholds (not official CWC danger levels).",
    }

@app.post("/predict")
async def predict_flood(input_data: FloodPredictionInput):
    """Endpoint consumed by the frontend"""
    try:
        source_policy = get_source_policy_payload()
        data_source = str(source_policy["prediction_data_source"])

        if source_policy.get("allow_live_cwc_in_app"):
            print("🔄 Fetching live data from Central Water Commission...")
            live_data = await asyncio.to_thread(cwc_scraper.get_live_river_level, input_data.station or "Kolhapur")

            if live_data.get("status") in ["success", "success_fallback"]:
                live_level = live_data.get("current_level_m")
                if live_level is not None:
                    input_data.Peak_Flood_Level_m = float(live_level)
                    data_source = f"Live CWC Sensor ({live_data['source']})"
                    print(f"🌊 OVERRIDE: Using Authentic Live CWC Level: {input_data.Peak_Flood_Level_m}m")
            else:
                print("⚠️ CWC Servers unavailable. Proceeding with user's manual input.")
        else:
            print(f"ℹ️ Source policy {source_policy['mode']} blocks in-app live CWC ingestion. Using manual/tactical context.")

        # Get ML Response (run blocking ML inference in thread)
        result = await asyncio.to_thread(predictor.predict_flood, input_data, source=data_source)
        result["source_policy"] = source_policy
        result["timestamp"] = current_timestamp_iso()

        # Attach Monitoring Protocols
        if result["severity"] == "CRITICAL":
            result["monitoring"] = {"level": "CRITICAL EMERGENCY", "action": "Evacuate vulnerable river basins immediately.", "priority_zones": ["Primary Catchment", "Downstream Villages", "Low-lying urban zones"]}
        elif result["severity"] == "SEVERE":
            result["monitoring"] = {"level": "CRITICAL EMERGENCY", "action": "Evacuate vulnerable river basins immediately.", "priority_zones": ["Primary Catchment", "Downstream Villages", "Low-lying urban zones"]}
        elif result["severity"] == "MODERATE":
            result["monitoring"] = {"level": "ELEVATED ALERT", "action": "Deploy monitoring teams & prep pumps.", "priority_zones": ["Drainage bottlenecks", "Main river gauge"]}
        else:
            result["monitoring"] = {"level": "STANDARD PROTOCOL", "action": "Maintain normal surveillance.", "priority_zones": ["None"]}

        prediction_id = persist_prediction_record(input_data, result)
        result["prediction_id"] = prediction_id
        return result
        
    except Exception as e:
        input_payload = model_to_dict(input_data)
        write_audit_log(
            event_type="prediction.inference",
            route="/predict",
            event_status="error",
            state_name=str(input_payload.get("state") or "Maharashtra"),
            station_name=str(input_payload.get("station") or "").strip() or None,
            details={"error": str(e)},
        )
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/prediction-history")
async def get_prediction_history(state: str | None = None, station: str | None = None, limit: int = 100):
    records = operational_store.list_predictions(limit=limit, state_name=state, station_name=station)
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


@app.get("/telemetry-snapshots")
async def get_telemetry_snapshots(state: str | None = None, station: str | None = None, limit: int = 50):
    records = operational_store.list_telemetry_snapshots(limit=limit, state_name=state, station_name=station)
    return {
        "status": "success",
        "storage": operational_store.status(),
        "total_records": len(records),
        "records": [
            {
                "id": record["id"],
                "timestamp": record["created_at"].isoformat() if record.get("created_at") else None,
                "state": record.get("state_name"),
                "station": record.get("station_name"),
                "request_limit": record.get("request_limit"),
                "snapshot_status": record.get("snapshot_status"),
                "data_source": record.get("data_source"),
                "source_policy_mode": record.get("source_policy_mode"),
                "node_count": record.get("node_count"),
            }
            for record in records
        ],
    }


@app.get("/audit-logs")
async def get_audit_logs(limit: int = 50):
    records = operational_store.list_audit_logs(limit=limit)
    return {
        "status": "success",
        "storage": operational_store.status(),
        "total_records": len(records),
        "records": [
            {
                "id": record["id"],
                "timestamp": record["created_at"].isoformat() if record.get("created_at") else None,
                "event_type": record.get("event_type"),
                "route": record.get("route"),
                "event_status": record.get("event_status"),
                "state": record.get("state_name"),
                "station": record.get("station_name"),
                "severity": record.get("severity"),
            }
            for record in records
        ],
    }

@app.get("/historical-logs")
async def get_historical_logs(city: str = "Kolhapur", limit: int = 50):
    """
    Fetch historical flood logs for a preferred city
    """
    try:
        import csv

        def _normalize_log_key(value: str) -> str:
            value = (value or "").strip().lower()
            cleaned = "".join(ch if ch.isalnum() or ch.isspace() else " " for ch in value)
            return " ".join(cleaned.split())

        def _safe_float(value: Any) -> float:
            try:
                return float(value or 0)
            except (TypeError, ValueError):
                return 0.0

        requested_city = city or "Kolhapur"
        requested_key = _normalize_log_key(requested_city)

        dataset_catalog = [
            {
                "dataset_city": "Kolhapur",
                "file": "kolhapur_flood_logs.csv",
                "aliases": [
                    "kolhapur",
                    "kolhapur district",
                    "kolhapur sector",
                    "shirol",
                    "shirol sector",
                    "irwin bridge",
                    "irwin bridge sector",
                    "irwin bridge kolhapur",
                    "irwin bridge area",
                    "kagal",
                    "kagal high ground",
                    "rajaram barrage",
                    "panchganga",
                    "kurundwad",
                ],
            },
        ]

        matched_dataset = next(
            (
                dataset
                for dataset in dataset_catalog
                if requested_key
                and any(
                    requested_key == _normalize_log_key(alias)
                    or requested_key in _normalize_log_key(alias)
                    or _normalize_log_key(alias) in requested_key
                    for alias in dataset["aliases"]
                )
            ),
            None,
        )

        logs = []
        if matched_dataset:
            csv_path = matched_dataset["file"]
            candidates = [
                csv_path,
                os.path.join(BASE_DIR, csv_path),
                os.path.join(REPO_DIR, "frontend", "data", csv_path),
                os.path.join(REPO_DIR, "data", csv_path),
            ]
            resolved_csv = next((p for p in candidates if os.path.exists(p)), None)

            if resolved_csv:
                all_rows = []
                with open(resolved_csv, "r", encoding="utf-8") as f:
                    reader = csv.DictReader(f)
                    for row in reader:
                        mapped_row = {
                            "timestamp": row.get("timestamp"),
                            "location": row.get("location"),
                            "peak_level": _safe_float(row.get("peak_level_m")),
                            "rainfall_7day": _safe_float(row.get("rainfall_7day_mm")),
                            "severity": row.get("severity"),
                            "confidence": _safe_float(row.get("confidence_percent")),
                            "alert": row.get("alert_message"),
                            "source": row.get("source"),
                            "dataset_city": matched_dataset["dataset_city"],
                        }
                        all_rows.append(mapped_row)

                def _row_matches(row: Dict[str, Any]) -> bool:
                    haystacks = [
                        row.get("location"),
                        row.get("alert"),
                        row.get("source"),
                        row.get("dataset_city"),
                    ]
                    return any(
                        requested_key in _normalize_log_key(item or "")
                        or _normalize_log_key(item or "") in requested_key
                        for item in haystacks
                    )

                prioritized_rows = [row for row in all_rows if requested_key and _row_matches(row)]
                if prioritized_rows:
                    remaining_rows = [row for row in all_rows if row not in prioritized_rows]
                    logs = prioritized_rows + remaining_rows
                else:
                    logs = all_rows

                logs.sort(key=lambda item: item.get("timestamp") or "", reverse=True)
                logs = logs[:limit]

        return {
            "status": "success",
            "city": requested_city,
            "data_mode": "REAL_DATASET" if logs else "NO_REAL_DATASET",
            "dataset_city": matched_dataset["dataset_city"] if matched_dataset else None,
            "matching_scope": "station_priority" if logs and matched_dataset else None,
            "total_records": len(logs),
            "records": logs,
            "message": None if logs else f"No packaged historical flood dataset is currently mapped to {requested_city}.",
        }
    except Exception as e:
        return {
            "status": "error",
            "message": str(e),
            "records": []
        }

@app.get("/sensors")
async def get_sensors(station: str = "Kolhapur", state: str = "Maharashtra"):
    """
    Tactical telemetry endpoint for the frontend "Telemetry" tab.
    """
    telemetry = build_policy_bound_telemetry(state_name=state, station_name=station)
    persist_telemetry_record(state, station, 6, telemetry, "/sensors")
    return telemetry.get("data", [])

@app.get("/api/live-telemetry")
async def get_live_telemetry(state: str = "Maharashtra", station: str = "Kolhapur", limit: int = 6):
    """
    Returns formatted CWC telemetry similar to the provided Node/Express interceptor design.
    """
    telemetry = build_policy_bound_telemetry(state_name=state, station_name=station, limit=limit)
    snapshot_id = persist_telemetry_record(state, station, limit, telemetry, "/api/live-telemetry")
    telemetry["snapshot_id"] = snapshot_id
    return telemetry

@app.get("/cwc-live-data")
async def get_cwc_live_data(station: str = "Kolhapur"):
    """
    Fetch live CWC river level data for a monitoring station
    """
    try:
        source_policy = get_source_policy_payload()
        if not source_policy.get("allow_live_cwc_in_app"):
            return {
                "status": "policy_locked",
                "station": station,
                "message": source_policy["description"],
                "source_policy": source_policy,
                "timestamp": datetime.datetime.now().isoformat(),
            }

        live_data = cwc_scraper.get_live_river_level(station)
        
        if live_data.get("status") in ["success", "success_fallback"]:
            return {
                "status": "success",
                "station": station,
                "current_level_m": live_data.get("current_level_m"),
                "source": live_data.get("source"),
                "source_policy": source_policy,
                "timestamp": datetime.datetime.now().isoformat(),
                "api": "CWC Official"
            }
        else:
            return {
                "status": "error",
                "station": station,
                "message": "Unable to fetch live CWC data",
                "source_policy": source_policy,
                "timestamp": datetime.datetime.now().isoformat()
            }
    except Exception as e:
        return {
            "status": "error",
            "station": station,
            "message": str(e),
            "source_policy": get_source_policy_payload(),
            "timestamp": datetime.datetime.now().isoformat()
        }


@app.get("/weather/current")
async def get_weather_current(city: str | None = None, lat: float | None = None, lon: float | None = None):
    if city:
        cleaned_city = city.strip()
        return resilient_openweather(
            "/data/2.5/weather",
            {"q": cleaned_city, "units": "metric"},
            fallback_factory=lambda exc: (
                resilient_openweather(
                    "/data/2.5/weather",
                    {
                        "lat": resolve_weather_location(cleaned_city)["lat"],
                        "lon": resolve_weather_location(cleaned_city)["lon"],
                        "units": "metric",
                    },
                    fallback_factory=lambda _: build_fallback_current_weather(
                        city=cleaned_city,
                        lat=resolve_weather_location(cleaned_city)["lat"],
                        lon=resolve_weather_location(cleaned_city)["lon"],
                        reason=f"FALLBACK_AFTER_{exc.status_code}",
                    ),
                )
                if resolve_weather_location(cleaned_city)
                else build_fallback_current_weather(
                    city=cleaned_city,
                    reason=f"FALLBACK_AFTER_{exc.status_code}",
                )
            ),
        )

    if lat is not None and lon is not None:
        return resilient_openweather(
            "/data/2.5/weather",
            {"lat": lat, "lon": lon, "units": "metric"},
            fallback_factory=lambda exc: build_fallback_current_weather(
                lat=lat,
                lon=lon,
                reason=f"FALLBACK_AFTER_{exc.status_code}",
            ),
        )

    raise HTTPException(status_code=400, detail="Provide either city or lat/lon")


@app.get("/weather/search")
async def search_weather_locations(query: str, limit: int = 5):
    cleaned_query = (query or "").strip()
    if not cleaned_query:
        return []

    return resilient_openweather(
        "/geo/1.0/direct",
        {"q": cleaned_query, "limit": max(1, min(limit, 10))},
        fallback_factory=lambda exc: build_fallback_search_results(cleaned_query, limit=max(1, min(limit, 10))),
    )


@app.get("/weather/reverse-geocode")
async def reverse_geocode_weather_location(lat: float, lon: float, limit: int = 1):
    return resilient_openweather(
        "/geo/1.0/reverse",
        {"lat": lat, "lon": lon, "limit": max(1, min(limit, 5))},
        fallback_factory=lambda exc: build_fallback_reverse_geocode(lat, lon, limit=max(1, min(limit, 5))),
    )


@app.get("/weather/forecast")
async def get_weather_forecast(city: str):
    cleaned_city = city.strip()
    return resilient_openweather(
        "/data/2.5/forecast",
        {"q": cleaned_city, "units": "metric"},
        fallback_factory=lambda exc: (
            build_fallback_forecast(
                city=cleaned_city,
                lat=(resolve_weather_location(cleaned_city) or {}).get("lat"),
                lon=(resolve_weather_location(cleaned_city) or {}).get("lon"),
            )
        ),
    )


@app.get("/weather/air-quality")
async def get_air_quality(lat: float, lon: float):
    return resilient_openweather(
        "/data/2.5/air_pollution",
        {"lat": lat, "lon": lon},
        fallback_factory=lambda exc: build_fallback_air_quality(lat, lon),
    )


@app.get("/weather/uv")
async def get_uv_index(lat: float, lon: float):
    data = resilient_openweather(
        "/data/3.0/onecall",
        {
            "lat": lat,
            "lon": lon,
            "units": "metric",
            "exclude": "minutely,hourly,daily,alerts",
        },
        fallback_factory=lambda exc: {"current": {"uvi": build_fallback_uv_index(lat, lon)}},
    )
    return {"uvi": data.get("current", {}).get("uvi", 0)}


@app.get("/weather/historical")
async def get_historical_weather(lat: float, lon: float, dt: int | None = None):
    timestamp = dt or int((datetime.datetime.utcnow() - datetime.timedelta(days=1)).timestamp())
    return resilient_openweather(
        "/data/3.0/onecall/timemachine",
        {"lat": lat, "lon": lon, "dt": timestamp, "units": "metric"},
        fallback_factory=lambda exc: build_fallback_historical_weather(lat, lon, timestamp),
    )


@app.get("/weather/alerts")
async def get_weather_alerts(lat: float, lon: float):
    data = resilient_openweather(
        "/data/3.0/onecall",
        {
            "lat": lat,
            "lon": lon,
            "units": "metric",
            "exclude": "minutely,hourly,daily,current",
        },
        fallback_factory=lambda exc: {"alerts": []},
    )
    return data.get("alerts", [])

@app.get("/{path_name:path}", include_in_schema=False)
async def serve_frontend(path_name: str):
    frontend_file = resolve_frontend_asset(path_name)
    if frontend_file:
        return FileResponse(frontend_file)
    if frontend_dist_ready():
        return FileResponse(FRONTEND_INDEX_PATH)
    return JSONResponse(status_code=404, content={"error": f"The path '{path_name}' was not found."})


@app.api_route("/{path_name:path}", methods=["POST", "PUT", "DELETE", "PATCH", "OPTIONS"], include_in_schema=False)
async def catch_all(path_name: str):
    return JSONResponse(status_code=404, content={"error": f"The path '{path_name}' was not found."})

# 🖥️ FRONTEND STATIC FILES (mounted LAST after ALL API routes)
if os.path.isdir(FRONTEND_DIST_DIR):
    app.mount("/", StaticFiles(directory=FRONTEND_DIST_DIR, html=False), name="frontend")

if __name__ == "__main__":
    print(" Starting INDIA_FLOODS ML Backend...")
    port = int(os.environ.get("PORT", 8000))
    module = "backend.app:app" if (__package__ and __package__.startswith("backend")) else "app:app"
    uvicorn.run(module, host="0.0.0.0", port=port, reload=True)
