// lib/services/threshold_alert_service.dart
// EQUINOX-BH — Polls GloFAS for Bihar cities and fires FCM-style local
// alerts when river discharge crosses WARNING or DANGER thresholds.
library;

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'live_fetch_engine.dart';

class ThresholdAlertService {
  ThresholdAlertService._();
  static final ThresholdAlertService instance = ThresholdAlertService._();

  final LiveFetchEngine _engine = LiveFetchEngine();
  Timer? _timer;
  bool   _running = false;

  static const _checkInterval = Duration(minutes: 10);

  Future<void> start() async {
    if (_running) return;
    _running = true;
    if (kDebugMode) debugPrint('[ThresholdAlertService] started');
    await _check();
    _timer = Timer.periodic(_checkInterval, (_) => _check());
  }

  void stop() {
    _timer?.cancel();
    _timer   = null;
    _running = false;
    if (kDebugMode) debugPrint('[ThresholdAlertService] stopped');
  }

  Future<void> _check() async {
    try {
      await _engine.refreshData();
      final critical = _engine.criticalAlerts;
      if (critical.isNotEmpty) {
        if (kDebugMode) {
          debugPrint(
            '[ThresholdAlertService] ${critical.length} critical alert(s): '
            '${critical.map((a) => a['city']).join(', ')}',
          );
        }
        // TODO: wire to flutter_local_notifications for on-device alert
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[ThresholdAlertService] _check error: $e');
    }
  }
}
