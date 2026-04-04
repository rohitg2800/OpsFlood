# Frontend Overview

This frontend is a React + TypeScript + Vite application for the INDIA_FLOODS OPS interface. It is designed as a multi-page operations console that shares a centralized reducer-driven state across dashboard, telemetry, mapping, and archive workflows.

## Primary routes

- `/` — Dashboard
- `/geo` — Geo-Spatial Console
- `/telemetry` — Telemetry Feed
- `/archives` — Archives Vault

## What the frontend includes

### Shared shell

- Sticky navigation with route highlighting and API status
- Shared page hero and content card primitives
- Global visual theme and animated background layers
- Route-level lazy loading

### Dashboard

- Flood prediction input form
- State matrix selection and regional filter
- City or station lock
- Scenario presets
- Monitoring alert card
- Weather console
- Selected-region water levels
- CWC live data display
- Probability and neural visualizations
- Risk heatmap
- Historical flood logs panel

### Geo-Spatial Console

- Geo lock resolution from state, city, or station
- Embedded OpenStreetMap panel
- Launch-out mapping link
- Weather console tied to the geo target
- Probability lane visuals and tactical geo summaries

### Telemetry Feed

- Scoped sensor cards for the selected region
- River-level, rainfall, trend, and station metadata
- Refreshable telemetry sync

### Archives Vault

- Historical flood logs panel
- Local prediction archive table
- CSV and JSON exports

## State architecture

The frontend uses a context provider and reducer in [AppContext.tsx](/Users/rohitraj/Desktop/flood-app-new/frontend/src/context/AppContext.tsx) backed by the types and initial state in [types.ts](/Users/rohitraj/Desktop/flood-app-new/frontend/src/types.ts).

Key state domains:

- `system`
- `prediction`
- `sensors`
- `form`
- `data`
- `preferences`
- `cwc`
- `models`

## Key hooks

The main operational hooks live in [useAppOperations.ts](/Users/rohitraj/Desktop/flood-app-new/frontend/src/hooks/useAppOperations.ts).

- `useSystemInit`
- `usePredictionAPI`
- `useEnhancedPrediction`
- `useSensorAPI`
- `useCWCIntegration`
- `useRainfallStats`
- `useFormValidation`
- `useAlertNotifications`

## Backend integration points

The frontend consumes:

- health and source-policy endpoints during initialization
- prediction endpoints for flood inference
- telemetry and CWC endpoints for live or tactical node data
- weather endpoints for current conditions, forecast, and related context
- historical log endpoints for packaged flood records

## Feature notes

- Weather and telemetry both include graceful fallback behavior so the UI remains demoable when upstream data is unavailable.
- The app tracks local prediction history and uses that state in the archives page.
- A gradient generator page exists in `src/pages/GradientGeneratorPage.tsx`, but it is not currently linked from the main navigation.

## Related docs

- [../README.md](../README.md)
- [../FEATURES.md](../FEATURES.md)
- [DOCUMENTATION_INDEX.md](DOCUMENTATION_INDEX.md)
