// lib/services/app_state_service.dart
// OpsFlood — AppStateService
// Central data bus: aggregates WRD Bihar + CWC live data into a single
// ChangeNotifier consumed by Home, Monitors, Alerts, and RiverMonitor screens.
// Prevents redundant API calls — all screens share one live data snapshot.
library;

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'wrd_bihar_service.dart';
import 'threshold_alert_service.dart';

enum AppRisk { safe, watch, high, critical, unknown }

class FloodAlertEntry {
  final String station;
  final String river;
  final String district;
  final double currentLevel;
  final double dangerLevel;
  final double pct;
  final AppRisk risk;
  final String trend;
  final DateTime detectedAt;
  final String source; // 'WRD_BIHAR' | 'CWC' | 'GLOFAS'

  const FloodAlertEntry({
    required this.station,
    required this.river,
    required this.district,
    required this.currentLevel,
    required this.dangerLevel,
    required this.pct,
    required this.risk,
    required this.trend,
    required this.detectedAt,
    required this.source,
  });

  bool get isCritical => risk == AppRisk.critical;
  bool get isHigh     => risk == AppRisk.high;
  bool get isActionable => risk == AppRisk.critical || risk == AppRisk.high;
}

class AppStateService extends ChangeNotifier {
  AppStateService._();
  static final AppStateService instance = AppStateService._();

  // ── State ──────────────────────────────────────────────────────────────────
  List<WrdStation>     wrdStations      = [];
  List<FloodAlertEntry> activeAlerts    = [];
  bool                 loading          = true;
  String?              lastError;
  DateTime?            lastRefresh;
  Timer?               _timer;

  // Derived
  int get totalMonitored   => wrdStations.length;
  int get liveCount        => wrdStations.where((s) => s.hasLiveData).length;
  int get criticalCount    => activeAlerts.where((a) => a.isCritical).length;
  int get highCount        => activeAlerts.where((a) => a.isHigh).length;
  int get alertCount       => activeAlerts.where((a) => a.isActionable).length;

  AppRisk get avgRisk {
    if (wrdStations.isEmpty) return AppRisk.unknown;
    final live = wrdStations.where((s) => s.hasLiveData).toList();
    if (live.isEmpty) return AppRisk.safe;
    int score = 0;
    for (final s in live) {
      switch (s.riskLabel) {
        case 'CRITICAL': score += 4; break;
        case 'HIGH':     score += 3; break;
        case 'MODERATE': score += 2; break;
        case 'LOW':      score += 1; break;
      }
    }
    final avg = score / live.length;
    if (avg >= 3.5) return AppRisk.critical;
    if (avg >= 2.5) return AppRisk.high;
    if (avg >= 1.5) return AppRisk.watch;
    return AppRisk.safe;
  }

  String get avgRiskLabel {
    switch (avgRisk) {
      case AppRisk.critical: return 'CRITICAL';
      case AppRisk.high:     return 'HIGH';
      case AppRisk.watch:    return 'MODERATE';
      case AppRisk.safe:     return 'SAFE';
      default:               return 'UNKNOWN';
    }
  }

  // ── Lifecycle ──────────────────────────────────────────────────────────────
  void startPolling({Duration interval = const Duration(minutes: 5)}) {
    _fetch();
    _timer = Timer.periodic(interval, (_) => _fetch());
  }

  void stopPolling() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> refresh() => _fetch(force: true);

  Future<void> _fetch({bool force = false}) async {
    loading = true;
    notifyListeners();
    try {
      final grouped = await WrdBiharService.instance
          .fetchGroupedByRiver();
      wrdStations = grouped.values.expand((v) => v).toList();
      _buildAlerts();
      lastRefresh = DateTime.now();
      lastError   = null;
    } catch (e) {
      lastError = e.toString();
    }
    loading = false;
    notifyListeners();
  }

  void _buildAlerts() {
    activeAlerts = [];
    for (final s in wrdStations) {
      if (!s.hasLiveData) continue;
      final pct = s.percentOfDanger;
      if (pct == null) continue;
      AppRisk risk;
      if (pct >= 100)      risk = AppRisk.critical;
      else if (pct >= 85)  risk = AppRisk.high;
      else if (pct >= 70)  risk = AppRisk.watch;
      else                 continue; // skip safe

      activeAlerts.add(FloodAlertEntry(
        station:      s.site,
        river:        s.river,
        district:     s.district,
        currentLevel: s.currentLevel ?? 0,
        dangerLevel:  s.dangerLevel ?? 0,
        pct:          pct,
        risk:         risk,
        trend:        s.trend ?? 'Steady',
        detectedAt:   DateTime.now(),
        source:       'WRD_BIHAR',
      ));
    }
    activeAlerts.sort((a, b) => b.pct.compareTo(a.pct));
  }
}
