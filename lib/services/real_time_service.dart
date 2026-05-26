// lib/services/real_time_service.dart
//
// OpsFlood — RealTimeService
//
// FIXED (2026-05-26):
//   Removed the factory-singleton anti-pattern. Riverpod's
//   ChangeNotifierProvider now fully owns the lifecycle — it can create,
//   dispose, and recreate this object as needed (important for testing).
//
//   LiveFetchEngine remains a singleton (it holds per-run state and a
//   persistent Timer), so two RealTimeService instances still share the
//   same underlying engine — this is intentional and correct.

import 'package:flutter/material.dart';
import '../models/flood_data.dart';
import '../models/river_monitoring.dart';
import 'live_fetch_engine.dart';
import 'ml_inference.dart';

class RealTimeService extends ChangeNotifier {
  // No singleton — Riverpod owns the lifecycle.
  RealTimeService() {
    _fetchEngine.onStateChanged = () {
      notifyListeners();
    };
  }

  final LiveFetchEngine _fetchEngine = LiveFetchEngine();
  final MlInferenceEngine _mlEngine  = MlInferenceEngine();

  bool get isLoading           => _fetchEngine.isLoading;
  bool get isOnline            => _fetchEngine.isOnline;
  bool get isUsingFallback     => _fetchEngine.isUsingFallback;
  bool get isWakingUp          => _fetchEngine.isWakingUp;
  bool get isUsingCache        => _fetchEngine.isUsingCache;
  DateTime? get lastFetchTime  => _fetchEngine.lastFetchTime;
  String? get error            => _fetchEngine.error;
  int get queuedOfflineCycles  => _fetchEngine.queuedOfflineCycles;

  List<FloodData> get liveLevels           => _fetchEngine.liveLevels;
  List<dynamic>   get activeCriticalAlerts => _fetchEngine.activeCriticalAlerts;
  List<dynamic>   get criticalAlerts       => _fetchEngine.criticalAlerts;
  int             get criticalCount        => _fetchEngine.criticalCount;
  List<dynamic>   get cwcStations          => _fetchEngine.cwcStations;
  bool            get hasCwcLiveData       => _fetchEngine.hasCwcLiveData;

  MultiLocationMonitoring get monitoringData => _fetchEngine.monitoringData;

  List<RiverLevelSnapshot> trendForCity(String city) =>
      _fetchEngine.trendForCity(city);

  FloodData? dataForCity(String city) =>
      _fetchEngine.dataForCity(city);

  List<dynamic> imdAlertsForState(String state)    => _fetchEngine.imdAlertsForState(state);
  List<dynamic> ndmaAdvisoriesForState(String state) => _fetchEngine.ndmaAdvisoriesForState(state);
  List<dynamic> emergencyContactsForState(String state) => _fetchEngine.emergencyContactsForState(state);

  List<dynamic> get imdAlerts        => _fetchEngine.imdAlerts;
  List<dynamic> get ndmaAdvisories   => _fetchEngine.ndmaAdvisories;
  List<dynamic> get emergencyContacts => _fetchEngine.emergencyContacts;

  Map<String, dynamic> get debugLevelsRaw   => _fetchEngine.debugLevelsRaw;
  Map<String, dynamic> get debugCwcRaw      => _fetchEngine.debugCwcRaw;
  int get debugRetryCount                   => _fetchEngine.debugRetryCount;
  int get debugWakeAttempts                 => _fetchEngine.debugWakeAttempts;

  Future<void> refreshData()   async => _fetchEngine.refreshData();
  Future<void> startPolling()  async => _fetchEngine.startPolling();
  void         stopPolling()         => _fetchEngine.stopPolling();

  @override
  void dispose() {
    _fetchEngine.onStateChanged = null;
    super.dispose();
  }
}
