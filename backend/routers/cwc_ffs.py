"""
backend/routers/cwc_ffs.py
--------------------------
Proxy + normaliser for the CWC Flood Forecast System (FFS).
Source: https://ffs.india-water.gov.in/flood_situation_report.php

The FFS portal is a public Government of India resource.
This router scrapes the HTML flood situation table, normalises it
to JSON, and caches it in memory for FFS_CACHE_SECONDS (15 min)
to avoid hammering the CWC servers.

Endpoints
---------
GET /api/cwc-ffs                  - all stations currently in alert
GET /api/cwc-ffs/state            - ?state=Maharashtra
GET /api/cwc-ffs/station          - ?name=Kolhapur  (fuzzy match)
GET /api/cwc-ffs/detail           - ?code=ST001     (exact station code)
"""
import time
import logging
from difflib import get_close_matches
from typing import Optional

import httpx
from bs4 import BeautifulSoup
from fastapi import APIRouter, Query, HTTPException

from backend.config import CWC_FFS_BASE_URL, CWC_FFS_REPORT_PATH, FFS_CACHE_SECONDS

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/api/cwc-ffs", tags=["CWC FFS"])

# ── In-memory cache ────────────────────────────────────────────────────────────
_ffs_cache: list[dict] = []
_ffs_cache_ts: float   = 0.0


async def _fetch_ffs_stations() -> list[dict]:
    """Fetch and parse the CWC FFS flood situation HTML table."""
    global _ffs_cache, _ffs_cache_ts

    now = time.time()
    if _ffs_cache and (now - _ffs_cache_ts) < FFS_CACHE_SECONDS:
        return _ffs_cache

    url = f"{CWC_FFS_BASE_URL}{CWC_FFS_REPORT_PATH}"
    try:
        async with httpx.AsyncClient(timeout=20, follow_redirects=True) as client:
            resp = await client.get(url, headers={"User-Agent": "OpsFlood/1.0 (flood monitoring)"})
            resp.raise_for_status()
    except Exception as exc:
        logger.warning("CWC FFS fetch failed: %s", exc)
        return _ffs_cache  # return stale cache on failure

    soup = BeautifulSoup(resp.text, "html.parser")
    stations: list[dict] = []

    # CWC FFS renders a table with columns:
    # Station | River | State | Obs Level | Danger Level | Warning Level | Trend | Alert | Forecast
    table = soup.find("table", {"class": lambda c: c and "flood" in c.lower()}) \
            or soup.find("table")

    if table is None:
        logger.warning("CWC FFS: no table found in response")
        return _ffs_cache

    rows = table.find_all("tr")
    headers: list[str] = []

    for row in rows:
        cells = [td.get_text(strip=True) for td in row.find_all(["td", "th"])]
        if not cells:
            continue

        # Detect header row
        if not headers:
            lower = [c.lower() for c in cells]
            if any(k in " ".join(lower) for k in ["station", "river", "level"]):
                headers = lower
                continue

        if len(cells) < 4:
            continue

        def _col(keywords: list[str], default: str = "") -> str:
            for kw in keywords:
                for i, h in enumerate(headers):
                    if kw in h and i < len(cells):
                        return cells[i].strip()
            return default

        def _flt(val: str) -> Optional[float]:
            try:
                return float(val.replace(",", ""))
            except (ValueError, AttributeError):
                return None

        station_name  = _col(["station", "name"], cells[0] if cells else "")
        river         = _col(["river"])
        state         = _col(["state"])
        obs_level     = _flt(_col(["obs", "current", "level"]))
        danger_level  = _flt(_col(["danger"]))
        warning_level = _flt(_col(["warning"]))
        trend_raw     = _col(["trend"]).lower()
        alert_raw     = _col(["alert", "colour", "color", "status"]).lower()
        forecast      = _col(["forecast", "remark"])

        trend = "rising" if "ris" in trend_raw else \
                "falling" if "fall" in trend_raw else "steady"

        alert_colour = "red"    if any(x in alert_raw for x in ["red",  "critical"]) else \
                       "orange" if any(x in alert_raw for x in ["orange", "severe"])  else \
                       "yellow" if any(x in alert_raw for x in ["yellow", "warning", "moderate"]) else \
                       "green"

        if obs_level is None:
            continue

        stations.append({
            "station_name":   station_name,
            "river":          river,
            "state":          state,
            "current_level":  obs_level,
            "danger_level":   danger_level or 0.0,
            "warning_level":  warning_level or 0.0,
            "alert_colour":   alert_colour,
            "trend":          trend,
            "forecast":       forecast or None,
            "observed_at":    time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        })

    if stations:
        _ffs_cache    = stations
        _ffs_cache_ts = now

    return _ffs_cache


# ── Routes ─────────────────────────────────────────────────────────────────────

@router.get("", summary="All CWC FFS alert stations")
async def get_all_ffs(
    alert_only: bool = Query(False, description="If true, only return stations above warning level"),
):
    stations = await _fetch_ffs_stations()
    if alert_only:
        stations = [s for s in stations if s["alert_colour"] in ("red", "orange", "yellow")]
    return {"status": "success", "count": len(stations), "data": stations}


@router.get("/state", summary="CWC FFS stations for a state")
async def get_ffs_by_state(
    state: str = Query(..., description="Indian state name, e.g. Maharashtra"),
    alert_only: bool = Query(False),
):
    stations = await _fetch_ffs_stations()
    filtered = [
        s for s in stations
        if state.lower() in s["state"].lower()
    ]
    if alert_only:
        filtered = [s for s in filtered if s["alert_colour"] in ("red", "orange", "yellow")]
    return {"status": "success", "state": state, "count": len(filtered), "data": filtered}


@router.get("/station", summary="CWC FFS data for a named station (fuzzy match)")
async def get_ffs_by_station(
    name: str  = Query(..., description="Station name, e.g. Kolhapur"),
    city: str  = Query("", description="Alias for name"),
    state: str = Query(""),
):
    query   = name or city
    all_stn = await _fetch_ffs_stations()

    if state:
        all_stn = [s for s in all_stn if state.lower() in s["state"].lower()]

    names   = [s["station_name"] for s in all_stn]
    matches = get_close_matches(query, names, n=3, cutoff=0.4)

    if not matches:
        # fallback: substring match
        matches_subs = [s for s in all_stn if query.lower() in s["station_name"].lower()]
        return {"status": "success", "query": query, "count": len(matches_subs), "data": matches_subs}

    result = [s for s in all_stn if s["station_name"] in matches]
    return {"status": "success", "query": query, "count": len(result), "data": result}


@router.get("/detail", summary="CWC FFS station detail by station code")
async def get_ffs_detail(
    code: str = Query(..., description="CWC station code"),
):
    all_stn = await _fetch_ffs_stations()
    match   = next(
        (s for s in all_stn if s.get("station_code", "").upper() == code.upper()),
        None,
    )
    if not match:
        raise HTTPException(status_code=404, detail=f"Station code '{code}' not found")
    return {"status": "success", "data": match}
