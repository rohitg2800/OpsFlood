# backend/routers package
# Exported routers — imported in backend/app.py
from .core import router as core_router
from .predict import router as predict_router
from .weather import router as weather_router
from .telemetry import router as telemetry_router
from .ingestion import router as ingestion_router
from .live_levels import router as live_levels_router
from .fcm import router as fcm_router

__all__ = [
    "core_router",
    "predict_router",
    "weather_router",
    "telemetry_router",
    "ingestion_router",
    "live_levels_router",
    "fcm_router",
]
