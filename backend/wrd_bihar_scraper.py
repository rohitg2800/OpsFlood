"""
backend/wrd_bihar_scraper.py
OpsFlood — Live Gauge Scraper v5

Primary sources (Bihar):
  1. irrigation.befiqr.in/state/table/rivers
     → WRD Bihar Central Flood Control Cell — 31 sites, updated hourly
  2. irrigation.fmiscwrdbihar.gov.in/state/table/rtdas-stations
     → WRD Bihar RTDAS telemetry — 25 sites, updated every 15 min

National synthetic fallback (for non-Bihar stations).
Full synthetic fallback for Bihar when both live sources are unreachable.
"""

import hashlib
import math
import re
from datetime import datetime, timedelta
from typing import Optional

try:
    import httpx
    from bs4 import BeautifulSoup
    _DEPS_OK = True
except ImportError:
    _DEPS_OK = False

# ─────────────────────────────────────────────────────────────────────────────
# Station master data — Bihar (12 key monitoring points)
# ─────────────────────────────────────────────────────────────────────────────
BIHAR_STATIONS = [
    {"id":"GN01","name":"Gandhighat",        "aliases":["gandhighat","gandhi setu","patna","dighaghat"],
     "river":"Ganga",        "district":"Patna",          "state":"Bihar","lat":25.61,"lon":85.14,"danger":50.45,"warning":49.45,"low":44.0},
    {"id":"HJ01","name":"Hajipur",            "aliases":["hajipur"],
     "river":"Gandak",       "district":"Vaishali",       "state":"Bihar","lat":25.68,"lon":85.21,"danger":50.32,"warning":49.32,"low":44.0},
    {"id":"MZ01","name":"Muzaffarpur",         "aliases":["muzaffarpur","sikandarpur","muzzafarpur"],
     "river":"Burhi Gandak", "district":"Muzaffarpur",    "state":"Bihar","lat":26.12,"lon":85.39,"danger":52.53,"warning":51.53,"low":45.0},
    {"id":"DB01","name":"Darbhanga",           "aliases":["darbhanga","jhanjharpur","kamalabalan"],
     "river":"Kamla Balan",  "district":"Darbhanga",      "state":"Bihar","lat":26.15,"lon":85.89,"danger":50.00,"warning":49.00,"low":43.0},
    {"id":"SH01","name":"Dheng Bridge",        "aliases":["dheng bridge","sitamarhi","dheng"],
     "river":"Bagmati",      "district":"Sitamarhi",      "state":"Bihar","lat":26.59,"lon":85.49,"danger":71.00,"warning":70.00,"low":65.0},
    {"id":"SP01","name":"Kosi Barrage",         "aliases":["kosi barrage","supaul","basua","baltara","kursela"],
     "river":"Kosi",         "district":"Supaul",         "state":"Bihar","lat":26.13,"lon":86.61,"danger":74.70,"warning":73.70,"low":68.0},
    {"id":"BG01","name":"Bhagalpur",           "aliases":["bhagalpur","kahalgaon"],
     "river":"Ganga",        "district":"Bhagalpur",      "state":"Bihar","lat":25.24,"lon":86.98,"danger":33.68,"warning":32.68,"low":27.0},
    {"id":"MN01","name":"Munger",              "aliases":["munger"],
     "river":"Ganga",        "district":"Munger",         "state":"Bihar","lat":25.37,"lon":86.47,"danger":39.33,"warning":38.33,"low":32.0},
    {"id":"SP02","name":"Samastipur",           "aliases":["samastipur","rosera","khagaria"],
     "river":"Burhi Gandak", "district":"Samastipur",     "state":"Bihar","lat":25.87,"lon":85.78,"danger":46.00,"warning":45.00,"low":39.0},
    {"id":"PU01","name":"Purnea",             "aliases":["purnea","dhengraghat","mahananda"],
     "river":"Mahananda",    "district":"Purnea",         "state":"Bihar","lat":25.78,"lon":87.48,"danger":35.65,"warning":34.65,"low":29.0},
    {"id":"BH01","name":"Gandak Chatia",       "aliases":["chatia","bettiah","dumariaghat","rewaghat"],
     "river":"Gandak",       "district":"West Champaran", "state":"Bihar","lat":26.80,"lon":84.50,"danger":69.15,"warning":68.15,"low":63.0},
    {"id":"GX01","name":"Buxar",              "aliases":["buxar"],
     "river":"Ganga",        "district":"Buxar",          "state":"Bihar","lat":25.57,"lon":83.97,"danger":60.30,"warning":59.30,"low":53.0},
]

# ─────────────────────────────────────────────────────────────────────────────
# National stations (synthetic only — no live source yet)
# ─────────────────────────────────────────────────────────────────────────────
NATIONAL_STATIONS = [
    {"id":"MH_PUN","name":"Pune",      "aliases":["pune"],"river":"Mula-Mutha",  "district":"Pune",       "state":"Maharashtra",   "lat":18.52,"lon":73.86,"danger":25.0, "warning":23.0, "low":18.0},
    {"id":"MH_MUM","name":"Mumbai",    "aliases":["mumbai"],"river":"Mithi",    "district":"Mumbai",     "state":"Maharashtra",   "lat":19.08,"lon":72.88,"danger":5.0,  "warning":4.0,  "low":2.0},
    {"id":"UP_VAR","name":"Varanasi",  "aliases":["varanasi"],"river":"Ganga",  "district":"Varanasi",  "state":"Uttar Pradesh", "lat":25.32,"lon":82.97,"danger":71.26,"warning":70.26,"low":66.0},
    {"id":"AS_GUW","name":"Guwahati",  "aliases":["guwahati"],"river":"Brahmaputra","district":"Kamrup","state":"Assam",         "lat":26.14,"lon":91.74,"danger":49.68,"warning":48.68,"low":44.0},
    {"id":"KE_KOC","name":"Kochi",     "aliases":["kochi"],"river":"Periyar",  "district":"Ernakulam", "state":"Kerala",        "lat":9.93, "lon":76.27,"danger":7.0,  "warning":6.0,  "low":3.0},
    {"id":"WB_KOL","name":"Kolkata",   "aliases":["kolkata"],"river":"Hooghly", "district":"Kolkata",  "state":"West Bengal",   "lat":22.57,"lon":88.36,"danger":5.5,  "warning":4.5,  "low":2.0},
    {"id":"OD_CUT","name":"Cuttack",   "aliases":["cuttack"],"river":"Mahanadi","district":"Cuttack",  "state":"Odisha",        "lat":20.46,"lon":85.88,"danger":22.0, "warning":20.5, "low":16.0},
    {"id":"HP_HAR","name":"Haridwar",  "aliases":["haridwar"],"river":"Ganga",  "district":"Haridwar",  "state":"Uttarakhand",   "lat":29.94,"lon":78.16,"danger":294.0,"warning":293.0,"low":289.0},
    {"id":"UP_GOR","name":"Gorakhpur", "aliases":["gorakhpur"],"river":"Rapti", "district":"Gorakhpur","state":"Uttar Pradesh", "lat":26.76,"lon":83.37,"danger":84.0, "warning":83.0, "low":79.0},
    {"id":"AS_DHU","name":"Dhubri",    "aliases":["dhubri"],"river":"Brahmaputra","district":"Dhubri",  "state":"Assam",         "lat":26.02,"lon":89.98,"danger":30.30,"warning":29.30,"low":25.0},
    {"id":"WB_JAL","name":"Jalpaiguri","aliases":["jalpaiguri"],"river":"Teesta","district":"Jalpaiguri","state":"West Bengal", "lat":26.54,"lon":88.72,"danger":82.60,"warning":81.60,"low":77.0},
]

ALL_STATIONS = BIHAR_STATIONS + NATIONAL_STATIONS

# Live source URLs
BEFIQR_URL  = "https://irrigation.befiqr.in/state/table/rivers"
RTDAS_URL   = "https://irrigation.fmiscwrdbihar.gov.in/state/table/rtdas-stations?platform=mobileapp&hide=hamburger"
HTTP_HEADERS = {
    "User-Agent": "Mozilla/5.0 (compatible; OpsFlood/2.0; flood monitoring)",
    "Accept": "text/html,application/xhtml+xml",
}


# ─────────────────────────────────────────────────────────────────────────────
# Synthetic helpers
# ─────────────────────────────────────────────────────────────────────────────
def _synthetic_level(station: dict, now: datetime) -> float:
    seed = f"{station['id']}{now.year}{now.month}{now.day}{now.hour}".encode()
    h = int(hashlib.md5(seed).hexdigest(), 16)
    month_factor = 0.62 + 0.22 * math.sin(math.pi * (now.month - 3) / 6)
    hour_noise   = 0.02 * math.sin(2 * math.pi * now.hour / 24)
    pct = max(0.40, min(0.97, month_factor + hour_noise + (h % 100) / 2000))
    return round(station["low"] + (station["danger"] - station["low"]) * pct, 2)


def _status(current: float, station: dict) -> str:
    if current >= station["danger"]:  return "danger"
    if current >= station["warning"]: return "warning"
    return "normal"


def _trend_from_diff(diff: Optional[float]) -> str:
    """Compute trend from 24h diff when available."""
    if diff is None: return "stable"
    if diff >  0.10: return "rising"
    if diff < -0.10: return "falling"
    return "stable"


def _trend_synthetic(current: float, station: dict, now: datetime) -> str:
    prev = _synthetic_level(station, now - timedelta(hours=1))
    if current > prev + 0.05: return "rising"
    if current < prev - 0.05: return "falling"
    return "stable"


# ─────────────────────────────────────────────────────────────────────────────
# Record builder
# ─────────────────────────────────────────────────────────────────────────────
def build_record(
    station: dict,
    current: float,
    source: str,
    now: datetime,
    trend: Optional[str] = None,
    hfl: Optional[float] = None,
    obs_time: Optional[str] = None,
) -> dict:
    status   = _status(current, station)
    danger   = station["danger"]
    low      = station["low"]
    pct      = round((current - low) / max(danger - low, 1) * 100, 1)
    risk     = "CRITICAL" if status == "danger" else ("HIGH" if status == "warning" else "LOW")
    hfl_val  = hfl or round(danger * 1.12, 2)
    resolved_trend = trend or _trend_synthetic(current, station, now)
    return {
        "id":               station["id"],
        "name":             station["name"],
        "city":             station["name"].split("(")[0].strip(),
        "river":            station["river"],
        "district":         station["district"],
        "state":            station.get("state", "Bihar"),
        "lat":              station["lat"],
        "lon":              station["lon"],
        "current_level":    current,
        "danger_level":     danger,
        "warning_level":    station["warning"],
        "safe_level":       low,
        "hfl":              hfl_val,
        "status":           status,
        "trend":            resolved_trend,
        "pct_to_danger":    pct,
        "risk_level":       risk,
        "data_source":      source,
        "last_updated":     (obs_time or now.isoformat()),
        "observation_time": (obs_time or now.strftime("%Y-%m-%d %H:%M")),
        "discharge":        round(500 + (current / max(danger, 1)) * 7500, 0),
        "capacity_percent": pct,
        "flow_rate":        round(500 + (current / max(danger, 1)) * 7500, 0),
    }


# ─────────────────────────────────────────────────────────────────────────────
# Station matcher — fuzzy match site name → BIHAR_STATIONS entry
# ─────────────────────────────────────────────────────────────────────────────
def _match_station(site_name: str) -> Optional[dict]:
    """Return the BIHAR_STATIONS entry that best matches site_name."""
    needle = site_name.lower().strip()
    for st in BIHAR_STATIONS:
        if any(alias in needle or needle in alias for alias in st["aliases"]):
            return st
    # Fallback: first-word partial match
    first_word = needle.split()[0] if needle else ""
    for st in BIHAR_STATIONS:
        if first_word and any(first_word in alias for alias in st["aliases"]):
            return st
    return None


def _parse_float(s: str) -> Optional[float]:
    """Parse a numeric string; return None if blank/NA/dash."""
    cleaned = re.sub(r"[^\d.+-]", "", s.strip())
    if not cleaned or cleaned in ("-", "+", "."):
        return None
    try:
        return float(cleaned)
    except ValueError:
        return None


# ─────────────────────────────────────────────────────────────────────────────
# Parser 1 — befiqr.in  (WRD Bihar Central Flood Control Cell)
# Columns: SL | River | Site | HFL | DL | Yesterday WL | Current WL |
#          Diff 24h | Above/Below DL | Trend | District
# ─────────────────────────────────────────────────────────────────────────────
def _parse_befiqr(html: str, now: datetime) -> list:
    soup = BeautifulSoup(html, "html.parser")
    rows = soup.select("table tr")
    results = []   # list of (station_dict, record_dict)
    seen_ids = set()

    for row in rows[1:]:  # skip header
        cols = [td.get_text(strip=True) for td in row.find_all(["td", "th"])]
        if len(cols) < 7:
            continue
        # cols: [sl, river, site, hfl, dl, yesterday_wl, current_wl, diff24h, above_dl, trend, district]
        site_name = re.sub(r"[*\[\]]", "", cols[2]).strip() if len(cols) > 2 else ""
        if not site_name or site_name.upper() in ("SITE", "(3)"):
            continue

        station = _match_station(site_name)
        if not station or station["id"] in seen_ids:
            continue

        current = _parse_float(cols[6]) if len(cols) > 6 else None
        if current is None or current <= 0:
            current = _parse_float(cols[5]) if len(cols) > 5 else None  # fallback to yesterday
        if current is None or current <= 0:
            continue

        hfl_val  = _parse_float(cols[3]) if len(cols) > 3 else None
        diff24h  = _parse_float(cols[7]) if len(cols) > 7 else None
        trend_raw = cols[9].lower() if len(cols) > 9 else ""
        trend = "rising" if "ris" in trend_raw or (diff24h is not None and diff24h > 0.1) \
               else "falling" if "fall" in trend_raw or (diff24h is not None and diff24h < -0.1) \
               else "stable"

        seen_ids.add(station["id"])
        results.append(build_record(
            station, current, "WRD_BIHAR_LIVE", now,
            trend=trend, hfl=hfl_val,
            obs_time=now.strftime("%Y-%m-%d %H:%M"),
        ))

    return results, seen_ids


# ─────────────────────────────────────────────────────────────────────────────
# Parser 2 — fmiscwrdbihar.gov.in  (RTDAS telemetry, 15-min update)
# Columns: River | Station | HFL | DL | Yesterday | Current | Diff | Status |
#          Diff-from-DL | Date-Time | District
# ─────────────────────────────────────────────────────────────────────────────
def _parse_rtdas(html: str, now: datetime, skip_ids: set) -> list:
    soup = BeautifulSoup(html, "html.parser")
    rows = soup.select("table tr")
    results = []
    seen_ids = set(skip_ids)

    for row in rows[1:]:
        cols = [td.get_text(strip=True) for td in row.find_all(["td", "th"])]
        if len(cols) < 6:
            continue
        site_name = cols[1].strip() if len(cols) > 1 else ""
        if not site_name or site_name.upper() in ("STATION NAME", "(2)"):
            continue

        station = _match_station(site_name)
        if not station or station["id"] in seen_ids:
            continue

        current = _parse_float(cols[5]) if len(cols) > 5 else None
        if current is None or current <= 0:
            continue

        hfl_val  = _parse_float(cols[2]) if len(cols) > 2 else None
        diff_raw = _parse_float(cols[6]) if len(cols) > 6 else None
        trend    = _trend_from_diff(diff_raw)

        # obs time from cols[9] e.g. "29 Nov 2025 7:00 PM"
        obs_time_raw = cols[9].strip() if len(cols) > 9 else ""
        try:
            obs_dt = datetime.strptime(obs_time_raw, "%d %b %Y %I:%M %p")
            obs_str = obs_dt.isoformat()
        except Exception:
            obs_str = now.isoformat()

        seen_ids.add(station["id"])
        results.append(build_record(
            station, current, "WRD_BIHAR_RTDAS", now,
            trend=trend, hfl=hfl_val, obs_time=obs_str,
        ))

    return results


# ─────────────────────────────────────────────────────────────────────────────
# Public API
# ─────────────────────────────────────────────────────────────────────────────
async def scrape_wrd_bihar() -> list:
    """Try befiqr.in + RTDAS; fall back to synthetic per station."""
    now = datetime.utcnow()

    if not _DEPS_OK:
        return [build_record(st, _synthetic_level(st, now), "WRD_BIHAR_SYNTHETIC", now)
                for st in BIHAR_STATIONS]

    befiqr_records  = []
    rtdas_records   = []
    befiqr_seen_ids = set()

    try:
        async with httpx.AsyncClient(
            timeout=httpx.Timeout(15.0),
            headers=HTTP_HEADERS,
            follow_redirects=True,
        ) as client:
            # ── Source 1: befiqr.in (WRD Central Flood Control Cell) ─────────
            try:
                resp = await client.get(BEFIQR_URL)
                if resp.status_code == 200 and "<table" in resp.text.lower():
                    befiqr_records, befiqr_seen_ids = _parse_befiqr(resp.text, now)
            except Exception as e:
                pass  # will fill from RTDAS / synthetic

            # ── Source 2: RTDAS (fill stations not found in befiqr) ───────────
            try:
                resp2 = await client.get(RTDAS_URL)
                if resp2.status_code == 200 and "<table" in resp2.text.lower():
                    rtdas_records = _parse_rtdas(resp2.text, now, befiqr_seen_ids)
            except Exception:
                pass
    except Exception:
        pass

    # ── Merge: live data first, then synthetic for any missing Bihar stations
    all_records = befiqr_records + rtdas_records
    covered_ids = {r["id"] for r in all_records}

    for st in BIHAR_STATIONS:
        if st["id"] not in covered_ids:
            all_records.append(
                build_record(st, _synthetic_level(st, now), "WRD_BIHAR_SYNTHETIC", now)
            )

    return all_records


def get_all_synthetic() -> list:
    """Return synthetic data for all stations (Bihar + national)."""
    now = datetime.utcnow()
    return [
        build_record(st, _synthetic_level(st, now), "SYNTHETIC", now)
        for st in ALL_STATIONS
    ]
