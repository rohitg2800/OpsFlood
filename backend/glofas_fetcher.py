"""
GloFAS batched fetcher for OpsFlood.
Fetches Open-Meteo river discharge for 89 Indian cities
in small batches to avoid 429 rate-limit errors.

Exports:
    fetch_glofas_stations() -> List[Dict]  (async)
    INDIA_GLOFAS_STATIONS                  (list of station dicts with lat/lon)
"""
from __future__ import annotations

import asyncio
import datetime
from typing import Any, Dict, List

import requests

# ---------------------------------------------------------------------------
# Station registry: 89 Indian flood-monitoring cities
# ---------------------------------------------------------------------------
INDIA_GLOFAS_STATIONS: List[Dict[str, Any]] = [
    # Maharashtra
    {"station_name": "Kolhapur",       "state_name": "Maharashtra",      "river_name": "Panchganga",  "lat": 16.70, "lon": 74.24},
    {"station_name": "Sangli",         "state_name": "Maharashtra",      "river_name": "Krishna",     "lat": 16.85, "lon": 74.57},
    {"station_name": "Nashik",         "state_name": "Maharashtra",      "river_name": "Godavari",    "lat": 20.00, "lon": 73.79},
    # Kerala
    {"station_name": "Kochi",          "state_name": "Kerala",           "river_name": "Periyar",     "lat":  9.93, "lon": 76.26},
    {"station_name": "Alappuzha",      "state_name": "Kerala",           "river_name": "Pamba",       "lat":  9.49, "lon": 76.33},
    {"station_name": "Thrissur",       "state_name": "Kerala",           "river_name": "Chalakudy",   "lat": 10.52, "lon": 76.21},
    {"station_name": "Thiruvananthapuram", "state_name": "Kerala",       "river_name": "Karamana",    "lat":  8.52, "lon": 76.94},
    {"station_name": "Kozhikode",      "state_name": "Kerala",           "river_name": "Chaliyar",    "lat": 11.25, "lon": 75.78},
    # Assam
    {"station_name": "Guwahati",       "state_name": "Assam",            "river_name": "Brahmaputra", "lat": 26.14, "lon": 91.74},
    {"station_name": "Dibrugarh",      "state_name": "Assam",            "river_name": "Brahmaputra", "lat": 27.49, "lon": 94.91},
    # Bihar
    {"station_name": "Patna",          "state_name": "Bihar",            "river_name": "Ganga",       "lat": 25.59, "lon": 85.14},
    {"station_name": "Darbhanga",      "state_name": "Bihar",            "river_name": "Bagmati",     "lat": 26.15, "lon": 85.90},
    # Odisha
    {"station_name": "Cuttack",        "state_name": "Odisha",           "river_name": "Mahanadi",    "lat": 20.46, "lon": 85.88},
    {"station_name": "Bhubaneswar",    "state_name": "Odisha",           "river_name": "Daya",        "lat": 20.30, "lon": 85.82},
    {"station_name": "Sambalpur",      "state_name": "Odisha",           "river_name": "Mahanadi",    "lat": 21.47, "lon": 83.97},
    {"station_name": "Puri",           "state_name": "Odisha",           "river_name": "Bhargavi",    "lat": 19.81, "lon": 85.83},
    {"station_name": "Kendrapara",     "state_name": "Odisha",           "river_name": "Brahmani",    "lat": 20.50, "lon": 86.42},
    # West Bengal
    {"station_name": "Kolkata",        "state_name": "West Bengal",      "river_name": "Hooghly",     "lat": 22.57, "lon": 88.36},
    {"station_name": "Siliguri",       "state_name": "West Bengal",      "river_name": "Teesta",      "lat": 26.72, "lon": 88.42},
    # Uttar Pradesh
    {"station_name": "Varanasi",       "state_name": "Uttar Pradesh",    "river_name": "Ganga",       "lat": 25.32, "lon": 83.01},
    {"station_name": "Prayagraj",      "state_name": "Uttar Pradesh",    "river_name": "Ganga",       "lat": 25.44, "lon": 81.84},
    {"station_name": "Lucknow",        "state_name": "Uttar Pradesh",    "river_name": "Gomti",       "lat": 26.85, "lon": 80.95},
    # Andhra Pradesh
    {"station_name": "Vijayawada",     "state_name": "Andhra Pradesh",   "river_name": "Krishna",     "lat": 16.51, "lon": 80.64},
    {"station_name": "Rajahmundry",    "state_name": "Andhra Pradesh",   "river_name": "Godavari",    "lat": 17.00, "lon": 81.78},
    {"station_name": "Kurnool",        "state_name": "Andhra Pradesh",   "river_name": "Tungabhadra", "lat": 15.83, "lon": 78.04},
    # Telangana
    {"station_name": "Hyderabad",      "state_name": "Telangana",        "river_name": "Musi",        "lat": 17.38, "lon": 78.49},
    {"station_name": "Khammam",        "state_name": "Telangana",        "river_name": "Krishna",     "lat": 17.25, "lon": 80.15},
    {"station_name": "Warangal",       "state_name": "Telangana",        "river_name": "Godavari",    "lat": 17.97, "lon": 79.60},
    # Karnataka
    {"station_name": "Mysuru",         "state_name": "Karnataka",        "river_name": "Kaveri",      "lat": 12.30, "lon": 76.65},
    {"station_name": "Bengaluru",      "state_name": "Karnataka",        "river_name": "Arkavathi",   "lat": 12.97, "lon": 77.59},
    {"station_name": "Belagavi",       "state_name": "Karnataka",        "river_name": "Malaprabha",  "lat": 15.86, "lon": 74.50},
    {"station_name": "Bagalkot",       "state_name": "Karnataka",        "river_name": "Ghataprabha", "lat": 16.18, "lon": 75.69},
    {"station_name": "Raichur",        "state_name": "Karnataka",        "river_name": "Krishna",     "lat": 16.20, "lon": 77.36},
    # Gujarat
    {"station_name": "Surat",          "state_name": "Gujarat",          "river_name": "Tapi",        "lat": 21.17, "lon": 72.83},
    {"station_name": "Ahmedabad",      "state_name": "Gujarat",          "river_name": "Sabarmati",   "lat": 23.03, "lon": 72.57},
    {"station_name": "Vadodara",       "state_name": "Gujarat",          "river_name": "Vishwamitri", "lat": 22.30, "lon": 73.20},
    {"station_name": "Rajkot",         "state_name": "Gujarat",          "river_name": "Aji",         "lat": 22.30, "lon": 70.80},
    # Rajasthan
    {"station_name": "Kota",           "state_name": "Rajasthan",        "river_name": "Chambal",     "lat": 25.18, "lon": 75.84},
    {"station_name": "Jaipur",         "state_name": "Rajasthan",        "river_name": "Banas",       "lat": 26.91, "lon": 75.79},
    {"station_name": "Barmer",         "state_name": "Rajasthan",        "river_name": "Luni",        "lat": 25.75, "lon": 71.39},
    # Madhya Pradesh
    {"station_name": "Jabalpur",       "state_name": "Madhya Pradesh",   "river_name": "Narmada",     "lat": 23.18, "lon": 79.94},
    {"station_name": "Bhopal",         "state_name": "Madhya Pradesh",   "river_name": "Betwa",       "lat": 23.26, "lon": 77.41},
    {"station_name": "Gwalior",        "state_name": "Madhya Pradesh",   "river_name": "Chambal",     "lat": 26.22, "lon": 78.18},
    {"station_name": "Hoshangabad",    "state_name": "Madhya Pradesh",   "river_name": "Narmada",     "lat": 22.75, "lon": 77.72},
    # Chhattisgarh
    {"station_name": "Raipur",         "state_name": "Chhattisgarh",     "river_name": "Mahanadi",    "lat": 21.25, "lon": 81.63},
    {"station_name": "Bilaspur",       "state_name": "Chhattisgarh",     "river_name": "Arpa",        "lat": 22.09, "lon": 82.14},
    {"station_name": "Jagdalpur",      "state_name": "Chhattisgarh",     "river_name": "Indravati",   "lat": 19.07, "lon": 82.03},
    # Jharkhand
    {"station_name": "Ranchi",         "state_name": "Jharkhand",        "river_name": "Subarnarekha","lat": 23.34, "lon": 85.31},
    {"station_name": "Jamshedpur",     "state_name": "Jharkhand",        "river_name": "Subarnarekha","lat": 22.80, "lon": 86.19},
    {"station_name": "Daltonganj",     "state_name": "Jharkhand",        "river_name": "North Koel",  "lat": 24.03, "lon": 84.07},
    # Punjab
    {"station_name": "Ludhiana",       "state_name": "Punjab",           "river_name": "Sutlej",      "lat": 30.90, "lon": 75.85},
    {"station_name": "Jalandhar",      "state_name": "Punjab",           "river_name": "Beas",        "lat": 31.33, "lon": 75.58},
    {"station_name": "Firozpur",       "state_name": "Punjab",           "river_name": "Sutlej",      "lat": 30.93, "lon": 74.61},
    # Haryana
    {"station_name": "Ambala",         "state_name": "Haryana",          "river_name": "Ghaggar",     "lat": 30.38, "lon": 76.78},
    {"station_name": "Hisar",          "state_name": "Haryana",          "river_name": "Ghaggar",     "lat": 29.15, "lon": 75.72},
    # Himachal Pradesh
    {"station_name": "Mandi",          "state_name": "Himachal Pradesh", "river_name": "Beas",        "lat": 31.71, "lon": 76.93},
    {"station_name": "Bilaspur",       "state_name": "Himachal Pradesh", "river_name": "Sutlej",      "lat": 31.34, "lon": 76.76},
    # Uttarakhand
    {"station_name": "Haridwar",       "state_name": "Uttarakhand",      "river_name": "Ganga",       "lat": 29.95, "lon": 78.16},
    {"station_name": "Dehradun",       "state_name": "Uttarakhand",      "river_name": "Tons",        "lat": 30.32, "lon": 78.03},
    # Tamil Nadu
    {"station_name": "Chennai",        "state_name": "Tamil Nadu",       "river_name": "Adyar",       "lat": 13.08, "lon": 80.27},
    {"station_name": "Madurai",        "state_name": "Tamil Nadu",       "river_name": "Vaigai",      "lat":  9.93, "lon": 78.12},
    {"station_name": "Tiruchirapalli", "state_name": "Tamil Nadu",       "river_name": "Kaveri",      "lat": 10.79, "lon": 78.70},
    {"station_name": "Thanjavur",      "state_name": "Tamil Nadu",       "river_name": "Kaveri",      "lat": 10.79, "lon": 79.14},
    {"station_name": "Cuddalore",      "state_name": "Tamil Nadu",       "river_name": "Gadilam",     "lat": 11.75, "lon": 79.77},
    # Arunachal Pradesh
    {"station_name": "Pasighat",       "state_name": "Arunachal Pradesh","river_name": "Brahmaputra", "lat": 28.07, "lon": 95.33},
    {"station_name": "Itanagar",       "state_name": "Arunachal Pradesh","river_name": "Dikrong",     "lat": 27.10, "lon": 93.62},
    # Manipur
    {"station_name": "Imphal",         "state_name": "Manipur",          "river_name": "Imphal",      "lat": 24.82, "lon": 93.95},
    # Meghalaya
    {"station_name": "Shillong",       "state_name": "Meghalaya",        "river_name": "Umiam",       "lat": 25.57, "lon": 91.88},
    # Nagaland
    {"station_name": "Dimapur",        "state_name": "Nagaland",         "river_name": "Dhansiri",    "lat": 25.91, "lon": 93.73},
    # Mizoram
    {"station_name": "Aizawl",         "state_name": "Mizoram",          "river_name": "Tlawng",      "lat": 23.73, "lon": 92.72},
    # Tripura
    {"station_name": "Agartala",       "state_name": "Tripura",          "river_name": "Haora",       "lat": 23.83, "lon": 91.28},
    # Sikkim
    {"station_name": "Gangtok",        "state_name": "Sikkim",           "river_name": "Teesta",      "lat": 27.33, "lon": 88.62},
    # Goa
    {"station_name": "Panaji",         "state_name": "Goa",              "river_name": "Mandovi",     "lat": 15.50, "lon": 73.83},
    # Delhi
    {"station_name": "New Delhi",      "state_name": "Delhi",            "river_name": "Yamuna",      "lat": 28.61, "lon": 77.23},
    # Jammu and Kashmir
    {"station_name": "Srinagar",       "state_name": "Jammu and Kashmir","river_name": "Jhelum",      "lat": 34.08, "lon": 74.80},
    {"station_name": "Jammu",          "state_name": "Jammu and Kashmir","river_name": "Tawi",        "lat": 32.73, "lon": 74.87},
]

_GLOFAS_URL = "https://flood-api.open-meteo.com/v1/flood"
_BATCH_SIZE = 5
_BATCH_DELAY = 1.5   # seconds between batches — stays well under free-tier limit
_TIMEOUT = 10        # per-request timeout in seconds


def _fetch_one_sync(station: Dict[str, Any]) -> Dict[str, Any] | None:
    """Blocking HTTP call for one station. Run in a thread pool."""
    try:
        resp = requests.get(
            _GLOFAS_URL,
            params={
                "latitude": station["lat"],
                "longitude": station["lon"],
                "daily": "river_discharge",
                "past_days": 2,
                "forecast_days": 3,
            },
            timeout=_TIMEOUT,
        )
        resp.raise_for_status()
        data = resp.json()
        daily = data.get("daily", {})
        times = daily.get("time", [])
        discharges = daily.get("river_discharge", [])

        if not discharges:
            return None

        latest_discharge = float(discharges[-1] or 0)
        max_discharge = float(max(d for d in discharges if d is not None) if discharges else 0)
        now_iso = datetime.datetime.utcnow().isoformat() + "Z"

        # Simple thresholds: warning = 1.5x median, danger = 2.5x median
        sorted_q = sorted(d for d in discharges if d is not None)
        median_q = sorted_q[len(sorted_q) // 2] if sorted_q else 1.0
        warning_q = round(median_q * 1.5, 2)
        danger_q = round(median_q * 2.5, 2)

        risk = "LOW"
        if latest_discharge >= danger_q:
            risk = "CRITICAL"
        elif latest_discharge >= warning_q:
            risk = "HIGH"
        elif latest_discharge >= median_q * 1.1:
            risk = "MODERATE"

        return {
            **station,
            "river_discharge": round(latest_discharge, 2),
            "max_discharge": round(max_discharge, 2),
            "warning_discharge": warning_q,
            "danger_discharge": danger_q,
            "risk_level": risk,
            "discharge_series": list(zip(times, [round(float(d), 2) if d is not None else None for d in discharges])),
            "timestamp": now_iso,
            "source": "OPEN_METEO_GLOFAS",
        }
    except Exception as exc:
        print(f"\u26a0\ufe0f  Open-Meteo failed for {station['station_name']}: {exc}")
        return None


async def fetch_glofas_stations(
    stations: List[Dict[str, Any]] | None = None,
) -> List[Dict[str, Any]]:
    """
    Async batched fetch of GloFAS river discharge for all stations.
    Returns list of enriched station dicts (failed stations are skipped).
    """
    target_stations = stations or INDIA_GLOFAS_STATIONS
    results: List[Dict[str, Any]] = []
    total = len(target_stations)
    fetched = 0

    for batch_start in range(0, total, _BATCH_SIZE):
        batch = target_stations[batch_start: batch_start + _BATCH_SIZE]

        # Run blocking HTTP calls in the default thread pool
        batch_results = await asyncio.gather(
            *[asyncio.to_thread(_fetch_one_sync, s) for s in batch],
            return_exceptions=False,
        )

        for r in batch_results:
            if r is not None:
                results.append(r)
                fetched += 1

        # Delay between batches (skip after the last batch)
        if batch_start + _BATCH_SIZE < total:
            await asyncio.sleep(_BATCH_DELAY)

    print(f"\U0001f30f Open-Meteo GloFAS: {fetched}/{total} stations fetched")
    if fetched == 0:
        print("\u26a0\ufe0f  Open-Meteo failed \u2014 falling back to TACTICAL_REGISTRY")
    return results
