// lib/constants/app_constants.dart
//
// Static display constants only — ALL network settings in lib/config/app_config.dart.
//
// SCOPE: Bihar-only build.
// monitoredCities contains only the 3 CWC-monitored Bihar stations.
// All pan-India cities removed to prevent 404-spamming non-Bihar state endpoints.
//
// warning_level / danger_level: CWC FFS published gauge levels (metres)
// Sources: CWC Flood Forecasting bulletin 2024-25, CWC FFS station data.

import '../config/app_config.dart';

class AppConstants {
  static String   get baseUrl                   => AppConfig.baseUrl;
  static String   get backupBaseUrl             => '';
  static Duration get pollingInterval           => AppConfig.backgroundInterval;
  static Duration get realtimePollingInterval   => AppConfig.realtimeInterval;
  static int      get maxRetries                => AppConfig.maxRetries;

  static const String healthEndpoint            = AppConfig.epHealth;
  static const String liveTelemetryEndpoint     = AppConfig.epLiveTelemetry;
  static const String liveLevelsEndpoint        = AppConfig.epLiveLevels;
  static const String criticalAlertsEndpoint    = AppConfig.epCriticalAlerts;
  static const String predictLegacyEndpoint     = '/predict/legacy';
  static const String weatherCurrentEndpoint    = AppConfig.epWeatherCurrent;
  static const String weatherForecastEndpoint   = AppConfig.epWeatherForecast;
  static const String pipelineFeaturesEndpoint  = AppConfig.epPipelineFeatures;
  static const String pipelineManifestEndpoint  = AppConfig.epPipelineManifest;
  static const String stateSeverityEndpoint     = AppConfig.epStateSeverity;

  static const Map<String, int> riskColors = {
    'LOW':      0xFF34C759,
    'MODERATE': 0xFFF59E0B,
    'HIGH':     0xFFEF4444,
    'CRITICAL': 0xFF8B0000,
  };

  static const Map<String, String> riskIcons = {
    'LOW':      'SAFE',
    'MODERATE': 'WATCH',
    'HIGH':     'WARN',
    'CRITICAL': 'ALERT',
  };

  // ──────────────────────────────────────────────────────────────────────────────
  // MONITORED CITIES — Bihar only (3 CWC-gauged stations)
  // Trimmed from 55 pan-India cities to prevent 404 spam on non-Bihar endpoints.
  // warning_level: CWC warning gauge (m)   danger_level: CWC danger gauge (m)
  // hfl (highest flood level) is auto-derived as danger_level × 1.10 in RTRS
  // ──────────────────────────────────────────────────────────────────────────────
  static const List<Map<String, dynamic>> monitoredCities = [

    // Patna — CWC gauge Gandhi Ghat; WL 48.50 m, DL 50.27 m, HFL 52.50 m
    {
      'city': 'Patna', 'state': 'Bihar', 'river': 'Ganga',
      'lat': 25.5941, 'lon': 85.1376,
      'warning_level': 48.50, 'danger_level': 50.27, 'hfl': 52.50,
      'cwc_station': 'PAT',
    },
    // Supaul — CWC gauge Kosi at Supaul; WL 59.82 m, DL 60.82 m
    {
      'city': 'Supaul', 'state': 'Bihar', 'river': 'Kosi',
      'lat': 26.1225, 'lon': 86.6082,
      'warning_level': 59.82, 'danger_level': 60.82, 'hfl': 62.00,
      'cwc_station': 'SUP',
    },
    // Darbhanga — CWC gauge Bagmati at Hayaghat; WL 51.40 m, DL 53.40 m
    {
      'city': 'Darbhanga', 'state': 'Bihar', 'river': 'Bagmati',
      'lat': 26.1542, 'lon': 85.8918,
      'warning_level': 51.40, 'danger_level': 53.40, 'hfl': 55.20,
      'cwc_station': null,
    },
  ];

  static const double criticalThreshold = 90.0;
  static const double highThreshold     = 75.0;
  static const double moderateThreshold = 50.0;
  static const double lowThreshold      = 30.0;

  static const double defaultDangerLevel  = 3.0;
  static const double defaultWarningLevel = 2.5;
  static const double defaultSafeLevel    = 1.5;

  static const Duration shortAnimDuration  = Duration(milliseconds: 220);
  static const Duration mediumAnimDuration = Duration(milliseconds: 320);
  static const Duration longAnimDuration   = Duration(milliseconds: 600);

  static const String criticalAlertChannelId   = 'opsflood_critical';
  static const String criticalAlertChannelName = 'Critical Flood Alerts';
  static const String warningAlertChannelId    = 'opsflood_warning';
  static const String warningAlertChannelName  = 'Flood Warnings';

  // Bihar-scoped build — only Bihar listed.
  static const List<String> indianStates = [
    'Bihar',
  ];
}
