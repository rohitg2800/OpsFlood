"""
backend/routers/wrd_bihar.py — /api/wrd-bihar/* router
"""
import time
from typing import Optional
from fastapi import APIRouter, Query
from ..wrd_bihar_scraper import scrape_wrd_bihar, BIHAR_STATIONS

router = APIRouter(prefix="/api/wrd-bihar", tags=["WRD Bihar"])
_cache: dict = {}
_TTL = 600

async def _get():
    now = time.time()
    if _cache.get("data") and now - _cache.get("ts", 0) < _TTL:
        return _cache["data"]
    data = await scrape_wrd_bihar()
    _cache["data"] = data
    _cache["ts"]   = now
    return data

@router.get("/stations")
async def wrd_stations(district: Optional[str] = Query(None), status: Optional[str] = Query(None), river: Optional[str] = Query(None)):
    data = await _get()
    if district: data = [d for d in data if district.lower() in d["district"].lower()]
    if status:   data = [d for d in data if d["status"] == status.lower()]
    if river:    data = [d for d in data if river.lower() in d["river"].lower()]
    return {"status": "success", "count": len(data), "data": data}

@router.get("/alerts")
async def wrd_alerts():
    data = await _get()
    alerts = sorted([d for d in data if d["status"] != "normal"], key=lambda x: 0 if x["status"] == "danger" else 1)
    return {"status": "success", "count": len(alerts), "data": alerts}

@router.get("/summary")
async def wrd_summary():
    data = await _get()
    return {"status": "success", "total": len(data),
            "normal": sum(1 for d in data if d["status"]=="normal"),
            "warning": sum(1 for d in data if d["status"]=="warning"),
            "danger": sum(1 for d in data if d["status"]=="danger")}

@router.get("/stations/{station_id}")
async def wrd_station(station_id: str):
    data = await _get()
    match = next((d for d in data if d["id"].upper() == station_id.upper()), None)
    if not match:
        from fastapi import HTTPException
        raise HTTPException(404, "Station not found")
    return {"status": "success", "data": match}
