// lib/providers/alerts_provider.dart
//
// OpsFlood — AlertsProvider (Riverpod)
//
// Manages WRD Bihar gauge-breach alerts only.
// IMD / SACHET / GloFAS removed — all data comes from kBiharGauges
// via ThresholdAlertService which calls the OpsFlood backend.
library;

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/threshold_alert.dart';
import '../services/threshold_alert_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Riverpod providers
// ─────────────────────────────────────────────────────────────────────────────

/// Primary provider.
final alertsProvider = ChangeNotifierProvider<AlertsProvider>((ref) {
  final provider = AlertsProvider();
  Future.microtask(() => ThresholdAlertService.instance.start());
  return provider;
});

/// All active (non-normal) alerts, sorted severe-first.
final activeAlertsProvider = Provider<List<ThresholdAlert>>((ref) {
  return ref.watch(alertsProvider).active;
});

/// Only danger + extreme alerts.
final criticalAlertsRiverProvider = Provider<List<ThresholdAlert>>((ref) {
  return ref.watch(alertsProvider).critical;
});

/// Unread badge count.
final alertBadgeCountProvider = Provider<int>((ref) {
  return ref.watch(alertsProvider).badgeCount;
});

/// Loading state.
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

  List<ThresholdAlert> _alerts  = [];
  bool    _loading = false;
  String? _error;

  // ── Getters ───────────────────────────────────────────────────────────────

  List<ThresholdAlert> get all      => _alerts;
  List<ThresholdAlert> get active   =>
      _alerts.where((a) => a.level != AlertLevel.normal).toList();
  List<ThresholdAlert> get critical =>
      _alerts.where((a) => a.level.requiresEmergency).toList();
  int                  get badgeCount => ThresholdAlertService.instance.unreadCount;
  bool                 get loading    => _loading;
  String?              get error      => _error;

  // ── Filter ────────────────────────────────────────────────────────────────

  AlertLevel? _filterLevel;
  String?     _filterRiver;
  String?     _filterDistrict;

  AlertLevel? get filterLevel    => _filterLevel;
  String?     get filterRiver    => _filterRiver;
  String?     get filterDistrict => _filterDistrict;

  List<ThresholdAlert> get filtered => _alerts.where((a) {
    if (_filterLevel    != null && a.level  != _filterLevel)    return false;
    if (_filterRiver    != null && a.river  != _filterRiver)    return false;
    // district is carried in ThresholdAlert.state field for Bihar gauges
    if (_filterDistrict != null && a.state  != _filterDistrict) return false;
    return true;
  }).toList();

  void setFilterLevel(AlertLevel? v)  { _filterLevel    = v; notifyListeners(); }
  void setFilterRiver(String? v)      { _filterRiver    = v; notifyListeners(); }
  void setFilterDistrict(String? v)   { _filterDistrict = v; notifyListeners(); }
  void clearFilters() {
    _filterLevel = null; _filterRiver = null; _filterDistrict = null;
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
    notifyListeners();
  }

  // ── Stream listener ───────────────────────────────────────────────────────

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
