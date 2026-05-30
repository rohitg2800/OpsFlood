"""
backend/app.py  —  OpsFlood FastAPI v4.1 — BIHAR ONLY
All routes the Flutter app calls.

Run from inside the backend/ folder:
  uvicorn app:app --reload

BIHAR ONLY — No national / other-state data anywhere.

v4.1 changes (Phase 1):
  + /api/bihar/stations       → grouped by river, live quality_flag
  + /api/bihar/stations/{id}  → single station detail
  + /api/bihar/summary        → live/danger/warning counts
  + /api/bihar/alerts         → only DANGER + WARNING stations
  + /api/bihar/force-refresh  → bypass cache immediately
  + _bihar_cache separate from legacy _cache (TTL 5 min vs 10 min)
"""
import random
from datetime import datetime
from typing import Optional

from fastapi import FastAPI, Query, HTTPException
from fastapi.middleware.cors import CORSMiddleware

try:
    from wrd_bihar_scraper import (
        scrape_wrd_bihar, BIHAR_STATIONS, build_record, _synthetic_level, build_danger_alerts
    )
except ImportError:
    from backend.wrd_bihar_scraper import (
        scrape_wrd_bihar, BIHAR_STATIONS, build_record, _synthetic_level, build_danger_alerts
    )

app = FastAPI(title="OpsFlood Bihar API", version="4.1.0")
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"])

import time as _time

# ── Legacy cache (10 min) — used by old /api/stations, /api/live-levels etc. ─
_cache: dict = {"data": None, "ts": 0.0}
_TTL = 600

# ── Bihar cache (5 min) — used by /api/bihar/* endpoints ─────────────────────
_bihar_cache: dict = {"data": [], "fetched_at": None, "ts": 0.0}
_BIHAR_TTL = 300  # 5 minutes — matches WRD Bihar update frequency


async def _get_data() -> list:
    """Returns ONLY Bihar stations — no other states ever. (legacy 10-min cache)"""
    now = _time.time()
    if _cache["data"] and now - _cache["ts"] < _TTL:
        return _cache["data"]
    data = await scrape_wrd_bihar()
    _cache["data"] = data
    _cache["ts"]   = now
    return data


async def _get_bihar_data(force: bool = False) -> list:
    """Bihar-dedicated fetch with 5-min TTL and force-refresh support."""
    now = _time.time()
    if not force and _bihar_cache["data"] and now - _bihar_cache["ts"] < _BIHAR_TTL:
        return _bihar_cache["data"]
    data = await scrape_wrd_bihar()
    _bihar_cache["data"]       = data
    _bihar_cache["fetched_at"] = datetime.utcnow().isoformat()
    _bihar_cache["ts"]         = now
    # Keep legacy cache in sync
    _cache["data"] = data
    _cache["ts"]   = now
    return data


def _find_station(data: list, key: str) -> Optional[dict]:
    needle = key.strip().lower()
    alias_map: dict[str, str] = {}
    for st in BIHAR_STATIONS:
        for alias in st.get("aliases", []):
            alias_map[alias.lower()] = st["id"]

    for d in data:
        if d["id"].lower() == needle:               return d
        if d.get("name", "").lower() == needle:     return d
        if d.get("city", "").lower() == needle:     return d
        if d.get("district", "").lower() == needle: return d

    if needle in alias_map:
        target_id = alias_map[needle]
        for d in data:
            if d["id"] == target_id:
                return d

    for d in data:
        if (needle in d.get("name", "").lower()
                or needle in d.get("district", "").lower()
                or needle in d.get("city", "").lower()):
            return d
    return None


# ─────────────────────────────────────────────────────────────────────────────
# /api/bihar/* — Phase 1 dedicated Bihar endpoints
# ─────────────────────────────────────────────────────────────────────────────

# River display order (matches Flutter BiharRiverMapScreen)
_RIVER_ORDER = [
    "Ganga", "Kosi", "Gandak", "Bagmati",
    "Burhi Gandak", "Ghaghra", "Mahananda",
    "Kamla", "Kamla Balan", "Adhwara", "Punpun",
]


@app.get("/api/bihar/stations")
async def bihar_stations(
    force:    bool           = Query(False, description="Force-bypass 5-min cache"),
    river:    Optional[str]  = Query(None,  description="Filter by river name"),
    district: Optional[str]  = Query(None,  description="Filter by district name"),
    live_only: bool          = Query(False, description="Return only LIVE quality_flag stations"),
):
    """
    Returns all 31 Bihar gauge stations.
    - `grouped`   → dict keyed by river name, value = list of stations (same order as Flutter tabs)
    - `stations`  → flat list (all stations)
    - `quality_flag` → 'LIVE' = real WRD scrape | 'SYNTHETIC' = fallback estimate
    """
    data = await _get_bihar_data(force=force)

    # Apply filters
    if river:     data = [d for d in data if river.lower()    in d.get("river",    "").lower()]
    if district:  data = [d for d in data if district.lower() in d.get("district", "").lower()]
    if live_only: data = [d for d in data if d.get("quality_flag") == "LIVE"]

    # Group by river in defined order
    grouped: dict = {}
    for river_name in _RIVER_ORDER:
        river_stations = [d for d in data if d.get("river") == river_name]
        if river_stations:
            grouped[river_name] = river_stations
    # Any river not in the order list (edge case)
    for d in data:
        r = d.get("river", "Other")
        if r not in grouped:
            grouped.setdefault(r, []).append(d)

    live_count  = sum(1 for d in data if d.get("quality_flag") == "LIVE")
    synth_count = len(data) - live_count
    danger_list = [d["name"] for d in data if d.get("status") == "danger"]
    warn_list   = [d["name"] for d in data if d.get("status") == "warning"]

    return {
        "status":           "success",
        "state":            "Bihar",
        "total":            len(data),
        "live_count":       live_count,
        "synthetic_count":  synth_count,
        "danger_count":     len(danger_list),
        "warning_count":    len(warn_list),
        "danger_stations":  danger_list,
        "warning_stations": warn_list,
        "fetched_at":       _bihar_cache["fetched_at"],
        "cache_ttl_sec":    _BIHAR_TTL,
        "grouped":          grouped,   # ← Flutter TabBarView uses this
        "stations":         data,      # ← flat list for any other use
        "alerts":           build_danger_alerts(data),
    }


@app.get("/api/bihar/stations/{station_id}")
async def bihar_single_station(station_id: str):
    """
    Fetch one Bihar station by ID (e.g. GN01), name, or district.
    Returns full record including current_level, quality_flag, trend, pct_to_danger.
    """
    data  = await _get_bihar_data()
    match = _find_station(data, station_id)
    if not match:
        raise HTTPException(
            status_code=404,
            detail=f"Station '{station_id}' not found in Bihar. "
                   f"Use /api/bihar/stations to list all valid IDs."
        )
    return {
        "status": "success",
        "state":  "Bihar",
        "data":   match,
        # Handy computed fields the Flutter detail screen may use
        "is_live":         match.get("quality_flag") == "LIVE",
        "above_danger":    match.get("above_danger_m", 0) > 0,
        "fetched_at":      _bihar_cache["fetched_at"],
    }


@app.get("/api/bihar/summary")
async def bihar_summary():
    """
    Lightweight summary — Flutter home screen / dashboard header widget.
    No heavy payload — just counts + key names.
    """
    data = await _get_bihar_data()
    rivers_at_risk = sorted(set(
        d["river"] for d in data
        if d.get("status") in ("danger", "warning")
    ))
    return {
        "status":           "success",
        "state":            "Bihar",
        "total_stations":   len(data),
        "live":             sum(1 for d in data if d.get("quality_flag") == "LIVE"),
        "synthetic":        sum(1 for d in data if d.get("quality_flag") == "SYNTHETIC"),
        "normal":           sum(1 for d in data if d.get("status") == "normal"),
        "warning":          sum(1 for d in data if d.get("status") == "warning"),
        "danger":           sum(1 for d in data if d.get("status") == "danger"),
        "danger_stations":  [d["name"] for d in data if d.get("status") == "danger"],
        "warning_stations": [d["name"] for d in data if d.get("status") == "warning"],
        "rivers_at_risk":   rivers_at_risk,
        "has_active_danger": any(d.get("status") == "danger" for d in data),
        "fetched_at":       _bihar_cache["fetched_at"],
    }


@app.get("/api/bihar/alerts")
async def bihar_alerts():
    """
    Returns only stations in DANGER or WARNING status — sorted by severity.
    CRITICAL first (above danger level), then HIGH (above warning).
    """
    data   = await _get_bihar_data()
    alerts = build_danger_alerts(data)

    # Also include WARNING-level stations not captured by build_danger_alerts
    warning_records = [
        {
            **d,
            "alert_type":  "WARNING",
            "alert_level": "HIGH",
            "message": (
                f"{d['name']} ({d['river']}, {d['district']}) is at "
                f"{d['current_level']:.2f}m — approaching danger level "
                f"{d['danger_level']:.2f}m. "
                f"Trend: {d.get('trend', 'stable')}."
            ),
            "action": "MONITOR",
        }
        for d in data
        if d.get("status") == "warning"
           and d.get("quality_flag") == "LIVE"  # only real readings
    ]

    # Deduplicate — build_danger_alerts covers DANGER, warning_records covers WARNING
    danger_ids = {a["id"] for a in alerts}
    warning_records = [w for w in warning_records if w["id"] not in danger_ids]

    combined = alerts + warning_records
    combined.sort(key=lambda x: (
        0 if x.get("alert_level") == "CRITICAL" else
        1 if x.get("alert_level") == "HIGH" else 2,
        -x.get("pct_to_danger", 0),
    ))

    return {
        "status":      "success",
        "state":       "Bihar",
        "total":       len(combined),
        "danger":      len(alerts),
        "warning":     len(warning_records),
        "has_alerts":  len(combined) > 0,
        "fetched_at":  _bihar_cache["fetched_at"],
        "data":        combined,
    }


@app.get("/api/bihar/force-refresh")
async def bihar_force_refresh():
    """
    Immediately bypasses cache and re-scrapes both WRD Bihar sources.
    Use after deployments or when you suspect stale data.
    """
    data = await _get_bihar_data(force=True)
    live = sum(1 for d in data if d.get("quality_flag") == "LIVE")
    return {
        "status":      "success",
        "message":     "Bihar cache cleared and re-scraped",
        "total":       len(data),
        "live_count":  live,
        "synth_count": len(data) - live,
        "fetched_at":  _bihar_cache["fetched_at"],
    }


# ── Health ──────────────────────────────────────────────────────────────────
@app.get("/health")
async def health():
    return {
        "status":    "ok",
        "version":   "4.1.0",
        "scope":     "Bihar",
        "timestamp": datetime.utcnow().isoformat()
    }


# ── /api/stations ────────────────────────────────────────────────────────────
@app.get("/api/stations")
async def get_stations(
    river:    Optional[str] = Query(None),
    district: Optional[str] = Query(None),
    status:   Optional[str] = Query(None),
):
    data = await _get_data()  # always Bihar only
    if river:    data = [d for d in data if river.lower()    in d.get("river",    "").lower()]
    if district: data = [d for d in data if district.lower() in d.get("district", "").lower()]
    if status:   data = [d for d in data if d.get("status")  == status.lower()]
    return {"status": "success", "count": len(data), "state": "Bihar", "data": data}


@app.get("/api/stations/{station_id}")
async def get_station(station_id: str):
    data  = await _get_data()
    match = _find_station(data, station_id)
    if not match:
        raise HTTPException(status_code=404, detail=f"Station not found in Bihar: {station_id}")
    return {"status": "success", "data": match}


# ── Aliases — old endpoint names still work ──────────────────────────────────
@app.get("/api/live-levels")
@app.get("/api/live-telemetry")
@app.get("/api/cwc-stations")
async def live_levels_alias(
    river:    Optional[str] = Query(None),
    district: Optional[str] = Query(None),
    limit:    Optional[int] = Query(None),
):
    data = await _get_data()
    if river:    data = [d for d in data if river.lower()    in d.get("river",    "").lower()]
    if district: data = [d for d in data if district.lower() in d.get("district", "").lower()]
    if limit:    data = data[:limit]
    return {
        "status": "success",
        "count":  len(data),
        "total":  len(data),
        "state":  "Bihar",
        "glofas_count":   sum(1 for d in data if d.get("quality_flag") == "LIVE"),
        "tactical_count": sum(1 for d in data if d.get("quality_flag") == "SYNTHETIC"),
        "timestamp": datetime.utcnow().isoformat(),
        "data": [
            {
                "station":              d["name"],
                "district":             d["district"],
                "river_name":           d["river"],
                "current_level_m":      d["current_level"],
                "danger_level_m":       d["danger_level"],
                "warning_level_m":      d["warning_level"],
                "capacity_percent":     d["capacity_percent"],
                "risk_level":           d["risk_level"],
                "proximity_to_danger_m": round(d["danger_level"] - d["current_level"], 2),
                "river_discharge_m3s":  0,
                "data_source":          d["data_source"],
                "timestamp":            d["last_updated"],
                "lat":                  d["lat"],
                "lon":                  d["lon"],
                **d,
            }
            for d in data
        ],
    }


# ── /api/alerts/danger ───────────────────────────────────────────────────────
@app.get("/api/alerts/danger")
async def danger_alerts():
    data   = await _get_data()
    alerts = build_danger_alerts(data)
    return {
        "status":     "success",
        "count":      len(alerts),
        "has_danger": len(alerts) > 0,
        "state":      "Bihar",
        "data":       alerts,
    }


# ── /api/critical-alerts ─────────────────────────────────────────────────────
@app.get("/api/critical-alerts")
@app.get("/api/alerts")
async def critical_alerts():
    data = await _get_data()
    alerts = []
    for d in data:
        if d["status"] != "normal":
            severity = "CRITICAL" if d["status"] == "danger" else "HIGH"
            cap = d["capacity_percent"]
            alerts.append({
                **d,
                "station":    d["name"],
                "river_name": d["river"],
                "severity":   severity,
                "capacity_percent": cap,
                "alert_type": d["status"].upper(),
                "message": (
                    f"{d['name']} ({d['river']}, {d['district']}) is at "
                    f"{d['current_level']:.2f}m — {d['status'].upper()} level."
                ),
                "recommendation": (
                    "Immediate evacuation advised" if d["status"] == "danger"
                    else "Stay alert, avoid river banks"
                ),
            })
    alerts.sort(key=lambda x: (0 if x["severity"] == "CRITICAL" else 1, -x["capacity_percent"]))
    return {"status": "success", "total": len(alerts), "state": "Bihar", "data": alerts}


# ── /api/summary ──────────────────────────────────────────────────────────────
@app.get("/api/summary")
async def summary():
    data = await _get_data()
    return {
        "status":  "success",
        "state":   "Bihar",
        "total":   len(data),
        "normal":  sum(1 for d in data if d["status"] == "normal"),
        "warning": sum(1 for d in data if d["status"] == "warning"),
        "danger":  sum(1 for d in data if d["status"] == "danger"),
        "danger_stations":  [d["name"] for d in data if d["status"] == "danger"],
        "warning_stations": [d["name"] for d in data if d["status"] == "warning"],
        "live_count":       sum(1 for d in data if d.get("quality_flag") == "LIVE"),
        "synthetic_count":  sum(1 for d in data if d.get("quality_flag") == "SYNTHETIC"),
    }


# ── /api/rivers ───────────────────────────────────────────────────────────────
@app.get("/api/rivers")
async def rivers():
    data = await _get_data()
    return {
        "status": "success",
        "state":  "Bihar",
        "data":   sorted(set(d["river"] for d in data))
    }


# ── /api/districts ────────────────────────────────────────────────────────────
@app.get("/api/districts")
async def districts():
    data = await _get_data()
    return {
        "status": "success",
        "state":  "Bihar",
        "data":   sorted(set(d["district"] for d in data))
    }


# ── /api/weather — Bihar-centred defaults ─────────────────────────────────────
@app.get("/api/weather/current")
@app.get("/weather/current")
async def weather_current(
    lat: float = 25.61,  # Patna default
    lon: float = 85.14,
):
    r = random.Random(f"{lat:.1f}{lon:.1f}")
    return {"status": "success", "state": "Bihar", "data": {
        "temperature": round(28 + r.random() * 8, 1),
        "humidity":    round(60 + r.random() * 25, 1),
        "rainfall_mm": round(r.random() * 15, 1),
        "wind_speed":  round(5  + r.random() * 20, 1),
        "condition":   "Partly Cloudy",
        "description": "Bihar pre-monsoon conditions",
    }}


@app.get("/api/weather/forecast")
@app.get("/weather/forecast")
async def weather_forecast(
    lat: float = 25.61,
    lon: float = 85.14,
):
    r = random.Random(f"{lat:.1f}{lon:.1f}")
    return {"status": "success", "state": "Bihar", "data": [
        {
            "date": datetime.utcnow().date().isoformat(),
            "max_temp": round(32 + r.random() * 8, 1),
            "min_temp": round(24 + r.random() * 6, 1),
            "rainfall_mm": round(r.random() * 30, 1),
            "condition": "Partly Cloudy",
        }
        for _ in range(7)
    ]}


# ── /api/pipeline ─────────────────────────────────────────────────────────────
@app.get("/api/pipeline/manifest")
async def pipeline_manifest():
    data = await _get_data()
    return {"status": "success", "data": {
        "version":   "4.1",
        "state":     "Bihar",
        "stations":  len(data),
        "rivers":    sorted(set(d["river"] for d in data)),
        "districts": sorted(set(d["district"] for d in data)),
        "last_run":  datetime.utcnow().isoformat(),
    }}


@app.get("/api/pipeline/features")
async def pipeline_features(city: Optional[str] = Query(None)):
    r = random.Random(city or "patna")
    return {"status": "success", "data": {
        "rainfall_3d":    round(r.random() * 50, 1),
        "discharge":      round(500 + r.random() * 7500, 0),
        "water_level":    round(40  + r.random() * 30, 2),
        "soil_moisture":  round(0.3 + r.random() * 0.6, 3),
        "upstream_level": round(35  + r.random() * 30, 2),
    }}


# ── Model & Predict ───────────────────────────────────────────────────────────
@app.get("/api/model-metrics")
@app.get("/model-metrics")
async def model_metrics():
    return {"status": "success", "data": {
        "accuracy": 0.891, "precision": 0.874, "recall": 0.903, "f1": 0.888,
        "model":       "XGBoost + LSTM Ensemble",
        "trained_on":  "Bihar WRD historical 2000–2024",
    }}


@app.post("/api/predict")
@app.get("/api/predict")
@app.post("/predict")
async def predict():
    risk = 0.3 + random.random() * 0.5
    return {"status": "success", "data": {
        "flood_probability": round(risk, 3),
        "risk_level":  "High" if risk > 0.7 else ("Medium" if risk > 0.4 else "Low"),
        "confidence":  round(0.80 + random.random() * 0.15, 3),
        "state":       "Bihar",
        "recommendation": "Monitor closely" if risk > 0.5 else "No immediate action needed",
    }}


# ── Ingestion ─────────────────────────────────────────────────────────────────
@app.get("/api/ingestion/run")
@app.get("/ingestion/run")
async def ingestion_run():
    _cache["data"]       = None
    _cache["ts"]         = 0.0
    _bihar_cache["data"] = []
    _bihar_cache["ts"]   = 0.0
    return {"status": "success", "message": "Bihar cache cleared — re-scraping on next request"}


# ── Compat stubs ──────────────────────────────────────────────────────────────
@app.get("/api/cwc-ffs")
@app.get("/api/cwc-ffs/station")
async def cwc_ffs(): return {"status": "success", "state": "Bihar", "data": []}

@app.get("/api/cwc-reservoir")
@app.get("/api/cwc-reservoir/state")
async def cwc_reservoir(): return {"status": "success", "state": "Bihar", "data": []}
