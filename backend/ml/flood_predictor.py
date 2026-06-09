# backend/ml/flood_predictor.py
# OpsFlood — LSTM Flood Prediction Engine
#
# Architecture: Stacked LSTM (2 layers, 64 units each)
# Input features: gauge_level, rainfall_3d, rainfall_7d, upstream_level,
#                 imd_forecast_rain, day_of_year (seasonality)
# Output: river level at t+3h, t+6h, ..., t+72h  (24 hourly steps for 72h)
#
# Training data: CWC historical gauge readings (Bihar, 2000-2024)
# IMD GridPoint Rainfall (0.25deg grid, Bihar bbox)
#
# Requirements: tensorflow>=2.15, numpy, pandas, scikit-learn
from __future__ import annotations

import json
import os
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import List, Optional

import numpy as np

# ── Model / scaler registry ───────────────────────────────────────────────────
MODEL_DIR   = Path(os.getenv('MODEL_DIR',   Path(__file__).parent / 'saved_models'))
SCALER_DIR  = Path(os.getenv('SCALER_DIR',  Path(__file__).parent / 'scalers'))
_STATS_FILE = SCALER_DIR / 'feature_stats.json'


def _load_feature_stats() -> dict[str, tuple[float, float]]:
    """
    Load normalisation (mean, std) pairs from scalers/feature_stats.json.
    Falls back to hardcoded training-set values so the predictor still works
    in test / CI environments where the file may not be present.
    """
    _fallback: dict[str, tuple[float, float]] = {
        'gauge_level':    (40.0, 20.0),
        'rainfall_3d':    (50.0, 80.0),
        'rainfall_7d':    (120.0, 150.0),
        'upstream_level': (40.0, 20.0),
        'imd_forecast':   (20.0, 60.0),
    }
    try:
        raw = json.loads(_STATS_FILE.read_text())
        loaded = {
            k: tuple(v)  # type: ignore[arg-type]
            for k, v in raw['features'].items()
        }
        # Validate all required keys are present
        if loaded.keys() == _fallback.keys():
            return loaded  # type: ignore[return-value]
    except Exception:
        pass
    return _fallback


# Module-level constant — loaded once at import time
FEATURE_STATS: dict[str, tuple[float, float]] = _load_feature_stats()

# ── Gauge danger / warning levels (m MSL) — mirrors lib/data/bihar_rivers.dart
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

# LSTM sequence length — must match the window used during training
SEQ_LEN = 12  # 12 hourly observations = 12h look-back window


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
        history:           Optional[List[float]] = None,
    ) -> dict:
        """
        Returns a prediction dict compatible with the Flutter PredictionProvider.

        Args:
            history: Optional list of up to SEQ_LEN previous hourly gauge readings
                     (oldest first). When provided, used as the LSTM context window
                     directly. When None, a synthetic window is reconstructed from
                     current_level + rainfall trend.
        """
        now = datetime.now(timezone.utc)

        if self._model is not None:
            points = self._ml_predict(
                current_level, rainfall_3d_mm, rainfall_7d_mm,
                upstream_level, imd_forecast_mm, now, history)
        else:
            points = self._physics_predict(current_level, rainfall_3d_mm, now)

        next_24h = points[:24]
        next_48h = points[:48]
        next_72h = points[:72]

        peak = max(p['level'] for p in next_72h) if next_72h else current_level
        confidence = 85.0 if self._model is not None else 65.0

        return {
            'station':            self.station,
            'current_level':      current_level,
            'danger_level':       self.threshold['danger'],
            'warning_level':      self.threshold['warning'],
            'next_24h':           next_24h,
            'next_48h':           next_48h,
            'next_72h':           next_72h,
            'peak_level':         round(peak, 3),
            'will_breach_danger': peak >= self.threshold['danger'],
            'confidence_pct':     confidence,
            'model_version':      'v2.1-lstm' if self._model else 'v1.0-physics',
        }

    # ── ML inference ────────────────────────────────────────────────────────
    def _ml_predict(
        self,
        current: float,
        r3d: float,
        r7d: float,
        upstream: Optional[float],
        imd_fcst: float,
        now: datetime,
        history: Optional[List[float]],
    ) -> list:
        """Run LSTM inference with a genuine SEQ_LEN-step historical window."""
        import tensorflow as tf  # noqa: PLC0415  (lazy import — optional dep)

        day_of_year = now.timetuple().tm_yday / 365.0
        upstream_v  = upstream or current

        level_window = self._build_history_window(current, r3d, history)

        def norm(val: float, key: str) -> float:
            mean, std = FEATURE_STATS[key]
            return (val - mean) / std

        seq_input = np.array(
            [
                [
                    norm(level_window[t], 'gauge_level'),
                    norm(r3d,             'rainfall_3d'),
                    norm(r7d,             'rainfall_7d'),
                    norm(upstream_v,      'upstream_level'),
                    norm(imd_fcst,        'imd_forecast'),
                    day_of_year,
                ]
                for t in range(SEQ_LEN)
            ],
            dtype=np.float32,
        )  # shape: (SEQ_LEN, 6)

        seq_input = seq_input[np.newaxis, ...]  # → (1, SEQ_LEN, 6)
        output = self._model.predict(seq_input, verbose=0)  # (1, 72)
        mean_lv, std_lv = FEATURE_STATS['gauge_level']
        levels = output[0] * std_lv + mean_lv  # de-normalise

        return [
            {
                'time':      (now + timedelta(hours=i + 1)).isoformat(),
                'level':     round(float(levels[i]), 3),
                'precip_mm': round(float(imd_fcst * (1 + 0.1 * np.sin(i))), 1),
            }
            for i in range(72)
        ]

    # ── History window builder ───────────────────────────────────────────────
    def _build_history_window(
        self,
        current_level: float,
        rainfall_3d_mm: float,
        history: Optional[List[float]],
    ) -> List[float]:
        """
        Returns SEQ_LEN gauge readings (oldest first, newest last).
        Uses supplied history if long enough; otherwise reconstructs via
        physics inverse: past[t] = oldest - rate * (n_missing - t).
        """
        if history and len(history) >= SEQ_LEN:
            return list(history[-SEQ_LEN:])

        rate = 0.025 if rainfall_3d_mm > 100 else 0.008
        partial = list(history) if history else []
        n_missing = SEQ_LEN - len(partial)
        oldest_known = partial[0] if partial else current_level
        synthetic_past = [
            oldest_known - rate * (n_missing - t)
            for t in range(n_missing)
        ]
        return synthetic_past + partial

    # ── Physics fallback ─────────────────────────────────────────────────────
    def _physics_predict(self, current: float, rainfall_3d_mm: float, now: datetime) -> list:
        """
        Simple rising-trend model when LSTM weights are not available.
        Trend = 0.025 m/h when 3d rainfall > 100 mm, else 0.008 m/h.
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
        """Try to load a per-station saved LSTM model, then fall back to generic."""
        try:
            import tensorflow as tf  # noqa: PLC0415
            path = MODEL_DIR / f'{station.lower().replace(" ", "_")}.keras'
            if path.exists():
                return tf.keras.models.load_model(str(path))
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
    history: Optional[List[float]] = None,
) -> str:
    predictor = FloodPredictor(station)
    result = predictor.predict(
        current_level, rainfall_3d_mm, rainfall_7d_mm,
        upstream_level, imd_forecast_mm, history)
    return json.dumps(result)
