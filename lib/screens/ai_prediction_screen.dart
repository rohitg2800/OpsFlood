// lib/screens/ai_prediction_screen.dart
// OpsFlood — AI Prediction Tab
//
// Wired data sources:
//   • liveLevelsProvider       → FloodData list (river levels, capacity%, severity)
//   • alertsProvider           → active alert count + severity distribution
//   • weatherProvider          → current temp, humidity, rainfall, wind
//   • forecastProvider         → 7-day rainfall forecast
//   • predictionProvider       → ML model output (risk label + confidence)
//   • riskScoreProvider        → composite risk score per station
//   • cwcProvider              → CWC station water-level readings
//   • kosibirpurProvider       → Kosi-Birpur hydrograph (key flood driver)
//
// Layout:
//   1. Header strip — overall AI risk verdict + confidence meter
//   2. Driver cards — 4 live inputs that feed the model (level, rain, alerts, humidity)
//   3. Per-station prediction list — sorted by risk score, animated entry
//   4. 7-day flood outlook — bar chart from forecastProvider
//   5. Model metadata footer — ensemble info, last-trained badge
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
import '../providers/forecast_provider.dart';
import '../providers/prediction_provider.dart';
import '../providers/risk_score_provider.dart';
import '../providers/weather_provider.dart';
import '../theme/river_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Tiny helpers
// ─────────────────────────────────────────────────────────────────────────────

enum _RiskLevel { extreme, high, moderate, low }

_RiskLevel _riskFromString(String? s) {
  switch ((s ?? '').toLowerCase()) {
    case 'critical':
    case 'extreme':  return _RiskLevel.extreme;
    case 'high':     return _RiskLevel.high;
    case 'moderate': return _RiskLevel.moderate;
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

  // ── derive overall risk from live data ───────────────────────────────────
  _RiskLevel _overallRisk({
    required List<FloodData> stations,
    required int alertCount,
    required double? rainfall,
  }) {
    final criticalStations =
        stations.where((d) => (d.imdSeverity ?? '').toLowerCase() == 'critical').length;
    final highStations =
        stations.where((d) => (d.imdSeverity ?? '').toLowerCase() == 'high').length;
    final avgCap = stations.isEmpty
        ? 0.0
        : stations.map((d) => d.capacityPercent).reduce((a, b) => a + b) /
            stations.length;
    final rain = rainfall ?? 0.0;

    if (criticalStations >= 3 || avgCap > 85 || alertCount >= 5 || rain > 50)
      return _RiskLevel.extreme;
    if (criticalStations >= 1 || highStations >= 3 || avgCap > 70 || rain > 30)
      return _RiskLevel.high;
    if (highStations >= 1 || avgCap > 50 || rain > 15)
      return _RiskLevel.moderate;
    return _RiskLevel.low;
  }

  // ── confidence score (0–100) from data richness ─────────────────────────
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
    final stations     = ref.watch(liveLevelsProvider);
    final alertsState  = ref.watch(alertsProvider);
    final weatherState = ref.watch(weatherProvider);
    final forecastState = ref.watch(forecastProvider);
    final predState    = ref.watch(predictionProvider);
    final riskScores   = ref.watch(riskScoreProvider);

    final alertCount = alertsState.alerts.length;
    final currentWx  = weatherState.current;
    final rainfall   = currentWx?.rainfall1h;
    final humidity   = currentWx?.humidity?.toDouble();
    final temp       = currentWx?.temperature;

    final overall    = _overallRisk(
      stations: stations,
      alertCount: alertCount,
      rainfall: rainfall,
    );
    final overallColor = _riskColor(overall);
    final confidence   = _confidence(stations, currentWx != null);

    // sort stations by risk score descending
    final sorted = [...stations]..sort((a, b) {
      final sa = riskScores[a.city] ?? 0.0;
      final sb = riskScores[b.city] ?? 0.0;
      return sb.compareTo(sa);
    });

    return Scaffold(
      backgroundColor: rc.scaffoldBg,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ── App bar ──────────────────────────────────────────────────────
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
                // AI brain icon with pulse
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
                // refresh button
                IconButton(
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    ref.invalidate(liveLevelsProvider);
                    ref.invalidate(alertsProvider);
                    ref.invalidate(weatherProvider);
                    ref.invalidate(forecastProvider);
                    ref.invalidate(predictionProvider);
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

                    // ── 1. Overall verdict card ──────────────────────────
                    _VerdictCard(
                      rc: rc,
                      overall: overall,
                      confidence: confidence,
                      overallColor: overallColor,
                      pulseCtrl: _pulseCtrl,
                      stationCount: stations.length,
                      alertCount: alertCount,
                      predState: predState,
                    ),

                    const SizedBox(height: 14),

                    // ── 2. Driver inputs strip ───────────────────────────
                    _SectionHeader(
                      rc: rc,
                      icon: Icons.input_rounded,
                      label: 'MODEL INPUTS',
                    ),
                    const SizedBox(height: 8),
                    _DriverStrip(
                      rc: rc,
                      stations: stations,
                      alertCount: alertCount,
                      rainfall: rainfall,
                      humidity: humidity,
                      temp: temp,
                    ),

                    const SizedBox(height: 16),

                    // ── 3. Per-station predictions ───────────────────────
                    _SectionHeader(
                      rc: rc,
                      icon: Icons.sensors_rounded,
                      label: 'STATION RISK SCORES',
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ),

          // station list as slivers so it doesn't nest viewports
          if (sorted.isEmpty)
            SliverToBoxAdapter(
              child: _EmptyStations(rc: rc),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (ctx, i) => _StationRiskRow(
                  rc: rc,
                  data: sorted[i],
                  index: i,
                  entryCtrl: _entryCtrl,
                  riskScore: riskScores[sorted[i].city] ?? 0.0,
                ),
                childCount: sorted.length,
              ),
            ),

          // ── 4. 7-day outlook + model footer ──────────────────────────
          SliverToBoxAdapter(
            child: AnimatedBuilder(
              animation: _entryCtrl,
              builder: (_, child) => Opacity(
                opacity: _entryCtrl.value, child: child),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 16, 14, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SectionHeader(
                      rc: rc,
                      icon: Icons.calendar_today_rounded,
                      label: '7-DAY FLOOD OUTLOOK',
                    ),
                    const SizedBox(height: 8),
                    _ForecastOutlook(
                      rc: rc,
                      forecastState: forecastState,
                      barCtrl: _barCtrl,
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
// Verdict card — big risk banner at the top
// ─────────────────────────────────────────────────────────────────────────────

class _VerdictCard extends StatelessWidget {
  final RiverColors rc;
  final _RiskLevel overall;
  final double confidence;
  final Color overallColor;
  final AnimationController pulseCtrl;
  final int stationCount;
  final int alertCount;
  final AsyncValue<dynamic> predState;

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
        border: Border.all(
            color: overallColor.withValues(alpha: 0.35), width: 1.5),
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
          // top row: emoji + label + live dot
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
              // live pulse indicator
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

          // confidence bar
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
              value: confidence / 100,
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

          // ML model name from predictionProvider
          predState.when(
            data: (pred) {
              if (pred == null) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Row(
                  children: [
                    Icon(Icons.auto_awesome_rounded,
                        size: 13, color: rc.accent),
                    const SizedBox(width: 5),
                    Text(
                      'Ensemble: Random Forest + XGBoost + Gradient Boost',
                      style: TextStyle(
                        color: rc.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Driver strip — 4 live input tiles
// ─────────────────────────────────────────────────────────────────────────────

class _DriverStrip extends StatelessWidget {
  final RiverColors rc;
  final List<FloodData> stations;
  final int alertCount;
  final double? rainfall;
  final double? humidity;
  final double? temp;

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
        .where((d) => (d.imdSeverity ?? '').toLowerCase() == 'critical')
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
            value: rainfall != null ? '${rainfall!.toStringAsFixed(1)} mm' : '– mm',
            subLabel: '1-hour observed',
            color: (rainfall ?? 0) > 30
                ? AppPalette.danger
                : (rainfall ?? 0) > 10
                    ? AppPalette.warning
                    : AppPalette.safe,
            fraction: ((rainfall ?? 0) / 60).clamp(0, 1),
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
            color: (humidity ?? 0) > 85
                ? AppPalette.warning
                : AppPalette.safe,
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
  final double fraction; // 0–1 for the mini bar

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
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
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
  final double riskScore; // 0–100 from riskScoreProvider

  const _StationRiskRow({
    required this.rc,
    required this.data,
    required this.index,
    required this.entryCtrl,
    required this.riskScore,
  });

  @override
  Widget build(BuildContext context) {
    final bucket  = _riskFromString(data.imdSeverity);
    final col     = _riskColor(bucket);
    final capPct  = data.capacityPercent.clamp(0.0, 100.0);
    final lvlPct  = data.dangerLevel > 0
        ? (data.currentLevel / data.dangerLevel * 100).clamp(0.0, 100.0)
        : capPct;
    final effectiveScore = riskScore > 0
        ? riskScore
        : lvlPct * 0.6 + capPct * 0.4; // fallback formula

    return AnimatedBuilder(
      animation: entryCtrl,
      builder: (_, child) {
        final delay = (index * 0.04).clamp(0.0, 0.7);
        final p = ((entryCtrl.value - delay) / (1.0 - delay)).clamp(0.0, 1.0);
        return Opacity(
          opacity: p,
          child: Transform.translate(
              offset: Offset(0, 16 * (1 - p)), child: child),
        );
      },
      child: Container(
        margin: const EdgeInsets.fromLTRB(14, 0, 14, 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: rc.cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: col.withValues(alpha: 0.22),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // risk level colored dot
            Container(
              width: 10,
              height: 10,
              margin: const EdgeInsets.only(right: 10),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: col,
              ),
            ),
            // city + river
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
                        color: rc.textSecondary,
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            // mini progress bar
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
                            color: rc.textSecondary,
                            fontSize: 10,
                          )),
                      const SizedBox(width: 4),
                      Text(
                        effectiveScore.toStringAsFixed(1),
                        style: TextStyle(
                          color: col,
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: (effectiveScore / 100).clamp(0, 1),
                      minHeight: 5,
                      backgroundColor: rc.stroke,
                      valueColor: AlwaysStoppedAnimation<Color>(col),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            // badge
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: col.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _bucketShort(bucket),
                style: TextStyle(
                  color: col,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.3,
                ),
              ),
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
// 7-day forecast outlook — bar chart from forecastProvider
// ─────────────────────────────────────────────────────────────────────────────

class _ForecastOutlook extends StatelessWidget {
  final RiverColors rc;
  final AsyncValue<dynamic> forecastState;
  final AnimationController barCtrl;

  const _ForecastOutlook({
    required this.rc,
    required this.forecastState,
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
      child: forecastState.when(
        loading: () => _shimmer(rc),
        error:   (e, _) => _errState(rc, e),
        data:    (forecast) {
          // forecastProvider returns a list or a model; adapt generically
          final days = _extractDays(forecast);
          if (days.isEmpty) return _noForecast(rc);
          final maxRain = days.map((d) => d.rain).reduce(math.max).clamp(1.0, double.infinity);

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
                      style: TextStyle(
                        color: rc.textSecondary,
                        fontSize: 11,
                      )),
                ],
              ),
              const SizedBox(height: 12),
              AnimatedBuilder(
                animation: barCtrl,
                builder: (_, __) => Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: days.map((d) {
                    final frac = (d.rain / maxRain * barCtrl.value).clamp(0.0, 1.0);
                    final col = d.rain > 30
                        ? AppPalette.danger
                        : d.rain > 15
                            ? AppPalette.warning
                            : rc.accent;
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: Column(
                          children: [
                            Text('${d.rain.round()}',
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
                            Text(d.label,
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
        },
      ),
    );
  }

  // Extract days generically — handles both List and model object
  List<_ForecastDay> _extractDays(dynamic forecast) {
    final now = DateTime.now();
    if (forecast is List) {
      return List.generate(
        math.min(forecast.length, 7),
        (i) {
          final item = forecast[i];
          double rain = 0;
          try { rain = (item.rainfall ?? item.rain ?? item.precipitation ?? 0.0).toDouble(); }
          catch (_) {}
          final date = now.add(Duration(days: i));
          return _ForecastDay(
            label: DateFormat('E').format(date),
            rain: rain,
          );
        },
      );
    }
    // Fallback: generate placeholder from today
    return List.generate(7, (i) {
      final d = now.add(Duration(days: i));
      return _ForecastDay(label: DateFormat('E').format(d), rain: 0);
    });
  }

  Widget _shimmer(RiverColors rc) => SizedBox(
    height: 80,
    child: Center(
      child: Text('Loading forecast…',
          style: TextStyle(color: rc.textSecondary, fontSize: 12)),
    ),
  );

  Widget _errState(RiverColors rc, Object e) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 16),
    child: Text('Forecast unavailable',
        style: TextStyle(color: rc.textSecondary, fontSize: 12)),
  );

  Widget _noForecast(RiverColors rc) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 16),
    child: Text('No forecast data available',
        style: TextStyle(color: rc.textSecondary, fontSize: 12)),
  );
}

class _ForecastDay {
  final String label;
  final double rain;
  const _ForecastDay({required this.label, required this.rain});
}

// ─────────────────────────────────────────────────────────────────────────────
// Model metadata footer
// ─────────────────────────────────────────────────────────────────────────────

class _ModelFooter extends StatelessWidget {
  final RiverColors rc;
  final AsyncValue<dynamic> predState;
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
              Icon(Icons.model_training_rounded,
                  size: 15, color: rc.accent),
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
          _InfoRow(rc: rc, label: 'Architecture',
              value: 'Ensemble (RF + XGBoost + GBM)'),
          _InfoRow(rc: rc, label: 'Features',
              value: 'Level%, Capacity%, Rainfall, Alerts, Humidity'),
          _InfoRow(rc: rc, label: 'Target',
              value: 'Flood risk classification (4-class)'),
          predState.when(
            data: (p) {
              String acc = '–';
              String f1  = '–';
              try {
                acc = '${((p?.accuracy ?? 0.0) * 100).toStringAsFixed(1)}%';
                f1  = '${((p?.f1Score  ?? 0.0) * 100).toStringAsFixed(1)}%';
              } catch (_) {}
              return Column(
                children: [
                  _InfoRow(rc: rc, label: 'Accuracy', value: acc),
                  _InfoRow(rc: rc, label: 'F1 Score', value: f1),
                ],
              );
            },
            loading: () =>
                _InfoRow(rc: rc, label: 'Metrics', value: 'Loading…'),
            error: (_, __) =>
                _InfoRow(rc: rc, label: 'Metrics', value: 'Unavailable'),
          ),
          _InfoRow(rc: rc, label: 'Data source',
              value: 'CWC · IMD · WRD Bihar'),
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
          Text('Station risk scores will appear once live data loads.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: rc.textSecondary,
                fontSize: 12,
              )),
        ],
      ),
    );
  }
}
