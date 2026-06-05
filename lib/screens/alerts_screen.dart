// lib/screens/alerts_screen.dart  v3
// Phase 4 upgrade:
//  - TabBar: ALL | IMD | NDMA tabs with live count badges
//  - Severity sort: CRITICAL → HIGH → MODERATE → LOW (stable)
//  - Each card has a "→ City Detail" CTA when alert.city is present
//  - Pull-to-refresh calls realTimeProvider.refreshData()
//  - Animated empty-state for clean tab experience
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../l10n/context_l10n.dart';
import '../providers/flood_providers.dart';
import '../screens/city_detail_screen.dart';
import '../theme/river_theme.dart';

// ── severity sort order ───────────────────────────────────────────────────────
int _severityRank(dynamic raw) {
  final sev = (_field(raw, 'severity') +
      _field(raw, 'alert_level'))
      .toLowerCase();
  if (sev.contains('extreme') || sev.contains('critical') ||
      sev.contains('red'))    return 0;
  if (sev.contains('severe')  || sev.contains('orange') ||
      sev.contains('high'))   return 1;
  if (sev.contains('moderate') || sev.contains('yellow') ||
      sev.contains('medium'))  return 2;
  return 3;
}

String _field(dynamic raw, String key, [String fallback = '']) {
  try {
    final val = (raw as dynamic)[key];
    return val?.toString().isNotEmpty == true ? val.toString() : fallback;
  } catch (_) { return fallback; }
}

Color _severityColor(dynamic raw) {
  final rank = _severityRank(raw);
  if (rank == 0) return AppPalette.critical;
  if (rank == 1) return AppPalette.danger;
  if (rank == 2) return AppPalette.amber;
  return AppPalette.safe;
}

// ─────────────────────────────────────────────────────────────────────────────

class AlertsScreen extends ConsumerStatefulWidget {
  static const route = '/alerts';
  const AlertsScreen({super.key});

  @override
  ConsumerState<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends ConsumerState<AlertsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    try {
      await ref.read(realTimeProvider).refreshData();
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s          = context.l10n;
    final imd        = ref.watch(imdAlertsProvider);
    final ndma       = ref.watch(ndmaAdvisoriesProvider);
    final all        = [...imd, ...ndma]
      ..sort((a, b) => _severityRank(a) - _severityRank(b));
    final imdSorted  = [...imd]
      ..sort((a, b) => _severityRank(a) - _severityRank(b));
    final ndmaSorted = [...ndma]
      ..sort((a, b) => _severityRank(a) - _severityRank(b));

    final criticalCount = all
        .where((a) => _severityRank(a) == 0)
        .length;

    return Scaffold(
      backgroundColor: AppPalette.abyss0,
      body: NestedScrollView(
        headerSliverBuilder: (ctx, _) => [
          SliverAppBar(
            pinned: true,
            backgroundColor: AppPalette.abyss0,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            title: Row(
              children: [
                Text(
                  s.floodAlerts,
                  style: const TextStyle(
                    color: AppPalette.textWhite,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (criticalCount > 0) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppPalette.critical.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: AppPalette.critical.withValues(alpha: 0.5)),
                    ),
                    child: Text(
                      '$criticalCount CRITICAL',
                      style: const TextStyle(
                          color: AppPalette.critical,
                          fontSize: 9,
                          fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ],
            ),
            actions: [
              IconButton(
                icon: _refreshing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppPalette.cyan))
                    : const Icon(Icons.refresh_rounded,
                        color: AppPalette.textGrey, size: 20),
                onPressed: _refresh,
              ),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(48),
              child: TabBar(
                controller: _tab,
                labelColor: AppPalette.cyan,
                unselectedLabelColor: AppPalette.textGrey,
                indicatorColor: AppPalette.cyan,
                indicatorWeight: 2,
                labelStyle: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w700),
                tabs: [
                  _CountTab('ALL', all.length),
                  _CountTab('IMD', imd.length),
                  _CountTab('NDMA', ndma.length),
                ],
              ),
            ),
          ),
        ],
        body: TabBarView(
          controller: _tab,
          children: [
            _AlertList(alerts: all,        onRefresh: _refresh),
            _AlertList(alerts: imdSorted,  onRefresh: _refresh),
            _AlertList(alerts: ndmaSorted, onRefresh: _refresh),
          ],
        ),
      ),
    );
  }
}

// ── tab label with count pill ─────────────────────────────────────────────────

class _CountTab extends StatelessWidget {
  final String label;
  final int    count;
  const _CountTab(this.label, this.count);

  @override
  Widget build(BuildContext context) => Tab(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label),
            if (count > 0) ...[
              const SizedBox(width: 5),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: AppPalette.cyan.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('$count',
                    style: const TextStyle(
                        fontSize: 9,
                        color: AppPalette.cyan,
                        fontWeight: FontWeight.w800)),
              ),
            ],
          ],
        ),
      );
}

// ── scrollable alert list per tab ─────────────────────────────────────────────

class _AlertList extends StatelessWidget {
  final List<dynamic>       alerts;
  final Future<void> Function() onRefresh;
  const _AlertList({required this.alerts, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    if (alerts.isEmpty) {
      return const _EmptyAlerts();
    }
    return RefreshIndicator(
      color: AppPalette.cyan,
      backgroundColor: AppPalette.abyss2,
      onRefresh: onRefresh,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics()),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
        itemCount: alerts.length,
        itemBuilder: (_, i) => _AlertCard(raw: alerts[i]),
      ),
    );
  }
}

// ─── Alert Card v3 ───────────────────────────────────────────────────────────

class _AlertCard extends StatelessWidget {
  final dynamic raw;
  const _AlertCard({required this.raw});

  @override
  Widget build(BuildContext context) {
    final col    = _severityColor(raw);
    final title  = _orElse(raw, ['title', 'headline'], 'Alert');
    final desc   = _orElse(raw, ['description', 'message', 'advisory'], '');
    final source = _orElse(raw, ['source', 'agency'], '');
    final area   = _orElse(raw, ['area', 'district', 'region'], '');
    final city   = _field(raw, 'city');
    final rawDate = _orElse(raw, ['issued_at', 'date', 'timestamp'], '');
    final sevLabel = _orElse(
        raw, ['severity', 'alert_level'], '').toUpperCase();

    String dateStr = '';
    if (rawDate.isNotEmpty) {
      try {
        final dt = DateTime.tryParse(rawDate);
        dateStr = dt != null
            ? DateFormat('dd MMM · HH:mm').format(dt.toLocal())
            : rawDate;
      } catch (_) { dateStr = rawDate; }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppPalette.abyss2,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: col.withValues(alpha: 0.28)),
        boxShadow: [
          BoxShadow(
              color: col.withValues(alpha: 0.07),
              blurRadius: 14,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          // ── main content ──────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // severity icon circle
                    Container(
                      width: 38, height: 38,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: col.withValues(alpha: 0.12),
                        border:
                            Border.all(color: col.withValues(alpha: 0.32)),
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
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                height: 1.3,
                              )),
                          if (area.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                const Icon(Icons.location_on_rounded,
                                    color: AppPalette.textDim, size: 10),
                                const SizedBox(width: 3),
                                Text(area,
                                    style: const TextStyle(
                                        color: AppPalette.textGrey,
                                        fontSize: 10)),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    // severity badge + date stacked
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (sevLabel.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: col.withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: col.withValues(alpha: 0.5)),
                            ),
                            child: Text(sevLabel,
                                style: TextStyle(
                                    color: col,
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.w800)),
                          ),
                        if (dateStr.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(dateStr,
                              style: const TextStyle(
                                  color: AppPalette.textDim,
                                  fontSize: 8.5)),
                        ],
                      ],
                    ),
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
                            fontSize: 11,
                            height: 1.5)),
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
                            fontSize: 9.5,
                            fontWeight: FontWeight.w600)),
                  ]),
                ],
              ],
            ),
          ),
          // ── city drill-through CTA ────────────────────────────────────
          if (city.isNotEmpty)
            InkWell(
              onTap: () => Navigator.pushNamed(
                context,
                CityDetailScreen.route,
                arguments: city,
              ),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 9),
                decoration: BoxDecoration(
                  color: col.withValues(alpha: 0.06),
                  border: Border(
                      top: BorderSide(
                          color: col.withValues(alpha: 0.18))),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.location_city_rounded,
                        color: col, size: 13),
                    const SizedBox(width: 6),
                    Text(
                      'View $city live data  →',
                      style: TextStyle(
                          color: col,
                          fontSize: 11,
                          fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _orElse(
      dynamic raw, List<String> keys, String fallback) {
    for (final k in keys) {
      final v = _field(raw, k);
      if (v.isNotEmpty) return v;
    }
    return fallback;
  }

  IconData _iconFor(Color c) {
    if (c == AppPalette.critical) return Icons.crisis_alert_rounded;
    if (c == AppPalette.danger)   return Icons.warning_rounded;
    if (c == AppPalette.amber)    return Icons.warning_amber_rounded;
    return Icons.info_outline_rounded;
  }
}

// ── empty state ───────────────────────────────────────────────────────────────

class _EmptyAlerts extends StatelessWidget {
  const _EmptyAlerts();

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 76, height: 76,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  AppPalette.safe.withValues(alpha: 0.13),
                  AppPalette.abyss2,
                ]),
                border: Border.all(
                    color: AppPalette.safe.withValues(alpha: 0.22)),
              ),
              child: const Icon(Icons.notifications_off_outlined,
                  color: AppPalette.safe, size: 34),
            ),
            const SizedBox(height: 16),
            Text(
              context.l10n.noAlerts,
              style: const TextStyle(
                  color: AppPalette.textGrey,
                  fontSize: 14,
                  fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            const Text(
              'Pull down to refresh',
              style: TextStyle(
                  color: AppPalette.textDim, fontSize: 11),
            ),
          ],
        ),
      );
}
