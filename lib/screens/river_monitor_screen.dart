// lib/screens/river_monitor_screen.dart
// UI v3 — provider-driven, RiverColors themed, typography floor 11px.
//
// Provider migration (v2 → v3):
//   BEFORE: ref.watch(realTimeServiceProvider) → rt.liveLevels / rt.isLoading
//   AFTER:
//     liveLevelsProvider           → List<FloodData>
//     isLoadingProvider            → bool skeleton gate
//     criticalStationCountProvider → pre-aggregated int
//     severeStationCountProvider   → pre-aggregated int
//     normalStationCountProvider   → pre-aggregated int
//
// Typography floor: all visible text ≥ 11px.
// Surfaces / text colours: routed through RiverColors.of(context).
// Status / risk colours (critical, danger, amber, safe, cyan) remain as
// AppPalette.* constants — they are intentionally theme-invariant.
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/flood_data.dart';
import '../providers/flood_providers.dart';
import '../theme/river_theme.dart';

class RiverMonitorScreen extends ConsumerWidget {
  const RiverMonitorScreen({super.key});
  static const String route = '/river_monitor';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Narrow provider watches — each rebuilds only its dependents.
    final levels     = ref.watch(liveLevelsProvider);
    final isLoading  = ref.watch(isLoadingProvider);
    final critCount  = ref.watch(criticalStationCountProvider);
    final sevCount   = ref.watch(severeStationCountProvider);
    final normCount  = ref.watch(normalStationCountProvider);

    return _RiverMonitorView(
      levels:    levels,
      isLoading: isLoading,
      critCount: critCount,
      sevCount:  sevCount,
      normCount: normCount,
    );
  }
}

// ───────────────────────────────────────────────────────────────────────────────
// _RiverMonitorView  —  StatefulWidget that owns only local search state
// ───────────────────────────────────────────────────────────────────────────────

class _RiverMonitorView extends StatefulWidget {
  final List<FloodData> levels;
  final bool            isLoading;
  final int             critCount;
  final int             sevCount;
  final int             normCount;

  const _RiverMonitorView({
    required this.levels,
    required this.isLoading,
    required this.critCount,
    required this.sevCount,
    required this.normCount,
  });

  @override
  State<_RiverMonitorView> createState() => _RiverMonitorViewState();
}

class _RiverMonitorViewState extends State<_RiverMonitorView> {
  String _query = '';

  List<FloodData> get _filtered {
    if (_query.isEmpty) return widget.levels;
    final q = _query.toLowerCase();
    return widget.levels.where((fd) =>
        fd.city.toLowerCase().contains(q) ||
        fd.state.toLowerCase().contains(q) ||
        fd.district.toLowerCase().contains(q) ||
        (fd.riverName?.toLowerCase().contains(q) ?? false)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final t        = RiverColors.of(context);
    final filtered = _filtered;

    return Scaffold(
      backgroundColor: t.scaffoldBg,
      appBar: AppBar(
        backgroundColor: t.cardBg,
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
            if (widget.levels.isNotEmpty)
              Text(
                '${widget.levels.length} stations · '
                '${widget.critCount > 0 ? "${widget.critCount} critical · " : ""}'
                '${widget.sevCount  > 0 ? "${widget.sevCount}  severe · "   : ""}'
                '${widget.normCount} normal',
                style: TextStyle(
                  color: t.textSecondary,
                  fontSize: 11,          // floor: was 10
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
              style: TextStyle(color: t.textPrimary, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Search city, district, state or river…',
                hintStyle: TextStyle(color: t.textSecondary, fontSize: 13),
                prefixIcon:
                    Icon(Icons.search, color: AppPalette.cyan, size: 20),
                filled: true,
                fillColor: t.scaffoldBg,
                contentPadding: EdgeInsets.zero,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide(
                      color: AppPalette.cyan.withValues(alpha: 0.18)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide(
                      color: AppPalette.cyan.withValues(alpha: 0.18)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide(
                      color: AppPalette.cyan.withValues(alpha: 0.60)),
                ),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
        ),
      ),
      body: widget.isLoading && widget.levels.isEmpty
          ? Center(
              child: CircularProgressIndicator(color: AppPalette.cyan))
          : filtered.isEmpty
              ? _EmptyState(query: _query, t: t)
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 16),
                  itemCount: filtered.length,
                  itemBuilder: (context, i) =>
                      _RiverCard(data: filtered[i], t: t),
                ),
    );
  }
}

// ───────────────────────────────────────────────────────────────────────────────
// _EmptyState  —  improved empty/no-results state
// ───────────────────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final String     query;
  final RiverColors t;
  const _EmptyState({required this.query, required this.t});

  @override
  Widget build(BuildContext context) {
    final isSearch = query.isNotEmpty;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSearch
                  ? Icons.search_off_rounded
                  : Icons.water_drop_outlined,
              color: t.textSecondary,
              size: 52,
            ),
            const SizedBox(height: 16),
            Text(
              isSearch ? 'No results for “$query”' : 'No live data yet',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: t.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isSearch
                  ? 'Try a different city, district, state, or river name.'
                  : 'Data will appear once the service connects.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: t.textSecondary,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ───────────────────────────────────────────────────────────────────────────────
// River Card v3
// ───────────────────────────────────────────────────────────────────────────────

class _RiverCard extends StatelessWidget {
  final FloodData   data;
  final RiverColors t;
  const _RiverCard({required this.data, required this.t});

  static const _staleThreshold    = Duration(hours: 3);
  static const _outdatedThreshold = Duration(hours: 12);

  bool get _isStale =>
      DateTime.now().difference(data.lastUpdated) > _staleThreshold;
  bool get _isOutdated =>
      DateTime.now().difference(data.lastUpdated) > _outdatedThreshold;

  @override
  Widget build(BuildContext context) {
    final color   = data.priorityColor;
    final pct     = (data.capacityPercent / 100).clamp(0.0, 1.0);
    final warnPct = data.dangerLevel > 0
        ? (data.warningLevel / data.dangerLevel).clamp(0.0, 1.0)
        : 0.65;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: t.cardBg,                                          // ← themed
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: color.withValues(alpha: _isOutdated ? 0.12 : 0.30),
            width: 1),
        boxShadow: [
          BoxShadow(
              color: color.withValues(alpha: _isOutdated ? 0.04 : 0.10),
              blurRadius: 20,
              offset: const Offset(0, 6)),
        ],
      ),
      child: Column(
        children: [
          // ── Stale / Outdated banner ────────────────────────────────────────
          if (_isStale)
            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: (_isOutdated
                        ? const Color(0xFFEF5350)
                        : const Color(0xFFFFA726))
                    .withValues(alpha: 0.10),
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
                    color: _isOutdated
                        ? const Color(0xFFEF5350)
                        : const Color(0xFFFFA726),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    _isOutdated
                        ? 'Outdated · last seen ${_timeAgo(data.lastUpdated)}'
                        : 'Stale · updated ${_timeAgo(data.lastUpdated)}',
                    style: TextStyle(
                      color: _isOutdated
                          ? const Color(0xFFEF5350)
                          : const Color(0xFFFFA726),
                      fontSize: 11,          // floor: was 10
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

          // ── Header row ────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 14, 0),
            child: Row(
              children: [
                _ArcGauge(
                  percent:     pct,
                  warnAt:      warnPct,
                  color:       color,
                  size:        76,
                  centerLabel: '${data.capacityPercent.toStringAsFixed(0)}%',
                  subLabel:    'fill',
                  t:           t,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data.city,
                        style: TextStyle(
                            color:      t.textPrimary,        // ← themed
                            fontSize:   18,
                            fontWeight: FontWeight.w700),
                        maxLines:  1,
                        overflow:  TextOverflow.ellipsis,
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
                                      color:    t.textSecondary, // ← themed
                                      fontSize: 11),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      Row(
                        children: [
                          const Icon(Icons.waves,
                              size: 13, color: AppPalette.cyan),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              data.riverName ?? 'N/A',
                              style: TextStyle(
                                  color: t.textSecondary, // ← themed
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
                              bg: AppPalette.cyan.withValues(alpha: 0.10),
                              fg: AppPalette.cyan),
                          if (data.imdSeverity != null)
                            _Badge(
                                label:
                                    'IMD ● ${data.imdSeverity}',
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
              color: t.stroke, height: 1, indent: 14, endIndent: 14),
          const SizedBox(height: 12),

          // ── Row 1: Level · Warning · Rain 24h ────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                _StatChip(
                  icon:   Icons.height,
                  label:  'Level',
                  value:  '${data.currentLevel.toStringAsFixed(2)} m',
                  accent: color,
                  t:      t,
                ),
                const SizedBox(width: 8),
                _StatChip(
                  icon:   Icons.warning_amber_rounded,
                  label:  'Warning',
                  value:  '${data.warningLevel.toStringAsFixed(1)} m',
                  accent: const Color(0xFFFFA726),
                  t:      t,
                ),
                const SizedBox(width: 8),
                _StatChip(
                  icon:   Icons.water_drop_outlined,
                  label:  'Rain 24h',
                  value:  '${data.effectiveRainfallMm.toStringAsFixed(1)} mm',
                  accent: AppPalette.cyan,
                  t:      t,
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // ── Row 2: Danger · Safe · Flow / IMD Rain ────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                _StatChip(
                  icon:   Icons.stream,
                  label:  'Danger',
                  value:  '${data.dangerLevel.toStringAsFixed(1)} m',
                  accent: const Color(0xFFEF5350),
                  t:      t,
                ),
                const SizedBox(width: 8),
                _StatChip(
                  icon:   Icons.check_circle_outline,
                  label:  'Safe',
                  value:  '${data.safeLevel.toStringAsFixed(1)} m',
                  accent: const Color(0xFF66BB6A),
                  t:      t,
                ),
                const SizedBox(width: 8),
                if (data.imdRainfallMm != null)
                  _StatChip(
                    icon:   Icons.grain_rounded,
                    label:  'IMD Rain',
                    value:  '${data.imdRainfallMm!.toStringAsFixed(1)} mm',
                    accent: const Color(0xFF42A5F5),
                    t:      t,
                  )
                else if (data.flowRate != null)
                  _StatChip(
                    icon:   Icons.speed,
                    label:  'Flow',
                    value:
                        '${(data.flowRate! / 1000).toStringAsFixed(1)}k m³/s',
                    accent: const Color(0xFF66BB6A),
                    t:      t,
                  )
                else
                  _StatChip(
                    icon:   Icons.access_time,
                    label:  'Updated',
                    value:  _timeAgo(data.lastUpdated),
                    accent: _isOutdated
                        ? const Color(0xFFEF5350)
                        : _isStale
                            ? const Color(0xFFFFA726)
                            : t.textSecondary,
                    t: t,
                  ),
              ],
            ),
          ),

          // ── Updated timestamp ───────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
            child: Row(
              children: [
                Icon(
                  Icons.access_time_rounded,
                  size: 11,
                  color: _isOutdated
                      ? const Color(0xFFEF5350)
                      : _isStale
                          ? const Color(0xFFFFA726)
                          : t.textSecondary,
                ),
                const SizedBox(width: 4),
                Text(
                  'Updated ${_timeAgo(data.lastUpdated)}',
                  style: TextStyle(
                    color: _isOutdated
                        ? const Color(0xFFEF5350)
                        : _isStale
                            ? const Color(0xFFFFA726)
                            : t.textSecondary,
                    fontSize: 11,        // floor: was 10
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
                        color:      t.textSecondary,
                        fontSize:   11,  // floor: was 10
                        fontWeight: FontWeight.w500),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 14),

          // ── Level progress bar ───────────────────────────────────────────────
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
      default:       return AppPalette.textGrey;
    }
  }

  String _timeAgo(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1)  return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours   < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

// ───────────────────────────────────────────────────────────────────────────────
// Arc Gauge
// ───────────────────────────────────────────────────────────────────────────────

class _ArcGauge extends StatelessWidget {
  final double      percent;
  final double      warnAt;
  final Color       color;
  final double      size;
  final String      centerLabel;
  final String      subLabel;
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
      width: size, height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size(size, size),
            painter: _ArcPainter(
                percent: percent, warnAt: warnAt, color: color,
                trackColor: t.stroke),   // ← themed track
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                centerLabel,
                style: TextStyle(
                    color:      color,
                    fontSize:   14,
                    fontWeight: FontWeight.w800,
                    height:     1.1),
              ),
              Text(
                subLabel,
                style: TextStyle(
                    color:         t.textSecondary, // ← themed
                    fontSize:      11,              // floor: was 9
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
  final Color  trackColor;

  const _ArcPainter({
    required this.percent,
    required this.warnAt,
    required this.color,
    required this.trackColor,
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
        ..color       = trackColor,       // ← themed
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
    canvas.drawLine(p1, p2,
        Paint()
          ..color       = const Color(0xFFFFA726)
          ..strokeWidth = 2.5
          ..strokeCap   = StrokeCap.round);

    if (percent > 0.01) {
      final dAngle = _start + _sweep * percent;
      final dotC   = Offset(
          cx + outer * math.cos(dAngle),
          cy + outer * math.sin(dAngle));
      canvas.drawCircle(dotC, 4, Paint()..color = color);
      canvas.drawCircle(
          dotC, 4,
          Paint()
            ..color       = Colors.white.withValues(alpha: 0.3)
            ..style       = PaintingStyle.stroke
            ..strokeWidth = 1.5);
    }
  }

  @override
  bool shouldRepaint(_ArcPainter o) =>
      o.percent != percent || o.color != color || o.trackColor != trackColor;
}

// ───────────────────────────────────────────────────────────────────────────────
// Stat Chip v3  —  themed surfaces, 11px label floor
// ───────────────────────────────────────────────────────────────────────────────

class _StatChip extends StatelessWidget {
  final IconData    icon;
  final String      label;
  final String      value;
  final Color       accent;
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
          border: Border.all(
              color: accent.withValues(alpha: 0.18), width: 0.8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 13, color: accent),
            const SizedBox(height: 3),
            Text(
              value,
              style: TextStyle(
                  color:      accent,
                  fontSize:   12,
                  fontWeight: FontWeight.w700,
                  height:     1.1),
              maxLines:  1,
              overflow:  TextOverflow.ellipsis,
            ),
            Text(
              label,
              style: TextStyle(
                  color:    t.textSecondary, // ← themed
                  fontSize: 11,              // floor: was 9
                  height:   1.2),
            ),
          ],
        ),
      ),
    );
  }
}

// ───────────────────────────────────────────────────────────────────────────────
// Badge
// ───────────────────────────────────────────────────────────────────────────────

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
            color:         fg,
            fontSize:      11,   // floor: was 10
            fontWeight:    FontWeight.w700,
            letterSpacing: 0.4),
      ),
    );
  }
}

// ───────────────────────────────────────────────────────────────────────────────
// Level Bar v3 — themed track colour
// ───────────────────────────────────────────────────────────────────────────────

class _LevelBar extends StatelessWidget {
  final double      current, warning, danger, safe;
  final Color       color;
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
                // Track
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    height: 10,
                    color: t.stroke,          // ← themed: was AppPalette.abyss2
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
                // Safe marker (green)
                Positioned(
                  left: box.maxWidth * sPct - 1, top: -3,
                  child: Container(
                    width: 2, height: 16,
                    decoration: BoxDecoration(
                        color: const Color(0xFF4CAF50),
                        borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                // Warning marker (orange)
                Positioned(
                  left: box.maxWidth * wPct - 1, top: -3,
                  child: Container(
                    width: 2.5, height: 16,
                    decoration: BoxDecoration(
                        color: const Color(0xFFFFA726),
                        borderRadius: BorderRadius.circular(2)),
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
                    fontSize: 11, color: Color(0xFF4CAF50))),  // floor: was 10
            Text('⚠ ${warning.toStringAsFixed(1)} m',
                style: const TextStyle(
                    fontSize: 11, color: Color(0xFFFFA726))),  // floor: was 10
            Text('🔴 ${danger.toStringAsFixed(1)} m',
                style: const TextStyle(
                    fontSize: 11, color: Color(0xFFEF5350))),  // floor: was 10
          ],
        ),
      ],
    );
  }
}
