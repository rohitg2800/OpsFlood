// lib/services/app_state_service.dart
// OpsFlood — AppStateService v2
// Central data bus: aggregates WRD Bihar + CWC live data.
// v2: integrates StationHistoryStore so NA stations are backfilled
//     with last known readings before notifying listeners.
library;

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'station_history_store.dart';
import 'wrd_bihar_service.dart';

export 'station_history_store.dart';

enum AppRisk { safe, watch, high, critical, unknown }

class FloodAlertEntry {
  final String   station;
  final String   river;
  final String   district;
  final double   currentLevel;
  final double   dangerLevel;
  final double   pct;
  final AppRisk  risk;
  final String   trend;
  final DateTime detectedAt;
  final String   source;
  final bool     isPastData; // true when reading came from history store

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
    this.isPastData = false,
  });

  bool get isCritical   => risk == AppRisk.critical;
  bool get isHigh       => risk == AppRisk.high;
  bool get isActionable => risk == AppRisk.critical || risk == AppRisk.high;
}

class AppStateService extends ChangeNotifier {
  AppStateService._();
  static final AppStateService instance = AppStateService._();

  // ── State ────────────────────────────────────────────────────────────────────
  List<WrdStation>              wrdStations     = [];
  List<WrdStationWithHistory>   wrdWithHistory  = [];
  List<FloodAlertEntry>         activeAlerts    = [];
  bool                          loading         = true;
  String?                       lastError;
  DateTime?                     lastRefresh;
  Timer?                        _timer;
  bool                          _histStoreReady = false;

  // ── Derived counters ──────────────────────────────────────────────────────
  int get totalMonitored => wrdStations.length;
  int get liveCount      => wrdStations.where((s) => s.hasLiveData).length;
  int get pastDataCount  => wrdWithHistory.where((s) => s.hasPastData).length;
  int get blindCount     => wrdWithHistory.where((s) => s.isBlind).length;
  int get criticalCount  => activeAlerts.where((a) => a.isCritical).length;
  int get highCount      => activeAlerts.where((a) => a.isHigh).length;
  int get alertCount     => activeAlerts.where((a) => a.isActionable).length;

  AppRisk get avgRisk {
    if (wrdStations.isEmpty) return AppRisk.unknown;
    // Use effective pct from wrdWithHistory (includes past data)
    final effective = wrdWithHistory
        .where((s) => s.effectivePct != null)
        .toList();
    if (effective.isEmpty) return AppRisk.safe;
    int score = 0;
    for (final s in effective) {
      final label = s.riskLabel.replaceAll('*', ''); // strip stale asterisk
      switch (label) {
        case 'CRITICAL': score += 4; break;
        case 'HIGH':     score += 3; break;
        case 'MODERATE': score += 2; break;
        case 'LOW':      score += 1; break;
      }
    }
    final avg = score / effective.length;
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

  // ── Lifecycle ───────────────────────────────────────────────────────────────
  void startPolling({Duration interval = const Duration(minutes: 5)}) {
    _initHistStore().then((_) => _fetch());
    _timer = Timer.periodic(interval, (_) => _fetch());
  }

  void stopPolling() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> refresh() => _fetch(force: true);

  Future<void> _initHistStore() async {
    if (_histStoreReady) return;
    await StationHistoryStore.instance.init();
    _histStoreReady = true;
  }

  Future<void> _fetch({bool force = false}) async {
    loading = true;
    notifyListeners();
    try {
      await _initHistStore();
      final grouped = await WrdBiharService.instance
          .fetchGroupedByRiver();
      wrdStations = grouped.values.expand((v) => v).toList();

      // Persist all new live readings to history store
      await StationHistoryStore.instance.recordAll(wrdStations);

      // Merge: NA stations get backfilled from history
      wrdWithHistory =
          StationHistoryStore.instance.mergeWithHistory(wrdStations);

      _buildAlerts();
      lastRefresh = DateTime.now();
      lastError   = null;

      if (kDebugMode) {
        debugPrint(
          '[AppState] live=${liveCount} past=${pastDataCount} '
          'blind=${blindCount} alerts=${alertCount}',
        );
      }
    } catch (e) {
      lastError = e.toString();
      if (kDebugMode) debugPrint('[AppState] fetch error: $e');
    }
    loading = false;
    notifyListeners();
  }

  void _buildAlerts() {
    activeAlerts = [];
    for (final sw in wrdWithHistory) {
      // Build alerts from live data only
      final s   = sw.station;
      final pct = s.percentOfDanger;
      if (!s.hasLiveData || pct == null) continue;
      AppRisk risk;
      if (pct >= 100)     risk = AppRisk.critical;
      else if (pct >= 85) risk = AppRisk.high;
      else if (pct >= 70) risk = AppRisk.watch;
      else                continue;

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
        isPastData:   false,
      ));
    }
    activeAlerts.sort((a, b) => b.pct.compareTo(a.pct));
  }
}
