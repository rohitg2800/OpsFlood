"""
Ingestion router: Data pipeline and ingestion scheduling endpoints.
"""

import asyncio
from fastapi import APIRouter

from .dependencies import (
    current_timestamp_iso,
)

router = APIRouter(prefix="/ingestion", tags=["ingestion"])

@router.get("/status")
async def get_ingestion_status(
    data_pipeline = None,
    data_ingestion_scheduler = None,
):
    """Get data ingestion scheduler status."""
    if data_pipeline:
        # Assume this updates targets
        pass
    
    return {
        "status": "success",
        "scheduler": data_ingestion_scheduler.status() if data_ingestion_scheduler else {},
        "time": current_timestamp_iso(),
    }

@router.post("/run")
async def run_ingestion_now(
    data_pipeline = None,
    data_ingestion_scheduler = None,
):
    """Trigger data ingestion immediately."""
    if data_pipeline:
        # Assume this updates targets
        pass
    
    if not data_ingestion_scheduler:
        return {
            "status": "error",
            "result": {"status": "scheduler_not_available"},
            "time": current_timestamp_iso(),
        }
    
    result = await asyncio.to_thread(data_ingestion_scheduler.trigger_now)
    return {
        "status": "success" if result.get("status") == "success" else result.get("status"),
        "result": result,
        "time": current_timestamp_iso(),
    }
