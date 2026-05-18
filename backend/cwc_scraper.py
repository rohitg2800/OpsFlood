"""
CWC River Level Scraper for OpsFlood Backend

This module handles live data acquisition from the Central Water Commission (CWC)
with graceful fallbacks to tactical/synthetic telemetry when APIs are unavailable.
"""

import os
import datetime
import requests
from bs4 import BeautifulSoup
from typing import Dict, Any

try:
    from backend.state_severity_matrix import get_state_severity_entry
except ImportError:
    from state_severity_matrix import get_state_severity_entry


class CWCRiverScraper:
    """
    Scrapes live river level data from CWC (Central Water Commission) APIs.
    
    Includes tactical fallback for simulated data when live endpoints are unavailable.
    Features:
    - Resilient multi-endpoint retry logic
    - Cooldown-based rate limiting on repeated failures
    - Tactical telemetry generation with seeded synthetic data
    - Station-based priority ranking for multi-site responses
    """

    def __init__(self):
        self.headers = {
            "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
            "Accept": "application/json, text/plain, */*",
            "Referer": "https://ffs.india-water.gov.in/"
        }
        self.cwc_api_base = "https://ffs.india-water.gov.in/iam/api"
        self.connect_timeout_seconds = max(1.0, float(os.getenv("CWC_CONNECT_TIMEOUT_SECONDS") or 3))
        self.read_timeout_seconds = max(1.0, float(os.getenv("CWC_READ_TIMEOUT_SECONDS") or 8))
        self._station_feed_retry_after: datetime.datetime | None = None
        self._station_feed_failure_message: str = ""
        self._last_telemetry_error_log_at: datetime.datetime | None = None
        self._last_telemetry_error_message: str = ""

    def _remember_station_feed_failure(self, message: str, cooldown_seconds: int):
        """Remember a failure and when to retry."""
        self._station_feed_failure_message = message
        self._station_feed_retry_after = datetime.datetime.now() + datetime.timedelta(seconds=max(30, cooldown_seconds))

    def _clear_station_feed_failure(self):
        """Clear failure state."""
        self._station_feed_retry_after = None
        self._station_feed_failure_message = ""

    def _log_telemetry_error(self, message: str):
        """Log telemetry errors with deduplication (300s window)."""
        now = datetime.datetime.now()
        if (
            self._last_telemetry_error_message == message
            and self._last_telemetry_error_log_at
            and (now - self._last_telemetry_error_log_at).total_seconds() < 300
        ):
            return

        self._last_telemetry_error_message = message
        self._last_telemetry_error_log_at = now
        print(f"❌ CWC Telemetry Error: {message}")

    def _safe_float(self, value, default=0.0):
        """Safely convert value to float."""
        try:
            if value is None or value == "":
                return float(default)
            return float(value)
        except (TypeError, ValueError):
            return float(default)

    def _normalize_key(self, value: str | None) -> str:
        """Normalize state/station names for comparison."""
        key = (value or "").strip().lower()
        key = " ".join(key.split())
        if key == "orissa":
            return "odisha"
        if key in {"nct of delhi", "new delhi"}:
            return "delhi"
        if key == "uttaranchal":
            return "uttarakhand"
        return key

    def _hash_value(self, input_value: str) -> int:
        """Generate deterministic hash for seeding."""
        hash_value = 0
        for char in input_value:
            hash_value = (hash_value << 5) - hash_value + ord(char)
            hash_value |= 0
        return abs(hash_value)

    def _seeded_unit(self, seed: str) -> float:
        """Generate deterministic pseudo-random value in [0, 1)."""
        return (self._hash_value(seed) % 1000) / 1000

    def _status_from_levels(self, current_level: float, warning_level: float, danger_level: float) -> str:
        """Derive status from current level relative to warning/danger thresholds."""
        if danger_level > 0 and current_level >= danger_level:
            return "CRITICAL"
        if warning_level > 0 and current_level >= warning_level:
            return "WARNING"
        return "ACTIVE"

    def _build_update_time(self, offset_ms: float) -> str:
        """Build ISO timestamp with historical offset."""
        timestamp = datetime.datetime.now() - datetime.timedelta(milliseconds=float(offset_ms))
        return timestamp.isoformat()

    def _format_request_error(self, exc: requests.RequestException) -> str:
        """Format request exception into user-friendly message."""
        if isinstance(exc, requests.ConnectTimeout):
            return "connect timeout"
        if isinstance(exc, requests.ReadTimeout):
            return "read timeout"
        if isinstance(exc, requests.SSLError):
            return "tls error"
        if isinstance(exc, requests.ConnectionError):
            return "connection error"

        compact = " ".join(str(exc).split())
        if len(compact) > 180:
            compact = f"{compact[:177]}..."
        return f"{exc.__class__.__name__}: {compact}"

    def _build_tactical_station_profiles(self, state_name: str, station_name: str):
        """Build tactical station profiles based on state severity matrix."""
        state_entry = get_state_severity_entry(state_name)
        clean_state = (state_name or "Active Region").strip() or "Active Region"
        preferred_station = (station_name or "").strip() or f"{clean_state} Central Gauge"
        danger_level = float(state_entry["danger_level_m"])
        primary_warning = round(max(danger_level - 1.4, danger_level * 0.86), 2)
        secondary_danger = round(max(danger_level - 0.4, primary_warning + 0.7), 2)
        secondary_warning = round(max(primary_warning - 0.6, 0.6), 2)
        tertiary_danger = round(max(danger_level - 1.1, secondary_warning + 0.8), 2)
        tertiary_warning = round(max(primary_warning - 1.2, 0.5), 2)

        return [
            {
                "station": preferred_station,
                "river": f"{clean_state} Primary Basin",
                "warning_level": primary_warning,
                "danger_level": round(danger_level, 2),
            },
            {
                "station": f"{clean_state} Downstream Sector",
                "river": f"{clean_state} Downstream Reach",
                "warning_level": secondary_warning,
                "danger_level": secondary_danger,
            },
            {
                "station": f"{clean_state} Catchment Control",
                "river": f"{clean_state} Catchment Basin",
                "warning_level": tertiary_warning,
                "danger_level": tertiary_danger,
            },
        ]

    def _build_tactical_telemetry(self, state_name="Maharashtra", station_name="Kolhapur", limit=6):
        """Generate synthetic tactical telemetry with seeded randomness."""
        profiles = self._build_tactical_station_profiles(state_name, station_name)
        state_key = self._normalize_key(state_name) or "active-region"
        station_key = self._normalize_key(station_name)
        time_bucket = int(datetime.datetime.now().timestamp() // (30 * 60))
        telemetry = []

        for index, profile in enumerate(profiles[: max(1, limit)]):
            seed = f"{state_key}|{self._normalize_key(profile['station'])}|{time_bucket}|{index}"
            threat = self._seeded_unit(f"{seed}|threat")
            warning_level = float(profile["warning_level"])
            danger_level = float(profile["danger_level"])

            current_level = warning_level - (0.45 + self._seeded_unit(f"{seed}|safe") * 1.55)
            if threat > 0.84:
                current_level = danger_level + self._seeded_unit(f"{seed}|critical") * 0.45
            elif threat > 0.58:
                current_level = warning_level + self._seeded_unit(f"{seed}|warning") * max(danger_level - warning_level, 0.6)

            current_level = round(current_level, 2)
            rainfall_last_hour = round(self._seeded_unit(f"{seed}|rain") * 18, 1)
            trend_roll = self._seeded_unit(f"{seed}|trend")
            trend = "RISING" if trend_roll > 0.66 else "FALLING" if trend_roll > 0.33 else "STEADY"

            telemetry.append({
                "station": profile["station"],
                "state_name": state_name,
                "state": state_name,
                "river": profile["river"],
                "river_level": current_level,
                "danger_level": danger_level,
                "warning_level": warning_level,
                "flow_rate": round(max(current_level, 0.0) * (10.8 + self._seeded_unit(f"{seed}|flow") * 4.4), 1),
                "rainfall_last_hour": rainfall_last_hour,
                "status": self._status_from_levels(current_level, warning_level, danger_level),
                "trend": trend,
                "source": "TACTICAL_REGISTRY",
                "last_update": self._build_update_time(self._seeded_unit(f"{seed}|time") * 55 * 60 * 1000),
            })

        if station_key:
            telemetry.sort(
                key=lambda site: (
                    0 if station_key in self._normalize_key(site["station"]) or station_key in self._normalize_key(site["river"]) else 1,
                    -float(site["river_level"]),
                )
            )

        return telemetry

    def _fetch_live_station_feed(self):
        """Fetch live station feed from CWC API with retry logic."""
        if self._station_feed_retry_after and datetime.datetime.now() < self._station_feed_retry_after:
            raise RuntimeError(self._station_feed_failure_message or "CWC live telemetry endpoints are temporarily unavailable.")

        candidate_paths = [
            "/new-warning-station",
            "/warning-station",
        ]
        failures = []
        host_connect_timeout = False

        for path in candidate_paths:
            try:
                response = requests.get(
                    f"{self.cwc_api_base}{path}",
                    headers=self.headers,
                    timeout=(self.connect_timeout_seconds, self.read_timeout_seconds),
                )
                if response.status_code == 404:
                    failures.append(f"{path}: 404")
                    continue

                response.raise_for_status()
                payload = response.json()
                if isinstance(payload, list):
                    self._clear_station_feed_failure()
                    return path, payload

                failures.append(f"{path}: unexpected payload {type(payload).__name__}")
            except requests.ConnectTimeout:
                failures.append(f"{path}: connect timeout")
                host_connect_timeout = True
                break
            except requests.RequestException as exc:
                failures.append(f"{path}: {self._format_request_error(exc)}")
            except Exception as exc:
                failures.append(f"{path}: unexpected {exc.__class__.__name__}")

        failure_summary = " ; ".join(failures)
        if host_connect_timeout:
            cooldown_seconds = 300
        else:
            cooldown_seconds = 900 if failures and all(": 404" in failure for failure in failures) else 180
        self._remember_station_feed_failure(failure_summary, cooldown_seconds)
        raise RuntimeError(failure_summary)

    def _site_priority(self, site: Dict[str, Any], target_state: str, target_station: str) -> int:
        """Rank site priority for station/state matching."""
        station_match = bool(target_station) and (
            target_station in self._normalize_key(site.get("station"))
            or target_station in self._normalize_key(site.get("river"))
        )
        state_match = bool(target_state) and target_state in self._normalize_key(site.get("state_name"))

        if station_match and state_match:
            return 0
        if station_match:
            return 1
        if state_match:
            return 2
        return 3

    def get_live_river_level(self, station_name="Kolhapur"):
        """Get current river level for a specific station."""
        print(f"📡 Initiating secure connection to CWC Servers for {station_name}...")
        try:
            _path, data = self._fetch_live_station_feed()
            for station in data:
                if station_name.lower() in station.get('stationName', '').lower():
                    level = station.get('waterLevel')
                    print(f"✅ SUCCESS: Live data fetched for {station['stationName']} ({level}m)")
                    return {
                        "status": "success",
                        "current_level_m": level,
                        "source": "CWC API"
                    }
            print("⚠️ API returned empty. Executing BeautifulSoup Fallback...")
            return self._beautifulsoup_fallback(station_name)
        except Exception as e:
            print(f"❌ CWC Scraper Error: {e}")
            return {"status": "error"}

    def _beautifulsoup_fallback(self, station_name):
        """Fallback: Parse HTML from CWC web interface."""
        try:
            fallback_url = "https://ffs.india-water.gov.in/iam/api/report/state/Maharashtra"
            res = requests.get(fallback_url, headers=self.headers, timeout=5)
            soup = BeautifulSoup(res.text, 'html.parser')
            rows = soup.find_all('tr')
            for row in rows:
                if station_name.lower() in row.text.lower():
                    columns = row.find_all('td')
                    if len(columns) > 3:
                        return {
                            "status": "success_fallback",
                            "current_level_m": float(columns[3].text.strip()),
                            "source": "HTML Scrape"
                        }
            return {"status": "error"}
        except Exception:
            return {"status": "error"}

    def get_live_telemetry(self, state_name="Maharashtra", station_name="Kolhapur", limit=6):
        """Get live telemetry from CWC with tactical fallback."""
        target_state = self._normalize_key(state_name)
        target_station = self._normalize_key(station_name)
        tactical_fallback = self._build_tactical_telemetry(state_name=state_name, station_name=station_name, limit=limit)

        try:
            endpoint_path, raw_data = self._fetch_live_station_feed()

            formatted_telemetry = []
            for site in raw_data:
                water_level = self._safe_float(site.get("waterLevel"))
                danger_level = self._safe_float(site.get("dangerLevel"))
                warning_level = self._safe_float(site.get("warningLevel"))
                rainfall_last_hour = self._safe_float(
                    site.get("rainfall")
                    or site.get("rainfallLastHour")
                    or site.get("rainfall1Hr")
                )

                status_label = self._status_from_levels(water_level, warning_level, danger_level)

                formatted_telemetry.append({
                    "station": site.get("stationName") or site.get("name") or "UNKNOWN_SECTOR",
                    "state_name": site.get("stateName") or site.get("state") or "",
                    "state": site.get("stateName") or site.get("state") or state_name,
                    "river": site.get("riverName") or site.get("river") or "",
                    "river_level": round(water_level, 2),
                    "danger_level": round(danger_level, 2),
                    "warning_level": round(warning_level, 2),
                    "flow_rate": round(self._safe_float(site.get("discharge") or site.get("flowRate")), 1),
                    "rainfall_last_hour": round(rainfall_last_hour, 2),
                    "status": status_label,
                    "trend": site.get("trend") or "STEADY",
                    "source": "CWC_API",
                    "endpoint_path": endpoint_path,
                    "last_update": site.get("dateTime") or site.get("lastUpdate") or datetime.datetime.now().isoformat(),
                })

            ranked = sorted(
                formatted_telemetry,
                key=lambda site: (self._site_priority(site, target_state, target_station), -float(site["river_level"])),
            )
            filtered = [site for site in ranked if self._site_priority(site, target_state, target_station) < 3][:limit]

            if filtered:
                return {
                    "status": "SECURED",
                    "data_source": "CWC_API",
                    "endpoint_path": endpoint_path,
                    "timestamp": datetime.datetime.now().isoformat(),
                    "data": filtered,
                }

            return {
                "status": "PARTIAL_FALLBACK",
                "data_source": "TACTICAL_REGISTRY",
                "error": f"No targeted live telemetry found for {state_name}/{station_name}.",
                "timestamp": datetime.datetime.now().isoformat(),
                "data": tactical_fallback,
            }
        except Exception as exc:
            self._log_telemetry_error(str(exc))
            return {
                "status": "FALLBACK_MODE",
                "error": "Central Water Commission servers offline or blocking requests.",
                "data_source": "TACTICAL_REGISTRY",
                "timestamp": datetime.datetime.now().isoformat(),
                "data": tactical_fallback,
            }
