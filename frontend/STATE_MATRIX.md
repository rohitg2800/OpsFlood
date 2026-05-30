# Frontend State Matrix

Last reviewed: 2026-04-04

Status: Active reference

This document summarizes the reducer-driven state model used by the frontend.

## Source Files

- `src/types.ts` - state types, action unions, initial state
- `src/context/AppContext.tsx` - reducer and provider wiring
- `src/hooks/useAppOperations.ts` - operational hooks that dispatch actions

## State Domains

- `ui` - tab, modal/sidebar flags, notifications toggle
- `system` - API status, source policy, version, initialization state
- `prediction` - current prediction, history, latency, monitoring guidance
- `sensors` - scoped telemetry nodes and loading state
- `form` - flood model inputs, derived rainfall stats, errors/touched flags
- `alerts` - in-app alert stream and counts
- `data` - weather/location payloads and weather fetch state
- `preferences` - theme, auto-refresh, interval, display options
- `cwc` - live/tactical hydrology payload and connectivity state
- `models` - available states and model-selection metadata

## Action Families

Reducer actions are grouped around:

- UI/system initialization and status
- Form edit/validation and rainfall updates
- Prediction lifecycle (loading, result, history, latency)
- Telemetry and CWC data synchronization
- Alert creation/removal/clear operations
- User preference updates
- State/city/monitoring selection

## Hook-to-State Mapping

- `useSystemInit` -> system readiness and source policy
- `usePredictionAPI` / `useEnhancedPrediction` -> prediction + monitoring + history
- `useSensorAPI` -> sensors data and fetch state
- `useCWCIntegration` -> CWC domain and source labeling
- `useRainfallStats` -> rainfall distribution + aggregate stats
- `useIndianStateModels` -> selected state and monitoring controls

## Operational Notes

- Prediction and telemetry flows both support fallback behavior.
- The reducer avoids redundant updates for repeated payloads where possible.
- History lists are bounded to control memory growth.
