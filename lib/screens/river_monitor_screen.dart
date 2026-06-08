// lib/screens/river_monitor_screen.dart
// UI v2 — richer data-driven cards, stale-data warning, district line,
//          IMD rainfall chip, safe-level stat, 2-row 3-chip stat grid.
// Logic unchanged: same providers, same FloodData fields.
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/flood_data.dart';
import '../providers/flood_providers.dart';
import '../theme/river_theme.dart';

class RiverMonitorScreen extends ConsumerStatefulWidget {
  const RiverMonitorScreen({super.key});
  static const String route = '/river_monitor';
  @override
  ConsumerState<RiverMonitorScreen> createState() => _RiverMonitorScreenState();
}

class _RiverMonitorScreenState extends ConsumerState<RiverMonitorScreen> {
  String _query = '';

  List<FloodData> _filtered(List<FloodData> levels) {
    if (_query.isEmpty) return levels;
    final q = _query.toLowerCase();
    return levels.where((fd) =>
        fd.city.toLowerCase().contains(q) ||
        fd.state.toLowerCase().contains(q) ||
        fd.district.toLowerCase().contains(q) ||
        (fd.riverName?.toLowerCase().contains(q) ?? false)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final rt     = ref.watch(realTimeServiceProvider);
    final levels = _filtered(rt.liveLevels);

    // summary counts for header strip
    final critCount = rt.liveLevels
        .where((d) => d.riskLevel.toUpperCase() == 'CRITICAL').length;
    final sevCount  = rt.liveLevels
        .where((d) => d.riskLevel.toUpperCase() == 'SEVERE').length;

    return Scaffold(
      backgroundColor: AppPalette.abyss0,
      appBar: AppBar(
        backgroundColor: AppPalette.abyss1,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'River Monitor',
              style: TextStyle(
                color: AppPalette.textWhite,
                fontWeight: FontWeight.w800,
                fontSize: 18,
                letterSpacing: 0.2,
              ),
            ),
            if (rt.liveLevels.isNotEmpty)
              Text(
                '${rt.liveLevels.length} stations · '
                '${critCount > 0 ? "$critCount critical · " : ""}'
                '${sevCount > 0 ? "$sevCount severe · " : ""}'
                '${rt.liveLevels.length - critCount - sevCount} normal',
                style: const TextStyle(
                  color: AppPalette.textGrey,
                  fontSize: 10,
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
              style: const TextStyle(color: AppPalette.textWhite),
              decoration: InputDecoration(
                hintText: 'Search city, district, state or river…',
                hintStyle:
                    const TextStyle(color: AppPalette.textGrey, fontSize: 13),
                prefixIcon:
                    const Icon(Icons.search, color: AppPalette.cyan, size: 20),
                filled: true,
                fillColor: AppPalette.abyss2,
                contentPadding: EdgeInsets.zero,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide:
                      BorderSide(color: AppPalette.cyan.withValues(alpha: 0.18)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide:
                      BorderSide(color: AppPalette.cyan.withValues(alpha: 0.18)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide:
                      BorderSide(color: AppPalette.cyan.withValues(alpha: 0.6)),
                ),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
        ),
      ),
      body: rt.isLoading && levels.isEmpty
          ? const Center(
              child: CircularProgressIndicator(color: AppPalette.cyan))
          : levels.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.water_drop_outlined,
                          color: AppPalette.textGrey, size: 48),
                      const SizedBox(height: 12),
                      Text(
                        _query.isEmpty
                            ? 'No live data available.'
                            : 'No results for "$_query".',
                        style:
                            const TextStyle(color: AppPalette.textGrey),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                  itemCount: levels.length,
                  itemBuilder: (context, i) =>
                      _RiverCard(data: levels[i]),
                ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// River Card v2
// ─────────────────────────────────────────────────────────────────────────────

class _RiverCard extends StatelessWidget {
  final FloodData data;
  const _RiverCard({required this.data});

  static const _staleThreshold = Duration(hours: 3);
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
        color: AppPalette.abyss1,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: color.withValues(alpha: _isOutdated ? 0.12 : 0.30), width: 1),
        boxShadow: [
          BoxShadow(
              color: color.withValues(alpha: _isOutdated ? 0.04 : 0.10),
              blurRadius: 20,
              offset: const Offset(0, 6)),
        ],
      ),
      child: Column(
        children: [
          // ── Stale/Outdated banner ─────────────────────────────────────────
          if (_isStale)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: (_isOutdated
                        ? const Color(0xFFEF5350)
                        : const Color(0xFFFFA726))
                    .withValues(alpha: 0.10),
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20)),
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
                        ? 'Outdated data · last seen ${_timeAgo(data.lastUpdated)}'
                        : 'Stale · last updated ${_timeAgo(data.lastUpdated)}',
                    style: TextStyle(
                      color: _isOutdated
                          ? const Color(0xFFEF5350)
                          : const Color(0xFFFFA726),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

          // ── Header row ────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 14, 0),
            child: Row(
              children: [
                // Arc gauge
                _ArcGauge(
                  percent: pct,
                  warnAt: warnPct,
                  color: color,
                  size: 76,
                  centerLabel:
                      '${data.capacityPercent.toStringAsFixed(0)}%',
                  subLabel: 'fill',
                ),
                const SizedBox(width: 14),
                // Name + river + district
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data.city,
                        style: const TextStyle(
                            color: AppPalette.textWhite,
                            fontSize: 18,
                            fontWeight: FontWeight.w700),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      // District line (new)
                      if (data.district.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: Row(
                            children: [
                              const Icon(Icons.location_city_rounded,
                                  size: 11,
                                  color: AppPalette.textGrey),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  '${data.district} · ${data.state}',
                                  style: const TextStyle(
                                      color: AppPalette.textGrey,
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
                              style: const TextStyle(
                                  color: AppPalette.textGrey,
                                  fontSize: 12),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Badges row
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
                                label: 'IMD ● ${data.imdSeverity}',
                                bg: _imdColor(data.imdSeverity!)
                                    .withValues(alpha: 0.15),
                                fg: _imdColor(data.imdSeverity!)),
                          // Fresh/Stale indicator badge
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
          const Divider(
              color: Color(0x1800C6FF), height: 1, indent: 14, endIndent: 14),
          const SizedBox(height: 12),

          // ── Row 1: Level · Warning · Rain24h ───────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                _StatChip(
                  icon: Icons.height,
                  label: 'Level',
                  value: '${data.currentLevel.toStringAsFixed(2)} m',
                  accent: color,
                ),
                const SizedBox(width: 8),
                _StatChip(
                  icon: Icons.warning_amber_rounded,
                  label: 'Warning',
                  value: '${data.warningLevel.toStringAsFixed(1)} m',
                  accent: const Color(0xFFFFA726),
                ),
                const SizedBox(width: 8),
                _StatChip(
                  icon: Icons.water_drop_outlined,
                  label: 'Rain 24h',
                  value: '${data.effectiveRainfallMm.toStringAsFixed(1)} mm',
                  accent: AppPalette.cyan,
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // ── Row 2: Danger · Flow · Safe · Updated ──────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                _StatChip(
                  icon: Icons.stream,
                  label: 'Danger',
                  value: '${data.dangerLevel.toStringAsFixed(1)} m',
                  accent: const Color(0xFFEF5350),
                ),
                const SizedBox(width: 8),
                _StatChip(
                  icon: Icons.check_circle_outline,
                  label: 'Safe',
                  value: '${data.safeLevel.toStringAsFixed(1)} m',
                  accent: const Color(0xFF66BB6A),
                ),
                const SizedBox(width: 8),
                // IMD Rainfall if available, else Flow
                if (data.imdRainfallMm != null)
                  _StatChip(
                    icon: Icons.grain_rounded,
                    label: 'IMD Rain',
                    value: '${data.imdRainfallMm!.toStringAsFixed(1)} mm',
                    accent: const Color(0xFF42A5F5),
                  )
                else if (data.flowRate != null)
                  _StatChip(
                    icon: Icons.speed,
                    label: 'Flow',
                    value:
                        '${(data.flowRate! / 1000).toStringAsFixed(1)}k m³/s',
                    accent: const Color(0xFF66BB6A),
                  )
                else
                  _StatChip(
                    icon: Icons.access_time,
                    label: 'Updated',
                    value: _timeAgo(data.lastUpdated),
                    accent: _isOutdated
                        ? const Color(0xFFEF5350)
                        : _isStale
                            ? const Color(0xFFFFA726)
                            : AppPalette.textGrey,
                  ),
              ],
            ),
          ),

          // ── Updated timestamp row ──────────────────────────────────────────
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
                          : AppPalette.textGrey,
                ),
                const SizedBox(width: 4),
                Text(
                  'Updated ${_timeAgo(data.lastUpdated)}',
                  style: TextStyle(
                    color: _isOutdated
                        ? const Color(0xFFEF5350)
                        : _isStale
                            ? const Color(0xFFFFA726)
                            : AppPalette.textGrey,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (data.flowRate != null && data.imdRainfallMm != null) ...[
                  const Spacer(),
                  Icon(Icons.speed, size: 11, color: AppPalette.textGrey),
                  const SizedBox(width: 4),
                  Text(
                    '${(data.flowRate! / 1000).toStringAsFixed(1)}k m³/s',
                    style: const TextStyle(
                        color: AppPalette.textGrey,
                        fontSize: 10,
                        fontWeight: FontWeight.w500),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 14),

          // ── Level progress bar ─────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: _LevelBar(
              current: data.currentLevel,
              warning: data.warningLevel,
              danger:  data.dangerLevel,
              safe:    data.safeLevel,
              color:   color,
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

  String _timeAgo(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 1)  return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours   < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Arc Gauge (CustomPaint — unchanged logic)
// ─────────────────────────────────────────────────────────────────────────────

class _ArcGauge extends StatelessWidget {
  final double percent;
  final double warnAt;
  final Color  color;
  final double size;
  final String centerLabel;
  final String subLabel;

  const _ArcGauge({
    required this.percent,
    required this.warnAt,
    required this.color,
    required this.size,
    required this.centerLabel,
    required this.subLabel,
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
                percent: percent, warnAt: warnAt, color: color),
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
                style: const TextStyle(
                    color: AppPalette.textGrey,
                    fontSize: 9,
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

  const _ArcPainter({
    required this.percent,
    required this.warnAt,
    required this.color,
  });

  static const _start  = math.pi * 0.75;
  static const _sweep  = math.pi * 1.5;

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
        ..color       = AppPalette.abyss2,
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
// Stat Chip
// ─────────────────────────────────────────────────────────────────────────────

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String   label;
  final String   value;
  final Color    accent;

  const _StatChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(10),
          border:
              Border.all(color: accent.withValues(alpha: 0.18), width: 0.8),
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
              style: const TextStyle(
                  color: AppPalette.textGrey, fontSize: 9, height: 1.2),
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
      decoration: BoxDecoration(
          color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(
        label,
        style: TextStyle(
            color: fg,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.4),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Level Bar v2 — shows safe level marker too
// ─────────────────────────────────────────────────────────────────────────────

class _LevelBar extends StatelessWidget {
  final double current, warning, danger, safe;
  final Color  color;
  const _LevelBar({
    required this.current,
    required this.warning,
    required this.danger,
    required this.safe,
    required this.color,
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
                    color: AppPalette.abyss2,
                    child: FractionallySizedBox(
                      widthFactor: pct,
                      alignment: Alignment.centerLeft,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          gradient: LinearGradient(
                            colors: [
                              color.withValues(alpha: 0.55),
                              color,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                // Safe marker (green)
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
                // Warning marker (orange)
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
            Text(
              '🟢 ${safe.toStringAsFixed(1)} m',
              style: const TextStyle(
                  fontSize: 10, color: Color(0xFF4CAF50)),
            ),
            Text(
              '⚠ ${warning.toStringAsFixed(1)} m',
              style: const TextStyle(
                  fontSize: 10, color: Color(0xFFFFA726)),
            ),
            Text(
              '🔴 ${danger.toStringAsFixed(1)} m',
              style: const TextStyle(
                  fontSize: 10, color: Color(0xFFEF5350)),
            ),
          ],
        ),
      ],
    );
  }
}
