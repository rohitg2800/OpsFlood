# OpsFlood Android — Setup & Deployment Guide

## P0 Fixes Applied (v2.1)
- ✅ RealTimeService.startPolling() moved to SplashScreen.initState()
- ✅ ListenableBuilder replaces AnimatedBuilder (scoped rebuild)
- ✅ ThemeProvider.mode properly wired into MaterialApp.themeMode
- ✅ _extractList() removed — single _deepExtractList() used everywhere
- ✅ Notification IDs use stable polynomial hash (no more hashCode collisions)
- ✅ flutter_map + latlong2 added to pubspec (map screen now compiles)
- ✅ workmanager added — background refresh every 15 min

## P1 Fixes Applied (v2.1)
- ✅ CwcDirectService wired into RealTimeService as Pass-0 data source
  - 4-source cascade: OpsFlood Proxy → india-water.gov.in FFS → India WRIS → data.gov.in
  - cwcDirectReadings getter exposed for map and detail screens
- ✅ FCM push service scaffolded (lib/services/fcm_service.dart)
  - Compiles in stub mode without firebase_messaging in pubspec
  - Full live implementation ready to uncomment
- ✅ predict.dart → prediction_service.dart → flood_engine.dart chain confirmed clean
- ✅ lib/config/env.dart — --dart-define config for URLs and feature flags

---

## Firebase FCM Setup (when ready)

```bash
# 1. Create Firebase project at https://console.firebase.google.com
# 2. Add android app with package: com.opsflood.android
#    Download google-services.json → android/app/
# 3. Add iOS app → download GoogleService-Info.plist → ios/Runner/

# 4. Add packages
flutter pub add firebase_core firebase_messaging

# 5. Configure (auto-generates lib/firebase_options.dart)
dart pub global activate flutterfire_cli
flutterfire configure

# 6. Uncomment the live implementation in lib/services/fcm_service.dart
# 7. Add to SplashScreen._bootServices():
#    await FcmService.instance.init();
```

### Backend — register-device endpoint (FastAPI)
```python
@app.post("/api/register-device")
async def register_device(payload: dict):
    token = payload["token"]
    platform = payload["platform"]
    # Store in DB — send push when CWC threshold fires
    db.save_device_token(token, platform)
    return {"status": "registered"}
```

---

## Background Fetch (workmanager)

Add to `SplashScreen._bootServices()` after `RealTimeService().startPolling()`:

```dart
await BackgroundService.init();
await FcmService.instance.init(); // add when Firebase configured
```

---

## Environment Config (--dart-define)

```bash
# Development (default — no flags needed)
flutter run

# Staging
flutter run \
  --dart-define=OPSFLOOD_BASE_URL=https://opsflood-staging.onrender.com \
  --dart-define=OPSFLOOD_ENV=staging

# Production build
flutter build apk \
  --dart-define=OPSFLOOD_BASE_URL=https://opsflood.onrender.com \
  --dart-define=OPSFLOOD_ENV=production \
  --dart-define=OPSFLOOD_POLL_SECONDS=30
```

---

## CWC Direct Data Sources

| Source | URL | Auth | Refresh |
|--------|-----|------|---------|
| OpsFlood Proxy | /api/cwc-ffs | None | 15 min |
| india-water.gov.in FFS | ffs.india-water.gov.in/ffs/floodForecastData | None | 6 hr (monsoon) |
| India WRIS | indiawris.gov.in/api/RainfallGaugeStation | None | Daily |
| data.gov.in Reservoir | /api/cwc-reservoir | None | Daily |

---

## Attribution (required by CWC open data terms)

All river level data sourced from:
- **CWC FFS** (Central Water Commission Flood Forecasting System)
- **India WRIS** (Water Resources Information System of India)
- **OGD Platform India** (data.gov.in)

Add this attribution in the app's About screen and any exported reports.
