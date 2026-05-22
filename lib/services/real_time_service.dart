import 'dart:async';
import 'dart:collection' show LinkedHashSet;
import 'dart:convert';
import 'dart:io' show SocketException;
import 'dart:math' as math;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants.dart';
import '../models/flood_data.dart';
import '../models/river_monitoring.dart';
import 'api_service.dart';

void _log(String msg) {
  if (kDebugMode) debugPrint('[RTS] $msg');
}

// ─────────────────────────────────────────────────────────────────────────────
class CwcStationData {
  final String stationName;
  final String stateName;
  final String riverName;
  final double riverLevel;
  final double warningLevel;
  final double dangerLevel;
  final double flowRate;
  final double rainfallLastHour;
  final String status;
  final String trend;
  final String source;
  final DateTime lastUpdate;

  const CwcStationData({
    required this.stationName,
    required this.stateName,
    required this.riverName,
    required this.riverLevel,
    required this.warningLevel,
    required this.dangerLevel,
    required this.flowRate,
    required this.rainfallLastHour,
    required this.status,
    required this.trend,
    required this.source,
    required this.lastUpdate,
  });

  factory CwcStationData.fromJson(Map<String, dynamic> j) {
    double sf(dynamic v) =>
        (v == null || v == '') ? 0.0 : (double.tryParse(v.toString()) ?? 0.0);
    return CwcStationData(
      stationName: (j['station'] ??
              j['stationName'] ??
              j['station_name'] ??
              j['city'] ??
              j['name'] ??
              '')
          .toString(),
      stateName: (j['state'] ?? j['stateName'] ?? j['state_name'] ?? '')
          .toString(),
      riverName: (j['river'] ?? j['riverName'] ?? j['river_name'] ?? '')
          .toString(),
      riverLevel: sf(j['river_level'] ??
          j['riverLevel'] ??
          j['current_level'] ??
          j['level'] ??
          j['gauge_reading']),
      warningLevel:
          sf(j['warning_level'] ?? j['warningLevel'] ?? j['wl']),
      dangerLevel:
          sf(j['danger_level'] ?? j['dangerLevel'] ?? j['dl']),
      flowRate:
          sf(j['flow_rate'] ?? j['flowRate'] ?? j['discharge']),
      rainfallLastHour: sf(
          j['rainfall_last_hour'] ?? j['rainfallLastHour'] ?? j['rainfall']),
      status: (j['status'] ?? j['alert_status'] ?? 'ACTIVE')
          .toString()
          .toUpperCase(),
      trend: (j['trend'] ?? j['water_trend'] ?? 'STEADY')
          .toString()
          .toUpperCase(),
      source: (j['source'] ?? j['data_source'] ?? 'UNKNOWN').toString(),
      lastUpdate: DateTime.tryParse(
              (j['last_update'] ??
                      j['lastUpdate'] ??
                      j['updated_at'] ??
                      j['timestamp'] ??
                      '')
                  .toString()) ??
          DateTime.now(),
    );
  }

  bool get isLiveCwc => source == 'CWC_API';
}

// ─────────────────────────────────────────────────────────────────────────────
class RealTimeService extends ChangeNotifier {
  static final RealTimeService _instance = RealTimeService._internal();
  factory RealTimeService() => _instance;
  RealTimeService._internal();

  static const String _cacheKey = 'opsflood_realtime_cache_v2';

  static const int      _wakeUpMaxAttempts = 20;
  static const Duration _wakeUpBaseDelay   = Duration(seconds: 2);
  static const Duration _wakeUpMaxDelay    = Duration(seconds: 15);

  // Build a state→city lookup from monitoredCities for enrichment
  static final Map<String, Map<String, dynamic>> _cityByState = () {
    final m = <String, Map<String, dynamic>>{};
    for (final c in AppConstants.monitoredCities) {
      final state = (c['state'] as String).toLowerCase();
      // Keep only first entry per state (primary monitored city)
      m.putIfAbsent(state, () => c);
    }
    return m;
  }();

  // Full list indexed by state for multi-city enrichment
  static final Map<String, List<Map<String, dynamic>>> _citiesByState = () {
    final m = <String, List<Map<String, dynamic>>>{};
    for (final c in AppConstants.monitoredCities) {
      final state = (c['state'] as String).toLowerCase();
      m.putIfAbsent(state, () => []).add(c);
    }
    return m;
  }();

  final ApiService _api = ApiService();
  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  Timer?  _pollingTimer;
  Timer?  _wakeUpTimer;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;

  bool _initialized          = false;
  bool _isPolling            = false;
  bool _isLoading            = false;
  bool _isOnline             = true;
  bool _isUsingCache         = false;
  bool _isUsingFallback      = false;
  bool _liveDataEverReceived = false;
  bool _hasRealFetchTime     = false;

  int       _retryCount          = 0;
  int       _queuedOfflineCycles = 0;
  int       _wakeAttempts        = 0;
  DateTime? _lastFetchTime;
  String?   _error;

  Map<String, dynamic> _lastLevelsRaw = {};
  Map<String, dynamic> _lastCwcRaw    = {};
  Map<String, dynamic> _lastAlertsRaw = {};

  List<FloodData>      _liveLevels     = <FloodData>[];
  List<FloodAlert>     _criticalAlerts = <FloodAlert>[];
  List<CwcStationData> _cwcStations    = <CwcStationData>[];
  String               _cwcSource      = '';

  final Map<String, List<RiverLevelSnapshot>> _historyByCity =
      <String, List<RiverLevelSnapshot>>{};

  final LinkedHashSet<String> _notificationDedup = LinkedHashSet<String>();

  MultiLocationMonitoring? _cachedMonitoringData;
  int _monitoringDataHash = 0;

  // ── Public getters ────────────────────────────────────────────────────────
  List<FloodData>      get liveLevels          => _liveLevels;
  List<FloodAlert>     get criticalAlerts      => _criticalAlerts;
  List<CwcStationData> get cwcStations         => _cwcStations;
  String               get cwcSource           => _cwcSource;
  bool                 get hasCwcLiveData      => _cwcStations.isNotEmpty;
  DateTime?            get lastFetchTime       => _lastFetchTime;
  String?              get error               => _error;
  bool                 get isLoading           => _isLoading;
  bool                 get isOnline            => _isOnline;
  bool                 get isUsingCache        => _isUsingCache;
  bool                 get isPolling           => _isPolling;
  int                  get queuedOfflineCycles => _queuedOfflineCycles;
  bool                 get isUsingFallback     => _isUsingFallback;
  bool                 get isWakingUp          =>
      _isOnline && !_liveDataEverReceived && !_hasRealFetchTime;

  Map<String, dynamic> get debugLevelsRaw    => _lastLevelsRaw;
  Map<String, dynamic> get debugCwcRaw       => _lastCwcRaw;
  Map<String, dynamic> get debugAlertsRaw    => _lastAlertsRaw;
  int                  get debugRetryCount   => _retryCount;
  int                  get debugWakeAttempts => _wakeAttempts;

  MultiLocationMonitoring get monitoringData {
    final hash = _liveLevels.length ^ (_historyByCity.length << 16);
    if (hash != _monitoringDataHash || _cachedMonitoringData == null) {
      _monitoringDataHash = hash;
      _cachedMonitoringData = MultiLocationMonitoring(
        locations: _liveLevels
            .map((item) =>
                RiverMonitoring.fromFloodData(item, trendForCity(item.city)))
            .toList(),
        fetchedAt:    _lastFetchTime ?? DateTime.now(),
        fromCache:    _isUsingCache,
        errorMessage: _error,
      );
    }
    return _cachedMonitoringData!;
  }

  int get criticalCount =>
      _liveLevels.where((e) => e.isCritical).length;

  List<FloodAlert> get activeCriticalAlerts => _criticalAlerts
      .where((e) => e.severity == 'CRITICAL' && !e.resolved)
      .toList(growable: false);

  List<RiverLevelSnapshot> trendForCity(String city) =>
      List<RiverLevelSnapshot>.from(
          _historyByCity[city.toLowerCase()] ?? <RiverLevelSnapshot>[]);

  FloodData? dataForCity(String city) {
    for (final item in _liveLevels) {
      if (item.city.toLowerCase() == city.toLowerCase()) return item;
    }
    return null;
  }

  // ── Initialization ────────────────────────────────────────────────────────
  Future<void> initialize() async {
    if (_initialized) return;
    await _initNotifications();
    _loadFallbackImmediately();
    await _restoreFromCache();
    await _initConnectivityListener();
    _initialized = true;
    _scheduleWakeUpRetry();
  }

  void _loadFallbackImmediately() {
    if (_liveLevels.isNotEmpty) return;
    _liveLevels      = _fallbackMonitoredLevels();
    _isUsingFallback = true;
    _lastFetchTime   = DateTime.now();
    notifyListeners();
  }

  // ── Wake-up loop ──────────────────────────────────────────────────────────
  void _scheduleWakeUpRetry() {
    if (_wakeAttempts >= _wakeUpMaxAttempts) return;
    _wakeUpTimer?.cancel();
    final delayMs = _wakeAttempts == 0
        ? 0
        : math
            .min(
              _wakeUpBaseDelay.inMilliseconds *
                  math.pow(1.3, _wakeAttempts - 1).toInt(),
              _wakeUpMaxDelay.inMilliseconds,
            )
            .toInt();
    _wakeUpTimer = Timer(Duration(milliseconds: delayMs), () async {
      _wakeAttempts++;
      _log('wake attempt $_wakeAttempts');
      try {
        final health = await _api.checkHealth();
        _log('health: $health');
        if (health['status'] != 'error') {
          await refreshData();
          if (_liveDataEverReceived && _liveLevels.isNotEmpty) return;
        }
      } catch (e) {
        _log('wake error: $e');
      }
      _scheduleWakeUpRetry();
    });
  }

  // ── Notifications ─────────────────────────────────────────────────────────
  Future<void> _initNotifications() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinInit  = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    await _notifications.initialize(
      settings: const InitializationSettings(
          android: androidInit, iOS: darwinInit, macOS: darwinInit),
    );
    final androidPlatform = _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidPlatform?.createNotificationChannel(
      const AndroidNotificationChannel(
        AppConstants.criticalAlertChannelId,
        AppConstants.criticalAlertChannelName,
        description: 'High priority flood emergency alerts',
        importance: Importance.max,
      ),
    );
    await androidPlatform?.createNotificationChannel(
      const AndroidNotificationChannel(
        AppConstants.warningAlertChannelId,
        AppConstants.warningAlertChannelName,
        description: 'Medium priority flood warnings',
        importance: Importance.high,
      ),
    );
  }

  // ── Connectivity ──────────────────────────────────────────────────────────
  Future<void> _initConnectivityListener() async {
    final connectivity = Connectivity();
    final initial = await connectivity.checkConnectivity();
    _isOnline = _listOnline(initial);
    _connectivitySub =
        connectivity.onConnectivityChanged.listen((List<ConnectivityResult> results) {
      final wasOnline = _isOnline;
      _isOnline = _listOnline(results);
      if (!wasOnline && _isOnline) {
        _wakeAttempts = 0;
        _scheduleWakeUpRetry();
        unawaited(refreshData(forceOnlineAttempt: true));
      } else if (wasOnline && !_isOnline) {
        _wakeUpTimer?.cancel();
      }
      notifyListeners();
    });
  }

  bool _listOnline(dynamic result) {
    if (result is List<ConnectivityResult>) {
      return result.any((r) => r != ConnectivityResult.none);
    }
    if (result is ConnectivityResult) {
      return result != ConnectivityResult.none;
    }
    return true;
  }

  // ── Polling ───────────────────────────────────────────────────────────────
  Future<void> startPolling({Duration? interval}) async {
    await initialize();
    if (_isPolling) return;
    _isPolling = true;
    await refreshData();
    _pollingTimer = Timer.periodic(
      interval ?? AppConstants.pollingInterval,
      (_) async {
        await refreshData();
        if (_liveDataEverReceived) {
          _wakeUpTimer?.cancel();
        } else {
          if (_wakeAttempts >= _wakeUpMaxAttempts) {
            _wakeAttempts = 0;
            _scheduleWakeUpRetry();
          }
        }
      },
    );
    notifyListeners();
  }

  void stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
    _wakeUpTimer?.cancel();
    _isPolling = false;
    notifyListeners();
  }

  // ── Core refresh ──────────────────────────────────────────────────────────
  Future<void> refreshData({bool forceOnlineAttempt = false}) async {
    if (_isLoading) return;
    if (!_isOnline && !forceOnlineAttempt) {
      _queuedOfflineCycles += 1;
      _error        = 'Offline. Showing cached data.';
      _isUsingCache = true;
      notifyListeners();
      return;
    }

    _isLoading = true;
    _error     = null;
    notifyListeners();

    try {
      // Fetch both sources in parallel:
      //  [0] /api/live-telemetry — station-level real CWC readings
      //  [1] /api/live-levels    — OPSFLOOD_MATRIX state aggregates
      //  [2] /api/critical-alerts
      final results = await Future.wait([
        _api.getAllLiveTelemetry(),
        _api.getLiveLevels(),
        _api.getCriticalAlerts(),
      ]);

      final telemetryResponse = results[0];
      final levelsResponse    = results[1];
      final alertsResponse    = results[2];

      _lastCwcRaw    = telemetryResponse;
      _lastLevelsRaw = levelsResponse;
      _lastAlertsRaw = alertsResponse;

      _log('telemetry status: ${telemetryResponse["status"]}');
      _log('levels    status: ${levelsResponse["status"]}');

      // Step 1 — parse raw telemetry (station-level)
      final telemetryItems = _deepExtractList(telemetryResponse) ?? [];
      _log('telemetry items: ${telemetryItems.length}');

      // Step 2 — parse OPSFLOOD_MATRIX levels (state-aggregated)
      final levelsItems = _deepExtractList(levelsResponse) ?? [];
      _log('levels items: ${levelsItems.length}');

      // Step 3 — update CWC station strip from telemetry
      _updateCwcStationsFromItems(telemetryItems);

      // Step 4 — build fused FloodData list
      //  Priority: live telemetry (has real station name + river_level)
      //         >  OPSFLOOD_MATRIX levels (enriched with monitoredCities metadata)
      //         >  monitoredCities fallback
      final fused = _buildFusedLevels(
        telemetryItems: telemetryItems
            .whereType<Map<String, dynamic>>()
            .toList(),
        levelsItems: levelsItems
            .whereType<Map<String, dynamic>>()
            .toList(),
      );

      final alerts = _parseAlerts(alertsResponse);

      _log('fused levels: ${fused.length}, cwcStations: ${_cwcStations.length}');

      if (fused.isNotEmpty) {
        _liveLevels           = fused;
        _isUsingFallback      = false;
        _liveDataEverReceived = true;
      } else if (!_liveDataEverReceived) {
        _liveLevels      = _fallbackMonitoredLevels();
        _isUsingFallback = true;
      }

      _criticalAlerts = alerts.isNotEmpty
          ? alerts
          : _alertsFromThresholds(_liveLevels);

      _appendHistoryPoints(_liveLevels);
      _apply24HourTrim();
      await _dispatchThresholdNotifications(_liveLevels);

      if (fused.isNotEmpty || _cwcStations.isNotEmpty) _retryCount = 0;

      _queuedOfflineCycles = 0;
      _lastFetchTime    = DateTime.now();
      _hasRealFetchTime = true;
      _isUsingCache     = false;
      _error            = null;

      await _persistCache();
    } on TimeoutException {
      _retryCount += 1;
      _error = 'Timed out — backend waking up (attempt $_retryCount).';
      _log(_error!);
      await _maybeRestoreCache();
    } on SocketException catch (e) {
      _retryCount += 1;
      _error = 'Network error: $e';
      _log(_error!);
      await _maybeRestoreCache();
    } catch (e) {
      _retryCount += 1;
      _error = 'Error: ${e.toString()}';
      _log(_error!);
      await _maybeRestoreCache();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _maybeRestoreCache() async {
    if (_retryCount >= AppConstants.maxRetries && !_liveDataEverReceived) {
      _isUsingCache = true;
      await _restoreFromCache();
    }
  }

  // ── Multi-source data fusion ──────────────────────────────────────────────
  //
  // Strategy:
  //  1. Index monitoredCities by state (lowercase) for fast lookup.
  //  2. Walk telemetryItems — each has a real station name + river_level.
  //     Build FloodData from it, enriching danger/warning/lat/lon from
  //     monitoredCities where the backend didn't send them.
  //  3. Walk levelsItems — these come from OPSFLOOD_MATRIX and often have
  //     city:"Unknown". For each, find the best matching monitoredCity for
  //     that state and emit a FloodData using the live river_level but
  //     metadata (city name, river name, coords, danger/warning) from our
  //     static registry. Only emit if not already covered by telemetry.
  //  4. Finally fill any monitoredCities not covered by either source
  //     using their risk estimate (fallback).
  List<FloodData> _buildFusedLevels({
    required List<Map<String, dynamic>> telemetryItems,
    required List<Map<String, dynamic>> levelsItems,
  }) {
    // track which states + cities have been covered
    final coveredCities = <String>{}; // lowercase city name
    final coveredStates = <String>{}; // lowercase state name
    final result        = <FloodData>[];

    // ── Pass 1: telemetry (station-level, highest fidelity) ─────────────────
    for (final item in telemetryItems) {
      final rawStation = (item['station'] ??
              item['stationName'] ??
              item['station_name'] ??
              item['city'] ??
              '')
          .toString()
          .trim();
      final rawState = (item['state'] ?? item['stateName'] ?? '')
          .toString()
          .trim();
      if (rawStation.isEmpty || rawStation == 'Unknown') continue;

      // Enrich with monitoredCities metadata if backend didn't send levels
      final enriched = _enrichFromRegistry(item, rawStation, rawState);
      final fd = FloodData.fromJson(enriched);
      if (fd.city.isNotEmpty && fd.city != 'Unknown') {
        result.add(fd);
        coveredCities.add(fd.city.toLowerCase());
        if (rawState.isNotEmpty) coveredStates.add(rawState.toLowerCase());
      }
    }

    // ── Pass 2: OPSFLOOD_MATRIX levels — enrich Unknown cities ──────────────
    // Group by state; pick the highest capacity_percent entry per state
    final bestByState = <String, Map<String, dynamic>>{};
    for (final item in levelsItems) {
      final st = (item['state'] ?? '').toString().trim().toLowerCase();
      if (st.isEmpty) continue;
      if (coveredStates.contains(st)) continue; // already have live data
      final existing = bestByState[st];
      final pct = (item['capacity_percent'] as num?)?.toDouble() ?? 0.0;
      final exPct = (existing?['capacity_percent'] as num?)?.toDouble() ?? -1.0;
      if (existing == null || pct > exPct) bestByState[st] = item;
    }

    for (final entry in bestByState.entries) {
      final stateKey = entry.key;
      final item     = entry.value;
      // find the best matching city in our registry for this state
      final registryCities = _citiesByState[stateKey] ?? [];
      if (registryCities.isEmpty) continue;

      // pick city whose risk matches the live risk_level if possible
      final liveRisk = (item['risk_level'] ?? 'MODERATE').toString().toUpperCase();
      Map<String, dynamic> bestCity = registryCities.first;
      for (final c in registryCities) {
        if ((c['risk'] as String).toUpperCase() == liveRisk) {
          bestCity = c;
          break;
        }
      }

      // Skip if we already covered this city via telemetry
      final cityNameLc = (bestCity['city'] as String).toLowerCase();
      if (coveredCities.contains(cityNameLc)) continue;

      // Build enriched item using live levels + registry metadata
      final liveLevel = (item['river_level'] ??
              item['current_level'] ??
              item['level']) as num?;
      final merged = <String, dynamic>{
        ...bestCity,
        'station':       bestCity['city'],
        'city':          bestCity['city'],
        'river_name':    bestCity['river'],
        'state':         bestCity['state'],
        'lat':           bestCity['lat'],
        'lon':           bestCity['lon'],
        'danger_level':  bestCity['danger_level'],
        'warning_level': bestCity['warning_level'],
        'safe_level':    (bestCity['warning_level'] as double) - 2.0,
        'risk_level':    item['risk_level'] ?? bestCity['risk'],
        'status':        item['status'] ?? 'Stable',
        'capacity_percent': item['capacity_percent'],
        'timestamp':     item['timestamp'],
        if (liveLevel != null) 'river_level': liveLevel,
      };

      final fd = FloodData.fromJson(merged);
      if (fd.city.isNotEmpty && !coveredCities.contains(fd.city.toLowerCase())) {
        result.add(fd);
        coveredCities.add(fd.city.toLowerCase());
        coveredStates.add(stateKey);
      }
    }

    // ── Pass 3: fill remaining monitoredCities not covered ──────────────────
    for (final c in AppConstants.monitoredCities) {
      final cityLc  = (c['city'] as String).toLowerCase();
      if (coveredCities.contains(cityLc)) continue;
      result.add(FloodData.fromMonitoredCity(c));
    }

    // Sort descending by capacity so highest-risk cities appear first
    result.sort((a, b) => b.capacityPercent.compareTo(a.capacityPercent));
    return result;
  }

  // Enrich a telemetry item with registry metadata where the backend
  // didn't provide danger_level / warning_level / coords / river_name.
  Map<String, dynamic> _enrichFromRegistry(
      Map<String, dynamic> item, String station, String state) {
    final stateKey = state.toLowerCase();
    final cities   = _citiesByState[stateKey] ?? [];

    // Try exact city match first
    Map<String, dynamic>? match;
    for (final c in cities) {
      if ((c['city'] as String).toLowerCase() == station.toLowerCase()) {
        match = c;
        break;
      }
    }
    // Then substring match
    if (match == null) {
      for (final c in cities) {
        final cn = (c['city'] as String).toLowerCase();
        if (station.toLowerCase().contains(cn) ||
            cn.contains(station.toLowerCase())) {
          match = c;
          break;
        }
      }
    }

    if (match == null) {
      // No registry entry — return as-is (station name is real at least)
      return {
        ...item,
        'station': station,
        'city': station,
      };
    }

    // Merge: live data wins for levels; registry wins for metadata gaps
    return <String, dynamic>{
      ...item,
      'station':    station,
      'city':       station,
      'river_name': item['river_name'] ?? item['river'] ?? match['river'],
      'lat':        item['lat'] ?? item['latitude'] ?? match['lat'],
      'lon':        item['lon'] ?? item['longitude'] ?? match['lon'],
      // Only use registry danger/warning if backend didn't send non-zero values
      'danger_level': _preferNonZero(
          item['danger_level'], match['danger_level']),
      'warning_level': _preferNonZero(
          item['warning_level'], match['warning_level']),
      'safe_level': item['safe_level'] ??
          ((match['warning_level'] as double) - 2.0),
    };
  }

  double _preferNonZero(dynamic live, dynamic fallback) {
    final lv = live == null ? 0.0 : (double.tryParse(live.toString()) ?? 0.0);
    final fv = fallback == null ? 0.0 : (double.tryParse(fallback.toString()) ?? 0.0);
    return lv > 0 ? lv : fv;
  }

  // ── CWC station parser (for the station strip widget) ────────────────────
  void _updateCwcStationsFromItems(List<dynamic> items) {
    if (items.isEmpty) {
      _log('CWC: no telemetry items');
      return;
    }

    final parsed = items
        .whereType<Map<String, dynamic>>()
        .map(CwcStationData.fromJson)
        .where((s) =>
            s.stationName.isNotEmpty &&
            s.stationName != 'Unknown' &&
            s.riverLevel > 0 &&
            (s.riverLevel >= s.warningLevel && s.warningLevel > 0))
        .toList();

    if (parsed.isEmpty) {
      // Relax filter — show any station with a real name + non-zero level
      final relaxed = items
          .whereType<Map<String, dynamic>>()
          .map(CwcStationData.fromJson)
          .where((s) => s.stationName.isNotEmpty && s.stationName != 'Unknown')
          .toList();
      _cwcStations = relaxed;
      _log('CWC strip (relaxed): ${_cwcStations.length} stations');
    } else {
      _cwcStations = parsed;
      _log('CWC strip (above warning): ${_cwcStations.length} stations');
    }

    _cwcSource = _cwcStations.any((s) => s.isLiveCwc)
        ? 'CWC_API'
        : 'TACTICAL_REGISTRY';
  }

  void _updateCwcStations(Map<String, dynamic> response) {
    final items = _deepExtractList(response) ?? [];
    _updateCwcStationsFromItems(items);
  }

  // ── Deep recursive list extractor ─────────────────────────────────────────
  List<dynamic>? _deepExtractList(dynamic node, {int depth = 0}) {
    if (depth > 6) return null;

    if (node is List) {
      if (node.isEmpty) return null;
      if (node.first is Map) return node;
      return null;
    }

    if (node is! Map<String, dynamic>) return null;

    const listKeys = [
      'data', 'stations', 'result', 'results',
      'items', 'records', 'levels', 'telemetry',
    ];

    for (final key in listKeys) {
      final v = node[key];
      if (v is List && v.isNotEmpty && v.first is Map) return v;
      if (v != null) {
        final found = _deepExtractList(v, depth: depth + 1);
        if (found != null) return found;
      }
    }

    if (node.containsKey('station') || node.containsKey('river_level') ||
        node.containsKey('stationName') || node.containsKey('gauge_reading')) {
      return [node];
    }

    return null;
  }

  List<dynamic>? _extractList(Map<String, dynamic> response) {
    for (final key in ['data', 'stations', 'result', 'results',
                        'items', 'records', 'levels', 'telemetry']) {
      final v = response[key];
      if (v is List) return v;
      if (v is Map<String, dynamic>) {
        for (final innerKey in ['data', 'stations', 'items', 'records', 'result']) {
          final inner = v[innerKey];
          if (inner is List) return inner;
        }
      }
    }
    if (response.containsKey('station') || response.containsKey('river_level')) {
      return [response];
    }
    return null;
  }

  // ── Parsers ───────────────────────────────────────────────────────────────
  List<FloodAlert> _parseAlerts(Map<String, dynamic> response) {
    if (response['status'] == 'error') return <FloodAlert>[];
    final items = _extractList(response);
    if (items == null) return <FloodAlert>[];
    return (items
            .whereType<Map<String, dynamic>>()
            .map(FloodAlert.fromJson)
            .toList(growable: false)
          ..sort((a, b) => b.timestamp.compareTo(a.timestamp)));
  }

  List<FloodData> _fallbackMonitoredLevels() =>
      AppConstants.monitoredCities
          .map(FloodData.fromMonitoredCity)
          .toList(growable: false);

  List<FloodAlert> _alertsFromThresholds(List<FloodData> levels) {
    final now = DateTime.now();
    return levels
        .where((e) => e.capacityPercent >= AppConstants.highThreshold)
        .map((e) => FloodAlert(
              id:       '${e.city}_${now.millisecondsSinceEpoch}',
              city:     e.city,
              state:    e.state,
              severity: e.capacityPercent >= AppConstants.criticalThreshold
                  ? 'CRITICAL'
                  : 'HIGH',
              title:   '${e.city} river alert',
              message: '${e.riverName ?? 'River'} is at '
                       '${e.capacityPercent.toStringAsFixed(0)}% capacity.',
              timestamp: now,
              resolved:  false,
              riverName:    e.riverName,
              currentLevel: e.currentLevel,
              dangerLevel:  e.dangerLevel,
              recommendation:
                  e.capacityPercent >= AppConstants.criticalThreshold
                      ? 'Move teams to emergency response mode.'
                      : 'Increase monitoring frequency.',
            ))
        .toList(growable: false);
  }

  // ── History ───────────────────────────────────────────────────────────────
  void _appendHistoryPoints(List<FloodData> levels) {
    final now = DateTime.now();
    for (final item in levels) {
      final key  = item.city.toLowerCase();
      final list = _historyByCity.putIfAbsent(
          key, () => <RiverLevelSnapshot>[]);
      list.add(RiverLevelSnapshot(
        timestamp: now,
        level:    item.currentLevel,
        flowRate: item.flowRate,
        status:   item.status,
      ));
    }
  }

  void _apply24HourTrim() {
    final cutoff = DateTime.now().subtract(const Duration(hours: 24));
    for (final key in _historyByCity.keys.toList()) {
      _historyByCity[key] = _historyByCity[key]!
          .where((p) => p.timestamp.isAfter(cutoff))
          .toList(growable: true);
    }
  }

  // ── Notifications ─────────────────────────────────────────────────────────
  Future<void> _dispatchThresholdNotifications(
      List<FloodData> levels) async {
    for (final level in levels) {
      final key =
          '${level.city}-${level.capacityPercent.toStringAsFixed(0)}-${level.riskLevel}';
      if (_notificationDedup.contains(key)) continue;
      if (level.capacityPercent >= AppConstants.criticalThreshold) {
        await _showNotification(
          id: level.city.hashCode,
          channelId: AppConstants.criticalAlertChannelId,
          channelName: AppConstants.criticalAlertChannelName,
          title: 'Critical flood risk in ${level.city}',
          body:
              '${level.riverName ?? 'River'} at ${level.capacityPercent.toStringAsFixed(0)}% capacity.',
          payload: 'city=${level.city}&severity=CRITICAL',
          persistent: true,
        );
        _notificationDedup.add(key);
      } else if (level.capacityPercent >= AppConstants.highThreshold) {
        await _showNotification(
          id: level.city.hashCode + 1000,
          channelId: AppConstants.warningAlertChannelId,
          channelName: AppConstants.warningAlertChannelName,
          title: 'High flood watch in ${level.city}',
          body:
              '${level.riverName ?? 'River'} at ${level.capacityPercent.toStringAsFixed(0)}% capacity.',
          payload: 'city=${level.city}&severity=HIGH',
          persistent: false,
        );
        _notificationDedup.add(key);
      }
    }
    while (_notificationDedup.length > 300) {
      _notificationDedup.remove(_notificationDedup.first);
    }
  }

  Future<void> _showNotification({
    required int    id,
    required String channelId,
    required String channelName,
    required String title,
    required String body,
    required String payload,
    required bool   persistent,
  }) async {
    final android = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelName,
      importance: persistent ? Importance.max  : Importance.high,
      priority:   persistent ? Priority.max    : Priority.high,
      ongoing: persistent,
      autoCancel: !persistent,
    );
    const ios = DarwinNotificationDetails(
        presentAlert: true, presentSound: true);
    await _notifications.show(
      id: id,
      title: title,
      body: body,
      notificationDetails:
          NotificationDetails(android: android, iOS: ios),
      payload: payload,
    );
  }

  // ── Cache ─────────────────────────────────────────────────────────────────
  Future<void> _persistCache() async {
    final prefs = await SharedPreferences.getInstance();
    final historyJson = <String, dynamic>{};
    _historyByCity.forEach((key, value) {
      historyJson[key] = value.map((item) => item.toJson()).toList();
    });
    await prefs.setString(
        _cacheKey,
        jsonEncode(<String, dynamic>{
          'last_fetch_time':
              (_lastFetchTime ?? DateTime.now()).toIso8601String(),
          'levels':  _liveLevels.map((i) => i.toJson()).toList(),
          'alerts':  _criticalAlerts.map((i) => i.toJson()).toList(),
          'history': historyJson,
        }));
  }

  Future<void> _restoreFromCache() async {
    final prefs = await SharedPreferences.getInstance();
    final raw   = prefs.getString(_cacheKey);
    if (raw == null || raw.isEmpty) {
      notifyListeners();
      return;
    }
    try {
      final parsed = jsonDecode(raw);
      if (parsed is! Map<String, dynamic>) {
        notifyListeners();
        return;
      }
      final rawLevels = parsed['levels'];
      if (rawLevels is List) {
        _liveLevels = rawLevels
            .whereType<Map<String, dynamic>>()
            .map(FloodData.fromJson)
            .toList(growable: false);
      }
      final rawAlerts = parsed['alerts'];
      if (rawAlerts is List) {
        _criticalAlerts = rawAlerts
            .whereType<Map<String, dynamic>>()
            .map(FloodAlert.fromJson)
            .toList(growable: false);
      }
      _historyByCity.clear();
      final history = parsed['history'];
      if (history is Map<String, dynamic>) {
        history.forEach((key, value) {
          if (value is List) {
            _historyByCity[key] = value
                .whereType<Map<String, dynamic>>()
                .map(RiverLevelSnapshot.fromJson)
                .toList(growable: true);
          }
        });
      }
      final cachedTime = DateTime.tryParse(
          (parsed['last_fetch_time'] ?? '').toString());
      if (!_hasRealFetchTime) _lastFetchTime = cachedTime;
      _isUsingCache = true;
      if (_liveLevels.isNotEmpty) _isUsingFallback = false;
      _apply24HourTrim();
      notifyListeners();
    } catch (_) {
      if (_liveLevels.isEmpty) {
        _liveLevels      = _fallbackMonitoredLevels();
        _isUsingFallback = true;
      }
      notifyListeners();
    }
  }

  @override
  void dispose() {
    stopPolling();
    _connectivitySub?.cancel();
    super.dispose();
  }
}
