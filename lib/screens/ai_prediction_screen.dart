// lib/screens/ai_prediction_screen.dart
// OpsFlood — AI Prediction Screen  (million-dollar rewrite)
//
// DATA: consumes AiInsight from aiInsightProvider which fuses:
//   WRD Bihar scraper · CWC befiqr · Kosi Birpur real-time ·
//   Open-Meteo weather · LSTM/ensemble ML backend · CWC alert watcher
//
// UI highlights:
//   _HeroCard       — glass-morphism verdict with animated risk ring + source pills
//   _ConfidenceGauge — arc-progress gauge (replaces flat bar)
//   _SourceStrip    — live/offline health pills for every data source
//   _RiverTrendList — per-river velocity + danger% with trend arrow
//   _DriverGrid     — 2×2 responsive grid (no overflow on small screens)
//   _ForecastBars   — 7-day animated rainfall bars with flood threshold line
//   _ModelFooter    — full model metadata + last-fetch timestamp
//
// All colors via RiverColors.of(context) + AppPalette semantic tokens.
// All fonts ≥ 11px (accessibility floor).
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../providers/ai_insight_provider.dart';
import '../theme/river_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Risk color/label helpers
// ─────────────────────────────────────────────────────────────────────────────

Color _riskColor(String risk, {bool dark = false}) {
  switch (risk.toUpperCase()) {
    case 'EXTREME': return dark ? AppPalette.danger.withValues(alpha: 0.85)  : AppPalette.danger;
    case 'HIGH':    return dark ? AppPalette.warning.withValues(alpha: 0.85) : AppPalette.warning;
    case 'MODERATE':return dark ? AppPalette.amber.withValues(alpha: 0.85)   : AppPalette.amber;
    case 'LOADING': return AppPalette.textDim;
    default:        return dark ? AppPalette.safe.withValues(alpha: 0.85)    : AppPalette.safe;
  }
}

String _riskEmoji(String risk) {
  switch (risk.toUpperCase()) {
    case 'EXTREME':  return '🔴';
    case 'HIGH':     return '🟠';
    case 'MODERATE': return '🟡';
    case 'LOADING':  return '⏳';
    default:         return '🟢';
  }
}

String _riskFullLabel(String risk) {
  switch (risk.toUpperCase()) {
    case 'EXTREME':  return 'EXTREME FLOOD RISK';
    case 'HIGH':     return 'HIGH FLOOD RISK';
    case 'MODERATE': return 'MODERATE RISK';
    case 'LOADING':  return 'LOADING DATA…';
    default:         return 'LOW / SAFE';
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

class _AiPredictionScreenState
    extends ConsumerState<AiPredictionScreen>
    with AutomaticKeepAliveClientMixin, TickerProviderStateMixin {
  @override
  bool get wantKeepAlive => true;

  late final AnimationController _entryCtrl;
  late final AnimationController _pulseCtrl;
  late final AnimationController _barCtrl;
  late final AnimationController _ringCtrl;

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
    _ringCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1600));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _entryCtrl.forward();
      _barCtrl.forward();
      _ringCtrl.forward();
    });
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    _pulseCtrl.dispose();
    _barCtrl.dispose();
    _ringCtrl.dispose();
    super.dispose();
  }

  void _refresh() {
    HapticFeedback.selectionClick();
    ref.invalidate(aiInsightProvider);
    _barCtrl ..reset() ..forward();
    _ringCtrl ..reset() ..forward();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final rc      = RiverColors.of(context);
    final insight = ref.watch(aiInsightProvider);

    return Scaffold(
      backgroundColor: rc.scaffoldBg,
      body: insight.when(
        data:    (data) => _body(rc, data),
        loading: () => _body(rc, AiInsight.empty()),
        error:   (_, __) => _body(rc, AiInsight.empty()),
      ),
    );
  }

  Widget _body(RiverColors rc, AiInsight data) {
    final riskColor = _riskColor(data.overallRisk);
    final isLoading = data.overallRisk == 'LOADING';

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        // ── App bar ─────────────────────────────────────────────────────
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
                  width: 34, height: 34,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: riskColor.withValues(
                        alpha: 0.10 + _pulseCtrl.value * 0.08),
                    border: Border.all(
                      color: riskColor.withValues(
                          alpha: 0.4 + _pulseCtrl.value * 0.3),
                      width: 1.5,
                    ),
                  ),
                  child: Icon(Icons.psychology_rounded,
                      size: 18, color: riskColor),
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('AI Flood Intelligence',
                      style: TextStyle(
                        color: rc.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      )),
                  Text(
                    isLoading
                        ? 'Fusing data sources…'
                        : 'Live · ${data.stationCount} stations · ${DateFormat("HH:mm").format(data.lastFetched)}',
                    style:
                        TextStyle(color: rc.textSecondary, fontSize: 11),
                  ),
                ],
              ),
              const Spacer(),
              IconButton(
                onPressed: _refresh,
                icon: Icon(Icons.refresh_rounded,
                    size: 20, color: rc.textSecondary),
                tooltip: 'Refresh all sources',
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
                offset: Offset(0, 24 * (1 - _entryCtrl.value)),
                child: child,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Hero verdict card ──────────────────────────────────
                  _HeroCard(
                    rc:         rc,
                    data:       data,
                    riskColor:  riskColor,
                    pulseCtrl:  _pulseCtrl,
                    ringCtrl:   _ringCtrl,
                  ),
                  const SizedBox(height: 12),

                  // ── Source health strip ───────────────────────────────
                  _SourceStrip(rc: rc, sources: data.sources),
                  const SizedBox(height: 16),

                  // ── Driver grid ───────────────────────────────────────
                  _SectionHeader(
                      rc: rc,
                      icon: Icons.input_rounded,
                      label: 'LIVE MODEL INPUTS'),
                  const SizedBox(height: 8),
                  _DriverGrid(rc: rc, data: data),
                  const SizedBox(height: 16),

                  // ── River trends ──────────────────────────────────────
                  if (data.riverTrends.isNotEmpty) ...[
                    _SectionHeader(
                        rc: rc,
                        icon: Icons.waves_rounded,
                        label: 'RIVER VELOCITY TRENDS'),
                    const SizedBox(height: 8),
                    _RiverTrendList(rc: rc, trends: data.riverTrends),
                    const SizedBox(height: 16),
                  ],

                  // ── Station scores header ─────────────────────────────
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

        // ── Station list ───────────────────────────────────────────────
        if (data.stations.isEmpty)
          SliverToBoxAdapter(child: _EmptyStations(rc: rc))
        else
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (ctx, i) {
                final s     = data.stations[i];
                final score = _stationScore(s);
                return _StationRiskRow(
                  rc:        rc,
                  data:      s,
                  index:     i,
                  entryCtrl: _entryCtrl,
                  riskScore: score,
                );
              },
              childCount: data.stations.length,
            ),
          ),

        // ── Forecast + footer ─────────────────────────────────────────
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
                  _ForecastBars(
                      rc: rc, data: data, barCtrl: _barCtrl),
                  const SizedBox(height: 16),
                  _ModelFooter(rc: rc, data: data),
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Station risk score (inline — no external provider needed)
// ─────────────────────────────────────────────────────────────────────────────

double _stationScore(d) {
  final cap  = (d.capacityPercent as double).clamp(0.0, 100.0);
  final lvl  = (d.dangerLevel as double) > 0
      ? ((d.currentLevel as double) / (d.dangerLevel as double) * 100)
          .clamp(0.0, 100.0)
      : cap;
  final rain =
      ((d.effectiveRainfallMm as double) / 60.0 * 100).clamp(0.0, 100.0);
  return lvl * 0.4 + cap * 0.4 + rain * 0.2;
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
        Icon(icon, size: 14, color: rc.accent),
        const SizedBox(width: 6),
        Text(label,
            style: TextStyle(
              color: rc.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.0,
            )),
        const SizedBox(width: 8),
        Expanded(
            child: Divider(color: rc.stroke, thickness: 1, height: 1)),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Hero card — glass-morphism verdict
// ─────────────────────────────────────────────────────────────────────────────

class _HeroCard extends StatelessWidget {
  final RiverColors rc;
  final AiInsight data;
  final Color riskColor;
  final AnimationController pulseCtrl;
  final AnimationController ringCtrl;

  const _HeroCard({
    required this.rc,
    required this.data,
    required this.riskColor,
    required this.pulseCtrl,
    required this.ringCtrl,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: rc.cardBg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
            color: riskColor.withValues(alpha: 0.30), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: riskColor.withValues(alpha: 0.07),
            blurRadius: 24,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // ── Risk ring gauge ─────────────────────────────────────
              _ConfidenceRing(
                rc:        rc,
                riskColor: riskColor,
                emoji:     _riskEmoji(data.overallRisk),
                value:     data.confidence / 100,
                ctrl:      ringCtrl,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_riskFullLabel(data.overallRisk),
                        style: TextStyle(
                          color: riskColor,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.4,
                        )),
                    const SizedBox(height: 3),
                    Text(
                      '${data.stationCount} stations · '
                      '${data.criticalCount} critical · '
                      '${data.alertCount} alerts',
                      style: TextStyle(
                        color: rc.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Confidence ${data.confidence.round()}%'  
                      ' · v${data.modelVersion}',
                      style: TextStyle(
                        color: rc.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              // ── LIVE badge ──────────────────────────────────────────
              AnimatedBuilder(
                animation: pulseCtrl,
                builder: (_, __) => Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppPalette.safe.withValues(
                        alpha: 0.10 + pulseCtrl.value * 0.06),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: AppPalette.safe.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 7, height: 7,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppPalette.safe,
                          boxShadow: [
                            BoxShadow(
                              color: AppPalette.safe.withValues(
                                  alpha: 0.7 * pulseCtrl.value),
                              blurRadius: 7,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text('LIVE',
                          style: TextStyle(
                            color: AppPalette.safe,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                          )),
                    ],
                  ),
                ),
              ),
            ],
          ),

          if (data.kosiLevel > 0) ...[
            const SizedBox(height: 14),
            _KosiGaugeBar(rc: rc, data: data),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Confidence ring (arc progress gauge)
// ─────────────────────────────────────────────────────────────────────────────

class _ConfidenceRing extends StatelessWidget {
  final RiverColors rc;
  final Color riskColor;
  final String emoji;
  final double value;    // 0–1
  final AnimationController ctrl;

  const _ConfidenceRing({
    required this.rc,
    required this.riskColor,
    required this.emoji,
    required this.value,
    required this.ctrl,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 68, height: 68,
      child: AnimatedBuilder(
        animation: ctrl,
        builder: (_, __) => CustomPaint(
          painter: _RingPainter(
            value:     (value * ctrl.value).clamp(0, 1),
            trackColor: rc.stroke,
            fillColor:  riskColor,
            strokeWidth: 6,
          ),
          child: Center(
            child: Text(emoji, style: const TextStyle(fontSize: 26)),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double value;
  final Color trackColor;
  final Color fillColor;
  final double strokeWidth;

  const _RingPainter({
    required this.value,
    required this.trackColor,
    required this.fillColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r  = (size.width - strokeWidth) / 2;
    const startAngle = -math.pi / 2;
    const fullSweep  = 2 * math.pi;

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = trackColor
      ..strokeCap = StrokeCap.round;
    final fill = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = fillColor
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: r),
        startAngle, fullSweep, false, track);
    canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: r),
        startAngle, fullSweep * value, false, fill);
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.value != value || old.fillColor != fillColor;
}

// ─────────────────────────────────────────────────────────────────────────────
// Kosi gauge bar (special highlight for Bihar's most critical river)
// ─────────────────────────────────────────────────────────────────────────────

class _KosiGaugeBar extends StatelessWidget {
  final RiverColors rc;
  final AiInsight data;
  const _KosiGaugeBar({required this.rc, required this.data});

  @override
  Widget build(BuildContext context) {
    final pct = (data.kosiLevel / data.kosiDanger).clamp(0.0, 1.2);
    final col = pct > 1.0
        ? AppPalette.danger
        : pct > 0.8
            ? AppPalette.warning
            : AppPalette.safe;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.water_rounded, size: 13, color: col),
            const SizedBox(width: 5),
            Text('Kosi @ Birpur',
                style: TextStyle(
                  color: rc.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                )),
            const Spacer(),
            Text(
              '${data.kosiLevel.toStringAsFixed(2)}m'
              ' / ${data.kosiDanger.toStringAsFixed(2)}m danger',
              style: TextStyle(
                color: col,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pct.clamp(0.0, 1.0),
            minHeight: 6,
            backgroundColor: rc.stroke,
            valueColor: AlwaysStoppedAnimation<Color>(col),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Source health strip
// ─────────────────────────────────────────────────────────────────────────────

class _SourceStrip extends StatelessWidget {
  final RiverColors rc;
  final Map<String, DataSourceHealth> sources;
  const _SourceStrip({required this.rc, required this.sources});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: sources.entries.map((e) {
        final isLive = e.value == DataSourceHealth.live;
        final col    = isLive ? AppPalette.safe : rc.textSecondary;
        return Expanded(
          child: Container(
            margin: const EdgeInsets.only(right: 6),
            padding: const EdgeInsets.symmetric(vertical: 7),
            decoration: BoxDecoration(
              color: col.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: col.withValues(alpha: 0.25)),
            ),
            child: Column(
              children: [
                Container(
                  width: 8, height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: col,
                    boxShadow: isLive
                        ? [
                            BoxShadow(
                              color: col.withValues(alpha: 0.5),
                              blurRadius: 6,
                              spreadRadius: 1,
                            )
                          ]
                        : null,
                  ),
                ),
                const SizedBox(height: 3),
                Text(e.key,
                    style: TextStyle(
                      color: col,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.4,
                    )),
                Text(isLive ? 'LIVE' : 'OFF',
                    style: TextStyle(
                      color: col.withValues(alpha: 0.7),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    )),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Driver grid (2×2 — no overflow on small screens)
// ─────────────────────────────────────────────────────────────────────────────

class _DriverGrid extends StatelessWidget {
  final RiverColors rc;
  final AiInsight data;
  const _DriverGrid({required this.rc, required this.data});

  @override
  Widget build(BuildContext context) {
    final avgCap = data.stations.isEmpty
        ? 0.0
        : data.stations
                .map((d) => d.capacityPercent)
                .reduce((a, b) => a + b) /
            data.stations.length;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _DriverTile(
                rc: rc,
                icon: Icons.water_rounded,
                label: 'Avg Capacity',
                value: '${avgCap.toStringAsFixed(1)}%',
                sub: '${data.criticalCount} critical',
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
                label: 'Rainfall Now',
                value: '${data.rainfallNow.toStringAsFixed(1)} mm',
                sub: 'current hour',
                color: data.rainfallNow > 30
                    ? AppPalette.danger
                    : data.rainfallNow > 10
                        ? AppPalette.warning
                        : AppPalette.safe,
                fraction: (data.rainfallNow / 60).clamp(0, 1),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _DriverTile(
                rc: rc,
                icon: Icons.notifications_active_rounded,
                label: 'CWC Alerts',
                value: '${data.alertCount}',
                sub: 'active now',
                color: data.alertCount >= 5
                    ? AppPalette.danger
                    : data.alertCount >= 2
                        ? AppPalette.warning
                        : AppPalette.safe,
                fraction: (data.alertCount / 10.0).clamp(0, 1),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _DriverTile(
                rc: rc,
                icon: Icons.thermostat_rounded,
                label: 'Temp / Humid',
                value: '${data.tempC.toStringAsFixed(1)}°C',
                sub: '${data.humidity.round()}% RH',
                color: data.humidity > 85
                    ? AppPalette.warning
                    : AppPalette.safe,
                fraction: (data.humidity / 100).clamp(0, 1),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _DriverTile extends StatelessWidget {
  final RiverColors rc;
  final IconData icon;
  final String label, value, sub;
  final Color color;
  final double fraction;

  const _DriverTile({
    required this.rc,
    required this.icon,
    required this.label,
    required this.value,
    required this.sub,
    required this.color,
    required this.fraction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: rc.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: rc.stroke),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(height: 7),
          Text(value,
              style: TextStyle(
                color: rc.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w900,
                fontFeatures: const [FontFeature.tabularFigures()],
              )),
          Text(label,
              style: TextStyle(
                color: rc.textSecondary,
                fontSize: 11,
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
          const SizedBox(height: 4),
          Text(sub,
              style: TextStyle(
                color: rc.textSecondary,
                fontSize: 11,
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
// River trend list
// ─────────────────────────────────────────────────────────────────────────────

class _RiverTrendList extends StatelessWidget {
  final RiverColors rc;
  final List<RiverTrend> trends;
  const _RiverTrendList({required this.rc, required this.trends});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: rc.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: rc.stroke),
      ),
      child: Column(
        children: trends.asMap().entries.map((e) {
          final i     = e.key;
          final trend = e.value;
          final pct   = trend.dangerPct;
          final col   = pct > 90
              ? AppPalette.danger
              : pct > 70
                  ? AppPalette.warning
                  : AppPalette.safe;
          final rising = trend.velocityMperHr >= 0;
          return Container(
            decoration: BoxDecoration(
              border: i < trends.length - 1
                  ? Border(bottom: BorderSide(color: rc.stroke, width: 1))
                  : null,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            child: Row(
              children: [
                Container(
                    width: 9, height: 9,
                    decoration:
                        BoxDecoration(shape: BoxShape.circle, color: col)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(trend.river,
                          style: TextStyle(
                            color: rc.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          )),
                      Text(trend.station,
                          style: TextStyle(
                              color: rc.textSecondary, fontSize: 11)),
                    ],
                  ),
                ),
                // Velocity chip
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: (rising ? AppPalette.warning : AppPalette.safe)
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: (rising ? AppPalette.warning : AppPalette.safe)
                          .withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    '${rising ? "▲" : "▼"} '  
                    '${trend.velocityMperHr.abs().toStringAsFixed(2)} m/hr',
                    style: TextStyle(
                      color:
                          rising ? AppPalette.warning : AppPalette.safe,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 44,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('${pct.toStringAsFixed(0)}%',
                          style: TextStyle(
                            color: col,
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            fontFeatures: const [
                              FontFeature.tabularFigures()
                            ],
                          )),
                      Text('danger',
                          style: TextStyle(
                              color: rc.textSecondary, fontSize: 10)),
                    ],
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Station risk row
// ─────────────────────────────────────────────────────────────────────────────

class _StationRiskRow extends StatelessWidget {
  final RiverColors rc;
  final dynamic data;     // FloodData
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
    final risk = (data.riskLevel as String).toUpperCase();
    final col  = _riskColor(risk);
    final lvl  = data.currentLevel as double;
    final dng  = data.dangerLevel  as double;

    return AnimatedBuilder(
      animation: entryCtrl,
      builder: (_, child) {
        final delay = (index * 0.04).clamp(0.0, 0.7);
        final p =
            ((entryCtrl.value - delay) / (1.0 - delay)).clamp(0.0, 1.0);
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
          border: Border.all(color: col.withValues(alpha: 0.20)),
        ),
        child: Row(
          children: [
            Container(
              width: 10, height: 10,
              margin: const EdgeInsets.only(right: 10),
              decoration: BoxDecoration(shape: BoxShape.circle, color: col),
            ),
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(data.city as String,
                      style: TextStyle(
                        color: rc.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  Text(
                    '${(data.riverName ?? data.district) as String}'  
                    '  ${lvl.toStringAsFixed(2)}m / ${dng.toStringAsFixed(2)}m',
                    style: TextStyle(
                        color: rc.textSecondary, fontSize: 11),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
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
                              color: rc.textSecondary, fontSize: 11)),
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
              padding:
                  const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
              decoration: BoxDecoration(
                color: col.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(_shortRisk(risk),
                  style: TextStyle(
                    color: col,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.3,
                  )),
            ),
          ],
        ),
      ),
    );
  }

  String _shortRisk(String r) {
    switch (r) {
      case 'EXTREME':
      case 'CRITICAL': return 'EXT';
      case 'HIGH':
      case 'SEVERE':   return 'HIGH';
      case 'MODERATE': return 'MOD';
      default:         return 'LOW';
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 7-day forecast bars with flood threshold line
// ─────────────────────────────────────────────────────────────────────────────

class _ForecastBars extends StatelessWidget {
  final RiverColors rc;
  final AiInsight data;
  final AnimationController barCtrl;

  const _ForecastBars(
      {required this.rc, required this.data, required this.barCtrl});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: rc.cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: rc.stroke),
      ),
      child: Column(
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
              Text(
                '7 days · total ${data.forecastRainTotal.toStringAsFixed(0)} mm',
                style: TextStyle(color: rc.textSecondary, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 12),
          data.forecast.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text('Weather forecast loading…',
                        style: TextStyle(
                            color: rc.textSecondary, fontSize: 12)),
                  ),
                )
              : _bars(context),
        ],
      ),
    );
  }

  Widget _bars(BuildContext context) {
    final days   = data.forecast.take(7).toList();
    final maxRain =
        days.map((d) => d.rainMm).reduce(math.max).clamp(1.0, double.infinity);
    const threshold    = 30.0;
    final thresholdFrac = (threshold / maxRain).clamp(0.0, 1.0);

    // Bar budget inside SizedBox(height: 90):
    //   rain label  ≈ 14px  (fontSize 10 + line-height)
    //   SizedBox(2) =  2px
    //   bar          ≤ 56px  ← was 60, reduced to guarantee fit
    //   SizedBox(4) =  4px
    //   day label   ≈ 14px
    //   total       = 90px  ✓
    const double _kBarMax = 56.0;
    const double _kBarMin =  2.0;

    return AnimatedBuilder(
      animation: barCtrl,
      builder: (_, __) => SizedBox(
        height: 90,
        child: Stack(
          children: [
            // Threshold line
            if (maxRain > threshold)
              Positioned(
                bottom: 18 + (1 - thresholdFrac) * _kBarMax,
                left: 0, right: 0,
                child: Row(
                  children: [
                    Expanded(
                      child: DashedLine(
                          color: AppPalette.warning.withValues(alpha: 0.5)),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Text('30mm',
                          style: TextStyle(
                            color: AppPalette.warning,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          )),
                    ),
                  ],
                ),
              ),
            // Bars row
            Positioned.fill(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: days.map((d) {
                  final frac =
                      (d.rainMm / maxRain * barCtrl.value).clamp(0.0, 1.0);
                  final col = d.rainMm > 30
                      ? AppPalette.danger
                      : d.rainMm > 15
                          ? AppPalette.warning
                          : rc.accent;
                  String dayLabel = '–';
                  try {
                    dayLabel =
                        DateFormat('E').format(DateTime.parse(d.date));
                  } catch (_) {}

                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text('${d.rainMm.round()}',
                              style: TextStyle(
                                color: rc.textSecondary,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              )),
                          const SizedBox(height: 2),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: Container(
                              // FIX: was 60 * frac + 4 — exceeded 90px slot.
                              // Now capped at 56px max + 2px min.
                              height: _kBarMax * frac + _kBarMin,
                              color: col,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(dayLabel,
                              style: TextStyle(
                                color: rc.textSecondary,
                                fontSize: 10,
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
        ),
      ),
    );
  }
}

/// Simple dashed horizontal line widget
class DashedLine extends StatelessWidget {
  final Color color;
  const DashedLine({required this.color, super.key});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(double.infinity, 1),
      painter: _DashedLinePainter(color: color),
    );
  }
}

class _DashedLinePainter extends CustomPainter {
  final Color color;
  const _DashedLinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    double x = 0;
    while (x < size.width) {
      canvas.drawLine(Offset(x, 0), Offset(x + 4, 0), paint);
      x += 8;
    }
  }

  @override
  bool shouldRepaint(_DashedLinePainter old) => old.color != color;
}

// ─────────────────────────────────────────────────────────────────────────────
// Model metadata footer
// ─────────────────────────────────────────────────────────────────────────────

class _ModelFooter extends StatelessWidget {
  final RiverColors rc;
  final AiInsight data;
  const _ModelFooter({required this.rc, required this.data});

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd MMM HH:mm');
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
              Text('Model & Data Info',
                  style: TextStyle(
                    color: rc.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  )),
            ],
          ),
          const SizedBox(height: 10),
          _Row(rc: rc, label: 'Architecture',
              value: 'RF + XGBoost + GBM ensemble'),
          _Row(rc: rc, label: 'Features',
              value: 'Level%, Capacity%, Rainfall, Alerts, Humidity, Kosi'),
          _Row(rc: rc, label: 'Target',
              value: '4-class flood risk (LOW/MOD/HIGH/EXTREME)'),
          _Row(rc: rc, label: 'Model ver',
              value: data.modelVersion),
          _Row(rc: rc, label: 'ML confidence',
              value: data.mlConfidence > 0
                  ? '${data.mlConfidence.toStringAsFixed(1)}%'
                  : '–'),
          _Row(rc: rc, label: 'Backend',
              value: data.mlBackendLive ? 'LSTM online' : 'CWC-sim fallback'),
          _Row(rc: rc, label: 'Data sources',
              value: 'CWC · WRD Bihar · Kosi Birpur · Open-Meteo · OpsFlood API'),
          _Row(rc: rc, label: 'Last fetched',
              value: fmt.format(data.lastFetched)),
          const SizedBox(height: 4),
          // Source health summary
          Row(
            children: data.sources.entries.map((e) {
              final live = e.value == DataSourceHealth.live;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text(
                  '${e.key} ${live ? "✓" : "✗"}',
                  style: TextStyle(
                    color: live ? AppPalette.safe : rc.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final RiverColors rc;
  final String label, value;
  const _Row({required this.rc, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
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
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: rc.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: rc.stroke),
      ),
      child: Column(
        children: [
          Icon(Icons.sensors_off_rounded,
              size: 40, color: rc.textSecondary),
          const SizedBox(height: 10),
          Text('No station data yet',
              style: TextStyle(
                color: rc.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              )),
          const SizedBox(height: 6),
          Text(
            'Station risk scores will appear once WRD Bihar\nand CWC live data loads.',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: rc.textSecondary, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
