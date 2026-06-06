// lib/widgets/station_status_strip.dart
// Dashboard Live Status Strip — counts by FloodSeverity bucket.
// API used by river_monitor_screen.dart:
//   StationStatusStrip(
//     counts:     Map<FloodSeverity, int>,
//     lastSynced: DateTime?,
//     isLoading:  bool,
//     onTap:      void Function(FloodSeverity)?,
//   )
import 'package:flutter/material.dart';
import '../theme/river_theme.dart';
import '../utils/flood_severity.dart';

class StationStatusStrip extends StatelessWidget {
  final Map<FloodSeverity, int> counts;
  final DateTime? lastSynced;
  final bool      isLoading;
  final void Function(FloodSeverity)? onTap;

  const StationStatusStrip({
    super.key,
    required this.counts,
    this.lastSynced,
    this.isLoading = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppPalette.abyss2,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppPalette.abyssStroke, width: 1),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _Chip(
            count: counts[FloodSeverity.normal]  ?? 0,
            label: 'Normal',
            color: AppPalette.safe,
            isLoading: isLoading,
            onTap: onTap != null ? () => onTap!(FloodSeverity.normal) : null,
          ),
          _Vr(),
          _Chip(
            count: counts[FloodSeverity.watch]   ?? 0,
            label: 'Watch',
            color: AppPalette.cyan,
            isLoading: isLoading,
            onTap: onTap != null ? () => onTap!(FloodSeverity.watch) : null,
          ),
          _Vr(),
          _Chip(
            count: counts[FloodSeverity.warning] ?? 0,
            label: 'Warning',
            color: AppPalette.warning,
            isLoading: isLoading,
            onTap: onTap != null ? () => onTap!(FloodSeverity.warning) : null,
          ),
          _Vr(),
          _Chip(
            count: counts[FloodSeverity.danger]  ?? 0,
            label: 'Danger',
            color: AppPalette.danger,
            isLoading: isLoading,
            onTap: onTap != null ? () => onTap!(FloodSeverity.danger) : null,
          ),
          _Vr(),
          _Chip(
            count: counts[FloodSeverity.extreme] ?? 0,
            label: 'Extreme',
            color: AppPalette.critical,
            isLoading: isLoading,
            onTap: onTap != null ? () => onTap!(FloodSeverity.extreme) : null,
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final int    count;
  final String label;
  final Color  color;
  final bool   isLoading;
  final VoidCallback? onTap;

  const _Chip({
    required this.count,
    required this.label,
    required this.color,
    required this.isLoading,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          isLoading
              ? Container(
                  width: 28,
                  height: 20,
                  decoration: BoxDecoration(
                    color: AppPalette.abyss3,
                    borderRadius: BorderRadius.circular(4),
                  ),
                )
              : Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: color,
                    height: 1.1,
                  ),
                ),
          const SizedBox(height: 3),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              color: AppPalette.textGrey,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _Vr extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        width: 1, height: 30,
        color: AppPalette.abyssStroke,
      );
}
