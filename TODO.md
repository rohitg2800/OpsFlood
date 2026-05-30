# TODO — OpsFlood

---

## Backend — critical rainfall threshold inconsistency

### ✅ Step 1: Fix severity_from_entry rainfall threshold source — DONE
- `severity_from_entry()` in `backend/state_severity_matrix.py` already uses
  `r = entry["rainfall_7d_mm"]` (per-state thresholds).
- `get_region_rainfall_thresholds()` is correctly kept for `danger_level_override_guard()` cap logic only.
- No code change required.

### ✅ Step 2: Validate training/label generation for hardcoded thresholds — DONE
- `backend/train.py` dynamically derives all thresholds via `get_state_severity_entry("bihar")`.
- `PK_MOD / PK_SEV / PK_CRIT / RN_MOD / RN_SEV / RN_CRIT` are all pulled from the state matrix at
  import time — no hardcoding present.
- Bihar per-state values confirmed: peak 11.0 / 12.0 / 13.2 m | rain 240 / 390 / 560 mm.

### Step 3: Add/confirm tests (if failing)
- Run backend tests.
- If needed, update/add tests under `backend/tests/` to assert Bihar rainfall mapping uses per-state thresholds.

### Step 4: Retrain and deploy
- Run: `python -m backend.train`
- Restart FastAPI server.

### Step 5: Manual verification cases
- Bihar: peak=13.5m, 7d_rain=580mm → expected CRITICAL
- Bihar: peak=10.5m, 7d_rain=200mm → expected LOW

---

## Flutter screens

### ✅ AlertsScreen — DONE (PR #5)
- `FloodData` entries grouped CRITICAL → SEVERE → MODERATE → LOW.
- Collapsible section headers with count badge.
- Alert cards: city/state/river, current/warning/danger/rainfall levels,
  `capacityPercent` bar, IMD severity chip, status pill, last-updated timestamp.
- Colours sourced exclusively from `data.priorityColor`.
- Empty state + pull-to-refresh.

### ✅ LiveStationsScreen — DONE (PR #5)
- `RiverStation` list sorted by `riskScore` (dangerClass.index) descending.
- Live search bar filtering across station / city / river name.
- Station cards: gauge levels (current / warning / danger / HFL), `progressPct` bar,
  DangerClass tier badge, LIVE badge, trend chip (↑ rising / ↓ falling / → steady),
  dataSource chip, flow rate (m³/s).
- Two empty states: fetching vs. no search results.
- Pull-to-refresh.

### ✅ DashboardScreen — DONE
- Dead import (`india_river_explorer_screen.dart`) removed.
- KPI row now shows all 4 severity tiers: CRITICAL / SEVERE / MODERATE / MONITORED.
- `_sorted` uses `priorityOrder`; city chips + trend chart use `priorityColor`.
- No inline colour switch blocks anywhere in the file.

### ✅ HomeScreen nav — DONE
- `LiveStationsScreen` added as tab 5 ('Stations', sensors icon).
- `MonitorsScreen` retained as tab 6 ('Monitor').
- Icon + label sizes tightened (icon 16/18px, label 8/8.5px) for 7-tab fit.
- Nav now: Dashboard • Rivers • Alerts • Weather • Predict • Stations • Monitor

---

## Remaining
- [ ] Step 3–5 above: run backend tests → retrain → manual verify.
