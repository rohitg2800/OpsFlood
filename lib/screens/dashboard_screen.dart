// lib/screens/dashboard_screen.dart
// OpsFlood — DashboardScreen v21  "Command Centre"
// Added: ThemeCycleButton in CommandHeader
library;

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../models/flood_data.dart';
import '../models/river_monitoring.dart';
import '../services/real_time_service.dart';
import '../theme/river_theme.dart';
import '../widgets/ops_area_chart.dart';
import '../widgets/ops_bar_chart.dart';
import '../widgets/premium_theme_sheet.dart';
import '../widgets/risk_heatmap.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with TickerProviderStateMixin {
  final RealTimeService _service = RealTimeService();
  String? _selectedCity;

  late AnimationController _pulseCtrl;
  late AnimationController _arcCtrl;
  late AnimationController _tickerCtrl;
  late AnimationController _shimmerCtrl;
  late Animation<double> _pulseAnim;
  late Animation<double> _arcAnim;
  late Animation<double> _shimmerAnim;

  int _tickerIdx = 0;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1400))
      ..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.3, end: 1.0)
        .animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    _arcCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1800))
      ..forward();
    _arcAnim = CurvedAnimation(parent: _arcCtrl, curve: Curves.easeOutCubic);

    _tickerCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 4))
      ..repeat();
    _tickerCtrl.addStatusListener((s) {
      if (s == AnimationStatus.completed && mounted) {
        final alerts = _alertCities;
        if (alerts.isNotEmpty) {
          setState(() => _tickerIdx = (_tickerIdx + 1) % alerts.length);
        }
        _tickerCtrl.forward(from: 0);
      }
    });

    _shimmerCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2200))
      ..repeat();
    _shimmerAnim = CurvedAnimation(parent: _shimmerCtrl, curve: Curves.linear);

    _service.addListener(_onData);
  }

  void _onData() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _service.removeListener(_onData);
    _pulseCtrl.dispose();
    _arcCtrl.dispose();
    _tickerCtrl.dispose();
    _shimmerCtrl.dispose();
    super.dispose();
  }

  // ── Data helpers ────────────────────────────────────────────────────────
  List<FloodData> get _sorted {
    final list = List<FloodData>.from(_service.liveLevels);
    list.sort((a, b) {
      final cmp = b.priorityOrder.compareTo(a.priorityOrder);
      return cmp != 0 ? cmp : b.capacityPercent.compareTo(a.capacityPercent);
    });
    return list;
  }

  int get _criticalCount  => _sorted.where((d) => d.riskLevel == 'CRITICAL').length;
  int get _severeCount    => _sorted.where((d) => d.riskLevel == 'SEVERE').length;
  int get _moderateCount  => _sorted.where((d) => d.riskLevel == 'MODERATE').length;
  int get _safeCount      => _sorted.where((d) => d.riskLevel == 'LOW').length;

  double get _overallRisk {
    if (_sorted.isEmpty) return 0;
    final w = _sorted.map((d) => d.capacityPercent).fold(0.0, (a, b) => a + b);
    return (w / _sorted.length).clamp(0, 100);
  }

  List<FloodData> get _alertCities =>
      _sorted.where((d) =>
          d.riskLevel == 'CRITICAL' || d.riskLevel == 'SEVERE').toList();

  FloodData? get _selectedData {
    if (_selectedCity == null) return null;
    try { return _sorted.firstWhere((d) => d.city == _selectedCity); }
    catch (_) { return null; }
  }

  // ── Build ───────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final data = _sorted;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppPalette.abyss0,
        body: SafeArea(
          bottom: false,
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // ── Command header
              SliverToBoxAdapter(child: _CommandHeader(
                pulseAnim:   _pulseAnim,
                shimmerAnim: _shimmerAnim,
                onRefresh:   () {
                  HapticFeedback.mediumImpact();
                  _arcCtrl.forward(from: 0);
                  _service.refreshData();
                },
                lastUpdated: _service.lastFetchTime,
              )),

              // ── Hero Arc Gauge + Bento KPI grid
              SliverToBoxAdapter(child: _HeroSection(
                arcAnim:       _arcAnim,
                overallRisk:   _overallRisk,
                critical:      _criticalCount,
                severe:        _severeCount,
                moderate:      _moderateCount,
                safe:          _safeCount,
                total:         data.length,
                alertCities:   _alertCities,
                tickerIdx:     _tickerIdx,
                pulseAnim:     _pulseAnim,
              )),

              if (data.isEmpty) ...
                [SliverToBoxAdapter(child: _EmptyState())]
              else ...[
                SliverToBoxAdapter(child: _SectionHeader(
                  title: 'Live River Status',
                  sub:   '${data.length} stations monitored',
                  icon:  Icons.water_rounded,
                  color: AppPalette.cyan,
                )),
                SliverToBoxAdapter(child: _RiverPulseList(
                  data:      data.take(8).toList(),
                  selected:  _selectedCity ?? (data.isNotEmpty ? data.first.city : null),
                  onSelect:  (c) => setState(() => _selectedCity = c),
                  pulseAnim: _pulseAnim,
                )),

                SliverToBoxAdapter(child: _SectionHeader(
                  title:    'River Level Trend',
                  sub:      _selectedCity ?? (data.isNotEmpty ? data.first.city : ''),
                  icon:     Icons.show_chart_rounded,
                  color:    AppPalette.cyan,
                )),
                SliverToBoxAdapter(child: _TrendCard(
                  service:  _service,
                  selected: _selectedData ?? (data.isNotEmpty ? data.first : null),
                )),

                SliverToBoxAdapter(child: _SectionHeader(
                  title: 'Capacity Overview',
                  sub:   'Top 8 by flood fill %',
                  icon:  Icons.bar_chart_rounded,
                  color: AppPalette.amber,
                )),
                SliverToBoxAdapter(child: _CapacityChart(data: data.take(8).toList())),

                SliverToBoxAdapter(child: _SectionHeader(
                  title: 'State Risk Heatmap',
                  sub:   'Region-level flood index',
                  icon:  Icons.grid_view_rounded,
                  color: AppPalette.safe,
                )),
                SliverToBoxAdapter(child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: RiskHeatmap(entries: _buildHeatmapEntries(data)),
                )),
              ],

              const SliverToBoxAdapter(child: SizedBox(height: 40)),
            ],
          ),
        ),
      ),
    );
  }

  List<RiskHeatmapEntry> _buildHeatmapEntries(List<FloodData> data) {
    final stateMap = <String, Map<String, int>>{};
    for (final d in data) {
      stateMap.putIfAbsent(d.state, () => {});
      final level = _capToLevel(d.capacityPercent);
      stateMap[d.state]![level] = (stateMap[d.state]![level] ?? 0) + 1;
    }
    return stateMap.entries.map((e) {
      final dom = e.value.entries.reduce((a, b) => a.value >= b.value ? a : b);
      return RiskHeatmapEntry(
        state: e.key, level: dom.key,
        count: e.value.values.fold(0, (s, v) => s + v),
      );
    }).toList()
      ..sort((a, b) {
        const o = ['CRITICAL', 'DANGER', 'WARNING', 'SAFE'];
        return o.indexOf(a.level).compareTo(o.indexOf(b.level));
      });
  }

  String _capToLevel(double p) {
    if (p >= 85) return 'CRITICAL';
    if (p >= 60) return 'DANGER';
    if (p >= 35) return 'WARNING';
    return 'SAFE';
  }
}

// ═══════════════════════════════════════════════════════════════════════
// COMMAND HEADER  (with ThemeCycleButton)
// ═══════════════════════════════════════════════════════════════════════
class _CommandHeader extends StatelessWidget {
  final Animation<double> pulseAnim;
  final Animation<double> shimmerAnim;
  final VoidCallback onRefresh;
  final DateTime? lastUpdated;
  const _CommandHeader({
    required this.pulseAnim, required this.shimmerAnim,
    required this.onRefresh, required this.lastUpdated,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
      decoration: BoxDecoration(
        color: AppPalette.abyss0,
        border: Border(
          bottom: BorderSide(
            color: AppPalette.cyan.withValues(alpha: 0.10), width: 1),
        ),
      ),
      child: Row(
        children: [
          // Logo mark
          AnimatedBuilder(
            animation: shimmerAnim,
            builder: (_, __) {
              return Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppPalette.cyan.withValues(alpha: 0.22),
                      AppPalette.cyan.withValues(alpha: 0.06),
                    ],
                  ),
                  border: Border.all(
                    color: AppPalette.cyan.withValues(
                        alpha: 0.20 + 0.15 * shimmerAnim.value),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppPalette.cyan.withValues(
                          alpha: 0.15 * shimmerAnim.value),
                      blurRadius: 16,
                    ),
                  ],
                ),
                child: const Icon(Icons.water_drop_rounded,
                    color: AppPalette.cyan, size: 22),
              );
            },
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShaderMask(
                  shaderCallback: (b) => const LinearGradient(
                    colors: [Color(0xFF00E5FF), Color(0xFF0072FF)],
                  ).createShader(b),
                  child: const Text(
                    'OpsFlood',
                    style: TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w900,
                      color: Colors.white, letterSpacing: -0.8,
                      height: 1.1,
                    ),
                  ),
                ),
                if (lastUpdated != null)
                  Text(
                    'Updated ${_fmt(lastUpdated!)}',
                    style: TextStyle(
                      fontSize: 9.5,
                      color: AppPalette.textGrey.withValues(alpha: 0.65),
                      letterSpacing: 0.2,
                    ),
                  )
                else
                  Text(
                    'Live Flood Intelligence',
                    style: TextStyle(
                      fontSize: 9.5,
                      color: AppPalette.textGrey.withValues(alpha: 0.65),
                    ),
                  ),
              ],
            ),
          ),

          // Live badge
          AnimatedBuilder(
            animation: pulseAnim,
            builder: (_, __) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppPalette.safe.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppPalette.safe
                      .withValues(alpha: 0.25 + 0.20 * pulseAnim.value),
                ),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  width: 6, height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppPalette.safe
                        .withValues(alpha: 0.5 + 0.5 * pulseAnim.value),
                    boxShadow: [
                      BoxShadow(
                        color: AppPalette.safe
                            .withValues(alpha: 0.6 * pulseAnim.value),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 5),
                const Text('LIVE',
                    style: TextStyle(
                      color:      AppPalette.safe,
                      fontSize:   9,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
                    )),
              ]),
            ),
          ),
          const SizedBox(width: 8),

          // ── Theme cycle icon (tap = cycle, long-press = full sheet)
          Tooltip(
            message: 'Hold for theme picker',
            child: GestureDetector(
              onTap:       () => showPremiumThemeSheet(context),
              child: Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color:        AppPalette.abyss2,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppPalette.abyssStroke),
                ),
                child: const Icon(Icons.palette_outlined,
                    color: AppPalette.cyan, size: 18),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Refresh button
          GestureDetector(
            onTap: onRefresh,
            child: Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: AppPalette.abyss2,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: AppPalette.abyssStroke, width: 1),
              ),
              child: const Icon(Icons.refresh_rounded,
                  color: AppPalette.textGrey, size: 18),
            ),
          ),
        ],
      ),
    );
  }

  String _fmt(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    return DateFormat('HH:mm').format(dt.toLocal());
  }
}

// ═══════════════════════════════════════════════════════════════════════
// HERO SECTION — Arc gauge + bento KPI grid + alert ticker
// ═══════════════════════════════════════════════════════════════════════
class _HeroSection extends StatelessWidget {
  final Animation<double> arcAnim;
  final Animation<double> pulseAnim;
  final double  overallRisk;
  final int critical, severe, moderate, safe, total;
  final List<FloodData> alertCities;
  final int tickerIdx;
  const _HeroSection({
    required this.arcAnim, required this.pulseAnim,
    required this.overallRisk, required this.critical,
    required this.severe, required this.moderate, required this.safe,
    required this.total, required this.alertCities, required this.tickerIdx,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ArcGauge(anim: arcAnim, percent: overallRisk, total: total),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(child: _BentoKPI(
                          label: 'CRITICAL', value: '$critical',
                          icon: Icons.crisis_alert_rounded,
                          color: critical > 0 ? AppPalette.critical : AppPalette.textDim,
                          glow: critical > 0,
                        )),
                        const SizedBox(width: 8),
                        Expanded(child: _BentoKPI(
                          label: 'SEVERE', value: '$severe',
                          icon: Icons.warning_rounded,
                          color: severe > 0 ? AppPalette.danger : AppPalette.textDim,
                          glow: severe > 0,
                        )),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(child: _BentoKPI(
                          label: 'MODERATE', value: '$moderate',
                          icon: Icons.warning_amber_rounded,
                          color: moderate > 0 ? AppPalette.warning : AppPalette.textDim,
                        )),
                        const SizedBox(width: 8),
                        Expanded(child: _BentoKPI(
                          label: 'SAFE', value: '$safe',
                          icon: Icons.check_circle_rounded,
                          color: AppPalette.safe,
                        )),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (alertCities.isNotEmpty)
            _AlertTicker(alerts: alertCities, idx: tickerIdx, pulseAnim: pulseAnim)
          else
            _AllClearBanner(),
        ],
      ),
    );
  }
}

// ── Below: all inner widget classes unchanged from v20 ──────────────────────
class _ArcGauge extends StatelessWidget {
  final Animation<double> anim;
  final double percent;
  final int    total;
  const _ArcGauge({required this.anim, required this.percent, required this.total});

  Color get _arcColor {
    if (percent >= 85) return AppPalette.critical;
    if (percent >= 60) return AppPalette.danger;
    if (percent >= 35) return AppPalette.warning;
    return AppPalette.safe;
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 148, height: 148,
      child: AnimatedBuilder(
        animation: anim,
        builder: (_, __) => CustomPaint(
          painter: _ArcPainter(progress: (percent / 100) * anim.value, color: _arcColor),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ShaderMask(
                  shaderCallback: (b) => LinearGradient(
                    colors: [_arcColor, _arcColor.withValues(alpha: 0.6)],
                  ).createShader(b),
                  child: Text(
                    '${(percent * anim.value).toStringAsFixed(0)}%',
                    style: const TextStyle(
                      fontSize: 30, fontWeight: FontWeight.w900,
                      color: Colors.white, letterSpacing: -1.5, height: 1,
                    ),
                  ),
                ),
                const SizedBox(height: 3),
                Text('RISK INDEX', style: TextStyle(
                  fontSize: 7.5,
                  color: AppPalette.textGrey.withValues(alpha: 0.65),
                  fontWeight: FontWeight.w700, letterSpacing: 1.5,
                )),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: _arcColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _arcColor.withValues(alpha: 0.30)),
                  ),
                  child: Text('$total stations', style: TextStyle(
                    fontSize: 8, color: _arcColor, fontWeight: FontWeight.w800,
                  )),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ArcPainter extends CustomPainter {
  final double progress;
  final Color  color;
  _ArcPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r  = size.width * 0.44;
    const startAngle = math.pi * 0.75;
    const sweepMax   = math.pi * 1.5;

    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: r),
      startAngle, sweepMax, false,
      Paint()..color = AppPalette.abyss4
             ..style = PaintingStyle.stroke
             ..strokeWidth = 9
             ..strokeCap = StrokeCap.round,
    );

    if (progress > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: r),
        startAngle, sweepMax * progress, false,
        Paint()..color = color.withValues(alpha: 0.25)
               ..style = PaintingStyle.stroke
               ..strokeWidth = 16
               ..strokeCap = StrokeCap.round
               ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
      final rect = Rect.fromCircle(center: Offset(cx, cy), radius: r);
      canvas.drawArc(
        rect, startAngle, sweepMax * progress, false,
        Paint()..shader = SweepGradient(
                    startAngle: startAngle,
                    endAngle:   startAngle + sweepMax * progress,
                    colors: [color.withValues(alpha: 0.5), color],
                  ).createShader(rect)
               ..style = PaintingStyle.stroke
               ..strokeWidth = 9
               ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_ArcPainter old) =>
      old.progress != progress || old.color != color;
}

class _BentoKPI extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  final bool glow;
  const _BentoKPI({
    required this.label, required this.value,
    required this.icon, required this.color, this.glow = false,
  });
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
    decoration: BoxDecoration(
      color: AppPalette.abyss2,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(
        color: glow ? color.withValues(alpha: 0.35) : AppPalette.abyssStroke,
        width: glow ? 1.5 : 1,
      ),
      boxShadow: glow ? [
        BoxShadow(color: color.withValues(alpha: 0.18), blurRadius: 12, spreadRadius: 1),
      ] : null,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Icon(icon, color: color, size: 14),
          const Spacer(),
          if (glow) Container(
            width: 6, height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle, color: color,
              boxShadow: [BoxShadow(color: color.withValues(alpha: 0.7), blurRadius: 6)],
            ),
          ),
        ]),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(
          fontSize: 24, fontWeight: FontWeight.w900,
          color: glow ? color : AppPalette.textWhite,
          letterSpacing: -1, height: 1,
        )),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(
          fontSize: 8,
          color: glow ? color.withValues(alpha: 0.75) : AppPalette.textDim,
          fontWeight: FontWeight.w700, letterSpacing: 0.8,
        )),
      ],
    ),
  );
}

class _AlertTicker extends StatelessWidget {
  final List<FloodData> alerts;
  final int idx;
  final Animation<double> pulseAnim;
  const _AlertTicker({required this.alerts, required this.idx, required this.pulseAnim});
  @override
  Widget build(BuildContext context) {
    final d   = alerts[idx.clamp(0, alerts.length - 1)];
    final col = d.priorityColor;
    return AnimatedBuilder(
      animation: pulseAnim,
      builder: (_, __) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: col.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: col.withValues(alpha: 0.20 + 0.15 * pulseAnim.value),
            width: 1.5,
          ),
        ),
        child: Row(children: [
          Container(
            width: 8, height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: col.withValues(alpha: 0.5 + 0.5 * pulseAnim.value),
              boxShadow: [
                BoxShadow(
                  color: col.withValues(alpha: 0.7 * pulseAnim.value),
                  blurRadius: 8,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(Icons.crisis_alert_rounded, color: col, size: 14),
          const SizedBox(width: 6),
          Expanded(
            child: RichText(
              overflow: TextOverflow.ellipsis,
              text: TextSpan(
                style: const TextStyle(fontSize: 11),
                children: [
                  TextSpan(
                    text: '${d.riskLevel}  ',
                    style: TextStyle(color: col, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                  ),
                  TextSpan(
                    text: d.city,
                    style: const TextStyle(color: AppPalette.textWhite, fontWeight: FontWeight.w700),
                  ),
                  if (d.district.isNotEmpty)
                    TextSpan(
                      text: '  ·  ${d.district}',
                      style: const TextStyle(color: AppPalette.textGrey, fontWeight: FontWeight.w500),
                    ),
                ],
              ),
            ),
          ),
          Text('${d.currentLevel.toStringAsFixed(1)} m',
              style: TextStyle(color: col, fontSize: 11, fontWeight: FontWeight.w900)),
          const SizedBox(width: 6),
          if (alerts.length > 1)
            Text('${idx + 1}/${alerts.length}',
                style: const TextStyle(color: AppPalette.textDim, fontSize: 9)),
        ]),
      ),
    );
  }
}

class _AllClearBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      color: AppPalette.safe.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppPalette.safe.withValues(alpha: 0.20)),
    ),
    child: const Row(children: [
      Icon(Icons.verified_rounded, color: AppPalette.safe, size: 14),
      SizedBox(width: 8),
      Text('All stations within safe levels',
          style: TextStyle(color: AppPalette.safe, fontSize: 11, fontWeight: FontWeight.w700)),
    ]),
  );
}

class _SectionHeader extends StatelessWidget {
  final String title, sub;
  final IconData icon;
  final Color color;
  const _SectionHeader({required this.title, required this.sub, required this.icon, required this.color});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 22, 16, 12),
    child: Row(
      children: [
        Container(
          width: 3, height: 22,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter, end: Alignment.bottomCenter,
              colors: [color, color.withValues(alpha: 0.2)],
            ),
            borderRadius: BorderRadius.circular(2),
            boxShadow: [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 8)],
          ),
        ),
        const SizedBox(width: 10),
        Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 14),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(
              fontSize: 13, fontWeight: FontWeight.w800,
              color: AppPalette.textWhite, letterSpacing: -0.3,
            )),
            Text(sub, style: TextStyle(
              fontSize: 9.5, color: AppPalette.textGrey.withValues(alpha: 0.7),
            )),
          ],
        ),
      ],
    ),
  );
}

class _RiverPulseList extends StatelessWidget {
  final List<FloodData> data;
  final String? selected;
  final ValueChanged<String> onSelect;
  final Animation<double> pulseAnim;
  const _RiverPulseList({
    required this.data, required this.selected,
    required this.onSelect, required this.pulseAnim,
  });
  @override
  Widget build(BuildContext context) => ListView.builder(
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    itemCount: data.length,
    itemBuilder: (_, i) => _RiverPulseCard(
      data: data[i], isActive: selected == data[i].city,
      onTap: () => onSelect(data[i].city), pulseAnim: pulseAnim,
    ),
  );
}

class _RiverPulseCard extends StatelessWidget {
  final FloodData data;
  final bool isActive;
  final VoidCallback onTap;
  final Animation<double> pulseAnim;
  const _RiverPulseCard({
    required this.data, required this.isActive,
    required this.onTap, required this.pulseAnim,
  });
  @override
  Widget build(BuildContext context) {
    final col     = data.priorityColor;
    final fillPct = (data.capacityPercent / 100).clamp(0.0, 1.0);
    final isCrit  = data.riskLevel == 'CRITICAL' || data.riskLevel == 'SEVERE';
    return GestureDetector(
      onTap: () { HapticFeedback.selectionClick(); onTap(); },
      child: AnimatedBuilder(
        animation: pulseAnim,
        builder: (_, __) => AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: isActive ? col.withValues(alpha: 0.06) : AppPalette.abyss2,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isActive || isCrit
                  ? col.withValues(alpha: isActive ? 0.40 : (0.15 + 0.12 * pulseAnim.value))
                  : AppPalette.abyssStroke,
              width: isActive ? 1.5 : 1,
            ),
            boxShadow: (isActive || isCrit) ? [
              BoxShadow(
                color: col.withValues(alpha: isActive ? 0.14 : 0.06 * pulseAnim.value),
                blurRadius: 18, offset: const Offset(0, 4),
              ),
            ] : null,
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: col.withValues(alpha: 0.10),
                      border: Border.all(
                        color: col.withValues(alpha: isCrit
                            ? 0.20 + 0.20 * pulseAnim.value : 0.25),
                        width: 1.5,
                      ),
                    ),
                    child: Icon(_iconFor(data.riskLevel), color: col, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Flexible(
                            child: Text(data.city,
                                style: const TextStyle(
                                  color: AppPalette.textWhite, fontSize: 14,
                                  fontWeight: FontWeight.w800, letterSpacing: -0.2,
                                ),
                                overflow: TextOverflow.ellipsis),
                          ),
                          const SizedBox(width: 6),
                          _chip(data.riskLevel, col),
                        ]),
                        const SizedBox(height: 2),
                        Text(_subLabel, style: const TextStyle(
                          color: AppPalette.textGrey, fontSize: 10),
                          overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('${data.currentLevel.toStringAsFixed(2)} m',
                          style: TextStyle(
                            color: col, fontSize: 18, fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                          )),
                      Text('${data.capacityPercent.toStringAsFixed(0)}% cap',
                          style: const TextStyle(
                            color: AppPalette.textGrey, fontSize: 9,
                          )),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Stack(
                children: [
                  Container(
                    height: 8,
                    decoration: BoxDecoration(
                      color: AppPalette.abyss4,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  if (data.dangerLevel > 0 && data.warningLevel > 0)
                    Positioned(
                      left: (data.warningLevel / data.dangerLevel).clamp(0.0, 1.0)
                          * (MediaQuery.of(context).size.width - 76),
                      top: 0, bottom: 0,
                      child: Container(
                          width: 2, color: AppPalette.amber.withValues(alpha: 0.7)),
                    ),
                  FractionallySizedBox(
                    widthFactor: fillPct,
                    child: Container(
                      height: 8,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [col.withValues(alpha: 0.45), col],
                        ),
                        borderRadius: BorderRadius.circular(4),
                        boxShadow: [
                          BoxShadow(color: col.withValues(alpha: 0.45), blurRadius: 6),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _miniLabel('W ${data.warningLevel.toStringAsFixed(1)} m', AppPalette.amber),
                  if (data.riverName != null)
                    _miniLabel(data.riverName!, AppPalette.textDim),
                  _miniLabel('D ${data.dangerLevel.toStringAsFixed(1)} m', AppPalette.danger),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
  String get _subLabel {
    final p = <String>[];
    if ((data.riverName ?? '').isNotEmpty) p.add(data.riverName!);
    if (data.district.isNotEmpty)          p.add(data.district);
    if (data.state.isNotEmpty)             p.add(data.state);
    return p.join('  ·  ');
  }
  IconData _iconFor(String r) {
    switch (r) {
      case 'CRITICAL': return Icons.crisis_alert_rounded;
      case 'SEVERE':   return Icons.error_outline_rounded;
      case 'MODERATE': return Icons.warning_amber_rounded;
      default:         return Icons.check_circle_outline_rounded;
    }
  }
  Widget _chip(String label, Color c) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: c.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: c.withValues(alpha: 0.30)),
    ),
    child: Text(label, style: TextStyle(
      color: c, fontSize: 8, fontWeight: FontWeight.w900)),
  );
  Widget _miniLabel(String t, Color c) => Text(t,
      style: TextStyle(color: c, fontSize: 9, fontWeight: FontWeight.w600));
}

class _TrendCard extends StatelessWidget {
  final RealTimeService _service;
  final FloodData? selected;
  const _TrendCard({required RealTimeService service, required this.selected})
      : _service = service;
  @override
  Widget build(BuildContext context) {
    if (selected == null) return const SizedBox.shrink();
    final d   = selected!;
    final col = d.priorityColor;
    final snapshots = _service.trendForCity(d.city);
    final history   = snapshots.map((s) => s.level).toList();
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [col.withValues(alpha: 0.05), AppPalette.abyss2],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: col.withValues(alpha: 0.20), width: 1.5),
        boxShadow: [
          BoxShadow(color: col.withValues(alpha: 0.08), blurRadius: 20, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(d.city, style: const TextStyle(
                color: AppPalette.textWhite, fontSize: 14,
                fontWeight: FontWeight.w800, letterSpacing: -0.3,
              )),
              if (d.district.isNotEmpty)
                Text('${d.riverName ?? ''}  ·  ${d.district}',
                    style: const TextStyle(color: AppPalette.textGrey, fontSize: 10)),
            ]),
            const Spacer(),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('${d.currentLevel.toStringAsFixed(2)} m',
                  style: TextStyle(
                    color: col, fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: -0.8,
                  )),
              Text(d.riskLevel, style: TextStyle(
                color: col, fontSize: 9, fontWeight: FontWeight.w800)),
            ]),
          ]),
          const SizedBox(height: 14),
          if (history.isEmpty)
            Container(
              height: 90, alignment: Alignment.center,
              child: Text('Building trend for ${d.city}…',
                  style: const TextStyle(color: AppPalette.textDim, fontSize: 11)),
            )
          else
            OpsAreaChart(
              values:   history,
              labels:   snapshots.asMap().entries
                  .map((e) => e.key % 4 == 0
                      ? DateFormat('HH:mm').format(snapshots[e.key].timestamp.toLocal())
                      : '')
                  .toList(),
              lineColor: col, warningY: d.warningLevel,
              dangerY: d.dangerLevel, yUnit: ' m', height: 120,
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _LevelPill(
                label: 'Safe', value: '${d.safeLevel.toStringAsFixed(1)} m',
                color: AppPalette.safe,
              )),
              const SizedBox(width: 8),
              Expanded(child: _LevelPill(
                label: 'Warning', value: '${d.warningLevel.toStringAsFixed(1)} m',
                color: AppPalette.amber,
              )),
              const SizedBox(width: 8),
              Expanded(child: _LevelPill(
                label: 'Danger', value: '${d.dangerLevel.toStringAsFixed(1)} m',
                color: AppPalette.critical,
              )),
            ],
          ),
        ],
      ),
    );
  }
}

class _LevelPill extends StatelessWidget {
  final String label, value;
  final Color  color;
  const _LevelPill({required this.label, required this.value, required this.color});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 10),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.07),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: color.withValues(alpha: 0.20)),
    ),
    child: Column(
      children: [
        Text(value, style: TextStyle(
          color: color, fontSize: 11, fontWeight: FontWeight.w800)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(
          color: AppPalette.textDim, fontSize: 8)),
      ],
    ),
  );
}

class _CapacityChart extends StatelessWidget {
  final List<FloodData> data;
  const _CapacityChart({required this.data});
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.fromLTRB(16, 0, 16, 0),
    padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
    decoration: BoxDecoration(
      color: AppPalette.abyss2,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: AppPalette.abyssStroke),
    ),
    child: Column(
      children: [
        OpsBarChart(
          values: data.map((d) => d.capacityPercent.clamp(0.0, 100.0)).toList(),
          labels: data.map((d) => d.city).toList(),
          maxY: 100, yUnit: '%', barWidth: 18, height: 150,
        ),
        const SizedBox(height: 6),
        Row(children: [
          _ldot(AppPalette.safe,     'Safe <35%'),
          const SizedBox(width: 10),
          _ldot(AppPalette.warning,  '35–60%'),
          const SizedBox(width: 10),
          _ldot(AppPalette.danger,   '60–85%'),
          const SizedBox(width: 10),
          _ldot(AppPalette.critical, 'Critical ≥85%'),
        ]),
      ],
    ),
  );
  Widget _ldot(Color c, String t) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 7, height: 7,
        decoration: BoxDecoration(
          shape: BoxShape.circle, color: c,
          boxShadow: [BoxShadow(color: c.withValues(alpha: 0.5), blurRadius: 4)],
        ),
      ),
      const SizedBox(width: 4),
      Text(t, style: const TextStyle(fontSize: 8.5, color: AppPalette.textGrey)),
    ],
  );
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) => SizedBox(
    height: 340,
    child: Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [
                AppPalette.cyan.withValues(alpha: 0.12), AppPalette.abyss2,
              ]),
              border: Border.all(color: AppPalette.cyan.withValues(alpha: 0.20)),
            ),
            child: const Icon(Icons.water_drop_outlined,
                color: AppPalette.cyan, size: 36),
          ),
          const SizedBox(height: 18),
          const Text('Fetching live flood data…', style: TextStyle(
            color: AppPalette.textGrey, fontSize: 14, fontWeight: FontWeight.w700,
          )),
          const SizedBox(height: 6),
          const Text('CWC  •  GloFAS  •  IMD  •  Open-Meteo', style: TextStyle(
            color: AppPalette.textDim, fontSize: 10, letterSpacing: 1.8,
          )),
        ],
      ),
    ),
  );
}
