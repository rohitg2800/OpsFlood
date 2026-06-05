// lib/screens/city_detail_screen.dart
// EQUINOX-BH — CityDetailScreen v4
// Phase 6 upgrades over v3:
//  - Animated staggered entry per section card (FadeTransition + SlideTransition)
//  - Threshold status banner  (danger / warning / normal colour strip)
//  - Share FAB  (copies city summary to clipboard + shows SnackBar)
//  - Skeleton loading state when data == null (shimmer-like pulse)
//  - Section collapse/expand toggle for Emergency Contacts (long list friendly)
//  - «View on Map» CTA chip linking to /bihar_river_map with city arg
//  - Refreshes via pull-to-refresh (RefreshIndicator wrapping CustomScrollView)
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/flood_data.dart';
import '../models/river_monitoring.dart';
import '../providers/flood_providers.dart';
import '../theme/river_theme.dart';
import '../widgets/sparkline_chart.dart';

class CityDetailScreen extends ConsumerStatefulWidget {
  static const String route = '/city_detail';

  final String cityName;
  const CityDetailScreen({super.key, required this.cityName});

  @override
  ConsumerState<CityDetailScreen> createState() => _CityDetailScreenState();
}

class _CityDetailScreenState extends ConsumerState<CityDetailScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entryCtrl;
  late final List<Animation<double>>  _sectionFades;
  late final List<Animation<Offset>>  _sectionSlides;

  bool _contactsExpanded = false;
  bool _refreshing       = false;

  static const int _sectionCount = 6; // gauge, trend, imd, ndma, contacts, predict

  @override
  void initState() {
    super.initState();
    _entryCtrl = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 900));

    _sectionFades  = [];
    _sectionSlides = [];
    for (int i = 0; i < _sectionCount; i++) {
      final start = i * 0.12;
      final end   = (start + 0.28).clamp(0.0, 1.0);
      _sectionFades.add(
        Tween<double>(begin: 0, end: 1).animate(
            CurvedAnimation(
                parent: _entryCtrl,
                curve: Interval(start, end, curve: Curves.easeOut))),
      );
      _sectionSlides.add(
        Tween<Offset>(
                begin: const Offset(0, 0.06), end: Offset.zero)
            .animate(CurvedAnimation(
                parent: _entryCtrl,
                curve: Interval(start, end, curve: Curves.easeOutCubic))),
      );
    }
    _entryCtrl.forward();
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    HapticFeedback.mediumImpact();
    try {
      await ref.read(realTimeProvider).refreshData();
      _entryCtrl
        ..reset()
        ..forward();
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  void _share(FloodData data) {
    final text =
        'EQUINOX-BH · ${widget.cityName}\n'
        'Level: ${data.currentLevel.toStringAsFixed(2)} m · '
        'Risk: ${data.riskLevel}\n'
        'W ${data.warningLevel.toStringAsFixed(1)} m  '
        'D ${data.dangerLevel.toStringAsFixed(1)} m\n'
        'Updated: ${DateFormat("dd MMM HH:mm").format(data.lastUpdated.toLocal())}';
    Clipboard.setData(ClipboardData(text: text));
    HapticFeedback.selectionClick();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Copied city summary to clipboard'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppPalette.abyss2,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Widget _section(int idx, Widget child) => FadeTransition(
        opacity: _sectionFades[idx],
        child: SlideTransition(
          position: _sectionSlides[idx],
          child: child,
        ),
      );

  @override
  Widget build(BuildContext context) {
    final data       = ref.watch(cityDataProvider(widget.cityName));
    final trend      = ref.watch(cityTrendProvider(widget.cityName));
    final imdAlerts  = ref.watch(
        stateImdAlertsProvider(data?.state ?? ''));
    final advisories = ref.watch(
        stateNdmaAdvisoriesProvider(data?.state ?? ''));
    final contacts   = ref
        .watch(stateEmergencyContactsProvider(data?.state ?? ''))
        .cast<EmergencyContact>();

    return Scaffold(
      backgroundColor: AppPalette.abyss0,
      floatingActionButton: data != null
          ? FloatingActionButton.small(
              heroTag: 'share_${widget.cityName}',
              backgroundColor: AppPalette.abyss2,
              foregroundColor: AppPalette.cyan,
              tooltip: 'Copy city summary',
              onPressed: () => _share(data),
              child: const Icon(Icons.share_rounded, size: 17),
            )
          : null,
      body: Container(
        decoration: AppPalette.scaffoldDecoration(),
        child: SafeArea(
          child: RefreshIndicator(
            color: AppPalette.cyan,
            backgroundColor: AppPalette.abyss2,
            onRefresh: _refresh,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics()),
              slivers: [

                // ── App Bar ────────────────────────────────────────────────
                SliverAppBar(
                  backgroundColor: Colors.transparent,
                  surfaceTintColor: Colors.transparent,
                  elevation: 0,
                  pinned: true,
                  leading: IconButton(
                    icon: const Icon(Icons.arrow_back_ios_rounded,
                        color: AppPalette.textWhite, size: 18),
                    onPressed: () => Navigator.pop(context),
                  ),
                  title: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.cityName,
                        style: const TextStyle(
                          color: AppPalette.textWhite,
                          fontWeight: FontWeight.w800,
                          fontSize: 17,
                        ),
                      ),
                      if (data != null)
                        Text(
                          '${data.riverName ?? "River"}  ·  ${data.state}',
                          style: const TextStyle(
                              color: AppPalette.textGrey,
                              fontSize: 10),
                        ),
                    ],
                  ),
                  actions: [
                    if (_refreshing)
                      const Padding(
                        padding: EdgeInsets.only(right: 14),
                        child: SizedBox(
                          width: 18, height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppPalette.cyan),
                        ),
                      )
                    else
                      IconButton(
                        icon: const Icon(Icons.refresh_rounded,
                            color: AppPalette.textGrey, size: 20),
                        onPressed: _refresh,
                      ),
                  ],
                ),

                // ── threshold banner ───────────────────────────────────────
                if (data != null)
                  SliverToBoxAdapter(
                    child: _ThresholdBanner(data: data),
                  ),

                // ── no-data skeleton ───────────────────────────────────────
                if (data == null)
                  SliverFillRemaining(
                    child: _SkeletonView(cityName: widget.cityName),
                  )

                // ── loaded body ────────────────────────────────────────────
                else
                  SliverPadding(
                    padding:
                        const EdgeInsets.fromLTRB(16, 10, 16, 100),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([

                        // 0 — gauge hero
                        _section(0, _GaugeHeroCard(data: data)),
                        const SizedBox(height: 12),

                        // 1 — 24-hr trend
                        if (trend.length >= 2) ...[
                          _section(
                            1,
                            _TrendCard(
                              trend:        trend,
                              warningLevel: data.warningLevel,
                              dangerLevel:  data.dangerLevel,
                              riskColor:    _riskColor(data.riskLevel),
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],

                        // 2 — IMD alerts
                        if (imdAlerts.isNotEmpty) ...[
                          _section(
                            2,
                            Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                _SectionLabel(
                                    '🌧  IMD Weather Alerts'),
                                ...imdAlerts
                                    .take(3)
                                    .map((a) => _ImdAlertTile(alert: a)),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],

                        // 3 — NDMA advisories
                        if (advisories.isNotEmpty) ...[
                          _section(
                            3,
                            Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                _SectionLabel(
                                    '🚨  NDMA Advisories'),
                                ...advisories
                                    .take(2)
                                    .map(
                                        (a) => _NdmaAdvisoryTile(adv: a)),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],

                        // 4 — emergency contacts (collapsible)
                        _section(
                          4,
                          _CollapsibleContacts(
                            contacts:  contacts,
                            state:     data.state,
                            expanded:  _contactsExpanded,
                            onToggle:  () => setState(
                                () => _contactsExpanded =
                                    !_contactsExpanded),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // CTA row: predict + map
                        _section(
                          5,
                          Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: _PredictCta(
                                    cityName:     widget.cityName,
                                    currentLevel: data.currentLevel),
                              ),
                              const SizedBox(width: 10),
                              _MapChip(cityName: widget.cityName),
                            ],
                          ),
                        ),
                      ]),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── helpers ───────────────────────────────────────────────────────────────────

Color _riskColor(String r) {
  switch (r.toUpperCase()) {
    case 'CRITICAL': return AppPalette.critical;
    case 'HIGH':     return AppPalette.danger;
    case 'SEVERE':   return AppPalette.danger;
    case 'MODERATE': return AppPalette.warning;
    default:         return AppPalette.safe;
  }
}

Color _imdColor(String s) {
  switch (s.toUpperCase()) {
    case 'RED':    return AppPalette.critical;
    case 'ORANGE': return AppPalette.danger;
    case 'YELLOW': return AppPalette.warning;
    default:       return AppPalette.safe;
  }
}

// ── Threshold Banner ──────────────────────────────────────────────────────────

class _ThresholdBanner extends StatelessWidget {
  final FloodData data;
  const _ThresholdBanner({required this.data});

  @override
  Widget build(BuildContext context) {
    final level  = data.currentLevel;
    final Color col;
    final String label;
    final IconData ico;

    if (level >= data.dangerLevel) {
      col   = AppPalette.critical;
      label = '⚠ ABOVE DANGER LEVEL  '
              '(+${(level - data.dangerLevel).toStringAsFixed(2)} m)';
      ico   = Icons.crisis_alert_rounded;
    } else if (level >= data.warningLevel) {
      col   = AppPalette.amber;
      label = '△ ABOVE WARNING LEVEL  '
              '(+${(level - data.warningLevel).toStringAsFixed(2)} m)';
      ico   = Icons.warning_rounded;
    } else {
      col   = AppPalette.safe;
      label = '✓ Below warning level  '
              '(${(data.warningLevel - level).toStringAsFixed(2)} m buffer)';
      ico   = Icons.check_circle_rounded;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
          horizontal: 16, vertical: 9),
      color: col.withValues(alpha: 0.10),
      child: Row(
        children: [
          Icon(ico, color: col, size: 14),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                  color: col,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Skeleton loading view ─────────────────────────────────────────────────────

class _SkeletonView extends StatefulWidget {
  final String cityName;
  const _SkeletonView({required this.cityName});
  @override
  State<_SkeletonView> createState() => _SkeletonViewState();
}

class _SkeletonViewState extends State<_SkeletonView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (_, __) {
        final alpha = 0.04 + 0.06 * _pulse.value;
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _bone(height: 100, alpha: alpha),
              const SizedBox(height: 12),
              _bone(height: 80, alpha: alpha),
              const SizedBox(height: 12),
              _bone(height: 60, alpha: alpha),
              const SizedBox(height: 24),
              Center(
                child: Column(
                  children: [
                    const Icon(Icons.location_off_rounded,
                        color: AppPalette.textGrey, size: 36),
                    const SizedBox(height: 10),
                    Text(
                      'No live data for ${widget.cityName}',
                      style: const TextStyle(
                          color: AppPalette.textGrey,
                          fontSize: 13),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Pull down to refresh',
                      style: TextStyle(
                          color: AppPalette.textDim,
                          fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _bone({required double height, required double alpha}) =>
      Container(
        width: double.infinity,
        height: height,
        decoration: BoxDecoration(
          color: AppPalette.textWhite.withValues(alpha: alpha),
          borderRadius: BorderRadius.circular(14),
        ),
      );
}

// ── Gauge Hero Card ───────────────────────────────────────────────────────────

class _GaugeHeroCard extends StatelessWidget {
  final FloodData data;
  const _GaugeHeroCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final rc     = _riskColor(data.riskLevel);
    final pct    = data.capacityPercent.clamp(0.0, 100.0);
    final isLive = data.status.toUpperCase() != 'ESTIMATED';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppPalette.abyss1,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: rc.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
              color: rc.withValues(alpha: 0.10),
              blurRadius: 22,
              offset: const Offset(0, 6)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(data.riverName ?? 'River',
                        style: const TextStyle(
                            color: AppPalette.textGrey, fontSize: 12)),
                    const SizedBox(height: 2),
                    Text(data.state,
                        style: const TextStyle(
                            color: AppPalette.textWhite,
                            fontWeight: FontWeight.w600,
                            fontSize: 13)),
                  ],
                ),
              ),
              _badge(
                  label: data.riskLevel,
                  bg: rc.withValues(alpha: 0.15),
                  fg: rc,
                  border: rc.withValues(alpha: 0.5)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${data.currentLevel.toStringAsFixed(2)} m',
                style: TextStyle(
                    color: rc,
                    fontWeight: FontWeight.w900,
                    fontSize: 38,
                    letterSpacing: -1),
              ),
              const SizedBox(width: 10),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: _badge(
                    label: isLive ? 'LIVE · CWC' : 'ESTIMATED',
                    bg: (isLive ? AppPalette.cyan : AppPalette.textGrey)
                        .withValues(alpha: 0.12),
                    fg: isLive ? AppPalette.cyan : AppPalette.textGrey,
                    border:
                        (isLive ? AppPalette.cyan : AppPalette.textGrey)
                            .withValues(alpha: 0.45)),
              ),
              if (data.imdSeverity != null) ...[
                const SizedBox(width: 6),
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: _badge(
                      label: 'IMD ${data.imdSeverity}',
                      bg: _imdColor(data.imdSeverity!)
                          .withValues(alpha: 0.15),
                      fg: _imdColor(data.imdSeverity!),
                      border: _imdColor(data.imdSeverity!)
                          .withValues(alpha: 0.5)),
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Stack(
              children: [
                Container(
                    height: 8, color: AppPalette.abyss3),
                FractionallySizedBox(
                  widthFactor: pct / 100,
                  child: Container(
                    height: 8,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                          colors: [rc.withValues(alpha: 0.55), rc]),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${pct.toStringAsFixed(0)}% capacity',
                style: TextStyle(
                    color: rc,
                    fontWeight: FontWeight.w700,
                    fontSize: 12),
              ),
              Text(
                'W ${data.warningLevel.toStringAsFixed(1)}  '
                'D ${data.dangerLevel.toStringAsFixed(1)} m',
                style: const TextStyle(
                    color: AppPalette.textGrey, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              if (data.flowRate != null)
                _StatChip(
                    Icons.waves_rounded,
                    '${data.flowRate!.toStringAsFixed(0)} m³/s',
                    'Flow'),
              if (data.effectiveRainfallMm > 0)
                _StatChip(
                    Icons.water_drop_outlined,
                    '${data.effectiveRainfallMm.toStringAsFixed(1)} mm',
                    data.imdRainfallMm != null ? 'IMD rain' : 'Rain 24h'),
              _StatChip(
                  Icons.schedule_rounded,
                  DateFormat('HH:mm')
                      .format(data.lastUpdated.toLocal()),
                  'Updated'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _badge({
    required String label,
    required Color bg,
    required Color fg,
    required Color border,
  }) =>
      Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: border),
        ),
        child: Text(label,
            style: TextStyle(
                color: fg,
                fontWeight: FontWeight.w800,
                fontSize: 10)),
      );
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String value, label;
  const _StatChip(this.icon, this.value, this.label);

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(right: 8),
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppPalette.abyss2,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppPalette.abyssStroke),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 11, color: AppPalette.textGrey),
            const SizedBox(width: 5),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value,
                    style: const TextStyle(
                        color: AppPalette.textWhite,
                        fontWeight: FontWeight.w700,
                        fontSize: 11)),
                Text(label,
                    style: const TextStyle(
                        color: AppPalette.textGrey, fontSize: 9)),
              ],
            ),
          ],
        ),
      );
}

// ── 24-hr Trend Card ──────────────────────────────────────────────────────────

class _TrendCard extends StatelessWidget {
  final List<RiverLevelSnapshot> trend;
  final double warningLevel, dangerLevel;
  final Color  riskColor;
  const _TrendCard({
    required this.trend,
    required this.warningLevel,
    required this.dangerLevel,
    required this.riskColor,
  });

  @override
  Widget build(BuildContext context) {
    final levels = trend.map((s) => s.level).toList();
    final minL   = levels.reduce((a, b) => a < b ? a : b);
    final maxL   = levels.reduce((a, b) => a > b ? a : b);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppPalette.abyss1,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppPalette.abyssStroke),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.show_chart_rounded,
                  color: AppPalette.gold, size: 15),
              const SizedBox(width: 6),
              const Text(
                '24-hr River Level Trend',
                style: TextStyle(
                    color: AppPalette.textWhite,
                    fontWeight: FontWeight.w700,
                    fontSize: 13),
              ),
              const Spacer(),
              Text(
                '${trend.length} pts  '
                '${minL.toStringAsFixed(2)}–${maxL.toStringAsFixed(2)} m',
                style: const TextStyle(
                    color: AppPalette.textGrey, fontSize: 9),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SparklineChart(
            snapshots:    trend,
            warningLevel: warningLevel,
            dangerLevel:  dangerLevel,
            color:        riskColor,
            height:       72,
            showLabels:   true,
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                DateFormat('HH:mm')
                    .format(trend.first.timestamp.toLocal()),
                style: const TextStyle(
                    color: AppPalette.textGrey, fontSize: 9),
              ),
              Text(
                DateFormat('HH:mm')
                    .format(trend.last.timestamp.toLocal()),
                style: const TextStyle(
                    color: AppPalette.textGrey, fontSize: 9),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── IMD Alert Tile ────────────────────────────────────────────────────────────

class _ImdAlertTile extends StatelessWidget {
  final dynamic alert;
  const _ImdAlertTile({required this.alert});

  @override
  Widget build(BuildContext context) {
    final c = _imdColor((alert.severity as String?) ?? '');
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Container(
            width: 10, height: 10,
            decoration: BoxDecoration(
                color: c,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                      color: c.withValues(alpha: 0.5),
                      blurRadius: 5)
                ]),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    (alert.title as String?) ??
                        (alert.severity as String? ?? 'IMD Alert'),
                    style: const TextStyle(
                        color: AppPalette.textWhite,
                        fontWeight: FontWeight.w700,
                        fontSize: 13)),
                if ((alert.description as String?)?.isNotEmpty == true)
                  Text(alert.description as String,
                      style: const TextStyle(
                          color: AppPalette.textDim, fontSize: 11),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _badge(
              label: (alert.severity as String? ?? '').toUpperCase(),
              color: c),
        ],
      ),
    );
  }

  Widget _badge({required String label, required Color color}) =>
      Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.5)),
        ),
        child: Text(label,
            style: TextStyle(
                color: color,
                fontWeight: FontWeight.w800,
                fontSize: 10)),
      );
}

// ── NDMA Advisory Tile ────────────────────────────────────────────────────────

class _NdmaAdvisoryTile extends StatelessWidget {
  final dynamic adv;
  const _NdmaAdvisoryTile({required this.adv});

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: AppPalette.warning.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: AppPalette.warning.withValues(alpha: 0.3)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.warning_amber_rounded,
                color: AppPalette.warning, size: 16),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text((adv.title as String?) ?? 'NDMA Advisory',
                      style: const TextStyle(
                          color: AppPalette.textWhite,
                          fontWeight: FontWeight.w700,
                          fontSize: 13)),
                  if ((adv.advisory as String?)?.isNotEmpty == true)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text(adv.advisory as String,
                          style: const TextStyle(
                              color: AppPalette.textDim,
                              fontSize: 11),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis),
                    ),
                ],
              ),
            ),
          ],
        ),
      );
}

// ── Collapsible Emergency Contacts ────────────────────────────────────────────

class _CollapsibleContacts extends StatelessWidget {
  final List<EmergencyContact> contacts;
  final String       state;
  final bool         expanded;
  final VoidCallback onToggle;
  const _CollapsibleContacts({
    required this.contacts,
    required this.state,
    required this.expanded,
    required this.onToggle,
  });

  Future<void> _call(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  @override
  Widget build(BuildContext context) {
    const always = [
      ('NDMA Helpline', '1078'),
      ('NDRF',          '011-24363260'),
      ('Police',        '100'),
      ('Ambulance',     '108'),
    ];

    return Container(
      decoration: BoxDecoration(
        color: AppPalette.abyss1,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppPalette.abyssStroke),
      ),
      child: Column(
        children: [
          // header row — tap to toggle
          InkWell(
            onTap: onToggle,
            borderRadius: expanded
                ? const BorderRadius.vertical(top: Radius.circular(14))
                : BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 11),
              child: Row(
                children: [
                  const Icon(Icons.phone_rounded,
                      color: AppPalette.safe, size: 14),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      '📞  Emergency Contacts',
                      style: TextStyle(
                          color: AppPalette.textWhite,
                          fontWeight: FontWeight.w700,
                          fontSize: 13),
                    ),
                  ),
                  AnimatedRotation(
                    turns: expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 250),
                    child: const Icon(Icons.keyboard_arrow_down_rounded,
                        color: AppPalette.textGrey, size: 18),
                  ),
                ],
              ),
            ),
          ),
          // always-visible rows
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 280),
            crossFadeState: expanded
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            firstChild: Column(
              children: [
                for (final e in always)
                  _row(e.$1, e.$2),
                if (contacts.isNotEmpty) ...[
                  Divider(
                      height: 1, color: AppPalette.abyssStroke),
                  ...contacts
                      .take(4)
                      .map((c) => _row(
                          c.role.isNotEmpty ? c.role : c.name,
                          c.phone)),
                ],
              ],
            ),
            secondChild: const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String phone) => InkWell(
        onTap: () => _call(phone),
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: 14, vertical: 10),
          child: Row(
            children: [
              const Icon(Icons.phone_rounded,
                  color: AppPalette.safe, size: 14),
              const SizedBox(width: 10),
              Expanded(
                child: Text(label,
                    style: const TextStyle(
                        color: AppPalette.textWhite, fontSize: 13)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppPalette.safe.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: AppPalette.safe.withValues(alpha: 0.4)),
                ),
                child: Text(phone,
                    style: const TextStyle(
                        color: AppPalette.safe,
                        fontWeight: FontWeight.w700,
                        fontSize: 12)),
              ),
            ],
          ),
        ),
      );
}

// ── Predict CTA ───────────────────────────────────────────────────────────────

class _PredictCta extends StatelessWidget {
  final String cityName;
  final double currentLevel;
  const _PredictCta(
      {required this.cityName, required this.currentLevel});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          Navigator.pushNamed(
            context,
            '/predict',
            arguments: {
              'city':        cityName,
              'river_level': currentLevel,
            },
          );
        },
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF005C6E), AppPalette.cyan],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                  color: AppPalette.cyan.withValues(alpha: 0.22),
                  blurRadius: 18,
                  spreadRadius: 1),
            ],
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.psychology_rounded,
                  color: Colors.white, size: 18),
              SizedBox(width: 8),
              Text(
                'Run Flood Prediction',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    letterSpacing: 0.3),
              ),
            ],
          ),
        ),
      );
}

// ── Map Chip CTA ──────────────────────────────────────────────────────────────

class _MapChip extends StatelessWidget {
  final String cityName;
  const _MapChip({required this.cityName});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          Navigator.pushNamed(context, '/bihar_river_map');
        },
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 14, vertical: 16),
          decoration: BoxDecoration(
            color: AppPalette.gold.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: AppPalette.gold.withValues(alpha: 0.35)),
          ),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.map_rounded,
                  color: AppPalette.gold, size: 20),
              SizedBox(height: 4),
              Text(
                'Map',
                style: TextStyle(
                    color: AppPalette.gold,
                    fontWeight: FontWeight.w700,
                    fontSize: 11),
              ),
            ],
          ),
        ),
      );
}

// ── Section Label ─────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          text,
          style: const TextStyle(
              color: AppPalette.textWhite,
              fontWeight: FontWeight.w700,
              fontSize: 13),
        ),
      );
}
