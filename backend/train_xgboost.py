import os
from pathlib import Path

import joblib
import numpy as np
from xgboost import XGBClassifier
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import StandardScaler
from sklearn.metrics import accuracy_score, classification_report

# ── SAME 11 FEATURES YOUR APP USES ──────────────────────────────────────────
FEATURES = [
    "Peak_Flood_Level_m",
    "Event_Duration_days",
    "Time_to_Peak_days",
    "Recession_Time_day",
    "T1d", "T2d", "T3d", "T4d", "T5d", "T6d", "T7d"
]

# ── SAME TRAINING DATA YOUR APP USES (from get_training_data) ───────────────
real_events = [
    [13.5, 5, 2, 4, 180, 320, 420, 450, 480, 490, 550, 2],
    [12.8, 4, 2, 3, 160, 280, 380, 420, 450, 460, 480, 2],
    [11.8, 3, 2, 2, 120, 200, 280, 320, 350, 380, 400, 1],
    [11.2, 2, 1, 2, 100, 180, 250, 290, 320, 350, 370, 1],
    [9.5,  1, 1, 1,  50,  80, 100, 120, 150, 160, 180, 0],
    [8.0,  0, 0, 1,  10,  20,  30,  40,  50,  60,  80, 0],
]

np.random.seed(42)
synthetic_data = []
for _ in range(1000):
    rand = np.random.random()
    if rand > 0.66:
        peak = np.random.uniform(12.2, 14.5)
        rain_7d = np.random.uniform(450, 700)
        dur = np.random.uniform(3, 7)
        label = 2
    elif rand > 0.33:
        peak = np.random.uniform(10.5, 12.1)
        rain_7d = np.random.uniform(250, 449)
        dur = np.random.uniform(2, 4)
        label = 1
    else:
        peak = np.random.uniform(5.0, 10.4)
        rain_7d = np.random.uniform(50, 249)
        dur = np.random.uniform(0, 2)
        label = 0

    rain_dist = np.random.dirichlet(np.ones(7)) * rain_7d
    synthetic_data.append([
        peak, dur,
        np.random.uniform(1, 3),
        np.random.uniform(1, 4),
        *rain_dist,
        label
    ])

all_data = real_events + synthetic_data
X = np.array([row[:-1] for row in all_data])
y = np.array([row[-1]  for row in all_data])

# ── TRAIN / TEST SPLIT ───────────────────────────────────────────────────────
X_train, X_test, y_train, y_test = train_test_split(
    X, y, test_size=0.2, random_state=42, stratify=y
)

# ── SCALE (matches your existing scaler pattern) ─────────────────────────────
scaler = StandardScaler()
X_train_scaled = scaler.fit_transform(X_train)
X_test_scaled  = scaler.transform(X_test)

# ── TRAIN XGBOOST ────────────────────────────────────────────────────────────
model = XGBClassifier(
    n_estimators=200,
    max_depth=6,
    learning_rate=0.1,
    subsample=0.8,
    colsample_bytree=0.8,
    eval_metric="mlogloss",
    random_state=42
)
model.fit(X_train_scaled, y_train, verbose=False)

# ── EVALUATE ─────────────────────────────────────────────────────────────────
y_pred = model.predict(X_test_scaled)
print(f"\n✅ XGBoost Bundle Accuracy: {accuracy_score(y_test, y_pred)*100:.2f}%")
print(classification_report(y_test, y_pred, target_names=["LOW", "MODERATE", "SEVERE"]))

# ── SAVE AS NEW BUNDLE ───────────────────────────────────────────────────────
REPO_DIR = Path(__file__).resolve().parents[1]
ARTIFACT_DIR = REPO_DIR / "artifacts" / "dvc" / "models"
ARTIFACT_DIR.mkdir(parents=True, exist_ok=True)

model_path = ARTIFACT_DIR / "xgboost_flood_model.pkl"
scaler_path = ARTIFACT_DIR / "xgboost_flood_scaler.pkl"
features_path = ARTIFACT_DIR / "xgboost_flood_features.txt"

joblib.dump(model, model_path)
joblib.dump(scaler, scaler_path)
features_path.write_text("\n".join(FEATURES) + "\n", encoding="utf-8")

print(f"✅ Saved → {model_path}")
print(f"✅ Saved → {scaler_path}")
print(f"✅ Saved → {features_path}")
