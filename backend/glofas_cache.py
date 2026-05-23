"""
GloFAS in-memory cache builder.
Fetches real river discharge data from Open-Meteo GloFAS API for ~87 Indian stations
and writes results into app.GLOFAS_STATION_CACHE so the /api/live-levels router
can serve real data.

Usage (called from app.py startup):
    from backend.glofas_cache import start_glofas_refresh_loop, INDIA_STATIONS
    asyncio.create_task(start_glofas_refresh_loop())

Notes on rate-limiting
----------------------
Open-Meteo free-tier flood API allows ~10 req/min with 1 concurrent connection.
We batch BATCH_SIZE stations into ONE request and space batches INTER_BATCH_DELAY
seconds apart (sequential, NOT concurrent) to stay safely below the limit.

  87 stations ÷ 10 per batch = 9 HTTP requests per refresh cycle.
  9 requests × 7 s delay     ≈ 63 s total fetch time per cycle.

The CACHE_READY flag lets callers (e.g. /api/live-telemetry) detect whether the
first cycle has finished and serve tactical fallback data immediately on startup
instead of waiting and timing out.
"""
from __future__ import annotations

import asyncio
import datetime
import sys
from typing import Any, Dict, List

import httpx

# ---------------------------------------------------------------------------
# Indian river gauge stations — lat/lon for Open-Meteo GloFAS
# ---------------------------------------------------------------------------
INDIA_STATIONS: List[Dict[str, Any]] = [
    # Maharashtra
    {"station_name": "Kolhapur",      "state_name": "Maharashtra",     "river_name": "Panchganga",   "lat": 16.70, "lon": 74.24, "warning_discharge": 1200, "danger_discharge": 2000},
    {"station_name": "Nashik",        "state_name": "Maharashtra",     "river_name": "Godavari",     "lat": 19.99, "lon": 73.79, "warning_discharge": 800,  "danger_discharge": 1400},
    {"station_name": "Pune",          "state_name": "Maharashtra",     "river_name": "Mutha",        "lat": 18.52, "lon": 73.86, "warning_discharge": 600,  "danger_discharge": 1200},
    {"station_name": "Nagpur",        "state_name": "Maharashtra",     "river_name": "Nag River",    "lat": 21.14, "lon": 79.08, "warning_discharge": 400,  "danger_discharge": 800},
    # Kerala
    {"station_name": "Kochi",         "state_name": "Kerala",          "river_name": "Periyar",      "lat":  9.93, "lon": 76.26, "warning_discharge": 900,  "danger_discharge": 1800},
    {"station_name": "Thrissur",      "state_name": "Kerala",          "river_name": "Bharathapuzha","lat": 10.53, "lon": 76.21, "warning_discharge": 700,  "danger_discharge": 1400},
    {"station_name": "Alappuzha",     "state_name": "Kerala",          "river_name": "Pampa",        "lat":  9.49, "lon": 76.33, "warning_discharge": 500,  "danger_discharge": 1000},
    {"station_name": "Kozhikode",     "state_name": "Kerala",          "river_name": "Chaliyar",     "lat": 11.25, "lon": 75.77, "warning_discharge": 600,  "danger_discharge": 1200},
    # Assam
    {"station_name": "Guwahati",      "state_name": "Assam",           "river_name": "Brahmaputra",  "lat": 26.14, "lon": 91.74, "warning_discharge": 30000, "danger_discharge": 50000},
    {"station_name": "Dibrugarh",     "state_name": "Assam",           "river_name": "Brahmaputra",  "lat": 27.47, "lon": 94.91, "warning_discharge": 25000, "danger_discharge": 45000},
    {"station_name": "Silchar",       "state_name": "Assam",           "river_name": "Barak",        "lat": 24.82, "lon": 92.80, "warning_discharge": 3000,  "danger_discharge": 6000},
    # Bihar
    {"station_name": "Patna",         "state_name": "Bihar",           "river_name": "Ganga",        "lat": 25.59, "lon": 85.14, "warning_discharge": 40000, "danger_discharge": 70000},
    {"station_name": "Bhagalpur",     "state_name": "Bihar",           "river_name": "Ganga",        "lat": 25.24, "lon": 86.97, "warning_discharge": 42000, "danger_discharge": 72000},
    {"station_name": "Darbhanga",     "state_name": "Bihar",           "river_name": "Bagmati",      "lat": 26.15, "lon": 85.89, "warning_discharge": 2000,  "danger_discharge": 4000},
    # Odisha
    {"station_name": "Cuttack",       "state_name": "Odisha",          "river_name": "Mahanadi",     "lat": 20.46, "lon": 85.88, "warning_discharge": 12000, "danger_discharge": 25000},
    {"station_name": "Bhubaneswar",   "state_name": "Odisha",          "river_name": "Kuakhai",      "lat": 20.30, "lon": 85.82, "warning_discharge": 3000,  "danger_discharge": 6000},
    {"station_name": "Puri",          "state_name": "Odisha",          "river_name": "Kushabhadra",  "lat": 19.81, "lon": 85.83, "warning_discharge": 1000,  "danger_discharge": 2000},
    # West Bengal
    {"station_name": "Kolkata",       "state_name": "West Bengal",     "river_name": "Hooghly",      "lat": 22.57, "lon": 88.36, "warning_discharge": 15000, "danger_discharge": 28000},
    {"station_name": "Siliguri",      "state_name": "West Bengal",     "river_name": "Teesta",       "lat": 26.71, "lon": 88.43, "warning_discharge": 3000,  "danger_discharge": 6000},
    {"station_name": "Jalpaiguri",    "state_name": "West Bengal",     "river_name": "Jaldhaka",     "lat": 26.52, "lon": 88.72, "warning_discharge": 2000,  "danger_discharge": 4500},
    # Uttar Pradesh
    {"station_name": "Varanasi",      "state_name": "Uttar Pradesh",   "river_name": "Ganga",        "lat": 25.32, "lon": 83.00, "warning_discharge": 38000, "danger_discharge": 65000},
    {"station_name": "Prayagraj",     "state_name": "Uttar Pradesh",   "river_name": "Yamuna",       "lat": 25.45, "lon": 81.84, "warning_discharge": 20000, "danger_discharge": 40000},
    {"station_name": "Lucknow",       "state_name": "Uttar Pradesh",   "river_name": "Gomti",        "lat": 26.85, "lon": 80.95, "warning_discharge": 2000,  "danger_discharge": 4000},
    {"station_name": "Agra",          "state_name": "Uttar Pradesh",   "river_name": "Yamuna",       "lat": 27.18, "lon": 78.01, "warning_discharge": 8000,  "danger_discharge": 18000},
    # Andhra Pradesh
    {"station_name": "Vijayawada",    "state_name": "Andhra Pradesh",  "river_name": "Krishna",      "lat": 16.51, "lon": 80.63, "warning_discharge": 8000,  "danger_discharge": 16000},
    {"station_name": "Rajahmundry",   "state_name": "Andhra Pradesh",  "river_name": "Godavari",     "lat": 16.99, "lon": 81.78, "warning_discharge": 15000, "danger_discharge": 30000},
    {"station_name": "Kurnool",       "state_name": "Andhra Pradesh",  "river_name": "Tungabhadra",  "lat": 15.83, "lon": 78.04, "warning_discharge": 5000,  "danger_discharge": 10000},
    # Telangana
    {"station_name": "Hyderabad",     "state_name": "Telangana",       "river_name": "Musi",         "lat": 17.38, "lon": 78.49, "warning_discharge": 1500,  "danger_discharge": 3000},
    {"station_name": "Warangal",      "state_name": "Telangana",       "river_name": "Wainganga",    "lat": 17.97, "lon": 79.59, "warning_discharge": 2000,  "danger_discharge": 4000},
    # Karnataka
    {"station_name": "Mysuru",        "state_name": "Karnataka",       "river_name": "Kaveri",       "lat": 12.30, "lon": 76.65, "warning_discharge": 4000,  "danger_discharge": 8000},
    {"station_name": "Hubballi",      "state_name": "Karnataka",       "river_name": "Tungabhadra",  "lat": 15.36, "lon": 75.13, "warning_discharge": 3000,  "danger_discharge": 6000},
    {"station_name": "Belagavi",      "state_name": "Karnataka",       "river_name": "Malaprabha",   "lat": 15.85, "lon": 74.50, "warning_discharge": 1500,  "danger_discharge": 3000},
    # Gujarat
    {"station_name": "Surat",         "state_name": "Gujarat",         "river_name": "Tapi",         "lat": 21.17, "lon": 72.83, "warning_discharge": 5000,  "danger_discharge": 10000},
    {"station_name": "Vadodara",      "state_name": "Gujarat",         "river_name": "Vishwamitri",  "lat": 22.30, "lon": 73.20, "warning_discharge": 3000,  "danger_discharge": 6000},
    {"station_name": "Rajkot",        "state_name": "Gujarat",         "river_name": "Aji",          "lat": 22.30, "lon": 70.80, "warning_discharge": 500,   "danger_discharge": 1000},
    # Madhya Pradesh
    {"station_name": "Jabalpur",      "state_name": "Madhya Pradesh",  "river_name": "Narmada",      "lat": 23.18, "lon": 79.94, "warning_discharge": 8000,  "danger_discharge": 16000},
    {"station_name": "Bhopal",        "state_name": "Madhya Pradesh",  "river_name": "Betwa",        "lat": 23.26, "lon": 77.41, "warning_discharge": 3000,  "danger_discharge": 6000},
    {"station_name": "Gwalior",       "state_name": "Madhya Pradesh",  "river_name": "Chambal",      "lat": 26.22, "lon": 78.18, "warning_discharge": 4000,  "danger_discharge": 9000},
    # Rajasthan
    {"station_name": "Kota",          "state_name": "Rajasthan",       "river_name": "Chambal",      "lat": 25.18, "lon": 75.83, "warning_discharge": 4500,  "danger_discharge": 9500},
    {"station_name": "Jaipur",        "state_name": "Rajasthan",       "river_name": "Banas",        "lat": 26.91, "lon": 75.79, "warning_discharge": 1500,  "danger_discharge": 3000},
    # Punjab
    {"station_name": "Ludhiana",      "state_name": "Punjab",          "river_name": "Sutlej",       "lat": 30.90, "lon": 75.85, "warning_discharge": 5000,  "danger_discharge": 10000},
    {"station_name": "Amritsar",      "state_name": "Punjab",          "river_name": "Ravi",         "lat": 31.63, "lon": 74.87, "warning_discharge": 3000,  "danger_discharge": 6000},
    # Haryana
    {"station_name": "Ambala",        "state_name": "Haryana",         "river_name": "Ghaggar",      "lat": 30.38, "lon": 76.78, "warning_discharge": 2000,  "danger_discharge": 4500},
    {"station_name": "Panipat",       "state_name": "Haryana",         "river_name": "Yamuna",       "lat": 29.38, "lon": 76.97, "warning_discharge": 5000,  "danger_discharge": 10000},
    # Delhi
    {"station_name": "New Delhi",     "state_name": "Delhi",           "river_name": "Yamuna",       "lat": 28.61, "lon": 77.21, "warning_discharge": 5000,  "danger_discharge": 10000},
    # Uttarakhand
    {"station_name": "Haridwar",      "state_name": "Uttarakhand",     "river_name": "Ganga",        "lat": 29.95, "lon": 78.16, "warning_discharge": 10000, "danger_discharge": 22000},
    {"station_name": "Dehradun",      "state_name": "Uttarakhand",     "river_name": "Song",         "lat": 30.32, "lon": 78.03, "warning_discharge": 1500,  "danger_discharge": 3000},
    # Himachal Pradesh
    {"station_name": "Mandi",         "state_name": "Himachal Pradesh","river_name": "Beas",         "lat": 31.71, "lon": 76.93, "warning_discharge": 3000,  "danger_discharge": 7000},
    {"station_name": "Shimla",        "state_name": "Himachal Pradesh","river_name": "Giri",         "lat": 31.10, "lon": 77.17, "warning_discharge": 800,   "danger_discharge": 2000},
    # Tamil Nadu
    {"station_name": "Chennai",       "state_name": "Tamil Nadu",      "river_name": "Adyar",        "lat": 13.08, "lon": 80.27, "warning_discharge": 1500,  "danger_discharge": 3000},
    {"station_name": "Madurai",       "state_name": "Tamil Nadu",      "river_name": "Vaigai",       "lat":  9.93, "lon": 78.12, "warning_discharge": 1200,  "danger_discharge": 2500},
    {"station_name": "Tiruchirappalli","state_name": "Tamil Nadu",     "river_name": "Kaveri",       "lat": 10.79, "lon": 78.70, "warning_discharge": 6000,  "danger_discharge": 12000},
    # Chhattisgarh
    {"station_name": "Raipur",        "state_name": "Chhattisgarh",    "river_name": "Mahanadi",     "lat": 21.25, "lon": 81.63, "warning_discharge": 3000,  "danger_discharge": 6000},
    {"station_name": "Bilaspur",      "state_name": "Chhattisgarh",    "river_name": "Arpa",         "lat": 22.07, "lon": 82.15, "warning_discharge": 1500,  "danger_discharge": 3000},
    # Jharkhand
    {"station_name": "Ranchi",        "state_name": "Jharkhand",       "river_name": "Subarnarekha", "lat": 23.35, "lon": 85.33, "warning_discharge": 2000,  "danger_discharge": 4500},
    {"station_name": "Dhanbad",       "state_name": "Jharkhand",       "river_name": "Damodar",      "lat": 23.80, "lon": 86.45, "warning_discharge": 3000,  "danger_discharge": 6500},
    # Arunachal Pradesh
    {"station_name": "Pasighat",      "state_name": "Arunachal Pradesh","river_name": "Brahmaputra", "lat": 28.07, "lon": 95.33, "warning_discharge": 20000, "danger_discharge": 40000},
    {"station_name": "Itanagar",      "state_name": "Arunachal Pradesh","river_name": "Dikrong",     "lat": 27.09, "lon": 93.61, "warning_discharge": 3000,  "danger_discharge": 7000},
    # Manipur
    {"station_name": "Imphal",        "state_name": "Manipur",         "river_name": "Imphal River", "lat": 24.82, "lon": 93.95, "warning_discharge": 500,   "danger_discharge": 1200},
    # Meghalaya
    {"station_name": "Shillong",      "state_name": "Meghalaya",       "river_name": "Umiam",        "lat": 25.58, "lon": 91.89, "warning_discharge": 800,   "danger_discharge": 1800},
    {"station_name": "Cherrapunji",   "state_name": "Meghalaya",       "river_name": "Umkhrah",      "lat": 25.30, "lon": 91.70, "warning_discharge": 1500,  "danger_discharge": 3000},
    # Nagaland
    {"station_name": "Dimapur",       "state_name": "Nagaland",        "river_name": "Dhansiri",     "lat": 25.91, "lon": 93.73, "warning_discharge": 800,   "danger_discharge": 1800},
    # Mizoram
    {"station_name": "Aizawl",        "state_name": "Mizoram",         "river_name": "Tlawng",       "lat": 23.73, "lon": 92.72, "warning_discharge": 600,   "danger_discharge": 1400},
    # Tripura
    {"station_name": "Agartala",      "state_name": "Tripura",         "river_name": "Haora",        "lat": 23.84, "lon": 91.28, "warning_discharge": 800,   "danger_discharge": 1800},
    # Sikkim
    {"station_name": "Gangtok",       "state_name": "Sikkim",          "river_name": "Teesta",       "lat": 27.34, "lon": 88.61, "warning_discharge": 2000,  "danger_discharge": 5000},
    # Goa
    {"station_name": "Panaji",        "state_name": "Goa",             "river_name": "Mandovi",      "lat": 15.50, "lon": 73.83, "warning_discharge": 1500,  "danger_discharge": 3000},
    # Jammu & Kashmir
    {"station_name": "Srinagar",      "state_name": "Jammu and Kashmir","river_name": "Jhelum",      "lat": 34.08, "lon": 74.80, "warning_discharge": 3000,  "danger_discharge": 7000},
    {"station_name": "Jammu",         "state_name": "Jammu and Kashmir","river_name": "Tawi",        "lat": 32.73, "lon": 74.87, "warning_discharge": 1500,  "danger_discharge": 3500},
    # Additional high-flood-risk stations
    {"station_name": "Lakhimpur",     "state_name": "Assam",           "river_name": "Subansiri",    "lat": 27.23, "lon": 94.11, "warning_discharge": 5000,  "danger_discharge": 10000},
    {"station_name": "Majuli Island", "state_name": "Assam",           "river_name": "Brahmaputra",  "lat": 26.95, "lon": 94.17, "warning_discharge": 28000, "danger_discharge": 50000},
    {"station_name": "Morigaon",      "state_name": "Assam",           "river_name": "Brahmaputra",  "lat": 26.25, "lon": 92.34, "warning_discharge": 26000, "danger_discharge": 48000},
    {"station_name": "Muzaffarpur",   "state_name": "Bihar",           "river_name": "Gandak",       "lat": 26.12, "lon": 85.36, "warning_discharge": 5000,  "danger_discharge": 10000},
    {"station_name": "Gopalganj",     "state_name": "Bihar",           "river_name": "Gandak",       "lat": 26.47, "lon": 84.44, "warning_discharge": 6000,  "danger_discharge": 12000},
    {"station_name": "Bijnor",        "state_name": "Uttar Pradesh",   "river_name": "Ganga",        "lat": 29.37, "lon": 78.13, "warning_discharge": 15000, "danger_discharge": 32000},
    {"station_name": "Ballia",        "state_name": "Uttar Pradesh",   "river_name": "Ganga",        "lat": 25.76, "lon": 84.15, "warning_discharge": 42000, "danger_discharge": 72000},
    {"station_name": "Navsari",       "state_name": "Gujarat",         "river_name": "Purna",        "lat": 20.95, "lon": 72.93, "warning_discharge": 3000,  "danger_discharge": 6000},
    {"station_name": "Amravati",      "state_name": "Maharashtra",     "river_name": "Wardha",       "lat": 20.93, "lon": 77.75, "warning_discharge": 1500,  "danger_discharge": 3000},
    {"station_name": "Aurangabad",    "state_name": "Maharashtra",     "river_name": "Kham",         "lat": 19.88, "lon": 75.34, "warning_discharge": 800,   "danger_discharge": 1600},
    {"station_name": "Nanded",        "state_name": "Maharashtra",     "river_name": "Godavari",     "lat": 19.16, "lon": 77.32, "warning_discharge": 5000,  "danger_discharge": 10000},
]

# ---------------------------------------------------------------------------
# Open-Meteo GloFAS endpoint
# ---------------------------------------------------------------------------
GLOFAS_API            = "https://flood-api.open-meteo.com/v1/flood"
REFRESH_INTERVAL_SECONDS = 3600   # re-fetch every 60 minutes
BATCH_SIZE            = 10        # stations per API call
INTER_BATCH_DELAY     = 7.0       # seconds between sequential batches (≈ 8 req/min)

# Callers can read this flag to decide whether the cache is warm.
# Set to True after the first successful fetch cycle completes.
CACHE_READY: bool = False


async def _fetch_glofas_batch(
    client: httpx.AsyncClient,
    stations: List[Dict[str, Any]],
) -> List[Dict[str, Any]]:
    """
    Fetch GloFAS river_discharge for a single batch of stations.
    Open-Meteo flood API supports comma-separated lat/lon lists.
    Returns a list of enriched station dicts (empty on any error).
    """
    lats = ",".join(str(s["lat"]) for s in stations)
    lons = ",".join(str(s["lon"]) for s in stations)

    params = {
        "latitude":      lats,
        "longitude":     lons,
        "daily":         "river_discharge",
        "forecast_days": 1,
        "models":        "seamless_v4",
    }

    try:
        resp = await client.get(GLOFAS_API, params=params, timeout=20)
        resp.raise_for_status()
        payload = resp.json()
    except Exception as exc:
        print(f"[glofas_cache] ⚠️  batch fetch failed: {exc}")
        return []

    locations = payload if isinstance(payload, list) else [payload]
    results: List[Dict[str, Any]] = []
    now_iso = datetime.datetime.utcnow().isoformat() + "Z"

    for i, loc in enumerate(locations):
        if i >= len(stations):
            break
        station = stations[i]
        daily = loc.get("daily") or {}
        discharge_list = daily.get("river_discharge") or []
        discharge = float(discharge_list[0]) if discharge_list else 0.0

        warning_q = float(station.get("warning_discharge") or 0)
        danger_q  = float(station.get("danger_discharge")  or 0)

        if danger_q > 0 and discharge >= danger_q:
            risk = "CRITICAL"
        elif warning_q > 0 and discharge >= warning_q:
            risk = "HIGH"
        elif warning_q > 0 and discharge >= warning_q * 0.7:
            risk = "MODERATE"
        else:
            risk = "LOW"

        results.append({
            "station_name":      station["station_name"],
            "state_name":        station["state_name"],
            "river_name":        station["river_name"],
            "lat":               station["lat"],
            "lon":               station["lon"],
            "river_discharge":   round(discharge, 2),
            "warning_discharge": warning_q,
            "danger_discharge":  danger_q,
            "risk_level":        risk,
            "timestamp":         now_iso,
            "source":            "OPEN_METEO_GLOFAS",
        })

    return results


async def fetch_all_glofas() -> List[Dict[str, Any]]:
    """
    Fetch GloFAS discharge for all INDIA_STATIONS using sequential batches
    with INTER_BATCH_DELAY between each to avoid 429 rate-limit errors.

    Sequential (not concurrent) is intentional — Open-Meteo free tier
    allows only 1 concurrent connection and ~10 req/min.
    """
    all_results: List[Dict[str, Any]] = []
    total = len(INDIA_STATIONS)
    num_batches = (total + BATCH_SIZE - 1) // BATCH_SIZE

    async with httpx.AsyncClient() as client:
        for batch_num, start in enumerate(range(0, total, BATCH_SIZE), start=1):
            batch = INDIA_STATIONS[start: start + BATCH_SIZE]
            batch_results = await _fetch_glofas_batch(client, batch)
            all_results.extend(batch_results)
            print(
                f"[glofas_cache] batch {batch_num}/{num_batches} "
                f"({len(batch_results)}/{len(batch)} ok)"
            )
            # Wait between batches to stay under the rate limit.
            # Skip the delay after the very last batch.
            if start + BATCH_SIZE < total:
                await asyncio.sleep(INTER_BATCH_DELAY)

    return all_results


def _write_to_app_cache(stations: List[Dict[str, Any]]):
    """Write fetched stations into app.GLOFAS_STATION_CACHE."""
    for mod_name in ('backend.app', 'app'):
        mod = sys.modules.get(mod_name)
        if mod is not None:
            mod.GLOFAS_STATION_CACHE = stations
            return


async def start_glofas_refresh_loop():
    """
    Background asyncio task: fetch GloFAS data immediately on startup,
    then refresh every REFRESH_INTERVAL_SECONDS.

    Sets CACHE_READY = True once the first cycle completes so that
    /api/live-telemetry can serve tactical fallback instead of blocking.
    """
    global CACHE_READY
    while True:
        try:
            print(
                f"[glofas_cache] 🔄 Fetching GloFAS data for "
                f"{len(INDIA_STATIONS)} stations "
                f"({(len(INDIA_STATIONS) + BATCH_SIZE - 1) // BATCH_SIZE} batches, "
                f"{INTER_BATCH_DELAY}s delay each)..."
            )
            stations = await fetch_all_glofas()
            if stations:
                _write_to_app_cache(stations)
                CACHE_READY = True
                print(
                    f"[glofas_cache] ✅ Cache updated: "
                    f"{len(stations)} stations from OPEN_METEO_GLOFAS"
                )
            else:
                print("[glofas_cache] ⚠️  GloFAS fetch returned 0 stations — cache not updated")
        except Exception as exc:
            print(f"[glofas_cache] ❌ Refresh loop error: {exc}")
        await asyncio.sleep(REFRESH_INTERVAL_SECONDS)
