// lib/screens/alerts_screen.dart
//
// OpsFlood — AlertsScreen
// Two tabs:
//   Tab 1 — Live CWC Gauge Alerts  (ThresholdAlertService, gauge breach events)
//   Tab 2 — IMD Weather Alerts     (SACHET NDMA, fully parsed via ImdAlert model)
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/threshold_alert.dart';
import '../models/imd_alert.dart';
import '../providers/alerts_provider.dart';

class AlertsScreen extends ConsumerStatefulWidget {
  const AlertsScreen({super.key});
  static const route = '/alerts';

  @override
  ConsumerState<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends ConsumerState<AlertsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(alertsProvider).markAllSeen();
    });
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ap      = ref.watch(alertsProvider);
    final loading = ap.loading;
    final imdList = ap.imdAlerts;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Alerts'),
        actions: [
          if (loading)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: SizedBox(
                width: 20, height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () => ref.read(alertsProvider).refresh(),
              tooltip: 'Refresh',
            ),
          _FilterMenu(provider: ap),
        ],
        bottom: TabBar(
          controller: _tab,
          tabs: [
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.water, size: 16),
                  const SizedBox(width: 6),
                  const Text('CWC Gauge'),
                  if (ap.critical.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    _Badge(count: ap.critical.length,
                           color: const Color(0xFFF44336)),
                  ],
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.thunderstorm_outlined, size: 16),
                  const SizedBox(width: 6),
                  const Text('IMD Weather'),
                  if (imdList.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    _Badge(count: imdList.length,
                           color: const Color(0xFFF97316)),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          _CwcTab(provider: ap),
          _ImdTab(alerts: imdList, loading: loading),
        ],
      ),
    );
  }
}

// ─── Tab 1: CWC Gauge Alerts ──────────────────────────────────────────────────

class _CwcTab extends StatelessWidget {
  final AlertsProvider provider;
  const _CwcTab({required this.provider});

  @override
  Widget build(BuildContext context) {
    final alerts   = provider.filtered;
    final critical = provider.critical;
    final loading  = provider.loading;

    return Column(
      children: [
        if (critical.isNotEmpty)
          _CriticalBanner(count: critical.length),
        Expanded(
          child: alerts.isEmpty
              ? _EmptyState(
                  loading: loading,
                  icon: Icons.water,
                  message: 'All rivers within safe levels',
                )
              : RefreshIndicator(
                  onRefresh: () => provider.refresh(),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: alerts.length,
                    itemBuilder: (ctx, i) => _AlertCard(alert: alerts[i]),
                  ),
                ),
        ),
      ],
    );
  }
}

// ─── Tab 2: IMD Weather Alerts ────────────────────────────────────────────────

class _ImdTab extends StatelessWidget {
  final List<ImdAlert> alerts;
  final bool loading;
  const _ImdTab({required this.alerts, required this.loading});

  @override
  Widget build(BuildContext context) {
    if (alerts.isEmpty) {
      return _EmptyState(
        loading: loading,
        icon: Icons.wb_sunny_outlined,
        message: 'No active IMD weather alerts',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: alerts.length,
      itemBuilder: (ctx, i) => _ImdCard(alert: alerts[i]),
    );
  }
}

class _ImdCard extends StatelessWidget {
  final ImdAlert alert;
  const _ImdCard({required this.alert});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = alert.severity.color;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: color, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header row ──────────────────────────────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(alert.severity.icon, color: color, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    alert.displayTitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 8),
                // Severity pill
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: color.withValues(alpha: 0.6)),
                  ),
                  child: Text(
                    alert.severity.label.toUpperCase(),
                    style: TextStyle(
                      color: color, fontSize: 9, fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (alert.isNew) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text('NEW',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold)),
                  ),
                ],
              ],
            ),

            // ── Area ────────────────────────────────────────────────────────
            if (alert.area.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.location_on_outlined, size: 13,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      alert.area,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.65)),
                    ),
                  ),
                ],
              ),
            ],

            // ── Event type chip ─────────────────────────────────────────────
            if (alert.event.isNotEmpty) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  alert.event,
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],

            // ── Description ─────────────────────────────────────────────────
            if (alert.description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                alert.description,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface
                        .withValues(alpha: 0.75)),
              ),
            ],

            // ── Validity row ────────────────────────────────────────────────
            if (alert.effective != null || alert.expires != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.schedule_outlined, size: 12,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.45)),
                  const SizedBox(width: 4),
                  DefaultTextStyle(
                    style: theme.textTheme.labelSmall!.copyWith(
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.5)),
                    child: Row(
                      children: [
                        if (alert.effective != null)
                          Text('From: ${_fmt(alert.effective!)}'),
                        if (alert.effective != null && alert.expires != null)
                          const Text('  —  '),
                        if (alert.expires != null)
                          Text('Until: ${_fmt(alert.expires!)}'),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _fmt(DateTime dt) =>
      DateFormat('dd MMM, HH:mm').format(dt.toLocal());
}

// ─── Shared widgets ───────────────────────────────────────────────────────────

class _Badge extends StatelessWidget {
  final int count;
  final Color color;
  const _Badge({required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
          color: color, borderRadius: BorderRadius.circular(10)),
      child: Text('$count',
          style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold)),
    );
  }
}

class _CriticalBanner extends StatelessWidget {
  final int count;
  const _CriticalBanner({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AlertLevel.danger.color,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Row(
        children: [
          const Icon(Icons.crisis_alert, color: Colors.white, size: 20),
          const SizedBox(width: 8),
          Text(
            '$count station${count > 1 ? 's' : ''} at or above Danger level',
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

class _AlertCard extends StatelessWidget {
  final ThresholdAlert alert;
  const _AlertCard({required this.alert});

  @override
  Widget build(BuildContext context) {
    final theme      = Theme.of(context);
    final levelColor = alert.level.color;
    final ts = DateFormat('dd MMM, HH:mm').format(alert.timestamp.toLocal());

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: levelColor, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(alert.level.icon, color: levelColor, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(alert.cityName,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold)),
                ),
                if (alert.isNew)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                        color: levelColor,
                        borderRadius: BorderRadius.circular(4)),
                    child: const Text('NEW',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text('${alert.state} · ${alert.river}',
                style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface
                        .withValues(alpha: 0.6))),
            const SizedBox(height: 10),
            _GaugeBar(
              warning: alert.warningLevel,
              danger:  alert.dangerLevel,
              hfl:     alert.hfl,
              fill:    alert.fillPercent,
              color:   levelColor,
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _MetricChip(
                  label: 'Current',
                  value: '${alert.currentValue.toStringAsFixed(1)} ${alert.unitLabel}',
                  color: levelColor,
                ),
                _MetricChip(
                  label: 'Danger',
                  value: '${alert.dangerLevel.toStringAsFixed(1)} ${alert.unitLabel}',
                  color: AlertLevel.danger.color,
                ),
                _MetricChip(
                  label: 'HFL',
                  value: alert.hfl > 0
                      ? '${alert.hfl.toStringAsFixed(1)} ${alert.unitLabel}'
                      : 'N/A',
                  color: AlertLevel.extreme.color,
                ),
                Icon(alert.trend.icon, color: alert.trend.color, size: 20),
              ],
            ),
            const SizedBox(height: 8),
            Text(ts,
                style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurface
                        .withValues(alpha: 0.5))),
          ],
        ),
      ),
    );
  }
}

class _GaugeBar extends StatelessWidget {
  final double warning, danger, hfl, fill;
  final Color color;
  const _GaugeBar({
    required this.warning, required this.danger,
    required this.hfl, required this.fill, required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final clamped = (fill / 100).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: clamped,
            backgroundColor: color.withValues(alpha: 0.15),
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 10,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('WL ${warning.toStringAsFixed(1)}',
                style: const TextStyle(fontSize: 10, color: Colors.orange)),
            Text('DL ${danger.toStringAsFixed(1)}',
                style: const TextStyle(fontSize: 10, color: Colors.red)),
            if (hfl > 0)
              Text('HFL ${hfl.toStringAsFixed(1)}',
                  style: const TextStyle(fontSize: 10, color: Colors.purple)),
          ],
        ),
      ],
    );
  }
}

class _MetricChip extends StatelessWidget {
  final String label, value;
  final Color color;
  const _MetricChip(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 10, color: color, fontWeight: FontWeight.bold)),
        Text(value, style: const TextStyle(fontSize: 11)),
      ],
    );
  }
}

class _FilterMenu extends StatelessWidget {
  final AlertsProvider provider;
  const _FilterMenu({required this.provider});

  @override
  Widget build(BuildContext context) {
    final hasFilter =
        provider.filterLevel != null || provider.filterState != null;
    return PopupMenuButton<String>(
      icon: Icon(Icons.filter_list,
          color: hasFilter
              ? Theme.of(context).colorScheme.primary
              : null),
      onSelected: (val) {
        if (val == 'clear') { provider.clearFilters(); return; }
        final level = AlertLevel.values
            .where((l) => l.name == val)
            .firstOrNull;
        if (level != null) provider.setFilterLevel(level);
      },
      itemBuilder: (_) => [
        const PopupMenuItem(value: 'clear', child: Text('Clear filters')),
        const PopupMenuDivider(),
        ...AlertLevel.values.reversed
            .where((l) => l != AlertLevel.normal)
            .map((l) => PopupMenuItem(
                  value: l.name,
                  child: Row(
                    children: [
                      Icon(l.icon, color: l.color, size: 18),
                      const SizedBox(width: 8),
                      Text(l.label),
                    ],
                  ),
                )),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool loading;
  final IconData icon;
  final String message;
  const _EmptyState({
    required this.loading,
    required this.icon,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: loading
          ? const CircularProgressIndicator()
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon,
                    size: 64,
                    color: Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.4)),
                const SizedBox(height: 16),
                Text(message, style: const TextStyle(fontSize: 16)),
                const SizedBox(height: 8),
                const Text('Pull to refresh',
                    style: TextStyle(color: Colors.grey)),
              ],
            ),
    );
  }
}
