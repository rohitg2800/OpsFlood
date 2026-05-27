"""
backend/wrd_bihar_scraper.py

Live flood-station data fetcher for WRD Bihar / FMISC portal.

Data sources (priority order)
------------------------------
1. FMISC Daily Water Level & FF Bulletin PDF
   https://www.fmiscwrdbihar.gov.in/bulletin/fmis%20daily%20water%20level%20and%20FF%20data.pdf
   Published once daily (updated during flood season Jun 15 – Oct 15).
   Contains: Station | River | DL | HFL/Year | Observed levels (last 3 days)

2. Ganga Model Result PDF (3-day forecast + observed)
   https://www.fmiscwrdbihar.gov.in/bulletin/Ganga_Model_Result.pdf
   Contains Buxar, Dighaghat (Gandhi Setu), Gandhighat, Hathidah,
   Munger, Bhagalpur, Kahalgaon with observed + forecast levels.

3. Static BIHAR_STATION_REGISTRY fallback
   Used when both PDFs are unavailable (network error, off-season).
   Provides correct danger/warning thresholds and coordinates always.

Exported symbols
----------------
    wrd_bihar_scraper      : singleton WRDBiharScraper instance
    BIHAR_STATION_REGISTRY : list[dict]  static station metadata
"""

from __future__ import annotations

import datetime
import io
import logging
import re
from typing import Any, Dict, List, Optional, Tuple

import requests

logger = logging.getLogger("opsflood.wrd_bihar")

# ---------------------------------------------------------------------------
# PDF bulletin URLs  (both return HTTP 200, verified May 2026)
# ---------------------------------------------------------------------------
_BULLETIN_PDF_URL = (
    "https://www.fmiscwrdbihar.gov.in/bulletin/"
    "fmis%20daily%20water%20level%20and%20FF%20data.pdf"
)
_GANGA_PDF_URL = (
    "https://www.fmiscwrdbihar.gov.in/bulletin/Ganga_Model_Result.pdf"
)
_SCRAPE_TIMEOUT  = (8, 20)   # (connect, read) seconds
_CACHE_TTL_SECS  = 60 * 60   # 1 hour — bulletin updates once daily


# ---------------------------------------------------------------------------
# Static registry — coordinates, rivers, standard danger/warning levels
# Sourced from CWC Flood Forecast bulletins for Bihar (authoritative).
# ---------------------------------------------------------------------------
BIHAR_STATION_REGISTRY: List[Dict[str, Any]] = [
    {"station": "Gandhi Setu",  "river": "Ganga",        "lat": 25.736, "lon": 85.004,
     "danger_level_m": 50.27, "warning_level_m": 49.27, "safe_level_m": 46.00,
     "pdf_aliases": ["dighaghat", "gandhighat", "gandhi setu", "patna ganga"]},
    {"station": "Hathidah",     "river": "Ganga",        "lat": 25.369, "lon": 85.788,
     "danger_level_m": 38.11, "warning_level_m": 37.11, "safe_level_m": 34.00,
     "pdf_aliases": ["hathidah"]},
    {"station": "Hajipur",      "river": "Gandak",       "lat": 25.686, "lon": 85.208,
     "danger_level_m": 55.00, "warning_level_m": 54.00, "safe_level_m": 51.00,
     "pdf_aliases": ["hajipur"]},
    {"station": "Dumariaghat",  "river": "Kosi",         "lat": 26.584, "lon": 86.738,
     "danger_level_m": 71.60, "warning_level_m": 70.60, "safe_level_m": 67.00,
     "pdf_aliases": ["dumariaghat", "dumaria ghat"]},
    {"station": "Basantpur",    "river": "Gandak",       "lat": 26.133, "lon": 84.367,
     "danger_level_m": 62.74, "warning_level_m": 61.74, "safe_level_m": 59.00,
     "pdf_aliases": ["basantpur"]},
    {"station": "Rosera",       "river": "Burhi Gandak", "lat": 25.866, "lon": 86.011,
     "danger_level_m": 45.80, "warning_level_m": 44.80, "safe_level_m": 42.00,
     "pdf_aliases": ["rosera"]},
    {"station": "Muzaffarpur",  "river": "Burhi Gandak", "lat": 26.121, "lon": 85.391,
     "danger_level_m": 52.73, "warning_level_m": 51.73, "safe_level_m": 49.00,
     "pdf_aliases": ["muzaffarpur"]},
    {"station": "Sitamarhi",    "river": "Bagmati",      "lat": 26.592, "lon": 85.486,
     "danger_level_m": 82.42, "warning_level_m": 81.42, "safe_level_m": 78.00,
     "pdf_aliases": ["sitamarhi"]},
    {"station": "Dheng Bridge", "river": "Bagmati",      "lat": 26.011, "lon": 85.539,
     "danger_level_m": 57.61, "warning_level_m": 56.61, "safe_level_m": 53.00,
     "pdf_aliases": ["dheng", "dheng bridge"]},
    {"station": "Hayaghat",     "river": "Kamla Balan",  "lat": 26.232, "lon": 86.081,
     "danger_level_m": 49.38, "warning_level_m": 48.38, "safe_level_m": 45.00,
     "pdf_aliases": ["hayaghat"]},
    {"station": "Jhanjharpur",  "river": "Kamla Balan",  "lat": 26.268, "lon": 86.277,
     "danger_level_m": 55.53, "warning_level_m": 54.53, "safe_level_m": 51.00,
     "pdf_aliases": ["jhanjharpur"]},
    {"station": "Benibad",      "river": "Bagmati",      "lat": 26.111, "lon": 85.868,
     "danger_level_m": 52.12, "warning_level_m": 51.12, "safe_level_m": 48.00,
     "pdf_aliases": ["benibad"]},
    {"station": "Kursela",      "river": "Kosi",         "lat": 25.453, "lon": 87.263,
     "danger_level_m": 29.49, "warning_level_m": 28.49, "safe_level_m": 25.00,
     "pdf_aliases": ["kursela"]},
    {"station": "Bhagalpur",    "river": "Ganga",        "lat": 25.249, "lon": 86.975,
     "danger_level_m": 33.68, "warning_level_m": 32.68, "safe_level_m": 29.00,
     "pdf_aliases": ["bhagalpur"]},
    {"station": "Manihari",     "river": "Ganga",        "lat": 25.406, "lon": 87.621,
     "danger_level_m": 28.96, "warning_level_m": 27.96, "safe_level_m": 25.00,
     "pdf_aliases": ["manihari"]},
]

# Flat alias -> registry entry map for O(1) lookup
_ALIAS_INDEX: Dict[str, Dict[str, Any]] = {}
for _entry in BIHAR_STATION_REGISTRY:
    for _alias in _entry.get("pdf_aliases", []):
        _ALIAS_INDEX[_alias.lower()] = _entry
    _ALIAS_INDEX[_entry["station"].lower()] = _entry


# ---------------------------------------------------------------------------
# Pure helper functions
# ---------------------------------------------------------------------------

def _now_iso() -> str:
    return datetime.datetime.now(datetime.timezone.utc).isoformat()


def _safe_float(val: str) -> Optional[float]:
    try:
        cleaned = re.sub(r"[^\d.\-]", "", val.strip())
        return float(cleaned) if cleaned not in ("", "-") else None
    except (ValueError, TypeError):
        return None


def _risk_level(observed: float, danger: float, warning: float) -> str:
    if danger  > 0 and observed >= danger:          return "CRITICAL"
    if warning > 0 and observed >= warning:         return "HIGH"
    if warning > 0 and observed >= warning * 0.90:  return "MODERATE"
    return "LOW"


def _capacity_pct(observed: float, safe: float, danger: float) -> float:
    span = danger - safe
    if span <= 0:
        return 50.0
    return round(min(max((observed - safe) / span * 100.0, 0.0), 100.0), 1)


def _status(risk: str) -> str:
    return "RISING" if risk in ("CRITICAL", "HIGH") else "STABLE"


def _alert(risk: str) -> str:
    return {
        "CRITICAL": "\U0001f6a8",
        "HIGH":     "\u26a0\ufe0f",
        "MODERATE": "\U0001f4ca",
        "LOW":      "\u2705",
    }.get(risk, "\U0001f4ca")


def _match_registry(name: str) -> Optional[Dict[str, Any]]:
    """Fuzzy-match a PDF station name to the registry."""
    needle = name.strip().lower()
    # Exact alias match first
    if needle in _ALIAS_INDEX:
        return _ALIAS_INDEX[needle]
    # Partial match: any alias that is a substring of the PDF name or vice versa
    for alias, entry in _ALIAS_INDEX.items():
        if alias in needle or needle in alias:
            return entry
    return None


def _build_station_dict(
    name: str,
    observed: Optional[float],
    danger_pdf: Optional[float],
    portal_status: str,
    timestamp: str,
    data_source: str,
) -> Dict[str, Any]:
    reg = _match_registry(name)

    if reg:
        danger_m  = danger_pdf if danger_pdf is not None else reg["danger_level_m"]
        warning_m = reg["warning_level_m"]
        safe_m    = reg["safe_level_m"]
        lat, lon  = reg["lat"], reg["lon"]
        river     = reg["river"]
        canon     = reg["station"]
    else:
        danger_m  = danger_pdf if danger_pdf is not None else 0.0
        warning_m = round(danger_m * 0.94, 2) if danger_m > 0 else 0.0
        safe_m    = round(danger_m * 0.80, 2) if danger_m > 0 else 0.0
        lat, lon  = None, None
        river     = "Unknown"
        canon     = name

    current = observed if observed is not None else round((safe_m + warning_m) / 2, 2)
    risk    = _risk_level(current, danger_m, warning_m)

    return {
        "station":          canon,
        "city":             canon,
        "state":            "Bihar",
        "river_name":       river,
        "lat":              lat,
        "lon":              lon,
        "current_level":    current,
        "observed_level_m": observed,
        "safe_level":       safe_m,
        "warning_level":    warning_m,
        "danger_level":     danger_m,
        "capacity_percent": _capacity_pct(current, safe_m, danger_m),
        "risk_level":       risk,
        "status":           _status(risk),
        "alert":            _alert(risk),
        "flow_rate":        None,
        "data_source":      data_source,
        "timestamp":        timestamp,
        "portal_status":    portal_status,
    }


def _station_from_registry(reg: Dict[str, Any], timestamp: str) -> Dict[str, Any]:
    danger  = reg["danger_level_m"]
    warning = reg["warning_level_m"]
    safe    = reg["safe_level_m"]
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


# ---------------------------------------------------------------------------
# PDF parsing
# ---------------------------------------------------------------------------

def _parse_bulletin_pdf(pdf_bytes: bytes, timestamp: str) -> List[Dict[str, Any]]:
    """
    Parse the FMISC daily water level bulletin PDF.

    Table layout (text extracted per row):
      Station Name | River | DL (m) | HFL/Year | Obs Day-2 | Obs Day-1 | Obs Today | Status

    We use pdfplumber for text extraction and regex to pull numeric values.
    pdfplumber is lightweight and already pulls table text reliably from
    government PDFs of this format.
    """
    try:
        import pdfplumber  # type: ignore
    except ImportError:
        logger.warning("[wrd_bihar] pdfplumber not installed — pip install pdfplumber")
        return []

    results: List[Dict[str, Any]] = []
    seen_stations: set = set()

    try:
        with pdfplumber.open(io.BytesIO(pdf_bytes)) as pdf:
            for page in pdf.pages:
                # Extract structured table rows first
                tables = page.extract_tables()
                for table in tables:
                    for row in table:
                        if not row or len(row) < 4:
                            continue
                        cells = [str(c or "").strip() for c in row]
                        name = cells[0]
                        if not name or name.lower() in ("station", "s.no", "sl", "#", ""):
                            continue
                        if name[0].isdigit() and len(name) <= 3:
                            # Serial number cell — shift
                            cells = cells[1:]
                            name = cells[0] if cells else ""
                        if not name or len(name) < 3:
                            continue

                        # DL column is usually col index 2, observed today is last numeric col
                        dl_val  = _safe_float(cells[2]) if len(cells) > 2 else None
                        # Try last 3 columns for observed — take the most recent non-None
                        observed = None
                        for idx in range(min(len(cells) - 1, 7), 2, -1):
                            v = _safe_float(cells[idx])
                            if v is not None and v > 0:
                                observed = v
                                break

                        portal_status = cells[-1] if cells else "Normal"
                        canon_key = name.strip().lower()
                        if canon_key in seen_stations:
                            continue
                        seen_stations.add(canon_key)

                        station = _build_station_dict(
                            name, observed, dl_val, portal_status, timestamp, "WRD_BIHAR"
                        )
                        results.append(station)

                # Fallback: raw text line scan when table extractor misses rows
                if not results:
                    text = page.extract_text() or ""
                    for line in text.splitlines():
                        numbers = re.findall(r"\d{2,3}\.\d{2}", line)
                        if len(numbers) < 2:
                            continue
                        # Heuristic: first token(s) are station name
                        tokens = line.split()
                        name_tokens = []
                        for tok in tokens:
                            if re.match(r"^\d+\.\d+$", tok):
                                break
                            name_tokens.append(tok)
                        name = " ".join(name_tokens).strip()
                        if not name or len(name) < 3:
                            continue
                        canon_key = name.lower()
                        if canon_key in seen_stations:
                            continue
                        dl_val   = _safe_float(numbers[0]) if numbers else None
                        observed = _safe_float(numbers[-1]) if numbers else None
                        seen_stations.add(canon_key)
                        results.append(
                            _build_station_dict(
                                name, observed, dl_val, "Normal", timestamp, "WRD_BIHAR"
                            )
                        )

    except Exception as exc:
        logger.warning("[wrd_bihar] PDF parse error: %s", exc)

    return results


def _parse_ganga_pdf(pdf_bytes: bytes, timestamp: str) -> List[Dict[str, Any]]:
    """
    Parse the Ganga Model Result PDF for Ganga-belt observed levels.
    Format: Station | Observed | Forecast D+1 | Forecast D+2 | Forecast D+3
    Only the observed column is extracted.
    """
    try:
        import pdfplumber  # type: ignore
    except ImportError:
        return []

    results: List[Dict[str, Any]] = []
    seen: set = set()

    try:
        with pdfplumber.open(io.BytesIO(pdf_bytes)) as pdf:
            for page in pdf.pages:
                tables = page.extract_tables()
                for table in tables:
                    for row in table:
                        if not row or len(row) < 2:
                            continue
                        cells = [str(c or "").strip() for c in row]
                        name = cells[0]
                        if not name or name.lower() in ("station", "gauge", "location", ""):
                            continue
                        # Observed is col 1 in Ganga PDF layout
                        observed = _safe_float(cells[1]) if len(cells) > 1 else None
                        dl_val   = None
                        # DL may appear in col 2 or 3
                        for idx in (2, 3):
                            if len(cells) > idx:
                                v = _safe_float(cells[idx])
                                if v is not None:
                                    dl_val = v
                                    break
                        canon_key = name.strip().lower()
                        if canon_key in seen:
                            continue
                        # Only accept if we can match registry (Ganga belt stations)
                        if _match_registry(name) is None:
                            continue
                        seen.add(canon_key)
                        results.append(
                            _build_station_dict(
                                name, observed, dl_val, "Normal", timestamp, "WRD_BIHAR"
                            )
                        )
    except Exception as exc:
        logger.warning("[wrd_bihar] Ganga PDF parse error: %s", exc)

    return results


# ---------------------------------------------------------------------------
# HTTP fetch helpers
# ---------------------------------------------------------------------------

_HEADERS = {
    "User-Agent": (
        "OpsFlood/1.0 (Flood Early Warning Research; "
        "contact: opsflood@example.com)"
    ),
    "Accept": "application/pdf,*/*",
}


def _fetch_pdf(url: str) -> Optional[bytes]:
    try:
        resp = requests.get(url, timeout=_SCRAPE_TIMEOUT, headers=_HEADERS)
        resp.raise_for_status()
        if "pdf" in resp.headers.get("content-type", "").lower() or len(resp.content) > 5000:
            return resp.content
        logger.warning("[wrd_bihar] Unexpected content-type from %s", url)
    except requests.exceptions.Timeout:
        logger.warning("[wrd_bihar] Timeout fetching %s", url)
    except requests.exceptions.ConnectionError as exc:
        logger.warning("[wrd_bihar] Connection error fetching %s: %s", url, exc)
    except Exception as exc:
        logger.warning("[wrd_bihar] Error fetching %s: %s", url, exc)
    return None


# ---------------------------------------------------------------------------
# Merge helper: combine bulletin + Ganga PDF results, dedupe by station
# ---------------------------------------------------------------------------

def _merge_pdf_results(
    bulletin: List[Dict[str, Any]],
    ganga: List[Dict[str, Any]],
) -> List[Dict[str, Any]]:
    """Bulletin takes priority; Ganga PDF fills in missing Ganga-belt stations."""
    merged: Dict[str, Dict[str, Any]] = {}
    for s in bulletin:
        merged[s["station"].lower()] = s
    for s in ganga:
        key = s["station"].lower()
        if key not in merged:
            merged[key] = s
    return list(merged.values())


# ---------------------------------------------------------------------------
# Main scraper class
# ---------------------------------------------------------------------------

class WRDBiharScraper:
    """
    Fetches live Bihar flood gauge data from FMISC WRD Bihar PDF bulletins.

    Priority:
      1. FMISC Daily Water Level Bulletin PDF  (all Bihar rivers)
      2. Ganga Model Result PDF               (Ganga belt only, supplementary)
      3. Static BIHAR_STATION_REGISTRY        (off-season / network failure)
    """

    def __init__(self) -> None:
        self._cache:    Optional[List[Dict[str, Any]]] = None
        self._cache_ts: Optional[datetime.datetime]    = None

    # ------------------------------------------------------------------
    # Public API
    # ------------------------------------------------------------------

    def get_live_stations(
        self,
        station_filter: Optional[str] = None,
        limit: int = 20,
    ) -> Dict[str, Any]:
        stations = self._get_cached_or_fetch()

        if station_filter:
            needle   = station_filter.strip().lower()
            stations = [s for s in stations if needle in s["station"].lower()]

        stations    = stations[:limit]
        data_source = stations[0]["data_source"] if stations else "WRD_BIHAR_REGISTRY"
        is_live     = any(s.get("data_source") == "WRD_BIHAR" for s in stations)

        return {
            "status":        "success" if is_live else "fallback",
            "state":         "Bihar",
            "data_source":   data_source,
            "portal_url":    _BULLETIN_PDF_URL,
            "station_count": len(stations),
            "timestamp":     _now_iso(),
            "data":          stations,
        }

    def get_all_stations_for_live_levels(self) -> List[Dict[str, Any]]:
        """Return raw station list for merging into /api/live-levels."""
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
            logger.debug("[wrd_bihar] Returning cached data (%d stations)", len(self._cache))
            return self._cache
        return self._fetch_and_cache()

    def _fetch_and_cache(self) -> List[Dict[str, Any]]:
        timestamp = _now_iso()

        # --- Attempt 1: Daily bulletin PDF (primary) ---
        bulletin_bytes = _fetch_pdf(_BULLETIN_PDF_URL)
        bulletin_data  = _parse_bulletin_pdf(bulletin_bytes, timestamp) if bulletin_bytes else []

        if bulletin_data:
            logger.info(
                "[wrd_bihar] ✅ Bulletin PDF: %d stations parsed", len(bulletin_data)
            )

        # --- Attempt 2: Ganga PDF (supplementary for Ganga belt) ---
        ganga_bytes = _fetch_pdf(_GANGA_PDF_URL)
        ganga_data  = _parse_ganga_pdf(ganga_bytes, timestamp) if ganga_bytes else []

        if ganga_data:
            logger.info(
                "[wrd_bihar] ✅ Ganga PDF: %d stations parsed", len(ganga_data)
            )

        # --- Merge PDF results ---
        live_data = _merge_pdf_results(bulletin_data, ganga_data)

        if live_data:
            self._cache    = live_data
            self._cache_ts = datetime.datetime.utcnow()
            logger.info(
                "[wrd_bihar] ✅ Total live stations cached: %d", len(live_data)
            )
            return live_data

        # --- Fallback: static registry ---
        logger.warning(
            "[wrd_bihar] ⚠️  Both PDFs empty/failed — returning static registry fallback"
        )
        fallback = [_station_from_registry(r, timestamp) for r in BIHAR_STATION_REGISTRY]
        self._cache    = fallback
        self._cache_ts = datetime.datetime.utcnow()
        return fallback


# ---------------------------------------------------------------------------
# Module-level singleton
# ---------------------------------------------------------------------------
wrd_bihar_scraper = WRDBiharScraper()
