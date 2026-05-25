# OpsFlood Android App

React Native app for **OpsFlood** — India Flood Intelligence.

## Architecture

```
android/
  src/
    config/api.ts          ← Base URL config (mirrors frontend)
    types/
      health.ts            ← HealthResponse + SourcePolicy types
      telemetry.ts         ← SensorNode + LiveTelemetryResponse types
    hooks/
      useHealth.ts         ← Polls /health every 60s, exposes allowLiveCWC
      useLiveTelemetry.ts  ← Polls /api/live-telemetry, gated by allowLiveCWC
    components/
      SourcePolicyBanner   ← Option B: always-visible policy status strip
      PolicyLockedScreen   ← Option A: full-screen gate when CWC is locked
      SensorCard           ← Individual sensor node card
    screens/
      HomeScreen           ← Server health + source policy detail + public sources
      TelemetryScreen      ← Live sensor feed with state selector chip bar
    App.tsx                ← Bottom tab navigator
```

## Source Policy Integration

### Option A — UI Gating
`TelemetryScreen` reads `allowLiveCWC` from `useHealth`. When `allow_live_cwc_in_app: false` is returned by `/health`, the live feed is replaced by `PolicyLockedScreen` instead of making a failed telemetry call.

### Option B — Status Banner
`SourcePolicyBanner` is rendered at the top of every screen. It colour-codes:
- 🟢 Green — `allow_live_cwc_in_app: true` and server online (current state)
- 🟡 Amber — policy active but CWC locked
- 🔴 Red — server unreachable

The banner shows `mode`, `telemetry_mode`, and `label` directly from the `/health` `source_policy` object.

## Setup

```bash
cd android
npm install

# Android
npx react-native run-android
```

### Change the backend URL
Edit `src/config/api.ts`:
```ts
export const API_BASE_URL = 'https://opsflood.onrender.com'; // or http://10.0.2.2:8000 for local emulator
```

> **Emulator note**: Android emulator maps `10.0.2.2` → your machine's `localhost:8000`.
