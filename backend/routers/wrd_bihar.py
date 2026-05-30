"""
WRD Bihar Live Data Router
Scrapes fldcontrolbihar.org flood monitoring table and exposes
GET /api/wrd-bihar/stations  — live station data for Bihar rivers
"""

from __future__ import annotations

import datetime
import os
from typing import Any, Dict, List

import requests
from bs4 import BeautifulSoup
from fastapi import APIRouter, HTTPException
from cachetools import TTLCache

router = APIRouter(prefix="/api/wrd-bihar", tags=["WRD Bihar"])

# ---------------------------------------------------------------------------
# Cache — 10-minute TTL (WRD Bihar updates ~every 15 min)
# ---------------------------------------------------------------------------
_CACHE: TTLCache = TTLCache(maxsize=64, ttl=600)

# ---------------------------------------------------------------------------
# Known Bihar WRD station metadata (lat/lon for map pins)
# ---------------------------------------------------------------------------
_STATION_META: Dict[str, Dict[str, Any]] = {
    "gandhi setu": {"district": "Patna", "river": "Ganga", "lat": 25.736, "lon": 85.004},
    "patna": {"district": "Patna", "river": "Ganga", "lat": 25.594, "lon": 85.138},
    "hajipur": {"district": "Vaishali", "river": "Ganga", "lat": 25.686, "lon": 85.208},
    "dumariaghat": {"district": "Sitamarhi", "river": "Bagmati", "lat": 26.804, "lon": 85.513},
    "raxaul": {"district": "East Champaran", "river": "Gandak", "lat": 26.986, "lon": 84.850},
    "muzaffarpur": {"district": "Muzaffarpur", "river": "Burhi Gandak", "lat": 26.121, "lon": 85.391},
    "darbhanga": {"district": "Darbhanga", "river": "Kamla Balan", "lat": 26.152, "lon": 85.901},
    "bhagalpur": {"district": "Bhagalpur", "river": "Ganga", "lat": 25.244, "lon": 86.972},
    "munger": {"district": "Munger", "river": "Ganga", "lat": 25.375, "lon": 86.473},
    "araria": {"district": "Araria", "river": "Kosi", "lat": 26.147, "lon": 87.471},
    "supaul": {"district": "Supaul", "river": "Kosi", "lat": 26.124, "lon": 86.604},
    "saharsa": {"district": "Saharsa", "river": "Kosi", "lat": 25.877, "lon": 86.594},
    "gopalganj": {"district": "Gopalganj", "river": "Gandak", "lat": 26.469, "lon": 84.436},
    "saran": {"district": "Saran", "river": "Ghaghara", "lat": 25.919, "lon": 84.733},
    "siwan": {"district": "Siwan", "river": "Ghaghara", "lat": 26.219, "lon": 84.358},
}

# ---------------------------------------------------------------------------
# Scraper targets (in priority order)
# ---------------------------------------------------------------------------
_WRD_URLS = [
    "http://fldcontrolbihar.org/",
    "http://fldcontrolbihar.org/flood-monitoring",
    "http://fldcontrolbihar.org/river-data",
]

_HEADERS = {
    "User-Agent": (
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
        "AppleWebKit/537.36 (KHTML, like Gecko) "
        "Chrome/120.0.0.0 Safari/537.36"
    ),
    "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
    "Accept-Language": "en-IN,en;q=0.9",
    "Referer": "http://fldcontrolbihar.org/",
}


def _normalize(value: str) -> str:
    return " ".join((value or "").strip().lower().split())


def _safe_float(value: Any, default: float = 0.0) -> float:
    try:
        return float(str(value).strip().replace(",", "")) if value not in (None, "", "--", "N/A") else default
    except (ValueError, TypeError):
        return default


def _enrich_station(name: str) -> Dict[str, Any]:
    """Return lat/lon/district/river for a station name via fuzzy key match."""
    key = _normalize(name)
    for meta_key, meta in _STATION_META.items():
        if meta_key in key or key in meta_key:
            return meta
    # Unknown station — synthetic coords near Bihar centre
    return {"district": "Bihar", "river": "Unknown", "lat": 25.8 + hash(key) % 100 / 500, "lon": 85.4}


def _status_label(current: float, warning: float, danger: float) -> str:
    if danger > 0 and current >= danger:
        return "CRITICAL"
    if warning > 0 and current >= warning:
        return "WARNING"
    if current > 0:
        return "NORMAL"
    return "UNKNOWN"


def _parse_table(soup: BeautifulSoup) -> List[Dict[str, Any]]:
    """
    Try to extract station rows from any HTML table on the WRD Bihar page.
    Handles both named-column headers and positional fallback.
    """
    stations: List[Dict[str, Any]] = []

    for table in soup.find_all("table"):
        headers_raw = [th.get_text(strip=True).lower() for th in table.find_all("th")]

        # Detect column positions
        def col(keywords: list[str]) -> int:
            for kw in keywords:
                for i, h in enumerate(headers_raw):
                    if kw in h:
                        return i
            return -1

        idx_station = col(["station", "gauge", "site", "location"])
        idx_river = col(["river", "nadi"])
        idx_current = col(["current", "observed", "water level", "wl", "level (m)", "gauge reading"])
        idx_warning = col(["warning", "warn"])
        idx_danger = col(["danger", "hfl", "flood level"])
        idx_status = col(["status", "remark", "flood situation"])

        for row in table.find_all("tr"):
            cells = [td.get_text(strip=True) for td in row.find_all("td")]
            if len(cells) < 3:
                continue

            def cell(idx: int, fallback: str = "") -> str:
                return cells[idx] if 0 <= idx < len(cells) else fallback

            station_name = cell(idx_station, cell(0))
            if not station_name or station_name.lower() in ("station", "s.no", "#", ""):
                continue

            river_name = cell(idx_river, "")
            current_level = _safe_float(cell(idx_current, cell(2)))
            warning_level = _safe_float(cell(idx_warning, cell(3) if len(cells) > 3 else ""))
            danger_level = _safe_float(cell(idx_danger, cell(4) if len(cells) > 4 else ""))
            raw_status = cell(idx_status, "")

            meta = _enrich_station(station_name)
            if not river_name:
                river_name = meta.get("river", "Unknown")

            status = (
                raw_status.upper()
                if raw_status.upper() in ("CRITICAL", "WARNING", "NORMAL", "SAFE")
                else _status_label(current_level, warning_level, danger_level)
            )

            stations.append({
                "station": station_name,
                "river": river_name,
                "district": meta["district"],
                "lat": meta["lat"],
                "lon": meta["lon"],
                "current_level_m": round(current_level, 3),
                "warning_level_m": round(warning_level, 3),
                "danger_level_m": round(danger_level, 3),
                "below_danger_m": round(max(danger_level - current_level, 0.0), 3) if danger_level > 0 else None,
                "status": status,
                "source": "WRD_BIHAR",
                "last_update": datetime.datetime.now(datetime.timezone.utc).isoformat(),
            })

    return stations


def _fetch_wrd_bihar_live() -> Dict[str, Any]:
    """Attempt each WRD Bihar URL in order; return parsed stations or raise."""
    errors: list[str] = []
    timeout = (
        max(1.0, float(os.getenv("WRD_BIHAR_CONNECT_TIMEOUT", "4"))),
        max(1.0, float(os.getenv("WRD_BIHAR_READ_TIMEOUT", "10"))),
    )

    for url in _WRD_URLS:
        try:
            resp = requests.get(url, headers=_HEADERS, timeout=timeout)
            resp.raise_for_status()
            soup = BeautifulSoup(resp.text, "html.parser")
            stations = _parse_table(soup)
            if stations:
                return {
                    "status": "LIVE",
                    "data_source": "WRD_BIHAR",
                    "source_url": url,
                    "station_count": len(stations),
                    "timestamp": datetime.datetime.now(datetime.timezone.utc).isoformat(),
                    "stations": stations,
                }
            errors.append(f"{url}: page loaded but no table rows found")
        except requests.Timeout:
            errors.append(f"{url}: timeout")
        except requests.RequestException as exc:
            errors.append(f"{url}: {exc.__class__.__name__} — {str(exc)[:120]}")

    raise RuntimeError(" | ".join(errors))


def _tactical_fallback() -> Dict[str, Any]:
    """Return known-static Bihar station data when live scrape fails."""
    now = datetime.datetime.now(datetime.timezone.utc).isoformat()
    stations = []
    for name, meta in _STATION_META.items():
        stations.append({
            "station": name.title(),
            "river": meta["river"],
            "district": meta["district"],
            "lat": meta["lat"],
            "lon": meta["lon"],
            "current_level_m": None,
            "warning_level_m": None,
            "danger_level_m": None,
            "below_danger_m": None,
            "status": "UNKNOWN",
            "source": "WRD_BIHAR_FALLBACK",
            "last_update": now,
        })
    return {
        "status": "FALLBACK",
        "data_source": "WRD_BIHAR_FALLBACK",
        "source_url": None,
        "station_count": len(stations),
        "timestamp": now,
        "stations": stations,
    }


# ---------------------------------------------------------------------------
# Routes
# ---------------------------------------------------------------------------

@router.get("/stations")
async def get_wrd_bihar_stations(force_refresh: bool = False) -> Dict[str, Any]:
    """
    Fetch live WRD Bihar flood station data.

    - Returns scraped table from fldcontrolbihar.org
    - Cached for 10 minutes to avoid hammering the government portal
    - Falls back to known static station list if portal is unreachable
    - Pass ?force_refresh=true to bypass cache
    """
    cache_key = "wrd_bihar_stations"

    if not force_refresh and cache_key in _CACHE:
        cached = _CACHE[cache_key]
        cached["_cache_hit"] = True
        return cached

    try:
        result = _fetch_wrd_bihar_live()
        _CACHE[cache_key] = result
        result["_cache_hit"] = False
        return result
    except RuntimeError as exc:
        fallback = _tactical_fallback()
        fallback["_scrape_error"] = str(exc)
        fallback["_cache_hit"] = False
        return fallback


@router.get("/stations/{station_name}")
async def get_wrd_bihar_station(station_name: str) -> Dict[str, Any]:
    """Get data for a single WRD Bihar station by name (case-insensitive partial match)."""
    all_data = await get_wrd_bihar_stations()
    key = _normalize(station_name)
    matches = [
        s for s in all_data.get("stations", [])
        if key in _normalize(s.get("station", "")) or _normalize(s.get("station", "")) in key
    ]
    if not matches:
        raise HTTPException(status_code=404, detail=f"No WRD Bihar station found matching '{station_name}'")
    return {
        "status": all_data["status"],
        "data_source": all_data["data_source"],
        "timestamp": all_data["timestamp"],
        "station": matches[0],
    }


@router.get("/health")
async def wrd_bihar_health() -> Dict[str, Any]:
    """Quick health check — does WRD Bihar portal respond?"""
    try:
        resp = requests.get(_WRD_URLS[0], headers=_HEADERS, timeout=(3, 6))
        return {
            "reachable": resp.ok,
            "status_code": resp.status_code,
            "url": _WRD_URLS[0],
            "timestamp": datetime.datetime.now(datetime.timezone.utc).isoformat(),
        }
    except requests.RequestException as exc:
        return {
            "reachable": False,
            "error": str(exc)[:200],
            "url": _WRD_URLS[0],
            "timestamp": datetime.datetime.now(datetime.timezone.utc).isoformat(),
        }
