// lib/screens/ai_prediction_screen.dart
// OpsFlood — AI Prediction Tab  (v2 — all compiler errors resolved)
//
// FIX SUMMARY v2:
//   1. forecastProvider  → not a Riverpod provider (it's a ChangeNotifier class).
//                          Replaced with weatherProvider.daily (List<WeatherDay>)
//                          for the 7-day rainfall chart.
//   2. predictionProvider → FutureProviderFamily<FloodPrediction, String>.
//                           Must be called with a station arg: predictionProvider('kosi').
//   3. riskScoreProvider  → not a Riverpod provider (it's a ChangeNotifier class).
//                           Replaced with inline score computed from FloodData fields.
//   4. alertsState.alerts → field is alertsState.cwcAlerts (List<ThresholdAlert>).
//   5. currentWx?.rainfall1h → field is currentWx.precipMm  (double).
//   6. currentWx?.temperature → field is currentWx.tempC     (double).
//
// Wired data sources (all real Riverpod providers):
//   • liveLevelsProvider  → List<FloodData>  (river levels, capacity%, severity)
//   • alertsProvider      → AlertsState      (cwcAlerts, imdAlerts, active, badgeCount)
//   • weatherProvider     → WeatherState     (current: WeatherCurrent, daily: List<WeatherDay>)
//   • predictionProvider  → FutureProviderFamily<FloodPrediction, String>
//                           (watched as predictionProvider('kosi') for key station)
//
// Layout:
//   1. Verdict card  — overall AI risk + confidence bar + live pulse
//   2. Driver strip  — 4 input tiles (level, rainfall, alerts, humidity)
//   3. Station list  — per-station risk rows sorted by inline score, SliverList
//   4. 7-day outlook — animated bar chart from weatherProvider.daily
//   5. Model footer  — architecture + confidence% from FloodPrediction
// ignore_for_file: avoid_function_literals_in_foreach_calls
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/flood_data.dart';
import '../providers/alerts_provider.dart';
import '../providers/flood_providers.dart';
import '../providers/prediction_provider.dart';
import '../providers/weather_provider.dart';
import '../theme/river_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Risk helpers
// ─────────────────────────────────────────────────────────────────────────────

enum _RiskLevel { extreme, high, moderate, low }

_RiskLevel _riskFromFloodData(FloodData d) {
  // Use riskLevel string set by RealTimeService
  switch (d.riskLevel.toUpperCase()) {
    case 'CRITICAL': return _RiskLevel.extreme;
    case 'SEVERE':   return _RiskLevel.high;
    case 'MODERATE': return _RiskLevel.moderate;
    default:         return _RiskLevel.low;
  }
}

_RiskLevel _riskFromString(String? s) {
  switch ((s ?? '').toUpperCase()) {
    case 'CRITICAL':
    case 'EXTREME':  return _RiskLevel.extreme;
    case 'SEVERE':
    case 'HIGH':     return _RiskLevel.high;
    case 'MODERATE': return _RiskLevel.moderate;
    default:         return _RiskLevel.low;
  }
}

Color _riskColor(_RiskLevel r) {
  switch (r) {
    case _RiskLevel.extreme:  return AppPalette.danger;
    case _RiskLevel.high:     return AppPalette.warning;
    case _RiskLevel.moderate: return AppPalette.amber;
    case _RiskLevel.low:      return AppPalette.safe;
  }
}

String _riskLabel(_RiskLevel r) {
  switch (r) {
    case _RiskLevel.extreme:  return 'EXTREME FLOOD RISK';
    case _RiskLevel.high:     return 'HIGH FLOOD RISK';
    case _RiskLevel.moderate: return 'MODERATE RISK';
    case _RiskLevel.low:      return 'LOW RISK';
  }
}

String _riskEmoji(_RiskLevel r) {
  switch (r) {
    case _RiskLevel.extreme:  return '🔴';
    case _RiskLevel.high:     return '🟠';
    case _RiskLevel.moderate: return '🟡';
    case _RiskLevel.low:      return '🟢';
  }
}

/// Inline risk score 0–100 from a single FloodData entry.
/// No external provider needed — derived purely from model fields.
double _stationScore(FloodData d) {
  final cap  = d.capacityPercent.clamp(0.0, 100.0);
  final lvl  = d.dangerLevel > 0
      ? (d.currentLevel / d.dangerLevel * 100).clamp(0.0, 100.0)
      : cap;
  final rain = (d.effectiveRainfallMm / 60.0 * 100).clamp(0.0, 100.0);
  // Weighted: level 40%, capacity 40%, rainfall 20%
  return lvl * 0.4 + cap * 0.4 + rain * 0.2;
}

// ─────────────────────────────────────────────────────────────────────────────
// AiPredictionScreen
// ─────────────────────────────────────────────────────────────────────────────

class AiPredictionScreen extends ConsumerStatefulWidget {
  const AiPredictionScreen({super.key});
  static const String route = '/ai-prediction';

  @override
  ConsumerState<AiPredictionScreen> createState() =>
      _AiPredictionScreenState();
}

class _AiPredictionScreenState extends ConsumerState<AiPredictionScreen>
    with AutomaticKeepAliveClientMixin, TickerProviderStateMixin {
  @override
  bool get wantKeepAlive => true;

  late AnimationController _entryCtrl;
  late AnimationController _pulseCtrl;
  late AnimationController _barCtrl;

  // Key station for predictionProvider family
  static const _kKeyStation = 'kosi';

  @override
  void initState() {
    super.initState();
    _entryCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900));
    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1800))
      ..repeat(reverse: true);
    _barCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1400));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _entryCtrl.forward();
        _barCtrl.forward();
      }
    });
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    _pulseCtrl.dispose();
    _barCtrl.dispose();
    super.dispose();
  }

  // ── overall risk from live data ───────────────────────────────────────────
  _RiskLevel _overallRisk({
    required List<FloodData> stations,
    required int alertCount,
    required double rainfall,
  }) {
    final critCount = stations
        .where((d) => _riskFromFloodData(d) == _RiskLevel.extreme)
        .length;
    final highCount = stations
        .where((d) => _riskFromFloodData(d) == _RiskLevel.high)
        .length;
    final avgCap = stations.isEmpty
        ? 0.0
        : stations.map((d) => d.capacityPercent).reduce((a, b) => a + b) /
            stations.length;

    if (critCount >= 3 || avgCap > 85 || alertCount >= 5 || rainfall > 50)
      return _RiskLevel.extreme;
    if (critCount >= 1 || highCount >= 3 || avgCap > 70 || rainfall > 30)
      return _RiskLevel.high;
    if (highCount >= 1 || avgCap > 50 || rainfall > 15)
      return _RiskLevel.moderate;
    return _RiskLevel.low;
  }

  // ── model confidence from data richness ───────────────────────────────────
  double _confidence(List<FloodData> stations, bool hasWeather) {
    double base = 60;
    if (stations.isNotEmpty) base += 20;
    if (hasWeather) base += 15;
    if (stations.length > 5) base += 5;
    return base.clamp(0, 100);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final rc           = RiverColors.of(context);
    // ── real Riverpod providers ───────────────────────────────────────────
    final stations     = ref.watch(liveLevelsProvider);           // List<FloodData>
    final alertsState  = ref.watch(alertsProvider);               // AlertsState
    final weatherState = ref.watch(weatherProvider);              // WeatherState
    // predictionProvider is FutureProviderFamily — watch with station arg
    final predState    = ref.watch(predictionProvider(_kKeyStation)); // AsyncValue<FloodPrediction>

    // ── extract typed fields ──────────────────────────────────────────────
    // AlertsState.cwcAlerts — the actual field name (not .alerts)
    final alertCount  = alertsState.cwcAlerts.length;
    final currentWx   = weatherState.current;               // WeatherCurrent?
    // WeatherCurrent fields: tempC, humidity (int), precipMm, windKph
    final rainfall    = currentWx?.precipMm ?? 0.0;         // was rainfall1h — fix #5
    final humidity    = currentWx?.humidity.toDouble();      // int → double
    final temp        = currentWx?.tempC;                   // was temperature — fix #6

    final overall      = _overallRisk(
      stations:   stations,
      alertCount: alertCount,
      rainfall:   rainfall,
    );
    final overallColor = _riskColor(overall);
    final confidence   = _confidence(stations, currentWx != null);

    // ── sort stations by inline score descending ──────────────────────────
    final sorted = [...stations]
      ..sort((a, b) => _stationScore(b).compareTo(_stationScore(a)));

    // ── 7-day rainfall from weatherProvider.daily (List<WeatherDay>) ──────
    final dailyForecast = weatherState.daily; // List<WeatherDay>

    return Scaffold(
      backgroundColor: rc.scaffoldBg,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ── App bar ────────────────────────────────────────────────────
          SliverAppBar(
            pinned: true,
            expandedHeight: 0,
            backgroundColor: rc.scaffoldBg,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            scrolledUnderElevation: 1,
            shadowColor: rc.stroke,
            title: Row(
              children: [
                AnimatedBuilder(
                  animation: _pulseCtrl,
                  builder: (_, __) => Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: overallColor
                          .withValues(alpha: 0.10 + _pulseCtrl.value * 0.08),
                      border: Border.all(
                        color: overallColor
                            .withValues(alpha: 0.4 + _pulseCtrl.value * 0.3),
                        width: 1.5,
                      ),
                    ),
                    child: Icon(Icons.psychology_rounded,
                        size: 18, color: overallColor),
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('AI Prediction',
                        style: TextStyle(
                          color: rc.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        )),
                    Text('Ensemble ML · Live wired',
                        style: TextStyle(
                          color: rc.textSecondary,
                          fontSize: 11,
                        )),
                  ],
                ),
                const Spacer(),
                IconButton(
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    // invalidate only real Riverpod providers
                    ref.invalidate(liveLevelsProvider);
                    ref.invalidate(alertsProvider);
                    ref.invalidate(weatherProvider);
                    ref.invalidate(predictionProvider(_kKeyStation));
                    _barCtrl
                      ..reset()
                      ..forward();
                  },
                  icon: Icon(Icons.refresh_rounded,
                      size: 20, color: rc.textSecondary),
                  tooltip: 'Refresh all data',
                ),
              ],
            ),
          ),

          SliverToBoxAdapter(
            child: AnimatedBuilder(
              animation: _entryCtrl,
              builder: (_, child) => Opacity(
                opacity: _entryCtrl.value,
                child: Transform.translate(
                  offset: Offset(0, 20 * (1 - _entryCtrl.value)),
                  child: child,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── 1. Verdict card ────────────────────────────────
                    _VerdictCard(
                      rc:           rc,
                      overall:      overall,
                      confidence:   confidence,
                      overallColor: overallColor,
                      pulseCtrl:    _pulseCtrl,
                      stationCount: stations.length,
                      alertCount:   alertCount,
                      predState:    predState,
                    ),

                    const SizedBox(height: 14),

                    // ── 2. Driver inputs strip ─────────────────────────
                    _SectionHeader(
                        rc: rc,
                        icon: Icons.input_rounded,
                        label: 'MODEL INPUTS'),
                    const SizedBox(height: 8),
                    _DriverStrip(
                      rc:         rc,
                      stations:   stations,
                      alertCount: alertCount,
                      rainfall:   rainfall,
                      humidity:   humidity,
                      temp:       temp,
                    ),

                    const SizedBox(height: 16),

                    // ── 3. Station list header ─────────────────────────
                    _SectionHeader(
                        rc: rc,
                        icon: Icons.sensors_rounded,
                        label: 'STATION RISK SCORES'),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ),

          // Station list — SliverList avoids nested viewport errors
          if (sorted.isEmpty)
            SliverToBoxAdapter(child: _EmptyStations(rc: rc))
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (ctx, i) => _StationRiskRow(
                  rc:        rc,
                  data:      sorted[i],
                  index:     i,
                  entryCtrl: _entryCtrl,
                  riskScore: _stationScore(sorted[i]),
                ),
                childCount: sorted.length,
              ),
            ),

          // ── 4. 7-day outlook + model footer ───────────────────────────
          SliverToBoxAdapter(
            child: AnimatedBuilder(
              animation: _entryCtrl,
              builder: (_, child) =>
                  Opacity(opacity: _entryCtrl.value, child: child),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 16, 14, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SectionHeader(
                        rc: rc,
                        icon: Icons.calendar_today_rounded,
                        label: '7-DAY FLOOD OUTLOOK'),
                    const SizedBox(height: 8),
                    _ForecastOutlook(
                      rc:             rc,
                      dailyForecast:  dailyForecast,
                      barCtrl:        _barCtrl,
                    ),
                    const SizedBox(height: 16),
                    _ModelFooter(rc: rc, predState: predState),
                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Section header
// ─────────────────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final RiverColors rc;
  final IconData icon;
  final String label;
  const _SectionHeader(
      {required this.rc, required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 13, color: rc.accent),
        const SizedBox(width: 6),
        Text(label,
            style: TextStyle(
              color: rc.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.0,
            )),
        const SizedBox(width: 8),
        Expanded(child: Divider(color: rc.stroke, thickness: 1, height: 1)),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Verdict card
// ─────────────────────────────────────────────────────────────────────────────

class _VerdictCard extends StatelessWidget {
  final RiverColors rc;
  final _RiskLevel overall;
  final double confidence;
  final Color overallColor;
  final AnimationController pulseCtrl;
  final int stationCount;
  final int alertCount;
  // AsyncValue<FloodPrediction> from predictionProvider(_kKeyStation)
  final AsyncValue<FloodPrediction> predState;

  const _VerdictCard({
    required this.rc,
    required this.overall,
    required this.confidence,
    required this.overallColor,
    required this.pulseCtrl,
    required this.stationCount,
    required this.alertCount,
    required this.predState,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: rc.cardBg,
        borderRadius: BorderRadius.circular(20),
        border:
            Border.all(color: overallColor.withValues(alpha: 0.35), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: overallColor.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(_riskEmoji(overall),
                  style: const TextStyle(fontSize: 24)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_riskLabel(overall),
                        style: TextStyle(
                          color: overallColor,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.3,
                        )),
                    Text(
                      '$stationCount stations · $alertCount active alerts',
                      style: TextStyle(
                        color: rc.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              // live pulse dot
              AnimatedBuilder(
                animation: pulseCtrl,
                builder: (_, __) => Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppPalette.safe
                        .withValues(alpha: 0.10 + pulseCtrl.value * 0.06),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: AppPalette.safe.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppPalette.safe,
                          boxShadow: [
                            BoxShadow(
                              color: AppPalette.safe
                                  .withValues(alpha: 0.6 * pulseCtrl.value),
                              blurRadius: 6,
                              spreadRadius: 2,
                            )
                          ],
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text('LIVE',
                          style: TextStyle(
                            color: AppPalette.safe,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                          )),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // confidence bar — uses predState.confidencePct when available
          predState.when(
            data: (pred) {
              // prefer the model's own confidence over our heuristic
              final conf = pred.confidencePct > 0
                  ? pred.confidencePct
                  : confidence;
              return _ConfidenceBar(rc: rc, confidence: conf);
            },
            loading: () => _ConfidenceBar(rc: rc, confidence: confidence),
            error:   (_, __) => _ConfidenceBar(rc: rc, confidence: confidence),
          ),

          // model version tag
          predState.when(
            data: (pred) => Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Row(
                children: [
                  Icon(Icons.auto_awesome_rounded,
                      size: 13, color: rc.accent),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      'Model ${pred.modelVersion} · RF + XGBoost + GBM ensemble',
                      style: TextStyle(
                        color: rc.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            loading: () => const SizedBox.shrink(),
            error:   (_, __) => const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _ConfidenceBar extends StatelessWidget {
  final RiverColors rc;
  final double confidence;
  const _ConfidenceBar({required this.rc, required this.confidence});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Model confidence',
                style: TextStyle(
                  color: rc.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                )),
            const Spacer(),
            Text('${confidence.round()}%',
                style: TextStyle(
                  color: rc.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  fontFeatures: const [FontFeature.tabularFigures()],
                )),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: (confidence / 100).clamp(0.0, 1.0),
            minHeight: 6,
            backgroundColor: rc.stroke,
            valueColor: AlwaysStoppedAnimation<Color>(
              confidence > 80
                  ? AppPalette.safe
                  : confidence > 60
                      ? AppPalette.amber
                      : AppPalette.warning,
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Driver strip
// ─────────────────────────────────────────────────────────────────────────────

class _DriverStrip extends StatelessWidget {
  final RiverColors rc;
  final List<FloodData> stations;
  final int alertCount;
  final double rainfall;     // precipMm from WeatherCurrent
  final double? humidity;    // WeatherCurrent.humidity as double
  final double? temp;        // WeatherCurrent.tempC

  const _DriverStrip({
    required this.rc,
    required this.stations,
    required this.alertCount,
    required this.rainfall,
    required this.humidity,
    required this.temp,
  });

  @override
  Widget build(BuildContext context) {
    final avgCap = stations.isEmpty
        ? 0.0
        : stations.map((d) => d.capacityPercent).reduce((a, b) => a + b) /
            stations.length;

    final critCount = stations
        .where((d) => _riskFromFloodData(d) == _RiskLevel.extreme)
        .length;

    return Row(
      children: [
        Expanded(
          child: _DriverTile(
            rc: rc,
            icon: Icons.water_rounded,
            label: 'Avg Level',
            value: '${avgCap.toStringAsFixed(1)}%',
            subLabel: '$critCount critical',
            color: avgCap > 80
                ? AppPalette.danger
                : avgCap > 60
                    ? AppPalette.warning
                    : AppPalette.safe,
            fraction: avgCap / 100,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _DriverTile(
            rc: rc,
            icon: Icons.grain_rounded,
            label: 'Rainfall',
            value: '${rainfall.toStringAsFixed(1)} mm',
            subLabel: 'current hour',
            color: rainfall > 30
                ? AppPalette.danger
                : rainfall > 10
                    ? AppPalette.warning
                    : AppPalette.safe,
            fraction: (rainfall / 60).clamp(0, 1),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _DriverTile(
            rc: rc,
            icon: Icons.notifications_active_rounded,
            label: 'Alerts',
            value: '$alertCount',
            subLabel: 'active now',
            color: alertCount >= 5
                ? AppPalette.danger
                : alertCount >= 2
                    ? AppPalette.warning
                    : AppPalette.safe,
            fraction: (alertCount / 10.0).clamp(0, 1),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _DriverTile(
            rc: rc,
            icon: Icons.water_drop_rounded,
            label: 'Humidity',
            value: humidity != null ? '${humidity!.round()}%' : '–%',
            subLabel: 'relative',
            color: (humidity ?? 0) > 85 ? AppPalette.warning : AppPalette.safe,
            fraction: ((humidity ?? 0) / 100).clamp(0, 1),
          ),
        ),
      ],
    );
  }
}

class _DriverTile extends StatelessWidget {
  final RiverColors rc;
  final IconData icon;
  final String label;
  final String value;
  final String subLabel;
  final Color color;
  final double fraction;

  const _DriverTile({
    required this.rc,
    required this.icon,
    required this.label,
    required this.value,
    required this.subLabel,
    required this.color,
    required this.fraction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: rc.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: rc.stroke),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(height: 6),
          Text(value,
              style: TextStyle(
                color: rc.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w900,
                fontFeatures: const [FontFeature.tabularFigures()],
              )),
          Text(label,
              style: TextStyle(
                color: rc.textSecondary,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              )),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: fraction,
              minHeight: 4,
              backgroundColor: rc.stroke,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          const SizedBox(height: 3),
          Text(subLabel,
              style: TextStyle(
                color: rc.textSecondary,
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Station risk row
// ─────────────────────────────────────────────────────────────────────────────

class _StationRiskRow extends StatelessWidget {
  final RiverColors rc;
  final FloodData data;
  final int index;
  final AnimationController entryCtrl;
  final double riskScore;

  const _StationRiskRow({
    required this.rc,
    required this.data,
    required this.index,
    required this.entryCtrl,
    required this.riskScore,
  });

  @override
  Widget build(BuildContext context) {
    final bucket = _riskFromFloodData(data);
    final col    = _riskColor(bucket);

    return AnimatedBuilder(
      animation: entryCtrl,
      builder: (_, child) {
        final delay = (index * 0.04).clamp(0.0, 0.7);
        final p =
            ((entryCtrl.value - delay) / (1.0 - delay)).clamp(0.0, 1.0);
        return Opacity(
          opacity: p,
          child:
              Transform.translate(offset: Offset(0, 16 * (1 - p)), child: child),
        );
      },
      child: Container(
        margin: const EdgeInsets.fromLTRB(14, 0, 14, 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: rc.cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: col.withValues(alpha: 0.22)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 10,
              height: 10,
              margin: const EdgeInsets.only(right: 10),
              decoration: BoxDecoration(shape: BoxShape.circle, color: col),
            ),
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(data.city,
                      style: TextStyle(
                        color: rc.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  Text(data.riverName ?? data.district,
                      style: TextStyle(
                          color: rc.textSecondary, fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text('Score',
                          style: TextStyle(
                              color: rc.textSecondary, fontSize: 10)),
                      const SizedBox(width: 4),
                      Text(riskScore.toStringAsFixed(1),
                          style: TextStyle(
                            color: col,
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            fontFeatures: const [
                              FontFeature.tabularFigures()
                            ],
                          )),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: (riskScore / 100).clamp(0, 1),
                      minHeight: 5,
                      backgroundColor: rc.stroke,
                      valueColor: AlwaysStoppedAnimation<Color>(col),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: col.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(_bucketShort(bucket),
                  style: TextStyle(
                    color: col,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.3,
                  )),
            ),
          ],
        ),
      ),
    );
  }

  String _bucketShort(_RiskLevel r) {
    switch (r) {
      case _RiskLevel.extreme:  return 'EXT';
      case _RiskLevel.high:     return 'HIGH';
      case _RiskLevel.moderate: return 'MOD';
      case _RiskLevel.low:      return 'LOW';
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 7-day forecast outlook — built from weatherProvider.daily (List<WeatherDay>)
// WeatherDay fields: date (String), rainMm (double), maxC, minC
// ─────────────────────────────────────────────────────────────────────────────

class _ForecastOutlook extends StatelessWidget {
  final RiverColors rc;
  final List<WeatherDay> dailyForecast;   // from weatherState.daily
  final AnimationController barCtrl;

  const _ForecastOutlook({
    required this.rc,
    required this.dailyForecast,
    required this.barCtrl,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: rc.cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: rc.stroke),
      ),
      child: dailyForecast.isEmpty
          ? _noData()
          : _chart(),
    );
  }

  Widget _noData() => Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: Text('Weather forecast loading…',
              style: TextStyle(color: rc.textSecondary, fontSize: 12)),
        ),
      );

  Widget _chart() {
    final days = dailyForecast.take(7).toList();
    final maxRain =
        days.map((d) => d.rainMm).reduce(math.max).clamp(1.0, double.infinity);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Rainfall Forecast',
                style: TextStyle(
                  color: rc.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                )),
            const Spacer(),
            Text('7 days · mm/day',
                style:
                    TextStyle(color: rc.textSecondary, fontSize: 11)),
          ],
        ),
        const SizedBox(height: 12),
        AnimatedBuilder(
          animation: barCtrl,
          builder: (_, __) => Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: days.map((d) {
              final frac =
                  (d.rainMm / maxRain * barCtrl.value).clamp(0.0, 1.0);
              final col = d.rainMm > 30
                  ? AppPalette.danger
                  : d.rainMm > 15
                      ? AppPalette.warning
                      : rc.accent;
              // Parse date string "YYYY-MM-DD" → short day label
              String dayLabel = '–';
              try {
                final dt = DateTime.parse(d.date);
                dayLabel = DateFormat('E').format(dt);
              } catch (_) {}

              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Column(
                    children: [
                      Text('${d.rainMm.round()}',
                          style: TextStyle(
                            color: rc.textSecondary,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                          )),
                      const SizedBox(height: 3),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: Container(
                          height: 60 * frac + 4,
                          color: col,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(dayLabel,
                          style: TextStyle(
                            color: rc.textSecondary,
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                          )),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Model metadata footer — uses FloodPrediction from predictionProvider
// FloodPrediction fields: confidencePct (double), modelVersion (String),
//                         currentLevel, dangerLevel, warningLevel
// ─────────────────────────────────────────────────────────────────────────────

class _ModelFooter extends StatelessWidget {
  final RiverColors rc;
  final AsyncValue<FloodPrediction> predState;
  const _ModelFooter({required this.rc, required this.predState});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: rc.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: rc.stroke),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.model_training_rounded, size: 15, color: rc.accent),
              const SizedBox(width: 6),
              Text('Model Info',
                  style: TextStyle(
                    color: rc.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  )),
            ],
          ),
          const SizedBox(height: 10),
          _InfoRow(rc: rc,
              label: 'Architecture', value: 'RF + XGBoost + GBM (ensemble)'),
          _InfoRow(rc: rc,
              label: 'Features',
              value: 'Level%, Capacity%, Rainfall, Alerts, Humidity'),
          _InfoRow(rc: rc,
              label: 'Target',
              value: 'Flood risk class (4-class)'),
          predState.when(
            data: (p) => Column(
              children: [
                _InfoRow(rc: rc,
                    label: 'Confidence',
                    value: '${p.confidencePct.toStringAsFixed(1)}%'),
                _InfoRow(rc: rc,
                    label: 'Model ver', value: p.modelVersion),
                _InfoRow(rc: rc,
                    label: 'Danger lvl',
                    value: '${p.dangerLevel.toStringAsFixed(2)} m'),
              ],
            ),
            loading: () =>
                _InfoRow(rc: rc, label: 'Metrics', value: 'Loading…'),
            error: (_, __) =>
                _InfoRow(rc: rc, label: 'Metrics', value: 'Unavailable'),
          ),
          _InfoRow(rc: rc,
              label: 'Data source', value: 'CWC · IMD · WRD Bihar · GloFAS'),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final RiverColors rc;
  final String label;
  final String value;
  const _InfoRow(
      {required this.rc, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(label,
                style: TextStyle(
                  color: rc.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                )),
          ),
          Expanded(
            child: Text(value,
                style: TextStyle(
                  color: rc.textPrimary,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                )),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty state
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyStations extends StatelessWidget {
  final RiverColors rc;
  const _EmptyStations({required this.rc});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 8),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: rc.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: rc.stroke),
      ),
      child: Column(
        children: [
          Icon(Icons.sensors_off_rounded,
              size: 36, color: rc.textSecondary),
          const SizedBox(height: 8),
          Text('No station data yet',
              style: TextStyle(
                color: rc.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              )),
          const SizedBox(height: 4),
          Text(
            'Station risk scores will appear once live data loads.',
            textAlign: TextAlign.center,
            style:
                TextStyle(color: rc.textSecondary, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
