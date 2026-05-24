import 'package:flutter/material.dart';
import '../models/flood_data.dart';
import '../models/river_monitoring.dart';
import 'live_fetch_engine.dart';
import 'ml_inference.dart';

class RealTimeService extends ChangeNotifier {
  static final RealTimeService _instance = RealTimeService._internal();
  factory RealTimeService() => _instance;
  
  final LiveFetchEngine _fetchEngine = LiveFetchEngine();
  final MlInferenceEngine _mlEngine = MlInferenceEngine();

  RealTimeService._internal() {
    _fetchEngine.onStateChanged = () {
      notifyListeners();
    };
  }

  bool get isLoading => _fetchEngine.isLoading;
  bool get isOnline => _fetchEngine.isOnline;
  bool get isUsingFallback => _fetchEngine.isUsingFallback;
  bool get isWakingUp => _fetchEngine.isWakingUp;
  bool get isUsingCache => _fetchEngine.isUsingCache;
  DateTime? get lastFetchTime => _fetchEngine.lastFetchTime;
  String? get error => _fetchEngine.error;
  int get queuedOfflineCycles => _fetchEngine.queuedOfflineCycles;

  List<FloodData> get liveLevels => _fetchEngine.liveLevels;
  List<dynamic> get activeCriticalAlerts => _fetchEngine.activeCriticalAlerts;
  List<dynamic> get criticalAlerts => _fetchEngine.criticalAlerts;
  int get criticalCount => _fetchEngine.criticalCount;
  List<dynamic> get cwcStations => _fetchEngine.cwcStations;
  bool get hasCwcLiveData => _fetchEngine.hasCwcLiveData;

  MultiLocationMonitoring get monitoringData => _fetchEngine.monitoringData;

  List<RiverLevelSnapshot> trendForCity(String city) {
    return _fetchEngine.trendForCity(city);
  }

  FloodData? dataForCity(String city) {
    return _fetchEngine.dataForCity(city);
  }

  List<dynamic> imdAlertsForState(String state) => _fetchEngine.imdAlertsForState(state);
  List<dynamic> ndmaAdvisoriesForState(String state) => _fetchEngine.ndmaAdvisoriesForState(state);
  List<dynamic> emergencyContactsForState(String state) => _fetchEngine.emergencyContactsForState(state);
  
  List<dynamic> get imdAlerts => _fetchEngine.imdAlerts;
  List<dynamic> get ndmaAdvisories => _fetchEngine.ndmaAdvisories;
  List<dynamic> get emergencyContacts => _fetchEngine.emergencyContacts;

  Map<String, dynamic> get debugLevelsRaw => _fetchEngine.debugLevelsRaw;
  Map<String, dynamic> get debugCwcRaw => _fetchEngine.debugCwcRaw;
  int get debugRetryCount => _fetchEngine.debugRetryCount;
  int get debugWakeAttempts => _fetchEngine.debugWakeAttempts;

  Future<void> refreshData() async {
    await _fetchEngine.refreshData();
  }

  Future<void> startPolling() async {
    await _fetchEngine.startPolling();
  }

  void stopPolling() {
    _fetchEngine.stopPolling();
  }
}
