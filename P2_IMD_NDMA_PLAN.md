# OpsFlood — P2 IMD + NDMA Integration Notes

## Added Services
- `lib/services/imd_service.dart`
- `lib/services/ndma_service.dart`

These are **non-breaking scaffolds**. They do not modify any current screen, provider, or singleton wiring.

## Why this before Riverpod?
- Riverpod migration would require touching all ~10 screens and app boot wiring.
- IMD + NDMA integration adds authoritative India-specific feeds with minimal risk.
- This preserves app stability while expanding real-world usefulness.

## Intended backend endpoints

### IMD
- `GET /api/imd/alerts?state=Maharashtra`
- `GET /api/imd/rainfall?state=Maharashtra&days=3`
- `GET /api/imd/nowcast?district=Pune`

### NDMA / NDRF
- `GET /api/ndma/advisories?state=Maharashtra`
- `GET /api/ndrf/contacts?state=Maharashtra`
- `GET /api/disaster/shelters?district=Pune`

## Recommended next UI steps
1. Add an "Official Alerts" card to `weather_screen.dart` powered by `ImdService.instance.getAlerts(state: ...)`
2. Add an "Emergency Contacts" section to `alerts_screen.dart` powered by `NdmaService.instance.getContacts(state: ...)`
3. Add a district drill-down screen with:
   - IMD warnings
   - CWC gauge level
   - NDMA advisory
   - NDRF / SDRF contact numbers
4. Add attribution footer:
   - CWC
   - IMD
   - NDMA / NDRF

## Recommended backend sequence
1. Implement `/api/imd/alerts`
2. Implement `/api/ndma/advisories`
3. Implement `/api/ndrf/contacts`
4. Then wire to screens

## Riverpod after this
Once the new official-data surfaces are visible and stable, migrate to Riverpod in one clean sprint:
- `realTimeServiceProvider`
- `imdAlertsProvider(state)`
- `ndmaContactsProvider(state)`
- `predictionProvider(input)`
