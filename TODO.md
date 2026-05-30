# TODO — EQUINOX-BH

## ✅ Completed
- [x] Bihar severity matrix calibrated (CWC thresholds)
- [x] `severity_from_entry()` signature fixed
- [x] Model retrained — 99.50% accuracy, CRITICAL/SEVERE F1 = 1.00
- [x] `model_metrics.py` DB persistence fixed (store.connection() pattern)
- [x] Manual verification: Bihar CRITICAL + LOW cases pass
- [x] App renamed OpsFlood → EQUINOX-BH across all files

## 🔄 In Progress
- [ ] Render service rename (manual step in dashboard)
- [ ] Firebase package name update: com.equinox_bh.android

## 📋 Backlog
- [ ] P2: IMD + NDMA integration
- [ ] GloFAS 7-day forecast integration
- [ ] Multi-state severity matrix expansion
- [ ] Push notifications: threshold breach alerts
