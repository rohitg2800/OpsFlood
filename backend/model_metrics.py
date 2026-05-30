"""
model_metrics.py — OpsFlood ML Evaluation Utilities

Usage (inside train_with_real_data in app.py):

    from backend.model_metrics import evaluate_and_log_metrics   # package mode
    # OR
    from model_metrics import evaluate_and_log_metrics           # standalone mode

    evaluate_and_log_metrics(model, scaler, X_test, y_test)
"""

from sklearn.metrics import (
    classification_report,
    f1_score,
    accuracy_score,
    confusion_matrix,
    roc_auc_score,
)
import numpy as np
from typing import Any, Dict



CLASS_LABEL_MAP = {
    0: "LOW",
    1: "MODERATE",
    2: "SEVERE",
    3: "CRITICAL",
    "LOW": "LOW",
    "MODERATE": "MODERATE",
    "SEVERE": "SEVERE",
    "CRITICAL": "CRITICAL",
}
CLASS_NAMES = ["LOW", "MODERATE", "SEVERE", "CRITICAL"]


def evaluate_and_log_metrics(
    model: Any,
    scaler: Any,
    X_test: np.ndarray,
    y_test: np.ndarray,
    model_name: str = "model",
    class_names: list[str] = CLASS_NAMES,
) -> Dict[str, Any]:
    """
    Evaluate a trained flood model and print F1, Accuracy, and full classification report.

    Returns a dict with:
        - weighted_f1      : weighted-average F1 score (float)
        - macro_f1         : macro-average F1 score (float)
        - per_class_f1     : dict of {class_name: f1_score}
        - accuracy         : overall accuracy (float)
        - confusion_matrix : 2D confusion matrix (list of lists)
        - report           : full sklearn classification_report string
    """
    X_test_scaled = scaler.transform(X_test)
    y_pred = model.predict(X_test_scaled)
    y_proba = None
    try:
        y_proba = model.predict_proba(X_test_scaled)
    except Exception:
        y_proba = None


    weighted_f1 = round(f1_score(y_test, y_pred, average="weighted"), 4)
    macro_f1    = round(f1_score(y_test, y_pred, average="macro"), 4)
    per_f1_raw  = f1_score(y_test, y_pred, average=None)
    accuracy    = round(accuracy_score(y_test, y_pred), 4)
    labels = sorted(set(np.unique(y_test)).union(set(np.unique(y_pred))))
    cm = confusion_matrix(y_test, y_pred, labels=labels).tolist()
    classes = list(getattr(model, "classes_", labels))
    per_class_f1 = {
        CLASS_LABEL_MAP.get(cls, str(cls)): round(float(score), 4)
        for cls, score in zip(classes, per_f1_raw)
    }

    report_target_names = [CLASS_LABEL_MAP.get(label, str(label)) for label in labels]

    report_str = classification_report(
        y_test,
        y_pred,
        labels=labels,
        target_names=report_target_names,
        zero_division=0,
    )

    # ── Macro AUROC (one-vs-rest) ────────────────────────────────────────────
    macro_auroc = None
    if y_proba is not None:
        try:
            macro_auroc = roc_auc_score(
                y_test,
                y_proba,
                multi_class="ovr",
                average="macro",
            )
        except Exception as e:
            print(f"[WARN] AUROC computation failed: {e}")


    # ── Console output (visible in server logs) ──────────────────────────────
    print("\n" + "=" * 55)
    print("  OpsFlood Model Evaluation Report")
    print("=" * 55)
    print(f"  Accuracy         : {accuracy * 100:.2f}%")
    print(f"  Weighted F1      : {weighted_f1:.4f}")
    print(f"  Macro F1         : {macro_f1:.4f}")
    print("  Per-Class F1:")
    for label, score in per_class_f1.items():
        print(f"    {label:<12}: {score:.4f}")
    print("\n  Full Classification Report:")
    print(report_str)
    print("=" * 55 + "\n")

    metrics = {
        "weighted_f1": weighted_f1,
        "macro_f1": macro_f1,
        "macro_auroc": round(float(macro_auroc), 4) if macro_auroc is not None else None,
        "per_class_f1": per_class_f1,
        "accuracy": accuracy,
        "confusion_matrix": cm,
        "report": report_str,
    }

    # ── Persist metrics to artifacts/metrics/ ────────────────────────────────
    try:
        import json
        from pathlib import Path

        METRICS_DIR = Path("artifacts/metrics")
        METRICS_DIR.mkdir(parents=True, exist_ok=True)
        metrics_path = METRICS_DIR / f"{model_name}_metrics.json"
        with open(metrics_path, "w") as f:
            json.dump(metrics, f, indent=2, default=str)
        print(f"[METRICS] Saved to {metrics_path}")
    except Exception as e:
        print(f"[WARN] Metrics JSON persistence failed (non-fatal): {e}")

    # ── Optional Postgres persistence (non-fatal) ────────────────────────────
    # FIX: PostgresOperationalStore has no .execute() method.
    # Use store.connection() context manager to get a raw psycopg cursor,
    # exactly the same pattern as save_prediction() / save_audit_log().
    try:
        import json as _json
        from backend.postgres_store import PostgresOperationalStore

        store = PostgresOperationalStore()
        # initialize() creates the core schema and sets store.ready = True
        store.initialize()

        if not store.ready:
            raise RuntimeError("Postgres not ready: " + (store.last_error or "unknown"))

        n_test = int(len(y_test)) if y_test is not None else None

        CREATE_TABLE_SQL = """
            CREATE TABLE IF NOT EXISTS model_metrics (
                id           SERIAL PRIMARY KEY,
                model_name   TEXT NOT NULL,
                recorded_at  TIMESTAMPTZ DEFAULT NOW(),
                weighted_f1  FLOAT,
                macro_f1     FLOAT,
                macro_auroc  FLOAT,
                n_train      INT,
                n_test       INT,
                raw_json     JSONB
            );
        """

        INSERT_SQL = """
            INSERT INTO model_metrics
                (model_name, weighted_f1, macro_f1, macro_auroc, n_train, n_test, raw_json)
            VALUES (%s, %s, %s, %s, %s, %s, %s)
        """

        with store.connection() as conn:
            with conn.cursor() as cur:
                cur.execute(CREATE_TABLE_SQL)
                cur.execute(
                    INSERT_SQL,
                    (
                        model_name,
                        metrics.get("weighted_f1"),
                        metrics.get("macro_f1"),
                        metrics.get("macro_auroc"),
                        None,   # n_train not known here
                        n_test,
                        _json.dumps(metrics),
                    ),
                )
        print("[METRICS] Persisted to Postgres model_metrics table")
    except Exception as e:
        print(f"[WARN] DB persistence failed (non-fatal): {e}")

    return metrics
