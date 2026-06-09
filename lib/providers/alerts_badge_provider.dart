// lib/providers/alerts_badge_provider.dart
// Derives a live total badge count from THREE sources:
//   1. biharLiveProvider  — WRD gauge stations at CRITICAL / DANGER level
//   2. RealTimeService    — IMD active alerts list
//   3. RealTimeService    — NDMA active advisories list
// MainShell reads criticalAlertCountProvider to render the red dot badge
// on the Alerts tab.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/real_time_service.dart';
import 'bihar_live_provider.dart';

// ── 1. WRD Bihar critical station count ──────────────────────────────────────
final _wrdCriticalCountProvider = Provider<int>((ref) {
  return ref.watch(biharLiveProvider).when(
    data:    (data) => data.stations.where((s) => s.isCritical).length,
    loading: () => 0,
    error:   (_, __) => 0,
  );
});

// ── 2. IMD alert count ────────────────────────────────────────────────────────
final _imdAlertCountProvider = Provider<int>((ref) {
  final svc = RealTimeService();
  return svc.imdAlerts.length;
});

// ── 3. NDMA advisory count ───────────────────────────────────────────────────
final _ndmaAdvisoryCountProvider = Provider<int>((ref) {
  final svc = RealTimeService();
  return svc.ndmaAdvisories.length;
});

// ── Combined badge count (all three sources) ──────────────────────────────────
/// Total badge count = WRD critical stations + IMD alerts + NDMA advisories.
/// Shown as the red dot on the Alerts tab in MainShell.
final criticalAlertCountProvider = Provider<int>((ref) {
  final wrd  = ref.watch(_wrdCriticalCountProvider);
  final imd  = ref.watch(_imdAlertCountProvider);
  final ndma = ref.watch(_ndmaAdvisoryCountProvider);
  return wrd + imd + ndma;
});
