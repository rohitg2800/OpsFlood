// ─────────────────────────────────────────────────────────────────────────────
//  StationStatusStrip  —  Live summary bar for the dashboard
//  Shows: Normal / Watch / Warning / Danger / Extreme counts + last sync time
//  Usage:
//    StationStatusStrip(
//      counts: {FloodSeverity.normal: 42, FloodSeverity.danger: 3, ...},
//      lastSynced: DateTime.now(),
//      onTap: (severity) => navigateToFilteredList(severity),
//    )
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import '../theme/river_theme.dart';
import '../utils/flood_severity_helper.dart';

class StationStatusStrip extends StatelessWidget {
  const StationStatusStrip({
    super.key,
    required this.counts,
    this.lastSynced,
    this.onTap,
    this.isLoading = false,
  });

  final Map<FloodSeverity, int> counts;
  final DateTime? lastSynced;
  final void Function(FloodSeverity)? onTap;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final rc = RiverColors.of(context);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: AppPalette.glassMorph(radius: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // LIVE dot
              _LiveDot(),
              const SizedBox(width: 6),
              Text(
                'LIVE STATIONS',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.4,
                  color: AppPalette.cyan,
                ),
              ),
              const Spacer(),
              if (lastSynced != null)
                Text(
                  _syncLabel(lastSynced!),
                  style: TextStyle(
                    fontSize: 10,
                    color: rc.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          isLoading
              ? _buildShimmerRow()
              : Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: FloodSeverity.values
                      .map((s) => _SeverityChip(
                            severity: s,
                            count: counts[s] ?? 0,
                            onTap: onTap != null ? () => onTap!(s) : null,
                          ))
                      .toList(),
                ),
        ],
      ),
    );
  }

  String _syncLabel(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60)  return 'Just now';
    if (diff.inMinutes < 60)  return '${diff.inMinutes}m ago';
    return '${diff.inHours}h ago';
  }

  Widget _buildShimmerRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: List.generate(
        5,
        (_) => Container(
          width: 48,
          height: 44,
          decoration: BoxDecoration(
            color: AppPalette.abyss3,
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    );
  }
}

class _SeverityChip extends StatelessWidget {
  const _SeverityChip({
    required this.severity,
    required this.count,
    this.onTap,
  });

  final FloodSeverity severity;
  final int count;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = FloodSeverityHelper.color(severity);
    final isAlert = severity == FloodSeverity.danger ||
        severity == FloodSeverity.extreme;
    final hasCount = count > 0;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: hasCount
              ? c.withValues(alpha: isAlert ? 0.18 : 0.10)
              : AppPalette.abyss3,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: hasCount ? c.withValues(alpha: 0.5) : AppPalette.abyssStroke,
            width: hasCount && isAlert ? 1.5 : 1.0,
          ),
          boxShadow: hasCount && isAlert
              ? [BoxShadow(color: c.withValues(alpha: 0.25), blurRadius: 8)]
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              FloodSeverityHelper.icon(severity),
              color: hasCount ? c : AppPalette.textDim,
              size: 16,
            ),
            const SizedBox(height: 3),
            Text(
              '$count',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: hasCount ? c : AppPalette.textDim,
                height: 1.0,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              FloodSeverityHelper.label(severity),
              style: TextStyle(
                fontSize: 8,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
                color: hasCount ? c.withValues(alpha: 0.85) : AppPalette.textDim,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LiveDot extends StatefulWidget {
  @override
  State<_LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends State<_LiveDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: _anim,
        child: Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            color: AppPalette.cyan,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(color: AppPalette.cyanGlow, blurRadius: 6),
            ],
          ),
        ),
      );
}
