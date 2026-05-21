class AppConstants {
  static const String baseUrl = 'https://opsflood.onrender.com';
  static const String backupBaseUrl = 'https://opsflood-backend.onrender.com';

  static const String healthEndpoint = '/health';
  static const String liveTelemetryEndpoint = '/api/live-telemetry';
  static const String liveLevelsEndpoint = '/api/live-levels';
  static const String criticalAlertsEndpoint = '/api/critical-alerts';
  static const String predictLegacyEndpoint = '/predict/legacy';
  static const String weatherCurrentEndpoint = '/weather/current';
  static const String weatherForecastEndpoint = '/weather/forecast';

  static const Map<String, int> riskColors = {
    'LOW': 0xFF34C759,
    'MODERATE': 0xFFF59E0B,
    'HIGH': 0xFFEF4444,
    'CRITICAL': 0xFF8B0000,
  };

  static const Map<String, String> riskIcons = {
    'LOW': 'SAFE',
    'MODERATE': 'WATCH',
    'HIGH': 'WARN',
    'CRITICAL': 'ALERT',
  };

  static const List<Map<String, dynamic>> monitoredCities = [
    {
      'city': 'Guwahati',
      'state': 'Assam',
      'river': 'Brahmaputra',
      'lat': 26.1445,
      'lon': 91.7362,
      'risk': 'HIGH'
    },
    {
      'city': 'Patna',
      'state': 'Bihar',
      'river': 'Ganga',
      'lat': 25.5941,
      'lon': 85.1376,
      'risk': 'MODERATE'
    },
    {
      'city': 'Kochi',
      'state': 'Kerala',
      'river': 'Periyar',
      'lat': 9.9312,
      'lon': 76.2673,
      'risk': 'HIGH'
    },
    {
      'city': 'Kolhapur',
      'state': 'Maharashtra',
      'river': 'Panchganga',
      'lat': 16.7050,
      'lon': 74.2433,
      'risk': 'MODERATE'
    },
    {
      'city': 'Kolkata',
      'state': 'West Bengal',
      'river': 'Hooghly',
      'lat': 22.5726,
      'lon': 88.3639,
      'risk': 'MODERATE'
    },
    {
      'city': 'Bhubaneswar',
      'state': 'Odisha',
      'river': 'Mahanadi',
      'lat': 20.2961,
      'lon': 85.8245,
      'risk': 'MODERATE'
    },
    {
      'city': 'Mumbai',
      'state': 'Maharashtra',
      'river': 'Mithi',
      'lat': 19.0760,
      'lon': 72.8777,
      'risk': 'LOW'
    },
    {
      'city': 'Chennai',
      'state': 'Tamil Nadu',
      'river': 'Adyar',
      'lat': 13.0827,
      'lon': 80.2707,
      'risk': 'LOW'
    },
  ];

  static const double criticalThreshold = 85.0;
  static const double highThreshold = 70.0;
  static const double moderateThreshold = 50.0;
  static const double lowThreshold = 30.0;

  static const Duration pollingInterval = Duration(seconds: 5);
  static const int maxRetries = 3;

  static const double defaultDangerLevel = 3.0;
  static const double defaultWarningLevel = 2.5;
  static const double defaultSafeLevel = 1.5;

  static const Duration shortAnimDuration = Duration(milliseconds: 220);
  static const Duration mediumAnimDuration = Duration(milliseconds: 320);
  static const Duration longAnimDuration = Duration(milliseconds: 600);

  static const String criticalAlertChannelId = 'flood_critical';
  static const String criticalAlertChannelName = 'Critical Flood Alerts';
  static const String warningAlertChannelId = 'flood_warning';
  static const String warningAlertChannelName = 'Flood Warnings';
}
