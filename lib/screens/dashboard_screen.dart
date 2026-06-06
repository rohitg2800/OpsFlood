// lib/screens/dashboard_screen.dart
// OpsFlood — DashboardScreen v23 (redesigned)
library;

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:intl/intl.dart';

import '../models/flood_data.dart';
import '../models/river_monitoring.dart';
import '../services/real_time_service.dart';
import '../theme/river_theme.dart';
import '../widgets/ops_area_chart.dart';
import '../widgets/premium_theme_sheet.dart';
import '../widgets/risk_heatmap.dart';

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
  String? _prevRiskSnapshot;

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
    _shimmerAnim = CurvedAnimation(parent: _shimmerCtrl, curve: Curves.linear);
    _service.addListener(_onData);
    _loadBannerAd();
  }

  void _loadBannerAd() {
    _bannerAd = BannerAd(
      adUnitId: _kBannerAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (mounted) setState(() => _bannerLoaded = true);
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          _bannerAd = null;
        },
      ),
    )..load();
  }

  void _onData() {
    if (!mounted) return;
    final snap = _sorted.map((d) => '${d.city}:${d.riskLevel}').join(',');
    _prevRiskSnapshot = snap;
    setState(() {});
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
    return (_sorted.map((d) => d.capacityPercent).fold(0.0, (a, b) => a + b)
        / _sorted.length).clamp(0, 100);
  }

  List<FloodData> get _alertCities =>
      _sorted.where((d) =>
          d.riskLevel == 'CRITICAL' || d.riskLevel == 'SEVERE').toList();

  @override
  Widget build(BuildContext context) {
    final data = _sorted;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppPalette.abyss0,
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
              // ── 1. Header ──────────────────────────────────────────────
              SliverToBoxAdapter(child: _CommandHeader(
                pulseAnim: _pulseAnim, shimmerAnim: _shimmerAnim,
                onRefresh: () {
                  HapticFeedback.mediumImpact();
                  _arcCtrl.forward(from: 0);
                  _service.refreshData();
                },
                lastUpdated: _service.lastFetchTime,
              )),

              // ── 2. Hero: Arc gauge + 4 KPI + ticker ───────────────────
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

                // ── 3. Quick Access ──────────────────────────────────────
                SliverToBoxAdapter(child: _QuickAccessGrid(context: context)),

                // ── 4. Critical Summary Card (only if critical/severe) ───
                if (_alertCities.isNotEmpty) ...[
                  SliverToBoxAdapter(child: _SectionHeader(
                    title: 'Highest Threat',
                    sub: 'Most critical station right now',
                    icon: Icons.crisis_alert_rounded,
                    color: AppPalette.critical,
                  )),
                  SliverToBoxAdapter(child: _CriticalSummaryCard(
                    data: _alertCities.first,
                    service: _service,
                    pulseAnim: _pulseAnim,
                  )),
                ],

                // ── 5. Hotspot Carousel (top 5) ──────────────────────────
                SliverToBoxAdapter(child: _SectionHeader(
                  title: 'Flood Hotspots',
                  sub: 'Top ${math.min(5, data.length)} by risk',
                  icon: Icons.local_fire_department_rounded,
                  color: AppPalette.critical,
                )),
                SliverToBoxAdapter(child: _HotspotCarousel(
                  cities: data.take(5).toList(),
                )),

                // ── 6. Live Pulse Strip (all stations, horizontal chips) ─
                SliverToBoxAdapter(child: _SectionHeader(
                  title: 'All Stations',
                  sub: '${data.length} stations · swipe to browse',
                  icon: Icons.sensors_rounded,
                  color: AppPalette.cyan,
                )),
                SliverToBoxAdapter(child: _LivePulseStrip(data: data)),

                // ── 7. River vs Danger bars (top 6) ──────────────────────
                SliverToBoxAdapter(child: _SectionHeader(
                  title: 'River vs Danger',
                  sub: 'Gap to danger level · top 6 stations',
                  icon: Icons.water_rounded,
                  color: AppPalette.cyan,
                )),
                SliverToBoxAdapter(child: _RiverDangerBars(
                  data: data.take(6).toList(),
                )),

                // ── 8. Trend chart (highest risk city) ───────────────────
                SliverToBoxAdapter(child: _SectionHeader(
                  title: 'Level Trend',
                  sub: data.first.city,
                  icon: Icons.show_chart_rounded,
                  color: AppPalette.cyan,
                )),
                SliverToBoxAdapter(child: _TrendCard(
                  service: _service, selected: data.first,
                )),

                // ── 9. Rainfall chips grid ───────────────────────────────
                SliverToBoxAdapter(child: _SectionHeader(
                  title: 'Rainfall 24h',
                  sub: 'IMD estimate · all stations',
                  icon: Icons.grain_rounded,
                  color: AppPalette.cyan,
                )),
                SliverToBoxAdapter(child: _RainfallChipsGrid(
                  data: data,
                )),

                // ── 10. Risk heatmap ─────────────────────────────────────
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

                // ── 11. Footer stats ─────────────────────────────────────
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
    if (p >= 35) return 'WARNING';
    return 'SAFE';
  }
}

// ═══════════════════════════════════════════════════════════════════════
// COMMAND HEADER
// ═══════════════════════════════════════════════════════════════════════
class _CommandHeader extends StatelessWidget {
  final Animation<double> pulseAnim, shimmerAnim;
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
        border: Border(bottom: BorderSide(
          color: AppPalette.cyan.withValues(alpha: 0.10), width: 1)),
      ),
      child: Row(
        children: [
          AnimatedBuilder(
            animation: shimmerAnim,
            builder: (_, __) => Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: LinearGradient(
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                  colors: [
                    AppPalette.cyan.withValues(alpha: 0.22),
                    AppPalette.cyan.withValues(alpha: 0.06),
                  ],
                ),
                border: Border.all(
                  color: AppPalette.cyan.withValues(
                    alpha: 0.20 + 0.15 * shimmerAnim.value), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: AppPalette.cyan.withValues(
                      alpha: 0.15 * shimmerAnim.value), blurRadius: 16),
                ],
              ),
              child: const Icon(Icons.water_drop_rounded,
                color: AppPalette.cyan, size: 22),
            ),
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
                  child: const Text('EQUINOX-BR05',
                    style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w900,
                      color: Colors.white, letterSpacing: 1.2, height: 1.1)),
                ),
                if (lastUpdated != null)
                  Text('Updated ${_fmt(lastUpdated!)}',
                    style: TextStyle(fontSize: 9.5,
                      color: AppPalette.textGrey.withValues(alpha: 0.65),
                      letterSpacing: 0.2))
                else
                  Text('Live Flood Intelligence',
                    style: TextStyle(fontSize: 9.5,
                      color: AppPalette.textGrey.withValues(alpha: 0.65))),
              ],
            ),
          ),
          AnimatedBuilder(
            animation: pulseAnim,
            builder: (_, __) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppPalette.safe.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppPalette.safe.withValues(
                    alpha: 0.25 + 0.20 * pulseAnim.value)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  width: 6, height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppPalette.safe.withValues(
                      alpha: 0.5 + 0.5 * pulseAnim.value),
                    boxShadow: [
                      BoxShadow(
                        color: AppPalette.safe.withValues(
                          alpha: 0.6 * pulseAnim.value), blurRadius: 8),
                    ],
                  ),
                ),
                const SizedBox(width: 5),
                const Text('LIVE', style: TextStyle(
                  color: AppPalette.safe, fontSize: 9,
                  fontWeight: FontWeight.w900, letterSpacing: 0.8)),
              ]),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => PremiumThemeSheet.show(context),
            child: Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: AppPalette.abyss2,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppPalette.abyssStroke),
              ),
              child: const Icon(Icons.palette_outlined,
                color: AppPalette.cyan, size: 18),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onRefresh,
            child: Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: AppPalette.abyss2,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppPalette.abyssStroke, width: 1),
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
// HERO SECTION
// ═══════════════════════════════════════════════════════════════════════
class _HeroSection extends StatelessWidget {
  final Animation<double> arcAnim, pulseAnim;
  final double overallRisk;
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
                    Row(children: [
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
                    ]),
                    const SizedBox(height: 8),
                    Row(children: [
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
                    ]),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (alertCities.isNotEmpty)
            _AlertTicker(
              alerts: alertCities, idx: tickerIdx, pulseAnim: pulseAnim)
          else
            _AllClearBanner(),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// QUICK ACCESS GRID
// ═══════════════════════════════════════════════════════════════════════
class _QuickAccessGrid extends StatelessWidget {
  final BuildContext context;
  const _QuickAccessGrid({required this.context});

  @override
  Widget build(BuildContext ctx) {
    final items = [
      _QuickItem(Icons.sensors_rounded,        'Live Stations', AppPalette.cyan,   '/live_stations'),
      _QuickItem(Icons.psychology_alt_rounded,  'ML Predict',   AppPalette.amber,  '/predict'),
      _QuickItem(Icons.map_rounded,             'Bihar Map',    AppPalette.safe,   '/bihar_map'),
      _QuickItem(Icons.monitor_heart_rounded,   'Monitors',     AppPalette.danger, '/monitors'),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Row(
        children: items.asMap().entries.map((entry) {
          final i = entry.key;
          final item = entry.value;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                Navigator.pushNamed(ctx, item.route);
              },
              child: Container(
                margin: EdgeInsets.only(right: i < items.length - 1 ? 8 : 0),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: item.color.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: item.color.withValues(alpha: 0.22)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(item.icon, color: item.color, size: 20),
                    const SizedBox(height: 5),
                    Text(item.label, style: TextStyle(
                      color: item.color, fontSize: 9,
                      fontWeight: FontWeight.w800, letterSpacing: 0.2),
                      textAlign: TextAlign.center),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _QuickItem {
  final IconData icon;
  final String label, route;
  final Color color;
  const _QuickItem(this.icon, this.label, this.color, this.route);
}

// ═══════════════════════════════════════════════════════════════════════
// CRITICAL SUMMARY CARD  (new)
// ═══════════════════════════════════════════════════════════════════════
class _CriticalSummaryCard extends StatelessWidget {
  final FloodData data;
  final RealTimeService service;
  final Animation<double> pulseAnim;
  const _CriticalSummaryCard({
    required this.data, required this.service, required this.pulseAnim});

  @override
  Widget build(BuildContext context) {
    final col      = data.priorityColor;
    final snapshots = service.trendForCity(data.city);
    final history   = snapshots.map((s) => s.level).toList();
    final overshoot = data.currentLevel - data.dangerLevel;
    final gapPct    = data.dangerLevel > 0
        ? (data.currentLevel / data.dangerLevel).clamp(0.0, 1.5)
        : 0.0;

    return AnimatedBuilder(
      animation: pulseAnim,
      builder: (_, __) => Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 4),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [
              col.withValues(alpha: 0.14),
              AppPalette.abyss2,
              col.withValues(alpha: 0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: col.withValues(
              alpha: 0.30 + 0.20 * pulseAnim.value), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: col.withValues(alpha: 0.18 * pulseAnim.value),
              blurRadius: 24, spreadRadius: 2),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // top row: badge + city + level
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: col.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: col.withValues(alpha: 0.35)),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Container(
                        width: 6, height: 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: col.withValues(
                            alpha: 0.5 + 0.5 * pulseAnim.value),
                          boxShadow: [
                            BoxShadow(
                              color: col.withValues(
                                alpha: 0.8 * pulseAnim.value),
                              blurRadius: 6),
                          ],
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(data.riskLevel, style: TextStyle(
                        color: col, fontSize: 9, fontWeight: FontWeight.w900,
                        letterSpacing: 0.8)),
                    ]),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(data.city, style: const TextStyle(
                          color: AppPalette.textWhite, fontSize: 18,
                          fontWeight: FontWeight.w900, letterSpacing: -0.5,
                          height: 1.1)),
                        Text(
                          '${data.riverName ?? ''}'  +
                          (data.district.isNotEmpty ? '  ·  ${data.district}' : ''),
                          style: const TextStyle(
                            color: AppPalette.textGrey, fontSize: 10)),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('${data.currentLevel.toStringAsFixed(2)} m',
                        style: TextStyle(
                          color: col, fontSize: 28,
                          fontWeight: FontWeight.w900, letterSpacing: -1.2,
                          height: 1)),
                      Text('current level', style: TextStyle(
                        color: AppPalette.textDim, fontSize: 8.5)),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // Gap to danger bar
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Gap to danger level', style: TextStyle(
                        color: AppPalette.textGrey.withValues(alpha: 0.8),
                        fontSize: 9.5, fontWeight: FontWeight.w600)),
                      Text(
                        overshoot > 0
                          ? '+${overshoot.toStringAsFixed(2)} m OVER'
                          : '${(-overshoot).toStringAsFixed(2)} m to danger',
                        style: TextStyle(
                          color: overshoot > 0
                            ? AppPalette.critical : AppPalette.warning,
                          fontSize: 9.5, fontWeight: FontWeight.w800)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: gapPct.clamp(0.0, 1.0),
                      minHeight: 10,
                      backgroundColor: AppPalette.abyss4,
                      valueColor: AlwaysStoppedAnimation(
                        gapPct >= 1.0 ? AppPalette.critical
                        : gapPct >= 0.8 ? AppPalette.danger
                        : AppPalette.warning),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _pill('W  ${data.warningLevel.toStringAsFixed(1)} m',
                        AppPalette.amber),
                      _pill('D  ${data.dangerLevel.toStringAsFixed(1)} m',
                        AppPalette.danger),
                      _pill('${data.capacityPercent.toStringAsFixed(0)}% cap',
                        col),
                    ],
                  ),
                ],
              ),

              // Mini trend if available
              if (history.isNotEmpty) ...[
                const SizedBox(height: 14),
                Container(
                  height: 70,
                  child: OpsAreaChart(
                    values: history,
                    labels: List.filled(history.length, ''),
                    lineColor: col, warningY: data.warningLevel,
                    dangerY: data.dangerLevel, yUnit: ' m', height: 70,
                  ),
                ),
              ],

              const SizedBox(height: 14),

              // Info tiles row
              Row(
                children: [
                  Expanded(child: _InfoTile(
                    label: 'Rainfall',
                    value: '${data.effectiveRainfallMm.toStringAsFixed(0)} mm',
                    icon: Icons.grain_rounded,
                    color: AppPalette.cyan)),
                  const SizedBox(width: 8),
                  Expanded(child: _InfoTile(
                    label: 'Flow Rate',
                    value: data.flowRateCumec != null
                        ? '${data.flowRateCumec!.toStringAsFixed(0)} m³/s'
                        : '—',
                    icon: Icons.speed_rounded,
                    color: AppPalette.amber)),
                  const SizedBox(width: 8),
                  Expanded(child: _InfoTile(
                    label: 'State',
                    value: data.state,
                    icon: Icons.location_on_rounded,
                    color: AppPalette.safe)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pill(String t, Color c) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: c.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: c.withValues(alpha: 0.25)),
    ),
    child: Text(t, style: TextStyle(
      color: c, fontSize: 8.5, fontWeight: FontWeight.w700)),
  );
}

class _InfoTile extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  const _InfoTile({
    required this.label, required this.value,
    required this.icon, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 10),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: color.withValues(alpha: 0.18)),
    ),
    child: Column(
      children: [
        Icon(icon, color: color, size: 14),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(
          color: color, fontSize: 11, fontWeight: FontWeight.w800),
          overflow: TextOverflow.ellipsis),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(
          color: AppPalette.textDim, fontSize: 8)),
      ],
    ),
  );
}

// ═══════════════════════════════════════════════════════════════════════
// HOTSPOT CAROUSEL
// ═══════════════════════════════════════════════════════════════════════
class _HotspotCarousel extends StatelessWidget {
  final List<FloodData> cities;
  const _HotspotCarousel({required this.cities});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 150,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
        physics: const BouncingScrollPhysics(),
        itemCount: cities.length,
        itemBuilder: (_, i) => _HotspotCard(data: cities[i], rank: i + 1),
      ),
    );
  }
}

class _HotspotCard extends StatelessWidget {
  final FloodData data;
  final int rank;
  const _HotspotCard({required this.data, required this.rank});

  @override
  Widget build(BuildContext context) {
    final col      = data.priorityColor;
    final overshoot = data.currentLevel - data.dangerLevel;
    final isAboveDanger = overshoot > 0;
    return Container(
      width: 200,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [col.withValues(alpha: 0.12), AppPalette.abyss2],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: col.withValues(alpha: 0.35), width: 1.5),
        boxShadow: [
          BoxShadow(color: col.withValues(alpha: 0.15),
            blurRadius: 18, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: col.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text('#$rank', style: TextStyle(
                color: col, fontSize: 9, fontWeight: FontWeight.w900)),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: col.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: col.withValues(alpha: 0.30)),
              ),
              child: Text(data.riskLevel, style: TextStyle(
                color: col, fontSize: 8, fontWeight: FontWeight.w900)),
            ),
          ]),
          const SizedBox(height: 8),
          Text(data.city, style: const TextStyle(
            color: AppPalette.textWhite, fontSize: 15,
            fontWeight: FontWeight.w900, letterSpacing: -0.3),
            overflow: TextOverflow.ellipsis),
          if ((data.riverName ?? '').isNotEmpty)
            Text(data.riverName!, style: const TextStyle(
              color: AppPalette.textGrey, fontSize: 9.5)),
          const Spacer(),
          Row(children: [
            Text('${data.currentLevel.toStringAsFixed(2)} m',
              style: TextStyle(color: col, fontSize: 20,
                fontWeight: FontWeight.w900, letterSpacing: -0.8)),
            const SizedBox(width: 6),
            if (isAboveDanger)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppPalette.critical.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: AppPalette.critical.withValues(alpha: 0.4)),
                ),
                child: Text('+${overshoot.toStringAsFixed(1)}m',
                  style: const TextStyle(
                    color: AppPalette.critical,
                    fontSize: 7.5, fontWeight: FontWeight.w800)),
              ),
          ]),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (data.capacityPercent / 100).clamp(0.0, 1.0),
              minHeight: 5,
              backgroundColor: AppPalette.abyss4,
              valueColor: AlwaysStoppedAnimation(col),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// LIVE PULSE STRIP  (new — all stations as mini chips)
// ═══════════════════════════════════════════════════════════════════════
class _LivePulseStrip extends StatelessWidget {
  final List<FloodData> data;
  const _LivePulseStrip({required this.data});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 76,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
        physics: const BouncingScrollPhysics(),
        itemCount: data.length,
        itemBuilder: (_, i) => _PulseChip(d: data[i]),
      ),
    );
  }
}

class _PulseChip extends StatelessWidget {
  final FloodData d;
  const _PulseChip({required this.d});

  @override
  Widget build(BuildContext context) {
    final col = d.priorityColor;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        Navigator.pushNamed(context, '/city_detail',
          arguments: d.city);
      },
      child: Container(
        width: 90,
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: col.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: col.withValues(alpha: 0.28)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(children: [
              Container(
                width: 6, height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle, color: col,
                  boxShadow: [
                    BoxShadow(color: col.withValues(alpha: 0.6),
                      blurRadius: 4)]),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(d.riskLevel.substring(0, math.min(3, d.riskLevel.length)),
                  style: TextStyle(
                    color: col, fontSize: 7.5, fontWeight: FontWeight.w900,
                    letterSpacing: 0.3)),
              ),
            ]),
            Text(d.city, style: const TextStyle(
              color: AppPalette.textWhite, fontSize: 11,
              fontWeight: FontWeight.w800, letterSpacing: -0.2),
              overflow: TextOverflow.ellipsis, maxLines: 1),
            Text('${d.currentLevel.toStringAsFixed(1)} m',
              style: TextStyle(
                color: col, fontSize: 12, fontWeight: FontWeight.w900,
                letterSpacing: -0.3)),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// RIVER VS DANGER BARS  (new)
// ═══════════════════════════════════════════════════════════════════════
class _RiverDangerBars extends StatelessWidget {
  final List<FloodData> data;
  const _RiverDangerBars({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppPalette.abyss2,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppPalette.abyssStroke),
      ),
      child: Column(
        children: data.map((d) {
          final col   = d.priorityColor;
          final ratio = d.dangerLevel > 0
              ? (d.currentLevel / d.dangerLevel).clamp(0.0, 1.2)
              : 0.0;
          final pct   = (ratio * 100).toStringAsFixed(0);
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(d.city, style: const TextStyle(
                        color: AppPalette.textWhite, fontSize: 11.5,
                        fontWeight: FontWeight.w700),
                        overflow: TextOverflow.ellipsis),
                    ),
                    Text('${d.currentLevel.toStringAsFixed(1)} m',
                      style: TextStyle(
                        color: col, fontSize: 11,
                        fontWeight: FontWeight.w800)),
                    const SizedBox(width: 6),
                    Text('/ ${d.dangerLevel.toStringAsFixed(1)} m danger',
                      style: const TextStyle(
                        color: AppPalette.textDim, fontSize: 9)),
                    const SizedBox(width: 6),
                    Text('$pct%', style: TextStyle(
                      color: col, fontSize: 9.5,
                      fontWeight: FontWeight.w900)),
                  ],
                ),
                const SizedBox(height: 5),
                Stack(
                  children: [
                    Container(
                      height: 8,
                      decoration: BoxDecoration(
                        color: AppPalette.abyss4,
                        borderRadius: BorderRadius.circular(4)),
                    ),
                    // Danger threshold marker at 100%
                    Positioned(
                      right: 0, top: 0, bottom: 0,
                      child: Container(
                        width: 2,
                        decoration: BoxDecoration(
                          color: AppPalette.danger.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(1)),
                      ),
                    ),
                    FractionallySizedBox(
                      widthFactor: ratio.clamp(0.0, 1.0),
                      child: Container(
                        height: 8,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [col.withValues(alpha: 0.5), col]),
                          borderRadius: BorderRadius.circular(4),
                          boxShadow: [
                            BoxShadow(
                              color: col.withValues(alpha: 0.40),
                              blurRadius: 6),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// RAINFALL CHIPS GRID  (replaces bar chart strip)
// ═══════════════════════════════════════════════════════════════════════
class _RainfallChipsGrid extends StatelessWidget {
  final List<FloodData> data;
  const _RainfallChipsGrid({required this.data});

  Color _col(double mm) {
    if (mm >= 115) return AppPalette.critical;
    if (mm >= 64)  return AppPalette.danger;
    if (mm >= 15)  return AppPalette.warning;
    return AppPalette.safe;
  }

  String _label(double mm) {
    if (mm >= 115) return 'EXTREME';
    if (mm >= 64)  return 'HEAVY';
    if (mm >= 15)  return 'MOD';
    return 'LIGHT';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppPalette.abyss2,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppPalette.abyssStroke),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Legend
          Row(children: [
            _leg(AppPalette.safe,     '< 15 Light'),
            const SizedBox(width: 8),
            _leg(AppPalette.warning,  '15–64 Mod'),
            const SizedBox(width: 8),
            _leg(AppPalette.danger,   '64–115 Heavy'),
            const SizedBox(width: 8),
            _leg(AppPalette.critical, '> 115 Extreme'),
          ]),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: data.map((d) {
              final mm  = d.effectiveRainfallMm;
              final col = _col(mm);
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 9, vertical: 6),
                decoration: BoxDecoration(
                  color: col.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: col.withValues(alpha: 0.28)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('${mm.toStringAsFixed(0)} mm',
                      style: TextStyle(
                        color: col, fontSize: 11,
                        fontWeight: FontWeight.w800)),
                    const SizedBox(height: 1),
                    Text(d.city, style: const TextStyle(
                      color: AppPalette.textGrey, fontSize: 8.5),
                      overflow: TextOverflow.ellipsis),
                    Text(_label(mm), style: TextStyle(
                      color: col.withValues(alpha: 0.7),
                      fontSize: 7, fontWeight: FontWeight.w700,
                      letterSpacing: 0.3)),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _leg(Color c, String t) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(width: 7, height: 7,
        decoration: BoxDecoration(shape: BoxShape.circle, color: c)),
      const SizedBox(width: 3),
      Text(t, style: const TextStyle(
        fontSize: 7.5, color: AppPalette.textGrey)),
    ],
  );
}

// ═══════════════════════════════════════════════════════════════════════
// TREND CARD
// ═══════════════════════════════════════════════════════════════════════
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
          BoxShadow(color: col.withValues(alpha: 0.08),
            blurRadius: 20, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(d.city, style: const TextStyle(
                color: AppPalette.textWhite, fontSize: 14,
                fontWeight: FontWeight.w800, letterSpacing: -0.3)),
              if (d.district.isNotEmpty)
                Text('${d.riverName ?? ''}  ·  ${d.district}',
                  style: const TextStyle(
                    color: AppPalette.textGrey, fontSize: 10)),
            ]),
            const Spacer(),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('${d.currentLevel.toStringAsFixed(2)} m',
                style: TextStyle(color: col, fontSize: 20,
                  fontWeight: FontWeight.w900, letterSpacing: -0.8)),
              Text(d.riskLevel, style: TextStyle(
                color: col, fontSize: 9, fontWeight: FontWeight.w800)),
            ]),
          ]),
          const SizedBox(height: 14),
          if (history.isEmpty)
            Container(
              height: 90, alignment: Alignment.center,
              child: Text('Building trend for ${d.city}…',
                style: const TextStyle(
                  color: AppPalette.textDim, fontSize: 11)))
          else
            OpsAreaChart(
              values: history,
              labels: snapshots.asMap().entries
                  .map((e) => e.key % 4 == 0
                      ? DateFormat('HH:mm').format(
                          snapshots[e.key].timestamp.toLocal())
                      : '')
                  .toList(),
              lineColor: col, warningY: d.warningLevel,
              dangerY: d.dangerLevel, yUnit: ' m', height: 120,
            ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _LevelPill(
              label: 'Safe',
              value: '${d.safeLevel.toStringAsFixed(1)} m',
              color: AppPalette.safe)),
            const SizedBox(width: 8),
            Expanded(child: _LevelPill(
              label: 'Warning',
              value: '${d.warningLevel.toStringAsFixed(1)} m',
              color: AppPalette.amber)),
            const SizedBox(width: 8),
            Expanded(child: _LevelPill(
              label: 'Danger',
              value: '${d.dangerLevel.toStringAsFixed(1)} m',
              color: AppPalette.critical)),
          ]),
        ],
      ),
    );
  }
}

class _LevelPill extends StatelessWidget {
  final String label, value;
  final Color color;
  const _LevelPill({
    required this.label, required this.value, required this.color});
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

// ═══════════════════════════════════════════════════════════════════════
// FOOTER STATS BAR  (was _SystemStatsBar, now compact at bottom)
// ═══════════════════════════════════════════════════════════════════════
class _FooterStatsBar extends StatelessWidget {
  final int totalStations, riversCount, statesAtRisk;
  final DateTime? lastUpdated;
  const _FooterStatsBar({
    required this.totalStations, required this.riversCount,
    required this.statesAtRisk, required this.lastUpdated,
  });

  @override
  Widget build(BuildContext context) {
    final syncStr = lastUpdated == null
        ? '--'
        : DateFormat('HH:mm').format(lastUpdated!.toLocal());
    final stats = [
      _Stat(Icons.sensors_rounded,      '$totalStations', 'Stations',  AppPalette.cyan),
      _Stat(Icons.waves_rounded,         '$riversCount',  'Rivers',    AppPalette.safe),
      _Stat(Icons.warning_amber_rounded, '$statesAtRisk', 'At Risk',   AppPalette.amber),
      _Stat(Icons.sync_rounded,          syncStr,         'Sync',      AppPalette.textGrey),
    ];
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: AppPalette.abyss2,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppPalette.abyssStroke),
      ),
      child: Row(
        children: stats.asMap().entries.map((e) {
          final s   = e.value;
          final idx = e.key;
          return Expanded(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Icon(s.icon, color: s.color, size: 14),
                      const SizedBox(height: 3),
                      Text(s.value, style: TextStyle(
                        color: s.color, fontSize: 13,
                        fontWeight: FontWeight.w900, letterSpacing: -0.5)),
                      const SizedBox(height: 1),
                      Text(s.label, style: const TextStyle(
                        color: AppPalette.textDim, fontSize: 8,
                        fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                if (idx < stats.length - 1)
                  Container(
                    width: 1, height: 28, color: AppPalette.abyssStroke),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _Stat {
  final IconData icon;
  final String value, label;
  final Color color;
  const _Stat(this.icon, this.value, this.label, this.color);
}

// ═══════════════════════════════════════════════════════════════════════
// SHARED: ARC GAUGE
// ═══════════════════════════════════════════════════════════════════════
class _ArcGauge extends StatelessWidget {
  final Animation<double> anim;
  final double percent;
  final int total;
  const _ArcGauge({
    required this.anim, required this.percent, required this.total});

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
          painter: _ArcPainter(
            progress: (percent / 100) * anim.value, color: _arcColor),
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
                      color: Colors.white, letterSpacing: -1.5, height: 1)),
                ),
                const SizedBox(height: 3),
                Text('RISK INDEX', style: TextStyle(
                  fontSize: 7.5,
                  color: AppPalette.textGrey.withValues(alpha: 0.65),
                  fontWeight: FontWeight.w700, letterSpacing: 1.5)),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: _arcColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _arcColor.withValues(alpha: 0.30)),
                  ),
                  child: Text('$total stations', style: TextStyle(
                    fontSize: 8, color: _arcColor,
                    fontWeight: FontWeight.w800)),
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
  final Color color;
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
                    endAngle: startAngle + sweepMax * progress,
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

// ═══════════════════════════════════════════════════════════════════════
// SHARED: BENTO KPI
// ═══════════════════════════════════════════════════════════════════════
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
        BoxShadow(
          color: color.withValues(alpha: 0.18),
          blurRadius: 12, spreadRadius: 1),
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
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.7), blurRadius: 6)]),
          ),
        ]),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(
          fontSize: 24, fontWeight: FontWeight.w900,
          color: glow ? color : AppPalette.textWhite,
          letterSpacing: -1, height: 1)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(
          fontSize: 8,
          color: glow
            ? color.withValues(alpha: 0.75) : AppPalette.textDim,
          fontWeight: FontWeight.w700, letterSpacing: 0.8)),
      ],
    ),
  );
}

// ═══════════════════════════════════════════════════════════════════════
// SHARED: ALERT TICKER + ALL CLEAR
// ═══════════════════════════════════════════════════════════════════════
class _AlertTicker extends StatelessWidget {
  final List<FloodData> alerts;
  final int idx;
  final Animation<double> pulseAnim;
  const _AlertTicker({
    required this.alerts, required this.idx, required this.pulseAnim});

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
            color: col.withValues(
              alpha: 0.20 + 0.15 * pulseAnim.value), width: 1.5),
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
                  blurRadius: 8),
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
                  TextSpan(text: '${d.riskLevel}  ',
                    style: TextStyle(color: col,
                      fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                  TextSpan(text: d.city,
                    style: const TextStyle(
                      color: AppPalette.textWhite,
                      fontWeight: FontWeight.w700)),
                  if (d.district.isNotEmpty)
                    TextSpan(text: '  ·  ${d.district}',
                      style: const TextStyle(
                        color: AppPalette.textGrey,
                        fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          ),
          Text('${d.currentLevel.toStringAsFixed(1)} m',
            style: TextStyle(
              color: col, fontSize: 11, fontWeight: FontWeight.w900)),
          const SizedBox(width: 6),
          if (alerts.length > 1)
            Text('${idx + 1}/${alerts.length}',
              style: const TextStyle(
                color: AppPalette.textDim, fontSize: 9)),
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
        style: TextStyle(
          color: AppPalette.safe, fontSize: 11,
          fontWeight: FontWeight.w700)),
    ]),
  );
}

// ═══════════════════════════════════════════════════════════════════════
// SHARED: SECTION HEADER
// ═══════════════════════════════════════════════════════════════════════
class _SectionHeader extends StatelessWidget {
  final String title, sub;
  final IconData icon;
  final Color color;
  const _SectionHeader({
    required this.title, required this.sub,
    required this.icon, required this.color,
  });
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
            boxShadow: [
              BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 8)],
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
              color: AppPalette.textWhite, letterSpacing: -0.3)),
            Text(sub, style: TextStyle(
              fontSize: 9.5,
              color: AppPalette.textGrey.withValues(alpha: 0.7))),
          ],
        ),
      ],
    ),
  );
}

// ═══════════════════════════════════════════════════════════════════════
// EMPTY STATE
// ═══════════════════════════════════════════════════════════════════════
class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.only(top: 60),
      child: Column(
        children: [
          Icon(Icons.water_damage_outlined,
            color: AppPalette.cyan.withValues(alpha: 0.3), size: 56),
          const SizedBox(height: 16),
          const Text('Loading flood data…',
            style: TextStyle(
              color: AppPalette.textGrey, fontSize: 14)),
        ],
      ),
    ),
  );
}
