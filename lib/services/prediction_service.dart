/// PredictionService
/// Full Dart port of OpsFlood app.py KolhapurFloodPredictor logic.
/// Implements the Hybrid Multi-Bundle Ensemble + Rule Engine from the backend.
/// Since the Flutter app cannot load .pkl models, we carry the rule-engine
/// (which drives 25-50 % of each prediction) fully, and use the backend
/// /predict endpoint for the ML component — with graceful offline fallback.
library;

import 'dart:convert';
import 'dart:math' as math;

import 'package:http/http.dart' as http;

import '../constants.dart';
import 'cwc_service.dart';

// ── Prediction result ─────────────────────────────────────────────────────────

class FloodPrediction {
  final String severity;          // LOW | MODERATE | SEVERE | CRITICAL
  final double confidencePercent;
  final Map<String, double> probabilities;
  final String algorithm;
  final String dataSource;
  final int riskScore;
  final double dangerLevel;
  final double proximityToDangerM;
  final MonitoringProtocol monitoring;
  final Map<String, dynamic> ensembleDetails;
  final bool fromBackend;
  final DateTime timestamp;

  const FloodPrediction({
    required this.severity,
    required this.confidencePercent,
    required this.probabilities,
    required this.algorithm,
    required this.dataSource,
    required this.riskScore,
    required this.dangerLevel,
    required this.proximityToDangerM,
    required this.monitoring,
    required this.ensembleDetails,
    required this.fromBackend,
    required this.timestamp,
  });

  String get alertEmoji =>
      severity == 'CRITICAL' || severity == 'SEVERE' ? '🚨' :
      severity == 'MODERATE' ? '⚠️' : '🟢';
}

class MonitoringProtocol {
  final String level;
  final String action;
  final List<String> priorityZones;
  const MonitoringProtocol({
    required this.level,
    required this.action,
    required this.priorityZones,
  });

  factory MonitoringProtocol.fromJson(Map<String, dynamic> j) =>
      MonitoringProtocol(
        level:         j['level']?.toString() ?? '',
        action:        j['action']?.toString() ?? '',
        priorityZones: (j['priority_zones'] as List?)?.cast<String>() ?? [],
      );
}

// ── Input model ───────────────────────────────────────────────────────────────

class PredictionInput {
  final double peakFloodLevelM;
  final double eventDurationDays;
  final double timeToPeakDays;
  final double recessionTimeDays;
  final double t1d, t2d, t3d, t4d, t5d, t6d, t7d;
  final String state;
  final String? station;

  const PredictionInput({
    required this.peakFloodLevelM,
    this.eventDurationDays = 1,
    this.timeToPeakDays    = 1,
    this.recessionTimeDays = 1,
    this.t1d = 10, this.t2d = 15, this.t3d = 20,
    this.t4d = 18, this.t5d = 12, this.t6d = 8, this.t7d = 7,
    required this.state,
    this.station,
  });

  double get rainfall7d => t1d + t2d + t3d + t4d + t5d + t6d + t7d;

  Map<String, dynamic> toJson() => {
        'Peak_Flood_Level_m': peakFloodLevelM,
        'Event_Duration_days': eventDurationDays,
        'Time_to_Peak_days': timeToPeakDays,
        'Recession_Time_day': recessionTimeDays,
        'T1d': t1d, 'T2d': t2d, 'T3d': t3d, 'T4d': t4d,
        'T5d': t5d, 'T6d': t6d, 'T7d': t7d,
        'state': state,
        if (station != null) 'station': station,
      };
}

// ── State severity matrix (mirrors state_severity_matrix.py keys used in prediction) ─

class _StateEntry {
  final double dangerLevelM;
  final double warningLevelM;
  final Map<String, double> peakLevelM;   // moderate, severe, critical
  final Map<String, double> rainfall7dMm; // moderate, severe, critical

  const _StateEntry({
    required this.dangerLevelM,
    required this.warningLevelM,
    required this.peakLevelM,
    required this.rainfall7dMm,
  });
}

const _stateMatrix = <String, _StateEntry>{
  'Maharashtra': _StateEntry(
    dangerLevelM: 14.0, warningLevelM: 12.05,
    peakLevelM:    {'moderate': 10.5, 'severe': 12.5, 'critical': 14.5},
    rainfall7dMm:  {'moderate': 200,  'severe': 400,  'critical': 650},
  ),
  'Odisha': _StateEntry(
    dangerLevelM: 16.5, warningLevelM: 14.19,
    peakLevelM:    {'moderate': 12.0, 'severe': 14.5, 'critical': 17.0},
    rainfall7dMm:  {'moderate': 250,  'severe': 500,  'critical': 800},
  ),
  'Assam': _StateEntry(
    dangerLevelM: 15.0, warningLevelM: 12.9,
    peakLevelM:    {'moderate': 11.0, 'severe': 13.5, 'critical': 15.5},
    rainfall7dMm:  {'moderate': 300,  'severe': 600,  'critical': 900},
  ),
  'West Bengal': _StateEntry(
    dangerLevelM: 12.5, warningLevelM: 10.75,
    peakLevelM:    {'moderate': 9.5,  'severe': 11.0, 'critical': 13.0},
    rainfall7dMm:  {'moderate': 200,  'severe': 400,  'critical': 650},
  ),
  'Bihar': _StateEntry(
    dangerLevelM: 13.5, warningLevelM: 11.6,
    peakLevelM:    {'moderate': 10.0, 'severe': 12.0, 'critical': 14.0},
    rainfall7dMm:  {'moderate': 250,  'severe': 500,  'critical': 800},
  ),
  'Kerala': _StateEntry(
    dangerLevelM: 12.0, warningLevelM: 10.32,
    peakLevelM:    {'moderate': 9.0,  'severe': 10.5, 'critical': 12.5},
    rainfall7dMm:  {'moderate': 300,  'severe': 600,  'critical': 950},
  ),
  'Andhra Pradesh': _StateEntry(
    dangerLevelM: 13.0, warningLevelM: 11.18,
    peakLevelM:    {'moderate': 10.0, 'severe': 11.5, 'critical': 13.5},
    rainfall7dMm:  {'moderate': 200,  'severe': 420,  'critical': 700},
  ),
  'Karnataka': _StateEntry(
    dangerLevelM: 12.5, warningLevelM: 10.75,
    peakLevelM:    {'moderate': 9.5,  'severe': 11.0, 'critical': 13.0},
    rainfall7dMm:  {'moderate': 250,  'severe': 500,  'critical': 800},
  ),
  'Gujarat': _StateEntry(
    dangerLevelM: 10.5, warningLevelM: 9.03,
    peakLevelM:    {'moderate': 8.0,  'severe': 9.5,  'critical': 11.0},
    rainfall7dMm:  {'moderate': 180,  'severe': 350,  'critical': 600},
  ),
  'Uttar Pradesh': _StateEntry(
    dangerLevelM: 11.5, warningLevelM: 9.89,
    peakLevelM:    {'moderate': 8.5,  'severe': 10.5, 'critical': 12.0},
    rainfall7dMm:  {'moderate': 200,  'severe': 400,  'critical': 650},
  ),
};

_StateEntry _getStateEntry(String state) =>
    _stateMatrix[state] ??
    const _StateEntry(
      dangerLevelM: 12.0, warningLevelM: 10.32,
      peakLevelM:    {'moderate': 9.0, 'severe': 11.0, 'critical': 13.0},
      rainfall7dMm:  {'moderate': 200, 'severe': 400,  'critical': 650},
    );

// ── Service ───────────────────────────────────────────────────────────────────

class PredictionService {
  PredictionService._();
  static final PredictionService instance = PredictionService._();

  final http.Client _client = http.Client();
  final CwcService  _cwc    = CwcService.instance;

  // ── Main entry point ───────────────────────────────────────────────────────

  /// Run prediction for a given city/state.
  /// 1. Fetch live CWC level for the station
  /// 2. Build input with real peak level
  /// 3. POST to backend /predict (with ML ensemble)
  /// 4. If backend offline, fall back to local rule-engine
  Future<FloodPrediction> predict({
    required String state,
    required String station,
    double? manualPeakLevelM,
    double? rainfall7dMm,
  }) async {
    // Step 1: Get live river level from CWC
    double? liveLevel = await _cwc.getLiveRiverLevel(station);
    final peakLevel   = liveLevel ?? manualPeakLevelM ?? _getStateEntry(state).dangerLevelM * 0.75;

    // Step 2: Build rainfall from state defaults if not supplied
    final rain = rainfall7dMm ?? _estimateRainfall(state, peakLevel);
    final input = PredictionInput(
      peakFloodLevelM:    peakLevel,
      eventDurationDays:  2,
      timeToPeakDays:     1,
      recessionTimeDays:  2,
      t1d: rain * 0.10, t2d: rain * 0.14, t3d: rain * 0.18,
      t4d: rain * 0.20, t5d: rain * 0.18, t6d: rain * 0.12, t7d: rain * 0.08,
      state:   state,
      station: station,
    );

    // Step 3: Try backend ML prediction
    try {
      return await _backendPredict(input, liveLevel: liveLevel);
    } catch (_) {
      // Step 4: Local rule-engine fallback
      return _localRuleEnginePredict(input, liveLevel: liveLevel);
    }
  }

  // ── Backend prediction (app.py /predict) ──────────────────────────────────

  Future<FloodPrediction> _backendPredict(
      PredictionInput input, {double? liveLevel}) async {
    final response = await _client
        .post(
          Uri.parse('${AppConstants.baseUrl}/predict/v2'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(input.toJson()),
        )
        .timeout(const Duration(seconds: 25));

    if (response.statusCode != 200) throw Exception('Backend ${response.statusCode}');

    final j = jsonDecode(response.body) as Map<String, dynamic>;
    return _fromBackendJson(j);
  }

  FloodPrediction _fromBackendJson(Map<String, dynamic> j) {
    final probs = <String, double>{};
    final rawProbs = j['probabilities'];
    if (rawProbs is Map) {
      rawProbs.forEach((k, v) => probs[k.toString()] = (v as num).toDouble());
    }

    final mon = j['monitoring'];
    final monitoring = mon is Map<String, dynamic>
        ? MonitoringProtocol.fromJson(mon)
        : _monitoringFor(j['severity']?.toString() ?? 'LOW');

    return FloodPrediction(
      severity:             j['severity']?.toString() ?? 'MODERATE',
      confidencePercent:    (j['confidence_percent'] as num?)?.toDouble() ?? 70,
      probabilities:        probs,
      algorithm:            j['algorithm']?.toString() ?? 'Backend ML',
      dataSource:           j['data_source']?.toString() ?? 'CWC + ML',
      riskScore:            (j['risk_score'] as num?)?.toInt() ?? 50,
      dangerLevel:          (j['danger_level'] as num?)?.toDouble() ?? 12.0,
      proximityToDangerM:   (j['proximity_to_danger_m'] as num?)?.toDouble() ?? 0,
      monitoring:           monitoring,
      ensembleDetails:      j['ensemble'] is Map ? j['ensemble'] as Map<String, dynamic> : {},
      fromBackend:          true,
      timestamp:            DateTime.now(),
    );
  }

  // ── Local Rule-Engine (mirrors rule_engine_probability_map in Python) ─────

  FloodPrediction _localRuleEnginePredict(
      PredictionInput input, {double? liveLevel}) {
    final entry = _getStateEntry(input.state);
    final dailyRain = [input.t1d, input.t2d, input.t3d,
                       input.t4d, input.t5d, input.t6d, input.t7d];
    final totalRain  = dailyRain.reduce((a, b) => a + b);
    final avgRain    = totalRain / 7;
    final maxDaily   = dailyRain.reduce(math.max);
    final rainDelta  = dailyRain.last - dailyRain.first;
    final peak       = input.peakFloodLevelM;

    // Ratios
    final peakMod  = peak / math.max(entry.peakLevelM['moderate']!,  0.001);
    final peakSev  = peak / math.max(entry.peakLevelM['severe']!,   0.001);
    final peakCrit = peak / math.max(entry.peakLevelM['critical']!, 0.001);
    final rainMod  = totalRain / math.max(entry.rainfall7dMm['moderate']!,  0.001);
    final rainSev  = totalRain / math.max(entry.rainfall7dMm['severe']!,   0.001);
    final rainCrit = totalRain / math.max(entry.rainfall7dMm['critical']!, 0.001);
    final dangerR  = peak / math.max(entry.peakLevelM['critical']!, 0.001);
    final concR    = maxDaily / math.max(avgRain, 1.0);
    final durR     = input.eventDurationDays / 4.0;
    final flashR   = math.max(0.0, (2.5 - input.timeToPeakDays) / 2.5);
    final recR     = math.min(1.5, input.recessionTimeDays / 3.0);
    final trendR   = math.max(-1.0, math.min(1.0, rainDelta / math.max(totalRain, 1.0) * 7.0));

    final scores = {
      'LOW':
          math.max(0.05, 1.25 - math.max(peakMod, rainMod) - math.max(0.0, dangerR - 0.88)),
      'MODERATE':
          math.max(0.05, 0.82 * rainMod + 0.78 * peakMod + 0.12 * durR - 0.82),
      'SEVERE': math.max(
          0.05,
          0.95 * rainSev +
              0.96 * peakSev +
              0.20 * concR +
              0.12 * durR +
              0.10 * math.max(0.0, trendR) -
              1.12),
      'CRITICAL': math.max(
          0.02,
          1.08 * rainCrit +
              1.12 * peakCrit +
              0.34 * math.max(0.0, dangerR - 1.0) +
              0.18 * math.max(0.0, concR - 1.35) +
              0.18 * flashR +
              0.10 * recR +
              0.12 * math.max(0.0, trendR) -
              1.25),
    };

    // Safety guard: if live level < warning, cap at MODERATE
    if (liveLevel != null && liveLevel < entry.warningLevelM) {
      scores['SEVERE']   = 0;
      scores['CRITICAL'] = 0;
    }

    final probs = _normalise(scores);
    final severity = probs.entries
        .reduce((a, b) => a.value >= b.value ? a : b)
        .key;

    final riskWeights = {'LOW': 16, 'MODERATE': 46, 'SEVERE': 78, 'CRITICAL': 96};
    final riskScore   = probs.entries
        .fold(0.0, (s, e) => s + e.value * riskWeights[e.key]!)
        .round();

    return FloodPrediction(
      severity:           severity,
      confidencePercent:  (probs[severity]! * 100).roundToDouble(),
      probabilities:      probs.map((k, v) => MapEntry(k, v * 100)),
      algorithm:          'Local Rule-Engine (offline fallback)',
      dataSource:         liveLevel != null ? 'CWC Live + Rule Engine' : 'Tactical + Rule Engine',
      riskScore:          riskScore.clamp(0, 100),
      dangerLevel:        entry.dangerLevelM,
      proximityToDangerM: double.parse((entry.dangerLevelM - peak).toStringAsFixed(2)),
      monitoring:         _monitoringFor(severity),
      ensembleDetails:    {
        'rule_signals': {
          'peak_moderate_ratio': peakMod,
          'peak_severe_ratio':   peakSev,
          'rain_moderate_ratio': rainMod,
          'danger_ratio':        dangerR,
          'concentration_ratio': concR,
        },
      },
      fromBackend:  false,
      timestamp:    DateTime.now(),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Map<String, double> _normalise(Map<String, double> raw) {
    final total = raw.values.fold(0.0, (s, v) => s + math.max(0, v));
    if (total <= 0) return {'LOW': 1.0, 'MODERATE': 0, 'SEVERE': 0, 'CRITICAL': 0};
    return raw.map((k, v) => MapEntry(k, math.max(0, v) / total));
  }

  double _estimateRainfall(String state, double peak) {
    final entry = _getStateEntry(state);
    if (peak >= entry.peakLevelM['critical']!) return entry.rainfall7dMm['critical']! * 0.85;
    if (peak >= entry.peakLevelM['severe']!)   return entry.rainfall7dMm['severe']!   * 0.75;
    if (peak >= entry.peakLevelM['moderate']!) return entry.rainfall7dMm['moderate']! * 0.80;
    return 60.0;
  }

  MonitoringProtocol _monitoringFor(String severity) {
    switch (severity) {
      case 'CRITICAL': return const MonitoringProtocol(
        level:  'CRITICAL EMERGENCY',
        action: 'Evacuate vulnerable river basins immediately.',
        priorityZones: ['Primary Catchment', 'Downstream Villages', 'Low-lying urban zones'],
      );
      case 'SEVERE': return const MonitoringProtocol(
        level:  'HIGH ALERT',
        action: 'Deploy monitoring teams & prepare contingency measures.',
        priorityZones: ['Primary Catchment', 'Downstream Villages'],
      );
      case 'MODERATE': return const MonitoringProtocol(
        level:  'ELEVATED ALERT',
        action: 'Deploy monitoring teams & prep pumps.',
        priorityZones: ['Drainage bottlenecks', 'Main river gauge'],
      );
      default: return const MonitoringProtocol(
        level:  'STANDARD PROTOCOL',
        action: 'Maintain normal surveillance.',
        priorityZones: ['None'],
      );
    }
  }
}
