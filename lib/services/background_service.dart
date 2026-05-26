// lib/services/background_service.dart
//
// OpsFlood — Background Service
//
// FIXED (2026-05-26):
//   • Migrated from raw http.Client + AppConstants to OpsClient.
//     Background isolate now shares the same retry/timeout/auth policy
//     as the foreground app. apiToken (if set) is automatically included.
//   • Removed hard-coded timeout literals — all values come from AppConfig.
//   • callbackDispatcher no longer creates a bare http.Client; it calls
//     FloodApi which routes through OpsClient.

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:workmanager/workmanager.dart';

import '../config/app_config.dart';
import '../constants/constants.dart';   // only for notification channel IDs
import 'flood_api.dart';

// callbackDispatcher runs in a SEPARATE Dart isolate.
@pragma('vm:entry-point')
void callbackDispatcher() {
  WidgetsFlutterBinding.ensureInitialized();
  Workmanager().initialize(callbackDispatcher, isInDebugMode: false);

  Workmanager().executeTask((taskName, inputData) async {
    try {
      if (taskName == BackgroundService.keepAliveTaskName) {
        await _runKeepAlivePing();
      } else if (taskName == BackgroundService.refreshTaskName) {
        await _runBackgroundRefresh();
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[BGS] error: $e');
    }
    return Future.value(true);
  });
}

// ── Keep-alive ping ──────────────────────────────────────────────────────────
Future<void> _runKeepAlivePing() async {
  try {
    // Uses healthTimeout (10s) via the coldStart=false path in FloodApi.
    // OpsClient handles retries, auth header, and logging automatically.
    final res = await FloodApi.instance
        .healthCheck(coldStart: false);
    if (kDebugMode) {
      debugPrint('[BGS] keep-alive ping → ${res['status']}');
    }
  } catch (e) {
    if (kDebugMode) debugPrint('[BGS] keep-alive ping failed (non-fatal): $e');
  }
}

// ── Background refresh ────────────────────────────────────────────────────
Future<void> _runBackgroundRefresh() async {
  // Step 1: health check (fast) — abort if backend is down
  final health = await FloodApi.instance.healthCheck(coldStart: false);
  if (health['status'] != 'ok' && health['status'] != 'error' ) {
    // status == 'error' means OpsClient already exhausted retries
    if (health['status'] != 'ok') {
      if (kDebugMode) debugPrint('[BGS] backend unhealthy, skipping refresh');
      return;
    }
  }

  // Step 2: fetch live levels (limit=50 is sufficient for alert scanning)
  final levelsResp = await FloodApi.instance.allLevels(limit: 50);
  if (levelsResp['status'] == 'error') {
    if (kDebugMode) debugPrint('[BGS] allLevels failed: ${levelsResp['error']}');
    return;
  }

  final items = _extractItems(levelsResp);

  final critical = items.whereType<Map<String, dynamic>>().where((item) {
    final pct  = (item['capacity_percent'] as num?)?.toDouble() ?? 0.0;
    final risk = (item['risk_level'] ?? '').toString().toUpperCase();
    return pct >= AppConstants.criticalThreshold || risk == 'CRITICAL';
  }).toList();

  if (critical.isEmpty) return;

  await _sendCriticalNotification(critical);
}

// ── Notification helper ────────────────────────────────────────────────────
const _bgSummaryNotifId = 0x40000000;

Future<void> _sendCriticalNotification(
    List<Map<String, dynamic>> critical) async {
  final plugin = FlutterLocalNotificationsPlugin();
  await plugin.initialize(
    const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS:     DarwinInitializationSettings(),
    ),
  );

  final firstCity = (critical.first['city'] ??
          critical.first['state'] ??
          'Multiple stations')
      .toString();
  final count = critical.length;

  final notifBody = count == 1
      ? '$firstCity is at critical flood risk.'
      : '$firstCity and ${count - 1} other '
        'station${count - 1 == 1 ? '' : 's'} are at critical flood risk.';

  await plugin.show(
    _bgSummaryNotifId,
    '\uD83D\uDEA8 Equinox Flood — $count critical alert${count > 1 ? 's' : ''}',
    notifBody,
    const NotificationDetails(
      android: AndroidNotificationDetails(
        AppConstants.criticalAlertChannelId,
        AppConstants.criticalAlertChannelName,
        importance: Importance.max,
        priority:   Priority.max,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentSound: true,
      ),
    ),
    payload: 'background_critical',
  );
}

// ── Helpers ───────────────────────────────────────────────────────────────
List<dynamic> _extractItems(dynamic body) {
  if (body is List)                     return body;
  if (body is Map<String, dynamic>) {
    for (final key in ['data', 'levels', 'result', 'stations', 'items']) {
      final v = body[key];
      if (v is List) return v;
    }
  }
  return const [];
}

// ── BackgroundService (registration) ─────────────────────────────────
class BackgroundService {
  BackgroundService._();

  static const refreshTaskName   = 'equinox-refresh';
  static const keepAliveTaskName = 'equinox-keep-alive';
  static const taskName          = refreshTaskName;

  static const _refreshUniqueName   = 'equinox-periodic-refresh';
  static const _keepAliveUniqueName = 'equinox-periodic-keep-alive';

  static bool _registered = false;

  static Future<void> init() async {
    if (_registered) return;

    await Workmanager().initialize(
      callbackDispatcher,
      isInDebugMode: kDebugMode,
    );

    await Workmanager().registerPeriodicTask(
      _refreshUniqueName,
      refreshTaskName,
      frequency:   AppConfig.backgroundInterval,
      constraints: Constraints(networkType: NetworkType.connected),
    );

    await Workmanager().registerPeriodicTask(
      _keepAliveUniqueName,
      keepAliveTaskName,
      frequency:    AppConfig.backgroundInterval,
      initialDelay: const Duration(minutes: 7),
      constraints:  Constraints(networkType: NetworkType.connected),
    );

    _registered = true;
    if (kDebugMode) {
      debugPrint('[BGS] refresh task registered  (${AppConfig.backgroundInterval.inMinutes} min)');
      debugPrint('[BGS] keep-alive task registered (${AppConfig.backgroundInterval.inMinutes} min, offset 7 min)');
    }
  }

  static Future<void> cancel() async {
    await Workmanager().cancelAll();
    _registered = false;
  }
}
