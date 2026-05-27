"""
routers/wrd_bihar.py
FastAPI router for WRD Bihar live flood station data.
Endpoints:
  GET /api/wrd-bihar/stations              - all stations (optional ?station= filter)
  GET /api/wrd-bihar/stations/registry     - static station registry, always available
  GET /api/wrd-bihar/stations/{station}    - single station detail
"""
from fastapi import APIRouter, Query
from typing import Optional
import importlib.util as _importlib_util


def _is_package_context() -> bool:
    return _importlib_util.find_spec("backend") is not None


if _is_package_context():
    from backend.wrd_bihar_scraper import wrd_bihar_scraper, BIHAR_STATION_REGISTRY
else:
    from wrd_bihar_scraper import wrd_bihar_scraper, BIHAR_STATION_REGISTRY


router = APIRouter(prefix="/api/wrd-bihar", tags=["WRD Bihar"])


@router.get("/stations")
def get_wrd_bihar_stations(
    station: Optional[str] = Query(None, description="Filter by station name substring (e.g. 'Gandhi', 'Hajipur')"),
    limit: int = Query(20, ge=1, le=50, description="Max stations to return"),
):
    """
    Fetch live flood station data from WRD Bihar portal.
    Falls back to tactical registry transparently on network failure.
    """
    return wrd_bihar_scraper.get_live_stations(station_filter=station, limit=limit)


@router.get("/stations/registry")
def get_wrd_bihar_registry():
    """
    Return the static Bihar station registry (coords, danger levels, rivers).
    Always available — does not hit the external portal.
    """
    return {
        "state":         "Bihar",
        "source":        "STATIC_REGISTRY",
        "station_count": len(BIHAR_STATION_REGISTRY),
        "stations":      BIHAR_STATION_REGISTRY,
    }


@router.get("/stations/{station_name}")
def get_wrd_bihar_station_detail(station_name: str):
    """
    Fetch live data for a single WRD Bihar station by name substring.
    """
    result = wrd_bihar_scraper.get_live_stations(station_filter=station_name, limit=5)
    data   = result.get("data", [])
    best   = next(
        (s for s in data if station_name.lower() in s["station"].lower()),
        data[0] if data else None,
    )
    return {
        **result,
        "data":            [best] if best else [],
        "queried_station": station_name,
    }
