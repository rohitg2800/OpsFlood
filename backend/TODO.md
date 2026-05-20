# OpsFlood TODO

- [x] Implement station-aware effective severity thresholds

  - [ ] Add `select_best_station_node()` and `build_effective_state_entry()` to `backend/state_severity_matrix.py`
  - [ ] Update predictor methods to accept optional `state_entry_override` and use it everywhere thresholds/guard are computed
  - [x] Wire `/predict` to fetch telemetry for the selected (state, station) and select the best node

  - [ ] Ensure `river_level_m` is passed consistently so Option-A guard is active
  - [ ] Update tests

  - [ ] Add `backend/tests/test_station_thresholds.py` to verify CRITICAL is capped when live telemetry danger is higher than state default
- [ ] Run unit tests
  - [ ] `python -m unittest discover -s backend/tests -p "test_*.py"`

