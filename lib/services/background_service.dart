// Equinox Flood — Background Service
// ─────────────────────────────────────────────────────────────────────────────
// P0 FIX: Timer.periodic stops when the app is backgrounded on Android.
// workmanager schedules a real OS-level periodic task that survives the
// app being backgrounded or the screen being locked.

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:workmanager/workmanager.dart';

import '../constants.dart';

// ── Top-level callback required by workmanager (must be top-level / static) ──
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    if (taskName != BackgroundService.taskName) return Future.value(true);
    try {
      await _runBackgroundRefresh();
    } catch (e) {
      if (kDebugMode) debugPrint('[BGS] error: $e');
    }
    return Future.value(true);
  });
}

// Polynomial hash — mirrors real_time_service._stableId() but kept top-level
// so it's accessible from the workmanager isolate without importing UI deps.
int _stableId(String city) =>
    city.codeUnits.fold(0, (int a, int b) => (a * 31 + b) & 0x7FFFFFFF);

// FIX (P2-audit): background summary notification uses a reserved block ABOVE
// the per-city range.  Per-city IDs are ≤ 0x7FFFFFFF (31-bit positive).
// We reserve 0x40000000 (1_073_741_824) as the background summary slot —
// well inside the signed 32-bit positive range and far from any city hash.
const _bgSummaryNotifId = 0x40000000;

Future<void> _runBackgroundRefresh() async {
  final client = http.Client();
  try {
    final base = AppConstants.baseUrl;

    final healthRes = await client
        .get(Uri.parse('$base${AppConstants.healthEndpoint}'))
        .timeout(const Duration(seconds: 10));
    if (healthRes.statusCode != 200) return;

    final levelsRes = await client
        .get(Uri.parse('$base${AppConstants.liveLevelsEndpoint}?limit=50'))
        .timeout(const Duration(seconds: 12));
    if (levelsRes.statusCode != 200) return;

    final body  = jsonDecode(levelsRes.body);
    final items = _extractItems(body);

    final critical = items.whereType<Map<String, dynamic>>().where((item) {
      final pct  = (item['capacity_percent'] as num?)?.toDouble() ?? 0.0;
      final risk = (item['risk_level'] ?? '').toString().toUpperCase();
      return pct >= AppConstants.criticalThreshold || risk == 'CRITICAL';
    }).toList();

    if (critical.isEmpty) return;

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

    // FIX (P2-audit): use _bgSummaryNotifId (reserved constant) instead of
    // hardcoded 99999 which could theoretically collide with a city _stableId.
    await plugin.show(
      _bgSummaryNotifId,
      // FIX (P2-audit): updated notification title to current app name
      '🚨 Equinox Flood — $count critical alert${count > 1 ? 's' : ''}',
      '$firstCity and ${count - 1} other '
          'station${count > 1 ? 's are' : ' is'} at critical flood risk.',
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
  } finally {
    client.close();
  }
}

List<dynamic> _extractItems(dynamic body) {
  if (body is List) return body;
  if (body is Map<String, dynamic>) {
    for (final key in ['data', 'levels', 'result', 'stations', 'items']) {
      final v = body[key];
      if (v is List) return v;
    }
  }
  return const [];
}

class BackgroundService {
  BackgroundService._();

  // FIX (P2-audit): renamed task identifiers from 'opsflood-*' → 'equinox-*'
  // so workmanager registry matches current app brand.
  static const taskName    = 'equinox-refresh';
  static const _uniqueName = 'equinox-periodic-refresh';

  static bool _registered = false;

  static Future<void> init() async {
    if (_registered) return;
    await Workmanager().initialize(
      callbackDispatcher,
      isInDebugMode: kDebugMode,
    );
    await Workmanager().registerPeriodicTask(
      _uniqueName,
      taskName,
      frequency: const Duration(minutes: 15),
      constraints: Constraints(
        networkType: NetworkType.connected,
      ),
    );
    _registered = true;
    if (kDebugMode) debugPrint('[BGS] background refresh registered (15 min)');
  }

  static Future<void> cancel() async {
    await Workmanager().cancelAll();
    _registered = false;
  }
}
