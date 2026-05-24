// lib/screens/alerts_screen.dart
//
// OpsFlood — AlertsScreen
// Full-screen list of threshold breach alerts, grouped by severity.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../models/threshold_alert.dart';
import '../providers/alerts_provider.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  static const route = '/alerts';

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AlertsProvider>().markAllSeen();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AlertsProvider>();
    final alerts   = provider.filtered;
    final theme    = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('River Alerts'),
        actions: [
          if (provider.loading)
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
              onPressed: provider.refresh,
              tooltip: 'Refresh now',
            ),
          _FilterMenu(provider: provider),
        ],
      ),
      body: Column(
        children: [
          // Active summary bar
          if (provider.critical.isNotEmpty)
            _CriticalBanner(count: provider.critical.length),

          // Alert list
          Expanded(
            child: alerts.isEmpty
                ? _EmptyState(loading: provider.loading)
                : RefreshIndicator(
                    onRefresh: provider.refresh,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: alerts.length,
                      itemBuilder: (ctx, i) => _AlertCard(alert: alerts[i]),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

// ─── Critical banner ─────────────────────────────────────────────────────────
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
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

// ─── Alert card ───────────────────────────────────────────────────────────────
class _AlertCard extends StatelessWidget {
  final ThresholdAlert alert;
  const _AlertCard({required this.alert});

  @override
  Widget build(BuildContext context) {
    final theme     = Theme.of(context);
    final levelColor = alert.level.color;
    final ts         = DateFormat('dd MMM, HH:mm').format(alert.timestamp.toLocal());

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
            // Header row
            Row(
              children: [
                Icon(alert.level.icon, color: levelColor, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    alert.cityName,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                // New badge
                if (alert.isNew)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: levelColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text('NEW',
                        style: TextStyle(color: Colors.white, fontSize: 10,
                            fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
            const SizedBox(height: 6),

            // Sub-header: state, river
            Text(
              '${alert.state} · ${alert.river}',
              style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.6)),
            ),
            const SizedBox(height: 10),

            // Gauge bar
            _GaugeBar(
              current:  alert.currentValue,
              warning:  alert.warningLevel,
              danger:   alert.dangerLevel,
              hfl:      alert.hfl,
              fill:     alert.fillPercent,
              color:    levelColor,
              unit:     alert.unitLabel,
            ),
            const SizedBox(height: 10),

            // Metrics row
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

            // Footer
            Text(
              ts,
              style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.5)),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Gauge bar ────────────────────────────────────────────────────────────────
class _GaugeBar extends StatelessWidget {
  final double current, warning, danger, hfl, fill;
  final Color color;
  final String unit;

  const _GaugeBar({
    required this.current,
    required this.warning,
    required this.danger,
    required this.hfl,
    required this.fill,
    required this.color,
    required this.unit,
  });

  @override
  Widget build(BuildContext context) {
    final clampedFill = (fill / 100).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: clampedFill,
            backgroundColor: color.withOpacity(0.15),
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

// ─── Metric chip ──────────────────────────────────────────────────────────────
class _MetricChip extends StatelessWidget {
  final String label, value;
  final Color color;
  const _MetricChip({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label,
            style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold)),
        Text(value, style: const TextStyle(fontSize: 11)),
      ],
    );
  }
}

// ─── Filter menu ─────────────────────────────────────────────────────────────
class _FilterMenu extends StatelessWidget {
  final AlertsProvider provider;
  const _FilterMenu({required this.provider});

  @override
  Widget build(BuildContext context) {
    final hasFilter = provider.filterLevel != null || provider.filterState != null;
    return PopupMenuButton<String>(
      icon: Icon(Icons.filter_list,
          color: hasFilter ? Theme.of(context).colorScheme.primary : null),
      onSelected: (val) {
        if (val == 'clear') {
          provider.clearFilters();
          return;
        }
        final level = AlertLevel.values.where((l) => l.name == val).firstOrNull;
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

// ─── Empty state ──────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final bool loading;
  const _EmptyState({required this.loading});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: loading
          ? const CircularProgressIndicator()
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle_outline,
                    size: 64,
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.4)),
                const SizedBox(height: 16),
                const Text('All rivers within safe levels',
                    style: TextStyle(fontSize: 16)),
                const SizedBox(height: 8),
                const Text('Pull to refresh',
                    style: TextStyle(color: Colors.grey)),
              ],
            ),
    );
  }
}
