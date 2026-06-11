// lib/screens/city_detail_screen.dart
// EQUINOX-BH — CityDetailScreen v10
// Uses PUBLIC widget classes from city_detail_screen_widgets.dart
// (Dart private _ classes can't cross file boundaries)
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/flood_data.dart';
import '../models/river_monitoring.dart';
import '../providers/bihar_city_provider.dart';
import '../providers/bihar_live_provider.dart';
import '../providers/flood_providers.dart';
import '../services/alert_engine.dart';
import '../theme/river_theme.dart';
import '../widgets/alert_share_button.dart';
import '../widgets/sparkline_chart.dart';
import 'city_detail_screen_widgets.dart';

FloodAlert _syntheticAlert(FloodData data, String stationName) {
  AlertSeverity severity;
  AlertType     type;
  switch (data.riskLevel.toUpperCase()) {
    case 'CRITICAL':
      severity = AlertSeverity.emergency;
      type     = AlertType.levelAboveDanger;
      break;
    case 'SEVERE':
      severity = AlertSeverity.critical;
      type     = AlertType.levelAboveDanger;
      break;
    case 'MODERATE':
      severity = AlertSeverity.warning;
      type     = AlertType.levelAboveWarning;
      break;
    default:
      severity = AlertSeverity.info;
      type     = AlertType.levelAboveWarning;
  }
  return FloodAlert(
    id:             '${stationName.toLowerCase().replaceAll(' ', '_')}.city_detail',
    type:           type,
    severity:       severity,
    title:          '$stationName — ${data.riskLevel} Risk',
    body:           'Current level: ${data.currentLevel.toStringAsFixed(2)} m '
                    '/ Danger: ${data.dangerLevel.toStringAsFixed(2)} m',
    stationName:    stationName,
    river:          data.riverName ?? 'River',
    district:       data.district.isNotEmpty ? data.district : data.state,
    state:          data.state,
    currentLevel:   data.currentLevel,
    thresholdLevel: data.dangerLevel,
    action:         'Monitor live levels and follow local authority guidance.',
    issuedAt:       data.lastUpdated,
  );
}

Color _riskColor(String risk) => cityDetailRiskColor(risk);

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
  late final List<Animation<double>> _sectionFades;
  late final List<Animation<Offset>> _sectionSlides;

  bool _contactsExpanded = false;
  bool _refreshing       = false;

  static const int _sectionCount = 7;

  @override
  void initState() {
    super.initState();
    _entryCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900));
    _sectionFades  = [];
    _sectionSlides = [];
    for (int i = 0; i < _sectionCount; i++) {
      final start = i * 0.10;
      final end   = (start + 0.28).clamp(0.0, 1.0);
      _sectionFades.add(Tween<double>(begin: 0, end: 1).animate(
          CurvedAnimation(parent: _entryCtrl,
              curve: Interval(start, end, curve: Curves.easeOut))));
      _sectionSlides.add(
          Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
              .animate(CurvedAnimation(parent: _entryCtrl,
                  curve: Interval(start, end, curve: Curves.easeOutCubic))));
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
      await Future.wait([
        ref.read(realTimeProvider).refreshData(),
        ref.read(biharLiveProvider.notifier).refresh(),
      ]);
      _entryCtrl..reset()..forward();
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  Widget _section(int idx, Widget child) => FadeTransition(
        opacity: _sectionFades[idx],
        child: SlideTransition(position: _sectionSlides[idx], child: child),
      );

  @override
  Widget build(BuildContext context) {
    final t          = RiverColors.of(context);
    final data       = ref.watch(cityDataProvider(widget.cityName));
    final trend      = ref.watch(cityTrendProvider(widget.cityName));
    final imdAlerts  = ref.watch(stateImdAlertsProvider(data?.state ?? ''));
    final advisories = ref.watch(stateNdmaAdvisoriesProvider(data?.state ?? ''));
    final contacts   = ref
        .watch(stateEmergencyContactsProvider(data?.state ?? ''))
        .cast<EmergencyContact>();
    final biharStation = ref.watch(biharCityProvider(widget.cityName));
    final biharLoading = ref.watch(biharCityLoadingProvider);

    return Scaffold(
      backgroundColor: t.scaffoldBg,
      body: Container(
        color: t.scaffoldBg,
        child: SafeArea(
          child: RefreshIndicator(
            color: t.accent,
            backgroundColor: t.cardBg,
            onRefresh: _refresh,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics()),
              slivers: [
                // ── App Bar ────────────────────────────────────────────────────────
                SliverAppBar(
                  backgroundColor: Colors.transparent,
                  surfaceTintColor: Colors.transparent,
                  elevation: 0,
                  pinned: true,
                  leading: IconButton(
                    icon: Icon(Icons.arrow_back_ios_rounded,
                        color: t.textPrimary, size: 18),
                    onPressed: () => Navigator.pop(context),
                  ),
                  title: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.cityName,
                          style: TextStyle(color: t.textPrimary,
                              fontWeight: FontWeight.w800, fontSize: 17)),
                      if (data != null)
                        Text('${data.riverName ?? "River"}  ·  ${data.state}',
                            style: TextStyle(
                                color: t.textSecondary, fontSize: 10)),
                    ],
                  ),
                  actions: [
                    if (data != null)
                      AlertShareButton(
                        alert:     _syntheticAlert(data, widget.cityName),
                        district:  data.district.isNotEmpty
                                       ? data.district : data.state,
                        riverName: data.riverName ?? 'River',
                      ),
                    if (_refreshing)
                      Padding(
                        padding: const EdgeInsets.only(right: 14),
                        child: SizedBox(
                          width: 18, height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: t.accent),
                        ),
                      )
                    else
                      IconButton(
                        icon: Icon(Icons.refresh_rounded,
                            color: t.textSecondary, size: 20),
                        onPressed: _refresh,
                      ),
                  ],
                ),

                // ── Threshold banner ───────────────────────────────────────────────
                if (data != null)
                  SliverToBoxAdapter(
                    child: ThresholdBanner(data: data),
                  ),

                // ── No-data skeleton ───────────────────────────────────────────────
                if (data == null)
                  SliverFillRemaining(
                    child: CitySkeletonView(cityName: widget.cityName),
                  )

                // ── Loaded body ───────────────────────────────────────────────────
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 100),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([

                        // 0 ─ Hero gauge
                        _section(0, GaugeHeroCard(data: data)),
                        const SizedBox(height: 12),

                        // 1 ─ Bihar live panel
                        _section(1, _BiharDataCard(
                          station:      biharStation,
                          isLoading:    biharLoading,
                          fallbackCity: widget.cityName,
                        )),
                        const SizedBox(height: 12),

                        // 2 ─ 24-hr trend sparkline
                        if (trend.length >= 2) ...[
                          _section(2, TrendCard(
                            trend:        trend,
                            warningLevel: data.warningLevel,
                            dangerLevel:  data.dangerLevel,
                            riskColor:    _riskColor(data.riskLevel),
                          )),
                          const SizedBox(height: 12),
                        ],

                        // 3 ─ IMD alerts
                        if (imdAlerts.isNotEmpty) ...[
                          _section(3, Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SectionLabel('🌧  IMD Weather Alerts'),
                              ...imdAlerts.take(3).map((a) => ImdAlertTile(alert: a)),
                            ],
                          )),
                          const SizedBox(height: 12),
                        ],

                        // 4 ─ NDMA advisories
                        if (advisories.isNotEmpty) ...[
                          _section(4, Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SectionLabel('🚨  NDMA Advisories'),
                              ...advisories.take(2).map((a) => NdmaAdvisoryTile(adv: a)),
                            ],
                          )),
                          const SizedBox(height: 12),
                        ],

                        // 5 ─ Emergency contacts
                        // stationName = widget.cityName so SosScreen can
                        // pre-filter contacts to the matching district.
                        _section(5, CollapsibleContacts(
                          contacts:    contacts,
                          state:       data.state,
                          stationName: widget.cityName,
                          expanded:    _contactsExpanded,
                          onToggle:    () => setState(
                              () => _contactsExpanded = !_contactsExpanded),
                        )),
                        const SizedBox(height: 12),

                        // 6 ─ Predict + Map + Share CTAs
                        _section(6, Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: PredictCta(
                                cityName:     widget.cityName,
                                currentLevel: data.currentLevel,
                              ),
                            ),
                            const SizedBox(width: 10),
                            MapChip(cityName: widget.cityName),
                            const SizedBox(width: 10),
                            AlertShareButton(
                              alert:     _syntheticAlert(data, widget.cityName),
                              district:  data.district.isNotEmpty
                                             ? data.district : data.state,
                              riverName: data.riverName ?? 'River',
                            ),
                          ],
                        )),
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

// ─────────────────────────────────────────────────────────────────────────────
// _BiharDataCard  (file-private)
// ─────────────────────────────────────────────────────────────────────────────
class _BiharDataCard extends StatelessWidget {
  final BiharStationData? station;
  final bool   isLoading;
  final String fallbackCity;
  const _BiharDataCard({
    required this.station,
    required this.isLoading,
    required this.fallbackCity,
  });

  @override
  Widget build(BuildContext context) {
    final t = RiverColors.of(context);

    if (isLoading) {
      return Container(
        height: 90,
        decoration: BoxDecoration(
          color: t.cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: t.stroke),
        ),
        child: Center(
          child: SizedBox(
            width: 20, height: 20,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: AppPalette.cyan),
          ),
        ),
      );
    }

    if (station == null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: t.cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: t.stroke),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline_rounded, color: t.textSecondary, size: 15),
            const SizedBox(width: 8),
            Expanded(
              child: Text('No Bihar WRD data available for $fallbackCity',
                  style: TextStyle(color: t.textSecondary, fontSize: 12)),
            ),
          ],
        ),
      );
    }

    final s = station!;

    Color  dischargeColor = AppPalette.safe;
    String dischargeDelta = '';
    if (s.discharge != null && s.dischargeMean != null) {
      final pct = ((s.discharge! - s.dischargeMean!) / s.dischargeMean! * 100);
      if (pct > 20) dischargeColor = pct > 50 ? AppPalette.danger : AppPalette.warning;
      dischargeDelta = pct >= 0
          ? '+${pct.toStringAsFixed(0)}% vs mean'
          : '${pct.toStringAsFixed(0)}% vs mean';
    }

    Color diffColor = AppPalette.safe;
    if (s.diff24h != null) {
      if (s.diff24h! > 0.5)      diffColor = AppPalette.danger;
      else if (s.diff24h! > 0.2) diffColor = AppPalette.warning;
      else if (s.diff24h! < 0)   diffColor = AppPalette.safe;
    }

    IconData trendIcon;
    Color    trendColor;
    switch (s.trend.toUpperCase()) {
      case 'RISING':
        trendIcon = Icons.trending_up_rounded;
        trendColor = AppPalette.danger;
        break;
      case 'FALLING':
        trendIcon = Icons.trending_down_rounded;
        trendColor = AppPalette.safe;
        break;
      default:
        trendIcon = Icons.trending_flat_rounded;
        trendColor = AppPalette.warning;
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: t.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppPalette.cyan.withValues(alpha: 0.25)),
        boxShadow: [
          BoxShadow(color: AppPalette.cyan.withValues(alpha: 0.06),
              blurRadius: 14, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.water_drop_rounded, color: AppPalette.cyan, size: 14),
              const SizedBox(width: 6),
              Expanded(
                child: Text('Bihar WRD + GloFAS + Rainfall',
                    style: TextStyle(color: t.textPrimary,
                        fontWeight: FontWeight.w700, fontSize: 13)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: AppPalette.cyan.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppPalette.cyan.withValues(alpha: 0.25)),
                ),
                child: Text(s.source,
                    style: const TextStyle(
                        color: AppPalette.cyan, fontSize: 9,
                        fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _DataCell(
                  label: 'GloFAS Discharge',
                  value: s.discharge != null ? '${_fmt(s.discharge!)} m³/s' : '—',
                  sub:   s.dischargeMean != null ? 'Mean: ${_fmt(s.dischargeMean!)} m³/s' : null,
                  icon:       Icons.water_rounded,
                  valueColor: dischargeColor,
                  t: t,
                ),
              ),
              if (dischargeDelta.isNotEmpty) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: dischargeColor.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: dischargeColor.withValues(alpha: 0.30)),
                  ),
                  child: Text(dischargeDelta,
                      style: TextStyle(color: dischargeColor, fontSize: 11,
                          fontWeight: FontWeight.w700)),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          Divider(height: 1, color: t.stroke),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _DataCell(
                  label: '24h Level Change',
                  value: s.diff24h != null
                      ? '${s.diff24h! >= 0 ? '+' : ''}${s.diff24h!.toStringAsFixed(2)} m'
                      : '—',
                  icon: Icons.height_rounded,
                  valueColor: diffColor,
                  t: t,
                ),
              ),
              Container(width: 1, height: 36, color: t.stroke),
              Expanded(
                child: _DataCell(
                  label: '24h Forecast',
                  value: s.forecast24h != null
                      ? '${s.forecast24h!.toStringAsFixed(2)} m' : '—',
                  icon: Icons.update_rounded,
                  valueColor: t.textPrimary,
                  t: t,
                  centered: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Divider(height: 1, color: t.stroke),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(trendIcon, color: trendColor, size: 16),
              const SizedBox(width: 6),
              Text(s.trend.isEmpty ? 'Stable' : s.trend,
                  style: TextStyle(color: trendColor,
                      fontWeight: FontWeight.w800, fontSize: 12)),
              const Spacer(),
              if (s.rainfall24h != null)
                Row(
                  children: [
                    const Icon(Icons.grain_rounded,
                        color: Colors.lightBlue, size: 12),
                    const SizedBox(width: 4),
                    Text('${s.rainfall24h!.toStringAsFixed(1)} mm rain',
                        style: const TextStyle(color: Colors.lightBlue,
                            fontSize: 11, fontWeight: FontWeight.w700)),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }

  static String _fmt(double v) =>
      v >= 1000 ? '${(v / 1000).toStringAsFixed(1)}k' : v.toStringAsFixed(0);
}

class _DataCell extends StatelessWidget {
  final String      label;
  final String      value;
  final String?     sub;
  final IconData    icon;
  final Color       valueColor;
  final RiverColors t;
  final bool        centered;
  const _DataCell({
    required this.label,
    required this.value,
    this.sub,
    required this.icon,
    required this.valueColor,
    required this.t,
    this.centered = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: centered ? 10 : 0),
      child: Column(
        crossAxisAlignment:
            centered ? CrossAxisAlignment.center : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment:
                centered ? MainAxisAlignment.center : MainAxisAlignment.start,
            children: [
              Icon(icon, size: 10, color: t.textSecondary),
              const SizedBox(width: 4),
              Text(label, style: TextStyle(color: t.textSecondary,
                  fontSize: 10, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 3),
          Text(value, style: TextStyle(color: valueColor,
              fontWeight: FontWeight.w800, fontSize: 13)),
          if (sub != null)
            Text(sub!, style: TextStyle(color: t.textSecondary, fontSize: 9)),
        ],
      ),
    );
  }
}
