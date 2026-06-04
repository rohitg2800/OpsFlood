"""
WRD Bihar Live River Level Router
Scrapes BeFIQR portal (irrigation.befiqr.in) — the official Central Flood
Control Cell, Water Resources Department, Govt of Bihar.

Routes:
  GET /api/wrd-bihar/stations          — all 31 stations (live or fallback)
  GET /api/wrd-bihar/stations/{name}   — single station by name
  GET /api/wrd-bihar/summary           — danger/warning/normal counts + top alerts
  GET /api/wrd-bihar/health            — portal reachability check

DATA SOURCE: WRD Bihar BeFIQR only. No other states or cities.
Live URL: https://irrigation.befiqr.in/state/table/rivers
"""

from __future__ import annotations

import datetime
import os
from typing import Any, Dict, List, Optional

import requests
from bs4 import BeautifulSoup
from fastapi import APIRouter
from cachetools import TTLCache

router = APIRouter(prefix="/api/wrd-bihar", tags=["WRD Bihar"])

# ---------------------------------------------------------------------------
# Cache — 10-minute TTL (BeFIQR updates every ~15 min)
# ---------------------------------------------------------------------------
_CACHE: TTLCache = TTLCache(maxsize=32, ttl=600)

# ---------------------------------------------------------------------------
# BeFIQR scraper targets — CORRECT domain: irrigation.befiqr.in
# Old dead domain was: befiqr.wrd.bih.nic.in (NameResolutionError)
# ---------------------------------------------------------------------------
_WRD_URLS = [
    "https://irrigation.befiqr.in/state/table/rivers",
    "https://irrigation.befiqr.in/state/table/wrd-manual-stations/water-level-obs",
    "http://irrigation.befiqr.in/state/table/rivers",
]

_HEADERS = {
    "User-Agent": (
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
        "AppleWebKit/537.36 (KHTML, like Gecko) "
        "Chrome/124.0.0.0 Safari/537.36"
    ),
    "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
    "Accept-Language": "en-IN,en;q=0.9,hi;q=0.8",
    "Referer": "https://irrigation.befiqr.in/",
}

# ---------------------------------------------------------------------------
# All 31 WRD Bihar stations — exact data from BeFIQR river table
# HFL = Historical Flood Level, DL = Danger Level (both in metres)
# ---------------------------------------------------------------------------
_STATION_REGISTRY: List[Dict[str, Any]] = [
    # Adhwara
    {"station": "Ekmighat",      "river": "Adhwara",      "district": "Darbhanga / Bahadurpur",   "hfl": 49.52, "danger_level_m": 46.94, "lat": 26.095, "lon": 85.902},
    {"station": "Kamtaul",       "river": "Adhwara",      "district": "Darbhanga / Jale",          "hfl": 53.05, "danger_level_m": 50.00, "lat": 26.272, "lon": 85.959},
    {"station": "Sonbarsa",      "river": "Adhwara",      "district": "Sitamarhi / Sonbarsa",      "hfl": 83.20, "danger_level_m": 81.85, "lat": 26.799, "lon": 85.483},
    # Bagmati
    {"station": "Benibad",       "river": "Bagmati",      "district": "Muzaffarpur / Gaighat",     "hfl": 50.12, "danger_level_m": 48.68, "lat": 26.005, "lon": 85.608},
    {"station": "Dheng Bridge",  "river": "Bagmati",      "district": "Sitamarhi / Suppi",         "hfl": 73.47, "danger_level_m": 71.00, "lat": 26.587, "lon": 85.480},
    {"station": "Hayaghat",      "river": "Bagmati",      "district": "Darbhanga / Hayaghat",      "hfl": 48.96, "danger_level_m": 45.72, "lat": 25.985, "lon": 85.806},
    # Burhi Gandak
    {"station": "Khagaria",      "river": "Burhi Gandak", "district": "Khagaria / Khagaria",       "hfl": 39.22, "danger_level_m": 36.58, "lat": 25.502, "lon": 86.467},
    {"station": "Rosera",        "river": "Burhi Gandak", "district": "Samastipur / Rosera",       "hfl": 46.56, "danger_level_m": 42.63, "lat": 25.868, "lon": 85.992},
    {"station": "Samastipur",    "river": "Burhi Gandak", "district": "Samastipur / Samastipur",   "hfl": 49.40, "danger_level_m": 46.00, "lat": 25.877, "lon": 85.782},
    {"station": "Sikandarpur",   "river": "Burhi Gandak", "district": "Muzaffarpur / Musahari",    "hfl": 54.29, "danger_level_m": 52.53, "lat": 26.098, "lon": 85.396},
    # Gandak
    {"station": "Chatia",        "river": "Gandak",       "district": "East Champaran / Areraj",  "hfl": 70.04, "danger_level_m": 69.15, "lat": 26.838, "lon": 84.879},
    {"station": "Dumariaghat",   "river": "Gandak",       "district": "Gopalganj / Sidhwalia",    "hfl": 64.36, "danger_level_m": 62.22, "lat": 26.491, "lon": 84.427},
    {"station": "Hajipur",       "river": "Gandak",       "district": "Vaishali / Hajipur",        "hfl": 50.93, "danger_level_m": 50.32, "lat": 25.686, "lon": 85.208},
    {"station": "Rewaghat",      "river": "Gandak",       "district": "Muzaffarpur / Saraiya",     "hfl": 55.46, "danger_level_m": 54.41, "lat": 25.940, "lon": 85.383},
    # Ganga
    {"station": "Bhagalpur",     "river": "Ganga",        "district": "Bhagalpur / Nathnagar",    "hfl": 34.86, "danger_level_m": 33.68, "lat": 25.244, "lon": 86.972},
    {"station": "Buxar",         "river": "Ganga",        "district": "Buxar / Buxar",             "hfl": 62.10, "danger_level_m": 60.30, "lat": 25.564, "lon": 83.976},
    {"station": "Dighaghat",     "river": "Ganga",        "district": "Patna / Patna Rural",      "hfl": 52.52, "danger_level_m": 50.45, "lat": 25.608, "lon": 85.046},
    {"station": "Gandhighat",    "river": "Ganga",        "district": "Patna / Patna Rural",      "hfl": 50.52, "danger_level_m": 48.60, "lat": 25.594, "lon": 85.138},
    {"station": "Hathidah",      "river": "Ganga",        "district": "Patna / Mokameh",          "hfl": 43.52, "danger_level_m": 41.76, "lat": 25.390, "lon": 85.614},
    {"station": "Kahalgaon",     "river": "Ganga",        "district": "Bhagalpur / Gopalpur",     "hfl": 32.87, "danger_level_m": 31.09, "lat": 25.241, "lon": 87.248},
    {"station": "Munger",        "river": "Ganga",        "district": "Munger / Sadar Munger",    "hfl": 40.99, "danger_level_m": 39.33, "lat": 25.375, "lon": 86.473},
    # Ghaghra
    {"station": "Darauli",       "river": "Ghaghra",      "district": "Siwan / Darauli",           "hfl": 61.82, "danger_level_m": 60.82, "lat": 26.012, "lon": 84.548},
    {"station": "Gangpur Siswan","river": "Ghaghra",      "district": "Siwan / Siswan",            "hfl": 58.26, "danger_level_m": 57.04, "lat": 26.219, "lon": 84.358},
    # Kamalabalan
    {"station": "Jhanjharpur",   "river": "Kamalabalan",  "district": "Madhubani / Jhanjharpur",  "hfl": 53.11, "danger_level_m": 50.00, "lat": 26.264, "lon": 86.280},
    # Kamla
    {"station": "Jainagar",      "river": "Kamla",        "district": "Madhubani / Jainagar",      "hfl": 71.35, "danger_level_m": 67.75, "lat": 26.599, "lon": 85.916},
    # Kosi
    {"station": "Baltara",       "river": "Kosi",         "district": "Khagaria / Beldaur",       "hfl": 36.40, "danger_level_m": 33.85, "lat": 25.458, "lon": 86.584},
    {"station": "Basua",         "river": "Kosi",         "district": "Supaul / Supaul",          "hfl": 49.24, "danger_level_m": 47.75, "lat": 26.124, "lon": 86.604},
    {"station": "Kursela",       "river": "Kosi",         "district": "Katihar / Kursela",        "hfl": 32.10, "danger_level_m": 30.00, "lat": 25.468, "lon": 87.258},
    # Mahananda
    {"station": "Dhengraghat",   "river": "Mahananda",    "district": "Purnia / Baisi",            "hfl": 38.20, "danger_level_m": 35.65, "lat": 26.079, "lon": 87.456},
    {"station": "Taibpur",       "river": "Mahananda",    "district": "Kishanganj / Thakurganj",  "hfl": 67.22, "danger_level_m": 66.00, "lat": 26.399, "lon": 88.016},
    # Punpun
    {"station": "Sripalpur",     "river": "Punpun",       "district": "Patna / Phulwari",         "hfl": 53.91, "danger_level_m": 50.60, "lat": 25.550, "lon": 85.080},
]

_REGISTRY_MAP: Dict[str, Dict[str, Any]] = {
    " ".join(s["station"].lower().split()): s for s in _STATION_REGISTRY
}


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _now_iso() -> str:
    return datetime.datetime.now(datetime.timezone.utc).isoformat()


def _normalize(value: str) -> str:
    return " ".join((value or "").strip().lower().split())


def _safe_float(value: Any) -> Optional[float]:
    try:
        v = str(value).strip().replace(",", "")
        if v in ("", "--", "N/A", "NA", "-", ".", "nil", "NIL"):
            return None
        f = float(v)
        return round(f, 3) if f != 0.0 else None
    except (ValueError, TypeError):
        return None


def _enrich(station_name: str) -> Dict[str, Any]:
    key = _normalize(station_name)
    if key in _REGISTRY_MAP:
        return _REGISTRY_MAP[key]
    for rk, rv in _REGISTRY_MAP.items():
        if rk in key or key in rk:
            return rv
    return {"station": station_name, "river": "Unknown", "district": "Bihar",
            "hfl": None, "danger_level_m": None, "lat": 25.8, "lon": 85.4}


def _status_label(current: Optional[float], danger: Optional[float], hfl: Optional[float]) -> str:
    if current is None:
        return "UNKNOWN"
    if danger and current >= danger:
        return "CRITICAL" if (hfl and current >= hfl * 0.97) else "DANGER"
    if danger and current >= danger * 0.95:
        return "WARNING"
    if current > 0:
        return "NORMAL"
    return "UNKNOWN"


# ---------------------------------------------------------------------------
# BeFIQR table parser
#
# BeFIQR /state/table/rivers column order (1-indexed as shown on site):
#   (1)SL  (2)River  (3)Site  (4)HFL  (5)DL  (6)Yesterday WL
#   (7)Current WL  (8)Diff 24h  (9)Above/Below DL  (10)Trend  (11)District
# Zero-indexed: 0=SL, 1=River, 2=Site, 3=HFL, 4=DL, 5=Yest, 6=Current,
#               7=Diff, 8=AboveDL, 9=Trend, 10=District
# ---------------------------------------------------------------------------

_BEFIQR_COL = {
    "river":   1,
    "site":    2,
    "hfl":     3,
    "dl":      4,
    "yest":    5,
    "current": 6,
    "diff":    7,
    "above":   8,
    "trend":   9,
    "dist":    10,
}


def _parse_befiqr_table(soup: BeautifulSoup) -> List[Dict[str, Any]]:
    stations: List[Dict[str, Any]] = []
    now = _now_iso()

    for table in soup.find_all("table"):
        rows = table.find_all("tr")
        if len(rows) < 3:
            continue

        # Confirm this is the rivers table
        all_text = table.get_text(" ", strip=True).lower()
        if not any(k in all_text for k in ["river", "site", "hfl", "danger"]):
            continue

        # Try to detect column indices dynamically from header rows
        header_cells: List[str] = []
        for hr in rows[:3]:
            cells = [c.get_text(" ", strip=True).lower() for c in hr.find_all(["th", "td"])]
            if len(cells) > len(header_cells):
                header_cells = cells

        def col_idx(keywords: List[str], default: int) -> int:
            for kw in keywords:
                for i, h in enumerate(header_cells):
                    if kw in h:
                        return i
            return default  # fall back to known BeFIQR positional index

        i_river   = col_idx(["river", "nadi"],                         _BEFIQR_COL["river"])
        i_site    = col_idx(["site", "station", "gauge"],              _BEFIQR_COL["site"])
        i_hfl     = col_idx(["hfl"],                                   _BEFIQR_COL["hfl"])
        i_dl      = col_idx(["dl", "danger level", "danger"],         _BEFIQR_COL["dl"])
        i_yest    = col_idx(["yesterday", "previous", "yest"],         _BEFIQR_COL["yest"])
        i_current = col_idx(["current observed", "current wl",
                              "current level", "observed wl"],         _BEFIQR_COL["current"])
        i_diff    = col_idx(["diff", "24", "change"],                  _BEFIQR_COL["diff"])
        i_above   = col_idx(["above", "below danger"],                 _BEFIQR_COL["above"])
        i_trend   = col_idx(["trend", "today"],                        _BEFIQR_COL["trend"])
        i_dist    = col_idx(["district", "block"],                     _BEFIQR_COL["dist"])

        for row in rows[1:]:
            cells = [td.get_text(" ", strip=True) for td in row.find_all("td")]
            if len(cells) < 5:
                continue

            def c(idx: int) -> str:
                return cells[idx].strip() if 0 <= idx < len(cells) else ""

            site = c(i_site)
            if not site or site.lower() in ("site", "station", "sl", "#", "(3)", ""):
                continue
            # Skip header-like rows
            if site.lower() in ("river", "hfl (mts)", "dl (mts)"):
                continue

            river    = c(i_river)
            hfl      = _safe_float(c(i_hfl))
            dl       = _safe_float(c(i_dl))
            yest     = _safe_float(c(i_yest))
            current  = _safe_float(c(i_current))
            diff_24h = _safe_float(c(i_diff))
            above_dl = _safe_float(c(i_above))
            trend    = c(i_trend) or "—"
            district = c(i_dist)

            meta = _enrich(site)
            if not river:       river    = meta.get("river", "Unknown")
            if not district:    district = meta.get("district", "Bihar")
            if hfl is None:     hfl      = meta.get("hfl")
            if dl is None:      dl       = meta.get("danger_level_m")

            below_danger: Optional[float] = None
            if dl and current is not None:
                below_danger = round(dl - current, 3)

            status = _status_label(current, dl, hfl)

            stations.append({
                "station":              site,
                "river":                river,
                "district":             district,
                "lat":                  meta.get("lat", 25.8),
                "lon":                  meta.get("lon", 85.4),
                "hfl_m":                hfl,
                "danger_level_m":       dl,
                "yesterday_level_m":    yest,
                "current_level_m":      current,
                "change_24h_m":         diff_24h,
                "above_below_danger_m": above_dl if above_dl is not None else below_danger,
                "trend":                trend,
                "status":               status,
                "source":               "WRD_BIHAR_BEFIQR",
                "last_update":          now,
            })

        if stations:
            break

    return stations


# ---------------------------------------------------------------------------
# Live fetch
# ---------------------------------------------------------------------------

def _fetch_befiqr_live() -> Dict[str, Any]:
    errors: List[str] = []
    timeout = (
        max(3.0, float(os.getenv("WRD_BIHAR_CONNECT_TIMEOUT", "6"))),
        max(8.0, float(os.getenv("WRD_BIHAR_READ_TIMEOUT", "20"))),
    )

    for url in _WRD_URLS:
        try:
            resp = requests.get(url, headers=_HEADERS, timeout=timeout)
            resp.raise_for_status()
            soup = BeautifulSoup(resp.text, "html.parser")
            stations = _parse_befiqr_table(soup)
            if stations:
                return {
                    "status": "LIVE",
                    "data_source": "WRD_BIHAR_BEFIQR",
                    "source_url": url,
                    "station_count": len(stations),
                    "timestamp": _now_iso(),
                    "stations": stations,
                }
            errors.append(f"{url}: page loaded (HTTP {resp.status_code}) but no table rows extracted")
        except requests.Timeout:
            errors.append(f"{url}: timeout")
        except requests.RequestException as exc:
            errors.append(f"{url}: {exc.__class__.__name__} — {str(exc)[:140]}")

    raise RuntimeError(" | ".join(errors))


# ---------------------------------------------------------------------------
# Fallback — all 31 stations with real HFL/DL, current=None
# ---------------------------------------------------------------------------

def _tactical_fallback() -> Dict[str, Any]:
    now = _now_iso()
    stations = []
    for s in _STATION_REGISTRY:
        stations.append({
            "station":              s["station"],
            "river":                s["river"],
            "district":             s["district"],
            "lat":                  s["lat"],
            "lon":                  s["lon"],
            "hfl_m":                s["hfl"],
            "danger_level_m":       s["danger_level_m"],
            "yesterday_level_m":    None,
            "current_level_m":      None,
            "change_24h_m":         None,
            "above_below_danger_m": None,
            "trend":                "—",
            "status":               "UNKNOWN",
            "source":               "WRD_BIHAR_FALLBACK",
            "last_update":          now,
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
# Shared getter
# ---------------------------------------------------------------------------

async def _get_stations(force_refresh: bool = False) -> Dict[str, Any]:
    cache_key = "wrd_bihar_stations_v3"
    if not force_refresh and cache_key in _CACHE:
        cached = dict(_CACHE[cache_key])
        cached["_cache_hit"] = True
        return cached
    try:
        result = _fetch_befiqr_live()
        _CACHE[cache_key] = result
        result = dict(result)
        result["_cache_hit"] = False
        return result
    except RuntimeError as exc:
        fallback = _tactical_fallback()
        fallback["_scrape_error"] = str(exc)[:500]
        fallback["_cache_hit"] = False
        return fallback


# ---------------------------------------------------------------------------
# Routes
# ---------------------------------------------------------------------------

@router.get("/stations")
async def get_wrd_bihar_stations(
    force_refresh: bool = False,
    river: Optional[str] = None,
    district: Optional[str] = None,
) -> Dict[str, Any]:
    """
    All 31 WRD Bihar river gauge stations from BeFIQR.
    Filters: ?river=Ganga  ?district=Patna  ?force_refresh=true
    """
    result = await _get_stations(force_refresh=force_refresh)
    stations = result.get("stations", [])

    if river:
        rk = _normalize(river)
        stations = [s for s in stations if rk in _normalize(s.get("river", ""))]
    if district:
        dk = _normalize(district)
        stations = [s for s in stations if dk in _normalize(s.get("district", ""))]

    return {**result, "station_count": len(stations), "stations": stations}


@router.get("/stations/{station_name}")
async def get_wrd_bihar_station(station_name: str, force_refresh: bool = False) -> Dict[str, Any]:
    """Single WRD Bihar station by name (case-insensitive partial match)."""
    all_data = await _get_stations(force_refresh=force_refresh)
    key = _normalize(station_name)
    matches = [
        s for s in all_data.get("stations", [])
        if key in _normalize(s.get("station", "")) or _normalize(s.get("station", "")) in key
    ]
    if not matches:
        return {
            "status": "NOT_FOUND",
            "data_source": all_data["data_source"],
            "timestamp": all_data["timestamp"],
            "query": station_name,
            "station": None,
        }
    return {
        "status": all_data["status"],
        "data_source": all_data["data_source"],
        "timestamp": all_data["timestamp"],
        "station": matches[0],
    }


@router.get("/summary")
async def get_wrd_bihar_summary(force_refresh: bool = False) -> Dict[str, Any]:
    """
    Bihar flood situation summary — alert level + station counts + top 5 alerts.
    state_alert_level: RED | ORANGE | YELLOW | GREEN | GREY
    """
    all_data = await _get_stations(force_refresh=force_refresh)
    stations = all_data.get("stations", [])

    counts: Dict[str, int] = {"CRITICAL": 0, "DANGER": 0, "WARNING": 0, "NORMAL": 0, "UNKNOWN": 0}
    alert_stations: List[Dict[str, Any]] = []

    for s in stations:
        status = s.get("status", "UNKNOWN")
        counts[status] = counts.get(status, 0) + 1
        current = s.get("current_level_m")
        dl = s.get("danger_level_m")
        if current is not None and dl and dl > 0:
            alert_stations.append({**s, "_pct_of_danger": round((current / dl) * 100, 1)})

    alert_stations.sort(key=lambda x: x["_pct_of_danger"], reverse=True)

    if counts["CRITICAL"] > 0:   state_alert = "RED"
    elif counts["DANGER"] > 0:   state_alert = "ORANGE"
    elif counts["WARNING"] > 0:  state_alert = "YELLOW"
    elif counts["NORMAL"] > 0:   state_alert = "GREEN"
    else:                         state_alert = "GREY"

    return {
        "status":            all_data["status"],
        "data_source":       all_data["data_source"],
        "timestamp":         all_data["timestamp"],
        "state":             "Bihar",
        "total_stations":    len(stations),
        "state_alert_level": state_alert,
        "station_counts":    counts,
        "top_alerts": [
            {
                "station":         s["station"],
                "river":           s["river"],
                "district":        s["district"],
                "current_level_m": s["current_level_m"],
                "danger_level_m":  s["danger_level_m"],
                "pct_of_danger":   s["_pct_of_danger"],
                "status":          s["status"],
            }
            for s in alert_stations[:5]
        ],
    }


@router.get("/health")
async def wrd_bihar_health() -> Dict[str, Any]:
    """Check if BeFIQR portal (irrigation.befiqr.in) is reachable."""
    primary_url = _WRD_URLS[0]
    try:
        resp = requests.get(primary_url, headers=_HEADERS, timeout=(4, 10))
        return {
            "reachable":   resp.ok,
            "status_code": resp.status_code,
            "url":         primary_url,
            "timestamp":   _now_iso(),
        }
    except requests.RequestException as exc:
        return {
            "reachable": False,
            "error":     str(exc)[:250],
            "url":       primary_url,
            "timestamp": _now_iso(),
        }
