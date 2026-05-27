"""
backend/wrd_bihar_scraper.py

Live flood-station data fetcher for WRD Bihar / FMISC portal.

Data sources (priority order)
------------------------------
1. FMISC Daily Water Level & FF Bulletin PDF
   https://www.fmiscwrdbihar.gov.in/bulletin/fmis%20daily%20water%20level%20and%20FF%20data.pdf
   Updated daily during flood season (Jun 15 – Oct 15).

   Confirmed column layout (pdfplumber, Nov 2025 bulletin):
     col 0 : Sl No.
     col 1 : Name of River          (merged rows — may be blank)
     col 2 : Site/Station           ← station name
     col 3 : District
     col 4 : Danger Level (DL)      ← danger level (m)
     col 5 : H.F.L (m)/Year         (skip)
     col 6 : Observed WL at 8:00 AM ← current observed level
     col 7 : Forecast D+0 (3 PM)
     col 8 : Forecast D+1
     col 9 : Forecast D+2
     col 10: Remarks
     col 11: Compared to DL         ← portal_status ("Below DL", "Above DL", etc.)

2. Ganga Model Result PDF (3-day forecast + observed)
   https://www.fmiscwrdbihar.gov.in/bulletin/Ganga_Model_Result.pdf

3. Static BIHAR_STATION_REGISTRY fallback
   Used off-season or when PDFs are unavailable.

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
from typing import Any, Dict, List, Optional

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
_SCRAPE_TIMEOUT = (8, 25)    # (connect, read) seconds
_CACHE_TTL_SECS = 60 * 60    # 1 hour — bulletin publishes once daily

# Bulletin column indices (confirmed from live PDF diagnostic)
_COL_SL       = 0
_COL_RIVER    = 1
_COL_STATION  = 2
_COL_DISTRICT = 3
_COL_DL       = 4
_COL_HFL      = 5
_COL_OBSERVED = 6
_COL_STATUS   = 11   # "Compared to DL"


# ---------------------------------------------------------------------------
# Static registry — coordinates, danger/warning/safe thresholds
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
    {"station": "Sonakhan",     "river": "Bagmati",      "lat": 26.550, "lon": 85.450,
     "danger_level_m": 68.80, "warning_level_m": 67.80, "safe_level_m": 65.00,
     "pdf_aliases": ["sonakhan"]},
    {"station": "Dubbadhar",    "river": "Bagmati",      "lat": 26.520, "lon": 85.070,
     "danger_level_m": 61.28, "warning_level_m": 60.28, "safe_level_m": 57.00,
     "pdf_aliases": ["dubbadhar"]},
    {"station": "Kansar",       "river": "Bagmati",      "lat": 26.470, "lon": 85.530,
     "danger_level_m": 59.06, "warning_level_m": 58.06, "safe_level_m": 55.00,
     "pdf_aliases": ["kansar"]},
    {"station": "Runisaidpur",  "river": "Bagmati",      "lat": 26.395, "lon": 85.660,
     "danger_level_m": 55.00, "warning_level_m": 54.00, "safe_level_m": 51.00,
     "pdf_aliases": ["runisaidpur", "saulighat"]},
    # Kosi belt stations (appear in bulletin with distance suffixes in PDF)
    {"station": "Chatra Bazar", "river": "Kosi",         "lat": 26.790, "lon": 87.100,
     "danger_level_m": 74.50, "warning_level_m": 73.50, "safe_level_m": 70.00,
     "pdf_aliases": ["chatra bazar", "chatra"]},
    {"station": "Rajabas",      "river": "Kosi",         "lat": 26.680, "lon": 86.980,
     "danger_level_m": 72.00, "warning_level_m": 71.00, "safe_level_m": 68.00,
     "pdf_aliases": ["rajabas"]},
    {"station": "Birpur",       "river": "Kosi",         "lat": 26.510, "lon": 87.030,
     "danger_level_m": 68.00, "warning_level_m": 67.00, "safe_level_m": 64.00,
     "pdf_aliases": ["birpur"]},
    {"station": "Kosi Mahasetu","river": "Kosi",         "lat": 25.960, "lon": 86.960,
     "danger_level_m": 43.28, "warning_level_m": 42.28, "safe_level_m": 39.00,
     "pdf_aliases": ["kosi mahasetu", "mahasetu"]},
    {"station": "Basua",        "river": "Kosi",         "lat": 25.800, "lon": 87.050,
     "danger_level_m": 38.00, "warning_level_m": 37.00, "safe_level_m": 34.00,
     "pdf_aliases": ["basua"]},
    {"station": "Baluwaha Bridge","river": "Gandak",     "lat": 27.100, "lon": 84.350,
     "danger_level_m": 80.00, "warning_level_m": 79.00, "safe_level_m": 76.00,
     "pdf_aliases": ["baluwaha", "baluwaha bridge"]},
    {"station": "Dumri",        "river": "Gandak",       "lat": 26.560, "lon": 84.480,
     "danger_level_m": 68.00, "warning_level_m": 67.00, "safe_level_m": 64.00,
     "pdf_aliases": ["dumri"]},
    {"station": "Baltara",      "river": "Burhi Gandak", "lat": 25.760, "lon": 85.870,
     "danger_level_m": 42.00, "warning_level_m": 41.00, "safe_level_m": 38.00,
     "pdf_aliases": ["baltara"]},
    {"station": "Vijay Ghat Bridge","river": "Gandak",   "lat": 25.940, "lon": 84.730,
     "danger_level_m": 60.00, "warning_level_m": 59.00, "safe_level_m": 56.00,
     "pdf_aliases": ["vijay ghat", "vijay ghat bridge"]},
    {"station": "Dagmara",      "river": "Kamla Balan",  "lat": 26.420, "lon": 86.570,
     "danger_level_m": 60.00, "warning_level_m": 59.00, "safe_level_m": 56.00,
     "pdf_aliases": ["dagmara"]},
    {"station": "Laukaha",      "river": "Kamla Balan",  "lat": 26.400, "lon": 86.090,
     "danger_level_m": 55.00, "warning_level_m": 54.00, "safe_level_m": 51.00,
     "pdf_aliases": ["laukaha"]},
    {"station": "Phulparas",    "river": "Kamla Balan",  "lat": 26.450, "lon": 86.380,
     "danger_level_m": 57.00, "warning_level_m": 56.00, "safe_level_m": 53.00,
     "pdf_aliases": ["phulparas"]},
    {"station": "Jainagar",     "river": "Kamla Balan",  "lat": 26.596, "lon": 86.231,
     "danger_level_m": 65.00, "warning_level_m": 64.00, "safe_level_m": 61.00,
     "pdf_aliases": ["jainagar"]},
    {"station": "Kothram",      "river": "Bagmati",      "lat": 26.650, "lon": 85.700,
     "danger_level_m": 90.00, "warning_level_m": 89.00, "safe_level_m": 86.00,
     "pdf_aliases": ["kothram"]},
    {"station": "Jhawa",        "river": "Bagmati",      "lat": 26.600, "lon": 85.620,
     "danger_level_m": 85.00, "warning_level_m": 84.00, "safe_level_m": 81.00,
     "pdf_aliases": ["jhawa"]},
    {"station": "Buxar",        "river": "Ganga",        "lat": 25.569, "lon": 83.982,
     "danger_level_m": 62.42, "warning_level_m": 61.42, "safe_level_m": 58.00,
     "pdf_aliases": ["buxar"]},
    {"station": "Munger",       "river": "Ganga",        "lat": 25.376, "lon": 86.473,
     "danger_level_m": 38.00, "warning_level_m": 37.00, "safe_level_m": 34.00,
     "pdf_aliases": ["munger"]},
    {"station": "Kahalgaon",    "river": "Ganga",        "lat": 25.241, "lon": 87.273,
     "danger_level_m": 30.17, "warning_level_m": 29.17, "safe_level_m": 26.00,
     "pdf_aliases": ["kahalgaon"]},
    {"station": "Barahkshetra", "river": "Kosi",         "lat": 26.830, "lon": 87.120,
     "danger_level_m": 76.50, "warning_level_m": 75.50, "safe_level_m": 72.00,
     "pdf_aliases": ["barahkshetra", "barah kshetra"]},
    {"station": "Ekmighat",     "river": "Bagmati",      "lat": 26.380, "lon": 85.760,
     "danger_level_m": 50.00, "warning_level_m": 49.00, "safe_level_m": 46.00,
     "pdf_aliases": ["ekmighat", "ekmi ghat"]},
    {"station": "Kamtaul",      "river": "Kamla Balan",  "lat": 26.310, "lon": 86.050,
     "danger_level_m": 50.00, "warning_level_m": 49.00, "safe_level_m": 46.00,
     "pdf_aliases": ["kamtaul"]},
    {"station": "Chatia",       "river": "Burhi Gandak", "lat": 26.350, "lon": 85.150,
     "danger_level_m": 58.00, "warning_level_m": 57.00, "safe_level_m": 54.00,
     "pdf_aliases": ["chatia"]},
    {"station": "Rewaghat",     "river": "Kosi",         "lat": 25.650, "lon": 87.040,
     "danger_level_m": 34.00, "warning_level_m": 33.00, "safe_level_m": 30.00,
     "pdf_aliases": ["rewaghat"]},
    {"station": "Khadda",       "river": "Gandak",       "lat": 26.250, "lon": 84.420,
     "danger_level_m": 65.00, "warning_level_m": 64.00, "safe_level_m": 61.00,
     "pdf_aliases": ["khadda"]},
    {"station": "Lalganj",      "river": "Gandak",       "lat": 25.870, "lon": 85.220,
     "danger_level_m": 56.00, "warning_level_m": 55.00, "safe_level_m": 52.00,
     "pdf_aliases": ["lalganj"]},
]

# Alias -> registry entry lookup
_ALIAS_INDEX: Dict[str, Dict[str, Any]] = {}
for _entry in BIHAR_STATION_REGISTRY:
    for _alias in _entry.get("pdf_aliases", []):
        _ALIAS_INDEX[_alias.lower()] = _entry
    _ALIAS_INDEX[_entry["station"].lower()] = _entry


# ---------------------------------------------------------------------------
# Pure helpers
# ---------------------------------------------------------------------------

def _now_iso() -> str:
    return datetime.datetime.now(datetime.timezone.utc).isoformat()


def _safe_float(val: str) -> Optional[float]:
    try:
        cleaned = re.sub(r"[^\d.\-]", "", str(val).strip())
        return float(cleaned) if cleaned not in ("", "-") else None
    except (ValueError, TypeError):
        return None


def _clean_station_name(raw: str) -> str:
    """
    Normalise a station name from the PDF:
      - Collapse embedded newlines to a single space
      - Strip parenthetical distance suffixes: '(47 km u/s)', '(64.25 km d/s)'
      - Strip leading/trailing whitespace
    """
    # Replace newlines (and any surrounding whitespace) with a single space
    name = re.sub(r"\s*\n\s*", " ", raw)
    # Drop trailing parenthetical: ' (xx km u/s)' or ' (xx km d/s)'
    name = re.sub(r"\s*\(\s*[\d.]+\s*km\s*[ud]/s\s*\)", "", name, flags=re.IGNORECASE)
    return name.strip()


def _risk_level(observed: float, danger: float, warning: float) -> str:
    if danger  > 0 and observed >= danger:         return "CRITICAL"
    if warning > 0 and observed >= warning:        return "HIGH"
    if warning > 0 and observed >= warning * 0.90: return "MODERATE"
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
    needle = name.strip().lower()
    if needle in _ALIAS_INDEX:
        return _ALIAS_INDEX[needle]
    for alias, entry in _ALIAS_INDEX.items():
        if alias in needle or needle in alias:
            return entry
    return None


def _build_station_dict(
    name: str,
    river_pdf: str,
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
        river     = river_pdf or "Unknown"
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
# Bulletin PDF parser  (column layout confirmed from live diagnostic)
# ---------------------------------------------------------------------------

_HEADER_FRAGMENTS = {
    "sl", "no.", "no", "name", "site", "station", "district",
    "danger", "level", "h.f.l", "observed", "forecast",
    "compared", "remarks", "river", "wl", "am", "pm", "year",
}


def _is_header_row(cells: List[str]) -> bool:
    station_cell = cells[_COL_STATION] if len(cells) > _COL_STATION else ""
    sl_cell      = cells[_COL_SL]      if len(cells) > _COL_SL      else ""
    # Reject if sl cell is non-numeric (header continuation rows)
    if sl_cell and not re.match(r"^\d+\.?$", sl_cell.strip()):
        words = station_cell.lower().split()
        if any(w in _HEADER_FRAGMENTS for w in words):
            return True
    # Reject if station cell itself is a header keyword
    words = station_cell.lower().split()
    if words and all(w in _HEADER_FRAGMENTS for w in words[:2]):
        return True
    return False


def _parse_bulletin_pdf(pdf_bytes: bytes, timestamp: str) -> List[Dict[str, Any]]:
    """
    Parse FMISC Daily Water Level Bulletin PDF.

    Column layout (confirmed):
      0=Sl, 1=River, 2=Station, 3=District, 4=DL, 5=HFL,
      6=ObservedWL, 7=FcstD0, 8=FcstD1, 9=FcstD2, 10=Remarks, 11=ComparedToDL
    """
    try:
        import pdfplumber  # type: ignore
    except ImportError:
        logger.warning("[wrd_bihar] pdfplumber not installed — run: pip install pdfplumber")
        return []

    results:   List[Dict[str, Any]] = []
    seen:      set = set()
    last_river = ""

    try:
        with pdfplumber.open(io.BytesIO(pdf_bytes)) as pdf:
            for page in pdf.pages:
                tables = page.extract_tables()
                for table in tables:
                    for row in table:
                        if not row:
                            continue
                        cells = [str(c or "").strip() for c in row]

                        while len(cells) < 12:
                            cells.append("")

                        if _is_header_row(cells):
                            continue

                        # ── Station name: clean newlines + distance suffixes ──
                        raw_name     = cells[_COL_STATION]
                        station_name = _clean_station_name(raw_name)
                        if not station_name or len(station_name) < 2:
                            continue

                        # ── River: carry forward from merged cells ──
                        river_name = _clean_station_name(cells[_COL_RIVER])
                        if river_name:
                            last_river = river_name
                        else:
                            river_name = last_river

                        # ── Levels from confirmed columns ──
                        dl_val   = _safe_float(cells[_COL_DL])
                        observed = _safe_float(cells[_COL_OBSERVED])

                        # Sanity check: Bihar gauge levels are 10–200 m MSL
                        if observed is not None and not (10.0 <= observed <= 200.0):
                            observed = None
                        if dl_val is not None and not (10.0 <= dl_val <= 200.0):
                            dl_val = None

                        portal_status = cells[_COL_STATUS].strip() or "Normal"

                        # Dedup by cleaned lower-case name
                        canon_key = station_name.lower()
                        if canon_key in seen:
                            continue
                        seen.add(canon_key)

                        results.append(
                            _build_station_dict(
                                station_name, river_name, observed,
                                dl_val, portal_status, timestamp, "WRD_BIHAR"
                            )
                        )
                        logger.debug(
                            "[wrd_bihar] %-22s | obs=%-6s | DL=%-6s | %s",
                            station_name, observed, dl_val, portal_status
                        )

    except Exception as exc:
        logger.warning("[wrd_bihar] Bulletin PDF parse error: %s", exc)

    logger.info("[wrd_bihar] Bulletin PDF: %d stations extracted", len(results))
    return results


# ---------------------------------------------------------------------------
# Ganga Model Result PDF parser
# ---------------------------------------------------------------------------

def _parse_ganga_pdf(pdf_bytes: bytes, timestamp: str) -> List[Dict[str, Any]]:
    try:
        import pdfplumber  # type: ignore
    except ImportError:
        return []

    results: List[Dict[str, Any]] = []
    seen:    set = set()

    try:
        with pdfplumber.open(io.BytesIO(pdf_bytes)) as pdf:
            for page in pdf.pages:
                tables = page.extract_tables()
                for table in tables:
                    for row in table:
                        if not row or len(row) < 2:
                            continue
                        cells = [str(c or "").strip() for c in row]
                        name  = _clean_station_name(cells[0])
                        if not name or len(name) < 2:
                            continue
                        words = name.lower().split()
                        if any(w in _HEADER_FRAGMENTS for w in words):
                            continue
                        if _match_registry(name) is None:
                            continue
                        observed = _safe_float(cells[1]) if len(cells) > 1 else None
                        dl_val   = None
                        for idx in (2, 3, 4):
                            if len(cells) > idx:
                                v = _safe_float(cells[idx])
                                if v is not None and 10.0 <= v <= 200.0:
                                    dl_val = v
                                    break
                        canon_key = name.lower()
                        if canon_key in seen:
                            continue
                        seen.add(canon_key)
                        results.append(
                            _build_station_dict(
                                name, "", observed, dl_val,
                                "Normal", timestamp, "WRD_BIHAR"
                            )
                        )
    except Exception as exc:
        logger.warning("[wrd_bihar] Ganga PDF parse error: %s", exc)

    logger.info("[wrd_bihar] Ganga PDF: %d stations extracted", len(results))
    return results


# ---------------------------------------------------------------------------
# HTTP fetch
# ---------------------------------------------------------------------------

_HEADERS = {
    "User-Agent": "OpsFlood/1.0 (Flood Early Warning Research)",
    "Accept":     "application/pdf,*/*",
}


def _fetch_pdf(url: str) -> Optional[bytes]:
    try:
        resp = requests.get(url, timeout=_SCRAPE_TIMEOUT, headers=_HEADERS)
        resp.raise_for_status()
        ct = resp.headers.get("content-type", "").lower()
        if "pdf" in ct or len(resp.content) > 5_000:
            return resp.content
        logger.warning("[wrd_bihar] Unexpected content from %s (ct=%s)", url, ct)
    except requests.exceptions.Timeout:
        logger.warning("[wrd_bihar] Timeout: %s", url)
    except requests.exceptions.ConnectionError as exc:
        logger.warning("[wrd_bihar] Connection error: %s | %s", url, exc)
    except Exception as exc:
        logger.warning("[wrd_bihar] Fetch error: %s | %s", url, exc)
    return None


# ---------------------------------------------------------------------------
# Merge
# ---------------------------------------------------------------------------

def _merge_pdf_results(
    bulletin: List[Dict[str, Any]],
    ganga: List[Dict[str, Any]],
) -> List[Dict[str, Any]]:
    """Bulletin is authoritative; Ganga PDF fills in missing Ganga-belt entries."""
    merged: Dict[str, Dict[str, Any]] = {s["station"].lower(): s for s in bulletin}
    for s in ganga:
        key = s["station"].lower()
        if key not in merged:
            merged[key] = s
    return list(merged.values())


# ---------------------------------------------------------------------------
# Main scraper class
# ---------------------------------------------------------------------------

class WRDBiharScraper:
    """TTL-cached PDF fetcher for FMISC WRD Bihar flood bulletin."""

    def __init__(self) -> None:
        self._cache:    Optional[List[Dict[str, Any]]] = None
        self._cache_ts: Optional[datetime.datetime]    = None

    def get_live_stations(
        self,
        station_filter: Optional[str] = None,
        limit: int = 50,
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
        return self._get_cached_or_fetch()

    def _cache_valid(self) -> bool:
        if self._cache is None or self._cache_ts is None:
            return False
        age = (datetime.datetime.utcnow() - self._cache_ts).total_seconds()
        return age < _CACHE_TTL_SECS

    def _get_cached_or_fetch(self) -> List[Dict[str, Any]]:
        if self._cache_valid() and self._cache:
            logger.debug("[wrd_bihar] cache hit (%d stations)", len(self._cache))
            return self._cache
        return self._fetch_and_cache()

    def _fetch_and_cache(self) -> List[Dict[str, Any]]:
        timestamp = _now_iso()

        bulletin_bytes = _fetch_pdf(_BULLETIN_PDF_URL)
        bulletin_data  = _parse_bulletin_pdf(bulletin_bytes, timestamp) if bulletin_bytes else []

        ganga_bytes = _fetch_pdf(_GANGA_PDF_URL)
        ganga_data  = _parse_ganga_pdf(ganga_bytes, timestamp) if ganga_bytes else []

        live_data = _merge_pdf_results(bulletin_data, ganga_data)

        if live_data:
            self._cache    = live_data
            self._cache_ts = datetime.datetime.utcnow()
            logger.info("[wrd_bihar] ✅ Cached %d live stations", len(live_data))
            return live_data

        logger.warning("[wrd_bihar] ⚠️  PDFs empty/failed — using registry fallback")
        fallback = [_station_from_registry(r, timestamp) for r in BIHAR_STATION_REGISTRY]
        self._cache    = fallback
        self._cache_ts = datetime.datetime.utcnow()
        return fallback


# ---------------------------------------------------------------------------
# Module-level singleton
# ---------------------------------------------------------------------------
wrd_bihar_scraper = WRDBiharScraper()
