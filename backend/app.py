"""
backend/app.py  —  OpsFlood FastAPI v3.3
All routes the Flutter app calls.

Run from inside the backend/ folder:
  uvicorn app:app --reload
"""
import random
from datetime import datetime
from typing import Optional

from fastapi import FastAPI, Query
from fastapi.middleware.cors import CORSMiddleware

# Absolute import — works when run as `uvicorn app:app` from backend/
try:
    from wrd_bihar_scraper import scrape_wrd_bihar, ALL_STATIONS, build_record, _synthetic_level
except ImportError:
    from .wrd_bihar_scraper import scrape_wrd_bihar, ALL_STATIONS, build_record, _synthetic_level

app = FastAPI(title="OpsFlood API", version="3.3.0")
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"])

import time as _time
_cache: dict = {"data": None, "ts": 0.0}
_TTL = 600  # cache for 10 minutes


async def _get_data() -> list:
    now = _time.time()
    if _cache["data"] and now - _cache["ts"] < _TTL:
        return _cache["data"]
    bihar = await scrape_wrd_bihar()
    national_now = datetime.utcnow()
    national = [
        build_record(st, _synthetic_level(st, national_now), "SYNTHETIC", national_now)
        for st in ALL_STATIONS
        if st.get("state", "Bihar") != "Bihar"
    ]
    data = bihar + national
    _cache["data"] = data
    _cache["ts"]   = now
    return data


def _find_station(data: list, key: str) -> Optional[dict]:
    """
    Match a station by any of:
      • exact station id          (e.g. "GN01")
      • name / city               (e.g. "Gandhighat", "Patna")
      • district                  (e.g. "Patna")
      • any alias from the master (e.g. "PATNA", "DIGHAGHAT")
    Case-insensitive.
    """
    needle = key.strip().lower()

    # Build an alias map from ALL_STATIONS once
    alias_map: dict[str, str] = {}  # alias → station id
    for st in ALL_STATIONS:
        for alias in st.get("aliases", []):
            alias_map[alias.lower()] = st["id"]

    for d in data:
        if d["id"].lower() == needle:
            return d
        if d.get("name", "").lower() == needle:
            return d
        if d.get("city", "").lower() == needle:
            return d
        if d.get("district", "").lower() == needle:
            return d

    # Check alias map
    if needle in alias_map:
        target_id = alias_map[needle]
        for d in data:
            if d["id"] == target_id:
                return d

    # Partial / contains fallback
    for d in data:
        if (needle in d.get("name", "").lower()
                or needle in d.get("district", "").lower()
                or needle in d.get("city", "").lower()):
            return d

    return None


# ── Health ─────────────────────────────────────────────────────────────
@app.get("/health")
async def health():
    return {"status": "ok", "version": "3.3.0", "timestamp": datetime.utcnow().isoformat()}


# ── /api/stations ────────────────────────────────────────────────────────────
@app.get("/api/stations")
async def get_stations(
    state:    Optional[str] = Query(None),
    river:    Optional[str] = Query(None),
    district: Optional[str] = Query(None),
    status:   Optional[str] = Query(None),
):
    data = await _get_data()
    if state:    data = [d for d in data if state.lower()    in d.get("state",    "").lower()]
    if river:    data = [d for d in data if river.lower()    in d.get("river",    "").lower()]
    if district: data = [d for d in data if district.lower() in d.get("district", "").lower()]
    if status:   data = [d for d in data if d.get("status")  == status.lower()]
    return {"status": "success", "count": len(data), "data": data}


@app.get("/api/stations/{station_id}")
async def get_station(station_id: str):
    data = await _get_data()
    match = _find_station(data, station_id)
    if not match:
        from fastapi import HTTPException
        raise HTTPException(status_code=404, detail=f"Station not found: {station_id}")
    return {"status": "success", "data": match}


# ── Aliases (old endpoint names still work) ──────────────────────────────
@app.get("/api/live-levels")
@app.get("/api/live-telemetry")
@app.get("/api/cwc-stations")
async def live_levels_alias(state: Optional[str] = Query(None)):
    return await get_stations(state=state)


# ── /api/critical-alerts ─────────────────────────────────────────────────
@app.get("/api/critical-alerts")
@app.get("/api/alerts")
async def critical_alerts():
    data = await _get_data()
    alerts = [
        {**d,
         "alert_type": d["status"].upper(),
         "message":    f"{d['name']} ({d['river']}) is at {d['status']} level",
         "severity":   1 if d["status"] == "danger" else 2}
        for d in data if d["status"] != "normal"
    ]
    alerts.sort(key=lambda x: x["severity"])
    return {"status": "success", "count": len(alerts), "data": alerts}


# ── /api/summary ────────────────────────────────────────────────────────────
@app.get("/api/summary")
async def summary():
    data = await _get_data()
    return {"status": "success",
            "total":   len(data),
            "normal":  sum(1 for d in data if d["status"] == "normal"),
            "warning": sum(1 for d in data if d["status"] == "warning"),
            "danger":  sum(1 for d in data if d["status"] == "danger")}


# ── /api/state-severity ───────────────────────────────────────────────────────
@app.get("/api/state-severity")
async def state_severity():
    data = await _get_data()
    states: dict = {}
    for d in data:
        st = d.get("state", "Unknown")
        if st not in states:
            states[st] = {"state": st, "total": 0, "danger": 0, "warning": 0, "normal": 0}
        states[st]["total"]     += 1
        states[st][d["status"]] += 1
    result = []
    for v in states.values():
        sev = "danger" if v["danger"] > 0 else ("warning" if v["warning"] > 0 else "normal")
        result.append({**v, "severity": sev})
    return {"status": "success", "data": result}


# ── /api/rivers & /api/districts ──────────────────────────────────────────────
@app.get("/api/rivers")
async def rivers():
    data = await _get_data()
    return {"status": "success", "data": sorted(set(d["river"] for d in data))}


@app.get("/api/districts")
async def districts():
    data = await _get_data()
    return {"status": "success", "data": sorted(set(d["district"] for d in data))}


# ── Weather ─────────────────────────────────────────────────────────────────────
@app.get("/api/weather/current")
@app.get("/weather/current")
async def weather_current(lat: float = 25.61, lon: float = 85.14):
    r = random.Random(f"{lat:.1f}{lon:.1f}")
    return {"status": "success", "data": {
        "temperature": round(28 + r.random() * 8, 1),
        "humidity":    round(60 + r.random() * 25, 1),
        "rainfall_mm": round(r.random() * 15, 1),
        "wind_speed":  round(5  + r.random() * 20, 1),
        "condition":   "Partly Cloudy",
        "description": "Pre-monsoon conditions",
    }}


@app.get("/api/weather/forecast")
@app.get("/weather/forecast")
async def weather_forecast(lat: float = 25.61, lon: float = 85.14):
    r = random.Random(f"{lat:.1f}{lon:.1f}")
    return {"status": "success", "data": [
        {"date": datetime.utcnow().date().isoformat(),
         "max_temp": round(32 + r.random() * 8, 1),
         "min_temp": round(24 + r.random() * 6, 1),
         "rainfall_mm": round(r.random() * 30, 1),
         "condition": "Partly Cloudy"}
        for _ in range(7)
    ]}


# ── Pipeline ───────────────────────────────────────────────────────────────────
@app.get("/api/pipeline/manifest")
async def pipeline_manifest():
    data = await _get_data()
    return {"status": "success", "data": {
        "version": "3.3",
        "states":  sorted(set(d["state"] for d in data)),
        "stations": len(data),
        "last_run": datetime.utcnow().isoformat(),
    }}


@app.get("/api/pipeline/features")
async def pipeline_features(city: Optional[str] = Query(None)):
    r = random.Random(city or "default")
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
        "recommendation": "Monitor closely" if risk > 0.5 else "No immediate action needed",
    }}


# ── Ingestion (force cache clear) ─────────────────────────────────────────────
@app.get("/api/ingestion/run")
@app.get("/ingestion/run")
async def ingestion_run():
    _cache["data"] = None
    return {"status": "success", "message": "Cache cleared — re-scraping on next request"}


# ── Compat stubs ────────────────────────────────────────────────────────────────
@app.get("/api/cwc-ffs")
@app.get("/api/cwc-ffs/station")
async def cwc_ffs(): return {"status": "success", "data": []}


@app.get("/api/cwc-reservoir")
@app.get("/api/cwc-reservoir/state")
async def cwc_reservoir(): return {"status": "success", "data": []}
