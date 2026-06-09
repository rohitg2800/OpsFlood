"""
Model artifacts discovery, classification, bundle management, and versioning.
"""

import hashlib
import os
import time
import joblib
from datetime import datetime, timezone
from typing import Dict, Any

from fastapi import APIRouter
from fastapi.responses import JSONResponse

from .dependencies import (
    FLOOD_ARTIFACT_KEYWORDS,
    get_model_artifact_root,
    repo_relative_path,
    INDOFLOODS_STATE_KEYS,
    REPO_DIR,
)

router = APIRouter(prefix='/api/model-artifacts', tags=['model-artifacts'])

# ============= ARTIFACT CLASSIFICATION =============
def classify_backend_artifact(filename: str) -> str:
    lower_name = filename.lower()
    if 'model' in lower_name:
        return 'model'
    if 'scaler' in lower_name:
        return 'scaler'
    if 'feature' in lower_name:
        return 'features'
    return 'artifact'


def read_model_artifact_preview(path: str) -> Any | None:
    lower_name = os.path.basename(path).lower()
    try:
        if lower_name.endswith('.txt'):
            with open(path, 'r', encoding='utf-8') as handle:
                return [line.strip() for line in handle if line.strip()]
        if 'feature' in lower_name and lower_name.endswith('.pkl'):
            loaded = joblib.load(path)
            if isinstance(loaded, dict):
                return list(loaded.keys())
            if isinstance(loaded, (list, tuple)):
                return list(loaded)
            return type(loaded).__name__
    except Exception as exc:
        return {'error': str(exc)}
    return None


def _sha256_file(path: str, chunk: int = 65536) -> str:
    """Return hex SHA-256 of a file without loading it fully into memory."""
    h = hashlib.sha256()
    try:
        with open(path, 'rb') as fh:
            while buf := fh.read(chunk):
                h.update(buf)
        return h.hexdigest()
    except Exception:
        return ''


def enrich_artifact_metadata(artifact: Dict[str, Any], full_path: str) -> Dict[str, Any]:
    """
    Adds versioning fields to an artifact dict in-place:
      - sha256          : content fingerprint (detects weight changes)
      - mtime_utc       : last-modified ISO timestamp
      - version_tag     : human-readable YYYYMMDD-HHMMSS derived from mtime
    """
    try:
        mtime = os.path.getmtime(full_path)
        dt    = datetime.fromtimestamp(mtime, tz=timezone.utc)
        artifact['mtime_utc']   = dt.isoformat()
        artifact['version_tag'] = dt.strftime('%Y%m%d-%H%M%S')
    except Exception:
        artifact['mtime_utc']   = None
        artifact['version_tag'] = 'unknown'

    artifact['sha256'] = _sha256_file(full_path)
    return artifact


def discover_model_artifacts() -> list[Dict[str, Any]]:
    """Discover all model artifacts in artifact root directory."""
    artifacts: list[Dict[str, Any]] = []
    artifact_root = get_model_artifact_root()

    if not os.path.isdir(artifact_root):
        return artifacts

    for current_root, _dirs, filenames in os.walk(artifact_root):
        for filename in sorted(filenames):
            full_path  = os.path.join(current_root, filename)
            lower_name = filename.lower()

            if not any(keyword in lower_name for keyword in FLOOD_ARTIFACT_KEYWORDS):
                continue

            artifact: Dict[str, Any] = {
                'name':                   filename,
                'relative_path':          repo_relative_path(full_path),
                'storage_relative_path':  os.path.relpath(full_path, artifact_root),
                'kind':                   classify_backend_artifact(filename),
                'size_bytes':             os.path.getsize(full_path),
            }

            enrich_artifact_metadata(artifact, full_path)

            preview = read_model_artifact_preview(full_path)
            if preview is not None:
                artifact['preview'] = preview

            artifacts.append(artifact)

    return sorted(artifacts, key=lambda a: a['relative_path'])


def discover_legacy_artifacts_outside_store() -> list[str]:
    artifact_root       = os.path.abspath(get_model_artifact_root())
    repo_artifacts_root = os.path.abspath(os.path.join(REPO_DIR, 'artifacts'))
    if not os.path.isdir(repo_artifacts_root):
        return []

    ignored: list[str] = []
    for current_root, _dirs, filenames in os.walk(repo_artifacts_root):
        current_root_abs = os.path.abspath(current_root)
        if current_root_abs == artifact_root or current_root_abs.startswith(
                f'{artifact_root}{os.sep}'):
            continue
        for filename in sorted(filenames):
            lower_name = filename.lower()
            if not any(keyword in lower_name for keyword in FLOOD_ARTIFACT_KEYWORDS):
                continue
            ignored.append(repo_relative_path(
                os.path.join(current_root_abs, filename)))
    return sorted(ignored)


# ============= ARTIFACT BUNDLING =============
def artifact_bundle_key(filename: str) -> str:
    stem, _ = os.path.splitext(filename.lower())
    if stem.endswith('_production_model'):
        return stem.removesuffix('_production_model')
    for suffix in ('_model', '_scaler', '_features'):
        if stem.endswith(suffix):
            return stem.removesuffix(suffix)
    return stem


def discover_model_bundles(artifacts: list[Dict[str, Any]]) -> Dict[str, Dict[str, Any]]:
    """Discover model bundles. Each bundle now carries a version_tag."""
    bundles: Dict[str, Dict[str, Any]] = {}

    for artifact in artifacts:
        bundle_key = artifact_bundle_key(artifact['name'])
        bundle = bundles.setdefault(
            bundle_key,
            {
                'bundle_key': bundle_key,
                'model':      None,
                'scaler':     None,
                'features':   [],
                'artifacts':  [],
                'version_tag': None,
            },
        )

        bundle['artifacts'].append(artifact['relative_path'])

        if artifact['kind'] == 'model':
            bundle['model']       = artifact['relative_path']
            bundle['version_tag'] = artifact.get('version_tag')  # model file drives version
            bundle['sha256']      = artifact.get('sha256')
        elif artifact['kind'] == 'scaler':
            bundle['scaler'] = artifact['relative_path']
        elif artifact['kind'] == 'features':
            bundle['features'].append(artifact['relative_path'])

    for bundle in bundles.values():
        bundle['artifacts'].sort()
        bundle['features'].sort()
        bundle['is_complete'] = bool(bundle['model'] and bundle['scaler'])

    return dict(sorted(bundles.items()))


# ============= API ENDPOINTS =============
@router.get('/versions')
def list_model_versions():
    """
    Returns all discovered model artifacts with versioning metadata:
      - sha256 fingerprint (detects weight file changes)
      - version_tag (YYYYMMDD-HHMMSS from file mtime)
      - bundle completeness (model + scaler both present?)
    """
    artifacts = discover_model_artifacts()
    bundles   = discover_model_bundles(artifacts)
    return JSONResponse({
        'generated_at': datetime.now(timezone.utc).isoformat(),
        'artifact_count': len(artifacts),
        'bundle_count':   len(bundles),
        'bundles':        bundles,
        'artifacts':      artifacts,
    })
