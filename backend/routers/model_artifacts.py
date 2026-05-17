"""
Model artifacts discovery, classification, and bundle management.
"""

import os
import joblib
from typing import Dict, Any

from .dependencies import (
    FLOOD_ARTIFACT_KEYWORDS,
    get_model_artifact_root,
    repo_relative_path,
    INDOFLOODS_STATE_KEYS,
)

# ============= ARTIFACT CLASSIFICATION =============
def classify_backend_artifact(filename: str) -> str:
    """Classify artifact based on filename."""
    lower_name = filename.lower()
    if "model" in lower_name:
        return "model"
    if "scaler" in lower_name:
        return "scaler"
    if "feature" in lower_name:
        return "features"
    return "artifact"

def read_model_artifact_preview(path: str) -> Any | None:
    """Read preview data from artifact file."""
    lower_name = os.path.basename(path).lower()

    try:
        if lower_name.endswith(".txt"):
            with open(path, "r", encoding="utf-8") as handle:
                return [line.strip() for line in handle if line.strip()]

        if "feature" in lower_name and lower_name.endswith(".pkl"):
            loaded = joblib.load(path)
            if isinstance(loaded, dict):
                return list(loaded.keys())
            if isinstance(loaded, (list, tuple)):
                return list(loaded)
            return type(loaded).__name__
    except Exception as exc:
        return {"error": str(exc)}

    return None

def discover_model_artifacts() -> list[Dict[str, Any]]:
    """Discover all model artifacts in artifact root directory."""
    artifacts: list[Dict[str, Any]] = []
    artifact_root = get_model_artifact_root()

    if not os.path.isdir(artifact_root):
        return artifacts

    for current_root, _dirs, filenames in os.walk(artifact_root):
        for filename in sorted(filenames):
            full_path = os.path.join(current_root, filename)
            lower_name = filename.lower()

            if not any(keyword in lower_name for keyword in FLOOD_ARTIFACT_KEYWORDS):
                continue

            artifact: Dict[str, Any] = {
                "name": filename,
                "relative_path": repo_relative_path(full_path),
                "storage_relative_path": os.path.relpath(full_path, artifact_root),
                "kind": classify_backend_artifact(filename),
                "size_bytes": os.path.getsize(full_path),
            }

            preview = read_model_artifact_preview(full_path)
            if preview is not None:
                artifact["preview"] = preview

            artifacts.append(artifact)

    return sorted(artifacts, key=lambda artifact: artifact["relative_path"])

# ============= ARTIFACT BUNDLING =============
def artifact_bundle_key(filename: str) -> str:
    """Extract bundle key from artifact filename."""
    stem, _ = os.path.splitext(filename.lower())

    if stem.endswith("_production_model"):
        return stem.removesuffix("_production_model")

    for suffix in ("_model", "_scaler", "_features"):
        if stem.endswith(suffix):
            return stem.removesuffix(suffix)

    return stem

def discover_model_bundles(artifacts: list[Dict[str, Any]]) -> Dict[str, Dict[str, Any]]:
    """Discover model bundles from artifact list."""
    bundles: Dict[str, Dict[str, Any]] = {}

    for artifact in artifacts:
        bundle_key = artifact_bundle_key(artifact["name"])
        bundle = bundles.setdefault(
            bundle_key,
            {
                "bundle_key": bundle_key,
                "model": None,
                "scaler": None,
                "features": [],
                "artifacts": [],
            },
        )

        bundle["artifacts"].append(artifact["relative_path"])

        if artifact["kind"] == "model":
            bundle["model"] = artifact["relative_path"]
        elif artifact["kind"] == "scaler":
            bundle["scaler"] = artifact["relative_path"]
        elif artifact["kind"] == "features":
            bundle["features"].append(artifact["relative_path"])

    for bundle in bundles.values():
        bundle["artifacts"].sort()
        bundle["features"].sort()
        bundle["is_complete"] = bool(bundle["model"] and bundle["scaler"])

    return dict(sorted(bundles.items()))
