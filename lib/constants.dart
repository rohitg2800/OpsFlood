// lib/constants.dart
// OpsFlood — App-wide constants

import 'dart:core';

class AppConstants {
  // ── Backend URLs ─────────────────────────────────────────────────────────────
  static const String baseUrl = 'https://opsflood.onrender.com';
  // Leave empty until a real secondary server (Fly.dev / Railway) is available.
  // ApiService._baseCandidates filters out empty strings automatically.
  static const String backupBaseUrl = '';

  // ── API Endpoints ──────────────────────────────────────────────────────────
  static const String healthEndpoint          = '/health';
  static const String liveTelemetryEndpoint   = '/api/live-telemetry';
  static const String liveLevelsEndpoint      = '/api/live-levels';
  static const String criticalAlertsEndpoint  = '/api/critical-alerts';
  static const String predictLegacyEndpoint   = '/predict/legacy';
  static const String weatherCurrentEndpoint  = '/weather/current';
  static const String weatherForecastEndpoint = '/weather/forecast';

  // ── Flood severity thresholds (capacity %) ───────────────────────────────
  static const double criticalThreshold  = 90.0;
  static const double highThreshold      = 75.0;
  static const double moderateThreshold  = 50.0;

  // ── Default water level values (metres) ───────────────────────────────────
  static const double defaultDangerLevel  = 12.0;
  static const double defaultWarningLevel = 10.32;
  static const double defaultSafeLevel    = 8.0;

  // ── Notification channels ───────────────────────────────────────────────────
  static const String criticalAlertChannelId   = 'opsflood_critical';
  static const String criticalAlertChannelName = 'Critical Flood Alerts';
  static const String warningAlertChannelId    = 'opsflood_warning';
  static const String warningAlertChannelName  = 'Flood Warnings';

  // ── Polling & retry config ──────────────────────────────────────────────────
  static const Duration pollingInterval = Duration(minutes: 5);
  static const int      maxRetries      = 3;

  // ── Animation durations ────────────────────────────────────────────────────
  static const Duration shortAnimDuration = Duration(milliseconds: 300);
  static const Duration longAnimDuration  = Duration(milliseconds: 800);

  // ── Risk color palette ─────────────────────────────────────────────────────
  static const Map<String, int> riskColors = {
    'LOW':      0xFF34C759,
    'MODERATE': 0xFFF59E0B,
    'SEVERE':   0xFFEF4444,
    'CRITICAL': 0xFF8B0000,
    'HIGH':     0xFFEF4444,
  };

  static const Map<String, String> riskIcons = {
    'LOW':      'SAFE',
    'MODERATE': 'WATCH',
    'SEVERE':   'WARN',
    'CRITICAL': 'ALERT',
    'HIGH':     'WARN',
  };

  // ── Indian states list ──────────────────────────────────────────────────────
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

  // ───────────────────────────────────────────────────────────────────────
  // MONITORED CITIES — all-India CWC gauge registry
  //
  // Fields:
  //   city, state, river        — identity
  //   lat, lon                  — WGS-84 coordinates
  //   danger_level              — CWC published danger level (metres)
  //   warning_level             — CWC published warning level (metres)
  //   risk                      — baseline risk tag (used as fallback label only;
  //                               actual capacity is computed by FloodRiskEngine)
  //   flood_freq                — historical annual flood probability 0.0–1.0
  //                               (sourced from NDMA/CWC flood hazard atlas)
  //   river_type                — 'perennial'|'seasonal'|'glacier'|'coastal'
  //   zone                      — 'himalayan'|'northeastern'|'peninsular'|
  //                               'coastal'|'arid'|'central'
  // ───────────────────────────────────────────────────────────────────────
  static const List<Map<String, dynamic>> monitoredCities = [

    // ── ANDHRA PRADESH ────────────────────────────────────────────────────────────
    { 'city': 'Vijayawada',   'state': 'Andhra Pradesh', 'river': 'Krishna',
      'lat': 16.5062, 'lon': 80.6480, 'risk': 'HIGH',
      'danger_level': 12.50, 'warning_level': 9.00,
      'flood_freq': 0.72, 'river_type': 'perennial', 'zone': 'peninsular' },
    { 'city': 'Rajahmundry',  'state': 'Andhra Pradesh', 'river': 'Godavari',
      'lat': 17.0005, 'lon': 81.8040, 'risk': 'HIGH',
      'danger_level': 14.00, 'warning_level': 12.00,
      'flood_freq': 0.78, 'river_type': 'perennial', 'zone': 'coastal' },
    { 'city': 'Kurnool',      'state': 'Andhra Pradesh', 'river': 'Tungabhadra',
      'lat': 15.8281, 'lon': 78.0373, 'risk': 'MODERATE',
      'danger_level': 9.00,  'warning_level': 7.50,
      'flood_freq': 0.48, 'river_type': 'perennial', 'zone': 'peninsular' },
    { 'city': 'Nellore',      'state': 'Andhra Pradesh', 'river': 'Pennar',
      'lat': 14.4426, 'lon': 79.9865, 'risk': 'MODERATE',
      'danger_level': 8.00,  'warning_level': 6.50,
      'flood_freq': 0.42, 'river_type': 'seasonal', 'zone': 'coastal' },
    { 'city': 'Guntur',       'state': 'Andhra Pradesh', 'river': 'Krishna',
      'lat': 16.3008, 'lon': 80.4428, 'risk': 'MODERATE',
      'danger_level': 11.50, 'warning_level': 9.50,
      'flood_freq': 0.55, 'river_type': 'perennial', 'zone': 'peninsular' },

    // ── ARUNACHAL PRADESH ─────────────────────────────────────────────────────────
    { 'city': 'Itanagar',     'state': 'Arunachal Pradesh', 'river': 'Dikrong',
      'lat': 27.0844, 'lon': 93.6053, 'risk': 'HIGH',
      'danger_level': 12.00, 'warning_level': 10.00,
      'flood_freq': 0.80, 'river_type': 'perennial', 'zone': 'northeastern' },
    { 'city': 'Pasighat',     'state': 'Arunachal Pradesh', 'river': 'Siang',
      'lat': 28.0669, 'lon': 95.3289, 'risk': 'HIGH',
      'danger_level': 154.00, 'warning_level': 151.00,
      'flood_freq': 0.85, 'river_type': 'glacier', 'zone': 'northeastern' },

    // ── ASSAM ────────────────────────────────────────────────────────────────────
    { 'city': 'Guwahati',     'state': 'Assam', 'river': 'Brahmaputra',
      'lat': 26.1445, 'lon': 91.7362, 'risk': 'HIGH',
      'danger_level': 51.75, 'warning_level': 49.68,
      'flood_freq': 0.90, 'river_type': 'glacier', 'zone': 'northeastern' },
    { 'city': 'Dibrugarh',    'state': 'Assam', 'river': 'Brahmaputra',
      'lat': 27.4728, 'lon': 94.9120, 'risk': 'HIGH',
      'danger_level': 108.00, 'warning_level': 106.00,
      'flood_freq': 0.88, 'river_type': 'glacier', 'zone': 'northeastern' },
    { 'city': 'Silchar',      'state': 'Assam', 'river': 'Barak',
      'lat': 24.8333, 'lon': 92.7789, 'risk': 'MODERATE',
      'danger_level': 22.30, 'warning_level': 20.30,
      'flood_freq': 0.65, 'river_type': 'perennial', 'zone': 'northeastern' },
    { 'city': 'Jorhat',       'state': 'Assam', 'river': 'Brahmaputra',
      'lat': 26.7465, 'lon': 94.2026, 'risk': 'MODERATE',
      'danger_level': 86.88, 'warning_level': 84.88,
      'flood_freq': 0.70, 'river_type': 'glacier', 'zone': 'northeastern' },
    { 'city': 'Dhubri',       'state': 'Assam', 'river': 'Brahmaputra',
      'lat': 26.0200, 'lon': 89.9700, 'risk': 'HIGH',
      'danger_level': 32.42, 'warning_level': 30.42,
      'flood_freq': 0.85, 'river_type': 'glacier', 'zone': 'northeastern' },
    { 'city': 'Tezpur',       'state': 'Assam', 'river': 'Brahmaputra',
      'lat': 26.6338, 'lon': 92.7926, 'risk': 'HIGH',
      'danger_level': 72.31, 'warning_level': 70.31,
      'flood_freq': 0.87, 'river_type': 'glacier', 'zone': 'northeastern' },
    { 'city': 'Barpeta',      'state': 'Assam', 'river': 'Beki',
      'lat': 26.3250, 'lon': 91.0000, 'risk': 'HIGH',
      'danger_level': 47.00, 'warning_level': 45.00,
      'flood_freq': 0.82, 'river_type': 'perennial', 'zone': 'northeastern' },

    // ── BIHAR ────────────────────────────────────────────────────────────────────
    { 'city': 'Patna',        'state': 'Bihar', 'river': 'Ganga',
      'lat': 25.5941, 'lon': 85.1376, 'risk': 'HIGH',
      'danger_level': 48.60, 'warning_level': 47.60,
      'flood_freq': 0.82, 'river_type': 'perennial', 'zone': 'himalayan' },
    { 'city': 'Bhagalpur',    'state': 'Bihar', 'river': 'Ganga',
      'lat': 25.2425, 'lon': 86.9842, 'risk': 'HIGH',
      'danger_level': 33.68, 'warning_level': 32.68,
      'flood_freq': 0.78, 'river_type': 'perennial', 'zone': 'himalayan' },
    { 'city': 'Muzaffarpur',  'state': 'Bihar', 'river': 'Gandak',
      'lat': 26.1209, 'lon': 85.3647, 'risk': 'HIGH',
      'danger_level': 48.68, 'warning_level': 47.68,
      'flood_freq': 0.80, 'river_type': 'perennial', 'zone': 'himalayan' },
    { 'city': 'Darbhanga',    'state': 'Bihar', 'river': 'Bagmati',
      'lat': 26.1542, 'lon': 85.8918, 'risk': 'HIGH',
      'danger_level': 51.00, 'warning_level': 49.50,
      'flood_freq': 0.83, 'river_type': 'perennial', 'zone': 'himalayan' },
    { 'city': 'Gaya',         'state': 'Bihar', 'river': 'Falgu',
      'lat': 24.7955, 'lon': 85.0002, 'risk': 'MODERATE',
      'danger_level': 97.00, 'warning_level': 95.50,
      'flood_freq': 0.40, 'river_type': 'seasonal', 'zone': 'central' },
    { 'city': 'Begusarai',    'state': 'Bihar', 'river': 'Ganga',
      'lat': 25.4182, 'lon': 86.1272, 'risk': 'HIGH',
      'danger_level': 40.68, 'warning_level': 39.68,
      'flood_freq': 0.76, 'river_type': 'perennial', 'zone': 'himalayan' },

    // ── CHHATTISGARH ────────────────────────────────────────────────────────────
    { 'city': 'Raipur',       'state': 'Chhattisgarh', 'river': 'Kharun',
      'lat': 21.2514, 'lon': 81.6296, 'risk': 'MODERATE',
      'danger_level': 8.50,  'warning_level': 7.00,
      'flood_freq': 0.38, 'river_type': 'seasonal', 'zone': 'central' },
    { 'city': 'Bilaspur',     'state': 'Chhattisgarh', 'river': 'Arpa',
      'lat': 22.0797, 'lon': 82.1391, 'risk': 'MODERATE',
      'danger_level': 9.00,  'warning_level': 7.50,
      'flood_freq': 0.42, 'river_type': 'seasonal', 'zone': 'central' },
    { 'city': 'Jagdalpur',    'state': 'Chhattisgarh', 'river': 'Indravati',
      'lat': 19.0748, 'lon': 82.0354, 'risk': 'HIGH',
      'danger_level': 11.00, 'warning_level': 9.50,
      'flood_freq': 0.65, 'river_type': 'seasonal', 'zone': 'central' },

    // ── DELHI ────────────────────────────────────────────────────────────────────
    { 'city': 'Delhi',        'state': 'Delhi', 'river': 'Yamuna',
      'lat': 28.6139, 'lon': 77.2090, 'risk': 'HIGH',
      'danger_level': 204.83, 'warning_level': 204.50,
      'flood_freq': 0.60, 'river_type': 'perennial', 'zone': 'himalayan' },

    // ── GOA ────────────────────────────────────────────────────────────────────
    { 'city': 'Panaji',       'state': 'Goa', 'river': 'Mandovi',
      'lat': 15.4909, 'lon': 73.8278, 'risk': 'MODERATE',
      'danger_level': 6.00,  'warning_level': 5.00,
      'flood_freq': 0.45, 'river_type': 'coastal', 'zone': 'coastal' },

    // ── GUJARAT ───────────────────────────────────────────────────────────────
    { 'city': 'Surat',        'state': 'Gujarat', 'river': 'Tapi',
      'lat': 21.1702, 'lon': 72.8311, 'risk': 'HIGH',
      'danger_level': 10.97, 'warning_level': 9.45,
      'flood_freq': 0.70, 'river_type': 'perennial', 'zone': 'coastal' },
    { 'city': 'Vadodara',     'state': 'Gujarat', 'river': 'Vishwamitri',
      'lat': 22.3072, 'lon': 73.1812, 'risk': 'HIGH',
      'danger_level': 11.58, 'warning_level': 10.06,
      'flood_freq': 0.68, 'river_type': 'seasonal', 'zone': 'coastal' },
    { 'city': 'Rajkot',       'state': 'Gujarat', 'river': 'Aji',
      'lat': 22.3039, 'lon': 70.8022, 'risk': 'MODERATE',
      'danger_level': 5.50,  'warning_level': 4.50,
      'flood_freq': 0.35, 'river_type': 'seasonal', 'zone': 'arid' },
    { 'city': 'Ahmedabad',    'state': 'Gujarat', 'river': 'Sabarmati',
      'lat': 23.0225, 'lon': 72.5714, 'risk': 'MODERATE',
      'danger_level': 48.00, 'warning_level': 46.50,
      'flood_freq': 0.48, 'river_type': 'seasonal', 'zone': 'arid' },

    // ── HARYANA ────────────────────────────────────────────────────────────────
    { 'city': 'Ambala',       'state': 'Haryana', 'river': 'Ghaggar',
      'lat': 30.3782, 'lon': 76.7767, 'risk': 'MODERATE',
      'danger_level': 270.0, 'warning_level': 268.5,
      'flood_freq': 0.52, 'river_type': 'seasonal', 'zone': 'himalayan' },
    { 'city': 'Hisar',        'state': 'Haryana', 'river': 'Ghaggar',
      'lat': 29.1492, 'lon': 75.7217, 'risk': 'LOW',
      'danger_level': 204.0, 'warning_level': 203.0,
      'flood_freq': 0.22, 'river_type': 'seasonal', 'zone': 'arid' },

    // ── HIMACHAL PRADESH ──────────────────────────────────────────────────────────
    { 'city': 'Mandi',        'state': 'Himachal Pradesh', 'river': 'Beas',
      'lat': 31.7090, 'lon': 76.9320, 'risk': 'HIGH',
      'danger_level': 775.0, 'warning_level': 773.0,
      'flood_freq': 0.65, 'river_type': 'glacier', 'zone': 'himalayan' },
    { 'city': 'Bilaspur',     'state': 'Himachal Pradesh', 'river': 'Sutlej',
      'lat': 31.3407, 'lon': 76.7602, 'risk': 'MODERATE',
      'danger_level': 670.0, 'warning_level': 668.0,
      'flood_freq': 0.48, 'river_type': 'glacier', 'zone': 'himalayan' },

    // ── JHARKHAND ──────────────────────────────────────────────────────────────
    { 'city': 'Ranchi',       'state': 'Jharkhand', 'river': 'Subarnarekha',
      'lat': 23.3441, 'lon': 85.3096, 'risk': 'MODERATE',
      'danger_level': 609.0, 'warning_level': 607.0,
      'flood_freq': 0.42, 'river_type': 'seasonal', 'zone': 'central' },
    { 'city': 'Jamshedpur',   'state': 'Jharkhand', 'river': 'Subarnarekha',
      'lat': 22.8046, 'lon': 86.2029, 'risk': 'HIGH',
      'danger_level': 131.0, 'warning_level': 129.0,
      'flood_freq': 0.62, 'river_type': 'seasonal', 'zone': 'central' },
    { 'city': 'Daltonganj',   'state': 'Jharkhand', 'river': 'Koel',
      'lat': 24.0359, 'lon': 84.0673, 'risk': 'MODERATE',
      'danger_level': 10.50, 'warning_level': 9.00,
      'flood_freq': 0.45, 'river_type': 'seasonal', 'zone': 'central' },

    // ── JAMMU & KASHMIR ─────────────────────────────────────────────────────────
    { 'city': 'Srinagar',     'state': 'Jammu and Kashmir', 'river': 'Jhelum',
      'lat': 34.0837, 'lon': 74.7973, 'risk': 'HIGH',
      'danger_level': 18.00, 'warning_level': 16.00,
      'flood_freq': 0.58, 'river_type': 'glacier', 'zone': 'himalayan' },
    { 'city': 'Jammu',        'state': 'Jammu and Kashmir', 'river': 'Tawi',
      'lat': 32.7266, 'lon': 74.8570, 'risk': 'MODERATE',
      'danger_level': 316.0, 'warning_level': 314.0,
      'flood_freq': 0.45, 'river_type': 'glacier', 'zone': 'himalayan' },

    // ── KARNATAKA ──────────────────────────────────────────────────────────────
    { 'city': 'Belagavi',     'state': 'Karnataka', 'river': 'Ghataprabha',
      'lat': 15.8497, 'lon': 74.4977, 'risk': 'HIGH',
      'danger_level': 11.00, 'warning_level': 9.50,
      'flood_freq': 0.68, 'river_type': 'perennial', 'zone': 'peninsular' },
    { 'city': 'Raichur',      'state': 'Karnataka', 'river': 'Krishna',
      'lat': 16.2120, 'lon': 77.3566, 'risk': 'MODERATE',
      'danger_level': 318.0, 'warning_level': 316.5,
      'flood_freq': 0.50, 'river_type': 'perennial', 'zone': 'peninsular' },
    { 'city': 'Bagalkot',     'state': 'Karnataka', 'river': 'Ghataprabha',
      'lat': 16.1826, 'lon': 75.6961, 'risk': 'MODERATE',
      'danger_level': 10.50, 'warning_level': 9.00,
      'flood_freq': 0.45, 'river_type': 'perennial', 'zone': 'peninsular' },
    { 'city': 'Mysuru',       'state': 'Karnataka', 'river': 'Kabini',
      'lat': 12.2958, 'lon': 76.6394, 'risk': 'MODERATE',
      'danger_level': 773.0, 'warning_level': 770.0,
      'flood_freq': 0.40, 'river_type': 'perennial', 'zone': 'peninsular' },

    // ── KERALA ──────────────────────────────────────────────────────────────────
    { 'city': 'Kochi',        'state': 'Kerala', 'river': 'Periyar',
      'lat': 9.9312, 'lon': 76.2673, 'risk': 'HIGH',
      'danger_level': 8.84,  'warning_level': 7.84,
      'flood_freq': 0.80, 'river_type': 'perennial', 'zone': 'coastal' },
    { 'city': 'Thrissur',     'state': 'Kerala', 'river': 'Chalakudy',
      'lat': 10.5276, 'lon': 76.2144, 'risk': 'HIGH',
      'danger_level': 9.50,  'warning_level': 8.00,
      'flood_freq': 0.75, 'river_type': 'perennial', 'zone': 'coastal' },
    { 'city': 'Alappuzha',    'state': 'Kerala', 'river': 'Pampa',
      'lat': 9.4981,  'lon': 76.3388, 'risk': 'HIGH',
      'danger_level': 4.00,  'warning_level': 3.00,
      'flood_freq': 0.82, 'river_type': 'coastal', 'zone': 'coastal' },
    { 'city': 'Kozhikode',    'state': 'Kerala', 'river': 'Chaliyar',
      'lat': 11.2588, 'lon': 75.7804, 'risk': 'MODERATE',
      'danger_level': 7.50,  'warning_level': 6.50,
      'flood_freq': 0.60, 'river_type': 'perennial', 'zone': 'coastal' },
    { 'city': 'Thiruvananthapuram', 'state': 'Kerala', 'river': 'Karamana',
      'lat': 8.5241,  'lon': 76.9366, 'risk': 'MODERATE',
      'danger_level': 5.50,  'warning_level': 4.50,
      'flood_freq': 0.50, 'river_type': 'perennial', 'zone': 'coastal' },

    // ── MADHYA PRADESH ────────────────────────────────────────────────────────────
    { 'city': 'Jabalpur',     'state': 'Madhya Pradesh', 'river': 'Narmada',
      'lat': 23.1815, 'lon': 79.9864, 'risk': 'HIGH',
      'danger_level': 12.50, 'warning_level': 11.00,
      'flood_freq': 0.68, 'river_type': 'perennial', 'zone': 'central' },
    { 'city': 'Hoshangabad',  'state': 'Madhya Pradesh', 'river': 'Narmada',
      'lat': 22.7510, 'lon': 77.7268, 'risk': 'HIGH',
      'danger_level': 286.5, 'warning_level': 284.5,
      'flood_freq': 0.70, 'river_type': 'perennial', 'zone': 'central' },
    { 'city': 'Bhopal',       'state': 'Madhya Pradesh', 'river': 'Betwa',
      'lat': 23.2599, 'lon': 77.4126, 'risk': 'MODERATE',
      'danger_level': 9.00,  'warning_level': 7.50,
      'flood_freq': 0.38, 'river_type': 'seasonal', 'zone': 'central' },
    { 'city': 'Gwalior',      'state': 'Madhya Pradesh', 'river': 'Chambal',
      'lat': 26.2183, 'lon': 78.1828, 'risk': 'MODERATE',
      'danger_level': 185.0, 'warning_level': 183.5,
      'flood_freq': 0.45, 'river_type': 'seasonal', 'zone': 'central' },

    // ── MAHARASHTRA ──────────────────────────────────────────────────────────────
    { 'city': 'Kolhapur',     'state': 'Maharashtra', 'river': 'Panchganga',
      'lat': 16.7050, 'lon': 74.2433, 'risk': 'HIGH',
      'danger_level': 14.00, 'warning_level': 12.05,
      'flood_freq': 0.72, 'river_type': 'perennial', 'zone': 'coastal' },
    { 'city': 'Pune',         'state': 'Maharashtra', 'river': 'Mutha',
      'lat': 18.5204, 'lon': 73.8567, 'risk': 'MODERATE',
      'danger_level': 10.50, 'warning_level': 9.00,
      'flood_freq': 0.45, 'river_type': 'perennial', 'zone': 'coastal' },
    { 'city': 'Nashik',       'state': 'Maharashtra', 'river': 'Godavari',
      'lat': 19.9975, 'lon': 73.7898, 'risk': 'MODERATE',
      'danger_level': 11.50, 'warning_level': 10.00,
      'flood_freq': 0.50, 'river_type': 'perennial', 'zone': 'coastal' },
    { 'city': 'Nagpur',       'state': 'Maharashtra', 'river': 'Nag',
      'lat': 21.1458, 'lon': 79.0882, 'risk': 'MODERATE',
      'danger_level': 9.50,  'warning_level': 8.00,
      'flood_freq': 0.38, 'river_type': 'seasonal', 'zone': 'central' },
    { 'city': 'Sangli',       'state': 'Maharashtra', 'river': 'Krishna',
      'lat': 16.8524, 'lon': 74.5815, 'risk': 'HIGH',
      'danger_level': 12.00, 'warning_level': 10.50,
      'flood_freq': 0.70, 'river_type': 'perennial', 'zone': 'coastal' },
    { 'city': 'Satara',       'state': 'Maharashtra', 'river': 'Krishna',
      'lat': 17.6805, 'lon': 73.9986, 'risk': 'MODERATE',
      'danger_level': 10.00, 'warning_level': 8.50,
      'flood_freq': 0.48, 'river_type': 'perennial', 'zone': 'coastal' },

    // ── MANIPUR ───────────────────────────────────────────────────────────────
    { 'city': 'Imphal',       'state': 'Manipur', 'river': 'Imphal',
      'lat': 24.8170, 'lon': 93.9368, 'risk': 'MODERATE',
      'danger_level': 786.5, 'warning_level': 784.5,
      'flood_freq': 0.55, 'river_type': 'perennial', 'zone': 'northeastern' },

    // ── MEGHALAYA ──────────────────────────────────────────────────────────────
    { 'city': 'Shillong',     'state': 'Meghalaya', 'river': 'Umiam',
      'lat': 25.5788, 'lon': 91.8933, 'risk': 'MODERATE',
      'danger_level': 960.0, 'warning_level': 958.0,
      'flood_freq': 0.50, 'river_type': 'perennial', 'zone': 'northeastern' },

    // ── ODISHA ─────────────────────────────────────────────────────────────────
    { 'city': 'Cuttack',      'state': 'Odisha', 'river': 'Mahanadi',
      'lat': 20.4625, 'lon': 85.8830, 'risk': 'HIGH',
      'danger_level': 15.24, 'warning_level': 14.19,
      'flood_freq': 0.80, 'river_type': 'perennial', 'zone': 'coastal' },
    { 'city': 'Bhubaneswar',  'state': 'Odisha', 'river': 'Daya',
      'lat': 20.2961, 'lon': 85.8245, 'risk': 'MODERATE',
      'danger_level': 12.00, 'warning_level': 10.50,
      'flood_freq': 0.45, 'river_type': 'seasonal', 'zone': 'coastal' },
    { 'city': 'Sambalpur',    'state': 'Odisha', 'river': 'Mahanadi',
      'lat': 21.4669, 'lon': 83.9812, 'risk': 'HIGH',
      'danger_level': 154.0, 'warning_level': 152.0,
      'flood_freq': 0.75, 'river_type': 'perennial', 'zone': 'central' },
    { 'city': 'Puri',         'state': 'Odisha', 'river': 'Bhargavi',
      'lat': 19.8135, 'lon': 85.8312, 'risk': 'MODERATE',
      'danger_level': 4.00,  'warning_level': 3.00,
      'flood_freq': 0.55, 'river_type': 'coastal', 'zone': 'coastal' },
    { 'city': 'Kendrapara',   'state': 'Odisha', 'river': 'Brahmani',
      'lat': 20.5006, 'lon': 86.4214, 'risk': 'HIGH',
      'danger_level': 7.00,  'warning_level': 5.50,
      'flood_freq': 0.72, 'river_type': 'perennial', 'zone': 'coastal' },

    // ── PUNJAB ─────────────────────────────────────────────────────────────────
    { 'city': 'Ludhiana',     'state': 'Punjab', 'river': 'Sutlej',
      'lat': 30.9010, 'lon': 75.8573, 'risk': 'MODERATE',
      'danger_level': 248.0, 'warning_level': 246.5,
      'flood_freq': 0.48, 'river_type': 'glacier', 'zone': 'himalayan' },
    { 'city': 'Jalandhar',    'state': 'Punjab', 'river': 'Beas',
      'lat': 31.3260, 'lon': 75.5762, 'risk': 'MODERATE',
      'danger_level': 225.0, 'warning_level': 223.5,
      'flood_freq': 0.50, 'river_type': 'glacier', 'zone': 'himalayan' },
    { 'city': 'Firozpur',     'state': 'Punjab', 'river': 'Sutlej',
      'lat': 30.9254, 'lon': 74.6132, 'risk': 'HIGH',
      'danger_level': 188.0, 'warning_level': 186.5,
      'flood_freq': 0.60, 'river_type': 'glacier', 'zone': 'himalayan' },

    // ── RAJASTHAN ──────────────────────────────────────────────────────────────
    { 'city': 'Kota',         'state': 'Rajasthan', 'river': 'Chambal',
      'lat': 25.2138, 'lon': 75.8648, 'risk': 'MODERATE',
      'danger_level': 256.0, 'warning_level': 254.0,
      'flood_freq': 0.42, 'river_type': 'perennial', 'zone': 'arid' },
    { 'city': 'Jaipur',       'state': 'Rajasthan', 'river': 'Banganga',
      'lat': 26.9124, 'lon': 75.7873, 'risk': 'LOW',
      'danger_level': 7.50,  'warning_level': 6.00,
      'flood_freq': 0.18, 'river_type': 'seasonal', 'zone': 'arid' },
    { 'city': 'Barmer',       'state': 'Rajasthan', 'river': 'Luni',
      'lat': 25.7521, 'lon': 71.3967, 'risk': 'MODERATE',
      'danger_level': 5.00,  'warning_level': 4.00,
      'flood_freq': 0.35, 'river_type': 'seasonal', 'zone': 'arid' },

    // ── SIKKIM ────────────────────────────────────────────────────────────────
    { 'city': 'Gangtok',      'state': 'Sikkim', 'river': 'Teesta',
      'lat': 27.3314, 'lon': 88.6138, 'risk': 'HIGH',
      'danger_level': 1462.0, 'warning_level': 1460.0,
      'flood_freq': 0.70, 'river_type': 'glacier', 'zone': 'himalayan' },

    // ── TAMIL NADU ──────────────────────────────────────────────────────────────
    { 'city': 'Chennai',      'state': 'Tamil Nadu', 'river': 'Adyar',
      'lat': 13.0827, 'lon': 80.2707, 'risk': 'HIGH',
      'danger_level': 5.50,  'warning_level': 4.50,
      'flood_freq': 0.65, 'river_type': 'seasonal', 'zone': 'coastal' },
    { 'city': 'Madurai',      'state': 'Tamil Nadu', 'river': 'Vaigai',
      'lat': 9.9252,  'lon': 78.1198, 'risk': 'MODERATE',
      'danger_level': 7.00,  'warning_level': 5.50,
      'flood_freq': 0.45, 'river_type': 'seasonal', 'zone': 'peninsular' },
    { 'city': 'Tiruchirapalli','state': 'Tamil Nadu', 'river': 'Cauvery',
      'lat': 10.7905, 'lon': 78.7047, 'risk': 'MODERATE',
      'danger_level': 9.00,  'warning_level': 7.50,
      'flood_freq': 0.52, 'river_type': 'perennial', 'zone': 'peninsular' },
    { 'city': 'Thanjavur',    'state': 'Tamil Nadu', 'river': 'Cauvery',
      'lat': 10.7870, 'lon': 79.1378, 'risk': 'MODERATE',
      'danger_level': 5.00,  'warning_level': 4.00,
      'flood_freq': 0.55, 'river_type': 'perennial', 'zone': 'coastal' },
    { 'city': 'Cuddalore',    'state': 'Tamil Nadu', 'river': 'Gadilam',
      'lat': 11.7480, 'lon': 79.7714, 'risk': 'HIGH',
      'danger_level': 6.00,  'warning_level': 5.00,
      'flood_freq': 0.68, 'river_type': 'coastal', 'zone': 'coastal' },

    // ── TELANGANA ──────────────────────────────────────────────────────────────
    { 'city': 'Hyderabad',    'state': 'Telangana', 'river': 'Musi',
      'lat': 17.3850, 'lon': 78.4867, 'risk': 'MODERATE',
      'danger_level': 7.50,  'warning_level': 6.50,
      'flood_freq': 0.45, 'river_type': 'seasonal', 'zone': 'peninsular' },
    { 'city': 'Warangal',     'state': 'Telangana', 'river': 'Godavari',
      'lat': 17.9784, 'lon': 79.5941, 'risk': 'MODERATE',
      'danger_level': 10.50, 'warning_level': 9.00,
      'flood_freq': 0.50, 'river_type': 'perennial', 'zone': 'peninsular' },
    { 'city': 'Khammam',      'state': 'Telangana', 'river': 'Munneru',
      'lat': 17.2473, 'lon': 80.1514, 'risk': 'HIGH',
      'danger_level': 8.00,  'warning_level': 6.50,
      'flood_freq': 0.62, 'river_type': 'seasonal', 'zone': 'peninsular' },

    // ── TRIPURA ───────────────────────────────────────────────────────────────
    { 'city': 'Agartala',     'state': 'Tripura', 'river': 'Haora',
      'lat': 23.8315, 'lon': 91.2868, 'risk': 'HIGH',
      'danger_level': 12.00, 'warning_level': 10.50,
      'flood_freq': 0.75, 'river_type': 'perennial', 'zone': 'northeastern' },

    // ── UTTAR PRADESH ────────────────────────────────────────────────────────────
    { 'city': 'Varanasi',     'state': 'Uttar Pradesh', 'river': 'Ganga',
      'lat': 25.3176, 'lon': 82.9739, 'risk': 'HIGH',
      'danger_level': 71.26, 'warning_level': 70.26,
      'flood_freq': 0.78, 'river_type': 'perennial', 'zone': 'himalayan' },
    { 'city': 'Allahabad',    'state': 'Uttar Pradesh', 'river': 'Ganga',
      'lat': 25.4358, 'lon': 81.8463, 'risk': 'HIGH',
      'danger_level': 84.73, 'warning_level': 83.73,
      'flood_freq': 0.75, 'river_type': 'perennial', 'zone': 'himalayan' },
    { 'city': 'Kanpur',       'state': 'Uttar Pradesh', 'river': 'Ganga',
      'lat': 26.4499, 'lon': 80.3319, 'risk': 'MODERATE',
      'danger_level': 111.5, 'warning_level': 110.5,
      'flood_freq': 0.58, 'river_type': 'perennial', 'zone': 'himalayan' },
    { 'city': 'Lucknow',      'state': 'Uttar Pradesh', 'river': 'Gomti',
      'lat': 26.8467, 'lon': 80.9462, 'risk': 'MODERATE',
      'danger_level': 102.0, 'warning_level': 100.5,
      'flood_freq': 0.48, 'river_type': 'perennial', 'zone': 'himalayan' },
    { 'city': 'Agra',         'state': 'Uttar Pradesh', 'river': 'Yamuna',
      'lat': 27.1767, 'lon': 78.0081, 'risk': 'MODERATE',
      'danger_level': 163.0, 'warning_level': 161.5,
      'flood_freq': 0.52, 'river_type': 'perennial', 'zone': 'himalayan' },
    { 'city': 'Gorakhpur',    'state': 'Uttar Pradesh', 'river': 'Rapti',
      'lat': 26.7606, 'lon': 83.3732, 'risk': 'HIGH',
      'danger_level': 76.34, 'warning_level': 74.34,
      'flood_freq': 0.80, 'river_type': 'perennial', 'zone': 'himalayan' },

    // ── UTTARAKHAND ─────────────────────────────────────────────────────────────
    { 'city': 'Haridwar',     'state': 'Uttarakhand', 'river': 'Ganga',
      'lat': 29.9457, 'lon': 78.1642, 'risk': 'HIGH',
      'danger_level': 294.0, 'warning_level': 292.5,
      'flood_freq': 0.68, 'river_type': 'glacier', 'zone': 'himalayan' },
    { 'city': 'Dehradun',     'state': 'Uttarakhand', 'river': 'Song',
      'lat': 30.3165, 'lon': 78.0322, 'risk': 'MODERATE',
      'danger_level': 455.0, 'warning_level': 453.0,
      'flood_freq': 0.50, 'river_type': 'glacier', 'zone': 'himalayan' },

    // ── WEST BENGAL ─────────────────────────────────────────────────────────────
    { 'city': 'Kolkata',      'state': 'West Bengal', 'river': 'Hooghly',
      'lat': 22.5726, 'lon': 88.3639, 'risk': 'HIGH',
      'danger_level': 5.97,  'warning_level': 4.97,
      'flood_freq': 0.75, 'river_type': 'perennial', 'zone': 'coastal' },
    { 'city': 'Howrah',       'state': 'West Bengal', 'river': 'Hooghly',
      'lat': 22.5958, 'lon': 88.2636, 'risk': 'HIGH',
      'danger_level': 6.50,  'warning_level': 5.50,
      'flood_freq': 0.73, 'river_type': 'perennial', 'zone': 'coastal' },
    { 'city': 'Malda',        'state': 'West Bengal', 'river': 'Ganga',
      'lat': 25.0108, 'lon': 88.1415, 'risk': 'HIGH',
      'danger_level': 25.00, 'warning_level': 24.00,
      'flood_freq': 0.78, 'river_type': 'perennial', 'zone': 'himalayan' },
    { 'city': 'Jalpaiguri',   'state': 'West Bengal', 'river': 'Teesta',
      'lat': 26.5418, 'lon': 88.7179, 'risk': 'HIGH',
      'danger_level': 59.00, 'warning_level': 57.50,
      'flood_freq': 0.82, 'river_type': 'glacier', 'zone': 'himalayan' },
    { 'city': 'Murshidabad',  'state': 'West Bengal', 'river': 'Bhagirathi',
      'lat': 24.1832, 'lon': 88.2690, 'risk': 'HIGH',
      'danger_level': 18.95, 'warning_level': 17.95,
      'flood_freq': 0.72, 'river_type': 'perennial', 'zone': 'coastal' },
  ];
}
