"""
backend/wrd_bihar_scraper.py

Live flood-station scraper for the WRD Bihar public portal.
Target URL: http://fldcontrolbihar.org/

Strategy
--------
* The portal serves an HTML page containing a <table> with columns:
    Station Name | River | Observed Level (m) | Danger Level (m) | Status
* We parse that table with BeautifulSoup.
* A TTL-based in-memory cache (10 min) prevents hammering the portal.
* On any network / parse failure the scraper returns data built from the
  BIHAR_STATION_REGISTRY static dict — so the API is always available.

Exported symbols
----------------
    wrd_bihar_scraper   : singleton WRDBiharScraper instance
    BIHAR_STATION_REGISTRY : list[dict]  static station metadata
"""

from __future__ import annotations

import datetime
import logging
from typing import Any, Dict, List, Optional

import requests
from bs4 import BeautifulSoup

logger = logging.getLogger("opsflood.wrd_bihar")

# ---------------------------------------------------------------------------
# Static registry  — coordinates, rivers, standard danger / warning levels
# (sourced from CWC Flood Forecast bulletins for Bihar).
# ---------------------------------------------------------------------------
BIHAR_STATION_REGISTRY: List[Dict[str, Any]] = [
    {"station": "Gandhi Setu",   "river": "Ganga",       "lat": 25.736, "lon": 85.004,
     "danger_level_m": 50.27, "warning_level_m": 49.27, "safe_level_m": 46.00},
    {"station": "Hathidah",      "river": "Ganga",       "lat": 25.369, "lon": 85.788,
     "danger_level_m": 38.11, "warning_level_m": 37.11, "safe_level_m": 34.00},
    {"station": "Hajipur",       "river": "Gandak",      "lat": 25.686, "lon": 85.208,
     "danger_level_m": 55.00, "warning_level_m": 54.00, "safe_level_m": 51.00},
    {"station": "Dumariaghat",   "river": "Kosi",        "lat": 26.584, "lon": 86.738,
     "danger_level_m": 71.60, "warning_level_m": 70.60, "safe_level_m": 67.00},
    {"station": "Basantpur",     "river": "Gandak",      "lat": 26.133, "lon": 84.367,
     "danger_level_m": 62.74, "warning_level_m": 61.74, "safe_level_m": 59.00},
    {"station": "Rosera",        "river": "Burhi Gandak","lat": 25.866, "lon": 86.011,
     "danger_level_m": 45.80, "warning_level_m": 44.80, "safe_level_m": 42.00},
    {"station": "Muzaffarpur",   "river": "Burhi Gandak","lat": 26.121, "lon": 85.391,
     "danger_level_m": 52.73, "warning_level_m": 51.73, "safe_level_m": 49.00},
    {"station": "Sitamarhi",     "river": "Bagmati",     "lat": 26.592, "lon": 85.486,
     "danger_level_m": 82.42, "warning_level_m": 81.42, "safe_level_m": 78.00},
    {"station": "Dheng Bridge",  "river": "Bagmati",     "lat": 26.011, "lon": 85.539,
     "danger_level_m": 57.61, "warning_level_m": 56.61, "safe_level_m": 53.00},
    {"station": "Hayaghat",      "river": "Kamla Balan", "lat": 26.232, "lon": 86.081,
     "danger_level_m": 49.38, "warning_level_m": 48.38, "safe_level_m": 45.00},
    {"station": "Jhanjharpur",   "river": "Kamla Balan", "lat": 26.268, "lon": 86.277,
     "danger_level_m": 55.53, "warning_level_m": 54.53, "safe_level_m": 51.00},
    {"station": "Benibad",       "river": "Bagmati",     "lat": 26.111, "lon": 85.868,
     "danger_level_m": 52.12, "warning_level_m": 51.12, "safe_level_m": 48.00},
    {"station": "Kursela",       "river": "Kosi",        "lat": 25.453, "lon": 87.263,
     "danger_level_m": 29.49, "warning_level_m": 28.49, "safe_level_m": 25.00},
    {"station": "Bhagalpur",     "river": "Ganga",       "lat": 25.249, "lon": 86.975,
     "danger_level_m": 33.68, "warning_level_m": 32.68, "safe_level_m": 29.00},
    {"station": "Manihari",      "river": "Ganga",       "lat": 25.406, "lon": 87.621,
     "danger_level_m": 28.96, "warning_level_m": 27.96, "safe_level_m": 25.00},
]

# Map lower-case name fragments -> registry index for fast lookup
_REGISTRY_INDEX: Dict[str, Dict[str, Any]] = {
    entry["station"].lower(): entry for entry in BIHAR_STATION_REGISTRY
}

# Portal URL and scrape timeout
_WRD_BIHAR_URL    = "http://fldcontrolbihar.org/"
_SCRAPE_TIMEOUT   = (5, 15)   # (connect, read) seconds
_CACHE_TTL_SECS   = 10 * 60   # 10 minutes


def _now_iso() -> str:
    return datetime.datetime.now(datetime.timezone.utc).isoformat()


def _risk_level(observed: float, danger: float, warning: float) -> str:
    if danger > 0 and observed >= danger:              return "CRITICAL"
    if warning > 0 and observed >= warning:            return "HIGH"
    if warning > 0 and observed >= warning * 0.90:     return "MODERATE"
    return "LOW"


def _capacity_pct(observed: float, safe: float, danger: float) -> float:
    span = danger - safe
    if span <= 0:
        return 50.0
    return round(min((observed - safe) / span * 100.0, 100.0), 1)


def _status(risk: str) -> str:
    return "RISING" if risk in ("CRITICAL", "HIGH") else "STABLE"


def _alert(risk: str) -> str:
    return {"CRITICAL": "\U0001f6a8", "HIGH": "\u26a0\ufe0f",
            "MODERATE": "\U0001f4ca", "LOW": "\u2705"}.get(risk, "\U0001f4ca")


def _station_from_registry(reg: Dict[str, Any], timestamp: str) -> Dict[str, Any]:
    """Build a station dict from registry data when live scrape is unavailable."""
    danger  = reg["danger_level_m"]
    warning = reg["warning_level_m"]
    safe    = reg["safe_level_m"]
    # Mid-range safe default: halfway between safe and warning
    current = round((safe + warning) / 2, 2)
    risk    = _risk_level(current, danger, warning)
    return {
        "station":          reg["station"],
        "city":             reg["station"],
        "state":            "Bihar",
        "river_name":       reg["river"],
        "lat":              reg["lat"],
        "lon":              reg["lon"],
        "current_level":    current,
        "observed_level_m": current,
        "safe_level":       safe,
        "warning_level":    warning,
        "danger_level":     danger,
        "capacity_percent": _capacity_pct(current, safe, danger),
        "risk_level":       risk,
        "status":           _status(risk),
        "alert":            _alert(risk),
        "flow_rate":        None,
        "data_source":      "WRD_BIHAR_REGISTRY",
        "timestamp":        timestamp,
        "portal_status":    "N/A",
    }


def _parse_wrd_table(html: str, timestamp: str) -> List[Dict[str, Any]]:
    """
    Parse WRD Bihar HTML table.

    The portal table structure (as observed):
      col 0 : S.No
      col 1 : Station Name
      col 2 : River
      col 3 : Observed Level (m) [may contain '-' when gauge not updated]
      col 4 : Danger Level (m)
      col 5 : Status  (e.g. 'Normal', 'Above Danger', 'Above Warning')

    We gracefully handle missing/extra columns and non-numeric cells.
    """
    soup = BeautifulSoup(html, "html.parser")
    results: List[Dict[str, Any]] = []

    # Try finding the flood monitoring table — look for any table with ≥5 columns
    tables = soup.find_all("table")
    target_table = None
    for tbl in tables:
        rows = tbl.find_all("tr")
        if len(rows) >= 3:
            # Check if a header row mentions 'station' or 'level'
            header_text = rows[0].get_text(" ", strip=True).lower()
            if any(kw in header_text for kw in ("station", "level", "river", "observed")):
                target_table = tbl
                break

    if target_table is None:
        logger.warning("[wrd_bihar] No suitable table found in HTML")
        return []

    rows = target_table.find_all("tr")
    for row in rows[1:]:   # skip header
        cells = [td.get_text(" ", strip=True) for td in row.find_all(["td", "th"])]
        if len(cells) < 5:
            continue

        raw_station = cells[1].strip() if len(cells) > 1 else ""
        raw_river   = cells[2].strip() if len(cells) > 2 else ""
        raw_obs     = cells[3].strip() if len(cells) > 3 else "-"
        raw_danger  = cells[4].strip() if len(cells) > 4 else "-"
        raw_status  = cells[5].strip() if len(cells) > 5 else "Normal"

        if not raw_station or raw_station.isdigit():
            continue

        # Parse numerics safely
        def _safe_float(val: str) -> Optional[float]:
            try:
                cleaned = val.replace(",", "").strip()
                return float(cleaned) if cleaned not in ("-", "", "N/A", "--") else None
            except ValueError:
                return None

        observed = _safe_float(raw_obs)
        danger   = _safe_float(raw_danger)

        # Try to enrich from registry (gives us warning_level, safe_level, coords)
        reg_key  = raw_station.lower()
        registry = next(
            (r for k, r in _REGISTRY_INDEX.items() if k in reg_key or reg_key in k),
            None,
        )

        if registry:
            danger_m  = danger  if danger  is not None else registry["danger_level_m"]
            warning_m = registry["warning_level_m"]
            safe_m    = registry["safe_level_m"]
            lat       = registry["lat"]
            lon       = registry["lon"]
            river     = registry["river"]
        else:
            # Unknown station — use observed danger if available
            danger_m  = danger  if danger  is not None else 0.0
            warning_m = danger_m * 0.9 if danger_m > 0 else 0.0
            safe_m    = danger_m * 0.7 if danger_m > 0 else 0.0
            lat, lon  = None, None
            river     = raw_river or "Unknown"

        current_m = observed if observed is not None else (
            round((safe_m + warning_m) / 2, 2) if safe_m < warning_m else 0.0
        )

        risk = _risk_level(current_m, danger_m, warning_m)

        results.append({
            "station":          raw_station,
            "city":             raw_station,
            "state":            "Bihar",
            "river_name":       river,
            "lat":              lat,
            "lon":              lon,
            "current_level":    current_m,
            "observed_level_m": observed,
            "safe_level":       safe_m,
            "warning_level":    warning_m,
            "danger_level":     danger_m,
            "capacity_percent": _capacity_pct(current_m, safe_m, danger_m),
            "risk_level":       risk,
            "status":           _status(risk),
            "alert":            _alert(risk),
            "flow_rate":        None,
            "data_source":      "WRD_BIHAR",
            "timestamp":        timestamp,
            "portal_status":    raw_status,
        })

    return results


# ---------------------------------------------------------------------------
# Main scraper class
# ---------------------------------------------------------------------------

class WRDBiharScraper:
    """Thin HTTP + parse wrapper with TTL in-memory cache."""

    def __init__(self) -> None:
        self._cache: Optional[List[Dict[str, Any]]] = None
        self._cache_ts: Optional[datetime.datetime] = None

    # ------------------------------------------------------------------
    # Public API
    # ------------------------------------------------------------------

    def get_live_stations(
        self,
        station_filter: Optional[str] = None,
        limit: int = 20,
    ) -> Dict[str, Any]:
        """
        Return live WRD Bihar stations dict.

        Response shape
        --------------
        {
          "status":        "success" | "fallback",
          "state":         "Bihar",
          "data_source":   "WRD_BIHAR" | "WRD_BIHAR_REGISTRY",
          "station_count": int,
          "timestamp":     ISO-8601,
          "data":          [ station_dict, ... ]
        }
        """
        stations = self._get_cached_or_fetch()

        if station_filter:
            needle = station_filter.strip().lower()
            stations = [s for s in stations if needle in s["station"].lower()]

        stations = stations[:limit]
        data_source = (
            stations[0]["data_source"] if stations else "WRD_BIHAR_REGISTRY"
        )
        is_live = any(s.get("data_source") == "WRD_BIHAR" for s in stations)

        return {
            "status":        "success" if is_live else "fallback",
            "state":         "Bihar",
            "data_source":   data_source,
            "portal_url":    _WRD_BIHAR_URL,
            "station_count": len(stations),
            "timestamp":     _now_iso(),
            "data":          stations,
        }

    def get_all_stations_for_live_levels(self) -> List[Dict[str, Any]]:
        """
        Return the raw station list for merging into /api/live-levels.
        Always returns data (registry fallback on failure).
        """
        return self._get_cached_or_fetch()

    # ------------------------------------------------------------------
    # Internal helpers
    # ------------------------------------------------------------------

    def _cache_valid(self) -> bool:
        if self._cache is None or self._cache_ts is None:
            return False
        age = (datetime.datetime.utcnow() - self._cache_ts).total_seconds()
        return age < _CACHE_TTL_SECS

    def _get_cached_or_fetch(self) -> List[Dict[str, Any]]:
        if self._cache_valid() and self._cache:
            logger.debug("[wrd_bihar] Returning cached data")
            return self._cache
        return self._fetch_and_cache()

    def _fetch_and_cache(self) -> List[Dict[str, Any]]:
        timestamp = _now_iso()
        try:
            resp = requests.get(
                _WRD_BIHAR_URL,
                timeout=_SCRAPE_TIMEOUT,
                headers={
                    "User-Agent": "OpsFlood/1.0 (Flood Early Warning Research; contact: opsflood@example.com)",
                    "Accept": "text/html,application/xhtml+xml",
                },
            )
            resp.raise_for_status()
            parsed = _parse_wrd_table(resp.text, timestamp)

            if parsed:
                self._cache    = parsed
                self._cache_ts = datetime.datetime.utcnow()
                logger.info("[wrd_bihar] ✅ Scraped %d stations from portal", len(parsed))
                return parsed

            logger.warning("[wrd_bihar] Parsed 0 stations — using registry fallback")

        except requests.exceptions.Timeout:
            logger.warning("[wrd_bihar] Portal timeout — using registry fallback")
        except requests.exceptions.ConnectionError:
            logger.warning("[wrd_bihar] Portal unreachable — using registry fallback")
        except Exception as exc:
            logger.warning("[wrd_bihar] Unexpected error: %s — using registry fallback", exc)

        # Build fallback from static registry
        fallback = [_station_from_registry(r, timestamp) for r in BIHAR_STATION_REGISTRY]
        # Cache the fallback too so repeated failures don't spam the portal
        self._cache    = fallback
        self._cache_ts = datetime.datetime.utcnow()
        return fallback


# ---------------------------------------------------------------------------
# Module-level singleton (imported by wrd_bihar.py router and live_levels.py)
# ---------------------------------------------------------------------------
wrd_bihar_scraper = WRDBiharScraper()
