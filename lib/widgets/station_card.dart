// lib/widgets/station_card.dart
// OpsFlood — StationCard v4  (district / zila added)
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/river_theme.dart';
import '../utils/flood_severity_helper.dart';

class StationCard extends StatefulWidget {
  final String city;
  final String district;   // ← zila
  final String river;
  final String state;
  final double current;
  final double warning;
  final double danger;
  final String source;  // 'LIVE' | 'SAT' | 'EST' | 'NO_DATA'
  final String status;  // 'SAFE' | 'WATCH' | 'WARNING' | 'DANGER' | 'CRITICAL' | 'EXTREME'
  final String? trend;  // 'RISING' | 'FALLING' | 'STEADY'
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  final bool expandable;

  const StationCard({
    super.key,
    required this.city,
    this.district = '',
    required this.river,
    required this.state,
    required this.current,
    required this.warning,
    required this.danger,
    required this.source,
    required this.status,
    this.trend,
    this.onTap,
    this.onDelete,
    this.expandable = false,
  });

  @override
  State<StationCard> createState() => _StationCardState();
}

class _StationCardState extends State<StationCard>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;
  late final AnimationController _ctrl;
  late final Animation<double> _expandAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
    _expandAnim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  FloodSeverity get _severity => FloodSeverityHelper.fromString(widget.status);
  Color get _statusColor => FloodSeverityHelper.color(_severity);
  IconData get _statusIcon => FloodSeverityHelper.icon(_severity);
  Color get _glowColor => FloodSeverityHelper.glowColor(_severity);

  WaterLevelTrend get _waterTrend {
    if (widget.trend == null) return WaterLevelTrend.unknown;
    switch (widget.trend!.toUpperCase()) {
      case 'RISING':  return WaterLevelTrend.rising;
      case 'FALLING': return WaterLevelTrend.falling;
      case 'STEADY':  return WaterLevelTrend.stable;
      default:        return WaterLevelTrend.unknown;
    }
  }

  double get _fillPct =>
      widget.danger > 0 ? (widget.current / widget.danger).clamp(0.0, 1.2) : 0.0;

  String get _subLabel {
    final parts = <String>[];
    if (widget.river.isNotEmpty)    parts.add(widget.river);
    if (widget.district.isNotEmpty) parts.add(widget.district);
    if (widget.state.isNotEmpty)    parts.add(widget.state);
    return parts.join('  ·  ');
  }

  void _toggleExpand() {
    HapticFeedback.selectionClick();
    setState(() => _expanded = !_expanded);
    _expanded ? _ctrl.forward() : _ctrl.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final col = _statusColor;
    final isAlert = _severity == FloodSeverity.danger ||
        _severity == FloodSeverity.extreme;

    return GestureDetector(
      onTap: widget.expandable ? _toggleExpand : widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: FloodSeverityHelper.cardFill(_severity) != Colors.transparent
              ? AppPalette.abyss2.withValues(alpha: 0.98)
              : AppPalette.abyss2,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: FloodSeverityHelper.cardBorder(_severity),
            width: isAlert ? 1.5 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: _glowColor,
              blurRadius: isAlert ? 18 : 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            // ── Top row ──────────────────────────────────────────
            Row(
              children: [
                Container(
                  width: 42, height: 42,
                  decoration: BoxDecoration(
                    color:  col.withValues(alpha: 0.10),
                    shape:  BoxShape.circle,
                    border: Border.all(
                        color: col.withValues(alpha: 0.35), width: 1.5),
                  ),
                  child: Icon(_statusIcon, color: col, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Flexible(
                          child: Text(
                            widget.city,
                            style: const TextStyle(
                              color: AppPalette.textWhite,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        _SourceBadge(source: widget.source),
                      ]),
                      const SizedBox(height: 2),
                      // River · District · State
                      Text(
                        _subLabel,
                        style: const TextStyle(
                          color: AppPalette.textGrey,
                          fontSize: 11,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      // district chip only if non-empty
                      if (widget.district.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        _DistrictChip(district: widget.district),
                      ],
                    ],
                  ),
                ),
                // Right side: level value + status chip
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${widget.current.toStringAsFixed(2)} m',
                      style: TextStyle(
                        color: col,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    _StatusChip(
                      label: FloodSeverityHelper.label(_severity),
                      color: col,
                    ),
                    if (widget.onDelete != null) ...[
                      const SizedBox(height: 4),
                      GestureDetector(
                        onTap: widget.onDelete,
                        child: const Icon(
                          Icons.remove_circle_outline,
                          size: 15,
                          color: AppPalette.textDim,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),

            const SizedBox(height: 12),
            // ── Fill bar ─────────────────────────────────────────
            Stack(children: [
              Container(
                height: 7,
                decoration: BoxDecoration(
                  color:        AppPalette.abyss4,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              if (widget.danger > 0 && widget.warning > 0)
                Positioned(
                  left: (widget.warning / widget.danger).clamp(0.0, 1.0) *
                      (MediaQuery.of(context).size.width - 92),
                  top: 0, bottom: 0,
                  child: Container(
                    width: 2,
                    color: AppPalette.amber.withValues(alpha: 0.65),
                  ),
                ),
              FractionallySizedBox(
                widthFactor: _fillPct.clamp(0.0, 1.0),
                child: Container(
                  height: 7,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        col.withValues(alpha: 0.55),
                        col,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(4),
                    boxShadow: [
                      BoxShadow(
                        color:      col.withValues(alpha: 0.40),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 6),

            // ── Metrics row ────────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _mini('W ${widget.warning.toStringAsFixed(1)} m',
                    AppPalette.amber),
                _mini('D ${widget.danger.toStringAsFixed(1)} m',
                    AppPalette.danger),
                _mini(
                  '${(_fillPct * 100).clamp(0, 120).toStringAsFixed(0)}%',
                  AppPalette.textGrey,
                ),
                // Trend icon
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      FloodSeverityHelper.trendIcon(_waterTrend),
                      size: 14,
                      color: FloodSeverityHelper.trendColor(_waterTrend),
                    ),
                    const SizedBox(width: 3),
                    Text(
                      FloodSeverityHelper.trendLabel(_waterTrend),
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: FloodSeverityHelper.trendColor(_waterTrend),
                      ),
                    ),
                  ],
                ),
              ],
            ),

            // ── Expanded detail section ────────────────────────────────
            if (widget.expandable)
              SizeTransition(
                sizeFactor: _expandAnim,
                child: _ExpandedDetail(
                  severity: _severity,
                  color: col,
                  current: widget.current,
                  warning: widget.warning,
                  danger: widget.danger,
                  fillPct: _fillPct,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _mini(String t, Color c) => Text(
        t,
        style: TextStyle(
            color: c, fontSize: 9, fontWeight: FontWeight.w600),
      );
}

// ── Expanded Detail ───────────────────────────────────────────────────────────
class _ExpandedDetail extends StatelessWidget {
  const _ExpandedDetail({
    required this.severity,
    required this.color,
    required this.current,
    required this.warning,
    required this.danger,
    required this.fillPct,
  });

  final FloodSeverity severity;
  final Color color;
  final double current, warning, danger, fillPct;

  @override
  Widget build(BuildContext context) {
    final aboveWarning = current - warning;
    final aboveDanger  = current - danger;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 10),
          child: Divider(color: AppPalette.abyssStroke, height: 1),
        ),
        Row(
          children: [
            _DetailTile(
              label: 'Above Warning',
              value: aboveWarning >= 0
                  ? '+${aboveWarning.toStringAsFixed(2)} m'
                  : '${aboveWarning.toStringAsFixed(2)} m',
              color: aboveWarning >= 0 ? AppPalette.warning : AppPalette.safe,
            ),
            const SizedBox(width: 8),
            _DetailTile(
              label: 'Above Danger',
              value: aboveDanger >= 0
                  ? '+${aboveDanger.toStringAsFixed(2)} m'
                  : '${aboveDanger.toStringAsFixed(2)} m',
              color: aboveDanger >= 0 ? AppPalette.danger : AppPalette.safe,
            ),
            const SizedBox(width: 8),
            _DetailTile(
              label: 'Capacity',
              value: '${(fillPct * 100).clamp(0, 120).toStringAsFixed(1)}%',
              color: color,
            ),
          ],
        ),
        const SizedBox(height: 10),
        // Severity description
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withValues(alpha: 0.25)),
          ),
          child: Row(
            children: [
              Icon(FloodSeverityHelper.icon(severity),
                  color: color, size: 16),
              const SizedBox(width: 8),
              Text(
                _severityAdvice(severity),
                style: TextStyle(
                  fontSize: 11,
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  String _severityAdvice(FloodSeverity s) {
    switch (s) {
      case FloodSeverity.normal:  return 'River within safe limits. No action needed.';
      case FloodSeverity.watch:   return 'Approaching warning level. Monitor closely.';
      case FloodSeverity.warning: return 'Warning level crossed. Prepare for response.';
      case FloodSeverity.danger:  return 'Danger level crossed! Evacuation may be needed.';
      case FloodSeverity.extreme: return 'EXTREME FLOOD! Immediate evacuation required.';
    }
  }
}

class _DetailTile extends StatelessWidget {
  const _DetailTile({
    required this.label,
    required this.value,
    required this.color,
  });
  final String label, value;
  final Color color;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withValues(alpha: 0.20)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: color)),
              Text(label,
                  style: const TextStyle(
                      fontSize: 9, color: AppPalette.textGrey)),
            ],
          ),
        ),
      );
}

// ── Level Fill Bar (unused — kept for future use) ─────────────────────────────
// ignore: unused_element
class _LevelFillBar extends StatelessWidget {
  const _LevelFillBar({
    required this.fillPct,
    required this.warnPct,
    required this.color,
  });
  final double fillPct, warnPct;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (_, box) {
      return Stack(
        children: [
          Container(
            height: 7,
            decoration: BoxDecoration(
              color: AppPalette.abyss4,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          // Warning marker
          Positioned(
            left: box.maxWidth * warnPct - 1,
            top: 0, bottom: 0,
            child: Container(
              width: 2,
              color: AppPalette.amber.withValues(alpha: 0.70),
            ),
          ),
          // Fill
          FractionallySizedBox(
            widthFactor: fillPct.clamp(0.0, 1.0),
            child: Container(
              height: 7,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [color.withValues(alpha: 0.55), color],
                ),
                borderRadius: BorderRadius.circular(4),
                boxShadow: [
                  BoxShadow(
                      color: color.withValues(alpha: 0.40),
                      blurRadius: 6),
                ],
              ),
            ),
          ),
        ],
      );
    });
  }
}

// ── Status Circle (with optional pulse animation) ─────────────────────────────
class _StatusCircle extends StatefulWidget {
  const _StatusCircle({
    required this.icon,
    required this.color,
    required this.pulse,
  });
  final IconData icon;
  final Color color;
  final bool pulse;

  @override
  State<_StatusCircle> createState() => _StatusCircleState();
}

class _StatusCircleState extends State<_StatusCircle>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    _anim = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
    if (widget.pulse) _ctrl.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(_StatusCircle old) {
    super.didUpdateWidget(old);
    if (widget.pulse && !_ctrl.isAnimating) {
      _ctrl.repeat(reverse: true);
    } else if (!widget.pulse && _ctrl.isAnimating) {
      _ctrl.stop();
      _ctrl.value = 1.0;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _anim,
      child: Container(
        width: 42, height: 42,
        decoration: BoxDecoration(
          color: widget.color.withValues(alpha: 0.12),
          shape: BoxShape.circle,
          border: Border.all(
            color: widget.color.withValues(alpha: 0.40),
            width: 1.5,
          ),
        ),
        child: Icon(widget.icon, color: widget.color, size: 20),
      ),
    );
  }
}

// ── District chip ─────────────────────────────────────────────────────────────
class _DistrictChip extends StatelessWidget {
  final String district;
  const _DistrictChip({required this.district});
  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.location_city_outlined,
              size: 9, color: AppPalette.textDim),
          const SizedBox(width: 3),
          Text(
            district,
            style: const TextStyle(
              color:      AppPalette.textDim,
              fontSize:   9,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
        ],
      );
}

// ── Source badge ──────────────────────────────────────────────────────────────
class _SourceBadge extends StatelessWidget {
  final String source;
  const _SourceBadge({required this.source});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (source.toUpperCase()) {
      'LIVE' || 'TELEMETRY' || 'LIVE_LEVELS' || 'CWC_FFS' || 'BULK' =>
        ('● LIVE', AppPalette.safe),
      'SAT' || 'GLOFAS' =>
        ('🛰 SAT', const Color(0xFF818CF8)),
      'NO_DATA' =>
        ('NO DATA', AppPalette.textGrey),
      _ =>
        ('◉ EST', AppPalette.amber),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Text(
        label,
        style: TextStyle(
            color: color, fontSize: 8, fontWeight: FontWeight.w800),
      ),
    );
  }
}

// ── Status chip ───────────────────────────────────────────────────────────────
class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;
  const _StatusChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: color.withValues(alpha: 0.38)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 9,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.3,
          ),
        ),
      );
}

// ── Trend chip (unused — kept for future use) ─────────────────────────────────
// ignore: unused_element
class _TrendChip extends StatelessWidget {
  final String trend;
  const _TrendChip({required this.trend});
  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (trend.toUpperCase()) {
      'RISING'  => ('↑', AppPalette.critical),
      'FALLING' => ('↓', AppPalette.safe),
      _         => ('→', AppPalette.amber),
    };
    return Text(
      icon,
      style: TextStyle(
        color:    color,
        fontSize: 14,
        fontWeight: FontWeight.w900,
      ),
    );
  }
}
