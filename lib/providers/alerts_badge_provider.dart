// lib/providers/alerts_badge_provider.dart  v2.0
//
// v2.0 (Problem-3 fix, 12 Jun 2026):
//   BEFORE: criticalAlertCountProvider watched biharLiveProvider (old
//   WRD-only legacy pipeline) and summed isCritical station counts.
//   MainShell imports ONLY this file, so the nav-bar badge was driven by
//   stale WRD data — NOT the AlertEngine output that the Alerts tab shows.
//
//   AFTER: criticalAlertCountProvider watches alertCountProvider
//   (= total active FloodAlert objects from alertsProvider, which is driven
//   by mergedStationsProvider via AlertEngine.evaluateMerged).
//   Badge count now matches exactly what the Alerts tab renders.
//
//   IMD alert and NDMA advisory counts are still added on top so that
//   external-source alerts also light the badge.
//
//   MainShell and _NavBar require ZERO changes — same provider name,
//   same import path, same int type.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/real_time_service.dart';
import 'data_fetch_provider.dart';

// ── 1. AlertEngine active alert count (merged, deduped) ────────────────────
//
// alertCountProvider (data_fetch_provider.dart) = alertsProvider.length
// alertsProvider    = AlertEngine.evaluateMerged(mergedStationsProvider)
// One station → at most one level alert → badge count matches Alerts tab.

final _alertEngineCountProvider = Provider<int>((ref) {
  return ref.watch(alertCountProvider);
});

// ── 2. IMD alert count ─────────────────────────────────────────────────────

final _imdAlertCountProvider = Provider<int>((ref) {
  final svc = RealTimeService();
  return svc.imdAlerts.length;
});

// ── 3. NDMA advisory count ───────────────────────────────────────────────

final _ndmaAdvisoryCountProvider = Provider<int>((ref) {
  final svc = RealTimeService();
  return svc.ndmaAdvisories.length;
});

// ── Combined badge count ───────────────────────────────────────────────────
//
// = AlertEngine active alerts + IMD alerts + NDMA advisories.
// Watched by MainShell → _NavBar to render the red dot on the Alerts tab.

final criticalAlertCountProvider = Provider<int>((ref) {
  final engine = ref.watch(_alertEngineCountProvider);
  final imd    = ref.watch(_imdAlertCountProvider);
  final ndma   = ref.watch(_ndmaAdvisoryCountProvider);
  return engine + imd + ndma;
});
