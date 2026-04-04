# Frontend Architecture Reference

Last reviewed: 2026-04-04

Status: Active reference

## Runtime Topology

```text
Browser
  -> React Router shell (src/App.tsx)
    -> Route pages (/ /geo /telemetry /archives)
      -> Domain components + hooks
        -> FastAPI backend (prediction, telemetry, weather, logs)
```

## Route Shell

`src/App.tsx` composes:

- Global navigation
- Severity-driven animated background layers
- Lazy route loading for page modules
- Fixed tactical footer on large screens

## State Layer

Global state is managed by a reducer/context pair:

- Context provider: `src/context/AppContext.tsx`
- Types + initial state: `src/types.ts`
- Action dispatch through hooks and page handlers

Primary state domains:

- `system`
- `prediction`
- `sensors`
- `form`
- `alerts`
- `data`
- `preferences`
- `cwc`
- `models`

## Hook Layer

Core integration logic lives in `src/hooks/useAppOperations.ts`.

- `useSystemInit` handles startup health/policy fetch
- `usePredictionAPI` handles base prediction request + fallback
- `useEnhancedPrediction` orchestrates rainfall stats + CWC context + prediction + monitoring action
- `useSensorAPI` and `useCWCIntegration` populate telemetry domains
- `useFormValidation` + `useAlertNotifications` support UX safety

## Data Flow: Prediction Path

1. User edits dashboard form fields
2. Form updates dispatch into `state.form.data`
3. `predictWithFullModel` runs from `useEnhancedPrediction`
4. Rainfall stats are recalculated from `T1d..T7d`
5. Telemetry context is fetched (live or tactical)
6. Payload posts to `/predict`
7. Prediction state and monitoring state are updated
8. Dependent components re-render (alert card, gauges, graphs, logs)

## Data Flow: Telemetry Path

1. Region selection comes from selected state/city/station
2. Telemetry fetch targets `/api/live-telemetry`
3. API payload normalizes into internal sensor model
4. Tactical registry data fills gaps when needed
5. UI shows scoped node cards or no-data guidance

## Design/UX Behavior

- Severity-aware visual tones across badges, cards, and highlights
- Graceful loading/empty/fallback states in all major panels
- Responsive layout for desktop and mobile operation
- Motion is reduced on constrained devices via utility checks

## Key Files

- `src/App.tsx`
- `src/pages/DashboardPage.tsx`
- `src/pages/GeoSpatialPage.tsx`
- `src/pages/TelemetryPage.tsx`
- `src/pages/ArchivesPage.tsx`
- `src/context/AppContext.tsx`
- `src/hooks/useAppOperations.ts`
- `src/components/OpsPrimitives.tsx`
