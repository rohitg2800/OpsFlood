from fastapi import APIRouter
import os
import sys

router = APIRouter()

_BACKEND_DIR = os.path.dirname(os.path.abspath(__file__))
_REPO_DIR = os.path.abspath(os.path.join(_BACKEND_DIR, os.pardir, os.pardir))
_ARTIFACTS_ROOT = os.path.join(_REPO_DIR, "artifacts", "dvc", "models")
_FLOOD_KEYWORDS = ("flood", "scaler", "feature", "indo")


def _count_artifacts() -> int:
    if not os.path.isdir(_ARTIFACTS_ROOT):
        return 0
    count = 0
    for _root, _dirs, files in os.walk(_ARTIFACTS_ROOT):
        for f in files:
            if any(kw in f.lower() for kw in _FLOOD_KEYWORDS):
                count += 1
    return count


def _glofas_cached_count() -> int:
    """Read GLOFAS_STATION_CACHE length from app module without circular import."""
    for mod_name in ("backend.app", "app"):
        mod = sys.modules.get(mod_name)
        if mod is not None:
            cache = getattr(mod, "GLOFAS_STATION_CACHE", None)
            if isinstance(cache, list):
                return len(cache)
    return 0


def health() -> dict:
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
        "version": "1.1.0",
        "database": {
            "configured": db_env_set,
            "note": "env var present" if db_env_set else "not configured",
        },
        "ingestion": {
            "scheduler_enabled": ingestion_enabled,
        },
        "artifact_count": _count_artifacts(),
        "glofas_stations_cached": _glofas_cached_count(),
    }


@router.get("/health", tags=["ops"])
def health_endpoint() -> dict:
    """GET /health — liveness / readiness check."""
    return health()
