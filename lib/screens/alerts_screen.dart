// lib/screens/alerts_screen.dart
//
// OpsFlood — AlertsScreen
// Two tabs:
//   Tab 1 — Live CWC Gauge Alerts  (ThresholdAlertService, gauge breach events)
//   Tab 2 — IMD Weather Alerts     (SACHET NDMA, imdAlertsProvider)
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/threshold_alert.dart';
import '../providers/alerts_provider.dart';
import '../providers/flood_providers.dart';

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
    final ap       = ref.watch(alertsProvider);
    final loading  = ap.loading;
    final imdList  = ref.watch(imdAlertsProvider);

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
                    _Badge(count: ap.critical.length, color: const Color(0xFFF44336)),
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
                    _Badge(count: imdList.length, color: const Color(0xFFF97316)),
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
          _ImdTab(alerts: imdList),
        ],
      ),
    );
  }
}

// ───────────────────────────────────────────────────────────────────────
// Tab 1 — CWC Gauge Alerts
// ───────────────────────────────────────────────────────────────────────

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

// ───────────────────────────────────────────────────────────────────────
// Tab 2 — IMD Weather Alerts
// ───────────────────────────────────────────────────────────────────────

class _ImdTab extends StatelessWidget {
  final List<dynamic> alerts;
  const _ImdTab({required this.alerts});

  @override
  Widget build(BuildContext context) {
    if (alerts.isEmpty) {
      return _EmptyState(
        loading: false,
        icon: Icons.wb_sunny_outlined,
        message: 'No active IMD weather alerts',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: alerts.length,
      itemBuilder: (ctx, i) => _ImdCard(raw: alerts[i]),
    );
  }
}

class _ImdCard extends StatelessWidget {
  final dynamic raw;
  const _ImdCard({required this.raw});

  // Safely pull a string from nested maps
  String _s(List<String> keys) {
    dynamic cur = raw;
    for (final k in keys) {
      if (cur is! Map) return '';
      cur = cur[k];
    }
    return cur?.toString() ?? '';
  }

  Color _severityColor(String sev) {
    final s = sev.toUpperCase();
    if (s.contains('RED'))    return const Color(0xFFF44336);
    if (s.contains('ORANGE')) return const Color(0xFFF97316);
    if (s.contains('YELLOW')) return const Color(0xFFEAB308);
    return const Color(0xFF34C759);
  }

  @override
  Widget build(BuildContext context) {
    final theme    = Theme.of(context);

    // Try common CAP / SACHET field paths
    final headline = _s(['info', 'headline']).isNotEmpty
        ? _s(['info', 'headline'])
        : _s(['headline']);
    final area     = _s(['info', 'area', 'areaDesc']).isNotEmpty
        ? _s(['info', 'area', 'areaDesc'])
        : _s(['areaDesc']);
    final severity = _s(['info', 'severity']).isNotEmpty
        ? _s(['info', 'severity'])
        : _s(['severity']);
    final event    = _s(['info', 'event']).isNotEmpty
        ? _s(['info', 'event'])
        : _s(['event']);
    final desc     = _s(['info', 'description']).isNotEmpty
        ? _s(['info', 'description'])
        : _s(['description']);
    final effective = _s(['info', 'effective']).isNotEmpty
        ? _s(['info', 'effective'])
        : _s(['effective']);
    final expires   = _s(['info', 'expires']).isNotEmpty
        ? _s(['info', 'expires'])
        : _s(['expires']);

    final color    = _severityColor(severity);
    final label    = severity.isNotEmpty ? severity : 'ADVISORY';
    final title    = headline.isNotEmpty ? headline
        : event.isNotEmpty ? event
        : 'IMD Weather Alert';

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
            // Header
            Row(
              children: [
                Icon(Icons.thunderstorm_outlined, color: color, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: color.withValues(alpha: 0.5)),
                  ),
                  child: Text(
                    label.toUpperCase(),
                    style: TextStyle(
                      color: color, fontSize: 9, fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),

            if (area.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.location_on_outlined, size: 13,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      area,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.65)),
                    ),
                  ),
                ],
              ),
            ],

            if (desc.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                desc,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.75)),
              ),
            ],

            if (effective.isNotEmpty || expires.isNotEmpty) ...[
              const SizedBox(height: 8),
              DefaultTextStyle(
                style: theme.textTheme.labelSmall!.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
                child: Row(
                  children: [
                    if (effective.isNotEmpty)
                      Text('From: ${_fmtTime(effective)}'),
                    if (effective.isNotEmpty && expires.isNotEmpty)
                      const Text('  —  '),
                    if (expires.isNotEmpty)
                      Text('Until: ${_fmtTime(expires)}'),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _fmtTime(String raw) {
    try {
      final dt = DateTime.parse(raw).toLocal();
      return DateFormat('dd MMM, HH:mm').format(dt);
    } catch (_) {
      return raw.length > 16 ? raw.substring(0, 16) : raw;
    }
  }
}

// ── Shared widgets ────────────────────────────────────────────────────────────────────────────

class _Badge extends StatelessWidget {
  final int count;
  final Color color;
  const _Badge({required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$count',
        style: const TextStyle(
          color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold,
        ),
      ),
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
                if (alert.isNew)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: levelColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text('NEW',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '${alert.state} · ${alert.river}',
              style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
            ),
            const SizedBox(height: 10),
            _GaugeBar(
              current: alert.currentValue,
              warning: alert.warningLevel,
              danger:  alert.dangerLevel,
              hfl:     alert.hfl,
              fill:    alert.fillPercent,
              color:   levelColor,
              unit:    alert.unitLabel,
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
            Text(
              ts,
              style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
            ),
          ],
        ),
      ),
    );
  }
}

class _GaugeBar extends StatelessWidget {
  final double current, warning, danger, hfl, fill;
  final Color color;
  final String unit;
  const _GaugeBar({
    required this.current, required this.warning, required this.danger,
    required this.hfl, required this.fill, required this.color,
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
  const _MetricChip({required this.label, required this.value, required this.color});

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
      icon: Icon(
        Icons.filter_list,
        color: hasFilter ? Theme.of(context).colorScheme.primary : null,
      ),
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
