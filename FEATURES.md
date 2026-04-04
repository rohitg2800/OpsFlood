# Feature Inventory

This document captures the current implemented capabilities in the repository as of the present codebase state.

## 1. Core Product Features

### Flood prediction workflow

- Manual flood input form with peak river level, event duration, time to peak, recession time, and 7-day rainfall distribution
- Four prediction bands: `LOW`, `MODERATE`, `SEVERE`, `CRITICAL`
- Prediction output includes severity, confidence, alert signal, risk score, danger level, state matrix thresholds, and monitoring metadata
- Prediction history is stored locally in app state for later archive review

### State-aware operations

- Built-in support for 36 Indian states and union territories in frontend model selection
- State-specific severity matrix endpoints in the backend
- Dynamic strategic response labels that change based on current severity
- State matrix browser with filtering and direct state selection from the dashboard

### Scoped regional targeting

- Selection can be driven by state, city, or station
- Utility logic narrows telemetry to exact station matches, nearby monitored sources, or state-wide network scope
- Region label propagation is shared across dashboard, telemetry, archives, and weather modules

## 2. Dashboard Features

### Prediction input matrix

- Peak flood level input
- Event timing controls: event days, time to peak, recession days
- Seven daily rainfall inputs with auto-updated total, average, and distribution stats
- Scenario presets for `Dry`, `Monsoon`, and `Extreme`
- City or station lock field for focused analysis

### Decision-support panels

- Monitoring protocol alert with severity-aware tone
- Weather console linked to the selected region
- Selected-region water level section with lead station gauge and linked sensor cards
- Probability lanes and inference matrix visualizations
- Strategic response cards
- Flood risk heatmap that swaps between city hotspot view and state risk view

### Usability and demo polish

- API status banner and shell chrome
- Loading states and skeletons
- Toast notifications for important prediction outcomes
- Prediction-triggered alert notifications and optional alert sound logic
- Cleaner empty state for historical logs when no packaged dataset is mapped

## 3. Geo-Spatial Console Features

- Selected state acts as the primary geo lock
- Optional city or station focus layered on top
- Geo coordinate resolution from known locations and cached selections
- Embedded OpenStreetMap viewport for the resolved target
- External OpenStreetMap launch link
- Probability lane geo graph and layered neural visual
- Weather console bound to the geo lock
- Tactical mapping summary cards and location metadata

## 4. Telemetry Features

### Sensor and river monitoring

- Live telemetry fetch via `/api/live-telemetry`
- Scoped node count based on selected state/city/station
- Station cards with river name, trend, last sync time, level, and rainfall
- Status rendering for `ACTIVE`, `WARNING`, `CRITICAL`, and default/offline-like cases
- Manual telemetry refresh button

### Fallback telemetry behavior

- Tactical registry generation when live feeds are unavailable or policy-blocked
- Merge logic that combines API sensors and tactical fallback nodes
- Cached recent telemetry requests to avoid duplicate network churn

## 5. Weather Intelligence Features

### Frontend weather console

- Current weather display for the selected operational region
- Proxy status badge: `SECURE`, `DEGRADED`, `MISSING_KEY`, `OFFLINE`, or `CHECKING`
- Feels-like temperature, min/max temperatures, cloud cover, wind, visibility, humidity, and pressure context
- Rain overlay effect for rainy conditions
- Resolved location lock support for state, city, station, or coordinate targets

### Backend weather services

- Current weather by city or coordinates
- Weather search and reverse geocoding
- Forecast retrieval
- Air quality endpoint
- UV index endpoint
- Historical weather endpoint
- Weather alerts endpoint

### Resilience and local fallback

- Cached weather responses
- Fallback current weather generation
- Fallback forecast generation
- Fallback air quality, UV, reverse geocode, search, and historical weather data
- Query cleanup for noisy region labels like `sector`, `basin`, `delta`, and similar terms

## 6. Archive and Historical Data Features

### Historical flood logs

- Backend endpoint for city-based historical flood log lookup
- Alias matching for packaged datasets
- Current packaged dataset mapping for Kolhapur and related aliases such as Shirol, Irwin Bridge, Kagal, and Panchganga
- Prioritized sorting when rows directly match the requested city/station context

### Archive UI

- Historical flood log table with export support
- Mode indicator for real dataset vs archive fallback
- Clear empty state messaging when no packaged dataset exists for the selected location
- Load selected historical row back into the dashboard input form

### Local prediction archive

- Local inference history table in the archives page
- CSV export for local predictions
- JSON bundle export including:
  - archive scope
  - system metadata
  - monitoring metadata
  - prediction records

## 7. Machine Learning and Risk Logic

### Model system

- Artifact catalog discovery for models, scalers, and feature files
- Bundle-based state model resolution
- Default bundle fallback when a state-specific bundle is unavailable
- Support for additional IndoFloods bundle selection for relevant states

### Prediction engine

- Feature vector built from 11 numeric inputs
- Multi-bundle ensemble weighting plan
- Probability normalization across `LOW`, `MODERATE`, `SEVERE`, and `CRITICAL`
- Rule-engine overlay using state matrix thresholds and rainfall/peak dynamics
- Threshold floors and severity promotion to prevent under-reporting against calibrated state thresholds
- Final response includes:
  - hybrid probabilities
  - bundle breakdown
  - ML vs rule-engine weights
  - rule signals
  - risk score
  - state matrix reference

### Monitoring logic

- Monitoring level escalation to `STANDARD`, `ELEVATED`, or `CRITICAL` in frontend state
- Backend monitoring payload for each prediction
- Priority zone recommendations for elevated and critical scenarios

## 8. Data Policy and Compliance Features

- Source-policy endpoint exposed to frontend and clients
- Three policy modes:
  - `OPEN_DATA`
  - `OFFICIAL_VIEW_ONLY`
  - `FALLBACK`
- Public-source references included in policy payload
- In current policy handling, in-app telemetry defaults to tactical/manual context rather than unrestricted live CWC reuse
- Frontend surfaces policy-aware telemetry and data source messaging

## 9. Backend API Features

### Service and inspection

- `GET /`
- `GET /health`
- `GET /source-policy`
- `GET /model-artifacts`
- `GET /model-artifacts/{state_name}`
- `GET /state-severity-matrix`
- `GET /state-severity-matrix/{state_name}`

### Forecasting and risk

- `POST /predict`

### Flood logs and telemetry

- `GET /historical-logs`
- `GET /sensors`
- `GET /api/live-telemetry`
- `GET /cwc-live-data`

### Weather

- `GET /weather/status`
- `GET /weather/current`
- `GET /weather/search`
- `GET /weather/reverse-geocode`
- `GET /weather/forecast`
- `GET /weather/air-quality`
- `GET /weather/uv`
- `GET /weather/historical`
- `GET /weather/alerts`

## 10. Frontend Architecture Features

- React 19 + TypeScript + Vite application
- Route-based page shell with lazy-loaded pages
- Centralized reducer-driven app state via context
- Custom hooks for:
  - prediction API
  - enhanced prediction workflow
  - CWC integration
  - sensor fetching
  - rainfall statistics
  - notifications
  - system initialization
  - validation
- Shared page hero and card system for consistent shell layout
- Custom charts, gauges, neural visuals, and probability-lane components

## 11. Reliability and UX Safeguards

- Health-based system initialization and API version capture
- Offline/degraded fallback prediction behavior
- Request deduplication for telemetry and CWC calls
- Short-lived client-side result caching for repeated telemetry/CWC requests
- Fallback telemetry registry when live data is blocked or unavailable
- Historical archive fallback messaging instead of hard failure
- Notification permission request on initialization

## 12. Utility and Secondary Features

- Gradient generator page in the codebase for tactical CSS gradient creation
- Exportable CSS from the gradient utility page
- Local hero imagery and icon assets
- Multi-file documentation set across root and frontend folders

## 13. What is currently limited

- The main navigation currently exposes four routes: dashboard, geo-spatial, telemetry, and archives
- The gradient generator exists but is not wired into the primary route shell
- Packaged historical flood logs are currently mapped to the Kolhapur dataset family, not every selected location
- Policy handling presently favors tactical/manual in-app telemetry over direct unrestricted official ingestion
