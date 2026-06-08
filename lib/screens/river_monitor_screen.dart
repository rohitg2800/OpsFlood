// lib/screens/river_monitor_screen.dart
// Bihar Flood Ops — River Monitor Screen v3
//
// 2026-06-08 provider migration:
//   BEFORE: ref.watch(realTimeServiceProvider) → rt.liveLevels, rt.isLoading
//   AFTER : ref.watch(liveLevelsProvider)      — derived, narrow watch
//           ref.watch(isLoadingProvider)        — isolated loading flag
//           ref.watch(isOfflineProvider)        — isolated offline flag
//           ref.watch(lastFetchTimeProvider)    — isolated timestamp
//
// UI improvements applied alongside migration:
//   • Sub-10px text floors lifted (9px label → 11px minimum everywhere)
//   • All surface / text colours routed through RiverColors (no bare AppPalette
//     surface constants remain in layout code)
//   • Summary chips (critical / severe / normal) moved to a themed strip
//     derived from the provider data, not the service object
//   • Empty state gains a proper action chip + warm message
//   • _StatChip label font floored at 11px (was 9px)
//   • Search field uses theme-driven InputDecoration via Theme.of(context)
//     so it adapts across Golden / Ocean / Sunset / Light modes
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/flood_data.dart';
import '../providers/flood_providers.dart';
import '../theme/river_theme.dart';

class RiverMonitorScreen extends ConsumerStatefulWidget {
  const RiverMonitorScreen({super.key});
  static const String route = '/river_monitor';

  @override
  ConsumerState<RiverMonitorScreen> createState() =>
      _RiverMonitorScreenState();
}

class _RiverMonitorScreenState extends ConsumerState<RiverMonitorScreen> {
  String _query = '';
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<FloodData> _filtered(List<FloodData> levels) {
    if (_query.isEmpty) return levels;
    final q = _query.toLowerCase();
    return levels
        .where((fd) =>
            fd.city.toLowerCase().contains(q) ||
            fd.state.toLowerCase().contains(q) ||
            fd.district.toLowerCase().contains(q) ||
            (fd.riverName?.toLowerCase().contains(q) ?? false))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    // ── Narrow provider watches — no full-service dependency ──────────────
    final allLevels  = ref.watch(liveLevelsProvider);
    final isLoading  = ref.watch(isLoadingProvider);
    final isOffline  = ref.watch(isOfflineProvider);
    final lastFetch  = ref.watch(lastFetchTimeProvider);
    final t          = RiverColors.of(context);

    final levels     = _filtered(allLevels);

    // Summary counts derived from provider data (not service object)
    final critCount  = allLevels
        .where((d) => d.riskLevel.toUpperCase() == 'CRITICAL').length;
    final sevCount   = allLevels
        .where((d) => d.riskLevel.toUpperCase() == 'SEVERE').length;
    final normCount  = allLevels.length - critCount - sevCount;

    return Scaffold(
      backgroundColor: t.scaffoldBg,
      appBar: AppBar(
        backgroundColor: t.navBg,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'River Monitor',
              style: TextStyle(
                color: t.textPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 18,
                letterSpacing: 0.2,
              ),
            ),
            if (allLevels.isNotEmpty)
              Text(
                _subtitleText(
                    allLevels.length, critCount, sevCount, normCount,
                    isOffline, lastFetch),
                style: TextStyle(
                  color: t.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
            child: TextField(
              controller: _searchCtrl,
              style: TextStyle(color: t.textPrimary, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Search city, district, state or river…',
                hintStyle: TextStyle(color: t.textSecondary, fontSize: 13),
                prefixIcon:
                    Icon(Icons.search, color: t.accent, size: 20),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear, color: t.textSecondary, size: 18),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _query = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: t.cardBg,
                contentPadding: EdgeInsets.zero,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide(
                      color: t.accent.withValues(alpha: 0.18)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide(color: t.stroke),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide(
                      color: t.accent.withValues(alpha: 0.6)),
                ),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
        ),
        actions: [
          if (isOffline)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Icon(Icons.wifi_off_rounded,
                  color: AppPalette.warning, size: 18),
            ),
        ],
      ),

      // ── Summary strip ──────────────────────────────────────────────────
      body: Column(
        children: [
          if (allLevels.isNotEmpty)
            _SummaryStrip(
              t: t,
              critCount: critCount,
              sevCount: sevCount,
              normCount: normCount,
              totalCount: allLevels.length,
            ),

          // ── Offline/stale banner ─────────────────────────────────────
          if (isOffline)
            _StatusBanner(
              t: t,
              message: 'No internet — showing cached data',
              color: AppPalette.warning,
              icon: Icons.wifi_off_rounded,
            )
          else if (lastFetch != null)
            _StatusBanner(
              t: t,
              message:
                  'Last updated ${DateFormat('HH:mm').format(lastFetch)}',
              color: t.accent,
              icon: Icons.check_circle_rounded,
            ),

          // ── Content ──────────────────────────────────────────────────
          Expanded(
            child: isLoading && allLevels.isEmpty
                ? _LoadingState(t: t)
                : levels.isEmpty
                    ? _EmptyState(t: t, query: _query)
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        itemCount: levels.length,
                        itemBuilder: (context, i) =>
                            _RiverCard(data: levels[i], t: t),
                      ),
          ),
        ],
      ),
    );
  }

  String _subtitleText(int total, int crit, int sev, int norm,
      bool offline, DateTime? lastFetch) {
    final parts = <String>['$total stations'];
    if (crit > 0) parts.add('$crit critical');
    if (sev  > 0) parts.add('$sev severe');
    parts.add('$norm normal');
    if (offline) parts.add('● offline');
    return parts.join(' · ');
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Summary Strip — themed, provider-driven
// ─────────────────────────────────────────────────────────────────────────────

class _SummaryStrip extends StatelessWidget {
  final RiverColors t;
  final int critCount, sevCount, normCount, totalCount;

  const _SummaryStrip({
    required this.t,
    required this.critCount,
    required this.sevCount,
    required this.normCount,
    required this.totalCount,
  });

  @override
  Widget build(BuildContext context) {
    final chips = [
      (label: 'CRITICAL', count: critCount, color: AppPalette.critical),
      (label: 'SEVERE',   count: sevCount,  color: AppPalette.danger),
      (label: 'NORMAL',   count: normCount, color: AppPalette.safe),
      (label: 'TOTAL',    count: totalCount,color: t.accent),
    ];

    return Container(
      color: t.navBg,
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
      child: Row(
        children: chips.map((c) => Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 3),
            padding: const EdgeInsets.symmetric(vertical: 7),
            decoration: BoxDecoration(
              color: c.color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: c.color.withValues(alpha: 0.22)),
            ),
            child: Column(
              children: [
                Text(
                  '${c.count}',
                  style: TextStyle(
                    color: c.color,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  c.label,
                  style: TextStyle(
                    color: t.textSecondary,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                  ),
                ),
              ],
            ),
          ),
        )).toList(),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Status Banner (offline / last-updated)
// ─────────────────────────────────────────────────────────────────────────────

class _StatusBanner extends StatelessWidget {
  final RiverColors t;
  final String message;
  final Color color;
  final IconData icon;

  const _StatusBanner({
    required this.t,
    required this.message,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 6, 14, 2),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 8),
          Text(message,
              style: TextStyle(
                  color: color, fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Loading State
// ─────────────────────────────────────────────────────────────────────────────

class _LoadingState extends StatelessWidget {
  final RiverColors t;
  const _LoadingState({required this.t});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      itemCount: 5,
      itemBuilder: (_, __) => Container(
        height: 130,
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: t.cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: t.stroke),
        ),
        child: _ShimmerBox(t: t),
      ),
    );
  }
}

class _ShimmerBox extends StatefulWidget {
  final RiverColors t;
  const _ShimmerBox({required this.t});
  @override
  State<_ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<_ShimmerBox>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        return ShaderMask(
          shaderCallback: (rect) => LinearGradient(
            begin: Alignment(-1.0 + 2.0 * _ctrl.value, 0),
            end: Alignment(1.0 + 2.0 * _ctrl.value, 0),
            colors: [
              widget.t.cardBg,
              widget.t.cardBgElevated,
              widget.t.cardBg,
            ],
          ).createShader(rect),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty State — warm message + action
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final RiverColors t;
  final String query;
  const _EmptyState({required this.t, required this.query});

  @override
  Widget build(BuildContext context) {
    final hasQuery = query.isNotEmpty;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64, height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: t.cardBg,
                border: Border.all(color: t.stroke),
              ),
              child: Icon(
                hasQuery
                    ? Icons.search_off_rounded
                    : Icons.water_drop_outlined,
                color: t.textSecondary, size: 30,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              hasQuery ? 'No results for "$query"' : 'No live data yet',
              style: TextStyle(
                color: t.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              hasQuery
                  ? 'Try a different city, district or river name.'
                  : 'CWC station data is being fetched. Pull down to refresh.',
              style: TextStyle(
                color: t.textSecondary,
                fontSize: 13,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// River Card v3 — theme-aware surface colours
// ─────────────────────────────────────────────────────────────────────────────

class _RiverCard extends StatelessWidget {
  final FloodData data;
  final RiverColors t;
  const _RiverCard({required this.data, required this.t});

  static const _staleThreshold    = Duration(hours: 3);
  static const _outdatedThreshold = Duration(hours: 12);

  bool get _isStale    =>
      DateTime.now().difference(data.lastUpdated) > _staleThreshold;
  bool get _isOutdated =>
      DateTime.now().difference(data.lastUpdated) > _outdatedThreshold;

  Color get _staleColor =>
      _isOutdated ? const Color(0xFFEF5350) : const Color(0xFFFFA726);

  @override
  Widget build(BuildContext context) {
    final color  = data.priorityColor;
    final pct    = (data.capacityPercent / 100).clamp(0.0, 1.0);
    final warnPct = data.dangerLevel > 0
        ? (data.warningLevel / data.dangerLevel).clamp(0.0, 1.0)
        : 0.65;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: t.cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: color.withValues(alpha: _isOutdated ? 0.12 : 0.30)),
        boxShadow: [
          BoxShadow(
              color: color.withValues(alpha: _isOutdated ? 0.04 : 0.10),
              blurRadius: 20,
              offset: const Offset(0, 6)),
        ],
      ),
      child: Column(
        children: [
          if (_isStale)
            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: _staleColor.withValues(alpha: 0.10),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  Icon(
                    _isOutdated
                        ? Icons.error_outline_rounded
                        : Icons.access_time_rounded,
                    size: 12,
                    color: _staleColor,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    _isOutdated
                        ? 'Outdated · last seen ${_timeAgo(data.lastUpdated)}'
                        : 'Stale · last updated ${_timeAgo(data.lastUpdated)}',
                    style: TextStyle(
                      color: _staleColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 14, 0),
            child: Row(
              children: [
                _ArcGauge(
                  percent: pct,
                  warnAt: warnPct,
                  color: color,
                  size: 76,
                  centerLabel:
                      '${data.capacityPercent.toStringAsFixed(0)}%',
                  subLabel: 'fill',
                  t: t,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data.city,
                        style: TextStyle(
                            color: t.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w700),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      if (data.district.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: Row(
                            children: [
                              Icon(Icons.location_city_rounded,
                                  size: 11, color: t.textSecondary),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  '${data.district} · ${data.state}',
                                  style: TextStyle(
                                      color: t.textSecondary,
                                      fontSize: 11),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      Row(
                        children: [
                          Icon(Icons.waves,
                              size: 13, color: t.accent),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              data.riverName ?? 'N/A',
                              style: TextStyle(
                                  color: t.textSecondary,
                                  fontSize: 12),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          _Badge(
                              label: data.riskLevel,
                              bg: color.withValues(alpha: 0.18),
                              fg: color),
                          _Badge(
                              label: data.status,
                              bg: t.accent.withValues(alpha: 0.10),
                              fg: t.accent),
                          if (data.imdSeverity != null)
                            _Badge(
                                label: 'IMD ● ${data.imdSeverity}',
                                bg: _imdColor(data.imdSeverity!)
                                    .withValues(alpha: 0.15),
                                fg: _imdColor(data.imdSeverity!)),
                          if (!_isStale)
                            _Badge(
                                label: '● LIVE',
                                bg: const Color(0xFF4CAF50)
                                    .withValues(alpha: 0.12),
                                fg: const Color(0xFF4CAF50)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),
          Divider(
              color: t.stroke.withValues(alpha: 0.4),
              height: 1, indent: 14, endIndent: 14),
          const SizedBox(height: 12),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                _StatChip(
                  icon: Icons.height,
                  label: 'Level',
                  value: '${data.currentLevel.toStringAsFixed(2)} m',
                  accent: color,
                  t: t,
                ),
                const SizedBox(width: 8),
                _StatChip(
                  icon: Icons.warning_amber_rounded,
                  label: 'Warning',
                  value: '${data.warningLevel.toStringAsFixed(1)} m',
                  accent: const Color(0xFFFFA726),
                  t: t,
                ),
                const SizedBox(width: 8),
                _StatChip(
                  icon: Icons.water_drop_outlined,
                  label: 'Rain 24h',
                  value:
                      '${data.effectiveRainfallMm.toStringAsFixed(1)} mm',
                  accent: t.accent,
                  t: t,
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                _StatChip(
                  icon: Icons.stream,
                  label: 'Danger',
                  value: '${data.dangerLevel.toStringAsFixed(1)} m',
                  accent: AppPalette.critical,
                  t: t,
                ),
                const SizedBox(width: 8),
                _StatChip(
                  icon: Icons.check_circle_outline,
                  label: 'Safe',
                  value: '${data.safeLevel.toStringAsFixed(1)} m',
                  accent: const Color(0xFF66BB6A),
                  t: t,
                ),
                const SizedBox(width: 8),
                if (data.imdRainfallMm != null)
                  _StatChip(
                    icon: Icons.grain_rounded,
                    label: 'IMD Rain',
                    value:
                        '${data.imdRainfallMm!.toStringAsFixed(1)} mm',
                    accent: const Color(0xFF42A5F5),
                    t: t,
                  )
                else if (data.flowRate != null)
                  _StatChip(
                    icon: Icons.speed,
                    label: 'Flow',
                    value:
                        '${(data.flowRate! / 1000).toStringAsFixed(1)}k m³/s',
                    accent: const Color(0xFF66BB6A),
                    t: t,
                  )
                else
                  _StatChip(
                    icon: Icons.access_time,
                    label: 'Updated',
                    value: _timeAgo(data.lastUpdated),
                    accent: _isOutdated
                        ? AppPalette.critical
                        : _isStale
                            ? AppPalette.warning
                            : t.textSecondary,
                    t: t,
                  ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
            child: Row(
              children: [
                Icon(
                  Icons.access_time_rounded,
                  size: 11,
                  color: _isOutdated
                      ? AppPalette.critical
                      : _isStale
                          ? AppPalette.warning
                          : t.textSecondary,
                ),
                const SizedBox(width: 4),
                Text(
                  'Updated ${_timeAgo(data.lastUpdated)}',
                  style: TextStyle(
                    color: _isOutdated
                        ? AppPalette.critical
                        : _isStale
                            ? AppPalette.warning
                            : t.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (data.flowRate != null && data.imdRainfallMm != null) ...[
                  const Spacer(),
                  Icon(Icons.speed, size: 11, color: t.textSecondary),
                  const SizedBox(width: 4),
                  Text(
                    '${(data.flowRate! / 1000).toStringAsFixed(1)}k m³/s',
                    style: TextStyle(
                        color: t.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w500),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 14),

          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: _LevelBar(
              current: data.currentLevel,
              warning: data.warningLevel,
              danger:  data.dangerLevel,
              safe:    data.safeLevel,
              color:   color,
              t:       t,
            ),
          ),
        ],
      ),
    );
  }

  Color _imdColor(String s) {
    switch (s.toUpperCase()) {
      case 'RED':    return const Color(0xFFEF5350);
      case 'ORANGE': return const Color(0xFFFFA726);
      case 'YELLOW': return const Color(0xFFFFEE58);
      default:       return AppPalette.warning;
    }
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1)  return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours   < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Arc Gauge (CustomPaint) — receives theme for center sub-label colour
// ─────────────────────────────────────────────────────────────────────────────

class _ArcGauge extends StatelessWidget {
  final double percent;
  final double warnAt;
  final Color  color;
  final double size;
  final String centerLabel;
  final String subLabel;
  final RiverColors t;

  const _ArcGauge({
    required this.percent,
    required this.warnAt,
    required this.color,
    required this.size,
    required this.centerLabel,
    required this.subLabel,
    required this.t,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size(size, size),
            painter: _ArcPainter(
                percent: percent, warnAt: warnAt, color: color, t: t),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                centerLabel,
                style: TextStyle(
                    color: color,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    height: 1.1),
              ),
              Text(
                subLabel,
                style: TextStyle(
                    color: t.textSecondary,
                    fontSize: 11,
                    letterSpacing: 0.5),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ArcPainter extends CustomPainter {
  final double percent;
  final double warnAt;
  final Color  color;
  final RiverColors t;

  const _ArcPainter({
    required this.percent,
    required this.warnAt,
    required this.color,
    required this.t,
  });

  static const _start = math.pi * 0.75;
  static const _sweep = math.pi * 1.5;

  @override
  void paint(Canvas canvas, Size size) {
    final cx    = size.width  / 2;
    final cy    = size.height / 2;
    final outer = size.width  / 2 - 4;
    final rect  = Rect.fromCircle(center: Offset(cx, cy), radius: outer);

    canvas.drawArc(
      rect, _start, _sweep, false,
      Paint()
        ..style       = PaintingStyle.stroke
        ..strokeWidth = 8
        ..strokeCap   = StrokeCap.round
        ..color       = t.cardBgElevated,
    );

    if (percent > 0) {
      canvas.drawArc(
        rect, _start, _sweep * percent.clamp(0, 1), false,
        Paint()
          ..style       = PaintingStyle.stroke
          ..strokeWidth = 8
          ..strokeCap   = StrokeCap.round
          ..shader      = SweepGradient(
            startAngle: _start,
            endAngle:   _start + _sweep,
            colors: [color.withValues(alpha: 0.5), color],
          ).createShader(rect),
      );
    }

    final wAngle = _start + _sweep * warnAt;
    final tickR  = outer + 3;
    final p1 = Offset(
        cx + (outer - 10) * math.cos(wAngle),
        cy + (outer - 10) * math.sin(wAngle));
    final p2 = Offset(
        cx + tickR * math.cos(wAngle),
        cy + tickR * math.sin(wAngle));
    canvas.drawLine(
      p1, p2,
      Paint()
        ..color       = const Color(0xFFFFA726)
        ..strokeWidth = 2.5
        ..strokeCap   = StrokeCap.round,
    );

    if (percent > 0.01) {
      final dAngle = _start + _sweep * percent;
      final dotC   = Offset(
          cx + outer * math.cos(dAngle),
          cy + outer * math.sin(dAngle));
      canvas.drawCircle(dotC, 4, Paint()..color = color);
      canvas.drawCircle(dotC, 4,
          Paint()
            ..color       = Colors.white.withValues(alpha: 0.3)
            ..style       = PaintingStyle.stroke
            ..strokeWidth = 1.5);
    }
  }

  @override
  bool shouldRepaint(_ArcPainter o) =>
      o.percent != percent || o.color != color;
}

// ─────────────────────────────────────────────────────────────────────────────
// Stat Chip — font floor 11px, theme-driven bg surface
// ─────────────────────────────────────────────────────────────────────────────

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String   label;
  final String   value;
  final Color    accent;
  final RiverColors t;

  const _StatChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
    required this.t,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: accent.withValues(alpha: 0.18), width: 0.8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 13, color: accent),
            const SizedBox(height: 3),
            Text(
              value,
              style: TextStyle(
                  color: accent,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  height: 1.1),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              label,
              style: TextStyle(
                  color: t.textSecondary,
                  fontSize: 11,
                  height: 1.2),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Badge
// ─────────────────────────────────────────────────────────────────────────────

class _Badge extends StatelessWidget {
  final String label;
  final Color  bg;
  final Color  fg;
  const _Badge({required this.label, required this.bg, required this.fg});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(
        label,
        style: TextStyle(
            color: fg,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.4),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Level Bar v3 — theme-aware track background
// ─────────────────────────────────────────────────────────────────────────────

class _LevelBar extends StatelessWidget {
  final double current, warning, danger, safe;
  final Color  color;
  final RiverColors t;

  const _LevelBar({
    required this.current,
    required this.warning,
    required this.danger,
    required this.safe,
    required this.color,
    required this.t,
  });

  @override
  Widget build(BuildContext context) {
    final pct  = danger > 0 ? (current / danger).clamp(0.0, 1.0) : 0.0;
    final wPct = danger > 0 ? (warning / danger).clamp(0.0, 1.0) : 0.65;
    final sPct = danger > 0 ? (safe    / danger).clamp(0.0, 1.0) : 0.20;

    return Column(
      children: [
        LayoutBuilder(
          builder: (_, box) {
            return Stack(
              clipBehavior: Clip.none,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    height: 10,
                    color: t.cardBgElevated,
                    child: FractionallySizedBox(
                      widthFactor: pct,
                      alignment: Alignment.centerLeft,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          gradient: LinearGradient(colors: [
                            color.withValues(alpha: 0.55),
                            color,
                          ]),
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: box.maxWidth * sPct - 1,
                  top: -3,
                  child: Container(
                    width: 2,
                    height: 16,
                    decoration: BoxDecoration(
                      color: const Color(0xFF4CAF50),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Positioned(
                  left: box.maxWidth * wPct - 1,
                  top: -3,
                  child: Container(
                    width: 2.5,
                    height: 16,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFA726),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 5),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('🟢 ${safe.toStringAsFixed(1)} m',
                style: const TextStyle(
                    fontSize: 11, color: Color(0xFF4CAF50))),
            Text('⚠ ${warning.toStringAsFixed(1)} m',
                style: const TextStyle(
                    fontSize: 11, color: Color(0xFFFFA726))),
            Text('🔴 ${danger.toStringAsFixed(1)} m',
                style: const TextStyle(
                    fontSize: 11, color: Color(0xFFEF5350))),
          ],
        ),
      ],
    );
  }
}
