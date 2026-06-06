// lib/providers/alerts_provider.dart
//
// OpsFlood — AlertsProvider (Riverpod v3)
//
// Riverpod v3 removed ChangeNotifierProvider.
// Migrated to a plain ChangeNotifier exposed via ChangeNotifierProvider
// shim — but since that's also gone, we use a Notifier<AlertsState>
// pattern with a thin facade for backward-compat getters.
library;

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/threshold_alert.dart';
import '../models/imd_alert.dart';
import '../services/threshold_alert_service.dart';
import 'flood_providers.dart';

// ── State model ──────────────────────────────────────────────────────────────
class AlertsState {
  final List<ThresholdAlert> cwcAlerts;
  final List<ImdAlert>       imdAlerts;
  final bool                 loading;
  final String?              error;

  const AlertsState({
    this.cwcAlerts = const [],
    this.imdAlerts = const [],
    this.loading   = false,
    this.error,
  });

  AlertsState copyWith({
    List<ThresholdAlert>? cwcAlerts,
    List<ImdAlert>?       imdAlerts,
    bool?                 loading,
    String?               error,
  }) => AlertsState(
    cwcAlerts: cwcAlerts ?? this.cwcAlerts,
    imdAlerts: imdAlerts ?? this.imdAlerts,
    loading:   loading   ?? this.loading,
    error:     error,
  );

  List<ThresholdAlert> get active   => cwcAlerts.where((a) => a.level != AlertLevel.normal).toList();
  List<ThresholdAlert> get critical => cwcAlerts.where((a) => a.level.requiresEmergency).toList();
  int get badgeCount => ThresholdAlertService.instance.unreadCount;
}

// ── Notifier ───────────────────────────────────────────────────────────────────
class AlertsNotifier extends Notifier<AlertsState> {
  StreamSubscription<List<ThresholdAlert>>? _sub;

  @override
  AlertsState build() {
    Future.microtask(() => ThresholdAlertService.instance.start());

    _sub = ThresholdAlertService.instance.stream.listen((alerts) {
      state = state.copyWith(cwcAlerts: alerts, loading: false);
    });

    // Watch imdAlertsProvider and push into state
    ref.listen<List<dynamic>>(imdAlertsProvider, (_, rawList) {
      ingestImdAlerts(rawList);
    });

    ref.onDispose(() => _sub?.cancel());

    return AlertsState(
      cwcAlerts: List.of(ThresholdAlertService.instance.currentAlerts),
    );
  }

  void ingestImdAlerts(List<dynamic> rawList) {
    if (rawList.isEmpty) return;
    final parsed = rawList.map(ImdAlert.fromRaw).toList()
      ..sort((a, b) => b.severity.order.compareTo(a.severity.order));
    final existing = {for (final a in state.imdAlerts) a.id: a};
    final merged   = parsed.map((a) {
      final old = existing[a.id];
      return old != null ? a.copyWith(isNew: false) : a;
    }).toList();
    state = state.copyWith(imdAlerts: merged);
  }

  Future<void> refresh() async {
    state = state.copyWith(loading: true);
    try {
      await ThresholdAlertService.instance.refresh();
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
      if (kDebugMode) debugPrint('[AlertsNotifier] refresh error: $e');
    }
  }

  Future<void> markAllSeen() async {
    await ThresholdAlertService.instance.markAllSeen();
    state = state.copyWith(
      imdAlerts: state.imdAlerts.map((a) => a.copyWith(isNew: false)).toList(),
    );
  }

  // ── Filter helpers (CWC tab) ───────────────────────────────────────────────
  AlertLevel? _filterLevel;
  String?     _filterState;
  void setFilterLevel(AlertLevel? l) { _filterLevel = l; state = state.copyWith(); }
  void setFilterState(String? s)     { _filterState = s; state = state.copyWith(); }
  void clearFilters()                { _filterLevel = null; _filterState = null; state = state.copyWith(); }

  List<ThresholdAlert> get filtered => state.cwcAlerts.where((a) {
    if (_filterLevel != null && a.level != _filterLevel) return false;
    if (_filterState != null && a.state != _filterState) return false;
    return true;
  }).toList();
}

// ── Providers ──────────────────────────────────────────────────────────────────
final alertsProvider =
    NotifierProvider<AlertsNotifier, AlertsState>(AlertsNotifier.new);

final activeAlertsProvider = Provider<List<ThresholdAlert>>((ref) {
  return ref.watch(alertsProvider).active;
});

final criticalAlertsRiverProvider = Provider<List<ThresholdAlert>>((ref) {
  return ref.watch(alertsProvider).critical;
});

final alertBadgeCountProvider = Provider<int>((ref) {
  return ref.watch(alertsProvider).badgeCount;
});

final alertsLoadingProvider = Provider<bool>((ref) {
  return ref.watch(alertsProvider).loading;
});

final parsedImdAlertsProvider = Provider<List<ImdAlert>>((ref) {
  return ref.watch(alertsProvider).imdAlerts;
});

// ── Backward-compat facade so callers using .active/.badgeCount still work ──
// Any file that does: ref.watch(alertsProvider).active
// still works because AlertsState exposes .active etc.

/// Legacy type alias so screens that typed AlertsProvider still compile.
typedef AlertsProvider = AlertsNotifier;
