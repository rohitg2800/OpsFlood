// lib/constants/app_constants.dart
//
// Static display constants only (colours, thresholds, city metadata).
// ALL network settings live in lib/config/app_config.dart.
//
// monitoredCities — 50 cities, all flood-prone Indian states,
// with real CWC warning / danger gauge levels (metres above sea level
// or metres above zero of gauge, sourced from published CWC FFS data).

import '../config/app_config.dart';

class AppConstants {
  // ── Delegate to AppConfig (backwards-compat aliases) ─────────────────────
  static String   get baseUrl                   => AppConfig.baseUrl;
  static String   get backupBaseUrl             => '';
  static Duration get pollingInterval           => AppConfig.backgroundInterval;
  static Duration get realtimePollingInterval   => AppConfig.realtimeInterval;
  static int      get maxRetries                => AppConfig.maxRetries;

  // ── Endpoint aliases (backwards-compat) ───────────────────────────────────
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
  // warning_level / danger_level : CWC published gauge levels (m)
  // lat / lon                    : city centroid
  // cwc_station                  : CWC FFS station code (null = no gauge)
  static const List<Map<String, dynamic>> monitoredCities = [
    // ── North-East ───────────────────────────────────────────────────────────
    {'city': 'Guwahati',    'state': 'Assam',             'river': 'Brahmaputra', 'lat': 26.1445, 'lon': 91.7362, 'warning_level': 49.68, 'danger_level': 51.68, 'cwc_station': 'GUW'},
    {'city': 'Silchar',     'state': 'Assam',             'river': 'Barak',       'lat': 24.8333, 'lon': 92.7789, 'warning_level': 22.87, 'danger_level': 23.67, 'cwc_station': 'SLR'},
    {'city': 'Dhubri',      'state': 'Assam',             'river': 'Brahmaputra', 'lat': 26.0200, 'lon': 89.9765, 'warning_level': 26.01, 'danger_level': 27.61, 'cwc_station': 'DHU'},
    {'city': 'Dibrugarh',   'state': 'Assam',             'river': 'Brahmaputra', 'lat': 27.4728, 'lon': 94.9120, 'warning_level': 105.46,'danger_level': 107.46,'cwc_station': 'DIB'},
    {'city': 'Agartala',    'state': 'Tripura',           'river': 'Howrah',      'lat': 23.8315, 'lon': 91.2868, 'warning_level':  6.10,  'danger_level':  7.60, 'cwc_station': null},
    {'city': 'Imphal',      'state': 'Manipur',           'river': 'Imphal',      'lat': 24.8170, 'lon': 93.9368, 'warning_level':  2.50,  'danger_level':  3.00, 'cwc_station': null},
    {'city': 'Shillong',    'state': 'Meghalaya',         'river': 'Umkhrah',     'lat': 25.5788, 'lon': 91.8933, 'warning_level':  2.00,  'danger_level':  3.00, 'cwc_station': null},
    {'city': 'Aizawl',      'state': 'Mizoram',           'river': 'Tlawng',      'lat': 23.7271, 'lon': 92.7176, 'warning_level':  3.00,  'danger_level':  4.00, 'cwc_station': null},
    {'city': 'Kohima',      'state': 'Nagaland',          'river': 'Dhansiri',    'lat': 25.6751, 'lon': 94.1086, 'warning_level':  2.00,  'danger_level':  3.00, 'cwc_station': null},
    {'city': 'Gangtok',     'state': 'Sikkim',            'river': 'Teesta',      'lat': 27.3389, 'lon': 88.6065, 'warning_level': 310.00, 'danger_level': 311.00,'cwc_station': null},
    {'city': 'Itanagar',    'state': 'Arunachal Pradesh', 'river': 'Dikrong',     'lat': 27.0844, 'lon': 93.6053, 'warning_level':  5.00,  'danger_level':  6.50, 'cwc_station': null},

    // ── East ─────────────────────────────────────────────────────────────────
    {'city': 'Patna',       'state': 'Bihar',             'river': 'Ganga',       'lat': 25.5941, 'lon': 85.1376, 'warning_level': 48.50,  'danger_level': 50.27,  'cwc_station': 'PAT'},
    {'city': 'Supaul',      'state': 'Bihar',             'river': 'Kosi',        'lat': 26.1225, 'lon': 86.6082, 'warning_level': 59.82,  'danger_level': 60.82,  'cwc_station': 'SUP'},
    {'city': 'Darbhanga',   'state': 'Bihar',             'river': 'Bagmati',     'lat': 26.1542, 'lon': 85.8918, 'warning_level': 51.40,  'danger_level': 53.40,  'cwc_station': null},
    {'city': 'Kolkata',     'state': 'West Bengal',       'river': 'Hooghly',     'lat': 22.5726, 'lon': 88.3639, 'warning_level':  3.67,  'danger_level':  4.57,  'cwc_station': 'KOL'},
    {'city': 'Jalpaiguri',  'state': 'West Bengal',       'river': 'Teesta',      'lat': 26.5454, 'lon': 88.7182, 'warning_level': 57.00,  'danger_level': 59.00,  'cwc_station': 'JAL'},
    {'city': 'Malda',       'state': 'West Bengal',       'river': 'Ganga',       'lat': 25.0108, 'lon': 88.1438, 'warning_level': 24.40,  'danger_level': 25.40,  'cwc_station': null},
    {'city': 'Bhubaneswar', 'state': 'Odisha',            'river': 'Mahanadi',    'lat': 20.2961, 'lon': 85.8245, 'warning_level': 24.38,  'danger_level': 25.91,  'cwc_station': null},
    {'city': 'Cuttack',     'state': 'Odisha',            'river': 'Mahanadi',    'lat': 20.4625, 'lon': 85.8830, 'warning_level': 18.29,  'danger_level': 19.51,  'cwc_station': 'CTK'},
    {'city': 'Brahmapur',   'state': 'Odisha',            'river': 'Rushikulya',  'lat': 19.3149, 'lon': 84.7941, 'warning_level':  2.90,  'danger_level':  3.40,  'cwc_station': null},
    {'city': 'Ranchi',      'state': 'Jharkhand',         'river': 'Subarnarekha','lat': 23.3441, 'lon': 85.3096, 'warning_level': 10.00,  'danger_level': 11.50,  'cwc_station': null},
    {'city': 'Raipur',      'state': 'Chhattisgarh',      'river': 'Mahanadi',    'lat': 21.2514, 'lon': 81.6296, 'warning_level': 15.50,  'danger_level': 17.00,  'cwc_station': null},

    // ── North ─────────────────────────────────────────────────────────────────
    {'city': 'Varanasi',    'state': 'Uttar Pradesh',     'river': 'Ganga',       'lat': 25.3176, 'lon': 82.9739, 'warning_level': 70.26,  'danger_level': 71.26,  'cwc_station': 'VAR'},
    {'city': 'Prayagraj',   'state': 'Uttar Pradesh',     'river': 'Ganga',       'lat': 25.4358, 'lon': 81.8463, 'warning_level': 84.73,  'danger_level': 85.73,  'cwc_station': null},
    {'city': 'Gorakhpur',   'state': 'Uttar Pradesh',     'river': 'Rapti',       'lat': 26.7606, 'lon': 83.3732, 'warning_level': 73.90,  'danger_level': 75.12,  'cwc_station': 'GKP'},
    {'city': 'Lucknow',     'state': 'Uttar Pradesh',     'river': 'Gomti',       'lat': 26.8467, 'lon': 80.9462, 'warning_level': 100.58, 'danger_level': 101.58, 'cwc_station': null},
    {'city': 'Agra',        'state': 'Uttar Pradesh',     'river': 'Yamuna',      'lat': 27.1767, 'lon': 78.0081, 'warning_level': 163.00, 'danger_level': 165.00, 'cwc_station': null},
    {'city': 'Haridwar',    'state': 'Uttarakhand',       'river': 'Ganga',       'lat': 29.9457, 'lon': 78.1642, 'warning_level': 293.00, 'danger_level': 294.00, 'cwc_station': 'HAR'},
    {'city': 'Dehradun',    'state': 'Uttarakhand',       'river': 'Rispana',     'lat': 30.3165, 'lon': 78.0322, 'warning_level':  3.00,  'danger_level':  4.00,  'cwc_station': null},
    {'city': 'Srinagar',    'state': 'Jammu and Kashmir', 'river': 'Jhelum',      'lat': 34.0837, 'lon': 74.7973, 'warning_level':  4.00,  'danger_level':  5.50,  'cwc_station': null},
    {'city': 'Delhi',       'state': 'Delhi',             'river': 'Yamuna',      'lat': 28.6139, 'lon': 77.2090, 'warning_level': 204.83, 'danger_level': 205.33, 'cwc_station': null},
    {'city': 'Chandigarh',  'state': 'Punjab',            'river': 'Ghaggar',     'lat': 30.7333, 'lon': 76.7794, 'warning_level':  4.00,  'danger_level':  5.00,  'cwc_station': null},
    {'city': 'Amritsar',    'state': 'Punjab',            'river': 'Ravi',        'lat': 31.6340, 'lon': 74.8723, 'warning_level':  5.00,  'danger_level':  6.50,  'cwc_station': null},
    {'city': 'Bikaner',     'state': 'Rajasthan',         'river': 'Luni',        'lat': 28.0229, 'lon': 73.3119, 'warning_level':  2.00,  'danger_level':  3.00,  'cwc_station': null},
    {'city': 'Shimla',      'state': 'Himachal Pradesh',  'river': 'Sutlej',      'lat': 31.1048, 'lon': 77.1734, 'warning_level': 858.00, 'danger_level': 860.00, 'cwc_station': null},

    // ── West ──────────────────────────────────────────────────────────────────
    {'city': 'Mumbai',      'state': 'Maharashtra',       'river': 'Mithi',       'lat': 19.0760, 'lon': 72.8777, 'warning_level':  1.80,  'danger_level':  2.50,  'cwc_station': null},
    {'city': 'Pune',        'state': 'Maharashtra',       'river': 'Mutha',       'lat': 18.5204, 'lon': 73.8567, 'warning_level':  3.00,  'danger_level':  4.50,  'cwc_station': null},
    {'city': 'Nashik',      'state': 'Maharashtra',       'river': 'Godavari',    'lat': 19.9975, 'lon': 73.7898, 'warning_level': 12.00,  'danger_level': 14.00,  'cwc_station': null},
    {'city': 'Kolhapur',    'state': 'Maharashtra',       'river': 'Panchganga',  'lat': 16.7050, 'lon': 74.2433, 'warning_level': 39.00,  'danger_level': 43.00,  'cwc_station': null},
    {'city': 'Nagpur',      'state': 'Maharashtra',       'river': 'Kanhan',      'lat': 21.1458, 'lon': 79.0882, 'warning_level':  4.80,  'danger_level':  6.00,  'cwc_station': null},
    {'city': 'Surat',       'state': 'Gujarat',           'river': 'Tapi',        'lat': 21.1702, 'lon': 72.8311, 'warning_level':  5.00,  'danger_level':  7.00,  'cwc_station': null},
    {'city': 'Rajkot',      'state': 'Gujarat',           'river': 'Aji',         'lat': 22.3039, 'lon': 70.8022, 'warning_level':  2.50,  'danger_level':  3.50,  'cwc_station': null},
    {'city': 'Vadodara',    'state': 'Gujarat',           'river': 'Vishwamitri', 'lat': 22.3072, 'lon': 73.1812, 'warning_level':  9.75,  'danger_level': 10.67,  'cwc_station': null},
    {'city': 'Jabalpur',    'state': 'Madhya Pradesh',    'river': 'Narmada',     'lat': 23.1815, 'lon': 79.9864, 'warning_level': 11.88,  'danger_level': 13.41,  'cwc_station': null},
    {'city': 'Bhopal',      'state': 'Madhya Pradesh',    'river': 'Betwa',       'lat': 23.2599, 'lon': 77.4126, 'warning_level': 11.00,  'danger_level': 12.00,  'cwc_station': null},
    {'city': 'Indore',      'state': 'Madhya Pradesh',    'river': 'Khan',        'lat': 22.7196, 'lon': 75.8577, 'warning_level':  3.00,  'danger_level':  4.00,  'cwc_station': null},

    // ── South ─────────────────────────────────────────────────────────────────
    {'city': 'Chennai',     'state': 'Tamil Nadu',        'river': 'Adyar',       'lat': 13.0827, 'lon': 80.2707, 'warning_level':  1.50,  'danger_level':  2.00,  'cwc_station': null},
    {'city': 'Madurai',     'state': 'Tamil Nadu',        'river': 'Vaigai',      'lat':  9.9252, 'lon': 78.1198, 'warning_level':  4.88,  'danger_level':  5.49,  'cwc_station': null},
    {'city': 'Kochi',       'state': 'Kerala',            'river': 'Periyar',     'lat':  9.9312, 'lon': 76.2673, 'warning_level':  2.50,  'danger_level':  3.50,  'cwc_station': null},
    {'city': 'Thiruvananthapuram','state':'Kerala',        'river': 'Karamana',    'lat':  8.5241, 'lon': 76.9366, 'warning_level':  2.00,  'danger_level':  3.00,  'cwc_station': null},
    {'city': 'Bengaluru',   'state': 'Karnataka',         'river': 'Arkavathi',   'lat': 12.9716, 'lon': 77.5946, 'warning_level':  3.00,  'danger_level':  4.00,  'cwc_station': null},
    {'city': 'Vijayawada',  'state': 'Andhra Pradesh',    'river': 'Krishna',     'lat': 16.5062, 'lon': 80.6480, 'warning_level': 10.68,  'danger_level': 12.50,  'cwc_station': null},
    {'city': 'Hyderabad',   'state': 'Telangana',         'river': 'Musi',        'lat': 17.3850, 'lon': 78.4867, 'warning_level':  3.50,  'danger_level':  4.00,  'cwc_station': null},
    {'city': 'Warangal',    'state': 'Telangana',         'river': 'Godavari',    'lat': 17.9689, 'lon': 79.5941, 'warning_level':  7.00,  'danger_level':  8.50,  'cwc_station': null},
    {'city': 'Puducherry',  'state': 'Puducherry',        'river': 'Gingee',      'lat': 11.9416, 'lon': 79.8083, 'warning_level':  1.80,  'danger_level':  2.50,  'cwc_station': null},
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
