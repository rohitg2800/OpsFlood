// OpsFlood — IMD Service v2.0
// Rainfall + alerts via Open-Meteo (free, no auth, real JSON)
// Falls back to empty list on any error — never throws.
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

// ── Models (unchanged public API) ────────────────────────────────────────────
class ImdAlert {
  final String title;
  final String severity; // RED | ORANGE | YELLOW | GREEN
  final String state;
  final String district;
  final DateTime? startTime;
  final DateTime? endTime;
  final double rainfallMm;
  final String source;
  final String message;

  const ImdAlert({
    required this.title,
    required this.severity,
    required this.state,
    required this.district,
    required this.startTime,
    required this.endTime,
    required this.rainfallMm,
    required this.source,
    required this.message,
  });

  factory ImdAlert.fromJson(Map<String, dynamic> j) {
    double sf(dynamic v) =>
        v == null ? 0.0 : (double.tryParse(v.toString()) ?? 0.0);
    return ImdAlert(
      title:      (j['title']    ?? j['headline'] ?? 'IMD Alert').toString(),
      severity:   (j['severity'] ?? j['color']    ?? 'YELLOW').toString().toUpperCase(),
      state:      (j['state']    ?? '').toString(),
      district:   (j['district'] ?? '').toString(),
      startTime:  DateTime.tryParse((j['start_time'] ?? j['start'] ?? '').toString()),
      endTime:    DateTime.tryParse((j['end_time']   ?? j['end']   ?? '').toString()),
      rainfallMm: sf(j['rainfall_mm'] ?? j['rainfall'] ?? j['rain_mm']),
      source:     (j['source']  ?? 'IMD').toString(),
      message:    (j['message'] ?? j['description'] ?? '').toString(),
    );
  }

  bool get isSevere => severity == 'RED' || severity == 'ORANGE';
}

class ImdRainfallPoint {
  final String   state;
  final String   district;
  final DateTime time;
  final double   rainfallMm;
  final String   source;

  const ImdRainfallPoint({
    required this.state,
    required this.district,
    required this.time,
    required this.rainfallMm,
    required this.source,
  });

  factory ImdRainfallPoint.fromJson(Map<String, dynamic> j) {
    double sf(dynamic v) =>
        v == null ? 0.0 : (double.tryParse(v.toString()) ?? 0.0);
    return ImdRainfallPoint(
      state:      (j['state']    ?? '').toString(),
      district:   (j['district'] ?? '').toString(),
      time:       DateTime.tryParse((j['time'] ?? j['timestamp'] ?? '').toString()) ??
                  DateTime.now(),
      rainfallMm: sf(j['rainfall_mm'] ?? j['rain_mm'] ?? j['value']),
      source:     (j['source'] ?? 'IMD').toString(),
    );
  }
}

// ── State capital coordinates (Open-Meteo uses lat/lon) ───────────────────────
const _stateCentre = <String, (double, double)>{
  'Andhra Pradesh':         (15.9129,  79.7400),
  'Arunachal Pradesh':      (27.1004,  93.6167),
  'Assam':                  (26.2006,  92.9376),
  'Bihar':                  (25.0961,  85.3131),
  'Chhattisgarh':           (21.2787,  81.8661),
  'Goa':                    (15.2993,  74.1240),
  'Gujarat':                (22.2587,  71.1924),
  'Haryana':                (29.0588,  76.0856),
  'Himachal Pradesh':       (31.1048,  77.1734),
  'Jharkhand':              (23.6102,  85.2799),
  'Karnataka':              (15.3173,  75.7139),
  'Kerala':                 (10.8505,  76.2711),
  'Madhya Pradesh':         (22.9734,  78.6569),
  'Maharashtra':            (19.7515,  75.7139),
  'Manipur':                (24.6637,  93.9063),
  'Meghalaya':              (25.4670,  91.3662),
  'Mizoram':                (23.1645,  92.9376),
  'Nagaland':               (26.1584,  94.5624),
  'Odisha':                 (20.9517,  85.0985),
  'Punjab':                 (31.1471,  75.3412),
  'Rajasthan':              (27.0238,  74.2179),
  'Sikkim':                 (27.5330,  88.5122),
  'Tamil Nadu':             (11.1271,  78.6569),
  'Telangana':              (18.1124,  79.0193),
  'Tripura':                (23.9408,  91.9882),
  'Uttar Pradesh':          (26.8467,  80.9462),
  'Uttarakhand':            (30.0668,  79.0193),
  'West Bengal':            (22.9868,  87.8550),
  'Delhi':                  (28.7041,  77.1025),
  'Jammu and Kashmir':      (33.7782,  76.5762),
  'Ladakh':                 (34.2996,  78.2932),
  'All India':              (20.5937,  78.9629),
};

// IMD rainfall thresholds (24-hour accumulation, mm)
// RED>=204, ORANGE>=115, YELLOW>=64, GREEN<64
String _rainfallToSeverity(double mm) {
  if (mm >= 204) return 'RED';
  if (mm >= 115) return 'ORANGE';
  if (mm >=  64) return 'YELLOW';
  return 'GREEN';
}

// ── Circuit-breaker state ─────────────────────────────────────────────────────
int      _omFailures  = 0;
DateTime? _omBackoff;
const    _omMaxFail   = 3;
const    _omBackoffDur = Duration(minutes: 30);

// ── Service ───────────────────────────────────────────────────────────────────
class ImdService {
  ImdService._();
  static final ImdService instance = ImdService._();

  final http.Client _client   = http.Client();
  static const _timeout       = Duration(seconds: 12);

  // ── Public API (same signatures as before) ──────────────────────────────────
  Future<List<ImdAlert>> getAlerts({required String state}) async {
    final rainfall = await getRainfall(state: state, days: 1);
    if (rainfall.isEmpty) return const [];

    // Aggregate 24 h total and derive a single alert if noteworthy
    final total = rainfall.fold<double>(0, (s, p) => s + p.rainfallMm);
    final sev   = _rainfallToSeverity(total);
    if (sev == 'GREEN') return const [];

    return [
      ImdAlert(
        title:      'Heavy Rainfall Warning — $state',
        severity:   sev,
        state:      state,
        district:   '',
        startTime:  rainfall.first.time,
        endTime:    rainfall.last.time,
        rainfallMm: total,
        source:     'Open-Meteo/IMD',
        message:
            '${total.toStringAsFixed(1)} mm forecast in 24 h. '
            'IMD $sev alert threshold met.',
      ),
    ];
  }

  Future<List<ImdRainfallPoint>> getRainfall({
    required String state,
    int days = 3,
  }) async {
    // Circuit-breaker check
    if (_omBackoff != null && DateTime.now().isBefore(_omBackoff!)) {
      return const [];
    }

    final centre = _stateCentre[state] ?? _stateCentre['All India']!;
    final lat    = centre.$1;
    final lon    = centre.$2;

    // Open-Meteo free forecast API — no key needed
    final url = Uri.parse(
      'https://api.open-meteo.com/v1/forecast'
      '?latitude=$lat&longitude=$lon'
      '&hourly=precipitation'
      '&forecast_days=$days'
      '&timezone=Asia%2FKolkata',
    );

    try {
      final res = await _client.get(url).timeout(_timeout);
      if (res.statusCode != 200) {
        _recordFailure();
        return const [];
      }
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final times  = (body['hourly']?['time']          as List?) ?? [];
      final precip = (body['hourly']?['precipitation'] as List?) ?? [];

      if (times.isEmpty) return const [];

      _omFailures = 0; // reset on success
      _omBackoff  = null;

      return List.generate(times.length, (i) {
        final mm = (precip[i] as num?)?.toDouble() ?? 0.0;
        return ImdRainfallPoint(
          state:      state,
          district:   '',
          time:       DateTime.tryParse(times[i].toString()) ?? DateTime.now(),
          rainfallMm: mm,
          source:     'Open-Meteo',
        );
      }).where((p) => p.rainfallMm > 0).toList();
    } catch (e) {
      _recordFailure();
      if (kDebugMode) debugPrint('[IMD/Open-Meteo] error: $e');
      return const [];
    }
  }

  void _recordFailure() {
    _omFailures++;
    if (_omFailures >= _omMaxFail) {
      _omBackoff = DateTime.now().add(_omBackoffDur);
      if (kDebugMode)
        debugPrint('[IMD] circuit open — backing off 30 min');
    }
  }
}
