class AppConstants {
  static const String baseUrl       = 'https://opsflood.onrender.com';
  static const String backupBaseUrl = 'https://opsflood-backend.onrender.com';

  static const String healthEndpoint        = '/health';
  static const String liveTelemetryEndpoint = '/api/live-telemetry';
  static const String liveLevelsEndpoint    = '/api/live-levels';
  static const String criticalAlertsEndpoint= '/api/critical-alerts';
  static const String predictLegacyEndpoint = '/predict/legacy';
  static const String weatherCurrentEndpoint= '/weather/current';
  static const String weatherForecastEndpoint= '/weather/forecast';

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

  // ─── India-wide river stations (state → city → river) ───────────────────
  // Data sourced from CWC / India-WRIS HMS stations
  static const List<Map<String, dynamic>> monitoredCities = [
    // Andhra Pradesh
    { 'city': 'Vijayawada',   'state': 'Andhra Pradesh', 'river': 'Krishna',     'lat': 16.5062, 'lon': 80.6480,  'risk': 'HIGH' },
    { 'city': 'Rajahmundry',  'state': 'Andhra Pradesh', 'river': 'Godavari',    'lat': 17.0005, 'lon': 81.8040,  'risk': 'HIGH' },
    { 'city': 'Kurnool',      'state': 'Andhra Pradesh', 'river': 'Tungabhadra', 'lat': 15.8281, 'lon': 78.0373,  'risk': 'MODERATE' },
    // Arunachal Pradesh
    { 'city': 'Pasighat',     'state': 'Arunachal Pradesh', 'river': 'Brahmaputra', 'lat': 28.0660, 'lon': 95.3280, 'risk': 'HIGH' },
    { 'city': 'Itanagar',     'state': 'Arunachal Pradesh', 'river': 'Dikrong',     'lat': 27.0844, 'lon': 93.6053, 'risk': 'MODERATE' },
    // Assam
    { 'city': 'Guwahati',     'state': 'Assam', 'river': 'Brahmaputra', 'lat': 26.1445, 'lon': 91.7362, 'risk': 'HIGH' },
    { 'city': 'Dibrugarh',    'state': 'Assam', 'river': 'Brahmaputra', 'lat': 27.4728, 'lon': 94.9120, 'risk': 'HIGH' },
    { 'city': 'Silchar',      'state': 'Assam', 'river': 'Barak',       'lat': 24.8333, 'lon': 92.7789, 'risk': 'MODERATE' },
    { 'city': 'Jorhat',       'state': 'Assam', 'river': 'Brahmaputra', 'lat': 26.7465, 'lon': 94.2026, 'risk': 'MODERATE' },
    // Bihar
    { 'city': 'Patna',        'state': 'Bihar', 'river': 'Ganga',    'lat': 25.5941, 'lon': 85.1376, 'risk': 'HIGH' },
    { 'city': 'Bhagalpur',    'state': 'Bihar', 'river': 'Ganga',    'lat': 25.2425, 'lon': 86.9842, 'risk': 'HIGH' },
    { 'city': 'Muzaffarpur',  'state': 'Bihar', 'river': 'Gandak',   'lat': 26.1209, 'lon': 85.3647, 'risk': 'MODERATE' },
    { 'city': 'Darbhanga',    'state': 'Bihar', 'river': 'Bagmati',  'lat': 26.1542, 'lon': 85.8918, 'risk': 'HIGH' },
    // Chhattisgarh
    { 'city': 'Raipur',       'state': 'Chhattisgarh', 'river': 'Mahanadi', 'lat': 21.2514, 'lon': 81.6296, 'risk': 'MODERATE' },
    { 'city': 'Bilaspur',     'state': 'Chhattisgarh', 'river': 'Arpa',     'lat': 22.0797, 'lon': 82.1409, 'risk': 'LOW' },
    // Goa
    { 'city': 'Panaji',       'state': 'Goa', 'river': 'Mandovi', 'lat': 15.4909, 'lon': 73.8278, 'risk': 'LOW' },
    // Gujarat
    { 'city': 'Vadodara',     'state': 'Gujarat', 'river': 'Vishwamitri', 'lat': 22.3072, 'lon': 73.1812, 'risk': 'MODERATE' },
    { 'city': 'Surat',        'state': 'Gujarat', 'river': 'Tapi',        'lat': 21.1702, 'lon': 72.8311, 'risk': 'MODERATE' },
    { 'city': 'Ahmedabad',    'state': 'Gujarat', 'river': 'Sabarmati',   'lat': 23.0225, 'lon': 72.5714, 'risk': 'LOW' },
    { 'city': 'Rajkot',       'state': 'Gujarat', 'river': 'Aji',         'lat': 22.3039, 'lon': 70.8022, 'risk': 'LOW' },
    // Haryana
    { 'city': 'Ambala',       'state': 'Haryana', 'river': 'Ghaggar',  'lat': 30.3782, 'lon': 76.7767, 'risk': 'MODERATE' },
    { 'city': 'Hisar',        'state': 'Haryana', 'river': 'Ghaggar',  'lat': 29.1492, 'lon': 75.7217, 'risk': 'LOW' },
    // Himachal Pradesh
    { 'city': 'Mandi',        'state': 'Himachal Pradesh', 'river': 'Beas',    'lat': 31.7080, 'lon': 76.9318, 'risk': 'MODERATE' },
    { 'city': 'Bilaspur',     'state': 'Himachal Pradesh', 'river': 'Sutlej',  'lat': 31.3260, 'lon': 76.7605, 'risk': 'LOW' },
    // Jharkhand
    { 'city': 'Ranchi',       'state': 'Jharkhand', 'river': 'Subarnarekha', 'lat': 23.3441, 'lon': 85.3096, 'risk': 'LOW' },
    { 'city': 'Dhanbad',      'state': 'Jharkhand', 'river': 'Damodar',      'lat': 23.7957, 'lon': 86.4304, 'risk': 'MODERATE' },
    // Karnataka
    { 'city': 'Bengaluru',    'state': 'Karnataka', 'river': 'Vrishabhavathi','lat': 12.9716, 'lon': 77.5946, 'risk': 'LOW' },
    { 'city': 'Mysuru',       'state': 'Karnataka', 'river': 'Kaveri',        'lat': 12.2958, 'lon': 76.6394, 'risk': 'MODERATE' },
    { 'city': 'Mangaluru',    'state': 'Karnataka', 'river': 'Netravati',     'lat': 12.9141, 'lon': 74.8560, 'risk': 'MODERATE' },
    { 'city': 'Belagavi',     'state': 'Karnataka', 'river': 'Malaprabha',    'lat': 15.8497, 'lon': 74.4977, 'risk': 'MODERATE' },
    // Kerala
    { 'city': 'Kochi',        'state': 'Kerala', 'river': 'Periyar',      'lat': 9.9312,  'lon': 76.2673, 'risk': 'HIGH' },
    { 'city': 'Thiruvananthapuram','state':'Kerala','river':'Karamana',   'lat': 8.5241,  'lon': 76.9366, 'risk': 'LOW' },
    { 'city': 'Kozhikode',    'state': 'Kerala', 'river': 'Chaliyar',     'lat': 11.2588, 'lon': 75.7804, 'risk': 'MODERATE' },
    { 'city': 'Thrissur',     'state': 'Kerala', 'river': 'Chalakudy',    'lat': 10.5276, 'lon': 76.2144, 'risk': 'MODERATE' },
    { 'city': 'Alappuzha',    'state': 'Kerala', 'river': 'Pamba',        'lat': 9.4981,  'lon': 76.3388, 'risk': 'HIGH' },
    // Madhya Pradesh
    { 'city': 'Jabalpur',     'state': 'Madhya Pradesh', 'river': 'Narmada',  'lat': 23.1815, 'lon': 79.9864, 'risk': 'MODERATE' },
    { 'city': 'Bhopal',       'state': 'Madhya Pradesh', 'river': 'Betwa',    'lat': 23.2599, 'lon': 77.4126, 'risk': 'LOW' },
    { 'city': 'Gwalior',      'state': 'Madhya Pradesh', 'river': 'Chambal',  'lat': 26.2183, 'lon': 78.1828, 'risk': 'LOW' },
    { 'city': 'Indore',       'state': 'Madhya Pradesh', 'river': 'Kshipra',  'lat': 22.7196, 'lon': 75.8577, 'risk': 'LOW' },
    // Maharashtra
    { 'city': 'Mumbai',       'state': 'Maharashtra', 'river': 'Mithi',      'lat': 19.0760, 'lon': 72.8777, 'risk': 'MODERATE' },
    { 'city': 'Pune',         'state': 'Maharashtra', 'river': 'Mula-Mutha', 'lat': 18.5204, 'lon': 73.8567, 'risk': 'MODERATE' },
    { 'city': 'Nashik',       'state': 'Maharashtra', 'river': 'Godavari',   'lat': 19.9975, 'lon': 73.7898, 'risk': 'MODERATE' },
    { 'city': 'Kolhapur',     'state': 'Maharashtra', 'river': 'Panchganga', 'lat': 16.7050, 'lon': 74.2433, 'risk': 'HIGH' },
    { 'city': 'Sangli',       'state': 'Maharashtra', 'river': 'Krishna',    'lat': 16.8524, 'lon': 74.5815, 'risk': 'HIGH' },
    { 'city': 'Nagpur',       'state': 'Maharashtra', 'river': 'Nag',        'lat': 21.1458, 'lon': 79.0882, 'risk': 'LOW' },
    // Manipur
    { 'city': 'Imphal',       'state': 'Manipur', 'river': 'Imphal', 'lat': 24.8170, 'lon': 93.9368, 'risk': 'MODERATE' },
    // Meghalaya
    { 'city': 'Shillong',     'state': 'Meghalaya', 'river': 'Umiam', 'lat': 25.5788, 'lon': 91.8933, 'risk': 'LOW' },
    // Mizoram
    { 'city': 'Aizawl',       'state': 'Mizoram', 'river': 'Tlawng', 'lat': 23.7307, 'lon': 92.7173, 'risk': 'LOW' },
    // Nagaland
    { 'city': 'Dimapur',      'state': 'Nagaland', 'river': 'Dhansiri', 'lat': 25.9044, 'lon': 93.7272, 'risk': 'LOW' },
    // Odisha
    { 'city': 'Bhubaneswar',  'state': 'Odisha', 'river': 'Mahanadi',   'lat': 20.2961, 'lon': 85.8245, 'risk': 'MODERATE' },
    { 'city': 'Cuttack',      'state': 'Odisha', 'river': 'Mahanadi',   'lat': 20.4625, 'lon': 85.8828, 'risk': 'HIGH' },
    { 'city': 'Sambalpur',    'state': 'Odisha', 'river': 'Mahanadi',   'lat': 21.4669, 'lon': 83.9812, 'risk': 'MODERATE' },
    // Punjab
    { 'city': 'Ludhiana',     'state': 'Punjab', 'river': 'Sutlej',  'lat': 30.9009, 'lon': 75.8573, 'risk': 'MODERATE' },
    { 'city': 'Amritsar',     'state': 'Punjab', 'river': 'Ravi',    'lat': 31.6340, 'lon': 74.8723, 'risk': 'LOW' },
    { 'city': 'Pathankot',    'state': 'Punjab', 'river': 'Ravi',    'lat': 32.2744, 'lon': 75.6522, 'risk': 'MODERATE' },
    // Rajasthan
    { 'city': 'Kota',         'state': 'Rajasthan', 'river': 'Chambal',   'lat': 25.2138, 'lon': 75.8648, 'risk': 'MODERATE' },
    { 'city': 'Jaipur',       'state': 'Rajasthan', 'river': 'Banas',     'lat': 26.9124, 'lon': 75.7873, 'risk': 'LOW' },
    // Sikkim
    { 'city': 'Gangtok',      'state': 'Sikkim', 'river': 'Teesta', 'lat': 27.3314, 'lon': 88.6138, 'risk': 'MODERATE' },
    // Tamil Nadu
    { 'city': 'Chennai',      'state': 'Tamil Nadu', 'river': 'Adyar',       'lat': 13.0827, 'lon': 80.2707, 'risk': 'MODERATE' },
    { 'city': 'Tiruchirappalli','state':'Tamil Nadu','river':'Kaveri',       'lat': 10.7905, 'lon': 78.7047, 'risk': 'MODERATE' },
    { 'city': 'Coimbatore',   'state': 'Tamil Nadu', 'river': 'Noyyal',      'lat': 11.0168, 'lon': 76.9558, 'risk': 'LOW' },
    { 'city': 'Madurai',      'state': 'Tamil Nadu', 'river': 'Vaigai',      'lat': 9.9252,  'lon': 78.1198, 'risk': 'LOW' },
    // Telangana
    { 'city': 'Hyderabad',    'state': 'Telangana', 'river': 'Musi',      'lat': 17.3850, 'lon': 78.4867, 'risk': 'MODERATE' },
    { 'city': 'Warangal',     'state': 'Telangana', 'river': 'Godavari',  'lat': 17.9689, 'lon': 79.5941, 'risk': 'MODERATE' },
    // Tripura
    { 'city': 'Agartala',     'state': 'Tripura', 'river': 'Haora', 'lat': 23.8315, 'lon': 91.2868, 'risk': 'MODERATE' },
    // Uttar Pradesh
    { 'city': 'Varanasi',     'state': 'Uttar Pradesh', 'river': 'Ganga',   'lat': 25.3176, 'lon': 82.9739, 'risk': 'MODERATE' },
    { 'city': 'Allahabad',    'state': 'Uttar Pradesh', 'river': 'Yamuna',  'lat': 25.4358, 'lon': 81.8463, 'risk': 'MODERATE' },
    { 'city': 'Lucknow',      'state': 'Uttar Pradesh', 'river': 'Gomti',   'lat': 26.8467, 'lon': 80.9462, 'risk': 'MODERATE' },
    { 'city': 'Agra',         'state': 'Uttar Pradesh', 'river': 'Yamuna',  'lat': 27.1767, 'lon': 78.0081, 'risk': 'LOW' },
    { 'city': 'Kanpur',       'state': 'Uttar Pradesh', 'river': 'Ganga',   'lat': 26.4499, 'lon': 80.3319, 'risk': 'MODERATE' },
    { 'city': 'Bareilly',     'state': 'Uttar Pradesh', 'river': 'Ramganga','lat': 28.3670, 'lon': 79.4304, 'risk': 'LOW' },
    // Uttarakhand
    { 'city': 'Haridwar',     'state': 'Uttarakhand', 'river': 'Ganga',    'lat': 29.9457, 'lon': 78.1642, 'risk': 'MODERATE' },
    { 'city': 'Dehradun',     'state': 'Uttarakhand', 'river': 'Song',     'lat': 30.3165, 'lon': 78.0322, 'risk': 'LOW' },
    { 'city': 'Rishikesh',    'state': 'Uttarakhand', 'river': 'Ganga',    'lat': 30.0869, 'lon': 78.2676, 'risk': 'MODERATE' },
    // West Bengal
    { 'city': 'Kolkata',      'state': 'West Bengal', 'river': 'Hooghly',  'lat': 22.5726, 'lon': 88.3639, 'risk': 'MODERATE' },
    { 'city': 'Siliguri',     'state': 'West Bengal', 'river': 'Teesta',   'lat': 26.7271, 'lon': 88.3953, 'risk': 'HIGH' },
    { 'city': 'Asansol',      'state': 'West Bengal', 'river': 'Damodar',  'lat': 23.6888, 'lon': 86.9661, 'risk': 'MODERATE' },
    // Delhi NCT
    { 'city': 'New Delhi',    'state': 'Delhi', 'river': 'Yamuna', 'lat': 28.6139, 'lon': 77.2090, 'risk': 'MODERATE' },
    // Jammu & Kashmir
    { 'city': 'Srinagar',     'state': 'Jammu & Kashmir', 'river': 'Jhelum', 'lat': 34.0837, 'lon': 74.7973, 'risk': 'HIGH' },
    { 'city': 'Jammu',        'state': 'Jammu & Kashmir', 'river': 'Tawi',   'lat': 32.7266, 'lon': 74.8570, 'risk': 'MODERATE' },
    // Ladakh
    { 'city': 'Leh',          'state': 'Ladakh', 'river': 'Indus', 'lat': 34.1526, 'lon': 77.5770, 'risk': 'LOW' },
  ];

  static const double criticalThreshold = 85.0;
  static const double highThreshold     = 70.0;
  static const double moderateThreshold = 50.0;
  static const double lowThreshold      = 30.0;

  static const Duration pollingInterval = Duration(seconds: 30);
  static const int maxRetries = 3;

  static const double defaultDangerLevel  = 3.0;
  static const double defaultWarningLevel = 2.5;
  static const double defaultSafeLevel    = 1.5;

  static const Duration shortAnimDuration  = Duration(milliseconds: 220);
  static const Duration mediumAnimDuration = Duration(milliseconds: 320);
  static const Duration longAnimDuration   = Duration(milliseconds: 600);

  static const String criticalAlertChannelId   = 'flood_critical';
  static const String criticalAlertChannelName = 'Critical Flood Alerts';
  static const String warningAlertChannelId    = 'flood_warning';
  static const String warningAlertChannelName  = 'Flood Warnings';

  // All 28 states + 8 UTs (display names)
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
