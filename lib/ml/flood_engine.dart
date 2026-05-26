// OpsFlood ML Engine — Dart port of backend/app.py + state_severity_matrix.py
//
// Mirrors:
//   complex_predict_flood()       — ensemble blend
//   fallback_prediction()         — heuristic path
//   severity_from_entry()         — dual-axis scoring
//   danger_level_override_guard() — Option-A CWC guard
//   risk_score formula            — identical weight map
//   STATE_SEVERITY_MATRIX         — Bihar-only (scoped build)
//
// SCOPE CHANGE (Bihar-only build):
//   stateSeverityMatrix trimmed to 'bihar' only.
//   All helper logic (getStateEntry, _unknownStateFallback, regionRainfallThresholds)
//   retained unchanged so the engine compiles and works for any future expansion.
//
// FIXES (v1.1, retained):
//   1. Delhi MSL-elevation flag (not needed for Bihar, kept for forward compat).
//   2. Unknown-state fallback returns PLAINS generic instead of Maharashtra.
//   3. Rule engine probability distribution is right-skewed.
//   4. Duration, timeToPeak, recessionTime contribute to combinedScore.

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
// STATE SEVERITY MATRIX — Bihar only (scoped build)
// Keys normalised to lowercase for lookup.
// Other states removed to match monitoredCities scope restriction.
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

// FIX-2: Safe generic fallback for unknown states uses PLAINS defaults.
final StateEntry _unknownStateFallback = _entry(
  region: 'PLAINS',
  peak: {'moderate': 8.5, 'severe': 11.0, 'critical': 13.0},
  danger: 11.0, warning: 9.0, hfl: 13.5,
  rivers: [],
  districts: [],
);

final Map<String, StateEntry> stateSeverityMatrix = {
  'bihar': _entry(
    region: 'PLAINS',
    peak: {'moderate': 9.0, 'severe': 11.5, 'critical': 13.5},
    danger: 11.5, warning: 9.2, hfl: 14.0,
    rivers: ['Gandak', 'Kosi', 'Bagmati', 'Kamla', 'Mahananda'],
    districts: ['Darbhanga', 'Sitamarhi', 'Muzaffarpur', 'Supaul', 'Madhubani'],
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
// ─────────────────────────────────────────────────────────────────────────────
Map<String, double> _ruleEngineProbMap(String thresholdSev) {
  final rank = _severityOrder[thresholdSev]!;
  final all = ['LOW', 'MODERATE', 'SEVERE', 'CRITICAL'];
  final probs = <String, double>{};
  double total = 0;
  for (final label in all) {
    final diff = _severityOrder[label]! - rank;
    double w;
    if (diff == 0) {
      w = 0.60;
    } else if (diff == 1) {
      w = 0.25;
    } else if (diff == -1) {
      w = 0.10;
    } else if (diff > 1) {
      w = 0.04;
    } else {
      w = 0.01;
    }
    probs[label] = w;
    total += w;
  }
  return {for (final e in probs.entries) e.key: e.value / total};
}

// ─────────────────────────────────────────────────────────────────────────────
// HEURISTIC ON-DEVICE ENGINE
// FIX-4: Duration, timeToPeak, recessionTime contribute to score.
// ─────────────────────────────────────────────────────────────────────────────
FloodResult runOnDeviceEngine(FloodInput input) {
  final entry = getStateEntry(input.state);
  final rainfall7d = input.rainfall7d;

  final thresholdSev = severityFromEntry(
    peakLevelM: input.peakFloodLevelM,
    rainfall7dMm: rainfall7d,
    entry: entry,
  );

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

  final durationScore = (input.eventDurationDays / 14.0).clamp(0.0, 1.0);
  final riseScore = input.timeToPeakDays > 0
      ? (1.0 - (input.timeToPeakDays / 7.0).clamp(0.0, 1.0))
      : 0.0;
  final recessionScore = (input.recessionTimeDay / 10.0).clamp(0.0, 1.0);
  final temporalScore = (durationScore * 0.4 + riseScore * 0.35 + recessionScore * 0.25)
      .clamp(0.0, 1.0);

  final combinedScore =
      (peakScore * 0.52 + rainScore * 0.38 + temporalScore * 0.10).clamp(0.0, 1.0);

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

  final ruleProbs = _ruleEngineProbMap(thresholdSev);

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
