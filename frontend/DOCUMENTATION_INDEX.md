# Frontend Documentation Index

This index points to the current useful documentation for the frontend and marks older planning documents as historical references where appropriate.

## Start here

1. [../README.md](../README.md)
   Project-level overview, routes, API groups, and repo layout.

2. [../FEATURES.md](../FEATURES.md)
   Complete feature inventory for the app, backend, weather stack, telemetry, and archives.

3. [README.md](README.md)
   Frontend-specific route map, architecture summary, and hook inventory.

4. [../QUICKSTART.md](../QUICKSTART.md)
   Local setup and startup flow.

## Current source-of-truth docs

### Product and architecture

- [../README.md](../README.md)
- [../FEATURES.md](../FEATURES.md)
- [README.md](README.md)

### Operational startup

- [../QUICKSTART.md](../QUICKSTART.md)

### Code-level reference

- [src/App.tsx](/Users/rohitraj/Desktop/flood-app-new/frontend/src/App.tsx)
- [src/context/AppContext.tsx](/Users/rohitraj/Desktop/flood-app-new/frontend/src/context/AppContext.tsx)
- [src/types.ts](/Users/rohitraj/Desktop/flood-app-new/frontend/src/types.ts)
- [src/hooks/useAppOperations.ts](/Users/rohitraj/Desktop/flood-app-new/frontend/src/hooks/useAppOperations.ts)

## Page map

- Dashboard: [src/pages/DashboardPage.tsx](/Users/rohitraj/Desktop/flood-app-new/frontend/src/pages/DashboardPage.tsx)
- Geo-Spatial Console: [src/pages/GeoSpatialPage.tsx](/Users/rohitraj/Desktop/flood-app-new/frontend/src/pages/GeoSpatialPage.tsx)
- Telemetry Feed: [src/pages/TelemetryPage.tsx](/Users/rohitraj/Desktop/flood-app-new/frontend/src/pages/TelemetryPage.tsx)
- Archives Vault: [src/pages/ArchivesPage.tsx](/Users/rohitraj/Desktop/flood-app-new/frontend/src/pages/ArchivesPage.tsx)
- Utility Gradient Console: [src/pages/GradientGeneratorPage.tsx](/Users/rohitraj/Desktop/flood-app-new/frontend/src/pages/GradientGeneratorPage.tsx)

## Key component map

- Navigation: [src/components/Navigation.tsx](/Users/rohitraj/Desktop/flood-app-new/frontend/src/components/Navigation.tsx)
- Weather console: [src/components/WeatherConsolePanel.tsx](/Users/rohitraj/Desktop/flood-app-new/frontend/src/components/WeatherConsolePanel.tsx)
- Monitoring alert: [src/components/MonitoringProtocolAlert.tsx](/Users/rohitraj/Desktop/flood-app-new/frontend/src/components/MonitoringProtocolAlert.tsx)
- Historical logs: [src/components/FloodLogsPanel.tsx](/Users/rohitraj/Desktop/flood-app-new/frontend/src/components/FloodLogsPanel.tsx)
- CWC display: [src/components/CWCLiveDataDisplay.tsx](/Users/rohitraj/Desktop/flood-app-new/frontend/src/components/CWCLiveDataDisplay.tsx)
- Neural visual layer: [src/components/NeuralOperationsGraph.tsx](/Users/rohitraj/Desktop/flood-app-new/frontend/src/components/NeuralOperationsGraph.tsx)

## Historical or planning-era docs

These files still contain useful context, but they should not be treated as the primary truth without checking current source files.

- [README_IMPLEMENTATION.md](README_IMPLEMENTATION.md)
- [IMPLEMENTATION_ROADMAP.md](IMPLEMENTATION_ROADMAP.md)
- [COMPONENT_IMPLEMENTATION_GUIDE.md](COMPONENT_IMPLEMENTATION_GUIDE.md)
- [INDOFLOODS_ML_INTEGRATION.md](INDOFLOODS_ML_INTEGRATION.md)
- [STATE_MATRIX.md](STATE_MATRIX.md)
- [ARCHITECTURE_COMPLETE.md](ARCHITECTURE_COMPLETE.md)
- [ANIMATION_COMPONENTS_GUIDE.md](ANIMATION_COMPONENTS_GUIDE.md)
- [ANIMATION_IMPLEMENTATION_SUMMARY.md](ANIMATION_IMPLEMENTATION_SUMMARY.md)

## Recommended reading order

For product understanding:

1. [../README.md](../README.md)
2. [../FEATURES.md](../FEATURES.md)
3. [README.md](README.md)

For implementation work:

1. [src/App.tsx](/Users/rohitraj/Desktop/flood-app-new/frontend/src/App.tsx)
2. [src/context/AppContext.tsx](/Users/rohitraj/Desktop/flood-app-new/frontend/src/context/AppContext.tsx)
3. [src/hooks/useAppOperations.ts](/Users/rohitraj/Desktop/flood-app-new/frontend/src/hooks/useAppOperations.ts)
4. The page/component files relevant to the feature you are touching
