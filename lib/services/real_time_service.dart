// lib/services/real_time_service.dart
import 'package:flutter/material.dart';
import '../models/flood_data.dart';
import '../models/river_monitoring.dart';
import 'live_fetch_engine.dart';
// kept for backwards compat — is an empty library

class RealTimeService extends ChangeNotifier {
  static final RealTimeService _instance = RealTimeService._internal();
  factory RealTimeService() => _instance;

  final LiveFetchEngine _fetchEngine = LiveFetchEngine();
  bool _disposed = false;

  RealTimeService._internal() {
    _fetchEngine.onStateChanged = () {
      if (!_disposed) notifyListeners();
    };
  }

  @override
  void dispose() {
    _disposed = true;
    _fetchEngine.stopPolling();
    _fetchEngine.onStateChanged = null;
    super.dispose();
  }

  // ── Status passthrough ────────────────────────────────────────────────
  bool      get isLoading           => _fetchEngine.isLoading;
  bool      get isOnline            => _fetchEngine.isOnline;
  bool      get isUsingFallback     => !_fetchEngine.isOnline && _fetchEngine.liveFloodData.isNotEmpty;
  bool      get isWakingUp          => _fetchEngine.isWakingUp;
  bool      get isUsingCache        => _fetchEngine.isUsingCache;
  DateTime? get lastFetchTime       => _fetchEngine.lastFetchTime;
  String?   get error               => _fetchEngine.error;
  int       get queuedOfflineCycles => _fetchEngine.queuedOfflineCycles;

  // ── Per-source health passthrough ──────────────────────────────────────
  SourceHealth get glofasHealth => _fetchEngine.glofasHealth;
  SourceHealth get imdHealth    => _fetchEngine.imdHealth;
  SourceHealth get wrdHealth    => _fetchEngine.wrdHealth;
  SourceHealth get cwcHealth    => _fetchEngine.cwcHealth;

  bool get glofasHealthy => _fetchEngine.glofasHealthy;
  bool get imdHealthy    => _fetchEngine.imdHealthy;
  bool get wrdHealthy    => _fetchEngine.wrdHealthy;
  bool get cwcHealthy    => _fetchEngine.cwcHealthy;

  int? get glofasLatencyMs => _fetchEngine.glofasLatencyMs;
  int? get imdLatencyMs    => _fetchEngine.imdLatencyMs;
  int? get wrdLatencyMs    => _fetchEngine.wrdLatencyMs;
  int? get cwcLatencyMs    => _fetchEngine.cwcLatencyMs;

  // ── Data passthrough ─────────────────────────────────────────────────
  List<FloodData> get liveLevels    => _fetchEngine.liveFloodData;

  List<dynamic>            get activeCriticalAlerts => _fetchEngine.activeCriticalAlerts;
  List<dynamic>            get criticalAlerts       => _fetchEngine.criticalAlerts;
  int                      get criticalCount        => _fetchEngine.criticalCount;
  List<dynamic>            get cwcStations          => _fetchEngine.cwcStations;
  bool                     get hasCwcLiveData       => _fetchEngine.hasCwcLiveData;
  MultiLocationMonitoring  get monitoringData       => _fetchEngine.monitoringData;

  List<dynamic> get imdAlerts         => _fetchEngine.imdAlerts;
  List<dynamic> get ndmaAdvisories    => _fetchEngine.ndmaAdvisories;
  List<dynamic> get emergencyContacts => _fetchEngine.emergencyContacts;

  Map<String, dynamic> get debugLevelsRaw   => _fetchEngine.debugLevelsRaw;
  Map<String, dynamic> get debugCwcRaw      => _fetchEngine.debugCwcRaw;
  int                  get debugRetryCount  => _fetchEngine.debugRetryCount;
  int                  get debugWakeAttempts => _fetchEngine.debugWakeAttempts;

  // ── Per-city ─────────────────────────────────────────────────────────
  List<RiverLevelSnapshot> trendForCity(String city) =>
      _fetchEngine.trendForCity(city).cast<RiverLevelSnapshot>();

  FloodData? dataForCity(String city) =>
      _fetchEngine.floodDataForCity(city);

  List<dynamic> imdAlertsForState(String state)         => _fetchEngine.imdAlertsForState(state);
  List<dynamic> ndmaAdvisoriesForState(String state)    => _fetchEngine.ndmaAdvisoriesForState(state);
  List<dynamic> emergencyContactsForState(String state) => _fetchEngine.emergencyContactsForState(state);

  // ── Actions ─────────────────────────────────────────────────────────
  Future<void> refreshData()  async => _fetchEngine.refreshData();
  Future<void> startPolling() async => _fetchEngine.startPolling();
  void         stopPolling()        => _fetchEngine.stopPolling();
}
