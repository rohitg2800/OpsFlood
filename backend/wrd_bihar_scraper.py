"""
backend/wrd_bihar_scraper.py
OpsFlood — Live Gauge Scraper v6

Primary sources (Bihar):
  1. irrigation.befiqr.in/state/table/rivers
     → WRD Bihar Central Flood Control Cell — 31 sites, updated hourly
  2. irrigation.fmiscwrdbihar.gov.in/state/table/rtdas-stations
     → WRD Bihar RTDAS telemetry — 25 sites, updated every 15 min

31 Bihar gauges across 10 rivers (matches lib/data/bihar_rivers.dart exactly).
National synthetic fallback for non-Bihar stations.
Full synthetic fallback for Bihar when both live sources are unreachable.

Alert generation: any station with current_level >= danger_level emits
  status='danger', risk_level='CRITICAL', and appears in /api/alerts/danger.
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
# Bihar station master — 31 gauges across 10 rivers
# Sources: WRD Bihar Central Flood Control Cell + CWC FFS (2024-25)
# All levels in metres above mean sea level (m MSL)
# ─────────────────────────────────────────────────────────────────────────────
BIHAR_STATIONS = [
    # ── 1. GANGA (7 stations) ─────────────────────────────────────────────────
    {"id":"GN01","name":"Gandhighat","aliases":["gandhighat","gandhi ghat","patna cwc"],
     "river":"Ganga","district":"Patna","state":"Bihar",
     "lat":25.6129,"lon":85.1376,"danger":48.60,"warning":47.50,"low":44.0,"hfl":50.52},
    {"id":"GN02","name":"Dighaghat","aliases":["dighaghat","digha ghat","patna"],
     "river":"Ganga","district":"Patna","state":"Bihar",
     "lat":25.5941,"lon":85.0700,"danger":50.45,"warning":49.30,"low":45.0,"hfl":52.52},
    {"id":"GN03","name":"Hathidah","aliases":["hathidah","mokameh"],
     "river":"Ganga","district":"Patna","state":"Bihar",
     "lat":25.4167,"lon":85.7500,"danger":41.76,"warning":40.50,"low":36.0,"hfl":43.52},
    {"id":"GN04","name":"Munger","aliases":["munger"],
     "river":"Ganga","district":"Munger","state":"Bihar",
     "lat":25.3743,"lon":86.4730,"danger":39.33,"warning":38.20,"low":33.0,"hfl":40.99},
    {"id":"GN05","name":"Kahalgaon","aliases":["kahalgaon"],
     "river":"Ganga","district":"Bhagalpur","state":"Bihar",
     "lat":25.2167,"lon":87.2667,"danger":31.09,"warning":30.00,"low":25.0,"hfl":32.87},
    {"id":"GN06","name":"Bhagalpur","aliases":["bhagalpur"],
     "river":"Ganga","district":"Bhagalpur","state":"Bihar",
     "lat":25.2425,"lon":86.9842,"danger":33.68,"warning":32.50,"low":27.0,"hfl":34.86},
    {"id":"GN07","name":"Buxar","aliases":["buxar"],
     "river":"Ganga","district":"Buxar","state":"Bihar",
     "lat":25.5667,"lon":83.9667,"danger":60.30,"warning":59.20,"low":53.0,"hfl":62.10},

    # ── 2. KOSI (4 stations) ──────────────────────────────────────────────────
    {"id":"KS01","name":"Birpur","aliases":["birpur","birpur cwc","kosi barrage","supaul entry"],
     "river":"Kosi","district":"Supaul","state":"Bihar",
     "lat":26.5167,"lon":86.9000,"danger":74.70,"warning":73.70,"low":68.0,"hfl":76.02},
    {"id":"KS02","name":"Basua","aliases":["basua","supaul","kosi supaul"],
     "river":"Kosi","district":"Supaul","state":"Bihar",
     "lat":26.1234,"lon":86.6020,"danger":47.75,"warning":46.50,"low":41.0,"hfl":49.24},
    {"id":"KS03","name":"Baltara","aliases":["baltara","khagaria kosi"],
     "river":"Kosi","district":"Khagaria","state":"Bihar",
     "lat":25.5000,"lon":86.5833,"danger":33.85,"warning":32.85,"low":28.0,"hfl":36.40},
    {"id":"KS04","name":"Kursela","aliases":["kursela","katihar","kosi confluence"],
     "river":"Kosi","district":"Katihar","state":"Bihar",
     "lat":25.4800,"lon":87.2600,"danger":30.00,"warning":28.80,"low":24.0,"hfl":32.10},

    # ── 3. GANDAK (4 stations) ────────────────────────────────────────────────
    {"id":"GK01","name":"Chatia","aliases":["chatia","bettiah","east champaran"],
     "river":"Gandak","district":"East Champaran","state":"Bihar",
     "lat":26.8500,"lon":84.9000,"danger":69.15,"warning":68.10,"low":63.0,"hfl":70.04},
    {"id":"GK02","name":"Dumariaghat","aliases":["dumariaghat","gopalganj","gandak gopalganj"],
     "river":"Gandak","district":"Gopalganj","state":"Bihar",
     "lat":26.4833,"lon":84.4667,"danger":62.22,"warning":61.10,"low":55.0,"hfl":63.70},
    {"id":"GK03","name":"Rewaghat","aliases":["rewaghat","muzaffarpur gandak"],
     "river":"Gandak","district":"Muzaffarpur","state":"Bihar",
     "lat":26.1000,"lon":85.3000,"danger":54.41,"warning":53.40,"low":47.0,"hfl":55.46},
    {"id":"GK04","name":"Hajipur","aliases":["hajipur","vaishali","gandak hajipur"],
     "river":"Gandak","district":"Vaishali","state":"Bihar",
     "lat":25.6933,"lon":85.2094,"danger":50.32,"warning":49.40,"low":43.0,"hfl":50.93},

    # ── 4. BAGMATI (3 stations) ───────────────────────────────────────────────
    {"id":"BG01","name":"Dheng Bridge","aliases":["dheng bridge","dheng","sitamarhi","bagmati entry"],
     "river":"Bagmati","district":"Sitamarhi","state":"Bihar",
     "lat":26.5800,"lon":85.4900,"danger":71.00,"warning":70.00,"low":65.0,"hfl":73.47},
    {"id":"BG02","name":"Benibad","aliases":["benibad","muzaffarpur bagmati"],
     "river":"Bagmati","district":"Muzaffarpur","state":"Bihar",
     "lat":26.0500,"lon":85.6500,"danger":48.68,"warning":47.68,"low":42.0,"hfl":50.01},
    {"id":"BG03","name":"Hayaghat","aliases":["hayaghat","darbhanga bagmati"],
     "river":"Bagmati","district":"Darbhanga","state":"Bihar",
     "lat":26.0200,"lon":85.9500,"danger":45.72,"warning":44.50,"low":39.0,"hfl":48.96},

    # ── 5. BURHI GANDAK (4 stations) ─────────────────────────────────────────
    {"id":"BK01","name":"Sikandarpur","aliases":["sikandarpur","muzaffarpur burhi"],
     "river":"Burhi Gandak","district":"Muzaffarpur","state":"Bihar",
     "lat":26.1209,"lon":85.3647,"danger":52.53,"warning":51.40,"low":45.0,"hfl":54.29},
    {"id":"BK02","name":"Samastipur","aliases":["samastipur"],
     "river":"Burhi Gandak","district":"Samastipur","state":"Bihar",
     "lat":25.8620,"lon":85.7812,"danger":46.00,"warning":44.80,"low":39.0,"hfl":49.40},
    {"id":"BK03","name":"Rosera","aliases":["rosera"],
     "river":"Burhi Gandak","district":"Samastipur","state":"Bihar",
     "lat":25.8600,"lon":85.9800,"danger":42.63,"warning":41.50,"low":36.0,"hfl":46.56},
    {"id":"BK04","name":"Khagaria","aliases":["khagaria","burhi gandak khagaria"],
     "river":"Burhi Gandak","district":"Khagaria","state":"Bihar",
     "lat":25.5000,"lon":86.4700,"danger":36.58,"warning":35.40,"low":29.0,"hfl":39.22},

    # ── 6. GHAGHRA / SARYU (2 stations) ──────────────────────────────────────
    {"id":"GH01","name":"Darauli","aliases":["darauli","siwan","ghaghra siwan"],
     "river":"Ghaghra","district":"Siwan","state":"Bihar",
     "lat":25.9500,"lon":84.1500,"danger":60.82,"warning":59.80,"low":54.0,"hfl":61.82},
    {"id":"GH02","name":"Gangpur Siswan","aliases":["gangpur siswan","gangpur","siswan"],
     "river":"Ghaghra","district":"Siwan","state":"Bihar",
     "lat":26.0500,"lon":84.4000,"danger":57.04,"warning":56.00,"low":50.0,"hfl":58.01},

    # ── 7. MAHANANDA (2 stations) ─────────────────────────────────────────────
    {"id":"MN01","name":"Dhengraghat","aliases":["dhengraghat","purnea","mahananda purnea"],
     "river":"Mahananda","district":"Purnea","state":"Bihar",
     "lat":25.7800,"lon":87.4800,"danger":35.65,"warning":34.65,"low":29.0,"hfl":38.20},
    {"id":"MN02","name":"Taibpur","aliases":["taibpur","kishanganj","mahananda kishanganj"],
     "river":"Mahananda","district":"Kishanganj","state":"Bihar",
     "lat":26.5800,"lon":87.9500,"danger":66.00,"warning":64.80,"low":59.0,"hfl":67.22},

    # ── 8. KAMLA-BALAN (2 stations) ───────────────────────────────────────────
    {"id":"KM01","name":"Jainagar","aliases":["jainagar","madhubani","kamla entry"],
     "river":"Kamla","district":"Madhubani","state":"Bihar",
     "lat":26.6000,"lon":86.2700,"danger":67.75,"warning":66.00,"low":60.0,"hfl":71.35},
    {"id":"KM02","name":"Jhanjharpur","aliases":["jhanjharpur","kamalabalan","kamla balan"],
     "river":"Kamla Balan","district":"Madhubani","state":"Bihar",
     "lat":26.2700,"lon":86.2800,"danger":50.00,"warning":48.80,"low":43.0,"hfl":53.11},

    # ── 9. ADHWARA GROUP (3 stations) ─────────────────────────────────────────
    {"id":"AW01","name":"Sonbarsa","aliases":["sonbarsa","sitamarhi adhwara"],
     "river":"Adhwara","district":"Sitamarhi","state":"Bihar",
     "lat":26.6500,"lon":85.5500,"danger":81.85,"warning":80.70,"low":75.0,"hfl":83.20},
    {"id":"AW02","name":"Kamtaul","aliases":["kamtaul","darbhanga adhwara"],
     "river":"Adhwara","district":"Darbhanga","state":"Bihar",
     "lat":26.2200,"lon":85.8500,"danger":50.00,"warning":49.00,"low":43.0,"hfl":52.99},
    {"id":"AW03","name":"Ekmighat","aliases":["ekmighat","ekmi ghat"],
     "river":"Adhwara","district":"Darbhanga","state":"Bihar",
     "lat":26.1500,"lon":86.0000,"danger":46.94,"warning":45.80,"low":40.0,"hfl":49.52},

    # ── 10. PUNPUN (1 station) ────────────────────────────────────────────────
    {"id":"PP01","name":"Sripalpur","aliases":["sripalpur","punpun","phulwari"],
     "river":"Punpun","district":"Patna","state":"Bihar",
     "lat":25.4833,"lon":85.1333,"danger":50.60,"warning":49.50,"low":43.0,"hfl":53.91},
]

# ─────────────────────────────────────────────────────────────────────────────
# National stations (synthetic only — no live source yet)
# ─────────────────────────────────────────────────────────────────────────────
NATIONAL_STATIONS = [
    {"id":"MH_PUN","name":"Pune",      "aliases":["pune"],"river":"Mula-Mutha",  "district":"Pune",       "state":"Maharashtra",   "lat":18.52,"lon":73.86,"danger":25.0, "warning":23.0, "low":18.0,"hfl":28.0},
    {"id":"MH_MUM","name":"Mumbai",    "aliases":["mumbai"],"river":"Mithi",    "district":"Mumbai",     "state":"Maharashtra",   "lat":19.08,"lon":72.88,"danger":5.0,  "warning":4.0,  "low":2.0,"hfl":6.5},
    {"id":"UP_VAR","name":"Varanasi",  "aliases":["varanasi"],"river":"Ganga",  "district":"Varanasi",  "state":"Uttar Pradesh", "lat":25.32,"lon":82.97,"danger":71.26,"warning":70.26,"low":66.0,"hfl":73.0},
    {"id":"AS_GUW","name":"Guwahati",  "aliases":["guwahati"],"river":"Brahmaputra","district":"Kamrup","state":"Assam",         "lat":26.14,"lon":91.74,"danger":49.68,"warning":48.68,"low":44.0,"hfl":51.0},
    {"id":"KE_KOC","name":"Kochi",     "aliases":["kochi"],"river":"Periyar",  "district":"Ernakulam", "state":"Kerala",        "lat":9.93, "lon":76.27,"danger":7.0,  "warning":6.0,  "low":3.0,"hfl":8.5},
    {"id":"WB_KOL","name":"Kolkata",   "aliases":["kolkata"],"river":"Hooghly", "district":"Kolkata",  "state":"West Bengal",   "lat":22.57,"lon":88.36,"danger":5.5,  "warning":4.5,  "low":2.0,"hfl":7.0},
    {"id":"OD_CUT","name":"Cuttack",   "aliases":["cuttack"],"river":"Mahanadi","district":"Cuttack",  "state":"Odisha",        "lat":20.46,"lon":85.88,"danger":22.0, "warning":20.5, "low":16.0,"hfl":25.0},
    {"id":"HP_HAR","name":"Haridwar",  "aliases":["haridwar"],"river":"Ganga",  "district":"Haridwar",  "state":"Uttarakhand",   "lat":29.94,"lon":78.16,"danger":294.0,"warning":293.0,"low":289.0,"hfl":296.0},
    {"id":"UP_GOR","name":"Gorakhpur", "aliases":["gorakhpur"],"river":"Rapti", "district":"Gorakhpur","state":"Uttar Pradesh", "lat":26.76,"lon":83.37,"danger":84.0, "warning":83.0, "low":79.0,"hfl":86.0},
    {"id":"AS_DHU","name":"Dhubri",    "aliases":["dhubri"],"river":"Brahmaputra","district":"Dhubri",  "state":"Assam",         "lat":26.02,"lon":89.98,"danger":30.30,"warning":29.30,"low":25.0,"hfl":32.0},
    {"id":"WB_JAL","name":"Jalpaiguri","aliases":["jalpaiguri"],"river":"Teesta","district":"Jalpaiguri","state":"West Bengal", "lat":26.54,"lon":88.72,"danger":82.60,"warning":81.60,"low":77.0,"hfl":85.0},
]

ALL_STATIONS = BIHAR_STATIONS + NATIONAL_STATIONS

# Live source URLs
BEFIQR_URL  = "https://irrigation.befiqr.in/state/table/rivers"
RTDAS_URL   = "https://irrigation.fmiscwrdbihar.gov.in/state/table/rtdas-stations?platform=mobileapp&hide=hamburger"
HTTP_HEADERS = {
    "User-Agent": "Mozilla/5.0 (compatible; OpsFlood/3.0; flood monitoring)",
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
    hfl_val  = hfl or station.get("hfl") or round(danger * 1.12, 2)
    resolved_trend = trend or _trend_synthetic(current, station, now)

    # Danger alert fields
    above_danger = round(current - danger, 2) if status == "danger" else 0.0

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
        # alert fields
        "above_danger_m":   above_danger,
        "alert_active":     status == "danger",
    }


# ─────────────────────────────────────────────────────────────────────────────
# Station matcher — fuzzy match site name → BIHAR_STATIONS entry
# ─────────────────────────────────────────────────────────────────────────────
def _match_station(site_name: str) -> Optional[dict]:
    needle = site_name.lower().strip()
    for st in BIHAR_STATIONS:
        if any(alias in needle or needle in alias for alias in st["aliases"]):
            return st
    first_word = needle.split()[0] if needle else ""
    for st in BIHAR_STATIONS:
        if first_word and any(first_word in alias for alias in st["aliases"]):
            return st
    return None


def _parse_float(s: str) -> Optional[float]:
    cleaned = re.sub(r"[^\d.+-]", "", s.strip())
    if not cleaned or cleaned in ("-", "+", "."):
        return None
    try:
        return float(cleaned)
    except ValueError:
        return None


# ─────────────────────────────────────────────────────────────────────────────
# Parser 1 — befiqr.in  (WRD Bihar Central Flood Control Cell)
# ─────────────────────────────────────────────────────────────────────────────
def _parse_befiqr(html: str, now: datetime) -> list:
    soup = BeautifulSoup(html, "html.parser")
    rows = soup.select("table tr")
    results = []
    seen_ids = set()

    for row in rows[1:]:
        cols = [td.get_text(strip=True) for td in row.find_all(["td", "th"])]
        if len(cols) < 7:
            continue
        site_name = re.sub(r"[*\[\]]", "", cols[2]).strip() if len(cols) > 2 else ""
        if not site_name or site_name.upper() in ("SITE", "(3)"):
            continue

        station = _match_station(site_name)
        if not station or station["id"] in seen_ids:
            continue

        current = _parse_float(cols[6]) if len(cols) > 6 else None
        if current is None or current <= 0:
            current = _parse_float(cols[5]) if len(cols) > 5 else None
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
            try:
                resp = await client.get(BEFIQR_URL)
                if resp.status_code == 200 and "<table" in resp.text.lower():
                    befiqr_records, befiqr_seen_ids = _parse_befiqr(resp.text, now)
            except Exception:
                pass

            try:
                resp2 = await client.get(RTDAS_URL)
                if resp2.status_code == 200 and "<table" in resp2.text.lower():
                    rtdas_records = _parse_rtdas(resp2.text, now, befiqr_seen_ids)
            except Exception:
                pass
    except Exception:
        pass

    all_records = befiqr_records + rtdas_records
    covered_ids = {r["id"] for r in all_records}

    # Fill any missing Bihar stations with synthetic data
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


# ─────────────────────────────────────────────────────────────────────────────
# Alert helpers
# ─────────────────────────────────────────────────────────────────────────────
def build_danger_alerts(data: list) -> list:
    """
    From a list of station records, return only those at danger level
    with enriched alert metadata, sorted by severity (most above danger first).
    """
    alerts = []
    for d in data:
        if d.get("status") == "danger":
            above = d.get("above_danger_m", 0.0)
            alerts.append({
                **d,
                "alert_type":     "DANGER",
                "alert_level":    "CRITICAL" if above >= 1.0 else "HIGH",
                "severity_score": round(above / max(d.get("hfl", d["danger_level"]) - d["danger_level"], 0.01) * 100, 1),
                "message":        (
                    f"{d['name']} ({d['river']}, {d['district']}) is {above:.2f}m "
                    f"ABOVE danger level {d['danger_level']}m. "
                    f"Current: {d['current_level']}m. Trend: {d.get('trend','stable')}."
                ),
                "action":         "EVACUATE" if above >= 1.5 else ("WARN" if above >= 0.5 else "MONITOR"),
            })
    alerts.sort(key=lambda x: x["above_danger_m"], reverse=True)
    return alerts
