# State Severity Matrix (India)

This repo includes a **per-state severity threshold matrix** used to calibrate flood severity when you select an Indian state/UT.

- Source of truth: `backend/state_severity_matrix.py`
- API endpoints:
  - `GET /state-severity-matrix` (all states)
  - `GET /state-severity-matrix/{state_name}` (single state)

Important: These thresholds are **heuristic calibration values** (not official CWC danger levels). Tune them using your own labeled flood-event datasets per state/station.

## Thresholds By Region

Severity is computed by escalating based on either:
- `Peak_Flood_Level_m` (meters), OR
- `T7d` (7-day rainfall, mm)

If any `critical` threshold is exceeded => `CRITICAL`, else if any `severe` exceeded => `SEVERE`, else if any `moderate` exceeded => `MODERATE`, else `LOW`.

| Region | Peak (m) MOD/SEV/CRIT | Rain 7d (mm) MOD/SEV/CRIT |
|---|---:|---:|
| COASTAL | 11.5 / 12.5 / 13.5 | 300 / 450 / 650 |
| PLAINS | 11.5 / 12.5 / 13.5 | 250 / 400 / 550 |
| HIMALAYAN | 11.0 / 12.0 / 13.0 | 200 / 350 / 500 |
| NORTHEAST | 11.0 / 12.0 / 13.0 | 220 / 370 / 520 |
| ARID | 11.0 / 12.0 / 13.0 | 150 / 250 / 350 |
| ISLAND | 11.5 / 12.5 / 13.5 | 300 / 450 / 650 |
| URBAN_UT | 11.5 / 12.5 / 13.5 | 220 / 350 / 500 |

## State/UT Matrix

| State/UT | Region |
|---|---|
| Andhra Pradesh | COASTAL |
| Arunachal Pradesh | HIMALAYAN |
| Assam | NORTHEAST |
| Bihar | PLAINS |
| Chhattisgarh | PLAINS |
| Goa | COASTAL |
| Gujarat | COASTAL |
| Haryana | PLAINS |
| Himachal Pradesh | HIMALAYAN |
| Jharkhand | PLAINS |
| Karnataka | COASTAL |
| Kerala | COASTAL |
| Madhya Pradesh | PLAINS |
| Maharashtra | COASTAL |
| Manipur | NORTHEAST |
| Meghalaya | NORTHEAST |
| Mizoram | NORTHEAST |
| Nagaland | NORTHEAST |
| Odisha | COASTAL |
| Punjab | PLAINS |
| Rajasthan | ARID |
| Sikkim | HIMALAYAN |
| Tamil Nadu | COASTAL |
| Telangana | PLAINS |
| Tripura | NORTHEAST |
| Uttar Pradesh | PLAINS |
| Uttarakhand | HIMALAYAN |
| West Bengal | COASTAL |
| Andaman and Nicobar Islands | ISLAND |
| Chandigarh | URBAN_UT |
| Dadra and Nagar Haveli and Daman and Diu | COASTAL |
| Delhi | URBAN_UT |
| Jammu and Kashmir | HIMALAYAN |
| Ladakh | HIMALAYAN |
| Lakshadweep | ISLAND |
| Puducherry | COASTAL |

