// Equinox Flood — Background Service
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';         // WidgetsFlutterBinding
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:workmanager/workmanager.dart';

import '../constants.dart';

// FIX: callbackDispatcher runs in a SEPARATE Dart isolate.
// WidgetsFlutterBinding.ensureInitialized() MUST be called first,
// otherwise Workmanager().initialize() crashes with
// "Binding has not yet been initialized".
@pragma('vm:entry-point')
void callbackDispatcher() {
  WidgetsFlutterBinding.ensureInitialized();          // ← FIX
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

// ─────────────────────────────────────────────────────────────────────────────
Future<void> _runKeepAlivePing() async {
  final client = http.Client();
  try {
    final url = Uri.parse('${AppConstants.baseUrl}${AppConstants.healthEndpoint}');
    final res = await client.get(url).timeout(const Duration(seconds: 10));
    if (kDebugMode) debugPrint('[BGS] keep-alive ping → ${res.statusCode}');
  } catch (e) {
    if (kDebugMode) debugPrint('[BGS] keep-alive ping failed (non-fatal): $e');
  } finally {
    client.close();
  }
}

int _stableId(String city) =>
    city.codeUnits.fold(0, (int a, int b) => (a * 31 + b) & 0x7FFFFFFF);

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

    await plugin.show(
      _bgSummaryNotifId,
      '🚨 Equinox Flood — $count critical alert${count > 1 ? 's' : ''}',
      '$firstCity and ${count - 1} other station${count > 1 ? 's are' : ' is'} at critical flood risk.',
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

// ─────────────────────────────────────────────────────────────────────────────
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
      frequency: const Duration(minutes: 15),
      constraints: Constraints(networkType: NetworkType.connected),
    );

    await Workmanager().registerPeriodicTask(
      _keepAliveUniqueName,
      keepAliveTaskName,
      frequency:    const Duration(minutes: 15),
      initialDelay: const Duration(minutes: 7),
      constraints:  Constraints(networkType: NetworkType.connected),
    );

    _registered = true;
    if (kDebugMode) {
      debugPrint('[BGS] refresh task registered  (15 min)');
      debugPrint('[BGS] keep-alive task registered (15 min, offset 7 min)');
    }
  }

  static Future<void> cancel() async {
    await Workmanager().cancelAll();
    _registered = false;
  }
}
