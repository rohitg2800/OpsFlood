// lib/data/direct_sources.dart
//
// ╔══════════════════════════════════════════════════════════════════════════╗
// ║  OpsFlood — LAYER 3: Direct (No-Backend) API URL Builders             ║
// ║                                                                          ║
// ║  Sources that are CORS-safe from Flutter (mobile client):              ║
// ║    A) Open-Meteo  — weather + GloFAS river discharge (free, no key)    ║
// ║    C) data.gov.in — reservoir levels (public JSON)                     ║
// ║    D) IMD RSS     — weather alerts (public XML feed)                   ║
// ║                                                                          ║
// ║  Sources that need OpsFlood proxy (CORS-blocked from mobile):          ║
// ║    B) CWC FFS     — routed via AppConfig.epCwcFfs on OpsFlood backend  ║
// ╚══════════════════════════════════════════════════════════════════════════╝
library;

import '../config/app_config.dart';

// ═════════════════════════════════════════════════════════════════════════════
// A) Open-Meteo — Weather (current + hourly forecast)
// Docs: https://open-meteo.com/en/docs
// No API key. Free tier: 10,000 requests/day.
// ═════════════════════════════════════════════════════════════════════════════
class OpenMeteoUrls {
  OpenMeteoUrls._();

  static const _base = 'https://api.open-meteo.com/v1';

  /// Current conditions + 24h hourly precipitation & soil moisture.
  static String weather(double lat, double lon) =>
      '$_base/forecast'
      '?latitude=$lat&longitude=$lon'
      '&current=temperature_2m,relative_humidity_2m,precipitation,rain,'
      'windspeed_10m,winddirection_10m,weathercode'
      '&hourly=precipitation,precipitation_probability,soil_moisture_0_1cm'
      '&forecast_days=2'
      '&timezone=Asia%2FKolkata';

  /// GloFAS river-discharge forecast (m³/s) — 30-day look-ahead.
  /// Docs: https://open-meteo.com/en/docs/flood-api
  static String riverDischarge(double lat, double lon) =>
      'https://flood-api.open-meteo.com/v1/flood'
      '?latitude=$lat&longitude=$lon'
      '&daily=river_discharge'
      '&forecast_days=16'
      '&past_days=7';

  /// Ensemble discharge for uncertainty ribbon (optional, heavier).
  static String riverDischargeEnsemble(double lat, double lon) =>
      'https://flood-api.open-meteo.com/v1/flood'
      '?latitude=$lat&longitude=$lon'
      '&daily=river_discharge_mean,river_discharge_max,river_discharge_min'
      '&forecast_days=16';
}

// ═════════════════════════════════════════════════════════════════════════════
// B) CWC FFS — via OpsFlood proxy (CORS not allowed from mobile)
// The proxy endpoint is defined in AppConfig; only URL helper here.
// ═════════════════════════════════════════════════════════════════════════════
class CwcProxyUrls {
  CwcProxyUrls._();

  /// Full URL to fetch a CWC FFS station via the OpsFlood proxy.
  /// e.g.  CwcProxyUrls.station('GUW')
  static String station(String stationCode) =>
      '${AppConfig.baseUrl}${AppConfig.epCwcFfs}/$stationCode';

  /// All CWC stations registry.
  static String get stationsRegistry =>
      '${AppConfig.baseUrl}${AppConfig.epCwcStations}';
}

// ═════════════════════════════════════════════════════════════════════════════
// C) data.gov.in — Reservoir Level Dataset
// API: https://data.gov.in/resource/reservoir-levels-central-water-commission
// No auth needed for public datasets. Limit=100 returns latest batch.
// ═════════════════════════════════════════════════════════════════════════════
class DataGovUrls {
  DataGovUrls._();

  // Public dataset resource IDs on data.gov.in
  static const _reservoirResourceId = '3b01bcb8-0b14-4abf-b6f2-c1bfd384ba69';

  static String get reservoirLevels =>
      'https://api.data.gov.in/resource/$_reservoirResourceId'
      '?api-version=2.0&format=json&limit=100&offset=0';

  /// Filter by state (uses OData-style filter; not all datasets support it).
  static String reservoirByState(String state) =>
      'https://api.data.gov.in/resource/$_reservoirResourceId'
      '?api-version=2.0&format=json&limit=50&filters[state]=${Uri.encodeComponent(state)}';

  // Flood relief camps dataset
  static const _reliefCampsResourceId = 'f6a5a9d2-3b3e-4b4b-8e8e-1a1a1a1a1a1a';
  static String get reliefCamps =>
      'https://api.data.gov.in/resource/$_reliefCampsResourceId'
      '?api-version=2.0&format=json&limit=100';
}

// ═════════════════════════════════════════════════════════════════════════════
// D) IMD RSS — Weather Alerts (public XML)
// No key required. Updated every 3–6 hours by IMD.
// ═════════════════════════════════════════════════════════════════════════════
class ImdRssUrls {
  ImdRssUrls._();

  /// National weather warning RSS (heavy rain, cyclone, thunderstorm).
  static const String nationalAlerts =
      'https://sachet.ndma.gov.in/cap_public_website/FeedPage';

  /// IMD public RSS — all India weather bulletins.
  static const String bulletins =
      'https://mausam.imd.gov.in/backend/rss_en.php';

  /// Cyclone track feed (active only during season).
  static const String cyclone =
      'https://mausam.imd.gov.in/backend/cyclone_rss_en.php';
}

// ═════════════════════════════════════════════════════════════════════════════
// E) OpsFlood ML Inference — POST to /predict
// Defined here for reference; actual call is in MlInferenceService.
// ═════════════════════════════════════════════════════════════════════════════
class OpsFloodUrls {
  OpsFloodUrls._();

  static String get predict => '${AppConfig.baseUrl}${AppConfig.epPredict}';
  static String get health  => '${AppConfig.baseUrl}${AppConfig.epHealth}';
}
