// lib/providers/ai_insight_provider.dart
// v3 — reads mergedStationsProvider for ALL flood context
//
// Changes:
//   • Removed dependency on FloodData / liveLevelsProvider (stale source)
//   • FloodContext now built from RiverStation list (real levels)
//   • riskScoreProvider now also from mergedStations (see risk_score_provider)
//   • weatherProvider kept as additional signal
//   • stationSummary prompt includes actual current/warning/danger values
library;

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../models/river_station.dart';
import 'real_time_river_provider.dart';
import 'risk_score_provider.dart';
import 'weather_provider.dart';

// ─── Config ────────────────────────────────────────────────────────────────────
const _openRouterUrl = 'https://openrouter.ai/api/v1/chat/completions';
const _aiModel       = 'google/gemini-2.5-flash-preview';

// ─── AiInsight model ──────────────────────────────────────────────────────────
class AiInsight {
  final String summary;      // 2-3 sentence plain-English brief
  final String riskLevel;    // 'LOW' | 'MODERATE' | 'HIGH' | 'EXTREME'
  final String actionAdvice; // recommended action
  final List<String> keyPoints;
  final String rawResponse;
  final DateTime generatedAt;
  final bool isLoading;
  final String? error;

  const AiInsight({
    required this.summary,
    required this.riskLevel,
    required this.actionAdvice,
    required this.keyPoints,
    required this.rawResponse,
    required this.generatedAt,
    this.isLoading = false,
    this.error,
  });

  static AiInsight loading() => AiInsight(
    summary: '', riskLevel: '', actionAdvice: '',
    keyPoints: [], rawResponse: '', generatedAt: DateTime.now(), isLoading: true,
  );

  static AiInsight errorState(String msg) => AiInsight(
    summary: 'Unable to generate insight.',
    riskLevel: 'UNKNOWN',
    actionAdvice: 'Check network and retry.',
    keyPoints: [msg],
    rawResponse: '', generatedAt: DateTime.now(), error: msg,
  );
}

// ─── State notifier ────────────────────────────────────────────────────────────
class AiInsightNotifier extends Notifier<AiInsight> {
  Timer? _debounce;

  @override
  AiInsight build() {
    // Trigger re-generation whenever merged stations or weather changes
    final stations = ref.watch(mergedStationsProvider);
    final wx       = ref.watch(weatherProvider);
    final risk     = ref.watch(riskScoreProvider);

    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 3), () {
      if (stations.isNotEmpty) _generate(stations, wx, risk);
    });

    return AiInsight.loading();
  }

  // ── Build the system prompt from live station data ───────────────────────────
  String _buildPrompt(
    List<RiverStation> stations,
    WeatherData wx,
    RiskScore risk,
  ) {
    final total    = stations.length;
    final critical = stations.where((s) => s.dangerClass == DangerClass.extreme).toList();
    final severe   = stations.where((s) => s.dangerClass == DangerClass.severe).toList();
    final elevated = stations.where((s) => s.dangerClass == DangerClass.aboveNormal).toList();

    // Top 5 worst stations
    final top5 = stations.take(5).map((s) =>
      '  • ${s.station} (${s.river}): ${s.current.toStringAsFixed(2)} m '
      '/ danger ${s.danger.toStringAsFixed(2)} m '
      '[${s.dangerClass.name.toUpperCase()}]'
    ).join('\n');

    return '''
You are a flood early-warning AI for Bihar, India. Respond with a JSON object only — no markdown, no prose outside JSON.

LIVE RIVER DATA (${DateTime.now().toIso8601String()}):
- Total monitored stations: $total
- EXTREME (above HFL): ${critical.length}
- SEVERE (at danger level): ${severe.length}
- ELEVATED (above warning): ${elevated.length}
- Normal: ${stations.length - critical.length - severe.length - elevated.length}
- Overall risk score: ${risk.overall.toStringAsFixed(1)}/100 [${risk.label}]

Top 5 critical stations:
$top5

WEATHER:
- Temperature: ${wx.tempC.toStringAsFixed(1)}°C
- Humidity: ${wx.humidity}%
- 7-day rainfall: ${wx.rainfall7dMm.toStringAsFixed(1)} mm
- Rainfall index: ${wx.rainfallIndex.toStringAsFixed(0)}/100
- Wind: ${wx.windKph.toStringAsFixed(0)} km/h

Respond ONLY with this JSON schema:
{
  "summary": "<2-3 sentence situation brief>",
  "riskLevel": "LOW|MODERATE|HIGH|EXTREME",
  "actionAdvice": "<recommended immediate action>",
  "keyPoints": ["<point 1>", "<point 2>", "<point 3>"]
}
''';
  }

  Future<void> _generate(
    List<RiverStation> stations,
    WeatherData wx,
    RiskScore risk,
  ) async {
    state = AiInsight.loading();
    try {
      final apiKey = const String.fromEnvironment('OPENROUTER_KEY', defaultValue: '');
      if (apiKey.isEmpty) {
        // No API key — produce a rule-based insight from live data
        state = _ruleBasedInsight(stations, risk);
        return;
      }

      final res = await http.post(
        Uri.parse(_openRouterUrl),
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
          'HTTP-Referer': 'https://floodwatch.bihar.app',
        },
        body: jsonEncode({
          'model': _aiModel,
          'messages': [
            {'role': 'user', 'content': _buildPrompt(stations, wx, risk)}
          ],
          'temperature': 0.2,
          'max_tokens': 512,
        }),
      ).timeout(const Duration(seconds: 20));

      if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');

      final body    = jsonDecode(res.body) as Map;
      final content = (body['choices'] as List).first['message']['content'] as String;

      // Strip possible markdown code fences
      final clean = content
          .replaceAll(RegExp(r'```json\s*'), '')
          .replaceAll(RegExp(r'```\s*'), '')
          .trim();

      final parsed = jsonDecode(clean) as Map;
      state = AiInsight(
        summary:      parsed['summary']      as String? ?? '',
        riskLevel:    parsed['riskLevel']     as String? ?? risk.label,
        actionAdvice: parsed['actionAdvice']  as String? ?? '',
        keyPoints:    (parsed['keyPoints'] as List?)?.cast<String>() ?? [],
        rawResponse:  content,
        generatedAt:  DateTime.now(),
      );
    } catch (e) {
      if (kDebugMode) debugPrint('[AiInsight] error: $e');
      // Fall back to rule-based on any error
      state = _ruleBasedInsight(stations, risk);
    }
  }

  // ── Offline / no-key rule-based fallback ─────────────────────────────────────
  AiInsight _ruleBasedInsight(List<RiverStation> stations, RiskScore risk) {
    final critical = stations.where((s) => s.dangerClass == DangerClass.extreme).toList();
    final severe   = stations.where((s) => s.dangerClass == DangerClass.severe).toList();
    final elevated = stations.where((s) => s.dangerClass == DangerClass.aboveNormal).toList();

    final worstStation = stations.isNotEmpty ? stations.first : null;

    final summary = worstStation == null
        ? 'No live station data available.'
        : '${stations.length} stations monitored across Bihar rivers. '
          '${critical.length + severe.length} stations at or above danger level. '
          'Worst: ${worstStation.station} (${worstStation.river}) '
          'at ${worstStation.current.toStringAsFixed(2)} m '
          '(danger: ${worstStation.danger.toStringAsFixed(2)} m).';

    final advice = critical.isNotEmpty
        ? 'Evacuate low-lying areas near ${critical.first.station} '
          'on ${critical.first.river} river immediately.'
        : severe.isNotEmpty
            ? 'Issue flood warnings for areas around ${severe.first.station}.'
            : elevated.isNotEmpty
                ? 'Monitor ${elevated.first.station} — approaching warning level.'
                : 'Continue routine monitoring. No immediate danger.';

    return AiInsight(
      summary:      summary,
      riskLevel:    risk.label,
      actionAdvice: advice,
      keyPoints: [
        '${critical.length} stations at extreme (above HFL) level',
        '${severe.length} stations at danger level',
        '${elevated.length} stations above warning level',
        'Overall risk: ${risk.overall.toStringAsFixed(1)}/100',
      ],
      rawResponse:  '',
      generatedAt:  DateTime.now(),
    );
  }

  void refresh() {
    final stations = ref.read(mergedStationsProvider);
    final wx       = ref.read(weatherProvider);
    final risk     = ref.read(riskScoreProvider);
    _generate(stations, wx, risk);
  }
}

final aiInsightProvider = NotifierProvider<AiInsightNotifier, AiInsight>(
    AiInsightNotifier.new);
