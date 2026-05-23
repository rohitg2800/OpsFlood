# 🌊 OpsFlood — AI-Powered Flood Monitoring App

> **Flutter mobile application** that provides real-time flood monitoring, AI-driven predictions, and push-alert notifications for **80+ CWC-monitored cities across India.**  
> Backed by the [OpsFlood FastAPI backend](https://opsflood.onrender.com) (XGBoost + RandomForest ensemble), with a full **on-device fallback ML engine** for offline use.

---

## 📱 Screenshots & Key Screens

| Screen | Description |
|---|---|
| Splash | Animated brand screen with backend health check |
| Dashboard | National flood status overview with risk heatmap |
| Predict | Manual flood prediction with feature sliders |
| River Monitor | Live CWC gauge telemetry per river |
| India Rivers | Full all-India river map with alert overlays |
| India River Explorer | State-by-state river browsing & filtering |
| Alerts | Critical + warning push notifications log |
| Weather | IMD weather data with rainfall forecasts |
| Monitors | CWC gauge station directory |
| City Detail | Deep-dive view for a single monitored city |
| State Matrix | State-level risk severity matrix |
| Model Info | On-device ML model transparency screen |
| Home | Bottom-nav shell |

---

## 🏗️ Architecture

```
android-flood-app/
├── lib/
│   ├── main.dart                    # App entry — dotenv, FCM, WorkManager init
│   ├── constants/                   # Domain-split constants (v2)
│   │   ├── app_config.dart          # API endpoints, polling, animation durations
│   │   ├── flood_thresholds.dart    # Severity %, water levels, risk colors/icons
│   │   ├── alert_channels.dart      # Notification channel IDs
│   │   ├── india_geodata.dart       # 36 states + 80+ CWC gauge cities
│   │   └── constants.dart           # Barrel export
│   ├── constants.dart               # @Deprecated shim — backward compat only
│   ├── config/                      # Runtime configuration
│   ├── ml/
│   │   └── flood_engine.dart        # On-device fallback ML (pure Dart, offline)
│   ├── models/                      # Data models (FloodResult, RiverData, etc.)
│   ├── providers/                   # Riverpod / ChangeNotifier state providers
│   ├── screens/                     # 13 UI screens
│   ├── services/                    # 15 data + business-logic services
│   ├── theme/                       # Dark theme, color tokens
│   └── widgets/                     # Shared reusable widgets
├── test/
│   └── constants_domain_test.dart   # 30 unit tests for constants layer
├── docs/
│   └── architecture/
│       └── flood_engine_boundary.md # On-device vs backend boundary contract
├── .env.example                     # Required environment variables
├── pubspec.yaml
├── SETUP.md
└── P2_IMD_NDMA_PLAN.md              # Phase 2 IMD + NDMA integration roadmap
```

---

## ⚙️ Services Layer (`lib/services/`)

| Service | Responsibility |
|---|---|
| `real_time_service.dart` | Primary data orchestrator — polls backend, triggers alerts |
| `real_time_river_service.dart` | Live CWC river gauge telemetry polling |
| `cwc_direct_service.dart` | Direct CWC API integration (raw gauge data) |
| `cwc_open_data_service.dart` | CWC Open Data portal scraper/parser |
| `cwc_live_provider.dart` | Provider wrapper for CWC live stream |
| `imd_service.dart` | IMD rainfall & weather data fetcher |
| `ndma_service.dart` | NDMA disaster alerts integration |
| `prediction_service.dart` | Calls FastAPI `/predict/legacy` endpoint |
| `prediction_facade.dart` | Facade: routes prediction to backend or on-device fallback |
| `predict.dart` | Low-level prediction request builder |
| `prediction_history_service.dart` | Persists prediction history locally |
| `api_service.dart` | Base HTTP client with retry & timeout logic |
| `fcm_service.dart` | Firebase Cloud Messaging — push notification handler |
| `background_service.dart` | WorkManager background polling (every 5 min) |
| `real_time_service_notif_patch.dart` | ⚠️ Temporary patch — pending merge into `real_time_service.dart` |

---

## 🤖 ML Architecture

### Backend (Primary)
- **XGBoost + RandomForest ensemble** trained on CWC historical flood data
- Hosted at `https://opsflood.onrender.com/predict/legacy`
- Feature inputs: rainfall (mm), river level (m), capacity (%), zone, river type, state severity
- Returns: `flood_probability`, `risk_level`, `confidence`

### On-Device Fallback (`lib/ml/flood_engine.dart`)
- Pure Dart heuristic engine — **no network required**
- Activates automatically when FastAPI backend is unreachable
- Always sets `isOfflineEstimate = true` on results
- Mirrors the state severity matrix from `state_severity_matrix.py` (backend)
- See [`docs/architecture/flood_engine_boundary.md`](docs/architecture/flood_engine_boundary.md) for the full contract

```
Online:   App → prediction_facade → FastAPI /predict/legacy → FloodResult
Offline:  App → prediction_facade → flood_engine.dart (Dart) → FloodResult (isOfflineEstimate=true)
```

---

## 📡 Data Sources

| Source | Data | Service |
|---|---|---|
| CWC (Central Water Commission) | Live river gauge levels, danger/warning thresholds | `cwc_direct_service`, `cwc_open_data_service` |
| IMD (India Meteorological Dept.) | Rainfall forecasts, weather data | `imd_service` |
| NDMA (National Disaster Mgmt. Authority) | Disaster alerts, state risk bulletins | `ndma_service` |
| OpsFlood FastAPI Backend | ML predictions, aggregated telemetry | `prediction_service`, `real_time_service` |
| Firebase Cloud Messaging | Push notification delivery | `fcm_service` |

---

## 🚀 Setup & Running

### Prerequisites
- Flutter SDK ≥ 3.x
- Dart SDK ≥ 3.x
- Android Studio / Xcode (for device/emulator)
- A `.env` file (copy from `.env.example`)

### 1. Clone & Install
```bash
git clone https://github.com/rohitg2800/android-flood-app.git
cd android-flood-app
flutter pub get
```

### 2. Configure Environment
```bash
cp .env.example .env
# Edit .env and set:
# BASE_URL=https://opsflood.onrender.com
# BACKUP_URL=           (optional)
```

### 3. Run
```bash
# Android (emulator or device)
flutter run

# iOS
flutter run -d ios

# With verbose logging
flutter run --verbose
```

### 4. Build Release APK
```bash
flutter build apk --release
# Output: build/app/outputs/flutter-apk/app-release.apk
```

> 📖 For full platform-specific setup (Firebase, permissions, signing), see [SETUP.md](SETUP.md).

---

## 🧪 Testing

```bash
# Run all tests
flutter test

# Run constants domain tests (30 tests)
flutter test test/constants_domain_test.dart
```

### Test Coverage
| Test File | Coverage Area | Tests |
|---|---|---|
| `constants_domain_test.dart` | `AppConfig`, `FloodThresholds`, `AlertChannels`, `IndiaGeodata` | 30 |

**Upcoming:** Service unit tests for `real_time_service`, `prediction_facade`, and `flood_engine` are planned (tracked in issues).

---

## 📦 Key Dependencies

| Package | Purpose |
|---|---|
| `flutter_riverpod` / `provider` | State management |
| `http` | HTTP client for API calls |
| `flutter_dotenv` | `.env` config loading |
| `firebase_messaging` | Push notifications (FCM) |
| `flutter_local_notifications` | On-device notification display |
| `workmanager` | Background periodic tasks |
| `flutter_map` + `latlong2` | Interactive India river maps |
| `fl_chart` | River level & weather charts |
| `shared_preferences` | Local prediction history persistence |
| `geolocator` | User location for nearest city detection |

> Full dependency list: [`pubspec.yaml`](pubspec.yaml)

---

## 🗂️ Constants Architecture (v2)

The old `lib/constants.dart` God-file has been split into four domain-focused files:

```dart
// New — use this in all new code:
import 'package:equinox_flood/constants/constants.dart';

AppConfig.baseUrl                  // API config
FloodThresholds.critical           // 90.0%
AlertChannels.criticalId           // 'opsflood_critical'
IndiaGeodata.monitoredCities       // 80+ CWC cities
```

The old `AppConstants` class is kept as a `@Deprecated` shim for backward compatibility during migration.

---

## 🔔 Notifications

OpsFlood uses a two-channel notification system:

| Channel | ID | Trigger |
|---|---|---|
| Critical Flood Alert | `opsflood_critical` | River capacity ≥ 90% |
| Flood Warning | `opsflood_warning` | River capacity ≥ 75% |

Background polling runs every **5 minutes** via WorkManager. FCM handles server-pushed alerts when the app is killed.

---

## 🗺️ Monitored Coverage

- **80+ cities** across all 28 states + 8 UTs
- CWC-published `danger_level` and `warning_level` (metres above sea level) per gauge
- Historical flood frequency (`flood_freq`) from NDMA/CWC hazard atlas
- River types: `perennial` · `seasonal` · `glacier` · `coastal`
- Zones: `himalayan` · `northeastern` · `peninsular` · `coastal` · `arid` · `central`

---

## 📋 Roadmap

- [ ] Merge `real_time_service_notif_patch.dart` into `real_time_service.dart`
- [ ] Break `india_rivers_screen.dart` (68KB) into sub-widgets
- [ ] Add unit tests for `real_time_service`, `prediction_facade`, `flood_engine`
- [ ] IMD + NDMA Phase 2 integration (see [`P2_IMD_NDMA_PLAN.md`](P2_IMD_NDMA_PLAN.md))
- [ ] Migrate all files from `AppConstants` → new domain constants
- [ ] Delete deprecated `lib/constants.dart` shim post-migration

---

## 👤 Author

**Rohit Kashyap** — MCA Student, IMCC Pune  
IBM Data Science Professional (12 Certifications)  
GitHub: [@rohitg2800](https://github.com/rohitg2800)

---

## 📄 License

This project is for educational and research purposes. All CWC/IMD/NDMA data is used under their respective open data policies.
