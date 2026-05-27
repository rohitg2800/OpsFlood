"""
backend/routers/wrd_bihar.py
-----------------------------
Live scraper for WRD Bihar flood monitoring portal.
Source: http://fldcontrolbihar.org/

Scrapes the real-time flood table published by the
Water Resources Department, Government of Bihar.

Endpoints
---------
GET /api/wrd-bihar                 - all Bihar stations (live data)
GET /api/wrd-bihar/state           - alias, always Bihar
GET /api/wrd-bihar/station         - ?name=Patna  (fuzzy match)
GET /api/wrd-bihar/danger          - stations currently above danger level
GET /api/wrd-bihar/refresh         - force-bust cache and re-fetch

TODO: Add to backend/app.py:
    from backend.routers.wrd_bihar import router as wrd_bihar_router
    app.include_router(wrd_bihar_router)
"""
import time
import logging
from difflib import get_close_matches
from typing import Optional, List, Dict, Any

import httpx
from bs4 import BeautifulSoup
from fastapi import APIRouter, Query, HTTPException

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/wrd-bihar", tags=["WRD Bihar"])

# ── Cache ──────────────────────────────────────────────────────────────────────
WRD_CACHE_SECONDS = 900          # 15 minutes
_wrd_cache: List[Dict[str, Any]] = []
_wrd_cache_ts: float = 0.0

# ── WRD Bihar URLs ─────────────────────────────────────────────────────────────
_WRD_URLS = [
    "http://fldcontrolbihar.org/",
    "http://fldcontrolbihar.org/flood_situation.php",
    "http://fldcontrolbihar.org/flood_report.php",
    "https://state.bihar.gov.in/wrd/CitizenHome.html",
]

# ── Known Bihar stations (coordinate lookup seed) ────────────────────────────────
_BIHAR_STATIONS_SEED: List[Dict[str, Any]] = [
    {"station": "Gandhi Setu / Patna", "river": "Ganga",        "lat": 25.736, "lon": 85.004},
    {"station": "Hajipur",             "river": "Gandak",       "lat": 25.686, "lon": 85.208},
    {"station": "Darbhanga",           "river": "Bagmati",      "lat": 26.152, "lon": 85.901},
    {"station": "Muzaffarpur",         "river": "Burhi Gandak", "lat": 26.121, "lon": 85.391},
    {"station": "Supaul",              "river": "Kosi",         "lat": 26.123, "lon": 86.604},
    {"station": "Bhagalpur",           "river": "Ganga",        "lat": 25.244, "lon": 87.000},
    {"station": "Sonepur",             "river": "Sone",         "lat": 25.710, "lon": 85.178},
    {"station": "Sitamarhi",           "river": "Lakhandei",    "lat": 26.592, "lon": 85.491},
    {"station": "Motihari",            "river": "Burhi Gandak", "lat": 26.649, "lon": 84.916},
    {"station": "Samastipur",          "river": "Bagmati",      "lat": 25.864, "lon": 85.781},
]


def _coord_for(station_name: str) -> Dict[str, Optional[float]]:
    name_lower = station_name.lower()
    for seed in _BIHAR_STATIONS_SEED:
        if seed["station"].lower().split("/")[0].strip() in name_lower or \
           name_lower in seed["station"].lower():
            return {"lat": seed["lat"], "lon": seed["lon"]}
    return {"lat": None, "lon": None}


def _parse_status(obs: Optional[float], danger: Optional[float], warning: Optional[float]) -> str:
    if obs is None:
        return "unknown"
    if danger is not None and obs >= danger:
        return "danger"
    if warning is not None and obs >= warning:
        return "warning"
    return "normal"


def _safe_float(text: str) -> Optional[float]:
    if not text:
        return None
    cleaned = text.strip().replace(",", "").split()[0]
    try:
        return float(cleaned)
    except (ValueError, IndexError):
        return None


def _parse_wrd_table(html: str) -> List[Dict[str, Any]]:
    soup = BeautifulSoup(html, "html.parser")
    stations: List[Dict[str, Any]] = []

    tables = soup.find_all("table")
    target_table = None
    for tbl in tables:
        text = tbl.get_text(" ").lower()
        if any(k in text for k in ["danger", "flood", "level", "station", "river"]):
            target_table = tbl
            break

    if target_table is None:
        logger.warning("WRD Bihar: no flood table found in HTML")
        return []

    rows = target_table.find_all("tr")
    if not rows:
        return []

    headers: List[str] = []
    data_rows: List[Any] = []

    for row in rows:
        cells = [td.get_text(strip=True) for td in row.find_all(["td", "th"])]
        if not cells:
            continue
        if not headers:
            lower_cells = [c.lower() for c in cells]
            if any(k in " ".join(lower_cells) for k in ["station", "river", "level", "danger"]):
                headers = lower_cells
                continue
        if headers:
            data_rows.append(cells)

    if not headers or not data_rows:
        logger.warning("WRD Bihar: table found but no parseable headers/rows")
        return []

    def col(keywords: List[str]) -> int:
        for kw in keywords:
            for i, h in enumerate(headers):
                if kw in h:
                    return i
        return -1

    idx_station = col(["station", "site", "location", "gauge"])
    idx_river   = col(["river", "stream", "nadi"])
    idx_obs     = col(["observed", "current", "obs.", "water level", "w.l", "wl"])
    idx_danger  = col(["danger", "dgl", "d.l"])
    idx_warning = col(["warning", "wgl", "w.l", "alert level"])
    idx_time    = col(["time", "date", "timestamp", "reported"])

    for row_cells in data_rows:
        if len(row_cells) < 2:
            continue

        def safe_get(idx: int) -> str:
            return row_cells[idx].strip() if 0 <= idx < len(row_cells) else ""

        station_name = safe_get(idx_station) or safe_get(0)
        if not station_name or station_name.lower() in ("", "-", "n/a", "na"):
            continue

        obs_level     = _safe_float(safe_get(idx_obs))
        danger_level  = _safe_float(safe_get(idx_danger))
        warning_level = _safe_float(safe_get(idx_warning))
        status        = _parse_status(obs_level, danger_level, warning_level)
        coords        = _coord_for(station_name)

        stations.append({
            "station":          station_name,
            "river":            safe_get(idx_river) or "—",
            "state":            "Bihar",
            "obs_level_m":      obs_level,
            "danger_level_m":   danger_level,
            "warning_level_m":  warning_level,
            "status":           status,
            "reported_at":      safe_get(idx_time) or None,
            "lat":              coords["lat"],
            "lon":              coords["lon"],
            "source":           "WRD Bihar",
        })

    return stations


async def _fetch_wrd_stations(force: bool = False) -> List[Dict[str, Any]]:
    global _wrd_cache, _wrd_cache_ts

    now = time.time()
    if not force and _wrd_cache and (now - _wrd_cache_ts) < WRD_CACHE_SECONDS:
        return _wrd_cache

    last_exc: Optional[Exception] = None
    for url in _WRD_URLS:
        try:
            async with httpx.AsyncClient(
                timeout=25,
                follow_redirects=True,
                verify=False,
            ) as client:
                resp = await client.get(
                    url,
                    headers={"User-Agent": "OpsFlood/2.0 (flood monitoring research)"},
                )
                resp.raise_for_status()

            parsed = _parse_wrd_table(resp.text)
            if parsed:
                _wrd_cache    = parsed
                _wrd_cache_ts = now
                logger.info("WRD Bihar: fetched %d stations from %s", len(parsed), url)
                return parsed

        except Exception as exc:
            last_exc = exc
            logger.warning("WRD Bihar: failed URL %s — %s", url, exc)
            continue

    if _wrd_cache:
        logger.warning("WRD Bihar: all URLs failed, serving stale cache (%d records)", len(_wrd_cache))
        return _wrd_cache

    logger.error("WRD Bihar: no live data and no cache. Last error: %s", last_exc)
    return []


@router.get("", summary="All Bihar flood monitoring stations")
async def get_all_wrd_bihar():
    """Returns all stations tracked by WRD Bihar. Cached 15 min."""
    data = await _fetch_wrd_stations()
    if not data:
        raise HTTPException(
            status_code=503,
            detail="WRD Bihar live data unavailable. Portal may be down.",
        )
    return {
        "source":    "WRD Bihar",
        "state":     "Bihar",
        "count":     len(data),
        "stations":  data,
        "cached_at": _wrd_cache_ts,
    }


@router.get("/state", summary="Bihar station list (alias)")
async def get_wrd_bihar_by_state(state: str = Query("Bihar")):
    return await get_all_wrd_bihar()


@router.get("/station", summary="Find a specific Bihar station by name")
async def get_wrd_bihar_station(name: str = Query(..., description="Station name (fuzzy match)")):
    data = await _fetch_wrd_stations()
    if not data:
        raise HTTPException(status_code=503, detail="WRD Bihar data unavailable.")

    names = [s["station"] for s in data]
    matches = get_close_matches(name, names, n=5, cutoff=0.4)
    if not matches:
        matches = [n for n in names if name.lower() in n.lower() or n.lower() in name.lower()]
    if not matches:
        raise HTTPException(
            status_code=404,
            detail=f"No Bihar station matching '{name}'. Available: {names[:10]}",
        )
    result = [s for s in data if s["station"] in matches]
    return {"query": name, "matches": result}


@router.get("/danger", summary="Bihar stations currently above danger level")
async def get_wrd_bihar_danger():
    data = await _fetch_wrd_stations()
    danger_stations  = [s for s in data if s.get("status") == "danger"]
    warning_stations = [s for s in data if s.get("status") == "warning"]
    return {
        "source":           "WRD Bihar",
        "danger_count":     len(danger_stations),
        "warning_count":    len(warning_stations),
        "danger_stations":  danger_stations,
        "warning_stations": warning_stations,
    }


@router.get("/refresh", summary="Force-refresh WRD Bihar cache")
async def refresh_wrd_bihar_cache():
    data = await _fetch_wrd_stations(force=True)
    return {
        "message":   "Cache refreshed",
        "count":     len(data),
        "cached_at": _wrd_cache_ts,
    }
