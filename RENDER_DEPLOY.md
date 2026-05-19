# Render Docker Deployment

This repo is now configured to run on Render with a Docker web service connected to a Neon serverless PostgreSQL database.

## What gets deployed

- **Web Service**: `frontend/` is built in the Docker image with Node. `backend/app.py` serves the built SPA from `frontend/dist`.
- **Neon PostgreSQL Database**: Serverless PostgreSQL with connection pooling for predictions, telemetry snapshots, and audit logs.
- Single root `Dockerfile` handles the entire application.

## Render setup

Use the included [render.yaml](render.yaml) blueprint with a Neon database connection.

### Web Service (`opsflood`)
- Environment: `Docker`
- Root directory: repository root (`.`)
- Docker context: `.`
- Dockerfile path: `./Dockerfile`
- Health check path: `/health`
- Connected to Neon database via `DATABASE_URL` environment variable

## Setting up Neon database

### Step 1: Create Neon account and database

1. Go to [Neon Console](https://console.neon.tech)
2. Sign up or log in
3. Click **Create a new project**
4. Choose:
   - **PostgreSQL version**: 15
   - **Region**: Select closest to your Render region (e.g., us-east-1)
   - **Database name**: `opsflood_db` (optional, can use default `neondb`)
5. Click **Create project**

### Step 2: Get your connection string

1. In Neon console, click your project
2. Click **Connection string** tab
3. Select **Connection pooling** (important for serverless)
4. Select **Pooler** (not Direct)
5. Copy the connection string (looks like `postgresql://user:password@host.neon.tech/opsflood_db?sslmode=require`)

### Step 3: Deploy to Render

1. Push this repository to GitHub
2. Go to [Render Dashboard](https://dashboard.render.com)
3. Click **Create** → **Create from YAML**
4. Select this GitHub repository
5. Render will read [render.yaml](render.yaml) and create the web service
6. Set environment variables in Render dashboard:
   - **`DATABASE_URL`**: Paste your Neon connection pooling string from step 2
   - **`NEON_DATABASE_API`**: Paste your Neon HTTP REST API endpoint (e.g., `https://ep-floral-hall-aogcv3y0.apirest.c-2.ap-southeast-1.aws.neon.tech/neondb/rest/v1`)
   - **`NEON_API_KEY`**: Paste your Neon API authentication key
   - **`OPENWEATHER_API_KEY`**: Your OpenWeather API key
7. Commit and push to trigger auto-deploy

The schema (predictions, telemetry_snapshots, audit_logs tables) will be created automatically on first connection.

## CI gate before auto-deploy

Keep Render `autoDeploy: true`, but require the GitHub Actions `CI` workflow to pass before changes merge into `main`.

That keeps the current Docker deploy flow intact while still validating:

- backend tests
- frontend production build
- container build

## Required env vars

- `OPENWEATHER_API_KEY` — Your OpenWeather API key (set in Render dashboard)
- `DATABASE_URL` — Your Neon connection pooling string (set in Render dashboard)
- `NEON_DATABASE_API` — Your Neon HTTP REST API endpoint (set in Render dashboard)
- `NEON_API_KEY` — Your Neon API authentication key (set in Render dashboard)

## Optional env vars

- `FLOOD_SOURCE_POLICY=OFFICIAL_VIEW_ONLY`
- `CORS_ORIGINS`
- `MODEL_ARTIFACTS_DIR=artifacts/dvc/models`
- `MODEL_ARTIFACTS_BACKEND=DVC`
- `ENABLE_DATA_INGESTION_SCHEDULER=0` (recommended for free-tier web services)
- `DATA_INGESTION_INTERVAL_MINUTES=60`

`CORS_ORIGINS` is usually not needed for the single-service deploy because the frontend and backend share the same origin.

## Database management (Neon)

### Accessing your Neon database

1. **From Neon Console**:
   - Go to [Neon Console](https://console.neon.tech)
   - Click your project
   - Find the **SQL Editor** or **Connection string** tab
   - Use **Connection pooling** endpoint for serverless connections

2. **Database tables created automatically**:
   - `predictions` — Flood prediction records with confidence scores
   - `telemetry_snapshots` — System telemetry and monitoring data
   - `audit_logs` — Event audit trail for compliance

3. **Local database connection (during development)**:
   ```bash
   # Use the connection pooling string from Neon console
   psql "postgresql://user:password@host.neon.tech/opsflood_db?sslmode=require"
   ```

4. **Visual database management**:
   - Use Neon's built-in SQL editor in the console
   - Or connect with DBeaver, pgAdmin using the connection string

### Benefits of Neon

- **Serverless**: No idle charges, scales automatically
- **Connection pooling**: Built-in PgBouncer for high connection volumes
- **Free tier**: Generous free tier with 3GB storage
- **Branching**: Create isolated database branches for testing
- **Auto-suspend**: Pauses databases after 5 min of inactivity (free tier)

### Monitoring usage

- Neon free tier: 3GB storage, 3 projects, 10 branches
- Monitor in Neon console under **Project settings** → **Billing**
- Upgrade to paid tier if you need more storage or higher limits

## Neon HTTP REST API

Neon provides an HTTP REST API for serverless database queries. You can use this as an alternative to direct PostgreSQL connections.

### Getting your API credentials

1. Go to [Neon Console](https://console.neon.tech)
2. Click **API keys** in the left sidebar
3. Create a new API key and copy it
4. For `NEON_DATABASE_API`, use the REST API endpoint provided in your Neon project settings (format: `https://ep-*.apirest.c-*.region.aws.neon.tech/database-name/rest/v1`)

### Using the REST API in your backend

Set these environment variables in Render:
- `NEON_DATABASE_API` — Your HTTP REST API endpoint
- `NEON_API_KEY` — Your Neon API authentication key

Example API usage:
```bash
# Query data via HTTP
curl -X POST "https://ep-your-endpoint.apirest.c-2.ap-southeast-1.aws.neon.tech/neondb/rest/v1/query" \
  -H "Authorization: Bearer YOUR_NEON_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "query": "SELECT * FROM predictions LIMIT 10"
  }'
```

### When to use REST API vs PostgreSQL connection

- **PostgreSQL connection** (DATABASE_URL): Better for frequent/transactional queries, connection pooling
- **REST API**: Better for serverless functions, AWS Lambda, edge computing, stateless APIs

Your backend currently uses PostgreSQL connection pooling (recommended for web services). The REST API is available if you need serverless-optimized queries in the future.

## GitHub Actions: Neon PR Branching

This project includes a GitHub Actions workflow (`.github/workflows/neon-branch.yml`) that automatically creates isolated Neon database branches for pull requests. This allows testing database schema changes safely without affecting production.

### How it works

1. **On PR open/update**: Creates a temporary Neon branch named `preview/pr-{number}-{branch-name}`
2. **Test in isolation**: Run tests and database migrations against the isolated branch
3. **On PR close**: Automatically deletes the temporary branch (expires in 2 weeks if not closed)

### Setup GitHub Secrets and Variables

1. Go to your GitHub repository **Settings** → **Secrets and variables** → **Actions**

2. Add the following **Repository Secrets**:
   - `NEON_API_KEY` — Your Neon API key (from [Neon Account Settings](https://console.neon.tech/app/settings/api-keys))

3. Add the following **Repository Variables**:
   - `NEON_PROJECT_ID` — Your Neon project ID (from [Neon Console](https://console.neon.tech) → Project settings)

### Using the Neon PR branch in tests

The workflow outputs the temporary database URL. You can uncomment the example steps in `.github/workflows/neon-branch.yml` to:

```yaml
- name: Run Migrations
  run: npm run db:migrate
  env:
    DATABASE_URL: "${{ steps.create_neon_branch.outputs.db_url_with_pooler }}"
```

Or run schema diff checks to see what changed:

```yaml
- name: Post Schema Diff Comment to PR
  uses: neondatabase/schema-diff-action@v1
  with:
    project_id: ${{ vars.NEON_PROJECT_ID }}
    compare_branch: preview/pr-${{ github.event.number }}-${{ needs.setup.outputs.branch }}
    api_key: ${{ secrets.NEON_API_KEY }}
```

### Benefits

- **Isolated testing**: Each PR gets its own database
- **Safe schema changes**: Test migrations without affecting production
- **Automatic cleanup**: Branches auto-delete when PR closes
- **Free tier compatible**: Uses Neon's branch feature included in free tier

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

## Rollback strategy (bad model / bad deploy)

This deployment serves ML artifacts from a versioned artifact store under:

- `artifacts/dvc/models/` (default)

and can be redirected via Render env vars:

- `MODEL_ARTIFACTS_DIR` (path to an artifact directory)
- `MODEL_ARTIFACTS_BACKEND` (defaults to `DVC`)

### Goal

If a new deploy introduces a “bad model” (worse predictions, broken deserialization, wrong features), rollback quickly by switching to a known-good artifact set without needing to rebuild the whole app.

### Strategy A (recommended): pin a known-good DVC revision + switch artifacts dir

1. Choose the last known-good artifact revision
   - In DVC terms, keep a revision/commit hash for the model artifacts that were validated.
   - Record it in a file in the repo (example: `artifacts/dvc/models/.pinned_revision`) or in your release notes.

2. Ensure the pinned artifact directory is present in the deployed image
   - Common options:
     - Keep multiple pinned directories in the repo, e.g.:
       - `artifacts/dvc/models/_pinned/rev_<HASH>/...`
     - OR fetch artifacts at build/start time from DVC using the pinned revision.

3. Rollback on Render (fast switch)
   - In Render dashboard for the web service `opsflood`, update:
     - `MODEL_ARTIFACTS_DIR` → the pinned directory for the last-good revision
   - Trigger a redeploy (or restart the service if Render supports it for env changes).

4. Verify rollback
   - Confirm the API sees the expected artifact set:
     - `curl https://<your-service>.onrender.com/model-artifacts`
   - Smoke test prediction behavior:
     - `curl -X POST https://<your-service>.onrender.com/predict ...`
   - Expected behavior:
     - If artifacts are present: algorithm should be ML-based.
     - If artifacts are missing/unavailable: backend returns `Heuristic Fallback – NO ML` with `probabilities: {}` (no fabricated ML probabilities).

### Strategy B: git rollback (revert commit + redeploy)

If the bad change is not only the model artifacts but also code/config:

1. Revert the GitHub commit that introduced the bad behavior (or re-deploy the previous tag).
2. Let Render auto-deploy / redeploy from YAML.
3. Keep `MODEL_ARTIFACTS_DIR` pointed at the default `artifacts/dvc/models/` unless you also need to swap artifact sets.

### Strategy C: keep “previous production model” artifact alongside the new one

If you use an artifact promotion flow (train → validate → promote), ensure your repo always includes:

- current production artifacts (default)
- previous production artifacts (rollback candidate)

Then rollback is just switching `MODEL_ARTIFACTS_DIR` to the previous production directory.

### Practical checklist for incident response

- [ ] Capture symptom + time window (did latency spike, did predictions degrade, did errors appear?)
- [ ] Confirm artifact set in production via `/model-artifacts`
- [ ] Switch `MODEL_ARTIFACTS_DIR` to last-good pinned revision (Strategy A)
- [ ] Redeploy/restart Render service
- [ ] Run one smoke `/predict` call and confirm ML vs `Heuristic Fallback – NO ML`
- [ ] After service is stable, investigate root cause (training data, feature drift, label alignment, etc.)

