"""
Live Levels router: Serves /api/live-levels and /api/critical-alerts
for the OpsFlood Flutter app.

Data priority order:
  1. WRD Bihar BeFIQR (31 real gauge stations with HFL + DL) — Bihar only
  2. GloFAS Open-Meteo cache (real river discharge) — all other states
  3. STATE_SEVERITY_MATRIX fallback — states with no live data
"""

from fastapi import APIRouter
from typing import Any, Dict, List, Optional
import sys

from .dependencies import (
    STATE_SEVERITY_MATRIX,
    current_timestamp_iso,
)

router = APIRouter(tags=["live-levels"])


# ---------------------------------------------------------------------------
# Cache accessors (avoid circular imports via sys.modules)
# ---------------------------------------------------------------------------

def _get_glofas_cache() -> List[Dict[str, Any]]:
    """GloFAS station list built by app.py warm_cache thread."""
    try:
        for mod_name in ("backend.app", "app"):
            mod = sys.modules.get(mod_name)
            if mod is not None:
                cache = getattr(mod, "GLOFAS_STATION_CACHE", None)
                if isinstance(cache, list) and len(cache) > 0:
                    return cache
    except Exception:
        pass
    return []


def _get_wrd_bihar_stations() -> List[Dict[str, Any]]:
    """
    Pull latest WRD Bihar station list from the BeFIQR router cache.
    Returns [] if not yet populated.
    """
    try:
        for mod_name in ("backend.routers.wrd_bihar", "routers.wrd_bihar"):
            mod = sys.modules.get(mod_name)
            if mod is not None:
                cache = getattr(mod, "_CACHE", None)
                cache_key = getattr(mod, "_CACHE_KEY", None)
                if cache is not None and cache_key and cache_key in cache:
                    return cache[cache_key].get("stations", [])
    except Exception:
        pass
    return []


# ---------------------------------------------------------------------------
# Risk / status helpers
# ---------------------------------------------------------------------------

def _risk_from_capacity(cap: float) -> str:
    if cap >= 85: return "CRITICAL"
    if cap >= 70: return "HIGH"
    if cap >= 50: return "MODERATE"
    return "LOW"

def _risk_from_discharge(discharge: float, danger_q: float, warning_q: float) -> str:
    if danger_q > 0 and discharge >= danger_q:          return "CRITICAL"
    if warning_q > 0 and discharge >= warning_q:        return "HIGH"
    if warning_q > 0 and discharge >= warning_q * 0.7:  return "MODERATE"
    return "LOW"

def _risk_from_wrd_status(status: str) -> str:
    return {
        "CRITICAL": "CRITICAL",
        "DANGER":   "HIGH",
        "WARNING":  "MODERATE",
        "NORMAL":   "LOW",
    }.get((status or "").upper(), "LOW")

def _capacity_from_discharge(discharge: float, danger_q: float) -> float:
    if danger_q <= 0:
        return 50.0
    return min(round(discharge / danger_q * 100.0, 1), 100.0)

def _capacity_from_levels(current_m: float, safe_m: float, danger_m: float) -> float:
    span = danger_m - safe_m
    if span <= 0:
        return 50.0
    return min(round((current_m - safe_m) / span * 100.0, 1), 100.0)

def _status_from_risk(risk: str) -> str:
    return {"CRITICAL": "RISING", "HIGH": "RISING",
            "MODERATE": "STABLE", "LOW": "STABLE"}.get(risk, "STABLE")

def _alert_from_risk(risk: str) -> str:
    return {"CRITICAL": "\U0001f6a8", "HIGH": "\u26a0\ufe0f",
            "MODERATE": "\U0001f4ca", "LOW": "\u2705"}.get(risk, "\U0001f4ca")


# ---------------------------------------------------------------------------
# Base level tables (metre thresholds per state)
# ---------------------------------------------------------------------------

_BASE_LEVELS: Dict[str, Dict[str, float]] = {
    "maharashtra":      {"safe": 2.0, "warning": 3.5, "danger": 5.0, "cap": 78.0},
    "kerala":           {"safe": 1.8, "warning": 2.8, "danger": 4.0, "cap": 74.0},
    "assam":            {"safe": 3.0, "warning": 5.0, "danger": 7.5, "cap": 88.0},
    "bihar":            {"safe": 4.0, "warning": 6.0, "danger": 8.0, "cap": 86.0},
    "odisha":           {"safe": 3.5, "warning": 5.5, "danger": 7.0, "cap": 65.0},
    "west_bengal":      {"safe": 3.0, "warning": 5.0, "danger": 6.5, "cap": 62.0},
    "uttar_pradesh":    {"safe": 4.5, "warning": 6.5, "danger": 9.0, "cap": 55.0},
    "andhra_pradesh":   {"safe": 3.0, "warning": 4.5, "danger": 6.0, "cap": 73.0},
    "telangana":        {"safe": 2.5, "warning": 4.0, "danger": 5.5, "cap": 60.0},
    "karnataka":        {"safe": 2.0, "warning": 3.5, "danger": 5.0, "cap": 55.0},
    "gujarat":          {"safe": 2.0, "warning": 3.5, "danger": 5.0, "cap": 42.0},
    "rajasthan":        {"safe": 1.5, "warning": 2.5, "danger": 3.5, "cap": 38.0},
    "madhya_pradesh":   {"safe": 3.0, "warning": 4.5, "danger": 6.0, "cap": 52.0},
    "chhattisgarh":     {"safe": 2.5, "warning": 4.0, "danger": 5.5, "cap": 48.0},
    "jharkhand":        {"safe": 2.5, "warning": 4.0, "danger": 5.5, "cap": 50.0},
    "punjab":           {"safe": 2.5, "warning": 4.0, "danger": 5.5, "cap": 54.0},
    "haryana":          {"safe": 2.0, "warning": 3.5, "danger": 5.0, "cap": 46.0},
    "himachal_pradesh": {"safe": 2.0, "warning": 3.5, "danger": 5.0, "cap": 52.0},
    "uttarakhand":      {"safe": 2.0, "warning": 3.5, "danger": 5.0, "cap": 52.0},
    "tamil_nadu":       {"safe": 2.0, "warning": 3.5, "danger": 5.0, "cap": 48.0},
    "arunachal_pradesh":{"safe": 3.0, "warning": 5.0, "danger": 7.5, "cap": 67.0},
    "manipur":          {"safe": 1.5, "warning": 2.5, "danger": 3.5, "cap": 44.0},
    "meghalaya":        {"safe": 1.5, "warning": 2.5, "danger": 3.5, "cap": 48.0},
    "nagaland":         {"safe": 1.5, "warning": 2.5, "danger": 3.5, "cap": 38.0},
    "mizoram":          {"safe": 1.5, "warning": 2.5, "danger": 3.5, "cap": 38.0},
    "tripura":          {"safe": 1.5, "warning": 2.5, "danger": 3.5, "cap": 46.0},
    "sikkim":           {"safe": 1.5, "warning": 2.5, "danger": 3.5, "cap": 58.0},
    "goa":              {"safe": 1.5, "warning": 2.5, "danger": 3.5, "cap": 32.0},
    "delhi":            {"safe": 2.5, "warning": 4.0, "danger": 6.0, "cap": 50.0},
    "jammu_and_kashmir":{"safe": 2.0, "warning": 3.5, "danger": 5.5, "cap": 62.0},
}

_CITY_RIVER_MAP: Dict[str, tuple] = {
    "maharashtra":      ("Kolhapur",   "Panchganga"),
    "kerala":           ("Kochi",      "Periyar"),
    "assam":            ("Guwahati",   "Brahmaputra"),
    "bihar":            ("Patna",      "Ganga"),
    "odisha":           ("Cuttack",    "Mahanadi"),
    "west_bengal":      ("Kolkata",    "Hooghly"),
    "uttar_pradesh":    ("Varanasi",   "Ganga"),
    "andhra_pradesh":   ("Vijayawada", "Krishna"),
    "telangana":        ("Hyderabad",  "Musi"),
    "karnataka":        ("Mysuru",     "Kaveri"),
    "gujarat":          ("Vadodara",   "Vishwamitri"),
    "rajasthan":        ("Kota",       "Chambal"),
    "madhya_pradesh":   ("Jabalpur",   "Narmada"),
    "chhattisgarh":     ("Raipur",     "Mahanadi"),
    "jharkhand":        ("Dhanbad",    "Damodar"),
    "punjab":           ("Ludhiana",   "Sutlej"),
    "haryana":          ("Ambala",     "Ghaggar"),
    "himachal_pradesh": ("Mandi",      "Beas"),
    "uttarakhand":      ("Haridwar",   "Ganga"),
    "tamil_nadu":       ("Chennai",    "Adyar"),
    "arunachal_pradesh":("Pasighat",   "Brahmaputra"),
    "manipur":          ("Imphal",     "Imphal River"),
    "meghalaya":        ("Shillong",   "Umiam"),
    "nagaland":         ("Dimapur",    "Dhansiri"),
    "mizoram":          ("Aizawl",     "Tlawng"),
    "tripura":          ("Agartala",   "Haora"),
    "sikkim":           ("Gangtok",    "Teesta"),
    "goa":              ("Panaji",     "Mandovi"),
    "delhi":            ("New Delhi",  "Yamuna"),
    "jammu_and_kashmir":("Srinagar",   "Jhelum"),
}

_STATE_DISPLAY: Dict[str, str] = {
    "maharashtra": "Maharashtra", "kerala": "Kerala", "assam": "Assam",
    "bihar": "Bihar", "odisha": "Odisha", "west_bengal": "West Bengal",
    "uttar_pradesh": "Uttar Pradesh", "andhra_pradesh": "Andhra Pradesh",
    "telangana": "Telangana", "karnataka": "Karnataka", "gujarat": "Gujarat",
    "rajasthan": "Rajasthan", "madhya_pradesh": "Madhya Pradesh",
    "chhattisgarh": "Chhattisgarh", "jharkhand": "Jharkhand",
    "punjab": "Punjab", "haryana": "Haryana",
    "himachal_pradesh": "Himachal Pradesh", "uttarakhand": "Uttarakhand",
    "tamil_nadu": "Tamil Nadu", "arunachal_pradesh": "Arunachal Pradesh",
    "manipur": "Manipur", "meghalaya": "Meghalaya", "nagaland": "Nagaland",
    "mizoram": "Mizoram", "tripura": "Tripura", "sikkim": "Sikkim",
    "goa": "Goa", "delhi": "Delhi", "jammu_and_kashmir": "Jammu and Kashmir",
}


def _normalise_state_key(s: str) -> str:
    return s.strip().lower().replace(" ", "_").replace("-", "_")


# ---------------------------------------------------------------------------
# WRD Bihar builder  — 31 individual gauge stations
# ---------------------------------------------------------------------------

def _build_levels_from_wrd_bihar(
    wrd_stations: List[Dict[str, Any]],
) -> List[Dict[str, Any]]:
    """
    Convert all 31 WRD Bihar BeFIQR stations to the live-levels wire format.
    Each station becomes its own row (multi-station view for Bihar).
    Fields used: station, river, district, lat, lon,
                 current_level_m, danger_level_m, hfl_m,
                 above_below_danger_m, change_24h_m, trend, status.
    """
    now_iso = current_timestamp_iso()
    base    = _BASE_LEVELS.get("bihar", {"safe": 4.0, "warning": 6.0, "danger": 8.0})
    result: List[Dict[str, Any]] = []

    for s in wrd_stations:
        city        = str(s.get("station") or "").strip()
        river       = str(s.get("river") or "Unknown").strip()
        district    = str(s.get("district") or "Bihar").strip()
        lat         = s.get("lat", 25.8)
        lon         = s.get("lon", 85.4)
        current_m   = s.get("current_level_m")      # may be None (BeFIQR not updated yet)
        danger_m    = s.get("danger_level_m") or base["danger"]
        hfl_m       = s.get("hfl_m")
        safe_m      = base["safe"]
        warning_m   = base["warning"]
        above_dl    = s.get("above_below_danger_m")  # +ve = above DL, -ve = below DL
        change_24h  = s.get("change_24h_m")
        trend       = s.get("trend", "—")
        wrd_status  = s.get("status", "UNKNOWN")
        source_raw  = s.get("source", "WRD_BIHAR_BEFIQR")
        last_update = s.get("last_update", now_iso)

        if city == "":
            continue

        # Capacity percent: use current vs danger if available
        if current_m is not None and danger_m > 0:
            capacity = _capacity_from_levels(current_m, safe_m, danger_m)
        else:
            # Fallback: derive from WRD status label
            capacity = {"CRITICAL": 96.0, "DANGER": 88.0,
                        "WARNING": 70.0, "NORMAL": 40.0}.get(wrd_status.upper(), 50.0)

        risk   = _risk_from_wrd_status(wrd_status) if wrd_status != "UNKNOWN" \
                 else _risk_from_capacity(capacity)
        status = _status_from_risk(risk)
        alert  = _alert_from_risk(risk)

        result.append({
            # Standard live-levels fields (Flutter app reads these)
            "city":                 city,
            "state":                "Bihar",
            "river_name":           river,
            "station":              city,
            "current_level":        current_m,
            "safe_level":           safe_m,
            "warning_level":        warning_m,
            "danger_level":         danger_m,
            "capacity_percent":     round(max(0.0, capacity), 1),
            "risk_level":           risk,
            "status":               status,
            "alert":                alert,
            "flow_rate":            None,   # WRD reports metres, not m3/s
            "lat":                  lat,
            "lon":                  lon,
            "data_source":          "WRD_BIHAR_BEFIQR" if "FALLBACK" not in source_raw else "WRD_BIHAR_FALLBACK",
            "timestamp":            last_update,
            # Extended Bihar-specific fields
            "hfl_m":                hfl_m,
            "district":             district,
            "above_below_danger_m": above_dl,
            "change_24h_m":         change_24h,
            "trend":                trend,
            "wrd_status":           wrd_status,
        })

    return result


# ---------------------------------------------------------------------------
# GloFAS builder  — all states except Bihar (which uses WRD)
# ---------------------------------------------------------------------------

def _build_station_record(
    station: Dict[str, Any],
    now_iso: str,
    state_key: str,
) -> Dict[str, Any]:
    city      = str(station.get("station_name") or station.get("city") or "").strip()
    state     = str(station.get("state_name")   or station.get("state") or "").strip()
    river     = str(station.get("river_name")   or station.get("river") or "").strip()
    discharge = float(station.get("river_discharge") or 0.0)
    warning_q = float(station.get("warning_discharge") or 0.0)
    danger_q  = float(station.get("danger_discharge")  or 0.0)
    base      = _BASE_LEVELS.get(state_key, {"safe": 2.0, "warning": 3.5, "danger": 5.0})
    current_m = float(station.get("current_level_m") or 0.0)
    warning_m = float(station.get("warning_level_m") or base["warning"])
    danger_m  = float(station.get("danger_level_m")  or base["danger"])
    safe_m    = float(station.get("safe_level_m")    or base["safe"])

    if current_m == 0.0 and discharge > 0 and danger_q > 0:
        current_m = round(safe_m + (danger_m - safe_m) * (discharge / danger_q), 2)
        current_m = min(current_m, danger_m * 1.5)

    capacity = _capacity_from_discharge(discharge, danger_q) if danger_q > 0 \
               else _capacity_from_levels(current_m, safe_m, danger_m)
    risk     = str(station.get("risk_level") or "").upper() or \
               _risk_from_discharge(discharge, danger_q, warning_q)
    ts       = str(station.get("timestamp") or now_iso)

    return {
        "city":             city,
        "state":            state,
        "river_name":       river,
        "station":          city,
        "current_level":    current_m,
        "safe_level":       safe_m,
        "warning_level":    warning_m,
        "danger_level":     danger_m,
        "river_discharge":  discharge,
        "capacity_percent": capacity,
        "risk_level":       risk,
        "status":           _status_from_risk(risk),
        "alert":            _alert_from_risk(risk),
        "flow_rate":        discharge if discharge > 0 else None,
        "lat":              station.get("lat"),
        "lon":              station.get("lon"),
        "data_source":      "OPEN_METEO_GLOFAS",
        "timestamp":        ts,
        "_discharge":       discharge,
    }


def _build_levels_from_glofas(
    glofas_cache: List[Dict],
    exclude_state_keys: set,
) -> tuple:
    """
    Highest-discharge-wins deduplication per state.
    Skips any state in exclude_state_keys (e.g. Bihar handled by WRD).
    """
    now_iso = current_timestamp_iso()
    best_by_state: Dict[str, Dict[str, Any]] = {}

    for station in glofas_cache:
        city  = str(station.get("station_name") or station.get("city") or "").strip()
        state = str(station.get("state_name")   or station.get("state") or "").strip()
        if not city or not state:
            continue
        state_key = _normalise_state_key(state)
        if state_key in exclude_state_keys:
            continue

        record    = _build_station_record(station, now_iso, state_key)
        discharge = record["_discharge"]
        existing  = best_by_state.get(state_key)
        if existing is None or discharge > existing["_discharge"]:
            best_by_state[state_key] = record

    result: List[Dict[str, Any]] = []
    for record in best_by_state.values():
        record.pop("_discharge", None)
        result.append(record)

    return result, set(best_by_state.keys())


# ---------------------------------------------------------------------------
# Matrix fallback  — states with no live data at all
# ---------------------------------------------------------------------------

def _build_levels_from_matrix(exclude_state_keys: set) -> List[Dict[str, Any]]:
    now_iso = current_timestamp_iso()
    result: List[Dict[str, Any]] = []
    seen: set = set()

    for state_key, entry in STATE_SEVERITY_MATRIX.items():
        if state_key in seen or state_key in exclude_state_keys:
            continue
        seen.add(state_key)

        base          = _BASE_LEVELS.get(state_key, {"safe": 2.0, "warning": 3.5, "danger": 5.0, "cap": 50.0})
        city, river   = _CITY_RIVER_MAP.get(state_key, ("Unknown", "River"))
        state_display = _STATE_DISPLAY.get(state_key, state_key.replace("_", " ").title())
        severity      = entry.get("default_severity", "MODERATE").upper()
        capacity      = {"CRITICAL": 88.0, "HIGH": 75.0, "MODERATE": 55.0, "LOW": 35.0}.get(severity, base.get("cap", 50.0))
        risk          = _risk_from_capacity(capacity)
        danger_m      = float(entry.get("danger_threshold_m")  or base["danger"])
        warning_m     = float(entry.get("warning_threshold_m") or base["warning"])
        safe_m        = base["safe"]
        current       = round(safe_m + (danger_m - safe_m) * (capacity / 100.0), 2)

        result.append({
            "city":             city,
            "state":            state_display,
            "river_name":       river,
            "station":          city,
            "current_level":    current,
            "safe_level":       safe_m,
            "warning_level":    warning_m,
            "danger_level":     danger_m,
            "capacity_percent": round(capacity, 1),
            "risk_level":       risk,
            "status":           _status_from_risk(risk),
            "alert":            _alert_from_risk(risk),
            "flow_rate":        None,
            "data_source":      "STATE_SEVERITY_MATRIX",
            "timestamp":        now_iso,
        })

    result.sort(key=lambda x: x["capacity_percent"], reverse=True)
    return result


# ---------------------------------------------------------------------------
# Master merge
# ---------------------------------------------------------------------------

def _build_all_levels() -> List[Dict[str, Any]]:
    """
    Priority merge:
      1. WRD Bihar  — 31 real gauge stations (individual rows)
      2. GloFAS     — best station per non-Bihar state
      3. Matrix     — fallback for states with no live source
    """
    covered: set = set()
    all_levels: List[Dict[str, Any]] = []

    # ── 1. WRD Bihar (“best source” for Bihar) ─────────────────────────────
    wrd_stations = _get_wrd_bihar_stations()
    if wrd_stations:
        bihar_levels = _build_levels_from_wrd_bihar(wrd_stations)
        all_levels.extend(bihar_levels)
        covered.add("bihar")
        print(f"[live_levels] \u2705 WRD Bihar: {len(bihar_levels)} stations")
    else:
        print("[live_levels] \u26a0\ufe0f  WRD Bihar cache empty — Bihar will use GloFAS/matrix")

    # ── 2. GloFAS (skip Bihar if already covered) ──────────────────────────
    glofas_cache = _get_glofas_cache()
    if glofas_cache:
        glofas_levels, glofas_covered = _build_levels_from_glofas(glofas_cache, exclude_state_keys=covered)
        all_levels.extend(glofas_levels)
        covered.update(glofas_covered)
        print(f"[live_levels] \u2705 GloFAS: {len(glofas_levels)} states")
    else:
        print("[live_levels] \u26a0\ufe0f  GloFAS cache empty")

    # ── 3. Matrix fallback for remaining states ───────────────────────────
    matrix_levels = _build_levels_from_matrix(exclude_state_keys=covered)
    all_levels.extend(matrix_levels)
    print(f"[live_levels] Matrix fallback: {len(matrix_levels)} states")

    all_levels.sort(key=lambda x: x["capacity_percent"], reverse=True)
    return all_levels


# ---------------------------------------------------------------------------
# Routes
# ---------------------------------------------------------------------------

@router.get("/api/live-levels")
async def get_live_levels(
    state: Optional[str] = None,
    limit: int = 100,
    river: Optional[str] = None,
):
    """
    All river gauge stations.
    Bihar returns 31 individual WRD stations (HFL + DL + current level).
    Other states return one representative GloFAS/matrix entry each.
    Optional filters: ?state=Bihar ?river=Bagmati ?limit=10
    """
    levels = _build_all_levels()

    if state:
        norm   = state.strip().lower()
        levels = [l for l in levels if norm in l["state"].lower()]
    if river:
        rn = river.strip().lower()
        levels = [l for l in levels if rn in l.get("river_name", "").lower()]

    levels = levels[:limit]

    wrd_count    = sum(1 for l in levels if "WRD_BIHAR" in l.get("data_source", ""))
    glofas_count = sum(1 for l in levels if l.get("data_source") == "OPEN_METEO_GLOFAS")
    matrix_count = len(levels) - wrd_count - glofas_count

    if wrd_count > 0 and glofas_count > 0:
        data_source = "WRD+GLOFAS+MATRIX"
    elif wrd_count > 0:
        data_source = "WRD+MATRIX"
    elif glofas_count > 0:
        data_source = "GLOFAS+MATRIX"
    else:
        data_source = "OPSFLOOD_MATRIX"

    return {
        "status":       "success",
        "data_source":  data_source,
        "wrd_count":    wrd_count,
        "glofas_count": glofas_count,
        "matrix_count": matrix_count,
        "total":        len(levels),
        "timestamp":    current_timestamp_iso(),
        "data":         levels,
    }


@router.get("/api/critical-alerts")
async def get_critical_alerts(
    state: Optional[str] = None,
    severity: Optional[str] = None,
):
    levels  = _build_all_levels()
    now_iso = current_timestamp_iso()
    alerts  = []

    for item in levels:
        risk = item["risk_level"]
        if risk not in ("HIGH", "CRITICAL"):
            continue
        if state    and state.strip().lower()    not in item["state"].lower():  continue
        if severity and severity.strip().upper() != risk:                       continue

        alerts.append({
            "id":             f"{item['city']}_{item['state']}_alert".replace(" ", "_"),
            "city":           item["city"],
            "state":          item["state"],
            "severity":       risk,
            "title":          f"{item['city']} flood alert",
            "message":        (
                f"{item.get('river_name', 'River')} at "
                f"{item['capacity_percent']:.0f}% of danger level — {risk.lower()} risk."
            ),
            "river_name":     item.get("river_name", ""),
            "district":       item.get("district"),
            "current_level":  item["current_level"],
            "danger_level":   item["danger_level"],
            "hfl_m":          item.get("hfl_m"),
            "above_below_danger_m": item.get("above_below_danger_m"),
            "change_24h_m":   item.get("change_24h_m"),
            "trend":          item.get("trend"),
            "data_source":    item.get("data_source", "UNKNOWN"),
            "timestamp":      now_iso,
            "resolved":       False,
            "recommendation": (
                "Immediate evacuation. Contact NDRF."
                if risk == "CRITICAL" else
                "Alert district admin. Pre-position rescue teams."
            ),
        })

    return {
        "status":    "success",
        "total":     len(alerts),
        "timestamp": now_iso,
        "data":      alerts,
    }
