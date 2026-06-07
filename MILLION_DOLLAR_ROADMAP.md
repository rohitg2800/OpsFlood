# 💰 OpsFlood — Million Dollar App Roadmap

> Audit date: June 2026 | Stack: Flutter + Python backend + Firebase + Render

This document is the complete blueprint to transform OpsFlood from a
Bihar flood monitor into a **nationally scalable, monetisable, life-saving
platform** worth ₹8–10 Cr (≈ $1M+).

---

## ✅ WHAT YOU ALREADY HAVE (Solid Foundation)

| Layer | Status | Detail |
|---|---|---|
| Flutter app (Android + iOS + Web) | ✅ Built | Multi-platform Flutter 3.x |
| Real-time flood gauge data | ✅ Built | 31 stations, 13 rivers, CWC+WRD |
| Weather overlay (WeatherAPI) | ✅ Built | Temp, rain index, humidity, UV |
| Bihar river deep metadata | ✅ Built | 10 rivers, basin profiles, flood history |
| Risk classification (CRITICAL/SEVERE/MODERATE/LOW) | ✅ Built | Priority-based scoring |
| Multi-language (l10n) | ✅ Built | l10n.yaml scaffold |
| Backend (Python + Render) | ✅ Built | Render deploy + Dockerfile |
| Firebase integration | ✅ Scaffolded | firebase.json present |
| CI/CD (.github workflows) | ✅ Present | GitHub Actions |
| Docker | ✅ Present | Dockerfile + dockerignore |

---

## 🚀 PHASE 1 — Core Value (Do First, 2–4 weeks)
_These 5 features alone will make the app 10x more useful and get government adoption._

### 1.1 🔔 Push Notifications (CRITICAL alert when river crosses danger level)
- **Why**: Life-saving. Users need alerts even when app is closed.
- **How**: Firebase Cloud Messaging (FCM). Backend sends push when
  `currentLevel >= dangerLevel` for any gauge.
- **Files to create**:
  - `lib/services/notification_service.dart`
  - `backend/notifier.py` (FCM trigger logic)
  - `android/app/google-services.json` (FCM config)
- **Revenue impact**: Makes app sticky. DAU retention goes from 20% → 70%+.

### 1.2 🗺️ Interactive Flood Map Screen
- **Why**: Visual map is the #1 requested feature for disaster apps.
- **How**: `flutter_map` + OpenStreetMap tiles + gauge markers color-coded by risk.
  Show inundation polygons for historical floods (GeoJSON from NDMA).
- **Files to create**:
  - `lib/screens/map_screen.dart`
  - `lib/widgets/gauge_map_marker.dart`
  - `assets/geojson/bihar_flood_zones.geojson`
- **Revenue impact**: Makes app shareable (screenshots go viral on social media during floods).

### 1.3 📊 Historical Trend Charts (river level last 7/30/90 days)
- **Why**: Shows flood trajectory — is level rising or falling? Priceless insight.
- **How**: `fl_chart` package. Backend stores time-series in SQLite/Postgres.
  Frontend fetches `/api/history/{station}?days=7`.
- **Files to create**:
  - `lib/screens/trend_screen.dart`
  - `lib/widgets/level_chart.dart`
  - `backend/routes/history.py`
- **Revenue impact**: Data depth → premium subscription justification.

### 1.4 🌐 Hindi Language Support (full translation)
- **Why**: 80%+ of Bihar users are Hindi-first. Currently only English.
- **How**: Add `lib/l10n/app_hi.arb` with all 60+ string keys translated.
- **Files to create**:
  - `lib/l10n/app_hi.arb`
- **Revenue impact**: 5x user base expansion in Bihar/UP/MP market.

### 1.5 📱 Offline Mode (cached last reading + offline river data)
- **Why**: During actual floods, internet connectivity fails. App must work offline.
- **How**: `hive` or `shared_preferences` cache. Show "Last known" badge when offline.
- **Files to create**:
  - `lib/services/cache_service.dart`
  - `lib/providers/offline_provider.dart`
- **Revenue impact**: Only flood app in India that works offline during disaster = unique selling point.

---

## 🔥 PHASE 2 — Differentiation (4–8 weeks)
_These features create a defensible moat that competitors can't copy easily._

### 2.1 🤖 AI Flood Prediction (24h/72h forecast)
- **Why**: Prediction is 100x more valuable than real-time data alone.
- **How**: LSTM/GRU model trained on 20yr CWC gauge data + IMD rainfall forecast.
  Expose as `/api/predict/{station}` endpoint. Show predicted level chart in app.
- **Files to create**:
  - `backend/ml/flood_predictor.py`
  - `backend/ml/model_train.py`
  - `lib/widgets/prediction_chart.dart`
- **Data needed**: CWC historical gauge CSV (request via RTI or download from
  `https://www.india-water.gov.in`)
- **Revenue impact**: NGOs, insurance companies, and govt pay ₹5–25L/yr for this data.

### 2.2 🆘 SOS / Emergency Contacts Screen
- **Why**: App becomes the FIRST thing people open during a flood emergency.
- **How**: Screen with clickable call buttons for:
  NDRF (9711077372), SDRF Bihar, Flood Control Room (0612-2294204),
  District Magistrate numbers (per district), nearest hospital, Red Cross.
- **Files to create**:
  - `lib/screens/sos_screen.dart`
  - `lib/data/emergency_contacts.dart`
- **Revenue impact**: Makes app a life-safety tool → government endorsement → official distribution.

### 2.3 📡 Expand to All 17 Flood-Prone Indian States
- Bihar is 1 of 17 flood-prone states. Expand data layer to:
  Assam, West Bengal, Odisha, Uttar Pradesh, Uttarakhand, Himachal Pradesh,
  Kerala, Maharashtra (Konkan), Gujarat, Andhra Pradesh, Telangana, Jharkhand,
  Chhattisgarh, Rajasthan (desert floods), Punjab, Manipur, Arunachal Pradesh.
- **How**: Create `kStateGauges` map per state. CWC publishes gauge data for all.
- **Files to create**:
  - `lib/data/state_gauges/assam_gauges.dart`
  - `lib/data/state_gauges/wb_gauges.dart`
  - (one file per state)
- **Revenue impact**: 50M+ potential users → VC fundable product.

### 2.4 📰 News + Alert Feed (NDMA + IMD bulletins)
- **Why**: Users want context, not just numbers.
- **How**: Parse RSS feeds from:
  - IMD: `https://mausam.imd.gov.in/rss/`
  - NDMA: `https://ndma.gov.in/`
  - Bihar WRD bulletins: `https://www.fmiscwrdbihar.gov.in/bulletin/`
- **Files to create**:
  - `lib/screens/news_screen.dart`
  - `backend/scrapers/ndma_feed.py`
  - `backend/scrapers/imd_feed.py`

### 2.5 📍 User Location + Nearest Gauge
- **Why**: "Am I in danger?" is the first question every user asks.
- **How**: `geolocator` package. Find nearest BiharGauge by haversine distance.
  Show personalized risk banner at top of home screen.
- **Files to create**:
  - `lib/services/location_service.dart`
  - `lib/widgets/my_location_banner.dart`

---

## 💎 PHASE 3 — Monetisation (8–16 weeks)
_This is where the million dollars actually comes from._

### 3.1 💳 Premium Subscription (₹99/month or ₹799/year)
**Free tier**: Real-time levels, 3 rivers, basic alerts
**Pro tier** (₹99/mo):
- All 17 states
- 72h AI prediction
- Unlimited alert subscriptions
- Historical data export (CSV)
- No ads
- Priority data refresh (30s vs 5min)

**Implementation**:
- `lib/services/subscription_service.dart`
- RevenueCat or Razorpay subscription API
- `lib/screens/paywall_screen.dart`

### 3.2 🏛️ B2G (Government) Sales — ₹10–50L contracts
Target buyers:
- Bihar State Disaster Management Authority (BSDMA)
- NDRF regional HQ Patna
- CWC (Central Water Commission)
- State Irrigation Departments (17 states)
- UNDP / World Bank disaster resilience programs

**What to offer**:
- White-label dashboard with dept branding
- API access for integration into govt portals
- Custom alert thresholds per district
- Data export + PDF reports
- SLA-backed uptime guarantee

**Files to create**:
- `docs/government_proposal.pdf`
- `backend/api/enterprise_api.py` (API key auth)
- `lib/screens/admin_dashboard_screen.dart`

### 3.3 🏢 B2B SaaS — Insurance & Agriculture
**Insurance companies** (LIC, ICICI Lombard, Bajaj Allianz):
- Sell flood risk scores per pin-code for crop insurance underwriting
- API: `/api/risk-score/{pincode}` → JSON with risk level + historical flood frequency
- Pricing: ₹2–5L/yr per insurance company

**Agriculture / FPOs**:
- Flood-risk alerts for farmers (SMS + push)
- When to evacuate livestock / harvest early
- Partner with e-Nam, APMC markets

### 3.4 📢 Non-Intrusive Ads (free tier)
- Google AdMob banner ads on free tier only
- Contextual: show govt flood relief scheme ads, insurance ads
- Expected: ₹0.50–2 CPM in Bihar market
- Files: `lib/widgets/ad_banner.dart`

### 3.5 🌍 International Expansion
**Bangladesh**: Same river systems (Ganga-Brahmaputra-Meghna basin).
**Nepal**: Upstream data is critical — Nepal govt would pay.
**Vietnam, Bangladesh, Pakistan**: High flood frequency, low-quality local apps.
**Revenue model**: License the platform per country at $50K–$200K/yr.

---

## 🏗️ PHASE 4 — Platform & Scale (16–24 weeks)

### 4.1 ☁️ Migrate Backend to Scalable Infrastructure
- Current: Single Render instance (fine for MVP)
- Target: AWS/GCP with:
  - Redis cache for gauge data (sub-second reads)
  - PostgreSQL + TimescaleDB for time-series gauge history
  - Celery workers for background gauge scraping every 15 min
  - CDN for static assets

### 4.2 👥 Community Reports (crowdsourced flood reports)
- Users can submit "flood report" with photo + GPS location
- Validated by 3+ confirmations → shown on map as verified report
- **This becomes the most valuable dataset in India flood response**
- Files:
  - `lib/screens/report_screen.dart`
  - `backend/routes/community_reports.py`
  - Firebase Storage for photo uploads

### 4.3 🔗 Open API (developer ecosystem)
- Public API with API key auth at `api.opsflood.in`
- Free tier: 1000 calls/day
- Paid: ₹999/mo for 100K calls/day
- This creates a developer ecosystem around your data

### 4.4 🏆 Gamification + Civic Engagement
- "Flood Reporter" badges for community contributors
- Leaderboard for most active districts
- Share flood status to WhatsApp (most viral channel in Bihar)
- Referral program: refer 3 friends → 1 month free Pro

---

## 📊 REVENUE PROJECTIONS

| Stream | Year 1 | Year 2 | Year 3 |
|---|---|---|---|
| Premium subscriptions (₹99/mo) | ₹12L | ₹60L | ₹2Cr |
| Government contracts | ₹25L | ₹1.5Cr | ₹4Cr |
| Insurance/B2B API | ₹10L | ₹50L | ₹2Cr |
| AdMob (free tier) | ₹3L | ₹15L | ₹40L |
| International licensing | ₹0 | ₹30L | ₹1.5Cr |
| **TOTAL** | **₹50L** | **₹2.55Cr** | **₹9.9Cr** |

**Year 3 = ₹9.9 Cr ≈ $1.2M** ✅

---

## 🎯 IMMEDIATE ACTION PLAN (Next 7 days)

Priority order — do these first:

1. **Day 1–2**: Add `app_hi.arb` (Hindi strings) — zero-code, maximum reach
2. **Day 2–3**: Wire FCM push notifications for danger-level breach
3. **Day 3–4**: Build `map_screen.dart` with `flutter_map`
4. **Day 4–5**: Add SOS screen with emergency contacts
5. **Day 5–7**: Historical trend chart (`fl_chart`)

---

## 🔑 KEY PACKAGES TO ADD (pubspec.yaml)

```yaml
dependencies:
  flutter_map: ^6.1.0        # Interactive maps
  fl_chart: ^0.68.0          # Trend charts
  firebase_messaging: ^14.9.0 # Push notifications
  geolocator: ^11.0.0        # User location
  hive_flutter: ^1.1.0       # Offline cache
  google_mobile_ads: ^5.1.0  # AdMob
  purchases_flutter: ^7.3.0  # RevenueCat subscriptions
  share_plus: ^9.0.0         # WhatsApp sharing
  url_launcher: ^6.2.6       # SOS call buttons
  cached_network_image: ^3.3.1 # Image caching
```

---

## 🏆 COMPETITIVE ADVANTAGE SUMMARY

You win because:
1. **Deepest Bihar data** — 31 stations, 13 rivers, basin profiles. No competitor has this.
2. **Offline-first** — works when internet dies during flood (unique in India)
3. **AI prediction** — 24h ahead warning vs just current data
4. **Government-grade accuracy** — CWC + WRD official data sources
5. **Hindi-first UX** — serves the actual flood victim population
6. **Community reports** — crowdsourced ground truth no govt has
7. **Multi-state scalability** — one platform, 17 states, 50M users TAM

---

_Built with OpsFlood — Saving lives through data._
