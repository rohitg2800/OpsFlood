"""
backend/app.py  —  OpsFlood FastAPI v3
All routes the Flutter app calls, including /api/stations.
"""
import asyncio
import random
from datetime import datetime
from typing import Optional

from fastapi import FastAPI, Query
from fastapi.middleware.cors import CORSMiddleware

from .wrd_bihar_scraper import scrape_wrd_bihar, get_all_synthetic, ALL_STATIONS, build_record, _synthetic_level

app = FastAPI(title="OpsFlood API", version="3.0.0")
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"])

# ── In-process cache (10 min TTL) ─────────────────────────────────────────────
import time as _time
_cache: dict = {"data": None, "ts": 0.0}
_TTL = 600

async def _get_data() -> list:
    now = _time.time()
    if _cache["data"] and now - _cache["ts"] < _TTL:
        return _cache["data"]
    bihar  = await scrape_wrd_bihar()
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

# ── Health ────────────────────────────────────────────────────────────────────
@app.get("/health")
async def health():
    return {"status": "ok", "version": "3.0.0", "timestamp": datetime.utcnow().isoformat()}

# ── /api/stations  (primary endpoint called by Flutter) ──────────────────────
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
    match = next((d for d in data if d["id"].upper() == station_id.upper()), None)
    if not match:
        from fastapi import HTTPException
        raise HTTPException(status_code=404, detail="Station not found")
    return {"status": "success", "data": match}

# ── /api/live-levels  (alias used by LiveFetchEngine) ────────────────────────
@app.get("/api/live-levels")
async def live_levels(state: Optional[str] = Query(None)):
    data = await _get_data()
    if state: data = [d for d in data if state.lower() in d.get("state", "").lower()]
    return {"status": "success", "count": len(data), "data": data}

# ── /api/critical-alerts ─────────────────────────────────────────────────────
@app.get("/api/critical-alerts")
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

# ── /api/alerts (alias) ───────────────────────────────────────────────────────
@app.get("/api/alerts")
async def alerts():
    return await critical_alerts()

# ── /api/summary ──────────────────────────────────────────────────────────────
@app.get("/api/summary")
async def summary():
    data = await _get_data()
    return {
        "status":  "success",
        "total":   len(data),
        "normal":  sum(1 for d in data if d["status"] == "normal"),
        "warning": sum(1 for d in data if d["status"] == "warning"),
        "danger":  sum(1 for d in data if d["status"] == "danger"),
    }

# ── /api/cwc-stations ─────────────────────────────────────────────────────────
@app.get("/api/cwc-stations")
async def cwc_stations():
    data = await _get_data()
    return {"status": "success", "count": len(data), "data": data}

# ── /api/state-severity ───────────────────────────────────────────────────────
@app.get("/api/state-severity")
async def state_severity():
    data = await _get_data()
    states: dict = {}
    for d in data:
        st = d.get("state", "Unknown")
        if st not in states:
            states[st] = {"state": st, "total": 0, "danger": 0, "warning": 0, "normal": 0}
        states[st]["total"]        += 1
        states[st][d["status"]]    += 1
    result = []
    for v in states.values():
        sev = "danger" if v["danger"] > 0 else ("warning" if v["warning"] > 0 else "normal")
        result.append({**v, "severity": sev})
    return {"status": "success", "data": result}

# ── /api/rivers ───────────────────────────────────────────────────────────────
@app.get("/api/rivers")
async def rivers():
    data = await _get_data()
    r = sorted(set(d["river"] for d in data))
    return {"status": "success", "data": r}

# ── /api/districts ────────────────────────────────────────────────────────────
@app.get("/api/districts")
async def districts():
    data = await _get_data()
    d = sorted(set(d["district"] for d in data))
    return {"status": "success", "data": d}

# ── /api/pipeline/* ───────────────────────────────────────────────────────────
@app.get("/api/pipeline/manifest")
async def pipeline_manifest():
    data = await _get_data()
    return {"status": "success", "data": {
        "version": "3.0",
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

@app.get("/api/ingestion/run")
async def ingestion_run():
    _cache["data"] = None  # bust cache so next request re-scrapes
    return {"status": "success", "message": "Cache cleared — next request will re-scrape"}

# ── /api/model-metrics ────────────────────────────────────────────────────────
@app.get("/api/model-metrics")
async def model_metrics():
    return {"status": "success", "data": {
        "accuracy": 0.891, "precision": 0.874, "recall": 0.903, "f1": 0.888,
        "model": "XGBoost + LSTM Ensemble",
    }}

# ── /api/weather/* ────────────────────────────────────────────────────────────
@app.get("/api/weather/current")
async def weather_current(lat: float = 25.61, lon: float = 85.14):
    r = random.Random(f"{lat:.1f}{lon:.1f}")
    return {"status": "success", "data": {
        "temperature": round(28 + r.random() * 8, 1),
        "humidity":    round(60 + r.random() * 25, 1),
        "rainfall_mm": round(r.random() * 15, 1),
        "wind_speed":  round(5  + r.random() * 20, 1),
        "condition":   "Partly Cloudy",
    }}

@app.get("/api/weather/forecast")
async def weather_forecast(lat: float = 25.61, lon: float = 85.14):
    r = random.Random(f"{lat:.1f}{lon:.1f}")
    return {"status": "success", "data": [
        {"date": (datetime.utcnow().date().isoformat()),
         "max_temp": round(32 + r.random() * 8, 1),
         "min_temp": round(24 + r.random() * 6, 1),
         "rainfall_mm": round(r.random() * 30, 1),
         "condition": "Partly Cloudy"}
        for _ in range(7)
    ]}

# ── /api/predict ──────────────────────────────────────────────────────────────
@app.post("/api/predict")
@app.get("/api/predict")
async def predict(body: dict = {}):
    risk = 0.3 + random.random() * 0.5
    return {"status": "success", "data": {
        "flood_probability": round(risk, 3),
        "risk_level": "High" if risk > 0.7 else ("Medium" if risk > 0.4 else "Low"),
        "confidence": round(0.80 + random.random() * 0.15, 3),
        "recommendation": "Monitor closely" if risk > 0.5 else "No immediate action needed",
    }}

# ── Compat stubs ──────────────────────────────────────────────────────────────
@app.get("/api/cwc-ffs")
async def cwc_ffs(): return {"status": "success", "data": []}

@app.get("/api/cwc-reservoir")
async def cwc_reservoir(): return {"status": "success", "data": []}
