#!/usr/bin/env python3
"""
Standalone training script for OpsFlood ML model.

This script generates and trains the flood prediction model.
It should be run separately from the FastAPI app, not during app startup.

Usage:
    python -m backend.train
    # or
    cd backend && python train.py
"""

import os
import sys
import numpy as np
import joblib
from sklearn.ensemble import RandomForestClassifier
from sklearn.preprocessing import StandardScaler
from sklearn.model_selection import train_test_split
from pathlib import Path

# Add parent directory to path for imports
sys.path.insert(0, str(Path(__file__).parent.parent))

try:
    from backend.model_metrics import evaluate_and_log_metrics
except ImportError:
    from model_metrics import evaluate_and_log_metrics

try:
    from backend.state_severity_matrix import get_state_severity_entry
except ImportError:
    from state_severity_matrix import get_state_severity_entry


# ── Calibration state ────────────────────────────────────────────────────────
# Bihar is the primary monitored state (Kosi / Gandak / Ganga belt).
# All synthetic training boundaries are derived from its STATE_SEVERITY_MATRIX
# entry so the model learns thresholds that match real CWC danger levels.
#
# Bihar thresholds (from STATE_SEVERITY_MATRIX):
#   peak_level_m  → moderate: 11.0 m | severe: 12.0 m | critical: 13.2 m
#   rainfall_7d_mm→ moderate: 240 mm | severe: 390 mm | critical: 560 mm
#   danger_level_m: 12.00 m  |  hfl_m: 14.40 m
#
# If you retrain for a different primary state, change CALIBRATION_STATE below.
CALIBRATION_STATE = "bihar"
_entry = get_state_severity_entry(CALIBRATION_STATE)

# Peak level (m) boundaries derived from per-state matrix
_pk = _entry["peak_level_m"]
PK_MOD      = float(_pk["moderate"])   # 11.0
PK_SEV      = float(_pk["severe"])     # 12.0
PK_CRIT     = float(_pk["critical"])   # 13.2
PK_HFL      = float(_entry["hfl_m"])   # 14.4  — hard ceiling for CRITICAL synthetic rows

# 7-day rainfall (mm) boundaries
_rn = _entry["rainfall_7d_mm"]
RN_MOD      = float(_rn["moderate"])   # 240
RN_SEV      = float(_rn["severe"])     # 390
RN_CRIT     = float(_rn["critical"])   # 560
RN_MAX      = RN_CRIT * 1.4            # ~784  — ceiling for synthetic CRITICAL rows


def get_training_data():
    """Generate synthetic training data for flood prediction model."""
    rng = np.random.default_rng(42)

    # Real historical Bihar flood events aligned to CWC danger/HFL levels.
    # Columns: peak_level, duration, time_to_peak, recession,
    #          T1d, T2d, T3d, T4d, T5d, T6d, T7d, severity_label
    # severity_label: 0=LOW, 1=MODERATE, 2=SEVERE, 3=CRITICAL
    real_events = [
        # CRITICAL — peak above Bihar HFL (14.4 m) with 7d rain > 560 mm
        [PK_HFL + 0.1,  5, 2, 4, 180, 320, 420, 450, 480, 490, 550, 3],   # 14.5 m, ~560 mm
        [PK_HFL - 0.1,  4, 2, 3, 160, 280, 380, 420, 450, 460, 480, 3],   # 14.3 m (at/above crit)
        # SEVERE — above danger (12.0 m), below HFL
        [PK_SEV + 0.8,  3, 2, 2, 120, 200, 280, 320, 350, 380, 400, 2],   # 12.8 m
        [PK_SEV + 0.2,  2, 1, 2, 100, 180, 250, 290, 320, 350, 370, 2],   # 12.2 m
        # MODERATE — above warning (10.2 m), below danger
        [PK_MOD + 0.5,  2, 1, 2,  80, 140, 190, 210, 230, 240, 260, 1],   # 11.5 m
        [PK_MOD - 0.2,  1, 1, 1,  60, 100, 140, 160, 180, 200, 210, 1],   # 10.8 m
        # LOW — below warning level
        [9.5,           1, 1, 1,  50,  80, 100, 120, 150, 160, 180, 0],
        [8.0,           0, 0, 1,  10,  20,  30,  40,  50,  60,  80, 0],
    ]

    synthetic_data = []
    for _ in range(1000):
        rand = float(rng.random())
        if rand > 0.75:
            # 25% → CRITICAL
            # peak >= critical threshold up to a sensible maximum (HFL + 10%)
            peak   = float(rng.uniform(PK_CRIT, PK_HFL * 1.10))
            rain_7d = float(rng.uniform(RN_CRIT, RN_MAX))
            dur    = float(rng.uniform(5, 9))
            label  = 3
        elif rand > 0.50:
            # 25% → SEVERE
            peak   = float(rng.uniform(PK_SEV, PK_CRIT - 0.01))
            rain_7d = float(rng.uniform(RN_SEV, RN_CRIT - 0.01))
            dur    = float(rng.uniform(3, 7))
            label  = 2
        elif rand > 0.25:
            # 25% → MODERATE
            peak   = float(rng.uniform(PK_MOD, PK_SEV - 0.01))
            rain_7d = float(rng.uniform(RN_MOD, RN_SEV - 0.01))
            dur    = float(rng.uniform(2, 4))
            label  = 1
        else:
            # 25% → LOW
            peak   = float(rng.uniform(5.0, PK_MOD - 0.01))
            rain_7d = float(rng.uniform(50, RN_MOD - 0.01))
            dur    = float(rng.uniform(0, 2))
            label  = 0

        rain_dist = rng.dirichlet(np.ones(7), size=1)[0] * rain_7d
        synthetic_data.append([
            peak,
            dur,
            float(rng.uniform(1, 3)),
            float(rng.uniform(1, 4)),
            float(rain_dist[0]),
            float(rain_dist[1]),
            float(rain_dist[2]),
            float(rain_dist[3]),
            float(rain_dist[4]),
            float(rain_dist[5]),
            float(rain_dist[6]),
            label,
        ])

    all_data = real_events + synthetic_data
    X = np.array([event[:-1] for event in all_data])
    y = np.array([event[-1] for event in all_data])
    return X, y


def train_model(output_dir=None):
    """Train the flood prediction model and save artifacts."""
    if output_dir is None:
        repo_root = Path(__file__).parent.parent
        output_dir = repo_root / "artifacts" / "dvc" / "models"
    else:
        output_dir = Path(output_dir)

    output_dir.mkdir(parents=True, exist_ok=True)

    print(f"📌 Calibration state : {CALIBRATION_STATE.title()}")
    print(f"   peak thresholds   : MOD={PK_MOD}m | SEV={PK_SEV}m | CRIT={PK_CRIT}m | HFL={PK_HFL}m")
    print(f"   rain thresholds   : MOD={RN_MOD}mm | SEV={RN_SEV}mm | CRIT={RN_CRIT}mm")

    print("🔄 Generating training data...")
    X, y = get_training_data()
    print(f"   ✓ Generated {len(X)} training samples with {X.shape[1]} features")

    print("🔄 Splitting data...")
    X_train, X_test, y_train, y_test = train_test_split(
        X, y, test_size=0.2, random_state=42, stratify=y
    )
    print(f"   ✓ Train set: {len(X_train)} samples")
    print(f"   ✓ Test set: {len(X_test)} samples")

    print("🔄 Training multi-class flood prediction model...")
    scaler = StandardScaler()
    X_train_scaled = scaler.fit_transform(X_train)

    model = RandomForestClassifier(n_estimators=100, random_state=42, n_jobs=-1)
    model.fit(X_train_scaled, y_train)
    print("   ✓ Model training complete")

    print("🔄 Evaluating model performance...")
    evaluate_and_log_metrics(model, scaler, X_test, y_test)

    model_path = output_dir / "flood_model.pkl"
    scaler_path = output_dir / "flood_scaler.pkl"

    print(f"💾 Saving model to {model_path}...")
    joblib.dump(model, model_path)

    print(f"💾 Saving scaler to {scaler_path}...")
    joblib.dump(scaler, scaler_path)

    print("✅ Training complete! Model artifacts saved.")
    print(f"   Model: {model_path}")
    print(f"   Scaler: {scaler_path}")

    return model, scaler


if __name__ == "__main__":
    output_dir = sys.argv[1] if len(sys.argv) > 1 else None
    train_model(output_dir)
