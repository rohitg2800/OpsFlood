// lib/providers/alert_provider.dart
//
// OpsFlood — AlertProvider (Riverpod ChangeNotifier)
//
// Facade over the existing AlertsProvider / ThresholdAlertService so that
// screens importing '../providers/alert_provider.dart' compile.
//
// Exposes the same interface the error log expects:
//   ap.dangerCount   — number of active danger/extreme alerts
//   ap.warningCount  — number of active warning alerts
//   ap.all           — every active (non-normal) FloodAlert
//   ap.danger        — danger + extreme FloodAlerts
//   ap.warnings      — warning FloodAlerts

library;

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/flood_alert.dart';
import '../models/threshold_alert.dart' as ta;
import '../services/threshold_alert_service.dart';
import 'alerts_provider.dart' show alertsProvider;

// ─────────────────────────────────────────────────────────────────────────────
// Riverpod provider
// ─────────────────────────────────────────────────────────────────────────────

final alertProviderInstance =
    ChangeNotifierProvider<AlertProvider>((ref) {
  final ap = AlertProvider._();
  // Keep in sync with the canonical AlertsProvider.
  ref.listen<List<ta.ThresholdAlert>>(
    alertsProvider.select((p) => p.all),
    (_, next) => ap._onAlerts(next),
    fireImmediately: true,
  );
  return ap;
});

// ─────────────────────────────────────────────────────────────────────────────
// AlertProvider — ChangeNotifier
// ─────────────────────────────────────────────────────────────────────────────

class AlertProvider extends ChangeNotifier {
  AlertProvider._() {
    // Subscribe directly to the service stream as a fallback so this
    // provider works even when used outside Riverpod (e.g. via Provider pkg).
    _sub = ThresholdAlertService.instance.stream.listen(_onAlerts);
    _onAlerts(ThresholdAlertService.instance.currentAlerts);
  }

  StreamSubscription<List<ta.ThresholdAlert>>? _sub;
  List<FloodAlert> _alerts = [];

  // ── Getters ───────────────────────────────────────────────────────────────

  /// All non-normal alerts.
  List<FloodAlert> get all => _alerts;

  /// Danger + extreme alerts only.
  List<FloodAlert> get danger =>
      _alerts.where((a) => a.level == AlertLevel.danger ||
                           a.level == AlertLevel.extreme).toList();

  /// Warning alerts only.
  List<FloodAlert> get warnings =>
      _alerts.where((a) => a.level == AlertLevel.warning).toList();

  int get dangerCount  => danger.length;
  int get warningCount => warnings.length;
  int get totalCount   => _alerts.length;

  bool get hasCritical => danger.isNotEmpty;

  // ── Actions ───────────────────────────────────────────────────────────────

  Future<void> refresh() => ThresholdAlertService.instance.refresh();

  Future<void> markAllSeen() async {
    await ThresholdAlertService.instance.markAllSeen();
    notifyListeners();
  }

  // ── Internal ──────────────────────────────────────────────────────────────

  void _onAlerts(List<ta.ThresholdAlert> raw) {
    _alerts = raw
        .where((a) => a.level != ta.AlertLevel.normal)
        .map(_toFloodAlert)
        .toList()
      ..sort((a, b) => b.level.index.compareTo(a.level.index));
    notifyListeners();
  }

  static FloodAlert _toFloodAlert(ta.ThresholdAlert src) {
    return FloodAlert(
      id:           src.stationId,
      station:      src.station,
      river:        src.river,
      district:     src.district,
      state:        src.state,
      currentLevel: src.currentLevel,
      dangerLevel:  src.dangerLevel,
      warningLevel: src.warningLevel,
      level:        _mapLevel(src.level),
      issuedAt:     src.updatedAt,
      message:      src.message,
    );
  }

  static AlertLevel _mapLevel(ta.AlertLevel l) {
    switch (l) {
      case ta.AlertLevel.warning: return AlertLevel.warning;
      case ta.AlertLevel.danger:  return AlertLevel.danger;
      case ta.AlertLevel.extreme: return AlertLevel.extreme;
      default:                    return AlertLevel.normal;
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
