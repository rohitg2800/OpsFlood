// lib/screens/historical_analytics_screen.dart
// OpsFlood — Historical Analytics Screen (Phase 3)
//
// Three tabs:
//   1. Timeline  — flood event list (WL/DL/HFL crossings)
//   2. Chart     — year-over-year monsoon peak comparison
//   3. Stats     — all-time summary statistics
library;

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../theme/river_theme.dart';
import '../l10n/context_l10n.dart';

// ── Data models ───────────────────────────────────────────────────────────────

enum FloodEventType { warningLevel, dangerLevel, hfl }

class FloodEvent {
  final DateTime date;
  final FloodEventType type;
  final double levelReached;
  final double dangerLevel;
  final int durationHours;

  const FloodEvent({
    required this.date,
    required this.type,
    required this.levelReached,
    required this.dangerLevel,
    required this.durationHours,
  });

  String get typeLabel {
    switch (type) {
      case FloodEventType.hfl:          return 'HFL';
      case FloodEventType.dangerLevel:  return 'DANGER';
      case FloodEventType.warningLevel: return 'WARNING';
    }
  }

  Color typeColor(BuildContext context) {
    switch (type) {
      case FloodEventType.hfl:          return const Color(0xFFFF3B30);
      case FloodEventType.dangerLevel:  return const Color(0xFFFF6B35);
      case FloodEventType.warningLevel: return const Color(0xFFFFCC02);
    }
  }

  IconData get typeIcon {
    switch (type) {
      case FloodEventType.hfl:          return Icons.water_rounded;
      case FloodEventType.dangerLevel:  return Icons.warning_rounded;
      case FloodEventType.warningLevel: return Icons.info_rounded;
    }
  }
}

// ── Provider (replace stub with real API call) ────────────────────────────────

final historicalEventsProvider =
    FutureProvider.family<List<FloodEvent>, String>((ref, stationId) async {
  // TODO: Replace with: GET /stations/{stationId}/history?start=&end=
  await Future.delayed(const Duration(milliseconds: 800));
  final now = DateTime.now();
  return [
    FloodEvent(date: now.subtract(const Duration(days: 5)),    type: FloodEventType.dangerLevel,  levelReached: 42.3, dangerLevel: 41.0, durationHours: 18),
    FloodEvent(date: now.subtract(const Duration(days: 12)),   type: FloodEventType.warningLevel, levelReached: 39.8, dangerLevel: 41.0, durationHours: 6),
    FloodEvent(date: now.subtract(const Duration(days: 380)),  type: FloodEventType.hfl,          levelReached: 46.1, dangerLevel: 41.0, durationHours: 52),
    FloodEvent(date: now.subtract(const Duration(days: 395)),  type: FloodEventType.dangerLevel,  levelReached: 43.5, dangerLevel: 41.0, durationHours: 30),
    FloodEvent(date: now.subtract(const Duration(days: 750)),  type: FloodEventType.dangerLevel,  levelReached: 42.8, dangerLevel: 41.0, durationHours: 24),
    FloodEvent(date: now.subtract(const Duration(days: 1120)), type: FloodEventType.warningLevel, levelReached: 40.2, dangerLevel: 41.0, durationHours: 8),
  ];
});

// ── Screen ────────────────────────────────────────────────────────────────────

class HistoricalAnalyticsScreen extends ConsumerStatefulWidget {
  static const String route = '/historical_analytics';
  final String stationId;
  final String stationName;
  final double dangerLevel;
  final double warningLevel;

  const HistoricalAnalyticsScreen({
    super.key,
    required this.stationId,
    required this.stationName,
    required this.dangerLevel,
    required this.warningLevel,
  });

  @override
  ConsumerState<HistoricalAnalyticsScreen> createState() =>
      _HistoricalAnalyticsScreenState();
}

class _HistoricalAnalyticsScreenState
    extends ConsumerState<HistoricalAnalyticsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  DateTimeRange? _selectedRange;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2015),
      lastDate: DateTime.now(),
      initialDateRange: _selectedRange ??
          DateTimeRange(
            start: DateTime.now().subtract(const Duration(days: 365)),
            end: DateTime.now(),
          ),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.dark(
            primary: const Color(0xFF00E5FF),
            surface: RiverColors.of(context).cardBg,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedRange = picked);
  }

  @override
  Widget build(BuildContext context) {
    final t = RiverColors.of(context);
    final eventsAsync = ref.watch(historicalEventsProvider(widget.stationId));

    return Scaffold(
      backgroundColor: t.scaffoldBg,
      appBar: AppBar(
        backgroundColor: t.scaffoldBg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: t.accent),
          tooltip: 'Back',
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Historical Analytics',
                style: TextStyle(
                    color: t.textPrimary, fontSize: 17, fontWeight: FontWeight.w900)),
            Text(widget.stationName,
                style: TextStyle(color: t.textSecondary, fontSize: 11)),
          ],
        ),
        actions: [
          Semantics(
            label: 'Select date range',
            button: true,
            child: Tooltip(
              message: 'Select date range',
              child: InkWell(
                onTap: () { HapticFeedback.selectionClick(); _pickDateRange(); },
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  margin: const EdgeInsets.only(right: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: t.accent.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: t.accent.withValues(alpha: 0.3)),
                  ),
                  child: Row(children: [
                    Icon(Icons.date_range_rounded, color: t.accent, size: 15),
                    const SizedBox(width: 5),
                    Text(
                      _selectedRange == null
                          ? 'All time'
                          : '${DateFormat('dd MMM').format(_selectedRange!.start)} – ${DateFormat('dd MMM yy').format(_selectedRange!.end)}',
                      style: TextStyle(color: t.accent, fontSize: 11, fontWeight: FontWeight.w700),
                    ),
                  ]),
                ),
              ),
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          labelColor: t.accent,
          unselectedLabelColor: t.textSecondary,
          indicatorColor: t.accent,
          indicatorSize: TabBarIndicatorSize.label,
          tabs: const [
            Tab(icon: Icon(Icons.timeline_rounded, size: 18), text: 'Timeline'),
            Tab(icon: Icon(Icons.bar_chart_rounded, size: 18), text: 'YoY Chart'),
            Tab(icon: Icon(Icons.analytics_rounded, size: 18), text: 'Stats'),
          ],
        ),
      ),
      body: eventsAsync.when(
        loading: () => Center(child: CircularProgressIndicator(color: t.accent, strokeWidth: 2)),
        error: (e, _) => Center(child: Text('Failed to load: $e', style: TextStyle(color: t.textSecondary))),
        data: (events) => TabBarView(
          controller: _tabs,
          children: [
            _TimelineTab(events: events, t: t),
            _YoyChartTab(events: events, dangerLevel: widget.dangerLevel, t: t),
            _StatsTab(events: events, dangerLevel: widget.dangerLevel, t: t),
          ],
        ),
      ),
    );
  }
}

// ── Tab 1: Timeline ───────────────────────────────────────────────────────────

class _TimelineTab extends StatelessWidget {
  final List<FloodEvent> events;
  final RiverColors t;
  const _TimelineTab({required this.events, required this.t});

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) {
      return Center(child: Text('No flood events recorded', style: TextStyle(color: t.textSecondary)));
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
      itemCount: events.length,
      itemBuilder: (context, index) {
        final event = events[index];
        final color = event.typeColor(context);
        final isLast = index == events.length - 1;
        return Semantics(
          label: '${event.typeLabel} event on ${DateFormat('dd MMM yyyy').format(event.date)}, '
              'level ${event.levelReached.toStringAsFixed(1)} metres, duration ${event.durationHours} hours',
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(children: [
                Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color.withValues(alpha: 0.12),
                    border: Border.all(color: color.withValues(alpha: 0.4), width: 1.5),
                  ),
                  child: Icon(event.typeIcon, color: color, size: 15),
                ),
                if (!isLast) Container(width: 2, height: 60, color: t.stroke),
              ]),
              const SizedBox(width: 14),
              Expanded(
                child: Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: t.cardBg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: color.withValues(alpha: 0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(event.typeLabel,
                              style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w800)),
                        ),
                        const Spacer(),
                        Text(DateFormat('dd MMM yyyy').format(event.date),
                            style: TextStyle(color: t.textSecondary, fontSize: 11)),
                      ]),
                      const SizedBox(height: 8),
                      Row(children: [
                        _StatMini(label: 'LEVEL', value: '${event.levelReached.toStringAsFixed(2)} m', t: t),
                        const SizedBox(width: 16),
                        _StatMini(
                          label: 'ABOVE DL',
                          value: '+${(event.levelReached - event.dangerLevel).toStringAsFixed(2)} m',
                          color: color, t: t,
                        ),
                        const SizedBox(width: 16),
                        _StatMini(label: 'DURATION', value: '${event.durationHours}h', t: t),
                      ]),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StatMini extends StatelessWidget {
  final String label, value;
  final RiverColors t;
  final Color? color;
  const _StatMini({required this.label, required this.value, required this.t, this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: t.textSecondary, fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 0.6)),
        Text(value, style: TextStyle(color: color ?? t.textPrimary, fontSize: 13, fontWeight: FontWeight.w800)),
      ],
    );
  }
}

// ── Tab 2: YoY Chart ─────────────────────────────────────────────────────────

class _YoyChartTab extends StatelessWidget {
  final List<FloodEvent> events;
  final double dangerLevel;
  final RiverColors t;
  const _YoyChartTab({required this.events, required this.dangerLevel, required this.t});

  @override
  Widget build(BuildContext context) {
    final Map<int, double> maxByYear = {};
    for (final e in events) {
      final y = e.date.year;
      maxByYear[y] = math.max(maxByYear[y] ?? 0, e.levelReached);
    }
    final sorted = maxByYear.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
    final maxVal = sorted.isEmpty ? dangerLevel + 5 : sorted.map((e) => e.value).reduce(math.max);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Peak Level by Monsoon Year',
              style: TextStyle(color: t.textPrimary, fontSize: 14, fontWeight: FontWeight.w800)),
          Text('Highest water level recorded each year (metres)',
              style: TextStyle(color: t.textSecondary, fontSize: 11)),
          const SizedBox(height: 20),
          Container(
            height: 260,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: t.cardBg,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: t.stroke),
            ),
            child: sorted.isEmpty
                ? Center(child: Text('No data', style: TextStyle(color: t.textSecondary)))
                : CustomPaint(
                    painter: _YoYBarPainter(
                      data: sorted,
                      dangerLevel: dangerLevel,
                      maxVal: maxVal * 1.15,
                      dangerColor: const Color(0xFFFF6B35),
                      barColor: const Color(0xFF00E5FF),
                      gridColor: t.stroke,
                      labelColor: t.textSecondary,
                    ),
                  ),
          ),
          const SizedBox(height: 14),
          Row(children: [
            _Legend(color: const Color(0xFF00E5FF), label: 'Peak Level'),
            const SizedBox(width: 16),
            _Legend(color: const Color(0xFFFF6B35), label: 'Danger Level', dashed: true),
          ]),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;
  final bool dashed;
  const _Legend({required this.color, required this.label, this.dashed = false});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
        width: 20, height: 3,
        decoration: BoxDecoration(
          color: dashed ? Colors.transparent : color,
          borderRadius: BorderRadius.circular(2),
          border: dashed ? Border(bottom: BorderSide(color: color, width: 2)) : null,
        ),
      ),
      const SizedBox(width: 6),
      Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    ]);
  }
}

class _YoYBarPainter extends CustomPainter {
  final List<MapEntry<int, double>> data;
  final double dangerLevel, maxVal;
  final Color dangerColor, barColor, gridColor, labelColor;

  const _YoYBarPainter({
    required this.data, required this.dangerLevel, required this.maxVal,
    required this.dangerColor, required this.barColor,
    required this.gridColor, required this.labelColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const double bottomPad = 28;
    const double topPad = 10;
    final chartH = size.height - bottomPad - topPad;
    final barW = (size.width / data.length) * 0.55;
    final gap = size.width / data.length;

    final gridPaint = Paint()..color = gridColor..strokeWidth = 0.5;
    for (int i = 0; i <= 4; i++) {
      final y = topPad + chartH * (1 - i / 4);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final dlY = topPad + chartH * (1 - dangerLevel / maxVal);
    final dlPaint = Paint()..color = dangerColor..strokeWidth = 1.5..style = PaintingStyle.stroke;
    double x = 0;
    while (x < size.width) {
      canvas.drawLine(Offset(x, dlY), Offset(math.min(x + 6, size.width), dlY), dlPaint);
      x += 10;
    }

    for (int i = 0; i < data.length; i++) {
      final entry = data[i];
      final barX = gap * i + gap / 2 - barW / 2;
      final barH = chartH * (entry.value / maxVal);
      final barY = topPad + chartH - barH;
      final aboveDanger = entry.value >= dangerLevel;
      final paint = Paint()
        ..color = (aboveDanger ? dangerColor : barColor).withValues(alpha: 0.75)
        ..style = PaintingStyle.fill;
      canvas.drawRRect(
        RRect.fromRectAndCorners(Rect.fromLTWH(barX, barY, barW, barH),
          topLeft: const Radius.circular(4), topRight: const Radius.circular(4)),
        paint,
      );
      final tp = TextPainter(
        text: TextSpan(text: '${entry.key}',
          style: TextStyle(color: labelColor, fontSize: 9, fontWeight: FontWeight.w600)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(barX + barW / 2 - tp.width / 2, size.height - bottomPad + 6));
    }
  }

  @override
  bool shouldRepaint(_YoYBarPainter old) => old.data != data;
}

// ── Tab 3: Stats ──────────────────────────────────────────────────────────────

class _StatsTab extends StatelessWidget {
  final List<FloodEvent> events;
  final double dangerLevel;
  final RiverColors t;
  const _StatsTab({required this.events, required this.dangerLevel, required this.t});

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) {
      return Center(child: Text('No historical data', style: TextStyle(color: t.textSecondary)));
    }
    final allTimePeak  = events.map((e) => e.levelReached).reduce(math.max);
    final avgPeak      = events.map((e) => e.levelReached).reduce((a, b) => a + b) / events.length;
    final dangerEvents = events.where((e) => e.type == FloodEventType.dangerLevel || e.type == FloodEventType.hfl).length;
    final hflEvents    = events.where((e) => e.type == FloodEventType.hfl).length;
    final avgDuration  = events.map((e) => e.durationHours).reduce((a, b) => a + b) / events.length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        _StatCard(t: t, label: 'All-Time Peak Level', value: '${allTimePeak.toStringAsFixed(2)} m',
            icon: Icons.water_rounded, color: const Color(0xFFFF3B30),
            subtitle: '+${(allTimePeak - dangerLevel).toStringAsFixed(2)} m above Danger Level'),
        _StatCard(t: t, label: 'Average Peak Level', value: '${avgPeak.toStringAsFixed(2)} m',
            icon: Icons.show_chart_rounded, color: const Color(0xFF00E5FF),
            subtitle: 'Across ${events.length} recorded events'),
        _StatCard(t: t, label: 'Danger-Level Crossings', value: '$dangerEvents events',
            icon: Icons.warning_rounded, color: const Color(0xFFFF6B35),
            subtitle: 'Times river exceeded Danger Level'),
        _StatCard(t: t, label: 'HFL Events', value: '$hflEvents events',
            icon: Icons.emergency_rounded, color: const Color(0xFFFF3B30),
            subtitle: 'All-time highest flood level events'),
        _StatCard(t: t, label: 'Avg Event Duration', value: '${avgDuration.toStringAsFixed(0)} hrs',
            icon: Icons.timer_rounded, color: const Color(0xFFFFCC02),
            subtitle: 'Average hours above warning level per event'),
      ]),
    );
  }
}

class _StatCard extends StatelessWidget {
  final RiverColors t;
  final String label, value, subtitle;
  final IconData icon;
  final Color color;

  const _StatCard({required this.t, required this.label, required this.value,
      required this.subtitle, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label: $value. $subtitle',
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: t.cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.10),
              border: Border.all(color: color.withValues(alpha: 0.3), width: 1.5),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(color: t.textSecondary, fontSize: 11, fontWeight: FontWeight.w600)),
              Text(value, style: TextStyle(color: t.textPrimary, fontSize: 22, fontWeight: FontWeight.w900)),
              Text(subtitle, style: TextStyle(color: t.textSecondary, fontSize: 11)),
            ],
          )),
        ]),
      ),
    );
  }
}
