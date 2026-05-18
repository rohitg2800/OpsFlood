# OpsFlood Backend Improvements — Implementation Tracker

## Task 1 — Freeze synthetic in-app training (make it offline-only)
- [x] 1a: Add production guard in `KolhapurFloodPredictor.train_with_real_data()` (backend/app.py)
- [x] 1b: Add docstring-warning comments at top of `get_training_data()` (backend/app.py)
- [x] 1c: Create `backend/train_indofloods.py` (new)


## Task 2 — Calibrate hybrid rule engine in backend/app.py
- [x] 2a: Update `apply_threshold_floor()` constants (backend/app.py)
- [x] 2b: Add `MAX_PROMOTION_GAP` guard in `promote_severity()` (backend/app.py)
- [x] 2c: Rewrite `fallback_prediction()` to honest heuristic-only version (backend/app.py)


## Task 3 — Add AUROC + durable metrics persistence
- [x] 3a: Compute `macro_auroc` in `backend/model_metrics.py`
- [x] 3b: Persist metrics JSON into `artifacts/metrics/`
- [x] 3c: Persist metrics to Postgres non-fatally (optional but requested)


## Task 4 — CRITICAL class alignment
- [x] 4a: Add `validate_critical_labels()` and call it after dataset load (backend/train_indofloods.py)
- [x] 4b: Add Delhi/Mizoram datum warning comment block (backend/state_severity_matrix.py, comment-only)


## Verification Checklist
- [ ] Start backend; confirm no in-app training overwrites artifacts
- [ ] /predict with ML artifacts present => algorithm != "Heuristic Fallback – NO ML"
- [ ] Temporarily remove ML artifacts; /predict => algorithm == "Heuristic Fallback – NO ML" and probabilities == {}
- [ ] Run offline training: `python backend/train_indofloods.py --dataset data/indofloods.csv`
- [ ] Confirm `artifacts/dvc/models/indofloods_production_model.pkl` updated
- [ ] Confirm `artifacts/metrics/indofloods_metrics.json` includes `macro_auroc`
- [ ] Confirm gating prevents overwrite when worse
- [ ] Confirm `model_metrics` Postgres table receives a new row (if DB reachable)

