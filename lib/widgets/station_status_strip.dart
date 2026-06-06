import 'package:flutter/material.dart';
import '../providers/station_status_provider.dart';
import '../utils/flood_severity.dart';

/// Resolves issue #12: Dashboard Live Status Strip
/// Shows counts of Normal/Watch/Danger/Offline stations
class StationStatusStrip extends StatelessWidget {
  final StationStatusProvider provider;

  const StationStatusStrip({super.key, required this.provider});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 4,
              offset: const Offset(0, 2))
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _StatusCount(
            count: provider.normalCount,
            label: 'Normal',
            color: FloodSeverityColor.normal,
          ),
          _Divider(),
          _StatusCount(
            count: provider.watchCount,
            label: 'Watch',
            color: FloodSeverityColor.watch,
          ),
          _Divider(),
          _StatusCount(
            count: provider.dangerCount,
            label: 'Danger',
            color: FloodSeverityColor.danger,
          ),
          _Divider(),
          _StatusCount(
            count: provider.offlineCount,
            label: 'Offline',
            color: FloodSeverityColor.offline,
          ),
        ],
      ),
    );
  }
}

class _StatusCount extends StatelessWidget {
  final int count;
  final String label;
  final Color color;

  const _StatusCount(
      {required this.count, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$count',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Colors.grey),
        ),
      ],
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: 32, color: Colors.grey.withOpacity(0.3));
}
