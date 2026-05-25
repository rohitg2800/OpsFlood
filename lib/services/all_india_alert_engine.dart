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
//
// Exposes allStations (List<FloodData>) and stateGroups (Map<state, List<FloodData>>)
// for the AlertsScreen to render.
library;

import 'dart:async';
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

  // ── Local notifications setup ─────────────────────────────────────────────
  final FlutterLocalNotificationsPlugin _localNotif =
      FlutterLocalNotificationsPlugin();
  bool _notifInitialised = false;

  // ── State ─────────────────────────────────────────────────────────────────
  List<FloodData>            allStations  = [];
  Map<String, List<FloodData>> stateGroups = {};
  bool                       isLoading    = false;
  DateTime?                  lastPoll;
  String?                    error;

  // Tracks last known risk per city so we only alert on CHANGE
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

  // ── Local notifications init ───────────────────────────────────────────────

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
      // 1. Fetch all-India from backend
      final backendAll = await _stations.fetchAll();

      // 2. Merge with live 10-city data (higher priority — overwrites same city)
      final merged = <String, FloodData>{};
      for (final fd in backendAll) {
        merged['${fd.state}|${fd.city}'.toLowerCase()] = fd;
      }
      for (final fd in _live.liveLevels) {
        merged['${fd.state}|${fd.city}'.toLowerCase()] = fd; // live overrides
      }

      final list = merged.values.toList()
        ..sort((a, b) {
          final r = {'CRITICAL': 4, 'HIGH': 3, 'MODERATE': 2, 'LOW': 1};
          final diff = (r[b.riskLevel] ?? 0) - (r[a.riskLevel] ?? 0);
          return diff != 0 ? diff : a.state.compareTo(b.state);
        });

      allStations = list;

      // 3. Group by state
      final groups = <String, List<FloodData>>{};
      for (final fd in list) {
        groups.putIfAbsent(fd.state, () => []).add(fd);
      }
      stateGroups = groups;

      // 4. Fire alerts for threshold crossings
      await _evaluateAlerts(list);

      lastPoll = DateTime.now();
      error    = null;
      if (kDebugMode) debugPrint('[AllIndiaAlerts] ${list.length} stations, ${groups.length} states');
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

      final crossed = _isWorseThan(current, prev);
      if (!crossed) {
        _lastRisk[key] = current;
        continue;
      }

      _lastRisk[key] = current;

      // Local notification
      if (current == 'CRITICAL' || current == 'HIGH') {
        await _fireLocalNotif(fd);
      }

      // FCM topic subscription: flood_alert_<State>_<City>
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
    return c > p && c >= 2; // only alert on MODERATE or worse
  }

  Future<void> _fireLocalNotif(FloodData fd) async {
    final isCrit  = fd.riskLevel == 'CRITICAL';
    final title   = isCrit
        ? '🚨 CRITICAL: ${fd.city}, ${fd.state}'
        : '⚠️ WARNING: ${fd.city}, ${fd.state}';
    final body    = fd.currentLevel > 0
        ? 'River level ${fd.currentLevel.toStringAsFixed(2)} m'
            ' / Danger ${fd.dangerLevel.toStringAsFixed(2)} m'
        : 'Elevated flood risk on ${fd.riverName ?? "river"}';

    final android = AndroidNotificationDetails(
      'flood_alerts',
      'Flood Alerts',
      channelDescription: 'Live flood risk alerts for Indian cities',
      importance: isCrit ? Importance.max   : Importance.high,
      priority:   isCrit ? Priority.max     : Priority.high,
      color:      isCrit ? const _Color(0xFFD32F2F) : const _Color(0xFFF57C00),
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

  /// Worst risk level for a given state
  String stateRisk(String state) {
    const rank = {'CRITICAL': 4, 'HIGH': 3, 'MODERATE': 2, 'LOW': 1};
    final cities = stateGroups[state] ?? [];
    if (cities.isEmpty) return 'LOW';
    return cities.reduce((a, b) =>
        (rank[a.riskLevel] ?? 0) >= (rank[b.riskLevel] ?? 0) ? a : b).riskLevel;
  }

  /// All cities in a state sorted worst first
  List<FloodData> citiesForState(String state) =>
      (stateGroups[state] ?? [])
        ..sort((a, b) {
          const rank = {'CRITICAL': 4, 'HIGH': 3, 'MODERATE': 2, 'LOW': 1};
          return (rank[b.riskLevel] ?? 0) - (rank[a.riskLevel] ?? 0);
        });

  /// Force a manual refresh
  Future<void> refresh() => _poll();
}

// ignore: avoid_classes_with_only_static_members
class _Color implements Color {
  final int value;
  const _Color(this.value);
  @override int get alpha => (value >> 24) & 0xff;
  @override int get blue  => value & 0xff;
  @override int get green => (value >> 8) & 0xff;
  @override int get red   => (value >> 16) & 0xff;
  @override double computeLuminance() => 0;
  @override Brightness estimateBrightnessForColor() => Brightness.dark;
  @override Color withAlpha(int a) => _Color((value & 0x00ffffff) | (a << 24));
  @override Color withBlue(int b)  => _Color((value & 0xffffff00) | b);
  @override Color withGreen(int g) => _Color((value & 0xff00ffff) | (g << 8));
  @override Color withRed(int r)   => _Color((value & 0x00ffffff) | (r << 16));
  @override Color withOpacity(double opacity) => withAlpha((opacity * 255).round());
  // ignore: deprecated_member_use_from_same_package
  @override Color withValues({int? alpha, int? red, int? green, int? blue, ColorSpace? colorSpace}) =>
      _Color(((alpha ?? this.alpha) << 24) | ((red ?? this.red) << 16) |
             ((green ?? this.green) << 8) | (blue ?? this.blue));
  @override bool operator ==(Object other) => other is Color && other.value == value;
  @override int get hashCode => value.hashCode;
  @override ColorSpace get colorSpace => ColorSpace.sRGB;
  @override double get a => alpha / 255;
  @override double get r => red / 255;
  @override double get g => this.green / 255;
  @override double get b => blue / 255;
}
