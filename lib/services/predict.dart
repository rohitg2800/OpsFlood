// lib/services/predict.dart
//
// OpsFlood Flutter Prediction Service
// v3 — Live-first: always tries OpsFlood API, surfaces real errors,
//       NEVER silently falls back to offline unless explicitly requested.

import 'dart:convert';
import 'package:http/http.dart' as http;

// ─── Constants ───────────────────────────────────────────────────────────────
const String _kBaseUrl = 'https://opsflood.onrender.com';

const Map<int, String> _kSeverityLabel = {
  0: 'LOW',
  1: 'MODERATE',
  2: 'SEVERE',
  3: 'CRITICAL',
};

const Map<String, String> _kSeverityAlert = {
  'LOW':      '✅',
  'MODERATE': '⚠️',
  'SEVERE':   '🚨',
  'CRITICAL': '🆘',
};

const Map<String, String> _kMonitoringLevel = {
  'LOW':      'Normal',
  'MODERATE': 'Elevated',
  'SEVERE':   'High Alert',
  'CRITICAL': 'Emergency',
};

const Map<String, String> _kMonitoringAction = {
  'LOW':      'Continue routine monitoring',
  'MODERATE': 'Increase monitoring frequency',
  'SEVERE':   'Deploy emergency response teams',
  'CRITICAL': 'Immediate evacuation and emergency response',
};

// ─── Input Model ─────────────────────────────────────────────────────────────
class FloodPredictionInput {
  final double peakFloodLevelM;
  final double eventDurationDays;
  final double timeToPeakDays;
  final double recessionTimeDays;
  final double t1d, t2d, t3d, t4d, t5d, t6d, t7d;
  final String state;
  final String? station;

  const FloodPredictionInput({
    this.peakFloodLevelM   = 8.5,
    this.eventDurationDays = 1.0,
    this.timeToPeakDays    = 1.0,
    this.recessionTimeDays = 1.0,
    this.t1d  = 10.0,
    this.t2d  = 15.0,
    this.t3d  = 20.0,
    this.t4d  = 18.0,
    this.t5d  = 12.0,
    this.t6d  = 8.0,
    this.t7d  = 7.0,
    this.state   = 'Maharashtra',
    this.station,
  });

  Map<String, dynamic> toJson() => {
    'Peak_Flood_Level_m':   peakFloodLevelM,
    'Event_Duration_days':  eventDurationDays,
    'Time_to_Peak_days':    timeToPeakDays,
    'Recession_Time_day':   recessionTimeDays,
    'T1d': t1d,
    'T2d': t2d,
    'T3d': t3d,
    'T4d': t4d,
    'T5d': t5d,
    'T6d': t6d,
    'T7d': t7d,
    'state': state,
    if (station != null && station!.isNotEmpty) 'station': station,
  };
}

// ─── Result Model ─────────────────────────────────────────────────────────────
class FloodPrediction {
  final String severity;
  final double confidencePercent;
  final int    riskScore;
  final String alert;
  final String algorithm;
  final String dataSource;
  final bool   modelTrained;
  final Map<String, int> probabilities;
  final String monitoringLevel;
  final String monitoringAction;
  final bool   autofillApplied;
  final double? liveRiverLevelM;
  final bool   isOfflineFallback;
  final String? responseMode;   // NEW: e.g. "LIVE_CWC" / "FALLBACK_MODEL"

  const FloodPrediction({
    required this.severity,
    required this.confidencePercent,
    required this.riskScore,
    required this.alert,
    required this.algorithm,
    required this.dataSource,
    required this.modelTrained,
    required this.probabilities,
    required this.monitoringLevel,
    required this.monitoringAction,
    this.autofillApplied  = false,
    this.liveRiverLevelM,
    this.isOfflineFallback = false,
    this.responseMode,
  });

  factory FloodPrediction.fromJson(Map<String, dynamic> json) {
    final severity  = (json['severity'] as String? ?? 'MODERATE').toUpperCase();
    final monitoring = json['monitoring'] as Map<String, dynamic>? ?? {};
    final isOffline  = json['data_source'] == 'Offline Fallback' ||
                       json['algorithm']   == 'OfflineRuleBased'  ||
                       (json['response_mode'] as String? ?? '').contains('FALLBACK');

    return FloodPrediction(
      severity:           severity,
      confidencePercent:  (json['confidence_percent'] as num?)?.toDouble() ?? 75.0,
      riskScore:          (json['risk_score'] as num?)?.toInt() ?? 50,
      alert:              json['alert']     as String? ?? _kSeverityAlert[severity] ?? '⚠️',
      algorithm:          json['algorithm'] as String? ?? 'Unknown',
      dataSource:         json['data_source'] as String? ?? 'API',
      modelTrained:       json['model_trained'] as bool? ?? true,
      probabilities:      (json['probabilities'] as Map<String, dynamic>? ?? {}).map(
                            (k, v) => MapEntry(k, (v as num).toInt()),
                          ),
      monitoringLevel:    monitoring['level']  as String? ?? _kMonitoringLevel[severity] ?? 'Normal',
      monitoringAction:   monitoring['action'] as String? ?? _kMonitoringAction[severity] ?? '',
      autofillApplied:    json['autofill_applied']  as bool? ?? false,
      liveRiverLevelM:    (json['live_river_level_m'] as num?)?.toDouble(),
      isOfflineFallback:  isOffline,
      responseMode:       json['response_mode'] as String?,
    );
  }
}

// ─── Prediction Service (LIVE-FIRST, no silent fallback) ─────────────────────
class PredictionService {
  final String   baseUrl;
  final Duration timeout;

  const PredictionService({
    this.baseUrl = _kBaseUrl,
    this.timeout = const Duration(seconds: 25),
  });

  // ── Primary: POST /predict/v2 (CWC live auto-fill) ──────────────────────
  /// Throws [PredictionException] on any failure — never silently falls back.
  Future<FloodPrediction> predict(FloodPredictionInput input) async {
    final uri = Uri.parse('$baseUrl/predict/v2');
    late http.Response response;

    try {
      response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(input.toJson()),
          )
          .timeout(timeout);
    } catch (e) {
      throw PredictionException(
        'Network error — check your connection or try again.\n($e)',
        isNetworkError: true,
      );
    }

    if (response.statusCode != 200) {
      throw PredictionException(
        'Server returned HTTP ${response.statusCode}.\n'
        'Body: ${response.body.substring(0, response.body.length.clamp(0, 200))}',
      );
    }

    final Map<String, dynamic> json;
    try {
      json = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw PredictionException('Server returned non-JSON response.');
    }

    if (json['status'] == 'error') {
      throw PredictionException(json['message'] as String? ?? 'Prediction error from server');
    }

    return FloodPrediction.fromJson(json);
  }

  // ── Offline fallback (only when user explicitly requests it) ────────────
  FloodPrediction predictOffline(FloodPredictionInput input) =>
      _offlineFallback(input);
}

// ─── Exception type ───────────────────────────────────────────────────────────
class PredictionException implements Exception {
  final String message;
  final bool isNetworkError;
  PredictionException(this.message, {this.isNetworkError = false});
  @override
  String toString() => message;
}

// ─── Offline fallback ─────────────────────────────────────────────────────────
FloodPrediction _offlineFallback(FloodPredictionInput input) {
  final double peak  = input.peakFloodLevelM;
  final double rain7d = input.t1d + input.t2d + input.t3d + input.t4d +
                        input.t5d + input.t6d + input.t7d;

  int    severityIdx;
  double confidence;
  int    riskScore;

  if (peak >= 14.0 || rain7d >= 650) {
    severityIdx = 3; confidence = 85.0; riskScore = 90;
  } else if (peak >= 12.0 || rain7d >= 420) {
    severityIdx = 2; confidence = 80.0; riskScore = 70;
  } else if (peak >= 10.0 || rain7d >= 250) {
    severityIdx = 1; confidence = 75.0; riskScore = 50;
  } else {
    severityIdx = 0; confidence = 90.0; riskScore = 20;
  }

  final severity = _kSeverityLabel[severityIdx]!;
  final Map<String, int> probs = {
    'LOW': 0, 'MODERATE': 0, 'SEVERE': 0, 'CRITICAL': 0,
  };
  probs[severity] = confidence.toInt();
  final remaining = 100 - confidence.toInt();
  if (severityIdx > 0) {
    probs[_kSeverityLabel[severityIdx - 1]!] = remaining;
  } else {
    probs['MODERATE'] = remaining;
  }

  return FloodPrediction(
    severity:          severity,
    confidencePercent: confidence,
    riskScore:         riskScore,
    alert:             _kSeverityAlert[severity]!,
    algorithm:         'OfflineRuleBased',
    dataSource:        'Offline Fallback',
    modelTrained:      false,
    probabilities:     probs,
    monitoringLevel:   _kMonitoringLevel[severity]!,
    monitoringAction:  _kMonitoringAction[severity]!,
    isOfflineFallback: true,
    responseMode:      'OFFLINE_FALLBACK',
  );
}
