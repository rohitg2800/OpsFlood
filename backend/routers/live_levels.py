"""
backend/routers/live_levels.py — merged live levels (Bihar WRD + national)
"""
from typing import Optional
from fastapi import APIRouter, Query
from ..app import _get_data

router = APIRouter(tags=["Live Levels"])

@router.get("/api/live-levels-v2")
async def live_levels_v2(state: Optional[str] = Query(None)):
    data = await _get_data()
    if state: data = [d for d in data if state.lower() in d.get("state","").lower()]
    return {"status": "success", "count": len(data), "data": data}
