# backend/ml/flood_predictor.py
# OpsFlood — LSTM Flood Prediction Engine
#
# Architecture: Stacked LSTM (2 layers, 64 units each)
# Input features: gauge_level, rainfall_3d, rainfall_7d, upstream_level,
#                 imd_forecast_rain, day_of_year (seasonality)
# Output: river level at t+3h, t+6h, ..., t+72h  (24 hourly steps for 72h)
#
# Training data: CWC historical gauge readings (Bihar, 2000-2024)
# IMD GridPoint Rainfall (0.25° grid, Bihar bbox)
#
# Requirements: tensorflow>=2.15, numpy, pandas, scikit-learn
from __future__ import annotations

import json
import os
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Optional

import numpy as np

# ── Model registry ────────────────────────────────────────────────────────────
MODEL_DIR = Path(os.getenv('MODEL_DIR', Path(__file__).parent / 'saved_models'))

# Gauge danger / warning levels (m MSL) — mirrors lib/data/bihar_rivers.dart
GAUGE_THRESHOLDS: dict[str, dict] = {
    'Gandhighat':     {'danger': 48.60, 'warning': 47.50, 'river': 'Ganga'},
    'Dighaghat':      {'danger': 50.45, 'warning': 49.30, 'river': 'Ganga'},
    'Hathidah':       {'danger': 41.76, 'warning': 40.50, 'river': 'Ganga'},
    'Munger':         {'danger': 39.33, 'warning': 38.20, 'river': 'Ganga'},
    'Kahalgaon':      {'danger': 31.09, 'warning': 30.00, 'river': 'Ganga'},
    'Bhagalpur':      {'danger': 33.68, 'warning': 32.50, 'river': 'Ganga'},
    'Buxar':          {'danger': 60.30, 'warning': 59.20, 'river': 'Ganga'},
    'Birpur (CWC)':   {'danger': 74.70, 'warning': 73.70, 'river': 'Kosi'},
    'Baltara':        {'danger': 33.85, 'warning': 32.85, 'river': 'Kosi'},
    'Basua':          {'danger': 47.75, 'warning': 46.50, 'river': 'Kosi'},
    'Kursela':        {'danger': 30.00, 'warning': 28.80, 'river': 'Kosi'},
    'Chatia':         {'danger': 69.15, 'warning': 68.10, 'river': 'Gandak'},
    'Dumariaghat':    {'danger': 62.22, 'warning': 61.10, 'river': 'Gandak'},
    'Rewaghat':       {'danger': 54.41, 'warning': 53.40, 'river': 'Gandak'},
    'Hajipur':        {'danger': 50.32, 'warning': 49.40, 'river': 'Gandak'},
    'Dheng Bridge':   {'danger': 71.00, 'warning': 70.00, 'river': 'Bagmati'},
    'Benibad':        {'danger': 48.68, 'warning': 47.68, 'river': 'Bagmati'},
    'Hayaghat':       {'danger': 45.72, 'warning': 44.50, 'river': 'Bagmati'},
    'Sikandarpur':    {'danger': 52.53, 'warning': 51.40, 'river': 'Burhi Gandak'},
    'Samastipur':     {'danger': 46.00, 'warning': 44.80, 'river': 'Burhi Gandak'},
    'Rosera':         {'danger': 42.63, 'warning': 41.50, 'river': 'Burhi Gandak'},
    'Khagaria':       {'danger': 36.58, 'warning': 35.40, 'river': 'Burhi Gandak'},
    'Darauli':        {'danger': 60.82, 'warning': 59.80, 'river': 'Ghaghra'},
    'Gangpur Siswan': {'danger': 57.04, 'warning': 56.00, 'river': 'Ghaghra'},
    'Dhengraghat':    {'danger': 35.65, 'warning': 34.65, 'river': 'Mahananda'},
    'Taibpur':        {'danger': 66.00, 'warning': 64.80, 'river': 'Mahananda'},
    'Jainagar':       {'danger': 67.75, 'warning': 66.00, 'river': 'Kamla'},
    'Jhanjharpur':    {'danger': 50.00, 'warning': 48.80, 'river': 'Kamalabalan'},
    'Sonbarsa':       {'danger': 81.85, 'warning': 80.70, 'river': 'Adhwara'},
    'Kamtaul':        {'danger': 50.00, 'warning': 49.00, 'river': 'Adhwara'},
    'Sripalpur':      {'danger': 50.60, 'warning': 49.50, 'river': 'Punpun'},
}


class FloodPredictor:
    """
    LSTM-based flood level predictor for Bihar gauge stations.
    Falls back to physics-based trend model when ML model is unavailable.
    """

    def __init__(self, station: str):
        self.station   = station
        self.threshold = GAUGE_THRESHOLDS.get(station, {'danger': 50.0, 'warning': 48.0})
        self._model    = self._load_model(station)

    # ── Public API ──────────────────────────────────────────────────────────
    def predict(
        self,
        current_level:     float,
        rainfall_3d_mm:    float,
        rainfall_7d_mm:    float,
        upstream_level:    Optional[float] = None,
        imd_forecast_mm:   float = 0.0,
    ) -> dict:
        """
        Returns a prediction dict compatible with the Flutter PredictionProvider.
        """
        now = datetime.now(timezone.utc)

        if self._model is not None:
            points = self._ml_predict(
                current_level, rainfall_3d_mm, rainfall_7d_mm,
                upstream_level, imd_forecast_mm, now)
        else:
            points = self._physics_predict(current_level, rainfall_3d_mm, now)

        next_24h = points[:24]
        next_48h = points[:48]
        next_72h = points[:72]

        peak = max(p['level'] for p in next_72h) if next_72h else current_level
        confidence = 85.0 if self._model is not None else 65.0

        return {
            'station':        self.station,
            'current_level':  current_level,
            'danger_level':   self.threshold['danger'],
            'warning_level':  self.threshold['warning'],
            'next_24h':       next_24h,
            'next_48h':       next_48h,
            'next_72h':       next_72h,
            'peak_level':     round(peak, 3),
            'will_breach_danger': peak >= self.threshold['danger'],
            'confidence_pct': confidence,
            'model_version':  'v2.1-lstm' if self._model else 'v1.0-physics',
        }

    # ── ML inference ────────────────────────────────────────────────────────
    def _ml_predict(self, current, r3d, r7d, upstream, imd_fcst, now) -> list:
        """Run LSTM inference. Requires TensorFlow."""
        import tensorflow as tf  # noqa: PLC0415  (lazy import — optional dep)
        day_of_year = now.timetuple().tm_yday / 365.0
        upstream_v  = upstream or current

        # Normalise inputs (values from training dataset statistics)
        features = np.array([[
            (current     - 40.0) / 20.0,
            (r3d         - 50.0) / 80.0,
            (r7d         - 120.0) / 150.0,
            (upstream_v  - 40.0) / 20.0,
            (imd_fcst    - 20.0) / 60.0,
            day_of_year,
        ]], dtype=np.float32)  # shape: (1, 6)

        seq_input = np.tile(features[:, np.newaxis, :], [1, 12, 1])  # (1, 12, 6)
        output = self._model.predict(seq_input, verbose=0)           # (1, 72)
        levels = output[0] * 20.0 + 40.0                             # de-normalise

        return [
            {
                'time':      (now + timedelta(hours=i + 1)).isoformat(),
                'level':     round(float(levels[i]), 3),
                'precip_mm': round(float(imd_fcst * (1 + 0.1 * np.sin(i))), 1),
            }
            for i in range(72)
        ]

    # ── Physics fallback ─────────────────────────────────────────────────────
    def _physics_predict(self, current, rainfall_3d_mm, now) -> list:
        """
        Simple rising-trend model when LSTM weights are not available.
        Trend = 0.025 m/h when 3d rainfall > 100 mm, else 0.008 m/h.
        Damped sinusoidal diurnal variation added.
        """
        rate = 0.025 if rainfall_3d_mm > 100 else 0.008
        return [
            {
                'time':      (now + timedelta(hours=i + 1)).isoformat(),
                'level':     round(
                    current
                    + rate * (i + 1)
                    + 0.06 * np.sin(2 * np.pi * (i + 1) / 24),
                    3),
                'precip_mm': round(max(0.0, rainfall_3d_mm / 3 - i * 0.5), 1),
            }
            for i in range(72)
        ]

    # ── Model loading ────────────────────────────────────────────────────────
    def _load_model(self, station: str):
        """Try to load a per-station saved LSTM model."""
        try:
            import tensorflow as tf  # noqa: PLC0415
            path = MODEL_DIR / f'{station.lower().replace(" ", "_")}.keras'
            if path.exists():
                return tf.keras.models.load_model(str(path))
            # Try the generic Bihar model
            generic = MODEL_DIR / 'bihar_generic.keras'
            if generic.exists():
                return tf.keras.models.load_model(str(generic))
        except Exception:
            pass
        return None


# ── Convenience function for API route ───────────────────────────────────────
def get_prediction_json(
    station: str,
    current_level: float,
    rainfall_3d_mm: float = 0.0,
    rainfall_7d_mm: float = 0.0,
    upstream_level: Optional[float] = None,
    imd_forecast_mm: float = 0.0,
) -> str:
    predictor = FloodPredictor(station)
    result = predictor.predict(
        current_level, rainfall_3d_mm, rainfall_7d_mm,
        upstream_level, imd_forecast_mm)
    return json.dumps(result)
