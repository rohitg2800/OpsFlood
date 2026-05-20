# TODO - OpsFlood critical rainfall threshold inconsistency

## Step 1: Fix severity_from_entry rainfall threshold source
- Update `backend/state_severity_matrix.py` in `severity_from_entry()`:
  - Replace `r = get_region_rainfall_thresholds(entry["region"])`
  - With `r = entry["rainfall_7d_mm"]`
- Keep `get_region_rainfall_thresholds()` intact for `danger_level_override_guard()` cap logic.

## Step 2: Validate training/label generation for hardcoded thresholds
- Review `backend/train.py` (and any related label logic) to confirm there’s no hardcoded LOW/MODERATE/SEVERE/CRITICAL rainfall threshold mapping that conflicts with per-state `rainfall_7d_mm`.
- If any hardcoding exists, align it to per-state calibrated values (e.g., Bihar thresholds: 240/390/560).

## Step 3: Add/confirm tests (if failing)
- Run backend tests.
- If needed, update/add tests under `backend/tests/` to assert Bihar rainfall mapping uses per-state thresholds.

## Step 4: Retrain and deploy
- Run: `python -m backend.train`
- Restart FastAPI server

## Step 5: Manual verification cases
- Bihar: peak=13.5m, 7d_rain=580mm => expected CRITICAL
- Bihar: peak=10.5m, 7d_rain=200mm => expected LOW

