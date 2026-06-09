# backend/routers/rainfall.py
#
# OpsFlood — GET /api/rainfall
#
# Called by Flutter BackendApiService.fetchRainfall().
# Accepts a comma-separated list of lats, lons and city names,
# returns total 24-hour accumulated precipitation (mm) for each coordinate
# from the Open-Meteo weather API.

from __future__ import annotations

import asyncio
import logging
import time
from typing import Any, Dict, List, Optional

import httpx
from fastapi import APIRouter, Query, HTTPException

logger = logging.getLogger("opsflood.rainfall")

router = APIRouter()

# ── in-process TTL cache ──────────────────────────────────────────────────
_CACHE: Dict[tuple, Dict[str, Any]] = {}
_CACHE_TTL_SECONDS = 900  # 15 min

OPEN_METEO_URL = "https://api.open-meteo.com/v1/forecast"
_HTTP_TIMEOUT  = 20.0
_SEMAPHORE     = asyncio.Semaphore(10)


def _cache_key(lat: float, lon: float) -> tuple:
    return (round(lat, 3), round(lon, 3))


def _cache_get(lat: float, lon: float) -> Optional[Dict[str, Any]]:
    entry = _CACHE.get(_cache_key(lat, lon))
    if entry and (time.time() - entry["_ts"]) < _CACHE_TTL_SECONDS:
        return entry
    return None


def _cache_set(lat: float, lon: float, data: Dict[str, Any]) -> None:
    _CACHE[_cache_key(lat, lon)] = {**data, "_ts": time.time()}


# ── upstream fetch ─────────────────────────────────────────────────────────
async def _fetch_one(client: httpx.AsyncClient, lat: float, lon: float) -> Dict[str, Any]:
    """Fetch 24-hour accumulated precipitation from Open-Meteo."""
    cached = _cache_get(lat, lon)
    if cached:
        return cached

    async with _SEMAPHORE:
        try:
            resp = await client.get(
                OPEN_METEO_URL,
                params={
                    "latitude":       lat,
                    "longitude":      lon,
                    "daily":          "precipitation_sum",
                    "forecast_days":  1,
                    "timezone":       "Asia/Kolkata",
                },
                timeout=_HTTP_TIMEOUT,
            )
            resp.raise_for_status()
            body      = resp.json()
            daily     = body.get("daily") or {}
            rain_list = daily.get("precipitation_sum") or []

            rainfall24h = float(rain_list[0]) if rain_list else None

            result = {"rainfall24h": rainfall24h}
            _cache_set(lat, lon, result)
            return result

        except Exception as exc:
            logger.warning(f"[Rainfall] fetch failed ({lat},{lon}): {exc}")
            return {"rainfall24h": None}


# ── route ──────────────────────────────────────────────────────────────────
@router.get("/api/rainfall", tags=["rainfall"])
async def get_rainfall(
    lats:   str = Query(..., description="Comma-separated latitudes"),
    lons:   str = Query(..., description="Comma-separated longitudes"),
    cities: str = Query("",  description="Comma-separated city keys (lowercase)"),
) -> List[Dict[str, Any]]:
    """
    Return 24-hour precipitation total (mm) for each (lat, lon) pair.

    Response shape (one item per coordinate, same order as input):
    [
      { "city": "gandhighat", "rainfall24h": 12.4 },
      ...
    ]
    """
    try:
        lat_list  = [float(v.strip()) for v in lats.split(",")  if v.strip()]
        lon_list  = [float(v.strip()) for v in lons.split(",")  if v.strip()]
        city_list = [v.strip()        for v in cities.split(",") if v.strip()]
    except ValueError as exc:
        raise HTTPException(status_code=422, detail=f"Invalid lat/lon values: {exc}")

    if not lat_list or len(lat_list) != len(lon_list):
        raise HTTPException(
            status_code=422,
            detail=f"lats and lons must be non-empty and equal length "
                   f"(got {len(lat_list)} vs {len(lon_list)})",
        )

    # Pad city list if shorter than coordinates
    while len(city_list) < len(lat_list):
        city_list.append(f"city_{len(city_list)}")

    async with httpx.AsyncClient() as client:
        tasks   = [_fetch_one(client, lat, lon) for lat, lon in zip(lat_list, lon_list)]
        results = await asyncio.gather(*tasks)

    return [
        {
            "city":       city_list[i],
            "rainfall24h": results[i]["rainfall24h"],
        }
        for i in range(len(lat_list))
    ]
