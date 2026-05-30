"""Verify deployed model artifacts match an expected pinned revision/hash.

How this is meant to be used:
- During deploy, set env vars:
  - MODEL_ARTIFACTS_EXPECTED_SHA256=<sha256-of-model-pkl-and-scaler>
  - MODEL_ARTIFACTS_EXPECTED_FILES=<comma-separated expected relative paths>

The verifier computes a deterministic digest over the configured artifact files:
- For each file: sha256(file_bytes)
- Then sha256(concat(sorted(rel_path|file_sha256)))

This allows an operator to confirm the running container is using the exact artifact set.

Notes:
- This does not require DVC to be present at runtime.
- Use DVC to compute the expected hashes offline, then paste the expected value into
  the Render env var.
"""

from __future__ import annotations

import hashlib
import os
from dataclasses import dataclass
from typing import Dict, Iterable, List, Tuple

# Reuse the same resolution logic as the backend so the paths match.
try:
    from backend.app import (
        get_model_artifact_root,
        resolve_model_artifact_path,
        DEFAULT_MODEL_ARTIFACT_FILES,
        REPO_DIR,
    )
except Exception:  # pragma: no cover
    # Fallback for direct script runs from repo root
    from app import (  # type: ignore
        get_model_artifact_root,
        resolve_model_artifact_path,
        DEFAULT_MODEL_ARTIFACT_FILES,
        REPO_DIR,
    )


def sha256_file(path: str, chunk_size: int = 1024 * 1024) -> str:
    h = hashlib.sha256()
    with open(path, "rb") as f:
        while True:
            chunk = f.read(chunk_size)
            if not chunk:
                break
            h.update(chunk)
    return h.hexdigest()


def compute_artifact_set_digest(file_rel_paths: Iterable[str]) -> Tuple[str, Dict[str, str]]:
    """Return (set_digest, per_file_sha256).

    file_rel_paths are resolved the same way the backend resolves artifacts.
    """
    per_file: Dict[str, str] = {}
    for rel in sorted({p.strip() for p in file_rel_paths if str(p).strip()}):
        resolved_path = resolve_model_artifact_path(rel)
        per_file[rel] = sha256_file(resolved_path)

    material = "".join(f"{rel}|{per_file[rel]}\n" for rel in sorted(per_file.keys()))
    set_digest = hashlib.sha256(material.encode("utf-8")).hexdigest()
    return set_digest, per_file


def parse_env_list(name: str) -> List[str]:
    raw = os.getenv(name, "").strip()
    if not raw:
        return []
    return [p.strip() for p in raw.split(",") if p.strip()]


def main() -> int:
    expected_sha = (os.getenv("MODEL_ARTIFACTS_EXPECTED_SHA256") or "").strip().lower()
    if not expected_sha:
        print("MODEL_ARTIFACTS_EXPECTED_SHA256 is not set; nothing to verify.")
        return 2

    configured_files = parse_env_list("MODEL_ARTIFACTS_EXPECTED_FILES")
    if not configured_files:
        # Default to the backend's primary model+scaler names
        configured_files = list(DEFAULT_MODEL_ARTIFACT_FILES)

    # Ensure artifact root exists (backend creates it).
    artifact_root = get_model_artifact_root()

    set_digest, per_file = compute_artifact_set_digest(configured_files)

    ok = set_digest.lower() == expected_sha
    report = {
        "status": "ok" if ok else "mismatch",
        "artifact_root": artifact_root,
        "expected": expected_sha,
        "actual": set_digest,
        "files": {rel: per_file[rel] for rel in sorted(per_file.keys())},
    }
    print(report)

    return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(main())

