#!/usr/bin/env python3
"""
Standalone training script for EQUINOX-BH ML model.

This script generates and trains the flood prediction model.
It should be run separately from the FastAPI app, not during app startup.

Usage:
    python -m backend.train
    # or
    python backend/train.py
"""

import os
import sys
from pathlib import Path

# Ensure the repo root is on the path so `backend.*` imports resolve.
REPO_ROOT = Path(__file__).resolve().parent.parent
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))

from backend.state_severity_matrix import (
    get_state_severity_entry,
    severity_from_entry,
)
from backend.model_metrics import evaluate_and_log_metrics

import numpy as np
import joblib
from sklearn.ensemble import RandomForestClassifier
from sklearn.preprocessing import StandardScaler
from sklearn.model_selection import train_test_split
import warnings

warnings.filterwarnings('ignore')

# ── Paths ───────────────────────────────────────────────────────────────────────
ARTIFACT_DIR  = REPO_ROOT / 'artifacts' / 'dvc' / 'models'
MODEL_PATH    = ARTIFACT_DIR / 'flood_model.pkl'
SCALER_PATH   = ARTIFACT_DIR / 'flood_scaler.pkl'

CALIBRATION_STATE = 'Bihar'


def generate_training_data(n_samples: int = 1008):
    """Generate synthetic flood training data calibrated to Bihar thresholds."""
    entry = get_state_severity_entry(CALIBRATION_STATE.lower())

    peak_thresholds  = entry['peak_level_m']
    rain_thresholds  = entry['rainfall_7d_mm']

    print(f"\n\U0001f4cc Calibration state : {CALIBRATION_STATE}")
    print(f"   peak thresholds   : "
          f"MOD={peak_thresholds['moderate']}m | "
          f"SEV={peak_thresholds['severe']}m | "
          f"CRIT={peak_thresholds['critical']}m | "
          f"HFL={entry['hfl_m']}m")
    print(f"   rain thresholds   : "
          f"MOD={rain_thresholds['moderate']}mm | "
          f"SEV={rain_thresholds['severe']}mm | "
          f"CRIT={rain_thresholds['critical']}mm")

    rng = np.random.default_rng(42)
    features, labels = [], []

    bands = [
        # (peak_range, rain_range, label_fn)
        ((8.0,  peak_thresholds['moderate']),  (0.0,   rain_thresholds['moderate']),  'LOW'),
        ((peak_thresholds['moderate'], peak_thresholds['severe']),
         (rain_thresholds['moderate'], rain_thresholds['severe']),  'MODERATE'),
        ((peak_thresholds['severe'],   peak_thresholds['critical']),
         (rain_thresholds['severe'],   rain_thresholds['critical']), 'SEVERE'),
        ((peak_thresholds['critical'], entry['hfl_m'] + 2.0),
         (rain_thresholds['critical'], rain_thresholds['critical'] + 200.0), 'CRITICAL'),
    ]

    per_band = n_samples // len(bands)
    for (p_lo, p_hi), (r_lo, r_hi), label in bands:
        peak   = rng.uniform(p_lo, p_hi, per_band)
        rain   = rng.uniform(r_lo, r_hi, per_band)
        temp   = rng.uniform(22.0, 38.0, per_band)
        humid  = rng.uniform(55.0, 98.0, per_band)
        days   = rng.integers(1, 8, per_band).astype(float)
        month  = rng.integers(6, 10, per_band).astype(float)
        prev1  = peak * rng.uniform(0.85, 1.0,  per_band)
        prev2  = peak * rng.uniform(0.70, 0.95, per_band)
        prev3  = peak * rng.uniform(0.60, 0.90, per_band)
        runoff = rain * rng.uniform(0.3, 0.7, per_band)
        trend  = peak - prev1

        for i in range(per_band):
            features.append([peak[i], rain[i], temp[i], humid[i],
                              days[i], month[i], prev1[i], prev2[i],
                              prev3[i], runoff[i], trend[i]])
            labels.append(label)

    return np.array(features), np.array(labels)


def train_model():
    print("\U0001f504 Generating training data...")
    X, y = generate_training_data()
    print(f"   \u2713 Generated {len(X)} training samples with {X.shape[1]} features")

    print("\U0001f504 Splitting data...")
    X_train, X_test, y_train, y_test = train_test_split(
        X, y, test_size=0.2, random_state=42, stratify=y
    )
    print(f"   \u2713 Train set: {len(X_train)} samples")
    print(f"   \u2713 Test set:  {len(X_test)} samples")

    scaler = StandardScaler()
    X_train_scaled = scaler.fit_transform(X_train)

    print("\U0001f504 Training multi-class flood prediction model...")
    model = RandomForestClassifier(
        n_estimators=200,
        max_depth=None,
        min_samples_split=2,
        min_samples_leaf=1,
        random_state=42,
        n_jobs=-1,
    )
    model.fit(X_train_scaled, y_train)
    print("   \u2713 Model training complete")

    print("\U0001f504 Evaluating model performance...")
    evaluate_and_log_metrics(model, scaler, X_test, y_test, model_name='model')

    ARTIFACT_DIR.mkdir(parents=True, exist_ok=True)
    print(f"\U0001f4be Saving model to {MODEL_PATH}...")
    joblib.dump(model, MODEL_PATH)
    print(f"\U0001f4be Saving scaler to {SCALER_PATH}...")
    joblib.dump(scaler, SCALER_PATH)
    print(f"\u2705 Training complete! Model artifacts saved.")
    print(f"   Model:  {MODEL_PATH}")
    print(f"   Scaler: {SCALER_PATH}")


if __name__ == '__main__':
    train_model()
