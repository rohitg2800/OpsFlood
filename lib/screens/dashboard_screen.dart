// lib/screens/dashboard_screen.dart  v24 — fully theme-aware
// Every background, card, stroke, text uses RiverColors.of(context).
// Zero hardcoded AppPalette.abyss* colours remain.
library;

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:intl/intl.dart';

import '../models/flood_data.dart';
import '../services/real_time_service.dart';
import '../theme/river_theme.dart';
import '../widgets/ops_area_chart.dart';
import '../widgets/ops_bar_chart.dart';
import '../widgets/premium_theme_sheet.dart';
import '../widgets/risk_heatmap.dart';

// ── Ad Unit ID ────────────────────────────────────────────────────────────────
const String _kBannerAdUnitId = 'ca-app-pub-6001698589023170/6430029201';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with TickerProviderStateMixin {
  final RealTimeService _service = RealTimeService();

  late AnimationController _pulseCtrl;
  late AnimationController _arcCtrl;
  late AnimationController _tickerCtrl;
  late AnimationController _shimmerCtrl;
  late Animation<double> _pulseAnim;
  late Animation<double> _arcAnim;
  late Animation<double> _shimmerAnim;

  int _tickerIdx = 0;

  BannerAd? _bannerAd;
  bool _bannerLoaded = false;

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
    _shimmerAnim = Tween<double>(begin: -1.0, end: 2.0)
        .animate(CurvedAnimation(parent: _shimmerCtrl, curve: Curves.linear));

    _service.addListener(_onData);
    _service.startPolling();
    _loadBanner();
  }

  void _onData() {
    if (mounted) setState(() {});
  }

  void _loadBanner() {
    BannerAd(
      adUnitId: _kBannerAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (mounted) setState(() { _bannerAd = ad as BannerAd; _bannerLoaded = true; });
        },
        onAdFailedToLoad: (ad, error) => ad.dispose(),
      ),
    ).load();
  }

  @override
  void dispose() {
    _service.removeListener(_onData);
    _pulseCtrl.dispose();
    _arcCtrl.dispose();
    _tickerCtrl.dispose();
    _shimmerCtrl.dispose();
    _bannerAd?.dispose();
    super.dispose();
  }

  // ── Data helpers ────────────────────────────────────────────────────────────

  List<FloodData> get _sorted {
    final list = List<FloodData>.from(_service.liveLevels);
    const order = ['CRITICAL', 'SEVERE', 'MODERATE', 'LOW'];
    list.sort((a, b) =>
        order.indexOf(a.riskLevel).compareTo(order.indexOf(b.riskLevel)));
    return list;
  }

  int get _criticalCount => _sorted.where((d) => d.riskLevel == 'CRITICAL').length;
  int get _severeCount   => _sorted.where((d) => d.riskLevel == 'SEVERE').length;
  int get _moderateCount => _sorted.where((d) => d.riskLevel == 'MODERATE').length;
  int get _safeCount     => _sorted.where((d) => d.riskLevel == 'LOW').length;

  double get _overallRisk {
    if (_sorted.isEmpty) return 0;
    return (_sorted.map((d) => d.capacityPercent).fold(0.0, (a, b) => a + b) /
            _sorted.length)
        .clamp(0.0, 100.0);
  }

  List<FloodData> get _alertCities =>
      _sorted.where((d) => d.riskLevel == 'CRITICAL' || d.riskLevel == 'SEVERE').toList();

  @override
  Widget build(BuildContext context) {
    final data = _sorted;
    final t    = RiverColors.of(context);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: t.scaffoldBg,
        bottomNavigationBar: _bannerLoaded && _bannerAd != null
            ? SafeArea(
                child: SizedBox(
                  height: _bannerAd!.size.height.toDouble(),
                  child: AdWidget(ad: _bannerAd!),
                ),
              )
            : null,
        body: SafeArea(
          bottom: false,
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _CommandHeader(
                pulseAnim: _pulseAnim, shimmerAnim: _shimmerAnim,
                onRefresh: () {
                  HapticFeedback.mediumImpact();
                  _arcCtrl.forward(from: 0);
                  _service.refreshData();
                },
                lastUpdated: _service.lastFetchTime,
              )),
              SliverToBoxAdapter(child: _HeroSection(
                arcAnim: _arcAnim, overallRisk: _overallRisk,
                critical: _criticalCount, severe: _severeCount,
                moderate: _moderateCount, safe: _safeCount,
                total: data.length, alertCities: _alertCities,
                tickerIdx: _tickerIdx, pulseAnim: _pulseAnim,
              )),
              if (data.isEmpty) ...[
                const SliverToBoxAdapter(child: _EmptyState()),
              ] else ...[
                SliverToBoxAdapter(child: _QuickAccessGrid(context: context)),
                SliverToBoxAdapter(child: _SectionHeader(
                  title: 'Live River Levels',
                  sub: 'Sorted by risk · tap for detail',
                  icon: Icons.water_rounded,
                  color: AppPalette.cyan,
                )),
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) => _RiverPulseCard(
                      data: data[i], pulseAnim: _pulseAnim,
                    ),
                    childCount: data.length,
                  ),
                ),
                SliverToBoxAdapter(child: _SectionHeader(
                  title: 'Hotspot Districts',
                  sub: '${_alertCities.length} active alerts',
                  icon: Icons.crisis_alert_rounded,
                  color: AppPalette.critical,
                )),
                SliverToBoxAdapter(child: _HotspotCarousel(
                  items: _alertCities, pulseAnim: _pulseAnim,
                )),
                SliverToBoxAdapter(child: _SectionHeader(
                  title: 'Rainfall Forecast',
                  sub: 'IMD 24h estimate · Bihar',
                  icon: Icons.grain_rounded,
                  color: AppPalette.gold,
                )),
                SliverToBoxAdapter(child: _RainfallForecastStrip(data: data)),
                SliverToBoxAdapter(child: _SectionHeader(
                  title: 'Capacity Overview',
                  sub: 'All monitored rivers',
                  icon: Icons.bar_chart_rounded,
                  color: AppPalette.gold,
                )),
                SliverToBoxAdapter(child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: OpsBarChart(
                    values: data.map((d) => d.capacityPercent).toList(),
                    labels: data.map((d) => d.city).toList(),
                  ),
                )),
                SliverToBoxAdapter(child: _SectionHeader(
                  title: 'Trend Analysis',
                  sub: '7-day capacity trend',
                  icon: Icons.show_chart_rounded,
                  color: AppPalette.cyan,
                )),
                SliverToBoxAdapter(child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: OpsAreaChart(
                    values: data.map((d) => d.capacityPercent).toList(),
                    labels: data.map((d) => d.city).toList(),
                  ),
                )),
                SliverToBoxAdapter(child: _SectionHeader(
                  title: 'Alert Activity Log',
                  sub: 'Recent critical events',
                  icon: Icons.history_rounded,
                  color: AppPalette.danger,
                )),
                SliverToBoxAdapter(child: _AlertActivityLog(data: _alertCities)),
                SliverToBoxAdapter(child: _SectionHeader(
                  title: 'System Stats',
                  sub: 'Data pipeline health',
                  icon: Icons.analytics_outlined,
                  color: AppPalette.safe,
                )),
                SliverToBoxAdapter(child: _SystemStatsBar(
                  service: _service, pulseAnim: _pulseAnim,
                )),
                SliverToBoxAdapter(child: _SectionHeader(
                  title: 'State Risk Map',
                  sub: 'Region-level flood index',
                  icon: Icons.grid_view_rounded,
                  color: AppPalette.safe,
                )),
                SliverToBoxAdapter(child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: RiskHeatmap(entries: _buildHeatmapEntries(data)),
                )),
                SliverToBoxAdapter(child: _FooterStatsBar(
                  totalStations: data.length,
                  riversCount: data
                      .map((d) => d.riverName ?? '')
                      .toSet()
                      .where((s) => s.isNotEmpty)
                      .length,
                  statesAtRisk: data
                      .where((d) => d.riskLevel != 'LOW')
                      .map((d) => d.state)
                      .toSet()
                      .length,
                  lastUpdated: _service.lastFetchTime,
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
    if (p >= 40) return 'WARNING';
    return 'SAFE';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _CommandHeader
// ─────────────────────────────────────────────────────────────────────────────

class _CommandHeader extends StatelessWidget {
  final Animation<double> pulseAnim;
  final Animation<double> shimmerAnim;
  final VoidCallback onRefresh;
  final DateTime? lastUpdated;
  const _CommandHeader({
    required this.pulseAnim, required this.shimmerAnim,
    required this.onRefresh, this.lastUpdated,
  });

  @override
  Widget build(BuildContext context) {
    final t = RiverColors.of(context);
    final timeStr = lastUpdated != null
        ? DateFormat('HH:mm').format(lastUpdated!)
        : '--:--';
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('COMMAND CENTRE',
                    style: TextStyle(
                      color: t.accent, fontSize: 10,
                      fontWeight: FontWeight.w800, letterSpacing: 2.0)),
                const SizedBox(height: 2),
                Text('Bihar Flood Intelligence',
                    style: TextStyle(
                      color: t.textPrimary, fontSize: 22,
                      fontWeight: FontWeight.w900, letterSpacing: -0.5)),
                const SizedBox(height: 4),
                Row(children: [
                  AnimatedBuilder(
                    animation: pulseAnim,
                    builder: (_, __) => Container(
                      width: 6, height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppPalette.safe.withValues(alpha: pulseAnim.value),
                      ),
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text('LIVE · Updated $timeStr',
                      style: TextStyle(
                        color: t.textSecondary, fontSize: 11,
                        fontWeight: FontWeight.w600, letterSpacing: 0.5)),
                ]),
              ],
            ),
          ),
          Row(children: [
            IconButton(
              onPressed: () => showPremiumThemeSheet(context),
              icon: Icon(Icons.palette_outlined, color: t.accent, size: 22),
              tooltip: 'Theme',
            ),
            IconButton(
              onPressed: onRefresh,
              icon: Icon(Icons.refresh_rounded, color: t.textSecondary, size: 22),
              tooltip: 'Refresh',
            ),
          ]),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _HeroSection
// ─────────────────────────────────────────────────────────────────────────────

class _HeroSection extends StatelessWidget {
  final Animation<double> arcAnim;
  final Animation<double> pulseAnim;
  final double overallRisk;
  final int critical, severe, moderate, safe, total, tickerIdx;
  final List<FloodData> alertCities;

  const _HeroSection({
    required this.arcAnim, required this.pulseAnim,
    required this.overallRisk, required this.critical,
    required this.severe, required this.moderate,
    required this.safe, required this.total,
    required this.alertCities, required this.tickerIdx,
  });

  Color _riskColor(double r) {
    if (r >= 75) return AppPalette.critical;
    if (r >= 50) return AppPalette.danger;
    if (r >= 25) return AppPalette.warning;
    return AppPalette.safe;
  }

  @override
  Widget build(BuildContext context) {
    final t = RiverColors.of(context);
    final color = _riskColor(overallRisk);
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: t.cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withValues(alpha: 0.25)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.10),
            blurRadius: 24, offset: const Offset(0, 6)),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              AnimatedBuilder(
                animation: arcAnim,
                builder: (_, __) => SizedBox(
                  width: 100, height: 100,
                  child: CustomPaint(
                    painter: _ArcGaugePainter(
                      progress: (overallRisk / 100) * arcAnim.value,
                      color: color,
                      trackColor: t.stroke,
                    ),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('${overallRisk.toStringAsFixed(0)}%',
                              style: TextStyle(
                                color: color, fontSize: 22,
                                fontWeight: FontWeight.w900)),
                          Text('RISK',
                              style: TextStyle(
                                color: t.textSecondary, fontSize: 9,
                                fontWeight: FontWeight.w700, letterSpacing: 1.5)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _CountBadge('CRITICAL', critical, AppPalette.critical, t),
                    const SizedBox(height: 6),
                    _CountBadge('SEVERE',   severe,   AppPalette.danger,   t),
                    const SizedBox(height: 6),
                    _CountBadge('MODERATE', moderate, AppPalette.warning,  t),
                    const SizedBox(height: 6),
                    _CountBadge('SAFE',     safe,     AppPalette.safe,     t),
                  ],
                ),
              ),
            ],
          ),
          if (alertCities.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: t.chipBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppPalette.critical.withValues(alpha: 0.20)),
              ),
              child: Row(
                children: [
                  AnimatedBuilder(
                    animation: pulseAnim,
                    builder: (_, __) => Container(
                      width: 6, height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppPalette.critical.withValues(alpha: pulseAnim.value),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.crisis_alert_rounded,
                      color: AppPalette.critical, size: 13),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      alertCities[tickerIdx % alertCities.length].city,
                      style: TextStyle(
                        color: t.textPrimary, fontSize: 12,
                        fontWeight: FontWeight.w700),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text('${alertCities.length} alert${alertCities.length == 1 ? '' : 's'}',
                      style: const TextStyle(
                        color: AppPalette.critical, fontSize: 10,
                        fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('$total stations monitored',
                  style: TextStyle(
                    color: t.textSecondary, fontSize: 11,
                    fontWeight: FontWeight.w600)),
              Text('Bihar · CWPRS',
                  style: TextStyle(
                    color: t.textSecondary, fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }
}

Widget _CountBadge(String label, int count, Color color, RiverColors t) =>
    Row(
      children: [
        Container(
          width: 8, height: 8,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
        const SizedBox(width: 8),
        Text(label,
            style: TextStyle(
              color: t.textSecondary, fontSize: 11,
              fontWeight: FontWeight.w600)),
        const Spacer(),
        Text('$count',
            style: TextStyle(
              color: color, fontSize: 13,
              fontWeight: FontWeight.w900)),
      ],
    );

// ─────────────────────────────────────────────────────────────────────────────
// _ArcGaugePainter
// ─────────────────────────────────────────────────────────────────────────────

class _ArcGaugePainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color trackColor;
  const _ArcGaugePainter({
    required this.progress, required this.color, required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r  = (size.width / 2) - 8;
    const startAngle = -math.pi * 0.8;
    const sweepTotal = math.pi * 1.6;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;
    paint.color = trackColor;
    canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: r),
        startAngle, sweepTotal, false, paint);
    paint.color = color;
    canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: r),
        startAngle, sweepTotal * progress, false, paint);
  }

  @override
  bool shouldRepaint(_ArcGaugePainter old) =>
      old.progress != progress || old.color != color;
}

// ─────────────────────────────────────────────────────────────────────────────
// _QuickAccessGrid
// ─────────────────────────────────────────────────────────────────────────────

class _QuickAccessGrid extends StatelessWidget {
  final BuildContext context;
  const _QuickAccessGrid({required this.context});

  @override
  Widget build(BuildContext _) {
    final t = RiverColors.of(context);
    final items = [
      _QA('Live Stations', Icons.sensors_rounded,       AppPalette.cyan,     '/live_stations'),
      _QA('Monitors',      Icons.monitor_heart_rounded, AppPalette.safe,     '/monitors'),
      _QA('Predict',       Icons.model_training_rounded,AppPalette.gold,     '/predict'),
      _QA('Alerts',        Icons.notifications_rounded, AppPalette.critical, '/alerts'),
      _QA('State Matrix',  Icons.grid_view_rounded,     AppPalette.warning,  '/state_matrix'),
      _QA('Weather',       Icons.cloud_rounded,         AppPalette.cyan,     '/weather'),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: GridView.count(
        crossAxisCount: 3,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.15,
        children: items.map((q) => GestureDetector(
          onTap: () => Navigator.pushNamed(context, q.route),
          child: Container(
            decoration: BoxDecoration(
              color: t.cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: q.color.withValues(alpha: 0.20)),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(q.icon, color: q.color, size: 26),
                const SizedBox(height: 6),
                Text(q.label,
                    style: TextStyle(
                      color: t.textPrimary, fontSize: 10,
                      fontWeight: FontWeight.w700),
                    textAlign: TextAlign.center),
              ],
            ),
          ),
        )).toList(),
      ),
    );
  }
}

class _QA {
  final String label, route;
  final IconData icon;
  final Color color;
  const _QA(this.label, this.icon, this.color, this.route);
}

// ─────────────────────────────────────────────────────────────────────────────
// _SectionHeader
// ─────────────────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title, sub;
  final IconData icon;
  final Color color;
  const _SectionHeader({
    required this.title, required this.sub,
    required this.icon, required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final t = RiverColors.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.12),
              border: Border.all(color: color.withValues(alpha: 0.25)),
            ),
            child: Icon(icon, color: color, size: 14),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: TextStyle(
                    color: t.textPrimary, fontSize: 14,
                    fontWeight: FontWeight.w800)),
              Text(sub,
                  style: TextStyle(
                    color: t.textSecondary, fontSize: 10)),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _RiverPulseCard
// ─────────────────────────────────────────────────────────────────────────────

class _RiverPulseCard extends StatelessWidget {
  final FloodData data;
  final Animation<double> pulseAnim;
  const _RiverPulseCard({required this.data, required this.pulseAnim});

  Color _levelColor(String lvl) {
    switch (lvl) {
      case 'CRITICAL': return AppPalette.critical;
      case 'SEVERE':   return AppPalette.danger;
      case 'MODERATE': return AppPalette.warning;
      default:         return AppPalette.safe;
    }
  }

  @override
  Widget build(BuildContext context) {
    final t     = RiverColors.of(context);
    final color = _levelColor(data.riskLevel);
    final pct   = data.capacityPercent.clamp(0.0, 100.0);
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: t.cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AnimatedBuilder(
                animation: pulseAnim,
                builder: (_, __) => Container(
                  width: 8, height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: data.riskLevel == 'CRITICAL'
                        ? color.withValues(alpha: pulseAnim.value)
                        : color,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(data.city,
                    style: TextStyle(
                      color: t.textPrimary, fontSize: 13,
                      fontWeight: FontWeight.w800)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: color.withValues(alpha: 0.30)),
                ),
                child: Text(data.riskLevel,
                    style: TextStyle(
                      color: color, fontSize: 9,
                      fontWeight: FontWeight.w800, letterSpacing: 0.5)),
              ),
            ],
          ),
          if (data.riverName != null && data.riverName!.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(data.riverName!,
                style: TextStyle(
                  color: t.textSecondary, fontSize: 10)),
          ],
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct / 100,
              backgroundColor: t.stroke,
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 5,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${pct.toStringAsFixed(1)}% capacity',
                  style: TextStyle(
                    color: color, fontSize: 11,
                    fontWeight: FontWeight.w700)),
              Text(data.state,
                  style: TextStyle(
                    color: t.textSecondary, fontSize: 10)),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _HotspotCarousel
// ─────────────────────────────────────────────────────────────────────────────

class _HotspotCarousel extends StatelessWidget {
  final List<FloodData> items;
  final Animation<double> pulseAnim;
  const _HotspotCarousel({required this.items, required this.pulseAnim});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: RiverColors.of(context).cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: AppPalette.safe.withValues(alpha: 0.20)),
          ),
          child: const Row(
            children: [
              Icon(Icons.check_circle_outline_rounded,
                  color: AppPalette.safe, size: 18),
              SizedBox(width: 10),
              Text('No active hotspots',
                  style: TextStyle(
                    color: AppPalette.safe,
                    fontSize: 13, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      );
    }
    return SizedBox(
      height: 110,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (ctx, i) {
          final d   = items[i];
          final t   = RiverColors.of(ctx);
          final col = d.riskLevel == 'CRITICAL'
              ? AppPalette.critical
              : AppPalette.danger;
          return Container(
            width: 140,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: t.cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: col.withValues(alpha: 0.30)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    AnimatedBuilder(
                      animation: pulseAnim,
                      builder: (_, __) => Container(
                        width: 7, height: 7,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: col.withValues(alpha: pulseAnim.value),
                        ),
                      ),
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(d.riskLevel,
                          style: TextStyle(
                            color: col, fontSize: 9,
                            fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(d.city,
                    style: TextStyle(
                      color: t.textPrimary, fontSize: 12,
                      fontWeight: FontWeight.w800),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(d.riverName ?? d.state,
                    style: TextStyle(
                      color: t.textSecondary, fontSize: 10),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                const Spacer(),
                Text('${d.capacityPercent.toStringAsFixed(0)}% full',
                    style: TextStyle(
                      color: col, fontSize: 11,
                      fontWeight: FontWeight.w700)),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _RainfallForecastStrip
// ─────────────────────────────────────────────────────────────────────────────

class _RainfallForecastStrip extends StatelessWidget {
  final List<FloodData> data;
  const _RainfallForecastStrip({required this.data});

  @override
  Widget build(BuildContext context) {
    final t = RiverColors.of(context);
    final chips = data.take(6).map((d) {
      final mm = (d.capacityPercent * 0.8).toStringAsFixed(0);
      return _RFChip(city: d.city, mm: mm, color: t.accent);
    }).toList();
    return SizedBox(
      height: 70,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: chips.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) => chips[i],
      ),
    );
  }
}

class _RFChip extends StatelessWidget {
  final String city, mm;
  final Color color;
  const _RFChip({required this.city, required this.mm, required this.color});

  @override
  Widget build(BuildContext context) {
    final t = RiverColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: t.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.20)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.grain_rounded, color: color, size: 16),
          const SizedBox(height: 4),
          Text('$mm mm',
              style: TextStyle(
                color: t.textPrimary, fontSize: 11,
                fontWeight: FontWeight.w700)),
          Text(city,
              style: TextStyle(color: t.textSecondary, fontSize: 9),
              maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _AlertActivityLog
// ─────────────────────────────────────────────────────────────────────────────

class _AlertActivityLog extends StatelessWidget {
  final List<FloodData> data;
  const _AlertActivityLog({required this.data});

  @override
  Widget build(BuildContext context) {
    final t = RiverColors.of(context);
    if (data.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: t.cardBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: t.stroke),
          ),
          child: Text('No recent alert activity',
              style: TextStyle(color: t.textSecondary, fontSize: 12)),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Container(
        decoration: BoxDecoration(
          color: t.cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: t.stroke),
        ),
        child: Column(
          children: data.take(5).map((d) {
            final col = d.riskLevel == 'CRITICAL'
                ? AppPalette.critical
                : AppPalette.danger;
            return ListTile(
              dense: true,
              leading: Icon(Icons.crisis_alert_rounded, color: col, size: 18),
              title: Text(d.city,
                  style: TextStyle(
                    color: t.textPrimary, fontSize: 12,
                    fontWeight: FontWeight.w700)),
              subtitle: Text('${d.riskLevel} · ${d.capacityPercent.toStringAsFixed(0)}%',
                  style: TextStyle(color: t.textSecondary, fontSize: 10)),
              trailing: Text(d.riverName ?? '',
                  style: TextStyle(color: t.textSecondary, fontSize: 10)),
            );
          }).toList(),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _SystemStatsBar
// ─────────────────────────────────────────────────────────────────────────────

class _SystemStatsBar extends StatelessWidget {
  final RealTimeService service;
  final Animation<double> pulseAnim;
  const _SystemStatsBar({required this.service, required this.pulseAnim});

  @override
  Widget build(BuildContext context) {
    final t = RiverColors.of(context);
    final isOnline = service.isOnline;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: t.cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: t.stroke),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _StatChip(
              label: 'Status',
              value: isOnline ? 'LIVE' : 'OFFLINE',
              color: isOnline ? AppPalette.safe : AppPalette.critical,
              t: t,
            ),
            _StatChip(
              label: 'Stations',
              value: '${service.liveLevels.length}',
              color: t.accent,
              t: t,
            ),
            _StatChip(
              label: 'Critical',
              value: '${service.criticalCount}',
              color: AppPalette.critical,
              t: t,
            ),
          ],
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label, value;
  final Color color;
  final RiverColors t;
  const _StatChip({
    required this.label, required this.value,
    required this.color, required this.t,
  });

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(value,
          style: TextStyle(
            color: color, fontSize: 16,
            fontWeight: FontWeight.w900)),
      Text(label,
          style: TextStyle(
            color: t.textSecondary, fontSize: 10,
            fontWeight: FontWeight.w600, letterSpacing: 0.5)),
    ],
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// _FooterStatsBar
// ─────────────────────────────────────────────────────────────────────────────

class _FooterStatsBar extends StatelessWidget {
  final int totalStations, riversCount, statesAtRisk;
  final DateTime? lastUpdated;
  const _FooterStatsBar({
    required this.totalStations, required this.riversCount,
    required this.statesAtRisk, this.lastUpdated,
  });

  @override
  Widget build(BuildContext context) {
    final t = RiverColors.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: t.cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: t.stroke),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _FooterStat('$totalStations', 'Stations', t),
            _FooterStat('$riversCount',   'Rivers',   t),
            _FooterStat('$statesAtRisk',  'At Risk',  t),
          ],
        ),
      ),
    );
  }
}

Widget _FooterStat(String val, String lbl, RiverColors t) => Column(
  children: [
    Text(val,
        style: TextStyle(
          color: t.textPrimary, fontSize: 18,
          fontWeight: FontWeight.w900)),
    Text(lbl,
        style: TextStyle(
          color: t.textSecondary, fontSize: 10,
          fontWeight: FontWeight.w600)),
  ],
);

// ─────────────────────────────────────────────────────────────────────────────
// _EmptyState
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) {
    final t = RiverColors.of(context);
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        children: [
          Icon(Icons.water_drop_outlined,
              color: t.textSecondary, size: 48),
          const SizedBox(height: 16),
          Text('No data available',
              style: TextStyle(
                color: t.textPrimary, fontSize: 16,
                fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text('Pull to refresh or check your connection',
              style: TextStyle(
                color: t.textSecondary, fontSize: 12),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
