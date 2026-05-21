import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants.dart';
import '../models/flood_data.dart';
import '../models/river_monitoring.dart';
import 'api_service.dart';

class RealTimeService extends ChangeNotifier {
  static final RealTimeService _instance = RealTimeService._internal();
  factory RealTimeService() => _instance;
  RealTimeService._internal();

  static const String _cacheKey = 'opsflood_realtime_cache_v1';

  // How many seconds to keep pinging the backend before giving up and
  // showing the fallback. Render free-tier typically wakes in 10-20 s.
  static const int _wakeUpMaxAttempts = 6;          // 6 × 5 s = 30 s max
  static const Duration _wakeUpRetryDelay = Duration(seconds: 5);

  final ApiService _api = ApiService();
  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  Timer? _pollingTimer;
  Timer? _wakeUpTimer;
  StreamSubscription<dynamic>? _connectivitySub;

  bool _initialized = false;
  bool _isPolling = false;
  bool _isLoading = false;
  bool _isOnline = true;
  bool _isUsingCache = false;
  bool _isUsingFallback = false;
  bool _liveDataEverReceived = false;   // ← once true, never show fallback banner

  int _retryCount = 0;
  int _queuedOfflineCycles = 0;
  int _wakeAttempts = 0;

  DateTime? _lastFetchTime;
  String? _error;

  List<FloodData> _liveLevels = <FloodData>[];
  List<FloodAlert> _criticalAlerts = <FloodAlert>[];
  final Map<String, List<RiverLevelSnapshot>> _historyByCity =
      <String, List<RiverLevelSnapshot>>{};

  final Set<String> _notificationDedup = <String>{};

  MultiLocationMonitoring? _cachedMonitoringData;
  int _monitoringDataHash = 0;

  // ── Public getters ────────────────────────────────────────────────────────
  List<FloodData>  get liveLevels           => _liveLevels;
  List<FloodAlert> get criticalAlerts       => _criticalAlerts;
  DateTime?        get lastFetchTime        => _lastFetchTime;
  String?          get error                => _error;
  bool             get isLoading            => _isLoading;
  bool             get isOnline             => _isOnline;
  bool             get isUsingCache         => _isUsingCache;
  bool             get isPolling            => _isPolling;
  int              get queuedOfflineCycles  => _queuedOfflineCycles;

  /// True only when we CURRENTLY have no live data AND have never had it.
  /// Once real data is fetched even once, this stays false forever.
  bool get isUsingFallback => _isUsingFallback && !_liveDataEverReceived;

  MultiLocationMonitoring get monitoringData {
    final hash = _liveLevels.length ^ (_historyByCity.length << 16);
    if (hash != _monitoringDataHash || _cachedMonitoringData == null) {
      _monitoringDataHash = hash;
      final locations = _liveLevels
          .map((item) => RiverMonitoring.fromFloodData(item, trendForCity(item.city)))
          .toList();
      _cachedMonitoringData = MultiLocationMonitoring(
        locations: locations,
        fetchedAt: _lastFetchTime ?? DateTime.now(),
        fromCache: _isUsingCache,
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
        _historyByCity[city.toLowerCase()] ?? <RiverLevelSnapshot>[],
      );

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
    await _restoreFromCache();
    await _initConnectivityListener();
    _initialized = true;

    // Kick off a rapid wake-up loop: ping every 5 s until we get live data
    // or exhaust _wakeUpMaxAttempts.
    _scheduleWakeUpRetry();
  }

  /// Fires a health-check ping and, if the backend is awake, immediately
  /// calls refreshData. Retries up to _wakeUpMaxAttempts times.
  void _scheduleWakeUpRetry() {
    if (_wakeAttempts >= _wakeUpMaxAttempts || _liveDataEverReceived) return;

    _wakeUpTimer?.cancel();
    _wakeUpTimer = Timer(_wakeUpRetryDelay * (_wakeAttempts == 0 ? 0 : 1), () async {
      _wakeAttempts++;
      try {
        final health = await _api.checkHealth();
        if (health['status'] != 'error') {
          // Backend is up — try to get real data
          await refreshData();
          if (_liveDataEverReceived) return;   // success, stop retrying
        }
      } catch (_) {}
      // Not up yet, schedule next attempt
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
    const settings = InitializationSettings(
      android: androidInit, iOS: darwinInit, macOS: darwinInit,
    );
    await _notifications.initialize(settings: settings);

    const criticalChannel = AndroidNotificationChannel(
      AppConstants.criticalAlertChannelId,
      AppConstants.criticalAlertChannelName,
      description: 'High priority flood emergency alerts',
      importance: Importance.max,
    );
    const warningChannel = AndroidNotificationChannel(
      AppConstants.warningAlertChannelId,
      AppConstants.warningAlertChannelName,
      description: 'Medium priority flood warnings',
      importance: Importance.high,
    );

    final androidPlatform = _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidPlatform?.createNotificationChannel(criticalChannel);
    await androidPlatform?.createNotificationChannel(warningChannel);
  }

  // ── Connectivity ──────────────────────────────────────────────────────────
  Future<void> _initConnectivityListener() async {
    final connectivity = Connectivity();
    final result = await connectivity.checkConnectivity();
    _isOnline = _connectionAvailable(result);

    _connectivitySub = connectivity.onConnectivityChanged.listen((dynamic r) {
      final wasOnline = _isOnline;
      _isOnline = _connectionAvailable(r);
      if (!wasOnline && _isOnline) {
        _wakeAttempts = 0;          // reset wake-up counter on reconnect
        unawaited(refreshData(forceOnlineAttempt: true));
        _scheduleWakeUpRetry();
      }
      notifyListeners();
    });
  }

  bool _connectionAvailable(dynamic result) {
    if (result is ConnectivityResult)       return result != ConnectivityResult.none;
    if (result is List<ConnectivityResult>) return result.any((r) => r != ConnectivityResult.none);
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
      (_) => unawaited(refreshData()),
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

  // ── Core data refresh ─────────────────────────────────────────────────────
  Future<void> refreshData({bool forceOnlineAttempt = false}) async {
    if (_isLoading) return;

    if (!_isOnline && !forceOnlineAttempt) {
      _queuedOfflineCycles += 1;
      _error = 'Offline. Showing cached data.';
      _isUsingCache = true;
      notifyListeners();
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final levelsResponse = await _api.getLiveLevels();
      final alertsResponse = await _api.getCriticalAlerts();

      final levels = _parseFloodLevels(levelsResponse);
      final alerts = _parseAlerts(alertsResponse);

      final gotLiveData = levels.isNotEmpty;

      if (gotLiveData) {
        _liveLevels          = levels;
        _isUsingFallback     = false;
        _liveDataEverReceived = true;    // ← never show fallback again
      } else if (!_liveDataEverReceived) {
        // Only use fallback stub data before we've ever had real data
        _liveLevels      = _fallbackMonitoredLevels();
        _isUsingFallback = true;
      }
      // If gotLiveData==false but _liveDataEverReceived==true, keep the
      // last good live snapshot rather than replacing with stubs.

      _criticalAlerts = alerts.isNotEmpty
          ? alerts
          : _alertsFromThresholds(_liveLevels);

      _appendHistoryPoints(_liveLevels);
      _apply24HourTrim();
      _dispatchThresholdNotifications(_liveLevels);

      _retryCount          = 0;
      _queuedOfflineCycles = 0;
      _lastFetchTime       = DateTime.now();
      _isUsingCache        = false;
      _error               = null;

      await _persistCache();
    } catch (e) {
      _retryCount += 1;
      _error = 'Refresh failed: ${e.toString()}';
      if (_retryCount >= AppConstants.maxRetries) {
        _isUsingCache = true;
        await _restoreFromCache();
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ── Parsers ───────────────────────────────────────────────────────────────
  List<FloodData> _parseFloodLevels(Map<String, dynamic> response) {
    if (response['status'] == 'error') return <FloodData>[];
    final raw = response['data'];
    if (raw is List) {
      return raw.whereType<Map<String, dynamic>>().map(FloodData.fromJson).toList(growable: false);
    }
    if (raw is Map<String, dynamic>) {
      final candidate = raw['levels'] ?? raw['items'];
      if (candidate is List) {
        return candidate.whereType<Map<String, dynamic>>().map(FloodData.fromJson).toList(growable: false);
      }
    }
    return <FloodData>[];
  }

  List<FloodAlert> _parseAlerts(Map<String, dynamic> response) {
    if (response['status'] == 'error') return <FloodAlert>[];
    final raw = response['data'];
    if (raw is List) {
      return (raw.whereType<Map<String, dynamic>>().map(FloodAlert.fromJson).toList(growable: false)
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp)));
    }
    return <FloodAlert>[];
  }

  List<FloodData> _fallbackMonitoredLevels() =>
      AppConstants.monitoredCities.map(FloodData.fromMonitoredCity).toList(growable: false);

  List<FloodAlert> _alertsFromThresholds(List<FloodData> levels) {
    final now = DateTime.now();
    return levels
        .where((e) => e.capacityPercent >= AppConstants.highThreshold)
        .map((e) => FloodAlert(
              id: '${e.city}_${now.millisecondsSinceEpoch}',
              city: e.city,
              state: e.state,
              severity: e.capacityPercent >= AppConstants.criticalThreshold ? 'CRITICAL' : 'HIGH',
              title: '${e.city} river alert',
              message: '${e.riverName ?? 'River'} is at ${e.capacityPercent.toStringAsFixed(0)}% capacity.',
              timestamp: now,
              resolved: false,
              riverName: e.riverName,
              currentLevel: e.currentLevel,
              dangerLevel: e.dangerLevel,
              recommendation: e.capacityPercent >= AppConstants.criticalThreshold
                  ? 'Move teams to emergency response mode for low-lying zones.'
                  : 'Increase monitoring frequency and keep response units on standby.',
            ))
        .toList(growable: false);
  }

  // ── History helpers ───────────────────────────────────────────────────────
  void _appendHistoryPoints(List<FloodData> levels) {
    final now = DateTime.now();
    for (final item in levels) {
      final key  = item.city.toLowerCase();
      final list = _historyByCity.putIfAbsent(key, () => <RiverLevelSnapshot>[]);
      list.add(RiverLevelSnapshot(
        timestamp: now,
        level: item.currentLevel,
        flowRate: item.flowRate,
        status: item.status,
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
  Future<void> _dispatchThresholdNotifications(List<FloodData> levels) async {
    for (final level in levels) {
      final key = '${level.city}-${level.capacityPercent.toStringAsFixed(0)}-${level.riskLevel}';
      if (_notificationDedup.contains(key)) continue;

      if (level.capacityPercent >= AppConstants.criticalThreshold) {
        await _showNotification(
          id: level.city.hashCode,
          channelId: AppConstants.criticalAlertChannelId,
          channelName: AppConstants.criticalAlertChannelName,
          title: 'Critical flood risk in ${level.city}',
          body: '${level.riverName ?? 'River'} at ${level.capacityPercent.toStringAsFixed(0)}% capacity. Immediate action needed.',
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
          body: '${level.riverName ?? 'River'} at ${level.capacityPercent.toStringAsFixed(0)}% capacity.',
          payload: 'city=${level.city}&severity=HIGH',
          persistent: false,
        );
        _notificationDedup.add(key);
      }
    }
    if (_notificationDedup.length > 300) _notificationDedup.remove(_notificationDedup.first);
  }

  Future<void> _showNotification({
    required int id,
    required String channelId,
    required String channelName,
    required String title,
    required String body,
    required String payload,
    required bool persistent,
  }) async {
    final android = AndroidNotificationDetails(
      channelId, channelName,
      channelDescription: channelName,
      importance: persistent ? Importance.max : Importance.high,
      priority:   persistent ? Priority.max   : Priority.high,
      ongoing:   persistent,
      autoCancel: !persistent,
    );
    const ios = DarwinNotificationDetails(presentAlert: true, presentSound: true);
    await _notifications.show(
      id: id, title: title, body: body,
      notificationDetails: NotificationDetails(android: android, iOS: ios),
      payload: payload,
    );
  }

  // ── Cache persistence ─────────────────────────────────────────────────────
  Future<void> _persistCache() async {
    final prefs = await SharedPreferences.getInstance();
    final historyJson = <String, dynamic>{};
    _historyByCity.forEach((key, value) {
      historyJson[key] = value.map((item) => item.toJson()).toList();
    });
    await prefs.setString(_cacheKey, jsonEncode(<String, dynamic>{
      'last_fetch_time': (_lastFetchTime ?? DateTime.now()).toIso8601String(),
      'levels':  _liveLevels.map((i) => i.toJson()).toList(),
      'alerts':  _criticalAlerts.map((i) => i.toJson()).toList(),
      'history': historyJson,
    }));
  }

  Future<void> _restoreFromCache() async {
    final prefs = await SharedPreferences.getInstance();
    final raw   = prefs.getString(_cacheKey);
    if (raw == null || raw.isEmpty) {
      if (_liveLevels.isEmpty) {
        _liveLevels      = _fallbackMonitoredLevels();
        _isUsingFallback = true;
      }
      return;
    }
    try {
      final parsed = jsonDecode(raw);
      if (parsed is! Map<String, dynamic>) return;

      final rawLevels = parsed['levels'];
      if (rawLevels is List) {
        _liveLevels = rawLevels.whereType<Map<String, dynamic>>().map(FloodData.fromJson).toList(growable: false);
      }

      final rawAlerts = parsed['alerts'];
      if (rawAlerts is List) {
        _criticalAlerts = rawAlerts.whereType<Map<String, dynamic>>().map(FloodAlert.fromJson).toList(growable: false);
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
      _lastFetchTime = DateTime.tryParse((parsed['last_fetch_time'] ?? '').toString());
      _isUsingCache  = true;
    } catch (_) {
      if (_liveLevels.isEmpty) {
        _liveLevels      = _fallbackMonitoredLevels();
        _isUsingFallback = true;
      }
    }
  }

  @override
  void dispose() {
    stopPolling();
    _connectivitySub?.cancel();
    super.dispose();
  }
}
