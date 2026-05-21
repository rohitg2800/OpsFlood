// lib/constants.dart
// OpsFlood — App-wide constants
// CWC danger/warning levels sourced from:
//   • CWC Daily Flood Situation Bulletins (Aug–Sep 2024)
//   • India-WRIS HMS station data
//   • CWC Flood Forecasting Network Annex-I (175 FF stations)
// Coordinates: OpenStreetMap / Google Maps verified

class AppConstants {
  static const String baseUrl       = 'https://opsflood.onrender.com';
  static const String backupBaseUrl = 'https://opsflood-backend.onrender.com';

  static const String healthEndpoint          = '/health';
  static const String liveTelemetryEndpoint   = '/api/live-telemetry';
  static const String liveLevelsEndpoint      = '/api/live-levels';
  static const String criticalAlertsEndpoint  = '/api/critical-alerts';
  static const String predictLegacyEndpoint   = '/predict/legacy';
  static const String weatherCurrentEndpoint  = '/weather/current';
  static const String weatherForecastEndpoint = '/weather/forecast';

  // FIXED: was 'HIGH' — PredictionService emits SEVERE not HIGH
  static const Map<String, int> riskColors = {
    'LOW':      0xFF34C759,
    'MODERATE': 0xFFF59E0B,
    'SEVERE':   0xFFEF4444,   // ← was 'HIGH'
    'CRITICAL': 0xFF8B0000,
    'HIGH':     0xFFEF4444,   // legacy alias for any old references
  };

  static const Map<String, String> riskIcons = {
    'LOW':      'SAFE',
    'MODERATE': 'WATCH',
    'SEVERE':   'WARN',       // ← was 'HIGH'
    'CRITICAL': 'ALERT',
    'HIGH':     'WARN',       // legacy alias
  };

  // ─── India-wide CWC river gauging stations ────────────────────────────────
  // danger_level / warning_level in metres on CWC gauge (MSL-based where noted).
  // Source: CWC DFB bulletins Aug–Sep 2024, India-WRIS HMS.
  // 'risk' = baseline seasonal risk category (not real-time).
  static const List<Map<String, dynamic>> monitoredCities = [

    // ══ ANDHRA PRADESH ══════════════════════════════════════════════════════
    { 'city': 'Vijayawada',      'state': 'Andhra Pradesh', 'river': 'Krishna',       'lat': 16.5062, 'lon': 80.6480, 'risk': 'HIGH',     'danger_level': 12.5,  'warning_level': 9.0   },
    { 'city': 'Rajahmundry',     'state': 'Andhra Pradesh', 'river': 'Godavari',      'lat': 17.0005, 'lon': 81.8040, 'risk': 'HIGH',     'danger_level': 14.0,  'warning_level': 12.0  },
    { 'city': 'Kurnool',         'state': 'Andhra Pradesh', 'river': 'Tungabhadra',   'lat': 15.8281, 'lon': 78.0373, 'risk': 'MODERATE', 'danger_level': 9.0,   'warning_level': 7.5   },
    { 'city': 'Nellore',         'state': 'Andhra Pradesh', 'river': 'Pennar',        'lat': 14.4426, 'lon': 79.9865, 'risk': 'MODERATE', 'danger_level': 8.0,   'warning_level': 6.5   },
    { 'city': 'Avanigadda',      'state': 'Andhra Pradesh', 'river': 'Lower Krishna', 'lat': 16.0200, 'lon': 80.9200, 'risk': 'HIGH',     'danger_level': 11.0,  'warning_level': 9.0   }, // CWC: DL 11.0, WL 9.0
    { 'city': 'Mantralayam',     'state': 'Andhra Pradesh', 'river': 'Tungabhadra',   'lat': 15.3758, 'lon': 78.2350, 'risk': 'MODERATE', 'danger_level': 10.5,  'warning_level': 9.0   },
    { 'city': 'Perur',           'state': 'Andhra Pradesh', 'river': 'Godavari',      'lat': 18.2500, 'lon': 80.0100, 'risk': 'MODERATE', 'danger_level': 90.0,  'warning_level': 88.0  }, // MSL-based
    { 'city': 'Srikakulam',      'state': 'Andhra Pradesh', 'river': 'Vamsadhara',    'lat': 18.2969, 'lon': 83.8978, 'risk': 'MODERATE', 'danger_level': 9.5,   'warning_level': 8.0   },
    { 'city': 'Vizianagaram',    'state': 'Andhra Pradesh', 'river': 'Nagavali',      'lat': 18.1066, 'lon': 83.3956, 'risk': 'MODERATE', 'danger_level': 9.0,   'warning_level': 7.5   },
    { 'city': 'Guntur',          'state': 'Andhra Pradesh', 'river': 'Krishna',       'lat': 16.3008, 'lon': 80.4428, 'risk': 'MODERATE', 'danger_level': 11.5,  'warning_level': 9.5   },
    { 'city': 'Ongole',          'state': 'Andhra Pradesh', 'river': 'Gundlakamma',   'lat': 15.5057, 'lon': 80.0499, 'risk': 'LOW',      'danger_level': 7.0,   'warning_level': 5.5   },

    // ══ ARUNACHAL PRADESH ═══════════════════════════════════════════════════
    { 'city': 'Pasighat',        'state': 'Arunachal Pradesh', 'river': 'Brahmaputra','lat': 28.0660, 'lon': 95.3280, 'risk': 'HIGH',    'danger_level': 145.0, 'warning_level': 143.0 }, // MSL
    { 'city': 'Itanagar',        'state': 'Arunachal Pradesh', 'river': 'Dikrong',    'lat': 27.0844, 'lon': 93.6053, 'risk': 'MODERATE','danger_level': 10.0,  'warning_level': 8.0   },
    { 'city': 'Along',           'state': 'Arunachal Pradesh', 'river': 'Siyom',      'lat': 28.1720, 'lon': 94.7989, 'risk': 'HIGH',    'danger_level': 12.0,  'warning_level': 10.0  },
    { 'city': 'Badatighat',      'state': 'Arunachal Pradesh', 'river': 'Subansiri',  'lat': 27.6000, 'lon': 94.2500, 'risk': 'HIGH',    'danger_level': 88.0,  'warning_level': 86.0  }, // CWC FF site MSL
    { 'city': 'Tezu',            'state': 'Arunachal Pradesh', 'river': 'Lohit',      'lat': 27.9266, 'lon': 96.1704, 'risk': 'HIGH',    'danger_level': 130.0, 'warning_level': 128.0 }, // MSL

    // ══ ASSAM ════════════════════════════════════════════════════════════════
    { 'city': 'Guwahati',        'state': 'Assam', 'river': 'Brahmaputra', 'lat': 26.1445, 'lon': 91.7362, 'risk': 'HIGH',     'danger_level': 51.75, 'warning_level': 49.68 }, // Guwahati DC Court CWC
    { 'city': 'Dibrugarh',       'state': 'Assam', 'river': 'Brahmaputra', 'lat': 27.4728, 'lon': 94.9120, 'risk': 'HIGH',     'danger_level': 108.0, 'warning_level': 106.0 }, // MSL Dibrugarh CWC
    { 'city': 'Silchar',         'state': 'Assam', 'river': 'Barak',       'lat': 24.8333, 'lon': 92.7789, 'risk': 'MODERATE', 'danger_level': 22.3,  'warning_level': 20.3  }, // Annapurna Ghat CWC
    { 'city': 'Jorhat',          'state': 'Assam', 'river': 'Brahmaputra', 'lat': 26.7465, 'lon': 94.2026, 'risk': 'MODERATE', 'danger_level': 86.88, 'warning_level': 84.88 }, // Neamatighat MSL
    { 'city': 'Dhubri',          'state': 'Assam', 'river': 'Brahmaputra', 'lat': 26.0200, 'lon': 89.9700, 'risk': 'HIGH',     'danger_level': 32.42, 'warning_level': 30.42 }, // CWC Dhubri
    { 'city': 'Tezpur',          'state': 'Assam', 'river': 'Brahmaputra', 'lat': 26.6338, 'lon': 92.7926, 'risk': 'HIGH',     'danger_level': 72.31, 'warning_level': 70.31 }, // CWC Tezpur MSL
    { 'city': 'Goalpara',        'state': 'Assam', 'river': 'Brahmaputra', 'lat': 26.1755, 'lon': 90.6170, 'risk': 'HIGH',     'danger_level': 38.25, 'warning_level': 36.25 }, // CWC Goalpara
    { 'city': 'Lakhimpur',       'state': 'Assam', 'river': 'Subansiri',   'lat': 27.2360, 'lon': 94.1010, 'risk': 'HIGH',     'danger_level': 87.0,  'warning_level': 85.0  }, // Badatighat area MSL
    { 'city': 'Karimganj',       'state': 'Assam', 'river': 'Kushiyara',   'lat': 24.8640, 'lon': 92.3600, 'risk': 'MODERATE', 'danger_level': 14.94, 'warning_level': 13.94 }, // CWC verified
    { 'city': 'Sivsagar',        'state': 'Assam', 'river': 'Dikhow',      'lat': 26.9880, 'lon': 94.6360, 'risk': 'MODERATE', 'danger_level': 91.5,  'warning_level': 89.5  }, // CWC Sivasagar MSL
    { 'city': 'Margherita',      'state': 'Assam', 'river': 'Buridehing',  'lat': 27.2850, 'lon': 95.6730, 'risk': 'HIGH',     'danger_level': 136.0, 'warning_level': 133.0 }, // CWC Margherita MSL
    { 'city': 'Numaligarh',      'state': 'Assam', 'river': 'Dhansiri',    'lat': 26.6700, 'lon': 93.7000, 'risk': 'MODERATE', 'danger_level': 71.0,  'warning_level': 68.0  }, // CWC Numaligarh MSL
    { 'city': 'Golaghat',        'state': 'Assam', 'river': 'Dhansiri',    'lat': 26.5230, 'lon': 93.9560, 'risk': 'MODERATE', 'danger_level': 73.5,  'warning_level': 71.5  },
    { 'city': 'Barpeta',         'state': 'Assam', 'river': 'Beki',        'lat': 26.3250, 'lon': 91.0000, 'risk': 'HIGH',     'danger_level': 47.0,  'warning_level': 45.0  }, // CWC Beki Road Bridge
    { 'city': 'Hailakandi',      'state': 'Assam', 'river': 'Katakhal',    'lat': 24.6841, 'lon': 92.5663, 'risk': 'MODERATE', 'danger_level': 20.27, 'warning_level': 19.27 }, // CWC Matijuri verified

    // ══ BIHAR ════════════════════════════════════════════════════════════════
    { 'city': 'Patna',           'state': 'Bihar', 'river': 'Ganga',       'lat': 25.5941, 'lon': 85.1376, 'risk': 'HIGH',     'danger_level': 48.60, 'warning_level': 47.60 }, // CWC Gandhighat verified
    { 'city': 'Bhagalpur',       'state': 'Bihar', 'river': 'Ganga',       'lat': 25.2425, 'lon': 86.9842, 'risk': 'HIGH',     'danger_level': 33.68, 'warning_level': 32.68 }, // CWC Bhagalpur verified
    { 'city': 'Muzaffarpur',     'state': 'Bihar', 'river': 'Gandak',      'lat': 26.1209, 'lon': 85.3647, 'risk': 'HIGH',     'danger_level': 48.68, 'warning_level': 47.68 }, // CWC Benibad Bagmati
    { 'city': 'Darbhanga',       'state': 'Bihar', 'river': 'Bagmati',     'lat': 26.1542, 'lon': 85.8918, 'risk': 'HIGH',     'danger_level