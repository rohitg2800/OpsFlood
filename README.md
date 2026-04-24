# INDIA_FLOODS OPS

INDIA_FLOODS OPS is a full-stack flood readiness and flood-risk analysis platform built with FastAPI, React, TypeScript, and Vite. It combines manual hydrology inputs, state-aware severity thresholds, live or policy-bounded telemetry, weather intelligence, and PostgreSQL-backed operational archives into a single demo-ready command console.

## What the app does

- Generates flood-risk predictions across four severity bands: `LOW`, `MODERATE`, `SEVERE`, and `CRITICAL`
- Uses state-specific severity matrices and multi-bundle ML artifact selection
- Displays scoped telemetry for a selected state, city, or station
- Shows weather context with live API support and deterministic local fallbacks
- Persists prediction history, telemetry snapshots, and audit logs in PostgreSQL-backed archive tables
- Presents geo-spatial context, hotspot heatmaps, and monitoring guidance for demo flows

## Main user-facing areas

### Dashboard

- Prediction input matrix for peak flood level, event timing, and 7-day rainfall
- State matrix lookup and state filter
- Scenario presets for quick demo inputs
- Monitoring alert card with severity-aware messaging
- Weather console, regional water levels, CWC data display, and risk heatmap
- Historical flood logs panel with clean fallback messaging when no packaged dataset is mapped

### Geo-Spatial Console

- State and station geo lock resolution
- Embedded OpenStreetMap view and external launch link
- Weather context for the locked location
- Probability lane visualization and tactical mapping summaries

### Telemetry Feed

- Scoped sensor cards for the selected state or nearby city/station network
- Node status, trend, river level, rainfall, and sync metadata
- Manual refresh for live telemetry fetches

### Archives Vault

- Historical flood logs from packaged datasets when available
- PostgreSQL-backed prediction history, telemetry snapshot counts, and audit activity
- CSV and JSON export for archive data

## UI highlights

- Premium dark command shell with branded navigation, status cluster, and responsive bottom nav on mobile
- Dashboard-first layout with hero strip, KPI row, structured prediction workspace, monitoring alert, telemetry, weather, and analytics grid
- Refined alert/telemetry/weather/log modules with disciplined severity tones and empty/loading states
- Consistent panel, badge, button, input, and typography system tuned for readability and operational density
- When adding screenshots, capture the Dashboard hero + KPI row and one telemetry/geo panel; place them alongside this README for quick reference

## Backend API groups

- Core service: `/`, `/health`, `/source-policy`
- Model inspection: `/model-artifacts`, `/model-artifacts/{state_name}`
- State thresholds: `/state-severity-matrix`, `/state-severity-matrix/{state_name}`
- Prediction: `/predict`, `/prediction-history`
- Historical logs: `/historical-logs`
- Telemetry: `/sensors`, `/api/live-telemetry`, `/cwc-live-data`, `/telemetry-snapshots`
- Audit: `/audit-logs`
- Weather: `/weather/status`, `/weather/current`, `/weather/search`, `/weather/reverse-geocode`, `/weather/forecast`, `/weather/air-quality`, `/weather/uv`, `/weather/historical`, `/weather/alerts`

## Documentation map

- [FEATURES.md](FEATURES.md): complete feature inventory and capability breakdown
- [QUICKSTART.md](QUICKSTART.md): setup and local run instructions
- [frontend/README.md](frontend/README.md): frontend routes, architecture, and key components
- [frontend/DOCUMENTATION_INDEX.md](frontend/DOCUMENTATION_INDEX.md): current documentation map and legacy doc references

## Repo structure

```text
artifacts/
  dvc/models/             DVC-backed model artifact store (models, scalers, features)

backend/
  app.py                  FastAPI app, ML orchestration, telemetry, weather, archives
  postgres_store.py       PostgreSQL schema/bootstrap and archive persistence helpers

frontend/
  src/App.tsx             Route shell
  src/pages/              Dashboard, Geo-Spatial, Telemetry, Archives
  src/components/         Weather, telemetry, monitoring, charts, navigation
  src/context/            App-wide reducer and provider
  src/hooks/              Prediction, telemetry, CWC, validation, initialization hooks
```

## Notes

- Model artifacts now live outside the app package in `artifacts/dvc/models/`.
- Override the artifact location with `MODEL_ARTIFACTS_DIR`; label the storage type with `MODEL_ARTIFACTS_BACKEND` if needed.
- Set `DATABASE_URL` to enable PostgreSQL persistence for predictions, telemetry snapshots, and audit logs.
- The frontend currently exposes four primary routes in navigation: dashboard, geo-spatial, telemetry, and archives.
- A gradient utility page also exists in the codebase but is not wired into the main navigation.
- Historical packaged flood logs are currently mapped for Kolhapur aliases; other locations fall back to an explanatory empty state.
