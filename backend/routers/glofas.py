# backend/routers/glofas.py
#
# OpsFlood — GET /api/glofas
#
# Called by Flutter BackendApiService.fetchGloFAS().
# Accepts a comma-separated list of lats, lons and city names,
# returns river discharge + mean discharge for each coordinate.
#
# The backend already maintains a warm in-memory GloFAS cache
# (GLOFAS_STATION_CACHE in app.py) for the fixed state-capital stations.
# For arbitrary per-city lat/lon queries from the Flutter app we hit
# flood-api.open-meteo.com directly (with a short in-process TTL cache
# so we don't hammer it when 60+ cities are requested at once).

from __future__ import annotations

import asyncio
import logging
import time
from typing import Any, Dict, List, Optional

import httpx
from fastapi import APIRouter, Query, HTTPException

logger = logging.getLogger("opsflood.glofas")

router = APIRouter()

# ── in-process TTL cache ──────────────────────────────────────────────────
# Key: (lat_rounded_3dp, lon_rounded_3dp) → {discharge, discharge_mean, ts}
_CACHE: Dict[tuple, Dict[str, Any]] = {}
_CACHE_TTL_SECONDS = 900  # 15 min — same as WRD Bihar

GLOFAS_API_URL = "https://flood-api.open-meteo.com/v1/flood"
_HTTP_TIMEOUT   = 20.0
_SEMAPHORE      = asyncio.Semaphore(10)  # max 10 concurrent upstream calls


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
    """Fetch current + ensemble-mean river discharge from GloFAS Open-Meteo."""
    cached = _cache_get(lat, lon)
    if cached:
        return cached

    async with _SEMAPHORE:
        try:
            resp = await client.get(
                GLOFAS_API_URL,
                params={
                    "latitude":     lat,
                    "longitude":    lon,
                    "daily":        "river_discharge,river_discharge_mean",
                    "forecast_days": 1,
                    "ensemble":     "true",
                },
                timeout=_HTTP_TIMEOUT,
            )
            resp.raise_for_status()
            body   = resp.json()
            daily  = body.get("daily") or {}
            q_list = daily.get("river_discharge")      or []
            m_list = daily.get("river_discharge_mean") or []

            discharge      = float(q_list[0]) if q_list else None
            discharge_mean = float(m_list[0]) if m_list else None

            result = {"discharge": discharge, "discharge_mean": discharge_mean}
            _cache_set(lat, lon, result)
            return result

        except Exception as exc:
            logger.warning(f"[GloFAS] fetch failed ({lat},{lon}): {exc}")
            return {"discharge": None, "discharge_mean": None}


# ── route ──────────────────────────────────────────────────────────────────
@router.get("/api/glofas", tags=["glofas"])
async def get_glofas(
    lats:   str = Query(..., description="Comma-separated latitudes"),
    lons:   str = Query(..., description="Comma-separated longitudes"),
    cities: str = Query("",  description="Comma-separated city keys (lowercase)"),
) -> List[Dict[str, Any]]:
    """
    Return GloFAS river discharge for each (lat, lon) pair.

    Response shape (one item per coordinate, same order as input):
    [
      { "city": "gandhighat", "discharge": 1234.5, "discharge_mean": 950.0 },
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

    # Pad city list if not provided
    while len(city_list) < len(lat_list):
        city_list.append(f"city_{len(city_list)}")

    async with httpx.AsyncClient() as client:
        tasks   = [_fetch_one(client, lat, lon) for lat, lon in zip(lat_list, lon_list)]
        results = await asyncio.gather(*tasks)

    return [
        {
            "city":           city_list[i],
            "discharge":      results[i]["discharge"],
            "discharge_mean": results[i]["discharge_mean"],
        }
        for i in range(len(lat_list))
    ]
