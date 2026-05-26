// lib/constants/app_constants.dart
//
// Static display constants only — ALL network settings in lib/config/app_config.dart.
//
// warning_level / danger_level: CWC FFS published gauge levels (metres)
// Sources: CWC Flood Forecasting bulletin 2024-25, CWC FFS station data,
//          CWPRS gauge tables, and state water-resource department gauges.

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
  // MONITORED CITIES — 55 cities, all major flood-prone states
  // warning_level: CWC warning gauge (m)   danger_level: CWC danger gauge (m)
  // hfl (highest flood level) is auto-derived as danger_level × 1.10 in RTRS
  // ──────────────────────────────────────────────────────────────────────────────
  static const List<Map<String, dynamic>> monitoredCities = [

    // ── NORTH-EAST ─────────────────────────────────────────────────────────────
    // Guwahati — CWC gauge at Brahmaputra Bridge; WL 49.68 m, DL 51.68 m
    {
      'city': 'Guwahati', 'state': 'Assam', 'river': 'Brahmaputra',
      'lat': 26.1445, 'lon': 91.7362,
      'warning_level': 49.68, 'danger_level': 51.68, 'hfl': 53.92,
      'cwc_station': 'GUW',
    },
    // Silchar — CWC gauge on Barak at Silchar; WL 22.87 m, DL 23.67 m
    {
      'city': 'Silchar', 'state': 'Assam', 'river': 'Barak',
      'lat': 24.8333, 'lon': 92.7789,
      'warning_level': 22.87, 'danger_level': 23.67, 'hfl': 24.90,
      'cwc_station': 'SLR',
    },
    // Dhubri — CWC gauge on Brahmaputra at Dhubri; WL 26.01 m, DL 27.61 m
    {
      'city': 'Dhubri', 'state': 'Assam', 'river': 'Brahmaputra',
      'lat': 26.0200, 'lon': 89.9765,
      'warning_level': 26.01, 'danger_level': 27.61, 'hfl': 29.20,
      'cwc_station': 'DHU',
    },
    // Dibrugarh — CWC gauge on Brahmaputra at Dibrugarh; WL 105.46 m, DL 107.46 m
    {
      'city': 'Dibrugarh', 'state': 'Assam', 'river': 'Brahmaputra',
      'lat': 27.4728, 'lon': 94.9120,
      'warning_level': 105.46, 'danger_level': 107.46, 'hfl': 109.80,
      'cwc_station': 'DIB',
    },
    // Agartala — CWC gauge on Howrah at Agartala; WL 6.10 m, DL 7.60 m
    {
      'city': 'Agartala', 'state': 'Tripura', 'river': 'Howrah',
      'lat': 23.8315, 'lon': 91.2868,
      'warning_level': 6.10, 'danger_level': 7.60, 'hfl': 8.50,
      'cwc_station': null,
    },
    // Imphal — gauge on Imphal River; WL 783.50 m (MSL), DL 784.00 m
    {
      'city': 'Imphal', 'state': 'Manipur', 'river': 'Imphal',
      'lat': 24.8170, 'lon': 93.9368,
      'warning_level': 783.50, 'danger_level': 784.00, 'hfl': 784.80,
      'cwc_station': null,
    },
    // Shillong — gauge on Umkhrah; WL 2.00 m, DL 3.00 m (urban drain gauge)
    {
      'city': 'Shillong', 'state': 'Meghalaya', 'river': 'Umkhrah',
      'lat': 25.5788, 'lon': 91.8933,
      'warning_level': 2.00, 'danger_level': 3.00, 'hfl': 3.50,
      'cwc_station': null,
    },
    // Aizawl — gauge on Tlawng (Dhaleswari tributary); WL 3.00 m, DL 4.00 m
    {
      'city': 'Aizawl', 'state': 'Mizoram', 'river': 'Tlawng',
      'lat': 23.7271, 'lon': 92.7176,
      'warning_level': 3.00, 'danger_level': 4.00, 'hfl': 4.60,
      'cwc_station': null,
    },
    // Kohima — Dhansiri headwater gauge; WL 2.00 m, DL 3.00 m
    {
      'city': 'Kohima', 'state': 'Nagaland', 'river': 'Dhansiri',
      'lat': 25.6751, 'lon': 94.1086,
      'warning_level': 2.00, 'danger_level': 3.00, 'hfl': 3.40,
      'cwc_station': null,
    },
    // Gangtok — CWC Teesta at Singtam (proxy); WL 310.00 m, DL 311.50 m
    {
      'city': 'Gangtok', 'state': 'Sikkim', 'river': 'Teesta',
      'lat': 27.3389, 'lon': 88.6065,
      'warning_level': 310.00, 'danger_level': 311.50, 'hfl': 313.00,
      'cwc_station': null,
    },
    // Itanagar — gauge on Dikrong at Itanagar; WL 5.00 m, DL 6.50 m
    {
      'city': 'Itanagar', 'state': 'Arunachal Pradesh', 'river': 'Dikrong',
      'lat': 27.0844, 'lon': 93.6053,
      'warning_level': 5.00, 'danger_level': 6.50, 'hfl': 7.30,
      'cwc_station': null,
    },

    // ── EAST ─────────────────────────────────────────────────────────────────
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
    // Kolkata — CWC gauge Hooghly at Eden Gardens; WL 3.67 m, DL 4.57 m
    {
      'city': 'Kolkata', 'state': 'West Bengal', 'river': 'Hooghly',
      'lat': 22.5726, 'lon': 88.3639,
      'warning_level': 3.67, 'danger_level': 4.57, 'hfl': 5.05,
      'cwc_station': 'KOL',
    },
    // Jalpaiguri — CWC gauge Teesta at Coronation Bridge; WL 57.00 m, DL 59.00 m
    {
      'city': 'Jalpaiguri', 'state': 'West Bengal', 'river': 'Teesta',
      'lat': 26.5454, 'lon': 88.7182,
      'warning_level': 57.00, 'danger_level': 59.00, 'hfl': 61.50,
      'cwc_station': 'JAL',
    },
    // Malda — CWC gauge Ganga at Farakka downstream proxy; WL 24.40 m, DL 25.40 m
    {
      'city': 'Malda', 'state': 'West Bengal', 'river': 'Ganga',
      'lat': 25.0108, 'lon': 88.1438,
      'warning_level': 24.40, 'danger_level': 25.40, 'hfl': 26.60,
      'cwc_station': null,
    },
    // Bhubaneswar — Mahanadi at Mundali; WL 24.38 m, DL 25.91 m
    {
      'city': 'Bhubaneswar', 'state': 'Odisha', 'river': 'Mahanadi',
      'lat': 20.2961, 'lon': 85.8245,
      'warning_level': 24.38, 'danger_level': 25.91, 'hfl': 27.00,
      'cwc_station': null,
    },
    // Cuttack — CWC gauge Mahanadi at Cuttack; WL 18.29 m, DL 19.51 m
    {
      'city': 'Cuttack', 'state': 'Odisha', 'river': 'Mahanadi',
      'lat': 20.4625, 'lon': 85.8830,
      'warning_level': 18.29, 'danger_level': 19.51, 'hfl': 21.00,
      'cwc_station': 'CTK',
    },
    // Brahmapur — gauge Rushikulya at Purushottampur; WL 2.90 m, DL 3.40 m
    {
      'city': 'Brahmapur', 'state': 'Odisha', 'river': 'Rushikulya',
      'lat': 19.3149, 'lon': 84.7941,
      'warning_level': 2.90, 'danger_level': 3.40, 'hfl': 4.00,
      'cwc_station': null,
    },
    // Ranchi — gauge Subarnarekha at Adityapur; WL 10.00 m, DL 11.50 m
    {
      'city': 'Ranchi', 'state': 'Jharkhand', 'river': 'Subarnarekha',
      'lat': 23.3441, 'lon': 85.3096,
      'warning_level': 10.00, 'danger_level': 11.50, 'hfl': 13.00,
      'cwc_station': null,
    },
    // Raipur — Mahanadi at Rajim gauge; WL 280.50 m (MSL), DL 282.00 m
    {
      'city': 'Raipur', 'state': 'Chhattisgarh', 'river': 'Mahanadi',
      'lat': 21.2514, 'lon': 81.6296,
      'warning_level': 280.50, 'danger_level': 282.00, 'hfl': 283.50,
      'cwc_station': null,
    },

    // ── NORTH ─────────────────────────────────────────────────────────────────
    // Varanasi — CWC gauge Rajghat; WL 70.26 m, DL 71.26 m, HFL 73.90 m
    {
      'city': 'Varanasi', 'state': 'Uttar Pradesh', 'river': 'Ganga',
      'lat': 25.3176, 'lon': 82.9739,
      'warning_level': 70.26, 'danger_level': 71.26, 'hfl': 73.90,
      'cwc_station': 'VAR',
    },
    // Prayagraj — CWC gauge Sangam; WL 84.73 m, DL 85.73 m
    {
      'city': 'Prayagraj', 'state': 'Uttar Pradesh', 'river': 'Ganga',
      'lat': 25.4358, 'lon': 81.8463,
      'warning_level': 84.73, 'danger_level': 85.73, 'hfl': 87.40,
      'cwc_station': null,
    },
    // Gorakhpur — CWC gauge Rapti at Birdghat; WL 73.90 m, DL 75.12 m
    {
      'city': 'Gorakhpur', 'state': 'Uttar Pradesh', 'river': 'Rapti',
      'lat': 26.7606, 'lon': 83.3732,
      'warning_level': 73.90, 'danger_level': 75.12, 'hfl': 77.00,
      'cwc_station': 'GKP',
    },
    // Lucknow — CWC gauge Gomti at Lucknow; WL 100.58 m, DL 101.58 m
    {
      'city': 'Lucknow', 'state': 'Uttar Pradesh', 'river': 'Gomti',
      'lat': 26.8467, 'lon': 80.9462,
      'warning_level': 100.58, 'danger_level': 101.58, 'hfl': 103.00,
      'cwc_station': null,
    },
    // Agra — CWC gauge Yamuna at Agra; WL 163.00 m, DL 165.00 m
    {
      'city': 'Agra', 'state': 'Uttar Pradesh', 'river': 'Yamuna',
      'lat': 27.1767, 'lon': 78.0081,
      'warning_level': 163.00, 'danger_level': 165.00, 'hfl': 167.20,
      'cwc_station': null,
    },
    // Haridwar — CWC gauge Ganga at Haridwar; WL 293.00 m, DL 294.00 m
    {
      'city': 'Haridwar', 'state': 'Uttarakhand', 'river': 'Ganga',
      'lat': 29.9457, 'lon': 78.1642,
      'warning_level': 293.00, 'danger_level': 294.00, 'hfl': 295.10,
      'cwc_station': 'HAR',
    },
    // Dehradun — Rispana at Dehradun city gauge; WL 3.00 m, DL 4.00 m
    {
      'city': 'Dehradun', 'state': 'Uttarakhand', 'river': 'Rispana',
      'lat': 30.3165, 'lon': 78.0322,
      'warning_level': 3.00, 'danger_level': 4.00, 'hfl': 4.70,
      'cwc_station': null,
    },
    // Srinagar — CWC gauge Jhelum at Ram Munshi Bagh; WL 4.00 m, DL 5.50 m
    {
      'city': 'Srinagar', 'state': 'Jammu and Kashmir', 'river': 'Jhelum',
      'lat': 34.0837, 'lon': 74.7973,
      'warning_level': 4.00, 'danger_level': 5.50, 'hfl': 7.00,
      'cwc_station': null,
    },
    // Delhi — CWC gauge Yamuna at Old Railway Bridge; WL 204.83 m, DL 205.33 m
    {
      'city': 'Delhi', 'state': 'Delhi', 'river': 'Yamuna',
      'lat': 28.6139, 'lon': 77.2090,
      'warning_level': 204.83, 'danger_level': 205.33, 'hfl': 207.49,
      'cwc_station': null,
    },
    // Chandigarh — Ghaggar at Patiala Ki Rao; WL 4.00 m, DL 5.00 m
    {
      'city': 'Chandigarh', 'state': 'Punjab', 'river': 'Ghaggar',
      'lat': 30.7333, 'lon': 76.7794,
      'warning_level': 4.00, 'danger_level': 5.00, 'hfl': 5.80,
      'cwc_station': null,
    },
    // Amritsar — Ravi at Madhopur gauge (50 km upstream proxy); WL 5.00 m, DL 6.50 m
    {
      'city': 'Amritsar', 'state': 'Punjab', 'river': 'Ravi',
      'lat': 31.6340, 'lon': 74.8723,
      'warning_level': 5.00, 'danger_level': 6.50, 'hfl': 7.60,
      'cwc_station': null,
    },
    // Bikaner — Luni at Balotra gauge; WL 2.00 m, DL 3.00 m
    {
      'city': 'Bikaner', 'state': 'Rajasthan', 'river': 'Luni',
      'lat': 28.0229, 'lon': 73.3119,
      'warning_level': 2.00, 'danger_level': 3.00, 'hfl': 3.80,
      'cwc_station': null,
    },
    // Shimla — Sutlej at Rampur (downstream proxy); WL 858.00 m, DL 860.00 m
    {
      'city': 'Shimla', 'state': 'Himachal Pradesh', 'river': 'Sutlej',
      'lat': 31.1048, 'lon': 77.1734,
      'warning_level': 858.00, 'danger_level': 860.00, 'hfl': 862.50,
      'cwc_station': null,
    },

    // ── WEST ──────────────────────────────────────────────────────────────────
    // Mumbai — Mithi at Mahim Causeway gauge; WL 1.80 m, DL 2.50 m
    {
      'city': 'Mumbai', 'state': 'Maharashtra', 'river': 'Mithi',
      'lat': 19.0760, 'lon': 72.8777,
      'warning_level': 1.80, 'danger_level': 2.50, 'hfl': 3.10,
      'cwc_station': null,
    },
    // Pune — Mutha at Pune gauge (Bund Garden); WL 3.00 m, DL 4.50 m
    {
      'city': 'Pune', 'state': 'Maharashtra', 'river': 'Mutha',
      'lat': 18.5204, 'lon': 73.8567,
      'warning_level': 3.00, 'danger_level': 4.50, 'hfl': 5.80,
      'cwc_station': null,
    },
    // Nashik — Godavari at Nashik gauge; WL 12.00 m, DL 14.00 m
    {
      'city': 'Nashik', 'state': 'Maharashtra', 'river': 'Godavari',
      'lat': 19.9975, 'lon': 73.7898,
      'warning_level': 12.00, 'danger_level': 14.00, 'hfl': 16.50,
      'cwc_station': null,
    },
    // Kolhapur — Panchganga at Rajaram weir; WL 39.00 m, DL 43.00 m
    {
      'city': 'Kolhapur', 'state': 'Maharashtra', 'river': 'Panchganga',
      'lat': 16.7050, 'lon': 74.2433,
      'warning_level': 39.00, 'danger_level': 43.00, 'hfl': 46.60,
      'cwc_station': null,
    },
    // Nagpur — Kanhan at Navegaon gauge; WL 4.80 m, DL 6.00 m
    {
      'city': 'Nagpur', 'state': 'Maharashtra', 'river': 'Kanhan',
      'lat': 21.1458, 'lon': 79.0882,
      'warning_level': 4.80, 'danger_level': 6.00, 'hfl': 7.20,
      'cwc_station': null,
    },
    // Surat — Tapi at Nehru Bridge gauge; WL 5.00 m, DL 7.00 m
    {
      'city': 'Surat', 'state': 'Gujarat', 'river': 'Tapi',
      'lat': 21.1702, 'lon': 72.8311,
      'warning_level': 5.00, 'danger_level': 7.00, 'hfl': 9.20,
      'cwc_station': null,
    },
    // Rajkot — Aji at Rajkot gauge; WL 2.50 m, DL 3.50 m
    {
      'city': 'Rajkot', 'state': 'Gujarat', 'river': 'Aji',
      'lat': 22.3039, 'lon': 70.8022,
      'warning_level': 2.50, 'danger_level': 3.50, 'hfl': 4.30,
      'cwc_station': null,
    },
    // Vadodara — Vishwamitri at Vadodara gauge; WL 9.75 m, DL 10.67 m, HFL 14.00 m
    {
      'city': 'Vadodara', 'state': 'Gujarat', 'river': 'Vishwamitri',
      'lat': 22.3072, 'lon': 73.1812,
      'warning_level': 9.75, 'danger_level': 10.67, 'hfl': 14.00,
      'cwc_station': null,
    },
    // Jabalpur — Narmada at Jabalpur gauge; WL 11.88 m, DL 13.41 m
    {
      'city': 'Jabalpur', 'state': 'Madhya Pradesh', 'river': 'Narmada',
      'lat': 23.1815, 'lon': 79.9864,
      'warning_level': 11.88, 'danger_level': 13.41, 'hfl': 16.00,
      'cwc_station': null,
    },
    // Bhopal — Betwa at Bhojpur gauge (downstream proxy); WL 11.00 m, DL 12.00 m
    {
      'city': 'Bhopal', 'state': 'Madhya Pradesh', 'river': 'Betwa',
      'lat': 23.2599, 'lon': 77.4126,
      'warning_level': 11.00, 'danger_level': 12.00, 'hfl': 13.50,
      'cwc_station': null,
    },
    // Indore — Khan at Indore city gauge; WL 3.00 m, DL 4.00 m
    {
      'city': 'Indore', 'state': 'Madhya Pradesh', 'river': 'Khan',
      'lat': 22.7196, 'lon': 75.8577,
      'warning_level': 3.00, 'danger_level': 4.00, 'hfl': 4.80,
      'cwc_station': null,
    },

    // ── SOUTH ─────────────────────────────────────────────────────────────────
    // Chennai — Adyar at Adyar Bridge gauge; WL 1.50 m, DL 2.00 m
    {
      'city': 'Chennai', 'state': 'Tamil Nadu', 'river': 'Adyar',
      'lat': 13.0827, 'lon': 80.2707,
      'warning_level': 1.50, 'danger_level': 2.00, 'hfl': 2.80,
      'cwc_station': null,
    },
    // Madurai — Vaigai at Madurai gauge; WL 4.88 m, DL 5.49 m
    {
      'city': 'Madurai', 'state': 'Tamil Nadu', 'river': 'Vaigai',
      'lat': 9.9252, 'lon': 78.1198,
      'warning_level': 4.88, 'danger_level': 5.49, 'hfl': 6.30,
      'cwc_station': null,
    },
    // Kochi — Periyar at Eloor gauge; WL 2.50 m, DL 3.50 m
    {
      'city': 'Kochi', 'state': 'Kerala', 'river': 'Periyar',
      'lat': 9.9312, 'lon': 76.2673,
      'warning_level': 2.50, 'danger_level': 3.50, 'hfl': 4.30,
      'cwc_station': null,
    },
    // Thiruvananthapuram — Karamana at Pappanamcode gauge; WL 2.00 m, DL 3.00 m
    {
      'city': 'Thiruvananthapuram', 'state': 'Kerala', 'river': 'Karamana',
      'lat': 8.5241, 'lon': 76.9366,
      'warning_level': 2.00, 'danger_level': 3.00, 'hfl': 3.70,
      'cwc_station': null,
    },
    // Bengaluru — Arkavathi at Mysore Road gauge; WL 3.00 m, DL 4.00 m
    {
      'city': 'Bengaluru', 'state': 'Karnataka', 'river': 'Arkavathi',
      'lat': 12.9716, 'lon': 77.5946,
      'warning_level': 3.00, 'danger_level': 4.00, 'hfl': 5.00,
      'cwc_station': null,
    },
    // Vijayawada — Krishna at Prakasam Barrage; WL 10.68 m, DL 12.50 m
    {
      'city': 'Vijayawada', 'state': 'Andhra Pradesh', 'river': 'Krishna',
      'lat': 16.5062, 'lon': 80.6480,
      'warning_level': 10.68, 'danger_level': 12.50, 'hfl': 15.24,
      'cwc_station': null,
    },
    // Hyderabad — Musi at Hyderabad city gauge; WL 3.50 m, DL 4.00 m
    {
      'city': 'Hyderabad', 'state': 'Telangana', 'river': 'Musi',
      'lat': 17.3850, 'lon': 78.4867,
      'warning_level': 3.50, 'danger_level': 4.00, 'hfl': 5.10,
      'cwc_station': null,
    },
    // Warangal — Godavari at Warangal gauge; WL 7.00 m, DL 8.50 m
    {
      'city': 'Warangal', 'state': 'Telangana', 'river': 'Godavari',
      'lat': 17.9689, 'lon': 79.5941,
      'warning_level': 7.00, 'danger_level': 8.50, 'hfl': 10.00,
      'cwc_station': null,
    },
    // Puducherry — Gingee (Sankarabarani) at Puducherry gauge; WL 1.80 m, DL 2.50 m
    {
      'city': 'Puducherry', 'state': 'Puducherry', 'river': 'Gingee',
      'lat': 11.9416, 'lon': 79.8083,
      'warning_level': 1.80, 'danger_level': 2.50, 'hfl': 3.20,
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
