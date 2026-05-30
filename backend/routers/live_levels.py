"""
Live Levels router: Serves /api/live-levels and /api/critical-alerts
for the OpsFlood Flutter app.

Data priority order:
  1. GloFAS in-memory cache (OPEN_METEO_GLOFAS) — real river discharge data
  2. STATE_SEVERITY_MATRIX fallback — used only when GloFAS has no entry for a state
"""

from fastapi import APIRouter
from typing import Any, Dict, List
import datetime
import sys

from .dependencies import (
    STATE_SEVERITY_MATRIX,
    get_source_policy_payload,
    current_timestamp_iso,
)

router = APIRouter(tags=["live-levels"])

# ---------------------------------------------------------------------------
# GloFAS cache accessor
# The main app.py stores the GloFAS cache in a module-level dict.
# We import it at call time (not import time) to avoid circular imports.
# ---------------------------------------------------------------------------

def _get_glofas_cache() -> List[Dict[str, Any]]:
    """
    Return the in-memory GloFAS station list built by app.py.
    Returns [] if not yet populated or unavailable.
    The cache variable is named GLOFAS_STATION_CACHE in app.py.
    """
    try:
        # app module is the top-level entry point registered as 'backend.app' or 'app'
        for mod_name in ('backend.app', 'app'):
            mod = sys.modules.get(mod_name)
            if mod is not None:
                cache = getattr(mod, 'GLOFAS_STATION_CACHE', None)
                if isinstance(cache, list) and len(cache) > 0:
                    return cache
    except Exception:
        pass
    return []


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _risk_from_capacity(cap: float) -> str:
    if cap >= 85: return "CRITICAL"
    if cap >= 70: return "HIGH"
    if cap >= 50: return "MODERATE"
    return "LOW"

def _risk_from_discharge(discharge: float, danger_q: float, warning_q: float) -> str:
    """Map GloFAS river_discharge to risk using danger/warning thresholds."""
    if danger_q > 0 and discharge >= danger_q:    return "CRITICAL"
    if warning_q > 0 and discharge >= warning_q:  return "HIGH"
    if warning_q > 0 and discharge >= warning_q * 0.7: return "MODERATE"
    return "LOW"

def _capacity_from_discharge(discharge: float, danger_q: float) -> float:
    """Convert discharge to a 0-100 capacity percent."""
    if danger_q <= 0:
        return 50.0
    return min(round(discharge / danger_q * 100.0, 1), 100.0)

def _status_from_risk(risk: str) -> str:
    return {"CRITICAL": "RISING", "HIGH": "RISING",
            "MODERATE": "STABLE", "LOW": "STABLE"}.get(risk, "STABLE")

def _alert_from_risk(risk: str) -> str:
    return {"CRITICAL": "\U0001f6a8", "HIGH": "\u26a0\ufe0f",
            "MODERATE": "\U0001f4ca", "LOW": "\u2705"}.get(risk, "\U0001f4ca")


_BASE_LEVELS: Dict[str, Dict[str, float]] = {
    "maharashtra":     {"safe": 2.0, "warning": 3.5, "danger": 5.0, "current": 4.1, "cap": 78.0},
    "kerala":          {"safe": 1.8, "warning": 2.8, "danger": 4.0, "current": 3.2, "cap": 74.0},
    "assam":           {"safe": 3.0, "warning": 5.0, "danger": 7.5, "current": 6.8, "cap": 88.0},
    "bihar":           {"safe": 4.0, "warning": 6.0, "danger": 8.0, "current": 7.1, "cap": 86.0},
    "odisha":          {"safe": 3.5, "warning": 5.5, "danger": 7.0, "current": 5.0, "cap": 65.0},
    "west_bengal":     {"safe": 3.0, "warning": 5.0, "danger": 6.5, "current": 4.5, "cap": 62.0},
    "uttar_pradesh":   {"safe": 4.5, "warning": 6.5, "danger": 9.0, "current": 5.5, "cap": 55.0},
    "andhra_pradesh":  {"safe": 3.0, "warning": 4.5, "danger": 6.0, "current": 4.8, "cap": 73.0},
    "telangana":       {"safe": 2.5, "warning": 4.0, "danger": 5.5, "current": 3.8, "cap": 60.0},
    "karnataka":       {"safe": 2.0, "warning": 3.5, "danger": 5.0, "current": 3.0, "cap": 55.0},
    "gujarat":         {"safe": 2.0, "warning": 3.5, "danger": 5.0, "current": 2.5, "cap": 42.0},
    "rajasthan":       {"safe": 1.5, "warning": 2.5, "danger": 3.5, "current": 2.0, "cap": 38.0},
    "madhya_pradesh":  {"safe": 3.0, "warning": 4.5, "danger": 6.0, "current": 3.5, "cap": 52.0},
    "chhattisgarh":    {"safe": 2.5, "warning": 4.0, "danger": 5.5, "current": 3.0, "cap": 48.0},
    "jharkhand":       {"safe": 2.5, "warning": 4.0, "danger": 5.5, "current": 3.2, "cap": 50.0},
    "punjab":          {"safe": 2.5, "warning": 4.0, "danger": 5.5, "current": 3.5, "cap": 54.0},
    "haryana":         {"safe": 2.0, "warning": 3.5, "danger": 5.0, "current": 2.8, "cap": 46.0},
    "himachal_pradesh":{"safe": 2.0, "warning": 3.5, "danger": 5.0, "current": 3.0, "cap": 52.0},
    "uttarakhand":     {"safe": 2.0, "warning": 3.5, "danger": 5.0, "current": 3.0, "cap": 52.0},
    "tamil_nadu":      {"safe": 2.0, "warning": 3.5, "danger": 5.0, "current": 2.8, "cap": 48.0},
    "arunachal_pradesh":{"safe": 3.0,"warning": 5.0,"danger": 7.5,"current": 5.5, "cap": 67.0},
    "manipur":         {"safe": 1.5, "warning": 2.5, "danger": 3.5, "current": 2.0, "cap": 44.0},
    "meghalaya":       {"safe": 1.5, "warning": 2.5, "danger": 3.5, "current": 2.2, "cap": 48.0},
    "nagaland":        {"safe": 1.5, "warning": 2.5, "danger": 3.5, "current": 1.8, "cap": 38.0},
    "mizoram":         {"safe": 1.5, "warning": 2.5, "danger": 3.5, "current": 1.8, "cap": 38.0},
    "tripura":         {"safe": 1.5, "warning": 2.5, "danger": 3.5, "current": 2.1, "cap": 46.0},
    "sikkim":          {"safe": 1.5, "warning": 2.5, "danger": 3.5, "current": 2.5, "cap": 58.0},
    "goa":             {"safe": 1.5, "warning": 2.5, "danger": 3.5, "current": 1.6, "cap": 32.0},
    "delhi":           {"safe": 2.5, "warning": 4.0, "danger": 6.0, "current": 3.5, "cap": 50.0},
    "jammu_and_kashmir":{"safe": 2.0,"warning": 3.5,"danger": 5.5,"current": 3.8, "cap": 62.0},
}

_CITY_RIVER_MAP: Dict[str, tuple] = {
    "maharashtra":     ("Kolhapur",   "Panchganga"),
    "kerala":          ("Kochi",      "Periyar"),
    "assam":           ("Guwahati",   "Brahmaputra"),
    "bihar":           ("Patna",      "Ganga"),
    "odisha":          ("Cuttack",    "Mahanadi"),
    "west_bengal":     ("Kolkata",    "Hooghly"),
    "uttar_pradesh":   ("Varanasi",   "Ganga"),
    "andhra_pradesh":  ("Vijayawada", "Krishna"),
    "telangana":       ("Hyderabad",  "Musi"),
    "karnataka":       ("Mysuru",     "Kaveri"),
    "gujarat":         ("Vadodara",   "Vishwamitri"),
    "rajasthan":       ("Kota",       "Chambal"),
    "madhya_pradesh":  ("Jabalpur",   "Narmada"),
    "chhattisgarh":    ("Raipur",     "Mahanadi"),
    "jharkhand":       ("Dhanbad",    "Damodar"),
    "punjab":          ("Ludhiana",   "Sutlej"),
    "haryana":         ("Ambala",     "Ghaggar"),
    "himachal_pradesh":("Mandi",      "Beas"),
    "uttarakhand":     ("Haridwar",   "Ganga"),
    "tamil_nadu":      ("Chennai",    "Adyar"),
    "arunachal_pradesh":("Pasighat",  "Brahmaputra"),
    "manipur":         ("Imphal",     "Imphal River"),
    "meghalaya":       ("Shillong",   "Umiam"),
    "nagaland":        ("Dimapur",    "Dhansiri"),
    "mizoram":         ("Aizawl",     "Tlawng"),
    "tripura":         ("Agartala",   "Haora"),
    "sikkim":          ("Gangtok",    "Teesta"),
    "goa":             ("Panaji",     "Mandovi"),
    "delhi":           ("New Delhi",  "Yamuna"),
    "jammu_and_kashmir":("Srinagar",  "Jhelum"),
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


def _normalise_state_key(state_str: str) -> str:
    return state_str.strip().lower().replace(" ", "_").replace("-", "_")


def _build_levels_from_glofas(glofas_cache: List[Dict]) -> List[Dict[str, Any]]:
    """
    Convert the raw GloFAS station list into the standard live-levels format
    the Flutter app expects:
      city, state, river_name, current_level, safe_level, warning_level,
      danger_level, capacity_percent, risk_level, status, alert,
      flow_rate, data_source, timestamp
    """
    now_iso = current_timestamp_iso()
    result: List[Dict[str, Any]] = []
    seen_state_keys: set = set()

    for station in glofas_cache:
        # GloFAS fields: station_name, state_name, river_name, lat, lon,
        #   river_discharge (m3/s), warning_discharge, danger_discharge,
        #   risk_level, timestamp, ...
        city  = str(station.get("station_name") or station.get("city") or station.get("name") or "").strip()
        state = str(station.get("state_name")   or station.get("state") or "").strip()
        river = str(station.get("river_name")   or station.get("river") or "").strip()

        if not city or not state:
            continue

        state_key = _normalise_state_key(state)

        # Take one representative station per state (highest discharge wins)
        # This matches the app’s Pass2 best-by-state logic.
        discharge    = float(station.get("river_discharge")    or station.get("discharge")    or 0.0)
        warning_q    = float(station.get("warning_discharge")  or station.get("warning_level") or 0.0)
        danger_q     = float(station.get("danger_discharge")   or station.get("danger_level")  or 0.0)

        base = _BASE_LEVELS.get(state_key, {"safe": 2.0, "warning": 3.5, "danger": 5.0})

        # Use GloFAS discharge as current_level (m3/s is real; scale to metres
        # using the existing base danger_level ratio if absolute metre values missing).
        # If the GloFAS station exposes metre values directly, prefer those.
        current_m    = float(station.get("current_level_m") or station.get("gauge_level") or 0.0)
        warning_m    = float(station.get("warning_level_m") or base["warning"])
        danger_m     = float(station.get("danger_level_m")  or base["danger"])
        safe_m       = float(station.get("safe_level_m")    or base["safe"])

        # If no metre values from GloFAS, derive from discharge ratio
        if current_m == 0.0 and discharge > 0 and danger_q > 0:
            # scale: danger_q discharge → danger_m metres
            current_m = round(safe_m + (danger_m - safe_m) * (discharge / danger_q), 2)
            current_m = min(current_m, danger_m * 1.5)   # cap at 150% of danger level

        capacity = _capacity_from_discharge(discharge, danger_q) if danger_q > 0 \
                   else _capacity_from_discharge(current_m - safe_m, danger_m - safe_m)

        risk   = str(station.get("risk_level") or "").upper() or _risk_from_discharge(discharge, danger_q, warning_q)
        status = _status_from_risk(risk)
        alert  = _alert_from_risk(risk)
        ts     = str(station.get("timestamp") or station.get("updated_at") or now_iso)

        result.append({
            "city":             city,
            "state":            state,
            "river_name":       river,
            "station":          city,
            "current_level":    current_m,
            "safe_level":       safe_m,
            "warning_level":    warning_m,
            "danger_level":     danger_m,
            "river_discharge":  discharge,   # raw GloFAS value (m3/s) — extra info
            "capacity_percent": capacity,
            "risk_level":       risk,
            "status":           status,
            "alert":            alert,
            "flow_rate":        discharge if discharge > 0 else None,
            "lat":              station.get("lat"),
            "lon":              station.get("lon"),
            "data_source":      "OPEN_METEO_GLOFAS",
            "timestamp":        ts,
        })

        seen_state_keys.add(state_key)

    return result, seen_state_keys


def _build_levels_from_matrix(exclude_state_keys: set = None) -> List[Dict[str, Any]]:
    """Build river-level list from STATE_SEVERITY_MATRIX for states NOT covered by GloFAS."""
    exclude = exclude_state_keys or set()
    now_iso = current_timestamp_iso()
    result: List[Dict[str, Any]] = []
    seen_states: set = set()

    for state_key, entry in STATE_SEVERITY_MATRIX.items():
        if state_key in seen_states or state_key in exclude:
            continue
        seen_states.add(state_key)

        base = _BASE_LEVELS.get(state_key, {
            "safe": 2.0, "warning": 3.5, "danger": 5.0, "current": 3.0, "cap": 50.0,
        })
        city, river = _CITY_RIVER_MAP.get(state_key, ("Unknown", "River"))
        state_display = _STATE_DISPLAY.get(state_key, state_key.replace("_", " ").title())

        matrix_severity = entry.get("default_severity", "MODERATE").upper()
        cap_override = {"CRITICAL": 88.0, "HIGH": 75.0, "MODERATE": 55.0, "LOW": 35.0}.get(matrix_severity, base["cap"])
        capacity = cap_override
        risk = _risk_from_capacity(capacity)
        status = _status_from_risk(risk)
        alert = _alert_from_risk(risk)

        danger_level  = float(entry.get("danger_threshold_m")  or base["danger"])
        warning_level = float(entry.get("warning_threshold_m") or base["warning"])
        safe_level    = base["safe"]
        current       = round(safe_level + (danger_level - safe_level) * (capacity / 100.0), 2)

        result.append({
            "city":             city,
            "state":            state_display,
            "river_name":       river,
            "station":          city,
            "current_level":    current,
            "safe_level":       safe_level,
            "warning_level":    warning_level,
            "danger_level":     danger_level,
            "capacity_percent": round(capacity, 1),
            "risk_level":       risk,
            "status":           status,
            "alert":            alert,
            "flow_rate":        None,
            "data_source":      "STATE_SEVERITY_MATRIX",
            "timestamp":        now_iso,
        })

    result.sort(key=lambda x: x["capacity_percent"], reverse=True)
    return result


def _build_all_levels() -> List[Dict[str, Any]]:
    """
    Merge GloFAS (real) + Matrix (fallback for uncovered states).
    GloFAS data always wins if available.
    """
    glofas_cache = _get_glofas_cache()

    if glofas_cache:
        glofas_levels, covered_states = _build_levels_from_glofas(glofas_cache)
        matrix_levels = _build_levels_from_matrix(exclude_state_keys=covered_states)
        all_levels = glofas_levels + matrix_levels
        print(f"[live_levels] ✅ GloFAS: {len(glofas_levels)} stations, "
              f"Matrix fallback: {len(matrix_levels)} states")
    else:
        all_levels = _build_levels_from_matrix()
        print("[live_levels] ⚠️  GloFAS cache empty — using static matrix")

    all_levels.sort(key=lambda x: x["capacity_percent"], reverse=True)
    return all_levels


# ---------------------------------------------------------------------------
# Routes
# ---------------------------------------------------------------------------

@router.get("/api/live-levels")
async def get_live_levels(
    state: str | None = None,
    limit: int = 100,
):
    levels = _build_all_levels()

    if state:
        norm = state.strip().lower()
        levels = [item for item in levels if norm in item["state"].lower()]

    levels = levels[:limit]

    glofas_count  = sum(1 for l in levels if l.get("data_source") == "OPEN_METEO_GLOFAS")
    matrix_count  = len(levels) - glofas_count
    data_source   = "GLOFAS+MATRIX" if glofas_count > 0 else "OPSFLOOD_MATRIX"

    return {
        "status":      "success",
        "data_source": data_source,
        "glofas_count": glofas_count,
        "matrix_count": matrix_count,
        "total":       len(levels),
        "timestamp":   current_timestamp_iso(),
        "data":        levels,
    }


@router.get("/api/critical-alerts")
async def get_critical_alerts(
    state: str | None = None,
    severity: str | None = None,
):
    levels  = _build_all_levels()
    now_iso = current_timestamp_iso()
    alerts: List[Dict[str, Any]] = []

    for item in levels:
        risk = item["risk_level"]
        if risk not in ("HIGH", "CRITICAL"):
            continue
        if state    and state.strip().lower()    not in item["state"].lower():  continue
        if severity and severity.strip().upper() != risk:                       continue

        alerts.append({
            "id":            f"{item['city']}_{item['state']}_alert".replace(" ", "_"),
            "city":          item["city"],
            "state":         item["state"],
            "severity":      risk,
            "title":         f"{item['city']} flood alert",
            "message":       (
                f"{item['river_name']} is at "
                f"{item['capacity_percent']:.0f}% capacity \u2014 {risk.lower()} risk."
            ),
            "river_name":    item["river_name"],
            "current_level": item["current_level"],
            "danger_level":  item["danger_level"],
            "data_source":   item.get("data_source", "UNKNOWN"),
            "timestamp":     now_iso,
            "resolved":      False,
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
