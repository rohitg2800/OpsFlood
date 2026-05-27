"""
backend/wrd_bihar_scraper.py
-----------------------------
Standalone WRD Bihar HTML scraper.
Can be run directly:  python -m backend.wrd_bihar_scraper
or imported by routers/wrd_bihar.py.

WRD Bihar portal: http://fldcontrolbihar.org/
"""
import asyncio
import json
import logging
import time
from typing import Any, Dict, List, Optional

import httpx
from bs4 import BeautifulSoup

logging.basicConfig(level=logging.INFO, format="%(levelname)s: %(message)s")
logger = logging.getLogger(__name__)

# ── Portal URLs ────────────────────────────────────────────────────────────────
WRD_BIHAR_URLS: List[str] = [
    "http://fldcontrolbihar.org/",
    "http://fldcontrolbihar.org/flood_situation.php",
    "http://fldcontrolbihar.org/flood_report.php",
    "https://state.bihar.gov.in/wrd/CitizenHome.html",
]

# ── Known stations with coordinates ───────────────────────────────────────────
BIHAR_STATION_COORDS: Dict[str, Dict[str, float]] = {
    "gandhi setu":   {"lat": 25.736, "lon": 85.004},
    "patna":         {"lat": 25.594, "lon": 85.137},
    "hajipur":       {"lat": 25.686, "lon": 85.208},
    "darbhanga":     {"lat": 26.152, "lon": 85.901},
    "muzaffarpur":   {"lat": 26.121, "lon": 85.391},
    "supaul":        {"lat": 26.123, "lon": 86.604},
    "bhagalpur":     {"lat": 25.244, "lon": 87.000},
    "sonepur":       {"lat": 25.710, "lon": 85.178},
    "sitamarhi":     {"lat": 26.592, "lon": 85.491},
    "motihari":      {"lat": 26.649, "lon": 84.916},
    "samastipur":    {"lat": 25.864, "lon": 85.781},
    "begusarai":     {"lat": 25.418, "lon": 86.127},
    "khagaria":      {"lat": 25.502, "lon": 86.470},
    "araria":        {"lat": 26.147, "lon": 87.473},
    "gopalganj":     {"lat": 26.467, "lon": 84.434},
    "siwan":         {"lat": 26.219, "lon": 84.355},
    "buxar":         {"lat": 25.567, "lon": 83.980},
    "katihar":       {"lat": 25.540, "lon": 87.579},
    "purnia":        {"lat": 25.777, "lon": 87.473},
}


def _safe_float(val: str) -> Optional[float]:
    """Convert a potentially messy string to float or None."""
    if not val:
        return None
    try:
        return float(val.strip().replace(",", "").split()[0])
    except (ValueError, IndexError):
        return None


def _get_coords(station_name: str) -> Dict[str, Optional[float]]:
    """Return lat/lon by matching station name to known coordinates."""
    name_lower = station_name.lower()
    for key, coords in BIHAR_STATION_COORDS.items():
        if key in name_lower or name_lower in key:
            return {"lat": coords["lat"], "lon": coords["lon"]}
    return {"lat": None, "lon": None}


def _determine_status(
    obs: Optional[float],
    danger: Optional[float],
    warning: Optional[float],
) -> str:
    """Calculate alert status from water levels."""
    if obs is None:
        return "unknown"
    if danger is not None and obs >= danger:
        return "danger"
    if warning is not None and obs >= warning:
        return "warning"
    return "normal"


def parse_wrd_html(html: str) -> List[Dict[str, Any]]:
    """
    Parse WRD Bihar flood monitoring HTML.
    Returns a list of station dicts with normalised fields.

    Expected table columns (WRD Bihar portal):
    Station Name | River | Observed Level (m) | Danger Level (m) |
    Warning Level (m) | Status | Date/Time
    """
    soup = BeautifulSoup(html, "html.parser")
    results: List[Dict[str, Any]] = []

    # Find the most relevant table
    candidate_table = None
    for tbl in soup.find_all("table"):
        text = tbl.get_text(" ", strip=True).lower()
        score = sum(1 for kw in ["danger", "flood level", "station", "river", "observed"] if kw in text)
        if score >= 2:
            candidate_table = tbl
            break

    if candidate_table is None:
        logger.warning("No flood table detected in WRD Bihar HTML")
        return results

    rows = candidate_table.find_all("tr")
    headers: List[str] = []
    data_rows: List[List[str]] = []

    for row in rows:
        cells = [c.get_text(strip=True) for c in row.find_all(["th", "td"])]
        if not cells:
            continue
        if not headers:
            lowered = [c.lower() for c in cells]
            if any(k in " ".join(lowered) for k in ["station", "danger", "level", "river"]):
                headers = lowered
                continue
        if headers:
            data_rows.append(cells)

    if not headers:
        logger.warning("Could not detect header row in WRD Bihar table")
        return results

    def find_col(*keywords: str) -> int:
        for kw in keywords:
            for i, h in enumerate(headers):
                if kw in h:
                    return i
        return -1

    i_station = find_col("station", "site", "gauge", "location")
    i_river   = find_col("river", "stream", "nadi")
    i_obs     = find_col("observed", "current", "obs.", "w.l", "water level")
    i_danger  = find_col("danger", "d.l", "dgl")
    i_warning = find_col("warning", "w.l", "wgl", "alert")
    i_time    = find_col("time", "date", "reported")

    for cells in data_rows:
        def get(idx: int) -> str:
            return cells[idx].strip() if 0 <= idx < len(cells) else ""

        station_name = get(i_station) or get(0)
        if not station_name or station_name.lower() in ("-", "n/a", "na", ""):
            continue

        obs_level     = _safe_float(get(i_obs))
        danger_level  = _safe_float(get(i_danger))
        warning_level = _safe_float(get(i_warning))
        coords        = _get_coords(station_name)

        results.append({
            "station":          station_name,
            "river":            get(i_river) or "—",
            "state":            "Bihar",
            "obs_level_m":      obs_level,
            "danger_level_m":   danger_level,
            "warning_level_m":  warning_level,
            "status":           _determine_status(obs_level, danger_level, warning_level),
            "reported_at":      get(i_time) or None,
            "lat":              coords["lat"],
            "lon":              coords["lon"],
            "source":           "WRD Bihar",
            "fetched_ts":       time.time(),
        })

    return results


async def fetch_wrd_bihar_live() -> List[Dict[str, Any]]:
    """
    Try each WRD Bihar URL in sequence and return first successful parse.
    Falls back to empty list if all fail.
    """
    async with httpx.AsyncClient(
        timeout=25,
        follow_redirects=True,
        verify=False,  # Govt portals often have self-signed/expired certs
    ) as client:
        for url in WRD_BIHAR_URLS:
            try:
                resp = await client.get(
                    url,
                    headers={"User-Agent": "OpsFlood/2.0 (flood research, rohitg2800)"},
                )
                resp.raise_for_status()
                stations = parse_wrd_html(resp.text)
                if stations:
                    logger.info("✅ WRD Bihar: %d stations from %s", len(stations), url)
                    return stations
                else:
                    logger.warning("⚠️  WRD Bihar: table empty at %s, trying next", url)
            except Exception as exc:
                logger.warning("❌ WRD Bihar URL failed %s: %s", url, exc)

    logger.error("WRD Bihar: all URLs exhausted, returning empty list")
    return []


if __name__ == "__main__":
    async def main():
        stations = await fetch_wrd_bihar_live()
        if stations:
            print(f"\n✅ WRD Bihar — {len(stations)} stations fetched:\n")
            print(json.dumps(stations, indent=2, ensure_ascii=False))
        else:
            print("\n❌ Could not fetch WRD Bihar data. Portal may be down.")

    asyncio.run(main())
