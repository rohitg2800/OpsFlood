from __future__ import annotations

from typing import Dict, Literal, TypedDict

SeverityLevel = Literal["LOW", "MODERATE", "SEVERE", "CRITICAL"]


class Thresholds(TypedDict):
    moderate: float
    severe: float
    critical: float


class StateSeverityMatrixEntry(TypedDict):
    region: str
    peak_level_m: Thresholds
    rainfall_7d_mm: Thresholds
    # Convenience: a single "danger level" scalar for UI/alerts. Not an official CWC danger level.
    danger_level_m: float
    notes: str


def normalize_state_name(state: str) -> str:
    key = (state or "").strip().lower()
    # Common aliases
    if key == "orissa":
        return "odisha"
    if key in {"nct of delhi", "new delhi"}:
        return "delhi"
    return key


# These thresholds are heuristic calibration values used to keep severity consistent across India
# when state-specific model calibration is not available. Tune per your own datasets.
_REGION_THRESHOLDS: Dict[str, Dict[str, Thresholds]] = {
    # Coastal + cyclone-prone: allow higher rainfall before escalating.
    "COASTAL": {
        "peak_level_m": {"moderate": 11.5, "severe": 12.5, "critical": 13.5},
        "rainfall_7d_mm": {"moderate": 300.0, "severe": 450.0, "critical": 650.0},
    },
    # Large river plains: moderate thresholds.
    "PLAINS": {
        "peak_level_m": {"moderate": 11.5, "severe": 12.5, "critical": 13.5},
        "rainfall_7d_mm": {"moderate": 250.0, "severe": 400.0, "critical": 550.0},
    },
    # Himalayan/flash-flood terrain: lower rainfall thresholds (smaller catchments).
    "HIMALAYAN": {
        "peak_level_m": {"moderate": 11.0, "severe": 12.0, "critical": 13.0},
        "rainfall_7d_mm": {"moderate": 200.0, "severe": 350.0, "critical": 500.0},
    },
    # North-east: very high rainfall + flash floods; keep moderate lower but not extreme.
    "NORTHEAST": {
        "peak_level_m": {"moderate": 11.0, "severe": 12.0, "critical": 13.0},
        "rainfall_7d_mm": {"moderate": 220.0, "severe": 370.0, "critical": 520.0},
    },
    # Arid/semi-arid: lower rainfall can still cause urban/flash floods.
    "ARID": {
        "peak_level_m": {"moderate": 11.0, "severe": 12.0, "critical": 13.0},
        "rainfall_7d_mm": {"moderate": 150.0, "severe": 250.0, "critical": 350.0},
    },
    # Islands: treat like coastal (cyclone + heavy rain).
    "ISLAND": {
        "peak_level_m": {"moderate": 11.5, "severe": 12.5, "critical": 13.5},
        "rainfall_7d_mm": {"moderate": 300.0, "severe": 450.0, "critical": 650.0},
    },
    # UTs with mostly urban catchments: slightly lower rainfall thresholds than plains.
    "URBAN_UT": {
        "peak_level_m": {"moderate": 11.5, "severe": 12.5, "critical": 13.5},
        "rainfall_7d_mm": {"moderate": 220.0, "severe": 350.0, "critical": 500.0},
    },
}


_STATE_TO_REGION: Dict[str, str] = {
    # States
    "andhra pradesh": "COASTAL",
    "arunachal pradesh": "HIMALAYAN",
    "assam": "NORTHEAST",
    "bihar": "PLAINS",
    "chhattisgarh": "PLAINS",
    "goa": "COASTAL",
    "gujarat": "COASTAL",
    "haryana": "PLAINS",
    "himachal pradesh": "HIMALAYAN",
    "jharkhand": "PLAINS",
    "karnataka": "COASTAL",
    "kerala": "COASTAL",
    "madhya pradesh": "PLAINS",
    "maharashtra": "COASTAL",
    "manipur": "NORTHEAST",
    "meghalaya": "NORTHEAST",
    "mizoram": "NORTHEAST",
    "nagaland": "NORTHEAST",
    "odisha": "COASTAL",
    "punjab": "PLAINS",
    "rajasthan": "ARID",
    "sikkim": "HIMALAYAN",
    "tamil nadu": "COASTAL",
    "telangana": "PLAINS",
    "tripura": "NORTHEAST",
    "uttar pradesh": "PLAINS",
    "uttarakhand": "HIMALAYAN",
    "west bengal": "COASTAL",
    # Union Territories
    "andaman and nicobar islands": "ISLAND",
    "chandigarh": "URBAN_UT",
    "dadra and nagar haveli and daman and diu": "COASTAL",
    "delhi": "URBAN_UT",
    "jammu and kashmir": "HIMALAYAN",
    "ladakh": "HIMALAYAN",
    "lakshadweep": "ISLAND",
    "puducherry": "COASTAL",
}


DEFAULT_STATE_ENTRY: StateSeverityMatrixEntry = {
    "region": "PLAINS",
    "peak_level_m": _REGION_THRESHOLDS["PLAINS"]["peak_level_m"],
    "rainfall_7d_mm": _REGION_THRESHOLDS["PLAINS"]["rainfall_7d_mm"],
    "danger_level_m": _REGION_THRESHOLDS["PLAINS"]["peak_level_m"]["severe"],
    "notes": "Default thresholds (tune per state/station).",
}


def get_state_severity_entry(state: str) -> StateSeverityMatrixEntry:
    key = normalize_state_name(state)
    region = _STATE_TO_REGION.get(key, DEFAULT_STATE_ENTRY["region"])
    thresholds = _REGION_THRESHOLDS.get(region, _REGION_THRESHOLDS[DEFAULT_STATE_ENTRY["region"]])
    peak = thresholds["peak_level_m"]
    rain = thresholds["rainfall_7d_mm"]
    return {
        "region": region,
        "peak_level_m": peak,
        "rainfall_7d_mm": rain,
        "danger_level_m": peak["severe"],
        "notes": "Heuristic calibration thresholds (not official CWC danger levels).",
    }


def severity_from_entry(peak_level_m: float, rainfall_7d_mm: float, entry: StateSeverityMatrixEntry) -> SeverityLevel:
    if peak_level_m >= entry["peak_level_m"]["critical"] or rainfall_7d_mm >= entry["rainfall_7d_mm"]["critical"]:
        return "CRITICAL"
    if peak_level_m >= entry["peak_level_m"]["severe"] or rainfall_7d_mm >= entry["rainfall_7d_mm"]["severe"]:
        return "SEVERE"
    if peak_level_m >= entry["peak_level_m"]["moderate"] or rainfall_7d_mm >= entry["rainfall_7d_mm"]["moderate"]:
        return "MODERATE"
    return "LOW"


STATE_SEVERITY_MATRIX: Dict[str, StateSeverityMatrixEntry] = {
    state: get_state_severity_entry(state) for state in _STATE_TO_REGION.keys()
}

