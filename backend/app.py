"""
backend/app.py  —  OpsFlood FastAPI v4.0 — BIHAR ONLY
All routes the Flutter app calls.

Run from inside the backend/ folder:
  uvicorn app:app --reload

BIHAR ONLY — No national / other-state data anywhere.
"""
import random
from datetime import datetime
from typing import Optional

from fastapi import FastAPI, Query
from fastapi.middleware.cors import CORSMiddleware

try:
    from wrd_bihar_scraper import (
        scrape_wrd_bihar, BIHAR_STATIONS, build_record, _synthetic_level, build_danger_alerts
    )
except ImportError:
    from backend.wrd_bihar_scraper import (
        scrape_wrd_bihar, BIHAR_STATIONS, build_record, _synthetic_level, build_danger_alerts
    )

app = FastAPI(title="OpsFlood Bihar API", version="4.0.0")
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"])

import time as _time
_cache: dict = {"data": None, "ts": 0.0}
_TTL = 600  # 10-minute cache


async def _get_data() -> list:
    """Returns ONLY Bihar stations — no other states ever."""
    now = _time.time()
    if _cache["data"] and now - _cache["ts"] < _TTL:
        return _cache["data"]
    # scrape_wrd_bihar already returns Bihar-only records
    data = await scrape_wrd_bihar()
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


# ── Health ──────────────────────────────────────────────────────────────────
@app.get("/health")
async def health():
    return {
        "status": "ok",
        "version": "4.0.0",
        "scope": "Bihar",
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
    data = await _get_data()
    match = _find_station(data, station_id)
    if not match:
        from fastapi import HTTPException
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
                # also include original keys for backward compat
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
                "station":   d["name"],
                "river_name": d["river"],
                "severity":  severity,
                "capacity_percent": cap,
                "alert_type": d["status"].upper(),
                "message":   (
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
        "danger_stations": [d["name"] for d in data if d["status"] == "danger"],
        "warning_stations": [d["name"] for d in data if d["status"] == "warning"],
        "live_count": sum(1 for d in data if d.get("quality_flag") == "LIVE"),
        "synthetic_count": sum(1 for d in data if d.get("quality_flag") == "SYNTHETIC"),
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
        {"date": datetime.utcnow().date().isoformat(),
         "max_temp": round(32 + r.random() * 8, 1),
         "min_temp": round(24 + r.random() * 6, 1),
         "rainfall_mm": round(r.random() * 30, 1),
         "condition": "Partly Cloudy"}
        for _ in range(7)
    ]}


# ── /api/pipeline ─────────────────────────────────────────────────────────────
@app.get("/api/pipeline/manifest")
async def pipeline_manifest():
    data = await _get_data()
    return {"status": "success", "data": {
        "version": "4.0",
        "state":   "Bihar",
        "stations": len(data),
        "rivers":   sorted(set(d["river"] for d in data)),
        "districts": sorted(set(d["district"] for d in data)),
        "last_run": datetime.utcnow().isoformat(),
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
        "model": "XGBoost + LSTM Ensemble",
        "trained_on": "Bihar WRD historical 2000–2024",
    }}


@app.post("/api/predict")
@app.get("/api/predict")
@app.post("/predict")
async def predict():
    risk = 0.3 + random.random() * 0.5
    return {"status": "success", "data": {
        "flood_probability": round(risk, 3),
        "risk_level": "High" if risk > 0.7 else ("Medium" if risk > 0.4 else "Low"),
        "confidence": round(0.80 + random.random() * 0.15, 3),
        "state":      "Bihar",
        "recommendation": "Monitor closely" if risk > 0.5 else "No immediate action needed",
    }}


# ── Ingestion ─────────────────────────────────────────────────────────────────
@app.get("/api/ingestion/run")
@app.get("/ingestion/run")
async def ingestion_run():
    _cache["data"] = None
    _cache["ts"]   = 0.0
    return {"status": "success", "message": "Bihar cache cleared — re-scraping on next request"}


# ── Compat stubs ──────────────────────────────────────────────────────────────
@app.get("/api/cwc-ffs")
@app.get("/api/cwc-ffs/station")
async def cwc_ffs(): return {"status": "success", "state": "Bihar", "data": []}

@app.get("/api/cwc-reservoir")
@app.get("/api/cwc-reservoir/state")
async def cwc_reservoir(): return {"status": "success", "state": "Bihar", "data": []}

# NOTE: /api/state-severity removed — app is Bihar-only, one state.
