# Render Docker Deployment

This repo is now configured to run on Render with a Docker web service and PostgreSQL database.

## What gets deployed

- **Web Service**: `frontend/` is built in the Docker image with Node. `backend/app.py` serves the built SPA from `frontend/dist`.
- **PostgreSQL Database**: Operational store for predictions, telemetry snapshots, and audit logs (automatically provisioned via render.yaml).
- Single root `Dockerfile` handles the entire application.

## Render setup

Use the included [render.yaml](render.yaml) blueprint which automatically provisions:

1. **PostgreSQL Service** (`opsflood-db`)
   - Database: `opsflood_db`
   - PostgreSQL 15
   - Free tier
   - Region: Oregon

2. **Web Service** (`opsflood`)
   - Environment: `Docker`
   - Root directory: repository root (`.`)
   - Docker context: `.`
   - Dockerfile path: `./Dockerfile`
   - Health check path: `/health`
   - Linked to PostgreSQL database via `DATABASE_URL` environment variable
   - Depends on database service startup

## Deploying with render.yaml blueprint

1. Push this repository to GitHub
2. Go to [Render Dashboard](https://dashboard.render.com)
3. Click **Create** → **Create from YAML**
4. Select this GitHub repository
5. Render will automatically read [render.yaml](render.yaml) and create both the PostgreSQL service and web service
6. Set `OPENWEATHER_API_KEY` in the Render dashboard (required for weather data)
7. Commit and push changes to trigger auto-deploy (or manually deploy from Render dashboard)

The blueprint automatically:
- Provisions a PostgreSQL 15 database with schemas for predictions, telemetry, and audit logs
- Configures the web service to connect via `DATABASE_URL`
- Sets up service dependencies so the database is ready before the web service starts

## CI gate before auto-deploy

Keep Render `autoDeploy: true`, but require the GitHub Actions `CI` workflow to pass before changes merge into `main`.

That keeps the current Docker deploy flow intact while still validating:

- backend tests
- frontend production build
- container build

## Required env vars

- `OPENWEATHER_API_KEY` — Your OpenWeather API key (set manually in Render dashboard)
- `DATABASE_URL` — **Auto-provisioned** by the PostgreSQL service in render.yaml (no manual setup needed)

## Optional env vars

- `FLOOD_SOURCE_POLICY=OFFICIAL_VIEW_ONLY`
- `CORS_ORIGINS`
- `MODEL_ARTIFACTS_DIR=artifacts/dvc/models`
- `MODEL_ARTIFACTS_BACKEND=DVC`
- `ENABLE_DATA_INGESTION_SCHEDULER=0` (recommended for free-tier web services)
- `DATA_INGESTION_INTERVAL_MINUTES=60`

`CORS_ORIGINS` is usually not needed for the single-service deploy because the frontend and backend share the same origin.

## Database management

### Accessing your PostgreSQL database

After deployment, you can access your PostgreSQL database:

1. **From Render Dashboard**:
   - Go to the `opsflood-db` service in your Render dashboard
   - Find the **External Database URL** (looks like `postgresql://user:pass@host:port/opsflood_db`)
   - Use this URL with any PostgreSQL client (psql, DBeaver, pgAdmin, etc.)

2. **Database tables created automatically**:
   - `predictions` — Flood prediction records with confidence scores
   - `telemetry_snapshots` — System telemetry and monitoring data
   - `audit_logs` — Event audit trail for compliance

3. **Local database connection (during development)**:
   ```bash
   # Connect to the remote Render database from your local machine
   psql postgresql://user:password@host.render.com:5432/opsflood_db
   ```

### Monitoring database usage

- Render free-tier PostgreSQL: 1GB storage limit
- Monitor usage in Render dashboard under the `opsflood-db` service
- If you exceed limits, upgrade to a paid tier or implement data archival

## Local Docker check

```bash
docker build -t opsflood .
docker run --rm -p 10000:10000 -e OPENWEATHER_API_KEY=your_key opsflood
```

Then open `http://localhost:10000`.

## If the Render URL is not showing the app

1. Confirm the service type is **Web Service** (not Static Site or Background Worker).
2. Confirm runtime is **Docker** and Dockerfile path is exactly `./Dockerfile`.
3. Confirm the service is connected to your repository (the blueprint no longer hard-codes a different repo).
4. Open Render logs and verify container startup reaches:
   - `Application startup complete`
5. Check `https://<your-service>.onrender.com/health`:
   - If this fails, deployment/startup is broken.
   - If this works but `/` is not the app, the wrong root directory/runtime was selected.
