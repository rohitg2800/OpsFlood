// lib/screens/alerts_screen.dart  v4.2 — overflow fix in _StatusBar
//
// v4.1 adds:  static const route = '/alerts'  (required by main.dart router)
// v4.2 fixes: RenderFlex overflow in _StatusBar (row of source chips)
//
// Reads alertsProvider (via data_fetch_provider) which is rebuilt automatically
// on every DataFetchEngine tick (every 45 s).
//
// Features:
//   • static const route = '/alerts'
//   • Animated badge on AppBar showing live alert count
//   • Filter chips: All / Emergency / Critical / Warning / Info
//   • Alert cards: colour-coded, expandable, with level progress bar
//   • Pull-to-refresh forces DataFetchEngine.forceRefresh()
//   • "No alerts" empty state with last-updated timestamp
//   • Source health row at bottom (CWC / WRD / GloFAS) — horizontally
//     scrollable so it never overflows on small screens
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../providers/data_fetch_provider.dart';
import '../services/alert_engine.dart';
import '../services/data_fetch_engine.dart';

// ── colour helpers ────────────────────────────────────────────────────────────
Color _severityColor(AlertSeverity s, {bool dark = false}) {
  switch (s) {
    case AlertSeverity.emergency: return dark ? const Color(0xFF8B0000) : const Color(0xFFB71C1C);
    case AlertSeverity.critical:  return dark ? const Color(0xFFBF360C) : const Color(0xFFE64A19);
    case AlertSeverity.warning:   return dark ? const Color(0xFFF57F17) : const Color(0xFFF9A825);
    case AlertSeverity.info:      return dark ? const Color(0xFF1565C0) : const Color(0xFF1976D2);
  }
}

Color _severityBg(AlertSeverity s) {
  switch (s) {
    case AlertSeverity.emergency: return const Color(0xFFFFEBEE);
    case AlertSeverity.critical:  return const Color(0xFFFBE9E7);
    case AlertSeverity.warning:   return const Color(0xFFFFFDE7);
    case AlertSeverity.info:      return const Color(0xFFE3F2FD);
  }
}

IconData _severityIcon(AlertSeverity s) {
  switch (s) {
    case AlertSeverity.emergency: return Icons.warning_amber_rounded;
    case AlertSeverity.critical:  return Icons.crisis_alert_rounded;
    case AlertSeverity.warning:   return Icons.notifications_active_rounded;
    case AlertSeverity.info:      return Icons.info_outline_rounded;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AlertsScreen
// ─────────────────────────────────────────────────────────────────────────────
class AlertsScreen extends ConsumerStatefulWidget {
  // ← route const required by main.dart router
  static const String route = '/alerts';

  const AlertsScreen({super.key});

  @override
  ConsumerState<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends ConsumerState<AlertsScreen>
    with TickerProviderStateMixin {
  AlertSeverity? _filter;
  late AnimationController _badgeCtrl;
  late Animation<double>   _badgePulse;
  int _prevCount = 0;

  @override
  void initState() {
    super.initState();
    _badgeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _badgePulse = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(parent: _badgeCtrl, curve: Curves.elasticOut),
    );
  }

  @override
  void dispose() {
    _badgeCtrl.dispose();
    super.dispose();
  }

  List<FloodAlert> _filtered(List<FloodAlert> all) {
    if (_filter == null) return all;
    return all.where((a) => a.severity == _filter).toList();
  }

  @override
  Widget build(BuildContext context) {
    final allAlerts = ref.watch(alertsProvider);
    final sources   = ref.watch(sourceStatusProvider);
    final fetchSnap = ref.watch(dataFetchProvider);

    if (allAlerts.length > _prevCount) {
      _badgeCtrl.forward(from: 0);
    }
    _prevCount = allAlerts.length;

    final shown     = _filtered(allAlerts);
    final isLoading = fetchSnap.isLoading ||
        fetchSnap.when(
            data: (s) => s.isLoading, loading: () => true, error: (_, __) => false);
    final lastUpdate = fetchSnap.when(
      data:    (s) => s.fetchedAt,
      loading: ()  => null,
      error:   (_, __) => null,
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: _buildAppBar(allAlerts.length, isLoading),
      body: RefreshIndicator(
        onRefresh: () => DataFetchEngine.instance.forceRefresh(),
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
                child: _StatusBar(sources: sources, lastUpdate: lastUpdate)),
            SliverToBoxAdapter(
                child: _FilterRow(
              selected:  _filter,
              all:       allAlerts,
              onChanged: (v) => setState(() => _filter = v),
            )),
            if (isLoading && allAlerts.isEmpty)
              const SliverFillRemaining(child: _LoadingState())
            else if (shown.isEmpty)
              SliverFillRemaining(child: _EmptyState(lastUpdate: lastUpdate))
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) {
                    if (i == shown.length) return const SizedBox(height: 24);
                    return _AlertCard(alert: shown[i]);
                  },
                  childCount: shown.length + 1,
                ),
              ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(int count, bool loading) {
    return AppBar(
      elevation: 0,
      backgroundColor: const Color(0xFF0D47A1),
      foregroundColor: Colors.white,
      title: const Text('Flood Alerts',
          style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.5)),
      actions: [
        if (loading)
          const Padding(
            padding: EdgeInsets.all(16),
            child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2)),
          )
        else
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: ScaleTransition(
              scale: _badgePulse,
              child: _AlertBadge(count: count),
            ),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _AlertBadge
// ─────────────────────────────────────────────────────────────────────────────
class _AlertBadge extends StatelessWidget {
  final int count;
  const _AlertBadge({required this.count});
  @override
  Widget build(BuildContext context) {
    if (count == 0) return const Icon(Icons.notifications_none_rounded);
    return Stack(
      alignment: Alignment.center,
      children: [
        const Icon(Icons.notifications_active_rounded),
        Positioned(
          top: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.all(3),
            decoration:
                const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
            child: Text('$count',
                style: const TextStyle(
                    fontSize: 9,
                    color: Colors.white,
                    fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _StatusBar  — FIX v4.2
//
// OLD: single Row[ ...chips, Spacer(), timestamp ]
//      → overflows when 4-5 chips fill 379px constraint
//
// NEW: Column[
//        Align(right) → timestamp          ← never overflows, always fits
//        SingleChildScrollView(horizontal) → chips  ← scrolls, never wraps
//      ]
// ─────────────────────────────────────────────────────────────────────────────
class _StatusBar extends StatelessWidget {
  final List<SourceStatus> sources;
  final DateTime?          lastUpdate;
  const _StatusBar({required this.sources, this.lastUpdate});

  @override
  Widget build(BuildContext context) {
    final fmt =
        lastUpdate != null ? DateFormat('HH:mm:ss').format(lastUpdate!) : '—';

    // Filter out seed-only sources from display unless all are seeds
    final display = sources.where((s) => !s.isFromSeed).toList();
    final chips   = (display.isEmpty ? sources : display)
        .map((s) => _SourceChip(
              name:        s.name,
              healthy:     s.healthy,
              count:       s.stationCount,
              isFromSeed:  s.isFromSeed,
            ))
        .toList();

    return Container(
      color: const Color(0xFF0D47A1),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── timestamp row — right-aligned, never overflows ──────────────
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              'Updated $fmt',
              style: const TextStyle(color: Colors.white70, fontSize: 10),
            ),
          ),
          const SizedBox(height: 4),
          // ── chip strip — horizontally scrollable, never overflows ───────
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: chips,
            ),
          ),
        ],
      ),
    );
  }
}

class _SourceChip extends StatelessWidget {
  final String name;
  final bool   healthy;
  final int    count;
  final bool   isFromSeed;
  const _SourceChip({
    required this.name,
    required this.healthy,
    required this.count,
    this.isFromSeed = false,
  });
  @override
  Widget build(BuildContext context) {
    // Seed chips shown with a muted grey style so they're visually distinct
    // from live-source chips — users can immediately tell what's real data.
    final borderColor = isFromSeed
        ? Colors.white38
        : (healthy ? Colors.greenAccent : Colors.redAccent);
    final bgColor = isFromSeed
        ? Colors.white.withOpacity(0.08)
        : (healthy
            ? Colors.green.withOpacity(0.25)
            : Colors.red.withOpacity(0.25));
    final iconColor = isFromSeed
        ? Colors.white38
        : (healthy ? Colors.greenAccent : Colors.redAccent);
    final icon = isFromSeed
        ? Icons.circle_outlined
        : (healthy ? Icons.check_circle : Icons.error);

    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color:        bgColor,
        borderRadius: BorderRadius.circular(12),
        border:       Border.all(color: borderColor, width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: iconColor),
          const SizedBox(width: 4),
          Text(
            '$name${count > 0 ? " $count" : ""}',
            style: TextStyle(
              color:    isFromSeed ? Colors.white54 : Colors.white,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _FilterRow
// ─────────────────────────────────────────────────────────────────────────────
class _FilterRow extends StatelessWidget {
  final AlertSeverity?               selected;
  final List<FloodAlert>             all;
  final ValueChanged<AlertSeverity?> onChanged;
  const _FilterRow(
      {required this.selected,
      required this.all,
      required this.onChanged});

  int _count(AlertSeverity? s) {
    if (s == null) return all.length;
    return all.where((a) => a.severity == s).length;
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        children: [
          _Chip(
              label:    'All (${_count(null)})',
              selected: selected == null,
              onTap:    () => onChanged(null)),
          _Chip(
              label:    '🔴 Emergency (${_count(AlertSeverity.emergency)})',
              selected: selected == AlertSeverity.emergency,
              color:    const Color(0xFFB71C1C),
              onTap:    () => onChanged(AlertSeverity.emergency)),
          _Chip(
              label:    '🚨 Critical (${_count(AlertSeverity.critical)})',
              selected: selected == AlertSeverity.critical,
              color:    const Color(0xFFE64A19),
              onTap:    () => onChanged(AlertSeverity.critical)),
          _Chip(
              label:    '⚠️ Warning (${_count(AlertSeverity.warning)})',
              selected: selected == AlertSeverity.warning,
              color:    const Color(0xFFF9A825),
              onTap:    () => onChanged(AlertSeverity.warning)),
          _Chip(
              label:    'ℹ️ Info (${_count(AlertSeverity.info)})',
              selected: selected == AlertSeverity.info,
              color:    const Color(0xFF1976D2),
              onTap:    () => onChanged(AlertSeverity.info)),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String     label;
  final bool       selected;
  final Color?     color;
  final VoidCallback onTap;
  const _Chip(
      {required this.label,
      required this.selected,
      required this.onTap,
      this.color});
  @override
  Widget build(BuildContext context) {
    final c = color ?? const Color(0xFF0D47A1);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(right: 8),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? c : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: c),
          boxShadow: selected
              ? [
                  BoxShadow(
                      color:  c.withOpacity(0.3),
                      blurRadius: 6,
                      offset: const Offset(0, 2))
                ]
              : null,
        ),
        child: Text(label,
            style: TextStyle(
                color:      selected ? Colors.white : c,
                fontSize:   12,
                fontWeight: FontWeight.w600)),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _AlertCard
// ─────────────────────────────────────────────────────────────────────────────
class _AlertCard extends StatefulWidget {
  final FloodAlert alert;
  const _AlertCard({required this.alert});
  @override
  State<_AlertCard> createState() => _AlertCardState();
}

class _AlertCardState extends State<_AlertCard>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;
  late AnimationController _ctrl;
  late Animation<double>   _rotate;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 250));
    _rotate = Tween<double>(begin: 0, end: 0.5).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _expanded = !_expanded);
    _expanded ? _ctrl.forward() : _ctrl.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final a  = widget.alert;
    final bg = _severityBg(a.severity);
    final fg = _severityColor(a.severity);

    return Card(
      margin:    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      elevation: 2,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Column(
          children: [
            Container(height: 4, color: fg),
            InkWell(
              onTap: _toggle,
              child: Container(
                color:   bg,
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: fg.withOpacity(0.15),
                      child:
                          Icon(_severityIcon(a.severity), color: fg, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                        child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          _SeverityBadge(severity: a.severity),
                          const SizedBox(width: 6),
                          Expanded(
                              child: Text(a.title,
                                  style: TextStyle(
                                      fontSize:   13,
                                      fontWeight: FontWeight.w700,
                                      color:      fg),
                                  maxLines:  2,
                                  overflow:  TextOverflow.ellipsis)),
                        ]),
                        const SizedBox(height: 4),
                        Text('${a.river} · ${a.district}',
                            style: const TextStyle(
                                fontSize: 11, color: Colors.black54)),
                        const SizedBox(height: 4),
                        if (a.thresholdLevel > 0)
                          _LevelBar(
                            current:   a.currentLevel,
                            threshold: a.thresholdLevel,
                            color:     fg,
                          ),
                      ],
                    )),
                    RotationTransition(
                      turns: _rotate,
                      child: Icon(Icons.expand_more_rounded, color: fg),
                    ),
                  ],
                ),
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 250),
              curve:    Curves.easeInOut,
              child: _expanded
                  ? _ExpandedBody(alert: a, fg: fg)
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

class _SeverityBadge extends StatelessWidget {
  final AlertSeverity severity;
  const _SeverityBadge({required this.severity});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding:    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
          color:        _severityColor(severity),
          borderRadius: BorderRadius.circular(4)),
      child: Text(severity.label,
          style: const TextStyle(
              color:      Colors.white,
              fontSize:   9,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5)),
    );
  }
}

class _LevelBar extends StatelessWidget {
  final double current;
  final double threshold;
  final Color  color;
  const _LevelBar(
      {required this.current,
      required this.threshold,
      required this.color});
  @override
  Widget build(BuildContext context) {
    final pct = threshold > 0
        ? (current / threshold).clamp(0.0, 1.5)
        : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value:           pct.clamp(0.0, 1.0),
            minHeight:       6,
            backgroundColor: Colors.black12,
            valueColor:      AlwaysStoppedAnimation(color),
          ),
        ),
        const SizedBox(height: 2),
        Text(
            '${current.toStringAsFixed(2)} m / '
            'threshold ${threshold.toStringAsFixed(2)} m '
            '(${(pct * 100).toStringAsFixed(0)}%)',
            style: const TextStyle(fontSize: 10, color: Colors.black54)),
      ],
    );
  }
}

class _ExpandedBody extends StatelessWidget {
  final FloodAlert alert;
  final Color      fg;
  const _ExpandedBody({required this.alert, required this.fg});
  @override
  Widget build(BuildContext context) {
    final a      = alert;
    final issued = DateFormat('dd MMM HH:mm').format(a.issuedAt);
    final exp    = a.expiresAt != null
        ? DateFormat('dd MMM HH:mm').format(a.expiresAt!)
        : 'No expiry';
    return Container(
      color:   Colors.white,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(a.body,
              style: const TextStyle(
                  fontSize: 13, height: 1.5, color: Colors.black87)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color:        fg.withOpacity(0.07),
              borderRadius: BorderRadius.circular(8),
              border:       Border.all(color: fg.withOpacity(0.3)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.tips_and_updates_rounded, color: fg, size: 18),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(a.action,
                        style: TextStyle(
                            fontSize:   12,
                            color:      fg,
                            fontWeight: FontWeight.w600,
                            height:     1.4))),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(children: [
            const Icon(Icons.schedule_rounded,
                size: 12, color: Colors.black38),
            const SizedBox(width: 4),
            Flexible(
              child: Text('Issued $issued  ·  Expires $exp',
                  style: const TextStyle(fontSize: 10, color: Colors.black45),
                  overflow: TextOverflow.ellipsis),
            ),
            const SizedBox(width: 4),
            if (a.rateOfRiseMph != null)
              _MetaTag(
                  icon: Icons.trending_up,
                  text: '${a.rateOfRiseMph!.toStringAsFixed(2)} m/h'),
            if (a.rainfall24hMm != null)
              _MetaTag(
                  icon: Icons.water_drop,
                  text: '${a.rainfall24hMm!.toStringAsFixed(0)} mm'),
          ]),
        ],
      ),
    );
  }
}

class _MetaTag extends StatelessWidget {
  final IconData icon;
  final String   text;
  const _MetaTag({required this.icon, required this.text});
  @override
  Widget build(BuildContext context) {
    return Container(
      margin:  const EdgeInsets.only(left: 6),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
          color:        Colors.grey.shade100,
          borderRadius: BorderRadius.circular(4)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 10, color: Colors.black54),
        const SizedBox(width: 3),
        Text(text,
            style: const TextStyle(fontSize: 10, color: Colors.black54)),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _EmptyState / _LoadingState
// ─────────────────────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final DateTime? lastUpdate;
  const _EmptyState({this.lastUpdate});
  @override
  Widget build(BuildContext context) {
    final t = lastUpdate != null
        ? DateFormat('HH:mm:ss dd MMM').format(lastUpdate!)
        : '—';
    return Center(
        child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
          const Icon(Icons.check_circle_outline_rounded,
              size: 72, color: Colors.green),
          const SizedBox(height: 16),
          const Text('No Active Alerts',
              style: TextStyle(
                  fontSize:   20,
                  fontWeight: FontWeight.w700,
                  color:      Colors.black87)),
          const SizedBox(height: 8),
          const Text('All monitored stations are within safe levels.',
              style: TextStyle(color: Colors.black45)),
          const SizedBox(height: 16),
          Text('Last checked: $t',
              style: const TextStyle(fontSize: 11, color: Colors.black38)),
        ]));
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();
  @override
  Widget build(BuildContext context) {
    return const Center(
        child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
          CircularProgressIndicator(strokeWidth: 2),
          SizedBox(height: 16),
          Text('Fetching live data…',
              style: TextStyle(color: Colors.black54)),
        ]));
  }
}
