// lib/providers/alerts_provider.dart
//
// OpsFlood — AlertsProvider (Riverpod)
//
// Manages BOTH:
//   • CWC gauge breach alerts  (ThresholdAlertService)
//   • IMD weather alerts       (LiveFetchEngine → imdAlertsProvider)
//
// IMD alerts are injected via ingestImdAlerts() which is called from the
// imdAlertsProvider watcher inside alertsProvider itself.
library;

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/threshold_alert.dart';
import '../models/imd_alert.dart';
import '../services/threshold_alert_service.dart';
import 'flood_providers.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Top-level Riverpod providers
// ─────────────────────────────────────────────────────────────────────────────

/// Primary provider — exposes the full AlertsProvider notifier.
final alertsProvider = ChangeNotifierProvider<AlertsProvider>((ref) {
  final provider = AlertsProvider();
  Future.microtask(() => ThresholdAlertService.instance.start());

  // Whenever raw IMD data changes in LiveFetchEngine, push it into AlertsProvider.
  ref.listen<List<dynamic>>(imdAlertsProvider, (_, rawList) {
    provider.ingestImdAlerts(rawList);
  });

  return provider;
});

/// Derived: all active (non-normal) CWC gauge alerts, sorted severe-first.
final activeAlertsProvider = Provider<List<ThresholdAlert>>((ref) {
  return ref.watch(alertsProvider).active;
});

/// Derived: only danger + extreme CWC alerts.
final criticalAlertsRiverProvider = Provider<List<ThresholdAlert>>((ref) {
  return ref.watch(alertsProvider).critical;
});

/// Derived: unread badge count (CWC only).
final alertBadgeCountProvider = Provider<int>((ref) {
  return ref.watch(alertsProvider).badgeCount;
});

/// Derived: loading state.
final alertsLoadingProvider = Provider<bool>((ref) {
  return ref.watch(alertsProvider).loading;
});

/// Derived: parsed IMD alerts list.
final parsedImdAlertsProvider = Provider<List<ImdAlert>>((ref) {
  return ref.watch(alertsProvider).imdAlerts;
});

// ─────────────────────────────────────────────────────────────────────────────
// AlertsProvider — ChangeNotifier
// ─────────────────────────────────────────────────────────────────────────────

class AlertsProvider extends ChangeNotifier {
  AlertsProvider() {
    _sub = ThresholdAlertService.instance.stream.listen(_onAlerts);
    _cwcAlerts = List.of(ThresholdAlertService.instance.currentAlerts);
  }

  StreamSubscription<List<ThresholdAlert>>? _sub;

  // ── CWC gauge alerts ──────────────────────────────────────────────────────
  List<ThresholdAlert> _cwcAlerts = [];
  bool    _loading = false;
  String? _error;

  List<ThresholdAlert> get all      => _cwcAlerts;
  List<ThresholdAlert> get active   => _cwcAlerts.where((a) => a.level != AlertLevel.normal).toList();
  List<ThresholdAlert> get critical => _cwcAlerts.where((a) => a.level.requiresEmergency).toList();
  int                  get badgeCount => ThresholdAlertService.instance.unreadCount;
  bool                 get loading  => _loading;
  String?              get error    => _error;

  // ── Filter state (CWC tab) ────────────────────────────────────────────────
  AlertLevel? _filterLevel;
  String?     _filterState;

  AlertLevel? get filterLevel => _filterLevel;
  String?     get filterState => _filterState;

  List<ThresholdAlert> get filtered => _cwcAlerts.where((a) {
    if (_filterLevel != null && a.level != _filterLevel) return false;
    if (_filterState != null && a.state != _filterState) return false;
    return true;
  }).toList();

  void setFilterLevel(AlertLevel? level) { _filterLevel = level; notifyListeners(); }
  void setFilterState(String? state)     { _filterState = state; notifyListeners(); }
  void clearFilters()                    { _filterLevel = null; _filterState = null; notifyListeners(); }

  // ── IMD weather alerts ────────────────────────────────────────────────────
  List<ImdAlert> _imdAlerts = [];
  List<ImdAlert> get imdAlerts => _imdAlerts;

  /// Called by the Riverpod listener in alertsProvider whenever
  /// LiveFetchEngine publishes a fresh imdAlerts list.
  void ingestImdAlerts(List<dynamic> rawList) {
    if (rawList.isEmpty) return;
    final parsed = rawList.map(ImdAlert.fromRaw).toList()
      ..sort((a, b) => b.severity.order.compareTo(a.severity.order));
    // Deduplicate by id; mark existing as not-new.
    final existing = { for (final a in _imdAlerts) a.id: a };
    _imdAlerts = parsed.map((a) {
      final old = existing[a.id];
      return old != null ? a.copyWith(isNew: false) : a;
    }).toList();
    notifyListeners();
  }

  // ── Actions ───────────────────────────────────────────────────────────────

  Future<void> refresh() async {
    _loading = true;
    _error   = null;
    notifyListeners();
    try {
      await ThresholdAlertService.instance.refresh();
    } catch (e) {
      _error = e.toString();
      if (kDebugMode) debugPrint('[AlertsProvider] refresh error: $e');
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> markAllSeen() async {
    await ThresholdAlertService.instance.markAllSeen();
    _imdAlerts = _imdAlerts.map((a) => a.copyWith(isNew: false)).toList();
    notifyListeners();
  }

  // ── Internal stream listener ───────────────────────────────────────────────

  void _onAlerts(List<ThresholdAlert> alerts) {
    _cwcAlerts = List.of(alerts);
    _loading   = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
