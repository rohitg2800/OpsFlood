// lib/screens/city_detail_screen.dart
// CityDetailScreen v3
//  - Route const for named navigation
//  - Replaced inline _SparklinePainter with shared SparklineChart widget
//  - Theme tokens from AppPalette instead of local constants
//  - showLabels: true on SparklineChart so W / D markers are visible
//  - Accepts both push (cityName param) and named route (/city_detail)
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/flood_data.dart';
import '../models/river_monitoring.dart';
import '../providers/flood_providers.dart';
import '../services/ndma_service.dart';
import '../theme/river_theme.dart';
import '../widgets/sparkline_chart.dart';

/// Named-route constant — register in MaterialApp as:
///   '/city_detail': (ctx) {
///     final city = ModalRoute.of(ctx)!.settings.arguments as String;
///     return CityDetailScreen(cityName: city);
///   }
class CityDetailScreen extends ConsumerWidget {
  static const String route = '/city_detail';

  final String cityName;
  const CityDetailScreen({super.key, required this.cityName});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data       = ref.watch(cityDataProvider(cityName));
    final trend      = ref.watch(cityTrendProvider(cityName));
    final imdAlerts  = ref.watch(stateImdAlertsProvider(data?.state ?? ''));
    final advisories = ref.watch(stateNdmaAdvisoriesProvider(data?.state ?? ''));
    final contacts   = ref
        .watch(stateEmergencyContactsProvider(data?.state ?? ''))
        .cast<EmergencyContact>();

    return Scaffold(
      backgroundColor: AppPalette.abyss0,
      body: Container(
        decoration: AppPalette.scaffoldDecoration(),
        child: SafeArea(
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // ── App Bar ─────────────────────────────────────────────────────
              SliverAppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                pinned: true,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_rounded,
                      color: AppPalette.textWhite, size: 18),
                  onPressed: () => Navigator.pop(context),
                ),
                title: Text(
                  cityName,
                  style: const TextStyle(
                    color: AppPalette.textWhite,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded,
                        color: AppPalette.textGrey, size: 20),
                    onPressed: () =>
                        ref.read(realTimeProvider).refreshData(),
                  ),
                ],
              ),

              // ── Body ──────────────────────────────────────────────────────────
              if (data == null)
                SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.location_off_rounded,
                            color: AppPalette.textGrey, size: 44),
                        const SizedBox(height: 12),
                        Text(
                          'No live data for $cityName',
                          style: const TextStyle(
                              color: AppPalette.textGrey, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(18, 8, 18, 60),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([

                      // ── Gauge hero ──────────────────────────────────────
                      _GaugeHeroCard(data: data),
                      const SizedBox(height: 14),

                      // ── 24-hr SparklineChart ────────────────────────────
                      if (trend.length >= 2) ...[
                        _TrendCard(
                          trend: trend,
                          warningLevel: data.warningLevel,
                          dangerLevel: data.dangerLevel,
                          riskColor: _riskColor(data.riskLevel),
                        ),
                        const SizedBox(height: 14),
                      ],

                      // ── IMD alerts ─────────────────────────────────────
                      if (imdAlerts.isNotEmpty) ...[
                        _SectionLabel('🌧  IMD Weather Alerts'),
                        ...imdAlerts.take(3)
                            .map((a) => _ImdAlertTile(alert: a)),
                        const SizedBox(height: 14),
                      ],

                      // ── NDMA advisories ────────────────────────────────
                      if (advisories.isNotEmpty) ...[
                        _SectionLabel('🚨  NDMA Advisories'),
                        ...advisories.take(2)
                            .map((a) => _NdmaAdvisoryTile(adv: a)),
                        const SizedBox(height: 14),
                      ],

                      // ── Emergency contacts ────────────────────────────
                      _SectionLabel('📞  Emergency Contacts'),
                      _EmergencyContactsCard(
                          contacts: contacts, state: data.state),
                      const SizedBox(height: 20),

                      // ── Predict CTA ───────────────────────────────────
                      _PredictCta(
                          cityName: cityName,
                          currentLevel: data.currentLevel),
                    ]),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

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

// ── Gauge Hero Card ───────────────────────────────────────────────────────────

class _GaugeHeroCard extends StatelessWidget {
  final FloodData data;
  const _GaugeHeroCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final rc  = _riskColor(data.riskLevel);
    final pct = data.capacityPercent.clamp(0.0, 100.0);
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
          // State / river row
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
          // Level hero + source badge
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
                    border: (isLive ? AppPalette.cyan : AppPalette.textGrey)
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
          // Capacity bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Stack(
              children: [
                Container(
                    height: 8,
                    color: AppPalette.abyss3),
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
          // Stat chips row
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
                  DateFormat('HH:mm').format(data.lastUpdated.toLocal()),
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

// ── 24-hr Trend Card (uses shared SparklineChart) ─────────────────────────────

class _TrendCard extends StatelessWidget {
  final List<RiverLevelSnapshot> trend;
  final double warningLevel;
  final double dangerLevel;
  final Color riskColor;

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
                '${trend.length} readings  '
                '${minL.toStringAsFixed(2)}–${maxL.toStringAsFixed(2)} m',
                style: const TextStyle(
                    color: AppPalette.textGrey, fontSize: 9),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // ✔ Using shared SparklineChart widget with W/D labels
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
                      color: c.withValues(alpha: 0.5), blurRadius: 5)
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

// ── Emergency Contacts Card ───────────────────────────────────────────────────

class _EmergencyContactsCard extends StatelessWidget {
  final List<EmergencyContact> contacts;
  final String state;
  const _EmergencyContactsCard(
      {required this.contacts, required this.state});

  Future<void> _call(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: AppPalette.abyss1,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppPalette.abyssStroke),
        ),
        child: Column(
          children: [
            _row('NDMA Helpline', '1078'),
            _row('NDRF',          '011-24363260'),
            _row('Police',        '100'),
            _row('Ambulance',     '108'),
            if (contacts.isNotEmpty) ...[
              Divider(
                  height: 1,
                  color: AppPalette.abyssStroke),
              ...contacts.take(4).map(
                  (c) => _row(
                      c.role.isNotEmpty ? c.role : c.name,
                      c.phone)),
            ],
          ],
        ),
      );

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
                        color: AppPalette.textWhite,
                        fontSize: 13)),
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
        onTap: () => Navigator.pushNamed(
          context,
          '/predict',
          arguments: {
            'city':        cityName,
            'river_level': currentLevel,
          },
        ),
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
                    fontSize: 15,
                    letterSpacing: 0.3),
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
