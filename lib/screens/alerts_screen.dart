// lib/screens/alerts_screen.dart
//
// OpsFlood — AlertsScreen (WRD Bihar only)
//
// Single tab showing WRD Bihar gauge alerts from kBiharGauges.
// Data: OpsFlood backend → ThresholdAlertService → AlertsProvider
// Thresholds: official WRD/CWC warningLevel / dangerLevel / hfl (m MSL)
//
// Layout:
//   • Summary strip  — 5 level pills with live counts
//   • Critical banner — shown if danger/extreme stations exist
//   • Grouped cards  — extreme → danger → warning → watch → normal
//   • Each card shows: gauge height (m MSL), WL/DL/HFL, fill bar,
//     breach margin vs danger, trend arrow, district, river
//   • Filter menu    — by AlertLevel or river
//   • Pull-to-refresh
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/threshold_alert.dart';
import '../providers/alerts_provider.dart';

// ─── Formatters ───────────────────────────────────────────────────────────────
String _fmtDate(DateTime dt) => DateFormat('dd MMM, HH:mm').format(dt.toLocal());
String _fmtLevel(double v)   => v.toStringAsFixed(2);

// ─────────────────────────────────────────────────────────────────────────────
// AlertsScreen
// ─────────────────────────────────────────────────────────────────────────────

class AlertsScreen extends ConsumerStatefulWidget {
  const AlertsScreen({super.key});
  static const route = '/alerts';

  @override
  ConsumerState<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends ConsumerState<AlertsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(alertsProvider).markAllSeen();
    });
  }

  @override
  Widget build(BuildContext context) {
    final ap      = ref.watch(alertsProvider);
    final loading = ap.loading;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('WRD Bihar Alerts'),
        elevation: 0,
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
              icon: const Icon(Icons.refresh_rounded),
              onPressed: () => ap.refresh(),
              tooltip: 'Refresh',
            ),
          _FilterMenu(provider: ap),
          const SizedBox(width: 4),
        ],
      ),
      body: _WrdAlertsBody(provider: ap),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Main body
// ─────────────────────────────────────────────────────────────────────────────

class _WrdAlertsBody extends StatelessWidget {
  final AlertsProvider provider;
  const _WrdAlertsBody({required this.provider});

  @override
  Widget build(BuildContext context) {
    final all     = provider.filtered;
    final loading = provider.loading;

    final extreme = all.where((a) => a.level == AlertLevel.extreme).toList();
    final danger  = all.where((a) => a.level == AlertLevel.danger).toList();
    final warning = all.where((a) => a.level == AlertLevel.warning).toList();
    final watch   = all.where((a) => a.level == AlertLevel.watch).toList();
    final normal  = all.where((a) => a.level == AlertLevel.normal).toList();

    final hasActionable =
        extreme.isNotEmpty || danger.isNotEmpty ||
        warning.isNotEmpty || watch.isNotEmpty;

    return RefreshIndicator(
      onRefresh: () => provider.refresh(),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [

          // ── Summary strip ─────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: _SummaryStrip(
              extreme: extreme.length,
              danger:  danger.length,
              warning: warning.length,
              watch:   watch.length,
              normal:  normal.length,
              total:   all.length,
            ),
          ),

          // ── Critical banner ───────────────────────────────────────────────
          if (extreme.isNotEmpty || danger.isNotEmpty)
            SliverToBoxAdapter(
              child: _CriticalBanner(
                count: extreme.length + danger.length,
              ),
            ),

          // ── Empty state ───────────────────────────────────────────────────
          if (all.isEmpty)
            SliverFillRemaining(
              child: _EmptyState(loading: loading),
            ),

          // ── Grouped sections ──────────────────────────────────────────────
          if (extreme.isNotEmpty) ...[
            _sectionHeader(context, AlertLevel.extreme),
            _alertSliver(extreme),
          ],
          if (danger.isNotEmpty) ...[
            _sectionHeader(context, AlertLevel.danger),
            _alertSliver(danger),
          ],
          if (warning.isNotEmpty) ...[
            _sectionHeader(context, AlertLevel.warning),
            _alertSliver(warning),
          ],
          if (watch.isNotEmpty) ...[
            _sectionHeader(context, AlertLevel.watch),
            _alertSliver(watch),
          ],
          // Show normal only when no actionable alerts exist
          if (!hasActionable && normal.isNotEmpty) ...[
            _sectionHeader(context, AlertLevel.normal),
            _alertSliver(normal),
          ],

          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }

  Widget _sectionHeader(BuildContext context, AlertLevel level) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: Row(
          children: [
            Icon(level.icon, color: level.color, size: 16),
            const SizedBox(width: 6),
            Text(
              level.label.toUpperCase(),
              style: TextStyle(
                color:       level.color,
                fontSize:    12,
                fontWeight:  FontWeight.w800,
                letterSpacing: 1.1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  SliverList _alertSliver(List<ThresholdAlert> alerts) {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (ctx, i) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: _GaugeCard(alert: alerts[i]),
        ),
        childCount: alerts.length,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Summary strip
// ─────────────────────────────────────────────────────────────────────────────

class _SummaryStrip extends StatelessWidget {
  final int extreme, danger, warning, watch, normal, total;
  const _SummaryStrip({
    required this.extreme,
    required this.danger,
    required this.warning,
    required this.watch,
    required this.normal,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color:        theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border:       Border.all(color: theme.dividerColor),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _Pill(count: extreme, level: AlertLevel.extreme),
              _Pill(count: danger,  level: AlertLevel.danger),
              _Pill(count: warning, level: AlertLevel.warning),
              _Pill(count: watch,   level: AlertLevel.watch),
              _Pill(count: normal,  level: AlertLevel.normal),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'WRD Bihar · ${total} stations monitored',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
            ),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final int count;
  final AlertLevel level;
  const _Pill({required this.count, required this.level});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 34, height: 34,
          decoration: BoxDecoration(
            color:  level.color.withValues(alpha: count > 0 ? 0.18 : 0.07),
            shape:  BoxShape.circle,
          ),
          child: Center(
            child: Text(
              '$count',
              style: TextStyle(
                color:      count > 0 ? level.color
                    : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
                fontWeight: FontWeight.bold,
                fontSize:   13,
              ),
            ),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          level.label,
          style: TextStyle(
            fontSize:   9,
            color:      count > 0 ? level.color
                : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.35),
            fontWeight: count > 0 ? FontWeight.w700 : FontWeight.normal,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Gauge card — one per BiharGauge station
// ─────────────────────────────────────────────────────────────────────────────

class _GaugeCard extends StatelessWidget {
  final ThresholdAlert alert;
  const _GaugeCard({required this.alert});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = alert.level.color;

    // Fill fraction: (currentValue - warningLevel) / (hfl - warningLevel)
    // clamped to [0, 1].  Below warning = 0.
    final span    = (alert.hfl - alert.warningLevel).abs();
    final fill    = span > 0
        ? ((alert.currentValue - alert.warningLevel) / span).clamp(0.0, 1.0)
        : (alert.level != AlertLevel.normal ? 0.05 : 0.0);
    // Warning tick position relative to [warningLevel, hfl]
    // i.e. always at 0 on this bar scale, but we pin it at the DL fraction.
    final dlFrac  = span > 0
        ? ((alert.dangerLevel - alert.warningLevel) / span).clamp(0.0, 1.0)
        : 0.65;

    final breachSign  = alert.breachMargin >= 0 ? '+' : '';
    final breachText  =
        '$breachSign${alert.breachMargin.toStringAsFixed(2)} m';
    final breachColor = alert.breachMargin >= 0
        ? AlertLevel.danger.color
        : const Color(0xFF4CAF50);

    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: color.withValues(alpha: 0.55), width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ── Header row ────────────────────────────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(
                    color:        color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(alert.level.icon, color: color, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        alert.cityName,
                        style: theme.textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${alert.river}  ·  ${alert.state}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.55),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                _LevelBadge(level: alert.level),
                if (alert.isNew) ...[
                  const SizedBox(width: 6),
                  _NewBadge(color: color),
                ],
              ],
            ),

            const SizedBox(height: 12),

            // ── Fill bar (WL → HFL scale) ─────────────────────────────────
            _FillBar(
              fillFraction: fill,
              dlFraction:   dlFrac,
              color:        color,
            ),

            const SizedBox(height: 6),

            // ── Threshold labels ──────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _ThreshLabel(
                  icon:  Icons.warning_amber_rounded,
                  color: AlertLevel.warning.color,
                  label: 'WL',
                  value: '${_fmtLevel(alert.warningLevel)} m',
                ),
                _ThreshLabel(
                  icon:  Icons.dangerous_outlined,
                  color: AlertLevel.danger.color,
                  label: 'DL',
                  value: '${_fmtLevel(alert.dangerLevel)} m',
                ),
                if (alert.hfl > 0)
                  _ThreshLabel(
                    icon:  Icons.crisis_alert,
                    color: AlertLevel.extreme.color,
                    label: 'HFL',
                    value: '${_fmtLevel(alert.hfl)} m',
                  ),
                // Trend
                Row(
                  children: [
                    Icon(alert.trend.icon,  color: alert.trend.color, size: 18),
                    const SizedBox(width: 2),
                    Text(
                      alert.trend.name,
                      style: TextStyle(
                        fontSize:   10,
                        color:      alert.trend.color,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 10),

            // ── Metric tiles ──────────────────────────────────────────────
            IntrinsicHeight(
              child: Row(
                children: [
                  _MetricTile(
                    label: 'Level (m MSL)',
                    value: _fmtLevel(alert.currentValue),
                    color: color,
                    flex: 2,
                  ),
                  VerticalDivider(width: 1, color: theme.dividerColor),
                  _MetricTile(
                    label: 'vs Danger',
                    value: breachText,
                    color: breachColor,
                    flex: 2,
                  ),
                  VerticalDivider(width: 1, color: theme.dividerColor),
                  _MetricTile(
                    label: 'Fill %',
                    value: '${(fill * 100).toStringAsFixed(0)}%',
                    color: color,
                    flex: 1,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // ── Footer ────────────────────────────────────────────────────
            Row(
              children: [
                Icon(
                  Icons.access_time_rounded,
                  size: 12,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                ),
                const SizedBox(width: 4),
                Text(
                  _fmtDate(alert.timestamp),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
                  ),
                ),
                const Spacer(),
                Icon(
                  Icons.water_drop_outlined,
                  size: 12,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                ),
                const SizedBox(width: 3),
                Text(
                  'WRD Bihar',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Fill bar — WL to HFL scale, DL tick
// ─────────────────────────────────────────────────────────────────────────────

class _FillBar extends StatelessWidget {
  final double fillFraction;
  final double dlFraction;   // where DL sits on the WL→HFL scale
  final Color  color;
  const _FillBar({
    required this.fillFraction,
    required this.dlFraction,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (ctx, box) {
      final w = box.maxWidth;
      return SizedBox(
        height: 14,
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(7),
              child: LinearProgressIndicator(
                value: fillFraction,
                backgroundColor: color.withValues(alpha: 0.12),
                valueColor: AlwaysStoppedAnimation<Color>(color),
                minHeight: 14,
              ),
            ),
            // Danger level tick (orange)
            Positioned(
              left: (dlFraction * w).clamp(0.0, w) - 1.5,
              top: 1, bottom: 1,
              child: Container(
                width: 3,
                decoration: BoxDecoration(
                  color: AlertLevel.danger.color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ],
        ),
      );
    });
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Small shared widgets
// ─────────────────────────────────────────────────────────────────────────────

class _LevelBadge extends StatelessWidget {
  final AlertLevel level;
  const _LevelBadge({required this.level});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color:  level.color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: level.color.withValues(alpha: 0.55)),
      ),
      child: Text(
        level.label.toUpperCase(),
        style: TextStyle(
          color:      level.color,
          fontSize:   9,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _NewBadge extends StatelessWidget {
  final Color color;
  const _NewBadge({required this.color});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
      decoration: BoxDecoration(
        color: color, borderRadius: BorderRadius.circular(4),
      ),
      child: const Text('NEW',
          style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
    );
  }
}

class _ThreshLabel extends StatelessWidget {
  final IconData icon;
  final Color    color;
  final String   label;
  final String   value;
  const _ThreshLabel({required this.icon, required this.color,
    required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 11, color: color),
        const SizedBox(width: 3),
        Text('$label: $value',
            style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _MetricTile extends StatelessWidget {
  final String label;
  final String value;
  final Color  color;
  final int    flex;
  const _MetricTile({required this.label, required this.value,
    required this.color, this.flex = 1});
  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label,
                style: TextStyle(
                  fontSize: 9,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                  fontWeight: FontWeight.w600, letterSpacing: 0.3,
                )),
            const SizedBox(height: 2),
            Text(value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12, color: color, fontWeight: FontWeight.bold,
                )),
          ],
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
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 4),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
      decoration: BoxDecoration(
        color: AlertLevel.danger.color.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.crisis_alert, color: Colors.white, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$count station${count > 1 ? 's' : ''} at or above Danger Level — WRD Bihar',
              style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool loading;
  const _EmptyState({required this.loading});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (loading) return const Center(child: CircularProgressIndicator());
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.water_rounded, size: 40,
                  color: theme.colorScheme.primary.withValues(alpha: 0.45)),
            ),
            const SizedBox(height: 16),
            Text('All stations normal',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
                textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Text(
              'All 31 WRD Bihar gauge stations are below warning level.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            const Text('Pull down to refresh',
                style: TextStyle(color: Colors.grey, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Filter menu
// ─────────────────────────────────────────────────────────────────────────────

class _FilterMenu extends StatelessWidget {
  final AlertsProvider provider;
  const _FilterMenu({required this.provider});

  // Rivers present in kBiharGauges
  static const _rivers = [
    'Ganga', 'Kosi', 'Gandak', 'Bagmati', 'Burhi Gandak',
    'Ghaghra', 'Mahananda', 'Kamla', 'Kamalabalan',
    'Adhwara', 'Punpun',
  ];

  @override
  Widget build(BuildContext context) {
    final hasFilter = provider.filterLevel != null || provider.filterRiver != null;
    return PopupMenuButton<String>(
      icon: Icon(
        Icons.filter_list_rounded,
        color: hasFilter ? Theme.of(context).colorScheme.primary : null,
      ),
      tooltip: 'Filter',
      onSelected: (val) {
        if (val == 'clear') { provider.clearFilters(); return; }
        // Check if it's a level name
        final level = AlertLevel.values
            .where((l) => l.name == val).firstOrNull;
        if (level != null) { provider.setFilterLevel(level); return; }
        // Otherwise it's a river
        provider.setFilterRiver(val);
      },
      itemBuilder: (_) => [
        const PopupMenuItem(
          value: 'clear',
          child: Row(children: [
            Icon(Icons.clear_all_rounded, size: 18), SizedBox(width: 8),
            Text('Clear filters'),
          ]),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          enabled: false,
          child: Text('BY LEVEL', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
        ),
        ...AlertLevel.values.reversed
            .where((l) => l != AlertLevel.normal)
            .map((l) => PopupMenuItem(
              value: l.name,
              child: Row(children: [
                Icon(l.icon, color: l.color, size: 18),
                const SizedBox(width: 8),
                Text(l.label),
              ]),
            )),
        const PopupMenuDivider(),
        const PopupMenuItem(
          enabled: false,
          child: Text('BY RIVER', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
        ),
        ..._rivers.map((r) => PopupMenuItem(
          value: r,
          child: Row(children: [
            const Icon(Icons.waves_rounded, size: 18),
            const SizedBox(width: 8),
            Text(r),
          ]),
        )),
      ],
    );
  }
}
