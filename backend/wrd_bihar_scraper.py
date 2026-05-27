"""
wrd_bihar_scraper.py
WRD Bihar Flood Monitoring Scraper
Source: http://fldcontrolbihar.org/ (HTML table scraping)
Fallback: Tactical registry using STATE_SEVERITY_MATRIX thresholds
"""

import requests
from bs4 import BeautifulSoup
import datetime
import logging
from typing import List, Dict, Any, Optional

logger = logging.getLogger("opsflood.wrd_bihar")

# Primary and mirror URLs to try in order
WRD_BIHAR_URLS = [
    "http://fldcontrolbihar.org/",
    "http://fldcontrolbihar.org/index.aspx",
    "http://fldcontrolbihar.org/floodreport.aspx",
]

REQUEST_TIMEOUT = (5, 12)  # (connect_timeout, read_timeout) seconds

# Known Bihar flood monitoring stations with GPS, river, and CWC danger thresholds
BIHAR_STATION_REGISTRY: List[Dict[str, Any]] = [
    {"station": "Gandhi Setu",        "river": "Ganga",        "lat": 25.736, "lon": 85.004, "danger_level": 50.27, "warning_level": 49.27},
    {"station": "Patna (Ganga)",      "river": "Ganga",        "lat": 25.594, "lon": 85.138, "danger_level": 50.27, "warning_level": 49.27},
    {"station": "Hajipur",            "river": "Gandak",       "lat": 25.686, "lon": 85.208, "danger_level": 57.61, "warning_level": 56.61},
    {"station": "Dumariaghat",        "river": "Kosi",         "lat": 26.584, "lon": 86.738, "danger_level": 68.17, "warning_level": 67.17},
    {"station": "Basantpur",          "river": "Burhi Gandak", "lat": 26.133, "lon": 84.367, "danger_level": 56.75, "warning_level": 55.75},
    {"station": "Rosera",             "river": "Burhi Gandak", "lat": 25.866, "lon": 86.011, "danger_level": 44.36, "warning_level": 43.36},
    {"station": "Muzaffarpur",        "river": "Burhi Gandak", "lat": 26.121, "lon": 85.391, "danger_level": 55.75, "warning_level": 54.75},
    {"station": "Sitamarhi",          "river": "Bagmati",      "lat": 26.592, "lon": 85.486, "danger_level": 75.40, "warning_level": 74.40},
    {"station": "Darbhanga",          "river": "Bagmati",      "lat": 26.152, "lon": 85.901, "danger_level": 45.75, "warning_level": 44.75},
    {"station": "Supaul",             "river": "Kosi",         "lat": 26.123, "lon": 86.604, "danger_level": 56.40, "warning_level": 55.40},
    {"station": "Bhagalpur (Ganga)",  "river": "Ganga",        "lat": 25.244, "lon": 87.000, "danger_level": 34.45, "warning_level": 33.45},
    {"station": "Kursela",            "river": "Kosi",         "lat": 25.460, "lon": 87.258, "danger_level": 30.15, "warning_level": 29.15},
]


def _safe_float(value: Any, default: float = 0.0) -> float:
    try:
        if value is None or str(value).strip() in ("", "-", "N/A", "NA", "--"):
            return default
        return float(str(value).strip())
    except (ValueError, TypeError):
        return default


def _status_from_levels(current: float, warning: float, danger: float) -> str:
    if danger > 0 and current >= danger:
        return "CRITICAL"
    if warning > 0 and current >= warning:
        return "WARNING"
    return "NORMAL"


def _normalize(text: str) -> str:
    return str(text or "").strip().lower()


def _match_station(raw_name: str) -> Optional[Dict[str, Any]]:
    """Match a scraped station name against the Bihar station registry."""
    normalized = _normalize(raw_name)
    for entry in BIHAR_STATION_REGISTRY:
        if _normalize(entry["station"]) in normalized or normalized in _normalize(entry["station"]):
            return entry
    return None


class WRDBiharScraper:
    """
    Scrapes live flood monitoring data from WRD Bihar portal.
    Falls back to seeded tactical registry data on network failure.
    Pattern mirrors CWCRiverScraper for consistency.
    """

    HEADERS = {
        "User-Agent": (
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
            "AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36"
        ),
        "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
        "Accept-Language": "en-IN,en;q=0.9",
        "Referer": "http://fldcontrolbihar.org/",
    }

    def __init__(self):
        self._last_error: str = ""
        self._retry_after: Optional[datetime.datetime] = None

    def _is_in_cooldown(self) -> bool:
        return bool(self._retry_after and datetime.datetime.now() < self._retry_after)

    def _set_cooldown(self, seconds: int, error: str):
        self._last_error = error
        self._retry_after = datetime.datetime.now() + datetime.timedelta(seconds=seconds)
        logger.warning(f"WRD Bihar scraper cooldown {seconds}s: {error}")

    def _clear_cooldown(self):
        self._retry_after = None
        self._last_error = ""

    def _parse_table(self, html: str) -> List[Dict[str, Any]]:
        """
        Parse flood monitoring HTML table from WRD Bihar page.
        Dynamically detects column positions to handle layout changes.
        Expected columns: Station | River | Observed Level | Danger Level | Status
        """
        soup = BeautifulSoup(html, "html.parser")
        results: List[Dict[str, Any]] = []

        tables = soup.find_all("table")
        if not tables:
            logger.warning("WRD Bihar: No <table> found in page HTML")
            return results

        for table in tables:
            headers = [th.get_text(strip=True).lower() for th in table.find_all("th")]

            # Detect column positions dynamically
            col_station  = next((i for i, h in enumerate(headers) if "station" in h or "gauge" in h or "site" in h), 0)
            col_river    = next((i for i, h in enumerate(headers) if "river" in h or "stream" in h), 1)
            col_obs      = next((i for i, h in enumerate(headers) if "observ" in h or "current" in h or "w.l" in h or "water level" in h), 2)
            col_danger   = next((i for i, h in enumerate(headers) if "danger" in h or "d.l" in h), 3)
            col_warning  = next((i for i, h in enumerate(headers) if "warning" in h), -1)
            col_status   = next((i for i, h in enumerate(headers) if "status" in h or "remark" in h or "situation" in h), -1)

            rows = table.find_all("tr")
            for row in rows[1:]:  # skip header row
                cells = row.find_all(["td", "th"])
                if len(cells) < 3:
                    continue

                def cell_text(idx: int) -> str:
                    if idx < 0 or idx >= len(cells):
                        return ""
                    return cells[idx].get_text(strip=True)

                raw_station = cell_text(col_station)
                if not raw_station or raw_station.lower() in ("s.no", "sr", "no.", "#", "sl"):
                    continue

                raw_river     = cell_text(col_river)
                obs_level     = _safe_float(cell_text(col_obs))
                danger_level  = _safe_float(cell_text(col_danger))
                warning_level = _safe_float(cell_text(col_warning)) if col_warning >= 0 else max(danger_level - 1.0, 0.0)
                raw_status    = cell_text(col_status)

                # Enrich from registry if possible
                matched       = _match_station(raw_station)
                station_name  = matched["station"] if matched else raw_station
                river_name    = matched["river"]    if matched else (raw_river or "Bihar River")
                lat           = matched["lat"]      if matched else 25.594
                lon           = matched["lon"]      if matched else 85.138

                if danger_level == 0.0 and matched:
                    danger_level  = matched["danger_level"]
                if warning_level == 0.0 and matched:
                    warning_level = matched["warning_level"]

                # Derive status
                if raw_status and raw_status.lower() not in ("", "-"):
                    rs = raw_status.lower()
                    if "critical" in rs or "danger" in rs or "above" in rs:
                        status = "CRITICAL"
                    elif "warn" in rs or "alert" in rs:
                        status = "WARNING"
                    else:
                        status = "NORMAL"
                else:
                    status = _status_from_levels(obs_level, warning_level, danger_level)

                results.append({
                    "station":           station_name,
                    "river":             river_name,
                    "state":             "Bihar",
                    "state_name":        "Bihar",
                    "river_level":       round(obs_level, 2),
                    "danger_level":      round(danger_level, 2),
                    "warning_level":     round(warning_level, 2),
                    "status":            status,
                    "trend":             "STEADY",
                    "flow_rate":         0.0,
                    "rainfall_last_hour": 0.0,
                    "lat":               lat,
                    "lon":               lon,
                    "source":            "WRD_BIHAR",
                    "last_update":       datetime.datetime.now().isoformat(),
                    "raw_status_text":   raw_status,
                })

            if results:
                break  # stop after first table that yielded data

        return results

    def _fetch_from_portal(self) -> List[Dict[str, Any]]:
        """Try each WRD Bihar URL and parse the flood table."""
        for url in WRD_BIHAR_URLS:
            try:
                resp = requests.get(url, headers=self.HEADERS, timeout=REQUEST_TIMEOUT)
                resp.raise_for_status()
                data = self._parse_table(resp.text)
                if data:
                    logger.info(f"WRD Bihar: fetched {len(data)} stations from {url}")
                    self._clear_cooldown()
                    return data
                logger.warning(f"WRD Bihar: no data parsed from {url}")
            except requests.ConnectTimeout:
                logger.warning(f"WRD Bihar: connect timeout {url}")
            except requests.ReadTimeout:
                logger.warning(f"WRD Bihar: read timeout {url}")
            except requests.RequestException as exc:
                logger.warning(f"WRD Bihar: request error {url}: {exc}")

        raise RuntimeError("All WRD Bihar portal URLs failed or returned no parseable flood data")

    def _build_tactical_fallback(self, station_filter: Optional[str] = None) -> List[Dict[str, Any]]:
        """Return seeded tactical data from registry when portal is unreachable."""
        import hashlib

        def seeded(seed: str) -> float:
            digest = hashlib.sha256(seed.encode()).digest()
            return int.from_bytes(digest[:8], "big") / float((1 << 64) - 1)

        time_bucket = int(datetime.datetime.now().timestamp() // 1800)
        results = []

        for entry in BIHAR_STATION_REGISTRY:
            sname = entry["station"]
            if station_filter and station_filter.lower() not in sname.lower():
                continue

            seed = f"bihar|{sname.lower()}|{time_bucket}"
            wl   = entry["warning_level"]
            dl   = entry["danger_level"]

            threat = seeded(f"{seed}|threat")
            if threat > 0.80:
                level = round(dl + seeded(f"{seed}|crit") * 0.5, 2)
            elif threat > 0.55:
                level = round(wl + seeded(f"{seed}|warn") * (dl - wl), 2)
            else:
                level = round(wl - (0.5 + seeded(f"{seed}|safe") * 1.5), 2)

            status  = _status_from_levels(level, wl, dl)
            trend_r = seeded(f"{seed}|trend")
            trend   = "RISING" if trend_r > 0.66 else "FALLING" if trend_r > 0.33 else "STEADY"

            results.append({
                "station":            sname,
                "river":              entry["river"],
                "state":              "Bihar",
                "state_name":         "Bihar",
                "river_level":        level,
                "danger_level":       round(dl, 2),
                "warning_level":      round(wl, 2),
                "status":             status,
                "trend":              trend,
                "flow_rate":          round(level * (10 + seeded(f"{seed}|flow") * 5), 1),
                "rainfall_last_hour": round(seeded(f"{seed}|rain") * 15, 1),
                "lat":                entry["lat"],
                "lon":                entry["lon"],
                "source":             "TACTICAL_REGISTRY",
                "last_update":        datetime.datetime.now().isoformat(),
                "raw_status_text":    "",
            })

        return results

    def get_live_stations(
        self,
        station_filter: Optional[str] = None,
        limit: int = 20,
    ) -> Dict[str, Any]:
        """
        Main public method.
        Returns live WRD Bihar data or transparent tactical fallback.
        """
        if self._is_in_cooldown():
            return self._fallback_response(station_filter, limit, reason=self._last_error)

        try:
            stations = self._fetch_from_portal()

            if station_filter:
                filtered = [s for s in stations if station_filter.lower() in s["station"].lower()]
                stations  = filtered if filtered else stations

            return {
                "status":        "LIVE",
                "data_source":   "WRD_BIHAR",
                "portal_url":    WRD_BIHAR_URLS[0],
                "state":         "Bihar",
                "station_count": len(stations[:limit]),
                "timestamp":     datetime.datetime.now().isoformat(),
                "data":          stations[:limit],
            }

        except Exception as exc:
            self._set_cooldown(300, str(exc))
            return self._fallback_response(station_filter, limit, reason=str(exc))

    def _fallback_response(
        self,
        station_filter: Optional[str],
        limit: int,
        reason: str = "",
    ) -> Dict[str, Any]:
        fallback = self._build_tactical_fallback(station_filter)
        return {
            "status":        "FALLBACK",
            "data_source":   "TACTICAL_REGISTRY",
            "portal_url":    WRD_BIHAR_URLS[0],
            "state":         "Bihar",
            "error":         reason or "WRD Bihar portal unreachable",
            "station_count": len(fallback[:limit]),
            "timestamp":     datetime.datetime.now().isoformat(),
            "data":          fallback[:limit],
        }


# Module-level singleton — imported by app.py and routers/wrd_bihar.py
wrd_bihar_scraper = WRDBiharScraper()
