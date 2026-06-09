// lib/providers/alerts_badge_provider.dart
// Derives a live count of CRITICAL / DANGER alerts from biharLiveProvider.
// MainShell reads this to render the red dot badge on the Alerts tab.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'bihar_live_provider.dart';

/// Number of stations currently at CRITICAL or DANGER level.
final criticalAlertCountProvider = Provider<int>((ref) {
  final liveAsync = ref.watch(biharLiveProvider);
  return liveAsync.when(
    data: (data) {
      if (data == null) return 0;
      return data.stations.where((s) {
        final risk = s.riskLevel.toUpperCase();
        return risk == 'CRITICAL' || risk == 'DANGER';
      }).length;
    },
    loading: () => 0,
    error: (_, __) => 0,
  );
});
