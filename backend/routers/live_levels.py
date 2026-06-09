"""
Live Levels router: Serves /api/live-levels and /api/critical-alerts
for the OpsFlood Flutter app.

Data priority order:
  1. WRD Bihar BeFIQR (31 real gauge stations with HFL + DL) — Bihar only
  2. GloFAS Open-Meteo cache (real river discharge) — all other states
  3. STATE_SEVERITY_MATRIX fallback — states with no live data

Risk thresholds (Bihar ASL gauges, aligned with WRD Bihar definitions):
  CRITICAL  — above_dl >= 0       (at or above danger level)
  HIGH      — above_dl in [-3, 0) (within WRD WARNING zone, <3 m below DL)
  MODERATE  — above_dl in [-6,-3) (approaching, 3–6 m below DL)
  LOW       — above_dl < -6       (well below danger level)
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
# Cache accessors
# ---------------------------------------------------------------------------

def _get_glofas_cache() -> List[Dict[str, Any]]:
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
    try:
        for mod_name in ("backend.routers.wrd_bihar", "routers.wrd_bihar"):
            mod = sys.modules.get(mod_name)
            if mod is not None:
                cache     = getattr(mod, "_CACHE", None)
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
    if cap >= 100: return "CRITICAL"
    if cap >= 85:  return "HIGH"
    if cap >= 70:  return "MODERATE"
    return "LOW"


def _risk_from_discharge(discharge: float, danger_q: float, warning_q: float) -> str:
    if danger_q > 0 and discharge >= danger_q:         return "CRITICAL"
    if warning_q > 0 and discharge >= warning_q:       return "HIGH"
    if warning_q > 0 and discharge >= warning_q * 0.7: return "MODERATE"
    return "LOW"


def _risk_from_above_dl(above_dl: Optional[float], wrd_status: str) -> str:
    """
    Converts signed above_below_danger_m to OpsFlood risk level.

    Aligned with WRD Bihar status boundaries:
      WRD CRITICAL/DANGER  = at or above DL    → CRITICAL
      WRD WARNING          = within 3 m of DL  → HIGH
      (approaching)        = 3–6 m below DL   → MODERATE
      WRD NORMAL           = > 6 m below DL    → LOW

    Falls back to wrd_status string if above_dl is None.
    """
    if above_dl is not None:
        if above_dl >= 0:   return "CRITICAL"   # at or above danger level
        if above_dl >= -3.0: return "HIGH"      # WRD WARNING zone: within 3 m
        if above_dl >= -6.0: return "MODERATE"  # approaching: 3–6 m below DL
        return "LOW"                             # WRD NORMAL: > 6 m below DL

    # Fallback when current_level is unknown (scrape gap)
    return {
        "CRITICAL": "CRITICAL",
        "DANGER":   "HIGH",
        "WARNING":  "HIGH",
        "NORMAL":   "LOW",
        "UNKNOWN":  "LOW",
    }.get((wrd_status or "").upper(), "LOW")


def _capacity_from_discharge(discharge: float, danger_q: float) -> float:
    if danger_q <= 0:
        return 50.0
    return min(round(discharge / danger_q * 100.0, 1), 130.0)


def _capacity_from_asl_levels(
    current_m: Optional[float],
    danger_m: float,
    hfl_m: Optional[float],
    above_dl: Optional[float],
) -> float:
    """
    Bihar gauges are in absolute metres above sea level (ASL).
    capacity_percent uses a +-10 m operational window around DL:
      100% = river exactly at danger level
      >100% = river above danger level (flooding)
       0%  = river 10 m below danger level (dry season low)

    Thresholds align with _risk_from_above_dl:
      >= 100%  CRITICAL  (above_dl >= 0)
      >= 70%   HIGH      (above_dl in [-3, 0))
      >= 40%   MODERATE  (above_dl in [-6, -3))
      <  40%   LOW       (above_dl < -6)
    """
    if above_dl is not None:
        span = 10.0  # operational window: 10 m below DL = 0%, at DL = 100%
        pct  = 100.0 + (above_dl / span * 100.0)
        return round(min(max(pct, 0.0), 130.0), 1)

    if current_m is not None and danger_m > 0:
        span  = 10.0
        above = current_m - danger_m
        pct   = 100.0 + (above / span * 100.0)
        return round(min(max(pct, 0.0), 130.0), 1)

    return 50.0


def _status_from_risk(risk: str) -> str:
    return {"CRITICAL": "RISING", "HIGH": "RISING",
            "MODERATE": "STABLE", "LOW": "STABLE"}.get(risk, "STABLE")


def _alert_from_risk(risk: str) -> str:
    return {"CRITICAL": "\U0001f6a8", "HIGH": "\u26a0\ufe0f",
            "MODERATE": "\U0001f4ca", "LOW": "\u2705"}.get(risk, "\U0001f4ca")


# ---------------------------------------------------------------------------
# Base level tables
# ---------------------------------------------------------------------------

_BASE_LEVELS: Dict[str, Dict[str, float]] = {
    "maharashtra":      {"safe": 2.0, "warning": 3.5, "danger": 5.0,  "cap": 78.0},
    "kerala":           {"safe": 1.8, "warning": 2.8, "danger": 4.0,  "cap": 74.0},
    "assam":            {"safe": 3.0, "warning": 5.0, "danger": 7.5,  "cap": 88.0},
    "bihar":            {"safe": 4.0, "warning": 6.0, "danger": 8.0,  "cap": 86.0},
    "odisha":           {"safe": 3.5, "warning": 5.5, "danger": 7.0,  "cap": 65.0},
    "west_bengal":      {"safe": 3.0, "warning": 5.0, "danger": 6.5,  "cap": 62.0},
    "uttar_pradesh":    {"safe": 4.5, "warning": 6.5, "danger": 9.0,  "cap": 55.0},
    "andhra_pradesh":   {"safe": 3.0, "warning": 4.5, "danger": 6.0,  "cap": 73.0},
    "telangana":        {"safe": 2.5, "warning": 4.0, "danger": 5.5,  "cap": 60.0},
    "karnataka":        {"safe": 2.0, "warning": 3.5, "danger": 5.0,  "cap": 55.0},
    "gujarat":          {"safe": 2.0, "warning": 3.5, "danger": 5.0,  "cap": 42.0},
    "rajasthan":        {"safe": 1.5, "warning": 2.5, "danger": 3.5,  "cap": 38.0},
    "madhya_pradesh":   {"safe": 3.0, "warning": 4.5, "danger": 6.0,  "cap": 52.0},
    "chhattisgarh":     {"safe": 2.5, "warning": 4.0, "danger": 5.5,  "cap": 48.0},
    "jharkhand":        {"safe": 2.5, "warning": 4.0, "danger": 5.5,  "cap": 50.0},
    "punjab":           {"safe": 2.5, "warning": 4.0, "danger": 5.5,  "cap": 54.0},
    "haryana":          {"safe": 2.0, "warning": 3.5, "danger": 5.0,  "cap": 46.0},
    "himachal_pradesh": {"safe": 2.0, "warning": 3.5, "danger": 5.0,  "cap": 52.0},
    "uttarakhand":      {"safe": 2.0, "warning": 3.5, "danger": 5.0,  "cap": 52.0},
    "tamil_nadu":       {"safe": 2.0, "warning": 3.5, "danger": 5.0,  "cap": 48.0},
    "arunachal_pradesh":{"safe": 3.0, "warning": 5.0, "danger": 7.5,  "cap": 67.0},
    "manipur":          {"safe": 1.5, "warning": 2.5, "danger": 3.5,  "cap": 44.0},
    "meghalaya":        {"safe": 1.5, "warning": 2.5, "danger": 3.5,  "cap": 48.0},
    "nagaland":         {"safe": 1.5, "warning": 2.5, "danger": 3.5,  "cap": 38.0},
    "mizoram":          {"safe": 1.5, "warning": 2.5, "danger": 3.5,  "cap": 38.0},
    "tripura":          {"safe": 1.5, "warning": 2.5, "danger": 3.5,  "cap": 46.0},
    "sikkim":           {"safe": 1.5, "warning": 2.5, "danger": 3.5,  "cap": 58.0},
    "goa":              {"safe": 1.5, "warning": 2.5, "danger": 3.5,  "cap": 32.0},
    "delhi":            {"safe": 2.5, "warning": 4.0, "danger": 6.0,  "cap": 50.0},
    "jammu_and_kashmir":{"safe": 2.0, "warning": 3.5, "danger": 5.5,  "cap": 62.0},
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
# WRD Bihar builder — 31 individual ASL gauge stations
# ---------------------------------------------------------------------------

def _build_levels_from_wrd_bihar(
    wrd_stations: List[Dict[str, Any]],
) -> List[Dict[str, Any]]:
    now_iso = current_timestamp_iso()
    result: List[Dict[str, Any]] = []

    for s in wrd_stations:
        city       = str(s.get("station") or "").strip()
        river      = str(s.get("river") or "Unknown").strip()
        district   = str(s.get("district") or "Bihar").strip()
        lat        = s.get("lat", 25.8)
        lon        = s.get("lon", 85.4)
        current_m  = s.get("current_level_m")
        danger_m   = s.get("danger_level_m") or 0.0
        hfl_m      = s.get("hfl_m")
        above_dl   = s.get("above_below_danger_m")  # signed: negative=below DL
        change_24h = s.get("change_24h_m")
        trend      = s.get("trend", "—")
        wrd_status = s.get("status", "UNKNOWN")
        source_raw = s.get("source", "WRD_BIHAR_BEFIQR")
        last_update= s.get("last_update", now_iso)

        if not city:
            continue

        risk     = _risk_from_above_dl(above_dl, wrd_status)
        capacity = _capacity_from_asl_levels(current_m, danger_m, hfl_m, above_dl)
        status   = _status_from_risk(risk)
        alert    = _alert_from_risk(risk)

        # Safe/warning in ASL space: danger-10 and danger-3
        safe_display    = round(danger_m - 10.0, 2) if danger_m > 10 else 0.0
        warning_display = round(danger_m - 3.0,  2) if danger_m > 3  else danger_m

        result.append({
            "city":                 city,
            "state":                "Bihar",
            "river_name":           river,
            "station":              city,
            "current_level":        current_m,
            "safe_level":           safe_display,
            "warning_level":        warning_display,
            "danger_level":         danger_m,
            "capacity_percent":     capacity,
            "risk_level":           risk,
            "status":               status,
            "alert":                alert,
            "flow_rate":            None,
            "lat":                  lat,
            "lon":                  lon,
            "data_source":          "WRD_BIHAR_BEFIQR" if "FALLBACK" not in source_raw else "WRD_BIHAR_FALLBACK",
            "timestamp":            last_update,
            "hfl_m":                hfl_m,
            "district":             district,
            "above_below_danger_m": above_dl,
            "change_24h_m":         change_24h,
            "trend":                trend,
            "wrd_status":           wrd_status,
        })

    return result


# ---------------------------------------------------------------------------
# GloFAS builder — all states except Bihar
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
               else min(round((current_m - safe_m) / max(danger_m - safe_m, 0.01) * 100, 1), 130.0)
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
# Matrix fallback
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
        capacity      = {"CRITICAL": 105.0, "HIGH": 88.0, "MODERATE": 55.0, "LOW": 35.0}.get(severity, base.get("cap", 50.0))
        risk          = _risk_from_capacity(capacity)
        danger_m      = float(entry.get("danger_threshold_m")  or base["danger"])
        warning_m     = float(entry.get("warning_threshold_m") or base["warning"])
        safe_m        = base["safe"]
        current       = round(safe_m + (danger_m - safe_m) * min(capacity / 100.0, 1.3), 2)

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
    covered: set = set()
    all_levels: List[Dict[str, Any]] = []

    wrd_stations = _get_wrd_bihar_stations()
    if wrd_stations:
        bihar_levels = _build_levels_from_wrd_bihar(wrd_stations)
        all_levels.extend(bihar_levels)
        covered.add("bihar")
        print(f"[live_levels] \u2705 WRD Bihar: {len(bihar_levels)} stations")
    else:
        print("[live_levels] \u26a0\ufe0f  WRD Bihar cache empty")

    glofas_cache = _get_glofas_cache()
    if glofas_cache:
        glofas_levels, glofas_covered = _build_levels_from_glofas(glofas_cache, exclude_state_keys=covered)
        all_levels.extend(glofas_levels)
        covered.update(glofas_covered)
        print(f"[live_levels] \u2705 GloFAS: {len(glofas_levels)} states")
    else:
        print("[live_levels] \u26a0\ufe0f  GloFAS cache empty")

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

        above_dl = item.get("above_below_danger_m")
        alerts.append({
            "id":             f"{item['city']}_{item['state']}_alert".replace(" ", "_"),
            "city":           item["city"],
            "state":          item["state"],
            "severity":       risk,
            "title":          f"{item['city']} flood alert",
            "message":        (
                f"{item.get('river_name', 'River')} is "
                + (f"{abs(above_dl):.2f}m ABOVE danger level" if above_dl and above_dl > 0
                   else f"within {abs(above_dl):.2f}m of danger level" if above_dl
                   else f"at {item['capacity_percent']:.0f}% of danger level")
                + f" — {risk.lower()} risk."
            ),
            "river_name":           item.get("river_name", ""),
            "district":             item.get("district"),
            "current_level":        item["current_level"],
            "danger_level":         item["danger_level"],
            "hfl_m":                item.get("hfl_m"),
            "above_below_danger_m": above_dl,
            "change_24h_m":         item.get("change_24h_m"),
            "trend":                item.get("trend"),
            "capacity_percent":     item["capacity_percent"],
            "data_source":          item.get("data_source", "UNKNOWN"),
            "timestamp":            now_iso,
            "resolved":             False,
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
