// lib/constants/app_constants.dart
//
// Static display constants only (colours, thresholds, city metadata).
// ALL network settings have moved to lib/config/app_config.dart.
// Do NOT add URLs, timeouts, or endpoints here.

import '../config/app_config.dart';

class AppConstants {
  // ── Delegate to AppConfig (backwards-compat aliases) ─────────────────────
  static String   get baseUrl              => AppConfig.baseUrl;
  static String   get backupBaseUrl        => '';           // no longer used
  static Duration get pollingInterval      => AppConfig.backgroundInterval;
  static Duration get realtimePollingInterval => AppConfig.realtimeInterval;
  static int      get maxRetries           => AppConfig.maxRetries;

  // ── Endpoint aliases (backwards-compat) ───────────────────────────────────
  static const String healthEndpoint          = AppConfig.epHealth;
  static const String liveTelemetryEndpoint   = AppConfig.epLiveTelemetry;
  static const String liveLevelsEndpoint      = AppConfig.epLiveLevels;
  static const String criticalAlertsEndpoint  = AppConfig.epCriticalAlerts;
  static const String predictLegacyEndpoint   = '/predict/legacy';
  static const String weatherCurrentEndpoint  = AppConfig.epWeatherCurrent;
  static const String weatherForecastEndpoint = AppConfig.epWeatherForecast;
  static const String pipelineFeaturesEndpoint  = AppConfig.epPipelineFeatures;
  static const String pipelineManifestEndpoint  = AppConfig.epPipelineManifest;
  static const String stateSeverityEndpoint     = AppConfig.epStateSeverity;

  // ── Risk colours (ARGB) ───────────────────────────────────────────────────
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

  // ── Monitored cities ──────────────────────────────────────────────────────
  static const List<Map<String, dynamic>> monitoredCities = [
    {'city': 'Guwahati',    'state': 'Assam',             'river': 'Brahmaputra', 'lat': 26.1445, 'lon': 91.7362, 'warning_level': 49.68, 'danger_level': 51.68, 'risk': 'HIGH'},
    {'city': 'Patna',       'state': 'Bihar',             'river': 'Ganga',       'lat': 25.5941, 'lon': 85.1376, 'warning_level': 48.50, 'danger_level': 50.27, 'risk': 'MODERATE'},
    {'city': 'Kochi',       'state': 'Kerala',            'river': 'Periyar',     'lat':  9.9312, 'lon': 76.2673, 'warning_level':  2.50, 'danger_level':  3.50, 'risk': 'HIGH'},
    {'city': 'Kolhapur',    'state': 'Maharashtra',       'river': 'Panchganga',  'lat': 16.7050, 'lon': 74.2433, 'warning_level': 39.00, 'danger_level': 43.00, 'risk': 'MODERATE'},
    {'city': 'Kolkata',     'state': 'West Bengal',       'river': 'Hooghly',     'lat': 22.5726, 'lon': 88.3639, 'warning_level':  3.67, 'danger_level':  4.57, 'risk': 'MODERATE'},
    {'city': 'Bhubaneswar', 'state': 'Odisha',            'river': 'Mahanadi',    'lat': 20.2961, 'lon': 85.8245, 'warning_level': 24.38, 'danger_level': 25.91, 'risk': 'MODERATE'},
    {'city': 'Mumbai',      'state': 'Maharashtra',       'river': 'Mithi',       'lat': 19.0760, 'lon': 72.8777, 'warning_level':  1.80, 'danger_level':  2.50, 'risk': 'LOW'},
    {'city': 'Chennai',     'state': 'Tamil Nadu',        'river': 'Adyar',       'lat': 13.0827, 'lon': 80.2707, 'warning_level':  1.50, 'danger_level':  2.00, 'risk': 'LOW'},
    {'city': 'Varanasi',    'state': 'Uttar Pradesh',     'river': 'Ganga',       'lat': 25.3176, 'lon': 82.9739, 'warning_level': 70.26, 'danger_level': 71.26, 'risk': 'MODERATE'},
    {'city': 'Prayagraj',   'state': 'Uttar Pradesh',     'river': 'Ganga',       'lat': 25.4358, 'lon': 81.8463, 'warning_level': 84.73, 'danger_level': 85.73, 'risk': 'MODERATE'},
    {'city': 'Haridwar',    'state': 'Uttarakhand',       'river': 'Ganga',       'lat': 29.9457, 'lon': 78.1642, 'warning_level':293.00, 'danger_level':294.00, 'risk': 'MODERATE'},
    {'city': 'Srinagar',    'state': 'Jammu and Kashmir', 'river': 'Jhelum',      'lat': 34.0837, 'lon': 74.7973, 'warning_level':  4.00, 'danger_level':  5.50, 'risk': 'HIGH'},
    {'city': 'Agartala',    'state': 'Tripura',           'river': 'Howrah',      'lat': 23.8315, 'lon': 91.2868, 'warning_level':  6.10, 'danger_level':  7.60, 'risk': 'HIGH'},
    {'city': 'Imphal',      'state': 'Manipur',           'river': 'Imphal',      'lat': 24.8170, 'lon': 93.9368, 'warning_level':  2.50, 'danger_level':  3.00, 'risk': 'MODERATE'},
    {'city': 'Shillong',    'state': 'Meghalaya',         'river': 'Umkhrah',     'lat': 25.5788, 'lon': 91.8933, 'warning_level':  2.00, 'danger_level':  3.00, 'risk': 'MODERATE'},
    {'city': 'Silchar',     'state': 'Assam',             'river': 'Barak',       'lat': 24.8333, 'lon': 92.7789, 'warning_level': 22.87, 'danger_level': 23.67, 'risk': 'HIGH'},
    {'city': 'Brahmapur',   'state': 'Odisha',            'river': 'Rushikulya',  'lat': 19.3149, 'lon': 84.7941, 'warning_level':  2.90, 'danger_level':  3.40, 'risk': 'MODERATE'},
    {'city': 'Vijayawada',  'state': 'Andhra Pradesh',    'river': 'Krishna',     'lat': 16.5062, 'lon': 80.6480, 'warning_level': 10.68, 'danger_level': 12.50, 'risk': 'HIGH'},
    {'city': 'Hyderabad',   'state': 'Telangana',         'river': 'Musi',        'lat': 17.3850, 'lon': 78.4867, 'warning_level':  3.50, 'danger_level':  4.00, 'risk': 'MODERATE'},
    {'city': 'Surat',       'state': 'Gujarat',           'river': 'Tapi',        'lat': 21.1702, 'lon': 72.8311, 'warning_level':  5.00, 'danger_level':  7.00, 'risk': 'MODERATE'},
    {'city': 'Rajkot',      'state': 'Gujarat',           'river': 'Aji',         'lat': 22.3039, 'lon': 70.8022, 'warning_level':  2.50, 'danger_level':  3.50, 'risk': 'LOW'},
    {'city': 'Jabalpur',    'state': 'Madhya Pradesh',    'river': 'Narmada',     'lat': 23.1815, 'lon': 79.9864, 'warning_level': 11.88, 'danger_level': 13.41, 'risk': 'MODERATE'},
    {'city': 'Nashik',      'state': 'Maharashtra',       'river': 'Godavari',    'lat': 19.9975, 'lon': 73.7898, 'warning_level': 12.00, 'danger_level': 14.00, 'risk': 'MODERATE'},
    {'city': 'Pune',        'state': 'Maharashtra',       'river': 'Mutha',       'lat': 18.5204, 'lon': 73.8567, 'warning_level':  3.00, 'danger_level':  4.50, 'risk': 'MODERATE'},
  ];

  // ── CWC threshold levels (%) ──────────────────────────────────────────────
  static const double criticalThreshold = 90.0;
  static const double highThreshold     = 75.0;
  static const double moderateThreshold = 50.0;
  static const double lowThreshold      = 30.0;

  // ── Default gauge levels ──────────────────────────────────────────────────
  static const double defaultDangerLevel  = 3.0;
  static const double defaultWarningLevel = 2.5;
  static const double defaultSafeLevel    = 1.5;

  // ── Animation durations ───────────────────────────────────────────────────
  static const Duration shortAnimDuration  = Duration(milliseconds: 220);
  static const Duration mediumAnimDuration = Duration(milliseconds: 320);
  static const Duration longAnimDuration   = Duration(milliseconds: 600);

  // ── Notification channels ─────────────────────────────────────────────────
  static const String criticalAlertChannelId   = 'opsflood_critical';
  static const String criticalAlertChannelName = 'Critical Flood Alerts';
  static const String warningAlertChannelId    = 'opsflood_warning';
  static const String warningAlertChannelName  = 'Flood Warnings';

  // ── Indian states + UTs ───────────────────────────────────────────────────
  static const List<String> indianStates = [
    'Andhra Pradesh', 'Arunachal Pradesh', 'Assam', 'Bihar',
    'Chhattisgarh', 'Goa', 'Gujarat', 'Haryana',
    'Himachal Pradesh', 'Jharkhand', 'Karnataka', 'Kerala',
    'Madhya Pradesh', 'Maharashtra', 'Manipur', 'Meghalaya',
    'Mizoram', 'Nagaland', 'Odisha', 'Punjab',
    'Rajasthan', 'Sikkim', 'Tamil Nadu', 'Telangana',
    'Tripura', 'Uttar Pradesh', 'Uttarakhand', 'West Bengal',
    'Andaman and Nicobar Islands', 'Chandigarh',
    'Dadra and Nagar Haveli and Daman and Diu',
    'Delhi', 'Jammu and Kashmir', 'Ladakh',
    'Lakshadweep', 'Puducherry',
  ];
}
