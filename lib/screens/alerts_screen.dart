// lib/screens/alerts_screen.dart
// OpsFlood — AlertsScreen v2  "Uses real providers"
// Uses imdAlertsProvider + ndmaAdvisoriesProvider from flood_providers.dart.
// AlertCard is inlined here — no separate widget file needed.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../l10n/context_l10n.dart';
import '../providers/flood_providers.dart';
import '../theme/river_theme.dart';

class AlertsScreen extends ConsumerWidget {
  static const route = '/alerts';
  const AlertsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s           = context.l10n;
    final imdAlerts   = ref.watch(imdAlertsProvider);
    final ndmaAlerts  = ref.watch(ndmaAdvisoriesProvider);

    // Merge both sources into a unified display list.
    final allAlerts   = [...imdAlerts, ...ndmaAlerts];

    return Scaffold(
      backgroundColor: AppPalette.abyss0,
      appBar: AppBar(
        backgroundColor: AppPalette.abyss0,
        title: Text(
          s.floodAlerts,
          style: const TextStyle(
            color: AppPalette.textWhite,
            fontSize: 18, fontWeight: FontWeight.w800,
          ),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: AppPalette.textWhite),
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            color: AppPalette.cyan.withValues(alpha: 0.10),
          ),
        ),
      ),
      body: allAlerts.isEmpty
          ? _EmptyAlerts(label: s.noAlerts)
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              itemCount: allAlerts.length,
              itemBuilder: (_, i) => _AlertCard(raw: allAlerts[i]),
            ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// INLINE ALERT CARD
// Works with any Map-like dynamic object from imdAlertsProvider /
// ndmaAdvisoriesProvider.  Safely casts via dynamic field access.
// ─────────────────────────────────────────────────────────────────────────────
class _AlertCard extends StatelessWidget {
  final dynamic raw;
  const _AlertCard({required this.raw});

  String _field(String key, [String fallback = '—']) {
    try {
      final val = (raw as dynamic)[key];
      return val?.toString().isNotEmpty == true ? val.toString() : fallback;
    } catch (_) { return fallback; }
  }

  Color get _severityColor {
    final sev = _field('severity', _field('alert_level', 'low')).toLowerCase();
    if (sev.contains('extreme') || sev.contains('critical') ||
        sev.contains('red'))   return AppPalette.critical;
    if (sev.contains('severe') || sev.contains('orange') ||
        sev.contains('high'))  return AppPalette.danger;
    if (sev.contains('moderate') || sev.contains('yellow') ||
        sev.contains('medium')) return AppPalette.amber;
    return AppPalette.safe;
  }

  @override
  Widget build(BuildContext context) {
    final col     = _severityColor;
    final title   = _field('title',    _field('headline',   'Alert'));
    final desc    = _field('description', _field('message', ''));
    final source  = _field('source',   _field('agency',     ''));
    final area    = _field('area',     _field('district',   ''));
    final rawDate = _field('issued_at', _field('date', ''));

    String dateStr = '';
    if (rawDate.isNotEmpty) {
      try {
        final dt = DateTime.tryParse(rawDate);
        if (dt != null) {
          dateStr = DateFormat('dd MMM · HH:mm').format(dt.toLocal());
        } else {
          dateStr = rawDate;
        }
      } catch (_) { dateStr = rawDate; }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppPalette.abyss2,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: col.withValues(alpha: 0.25)),
        boxShadow: [
          BoxShadow(
            color: col.withValues(alpha: 0.08),
            blurRadius: 12, offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: col.withValues(alpha: 0.12),
                  border: Border.all(color: col.withValues(alpha: 0.30)),
                ),
                child: Icon(_iconFor(col), color: col, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                          color: AppPalette.textWhite,
                          fontSize: 13, fontWeight: FontWeight.w800,
                          height: 1.25,
                        )),
                    if (area.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(area,
                          style: const TextStyle(
                            color: AppPalette.textGrey, fontSize: 11)),
                    ],
                  ],
                ),
              ),
              if (dateStr.isNotEmpty)
                Text(dateStr,
                    style: const TextStyle(
                      color: AppPalette.textDim, fontSize: 9)),
            ],
          ),
          if (desc.isNotEmpty && desc != '—') ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppPalette.abyss4,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppPalette.abyssStroke),
              ),
              child: Text(desc,
                  style: const TextStyle(
                    color: AppPalette.textGrey,
                    fontSize: 11, height: 1.5)),
            ),
          ],
          if (source.isNotEmpty && source != '—') ...[
            const SizedBox(height: 8),
            Row(children: [
              const Icon(Icons.source_rounded,
                  color: AppPalette.textDim, size: 11),
              const SizedBox(width: 4),
              Text(source,
                  style: const TextStyle(
                    color: AppPalette.textDim,
                    fontSize: 9.5, fontWeight: FontWeight.w600)),
            ]),
          ],
        ],
      ),
    );
  }

  IconData _iconFor(Color c) {
    if (c == AppPalette.critical) return Icons.crisis_alert_rounded;
    if (c == AppPalette.danger)   return Icons.warning_rounded;
    if (c == AppPalette.amber)    return Icons.warning_amber_rounded;
    return Icons.info_outline_rounded;
  }
}

class _EmptyAlerts extends StatelessWidget {
  final String label;
  const _EmptyAlerts({required this.label});
  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72, height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  AppPalette.safe.withValues(alpha: 0.12),
                  AppPalette.abyss2,
                ]),
                border: Border.all(
                    color: AppPalette.safe.withValues(alpha: 0.20)),
              ),
              child: const Icon(Icons.notifications_off_outlined,
                  color: AppPalette.safe, size: 32),
            ),
            const SizedBox(height: 16),
            Text(label,
                style: const TextStyle(
                  color: AppPalette.textGrey,
                  fontSize: 14, fontWeight: FontWeight.w600)),
          ],
        ),
      );
}
