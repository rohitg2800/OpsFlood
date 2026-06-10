# OpsFlood — Google Play Store Submission Checklist

> Last updated: Module 10

---

## 1. App Bundle

- [ ] `flutter build appbundle --release --obfuscate --split-debug-info=build/debug-info`
- [ ] `.aab` file is under **150 MB** (current target: ~45 MB after NDK abiFilters)
- [ ] Upload debug symbols ZIP to Play Console → App Bundle Explorer
- [ ] minSdkVersion ≥ 21 (Android 5.0) — confirmed in `build.gradle`
- [ ] targetSdkVersion = 34 — confirmed in `build.gradle`
- [ ] multiDexEnabled = true — confirmed
- [ ] ProGuard rules applied — `proguard-rules.pro` present

---

## 2. Signing

- [ ] Upload keystore generated: `keytool -genkey -v -keystore upload.jks -keyalg RSA -keysize 2048 -validity 25000 -alias upload`
- [ ] `KEYSTORE_BASE64` GitHub secret set
- [ ] `KEYSTORE_PASSWORD`, `KEY_ALIAS`, `KEY_PASSWORD` secrets set
- [ ] Play App Signing enrolled (Google holds delivery key)

---

## 3. Store Listing

### Basic
- [ ] App name: **OpsFlood — Bihar Flood Monitor**
- [ ] Short description (≤80 chars): `Real-time Bihar river levels, CWC alerts & AI flood prediction`
- [ ] Full description (≤4000 chars): see `docs/store_description.md`
- [ ] Category: **Weather** (or News & Magazines)
- [ ] Content rating: **Everyone**
- [ ] App icon: 512×512 PNG (no alpha)
- [ ] Feature graphic: 1024×500 PNG

### Screenshots (minimum per type)
- [ ] Phone: 4 screenshots (1080×1920 or 16:9)
  1. Dashboard with live river levels
  2. Bihar map with flood markers
  3. Alert screen (danger + emergency)
  4. Export PDF preview
- [ ] 7-inch tablet: 2 screenshots (optional but recommended)

---

## 4. Privacy & Permissions

- [ ] Privacy policy URL set in Play Console
  - Minimum: `https://rohitg2800.github.io/android-flood-app/privacy`
- [ ] Data safety form completed:
  | Data type | Collected | Shared | Required |
  |---|---|---|---|
  | Location (approx) | No | No | — |
  | Device ID | No | No | — |
  | Push token (FCM) | Yes | No (Firebase only) | For alerts |
  | Crash logs | Yes (Firebase Crashlytics) | No | For stability |
- [ ] `POST_NOTIFICATIONS` permission declared (Android 13+)
- [ ] `INTERNET` permission declared
- [ ] `RECEIVE_BOOT_COMPLETED` declared (for rescheduling data fetch)
- [ ] No `READ_CONTACTS`, `CAMERA`, or `RECORD_AUDIO` — confirm absence

---

## 5. Firebase & APIs

- [ ] `google-services.json` in `android/app/` (not committed — in CI secret)
- [ ] Firebase project set to **production** (not emulator)
- [ ] FCM default channel ID matches `NotificationChannelService` constants
- [ ] CWC API key rotated for production (not the dev key)
- [ ] Rate-limit headers respected — `DataFetchEngine` refresh ≥10 min for release

---

## 6. Testing

- [ ] `flutter test` passes with 0 failures
- [ ] Widget tests pass: `test/widget/`
- [ ] Unit tests pass: `test/unit/`
- [ ] Manual smoke test on Android 10, 12, 14 physical devices
- [ ] Tested with TalkBack enabled (Accessibility Module 9)
- [ ] Tested with "Remove animations" enabled (Reduced-motion Module 9)
- [ ] Tested with Hindi locale
- [ ] Offline mode: kills WiFi, verifies Hive cache serves data
- [ ] Background alert: app in background, trigger threshold — verify heads-up

---

## 7. Pre-launch Report (Play Console)

- [ ] Upload to **Internal Testing** track first
- [ ] Review Pre-launch Report for crashes
- [ ] Review Pre-launch Accessibility scan
- [ ] Fix any ANR (Application Not Responding) issues

---

## 8. Release Track Progression

```
Internal Testing (dev team, 5 testers)
  ↓  1 week
Closed Testing — Alpha (50 users, Bihar flood-watch volunteers)
  ↓  2 weeks
Open Testing — Beta (all users, opt-in)
  ↓  1 week stable
Production — 20% staged rollout
  ↓  48 hours no crash spike
Production — 100% rollout
```

---

## 9. Post-launch Monitoring

- [ ] Firebase Crashlytics dashboard bookmarked
- [ ] ANR rate target: < 0.47% (Play policy threshold)
- [ ] Crash rate target: < 1.09%
- [ ] Play Console → Android vitals alerts configured for email
- [ ] FCM delivery rate monitored in Firebase Console

---

## 10. Module completion gate

All modules 1–10 merged to `main` → CI green → submit to Internal Testing.
