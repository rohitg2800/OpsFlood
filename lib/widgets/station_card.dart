// lib/widgets/station_card.dart
// OpsFlood — StationCard v4  (district / zila added)
library;

import 'package:flutter/material.dart';
import '../theme/river_theme.dart';

class StationCard extends StatelessWidget {
  final String city;
  final String district;   // ← zila
  final String river;
  final String state;
  final double current;
  final double warning;
  final double danger;
  final String source;  // 'LIVE' | 'SAT' | 'EST' | 'NO_DATA'
  final String status;  // 'SAFE' | 'WARNING' | 'DANGER' | 'CRITICAL'
  final String? trend;  // 'RISING' | 'FALLING' | 'STEADY'
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

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
  });

  Color get _statusColor => AppPalette.statusColor(status);

  double get _fillPct => danger > 0
      ? (current / danger).clamp(0.0, 1.2)
      : 0.0;

  /// Sub-label under city: "Kosi · Supaul · Bihar"
  String get _subLabel {
    final parts = <String>[];
    if (river.isNotEmpty)    parts.add(river);
    if (district.isNotEmpty) parts.add(district);
    if (state.isNotEmpty)    parts.add(state);
    return parts.join('  ·  ');
  }

  @override
  Widget build(BuildContext context) {
    final col = _statusColor;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color:        AppPalette.abyss2,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: col.withValues(alpha: 0.25)),
          boxShadow: [
            BoxShadow(
              color:      col.withValues(alpha: 0.05),
              blurRadius: 16,
              offset:     const Offset(0, 4),
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
                            city,
                            style: const TextStyle(
                              color:      AppPalette.textWhite,
                              fontSize:   15,
                              fontWeight: FontWeight.w800,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        _SourceBadge(source: source),
                      ]),
                      const SizedBox(height: 2),
                      // River · District · State
                      Text(
                        _subLabel,
                        style: const TextStyle(
                          color:    AppPalette.textGrey,
                          fontSize: 11,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      // district chip only if non-empty
                      if (district.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        _DistrictChip(district: district),
                      ],
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${current.toStringAsFixed(2)} m',
                      style: TextStyle(
                        color:      col,
                        fontSize:   20,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                    _StatusChip(status: status, color: col),
                    if (onDelete != null) ...[
                      const SizedBox(height: 4),
                      GestureDetector(
                        onTap: onDelete,
                        child: const Icon(
                          Icons.remove_circle_outline,
                          size: 15, color: AppPalette.textDim,
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
              if (danger > 0 && warning > 0)
                Positioned(
                  left: (warning / danger).clamp(0.0, 1.0) *
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _mini('W ${warning.toStringAsFixed(1)} m', AppPalette.amber),
                _mini('D ${danger.toStringAsFixed(1)} m',  AppPalette.danger),
                _mini(
                  '${(_fillPct * 100).clamp(0, 120).toStringAsFixed(0)}%',
                  AppPalette.textGrey,
                ),
                if (trend != null)
                  _TrendChip(trend: trend!),
              ],
            ),
          ],
        ),
      ),
    );
  }

  IconData get _statusIcon {
    switch (status.toUpperCase()) {
      case 'CRITICAL': return Icons.crisis_alert_rounded;
      case 'DANGER':   return Icons.error_outline_rounded;
      case 'WARNING':  return Icons.warning_amber_rounded;
      default:         return Icons.check_circle_outline_rounded;
    }
  }

  Widget _mini(String t, Color c) => Text(
    t,
    style: TextStyle(
      color: c, fontSize: 9, fontWeight: FontWeight.w600),
  );
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
        color:        color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(6),
        border:       Border.all(color: color.withValues(alpha: 0.30)),
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
  final String status;
  final Color  color;
  const _StatusChip({required this.status, required this.color});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        margin:  const EdgeInsets.only(top: 4),
        decoration: BoxDecoration(
          color:        color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(7),
          border:       Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Text(
          status,
          style: TextStyle(
            color:      color,
            fontSize:   9,
            fontWeight: FontWeight.w800,
          ),
        ),
      );
}

// ── Trend chip ────────────────────────────────────────────────────────────────
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
