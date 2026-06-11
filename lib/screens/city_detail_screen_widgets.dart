// lib/screens/city_detail_screen_widgets.dart
// Helper widgets for CityDetailScreen — split out to fix truncation.
// Part of: city_detail_screen.dart (imported via part directive)
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/flood_data.dart';
import '../models/river_monitoring.dart';
import '../theme/river_theme.dart';
import '../widgets/sparkline_chart.dart';

// ─────────────────────────────────────────────────────────────────────────────
// _ThresholdBanner
// ─────────────────────────────────────────────────────────────────────────────

class _ThresholdBanner extends StatelessWidget {
  final FloodData data;
  const _ThresholdBanner({required this.data});

  @override
  Widget build(BuildContext context) {
    final t        = RiverColors.of(context);
    final risk     = data.riskLevel.toUpperCase();
    final Color bg;
    final String msg;
    final IconData icon;

    switch (risk) {
      case 'CRITICAL':
        bg   = AppPalette.critical.withValues(alpha: 0.18);
        msg  = '🚨 CRITICAL — Level above HFL. Immediate action required.';
        icon = Icons.warning_amber_rounded;
        break;
      case 'SEVERE':
        bg   = AppPalette.danger.withValues(alpha: 0.14);
        msg  = '🔴 SEVERE — Above danger level. Stay alert.';
        icon = Icons.error_outline_rounded;
        break;
      case 'MODERATE':
        bg   = AppPalette.warning.withValues(alpha: 0.12);
        msg  = '⚠️ MODERATE — Above warning level. Monitor closely.';
        icon = Icons.info_outline_rounded;
        break;
      default:
        return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 6, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: _riskColor(data.riskLevel).withValues(alpha: 0.35)),
      ),
      child: Row(children: [
        Icon(icon, size: 16, color: _riskColor(data.riskLevel)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(msg,
              style: TextStyle(
                  color: t.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _SkeletonView
// ─────────────────────────────────────────────────────────────────────────────

class _SkeletonView extends StatelessWidget {
  final String cityName;
  const _SkeletonView({required this.cityName});

  @override
  Widget build(BuildContext context) {
    final t = RiverColors.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 28, height: 28,
            child: CircularProgressIndicator(
                strokeWidth: 2.5, color: t.accent)),
          const SizedBox(height: 16),
          Text('Loading data for $cityName…',
              style: TextStyle(color: t.textSecondary, fontSize: 13)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _GaugeHeroCard
// ─────────────────────────────────────────────────────────────────────────────

class _GaugeHeroCard extends StatelessWidget {
  final FloodData data;
  const _GaugeHeroCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final t    = RiverColors.of(context);
    final pct  = (data.currentLevel / data.dangerLevel).clamp(0.0, 1.2);
    final risk = data.riskLevel.toUpperCase();
    final riskC = _riskColor(data.riskLevel);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: t.cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: riskC.withValues(alpha: 0.30)),
        boxShadow: [
          BoxShadow(
            color: riskC.withValues(alpha: 0.08),
            blurRadius: 18, offset: const Offset(0, 5))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Current Level',
                      style: TextStyle(
                          color: t.textSecondary, fontSize: 11,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(
                    '${data.currentLevel.toStringAsFixed(2)} m',
                    style: TextStyle(
                      color: riskC,
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: riskC.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: riskC.withValues(alpha: 0.4)),
              ),
              child: Text(risk,
                  style: TextStyle(
                      color: riskC,
                      fontWeight: FontWeight.w800,
                      fontSize: 13)),
            ),
          ]),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: pct.clamp(0.0, 1.0),
              backgroundColor: t.stroke,
              valueColor: AlwaysStoppedAnimation<Color>(riskC),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _levelPill(t, 'Warning', data.warningLevel, AppPalette.warning),
              _levelPill(t, 'Danger',  data.dangerLevel,  AppPalette.danger),
            ],
          ),
        ],
      ),
    );
  }

  Widget _levelPill(
      RiverColors t, String label, double level, Color color) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 8, height: 8,
            decoration: BoxDecoration(
                color: color, shape: BoxShape.circle)),
        const SizedBox(width: 5),
        Text('$label: ${level.toStringAsFixed(2)} m',
            style: TextStyle(
                color: t.textSecondary, fontSize: 10,
                fontWeight: FontWeight.w600)),
      ]);
}

// ─────────────────────────────────────────────────────────────────────────────
// _TrendCard
// ─────────────────────────────────────────────────────────────────────────────

class _TrendCard extends StatelessWidget {
  final List<double> trend;
  final double warningLevel;
  final double dangerLevel;
  final Color  riskColor;
  const _TrendCard({
    required this.trend,
    required this.warningLevel,
    required this.dangerLevel,
    required this.riskColor,
  });

  @override
  Widget build(BuildContext context) {
    final t = RiverColors.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: t.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: t.stroke),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.show_chart_rounded, size: 14, color: t.textSecondary),
            const SizedBox(width: 6),
            Text('24-Hour Trend',
                style: TextStyle(
                    color: t.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 13)),
          ]),
          const SizedBox(height: 10),
          SizedBox(
            height: 80,
            child: SparklineChart(
              data:         trend,
              lineColor:    riskColor,
              warningLevel: warningLevel,
              dangerLevel:  dangerLevel,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _SectionLabel
// ─────────────────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel(this.label);

  @override
  Widget build(BuildContext context) {
    final t = RiverColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(label,
          style: TextStyle(
              color: t.textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 13)),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _ImdAlertTile
// ─────────────────────────────────────────────────────────────────────────────

class _ImdAlertTile extends StatelessWidget {
  final ImdAlert alert;
  const _ImdAlertTile({required this.alert});

  @override
  Widget build(BuildContext context) {
    final t = RiverColors.of(context);
    final color = _sevColor(alert.severity);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: t.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 4, height: 40,
          margin: const EdgeInsets.only(right: 10),
          decoration: BoxDecoration(
              color: color, borderRadius: BorderRadius.circular(2)),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(alert.headline,
                  style: TextStyle(
                      color: t.textPrimary, fontSize: 12,
                      fontWeight: FontWeight.w700)),
              if (alert.description.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(alert.description,
                    style: TextStyle(
                        color: t.textSecondary, fontSize: 11),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
              ],
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(alert.severity,
              style: TextStyle(
                  color: color, fontSize: 9,
                  fontWeight: FontWeight.w800)),
        ),
      ]),
    );
  }

  static Color _sevColor(String sev) {
    switch (sev.toUpperCase()) {
      case 'RED':    return AppPalette.danger;
      case 'ORANGE': return AppPalette.warning;
      case 'YELLOW': return const Color(0xFFFFD600);
      default:       return AppPalette.safe;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _NdmaAdvisoryTile
// ─────────────────────────────────────────────────────────────────────────────

class _NdmaAdvisoryTile extends StatelessWidget {
  final NdmaAdvisory adv;
  const _NdmaAdvisoryTile({required this.adv});

  @override
  Widget build(BuildContext context) {
    final t = RiverColors.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: t.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppPalette.critical.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(adv.title,
              style: TextStyle(
                  color: t.textPrimary, fontSize: 12,
                  fontWeight: FontWeight.w700)),
          if (adv.body.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(adv.body,
                style: TextStyle(color: t.textSecondary, fontSize: 11),
                maxLines: 3,
                overflow: TextOverflow.ellipsis),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _CollapsibleContacts
// ─────────────────────────────────────────────────────────────────────────────

class _CollapsibleContacts extends StatelessWidget {
  final List<EmergencyContact> contacts;
  final String state;
  final bool   expanded;
  final VoidCallback onToggle;
  const _CollapsibleContacts({
    required this.contacts,
    required this.state,
    required this.expanded,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final t = RiverColors.of(context);
    return Container(
      decoration: BoxDecoration(
        color: t.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: t.stroke),
      ),
      child: Column(children: [
        InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            HapticFeedback.selectionClick();
            onToggle();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 12),
            child: Row(children: [
              Icon(Icons.contact_phone_rounded,
                  size: 16, color: t.accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Emergency Contacts — $state',
                    style: TextStyle(
                        color: t.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 13)),
              ),
              Icon(
                  expanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  color: t.textSecondary),
            ]),
          ),
        ),
        if (expanded)
          ...contacts.map((c) => _ContactTile(c: c, t: t)),
        if (expanded && contacts.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
            child: Text('No contacts listed for $state.',
                style: TextStyle(
                    color: t.textSecondary, fontSize: 12)),
          ),
      ]),
    );
  }
}

class _ContactTile extends StatelessWidget {
  final EmergencyContact c;
  final RiverColors      t;
  const _ContactTile({required this.c, required this.t});

  @override
  Widget build(BuildContext context) =>
      ListTile(
        dense: true,
        leading: Icon(Icons.phone_rounded,
            size: 16, color: t.accent),
        title: Text(c.name,
            style: TextStyle(
                color: t.textPrimary, fontSize: 12,
                fontWeight: FontWeight.w600)),
        subtitle: Text(c.number,
            style: TextStyle(
                color: t.textSecondary, fontSize: 11)),
        trailing: IconButton(
          icon: Icon(Icons.call_rounded,
              size: 18, color: AppPalette.safe),
          onPressed: () async {
            final uri = Uri.parse('tel:${c.number}');
            if (await canLaunchUrl(uri)) {
              await launchUrl(uri);
            }
          },
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// _PredictCta
// ─────────────────────────────────────────────────────────────────────────────

class _PredictCta extends StatelessWidget {
  final String cityName;
  final double currentLevel;
  const _PredictCta({
    required this.cityName,
    required this.currentLevel,
  });

  @override
  Widget build(BuildContext context) {
    final t = RiverColors.of(context);
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        Navigator.of(context).pushNamed(
          '/predict',
          arguments: {
            'cityName':     cityName,
            'currentLevel': currentLevel,
          },
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [t.accent, t.accent.withValues(alpha: 0.7)],
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Center(
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.auto_graph_rounded,
                size: 16, color: Colors.black),
            const SizedBox(width: 6),
            const Text('Predict 24h',
                style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.w800,
                    fontSize: 13)),
          ]),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _MapChip
// ─────────────────────────────────────────────────────────────────────────────

class _MapChip extends StatelessWidget {
  final String cityName;
  const _MapChip({required this.cityName});

  @override
  Widget build(BuildContext context) {
    final t = RiverColors.of(context);
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.of(context).pushNamed(
          '/bihar_map',
          arguments: {'focusCity': cityName},
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: t.cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: t.stroke),
        ),
        child: Icon(Icons.map_rounded,
            size: 18, color: t.textSecondary),
      ),
    );
  }
}
