"""\
Offline training script for OpsFlood — INDOFLOODS 4-class RandomForest.
Run from repo root:
    python backend/train_indofloods.py --dataset path/to/indofloods.csv

Produces:
    artifacts/dvc/models/indofloods_production_model.pkl
    artifacts/dvc/models/indofloods_scaler.pkl
    artifacts/metrics/indofloods_metrics.json

Only overwrites production artifacts if new model beats current on macro F1 AND macro AUROC (gating logic).
"""

import argparse
import json
from pathlib import Path
import pickle
import os

import numpy as np
import pandas as pd
from sklearn.ensemble import RandomForestClassifier
from sklearn.metrics import (
    classification_report,
    confusion_matrix,
    f1_score,
    roc_auc_score,
)
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import StandardScaler

# ── Paths ──────────────────────────────────────────────────────────────────────
ARTIFACTS_DIR = Path("artifacts/dvc/models")
METRICS_DIR = Path("artifacts/metrics")
PROD_MODEL = ARTIFACTS_DIR / "indofloods_production_model.pkl"
PROD_SCALER = ARTIFACTS_DIR / "indofloods_scaler.pkl"
METRICS_FILE = METRICS_DIR / "indofloods_metrics.json"

LABEL_MAP = {
    "LOW": 0,
    "MODERATE": 1,
    "SEVERE": 2,
    "CRITICAL": 3,
    0: 0,
    1: 1,
    2: 2,
    3: 3,
}

FEATURES = [
    "Peak_Flood_Level_m",
    "Rainfall_7d_mm",
    "Discharge_cumecs",
    "Catchment_Area_km2",
    "Duration_days",
    "Antecedent_Rainfall_mm",
    "Distance_from_Gauge_km",
    # Add or remove columns to match your actual INDOFLOODS CSV headers.
    # The script will drop any column not present and warn you.
]

TARGET_COL = "Flood_Severity"  # Must be one of {LOW, MODERATE, SEVERE, CRITICAL} or {0,1,2,3}


def validate_critical_labels(df: pd.DataFrame, target_col: str, label_map: dict) -> None:
    """\
    Warn if rows that exceed state-matrix CRITICAL thresholds are NOT labelled CRITICAL.
    Uses default national thresholds as a proxy check.
    """
    DEFAULT_CRITICAL_LEVEL_M = 13.5  # from DEFAULT_STATE_ENTRY
    DEFAULT_CRITICAL_RAIN_MM = 550.0

    if "Peak_Flood_Level_m" in df.columns:
        should_be_critical = (
            (df["Peak_Flood_Level_m"] >= DEFAULT_CRITICAL_LEVEL_M)
            | (df.get("Rainfall_7d_mm", 0) >= DEFAULT_CRITICAL_RAIN_MM)
        )
        actual_critical = df[target_col].isin([3, "CRITICAL"]) | df[target_col].astype(str).str.upper().eq("3")
        mislabelled = should_be_critical & ~actual_critical
        if int(mislabelled.sum()) > 0:
            print(
                f"[WARN] {int(mislabelled.sum())} rows exceed CRITICAL thresholds but are NOT labelled CRITICAL. Review and re-label."
            )


def load_dataset(path: str) -> tuple[np.ndarray, np.ndarray]:
    df = pd.read_csv(path)
    print(f"[INFO] Loaded {len(df)} rows from {path}")

    # Map string labels -> int if needed
    if df[TARGET_COL].dtype == object:
        df[TARGET_COL] = df[TARGET_COL].astype(str).str.upper().map(lambda v: LABEL_MAP.get(v, np.nan))

    validate_critical_labels(df, TARGET_COL, LABEL_MAP)

    # Drop rows where target is NaN
    df = df.dropna(subset=[TARGET_COL])

    available = [f for f in FEATURES if f in df.columns]
    missing = [f for f in FEATURES if f not in df.columns]
    if missing:
        print(f"[WARN] Missing feature columns (skipped): {missing}")

    X = df[available].fillna(df[available].median()).values
    y = df[TARGET_COL].astype(int).values
    return X, y


def train_and_evaluate(X_train, X_test, y_train, y_test):
    scaler = StandardScaler()
    X_train_s = scaler.fit_transform(X_train)
    X_test_s = scaler.transform(X_test)

    model = RandomForestClassifier(
        n_estimators=300,
        max_depth=None,
        min_samples_split=4,
        class_weight="balanced",
        random_state=42,
        n_jobs=-1,
    )
    model.fit(X_train_s, y_train)

    y_pred = model.predict(X_test_s)
    y_proba = model.predict_proba(X_test_s)

    weighted_f1 = f1_score(y_test, y_pred, average="weighted")
    macro_f1 = f1_score(y_test, y_pred, average="macro")

    macro_auroc = roc_auc_score(y_test, y_proba, multi_class="ovr", average="macro")

    metrics = {
        "weighted_f1": round(float(weighted_f1), 4),
        "macro_f1": round(float(macro_f1), 4),
        "macro_auroc": round(float(macro_auroc), 4),
        "classification_report": classification_report(
            y_test, y_pred, output_dict=True
        ),
        "confusion_matrix": confusion_matrix(y_test, y_pred).tolist(),
        "n_train": int(len(y_train)),
        "n_test": int(len(y_test)),
        "class_distribution": {
            str(k): int(v) for k, v in zip(*np.unique(y_train, return_counts=True))
        },
    }

    print("\n[METRICS]")
    print(f"  Weighted F1  : {weighted_f1:.4f}")
    print(f"  Macro F1     : {macro_f1:.4f}")
    print(f"  Macro AUROC  : {macro_auroc:.4f}")
    print(classification_report(y_test, y_pred, target_names=["LOW", "MOD", "SEVERE", "CRITICAL"]))

    return model, scaler, metrics


def load_current_metrics() -> dict | None:
    if METRICS_FILE.exists():
        with open(METRICS_FILE) as f:
            return json.load(f)
    return None


def gate_and_save(model, scaler, new_metrics: dict, force: bool = False):
    """Only overwrite production artifacts if new model beats current on macro_f1 AND macro_auroc."""
    current = load_current_metrics()
    if current and not force:
        curr_f1 = current.get("macro_f1", 0)
        curr_auroc = current.get("macro_auroc", 0)
        new_f1 = new_metrics["macro_f1"]
        new_auroc = new_metrics["macro_auroc"]

        if new_f1 <= curr_f1 and new_auroc <= curr_auroc:
            print(
                f"\n[GATE] New model ({new_f1=:.4f}, {new_auroc=:.4f}) does NOT beat current ({curr_f1=:.4f}, {curr_auroc=:.4f}). Artifacts NOT updated."
            )
            return False

        print(
            f"\n[GATE] New model ({new_f1=:.4f}, {new_auroc=:.4f}) beats current ({curr_f1=:.4f}, {curr_auroc=:.4f}). Updating production artifacts."
        )

    ARTIFACTS_DIR.mkdir(parents=True, exist_ok=True)
    METRICS_DIR.mkdir(parents=True, exist_ok=True)

    with open(PROD_MODEL, "wb") as f:
        pickle.dump(model, f)
    with open(PROD_SCALER, "wb") as f:
        pickle.dump(scaler, f)
    with open(METRICS_FILE, "w") as f:
        json.dump(new_metrics, f, indent=2)

    print(f"\n[SAVED] {PROD_MODEL}")
    print(f"[SAVED] {PROD_SCALER}")
    print(f"[SAVED] {METRICS_FILE}")
    return True


def main():
    parser = argparse.ArgumentParser(description="Train INDOFLOODS 4-class RandomForest")
    parser.add_argument("--dataset", required=True, help="Path to INDOFLOODS CSV")
    parser.add_argument("--test-size", type=float, default=0.2)
    parser.add_argument("--force", action="store_true", help="Skip gating, always save")
    args = parser.parse_args()

    X, y = load_dataset(args.dataset)
    print(f"[INFO] Class distribution: {dict(zip(*np.unique(y, return_counts=True)))}")

    classes = set(np.unique(y))
    expected = {0, 1, 2, 3}
    if not expected.issubset(classes):
        print(f"[WARN] Missing classes: {expected - classes}. Add CRITICAL examples to dataset.")

    X_train, X_test, y_train, y_test = train_test_split(
        X,
        y,
        test_size=args.test_size,
        stratify=y,
        random_state=42,
    )

    model, scaler, metrics = train_and_evaluate(X_train, X_test, y_train, y_test)
    gate_and_save(model, scaler, metrics, force=args.force)


if __name__ == "__main__":
    main()

