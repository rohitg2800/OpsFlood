// lib/screens/alerts_screen.dart
//
// OpsFlood — AlertsScreen (fully recoded)
//
// DATA SOURCES:
//   Tab 1 — CWC / GloFAS Discharge Alerts
//     • ThresholdAlertService (Option B) — discharge vs return-period thresholds
//     • ALL levels shown (normal, watch, warning, danger, extreme) but grouped
//     • liveLevelsProvider also consulted to show FloodData-based capacity bars
//       alongside discharge alerts so the user sees both gauge height AND discharge.
//
//   Tab 2 — IMD SACHET Weather Alerts
//     • imdAlerts from AlertsProvider (parsed ImdAlert objects)
//     • Grouped by ImdSeverity: RED → ORANGE → YELLOW → GREEN
//     • Shows valid time window, event type chip, location, and description
//
// LOGIC CHANGES vs old screen:
//   • Alerts are no longer filtered to only show non-normal — the full list
//     is shown with colour-coded rows so the user sees the whole picture.
//   • CWC tab has a summary header row with counts per level.
//   • Each discharge card shows: discharge m³/s, return-period thresholds,
//     fillPercent bar, breach margin, and trend arrow.
//   • Sort: extreme > danger > warning > watch > normal; within same level,
//     most recent timestamp first.
//   • IMD tab groups by severity with sticky section headers.
//   • Both tabs show an "All clear" illustration when empty.
//   • Pull-to-refresh on both tabs.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/threshold_alert.dart';
import '../models/imd_alert.dart';
import '../models/flood_data.dart';
import '../providers/alerts_provider.dart';
import '../providers/flood_providers.dart';

// ─── Date formatter ───────────────────────────────────────────────────────────
String _fmtDate(DateTime dt) =>
    DateFormat('dd MMM, HH:mm').format(dt.toLocal());

// ─── Number formatter (compact) ───────────────────────────────────────────────
String _fmtDischarge(double v) {
  if (v >= 10000) return '${(v / 1000).toStringAsFixed(1)}k';
  if (v >= 1000)  return '${(v / 1000).toStringAsFixed(2)}k';
  return v.toStringAsFixed(1);
}

// ─────────────────────────────────────────────────────────────────────────────
// AlertsScreen
// ─────────────────────────────────────────────────────────────────────────────

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
    final ap         = ref.watch(alertsProvider);
    final loading    = ap.loading;
    final imdList    = ap.imdAlerts;
    final cwcAlerts  = ap.all; // full list (all levels)
    final imdRedCount = imdList.where((a) => a.severity == ImdSeverity.red).length;

    // Count actionable CWC alerts (watch+)
    final cwcActionable = cwcAlerts
        .where((a) => a.level != AlertLevel.normal)
        .length;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Alerts'),
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
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: TabBar(
            controller: _tab,
            indicatorSize: TabBarIndicatorSize.tab,
            tabs: [
              _TabLabel(
                icon: Icons.water_rounded,
                label: 'CWC / GloFAS',
                badgeCount: cwcActionable,
                badgeColor: cwcActionable > 0
                    ? const Color(0xFFF44336)
                    : null,
              ),
              _TabLabel(
                icon: Icons.thunderstorm_rounded,
                label: 'IMD Weather',
                badgeCount: imdList.length,
                badgeColor: imdRedCount > 0
                    ? const Color(0xFFF44336)
                    : imdList.isNotEmpty
                        ? const Color(0xFFF97316)
                        : null,
              ),
            ],
          ),
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          _CwcTab(provider: ap),
          _ImdTab(alerts: imdList, loading: loading, onRefresh: ap.refresh),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab 1 — CWC / GloFAS Discharge Alerts
// ─────────────────────────────────────────────────────────────────────────────

class _CwcTab extends ConsumerWidget {
  final AlertsProvider provider;
  const _CwcTab({required this.provider});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final liveLevels = ref.watch(liveLevelsProvider);

    // Build a lookup from cityId / city name to FloodData for enrichment
    final liveMap = <String, FloodData>{};
    for (final fd in liveLevels) {
      liveMap[fd.id]               = fd;
      liveMap[fd.city.toLowerCase()] = fd;
    }

    final all     = provider.filtered; // sorted by level desc, then timestamp
    final loading = provider.loading;

    // Group by AlertLevel
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
          // ── Summary strip ──────────────────────────────────────────────
          SliverToBoxAdapter(
            child: _CwcSummaryStrip(
              extreme: extreme.length,
              danger:  danger.length,
              warning: warning.length,
              watch:   watch.length,
              normal:  normal.length,
            ),
          ),

          // ── Critical banner ─────────────────────────────────────────────
          if (extreme.isNotEmpty || danger.isNotEmpty)
            SliverToBoxAdapter(
              child: _CriticalBanner(
                count: extreme.length + danger.length,
              ),
            ),

          // ── Empty state ─────────────────────────────────────────────────
          if (all.isEmpty)
            SliverFillRemaining(
              child: _EmptyState(
                loading: loading,
                icon: Icons.water_rounded,
                message: 'No discharge alerts',
                sub: 'All monitored rivers are within safe discharge ranges.',
              ),
            ),

          // ── Grouped sections ─────────────────────────────────────────────
          if (extreme.isNotEmpty) ...[
            _sectionHeader(context, AlertLevel.extreme),
            _alertSliver(extreme, liveMap),
          ],
          if (danger.isNotEmpty) ...[
            _sectionHeader(context, AlertLevel.danger),
            _alertSliver(danger, liveMap),
          ],
          if (warning.isNotEmpty) ...[
            _sectionHeader(context, AlertLevel.warning),
            _alertSliver(warning, liveMap),
          ],
          if (watch.isNotEmpty) ...[
            _sectionHeader(context, AlertLevel.watch),
            _alertSliver(watch, liveMap),
          ],
          if (!hasActionable && normal.isNotEmpty) ...[
            _sectionHeader(context, AlertLevel.normal),
            _alertSliver(normal, liveMap),
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
                color: level.color,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  SliverList _alertSliver(
      List<ThresholdAlert> alerts, Map<String, FloodData> liveMap) {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (ctx, i) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: _DischargeCard(
            alert:    alerts[i],
            liveData: liveMap[alerts[i].cityId] ??
                      liveMap[alerts[i].cityName.toLowerCase()],
          ),
        ),
        childCount: alerts.length,
      ),
    );
  }
}

// ── Summary strip ─────────────────────────────────────────────────────────────

class _CwcSummaryStrip extends StatelessWidget {
  final int extreme, danger, warning, watch, normal;
  const _CwcSummaryStrip({
    required this.extreme,
    required this.danger,
    required this.warning,
    required this.watch,
    required this.normal,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).dividerColor,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _SummaryPill(count: extreme, level: AlertLevel.extreme),
          _SummaryPill(count: danger,  level: AlertLevel.danger),
          _SummaryPill(count: warning, level: AlertLevel.warning),
          _SummaryPill(count: watch,   level: AlertLevel.watch),
          _SummaryPill(count: normal,  level: AlertLevel.normal),
        ],
      ),
    );
  }
}

class _SummaryPill extends StatelessWidget {
  final int count;
  final AlertLevel level;
  const _SummaryPill({required this.count, required this.level});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(
            color: level.color.withValues(alpha: count > 0 ? 0.18 : 0.07),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              '$count',
              style: TextStyle(
                color: count > 0
                    ? level.color
                    : Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.3),
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          level.label,
          style: TextStyle(
            fontSize: 9,
            color: count > 0
                ? level.color
                : Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.35),
            fontWeight: count > 0 ? FontWeight.w700 : FontWeight.normal,
          ),
        ),
      ],
    );
  }
}

// ── Discharge card ────────────────────────────────────────────────────────────

class _DischargeCard extends StatelessWidget {
  final ThresholdAlert alert;
  final FloodData?     liveData; // enrichment from liveLevelsProvider
  const _DischargeCard({required this.alert, this.liveData});

  @override
  Widget build(BuildContext context) {
    final theme      = Theme.of(context);
    final color      = alert.level.color;
    final ts         = _fmtDate(alert.timestamp);
    final isDischarge = alert.isDischarge;

    // Effective fill: prefer alert.fillPercent; fallback to liveData.capacityPercent
    final fillPct = alert.fillPercent > 0
        ? alert.fillPercent
        : (liveData?.capacityPercent ?? 0.0);
    final clamped = (fillPct / 100).clamp(0.0, 1.0);

    // Effective gauge from liveData (if available and not discharge mode)
    final hasGauge = !isDischarge &&
        liveData != null &&
        liveData!.currentLevel > 0;

    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: color.withValues(alpha: 0.6), width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Level icon
                Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
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
                const SizedBox(width: 8),
                // Level badge
                _LevelBadge(level: alert.level),
                if (alert.isNew) ...[
                  const SizedBox(width: 6),
                  _NewBadge(color: color),
                ],
              ],
            ),

            const SizedBox(height: 12),

            // ── Fill bar ─────────────────────────────────────────────────
            _FillBar(
              fillFraction: clamped,
              color: color,
              warningPct: _warnPctOnBar(alert),
            ),
            const SizedBox(height: 6),

            // ── Threshold labels ──────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _ThreshLabel(
                  icon: Icons.warning_amber_rounded,
                  color: AlertLevel.warning.color,
                  label: 'WL',
                  value:
                      '${_fmtDischarge(alert.warningLevel)} ${alert.unitLabel}',
                ),
                _ThreshLabel(
                  icon: Icons.dangerous_outlined,
                  color: AlertLevel.danger.color,
                  label: 'DL',
                  value:
                      '${_fmtDischarge(alert.dangerLevel)} ${alert.unitLabel}',
                ),
                if (alert.hfl > 0)
                  _ThreshLabel(
                    icon: Icons.crisis_alert,
                    color: AlertLevel.extreme.color,
                    label: 'HFL',
                    value:
                        '${_fmtDischarge(alert.hfl)} ${alert.unitLabel}',
                  ),
                // Trend arrow
                Row(
                  children: [
                    Icon(
                      alert.trend.icon,
                      color: alert.trend.color,
                      size: 20,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      alert.trend.name,
                      style: TextStyle(
                        fontSize: 10,
                        color: alert.trend.color,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 10),

            // ── Metric row ───────────────────────────────────────────────
            IntrinsicHeight(
              child: Row(
                children: [
                  _MetricTile(
                    label: isDischarge ? 'Discharge' : 'Level',
                    value: '${_fmtDischarge(alert.currentValue)} ${alert.unitLabel}',
                    color: color,
                    flex: 2,
                  ),
                  VerticalDivider(
                    width: 1,
                    color: theme.dividerColor,
                  ),
                  _MetricTile(
                    label: 'vs Danger',
                    value: _breachText(alert),
                    color: alert.breachMargin >= 0
                        ? AlertLevel.danger.color
                        : const Color(0xFF4CAF50),
                    flex: 2,
                  ),
                  if (hasGauge) ...[
                    VerticalDivider(
                      width: 1,
                      color: theme.dividerColor,
                    ),
                    _MetricTile(
                      label: 'Gauge (m)',
                      value: liveData!.currentLevel.toStringAsFixed(2),
                      color: theme.colorScheme.onSurface
                          .withValues(alpha: 0.7),
                      flex: 2,
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 8),
            // ── Footer ───────────────────────────────────────────────────
            Row(
              children: [
                Icon(
                  Icons.access_time_rounded,
                  size: 12,
                  color: theme.colorScheme.onSurface
                      .withValues(alpha: 0.4),
                ),
                const SizedBox(width: 4),
                Text(
                  ts,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurface
                        .withValues(alpha: 0.45),
                  ),
                ),
                if (liveData?.imdSeverity != null) ...[
                  const Spacer(),
                  _ImdSeverityChip(severity: liveData!.imdSeverity!),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _breachText(ThresholdAlert a) {
    final sign  = a.breachMargin >= 0 ? '+' : '';
    final value = a.breachMargin.abs() < 1000
        ? '$sign${a.breachMargin.toStringAsFixed(1)}'
        : '$sign${_fmtDischarge(a.breachMargin)}';
    return '$value ${a.unitLabel}';
  }

  /// Position of warning level as fraction of [0, dangerLevel].
  double _warnPctOnBar(ThresholdAlert a) {
    if (a.dangerLevel <= 0) return 0.7;
    return (a.warningLevel / a.dangerLevel).clamp(0.0, 1.0);
  }
}

// ── Fill bar with warning marker ──────────────────────────────────────────────

class _FillBar extends StatelessWidget {
  final double fillFraction;   // 0–1
  final double warningPct;     // 0–1 position of warning tick
  final Color  color;
  const _FillBar({
    required this.fillFraction,
    required this.warningPct,
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
            // Background track
            ClipRRect(
              borderRadius: BorderRadius.circular(7),
              child: LinearProgressIndicator(
                value: fillFraction,
                backgroundColor: color.withValues(alpha: 0.12),
                valueColor: AlwaysStoppedAnimation<Color>(color),
                minHeight: 14,
              ),
            ),
            // Warning tick mark
            Positioned(
              left: (warningPct * w).clamp(0.0, w) - 1.5,
              top: 2, bottom: 2,
              child: Container(
                width: 3,
                decoration: BoxDecoration(
                  color: AlertLevel.warning.color,
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
// Tab 2 — IMD SACHET Weather Alerts
// ─────────────────────────────────────────────────────────────────────────────

class _ImdTab extends StatelessWidget {
  final List<ImdAlert> alerts;
  final bool loading;
  final Future<void> Function() onRefresh;

  const _ImdTab({
    required this.alerts,
    required this.loading,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    if (alerts.isEmpty) {
      return _EmptyState(
        loading: loading,
        icon: Icons.wb_sunny_rounded,
        message: 'No active IMD weather alerts',
        sub: 'SACHET / NDMA feeds are clear at this time.',
      );
    }

    // Group by severity
    final groups = <ImdSeverity, List<ImdAlert>>{};
    for (final sev in [
      ImdSeverity.red,
      ImdSeverity.orange,
      ImdSeverity.yellow,
      ImdSeverity.green,
      ImdSeverity.unknown,
    ]) {
      final items = alerts.where((a) => a.severity == sev).toList();
      if (items.isNotEmpty) groups[sev] = items;
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          for (final entry in groups.entries) ...[
            // Severity section header
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: Row(
                  children: [
                    Icon(
                      entry.key.icon,
                      color: entry.key.color,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      entry.key.label.toUpperCase(),
                      style: TextStyle(
                        color: entry.key.color,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: entry.key.color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${entry.value.length}',
                        style: TextStyle(
                          color: entry.key.color,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (ctx, i) => Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: _ImdCard(alert: entry.value[i]),
                ),
                childCount: entry.value.length,
              ),
            ),
          ],
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
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
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: color.withValues(alpha: 0.6), width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(alert.severity.icon, color: color, size: 20),
                ),
                const SizedBox(width: 10),
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
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border:
                        Border.all(color: color.withValues(alpha: 0.55)),
                  ),
                  child: Text(
                    alert.severity.label.toUpperCase(),
                    style: TextStyle(
                      color: color,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (alert.isNew) ...[
                  const SizedBox(width: 6),
                  _NewBadge(color: color),
                ],
              ],
            ),

            // Event chip
            if (alert.event.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  _Chip(
                    label: alert.event,
                    bg: theme.colorScheme.surfaceContainerHighest,
                    textColor: theme.colorScheme.onSurface
                        .withValues(alpha: 0.8),
                    icon: Icons.bolt_rounded,
                  ),
                  if (alert.state.isNotEmpty)
                    _Chip(
                      label: alert.state,
                      bg: theme.colorScheme.surfaceContainerHighest,
                      textColor: theme.colorScheme.onSurface
                          .withValues(alpha: 0.8),
                      icon: Icons.location_on_rounded,
                    ),
                ],
              ),
            ],

            // Area
            if (alert.area.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.pin_drop_outlined,
                    size: 13,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      alert.area,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.65),
                      ),
                    ),
                  ),
                ],
              ),
            ],

            // Description
            if (alert.description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                alert.description,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface
                      .withValues(alpha: 0.75),
                ),
              ),
            ],

            // Validity window
            if (alert.effective != null || alert.expires != null) ...[
              const SizedBox(height: 8),
              _ValidityRow(
                effective: alert.effective,
                expires: alert.expires,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ValidityRow extends StatelessWidget {
  final DateTime? effective;
  final DateTime? expires;
  const _ValidityRow({this.effective, this.expires});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now   = DateTime.now();
    final isActive = expires == null || expires!.isAfter(now);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            isActive
                ? Icons.schedule_rounded
                : Icons.timer_off_outlined,
            size: 13,
            color: isActive
                ? const Color(0xFF34C759)
                : theme.colorScheme.onSurface.withValues(alpha: 0.4),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              _buildText(),
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _buildText() {
    if (effective != null && expires != null) {
      return '${_fmtDate(effective!)}  →  ${_fmtDate(expires!)}';
    }
    if (effective != null) return 'From: ${_fmtDate(effective!)}';
    if (expires   != null) return 'Until: ${_fmtDate(expires!)}';
    return '';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared small widgets
// ─────────────────────────────────────────────────────────────────────────────

class _TabLabel extends StatelessWidget {
  final IconData icon;
  final String   label;
  final int      badgeCount;
  final Color?   badgeColor;
  const _TabLabel({
    required this.icon,
    required this.label,
    required this.badgeCount,
    this.badgeColor,
  });

  @override
  Widget build(BuildContext context) {
    return Tab(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15),
          const SizedBox(width: 5),
          Text(label, style: const TextStyle(fontSize: 13)),
          if (badgeCount > 0 && badgeColor != null) ...[
            const SizedBox(width: 5),
            _Badge(count: badgeCount, color: badgeColor!),
          ],
        ],
      ),
    );
  }
}

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
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _LevelBadge extends StatelessWidget {
  final AlertLevel level;
  const _LevelBadge({required this.level});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: level.color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: level.color.withValues(alpha: 0.55)),
      ),
      child: Text(
        level.label.toUpperCase(),
        style: TextStyle(
          color: level.color,
          fontSize: 9,
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
        color: color,
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Text(
        'NEW',
        style: TextStyle(
          color: Colors.white,
          fontSize: 9,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _ThreshLabel extends StatelessWidget {
  final IconData icon;
  final Color    color;
  final String   label;
  final String   value;
  const _ThreshLabel({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 11, color: color),
        const SizedBox(width: 3),
        Text(
          '$label: $value',
          style: TextStyle(
            fontSize: 10,
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _MetricTile extends StatelessWidget {
  final String label;
  final String value;
  final Color  color;
  final int    flex;
  const _MetricTile({
    required this.label,
    required this.value,
    required this.color,
    this.flex = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 9,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.5),
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String   label;
  final Color    bg;
  final Color    textColor;
  final IconData icon;
  const _Chip({
    required this.label,
    required this.bg,
    required this.textColor,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: textColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: textColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ImdSeverityChip extends StatelessWidget {
  final String severity;
  const _ImdSeverityChip({required this.severity});

  Color _color() {
    switch (severity.toUpperCase()) {
      case 'RED':    return const Color(0xFFF44336);
      case 'ORANGE': return const Color(0xFFF97316);
      case 'YELLOW': return const Color(0xFFEAB308);
      default:       return const Color(0xFF34C759);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _color();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: c.withValues(alpha: 0.5)),
      ),
      child: Text(
        'IMD ${severity.toUpperCase()}',
        style: TextStyle(
          color: c,
          fontSize: 9,
          fontWeight: FontWeight.w700,
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
        color: AlertLevel.danger.color.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.crisis_alert, color: Colors.white, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$count station${count > 1 ? 's' : ''} at or above Danger discharge',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13,
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
  final bool    loading;
  final IconData icon;
  final String  message;
  final String  sub;
  const _EmptyState({
    required this.loading,
    required this.icon,
    required this.message,
    required this.sub,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }
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
              child: Icon(
                icon,
                size: 40,
                color: theme.colorScheme.primary.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              sub,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            const Text(
              'Pull down to refresh',
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Filter menu ────────────────────────────────────────────────────────────────

class _FilterMenu extends StatelessWidget {
  final AlertsProvider provider;
  const _FilterMenu({required this.provider});

  @override
  Widget build(BuildContext context) {
    final hasFilter = provider.filterLevel != null ||
        provider.filterState != null;
    return PopupMenuButton<String>(
      icon: Icon(
        Icons.filter_list_rounded,
        color: hasFilter ? Theme.of(context).colorScheme.primary : null,
      ),
      tooltip: 'Filter alerts',
      onSelected: (val) {
        if (val == 'clear') {
          provider.clearFilters();
          return;
        }
        final level = AlertLevel.values
            .where((l) => l.name == val)
            .firstOrNull;
        if (level != null) provider.setFilterLevel(level);
      },
      itemBuilder: (_) => [
        const PopupMenuItem(
          value: 'clear',
          child: Row(
            children: [
              Icon(Icons.clear_all_rounded, size: 18),
              SizedBox(width: 8),
              Text('Clear filters'),
            ],
          ),
        ),
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
        const PopupMenuDivider(),
        ...AlertLevel.values
            .where((l) => l == AlertLevel.normal)
            .map((l) => PopupMenuItem(
                  value: l.name,
                  child: Row(
                    children: [
                      Icon(l.icon, color: l.color, size: 18),
                      const SizedBox(width: 8),
                      const Text('Show Normal (all)'),
                    ],
                  ),
                )),
      ],
    );
  }
}
