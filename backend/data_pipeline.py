from __future__ import annotations

import json
import threading
from dataclasses import asdict, dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Callable, Dict, Iterable

import pandas as pd


@dataclass(frozen=True)
class IngestionTarget:
    state_name: str
    station_name: str
    weather_query: str
    lat: float | None = None
    lon: float | None = None


def slugify_value(value: str) -> str:
    normalized = "".join(ch.lower() if ch.isalnum() else "_" for ch in (value or "").strip())
    collapsed = "_".join(part for part in normalized.split("_") if part)
    return collapsed or "unknown"


class OperationalDataPipeline:
    def __init__(
        self,
        *,
        repo_dir: str,
        weather_fetcher: Callable[[IngestionTarget], Dict[str, Any]],
        water_level_fetcher: Callable[[IngestionTarget], Dict[str, Any]],
        audit_logger: Callable[..., Any] | None = None,
        targets: Iterable[IngestionTarget] | None = None,
    ):
        self.repo_dir = Path(repo_dir)
        self.data_root = self.repo_dir / "data"
        self.raw_root = self.data_root / "raw"
        self.cleaned_root = self.data_root / "cleaned"
        self.features_root = self.data_root / "features"
        self.manifest_root = self.data_root / "manifest"
        self.weather_fetcher = weather_fetcher
        self.water_level_fetcher = water_level_fetcher
        self.audit_logger = audit_logger
        self.targets = list(targets or [])
        self.last_run_summary: Dict[str, Any] | None = None
        self.last_error: str | None = None
        self.ensure_directories()

    def ensure_directories(self):
        for path in (
            self.raw_root / "weather",
            self.raw_root / "water_level",
            self.cleaned_root / "weather",
            self.cleaned_root / "water_level",
            self.features_root / "weather_water",
            self.manifest_root,
        ):
            path.mkdir(parents=True, exist_ok=True)

    def update_targets(self, targets: Iterable[IngestionTarget]):
        self.targets = list(targets)

    def dataset_paths(self) -> Dict[str, str]:
        return {
            "raw_weather": str(self.raw_root / "weather"),
            "raw_water_level": str(self.raw_root / "water_level"),
            "cleaned_weather": str(self.cleaned_root / "weather"),
            "cleaned_water_level": str(self.cleaned_root / "water_level"),
            "feature_ready": str(self.features_root / "weather_water"),
            "manifest": str(self.manifest_root),
        }

    def status(self) -> Dict[str, Any]:
        return {
            "target_count": len(self.targets),
            "targets": [asdict(target) for target in self.targets],
            "dataset_paths": self.dataset_paths(),
            "last_run_summary": self.last_run_summary,
            "last_error": self.last_error,
        }

    def _append_jsonl(self, path: Path, record: Dict[str, Any]):
        path.parent.mkdir(parents=True, exist_ok=True)
        with path.open("a", encoding="utf-8") as handle:
            handle.write(json.dumps(record, ensure_ascii=True, default=str))
            handle.write("\n")

    def _load_jsonl_records(self, root: Path) -> list[Dict[str, Any]]:
        records: list[Dict[str, Any]] = []
        if not root.exists():
            return records

        for jsonl_path in sorted(root.rglob("*.jsonl")):
            with jsonl_path.open("r", encoding="utf-8") as handle:
                for line in handle:
                    stripped = line.strip()
                    if not stripped:
                        continue
                    try:
                        records.append(json.loads(stripped))
                    except json.JSONDecodeError:
                        continue
        return records

    def _write_dataframe(self, df: pd.DataFrame, latest_path: Path, partition_root: Path, prefix: str, run_at: datetime):
        latest_path.parent.mkdir(parents=True, exist_ok=True)
        partition_dir = partition_root / f"date={run_at.date().isoformat()}"
        partition_dir.mkdir(parents=True, exist_ok=True)
        partition_path = partition_dir / f"{prefix}_{run_at.strftime('%Y%m%dT%H%M%SZ')}.csv"

        frame = df.copy()
        frame.to_csv(latest_path, index=False)
        frame.to_csv(partition_path, index=False)

    def _normalize_weather_records(self) -> pd.DataFrame:
        records = self._load_jsonl_records(self.raw_root / "weather")
        rows: list[Dict[str, Any]] = []

        for record in records:
            target = record.get("target", {})
            snapshot = record.get("snapshot", {}) or {}
            weather_items = snapshot.get("weather") or [{}]
            weather_head = weather_items[0] if weather_items else {}
            main_block = snapshot.get("main") or {}
            rain_block = snapshot.get("rain") or {}
            wind_block = snapshot.get("wind") or {}
            coord_block = snapshot.get("coord") or {}
            clouds_block = snapshot.get("clouds") or {}
            weather_meta = snapshot.get("_weather_meta") or {}

            rows.append(
                {
                    "ingested_at": record.get("ingested_at"),
                    "pipeline_run_id": record.get("pipeline_run_id"),
                    "state_name": target.get("state_name"),
                    "requested_station_name": target.get("station_name"),
                    "weather_query": target.get("weather_query"),
                    "resolved_location": snapshot.get("name"),
                    "lat": coord_block.get("lat") or target.get("lat"),
                    "lon": coord_block.get("lon") or target.get("lon"),
                    "weather_source": weather_meta.get("source") or "OPENWEATHER_PROXY",
                    "weather_main": weather_head.get("main"),
                    "weather_description": weather_head.get("description"),
                    "temperature_c": main_block.get("temp"),
                    "feels_like_c": main_block.get("feels_like"),
                    "temp_min_c": main_block.get("temp_min"),
                    "temp_max_c": main_block.get("temp_max"),
                    "humidity_pct": main_block.get("humidity"),
                    "pressure_hpa": main_block.get("pressure"),
                    "cloud_cover_pct": clouds_block.get("all"),
                    "wind_speed_mps": wind_block.get("speed"),
                    "wind_deg": wind_block.get("deg"),
                    "visibility_m": snapshot.get("visibility"),
                    "rainfall_1h_mm": rain_block.get("1h", 0.0),
                    "rainfall_3h_mm": rain_block.get("3h", 0.0),
                }
            )

        return pd.DataFrame(rows)

    def _normalize_water_level_records(self) -> pd.DataFrame:
        records = self._load_jsonl_records(self.raw_root / "water_level")
        rows: list[Dict[str, Any]] = []

        for record in records:
            target = record.get("target", {})
            snapshot = record.get("snapshot", {}) or {}
            nodes = snapshot.get("data") or []
            for node in nodes:
                rows.append(
                    {
                        "ingested_at": record.get("ingested_at"),
                        "pipeline_run_id": record.get("pipeline_run_id"),
                        "state_name": target.get("state_name"),
                        "requested_station_name": target.get("station_name"),
                        "telemetry_status": snapshot.get("status"),
                        "telemetry_source": snapshot.get("data_source"),
                        "river_station": node.get("station"),
                        "river_name": node.get("river"),
                        "river_level_m": node.get("river_level"),
                        "warning_level_m": node.get("warning_level"),
                        "danger_level_m": node.get("danger_level"),
                        "flow_rate": node.get("flow_rate"),
                        "rainfall_last_hour_mm": node.get("rainfall_last_hour"),
                        "status": node.get("status"),
                        "trend": node.get("trend"),
                        "source": node.get("source"),
                        "last_update": node.get("last_update"),
                    }
                )

        return pd.DataFrame(rows)

    def _build_feature_frame(self, weather_df: pd.DataFrame, water_df: pd.DataFrame, run_at: datetime) -> pd.DataFrame:
        if weather_df.empty and water_df.empty:
            return pd.DataFrame(
                columns=[
                    "feature_ready_at",
                    "state_name",
                    "requested_station_name",
                    "resolved_location",
                    "river_station",
                    "weather_source",
                    "telemetry_source",
                    "temperature_c",
                    "humidity_pct",
                    "pressure_hpa",
                    "rainfall_1h_mm",
                    "rainfall_3h_mm",
                    "rainfall_last_hour_mm",
                    "river_level_m",
                    "warning_level_m",
                    "danger_level_m",
                    "warning_headroom_m",
                    "danger_headroom_m",
                    "hydro_meteorological_stress_index",
                ]
            )

        weather_latest = (
            weather_df.sort_values("ingested_at", ascending=False).drop_duplicates(["state_name", "requested_station_name"], keep="first")
            if not weather_df.empty
            else pd.DataFrame(columns=["state_name", "requested_station_name"])
        )
        if not water_df.empty:
            water_ranked = water_df.copy()
            water_ranked["station_match"] = (
                water_ranked["river_station"].fillna("").str.lower()
                == water_ranked["requested_station_name"].fillna("").str.lower()
            ).astype(int)
            water_ranked["status_rank"] = water_ranked["status"].map(
                {"CRITICAL": 3, "WARNING": 2, "ACTIVE": 1, "OFFLINE": 0}
            ).fillna(0)
            water_latest = (
                water_ranked.sort_values(
                    ["ingested_at", "station_match", "status_rank", "river_level_m"],
                    ascending=[False, False, False, False],
                )
                .drop_duplicates(["state_name", "requested_station_name"], keep="first")
                .drop(columns=["station_match", "status_rank"], errors="ignore")
            )
        else:
            water_latest = pd.DataFrame(columns=["state_name", "requested_station_name"])

        merged = pd.merge(
            weather_latest,
            water_latest,
            on=["state_name", "requested_station_name"],
            how="outer",
            suffixes=("_weather", "_water"),
        )

        rows: list[Dict[str, Any]] = []
        for _, row in merged.iterrows():
            river_level = self._safe_float(row.get("river_level_m"))
            warning_level = self._safe_float(row.get("warning_level_m"))
            danger_level = self._safe_float(row.get("danger_level_m"))
            rainfall_1h = self._safe_float(row.get("rainfall_1h_mm"))
            rainfall_3h = self._safe_float(row.get("rainfall_3h_mm"))
            rainfall_last_hour = self._safe_float(row.get("rainfall_last_hour_mm"))
            humidity_pct = self._safe_float(row.get("humidity_pct"))
            pressure_hpa = self._safe_float(row.get("pressure_hpa"))

            warning_headroom = round(warning_level - river_level, 3) if warning_level else None
            danger_headroom = round(danger_level - river_level, 3) if danger_level else None
            stress_index = round(
                rainfall_1h * 0.35
                + rainfall_3h * 0.2
                + rainfall_last_hour * 0.25
                + humidity_pct * 0.08
                + max(river_level, 0.0) * 1.15
                - max(pressure_hpa - 1000.0, 0.0) * 0.04,
                3,
            )

            rows.append(
                {
                    "feature_ready_at": run_at.isoformat(),
                    "state_name": row.get("state_name"),
                    "requested_station_name": row.get("requested_station_name"),
                    "resolved_location": row.get("resolved_location"),
                    "river_station": row.get("river_station"),
                    "weather_source": row.get("weather_source"),
                    "telemetry_source": row.get("telemetry_source"),
                    "temperature_c": row.get("temperature_c"),
                    "humidity_pct": row.get("humidity_pct"),
                    "pressure_hpa": row.get("pressure_hpa"),
                    "rainfall_1h_mm": row.get("rainfall_1h_mm"),
                    "rainfall_3h_mm": row.get("rainfall_3h_mm"),
                    "rainfall_last_hour_mm": row.get("rainfall_last_hour_mm"),
                    "river_level_m": row.get("river_level_m"),
                    "warning_level_m": row.get("warning_level_m"),
                    "danger_level_m": row.get("danger_level_m"),
                    "warning_headroom_m": warning_headroom,
                    "danger_headroom_m": danger_headroom,
                    "hydro_meteorological_stress_index": stress_index,
                }
            )

        return pd.DataFrame(rows)

    def _safe_float(self, value: Any) -> float:
        try:
            return float(value or 0.0)
        except (TypeError, ValueError):
            return 0.0

    def _write_manifest(self, summary: Dict[str, Any]):
        manifest_path = self.manifest_root / "latest_ingestion_summary.json"
        manifest_path.write_text(json.dumps(summary, indent=2, ensure_ascii=True), encoding="utf-8")

    def _log_audit(self, *, event_status: str, details: Dict[str, Any]):
        if not self.audit_logger:
            return
        self.audit_logger(
            event_type="dataset.ingestion.run",
            route="scheduler:data_ingestion",
            event_status=event_status,
            details=details,
        )

    def run_once(self) -> Dict[str, Any]:
        self.ensure_directories()
        run_at = datetime.now(timezone.utc)
        run_id = run_at.strftime("%Y%m%dT%H%M%SZ")
        run_date = run_at.date().isoformat()

        summary: Dict[str, Any] = {
            "run_id": run_id,
            "run_started_at": run_at.isoformat(),
            "target_count": len(self.targets),
            "targets_processed": 0,
            "raw_records_written": {"weather": 0, "water_level": 0},
            "cleaned_rows": {"weather": 0, "water_level": 0},
            "feature_rows": 0,
            "dataset_paths": self.dataset_paths(),
            "errors": [],
        }

        for target in self.targets:
            target_slug = f"{slugify_value(target.state_name)}__{slugify_value(target.station_name)}"
            target_payload = asdict(target)

            try:
                weather_snapshot = self.weather_fetcher(target)
                weather_record = {
                    "ingested_at": run_at.isoformat(),
                    "pipeline_run_id": run_id,
                    "target": target_payload,
                    "snapshot": weather_snapshot,
                }
                weather_path = self.raw_root / "weather" / f"date={run_date}" / f"{target_slug}.jsonl"
                self._append_jsonl(weather_path, weather_record)
                summary["raw_records_written"]["weather"] += 1
            except Exception as exc:
                summary["errors"].append(
                    {
                        "kind": "weather",
                        "target": target_payload,
                        "detail": str(exc),
                    }
                )

            try:
                water_snapshot = self.water_level_fetcher(target)
                water_record = {
                    "ingested_at": run_at.isoformat(),
                    "pipeline_run_id": run_id,
                    "target": target_payload,
                    "snapshot": water_snapshot,
                }
                water_path = self.raw_root / "water_level" / f"date={run_date}" / f"{target_slug}.jsonl"
                self._append_jsonl(water_path, water_record)
                summary["raw_records_written"]["water_level"] += 1
            except Exception as exc:
                summary["errors"].append(
                    {
                        "kind": "water_level",
                        "target": target_payload,
                        "detail": str(exc),
                    }
                )

            summary["targets_processed"] += 1

        weather_df = self._normalize_weather_records()
        water_df = self._normalize_water_level_records()
        feature_df = self._build_feature_frame(weather_df, water_df, run_at)

        self._write_dataframe(
            weather_df,
            self.cleaned_root / "weather" / "weather_cleaned_latest.csv",
            self.cleaned_root / "weather",
            "weather_cleaned",
            run_at,
        )
        self._write_dataframe(
            water_df,
            self.cleaned_root / "water_level" / "water_level_cleaned_latest.csv",
            self.cleaned_root / "water_level",
            "water_level_cleaned",
            run_at,
        )
        self._write_dataframe(
            feature_df,
            self.features_root / "weather_water" / "weather_water_features_latest.csv",
            self.features_root / "weather_water",
            "weather_water_features",
            run_at,
        )

        summary["cleaned_rows"]["weather"] = int(len(weather_df.index))
        summary["cleaned_rows"]["water_level"] = int(len(water_df.index))
        summary["feature_rows"] = int(len(feature_df.index))
        summary["run_finished_at"] = datetime.now(timezone.utc).isoformat()

        self.last_error = None if not summary["errors"] else f"{len(summary['errors'])} ingestion errors"
        self.last_run_summary = summary
        self._write_manifest(summary)
        self._log_audit(event_status="success" if not summary["errors"] else "partial_success", details=summary)
        return summary


class ScheduledIngestionService:
    def __init__(
        self,
        *,
        pipeline: OperationalDataPipeline,
        interval_seconds: int = 3600,
        enabled: bool = False,
        run_on_startup: bool = True,
    ):
        self.pipeline = pipeline
        self.interval_seconds = max(60, int(interval_seconds))
        self.enabled = enabled
        self.run_on_startup = run_on_startup
        self._stop_event = threading.Event()
        self._lock = threading.Lock()
        self._thread: threading.Thread | None = None
        self.last_started_at: str | None = None
        self.last_finished_at: str | None = None
        self.last_error: str | None = None

    def start(self) -> bool:
        if not self.enabled:
            return False
        if self._thread and self._thread.is_alive():
            return False

        self._stop_event.clear()
        self._thread = threading.Thread(target=self._run_loop, name="data-ingestion-scheduler", daemon=True)
        self._thread.start()
        return True

    def stop(self):
        self._stop_event.set()
        if self._thread and self._thread.is_alive():
            self._thread.join(timeout=2)

    def _run_loop(self):
        if self.run_on_startup:
            self.trigger_now()

        while not self._stop_event.wait(self.interval_seconds):
            self.trigger_now()

    def trigger_now(self) -> Dict[str, Any]:
        if not self._lock.acquire(blocking=False):
            return {
                "status": "busy",
                "message": "An ingestion run is already in progress.",
                "scheduler": self.status(),
            }

        try:
            self.last_started_at = datetime.now(timezone.utc).isoformat()
            summary = self.pipeline.run_once()
            self.last_finished_at = datetime.now(timezone.utc).isoformat()
            self.last_error = None
            return {"status": "success", "summary": summary}
        except Exception as exc:
            self.last_finished_at = datetime.now(timezone.utc).isoformat()
            self.last_error = str(exc)
            self.pipeline.last_error = str(exc)
            return {
                "status": "error",
                "message": str(exc),
                "scheduler": self.status(),
            }
        finally:
            self._lock.release()

    def status(self) -> Dict[str, Any]:
        return {
            "enabled": self.enabled,
            "running": bool(self._thread and self._thread.is_alive()),
            "interval_seconds": self.interval_seconds,
            "run_on_startup": self.run_on_startup,
            "in_progress": self._lock.locked(),
            "last_started_at": self.last_started_at,
            "last_finished_at": self.last_finished_at,
            "last_error": self.last_error,
            "pipeline": self.pipeline.status(),
        }
