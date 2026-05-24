// lib/providers/alerts_provider.dart
//
// OpsFlood — AlertsProvider (Riverpod)
//
// Wraps ThresholdAlertService as a Riverpod ChangeNotifierProvider,
// matching the pattern used by realTimeProvider in flood_providers.dart.
library;

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/threshold_alert.dart';
import '../services/threshold_alert_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Top-level Riverpod providers — importable anywhere via ref.watch / ref.read
// ─────────────────────────────────────────────────────────────────────────────

/// Primary provider — exposes the full AlertsProvider notifier.
final alertsProvider = ChangeNotifierProvider<AlertsProvider>((ref) {
  final provider = AlertsProvider();
  // Ensure the service is started (idempotent — safe to call twice).
  Future.microtask(() => ThresholdAlertService.instance.start());
  return provider;
});

/// Derived: all active (non-normal) alerts, sorted severe-first.
final activeAlertsProvider = Provider<List<ThresholdAlert>>((ref) {
  return ref.watch(alertsProvider).active;
});

/// Derived: only danger + extreme alerts.
final criticalAlertsRiverProvider = Provider<List<ThresholdAlert>>((ref) {
  return ref.watch(alertsProvider).critical;
});

/// Derived: unread badge count.
final alertBadgeCountProvider = Provider<int>((ref) {
  return ref.watch(alertsProvider).badgeCount;
});

/// Derived: loading state.
final alertsLoadingProvider = Provider<bool>((ref) {
  return ref.watch(alertsProvider).loading;
});

// ─────────────────────────────────────────────────────────────────────────────
// AlertsProvider — ChangeNotifier
// ─────────────────────────────────────────────────────────────────────────────

class AlertsProvider extends ChangeNotifier {
  AlertsProvider() {
    _sub = ThresholdAlertService.instance.stream.listen(_onAlerts);
    _alerts = List.of(ThresholdAlertService.instance.currentAlerts);
  }

  StreamSubscription<List<ThresholdAlert>>? _sub;
  List<ThresholdAlert> _alerts = [];
  bool    _loading = false;
  String? _error;

  // ─── Public read state ───────────────────────────────────────────────────
  List<ThresholdAlert> get all      => _alerts;
  List<ThresholdAlert> get active   => _alerts.where((a) => a.level != AlertLevel.normal).toList();
  List<ThresholdAlert> get critical => _alerts.where((a) => a.level.requiresEmergency).toList();
  int                  get badgeCount => ThresholdAlertService.instance.unreadCount;
  bool                 get loading  => _loading;
  String?              get error    => _error;

  // ─── Filter state ────────────────────────────────────────────────────────
  AlertLevel? _filterLevel;
  String?     _filterState;

  AlertLevel? get filterLevel => _filterLevel;
  String?     get filterState => _filterState;

  List<ThresholdAlert> get filtered => _alerts.where((a) {
    if (_filterLevel != null && a.level != _filterLevel) return false;
    if (_filterState != null && a.state != _filterState) return false;
    return true;
  }).toList();

  void setFilterLevel(AlertLevel? level) { _filterLevel = level; notifyListeners(); }
  void setFilterState(String? state)     { _filterState = state; notifyListeners(); }
  void clearFilters()                    { _filterLevel = null; _filterState = null; notifyListeners(); }

  // ─── Actions ─────────────────────────────────────────────────────────────

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
    notifyListeners();
  }

  // ─── Internal stream listener ──────────────────────────────────────────────

  void _onAlerts(List<ThresholdAlert> alerts) {
    _alerts  = List.of(alerts);
    _loading = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
