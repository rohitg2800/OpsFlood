# Render Docker Deployment

This repo is now configured to run as a single Render web service.

## What gets deployed

- `frontend/` is built in the Docker image with Node.
- `backend/app.py` serves the built SPA from `frontend/dist`.
- Render only needs one web service using the root `Dockerfile`.

## Render setup

Use the included [render.yaml](render.yaml) blueprint or create the service manually with these values:

- Environment: `Docker`
- Dockerfile path: `./Dockerfile`
- Health check path: `/health`

## Required env vars

- `OPENWEATHER_API_KEY`
- `DATABASE_URL`

## Optional env vars

- `FLOOD_SOURCE_POLICY=OFFICIAL_VIEW_ONLY`
- `CORS_ORIGINS`
- `MODEL_ARTIFACTS_DIR=artifacts/dvc/models`
- `MODEL_ARTIFACTS_BACKEND=DVC`
- `ENABLE_DATA_INGESTION_SCHEDULER=1`
- `DATA_INGESTION_INTERVAL_MINUTES=60`

`CORS_ORIGINS` is usually not needed for the single-service deploy because the frontend and backend share the same origin.

## Local Docker check

```bash
docker build -t opsflood .
docker run --rm -p 10000:10000 -e OPENWEATHER_API_KEY=your_key opsflood
```

Then open `http://localhost:10000`.
