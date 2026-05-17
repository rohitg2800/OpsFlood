"""
Core router: Health checks, root endpoint, and system status endpoints.
"""

from fastapi import APIRouter
from fastapi.responses import FileResponse, JSONResponse
import datetime

from .dependencies import (
    frontend_dist_ready,
    FRONTEND_INDEX_PATH,
    current_timestamp_iso,
    get_source_policy_payload,
    operational_store,
)

router = APIRouter()

@router.get("/", include_in_schema=False)
async def root():
    """Root endpoint: serve frontend or return API status."""
    if frontend_dist_ready():
        return FileResponse(FRONTEND_INDEX_PATH)

    return {
        "service": "INDIA_FLOODS ML Server",
        "status": "Online",
        "model_ready": True,  # Will be set from main app
        "source_policy": get_source_policy_payload(),
    }

@router.get("/health")
def health(
    predictor = None,  # Dependency injection from main app
    data_ingestion_scheduler = None,
    artifact_count = 0,
    bundle_count = 0,
):
    """Health check endpoint with system status."""
    return {
        "status": "ok",
        "service": "INDIA_FLOODS ML Server",
        "model_ready": predictor.is_trained if predictor else False,
        "database": operational_store.status(),
        "ingestion": data_ingestion_scheduler.status() if data_ingestion_scheduler else {},
        "artifact_count": artifact_count,
        "bundle_count": bundle_count,
        "version": "8.5",
        "source_policy": get_source_policy_payload(),
        "time": datetime.datetime.now().isoformat(),
    }

@router.get("/source-policy")
async def get_source_policy():
    """Get current source policy configuration."""
    return {
        "status": "success",
        "source_policy": get_source_policy_payload(),
        "time": datetime.datetime.now().isoformat(),
    }
