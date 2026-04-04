# Component Integration and Maintenance Guide

Last reviewed: 2026-04-04

Status: Active maintenance reference

This file replaces earlier TODO-focused guidance and documents current component ownership points.

## Core Dashboard Components

### State selector

- File: `src/components/StateSelector.tsx`
- Source: `useIndianStateModels()`
- Responsibility: selected state sync and matrix context messaging

### Monitoring protocol card

- File: `src/components/MonitoringProtocolAlert.tsx`
- Source: `state.prediction` + `state.cwc` + `state.system.sourcePolicy`
- Responsibility: severity-linked operational guidance

### CWC/telemetry display

- File: `src/components/CWCLiveDataDisplay.tsx`
- Source: `useCWCIntegration()` and scoped sensors
- Responsibility: preferred station snapshot and regional node strip

### Weather console

- File: `src/components/WeatherConsolePanel.tsx`
- Source: backend weather endpoints + selected location context
- Responsibility: current weather, destination resolution, update status

### Historical logs panel

- File: `src/components/FloodLogsPanel.tsx`
- Source: `/historical-logs` and prediction history state
- Responsibility: archive timeline and fallback messaging

## Visualization Components

- `NeuralOperationsGraph.tsx`
- `ProbabilityLaneHeartbeat.tsx`
- `FloodRiskHeatmap.tsx`
- `WaterLevelGauge.tsx`

These components should remain severity-aware and resilient to missing optional fields.

## Shared Primitives

- File: `src/components/OpsPrimitives.tsx`
- Use this as the first choice for panel, badge, and section layout patterns.

## Integration Rules

- Keep state writes inside reducer actions; avoid ad-hoc mutable state patterns.
- Reuse hook APIs (`useEnhancedPrediction`, `useSensorAPI`, `useCWCIntegration`) instead of duplicating request logic.
- Preserve fallback/empty-state behavior when changing cards.
- Avoid hardcoding a single state/station except as documented default fallback.

## Quick Verification

```bash
cd frontend
npm run lint
npm run build
```

Then validate route surfaces:

- `/`
- `/geo`
- `/telemetry`
- `/archives`
