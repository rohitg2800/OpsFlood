// lib/screens/monitors_screen.dart
// OpsFlood — MonitorsScreen v4  "Command Centre"
// Full redesign: header stats bar · risk-sorted cards with fill bar
// · detail expand panel · no-data skeleton · matches dashboard v20 theme
library;

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/flood_data.dart';
import '../providers/flood_providers.dart';
import '../theme/river_theme.dart';

class MonitorsScreen extends ConsumerStatefulWidget {
  const MonitorsScreen({super.key});
  @override
  ConsumerState<MonitorsScreen> createState() => _MonitorsScreenState();
}

class _MonitorsScreenState extends ConsumerState<MonitorsScreen>
    with SingleTickerProviderStateMixin {
  String? _expanded;
  late AnimationController _pulseCtrl;
  late Animation<double>   _pulseAnim;
  String _sort = 'risk'; // 'risk' | 'level' | 'rain'

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1400))
      ..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.3, end: 1.0)
        .animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  List<FloodData> _sorted(List<FloodData> raw) {
    final list = List<FloodData>.from(raw);
    switch (_sort) {
      case 'level':
        list.sort((a, b) => b.currentLevel.compareTo(a.currentLevel));
      case 'rain':
        list.sort((a, b) =>
            b.effectiveRainfallMm.compareTo(a.effectiveRainfallMm));
      default: // risk
        list.sort((a, b) {
          final c = b.priorityOrder.compareTo(a.priorityOrder);
          return c != 0 ? c : b.capacityPercent.compareTo(a.capacityPercent);
        });
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final rt       = ref.watch(realTimeServiceProvider);
    final cities   = ref.watch(monitoredCitiesProvider);
    final allData  = ref.watch(liveLevelsProvider);

    // Build FloodData list for monitored cities
    final items = cities
        .map((c) => rt.dataForCity(c))
        .where((d) => d != null)
        .cast<FloodData>()
        .toList();

    final sorted = _sorted(items);

    // KPI totals
    final critCount  = sorted.where((d) => d.riskLevel == 'CRITICAL').length;
    final sevCount   = sorted.where((d) => d.riskLevel == 'SEVERE').length;
    final modCount   = sorted.where((d) => d.riskLevel == 'MODERATE').length;
    final safeCount  = sorted.where((d) => d.riskLevel == 'LOW').length;
    final noData     = cities.length - items.length;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppPalette.abyss0,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              // ── Header
              _Header(
                total:     sorted.length,
                critical:  critCount,
                pulseAnim: _pulseAnim,
                lastFetch: rt.lastFetchTime,
                onRefresh: () {
                  HapticFeedback.mediumImpact();
                  rt.refreshData();
                },
              ),

              // ── Stats bar
              if (sorted.isNotEmpty)
                _StatsBar(
                  critical: critCount,
                  severe:   sevCount,
                  moderate: modCount,
                  safe:     safeCount,
                  noData:   noData,
                  total:    cities.length,
                ),

              // ── Sort chips
              if (sorted.isNotEmpty)
                _SortChips(
                  current:  _sort,
                  onChange: (v) => setState(() => _sort = v),
                ),

              // ── List
              Expanded(
                child: sorted.isEmpty
                    ? _EmptyState(hasCities: cities.isNotEmpty)
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                        physics: const BouncingScrollPhysics(),
                        itemCount: sorted.length,
                        itemBuilder: (_, i) => _MonitorCard(
                          data:       sorted[i],
                          isExpanded: _expanded == sorted[i].city,
                          pulseAnim:  _pulseAnim,
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() => _expanded =
                                _expanded == sorted[i].city
                                    ? null
                                    : sorted[i].city);
                          },
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// HEADER
// ══════════════════════════════════════════════════════════════════════════════
class _Header extends StatelessWidget {
  final int               total;
  final int               critical;
  final Animation<double> pulseAnim;
  final DateTime?         lastFetch;
  final VoidCallback      onRefresh;
  const _Header({
    required this.total, required this.critical,
    required this.pulseAnim, required this.lastFetch,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
      decoration: BoxDecoration(
        color: AppPalette.abyss0,
        border: Border(
          bottom: BorderSide(
              color: AppPalette.cyan.withValues(alpha: 0.10), width: 1),
        ),
      ),
      child: Row(
        children: [
          // Icon mark
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end:   Alignment.bottomRight,
                colors: [
                  AppPalette.cyan.withValues(alpha: 0.20),
                  AppPalette.cyan.withValues(alpha: 0.05),
                ],
              ),
              border: Border.all(
                  color: AppPalette.cyan.withValues(alpha: 0.28), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: AppPalette.cyan.withValues(alpha: 0.14),
                  blurRadius: 14,
                ),
              ],
            ),
            child: const Icon(Icons.monitor_heart_rounded,
                color: AppPalette.cyan, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShaderMask(
                  shaderCallback: (b) => const LinearGradient(
                    colors: [Color(0xFF00E5FF), Color(0xFF0072FF)],
                  ).createShader(b),
                  child: const Text(
                    'Station Monitor',
                    style: TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w900,
                      color: Colors.white, letterSpacing: -0.8, height: 1.1,
                    ),
                  ),
                ),
                Text(
                  lastFetch != null
                      ? 'Updated ${_fmt(lastFetch!)}'
                      : '$total stations tracked',
                  style: TextStyle(
                    fontSize: 9.5,
                    color: AppPalette.textGrey.withValues(alpha: 0.65),
                  ),
                ),
              ],
            ),
          ),
          // Alert badge
          if (critical > 0)
            AnimatedBuilder(
              animation: pulseAnim,
              builder: (_, __) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppPalette.critical.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppPalette.critical.withValues(
                        alpha: 0.25 + 0.20 * pulseAnim.value),
                  ),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    width: 6, height: 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppPalette.critical.withValues(
                          alpha: 0.5 + 0.5 * pulseAnim.value),
                      boxShadow: [
                        BoxShadow(
                          color: AppPalette.critical
                              .withValues(alpha: 0.7 * pulseAnim.value),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    '$critical CRIT',
                    style: const TextStyle(
                      color: AppPalette.critical,
                      fontSize: 9, fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                ]),
              ),
            )
          else
            // LIVE badge
            AnimatedBuilder(
              animation: pulseAnim,
              builder: (_, __) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppPalette.safe.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppPalette.safe.withValues(
                        alpha: 0.20 + 0.15 * pulseAnim.value),
                  ),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    width: 6, height: 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppPalette.safe.withValues(
                          alpha: 0.5 + 0.5 * pulseAnim.value),
                      boxShadow: [
                        BoxShadow(
                          color: AppPalette.safe
                              .withValues(alpha: 0.6 * pulseAnim.value),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 5),
                  const Text('LIVE',
                      style: TextStyle(
                        color: AppPalette.safe,
                        fontSize: 9, fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                      )),
                ]),
              ),
            ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onRefresh,
            child: Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: AppPalette.abyss2,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppPalette.abyssStroke),
              ),
              child: const Icon(Icons.refresh_rounded,
                  color: AppPalette.textGrey, size: 18),
            ),
          ),
        ],
      ),
    );
  }

  String _fmt(DateTime dt) {
    final d = DateTime.now().difference(dt);
    if (d.inSeconds < 60) return 'just now';
    if (d.inMinutes < 60) return '${d.inMinutes}m ago';
    return DateFormat('HH:mm').format(dt.toLocal());
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// STATS BAR — horizontal risk breakdown strip
// ══════════════════════════════════════════════════════════════════════════════
class _StatsBar extends StatelessWidget {
  final int critical, severe, moderate, safe, noData, total;
  const _StatsBar({
    required this.critical, required this.severe, required this.moderate,
    required this.safe,     required this.noData,  required this.total,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
      decoration: BoxDecoration(
        color: AppPalette.abyss2,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppPalette.abyssStroke),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _StatPill(value: critical, label: 'CRITICAL',
              color: AppPalette.critical, glow: critical > 0),
          _vDivider(),
          _StatPill(value: severe,   label: 'SEVERE',
              color: AppPalette.danger,   glow: severe > 0),
          _vDivider(),
          _StatPill(value: moderate, label: 'MODERATE',
              color: AppPalette.warning),
          _vDivider(),
          _StatPill(value: safe,     label: 'SAFE',
              color: AppPalette.safe),
          if (noData > 0) ...[
            _vDivider(),
            _StatPill(value: noData, label: 'NO DATA',
                color: AppPalette.textDim),
          ],
        ],
      ),
    );
  }

  Widget _vDivider() => Container(
    width: 1, height: 28,
    color: AppPalette.abyssStroke,
  );
}

class _StatPill extends StatelessWidget {
  final int    value;
  final String label;
  final Color  color;
  final bool   glow;
  const _StatPill({
    required this.value, required this.label,
    required this.color, this.glow = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$value',
          style: TextStyle(
            fontSize: 22, fontWeight: FontWeight.w900,
            color: glow ? color : (value > 0 ? color : AppPalette.textDim),
            letterSpacing: -1,
            shadows: glow
                ? [Shadow(color: color.withValues(alpha: 0.6), blurRadius: 8)]
                : null,
          ),
        ),
        const SizedBox(height: 1),
        Text(
          label,
          style: TextStyle(
            fontSize: 7.5, fontWeight: FontWeight.w700,
            color: glow ? color.withValues(alpha: 0.75) : AppPalette.textDim,
            letterSpacing: 0.6,
          ),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// SORT CHIPS
// ══════════════════════════════════════════════════════════════════════════════
class _SortChips extends StatelessWidget {
  final String current;
  final ValueChanged<String> onChange;
  const _SortChips({required this.current, required this.onChange});

  static const _opts = [
    ('risk',  Icons.crisis_alert_rounded,  'Risk'),
    ('level', Icons.water_rounded,         'Level'),
    ('rain',  Icons.grain_rounded,         'Rainfall'),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          Text('Sort by:',
              style: TextStyle(
                fontSize: 10,
                color: AppPalette.textGrey.withValues(alpha: 0.60),
                fontWeight: FontWeight.w600,
              )),
          const SizedBox(width: 8),
          ..._opts.map((o) {
            final active = current == o.$1;
            return GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                onChange(o.$1);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(right: 6),
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: active
                      ? AppPalette.cyan.withValues(alpha: 0.12)
                      : AppPalette.abyss2,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: active
                        ? AppPalette.cyan.withValues(alpha: 0.40)
                        : AppPalette.abyssStroke,
                    width: active ? 1.5 : 1,
                  ),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(o.$2,
                      size: 11,
                      color: active
                          ? AppPalette.cyan
                          : AppPalette.textGrey),
                  const SizedBox(width: 4),
                  Text(
                    o.$3,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: active
                          ? FontWeight.w800
                          : FontWeight.w500,
                      color: active
                          ? AppPalette.cyan
                          : AppPalette.textGrey,
                    ),
                  ),
                ]),
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// MONITOR CARD
// ══════════════════════════════════════════════════════════════════════════════
class _MonitorCard extends StatelessWidget {
  final FloodData         data;
  final bool              isExpanded;
  final Animation<double> pulseAnim;
  final VoidCallback      onTap;
  const _MonitorCard({
    required this.data, required this.isExpanded,
    required this.pulseAnim, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final col    = data.priorityColor;
    final fill   = (data.capacityPercent / 100).clamp(0.0, 1.0);
    final isCrit = data.riskLevel == 'CRITICAL' || data.riskLevel == 'SEVERE';

    return GestureDetector(
      onTap: onTap,
      child: AnimatedBuilder(
        animation: pulseAnim,
        builder: (_, __) => AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: isExpanded
                ? col.withValues(alpha: 0.06)
                : AppPalette.abyss2,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isExpanded || isCrit
                  ? col.withValues(alpha:
                      isExpanded ? 0.40 : 0.14 + 0.12 * pulseAnim.value)
                  : AppPalette.abyssStroke,
              width: isExpanded ? 1.5 : 1,
            ),
            boxShadow: (isExpanded || isCrit)
                ? [
                    BoxShadow(
                      color: col.withValues(
                          alpha: isExpanded ? 0.14 : 0.05 * pulseAnim.value),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // ── Top row
              Row(
                children: [
                  // Status circle
                  Container(
                    width: 46, height: 46,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color:  col.withValues(alpha: 0.10),
                      border: Border.all(
                        color: col.withValues(
                          alpha: isCrit
                              ? 0.22 + 0.18 * pulseAnim.value
                              : 0.25,
                        ),
                        width: 1.5,
                      ),
                    ),
                    child: Icon(_iconFor(data.riskLevel), color: col, size: 20),
                  ),
                  const SizedBox(width: 12),
                  // City + sub-info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                data.city,
                                style: const TextStyle(
                                  color:      AppPalette.textWhite,
                                  fontSize:   15,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.3,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            _RiskChip(label: data.riskLevel, color: col),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _subLine,
                          style: const TextStyle(
                            color: AppPalette.textGrey, fontSize: 10),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  // Level reading
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${data.currentLevel.toStringAsFixed(2)} m',
                        style: TextStyle(
                          color: col, fontSize: 20,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.8,
                        ),
                      ),
                      Text(
                        '${data.capacityPercent.toStringAsFixed(0)}% cap',
                        style: const TextStyle(
                          color: AppPalette.textGrey, fontSize: 9.5),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // ── Fill bar
              Stack(
                children: [
                  Container(
                    height: 7,
                    decoration: BoxDecoration(
                      color: AppPalette.abyss4,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  FractionallySizedBox(
                    widthFactor: fill,
                    child: Container(
                      height: 7,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [
                          col.withValues(alpha: 0.45), col,
                        ]),
                        borderRadius: BorderRadius.circular(4),
                        boxShadow: [
                          BoxShadow(
                            color:      col.withValues(alpha: 0.45),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              // ── Expand panel
              AnimatedSize(
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOutCubic,
                child: isExpanded
                    ? _ExpandPanel(data: data)
                    : const SizedBox.shrink(),
              ),

              // ── Collapse indicator
              if (!isExpanded) ...
                [const SizedBox(height: 4),
                _SubLine(
                  warning: data.warningLevel,
                  danger:  data.dangerLevel,
                  rain:    data.effectiveRainfallMm,
                  river:   data.riverName,
                )],

              // ── Expand arrow
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AnimatedRotation(
                      turns:    isExpanded ? 0.5 : 0.0,
                      duration: const Duration(milliseconds: 260),
                      child: Icon(
                        Icons.expand_more_rounded,
                        color: AppPalette.textDim.withValues(alpha: 0.6),
                        size: 18,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String get _subLine {
    final p = <String>[];
    if ((data.riverName ?? '').isNotEmpty) p.add(data.riverName!);
    if (data.district.isNotEmpty)          p.add(data.district);
    if (data.state.isNotEmpty)             p.add(data.state);
    return p.join('  ·  ');
  }

  IconData _iconFor(String r) => switch (r) {
    'CRITICAL' => Icons.crisis_alert_rounded,
    'SEVERE'   => Icons.error_outline_rounded,
    'MODERATE' => Icons.warning_amber_rounded,
    _          => Icons.check_circle_outline_rounded,
  };
}

// ── Risk chip
class _RiskChip extends StatelessWidget {
  final String label;
  final Color  color;
  const _RiskChip({required this.label, required this.color});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color:        color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(6),
          border:       Border.all(color: color.withValues(alpha: 0.30)),
        ),
        child: Text(label,
            style: TextStyle(
              color: color, fontSize: 8, fontWeight: FontWeight.w900)),
      );
}

// ── Sub-line (warning / danger / rain)
class _SubLine extends StatelessWidget {
  final double  warning, danger, rain;
  final String? river;
  const _SubLine({
    required this.warning, required this.danger,
    required this.rain,    this.river,
  });
  @override
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _mini('W ${warning.toStringAsFixed(1)} m', AppPalette.amber),
          if (river != null && river!.isNotEmpty)
            _mini(river!, AppPalette.textDim),
          _mini('D ${danger.toStringAsFixed(1)} m', AppPalette.danger),
          _mini('${rain.toStringAsFixed(1)} mm', AppPalette.cyan),
        ],
      );

  Widget _mini(String t, Color c) => Text(t,
      style: TextStyle(
          color: c, fontSize: 9, fontWeight: FontWeight.w600));
}

// ══════════════════════════════════════════════════════════════════════════════
// EXPAND PANEL — tapped card detail
// ══════════════════════════════════════════════════════════════════════════════
class _ExpandPanel extends StatelessWidget {
  final FloodData data;
  const _ExpandPanel({required this.data});

  @override
  Widget build(BuildContext context) {
    final col = data.priorityColor;
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        children: [
          // Divider
          Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                Colors.transparent,
                col.withValues(alpha: 0.30),
                Colors.transparent,
              ]),
            ),
          ),
          const SizedBox(height: 14),
          // 3-column threshold row
          Row(
            children: [
              Expanded(child: _ThresholdPill(
                label: 'Safe',
                value: '${data.safeLevel.toStringAsFixed(1)} m',
                color: AppPalette.safe,
              )),
              const SizedBox(width: 8),
              Expanded(child: _ThresholdPill(
                label: 'Warning',
                value: '${data.warningLevel.toStringAsFixed(1)} m',
                color: AppPalette.amber,
              )),
              const SizedBox(width: 8),
              Expanded(child: _ThresholdPill(
                label: 'Danger',
                value: '${data.dangerLevel.toStringAsFixed(1)} m',
                color: AppPalette.critical,
              )),
            ],
          ),
          const SizedBox(height: 10),
          // Stats grid
          Row(
            children: [
              Expanded(child: _InfoTile(
                icon:  Icons.grain_rounded,
                label: 'Rainfall',
                value: '${data.effectiveRainfallMm.toStringAsFixed(1)} mm',
                color: AppPalette.cyan,
              )),
              const SizedBox(width: 8),
              Expanded(child: _InfoTile(
                icon:  Icons.speed_rounded,
                label: 'Flow Rate',
                value: data.flowRate != null
                    ? '${data.flowRate!.toStringAsFixed(0)} m³/s'
                    : '—',
                color: AppPalette.cyan,
              )),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _InfoTile(
                icon:  Icons.thermostat_rounded,
                label: 'IMD Severity',
                value: data.imdSeverity ?? '—',
                color: AppPalette.amber,
              )),
              const SizedBox(width: 8),
              Expanded(child: _InfoTile(
                icon:  Icons.cloud_rounded,
                label: 'IMD Rain',
                value: data.imdRainfallMm != null
                    ? '${data.imdRainfallMm!.toStringAsFixed(1)} mm'
                    : '—',
                color: AppPalette.amber,
              )),
            ],
          ),
          const SizedBox(height: 8),
          // Gap to danger
          _GapBar(
            current: data.currentLevel,
            danger:  data.dangerLevel,
            color:   col,
          ),
          const SizedBox(height: 8),
          // Status + updated
          Row(
            children: [
              _StatusBadge(status: data.status),
              const Spacer(),
              Text(
                DateFormat('dd MMM HH:mm')
                    .format(data.lastUpdated.toLocal()),
                style: const TextStyle(
                  color: AppPalette.textDim, fontSize: 9.5),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ThresholdPill extends StatelessWidget {
  final String label, value;
  final Color  color;
  const _ThresholdPill({
    required this.label, required this.value, required this.color});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        decoration: BoxDecoration(
          color:        color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(10),
          border:       Border.all(color: color.withValues(alpha: 0.20)),
        ),
        child: Column(
          children: [
            Text(value, style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(
              color: AppPalette.textDim, fontSize: 8)),
          ],
        ),
      );
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String   label, value;
  final Color    color;
  const _InfoTile({
    required this.icon, required this.label,
    required this.value, required this.color,
  });
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        decoration: BoxDecoration(
          color:        AppPalette.abyss4,
          borderRadius: BorderRadius.circular(10),
          border:       Border.all(color: AppPalette.abyssStroke),
        ),
        child: Row(children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: TextStyle(
                  color: AppPalette.textWhite,
                  fontSize: 11, fontWeight: FontWeight.w800)),
                Text(label, style: const TextStyle(
                  color: AppPalette.textDim, fontSize: 8.5)),
              ],
            ),
          ),
        ]),
      );
}

class _GapBar extends StatelessWidget {
  final double current, danger;
  final Color  color;
  const _GapBar({
    required this.current, required this.danger, required this.color});
  @override
  Widget build(BuildContext context) {
    final gap     = (danger - current).clamp(0.0, danger);
    final gapPct  = danger > 0 ? gap / danger : 0.0;
    final isAbove = current >= danger;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color:        AppPalette.abyss4,
        borderRadius: BorderRadius.circular(10),
        border:       Border.all(color: AppPalette.abyssStroke),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isAbove
                    ? '⚠️ ${(current - danger).abs().toStringAsFixed(2)} m above danger'
                    : '${gap.toStringAsFixed(2)} m to danger level',
                style: TextStyle(
                  fontSize: 10,
                  color: isAbove ? AppPalette.critical : AppPalette.textGrey,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                'Danger: ${danger.toStringAsFixed(1)} m',
                style: const TextStyle(
                  fontSize: 9.5, color: AppPalette.textDim),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Stack(
            children: [
              Container(
                height: 5,
                decoration: BoxDecoration(
                  color: AppPalette.abyssStroke,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              FractionallySizedBox(
                widthFactor: (current / math.max(danger, 1)).clamp(0.0, 1.5),
                child: Container(
                  height: 5,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                        colors: [color.withValues(alpha: 0.4), color]),
                    borderRadius: BorderRadius.circular(3),
                    boxShadow: [
                      BoxShadow(
                          color: color.withValues(alpha: 0.4),
                          blurRadius: 4),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});
  @override
  Widget build(BuildContext context) {
    final isLive = status.toUpperCase() == 'LIVE' ||
        status.toUpperCase() == 'REAL';
    final c = isLive ? AppPalette.safe : AppPalette.textDim;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color:        c.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border:       Border.all(color: c.withValues(alpha: 0.25)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 5, height: 5,
          decoration: BoxDecoration(shape: BoxShape.circle, color: c),
        ),
        const SizedBox(width: 4),
        Text(status.toUpperCase(),
            style: TextStyle(
              color: c, fontSize: 8, fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            )),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// EMPTY STATE
// ══════════════════════════════════════════════════════════════════════════════
class _EmptyState extends StatelessWidget {
  final bool hasCities;
  const _EmptyState({required this.hasCities});
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80, height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [
                    AppPalette.cyan.withValues(alpha: 0.12),
                    AppPalette.abyss2,
                  ]),
                  border: Border.all(
                      color: AppPalette.cyan.withValues(alpha: 0.20)),
                ),
                child: Icon(
                  hasCities
                      ? Icons.hourglass_top_rounded
                      : Icons.sensors_off_rounded,
                  color: AppPalette.cyan, size: 36,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                hasCities
                    ? 'Loading station data…'
                    : 'No stations configured',
                style: const TextStyle(
                  color: AppPalette.textGrey,
                  fontSize: 14, fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                hasCities
                    ? 'Live data is on its way'
                    : 'Stations appear here once live data arrives',
                style: const TextStyle(
                  color: AppPalette.textDim,
                  fontSize: 10,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
}
