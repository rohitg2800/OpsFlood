// lib/screens/alerts_screen.dart
// OpsFlood — AlertsScreen v5 (Abyss Ops rebuild)
// Minimal, accurate, premium. Removed noisy gauge references.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/threshold_alert.dart';
import '../providers/alerts_provider.dart';
import '../theme/river_theme.dart';
import '../widgets/risk_bar.dart';

class AlertsScreen extends ConsumerStatefulWidget {
  static const route = '/alerts';
  const AlertsScreen({super.key});
  @override
  ConsumerState<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends ConsumerState<AlertsScreen> {
  @override
  Widget build(BuildContext context) {
    final provider = ref.watch(alertsProvider);
    final alerts   = provider.filtered;
    final critical = provider.critical;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      provider.markAllSeen();
    });

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppPalette.abyss0,
        body: SafeArea(
          child: Column(
            children: [
              _header(critical.length, alerts.length),
              if (critical.isNotEmpty)
                _criticalBanner(critical.length),
              _filterBar(provider),
              Expanded(
                child: alerts.isEmpty
                    ? _emptyState(provider.loading)
                    : RefreshIndicator(
                        color: AppPalette.cyan,
                        backgroundColor: AppPalette.abyss2,
                        onRefresh: provider.refresh,
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
                          itemCount: alerts.length,
                          itemBuilder: (_, i) => _AlertCard(alert: alerts[i]),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(int critCount, int total) => Container(
    padding: const EdgeInsets.fromLTRB(20, 20, 20, 14),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [
          AppPalette.critical.withValues(alpha: critCount > 0 ? 0.07 : 0.0),
          AppPalette.abyss0,
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      border: Border(
          bottom: BorderSide(
              color: AppPalette.abyssStroke, width: 1)),
    ),
    child: Row(children: [
      Container(
        width: 42, height: 42,
        decoration: BoxDecoration(
          color: AppPalette.critical.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: AppPalette.critical.withValues(alpha: 0.30)),
        ),
        child: const Icon(Icons.notifications_rounded,
            color: AppPalette.critical, size: 22),
      ),
      const SizedBox(width: 14),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Flood Alerts',
                style: TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w900,
                  color: AppPalette.textWhite, letterSpacing: -0.6,
                )),
            Text(
              '$total active alert${total != 1 ? 's' : ''}',
              style: const TextStyle(
                  fontSize: 11, color: AppPalette.textGrey),
            ),
          ],
        ),
      ),
      if (critCount > 0)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: AppPalette.critical.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: AppPalette.critical.withValues(alpha: 0.40)),
          ),
          child: Text(
            '$critCount CRITICAL',
            style: const TextStyle(
              color: AppPalette.critical, fontSize: 10,
              fontWeight: FontWeight.w900, letterSpacing: 0.3,
            ),
          ),
        ),
    ]),
  );

  Widget _criticalBanner(int n) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
    color: AppPalette.critical.withValues(alpha: 0.12),
    child: Row(children: [
      const Icon(Icons.crisis_alert_rounded,
          color: AppPalette.critical, size: 18),
      const SizedBox(width: 10),
      Text(
        '$n station${n > 1 ? 's' : ''} at or above danger level',
        style: const TextStyle(
          color: AppPalette.critical,
          fontWeight: FontWeight.w700, fontSize: 12,
        ),
      ),
    ]),
  );

  Widget _filterBar(AlertsProvider provider) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
    child: Row(children: [
      Expanded(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            _FilterChip(
              label: 'All',
              active: provider.filterLevel == null,
              onTap: provider.clearFilters,
              color: AppPalette.cyan,
            ),
            ...AlertLevel.values.reversed
                .where((l) => l != AlertLevel.normal)
                .map((l) => _FilterChip(
                      label: l.label,
                      active: provider.filterLevel == l,
                      onTap: () => provider.setFilterLevel(l),
                      color: l.color,
                    )),
          ]),
        ),
      ),
      GestureDetector(
        onTap: provider.refresh,
        child: Container(
          width: 34, height: 34,
          margin: const EdgeInsets.only(left: 8),
          decoration: BoxDecoration(
            color: AppPalette.abyss2,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppPalette.abyssStroke),
          ),
          child: const Icon(Icons.refresh_rounded,
              color: AppPalette.textGrey, size: 17),
        ),
      ),
    ]),
  );

  Widget _emptyState(bool loading) => Center(
    child: loading
        ? const CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation(AppPalette.cyan))
        : Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64, height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppPalette.safe.withValues(alpha: 0.08),
                  border: Border.all(
                      color: AppPalette.safe.withValues(alpha: 0.20)),
                ),
                child: const Icon(Icons.check_circle_outline_rounded,
                    size: 32, color: AppPalette.safe),
              ),
              const SizedBox(height: 14),
              const Text(
                'All rivers within safe levels',
                style: TextStyle(
                    color: AppPalette.textGrey,
                    fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ],
          ),
  );
}

// ── Alert Card ────────────────────────────────────────────────────────────
class _AlertCard extends StatelessWidget {
  final ThresholdAlert alert;
  const _AlertCard({required this.alert});

  @override
  Widget build(BuildContext context) {
    final col = alert.level.color;
    final ts  = DateFormat('dd MMM  HH:mm').format(alert.timestamp.toLocal());
    final pct = (alert.fillPercent).clamp(0.0, 100.0);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppPalette.abyss2,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: col.withValues(alpha: 0.25), width: 1),
        boxShadow: [
          BoxShadow(
            color: col.withValues(alpha: 0.06),
            blurRadius: 18, offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: icon + city + level badge + new pill
          Row(children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: col.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(alert.level.icon, color: col, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(alert.cityName,
                      style: const TextStyle(
                        color: AppPalette.textWhite,
                        fontWeight: FontWeight.w800, fontSize: 14,
                      )),
                  Text('${alert.state}  ·  ${alert.river}',
                      style: const TextStyle(
                          color: AppPalette.textGrey, fontSize: 10)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: col.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: col.withValues(alpha: 0.38)),
              ),
              child: Text(alert.level.label,
                  style: TextStyle(
                    color: col, fontSize: 10,
                    fontWeight: FontWeight.w900,
                  )),
            ),
            if (alert.isNew) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 5, vertical: 3),
                decoration: BoxDecoration(
                  color: col,
                  borderRadius: BorderRadius.circular(5),
                ),
                child: const Text('NEW',
                    style: TextStyle(
                      color: Colors.white, fontSize: 8,
                      fontWeight: FontWeight.w900,
                    )),
              ),
            ],
          ]),
          const SizedBox(height: 14),
          // Risk bar (replaces gauge)
          RiskBar(
            value:    pct,
            warning:  60,
            danger:   80,
            barColor: col,
            label:    'Fill Level',
            height:   8,
          ),
          const SizedBox(height: 12),
          // Row 3: metrics
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _metric(
                '${alert.currentValue.toStringAsFixed(0)} m³/s',
                'Current flow', col,
              ),
              _metric(
                '${alert.dangerLevel.toStringAsFixed(0)} m³/s',
                'Danger level', AppPalette.critical,
              ),
              Row(children: [
                Icon(alert.trend.icon,
                    size: 12, color: alert.trend.color),
                const SizedBox(width: 4),
                Text(alert.trend.name,
                    style: TextStyle(
                      color: alert.trend.color,
                      fontSize: 10, fontWeight: FontWeight.w700,
                    )),
              ]),
              Text(ts,
                  style: const TextStyle(
                      color: AppPalette.textDim, fontSize: 9)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metric(String val, String label, Color c) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(val, style: TextStyle(
        color: c, fontSize: 12, fontWeight: FontWeight.w800)),
      Text(label, style: const TextStyle(
        color: AppPalette.textGrey, fontSize: 9)),
    ],
  );
}

// ── Filter chip ────────────────────────────────────────────────────────────
class _FilterChip extends StatelessWidget {
  final String   label;
  final bool     active;
  final Color    color;
  final VoidCallback onTap;
  const _FilterChip({
    required this.label,
    required this.active,
    required this.color,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: active ? color.withValues(alpha: 0.14) : AppPalette.abyss2,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: active
              ? color.withValues(alpha: 0.42)
              : AppPalette.abyssStroke,
          width: active ? 1.5 : 1,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: active ? FontWeight.w800 : FontWeight.w500,
          color: active ? color : AppPalette.textGrey,
        ),
      ),
    ),
  );
}
