// lib/services/all_india_alert_engine.dart
//
// OpsFlood — AllIndiaAlertEngine
//
// Polls every 5 minutes:
//   1. Fetches all stations from IndiaStationsService (backend + GloFAS)
//   2. Merges with existing 10-city LiveFetchEngine data
//   3. Deduplicates by city+state
//   4. Fires flutter_local_notifications for first-time threshold crossings
//   5. Calls FcmService to subscribe/unsubscribe per-state FCM topics
library;

import 'dart:async';
import 'dart:ui' show Color;
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../models/flood_data.dart';
import 'fcm_service.dart';
import 'india_stations_service.dart';
import 'live_fetch_engine.dart';

class AllIndiaAlertEngine extends ChangeNotifier {
  static final AllIndiaAlertEngine _instance = AllIndiaAlertEngine._();
  factory AllIndiaAlertEngine() => _instance;
  AllIndiaAlertEngine._();

  final IndiaStationsService _stations = IndiaStationsService();
  final LiveFetchEngine      _live     = LiveFetchEngine();
  final FcmService           _fcm      = FcmService();

  final FlutterLocalNotificationsPlugin _localNotif =
      FlutterLocalNotificationsPlugin();
  bool _notifInitialised = false;

  List<FloodData>              allStations  = [];
  Map<String, List<FloodData>> stateGroups  = {};
  bool                         isLoading    = false;
  DateTime?                    lastPoll;
  String?                      error;

  final Map<String, String> _lastRisk = {};
  Timer? _timer;

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  Future<void> start() async {
    await _initLocalNotif();
    _timer?.cancel();
    await _poll();
    _timer = Timer.periodic(const Duration(minutes: 5), (_) => _poll());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _initLocalNotif() async {
    if (_notifInitialised) return;
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios     = DarwinInitializationSettings();
    await _localNotif.initialize(
      const InitializationSettings(android: android, iOS: ios),
    );
    _notifInitialised = true;
  }

  // ── Core poll ──────────────────────────────────────────────────────────────

  Future<void> _poll() async {
    if (isLoading) return;
    isLoading = true;
    notifyListeners();

    try {
      final backendAll = await _stations.fetchAll();

      final merged = <String, FloodData>{};
      for (final fd in backendAll) {
        merged['${fd.state}|${fd.city}'.toLowerCase()] = fd;
      }
      for (final fd in _live.liveLevels) {
        merged['${fd.state}|${fd.city}'.toLowerCase()] = fd;
      }

      final list = merged.values.toList()
        ..sort((a, b) {
          const r = {'CRITICAL': 4, 'HIGH': 3, 'MODERATE': 2, 'LOW': 1};
          final diff = (r[b.riskLevel] ?? 0) - (r[a.riskLevel] ?? 0);
          return diff != 0 ? diff : a.state.compareTo(b.state);
        });

      allStations = list;

      final groups = <String, List<FloodData>>{};
      for (final fd in list) {
        groups.putIfAbsent(fd.state, () => []).add(fd);
      }
      stateGroups = groups;

      await _evaluateAlerts(list);

      lastPoll = DateTime.now();
      error    = null;
      if (kDebugMode) {
        debugPrint('[AllIndiaAlerts] ${list.length} stations, ${groups.length} states');
      }
    } catch (e) {
      error = e.toString();
      if (kDebugMode) debugPrint('[AllIndiaAlerts] error: $e');
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  // ── Alert evaluation ───────────────────────────────────────────────────────

  Future<void> _evaluateAlerts(List<FloodData> stations) async {
    for (final fd in stations) {
      final key     = '${fd.state}|${fd.city}'.toLowerCase();
      final prev    = _lastRisk[key];
      final current = fd.riskLevel;

      if (!_isWorseThan(current, prev)) {
        _lastRisk[key] = current;
        continue;
      }
      _lastRisk[key] = current;

      if (current == 'CRITICAL' || current == 'HIGH') {
        await _fireLocalNotif(fd);
      }

      final topic = 'flood_alert_${fd.state}_${fd.city}'
          .replaceAll(' ', '_')
          .replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '');
      try {
        if (current == 'CRITICAL' || current == 'HIGH') {
          await _fcm.subscribeToTopic(topic);
        } else if (current == 'LOW' || current == 'NORMAL') {
          await _fcm.unsubscribeFromTopic(topic);
        }
      } catch (_) {}
    }
  }

  bool _isWorseThan(String current, String? previous) {
    const rank = {'CRITICAL': 4, 'HIGH': 3, 'MODERATE': 2, 'LOW': 1, 'NORMAL': 0};
    final c = rank[current]  ?? 0;
    final p = rank[previous] ?? 0;
    return c > p && c >= 2;
  }

  Future<void> _fireLocalNotif(FloodData fd) async {
    final isCrit = fd.riskLevel == 'CRITICAL';
    final title  = isCrit
        ? '\ud83d\udea8 CRITICAL: ${fd.city}, ${fd.state}'
        : '\u26a0\ufe0f WARNING: ${fd.city}, ${fd.state}';
    final body   = fd.currentLevel > 0
        ? 'River level ${fd.currentLevel.toStringAsFixed(2)} m'
            ' / Danger ${fd.dangerLevel.toStringAsFixed(2)} m'
        : 'Elevated flood risk on ${fd.riverName ?? "river"}';

    final android = AndroidNotificationDetails(
      'flood_alerts',
      'Flood Alerts',
      channelDescription: 'Live flood risk alerts for Indian cities',
      importance: isCrit ? Importance.max  : Importance.high,
      priority:   isCrit ? Priority.max    : Priority.high,
      // Use plain dart:ui Color — no custom class needed
      color:      isCrit ? const Color(0xFFD32F2F) : const Color(0xFFF57C00),
      icon: '@mipmap/ic_launcher',
      playSound: true,
      enableVibration: true,
    );
    const ios = DarwinNotificationDetails(presentAlert: true, presentSound: true);

    await _localNotif.show(
      fd.city.hashCode,
      title,
      body,
      NotificationDetails(android: android, iOS: ios),
    );
  }

  // ── Public helpers ─────────────────────────────────────────────────────────

  String stateRisk(String state) {
    const rank   = {'CRITICAL': 4, 'HIGH': 3, 'MODERATE': 2, 'LOW': 1};
    final cities = stateGroups[state] ?? [];
    if (cities.isEmpty) return 'LOW';
    return cities.reduce((a, b) =>
        (rank[a.riskLevel] ?? 0) >= (rank[b.riskLevel] ?? 0) ? a : b).riskLevel;
  }

  List<FloodData> citiesForState(String state) {
    final list = List<FloodData>.from(stateGroups[state] ?? []);
    const rank = {'CRITICAL': 4, 'HIGH': 3, 'MODERATE': 2, 'LOW': 1};
    list.sort((a, b) =>
        (rank[b.riskLevel] ?? 0) - (rank[a.riskLevel] ?? 0));
    return list;
  }

  Future<void> refresh() => _poll();
}
