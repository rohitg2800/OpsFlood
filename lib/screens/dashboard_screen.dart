// lib/screens/dashboard_screen.dart  v27 — robotic HUD · Bihar-only · rich charts
library;

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:intl/intl.dart';

import '../models/flood_data.dart';
import '../services/real_time_service.dart';
import '../theme/river_theme.dart';
import '../widgets/premium_theme_sheet.dart';
import '../widgets/risk_heatmap.dart';

const String _kBannerAdUnitId = 'ca-app-pub-6001698589023170/6430029201';

// ─── Bihar districts (38 official) ───────────────────────────────────────────
const List<String> _biharDistricts = [
  'Patna', 'Gaya', 'Bhagalpur', 'Muzaffarpur', 'Darbhanga', 'Purnia',
  'Samastipur', 'Begusarai', 'Sitamarhi', 'Madhubani', 'Supaul', 'Saharsa',
  'Khagaria', 'Katihar', 'Kishanganj', 'Araria', 'West Champaran',
  'East Champaran', 'Gopalganj', 'Siwan', 'Saran', 'Vaishali', 'Sheohar',
  'Nalanda', 'Nawada', 'Jehanabad', 'Arwal', 'Aurangabad', 'Kaimur',
  'Rohtas', 'Bhojpur', 'Buxar', 'Munger', 'Lakhisarai', 'Sheikhpura',
  'Jamui', 'Banka', 'Madhepura',
];

// ─── Bihar rivers ─────────────────────────────────────────────────────────────
const List<String> _biharRivers = [
  'Ganga', 'Gandak', 'Kosi', 'Bagmati', 'Kamla-Balan', 'Burhi Gandak',
  'Mahananda', 'Son', 'Punpun', 'Falgu', 'Ghaghra', 'Adhwara',
];

// ─── Colour helpers ───────────────────────────────────────────────────────────
Color _riskCol(String lvl) {
  switch (lvl.toUpperCase()) {
    case 'CRITICAL': return AppPalette.critical;
    case 'SEVERE':   return AppPalette.danger;
    case 'MODERATE': return AppPalette.warning;
    default:         return AppPalette.safe;
  }
}

// ─── Root screen ──────────────────────────────────────────────────────────────
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with TickerProviderStateMixin {
  final RealTimeService _service = RealTimeService();

  late AnimationController _entryCtrl;
  late AnimationController _gaugeCtrl;
  late AnimationController _waveCtrl;
  late AnimationController _pulseCtrl;
  late AnimationController _countCtrl;
  late AnimationController _scanCtrl;   // HUD scan-line
  late Animation<double>   _gaugeAnim;

  final Map<String, bool> _collapsed = {
    'rivers': false, 'district': false, 'hotspots': false, 'rainfall': false,
    'capacity': false, 'trend': false, 'log': false, 'stats': false, 'map': false,
  };

  int _tickerIdx = 0;
  BannerAd? _bannerAd;
  bool _bannerLoaded = false;

  bool get _reduceMotion => MediaQuery.of(context).disableAnimations;

  @override
  void initState() {
    super.initState();
    _entryCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _gaugeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 2000))..forward();
    _gaugeAnim = CurvedAnimation(parent: _gaugeCtrl, curve: Curves.easeOutExpo);
    _waveCtrl  = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat(reverse: true);
    _countCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..forward();
    _scanCtrl  = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();
    Future.delayed(const Duration(seconds: 4), _rotateTicker);
    _service.addListener(_onData);
    _service.startPolling();
    _loadBanner();
    Future.microtask(() => _entryCtrl.forward());
  }

  void _rotateTicker() {
    if (!mounted) return;
    final alerts = _alertCities;
    if (alerts.isNotEmpty) {
      setState(() => _tickerIdx = (_tickerIdx + 1) % alerts.length);
    }
    Future.delayed(const Duration(seconds: 4), _rotateTicker);
  }

  void _onData() {
    if (mounted) {
      setState(() {});
      _gaugeCtrl.forward(from: 0);
      _countCtrl.forward(from: 0);
      _entryCtrl.forward(from: 0);
    }
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
        onAdFailedToLoad: (ad, _) => ad.dispose(),
      ),
    ).load();
  }

  @override
  void dispose() {
    _service.removeListener(_onData);
    for (final c in [_entryCtrl, _gaugeCtrl, _waveCtrl, _pulseCtrl, _countCtrl, _scanCtrl]) {
      c.dispose();
    }
    _bannerAd?.dispose();
    super.dispose();
  }

  List<FloodData> get _sorted {
    final list = List<FloodData>.from(_service.liveLevels);
    const order = ['CRITICAL', 'SEVERE', 'MODERATE', 'LOW'];
    list.sort((a, b) => order.indexOf(a.riskLevel).compareTo(order.indexOf(b.riskLevel)));
    return list;
  }

  int get _criticalCount  => _sorted.where((d) => d.riskLevel == 'CRITICAL').length;
  int get _severeCount    => _sorted.where((d) => d.riskLevel == 'SEVERE').length;
  int get _moderateCount  => _sorted.where((d) => d.riskLevel == 'MODERATE').length;
  int get _safeCount      => _sorted.where((d) => d.riskLevel == 'LOW').length;

  double get _overallRisk {
    if (_sorted.isEmpty) return 0;
    return (_sorted.map((d) => d.capacityPercent).fold(0.0, (a, b) => a + b) / _sorted.length).clamp(0.0, 100.0);
  }

  List<FloodData> get _alertCities =>
      _sorted.where((d) => d.riskLevel == 'CRITICAL' || d.riskLevel == 'SEVERE').toList();

  void _refresh() {
    HapticFeedback.mediumImpact();
    _gaugeCtrl.forward(from: 0);
    _countCtrl.forward(from: 0);
    _entryCtrl.forward(from: 0);
    _service.refreshData();
  }

  void _toggle(String key) {
    HapticFeedback.selectionClick();
    setState(() => _collapsed[key] = !(_collapsed[key] ?? false));
  }

  bool _isCollapsed(String key) => _collapsed[key] ?? false;

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
              // HUD Header
              SliverToBoxAdapter(child: _HUDHeader(
                pulseCtrl: _pulseCtrl, scanCtrl: _scanCtrl,
                lastUpdated: _service.lastFetchTime,
                isOnline: _service.isOnline, onRefresh: _refresh,
              )),

              // Command stats strip
              SliverToBoxAdapter(child: _CommandStrip(
                critical: _criticalCount, severe: _severeCount,
                moderate: _moderateCount, safe: _safeCount,
                total: data.length, countCtrl: _countCtrl,
              )),

              // Hero wave gauge
              SliverToBoxAdapter(child: _HeroGauge(
                gaugeAnim: _gaugeAnim, waveCtrl: _waveCtrl,
                pulseCtrl: _pulseCtrl, countCtrl: _countCtrl,
                overallRisk: _overallRisk, critical: _criticalCount,
                severe: _severeCount, moderate: _moderateCount,
                safe: _safeCount, total: data.length,
                alertCities: _alertCities, tickerIdx: _tickerIdx,
                reduceMotion: _reduceMotion,
              )),

              // Quick actions grid
              SliverToBoxAdapter(child: _QuickGrid(entryCtrl: _entryCtrl)),

              if (data.isEmpty)
                const SliverToBoxAdapter(child: _EmptyState())
              else ...[

                // ── Live River Levels ──────────────────────────────────────
                SliverToBoxAdapter(child: _CollapsibleSection(
                  sectionKey: 'rivers', title: 'Live River Levels',
                  subtitle: 'Bihar WRD · sorted by risk',
                  icon: Icons.water_rounded, color: AppPalette.cyan,
                  collapsed: _isCollapsed('rivers'), onToggle: () => _toggle('rivers'),
                  child: Column(
                    children: data.asMap().entries.map((e) => _AnimatedRiverCard(
                      data: e.value, index: e.key,
                      entryCtrl: _entryCtrl, pulseCtrl: _pulseCtrl,
                      reduceMotion: _reduceMotion,
                    )).toList(),
                  ),
                )),

                // ── District Risk Matrix ───────────────────────────────────
                SliverToBoxAdapter(child: _CollapsibleSection(
                  sectionKey: 'district', title: 'District Risk Matrix',
                  subtitle: '${_biharDistricts.length} districts · Bihar',
                  icon: Icons.map_rounded, color: AppPalette.warning,
                  collapsed: _isCollapsed('district'), onToggle: () => _toggle('district'),
                  child: _DistrictMatrix(data: data, gaugeAnim: _gaugeAnim),
                )),

                // ── Hotspot Alerts ─────────────────────────────────────────
                SliverToBoxAdapter(child: _CollapsibleSection(
                  sectionKey: 'hotspots', title: 'Hotspot Districts',
                  subtitle: '${_alertCities.length} active alerts',
                  icon: Icons.crisis_alert_rounded, color: AppPalette.critical,
                  collapsed: _isCollapsed('hotspots'), onToggle: () => _toggle('hotspots'),
                  child: _HotspotPageView(items: _alertCities, pulseCtrl: _pulseCtrl),
                )),

                // ── Rainfall ──────────────────────────────────────────────
                SliverToBoxAdapter(child: _CollapsibleSection(
                  sectionKey: 'rainfall', title: 'Rainfall Estimate',
                  subtitle: 'IMD 24h · Bihar districts',
                  icon: Icons.grain_rounded, color: AppPalette.gold,
                  collapsed: _isCollapsed('rainfall'), onToggle: () => _toggle('rainfall'),
                  child: _RainfallBars(data: data, gaugeAnim: _gaugeAnim, reduceMotion: _reduceMotion),
                )),

                // ── Capacity bar chart ─────────────────────────────────────
                SliverToBoxAdapter(child: _CollapsibleSection(
                  sectionKey: 'capacity', title: 'Capacity Overview',
                  subtitle: 'All monitored rivers · Bihar',
                  icon: Icons.bar_chart_rounded, color: AppPalette.gold,
                  collapsed: _isCollapsed('capacity'), onToggle: () => _toggle('capacity'),
                  child: _AnimatedBarChart(
                    values: data.map((d) => d.capacityPercent).toList(),
                    labels: data.map((d) => d.city).toList(),
                    colors: data.map((d) => _riskCol(d.riskLevel)).toList(),
                    entryCtrl: _entryCtrl, reduceMotion: _reduceMotion,
                  ),
                )),

                // ── Trend area chart ───────────────────────────────────────
                SliverToBoxAdapter(child: _CollapsibleSection(
                  sectionKey: 'trend', title: 'Capacity Trend',
                  subtitle: 'Distribution curve · live',
                  icon: Icons.show_chart_rounded, color: AppPalette.cyan,
                  collapsed: _isCollapsed('trend'), onToggle: () => _toggle('trend'),
                  child: _AnimatedAreaChart(
                    values: data.map((d) => d.capacityPercent).toList(),
                    labels: data.map((d) => d.city).toList(),
                    gaugeAnim: _gaugeAnim, waveCtrl: _waveCtrl,
                    reduceMotion: _reduceMotion,
                  ),
                )),

                // ── Radar chart ────────────────────────────────────────────
                SliverToBoxAdapter(child: _CollapsibleSection(
                  sectionKey: 'log', title: 'Risk Radar',
                  subtitle: 'Multi-axis district analysis',
                  icon: Icons.radar_rounded, color: AppPalette.danger,
                  collapsed: _isCollapsed('log'), onToggle: () => _toggle('log'),
                  child: _RadarChart(data: data, gaugeAnim: _gaugeAnim),
                )),

                // ── System stats ───────────────────────────────────────────
                SliverToBoxAdapter(child: _CollapsibleSection(
                  sectionKey: 'stats', title: 'System Health',
                  subtitle: 'Data pipeline · Bihar nodes',
                  icon: Icons.analytics_outlined, color: AppPalette.safe,
                  collapsed: _isCollapsed('stats'), onToggle: () => _toggle('stats'),
                  child: _SystemStats(
                    service: _service, pulseCtrl: _pulseCtrl,
                    gaugeAnim: _gaugeAnim, reduceMotion: _reduceMotion,
                  ),
                )),

                // ── Heatmap ────────────────────────────────────────────────
                SliverToBoxAdapter(child: _CollapsibleSection(
                  sectionKey: 'map', title: 'State Risk Map',
                  subtitle: 'Bihar flood index · district view',
                  icon: Icons.grid_view_rounded, color: AppPalette.safe,
                  collapsed: _isCollapsed('map'), onToggle: () => _toggle('map'),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: RiskHeatmap(entries: _buildHeatmapEntries(data)),
                  ),
                )),

                SliverToBoxAdapter(child: _Footer(
                  totalStations: data.length,
                  riversCount: data.map((d) => d.riverName ?? '').toSet().where((s) => s.isNotEmpty).length,
                  districtsAtRisk: data.where((d) => d.riskLevel != 'LOW').map((d) => d.city).toSet().length,
                  lastUpdated: _service.lastFetchTime,
                )),
              ],
              const SliverToBoxAdapter(child: SizedBox(height: 48)),
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
      return RiskHeatmapEntry(state: e.key, level: dom.key,
          count: e.value.values.fold(0, (s, v) => s + v));
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
// _HUDHeader — robotic command-center bar
// ─────────────────────────────────────────────────────────────────────────────
class _HUDHeader extends StatelessWidget {
  final AnimationController pulseCtrl, scanCtrl;
  final DateTime? lastUpdated;
  final bool isOnline;
  final VoidCallback onRefresh;
  const _HUDHeader({required this.pulseCtrl, required this.scanCtrl,
      required this.lastUpdated, required this.isOnline, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final t = RiverColors.of(context);
    final timeStr = lastUpdated != null ? DateFormat('HH:mm:ss').format(lastUpdated!) : '--:--:--';
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: t.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: t.accent.withValues(alpha: 0.25)),
        boxShadow: [BoxShadow(color: t.accent.withValues(alpha: 0.08),
            blurRadius: 20, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          // Animated scan target icon
          AnimatedBuilder(
            animation: scanCtrl,
            builder: (_, __) => Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: t.accent.withValues(alpha: 0.2 + scanCtrl.value * 0.3),
                      width: 1.5,
                    ),
                  ),
                ),
                Container(
                  width: 26, height: 26,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: t.accent.withValues(alpha: 0.08 + scanCtrl.value * 0.06),
                    border: Border.all(
                      color: t.accent.withValues(alpha: 0.5 + scanCtrl.value * 0.3),
                      width: 1,
                    ),
                  ),
                  child: Icon(Icons.radar_rounded, color: t.accent, size: 14),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('BIHAR FLOOD COMMAND CENTER',
                    style: TextStyle(color: t.accent, fontSize: 8.5,
                        fontWeight: FontWeight.w900, letterSpacing: 2.0)),
                const SizedBox(height: 3),
                Text('WRD Bihar · GloFAS · IMD · CWC',
                    style: TextStyle(color: t.textPrimary, fontSize: 13,
                        fontWeight: FontWeight.w800, letterSpacing: -0.3)),
                const SizedBox(height: 2),
                Text('SYS CLOCK $timeStr',
                    style: TextStyle(color: t.textSecondary, fontSize: 9,
                        fontWeight: FontWeight.w600, letterSpacing: 1.0,
                        fontFeatures: const [FontFeature.tabularFigures()])),
              ],
            ),
          ),
          // Online badge
          AnimatedBuilder(
            animation: pulseCtrl,
            builder: (_, __) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: (isOnline ? AppPalette.safe : AppPalette.critical)
                    .withValues(alpha: 0.12 + pulseCtrl.value * 0.08),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: (isOnline ? AppPalette.safe : AppPalette.critical)
                      .withValues(alpha: 0.35),
                ),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  width: 5, height: 5,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isOnline ? AppPalette.safe : AppPalette.critical,
                    boxShadow: [BoxShadow(
                        color: (isOnline ? AppPalette.safe : AppPalette.critical)
                            .withValues(alpha: pulseCtrl.value * 0.7),
                        blurRadius: 6)],
                  ),
                ),
                const SizedBox(width: 5),
                Text(isOnline ? 'LIVE' : 'OFFLINE',
                    style: TextStyle(
                      color: isOnline ? AppPalette.safe : AppPalette.critical,
                      fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 1.2,
                    )),
              ]),
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            onPressed: () => showPremiumThemeSheet(context),
            icon: Icon(Icons.tune_rounded, color: t.textSecondary, size: 20),
            padding: const EdgeInsets.all(8),
          ),
          IconButton(
            onPressed: onRefresh,
            icon: Icon(Icons.refresh_rounded, color: t.accent, size: 20),
            padding: const EdgeInsets.all(8),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _CommandStrip — 5-stat HUD strip
// ─────────────────────────────────────────────────────────────────────────────
class _CommandStrip extends StatelessWidget {
  final int critical, severe, moderate, safe, total;
  final AnimationController countCtrl;
  const _CommandStrip({required this.critical, required this.severe,
      required this.moderate, required this.safe, required this.total,
      required this.countCtrl});

  @override
  Widget build(BuildContext context) {
    final t = RiverColors.of(context);
    final stats = [
      (label: 'CRITICAL', value: critical, color: AppPalette.critical),
      (label: 'SEVERE',   value: severe,   color: AppPalette.danger),
      (label: 'MODERATE', value: moderate, color: AppPalette.warning),
      (label: 'SAFE',     value: safe,     color: AppPalette.safe),
      (label: 'TOTAL',    value: total,    color: t.accent),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Row(
        children: stats.asMap().entries.map((e) {
          final s = e.value;
          return Expanded(
            child: Container(
              margin: EdgeInsets.only(right: e.key < stats.length - 1 ? 6 : 0),
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: s.color.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: s.color.withValues(alpha: 0.20)),
              ),
              child: Column(children: [
                AnimatedBuilder(
                  animation: countCtrl,
                  builder: (_, __) => Text(
                    '${(s.value * countCtrl.value).round()}',
                    style: TextStyle(color: s.color, fontSize: 18,
                        fontWeight: FontWeight.w900,
                        fontFeatures: const [FontFeature.tabularFigures()]),
                  ),
                ),
                const SizedBox(height: 2),
                Text(s.label, style: TextStyle(color: t.textSecondary, fontSize: 7.5,
                    fontWeight: FontWeight.w700, letterSpacing: 0.8)),
              ]),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _HeroGauge
// ─────────────────────────────────────────────────────────────────────────────
class _HeroGauge extends StatelessWidget {
  final Animation<double> gaugeAnim;
  final AnimationController waveCtrl, pulseCtrl, countCtrl;
  final double overallRisk;
  final int critical, severe, moderate, safe, total, tickerIdx;
  final List<FloodData> alertCities;
  final bool reduceMotion;

  const _HeroGauge({
    required this.gaugeAnim, required this.waveCtrl, required this.pulseCtrl,
    required this.countCtrl, required this.overallRisk, required this.critical,
    required this.severe, required this.moderate, required this.safe,
    required this.total, required this.alertCities, required this.tickerIdx,
    required this.reduceMotion,
  });

  Color get _gaugeColor {
    if (overallRisk >= 75) return AppPalette.critical;
    if (overallRisk >= 50) return AppPalette.danger;
    if (overallRisk >= 25) return AppPalette.warning;
    return AppPalette.safe;
  }

  @override
  Widget build(BuildContext context) {
    final t = RiverColors.of(context);
    final col = _gaugeColor;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 10),
      decoration: BoxDecoration(
        color: t.cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: col.withValues(alpha: 0.22)),
        boxShadow: [BoxShadow(color: col.withValues(alpha: 0.12),
            blurRadius: 32, spreadRadius: -4, offset: const Offset(0, 8))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            // Corner bracket decoration
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              _HUDBracket(color: col, flip: false),
              Text('THREAT INDEX · BIHAR',
                  style: TextStyle(color: t.textSecondary, fontSize: 8.5,
                      fontWeight: FontWeight.w800, letterSpacing: 2.0)),
              _HUDBracket(color: col, flip: true),
            ]),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  width: 112, height: 112,
                  child: AnimatedBuilder(
                    animation: Listenable.merge([gaugeAnim, waveCtrl]),
                    builder: (_, __) => CustomPaint(
                      painter: _WaveGaugePainter(
                        fillFraction: (overallRisk / 100) * gaugeAnim.value,
                        wavePhase: reduceMotion ? 0 : waveCtrl.value * 2 * math.pi,
                        color: col, trackColor: t.stroke,
                      ),
                      child: Center(
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          AnimatedBuilder(
                            animation: countCtrl,
                            builder: (_, __) => Text(
                              '${(overallRisk * countCtrl.value).toStringAsFixed(0)}%',
                              style: TextStyle(color: col, fontSize: 26,
                                  fontWeight: FontWeight.w900, letterSpacing: -1,
                                  fontFeatures: const [FontFeature.tabularFigures()]),
                            ),
                          ),
                          Text('RISK', style: TextStyle(color: t.textSecondary,
                              fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 2.5)),
                        ]),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(children: [
                    _riskRow('CRITICAL', critical, AppPalette.critical, countCtrl, t),
                    const SizedBox(height: 9),
                    _riskRow('SEVERE',   severe,   AppPalette.danger,   countCtrl, t),
                    const SizedBox(height: 9),
                    _riskRow('MODERATE', moderate, AppPalette.warning,  countCtrl, t),
                    const SizedBox(height: 9),
                    _riskRow('SAFE',     safe,     AppPalette.safe,     countCtrl, t),
                  ]),
                ),
              ],
            ),
            if (alertCities.isNotEmpty) ...[
              const SizedBox(height: 14),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 500),
                transitionBuilder: (child, anim) => FadeTransition(
                  opacity: anim,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.3), end: Offset.zero,
                    ).animate(anim),
                    child: child,
                  ),
                ),
                child: _TickerBanner(
                  key: ValueKey(tickerIdx),
                  city: alertCities[tickerIdx % alertCities.length],
                  total: alertCities.length,
                  pulseCtrl: pulseCtrl,
                ),
              ),
            ],
            const SizedBox(height: 10),
            // HUD bottom strip
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: t.stroke.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('STATIONS: $total',
                      style: TextStyle(color: t.textSecondary, fontSize: 9,
                          fontWeight: FontWeight.w700, letterSpacing: 0.8)),
                  Container(width: 1, height: 12, color: t.stroke),
                  Text('STATE: BIHAR',
                      style: TextStyle(color: t.accent, fontSize: 9,
                          fontWeight: FontWeight.w800, letterSpacing: 0.8)),
                  Container(width: 1, height: 12, color: t.stroke),
                  Text('SRC: WRD+IMD',
                      style: TextStyle(color: t.textSecondary, fontSize: 9,
                          fontWeight: FontWeight.w700, letterSpacing: 0.8)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Corner bracket widget for HUD look
class _HUDBracket extends StatelessWidget {
  final Color color;
  final bool flip;
  const _HUDBracket({required this.color, required this.flip});

  @override
  Widget build(BuildContext context) {
    return Transform(
      alignment: Alignment.center,
      transform: flip ? (Matrix4.identity()..scale(-1.0, 1.0)) : Matrix4.identity(),
      child: SizedBox(
        width: 14, height: 14,
        child: CustomPaint(painter: _BracketPainter(color: color)),
      ),
    );
  }
}

class _BracketPainter extends CustomPainter {
  final Color color;
  const _BracketPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.6)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.square;
    canvas.drawLine(Offset(0, size.height), Offset(0, 0), paint);
    canvas.drawLine(Offset(0, 0), Offset(size.width, 0), paint);
  }

  @override
  bool shouldRepaint(_BracketPainter old) => old.color != color;
}

// ignore: non_constant_identifier_names
Widget _riskRow(String label, int count, Color color, AnimationController ctrl, RiverColors t) {
  return Row(children: [
    Container(width: 10, height: 10,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color,
            boxShadow: [BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 4)])),
    const SizedBox(width: 8),
    Expanded(child: Text(label, style: TextStyle(color: t.textSecondary,
        fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.3))),
    AnimatedBuilder(animation: ctrl, builder: (_, __) => Text(
      '${(count * ctrl.value).round()}',
      style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w900,
          fontFeatures: const [FontFeature.tabularFigures()]),
    )),
  ]);
}

class _TickerBanner extends StatelessWidget {
  final FloodData city;
  final int total;
  final AnimationController pulseCtrl;
  const _TickerBanner({super.key, required this.city, required this.total, required this.pulseCtrl});

  @override
  Widget build(BuildContext context) {
    final t = RiverColors.of(context);
    final col = _riskCol(city.riskLevel);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [col.withValues(alpha: 0.10), col.withValues(alpha: 0.04)]),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: col.withValues(alpha: 0.25)),
      ),
      child: Row(children: [
        AnimatedBuilder(
          animation: pulseCtrl,
          builder: (_, __) => Container(width: 7, height: 7,
              decoration: BoxDecoration(shape: BoxShape.circle,
                  color: col.withValues(alpha: 0.4 + pulseCtrl.value * 0.6),
                  boxShadow: [BoxShadow(color: col.withValues(alpha: pulseCtrl.value * 0.5), blurRadius: 6)])),
        ),
        const SizedBox(width: 10),
        Icon(Icons.crisis_alert_rounded, color: col, size: 14),
        const SizedBox(width: 6),
        Expanded(child: Text('⚠ ${city.city}', style: TextStyle(color: t.textPrimary,
            fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 0.2))),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(color: col.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20)),
          child: Text('$total ALERT${total == 1 ? '' : 'S'}',
              style: TextStyle(color: col, fontSize: 8.5, fontWeight: FontWeight.w900, letterSpacing: 0.8)),
        ),
      ]),
    );
  }
}

class _WaveGaugePainter extends CustomPainter {
  final double fillFraction, wavePhase;
  final Color color, trackColor;
  const _WaveGaugePainter({required this.fillFraction, required this.wavePhase,
      required this.color, required this.trackColor});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r  = math.min(cx, cy) - 4;
    canvas.drawCircle(Offset(cx, cy), r,
        Paint()..color = trackColor..style = PaintingStyle.fill);
    final clipPath = Path()..addOval(Rect.fromCircle(center: Offset(cx, cy), radius: r));
    canvas.save();
    canvas.clipPath(clipPath);
    final fillY = size.height * (1 - fillFraction);
    const waveAmp = 5.0;
    final wavePath = Path();
    wavePath.moveTo(0, size.height);
    wavePath.lineTo(0, fillY);
    for (double x = 0; x <= size.width; x++) {
      wavePath.lineTo(x, fillY + math.sin((x / size.width) * 2 * math.pi + wavePhase) * waveAmp);
    }
    wavePath.lineTo(size.width, size.height);
    wavePath.close();
    canvas.drawPath(wavePath, Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter, end: Alignment.bottomCenter,
        colors: [color.withValues(alpha: 0.65), color.withValues(alpha: 0.90)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)));
    canvas.restore();
    canvas.drawCircle(Offset(cx, cy), r, Paint()
      ..color = color.withValues(alpha: 0.30)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2);
  }

  @override
  bool shouldRepaint(_WaveGaugePainter old) =>
      old.fillFraction != fillFraction || old.wavePhase != wavePhase || old.color != color;
}

// ─────────────────────────────────────────────────────────────────────────────
// _QuickGrid
// ─────────────────────────────────────────────────────────────────────────────
class _QuickGrid extends StatelessWidget {
  final AnimationController entryCtrl;
  const _QuickGrid({required this.entryCtrl});

  static const _items = [
    (label: 'Live Stations', icon: Icons.sensors_rounded,        color: AppPalette.cyan,     route: '/live_stations'),
    (label: 'Monitors',      icon: Icons.monitor_heart_rounded,  color: AppPalette.safe,     route: '/monitors'),
    (label: 'Predict',       icon: Icons.model_training_rounded, color: AppPalette.gold,     route: '/predict'),
    (label: 'Alerts',        icon: Icons.notifications_rounded,  color: AppPalette.critical, route: '/alerts'),
    (label: 'Districts',     icon: Icons.location_city_rounded,  color: AppPalette.warning,  route: '/state_matrix'),
    (label: 'Weather',       icon: Icons.cloud_rounded,          color: AppPalette.cyan,     route: '/weather'),
  ];

  @override
  Widget build(BuildContext context) {
    final t = RiverColors.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 10),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3, crossAxisSpacing: 9,
          mainAxisSpacing: 9, childAspectRatio: 1.15,
        ),
        itemCount: _items.length,
        itemBuilder: (ctx, i) {
          final item = _items[i];
          return AnimatedBuilder(
            animation: entryCtrl,
            builder: (_, child) {
              final delay = i * 0.08;
              final t2 = ((entryCtrl.value - delay) / (1.0 - delay)).clamp(0.0, 1.0);
              return Opacity(opacity: t2,
                  child: Transform.translate(offset: Offset(0, 14 * (1 - t2)), child: child));
            },
            child: GestureDetector(
              onTap: () { HapticFeedback.lightImpact(); Navigator.pushNamed(context, item.route); },
              child: Container(
                decoration: BoxDecoration(
                  color: t.cardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: item.color.withValues(alpha: 0.20)),
                  boxShadow: [BoxShadow(color: item.color.withValues(alpha: 0.06),
                      blurRadius: 10, offset: const Offset(0, 3))],
                ),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(item.icon, color: item.color, size: 24),
                  const SizedBox(height: 6),
                  Text(item.label, style: TextStyle(color: t.textPrimary, fontSize: 9.5,
                      fontWeight: FontWeight.w700), textAlign: TextAlign.center),
                ]),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _CollapsibleSection
// ─────────────────────────────────────────────────────────────────────────────
class _CollapsibleSection extends StatelessWidget {
  final String sectionKey, title, subtitle;
  final IconData icon;
  final Color color;
  final bool collapsed;
  final VoidCallback onToggle;
  final Widget child;

  const _CollapsibleSection({
    required this.sectionKey, required this.title, required this.subtitle,
    required this.icon, required this.color, required this.collapsed,
    required this.onToggle, required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final t = RiverColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: onToggle,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 16, 8),
            child: Row(children: [
              Container(
                width: 30, height: 30,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: color.withValues(alpha: 0.10),
                  border: Border.all(color: color.withValues(alpha: 0.20)),
                ),
                child: Icon(icon, color: color, size: 14),
              ),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: TextStyle(color: t.textPrimary, fontSize: 13,
                    fontWeight: FontWeight.w800, letterSpacing: 0.1)),
                Text(subtitle, style: TextStyle(color: t.textSecondary, fontSize: 10)),
              ])),
              AnimatedRotation(
                turns: collapsed ? 0 : 0.5,
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOutCubic,
                child: Icon(Icons.keyboard_arrow_down_rounded,
                    color: t.textSecondary, size: 20),
              ),
            ]),
          ),
        ),
        // Accent divider line
        Container(
          margin: const EdgeInsets.fromLTRB(20, 0, 20, 4),
          height: 1,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [
              color.withValues(alpha: 0.4), color.withValues(alpha: 0.0),
            ]),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
          child: collapsed ? const SizedBox.shrink() : child,
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _DistrictMatrix — all 38 Bihar districts as a risk grid
// ─────────────────────────────────────────────────────────────────────────────
class _DistrictMatrix extends StatelessWidget {
  final List<FloodData> data;
  final Animation<double> gaugeAnim;
  const _DistrictMatrix({required this.data, required this.gaugeAnim});

  @override
  Widget build(BuildContext context) {
    final t = RiverColors.of(context);
    // Map live data to district names
    final liveMap = <String, FloodData>{};
    for (final d in data) {
      liveMap[d.city] = d;
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: t.cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: t.stroke),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Legend
            Row(children: [
              _matrixLegend('CRITICAL', AppPalette.critical),
              const SizedBox(width: 10),
              _matrixLegend('SEVERE', AppPalette.danger),
              const SizedBox(width: 10),
              _matrixLegend('MODERATE', AppPalette.warning),
              const SizedBox(width: 10),
              _matrixLegend('SAFE', AppPalette.safe),
            ]),
            const SizedBox(height: 12),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: _biharDistricts.map((district) {
                final live = liveMap[district];
                final col = live != null ? _riskCol(live.riskLevel) : t.stroke;
                final riskLabel = live?.riskLevel ?? 'N/A';
                return AnimatedBuilder(
                  animation: gaugeAnim,
                  builder: (_, __) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    decoration: BoxDecoration(
                      color: col.withValues(alpha: 0.08 * gaugeAnim.value),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: col.withValues(alpha: 0.35)),
                    ),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Text(district.length > 8 ? '${district.substring(0, 7)}…' : district,
                          style: TextStyle(color: t.textPrimary, fontSize: 8.5,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      if (live != null)
                        Text('${live.capacityPercent.toStringAsFixed(0)}%',
                            style: TextStyle(color: col, fontSize: 8,
                                fontWeight: FontWeight.w900))
                      else
                        Text(riskLabel, style: TextStyle(color: t.textSecondary, fontSize: 7.5)),
                    ]),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _matrixLegend(String label, Color color) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(width: 8, height: 8, decoration: BoxDecoration(
          shape: BoxShape.circle, color: color)),
      const SizedBox(width: 4),
      Text(label, style: TextStyle(color: color, fontSize: 8, fontWeight: FontWeight.w700)),
    ],
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// _AnimatedRiverCard
// ─────────────────────────────────────────────────────────────────────────────
class _AnimatedRiverCard extends StatelessWidget {
  final FloodData data;
  final int index;
  final AnimationController entryCtrl, pulseCtrl;
  final bool reduceMotion;

  const _AnimatedRiverCard({required this.data, required this.index,
      required this.entryCtrl, required this.pulseCtrl, required this.reduceMotion});

  @override
  Widget build(BuildContext context) {
    final t   = RiverColors.of(context);
    final col = _riskCol(data.riskLevel);
    final pct = data.capacityPercent.clamp(0.0, 100.0);

    return AnimatedBuilder(
      animation: entryCtrl,
      builder: (_, child) {
        final delay = (index * 0.06).clamp(0.0, 0.6);
        final progress = ((entryCtrl.value - delay) / (1.0 - delay)).clamp(0.0, 1.0);
        return Opacity(opacity: progress,
            child: Transform.translate(offset: Offset(24 * (1 - progress), 0), child: child));
      },
      child: GestureDetector(
        onTap: () => Navigator.pushNamed(context, '/city_detail', arguments: data),
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          decoration: BoxDecoration(
            color: t.cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: col.withValues(alpha: 0.18)),
            boxShadow: [BoxShadow(color: col.withValues(alpha: 0.05),
                blurRadius: 10, offset: const Offset(0, 3))],
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                AnimatedBuilder(
                  animation: pulseCtrl,
                  builder: (_, __) {
                    final glow = data.riskLevel == 'CRITICAL' || data.riskLevel == 'SEVERE';
                    return Container(width: 8, height: 8,
                        decoration: BoxDecoration(shape: BoxShape.circle,
                            color: glow ? col.withValues(alpha: 0.5 + pulseCtrl.value * 0.5) : col,
                            boxShadow: glow ? [BoxShadow(
                                color: col.withValues(alpha: pulseCtrl.value * 0.6), blurRadius: 8)] : null));
                  },
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(data.city, style: TextStyle(color: t.textPrimary,
                    fontSize: 13, fontWeight: FontWeight.w800))),
                // Risk badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: col.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: col.withValues(alpha: 0.25))),
                  child: Text(data.riskLevel, style: TextStyle(color: col, fontSize: 8.5,
                      fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                ),
              ]),
              if (data.riverName != null && data.riverName!.isNotEmpty) ...[
                const SizedBox(height: 3),
                Row(children: [
                  Icon(Icons.water_rounded, color: t.textSecondary, size: 10),
                  const SizedBox(width: 4),
                  Text(data.riverName!, style: TextStyle(color: t.textSecondary, fontSize: 9.5)),
                ]),
              ],
              const SizedBox(height: 9),
              // Progress bar
              Container(
                height: 5,
                decoration: BoxDecoration(color: t.stroke, borderRadius: BorderRadius.circular(3)),
                child: AnimatedBuilder(
                  animation: entryCtrl,
                  builder: (_, __) {
                    final delay = (index * 0.06).clamp(0.0, 0.6);
                    final p = ((entryCtrl.value - delay) / (1.0 - delay)).clamp(0.0, 1.0);
                    return FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: (pct / 100) * p,
                      child: Container(
                        decoration: BoxDecoration(borderRadius: BorderRadius.circular(3),
                            gradient: LinearGradient(colors: [col.withValues(alpha: 0.6), col])),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 6),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('${pct.toStringAsFixed(1)}% capacity',
                    style: TextStyle(color: col, fontSize: 11, fontWeight: FontWeight.w800)),
                Text('Bihar', style: TextStyle(color: t.textSecondary, fontSize: 9.5)),
              ]),
            ]),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _HotspotPageView
// ─────────────────────────────────────────────────────────────────────────────
class _HotspotPageView extends StatefulWidget {
  final List<FloodData> items;
  final AnimationController pulseCtrl;
  const _HotspotPageView({required this.items, required this.pulseCtrl});
  @override
  State<_HotspotPageView> createState() => _HotspotPageViewState();
}

class _HotspotPageViewState extends State<_HotspotPageView> {
  late final PageController _pageCtrl;
  double _page = 0;

  @override
  void initState() {
    super.initState();
    _pageCtrl = PageController(viewportFraction: 0.72)
      ..addListener(() { if (mounted) setState(() => _page = _pageCtrl.page ?? 0); });
  }

  @override
  void dispose() { _pageCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) {
      final t = RiverColors.of(context);
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: t.cardBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppPalette.safe.withValues(alpha: 0.20))),
          child: const Row(children: [
            Icon(Icons.check_circle_outline_rounded, color: AppPalette.safe, size: 16),
            SizedBox(width: 10),
            Text('No active hotspot alerts — Bihar is stable',
                style: TextStyle(color: AppPalette.safe, fontSize: 12, fontWeight: FontWeight.w700)),
          ]),
        ),
      );
    }
    return SizedBox(
      height: 136,
      child: PageView.builder(
        controller: _pageCtrl,
        itemCount: widget.items.length,
        itemBuilder: (ctx, i) {
          final d   = widget.items[i];
          final t   = RiverColors.of(ctx);
          final col = _riskCol(d.riskLevel);
          final scale = (1.0 - (_page - i).abs() * 0.05).clamp(0.9, 1.0);
          return Transform.scale(
            scale: scale,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: t.cardBg, borderRadius: BorderRadius.circular(18),
                border: Border.all(color: col.withValues(alpha: 0.30)),
                boxShadow: [BoxShadow(color: col.withValues(alpha: 0.12),
                    blurRadius: 16, offset: const Offset(0, 4))],
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  AnimatedBuilder(
                    animation: widget.pulseCtrl,
                    builder: (_, __) => Container(width: 7, height: 7,
                        decoration: BoxDecoration(shape: BoxShape.circle,
                            color: col.withValues(alpha: 0.4 + widget.pulseCtrl.value * 0.6),
                            boxShadow: [BoxShadow(
                                color: col.withValues(alpha: widget.pulseCtrl.value * 0.5),
                                blurRadius: 6)])),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(color: col.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6)),
                    child: Text(d.riskLevel, style: TextStyle(color: col, fontSize: 8,
                        fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                  ),
                  const Spacer(),
                  Text('Bihar', style: TextStyle(color: col.withValues(alpha: 0.6), fontSize: 9)),
                ]),
                const SizedBox(height: 8),
                Text(d.city, style: TextStyle(color: t.textPrimary, fontSize: 14,
                    fontWeight: FontWeight.w900), maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(d.riverName ?? _biharRivers.first, style: TextStyle(color: t.textSecondary, fontSize: 9.5),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                const Spacer(),
                ClipRRect(borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(value: d.capacityPercent / 100,
                        backgroundColor: t.stroke,
                        valueColor: AlwaysStoppedAnimation(col), minHeight: 4)),
                const SizedBox(height: 4),
                Text('${d.capacityPercent.toStringAsFixed(0)}% river capacity',
                    style: TextStyle(color: col, fontSize: 9.5, fontWeight: FontWeight.w800)),
              ]),
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _RainfallBars
// ─────────────────────────────────────────────────────────────────────────────
class _RainfallBars extends StatelessWidget {
  final List<FloodData> data;
  final Animation<double> gaugeAnim;
  final bool reduceMotion;
  const _RainfallBars({required this.data, required this.gaugeAnim, required this.reduceMotion});

  @override
  Widget build(BuildContext context) {
    final t = RiverColors.of(context);
    final items = data.take(10).toList();
    final maxMm = items.isEmpty ? 1.0
        : items.map((d) => d.effectiveRainfallMm).reduce(math.max).clamp(1.0, double.infinity);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
        decoration: BoxDecoration(color: t.cardBg, borderRadius: BorderRadius.circular(20),
            border: Border.all(color: t.stroke)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('24h RAINFALL · BIHAR IMD',
                style: TextStyle(color: t.textSecondary, fontSize: 9.5,
                    fontWeight: FontWeight.w800, letterSpacing: 1.0)),
            Text('mm', style: TextStyle(color: t.accent, fontSize: 10,
                fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 14),
          SizedBox(
            height: 90,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: items.asMap().entries.map((e) {
                final i  = e.key;
                final d  = e.value;
                final mm = d.effectiveRainfallMm.clamp(0.0, double.infinity);
                final col = _riskCol(d.riskLevel);
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2.5),
                    child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                      Text('${mm.toStringAsFixed(0)}',
                          style: TextStyle(color: col, fontSize: 7, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      AnimatedBuilder(
                        animation: gaugeAnim,
                        builder: (_, __) {
                          final frac = reduceMotion ? 1.0
                              : ((gaugeAnim.value - i * 0.05).clamp(0.0, 1.0));
                          final h = (mm / maxMm) * 60 * frac;
                          return Container(
                            width: double.infinity, height: h.clamp(3.0, 60.0),
                            decoration: BoxDecoration(
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                              gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter,
                                  colors: [col.withValues(alpha: 0.9), col.withValues(alpha: 0.4)]),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 4),
                      Text(d.city.substring(0, math.min(3, d.city.length)),
                          style: TextStyle(color: t.textSecondary, fontSize: 7.5),
                          textAlign: TextAlign.center),
                    ]),
                  ),
                );
              }).toList(),
            ),
          ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _AnimatedBarChart
// ─────────────────────────────────────────────────────────────────────────────
class _AnimatedBarChart extends StatelessWidget {
  final List<double> values;
  final List<String> labels;
  final List<Color> colors;
  final AnimationController entryCtrl;
  final bool reduceMotion;

  const _AnimatedBarChart({required this.values, required this.labels,
      required this.colors, required this.entryCtrl, required this.reduceMotion});

  @override
  Widget build(BuildContext context) {
    final t = RiverColors.of(context);
    if (values.isEmpty) return const SizedBox.shrink();
    final maxVal = values.reduce(math.max).clamp(1.0, double.infinity);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 14, 12, 10),
        decoration: BoxDecoration(color: t.cardBg, borderRadius: BorderRadius.circular(20),
            border: Border.all(color: t.stroke)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('CAPACITY BY DISTRICT · BIHAR',
                style: TextStyle(color: t.textSecondary, fontSize: 9.5,
                    fontWeight: FontWeight.w800, letterSpacing: 1.0)),
            const SizedBox(height: 12),
            SizedBox(
              height: 130,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: values.asMap().entries.map((e) {
                  final i   = e.key;
                  final val = e.value;
                  final col = colors.length > i ? colors[i] : t.accent;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                        AnimatedBuilder(
                          animation: entryCtrl,
                          builder: (_, __) {
                            final delay = (i * 0.045).clamp(0.0, 0.7);
                            final p = reduceMotion ? 1.0
                                : ((entryCtrl.value - delay) / (1.0 - delay)).clamp(0.0, 1.0);
                            final h = (val / maxVal) * 90 * p;
                            return Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                              Text('${val.toStringAsFixed(0)}%',
                                  style: TextStyle(color: col, fontSize: 6.5,
                                      fontWeight: FontWeight.w800)),
                              const SizedBox(height: 2),
                              Container(
                                width: double.infinity, height: h.clamp(2.0, 90.0),
                                decoration: BoxDecoration(
                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                                  gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
                                      colors: [col, col.withValues(alpha: 0.55)]),
                                ),
                              ),
                            ]);
                          },
                        ),
                        const SizedBox(height: 4),
                        Text(labels.length > i ? labels[i].substring(0, math.min(3, labels[i].length)) : '',
                            style: TextStyle(color: t.textSecondary, fontSize: 7.5),
                            textAlign: TextAlign.center),
                      ]),
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

// ─────────────────────────────────────────────────────────────────────────────
// _AnimatedAreaChart
// ─────────────────────────────────────────────────────────────────────────────
class _AnimatedAreaChart extends StatelessWidget {
  final List<double> values;
  final List<String> labels;
  final Animation<double> gaugeAnim;
  final AnimationController waveCtrl;
  final bool reduceMotion;

  const _AnimatedAreaChart({
    required this.values, required this.labels,
    required this.gaugeAnim, required this.waveCtrl,
    required this.reduceMotion,
  });

  @override
  Widget build(BuildContext context) {
    final t = RiverColors.of(context);
    if (values.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
        decoration: BoxDecoration(color: t.cardBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: t.stroke)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('CAPACITY TREND · BIHAR RIVERS',
              style: TextStyle(color: t.textSecondary, fontSize: 9.5,
                  fontWeight: FontWeight.w800, letterSpacing: 1.0)),
          const SizedBox(height: 8),
          SizedBox(
            height: 120,
            child: AnimatedBuilder(
              animation: Listenable.merge([gaugeAnim, waveCtrl]),
              builder: (_, __) => CustomPaint(
                painter: _AreaChartPainter(
                  values: values,
                  progress: gaugeAnim.value,
                  wavePhase: reduceMotion ? 0 : waveCtrl.value * 2 * math.pi,
                  lineColor: t.accent,
                  fillColor: t.accent.withValues(alpha: 0.15),
                  dotColor: t.accent,
                  gridColor: t.stroke,
                ),
                size: Size.infinite,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (int i = 0; i < labels.length; i += math.max(1, labels.length ~/ 5))
                Text(labels[i].substring(0, math.min(3, labels[i].length)),
                    style: TextStyle(color: t.textSecondary, fontSize: 7.5)),
            ],
          ),
        ]),
      ),
    );
  }
}

class _AreaChartPainter extends CustomPainter {
  final List<double> values;
  final double progress, wavePhase;
  final Color lineColor, fillColor, dotColor, gridColor;

  const _AreaChartPainter({required this.values, required this.progress,
      required this.wavePhase, required this.lineColor, required this.fillColor,
      required this.dotColor, required this.gridColor});

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final maxV  = values.reduce(math.max).clamp(1.0, double.infinity);
    final n     = values.length;
    final xStep = size.width / (n - 1).clamp(1, n);

    // Grid lines
    final gridPaint = Paint()..color = gridColor..strokeWidth = 0.5;
    for (int g = 0; g <= 4; g++) {
      final y = size.height - (g / 4) * size.height;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
      // Y-axis labels via text painter
      final tp = TextPainter(
        text: TextSpan(
          text: '${(g * 25)}%',
          style: TextStyle(color: gridColor, fontSize: 8),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(2, y - 9));
    }

    // Compute points
    final pts = <Offset>[];
    for (int i = 0; i < n; i++) {
      final x = i * xStep;
      final rawY = (1 - values[i] / maxV) * size.height;
      final shimmer = math.sin(wavePhase + i * 0.5) * 1.5 * progress;
      pts.add(Offset(x, rawY + shimmer));
    }

    // Fill path
    final fillPath = Path()
      ..moveTo(0, size.height)
      ..lineTo(pts[0].dx, pts[0].dy * progress);
    for (int i = 1; i < pts.length; i++) {
      final prev = pts[i - 1];
      final cur  = Offset(pts[i].dx, pts[i].dy * progress);
      fillPath.cubicTo(prev.dx + xStep * 0.4, prev.dy,
          cur.dx - xStep * 0.4, cur.dy, cur.dx, cur.dy);
    }
    fillPath.lineTo(size.width, size.height);
    fillPath.close();
    canvas.drawPath(fillPath, Paint()
      ..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [fillColor, fillColor.withValues(alpha: 0.01)])
          .createShader(Rect.fromLTWH(0, 0, size.width, size.height)));

    // Line path
    final linePath = Path()..moveTo(pts[0].dx, pts[0].dy * progress);
    for (int i = 1; i < pts.length; i++) {
      final prev = pts[i - 1];
      final cur  = Offset(pts[i].dx, pts[i].dy * progress);
      linePath.cubicTo(prev.dx + xStep * 0.4, prev.dy,
          cur.dx - xStep * 0.4, cur.dy, cur.dx, cur.dy);
    }
    canvas.drawPath(linePath, Paint()
      ..color = lineColor..strokeWidth = 2.2
      ..style = PaintingStyle.stroke..strokeCap = StrokeCap.round);

    // Dots
    for (final p in pts) {
      final dp = Offset(p.dx, p.dy * progress);
      canvas.drawCircle(dp, 3.5, Paint()..color = dotColor);
      canvas.drawCircle(dp, 2.0, Paint()..color = Colors.white.withValues(alpha: 0.6));
    }
  }

  @override
  bool shouldRepaint(_AreaChartPainter old) =>
      old.progress != progress || old.wavePhase != wavePhase;
}

// ─────────────────────────────────────────────────────────────────────────────
// _RadarChart — spider chart for top-N districts
// ─────────────────────────────────────────────────────────────────────────────
class _RadarChart extends StatelessWidget {
  final List<FloodData> data;
  final Animation<double> gaugeAnim;
  const _RadarChart({required this.data, required this.gaugeAnim});

  @override
  Widget build(BuildContext context) {
    final t = RiverColors.of(context);
    final top = data.take(6).toList();
    if (top.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: t.cardBg, borderRadius: BorderRadius.circular(20),
            border: Border.all(color: t.stroke)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('MULTI-AXIS RISK RADAR · TOP DISTRICTS',
              style: TextStyle(color: t.textSecondary, fontSize: 9.5,
                  fontWeight: FontWeight.w800, letterSpacing: 1.0)),
          const SizedBox(height: 12),
          SizedBox(
            height: 200,
            child: AnimatedBuilder(
              animation: gaugeAnim,
              builder: (_, __) => CustomPaint(
                painter: _RadarChartPainter(
                  labels: top.map((d) => d.city).toList(),
                  values: top.map((d) => d.capacityPercent / 100).toList(),
                  colors: top.map((d) => _riskCol(d.riskLevel)).toList(),
                  progress: gaugeAnim.value,
                  gridColor: t.stroke,
                  accentColor: t.accent,
                ),
                size: Size.infinite,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10, runSpacing: 6,
            children: top.map((d) {
              final col = _riskCol(d.riskLevel);
              return Row(mainAxisSize: MainAxisSize.min, children: [
                Container(width: 8, height: 8,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: col)),
                const SizedBox(width: 5),
                Text(d.city, style: TextStyle(color: t.textSecondary, fontSize: 9,
                    fontWeight: FontWeight.w600)),
              ]);
            }).toList(),
          ),
        ]),
      ),
    );
  }
}

class _RadarChartPainter extends CustomPainter {
  final List<String> labels;
  final List<double> values;
  final List<Color> colors;
  final double progress;
  final Color gridColor, accentColor;

  const _RadarChartPainter({required this.labels, required this.values,
      required this.colors, required this.progress,
      required this.gridColor, required this.accentColor});

  @override
  void paint(Canvas canvas, Size size) {
    final n = labels.length;
    if (n < 3) return;
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r  = math.min(cx, cy) - 24;
    final angleStep = 2 * math.pi / n;

    // Grid rings
    for (int ring = 1; ring <= 4; ring++) {
      final rr = r * ring / 4;
      final path = Path();
      for (int i = 0; i < n; i++) {
        final angle = -math.pi / 2 + i * angleStep;
        final x = cx + rr * math.cos(angle);
        final y = cy + rr * math.sin(angle);
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      path.close();
      canvas.drawPath(path, Paint()
        ..color = gridColor.withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.7);
    }

    // Spoke lines
    for (int i = 0; i < n; i++) {
      final angle = -math.pi / 2 + i * angleStep;
      canvas.drawLine(
        Offset(cx, cy),
        Offset(cx + r * math.cos(angle), cy + r * math.sin(angle)),
        Paint()..color = gridColor..strokeWidth = 0.7,
      );
    }

    // Data polygon
    final dataPath = Path();
    for (int i = 0; i < n; i++) {
      final angle = -math.pi / 2 + i * angleStep;
      final val   = values.length > i ? values[i] * progress : 0.0;
      final x = cx + r * val * math.cos(angle);
      final y = cy + r * val * math.sin(angle);
      if (i == 0) {
        dataPath.moveTo(x, y);
      } else {
        dataPath.lineTo(x, y);
      }
    }
    dataPath.close();
    canvas.drawPath(dataPath, Paint()
      ..color = accentColor.withValues(alpha: 0.15)
      ..style = PaintingStyle.fill);
    canvas.drawPath(dataPath, Paint()
      ..color = accentColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0);

    // Data dots + labels
    for (int i = 0; i < n; i++) {
      final angle = -math.pi / 2 + i * angleStep;
      final val   = values.length > i ? values[i] * progress : 0.0;
      final dx = cx + r * val * math.cos(angle);
      final dy = cy + r * val * math.sin(angle);
      final col = colors.length > i ? colors[i] : accentColor;

      canvas.drawCircle(Offset(dx, dy), 4, Paint()..color = col);
      canvas.drawCircle(Offset(dx, dy), 2.5, Paint()..color = Colors.white.withValues(alpha: 0.6));

      // Label
      final labelX = cx + (r + 16) * math.cos(angle);
      final labelY = cy + (r + 16) * math.sin(angle);
      final label = labels[i].length > 5 ? '${labels[i].substring(0, 5)}…' : labels[i];
      final tp = TextPainter(
        text: TextSpan(text: label,
            style: TextStyle(color: col, fontSize: 9, fontWeight: FontWeight.w700)),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      )..layout();
      tp.paint(canvas, Offset(labelX - tp.width / 2, labelY - tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(_RadarChartPainter old) =>
      old.progress != progress || old.values != values;
}

// ─────────────────────────────────────────────────────────────────────────────
// _SystemStats
// ─────────────────────────────────────────────────────────────────────────────
class _SystemStats extends StatelessWidget {
  final RealTimeService service;
  final AnimationController pulseCtrl;
  final Animation<double> gaugeAnim;
  final bool reduceMotion;
  const _SystemStats({required this.service, required this.pulseCtrl,
      required this.gaugeAnim, required this.reduceMotion});

  @override
  Widget build(BuildContext context) {
    final t = RiverColors.of(context);
    final health = [
      (label: 'GloFAS',    ok: service.isOnline, detail: 'Flood Forecast'),
      (label: 'WRD Bihar', ok: service.isOnline, detail: 'River Gauge'),
      (label: 'IMD',       ok: service.isOnline, detail: 'Rainfall · Bihar'),
      (label: 'CWC',       ok: true,             detail: 'Central Water'),
      (label: 'NDMA',      ok: true,             detail: 'Disaster Mgmt'),
      (label: 'BSDMA',     ok: service.isOnline, detail: 'Bihar State DMA'),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: t.cardBg, borderRadius: BorderRadius.circular(20),
            border: Border.all(color: t.stroke)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('NODE STATUS · BIHAR NETWORK',
              style: TextStyle(color: t.textSecondary, fontSize: 9.5,
                  fontWeight: FontWeight.w800, letterSpacing: 1.0)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 9, runSpacing: 9,
            children: health.map((h) {
              final col = h.ok ? AppPalette.safe : AppPalette.critical;
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                decoration: BoxDecoration(
                  color: col.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: col.withValues(alpha: 0.22)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  AnimatedBuilder(
                    animation: pulseCtrl,
                    builder: (_, __) => Container(width: 6, height: 6,
                        decoration: BoxDecoration(shape: BoxShape.circle,
                            color: col.withValues(alpha: h.ok ? 0.5 + pulseCtrl.value * 0.5 : 0.8),
                            boxShadow: h.ok ? [BoxShadow(
                                color: col.withValues(alpha: pulseCtrl.value * 0.5), blurRadius: 6)] : null)),
                  ),
                  const SizedBox(width: 8),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(h.label, style: TextStyle(color: t.textPrimary, fontSize: 11,
                        fontWeight: FontWeight.w800)),
                    Text(h.detail, style: TextStyle(color: t.textSecondary, fontSize: 8.5)),
                  ]),
                ]),
              );
            }).toList(),
          ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _Footer
// ─────────────────────────────────────────────────────────────────────────────
class _Footer extends StatelessWidget {
  final int totalStations, riversCount, districtsAtRisk;
  final DateTime? lastUpdated;
  const _Footer({required this.totalStations, required this.riversCount,
      required this.districtsAtRisk, required this.lastUpdated});

  @override
  Widget build(BuildContext context) {
    final t = RiverColors.of(context);
    final fmt = lastUpdated != null ? DateFormat('dd MMM yyyy, HH:mm:ss').format(lastUpdated!) : 'Never';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: t.cardBg, borderRadius: BorderRadius.circular(20),
            border: Border.all(color: t.stroke)),
        child: Column(children: [
          // Top command label
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: t.accent.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: t.accent.withValues(alpha: 0.20))),
            child: Text('BIHAR FLOOD INTELLIGENCE SYSTEM v2.7',
                style: TextStyle(color: t.accent, fontSize: 8.5,
                    fontWeight: FontWeight.w800, letterSpacing: 1.2)),
          ),
          const SizedBox(height: 14),
          Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
            _footerStat('$totalStations', 'stations', t),
            Container(width: 1, height: 34, color: t.stroke),
            _footerStat('$riversCount', 'rivers', t),
            Container(width: 1, height: 34, color: t.stroke),
            _footerStat('${_biharDistricts.length}', 'districts', t),
            Container(width: 1, height: 34, color: t.stroke),
            _footerStat('$districtsAtRisk', 'at risk', t),
          ]),
          const SizedBox(height: 12),
          Text('Last sync: $fmt',
              style: TextStyle(color: t.textSecondary, fontSize: 9,
                  fontWeight: FontWeight.w600, letterSpacing: 0.5,
                  fontFeatures: const [FontFeature.tabularFigures()]),
              textAlign: TextAlign.center),
          const SizedBox(height: 3),
          Text('Sources: WRD Bihar · GloFAS · IMD · CWC · BSDMA',
              style: TextStyle(color: t.textSecondary, fontSize: 8.5),
              textAlign: TextAlign.center),
        ]),
      ),
    );
  }

  Widget _footerStat(String val, String label, RiverColors t) => Column(children: [
    Text(val, style: TextStyle(color: t.textPrimary, fontSize: 20, fontWeight: FontWeight.w900,
        fontFeatures: const [FontFeature.tabularFigures()])),
    Text(label, style: TextStyle(color: t.textSecondary, fontSize: 9.5,
        fontWeight: FontWeight.w600)),
  ]);
}

// ─────────────────────────────────────────────────────────────────────────────
// _EmptyState
// ─────────────────────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final t = RiverColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
      child: Column(children: [
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 800),
          curve: Curves.elasticOut,
          builder: (_, v, child) => Transform.scale(scale: v, child: child),
          child: Container(
            width: 68, height: 68,
            decoration: BoxDecoration(shape: BoxShape.circle,
                border: Border.all(color: t.accent.withValues(alpha: 0.3), width: 1.5),
                color: t.accent.withValues(alpha: 0.08)),
            child: Icon(Icons.radar_rounded, color: t.accent, size: 32),
          ),
        ),
        const SizedBox(height: 20),
        Text('NO SIGNAL', style: TextStyle(color: t.textPrimary,
            fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 2.0)),
        const SizedBox(height: 6),
        Text('Awaiting Bihar WRD data feed.\nPull down to retry or check network.',
            style: TextStyle(color: t.textSecondary, fontSize: 12),
            textAlign: TextAlign.center),
      ]),
    );
  }
}
