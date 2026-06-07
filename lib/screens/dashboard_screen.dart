// lib/screens/dashboard_screen.dart  v26 — analyze clean
// Collapsible sections · animated charts · organic feel
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
  late Animation<double> _gaugeAnim;

  final Map<String, bool> _collapsed = {
    'rivers': false, 'hotspots': false, 'rainfall': false,
    'capacity': false, 'trend': false, 'log': false,
    'stats': false, 'map': false,
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
    Future.delayed(const Duration(seconds: 4), _rotateTicker);
    _service.addListener(_onData);
    _service.startPolling();
    _loadBanner();
    Future.microtask(() => _entryCtrl.forward());
  }

  void _rotateTicker() {
    if (!mounted) return;
    final alerts = _alertCities;
    if (alerts.isNotEmpty) setState(() => _tickerIdx = (_tickerIdx + 1) % alerts.length);
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
    for (final c in [_entryCtrl, _gaugeCtrl, _waveCtrl, _pulseCtrl, _countCtrl]) {
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
              SliverToBoxAdapter(child: _Header(
                pulseCtrl: _pulseCtrl, lastUpdated: _service.lastFetchTime,
                isOnline: _service.isOnline, onRefresh: _refresh,
              )),
              SliverToBoxAdapter(child: _HeroGauge(
                gaugeAnim: _gaugeAnim, waveCtrl: _waveCtrl,
                pulseCtrl: _pulseCtrl, countCtrl: _countCtrl,
                overallRisk: _overallRisk, critical: _criticalCount,
                severe: _severeCount, moderate: _moderateCount,
                safe: _safeCount, total: data.length,
                alertCities: _alertCities, tickerIdx: _tickerIdx,
                reduceMotion: _reduceMotion,
              )),
              SliverToBoxAdapter(child: _QuickGrid(entryCtrl: _entryCtrl)),

              if (data.isEmpty)
                const SliverToBoxAdapter(child: _EmptyState())
              else ...[
                SliverToBoxAdapter(child: _CollapsibleSection(
                  sectionKey: 'rivers', title: 'Live River Levels',
                  subtitle: 'Sorted by risk · tap for detail',
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
                SliverToBoxAdapter(child: _CollapsibleSection(
                  sectionKey: 'hotspots', title: 'Hotspot Districts',
                  subtitle: '${_alertCities.length} active alerts',
                  icon: Icons.crisis_alert_rounded, color: AppPalette.critical,
                  collapsed: _isCollapsed('hotspots'), onToggle: () => _toggle('hotspots'),
                  child: _HotspotPageView(items: _alertCities, pulseCtrl: _pulseCtrl),
                )),
                SliverToBoxAdapter(child: _CollapsibleSection(
                  sectionKey: 'rainfall', title: 'Rainfall Estimate',
                  subtitle: 'IMD 24h · Bihar',
                  icon: Icons.grain_rounded, color: AppPalette.gold,
                  collapsed: _isCollapsed('rainfall'), onToggle: () => _toggle('rainfall'),
                  child: _RainfallBars(data: data, gaugeAnim: _gaugeAnim, reduceMotion: _reduceMotion),
                )),
                SliverToBoxAdapter(child: _CollapsibleSection(
                  sectionKey: 'capacity', title: 'Capacity Overview',
                  subtitle: 'All monitored rivers',
                  icon: Icons.bar_chart_rounded, color: AppPalette.gold,
                  collapsed: _isCollapsed('capacity'), onToggle: () => _toggle('capacity'),
                  child: _AnimatedBarChart(
                    values: data.map((d) => d.capacityPercent).toList(),
                    labels: data.map((d) => d.city).toList(),
                    colors: data.map((d) => _riskCol(d.riskLevel)).toList(),
                    entryCtrl: _entryCtrl, reduceMotion: _reduceMotion,
                  ),
                )),
                SliverToBoxAdapter(child: _CollapsibleSection(
                  sectionKey: 'trend', title: 'Trend Analysis',
                  subtitle: 'Capacity distribution · live',
                  icon: Icons.show_chart_rounded, color: AppPalette.cyan,
                  collapsed: _isCollapsed('trend'), onToggle: () => _toggle('trend'),
                  child: _AnimatedAreaChart(
                    values: data.map((d) => d.capacityPercent).toList(),
                    labels: data.map((d) => d.city).toList(),
                    gaugeAnim: _gaugeAnim, waveCtrl: _waveCtrl,
                    reduceMotion: _reduceMotion,
                  ),
                )),
                SliverToBoxAdapter(child: _CollapsibleSection(
                  sectionKey: 'log', title: 'Alert Activity',
                  subtitle: 'Recent critical events',
                  icon: Icons.history_rounded, color: AppPalette.danger,
                  collapsed: _isCollapsed('log'), onToggle: () => _toggle('log'),
                  child: _AlertLog(data: _alertCities, entryCtrl: _entryCtrl),
                )),
                SliverToBoxAdapter(child: _CollapsibleSection(
                  sectionKey: 'stats', title: 'System Health',
                  subtitle: 'Data pipeline status',
                  icon: Icons.analytics_outlined, color: AppPalette.safe,
                  collapsed: _isCollapsed('stats'), onToggle: () => _toggle('stats'),
                  child: _SystemStats(
                    service: _service, pulseCtrl: _pulseCtrl,
                    gaugeAnim: _gaugeAnim, reduceMotion: _reduceMotion,
                  ),
                )),
                SliverToBoxAdapter(child: _CollapsibleSection(
                  sectionKey: 'map', title: 'State Risk Map',
                  subtitle: 'Region-level flood index',
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
                  statesAtRisk: data.where((d) => d.riskLevel != 'LOW').map((d) => d.state).toSet().length,
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
// _Header
// ─────────────────────────────────────────────────────────────────────────────
class _Header extends StatelessWidget {
  final AnimationController pulseCtrl;
  final DateTime? lastUpdated;
  final bool isOnline;
  final VoidCallback onRefresh;
  const _Header({required this.pulseCtrl, required this.lastUpdated,
      required this.isOnline, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final t = RiverColors.of(context);
    final timeStr = lastUpdated != null ? DateFormat('HH:mm').format(lastUpdated!) : '--:--';
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text('FLOOD COMMAND', style: TextStyle(color: t.accent, fontSize: 10,
                      fontWeight: FontWeight.w800, letterSpacing: 2.5)),
                  const SizedBox(width: 8),
                  AnimatedBuilder(
                    animation: pulseCtrl,
                    builder: (_, __) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: (isOnline ? AppPalette.safe : AppPalette.critical)
                            .withValues(alpha: 0.15 + pulseCtrl.value * 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(isOnline ? '● LIVE' : '○ OFFLINE',
                          style: TextStyle(
                            color: isOnline ? AppPalette.safe : AppPalette.critical,
                            fontSize: 8, fontWeight: FontWeight.w800, letterSpacing: 1)),
                    ),
                  ),
                ]),
                const SizedBox(height: 2),
                Text('Bihar Flood Intelligence', style: TextStyle(
                    color: t.textPrimary, fontSize: 21,
                    fontWeight: FontWeight.w900, letterSpacing: -0.5)),
                const SizedBox(height: 3),
                Text('Updated $timeStr · WRD Bihar + GloFAS',
                    style: TextStyle(color: t.textSecondary, fontSize: 10,
                        fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          IconButton(onPressed: () => showPremiumThemeSheet(context),
              icon: Icon(Icons.palette_outlined, color: t.accent, size: 22)),
          IconButton(onPressed: onRefresh,
              icon: Icon(Icons.refresh_rounded, color: t.textSecondary, size: 22)),
        ],
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
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      decoration: BoxDecoration(
        color: t.cardBg,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: col.withValues(alpha: 0.20)),
        boxShadow: [BoxShadow(color: col.withValues(alpha: 0.12),
            blurRadius: 32, spreadRadius: -4, offset: const Offset(0, 8))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  width: 108, height: 108,
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
                              style: TextStyle(color: col, fontSize: 24,
                                  fontWeight: FontWeight.w900, letterSpacing: -1),
                            ),
                          ),
                          Text('RISK', style: TextStyle(color: t.textSecondary,
                              fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 2)),
                        ]),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(children: [
                    _riskRow('CRITICAL', critical, AppPalette.critical, countCtrl, t),
                    const SizedBox(height: 8),
                    _riskRow('SEVERE',   severe,   AppPalette.danger,   countCtrl, t),
                    const SizedBox(height: 8),
                    _riskRow('MODERATE', moderate, AppPalette.warning,  countCtrl, t),
                    const SizedBox(height: 8),
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('$total stations monitored',
                    style: TextStyle(color: t.textSecondary, fontSize: 11,
                        fontWeight: FontWeight.w500)),
                Text('Bihar · WRD', style: TextStyle(color: t.textSecondary, fontSize: 11)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ignore: non_constant_identifier_names (top-level helper, lowercase per fix)
Widget _riskRow(String label, int count, Color color, AnimationController ctrl, RiverColors t) {
  return Row(children: [
    Container(width: 10, height: 10,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color,
            boxShadow: [BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 4)])),
    const SizedBox(width: 8),
    Expanded(child: Text(label, style: TextStyle(color: t.textSecondary,
        fontSize: 11, fontWeight: FontWeight.w600))),
    AnimatedBuilder(animation: ctrl, builder: (_, __) => Text(
      '${(count * ctrl.value).round()}',
      style: TextStyle(color: color, fontSize: 15, fontWeight: FontWeight.w900),
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
        borderRadius: BorderRadius.circular(14),
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
        Expanded(child: Text(city.city, style: TextStyle(color: t.textPrimary,
            fontSize: 12, fontWeight: FontWeight.w700))),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(color: col.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20)),
          child: Text('$total alert${total == 1 ? '' : 's'}',
              style: TextStyle(color: col, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
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
    const waveAmp = 6.0;
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
        colors: [color.withValues(alpha: 0.7), color.withValues(alpha: 0.9)],
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
    (label: 'State Matrix',  icon: Icons.grid_view_rounded,      color: AppPalette.warning,  route: '/state_matrix'),
    (label: 'Weather',       icon: Icons.cloud_rounded,          color: AppPalette.cyan,     route: '/weather'),
  ];

  @override
  Widget build(BuildContext context) {
    final t = RiverColors.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3, crossAxisSpacing: 10,
          mainAxisSpacing: 10, childAspectRatio: 1.1,
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
                  child: Transform.translate(offset: Offset(0, 16 * (1 - t2)), child: child));
            },
            child: GestureDetector(
              onTap: () { HapticFeedback.lightImpact(); Navigator.pushNamed(context, item.route); },
              child: Container(
                decoration: BoxDecoration(
                  color: t.cardBg,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: item.color.withValues(alpha: 0.18)),
                  boxShadow: [BoxShadow(color: item.color.withValues(alpha: 0.06),
                      blurRadius: 12, offset: const Offset(0, 4))],
                ),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(shape: BoxShape.circle,
                        color: item.color.withValues(alpha: 0.12)),
                    child: Icon(item.icon, color: item.color, size: 22),
                  ),
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
            padding: const EdgeInsets.fromLTRB(20, 18, 16, 10),
            child: Row(children: [
              Container(width: 32, height: 32,
                  decoration: BoxDecoration(shape: BoxShape.circle,
                      color: color.withValues(alpha: 0.12)),
                  child: Icon(icon, color: color, size: 15)),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: TextStyle(color: t.textPrimary, fontSize: 13.5,
                    fontWeight: FontWeight.w800)),
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
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          decoration: BoxDecoration(
            color: t.cardBg,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: col.withValues(alpha: 0.18)),
            boxShadow: [BoxShadow(color: col.withValues(alpha: 0.06),
                blurRadius: 12, offset: const Offset(0, 3))],
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                AnimatedBuilder(
                  animation: pulseCtrl,
                  builder: (_, __) {
                    final glow = data.riskLevel == 'CRITICAL' || data.riskLevel == 'SEVERE';
                    return Container(width: 9, height: 9,
                        decoration: BoxDecoration(shape: BoxShape.circle,
                            color: glow ? col.withValues(alpha: 0.5 + pulseCtrl.value * 0.5) : col,
                            boxShadow: glow ? [BoxShadow(
                                color: col.withValues(alpha: pulseCtrl.value * 0.6), blurRadius: 8)] : null));
                  },
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(data.city, style: TextStyle(color: t.textPrimary,
                    fontSize: 13, fontWeight: FontWeight.w800))),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(color: col.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: col.withValues(alpha: 0.25))),
                  child: Text(data.riskLevel, style: TextStyle(color: col, fontSize: 9,
                      fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                ),
              ]),
              if (data.riverName != null && data.riverName!.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(data.riverName!, style: TextStyle(color: t.textSecondary, fontSize: 10)),
              ],
              const SizedBox(height: 10),
              Container(
                height: 6,
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
                            gradient: LinearGradient(colors: [col.withValues(alpha: 0.7), col])),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 7),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('${pct.toStringAsFixed(1)}% capacity',
                    style: TextStyle(color: col, fontSize: 11, fontWeight: FontWeight.w700)),
                Text(data.state, style: TextStyle(color: t.textSecondary, fontSize: 10)),
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
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: t.cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppPalette.safe.withValues(alpha: 0.20))),
          child: const Row(children: [
            Icon(Icons.check_circle_outline_rounded, color: AppPalette.safe, size: 18),
            SizedBox(width: 10),
            Text('No active hotspots', style: TextStyle(color: AppPalette.safe,
                fontSize: 13, fontWeight: FontWeight.w700)),
          ]),
        ),
      );
    }
    return SizedBox(
      height: 130,
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
                color: t.cardBg, borderRadius: BorderRadius.circular(20),
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
                        borderRadius: BorderRadius.circular(20)),
                    child: Text(d.riskLevel, style: TextStyle(color: col, fontSize: 8,
                        fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                  ),
                ]),
                const SizedBox(height: 8),
                Text(d.city, style: TextStyle(color: t.textPrimary, fontSize: 14,
                    fontWeight: FontWeight.w900), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(d.riverName ?? d.state, style: TextStyle(color: t.textSecondary, fontSize: 10),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                const Spacer(),
                ClipRRect(borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(value: d.capacityPercent / 100,
                        backgroundColor: t.stroke,
                        valueColor: AlwaysStoppedAnimation(col), minHeight: 4)),
                const SizedBox(height: 4),
                Text('${d.capacityPercent.toStringAsFixed(0)}% capacity',
                    style: TextStyle(color: col, fontSize: 10, fontWeight: FontWeight.w700)),
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
    final items = data.take(8).toList();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
        decoration: BoxDecoration(color: t.cardBg, borderRadius: BorderRadius.circular(20),
            border: Border.all(color: t.stroke)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('24h Estimated Rainfall', style: TextStyle(color: t.textSecondary, fontSize: 10,
              fontWeight: FontWeight.w600, letterSpacing: 0.5)),
          const SizedBox(height: 12),
          SizedBox(
            height: 80,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: items.asMap().entries.map((e) {
                final i  = e.key;
                final d  = e.value;
                final mm = (d.effectiveRainfallMm).clamp(0.0, 80.0);
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                      AnimatedBuilder(
                        animation: gaugeAnim,
                        builder: (_, __) {
                          final frac = reduceMotion ? 1.0
                              : ((gaugeAnim.value - i * 0.06).clamp(0.0, 1.0));
                          final h = (mm / 80) * 56 * frac;
                          return Container(
                            width: double.infinity, height: h.clamp(3.0, 56.0),
                            decoration: BoxDecoration(
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                              gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter,
                                  colors: [t.accent.withValues(alpha: 0.8), t.accent.withValues(alpha: 0.4)]),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 4),
                      Text(d.city.substring(0, math.min(3, d.city.length)),
                          style: TextStyle(color: t.textSecondary, fontSize: 8),
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
        child: SizedBox(
          height: 120,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: values.asMap().entries.map((e) {
              final i   = e.key;
              final val = e.value;
              final col = colors.length > i ? colors[i] : t.accent;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2.5),
                  child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                    AnimatedBuilder(
                      animation: entryCtrl,
                      builder: (_, __) {
                        final delay = (i * 0.05).clamp(0.0, 0.7);
                        final p = reduceMotion ? 1.0
                            : ((entryCtrl.value - delay) / (1.0 - delay)).clamp(0.0, 1.0);
                        final h = (val / maxVal) * 80 * p;
                        return Container(
                          width: double.infinity, height: h.clamp(2.0, 80.0),
                          decoration: BoxDecoration(
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
                            gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
                                colors: [col, col.withValues(alpha: 0.6)]),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 4),
                    Text(labels.length > i ? labels[i].substring(0, math.min(3, labels[i].length)) : '',
                        style: TextStyle(color: t.textSecondary, fontSize: 8),
                        textAlign: TextAlign.center),
                  ]),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _AnimatedAreaChart — smooth bezier area chart with CustomPainter
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
          Text('Capacity Distribution', style: TextStyle(color: t.textSecondary,
              fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
          const SizedBox(height: 8),
          SizedBox(
            height: 110,
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
                    style: TextStyle(color: t.textSecondary, fontSize: 8)),
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
    final maxV = values.reduce(math.max).clamp(1.0, double.infinity);
    final n = values.length;
    final xStep = size.width / (n - 1).clamp(1, n);

    // Grid
    final gridPaint = Paint()..color = gridColor..strokeWidth = 0.5;
    for (int g = 0; g <= 4; g++) {
      final y = size.height - (g / 4) * size.height;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Points
    final pts = <Offset>[];
    for (int i = 0; i < n; i++) {
      final x = i * xStep;
      final rawY = (1 - values[i] / maxV) * size.height;
      final shimmer = math.sin(wavePhase + i * 0.5) * 1.5 * progress;
      pts.add(Offset(x, rawY + shimmer));
    }

    // Fill
    final fillPath = Path()..moveTo(0, size.height)..lineTo(pts[0].dx, pts[0].dy * progress);
    for (int i = 1; i < pts.length; i++) {
      final prev = pts[i - 1];
      final cur  = Offset(pts[i].dx, pts[i].dy * progress);
      fillPath.cubicTo(prev.dx + xStep * 0.4, prev.dy,
          cur.dx - xStep * 0.4, cur.dy, cur.dx, cur.dy);
    }
    // Fix: split lineTo + close into separate statements (cascade on void result)
    fillPath.lineTo(size.width, size.height);
    fillPath.close();
    canvas.drawPath(fillPath, Paint()
      ..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [fillColor, fillColor.withValues(alpha: 0.01)])
          .createShader(Rect.fromLTWH(0, 0, size.width, size.height)));

    // Line
    final linePath = Path()..moveTo(pts[0].dx, pts[0].dy * progress);
    for (int i = 1; i < pts.length; i++) {
      final prev = pts[i - 1];
      final cur  = Offset(pts[i].dx, pts[i].dy * progress);
      linePath.cubicTo(prev.dx + xStep * 0.4, prev.dy,
          cur.dx - xStep * 0.4, cur.dy, cur.dx, cur.dy);
    }
    canvas.drawPath(linePath, Paint()
      ..color = lineColor..strokeWidth = 2.0
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
// _AlertLog
// ─────────────────────────────────────────────────────────────────────────────
class _AlertLog extends StatelessWidget {
  final List<FloodData> data;
  final AnimationController entryCtrl;
  const _AlertLog({required this.data, required this.entryCtrl});

  @override
  Widget build(BuildContext context) {
    final t = RiverColors.of(context);
    if (data.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: t.cardBg, borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppPalette.safe.withValues(alpha: 0.20))),
          child: Row(children: [
            const Icon(Icons.check_circle_outline_rounded, color: AppPalette.safe, size: 18),
            const SizedBox(width: 10),
            Text('No critical alerts logged',
                style: TextStyle(color: t.textSecondary, fontSize: 12)),
          ]),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Container(
        decoration: BoxDecoration(color: t.cardBg, borderRadius: BorderRadius.circular(20),
            border: Border.all(color: t.stroke)),
        child: Column(
          children: data.asMap().entries.map((e) {
            final i   = e.key;
            final d   = e.value;
            final col = _riskCol(d.riskLevel);
            return AnimatedBuilder(
              animation: entryCtrl,
              builder: (_, child) {
                final delay = (i * 0.07).clamp(0.0, 0.6);
                final p = ((entryCtrl.value - delay) / (1.0 - delay)).clamp(0.0, 1.0);
                return Opacity(opacity: p,
                    child: Transform.translate(offset: Offset(-16 * (1 - p), 0), child: child));
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  border: i < data.length - 1
                      ? Border(bottom: BorderSide(color: t.stroke, width: 0.7))
                      : null,
                ),
                child: Row(children: [
                  Container(width: 3, height: 36,
                      decoration: BoxDecoration(color: col, borderRadius: BorderRadius.circular(2))),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(d.city, style: TextStyle(color: t.textPrimary, fontSize: 12,
                        fontWeight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text('${d.riverName ?? d.state} · ${d.capacityPercent.toStringAsFixed(0)}% capacity',
                        style: TextStyle(color: t.textSecondary, fontSize: 10)),
                  ])),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: col.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(20)),
                    child: Text(d.riskLevel, style: TextStyle(color: col, fontSize: 9,
                        fontWeight: FontWeight.w800)),
                  ),
                ]),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
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
      (label: 'GloFAS',    ok: service.isOnline, detail: 'flood forecast'),
      (label: 'WRD Bihar', ok: service.isOnline, detail: 'river gauge'),
      (label: 'IMD',       ok: service.isOnline, detail: 'rainfall'),
      (label: 'CWC',       ok: true,             detail: 'central water'),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: t.cardBg, borderRadius: BorderRadius.circular(20),
            border: Border.all(color: t.stroke)),
        child: Wrap(
          spacing: 10, runSpacing: 10,
          children: health.map((h) {
            final col = h.ok ? AppPalette.safe : AppPalette.critical;
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: col.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: col.withValues(alpha: 0.20)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                AnimatedBuilder(
                  animation: pulseCtrl,
                  builder: (_, __) => Container(width: 7, height: 7,
                      decoration: BoxDecoration(shape: BoxShape.circle,
                          color: col.withValues(alpha: h.ok ? 0.5 + pulseCtrl.value * 0.5 : 0.8),
                          boxShadow: h.ok ? [BoxShadow(
                              color: col.withValues(alpha: pulseCtrl.value * 0.5), blurRadius: 6)] : null)),
                ),
                const SizedBox(width: 8),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(h.label, style: TextStyle(color: t.textPrimary, fontSize: 11,
                      fontWeight: FontWeight.w800)),
                  Text(h.detail, style: TextStyle(color: t.textSecondary, fontSize: 9)),
                ]),
              ]),
            );
          }).toList(),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _Footer
// ─────────────────────────────────────────────────────────────────────────────
class _Footer extends StatelessWidget {
  final int totalStations, riversCount, statesAtRisk;
  final DateTime? lastUpdated;
  const _Footer({required this.totalStations, required this.riversCount,
      required this.statesAtRisk, required this.lastUpdated});

  @override
  Widget build(BuildContext context) {
    final t = RiverColors.of(context);
    final fmt = lastUpdated != null ? DateFormat('dd MMM, HH:mm').format(lastUpdated!) : 'Never';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: t.cardBg, borderRadius: BorderRadius.circular(20),
            border: Border.all(color: t.stroke)),
        child: Column(children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
            _footerStat('$totalStations', 'stations', t),
            Container(width: 1, height: 32, color: t.stroke),
            _footerStat('$riversCount', 'rivers', t),
            Container(width: 1, height: 32, color: t.stroke),
            _footerStat('$statesAtRisk', 'at risk', t),
          ]),
          const SizedBox(height: 12),
          Text('Last updated: $fmt · Data: WRD Bihar, GloFAS, IMD',
              style: TextStyle(color: t.textSecondary, fontSize: 9.5,
                  fontWeight: FontWeight.w500),
              textAlign: TextAlign.center),
        ]),
      ),
    );
  }

  Widget _footerStat(String val, String label, RiverColors t) => Column(children: [
    Text(val, style: TextStyle(color: t.textPrimary, fontSize: 20, fontWeight: FontWeight.w900)),
    Text(label, style: TextStyle(color: t.textSecondary, fontSize: 10)),
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
            width: 72, height: 72,
            decoration: BoxDecoration(shape: BoxShape.circle,
                color: t.accent.withValues(alpha: 0.10)),
            child: Icon(Icons.water_drop_outlined, color: t.accent, size: 36),
          ),
        ),
        const SizedBox(height: 20),
        Text('No River Data', style: TextStyle(color: t.textPrimary,
            fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Text('Pull down to refresh or check your network connection.',
            style: TextStyle(color: t.textSecondary, fontSize: 13),
            textAlign: TextAlign.center),
      ]),
    );
  }
}
