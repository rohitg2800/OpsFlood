# Frontend Overview

Last reviewed: 2026-04-04

This frontend is a React + TypeScript + Vite operations console for the INDIA_FLOODS OPS project.

## Routes

- `/` - Dashboard
- `/geo` - Geo-Spatial Console
- `/telemetry` - Telemetry Feed
- `/archives` - Archives Vault

## Architecture Summary

- Route shell and lazy loading in `src/App.tsx`
- Global reducer-driven state in `src/context/AppContext.tsx`
- Typed state models in `src/types.ts`
- Operational hooks in `src/hooks/useAppOperations.ts`
- Shared UI primitives in `src/components/OpsPrimitives.tsx`

## Key Frontend Modules

### Dashboard

- Prediction form and severity output
- State selector and regional targeting
- Monitoring protocol card
- Weather, CWC/telemetry, heatmap, and archive widgets

### Geo-Spatial

- Geo lock derived from selected state/city/station
- Embedded map context and external map handoff
- Weather and probability context for selected target

### Telemetry

- Scoped river/sensor node cards
- Trend, rainfall, river level, and freshness metadata

### Archives

- Historical flood logs (when mapped)
- Local prediction history usage
- CSV and JSON export tools

## Backend Touchpoints

Frontend consumes backend endpoints for:

- Health and policy (`/health`, `/source-policy`)
- Prediction (`/predict`)
- Telemetry (`/api/live-telemetry`, `/cwc-live-data`, `/sensors`)
- Weather (`/weather/*`)
- Historical logs (`/historical-logs`)

## Local Run

```bash
cd frontend
npm install
npm run dev
```

Optional env:

```bash
VITE_API_BASE_URL=http://localhost:8000
```

For the single-container Render deployment, leave `VITE_API_BASE_URL` unset so the built frontend calls the backend on the same origin.

## Render Deployment

- `Dockerfile` builds `frontend/` and packages it with the FastAPI backend.
- `backend/app.py` serves `frontend/dist` and falls back to `index.html` for SPA routes.
- `render.yaml` defines one Docker web service named `opsflood`.

## Related Docs

- [../README.md](../README.md)
- [../QUICKSTART.md](../QUICKSTART.md)
- [../FEATURES.md](../FEATURES.md)
- [DOCUMENTATION_INDEX.md](DOCUMENTATION_INDEX.md)
