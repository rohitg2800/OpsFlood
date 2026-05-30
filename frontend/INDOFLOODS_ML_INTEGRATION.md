# IndoFloods ML Integration Guide

Last reviewed: 2026-04-04

Status: Active reference

This guide covers how frontend and backend coordinate for flood prediction.

## Integration Surface

- Frontend request path: `useEnhancedPrediction` in `src/hooks/useAppOperations.ts`
- Backend inference path: `/predict` in `backend/app.py`
- Calibration source: `backend/state_severity_matrix.py`

## Frontend Prediction Orchestration

`useEnhancedPrediction` performs these steps in order:

1. Recompute rainfall statistics from `T1d..T7d`
2. Fetch scoped CWC/telemetry context
3. Optionally override `Peak_Flood_Level_m` with live/tactical level
4. Send prediction payload to `/predict` (including selected state)
5. Update monitoring level/action/zones based on result severity
6. Persist result into prediction state/history

## Backend Response Usage

Frontend reads these prediction fields (when present):

- `severity`
- `confidence_percent`
- `risk_score`
- `danger_level`
- `monitoring_level`
- `monitoring_action`
- `priority_zones`
- `state_matrix`

## State-Specific Calibration

- Frontend state selector uses `state.models.availableStates` (36 states/UTs)
- Backend matrix endpoint provides region + threshold profile for each state
- Prediction payload includes selected state to apply calibrated thresholds

## Telemetry + ML Coupling

- Telemetry fetch: `/api/live-telemetry`
- CWC domain stores live or tactical fallback nodes
- Prediction flow uses latest node to improve contextual confidence and guidance

## Fallback Behavior

If backend/API calls fail:

- Base prediction hook can return local fallback estimate
- Telemetry hooks fallback to tactical registry data
- UI still renders with degraded status instead of hard failure

## Validation Path

- `useFormValidation` enforces input ranges before inference
- Backend remains source-of-truth for inference output and final calibration

## Related Files

- `src/hooks/useAppOperations.ts`
- `src/pages/DashboardPage.tsx`
- `src/context/AppContext.tsx`
- `backend/app.py`
- `backend/state_severity_matrix.py`
