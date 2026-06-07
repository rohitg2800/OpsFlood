// lib/widgets/dashboard/command_header.dart
// Extracted from dashboard_screen.dart — top header with refresh button.
import 'package:flutter/material.dart';

class CommandHeader extends StatelessWidget {
  final Animation<double> pulseAnim;
  final Animation<double> shimmerAnim;
  final VoidCallback onRefresh;
  final DateTime? lastUpdated;

  const CommandHeader({
    super.key,
    required this.pulseAnim,
    required this.shimmerAnim,
    required this.onRefresh,
    this.lastUpdated,
  });

  @override
  Widget build(BuildContext context) {
    final updatedText = lastUpdated != null
        ? 'Updated ${_timeAgo(lastUpdated!)}'
        : 'Loading\u2026';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'OpsFlood',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  updatedText,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.white54,
                      ),
                ),
              ],
            ),
          ),
          AnimatedBuilder(
            animation: pulseAnim,
            builder: (_, child) => Opacity(
              opacity: pulseAnim.value,
              child: child,
            ),
            child: IconButton(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'Refresh data',
            ),
          ),
        ],
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    return '${diff.inHours}h ago';
  }
}
