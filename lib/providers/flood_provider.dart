// lib/providers/flood_provider.dart
//
// OpsFlood — FloodProvider (Riverpod ChangeNotifier)
//
// Thin facade over the existing RealTimeService / realTimeProvider so that
// screens which import '../providers/flood_provider.dart' and call
// context.watch<FloodProvider>() / context.read<FloodProvider>() compile
// without touching the rest of the Riverpod provider graph.
//
// Usage in screens (with flutter_riverpod):
//
//   final fp = ref.watch(floodProviderInstance);
//
// Or — if the screen uses the legacy context.watch<FloodProvider>() pattern —
// wrap the subtree with a ChangeNotifierProvider<FloodProvider> in main.dart.

library;

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/flood_data.dart';
import '../models/river_monitoring.dart';
import '../services/real_time_service.dart';
import 'flood_providers.dart' show realTimeProvider;

// ─────────────────────────────────────────────────────────────────────────────
// Riverpod provider
// ─────────────────────────────────────────────────────────────────────────────

/// Riverpod entry-point.  Screens using ref.watch() should prefer this.
final floodProviderInstance =
    ChangeNotifierProvider<FloodProvider>((ref) {
  final svc = ref.watch(realTimeProvider);
  return FloodProvider._(svc);
});

// ─────────────────────────────────────────────────────────────────────────────
// FloodProvider — ChangeNotifier
// ─────────────────────────────────────────────────────────────────────────────

class FloodProvider extends ChangeNotifier {
  FloodProvider._(RealTimeService svc) : _svc = svc {
    _sub = svc.addListener(_onServiceChange, fireImmediately: false);
  }

  final RealTimeService _svc;
  VoidCallback? _sub;

  // ── Getters ───────────────────────────────────────────────────────────────

  /// All currently-live flood-level readings, sorted by capacity %.
  List<FloodData> get liveLevels =>
      List<FloodData>.from(_svc.liveLevels)
        ..sort((a, b) => b.capacityPercent.compareTo(a.capacityPercent));

  /// Stations at CRITICAL risk.
  List<FloodData> get critical =>
      liveLevels.where((d) => d.riskLevel == 'CRITICAL').toList();

  /// Stations at HIGH or CRITICAL risk.
  List<FloodData> get highRisk =>
      liveLevels
          .where((d) =>
              d.riskLevel == 'HIGH' || d.riskLevel == 'CRITICAL')
          .toList();

  /// Count of critical stations.
  int get criticalCount => critical.length;

  /// Count of high-risk stations.
  int get highRiskCount => highRisk.length;

  /// Total monitored station count.
  int get stationCount => liveLevels.length;

  /// Whether the service is currently online.
  bool get isOnline => _svc.isOnline;

  /// Timestamp of the most recent successful fetch.
  DateTime? get lastFetchTime => _svc.lastFetchTime;

  /// Returns the 24-h level history for [city].
  List<RiverLevelSnapshot> trendForCity(String city) =>
      _svc.trendForCity(city);

  // ── Actions ───────────────────────────────────────────────────────────────

  Future<void> refresh() => _svc.refreshData();

  // ── Internal ──────────────────────────────────────────────────────────────

  void _onServiceChange() => notifyListeners();

  @override
  void dispose() {
    // ChangeNotifier.removeListener is not stored as a sub in flutter;
    // listener was added via addListener which returns void, so we call
    // removeListener directly.
    _svc.removeListener(_onServiceChange);
    super.dispose();
  }
}
