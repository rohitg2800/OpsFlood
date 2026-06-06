// lib/constants/app_constants.dart

class AppConstants {
  AppConstants._();

  // ── Network ──────────────────────────────────────────────────────────────
  static const Duration defaultTimeout       = Duration(seconds: 15);
  static const Duration longTimeout          = Duration(seconds: 30);
  static const Duration shortTimeout         = Duration(seconds: 5);
  static const int      maxRetries           = 3;
  static const Duration retryDelay           = Duration(seconds: 2);

  // ── Cache ───────────────────────────────────────────────────────────────
  static const Duration cacheTtlShort        = Duration(minutes: 5);
  static const Duration cacheTtlMedium       = Duration(minutes: 15);
  static const Duration cacheTtlLong         = Duration(hours: 1);
  static const Duration cacheTtlVeryLong     = Duration(hours: 6);

  // ── Polling ──────────────────────────────────────────────────────────────
  static const Duration pollIntervalFast     = Duration(minutes: 5);
  static const Duration pollIntervalNormal   = Duration(minutes: 15);
  static const Duration pollIntervalSlow     = Duration(minutes: 30);

  // ── Pagination ────────────────────────────────────────────────────────────
  static const int defaultPageSize           = 20;
  static const int maxPageSize               = 100;

  // ── UI ─────────────────────────────────────────────────────────────────
  static const double cardBorderRadius       = 12.0;
  static const double defaultPadding         = 16.0;
  static const double smallPadding           = 8.0;
  static const double largePadding           = 24.0;
  static const Duration animationFast        = Duration(milliseconds: 200);
  static const Duration animationNormal      = Duration(milliseconds: 350);
  static const Duration animationSlow        = Duration(milliseconds: 600);

  // ── Notification Channels ─────────────────────────────────────────────────
  static const String criticalAlertChannelId   = 'equinox_bh_critical';
  static const String criticalAlertChannelName = 'Critical Flood Alerts';
  static const String warningAlertChannelId    = 'equinox_bh_warning';
  static const String warningAlertChannelName  = 'Flood Warnings';
  static const String infoChannelId            = 'flood_info';
  static const String infoChannelName          = 'Flood Information';

  // ── Severity ──────────────────────────────────────────────────────────────
  static const List<String> severityLevels = [
    'LOW', 'MODERATE', 'SEVERE', 'CRITICAL',
  ];

  // ── Storage Keys ──────────────────────────────────────────────────────────
  static const String storageKeyTheme        = 'theme_mode';
  static const String storageKeyLastSync     = 'last_sync';
  static const String storageKeyAlerts       = 'cached_alerts';
  static const String storageKeyPredictions  = 'cached_predictions';
  static const String storageKeySourcePolicy = 'source_policy';

  // ── Flood thresholds ────────────────────────────────────────────────────
  static const double defaultWarningLevel = 7.0;
  static const double defaultDangerLevel  = 9.0;

  // ── Backend base URL alias ───────────────────────────────────────────────
  static const String baseUrl = 'https://equinox-bh.onrender.com';

  // ── Monitored cities ────────────────────────────────────────────────────
  // List<Map<String,dynamic>> — each entry has city, state, river,
  // warning_level (metres), danger_level (metres).
  // Used by RealTimeRiverService, CwcLiveProvider, StationStatusProvider.
  static const List<Map<String, dynamic>> monitoredCities = [
    {'city': 'Patna',          'state': 'Bihar', 'river': 'Ganga',      'warning_level': 49.27, 'danger_level': 50.27},
    {'city': 'Bhagalpur',      'state': 'Bihar', 'river': 'Ganga',      'warning_level': 32.23, 'danger_level': 33.23},
    {'city': 'Muzaffarpur',    'state': 'Bihar', 'river': 'Burhi Gandak','warning_level': 48.11, 'danger_level': 49.11},
    {'city': 'Darbhanga',      'state': 'Bihar', 'river': 'Kamla',      'warning_level': 51.68, 'danger_level': 52.68},
    {'city': 'Samastipur',     'state': 'Bihar', 'river': 'Burhi Gandak','warning_level': 42.60, 'danger_level': 43.60},
    {'city': 'Sitamarhi',      'state': 'Bihar', 'river': 'Bagmati',    'warning_level': 73.37, 'danger_level': 74.37},
    {'city': 'Supaul',         'state': 'Bihar', 'river': 'Kosi',       'warning_level': 67.50, 'danger_level': 68.50},
    {'city': 'Katihar',        'state': 'Bihar', 'river': 'Ganga',      'warning_level': 27.44, 'danger_level': 28.44},
    {'city': 'Purnia',         'state': 'Bihar', 'river': 'Saura',      'warning_level': 34.00, 'danger_level': 35.00},
    {'city': 'Saharsa',        'state': 'Bihar', 'river': 'Kosi',       'warning_level': 39.62, 'danger_level': 40.62},
    {'city': 'Madhubani',      'state': 'Bihar', 'river': 'Adhwara',    'warning_level': 59.00, 'danger_level': 60.00},
    {'city': 'Gopalganj',      'state': 'Bihar', 'river': 'Gandak',     'warning_level': 62.00, 'danger_level': 63.00},
    {'city': 'Siwan',          'state': 'Bihar', 'river': 'Gandak',     'warning_level': 60.50, 'danger_level': 61.50},
    {'city': 'Saran',          'state': 'Bihar', 'river': 'Ganga',      'warning_level': 48.00, 'danger_level': 49.00},
    {'city': 'Vaishali',       'state': 'Bihar', 'river': 'Ganga',      'warning_level': 49.00, 'danger_level': 50.00},
    {'city': 'Begusarai',      'state': 'Bihar', 'river': 'Burhi Gandak','warning_level': 39.00, 'danger_level': 40.00},
    {'city': 'Khagaria',       'state': 'Bihar', 'river': 'Kosi',       'warning_level': 32.00, 'danger_level': 33.00},
    {'city': 'Kishanganj',     'state': 'Bihar', 'river': 'Mahananda',  'warning_level': 35.00, 'danger_level': 36.00},
    {'city': 'Araria',         'state': 'Bihar', 'river': 'Bakra',      'warning_level': 52.00, 'danger_level': 53.00},
    {'city': 'East Champaran', 'state': 'Bihar', 'river': 'Gandak',     'warning_level': 75.00, 'danger_level': 76.00},
    {'city': 'West Champaran', 'state': 'Bihar', 'river': 'Gandak',     'warning_level': 80.00, 'danger_level': 81.00},
    {'city': 'Sheohar',        'state': 'Bihar', 'river': 'Bagmati',    'warning_level': 65.00, 'danger_level': 66.00},
  ];
}
