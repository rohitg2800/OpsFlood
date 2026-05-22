// lib/constants.dart
// OpsFlood — App-wide constants

import 'dart:core';

class AppConstants {
  // ── Backend URLs ────────────────────────────────────────────────────────────
  static const String baseUrl       = 'https://opsflood.onrender.com';
  // FIX: was 'opsflood-backend.onrender.com' which does not exist
  static const String backupBaseUrl = 'https://opsflood.onrender.com';

  // ── API Endpoints ─────────────────────────────────────────────────────────
  static const String healthEndpoint          = '/health';
  static const String liveTelemetryEndpoint   = '/api/live-telemetry';
  static const String liveLevelsEndpoint      = '/api/live-levels';
  static const String criticalAlertsEndpoint  = '/api/critical-alerts';
  static const String predictLegacyEndpoint   = '/predict/legacy';
  static const String weatherCurrentEndpoint  = '/weather/current';
  static const String weatherForecastEndpoint = '/weather/forecast';

  // ── Flood severity thresholds (capacity %) ─────────────────────────────
  static const double criticalThreshold  = 90.0;
  static const double highThreshold      = 75.0;
  static const double moderateThreshold  = 50.0;

  // ── Default water level values (metres) — used only when city map has no levels ───
  static const double defaultDangerLevel  = 12.0;
  static const double defaultWarningLevel = 10.32;
  static const double defaultSafeLevel    = 8.0;

  // ── Notification channels ───────────────────────────────────────────────
  static const String criticalAlertChannelId   = 'opsflood_critical';
  static const String criticalAlertChannelName = 'Critical Flood Alerts';
  static const String warningAlertChannelId    = 'opsflood_warning';
  static const String warningAlertChannelName  = 'Flood Warnings';

  // ── Polling & retry config ──────────────────────────────────────────────
  static const Duration pollingInterval = Duration(minutes: 5);
  static const int      maxRetries      = 3;

  // ── Animation durations ──────────────────────────────────────────────────
  static const Duration shortAnimDuration = Duration(milliseconds: 300);
  static const Duration longAnimDuration  = Duration(milliseconds: 800);

  // ── Risk color palette ───────────────────────────────────────────────────
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

  // ── Indian states list ────────────────────────────────────────────────────
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

  // ── Monitored cities with CWC danger/warning levels ───────────────────
  static const List<Map<String, dynamic>> monitoredCities = [

    // ANDHRA PRADESH
    { 'city': 'Vijayawada',   'state': 'Andhra Pradesh', 'river': 'Krishna',       'lat': 16.5062, 'lon': 80.6480, 'risk': 'HIGH',     'danger_level': 12.5,  'warning_level': 9.0  },
    { 'city': 'Rajahmundry',  'state': 'Andhra Pradesh', 'river': 'Godavari',      'lat': 17.0005, 'lon': 81.8040, 'risk': 'HIGH',     'danger_level': 14.0,  'warning_level': 12.0 },
    { 'city': 'Kurnool',      'state': 'Andhra Pradesh', 'river': 'Tungabhadra',   'lat': 15.8281, 'lon': 78.0373, 'risk': 'MODERATE', 'danger_level': 9.0,   'warning_level': 7.5  },
    { 'city': 'Nellore',      'state': 'Andhra Pradesh', 'river': 'Pennar',        'lat': 14.4426, 'lon': 79.9865, 'risk': 'MODERATE', 'danger_level': 8.0,   'warning_level': 6.5  },
    { 'city': 'Guntur',       'state': 'Andhra Pradesh', 'river': 'Krishna',       'lat': 16.3008, 'lon': 80.4428, 'risk': 'MODERATE', 'danger_level': 11.5,  'warning_level': 9.5  },

    // ASSAM
    { 'city': 'Guwahati',     'state': 'Assam', 'river': 'Brahmaputra', 'lat': 26.1445, 'lon': 91.7362, 'risk': 'HIGH',     'danger_level': 51.75, 'warning_level': 49.68 },
    { 'city': 'Dibrugarh',    'state': 'Assam', 'river': 'Brahmaputra', 'lat': 27.4728, 'lon': 94.9120, 'risk': 'HIGH',     'danger_level': 108.0, 'warning_level': 106.0 },
    { 'city': 'Silchar',      'state': 'Assam', 'river': 'Barak',       'lat': 24.8333, 'lon': 92.7789, 'risk': 'MODERATE', 'danger_level': 22.3,  'warning_level': 20.3  },
    { 'city': 'Jorhat',       'state': 'Assam', 'river': 'Brahmaputra', 'lat': 26.7465, 'lon': 94.2026, 'risk': 'MODERATE', 'danger_level': 86.88, 'warning_level': 84.88 },
    { 'city': 'Dhubri',       'state': 'Assam', 'river': 'Brahmaputra', 'lat': 26.0200, 'lon': 89.9700, 'risk': 'HIGH',     'danger_level': 32.42, 'warning_level': 30.42 },
    { 'city': 'Tezpur',       'state': 'Assam', 'river': 'Brahmaputra', 'lat': 26.6338, 'lon': 92.7926, 'risk': 'HIGH',     'danger_level': 72.31, 'warning_level': 70.31 },
    { 'city': 'Barpeta',      'state': 'Assam', 'river': 'Beki',        'lat': 26.3250, 'lon': 91.0000, 'risk': 'HIGH',     'danger_level': 47.0,  'warning_level': 45.0  },

    // BIHAR
    { 'city': 'Patna',        'state': 'Bihar', 'river': 'Ganga',   'lat': 25.5941, 'lon': 85.1376, 'risk': 'HIGH',     'danger_level': 48.60, 'warning_level': 47.60 },
    { 'city': 'Bhagalpur',    'state': 'Bihar', 'river': 'Ganga',   'lat': 25.2425, 'lon': 86.9842, 'risk': 'HIGH',     'danger_level': 33.68, 'warning_level': 32.68 },
    { 'city': 'Muzaffarpur',  'state': 'Bihar', 'river': 'Gandak',  'lat': 26.1209, 'lon': 85.3647, 'risk': 'HIGH',     'danger_level': 48.68, 'warning_level': 47.68 },
    { 'city': 'Darbhanga',    'state': 'Bihar', 'river': 'Bagmati', 'lat': 26.1542, 'lon': 85.8918, 'risk': 'HIGH',     'danger_level': 51.0,  'warning_level': 49.5  },
    { 'city': 'Gaya',         'state': 'Bihar', 'river': 'Falgu',   'lat': 24.7955, 'lon': 85.0002, 'risk': 'MODERATE', 'danger_level': 97.0,  'warning_level': 95.5  },
    { 'city': 'Begusarai',    'state': 'Bihar', 'river': 'Ganga',   'lat': 25.4182, 'lon': 86.1272, 'risk': 'HIGH',     'danger_level': 40.68, 'warning_level': 39.68 },

    // GUJARAT
    { 'city': 'Surat',        'state': 'Gujarat', 'river': 'Tapi',     'lat': 21.1702, 'lon': 72.8311, 'risk': 'HIGH',     'danger_level': 10.97, 'warning_level': 9.45  },
    { 'city': 'Vadodara',     'state': 'Gujarat', 'river': 'Vishwamitri','lat': 22.3072,'lon': 73.1812, 'risk': 'HIGH',     'danger_level': 11.58, 'warning_level': 10.06 },
    { 'city': 'Rajkot',       'state': 'Gujarat', 'river': 'Aji',      'lat': 22.3039, 'lon': 70.8022, 'risk': 'MODERATE', 'danger_level': 5.5,   'warning_level': 4.5   },
    { 'city': 'Ahmedabad',    'state': 'Gujarat', 'river': 'Sabarmati','lat': 23.0225, 'lon': 72.5714, 'risk': 'MODERATE', 'danger_level': 48.0,  'warning_level': 46.5  },

    // KERALA
    { 'city': 'Kochi',        'state': 'Kerala', 'river': 'Periyar',   'lat': 9.9312,  'lon': 76.2673, 'risk': 'HIGH',     'danger_level': 8.84,  'warning_level': 7.84  },
    { 'city': 'Thrissur',     'state': 'Kerala', 'river': 'Chalakudy', 'lat': 10.5276, 'lon': 76.2144, 'risk': 'HIGH',     'danger_level': 9.5,   'warning_level': 8.0   },
    { 'city': 'Alappuzha',    'state': 'Kerala', 'river': 'Pampa',     'lat': 9.4981,  'lon': 76.3388, 'risk': 'HIGH',     'danger_level': 4.0,   'warning_level': 3.0   },
    { 'city': 'Kozhikode',    'state': 'Kerala', 'river': 'Chaliyar',  'lat': 11.2588, 'lon': 75.7804, 'risk': 'MODERATE', 'danger_level': 7.5,   'warning_level': 6.5   },
    { 'city': 'Thiruvananthapuram', 'state': 'Kerala', 'river': 'Karamana', 'lat': 8.5241, 'lon': 76.9366, 'risk': 'MODERATE', 'danger_level': 5.5, 'warning_level': 4.5 },

    // MAHARASHTRA
    { 'city': 'Kolhapur',     'state': 'Maharashtra', 'river': 'Panchganga', 'lat': 16.7050, 'lon': 74.2433, 'risk': 'HIGH',     'danger_level': 14.0,  'warning_level': 12.05 },
    { 'city': 'Pune',         'state': 'Maharashtra', 'river': 'Mutha',      'lat': 18.5204, 'lon': 73.8567, 'risk': 'MODERATE', 'danger_level': 10.5,  'warning_level': 9.0   },
    { 'city': 'Nashik',       'state': 'Maharashtra', 'river': 'Godavari',   'lat': 19.9975, 'lon': 73.7898, 'risk': 'MODERATE', 'danger_level': 11.5,  'warning_level': 10.0  },
    { 'city': 'Nagpur',       'state': 'Maharashtra', 'river': 'Nag',        'lat': 21.1458, 'lon': 79.0882, 'risk': 'MODERATE', 'danger_level': 9.5,   'warning_level': 8.0   },
    { 'city': 'Sangli',       'state': 'Maharashtra', 'river': 'Krishna',    'lat': 16.8524, 'lon': 74.5815, 'risk': 'HIGH',     'danger_level': 12.0,  'warning_level': 10.5  },
    { 'city': 'Satara',       'state': 'Maharashtra', 'river': 'Krishna',    'lat': 17.6805, 'lon': 73.9986, 'risk': 'MODERATE', 'danger_level': 10.0,  'warning_level': 8.5   },

    // ODISHA
    { 'city': 'Cuttack',      'state': 'Odisha', 'river': 'Mahanadi',  'lat': 20.4625, 'lon': 85.8830, 'risk': 'HIGH',     'danger_level': 15.24, 'warning_level': 14.19 },
    { 'city': 'Bhubaneswar',  'state': 'Odisha', 'river': 'Daya',      'lat': 20.2961, 'lon': 85.8245, 'risk': 'MODERATE', 'danger_level': 12.0,  'warning_level': 10.5  },
    { 'city': 'Sambalpur',    'state': 'Odisha', 'river': 'Mahanadi',  'lat': 21.4669, 'lon': 83.9812, 'risk': 'HIGH',     'danger_level': 154.0, 'warning_level': 152.0 },
    { 'city': 'Puri',         'state': 'Odisha', 'river': 'Bhargavi',  'lat': 19.8135, 'lon': 85.8312, 'risk': 'MODERATE', 'danger_level': 4.0,   'warning_level': 3.0   },
    { 'city': 'Kendrapara',   'state': 'Odisha', 'river': 'Brahmani',  'lat': 20.5006, 'lon': 86.4214, 'risk': 'HIGH',     'danger_level': 7.0,   'warning_level': 5.5   },

    // UTTAR PRADESH
    { 'city': 'Varanasi',     'state': 'Uttar Pradesh', 'river': 'Ganga',   'lat': 25.3176, 'lon': 82.9739, 'risk': 'HIGH',     'danger_level': 71.26, 'warning_level': 70.26 },
    { 'city': 'Allahabad',    'state': 'Uttar Pradesh', 'river': 'Ganga',   'lat': 25.4358, 'lon': 81.8463, 'risk': 'HIGH',     'danger_level': 84.73, 'warning_level': 83.73 },
    { 'city': 'Kanpur',       'state': 'Uttar Pradesh', 'river': 'Ganga',   'lat': 26.4499, 'lon': 80.3319, 'risk': 'MODERATE', 'danger_level': 111.5, 'warning_level': 110.5 },
    { 'city': 'Lucknow',      'state': 'Uttar Pradesh', 'river': 'Gomti',   'lat': 26.8467, 'lon': 80.9462, 'risk': 'MODERATE', 'danger_level': 102.0, 'warning_level': 100.5 },
    { 'city': 'Agra',         'state': 'Uttar Pradesh', 'river': 'Yamuna',  'lat': 27.1767, 'lon': 78.0081, 'risk': 'MODERATE', 'danger_level': 163.0, 'warning_level': 161.5 },

    // WEST BENGAL
    { 'city': 'Kolkata',      'state': 'West Bengal', 'river': 'Hooghly',  'lat': 22.5726, 'lon': 88.3639, 'risk': 'HIGH',     'danger_level': 5.97,  'warning_level': 4.97  },
    { 'city': 'Howrah',       'state': 'West Bengal', 'river': 'Hooghly',  'lat': 22.5958, 'lon': 88.2636, 'risk': 'HIGH',     'danger_level': 6.5,   'warning_level': 5.5   },
    { 'city': 'Malda',        'state': 'West Bengal', 'river': 'Ganga',    'lat': 25.0108, 'lon': 88.1415, 'risk': 'HIGH',     'danger_level': 25.0,  'warning_level': 24.0  },
    { 'city': 'Jalpaiguri',   'state': 'West Bengal', 'river': 'Teesta',   'lat': 26.5418, 'lon': 88.7179, 'risk': 'HIGH',     'danger_level': 59.0,  'warning_level': 57.5  },
    { 'city': 'Murshidabad',  'state': 'West Bengal', 'river': 'Bhagirathi','lat': 24.1832, 'lon': 88.2690, 'risk': 'HIGH',     'danger_level': 18.95, 'warning_level': 17.95 },

    // KARNATAKA
    { 'city': 'Belagavi',     'state': 'Karnataka', 'river': 'Ghataprabha','lat': 15.8497, 'lon': 74.4977, 'risk': 'HIGH',     'danger_level': 11.0,  'warning_level': 9.5   },
    { 'city': 'Raichur',      'state': 'Karnataka', 'river': 'Krishna',    'lat': 16.2120, 'lon': 77.3566, 'risk': 'MODERATE', 'danger_level': 318.0, 'warning_level': 316.5 },
    { 'city': 'Bagalkot',     'state': 'Karnataka', 'river': 'Ghataprabha','lat': 16.1826, 'lon': 75.6961, 'risk': 'MODERATE', 'danger_level': 10.5,  'warning_level': 9.0   },
    { 'city': 'Mysuru',       'state': 'Karnataka', 'river': 'Kabini',     'lat': 12.2958, 'lon': 76.6394, 'risk': 'MODERATE', 'danger_level': 773.0, 'warning_level': 770.0 },

    // TELANGANA
    { 'city': 'Hyderabad',    'state': 'Telangana', 'river': 'Musi',       'lat': 17.3850, 'lon': 78.4867, 'risk': 'MODERATE', 'danger_level': 7.5,   'warning_level': 6.5   },
    { 'city': 'Warangal',     'state': 'Telangana', 'river': 'Godavari',   'lat': 17.9784, 'lon': 79.5941, 'risk': 'MODERATE', 'danger_level': 10.5,  'warning_level': 9.0   },
    { 'city': 'Khammam',      'state': 'Telangana', 'river': 'Munneru',    'lat': 17.2473, 'lon': 80.1514, 'risk': 'HIGH',     'danger_level': 8.0,   'warning_level': 6.5   },

    // MADHYA PRADESH
    { 'city': 'Jabalpur',     'state': 'Madhya Pradesh', 'river': 'Narmada', 'lat': 23.1815, 'lon': 79.9864, 'risk': 'HIGH',     'danger_level': 12.5,  'warning_level': 11.0  },
    { 'city': 'Hoshangabad',  'state': 'Madhya Pradesh', 'river': 'Narmada', 'lat': 22.7510, 'lon': 77.7268, 'risk': 'HIGH',     'danger_level': 286.5, 'warning_level': 284.5 },
    { 'city': 'Bhopal',       'state': 'Madhya Pradesh', 'river': 'Betwa',   'lat': 23.2599, 'lon': 77.4126, 'risk': 'MODERATE', 'danger_level': 9.0,   'warning_level': 7.5   },
  ];
}
