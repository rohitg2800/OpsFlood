## Model Artifact Store

Model binaries and feature manifests are stored under `artifacts/dvc/models/` instead of inside `backend/`.

The backend resolves this directory by default and can be pointed at another mounted store with:

- `MODEL_ARTIFACTS_DIR`
- `MODEL_ARTIFACTS_BACKEND` (defaults to `DVC`)

If you wire this repo into a full DVC workflow later, this directory is the one to track and sync with remote storage.
