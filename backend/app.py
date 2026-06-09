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
import logging

logger = logging.getLogger("opsflood")

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

import requests
from bs4 import BeautifulSoup
import datetime

import importlib.util as _importlib_util


def _is_package_context() -> bool:
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
    from backend.routers.wrd_bihar import start_scheduler as wrd_start_scheduler
    from backend.routers.wrd_bihar import stop_scheduler as wrd_stop_scheduler
    from backend.routers.cwc_ffs import router as cwc_ffs_router
    from backend.routers.fcm import router as fcm_router
    from backend.routers.data_gov_cwc import router as data_gov_cwc_router
    from backend.routers.model_artifacts import router as model_artifacts_router
else:
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
    from routers.wrd_bihar import start_scheduler as wrd_start_scheduler
    from routers.wrd_bihar import stop_scheduler as wrd_stop_scheduler
    from routers.cwc_ffs import router as cwc_ffs_router
    from routers.fcm import router as fcm_router
    from routers.data_gov_cwc import router as data_gov_cwc_router
    from routers.model_artifacts import router as model_artifacts_router


warnings.filterwarnings('ignore')
operational_store = PostgresOperationalStore()
operational_store.initialize()

SOURCE_POLICY_MODES = {"OPEN_DATA", "OFFICIAL_VIEW_ONLY", "FALLBACK"}


def env_flag(key: str, default: bool = False) -> bool:
    val = os.getenv(key, "").strip().lower()
    if val in ("1", "true", "yes"):
        return True
    if val in ("0", "false", "no"):
        return False
    return default


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
        print(f"\u26a0\ufe0f Audit log persistence failed: {exc}")
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
        print(f"\u26a0\ufe0f Prediction persistence failed: {exc}")
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
        print(f"\u26a0\ufe0f Telemetry snapshot persistence failed: {exc}")
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
        pass  # live CWC telemetry path — implemented in routers/telemetry.py
    return policy


# ── FastAPI application ────────────────────────────────────────────────────────

app = FastAPI(
    title="OpsFlood API",
    description="Flood monitoring, prediction and telemetry backend for the Android Flood App.",
    version="1.1.0",
)

# CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ── Router registrations ───────────────────────────────────────────────────────
app.include_router(core_router)
app.include_router(predict_router)
app.include_router(weather_router)
app.include_router(telemetry_router)
app.include_router(ingestion_router)
app.include_router(live_levels_router)
app.include_router(wrd_bihar_router)
app.include_router(cwc_ffs_router)
app.include_router(fcm_router)
app.include_router(data_gov_cwc_router)
app.include_router(model_artifacts_router)


# ── Startup / shutdown ─────────────────────────────────────────────────────────

@app.on_event("startup")
async def startup_event():
    logger.info("OpsFlood API starting up — version 1.1.0")
    try:
        wrd_start_scheduler()
        logger.info("WRD Bihar scheduler started")
    except Exception as exc:
        logger.warning(f"WRD Bihar scheduler start failed (non-fatal): {exc}")


@app.on_event("shutdown")
async def shutdown_event():
    logger.info("OpsFlood API shutting down")
    try:
        wrd_stop_scheduler()
    except Exception as exc:
        logger.warning(f"WRD Bihar scheduler stop failed (non-fatal): {exc}")


# ── Health check ───────────────────────────────────────────────────────────────

@app.get("/health")
async def health():
    return {"status": "ok", "version": "1.1.0", "timestamp": current_timestamp_iso()}


@app.get("/api/source-policy")
async def source_policy():
    return get_source_policy_payload()


# ── Static frontend (serve React/Vite build) ───────────────────────────────────

if os.path.isdir(FRONTEND_DIST_DIR):
    app.mount("/assets", StaticFiles(directory=os.path.join(FRONTEND_DIST_DIR, "assets")), name="assets")

    @app.get("/{full_path:path}", include_in_schema=False)
    async def serve_frontend(full_path: str):
        file_path = os.path.join(FRONTEND_DIST_DIR, full_path)
        if os.path.isfile(file_path):
            return FileResponse(file_path)
        return FileResponse(FRONTEND_INDEX_PATH)
