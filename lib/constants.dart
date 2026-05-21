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

  // ─── India-wide river stations ────────────────────────────────────────────
  // Sources: CWC / India-WRIS HMS; danger levels in metres (CWC scale).
  // Per-city real values come from the live backend — these are fallback defaults.
  static const List<Map<String, dynamic>> monitoredCities = [
    // ── Andhra Pradesh ──────────────────────────────────────────────────────
    { 'city': 'Vijayawada',    'state': 'Andhra Pradesh', 'river': 'Krishna',      'lat': 16.5062, 'lon': 80.6480, 'risk': 'HIGH',     'danger_level': 12.5, 'warning_level': 10.5 },
    { 'city': 'Rajahmundry',   'state': 'Andhra Pradesh', 'river': 'Godavari',     'lat': 17.0005, 'lon': 81.8040, 'risk': 'HIGH',     'danger_level': 14.0, 'warning_level': 12.0 },
    { 'city': 'Kurnool',       'state': 'Andhra Pradesh', 'river': 'Tungabhadra',  'lat': 15.8281, 'lon': 78.0373, 'risk': 'MODERATE', 'danger_level': 9.0,  'warning_level': 7.5  },
    { 'city': 'Nellore',       'state': 'Andhra Pradesh', 'river': 'Pennar',       'lat': 14.4426, 'lon': 79.9865, 'risk': 'MODERATE', 'danger_level': 8.0,  'warning_level': 6.5  },
    // ── Arunachal Pradesh ───────────────────────────────────────────────────
    { 'city': 'Pasighat',      'state': 'Arunachal Pradesh', 'river': 'Brahmaputra','lat': 28.0660, 'lon': 95.3280, 'risk': 'HIGH',    'danger_level': 18.0, 'warning_level': 15.0 },
    { 'city': 'Itanagar',      'state': 'Arunachal Pradesh', 'river': 'Dikrong',    'lat': 27.0844, 'lon': 93.6053, 'risk': 'MODERATE','danger_level': 10.0, 'warning_level': 8.0  },
    // ── Assam ────────────────────────────────────────────────────────────────
    { 'city': 'Guwahati',      'state': 'Assam', 'river': 'Brahmaputra', 'lat': 26.1445, 'lon': 91.7362, 'risk': 'HIGH',     'danger_level': 16.5, 'warning_level': 14.0 },
    { 'city': 'Dibrugarh',     'state': 'Assam', 'river': 'Brahmaputra', 'lat': 27.4728, 'lon': 94.9120, 'risk': 'HIGH',     'danger_level': 17.0, 'warning_level': 14.5 },
    { 'city': 'Silchar',       'state': 'Assam', 'river': 'Barak',       'lat': 24.8333, 'lon': 92.7789, 'risk': 'MODERATE', 'danger_level': 11.0, 'warning_level': 9.0  },
    { 'city': 'Jorhat',        'state': 'Assam', 'river': 'Brahmaputra', 'lat': 26.7465, 'lon': 94.2026, 'risk': 'MODERATE', 'danger_level': 14.0, 'warning_level': 11.5 },
    { 'city': 'Dhubri',        'state': 'Assam', 'river': 'Brahmaputra', 'lat': 26.0200, 'lon': 89.9700, 'risk': 'HIGH',     'danger_level': 15.5, 'warning_level': 13.0 },
    // ── Bihar ────────────────────────────────────────────────────────────────
    // Bihar has India's highest flood exposure — 28 districts flood-prone.
    { 'city': 'Patna',         'state': 'Bihar', 'river': 'Ganga',       'lat': 25.5941, 'lon': 85.1376, 'risk': 'HIGH',     'danger_level': 50.27, 'warning_level': 48.50 },
    { 'city': 'Bhagalpur',     'state': 'Bihar', 'river': 'Ganga',       'lat': 25.2425, 'lon': 86.9842, 'risk': 'HIGH',     'danger_level': 34.93, 'warning_level': 33.00 },
    { 'city': 'Muzaffarpur',   'state': 'Bihar', 'river': 'Gandak',      'lat': 26.1209, 'lon': 85.3647, 'risk': 'HIGH',     'danger_level': 56.50, 'warning_level': 54.40 },
    { 'city': 'Darbhanga',     'state': 'Bihar', 'river': 'Bagmati',     'lat': 26.1542, 'lon': 85.8918, 'risk': 'HIGH',     'danger_level': 52.73, 'warning_level': 50.80 },
    { 'city': 'Sitamarhi',     'state': 'Bihar', 'river': 'Bagmati',     'lat': 26.5918, 'lon': 85.4900, 'risk': 'HIGH',     'danger_level': 75.20, 'warning_level': 73.50 },
    { 'city': 'Supaul',        'state': 'Bihar', 'river': 'Koshi',       'lat': 26.1230, 'lon': 86.6070, 'risk': 'CRITICAL', 'danger_level': 64.92, 'warning_level': 62.80 },
    { 'city': 'Araria',        'state': 'Bihar', 'river': 'Koshi',       'lat': 26.1500, 'lon': 87.4700, 'risk': 'CRITICAL', 'danger_level': 70.00, 'warning_level': 67.50 },
    { 'city': 'Bhimnagar',     'state': 'Bihar', 'river': 'Koshi',       'lat': 26.8000, 'lon': 87.0500, 'risk': 'CRITICAL', 'danger_level': 68.50, 'warning_level': 66.00 },
    { 'city': 'Samastipur',    'state': 'Bihar', 'river': 'Burhi Gandak', 'lat': 25.8600, 'lon': 85.7800, 'risk': 'HIGH',    'danger_level': 51.80, 'warning_level': 49.50 },
    { 'city': 'Gopalganj',     'state': 'Bihar', 'river': 'Gandak',      'lat': 26.4700, 'lon': 84.4400, 'risk': 'HIGH',     'danger_level': 62.10, 'warning_level': 60.00 },
    { 'city': 'Saran',         'state': 'Bihar', 'river': 'Ganga',       'lat': 25.9200, 'lon': 84.7500, 'risk': 'HIGH',     'danger_level': 48.50, 'warning_level': 46.50 },
    { 'city': 'Vaishali',      'state': 'Bihar', 'river': 'Gandak',      'lat': 25.6900, 'lon': 85.2000, 'risk': 'HIGH',     'danger_level': 55.20, 'warning_level': 53.00 },
    { 'city': 'Begusarai',     'state': 'Bihar', 'river': 'Ganga',       'lat': 25.4200, 'lon': 86.1300, 'risk': 'MODERATE', 'danger_level': 38.50, 'warning_level': 36.50 },
    // ── Chhattisgarh ────────────────────────────────────────────────────────
    { 'city': 'Raipur',        'state': 'Chhattisgarh', 'river': 'Mahanadi',  'lat': 21.2514, 'lon': 81.6296, 'risk': 'MODERATE', 'danger_level': 9.0,  'warning_level': 7.5  },
    { 'city': 'Bilaspur',      'state': 'Chhattisgarh', 'river': 'Arpa',      'lat': 22.0797, 'lon': 82.1409, 'risk': 'LOW',      'danger_level': 6.5,  'warning_level': 5.0  },
    { 'city': 'Jagdalpur',     'state': 'Chhattisgarh', 'river': 'Indravati', 'lat': 19.0800, 'lon': 82.0200, 'risk': 'MODERATE', 'danger_level': 11.0, 'warning_level': 9.0  },
    // ── Goa ─────────────────────────────────────────────────────────────────
    { 'city': 'Panaji',        'state': 'Goa', 'river': 'Mandovi',      'lat': 15.4909, 'lon': 73.8278, 'risk': 'LOW',      'danger_level': 5.5,  'warning_level': 4.0  },
    { 'city': 'Margao',        'state': 'Goa', 'river': 'Zuari',        'lat': 15.2736, 'lon': 74.0018, 'risk': 'LOW',      'danger_level': 4.5,  'warning_level': 3.5  },
    // ── Gujarat ─────────────────────────────────────────────────────────────
    { 'city': 'Vadodara',      'state': 'Gujarat', 'river': 'Vishwamitri','lat': 22.3072, 'lon': 73.1812, 'risk': 'HIGH',     'danger_level': 14.0, 'warning_level': 12.0 },
    { 'city': 'Surat',         'state': 'Gujarat', 'river': 'Tapi',       'lat': 21.1702, 'lon': 72.8311, 'risk': 'HIGH',     'danger_level': 11.0, 'warning_level': 9.0  },
    { 'city': 'Ahmedabad',     'state': 'Gujarat', 'river': 'Sabarmati',  'lat': 23.0225, 'lon': 72.5714, 'risk': 'MODERATE', 'danger_level': 9.0,  'warning_level': 7.5  },
    { 'city': 'Rajkot',        'state': 'Gujarat', 'river': 'Aji',        'lat': 22.3039, 'lon': 70.8022, 'risk': 'LOW',      'danger_level': 6.0,  'warning_level': 5.0  },
    { 'city': 'Bharuch',       'state': 'Gujarat', 'river': 'Narmada',    'lat': 21.7051, 'lon': 72.9959, 'risk': 'HIGH',     'danger_level': 13.0, 'warning_level': 11.0 },
    // ── Haryana ─────────────────────────────────────────────────────────────
    { 'city': 'Ambala',        'state': 'Haryana', 'river': 'Ghaggar',   'lat': 30.3782, 'lon': 76.7767, 'risk': 'HIGH',     'danger_level': 10.0, 'warning_level': 8.5  },
    { 'city': 'Hisar',         'state': 'Haryana', 'river': 'Ghaggar',   'lat': 29.1492, 'lon': 75.7217, 'risk': 'MODERATE', 'danger_level': 8.0,  'warning_level': 6.5  },
    { 'city': 'Yamunanagar',   'state': 'Haryana', 'river': 'Yamuna',    'lat': 30.1290, 'lon': 77.3030, 'risk': 'MODERATE', 'danger_level': 9.5,  'warning_level': 8.0  },
    // ── Himachal Pradesh ────────────────────────────────────────────────────
    { 'city': 'Mandi',         'state': 'Himachal Pradesh', 'river': 'Beas',   'lat': 31.7080, 'lon': 76.9318, 'risk': 'HIGH',     'danger_level': 12.0, 'warning_level': 10.0 },
    { 'city': 'Bilaspur HP',   'state': 'Himachal Pradesh', 'river': 'Sutlej', 'lat': 31.3260, 'lon': 76.7605, 'risk': 'MODERATE', 'danger_level': 10.0, 'warning_level': 8.5  },
    { 'city': 'Kullu',         'state': 'Himachal Pradesh', 'river': 'Beas',   'lat': 31.9577, 'lon': 77.1095, 'risk': 'HIGH',     'danger_level': 11.0, 'warning_level': 9.0  },
    // ── Jharkhand ───────────────────────────────────────────────────────────
    { 'city': 'Ranchi',        'state': 'Jharkhand', 'river': 'Subarnarekha', 'lat': 23.3441, 'lon': 85.3096, 'risk': 'MODERATE', 'danger_level': 8.0,  'warning_level': 6.5  },
    { 'city': 'Dhanbad',       'state': 'Jharkhand', 'river': 'Damodar',      'lat': 23.7957, 'lon': 86.4304, 'risk': 'HIGH',     'danger_level': 10.0, 'warning_level': 8.0  },
    { 'city': 'Jamshedpur',    'state': 'Jharkhand', 'river': 'Subarnarekha', 'lat': 22.8046, 'lon': 86.2029, 'risk': 'HIGH',     'danger_level': 12.0, 'warning_level': 10.0 },
    // ── Karnataka ───────────────────────────────────────────────────────────
    { 'city': 'Bengaluru',     'state': 'Karnataka', 'river': 'Vrishabhavathi','lat': 12.9716, 'lon': 77.5946, 'risk': 'LOW',      'danger_level': 5.0,  'warning_level': 4.0  },
    { 'city': 'Mysuru',        'state': 'Karnataka', 'river': 'Kaveri',         'lat': 12.2958, 'lon': 76.6394, 'risk': 'MODERATE', 'danger_level': 9.0,  'warning_level': 7.5  },
    { 'city': 'Mangaluru',     'state': 'Karnataka', 'river': 'Netravati',      'lat': 12.9141, 'lon': 74.8560, 'risk': 'MODERATE', 'danger_level': 8.0,  'warning_level': 6.5  },
    { 'city': 'Belagavi',      'state': 'Karnataka', 'river': 'Malaprabha',     'lat': 15.8497, 'lon': 74.4977, 'risk': 'MODERATE', 'danger_level': 8.5,  'warning_level': 7.0  },
    { 'city': 'Raichur',       'state': 'Karnataka', 'river': 'Krishna',        'lat': 16.2120, 'lon': 77.3566, 'risk': 'HIGH',     'danger_level': 11.0, 'warning_level': 9.0  },
    // ── Kerala ──────────────────────────────────────────────────────────────
    { 'city': 'Kochi',              'state': 'Kerala', 'river': 'Periyar',   'lat': 9.9312,  'lon': 76.2673, 'risk': 'HIGH',     'danger_level': 10.0, 'warning_level': 8.5  },
    { 'city': 'Thiruvananthapuram', 'state': 'Kerala', 'river': 'Karamana',  'lat': 8.5241,  'lon': 76.9366, 'risk': 'LOW',      'danger_level': 6.0,  'warning_level': 5.0  },
    { 'city': 'Kozhikode',          'state': 'Kerala', 'river': 'Chaliyar',  'lat': 11.2588, 'lon': 75.7804, 'risk': 'MODERATE', 'danger_level': 8.5,  'warning_level': 7.0  },
    { 'city': 'Thrissur',           'state': 'Kerala', 'river': 'Chalakudy', 'lat': 10.5276, 'lon': 76.2144, 'risk': 'MODERATE', 'danger_level': 9.0,  'warning_level': 7.5  },
    { 'city': 'Alappuzha',          'state': 'Kerala', 'river': 'Pamba',     'lat': 9.4981,  'lon': 76.3388, 'risk': 'HIGH',     'danger_level': 8.0,  'warning_level': 6.5  },
    { 'city': 'Palakkad',           'state': 'Kerala', 'river': 'Bharathapuzha', 'lat': 10.7867, 'lon': 76.6548, 'risk': 'MODERATE', 'danger_level': 9.5, 'warning_level': 8.0 },
    // ── Madhya Pradesh ──────────────────────────────────────────────────────
    { 'city': 'Jabalpur',      'state': 'Madhya Pradesh', 'river': 'Narmada',  'lat': 23.1815, 'lon': 79.9864, 'risk': 'HIGH',     'danger_level': 11.0, 'warning_level': 9.5  },
    { 'city': 'Bhopal',        'state': 'Madhya Pradesh', 'river': 'Betwa',    'lat': 23.2599, 'lon': 77.4126, 'risk': 'MODERATE', 'danger_level': 8.5,  'warning_level': 7.0  },
    { 'city': 'Gwalior',       'state': 'Madhya Pradesh', 'river': 'Chambal',  'lat': 26.2183, 'lon': 78.1828, 'risk': 'MODERATE', 'danger_level': 9.0,  'warning_level': 7.5  },
    { 'city': 'Indore',        'state': 'Madhya Pradesh', 'river': 'Kshipra',  'lat': 22.7196, 'lon': 75.8577, 'risk': 'LOW',      'danger_level': 6.5,  'warning_level': 5.0  },
    { 'city': 'Khandwa',       'state': 'Madhya Pradesh', 'river': 'Narmada',  'lat': 21.8281, 'lon': 76.3556, 'risk': 'MODERATE', 'danger_level': 10.5, 'warning_level': 8.5  },
    // ── Maharashtra ─────────────────────────────────────────────────────────
    { 'city': 'Mumbai',        'state': 'Maharashtra', 'river': 'Mithi',       'lat': 19.0760, 'lon': 72.8777, 'risk': 'HIGH',     'danger_level': 5.0,  'warning_level': 4.0  },
    { 'city': 'Pune',          'state': 'Maharashtra', 'river': 'Mula-Mutha',  'lat': 18.5204, 'lon': 73.8567, 'risk': 'HIGH',     'danger_level': 9.0,  'warning_level': 7.5  },
    { 'city': 'Nashik',        'state': 'Maharashtra', 'river': 'Godavari',    'lat': 19.9975, 'lon': 73.7898, 'risk': 'MODERATE', 'danger_level': 10.0, 'warning_level': 8.5  },
    { 'city': 'Kolhapur',      'state': 'Maharashtra', 'river': 'Panchganga',  'lat': 16.7050, 'lon': 74.2433, 'risk': 'HIGH',     'danger_level': 46.50, 'warning_level': 44.50 },
    { 'city': 'Sangli',        'state': 'Maharashtra', 'river': 'Krishna',     'lat': 16.8524, 'lon': 74.5815, 'risk': 'HIGH',     'danger_level': 49.00, 'warning_level': 47.00 },
    { 'city': 'Nagpur',        'state': 'Maharashtra', 'river': 'Nag',         'lat': 21.1458, 'lon': 79.0882, 'risk': 'LOW',      'danger_level': 6.5,  'warning_level': 5.0  },
    { 'city': 'Aurangabad',    'state': 'Maharashtra', 'river': 'Kham',        'lat': 19.8762, 'lon': 75.3433, 'risk': 'LOW',      'danger_level': 5.5,  'warning_level': 4.5  },
    // ── Manipur ─────────────────────────────────────────────────────────────
    { 'city': 'Imphal',        'state': 'Manipur', 'river': 'Imphal',  'lat': 24.8170, 'lon': 93.9368, 'risk': 'MODERATE', 'danger_level': 9.0, 'warning_level': 7.5 },
    // ── Meghalaya ────────────────────────────────────────────────────────────
    { 'city': 'Shillong',      'state': 'Meghalaya', 'river': 'Umiam',   'lat': 25.5788, 'lon': 91.8933, 'risk': 'LOW',      'danger_level': 6.5,  'warning_level': 5.0  },
    // ── Mizoram ──────────────────────────────────────────────────────────────
    { 'city': 'Aizawl',        'state': 'Mizoram', 'river': 'Tlawng',   'lat': 23.7307, 'lon': 92.7173, 'risk': 'LOW',      'danger_level': 7.0,  'warning_level': 5.5  },
    // ── Nagaland ─────────────────────────────────────────────────────────────
    { 'city': 'Dimapur',       'state': 'Nagaland', 'river': 'Dhansiri', 'lat': 25.9044, 'lon': 93.7272, 'risk': 'MODERATE', 'danger_level': 8.5,  'warning_level': 7.0  },
    // ── Odisha ───────────────────────────────────────────────────────────────
    { 'city': 'Bhubaneswar',   'state': 'Odisha', 'river': 'Mahanadi',  'lat': 20.2961, 'lon': 85.8245, 'risk': 'MODERATE', 'danger_level': 10.0, 'warning_level': 8.5  },
    { 'city': 'Cuttack',       'state': 'Odisha', 'river': 'Mahanadi',  'lat': 20.4625, 'lon': 85.8828, 'risk': 'HIGH',     'danger_level': 12.0, 'warning_level': 10.0 },
    { 'city': 'Sambalpur',     'state': 'Odisha', 'river': 'Mahanadi',  'lat': 21.4669, 'lon': 83.9812, 'risk': 'HIGH',     'danger_level': 11.0, 'warning_level': 9.0  },
    { 'city': 'Balasore',      'state': 'Odisha', 'river': 'Subarnarekha', 'lat': 21.4942, 'lon': 86.9342, 'risk': 'HIGH',  'danger_level': 10.5, 'warning_level': 8.5  },
    { 'city': 'Kendrapara',    'state': 'Odisha', 'river': 'Brahmani',  'lat': 20.5000, 'lon': 86.4100, 'risk': 'HIGH',     'danger_level': 9.5,  'warning_level': 8.0  },
    // ── Punjab ───────────────────────────────────────────────────────────────
    { 'city': 'Ludhiana',      'state': 'Punjab', 'river': 'Sutlej',    'lat': 30.9009, 'lon': 75.8573, 'risk': 'HIGH',     'danger_level': 11.0, 'warning_level': 9.5  },
    { 'city': 'Amritsar',      'state': 'Punjab', 'river': 'Ravi',      'lat': 31.6340, 'lon': 74.8723, 'risk': 'MODERATE', 'danger_level': 8.0,  'warning_level': 6.5  },
    { 'city': 'Pathankot',     'state': 'Punjab', 'river': 'Ravi',      'lat': 32.2744, 'lon': 75.6522, 'risk': 'HIGH',     'danger_level': 10.0, 'warning_level': 8.5  },
    { 'city': 'Ropar',         'state': 'Punjab', 'river': 'Sutlej',    'lat': 30.9600, 'lon': 76.5200, 'risk': 'MODERATE', 'danger_level': 9.0,  'warning_level': 7.5  },
    // ── Rajasthan ────────────────────────────────────────────────────────────
    { 'city': 'Kota',          'state': 'Rajasthan', 'river': 'Chambal',  'lat': 25.2138, 'lon': 75.8648, 'risk': 'HIGH',     'danger_level': 11.5, 'warning_level': 9.5  },
    { 'city': 'Jaipur',        'state': 'Rajasthan', 'river': 'Banas',    'lat': 26.9124, 'lon': 75.7873, 'risk': 'LOW',      'danger_level': 7.0,  'warning_level': 5.5  },
    { 'city': 'Jhalawar',      'state': 'Rajasthan', 'river': 'Kalisindh','lat': 24.5930, 'lon': 76.1600, 'risk': 'MODERATE', 'danger_level': 9.0,  'warning_level': 7.5  },
    // ── Sikkim ───────────────────────────────────────────────────────────────
    { 'city': 'Gangtok',       'state': 'Sikkim', 'river': 'Teesta',    'lat': 27.3314, 'lon': 88.6138, 'risk': 'HIGH',     'danger_level': 12.0, 'warning_level': 10.0 },
    { 'city': 'Rangpo',        'state': 'Sikkim', 'river': 'Teesta',    'lat': 27.1700, 'lon': 88.5300, 'risk': 'HIGH',     'danger_level': 11.0, 'warning_level': 9.0  },
    // ── Tamil Nadu ───────────────────────────────────────────────────────────
    { 'city': 'Chennai',            'state': 'Tamil Nadu', 'river': 'Adyar',    'lat': 13.0827, 'lon': 80.2707, 'risk': 'HIGH',     'danger_level': 5.0,  'warning_level': 4.0  },
    { 'city': 'Tiruchirappalli',    'state': 'Tamil Nadu', 'river': 'Kaveri',   'lat': 10.7905, 'lon': 78.7047, 'risk': 'MODERATE', 'danger_level': 10.0, 'warning_level': 8.5  },
    { 'city': 'Coimbatore',         'state': 'Tamil Nadu', 'river': 'Noyyal',   'lat': 11.0168, 'lon': 76.9558, 'risk': 'LOW',      'danger_level': 6.5,  'warning_level': 5.0  },
    { 'city': 'Madurai',            'state': 'Tamil Nadu', 'river': 'Vaigai',   'lat': 9.9252,  'lon': 78.1198, 'risk': 'MODERATE', 'danger_level': 8.5,  'warning_level': 7.0  },
    { 'city': 'Cuddalore',          'state': 'Tamil Nadu', 'river': 'Vellar',   'lat': 11.7447, 'lon': 79.7689, 'risk': 'HIGH',     'danger_level': 9.0,  'warning_level': 7.5  },
    // ── Telangana ────────────────────────────────────────────────────────────
    { 'city': 'Hyderabad',     'state': 'Telangana', 'river': 'Musi',      'lat': 17.3850, 'lon': 78.4867, 'risk': 'MODERATE', 'danger_level': 8.0,  'warning_level': 6.5  },
    { 'city': 'Warangal',      'state': 'Telangana', 'river': 'Godavari',  'lat': 17.9689, 'lon': 79.5941, 'risk': 'HIGH',     'danger_level': 11.0, 'warning_level': 9.0  },
    { 'city': 'Nalgonda',      'state': 'Telangana', 'river': 'Krishna',   'lat': 17.0575, 'lon': 79.2678, 'risk': 'MODERATE', 'danger_level': 9.5,  'warning_level': 8.0  },
    // ── Tripura ──────────────────────────────────────────────────────────────
    { 'city': 'Agartala',      'state': 'Tripura', 'river': 'Haora',     'lat': 23.8315, 'lon': 91.2868, 'risk': 'HIGH',     'danger_level': 9.5,  'warning_level': 8.0  },
    // ── Uttar Pradesh ────────────────────────────────────────────────────────
    { 'city': 'Varanasi',      'state': 'Uttar Pradesh', 'river': 'Ganga',   'lat': 25.3176, 'lon': 82.9739, 'risk': 'HIGH',     'danger_level': 73.90, 'warning_level': 71.26 },
    { 'city': 'Allahabad',     'state': 'Uttar Pradesh', 'river': 'Yamuna',  'lat': 25.4358, 'lon': 81.8463, 'risk': 'HIGH',     'danger_level': 86.80, 'warning_level': 84.73 },
    { 'city': 'Lucknow',       'state': 'Uttar Pradesh', 'river': 'Gomti',   'lat': 26.8467, 'lon': 80.9462, 'risk': 'MODERATE', 'danger_level': 108.00,'warning_level': 106.50 },
    { 'city': 'Agra',          'state': 'Uttar Pradesh', 'river': 'Yamuna',  'lat': 27.1767, 'lon': 78.0081, 'risk': 'MODERATE', 'danger_level': 167.00,'warning_level': 165.50 },
    { 'city': 'Kanpur',        'state': 'Uttar Pradesh', 'river': 'Ganga',   'lat': 26.4499, 'lon': 80.3319, 'risk': 'HIGH',     'danger_level': 113.50,'warning_level': 111.88 },
    { 'city': 'Bareilly',      'state': 'Uttar Pradesh', 'river': 'Ramganga','lat': 28.3670, 'lon': 79.4304, 'risk': 'MODERATE', 'danger_level': 170.00,'warning_level': 168.00 },
    { 'city': 'Gorakhpur',     'state': 'Uttar Pradesh', 'river': 'Rapti',   'lat': 26.7606, 'lon': 83.3732, 'risk': 'HIGH',     'danger_level': 75.00, 'warning_level': 73.00 },
    { 'city': 'Bahraich',      'state': 'Uttar Pradesh', 'river': 'Ghaghra', 'lat': 27.5740, 'lon': 81.5940, 'risk': 'HIGH',     'danger_level': 120.00,'warning_level': 118.00 },
    // ── Uttarakhand ──────────────────────────────────────────────────────────
    { 'city': 'Haridwar',      'state': 'Uttarakhand', 'river': 'Ganga',   'lat': 29.9457, 'lon': 78.1642, 'risk': 'HIGH',     'danger_level': 295.00,'warning_level': 293.50 },
    { 'city': 'Dehradun',      'state': 'Uttarakhand', 'river': 'Song',    'lat': 30.3165, 'lon': 78.0322, 'risk': 'LOW',      'danger_level': 9.0,   'warning_level': 7.5   },
    { 'city': 'Rishikesh',     'state': 'Uttarakhand', 'river': 'Ganga',   'lat': 30.0869, 'lon': 78.2676, 'risk': 'HIGH',     'danger_level': 340.00,'warning_level': 338.00 },
    // ── West Bengal ──────────────────────────────────────────────────────────
    { 'city': 'Kolkata',       'state': 'West Bengal', 'river': 'Hooghly',   'lat': 22.5726, 'lon': 88.3639, 'risk': 'HIGH',     'danger_level': 6.5,  'warning_level': 5.5  },
    { 'city': 'Siliguri',      'state': 'West Bengal', 'river': 'Teesta',    'lat': 26.7271, 'lon': 88.3953, 'risk': 'HIGH',     'danger_level': 12.0, 'warning_level': 10.0 },
    { 'city': 'Asansol',       'state': 'West Bengal', 'river': 'Damodar',   'lat': 23.6888, 'lon': 86.9661, 'risk': 'MODERATE', 'danger_level': 9.0,  'warning_level': 7.5  },
    { 'city': 'Malda',         'state': 'West Bengal', 'river': 'Ganga',     'lat': 25.0108, 'lon': 88.1418, 'risk': 'HIGH',     'danger_level': 27.00, 'warning_level': 25.50 },
    { 'city': 'Jalpaiguri',    'state': 'West Bengal', 'river': 'Teesta',    'lat': 26.5196, 'lon': 88.7290, 'risk': 'HIGH',     'danger_level': 11.5, 'warning_level': 9.5  },
    { 'city': 'Murshidabad',   'state': 'West Bengal', 'river': 'Bhagirathi','lat': 24.1800, 'lon': 88.2700, 'risk': 'HIGH',     'danger_level': 24.00, 'warning_level': 22.00 },
    // ── Delhi NCT ────────────────────────────────────────────────────────────
    { 'city': 'New Delhi',     'state': 'Delhi', 'river': 'Yamuna',     'lat': 28.6139, 'lon': 77.2090, 'risk': 'HIGH',     'danger_level': 205.33,'warning_level': 204.50 },
    // ── Jammu & Kashmir ──────────────────────────────────────────────────────
    { 'city': 'Srinagar',      'state': 'Jammu & Kashmir', 'river': 'Jhelum', 'lat': 34.0837, 'lon': 74.7973, 'risk': 'HIGH',     'danger_level': 18.0, 'warning_level': 15.5 },
    { 'city': 'Jammu',         'state': 'Jammu & Kashmir', 'river': 'Tawi',   'lat': 32.7266, 'lon': 74.8570, 'risk': 'MODERATE', 'danger_level': 11.0, 'warning_level': 9.0  },
    // ── Ladakh ───────────────────────────────────────────────────────────────
    { 'city': 'Leh',           'state': 'Ladakh', 'river': 'Indus',     'lat': 34.1526, 'lon': 77.5770, 'risk': 'LOW',      'danger_level': 10.0, 'warning_level': 8.0  },
  ];

  // ─── Alert thresholds (% capacity) ───────────────────────────────────────
  static const double criticalThreshold = 85.0;
  static const double highThreshold     = 70.0;
  static const double moderateThreshold = 50.0;
  static const double lowThreshold      = 30.0;

  // ─── Polling / retry ─────────────────────────────────────────────────────
  static const Duration pollingInterval = Duration(seconds: 45);
  static const int      maxRetries      = 3;

  // ─── Default river gauge levels (metres, CWC HMS scale) ──────────────────
  // Used only in FloodData.fromMonitoredCity() when no backend data available.
  static const double defaultDangerLevel  = 10.0;
  static const double defaultWarningLevel =  8.0;
  static const double defaultSafeLevel    =  5.0;

  // ─── Animation durations ─────────────────────────────────────────────────
  static const Duration shortAnimDuration  = Duration(milliseconds: 220);
  static const Duration mediumAnimDuration = Duration(milliseconds: 320);
  static const Duration longAnimDuration   = Duration(milliseconds: 600);

  // ─── Notification channels ────────────────────────────────────────────────
  static const String criticalAlertChannelId   = 'flood_critical';
  static const String criticalAlertChannelName = 'Critical Flood Alerts';
  static const String warningAlertChannelId    = 'flood_warning';
  static const String warningAlertChannelName  = 'Flood Warnings';

  // ─── Indian states + UTs ─────────────────────────────────────────────────
  static const List<String> indianStates = [
    'All India',
    'Andhra Pradesh', 'Arunachal Pradesh', 'Assam', 'Bihar',
    'Chhattisgarh', 'Goa', 'Gujarat', 'Haryana',
    'Himachal Pradesh', 'Jharkhand', 'Karnataka', 'Kerala',
    'Madhya Pradesh', 'Maharashtra', 'Manipur', 'Meghalaya',
    'Mizoram', 'Nagaland', 'Odisha', 'Punjab',
    'Rajasthan', 'Sikkim', 'Tamil Nadu', 'Telangana',
    'Tripura', 'Uttar Pradesh', 'Uttarakhand', 'West Bengal',
    'Delhi', 'Jammu & Kashmir', 'Ladakh',
  ];
}
