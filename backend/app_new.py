"""
INDIA_FLOODS ML Backend - Refactored Main Application

This is the main FastAPI application with modular routers for:
- Core (health, root, source-policy)
- Prediction (ML predictions, artifacts, severity matrix)
- Weather (OpenWeatherMap integration)
- Telemetry (live data, audit logs, historical logs)
- Ingestion (data pipeline and scheduling)
"""

import os
import warnings
import uvicorn
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse, JSONResponse

# Import all router modules
from routers.core import router as core_router
from routers.predict import router as predict_router, FloodPredictionInput
from routers.weather import router as weather_router
from routers.telemetry import router as telemetry_router
from routers.ingestion import router as ingestion_router

# Import shared dependencies
from routers.dependencies import (
    refresh_backend_env,
    configured_cors_origins,
    operational_store,
    frontend_dist_ready,
    FRONTEND_INDEX_PATH,
    resolve_frontend_asset,
    BASE_DIR,
    REPO_DIR,
    env_flag,
    get_data_ingestion_targets,
)

# Import large classes and services
from backend.data_pipeline import IngestionTarget, OperationalDataPipeline, ScheduledIngestionService
from backend.state_severity_matrix import (
    STATE_SEVERITY_MATRIX,
    get_state_severity_entry,
    severity_from_entry,
)

# For CWC Scraper - will be imported from original app location
# and adapted for compatibility
import requests
from bs4 import BeautifulSoup
import datetime
from sklearn.ensemble import RandomForestClassifier
from sklearn.preprocessing import StandardScaler
from sklearn.model_selection import train_test_split
from sklearn.metrics import accuracy_score
import joblib
import numpy as np

warnings.filterwarnings('ignore')

# ============= FASTAPI APP SETUP =============
app = FastAPI(title="🌧️ INDIA_FLOODS ML API", version="8.5")

# Configure CORS
cors_origins = configured_cors_origins()
app.add_middleware(
    CORSMiddleware,
    allow_origins=cors_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ============= EXTRACT CWC SCRAPER CLASS =============
# This class is needed for live telemetry and prediction
class CWCRiverScraper:
    """CWC river level scraper with tactical fallback."""
    
    def __init__(self):
        self.cwc_api_base = "https://ffs.india-water.gov.in/iam/api"
        self.headers = {
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"
        }
        self.connect_timeout_seconds = max(1.0, float(os.getenv("CWC_CONNECT_TIMEOUT_SECONDS") or 3))
        self.read_timeout_seconds = max(1.0, float(os.getenv("CWC_READ_TIMEOUT_SECONDS") or 8))
        self._last_telemetry_error_message = ""
        self._last_telemetry_error_log_at = None
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

    def _format_request_error(self, exc: requests.RequestException) -> str:
        if isinstance(exc, requests.ConnectTimeout):
            return "connect timeout"
        if isinstance(exc, requests.ReadTimeout):
            return "read timeout"
        if isinstance(exc, requests.SSLError):
            return "tls error"
        if isinstance(exc, requests.ConnectionError):
            return "connection error"

        compact = " ".join(str(exc).split())
        if len(compact) > 180:
            compact = f"{compact[:177]}..."
        return f"{exc.__class__.__name__}: {compact}"

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
        host_connect_timeout = False

        for path in candidate_paths:
            try:
                response = requests.get(
                    f"{self.cwc_api_base}{path}",
                    headers=self.headers,
                    timeout=(self.connect_timeout_seconds, self.read_timeout_seconds),
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
            except requests.ConnectTimeout:
                failures.append(f"{path}: connect timeout")
                host_connect_timeout = True
                break
            except requests.RequestException as exc:
                failures.append(f"{path}: {self._format_request_error(exc)}")
            except Exception as exc:
                failures.append(f"{path}: unexpected {exc.__class__.__name__}")

        failure_summary = " ; ".join(failures)
        if host_connect_timeout:
            cooldown_seconds = 300
        else:
            cooldown_seconds = 900 if failures and all(": 404" in failure for failure in failures) else 180
        self._remember_station_feed_failure(failure_summary, cooldown_seconds)
        raise RuntimeError(failure_summary)

    def _remember_station_feed_failure(self, message: str, cooldown_seconds: int):
        self._station_feed_failure_message = message
        self._station_feed_retry_after = datetime.datetime.now() + datetime.timedelta(seconds=max(30, cooldown_seconds))

    def _clear_station_feed_failure(self):
        self._station_feed_failure_message = ""
        self._station_feed_retry_after = None

    def _site_priority(self, site, target_state: str, target_station: str) -> int:
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

# Initialize CWC Scraper
cwc_scraper = CWCRiverScraper()

# ============= PLACEHOLDER PREDICTOR CLASS =============
# In production, this would be the full KolhapurFloodPredictor from the original app.py
# For now, it's a minimal implementation
class KolhapurFloodPredictor:
    """Placeholder flood predictor - extend with full ML logic from original app.py"""
    
    def __init__(self):
        self.is_trained = False
        self.artifact_catalog = []
        self.artifact_bundles = {}
        self.artifact_store_dir = ""
        self.artifact_storage_backend = "DVC"
        self.default_bundle_key = "flood"
        self.default_model_paths = ("", "")
    
    def refresh_artifact_catalog(self):
        pass
    
    def describe_state_model_artifacts(self, state_name: str):
        return {
            "state": state_name,
            "bundle_key": self.default_bundle_key,
        }
    
    async def predict(self, input_data, source: str = "Manual Input"):
        # Placeholder fallback prediction
        return {
            "severity": "MODERATE",
            "confidence_percent": 75.0,
            "probabilities": {"SEVERE": 25, "MODERATE": 75, "LOW": 0, "CRITICAL": 0},
            "alert": "⚠️",
            "algorithm": "Fallback",
            "data_source": source,
            "model_trained": False,
            "risk_score": 50,
        }

predictor = KolhapurFloodPredictor()

# ============= DATA INGESTION SETUP =============
data_pipeline = OperationalDataPipeline(
    repo_dir=REPO_DIR,
    weather_fetcher=None,  # Would be build_weather_ingestion_snapshot
    water_level_fetcher=None,  # Would be build_water_level_ingestion_snapshot
    audit_logger=None,  # Would be write_audit_log
    targets=get_data_ingestion_targets(),
)

data_ingestion_scheduler = ScheduledIngestionService(
    pipeline=data_pipeline,
    interval_seconds=max(60, int(float(os.getenv("DATA_INGESTION_INTERVAL_MINUTES") or 60) * 60)),
    enabled=env_flag("ENABLE_DATA_INGESTION_SCHEDULER", default=False),
    run_on_startup=env_flag("DATA_INGESTION_RUN_ON_STARTUP", default=True),
)

# ============= REGISTER ROUTERS =============
app.include_router(core_router)
app.include_router(predict_router)
app.include_router(weather_router)
app.include_router(telemetry_router)
app.include_router(ingestion_router)

# ============= FRONTEND SERVING =============
@app.get("/{path_name:path}", include_in_schema=False)
async def serve_frontend(path_name: str):
    """Serve frontend assets or fall back to index.html."""
    frontend_file = resolve_frontend_asset(path_name)
    if frontend_file:
        return FileResponse(frontend_file)
    if frontend_dist_ready():
        return FileResponse(FRONTEND_INDEX_PATH)
    return JSONResponse(status_code=404, content={"error": f"The path '{path_name}' was not found."})

@app.api_route("/{path_name:path}", methods=["POST", "PUT", "DELETE", "PATCH", "OPTIONS"], include_in_schema=False)
async def catch_all(path_name: str):
    """Catch unmatched API routes."""
    return JSONResponse(status_code=404, content={"error": f"The path '{path_name}' was not found."})

# ============= STARTUP/SHUTDOWN =============
@app.on_event("startup")
async def startup_event():
    """Application startup event."""
    print("🚀 INDIA_FLOODS ML Backend starting...")
    predictor.refresh_artifact_catalog()
    print(f"📦 Loaded {len(predictor.artifact_catalog)} artifacts")
    print(f"✅ Backend ready")

@app.on_event("shutdown")
async def shutdown_event():
    """Application shutdown event."""
    print("🛑 INDIA_FLOODS ML Backend shutting down...")

# ============= MAIN =============
if __name__ == "__main__":
    print("Starting INDIA_FLOODS ML Backend...")
    port = int(os.environ.get("PORT", 8000))
    module = "backend.app:app" if (__package__ and __package__.startswith("backend")) else "app:app"
    uvicorn.run(module, host="0.0.0.0", port=port, reload=True)
