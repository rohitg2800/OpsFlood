from fastapi import APIRouter
import os

router = APIRouter()

# ---------------------------------------------------------------------------
# Resolve repo root so we can count model artifacts without importing app.py
# ---------------------------------------------------------------------------
_BACKEND_DIR = os.path.dirname(os.path.abspath(__file__))
_REPO_DIR = os.path.abspath(os.path.join(_BACKEND_DIR, os.pardir, os.pardir))
_ARTIFACTS_ROOT = os.path.join(_REPO_DIR, "artifacts", "dvc", "models")
_FLOOD_KEYWORDS = ("flood", "scaler", "feature", "indo")


def _count_artifacts() -> int:
    """Count model artifact files under the DVC artifacts store."""
    if not os.path.isdir(_ARTIFACTS_ROOT):
        return 0
    count = 0
    for _root, _dirs, files in os.walk(_ARTIFACTS_ROOT):
        for f in files:
            if any(kw in f.lower() for kw in _FLOOD_KEYWORDS):
                count += 1
    return count


def health() -> dict:
    """
    Return a lightweight health payload.

    Designed as a plain sync function (no FastAPI Request dependency)
    so it can be called directly from unit tests without spinning up
    the full app or hitting the database.
    """
    db_env_set = bool(
        os.environ.get("DATABASE_URL")
        or os.environ.get("NEON_DATABASE_URL")
        or os.environ.get("POSTGRES_URL")
    )
    ingestion_enabled = (
        os.environ.get("ENABLE_DATA_INGESTION_SCHEDULER", "").strip().lower()
        in {"1", "true", "yes", "on"}
    )

    return {
        "status": "ok",
        "version": "8.5",
        "database": {
            "configured": db_env_set,
            "note": "env var present" if db_env_set else "not configured",
        },
        "ingestion": {
            "scheduler_enabled": ingestion_enabled,
        },
        "artifact_count": _count_artifacts(),
    }


@router.get("/health", tags=["ops"])
def health_endpoint() -> dict:
    """GET /health — liveness / readiness check."""
    return health()
