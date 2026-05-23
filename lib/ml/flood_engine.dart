// OpsFlood ML Engine — Dart port of backend/app.py + state_severity_matrix.py
//
// Mirrors:
//   complex_predict_flood()       — ensemble blend
//   fallback_prediction()         — heuristic path
//   severity_from_entry()         — dual-axis scoring
//   danger_level_override_guard() — Option-A CWC guard
//   risk_score formula            — identical weight map
//   STATE_SEVERITY_MATRIX         — all 36 states + UTs
//
// FIXES (v1.1):
//   1. Delhi uses absolute MSL elevation — added usesAbsoluteElevation flag;
//      peakFloodLevelM for Delhi must be in MSL metres (e.g. 205.4).
//   2. Unknown-state fallback now returns a safe PLAINS generic entry
//      instead of Maharashtra thresholds.
//   3. Rule engine probability distribution is right-skewed (under-predict
//      is worse than over-predict for disaster systems).
//   4. Duration, timeToPeak, recessionTime features now contribute to
//      combinedScore in on-device path.

class FloodInput {
  final double peakFloodLevelM;
  final double eventDurationDays;
  final double timeToPeakDays;
  final double recessionTimeDay;
  final double t1d, t2d, t3d, t4d, t5d, t6d, t7d;
  final String state;
  final String? station;

  const FloodInput({
    required this.peakFloodLevelM,
    required this.eventDurationDays,
    required this.timeToPeakDays,
    required this.recessionTimeDay,
    required this.t1d,
    required this.t2d,
    required this.t3d,
    required this.t4d,
    required this.t5d,
    required this.t6d,
    required this.t7d,
    required this.state,
    this.station,
  });

  // Exact feature order from EXPECTED_FEATURE_COLUMNS in app.py
  List<double> toFeatureVector() => [
        peakFloodLevelM,
        eventDurationDays,
        timeToPeakDays,
        recessionTimeDay,
        t1d, t2d, t3d, t4d, t5d, t6d, t7d,
      ];

  double get rainfall7d => t1d + t2d + t3d + t4d + t5d + t6d + t7d;
}

class FloodResult {
  final String severity; // LOW / MODERATE / SEVERE / CRITICAL
  final double confidencePercent;
  final Map<String, double> probabilities; // label -> 0..100
  final int riskScore; // 0..100
  final double proximityToDangerM;
  final String algorithm;
  final String alert;
  final String monitoringLevel;
  final String monitoringAction;
  final bool usedApi;
  final bool isOfflineEstimate; // FIX-1: always true for on-device path
  final Map<String, double> ruleProbs;
  final Map<String, double> mlProbs;
  final String thresholdSeverity;

  const FloodResult({
    required this.severity,
    required this.confidencePercent,
    required this.probabilities,
    required this.riskScore,
    required this.proximityToDangerM,
    required this.algorithm,
    required this.alert,
    required this.monitoringLevel,
    required this.monitoringAction,
    required this.usedApi,
    required this.isOfflineEstimate,
    required this.ruleProbs,
    required this.mlProbs,
    required this.thresholdSeverity,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// SEVERITY CONSTANTS
// ─────────────────────────────────────────────────────────────────────────────
const _severityOrder = {'LOW': 0, 'MODERATE': 1, 'SEVERE': 2, 'CRITICAL': 3};

// CLASS_LABEL_MAP from app.py
const Map<int, String> classLabelMap = {
  0: 'LOW',
  1: 'MODERATE',
  2: 'SEVERE',
  3: 'CRITICAL',
};

// risk_weights from complex_predict_flood()
const Map<String, double> riskWeights = {
  'LOW': 16,
  'MODERATE': 46,
  'SEVERE': 78,
  'CRITICAL': 96,
};

// ─────────────────────────────────────────────────────────────────────────────
// REGION RAINFALL THRESHOLDS
// Mirrors REGION_RAINFALL_THRESHOLDS in state_severity_matrix.py
// ─────────────────────────────────────────────────────────────────────────────
const Map<String, Map<String, double>> regionRainfallThresholds = {
  'PLAINS':    {'moderate': 150.0, 'severe': 300.0, 'critical': 450.0},
  'COASTAL':   {'moderate': 200.0, 'severe': 400.0, 'critical': 600.0},
  'HIMALAYAN': {'moderate': 150.0, 'severe': 300.0, 'critical': 500.0},
  'NORTHEAST': {'moderate': 200.0, 'severe': 400.0, 'critical': 600.0},
  'ARID':      {'moderate': 100.0, 'severe': 200.0, 'critical': 350.0},
  'ISLAND':    {'moderate': 200.0, 'severe': 400.0, 'critical': 600.0},
  'URBAN_UT':  {'moderate': 100.0, 'severe': 200.0, 'critical': 350.0},
};

Map<String, double> getRegionRainfallThresholds(String region) =>
    regionRainfallThresholds[region.toUpperCase()] ??
    regionRainfallThresholds['PLAINS']!;

// ─────────────────────────────────────────────────────────────────────────────
// STATE SEVERITY MATRIX  (ported from state_severity_matrix.py)
// Keys normalised to lowercase for lookup
// ─────────────────────────────────────────────────────────────────────────────
class StateEntry {
  final String region;
  final Map<String, double> peakLevelM; // moderate/severe/critical
  final Map<String, double> rainfall7dMm; // moderate/severe/critical  (from region)
  final double dangerLevelM;
  final double warningLevelM;
  final double hflM;
  final List<String> primaryRivers;
  final List<String> vulnerableDistricts;
  // FIX-1: Delhi and some stations report level as MSL elevation, not depth
  final bool usesAbsoluteElevation;

  const StateEntry({
    required this.region,
    required this.peakLevelM,
    required this.rainfall7dMm,
    required this.dangerLevelM,
    required this.warningLevelM,
    required this.hflM,
    required this.primaryRivers,
    required this.vulnerableDistricts,
    this.usesAbsoluteElevation = false,
  });
}

// Derives rainfall thresholds from region
StateEntry _entry({
  required String region,
  required Map<String, double> peak,
  required double danger,
  required double warning,
  required double hfl,
  List<String> rivers = const [],
  List<String> districts = const [],
  bool absoluteElevation = false,
}) {
  return StateEntry(
    region: region,
    peakLevelM: peak,
    rainfall7dMm: getRegionRainfallThresholds(region),
    dangerLevelM: danger,
    warningLevelM: warning,
    hflM: hfl,
    primaryRivers: rivers,
    vulnerableDistricts: districts,
    usesAbsoluteElevation: absoluteElevation,
  );
}

// FIX-2: Safe generic fallback for unknown states uses PLAINS defaults
// instead of silently mapping to Maharashtra thresholds.
final StateEntry _unknownStateFallback = _entry(
  region: 'PLAINS',
  peak: {'moderate': 8.5, 'severe': 11.0, 'critical': 13.0},
  danger: 11.0, warning: 9.0, hfl: 13.5,
  rivers: [],
  districts: [],
);

final Map<String, StateEntry> stateSeverityMatrix = {
  'maharashtra': _entry(
    region: 'COASTAL',
    peak: {'moderate': 9.0, 'severe': 11.5, 'critical': 13.0},
    danger: 11.5, warning: 9.5, hfl: 14.2,
    rivers: ['Krishna', 'Godavari', 'Bhima', 'Koyna', 'Panchganga'],
    districts: ['Kolhapur', 'Sangli', 'Satara', 'Pune', 'Nashik'],
  ),
  'kerala': _entry(
    region: 'COASTAL',
    peak: {'moderate': 8.5, 'severe': 11.0, 'critical': 13.5},
    danger: 11.0, warning: 9.0, hfl: 14.5,
    rivers: ['Periyar', 'Pampa', 'Bharathapuzha', 'Chaliyar'],
    districts: ['Ernakulam', 'Thrissur', 'Pathanamthitta', 'Idukki', 'Alappuzha'],
  ),
  'assam': _entry(
    region: 'NORTHEAST',
    peak: {'moderate': 8.0, 'severe': 10.5, 'critical': 12.5},
    danger: 10.5, warning: 8.5, hfl: 13.2,
    rivers: ['Brahmaputra', 'Barak', 'Subansiri', 'Dhansiri'],
    districts: ['Kamrup', 'Dhubri', 'Goalpara', 'Barpeta', 'Morigaon'],
  ),
  'bihar': _entry(
    region: 'PLAINS',
    peak: {'moderate': 9.0, 'severe': 11.5, 'critical': 13.5},
    danger: 11.5, warning: 9.2, hfl: 14.0,
    rivers: ['Gandak', 'Kosi', 'Bagmati', 'Kamla', 'Mahananda'],
    districts: ['Darbhanga', 'Sitamarhi', 'Muzaffarpur', 'Supaul', 'Madhubani'],
  ),
  'uttar pradesh': _entry(
    region: 'PLAINS',
    peak: {'moderate': 8.5, 'severe': 11.0, 'critical': 13.0},
    danger: 11.0, warning: 9.0, hfl: 13.8,
    rivers: ['Ganga', 'Yamuna', 'Ghaghra', 'Rapti', 'Sharda'],
    districts: ['Varanasi', 'Allahabad', 'Ballia', 'Gonda', 'Bahraich'],
  ),
  'odisha': _entry(
    region: 'COASTAL',
    peak: {'moderate': 9.5, 'severe': 12.0, 'critical': 14.0},
    danger: 12.0, warning: 10.0, hfl: 14.8,
    rivers: ['Mahanadi', 'Baitarani', 'Brahmani', 'Subarnarekha'],
    districts: ['Puri', 'Kendrapara', 'Bhadrak', 'Balasore', 'Jagatsinghpur'],
  ),
  'west bengal': _entry(
    region: 'COASTAL',
    peak: {'moderate': 8.5, 'severe': 11.0, 'critical': 13.0},
    danger: 11.0, warning: 9.0, hfl: 13.5,
    rivers: ['Ganga', 'Damodar', 'Ajay', 'Mayurakshi', 'Teesta'],
    districts: ['Murshidabad', 'Malda', 'Cooch Behar', 'South 24 Parganas'],
  ),
  'andhra pradesh': _entry(
    region: 'COASTAL',
    peak: {'moderate': 9.0, 'severe': 11.5, 'critical': 13.5},
    danger: 11.5, warning: 9.5, hfl: 14.0,
    rivers: ['Krishna', 'Godavari', 'Tungabhadra', 'Penna'],
    districts: ['East Godavari', 'West Godavari', 'Krishna', 'Guntur'],
  ),
  'telangana': _entry(
    region: 'PLAINS',
    peak: {'moderate': 9.0, 'severe': 11.5, 'critical': 13.0},
    danger: 11.5, warning: 9.5, hfl: 13.8,
    rivers: ['Godavari', 'Krishna', 'Manjira', 'Musi'],
    districts: ['Khammam', 'Warangal', 'Nizamabad', 'Karimnagar'],
  ),
  'karnataka': _entry(
    region: 'COASTAL',
    peak: {'moderate': 9.0, 'severe': 11.5, 'critical': 13.5},
    danger: 11.5, warning: 9.5, hfl: 14.2,
    rivers: ['Cauvery', 'Krishna', 'Tungabhadra', 'Kabini', 'Sharavathi'],
    districts: ['Kodagu', 'Hassan', 'Dakshina Kannada', 'Raichur'],
  ),
  'tamil nadu': _entry(
    region: 'COASTAL',
    peak: {'moderate': 8.5, 'severe': 11.0, 'critical': 13.0},
    danger: 11.0, warning: 9.0, hfl: 13.8,
    rivers: ['Cauvery', 'Vaigai', 'Tamiraparani', 'Palar'],
    districts: ['Chennai', 'Cuddalore', 'Nagapattinam', 'Thanjavur'],
  ),
  'gujarat': _entry(
    region: 'ARID',
    peak: {'moderate': 7.5, 'severe': 10.0, 'critical': 12.0},
    danger: 10.0, warning: 8.0, hfl: 12.5,
    rivers: ['Narmada', 'Tapti', 'Sabarmati', 'Mahi', 'Banas'],
    districts: ['Vadodara', 'Bharuch', 'Anand', 'Kheda', 'Gandhinagar'],
  ),
  'rajasthan': _entry(
    region: 'ARID',
    peak: {'moderate': 6.0, 'severe': 8.5, 'critical': 11.0},
    danger: 8.5, warning: 6.5, hfl: 11.5,
    rivers: ['Chambal', 'Luni', 'Banas', 'Mahi'],
    districts: ['Barmer', 'Jalore', 'Pali', 'Sikar', 'Alwar'],
  ),
  'madhya pradesh': _entry(
    region: 'PLAINS',
    peak: {'moderate': 8.5, 'severe': 11.0, 'critical': 13.0},
    danger: 11.0, warning: 9.0, hfl: 13.5,
    rivers: ['Narmada', 'Chambal', 'Tapti', 'Betwa', 'Sone'],
    districts: ['Gwalior', 'Morena', 'Bhind', 'Jabalpur', 'Hoshangabad'],
  ),
  'chhattisgarh': _entry(
    region: 'PLAINS',
    peak: {'moderate': 8.5, 'severe': 11.0, 'critical': 13.0},
    danger: 11.0, warning: 9.0, hfl: 13.5,
    rivers: ['Mahanadi', 'Sheonath', 'Indravati', 'Jonk'],
    districts: ['Raipur', 'Rajnandgaon', 'Dhamtari', 'Kanker'],
  ),
  'jharkhand': _entry(
    region: 'PLAINS',
    peak: {'moderate': 8.5, 'severe': 11.0, 'critical': 13.0},
    danger: 11.0, warning: 9.0, hfl: 13.5,
    rivers: ['Subarnarekha', 'Damodar', 'Koel', 'Sankh'],
    districts: ['Sahebganj', 'Pakur', 'Godda', 'Dumka'],
  ),
  'uttarakhand': _entry(
    region: 'HIMALAYAN',
    peak: {'moderate': 8.0, 'severe': 10.5, 'critical': 12.5},
    danger: 10.5, warning: 8.5, hfl: 13.0,
    rivers: ['Ganga', 'Yamuna', 'Alaknanda', 'Mandakini', 'Tons'],
    districts: ['Haridwar', 'Dehradun', 'Rishikesh', 'Chamoli', 'Rudraprayag'],
  ),
  'himachal pradesh': _entry(
    region: 'HIMALAYAN',
    peak: {'moderate': 7.5, 'severe': 10.0, 'critical': 12.0},
    danger: 10.0, warning: 8.0, hfl: 12.5,
    rivers: ['Beas', 'Sutlej', 'Ravi', 'Chenab'],
    districts: ['Mandi', 'Kullu', 'Kangra', 'Solan'],
  ),
  'jammu and kashmir': _entry(
    region: 'HIMALAYAN',
    peak: {'moderate': 7.0, 'severe': 9.5, 'critical': 11.5},
    danger: 9.5, warning: 7.5, hfl: 12.0,
    rivers: ['Jhelum', 'Chenab', 'Tawi'],
    districts: ['Srinagar', 'Anantnag', 'Jammu', 'Poonch'],
  ),
  'punjab': _entry(
    region: 'PLAINS',
    peak: {'moderate': 8.5, 'severe': 11.0, 'critical': 13.0},
    danger: 11.0, warning: 9.0, hfl: 13.5,
    rivers: ['Sutlej', 'Beas', 'Ravi', 'Ghaggar'],
    districts: ['Jalandhar', 'Ludhiana', 'Gurdaspur', 'Hoshiarpur'],
  ),
  'haryana': _entry(
    region: 'PLAINS',
    peak: {'moderate': 8.0, 'severe': 10.5, 'critical': 12.5},
    danger: 10.5, warning: 8.5, hfl: 13.0,
    rivers: ['Yamuna', 'Ghaggar', 'Saraswati'],
    districts: ['Kurukshetra', 'Ambala', 'Yamunanagar', 'Karnal'],
  ),
  // FIX-1: Delhi uses Yamuna MSL elevation (204–207m). Flag explicitly.
  'delhi': _entry(
    region: 'URBAN_UT',
    peak: {'moderate': 204.0, 'severe': 205.5, 'critical': 206.5},
    danger: 205.33, warning: 204.5, hfl: 207.49,
    rivers: ['Yamuna'],
    districts: ['East Delhi', 'North Delhi', 'South Delhi'],
    absoluteElevation: true,
  ),
  'meghalaya': _entry(
    region: 'NORTHEAST',
    peak: {'moderate': 8.0, 'severe': 10.5, 'critical': 12.5},
    danger: 10.5, warning: 8.5, hfl: 13.0,
    rivers: ['Umkhrah', 'Umiam', 'Kopili'],
    districts: ['East Khasi Hills', 'Ri Bhoi', 'West Garo Hills'],
  ),
  'manipur': _entry(
    region: 'NORTHEAST',
    peak: {'moderate': 7.5, 'severe': 10.0, 'critical': 12.0},
    danger: 10.0, warning: 8.0, hfl: 12.5,
    rivers: ['Imphal', 'Iril', 'Thoubal'],
    districts: ['Imphal West', 'Bishnupur', 'Chandel'],
  ),
  'mizoram': _entry(
    region: 'NORTHEAST',
    peak: {'moderate': 98.0, 'severe': 110.0, 'critical': 118.0},
    danger: 112.0, warning: 100.0, hfl: 121.0,
    rivers: ['Tlawng', 'Tuirial', 'Chhimtuipui'],
    districts: ['Aizawl', 'Lunglei', 'Champhai'],
    absoluteElevation: true,
  ),
  'nagaland': _entry(
    region: 'NORTHEAST',
    peak: {'moderate': 7.5, 'severe': 10.0, 'critical': 12.0},
    danger: 10.0, warning: 8.0, hfl: 12.5,
    rivers: ['Dhansiri', 'Doyang', 'Tizu'],
    districts: ['Dimapur', 'Peren', 'Wokha'],
  ),
  'tripura': _entry(
    region: 'NORTHEAST',
    peak: {'moderate': 7.5, 'severe': 10.0, 'critical': 12.0},
    danger: 10.0, warning: 8.0, hfl: 12.5,
    rivers: ['Gomati', 'Haora', 'Khowai'],
    districts: ['West Tripura', 'Sepahijala', 'Gomati'],
  ),
  'arunachal pradesh': _entry(
    region: 'HIMALAYAN',
    peak: {'moderate': 8.0, 'severe': 10.5, 'critical': 12.5},
    danger: 10.5, warning: 8.5, hfl: 13.0,
    rivers: ['Siang', 'Subansiri', 'Kameng', 'Lohit'],
    districts: ['East Siang', 'Lower Dibang', 'Lohit', 'Papum Pare'],
  ),
  'sikkim': _entry(
    region: 'HIMALAYAN',
    peak: {'moderate': 6.0, 'severe': 8.5, 'critical': 10.5},
    danger: 8.5, warning: 6.5, hfl: 11.0,
    rivers: ['Teesta', 'Rangit', 'Rangpo'],
    districts: ['East Sikkim', 'South Sikkim', 'West Sikkim'],
  ),
  'goa': _entry(
    region: 'COASTAL',
    peak: {'moderate': 8.5, 'severe': 11.0, 'critical': 13.0},
    danger: 11.0, warning: 9.0, hfl: 13.5,
    rivers: ['Mandovi', 'Zuari', 'Sal'],
    districts: ['North Goa', 'South Goa'],
  ),
  // Missing states added in v1.1
  'ladakh': _entry(
    region: 'HIMALAYAN',
    peak: {'moderate': 5.0, 'severe': 7.5, 'critical': 10.0},
    danger: 7.5, warning: 5.5, hfl: 10.5,
    rivers: ['Indus', 'Shyok', 'Zanskar'],
    districts: ['Leh', 'Kargil'],
  ),
  'dadra and nagar haveli': _entry(
    region: 'COASTAL',
    peak: {'moderate': 8.0, 'severe': 10.5, 'critical': 12.5},
    danger: 10.5, warning: 8.5, hfl: 13.0,
    rivers: ['Damanganga'],
    districts: ['Dadra and Nagar Haveli'],
  ),
  'daman and diu': _entry(
    region: 'COASTAL',
    peak: {'moderate': 7.5, 'severe': 10.0, 'critical': 12.0},
    danger: 10.0, warning: 8.0, hfl: 12.5,
    rivers: ['Damanganga'],
    districts: ['Daman', 'Diu'],
  ),
  // UTs
  'chandigarh': _entry(
    region: 'URBAN_UT',
    peak: {'moderate': 7.5, 'severe': 9.5, 'critical': 11.5},
    danger: 9.5, warning: 7.5, hfl: 12.0,
    rivers: ['Ghaggar', 'Sukhna'],
    districts: ['Chandigarh'],
  ),
  'andaman and nicobar': _entry(
    region: 'ISLAND',
    peak: {'moderate': 8.5, 'severe': 11.0, 'critical': 13.0},
    danger: 11.0, warning: 9.0, hfl: 13.5,
    rivers: ['Andaman', 'Nicobar Streams'],
    districts: ['South Andaman', 'North and Middle Andaman'],
  ),
  'lakshadweep': _entry(
    region: 'ISLAND',
    peak: {'moderate': 6.0, 'severe': 8.0, 'critical': 10.0},
    danger: 8.0, warning: 6.0, hfl: 10.5,
    rivers: [],
    districts: ['Kavaratti'],
  ),
  'puducherry': _entry(
    region: 'COASTAL',
    peak: {'moderate': 8.0, 'severe': 10.5, 'critical': 12.5},
    danger: 10.5, warning: 8.5, hfl: 13.0,
    rivers: ['Gingee', 'Malattar'],
    districts: ['Puducherry', 'Karaikal'],
  ),
};

StateEntry getStateEntry(String state) {
  final key = state.trim().toLowerCase();
  final normalized = <String, String>{
    'orissa': 'odisha',
    'nct of delhi': 'delhi',
    'new delhi': 'delhi',
    'j&k': 'jammu and kashmir',
    'j & k': 'jammu and kashmir',
    'uttaranchal': 'uttarakhand',
    'dnhdd': 'dadra and nagar haveli',
  }[key] ?? key;
  // FIX-2: safe PLAINS fallback instead of Maharashtra
  return stateSeverityMatrix[normalized] ?? _unknownStateFallback;
}

// ─────────────────────────────────────────────────────────────────────────────
// OPTION-A GUARD — mirrors danger_level_override_guard() in state_severity_matrix.py
// ─────────────────────────────────────────────────────────────────────────────
String _dangerLevelGuard({
  required String severity,
  required double riverLevelM,
  required double rainfall7dMm,
  required StateEntry entry,
}) {
  final warnM = entry.warningLevelM;
  final dangerM = entry.dangerLevelM;
  final hflM = entry.hflM;

  if (warnM <= 0 || dangerM <= 0) return severity;

  final regionT = getRegionRainfallThresholds(entry.region);

  if (riverLevelM >= hflM) {
    return severity;
  } else if (riverLevelM >= dangerM) {
    if (severity == 'CRITICAL') return 'SEVERE';
    return severity;
  } else if (riverLevelM >= warnM) {
    return severity;
  } else {
    if (rainfall7dMm >= regionT['severe']!) return severity;
    if (severity == 'SEVERE' || severity == 'CRITICAL') return 'MODERATE';
    return severity;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DUAL-AXIS SEVERITY — mirrors severity_from_entry() in state_severity_matrix.py
// ─────────────────────────────────────────────────────────────────────────────
String severityFromEntry({
  required double peakLevelM,
  required double rainfall7dMm,
  required StateEntry entry,
  double? riverLevelM,
}) {
  final p = entry.peakLevelM;
  final r = entry.rainfall7dMm;

  String depthSev;
  if (peakLevelM >= p['critical']!) {
    depthSev = 'CRITICAL';
  } else if (peakLevelM >= p['severe']!) {
    depthSev = 'SEVERE';
  } else if (peakLevelM >= p['moderate']!) {
    depthSev = 'MODERATE';
  } else {
    depthSev = 'LOW';
  }

  String rainSev;
  if (rainfall7dMm >= r['critical']!) {
    rainSev = 'CRITICAL';
  } else if (rainfall7dMm >= r['severe']!) {
    rainSev = 'SEVERE';
  } else if (rainfall7dMm >= r['moderate']!) {
    rainSev = 'MODERATE';
  } else {
    rainSev = 'LOW';
  }

  final rawSev = (_severityOrder[depthSev]! >= _severityOrder[rainSev]!)
      ? depthSev
      : rainSev;

  if (riverLevelM != null) {
    return _dangerLevelGuard(
      severity: rawSev,
      riverLevelM: riverLevelM,
      rainfall7dMm: rainfall7dMm,
      entry: entry,
    );
  }
  return rawSev;
}

// ─────────────────────────────────────────────────────────────────────────────
// RULE ENGINE — FIX-3: right-skewed distribution
// Under-predicting a flood is worse than over-predicting.
// Weights are asymmetric: higher-severity neighbours get more mass.
// ─────────────────────────────────────────────────────────────────────────────
Map<String, double> _ruleEngineProbMap(String thresholdSev) {
  final rank = _severityOrder[thresholdSev]!;
  final all = ['LOW', 'MODERATE', 'SEVERE', 'CRITICAL'];
  final probs = <String, double>{};
  double total = 0;
  for (final label in all) {
    final diff = _severityOrder[label]! - rank; // positive = higher severity
    double w;
    if (diff == 0) {
      w = 0.60; // anchor class
    } else if (diff == 1) {
      w = 0.25; // one step above — higher weight (right-skew)
    } else if (diff == -1) {
      w = 0.10; // one step below — lower weight
    } else if (diff > 1) {
      w = 0.04; // two+ steps above
    } else {
      w = 0.01; // two+ steps below
    }
    probs[label] = w;
    total += w;
  }
  return {for (final e in probs.entries) e.key: e.value / total};
}

// ─────────────────────────────────────────────────────────────────────────────
// HEURISTIC ON-DEVICE ENGINE
// FIX-4: Duration, timeToPeak, and recessionTime now contribute to score.
// ─────────────────────────────────────────────────────────────────────────────
FloodResult runOnDeviceEngine(FloodInput input) {
  final entry = getStateEntry(input.state);
  final rainfall7d = input.rainfall7d;

  // --- Threshold severity (rule engine axis) ---
  final thresholdSev = severityFromEntry(
    peakLevelM: input.peakFloodLevelM,
    rainfall7dMm: rainfall7d,
    entry: entry,
  );

  // --- Peak level score ---
  final critP = entry.peakLevelM['critical']!;
  final sevP = entry.peakLevelM['severe']!;
  final modP = entry.peakLevelM['moderate']!;

  double peakScore;
  if (input.peakFloodLevelM >= critP) {
    peakScore = 1.0;
  } else if (input.peakFloodLevelM >= sevP) {
    peakScore = 0.67 + 0.33 * ((input.peakFloodLevelM - sevP) / (critP - sevP));
  } else if (input.peakFloodLevelM >= modP) {
    peakScore = 0.33 + 0.34 * ((input.peakFloodLevelM - modP) / (sevP - modP));
  } else {
    peakScore = 0.33 * (input.peakFloodLevelM / modP).clamp(0, 1);
  }

  // --- Rainfall score ---
  final rainT = getRegionRainfallThresholds(entry.region);
  double rainScore;
  if (rainfall7d >= rainT['critical']!) {
    rainScore = 1.0;
  } else if (rainfall7d >= rainT['severe']!) {
    rainScore = 0.67 + 0.33 * ((rainfall7d - rainT['severe']!) / (rainT['critical']! - rainT['severe']!));
  } else if (rainfall7d >= rainT['moderate']!) {
    rainScore = 0.33 + 0.34 * ((rainfall7d - rainT['moderate']!) / (rainT['severe']! - rainT['moderate']!));
  } else {
    rainScore = 0.33 * (rainfall7d / rainT['moderate']!).clamp(0, 1);
  }

  // --- FIX-4: Temporal feature score ---
  // Long duration + fast rise + slow recession = higher risk
  // Each sub-score 0..1, blended with 10% total weight
  final durationScore = (input.eventDurationDays / 14.0).clamp(0.0, 1.0);
  final riseScore = input.timeToPeakDays > 0
      ? (1.0 - (input.timeToPeakDays / 7.0).clamp(0.0, 1.0)) // faster rise = higher score
      : 0.0;
  final recessionScore = (input.recessionTimeDay / 10.0).clamp(0.0, 1.0); // slower recession = higher score
  final temporalScore = (durationScore * 0.4 + riseScore * 0.35 + recessionScore * 0.25)
      .clamp(0.0, 1.0);

  // Weighted combination: peak=52%, rain=38%, temporal=10%
  final combinedScore =
      (peakScore * 0.52 + rainScore * 0.38 + temporalScore * 0.10).clamp(0.0, 1.0);

  // Map combinedScore to 4-class probability vector
  final mlRank = (combinedScore * 3.0).clamp(0.0, 3.0);
  final mlProbs = <String, double>{};
  double mlTotal = 0;
  for (final label in ['LOW', 'MODERATE', 'SEVERE', 'CRITICAL']) {
    final dist = (_severityOrder[label]! - mlRank).abs();
    final w = (dist < 0.5) ? 0.65 : (dist < 1.5) ? 0.25 : (dist < 2.5) ? 0.08 : 0.02;
    mlProbs[label] = w;
    mlTotal += w;
  }
  final normMlProbs = {for (final e in mlProbs.entries) e.key: e.value / mlTotal};

  // --- Rule engine probs ---
  final ruleProbs = _ruleEngineProbMap(thresholdSev);

  // --- Blend: ML=0.75, rule=0.25 ---
  const mlW = 0.75;
  const ruleW = 0.25;
  final finalProbs = <String, double>{};
  for (final label in ['LOW', 'MODERATE', 'SEVERE', 'CRITICAL']) {
    finalProbs[label] =
        (normMlProbs[label]! * mlW) + (ruleProbs[label]! * ruleW);
  }

  double fTotal = finalProbs.values.fold(0, (a, b) => a + b);
  final normFinal = {for (final e in finalProbs.entries) e.key: e.value / fTotal};

  String severity =
      normFinal.entries.reduce((a, b) => a.value > b.value ? a : b).key;

  // Safety suppression: below warning level → cap at MODERATE
  final warnM = entry.warningLevelM;
  if (warnM > 0 &&
      input.peakFloodLevelM < warnM &&
      (severity == 'SEVERE' || severity == 'CRITICAL')) {
    normFinal['SEVERE'] = 0.0;
    normFinal['CRITICAL'] = 0.0;
    double s2 = normFinal.values.fold(0, (a, b) => a + b);
    for (final k in normFinal.keys) {
      normFinal[k] = s2 > 0 ? normFinal[k]! / s2 : 0;
    }
    severity = normFinal.entries.reduce((a, b) => a.value > b.value ? a : b).key;
  }

  final confidence = (normFinal[severity]! * 100).roundToDouble();

  double rs = 0;
  for (final label in ['LOW', 'MODERATE', 'SEVERE', 'CRITICAL']) {
    rs += normFinal[label]! * riskWeights[label]!;
  }
  final riskScore = rs.round().clamp(0, 100);

  final proximityToDanger = entry.dangerLevelM - input.peakFloodLevelM;

  final String alert;
  if (severity == 'CRITICAL' || severity == 'SEVERE') {
    alert = '🚨';
  } else if (severity == 'MODERATE') {
    alert = '⚠️';
  } else {
    alert = '🟢';
  }

  final monitoring = _monitoringAdvice(severity, riskScore);

  return FloodResult(
    severity: severity,
    confidencePercent: confidence,
    probabilities: {for (final e in normFinal.entries) e.key: e.value * 100},
    riskScore: riskScore,
    proximityToDangerM: proximityToDanger,
    algorithm: 'On-Device Heuristic Ensemble v1.1 (OpsFlood port)',
    alert: alert,
    monitoringLevel: monitoring['level']!,
    monitoringAction: monitoring['action']!,
    usedApi: false,
    isOfflineEstimate: true,
    ruleProbs: {for (final e in ruleProbs.entries) e.key: e.value * 100},
    mlProbs: {for (final e in normMlProbs.entries) e.key: e.value * 100},
    thresholdSeverity: thresholdSev,
  );
}

Map<String, String> _monitoringAdvice(String severity, int riskScore) {
  switch (severity) {
    case 'CRITICAL':
      return {
        'level': 'CRITICAL',
        'action': 'Immediate evacuation. Contact NDRF. Activate emergency protocol.',
      };
    case 'SEVERE':
      return {
        'level': 'HIGH ALERT',
        'action': 'Alert district administration. Prepare evacuation routes. 4-hour monitoring.',
      };
    case 'MODERATE':
      return {
        'level': 'WATCH',
        'action': 'Monitor river levels every 6 hours. Pre-position rescue teams.',
      };
    default:
      return {
        'level': 'NORMAL',
        'action': 'Standard monitoring. Review 7-day forecast daily.',
      };
  }
}
