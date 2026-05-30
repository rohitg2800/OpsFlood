# TODO - OpsFlood critical rainfall threshold inconsistency

## ✅ Step 1: Fix severity_from_entry rainfall threshold source — DONE
- `severity_from_entry()` in `backend/state_severity_matrix.py` already uses
  `r = entry["rainfall_7d_mm"]` (per-state thresholds).
- `get_region_rainfall_thresholds()` is correctly kept for `danger_level_override_guard()` cap logic only.
- No code change required.

## ✅ Step 2: Validate training/label generation for hardcoded thresholds — DONE
- `backend/train.py` dynamically derives all thresholds via `get_state_severity_entry("bihar")`.
- `PK_MOD / PK_SEV / PK_CRIT / RN_MOD / RN_SEV / RN_CRIT` are all pulled from the state matrix at
  import time — no hardcoding present.
- Bihar per-state values confirmed: peak 11.0 / 12.0 / 13.2 m | rain 240 / 390 / 560 mm.

## Step 3: Add/confirm tests (if failing)
- Run backend tests.
- If needed, update/add tests under `backend/tests/` to assert Bihar rainfall mapping uses per-state thresholds.

## Step 4: Retrain and deploy
- Run: `python -m backend.train`
- Restart FastAPI server

## Step 5: Manual verification cases
- Bihar: peak=13.5m, 7d_rain=580mm => expected CRITICAL
- Bihar: peak=10.5m, 7d_rain=200mm => expected LOW
