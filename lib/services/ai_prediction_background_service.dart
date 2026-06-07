// lib/services/ai_prediction_background_service.dart
//
// Background service that periodically fetches AI flood predictions for every
// live CWC station and fires a local notification whenever a station's
// severity changes (e.g. LOW → SEVERE).
//
// Architecture
// ────────────
//  • Uses flutter_background_service (Android foreground service /
//    iOS BGProcessingTask) so it runs even when the app is backgrounded.
//  • Polls every 30 minutes.  Interval is configurable via
//    AiPredictionBgService.kPollIntervalMinutes.
//  • Persists the last-known severity per station in SharedPreferences so
//    a severity change is detected across restarts.
//  • On Android the service posts a persistent "Monitoring active" low-
//    priority foreground notification and a high-priority alert if the
//    severity of any station worsens.
//  • Fully self-contained — no Riverpod ProviderContainer needed at
//    startup; makes raw HTTP calls the same way prediction_provider.dart
//    does, then falls back to befiqr CWC simulation.
//
// Setup (call once from main.dart before runApp)
// ─────
//   await AiPredictionBgService.initialise();
//
// Start / stop from UI
// ─────────────────────
//   AiPredictionBgService.start();
//   AiPredictionBgService.stop();
//
// Required pubspec additions
// ──────────────────────────
//   flutter_background_service: ^5.0.10
//   flutter_local_notifications: ^17.2.3
//   shared_preferences: ^2.3.2
//   http: (already present)
library;

import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// ──────────────────────────────────────────────────────────────────────────
// Public API
// ──────────────────────────────────────────────────────────────────────────

class AiPredictionBgService {
  AiPredictionBgService._();

  static const int  kPollIntervalMinutes = 30;
  static const String _channelId   = 'ai_flood_bg';
  static const String _channelName = 'AI Flood Monitor';

  // ── Initialise: registers channels + configures background service ──────
  static Future<void> initialise() async {
    await _initNotifications();
    final service = FlutterBackgroundService();
    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart:           _onStart,
        autoStart:         true,
        isForegroundMode:  true,
        notificationChannelId:   _channelId,
        initialNotificationTitle: 'Flood AI Monitor',
        initialNotificationContent: 'Watching all CWC Bihar stations…',
        foregroundServiceNotificationId: _kFgNotifId,
      ),
      iosConfiguration: IosConfiguration(
        autoStart:  true,
        onForeground: _onStart,
        onBackground: _onIosBackground,
      ),
    );
  }

  static Future<void> start() async {
    final s = FlutterBackgroundService();
    if (!await s.isRunning()) await s.startService();
  }

  static Future<void> stop() async {
    final s = FlutterBackgroundService();
    s.invoke('stopService');
  }

  static Future<bool> get isRunning =>
      FlutterBackgroundService().isRunning();
}

// ──────────────────────────────────────────────────────────────────────────
// Notification setup
// ──────────────────────────────────────────────────────────────────────────

const int _kFgNotifId    = 9000;
const int _kAlertBaseId  = 9100;  // alert IDs = base + station index

final _notif = FlutterLocalNotificationsPlugin();

Future<void> _initNotifications() async {
  const android = AndroidInitializationSettings('@mipmap/ic_launcher');
  const ios     = DarwinInitializationSettings();
  await _notif.initialize(
    const InitializationSettings(android: android, iOS: ios),
  );
  // High-priority alert channel
  const channel = AndroidNotificationChannel(
    AiPredictionBgService._channelId,
    AiPredictionBgService._channelName,
    description: 'Live AI flood severity alerts',
    importance: Importance.high,
    playSound: true,
    enableVibration: true,
  );
  await _notif
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);
}

Future<void> _showAlert({
  required int     id,
  required String  title,
  required String  body,
  bool             highPriority = false,
}) async {
  await _notif.show(
    id,
    title,
    body,
    NotificationDetails(
      android: AndroidNotificationDetails(
        AiPredictionBgService._channelId,
        AiPredictionBgService._channelName,
        importance:  highPriority ? Importance.high : Importance.defaultImportance,
        priority:    highPriority ? Priority.high   : Priority.defaultPriority,
        icon:        '@mipmap/ic_launcher',
        color:       const Color(0xFF00BCD4),
        styleInformation: BigTextStyleInformation(body),
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentSound: true,
      ),
    ),
  );
}

// ──────────────────────────────────────────────────────────────────────────
// iOS background handler (required by package)
// ──────────────────────────────────────────────────────────────────────────

@pragma('vm:entry-point')
FutureOr<bool> _onIosBackground(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  return true;
}

// ──────────────────────────────────────────────────────────────────────────
// Main entry point  (runs in its own Dart isolate on Android)
// ──────────────────────────────────────────────────────────────────────────

@pragma('vm:entry-point')
void _onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();
  await _initNotifications();

  // Allow UI to stop the service gracefully
  service.on('stopService').listen((_) => service.stopSelf());

  // Update foreground notification text
  void setStatus(String msg) {
    if (service is AndroidServiceInstance) {
      service.setForegroundNotificationInfo(
        title:   'Flood AI Monitor',
        content: msg,
      );
    }
  }

  // Run immediately on start then on a periodic timer
  await _pollAll(setStatus);
  Timer.periodic(
    Duration(minutes: AiPredictionBgService.kPollIntervalMinutes),
    (_) => _pollAll(setStatus),
  );
}

// ──────────────────────────────────────────────────────────────────────────
// Poll logic
// ──────────────────────────────────────────────────────────────────────────

const String _backendBase = String.fromEnvironment(
  'BACKEND_URL',
  defaultValue: 'https://opsflood-api.onrender.com',
);

/// All CWC Bihar station names that the befiqr API returns.
/// We derive these from the befiqr endpoint — this list is the seed for the
/// first poll before the live list arrives.
const List<String> _kSeedStations = [
  'Gandhighat',
  'Hathidah',
  'Digha Ghat',
  'Gandhi Setu',
  'Munger',
  'Bhagalpur',
  'Sultanganj',
  'Kahalgaon',
  'Farakka',
  'Birpur',
  'Baltara',
  'Rosera',
  'Benibad',
  'Hayaghat',
  'Khagaria',
  'Minapur',
  'Lalganj',
  'Bettiah',
  'Bagaha',
  'Valmikinagar',
  'Triveni',
  'Banmankhi',
  'Purnea',
  'Forbesganj',
  'Araria',
  'Sitamarhi',
  'Muzaffarpur',
  'Motihari',
  'Darbhanga',
  'Samastipur',
  'Patna',
];

/// Shared-prefs key: last severity per station  (JSON map)
const String _kPrefKey = 'ai_bg_last_severity';

Future<void> _pollAll(void Function(String) setStatus) async {
  final prefs = await SharedPreferences.getInstance();
  final Map<String, String> lastSeverity =
      Map<String, String>.from(
          jsonDecode(prefs.getString(_kPrefKey) ?? '{}') as Map);

  // Try to get live station list from befiqr
  List<String> stations = await _fetchLiveStations();
  if (stations.isEmpty) stations = _kSeedStations;

  setStatus('Refreshing ${stations.length} stations…');

  int alertsFired = 0;
  for (int i = 0; i < stations.length; i++) {
    final site = stations[i];
    try {
      final pred = await _fetchPrediction(site);
      if (pred == null) continue;

      final newSev = _severity(pred['currentLevel'] as double,
          pred['dangerLevel'] as double);
      final oldSev = lastSeverity[site];

      if (oldSev != null && _sevRank(newSev) > _sevRank(oldSev)) {
        // Severity worsened — fire alert notification
        final gap = ((pred['dangerLevel'] as double) -
            (pred['currentLevel'] as double)).abs();
        await _showAlert(
          id:           _kAlertBaseId + i,
          title:        '⚠ $site — $newSev',
          body:         '${_sevEmoji(newSev)} Flood risk escalated from '
                        '$oldSev → $newSev.  '
                        '${gap < 0.5 ? "Only ${gap.toStringAsFixed(2)} m to danger!" : "Gap: ${gap.toStringAsFixed(2)} m"}',
          highPriority: newSev == 'CRITICAL' || newSev == 'SEVERE',
        );
        alertsFired++;
      }

      lastSeverity[site] = newSev;
    } catch (_) {
      // individual station failure — skip silently
    }

    // Small back-off between requests to avoid hammering the API
    await Future<void>.delayed(const Duration(milliseconds: 400));
  }

  await prefs.setString(_kPrefKey, jsonEncode(lastSeverity));

  final now = DateTime.now();
  final ts  = '${now.hour.toString().padLeft(2,'0')}:'
              '${now.minute.toString().padLeft(2,'0')}';
  if (alertsFired > 0) {
    setStatus('$alertsFired alert${alertsFired > 1 ? 's' : ''} · Last sync $ts');
  } else {
    setStatus('All clear · Last sync $ts');
  }
}

// ──────────────────────────────────────────────────────────────────────────
// Fetch helpers
// ──────────────────────────────────────────────────────────────────────────

/// Returns live station site-names from befiqr CWC endpoint.
Future<List<String>> _fetchLiveStations() async {
  try {
    final res = await http
        .get(Uri.parse('https://befiqr.in/cwc-ffs/bihar'))
        .timeout(const Duration(seconds: 15));
    if (res.statusCode == 200) {
      final list = jsonDecode(res.body) as List;
      return list
          .map((e) => (e as Map<String, dynamic>)['site'] as String? ?? '')
          .where((s) => s.isNotEmpty)
          .toList();
    }
  } catch (_) {}
  return [];
}

/// Returns a minimal map with currentLevel + dangerLevel.
/// Priority: 1) backend LSTM  2) befiqr CWC  3) null
Future<Map<String, double>?> _fetchPrediction(String station) async {
  // 1. Backend LSTM
  try {
    final res = await http
        .get(Uri.parse('$_backendBase/api/predict/$station'))
        .timeout(const Duration(seconds: 18));
    if (res.statusCode == 200) {
      final j = jsonDecode(res.body) as Map<String, dynamic>;
      return {
        'currentLevel': (j['current_level'] as num).toDouble(),
        'dangerLevel':  (j['danger_level']  as num).toDouble(),
      };
    }
  } catch (_) {}

  // 2. Befiqr CWC direct
  try {
    final res = await http
        .get(Uri.parse('https://befiqr.in/cwc-ffs/bihar'))
        .timeout(const Duration(seconds: 12));
    if (res.statusCode == 200) {
      final list = jsonDecode(res.body) as List;
      final match = list.cast<Map<String, dynamic>?>().firstWhere(
        (e) => (e?['site'] as String? ?? '')
            .toLowerCase()
            .contains(station.toLowerCase()),
        orElse: () => null,
      );
      if (match != null) {
        final lvl    = (match['current_level']  as num?)?.toDouble() ?? 0;
        final danger = (match['danger_level']   as num?)?.toDouble() ?? 1;
        return {'currentLevel': lvl, 'dangerLevel': danger};
      }
    }
  } catch (_) {}

  return null;
}

// ──────────────────────────────────────────────────────────────────────────
// Severity helpers  (mirror ai_prediction_panel.dart logic)
// ──────────────────────────────────────────────────────────────────────────

String _severity(double level, double danger) {
  if (danger <= 0) return 'LOW';
  final pct = level / danger;
  if (pct >= 1.00) return 'CRITICAL';
  if (pct >= 0.97) return 'SEVERE';
  if (pct >= 0.85) return 'MODERATE';
  return 'LOW';
}

int _sevRank(String s) {
  switch (s) {
    case 'CRITICAL': return 3;
    case 'SEVERE':   return 2;
    case 'MODERATE': return 1;
    default:         return 0;
  }
}

String _sevEmoji(String s) {
  switch (s) {
    case 'CRITICAL': return '🔴';
    case 'SEVERE':   return '🟠';
    case 'MODERATE': return '🟡';
    default:         return '🟢';
  }
}
