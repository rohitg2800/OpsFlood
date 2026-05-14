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
)
import numpy as np
from typing import Any, Dict


CLASS_NAMES = ["LOW", "MODERATE", "SEVERE"]


def evaluate_and_log_metrics(
    model: Any,
    scaler: Any,
    X_test: np.ndarray,
    y_test: np.ndarray,
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

    weighted_f1 = round(f1_score(y_test, y_pred, average="weighted"), 4)
    macro_f1    = round(f1_score(y_test, y_pred, average="macro"), 4)
    per_f1_raw  = f1_score(y_test, y_pred, average=None)
    accuracy    = round(accuracy_score(y_test, y_pred), 4)
    cm          = confusion_matrix(y_test, y_pred).tolist()

    classes = list(getattr(model, "classes_", range(len(per_f1_raw))))
    label_map = {0: "LOW", 1: "MODERATE", 2: "SEVERE"}
    per_class_f1 = {
        label_map.get(cls, str(cls)): round(float(score), 4)
        for cls, score in zip(classes, per_f1_raw)
    }

    report_str = classification_report(
        y_test,
        y_pred,
        target_names=class_names,
        zero_division=0,
    )

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

    return {
        "weighted_f1": weighted_f1,
        "macro_f1": macro_f1,
        "per_class_f1": per_class_f1,
        "accuracy": accuracy,
        "confusion_matrix": cm,
        "report": report_str,
    }
