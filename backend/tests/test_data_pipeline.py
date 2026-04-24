import json
import tempfile
import unittest
from pathlib import Path

import pandas as pd

from backend.data_pipeline import IngestionTarget, OperationalDataPipeline, ScheduledIngestionService


class OperationalDataPipelineTests(unittest.TestCase):
    def setUp(self):
        self.temp_dir = tempfile.TemporaryDirectory()
        self.repo_dir = Path(self.temp_dir.name)

        self.targets = [
            IngestionTarget(
                state_name="Maharashtra",
                station_name="Kolhapur",
                weather_query="Kolhapur, Maharashtra",
                lat=16.705,
                lon=74.2433,
            )
        ]

        def fake_weather_fetcher(target: IngestionTarget):
            return {
                "name": target.station_name,
                "coord": {"lat": target.lat, "lon": target.lon},
                "weather": [{"main": "Rain", "description": "steady rain"}],
                "main": {
                    "temp": 28.5,
                    "feels_like": 30.2,
                    "temp_min": 27.1,
                    "temp_max": 29.6,
                    "humidity": 84,
                    "pressure": 1002,
                },
                "clouds": {"all": 92},
                "wind": {"speed": 8.4, "deg": 220},
                "visibility": 5400,
                "rain": {"1h": 12.2, "3h": 26.4},
                "_weather_meta": {"source": "TEST_FIXTURE"},
            }

        def fake_water_level_fetcher(target: IngestionTarget):
            return {
                "status": "SECURED",
                "data_source": "TEST_FIXTURE",
                "data": [
                    {
                        "station": target.station_name,
                        "river": "Panchganga",
                        "river_level": 12.8,
                        "warning_level": 11.2,
                        "danger_level": 12.5,
                        "flow_rate": 144.0,
                        "rainfall_last_hour": 10.8,
                        "status": "CRITICAL",
                        "trend": "RISING",
                        "source": "TEST_FIXTURE",
                        "last_update": "2026-04-24T16:00:00Z",
                    },
                    {
                        "station": "Kolhapur Downstream",
                        "river": "Panchganga Downstream",
                        "river_level": 10.7,
                        "warning_level": 10.4,
                        "danger_level": 12.1,
                        "flow_rate": 129.0,
                        "rainfall_last_hour": 8.4,
                        "status": "WARNING",
                        "trend": "RISING",
                        "source": "TEST_FIXTURE",
                        "last_update": "2026-04-24T16:00:00Z",
                    },
                ],
            }

        self.pipeline = OperationalDataPipeline(
            repo_dir=str(self.repo_dir),
            weather_fetcher=fake_weather_fetcher,
            water_level_fetcher=fake_water_level_fetcher,
            targets=self.targets,
        )

    def tearDown(self):
        self.temp_dir.cleanup()

    def test_run_once_materializes_raw_cleaned_and_feature_layers(self):
        summary = self.pipeline.run_once()

        self.assertEqual(summary["target_count"], 1)
        self.assertEqual(summary["raw_records_written"]["weather"], 1)
        self.assertEqual(summary["raw_records_written"]["water_level"], 1)
        self.assertEqual(summary["cleaned_rows"]["weather"], 1)
        self.assertEqual(summary["cleaned_rows"]["water_level"], 2)
        self.assertEqual(summary["feature_rows"], 1)
        self.assertEqual(summary["errors"], [])

        raw_weather_files = list((self.repo_dir / "data" / "raw" / "weather").rglob("*.jsonl"))
        raw_water_files = list((self.repo_dir / "data" / "raw" / "water_level").rglob("*.jsonl"))
        self.assertTrue(raw_weather_files)
        self.assertTrue(raw_water_files)

        cleaned_weather = pd.read_csv(self.repo_dir / "data" / "cleaned" / "weather" / "weather_cleaned_latest.csv")
        cleaned_water = pd.read_csv(self.repo_dir / "data" / "cleaned" / "water_level" / "water_level_cleaned_latest.csv")
        feature_ready = pd.read_csv(self.repo_dir / "data" / "features" / "weather_water" / "weather_water_features_latest.csv")

        self.assertEqual(len(cleaned_weather.index), 1)
        self.assertEqual(len(cleaned_water.index), 2)
        self.assertEqual(len(feature_ready.index), 1)
        self.assertEqual(feature_ready.iloc[0]["river_station"], "Kolhapur")
        self.assertEqual(feature_ready.iloc[0]["telemetry_source"], "TEST_FIXTURE")

        manifest = json.loads((self.repo_dir / "data" / "manifest" / "latest_ingestion_summary.json").read_text(encoding="utf-8"))
        self.assertEqual(manifest["feature_rows"], 1)

    def test_scheduler_trigger_now_executes_pipeline(self):
        scheduler = ScheduledIngestionService(
            pipeline=self.pipeline,
            interval_seconds=300,
            enabled=False,
            run_on_startup=False,
        )

        result = scheduler.trigger_now()

        self.assertEqual(result["status"], "success")
        self.assertIn("summary", result)
        self.assertEqual(result["summary"]["target_count"], 1)


if __name__ == "__main__":
    unittest.main()
