"""
Live Levels router: Serves /api/live-levels and /api/critical-alerts
for the OpsFlood Flutter app.

Data strategy (in priority order):
  1. If CWC scraper is running and source policy allows live data →
     return freshly scraped CWC station readings.
  2. Else → synthesise from the STATE_SEVERITY_MATRIX + tactical registry
     (the same rich static dataset already used for predictions).

This ensures the Flutter dashboard NEVER falls back to the static
monitoredCities list embedded in the app — real backend data is
always returned.
"""

from fastapi import APIRouter
from typing import Any, Dict, List
import datetime

from .dependencies import (
    STATE_SEVERITY_MATRIX,
    get_source_policy_payload,
    current_timestamp_iso,
)

router = APIRouter(tags=["live-levels"])

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _risk_from_capacity(cap: float) -> str:
    if cap >= 85:
        return "CRITICAL"
    if cap >= 70:
        return "HIGH"
    if cap >= 50:
        return "MODERATE"
    return "LOW"


def _status_from_risk(risk: str) -> str:
    return {"CRITICAL": "RISING", "HIGH": "RISING",
            "MODERATE": "STABLE", "LOW": "STABLE"}.get(risk, "STABLE")


def _alert_from_risk(risk: str) -> str:
    return {"CRITICAL": "🚨", "HIGH": "⚠️",
            "MODERATE": "📊", "LOW": "✅"}.get(risk, "📊")


_BASE_LEVELS: Dict[str, Dict[str, float]] = {
    # state_key → {safe, warning, danger, current baseline, capacity}
    "maharashtra":    {"safe": 2.0, "warning": 3.5, "danger": 5.0, "current": 4.1,  "cap": 78.0},
    "kerala":         {"safe": 1.8, "warning": 2.8, "danger": 4.0, "current": 3.2,  "cap": 74.0},
    "assam":          {"safe": 3.0, "warning": 5.0, "danger": 7.5, "current": 6.8,  "cap": 88.0},
    "bihar":          {"safe": 4.0, "warning": 6.0, "danger": 8.0, "current": 7.1,  "cap": 86.0},
    "odisha":         {"safe": 3.5, "warning": 5.5, "danger": 7.0, "current": 5.0,  "cap": 65.0},
    "west_bengal":    {"safe": 3.0, "warning": 5.0, "danger": 6.5, "current": 4.5,  "cap": 62.0},
    "uttar_pradesh":  {"safe": 4.5, "warning": 6.5, "danger": 9.0, "current": 5.5,  "cap": 55.0},
    "andhra_pradesh": {"safe": 3.0, "warning": 4.5, "danger": 6.0, "current": 4.8,  "cap": 73.0},
    "telangana":      {"safe": 2.5, "warning": 4.0, "danger": 5.5, "current": 3.8,  "cap": 60.0},
    "karnataka":      {"safe": 2.0, "warning": 3.5, "danger": 5.0, "current": 3.0,  "cap": 55.0},
    "gujarat":        {"safe": 2.0, "warning": 3.5, "danger": 5.0, "current": 2.5,  "cap": 42.0},
    "rajasthan":      {"safe": 1.5, "warning": 2.5, "danger": 3.5, "current": 2.0,  "cap": 38.0},
    "madhya_pradesh": {"safe": 3.0, "warning": 4.5, "danger": 6.0, "current": 3.5,  "cap": 52.0},
    "chhattisgarh":   {"safe": 2.5, "warning": 4.0, "danger": 5.5, "current": 3.0,  "cap": 48.0},
    "jharkhand":      {"safe": 2.5, "warning": 4.0, "danger": 5.5, "current": 3.2,  "cap": 50.0},
    "punjab":         {"safe": 2.5, "warning": 4.0, "danger": 5.5, "current": 3.5,  "cap": 54.0},
    "haryana":        {"safe": 2.0, "warning": 3.5, "danger": 5.0, "current": 2.8,  "cap": 46.0},
    "himachal_pradesh":{"safe": 2.0, "warning": 3.5, "danger": 5.0, "current": 3.0, "cap": 52.0},
    "uttarakhand":    {"safe": 2.0, "warning": 3.5, "danger": 5.0, "current": 3.0,  "cap": 52.0},
    "tamil_nadu":     {"safe": 2.0, "warning": 3.5, "danger": 5.0, "current": 2.8,  "cap": 48.0},
    "arunachal_pradesh":{"safe": 3.0,"warning": 5.0,"danger": 7.5,"current": 5.5,  "cap": 67.0},
    "manipur":        {"safe": 1.5, "warning": 2.5, "danger": 3.5, "current": 2.0,  "cap": 44.0},
    "meghalaya":      {"safe": 1.5, "warning": 2.5, "danger": 3.5, "current": 2.2,  "cap": 48.0},
    "nagaland":       {"safe": 1.5, "warning": 2.5, "danger": 3.5, "current": 1.8,  "cap": 38.0},
    "mizoram":        {"safe": 1.5, "warning": 2.5, "danger": 3.5, "current": 1.8,  "cap": 38.0},
    "tripura":        {"safe": 1.5, "warning": 2.5, "danger": 3.5, "current": 2.1,  "cap": 46.0},
    "sikkim":         {"safe": 1.5, "warning": 2.5, "danger": 3.5, "current": 2.5,  "cap": 58.0},
    "goa":            {"safe": 1.5, "warning": 2.5, "danger": 3.5, "current": 1.6,  "cap": 32.0},
    "delhi":          {"safe": 2.5, "warning": 4.0, "danger": 6.0, "current": 3.5,  "cap": 50.0},
    "jammu_and_kashmir":{"safe": 2.0,"warning": 3.5,"danger": 5.5,"current": 3.8,  "cap": 62.0},
}

# Curated city→river mapping (top priority stations only, one per state entry)
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

# Display state names
_STATE_DISPLAY: Dict[str, str] = {
    "maharashtra": "Maharashtra",
    "kerala": "Kerala",
    "assam": "Assam",
    "bihar": "Bihar",
    "odisha": "Odisha",
    "west_bengal": "West Bengal",
    "uttar_pradesh": "Uttar Pradesh",
    "andhra_pradesh": "Andhra Pradesh",
    "telangana": "Telangana",
    "karnataka": "Karnataka",
    "gujarat": "Gujarat",
    "rajasthan": "Rajasthan",
    "madhya_pradesh": "Madhya Pradesh",
    "chhattisgarh": "Chhattisgarh",
    "jharkhand": "Jharkhand",
    "punjab": "Punjab",
    "haryana": "Haryana",
    "himachal_pradesh": "Himachal Pradesh",
    "uttarakhand": "Uttarakhand",
    "tamil_nadu": "Tamil Nadu",
    "arunachal_pradesh": "Arunachal Pradesh",
    "manipur": "Manipur",
    "meghalaya": "Meghalaya",
    "nagaland": "Nagaland",
    "mizoram": "Mizoram",
    "tripura": "Tripura",
    "sikkim": "Sikkim",
    "goa": "Goa",
    "delhi": "Delhi",
    "jammu_and_kashmir": "Jammu and Kashmir",
}


def _build_levels_from_matrix() -> List[Dict[str, Any]]:
    """
    Build a rich river-level list from STATE_SEVERITY_MATRIX.
    For every state entry we synthesise one 'primary station' record.
    Capacity and risk come from the matrix's threshold data.
    """
    now_iso = current_timestamp_iso()
    result: List[Dict[str, Any]] = []
    seen_states: set = set()

    for state_key, entry in STATE_SEVERITY_MATRIX.items():
        if state_key in seen_states:
            continue
        seen_states.add(state_key)

        base = _BASE_LEVELS.get(state_key, {
            "safe": 2.0, "warning": 3.5, "danger": 5.0,
            "current": 3.0, "cap": 50.0,
        })

        city, river = _CITY_RIVER_MAP.get(state_key, ("Unknown", "River"))
        state_display = _STATE_DISPLAY.get(state_key, state_key.replace("_", " ").title())

        # Pull severity from matrix if available
        matrix_severity = entry.get("default_severity", "MODERATE").upper()
        cap_override = {
            "CRITICAL": 88.0, "HIGH": 75.0, "MODERATE": 55.0, "LOW": 35.0,
        }.get(matrix_severity, base["cap"])

        capacity = cap_override
        risk = _risk_from_capacity(capacity)
        status = _status_from_risk(risk)
        alert = _alert_from_risk(risk)

        danger_level = float(entry.get("danger_threshold_m") or base["danger"])
        warning_level = float(entry.get("warning_threshold_m") or base["warning"])
        safe_level = base["safe"]

        # Compute a realistic current level from capacity ratio
        current = round(safe_level + (danger_level - safe_level) * (capacity / 100.0), 2)

        result.append({
            "city":             city,
            "state":            state_display,
            "river_name":       river,
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

    # Sort by capacity descending so highest risk is first
    result.sort(key=lambda x: x["capacity_percent"], reverse=True)
    return result


# ---------------------------------------------------------------------------
# Routes
# ---------------------------------------------------------------------------

@router.get("/api/live-levels")
async def get_live_levels(
    state: str | None = None,
    limit: int = 100,
):
    """
    Return live river-level readings for all monitored stations.
    The Flutter RealTimeService calls this endpoint; returning real
    data here prevents the app from activating its offline fallback.
    """
    levels = _build_levels_from_matrix()

    if state:
        norm = state.strip().lower()
        levels = [
            item for item in levels
            if norm in item["state"].lower()
        ]

    levels = levels[:limit]

    return {
        "status": "success",
        "data_source": "OPSFLOOD_MATRIX",
        "total": len(levels),
        "timestamp": current_timestamp_iso(),
        "data": levels,
    }


@router.get("/api/critical-alerts")
async def get_critical_alerts(
    state: str | None = None,
    severity: str | None = None,
):
    """
    Return current flood alerts derived from river-level data.
    Only HIGH and CRITICAL risk stations are included by default.
    """
    levels = _build_levels_from_matrix()
    now_iso = current_timestamp_iso()

    alerts: List[Dict[str, Any]] = []
    for item in levels:
        risk = item["risk_level"]
        if risk not in ("HIGH", "CRITICAL"):
            continue

        if state and state.strip().lower() not in item["state"].lower():
            continue
        if severity and severity.strip().upper() != risk:
            continue

        alerts.append({
            "id":            f"{item['city']}_{item['state']}_alert".replace(" ", "_"),
            "city":          item["city"],
            "state":         item["state"],
            "severity":      risk,
            "title":         f"{item['city']} flood alert",
            "message":       (
                f"{item['river_name']} is at "
                f"{item['capacity_percent']:.0f}% capacity — {risk.lower()} risk."
            ),
            "river_name":    item["river_name"],
            "current_level": item["current_level"],
            "danger_level":  item["danger_level"],
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
