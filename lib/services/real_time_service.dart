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
      stateName: (j['state'] ??
              j['stateName'] ??
              j['state_name'] ??
              '')
          .toString(),
      riverName: (j['river'] ??
              j['riverName'] ??
              j['river_name'] ??
              '')
          .toString(),
      // FIX: backend sends river_level; accept all common aliases
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
      rainfallLastHour: sf(j['rainfall_last_hour'] ??
          j['rainfallLastHour'] ??
          j['rainfall']),
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

  Map<String, dynamic> get debugLevelsRaw   => _lastLevelsRaw;
  Map<String, dynamic> get debugCwcRaw      => _lastCwcRaw;
  Map<String, dynamic> get debugAlertsRaw   => _lastAlertsRaw;
  int                  get debugRetryCount  => _retryCount;
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
      final results = await Future.wait([
        _api.getLiveLevels(),
        _api.getCriticalAlerts(),
        _api.getAllCwcStations(),
      ]);

      final levelsResponse = results[0];
      final alertsResponse = results[1];
      final cwcResponse    = results[2];

      _lastLevelsRaw = levelsResponse;
      _lastCwcRaw    = cwcResponse;
      _lastAlertsRaw = alertsResponse;

      _log('levels raw keys: ${levelsResponse.keys.toList()}');
      _log('cwc raw keys:    ${cwcResponse.keys.toList()}');

      // Deep-dump cwc envelope in debug mode so we can see actual structure
      if (kDebugMode) {
        final d = cwcResponse['data'];
        _log('cwc data type:   ${d?.runtimeType}');
        if (d is Map) {
          _log('cwc data keys:   ${d.keys.toList()}');
          final inner = d['data'];
          _log('cwc data.data type: ${inner?.runtimeType}');
          if (inner is List && inner.isNotEmpty) {
            _log('cwc data.data[0]: ${inner.first}');
          } else if (inner is Map) {
            _log('cwc data.data keys: ${inner.keys.toList()}');
          }
        } else if (d is List && d.isNotEmpty) {
          _log('cwc data[0]: ${d.first}');
        }
      }

      // FIX: Use _deepExtractList (not shallow _extractList) for live-levels response.
      // /api/live-levels wraps as {data: {data: [...]}} (depth-2), which _extractList misses.
      final levels = _parseFloodLevels(levelsResponse);
      final alerts = _parseAlerts(alertsResponse);
      _updateCwcStations(cwcResponse);

      _log('parsed levels: ${levels.length}, cwcStations: ${_cwcStations.length}');

      final bool cwcArrived = _cwcStations.isNotEmpty;

      if (levels.isNotEmpty) {
        _liveLevels           = levels;
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

      if (levels.isNotEmpty || cwcArrived) _retryCount = 0;

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

  // ── CWC station parser ────────────────────────────────────────────────────
  void _updateCwcStations(Map<String, dynamic> response) {
    if (response['status'] == 'error') {
      _log('CWC error response: ${response["error"]}');
      return;
    }

    final List<dynamic>? items = _deepExtractList(response);
    if (items == null || items.isEmpty) {
      _log('CWC: no list found. Full response: $response');
      return;
    }

    _log('CWC: found ${items.length} raw items');

    if (kDebugMode && items.isNotEmpty) {
      _log('CWC first item keys: ${(items.first as Map?)?.keys.toList()}');
      _log('CWC first item: ${items.first}');
    }

    final parsed = items
        .whereType<Map<String, dynamic>>()
        .map(CwcStationData.fromJson)
        .where((s) => s.stationName.isNotEmpty)
        .toList();

    if (parsed.isEmpty) {
      _log('CWC: items found but stationName empty in all. '
          'Check field name mapping in CwcStationData.fromJson');
      return;
    }

    _cwcStations = parsed;
    _cwcSource   = parsed.any((s) => s.isLiveCwc)
        ? 'CWC_API'
        : 'TACTICAL_REGISTRY';
    _log('CWC: populated ${_cwcStations.length} stations, source=$_cwcSource');
  }

  // ── Deep recursive list extractor ─────────────────────────────────────────
  // Searches every level of a nested Map/List envelope for the first
  // non-empty List<Map> it can find. Handles:
  //   {data: [...]}                      depth-1
  //   {data: {data: [...]}}              depth-2  ← /api/live-levels format
  //   {data: {data: {data: [...]}}}      depth-3 (some backends)
  //   {records: [...]}                   alternate key
  //   bare Map with station fields       single-station shortcut
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

  // ── Legacy flat extractor (kept for alerts parser) ─────────────────────────
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
  // FIX: Use _deepExtractList so we can pierce {data: {data: [...]}} wrapping
  // from /api/live-levels. Previously used _extractList which only went 2 levels.
  List<FloodData> _parseFloodLevels(Map<String, dynamic> response) {
    if (response['status'] == 'error') return <FloodData>[];
    final items = _deepExtractList(response);
    if (items == null) return <FloodData>[];
    return items
        .whereType<Map<String, dynamic>>()
        .map(FloodData.fromJson)
        .where((e) => e.city.isNotEmpty)
        .toList(growable: false);
  }

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
    final cutoff =
        DateTime.now().subtract(const Duration(hours: 24));
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
