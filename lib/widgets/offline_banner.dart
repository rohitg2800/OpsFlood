// lib/widgets/offline_banner.dart
// Global offline / cache / waking-up persistent banner.
// Drop this anywhere in a scaffold via:
//
//   Column(children: [
//     const OfflineBanner(),
//     Expanded(child: yourBody),
//   ])
//
// Or wrap a Scaffold body:
//   body: Column(children: [const OfflineBanner(), Expanded(child: ...)]),

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../providers/flood_providers.dart';

class OfflineBanner extends ConsumerWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOffline    = ref.watch(isOfflineProvider);
    final isWakingUp   = ref.watch(isWakingUpProvider);
    final isUsingCache = ref.watch(realTimeProvider).isUsingCache;
    final lastFetch    = ref.watch(lastFetchTimeProvider);
    final error        = ref.watch(errorMessageProvider);

    // Nothing to show when live and fresh
    if (!isOffline && !isWakingUp && !isUsingCache && error == null) {
      return const SizedBox.shrink();
    }

    String message;
    Color  color;
    IconData icon;

    if (isOffline) {
      icon    = Icons.wifi_off_rounded;
      color   = const Color(0xFFEA580C); // orange
      final ago = lastFetch == null
          ? ''
          : ' \u00B7 cached ${_ago(lastFetch)}';
      message = 'No internet connection$ago';
    } else if (isWakingUp) {
      icon    = Icons.cloud_sync_outlined;
      color   = const Color(0xFF00C2DE); // cyan
      message = 'Connecting to OpsFlood backend\u2026';
    } else if (isUsingCache) {
      icon    = Icons.history_rounded;
      color   = const Color(0xFFF59E0B); // yellow
      final ago = lastFetch == null ? '' : ' from ${_ago(lastFetch)} ago';
      message = 'Showing cached data$ago';
    } else {
      icon    = Icons.warning_amber_rounded;
      color   = const Color(0xFFF59E0B);
      message = error ?? 'Data may be stale';
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      color: color.withOpacity(0.13),
      child: Row(
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                  color: color,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600),
            ),
          ),
          if (isOffline || isUsingCache)
            GestureDetector(
              onTap: () =>
                  ref.read(realTimeProvider).refreshData(forceOnlineAttempt: true),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: color.withOpacity(0.5)),
                ),
                child: Text('Retry',
                    style: TextStyle(
                        color: color,
                        fontSize: 10,
                        fontWeight: FontWeight.w700)),
              ),
            ),
        ],
      ),
    );
  }

  static String _ago(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 1)  return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    return DateFormat('HH:mm').format(t);
  }
}
