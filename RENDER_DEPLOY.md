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

## Optional env vars

- `FLOOD_SOURCE_POLICY=OFFICIAL_VIEW_ONLY`
- `CORS_ORIGINS`

`CORS_ORIGINS` is usually not needed for the single-service deploy because the frontend and backend share the same origin.

## Local Docker check

```bash
docker build -t opsflood .
docker run --rm -p 10000:10000 -e OPENWEATHER_API_KEY=your_key opsflood
```

Then open `http://localhost:10000`.
