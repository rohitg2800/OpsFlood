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


def get_training_data():
    """Generate synthetic training data for flood prediction model."""
    rng = np.random.default_rng(42)

    # Real historical flood events (peak_level, duration, time_to_peak, recession, T1d-T7d, severity_label)
    # NOTE: these are still only LOW/MODERATE/SEVERE in the current repo.
    real_events = [
        [13.5, 5, 2, 4, 180, 320, 420, 450, 480, 490, 550, 2],
        [12.8, 4, 2, 3, 160, 280, 380, 420, 450, 460, 480, 2],
        [11.8, 3, 2, 2, 120, 200, 280, 320, 350, 380, 400, 1],
        [11.2, 2, 1, 2, 100, 180, 250, 290, 320, 350, 370, 1],
        [9.5,  1, 1, 1,  50,  80, 100, 120, 150, 160, 180, 0],
        [8.0,  0, 0, 1,  10,  20,  30,  40,  50,  60,  80, 0],
    ]

    # Synthetic data is responsible for ensuring the CRITICAL class exists.
    synthetic_data = []
    for _ in range(1000):
        rand = float(rng.random())
        if rand > 0.75:
            peak = float(rng.uniform(14.0, 18.0))
            rain_7d = float(rng.uniform(650, 1000))
            dur = float(rng.uniform(3, 7))
            label = 3  # CRITICAL
        elif rand > 0.50:
            peak = float(rng.uniform(12.0, 14.0))
            rain_7d = float(rng.uniform(420, 650))
            dur = float(rng.uniform(2, 4))
            label = 2  # SEVERE
        elif rand > 0.25:
            peak = float(rng.uniform(10.0, 12.0))
            rain_7d = float(rng.uniform(250, 420))
            dur = float(rng.uniform(1, 3))
            label = 1  # MODERATE
        else:
            peak = float(rng.uniform(4.0, 10.0))
            rain_7d = float(rng.uniform(30, 250))
            dur = float(rng.uniform(0, 2))
            label = 0  # LOW

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

    # Fit expects consistent numeric labels; model app-side maps numeric->severity.
    X = np.array([event[:-1] for event in all_data], dtype=float)
    y_numeric = np.array([int(event[-1]) for event in all_data], dtype=int)

    return X, y_numeric



def train_model(output_dir=None):
    """Train the flood prediction model and save artifacts."""
    if output_dir is None:
        # Default to artifacts/dvc/models directory
        repo_root = Path(__file__).parent.parent
        output_dir = repo_root / "artifacts" / "dvc" / "models"
    else:
        output_dir = Path(output_dir)
    
    output_dir.mkdir(parents=True, exist_ok=True)
    
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
