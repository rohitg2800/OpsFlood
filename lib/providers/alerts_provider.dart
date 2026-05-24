// lib/providers/alerts_provider.dart
//
// OpsFlood — AlertsProvider
// ChangeNotifier that wraps ThresholdAlertService and exposes sorted,
// filtered alert state to the UI.
library;

import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/threshold_alert.dart';
import '../services/threshold_alert_service.dart';

class AlertsProvider extends ChangeNotifier {
  AlertsProvider() {
    _sub = ThresholdAlertService.instance.stream.listen(_onAlerts);
    // Seed from cache on construction
    _alerts = List.of(ThresholdAlertService.instance.currentAlerts);
  }

  StreamSubscription<List<ThresholdAlert>>? _sub;
  List<ThresholdAlert> _alerts = [];

  // ─── Public state ────────────────────────────────────────────────────────
  List<ThresholdAlert> get all      => _alerts;
  List<ThresholdAlert> get active   => _alerts.where((a) => a.level != AlertLevel.normal).toList();
  List<ThresholdAlert> get critical => _alerts.where((a) => a.level.requiresEmergency).toList();
  int                  get badgeCount => ThresholdAlertService.instance.unreadCount;

  bool _loading = false;
  bool get loading => _loading;

  String? _error;
  String? get error => _error;

  // ─── Filter state ────────────────────────────────────────────────────────
  AlertLevel?  _filterLevel;
  String?      _filterState;

  AlertLevel?  get filterLevel => _filterLevel;
  String?      get filterState => _filterState;

  List<ThresholdAlert> get filtered {
    return _alerts.where((a) {
      if (_filterLevel != null && a.level != _filterLevel) return false;
      if (_filterState != null && a.state != _filterState) return false;
      return true;
    }).toList();
  }

  void setFilterLevel(AlertLevel? level) {
    _filterLevel = level;
    notifyListeners();
  }

  void setFilterState(String? state) {
    _filterState = state;
    notifyListeners();
  }

  void clearFilters() {
    _filterLevel = null;
    _filterState = null;
    notifyListeners();
  }

  // ─── Actions ─────────────────────────────────────────────────────────────

  Future<void> refresh() async {
    _loading = true;
    _error   = null;
    notifyListeners();
    try {
      await ThresholdAlertService.instance.refresh();
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> markAllSeen() async {
    await ThresholdAlertService.instance.markAllSeen();
    notifyListeners();
  }

  // ─── Internals ────────────────────────────────────────────────────────────

  void _onAlerts(List<ThresholdAlert> alerts) {
    _alerts = List.of(alerts);
    _loading = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
