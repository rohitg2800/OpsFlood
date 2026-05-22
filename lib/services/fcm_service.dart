// OpsFlood — Firebase Cloud Messaging (FCM) Service
// ─────────────────────────────────────────────────────────────────────────────
// P1: Real push delivery for critical flood alerts.
//
// WHY FCM OVER POLLING:
//   HTTP polling discovers alerts only after the poll interval fires.
//   FCM pushes the alert instantly from the backend the moment CWC data
//   crosses a threshold — critical for evacuation decisions.
//
// ARCHITECTURE:
//   Backend (OpsFlood FastAPI) calls:
//     POST https://fcm.googleapis.com/v1/projects/{project}/messages:send
//   With the Server Key stored as an env var (never in this app).
//
//   App-side (this file):
//     1. Initialise firebase_messaging
//     2. Get FCM token → send to OpsFlood backend for registration
//     3. Handle foreground / background / terminated messages
//     4. Map FCM payload to local notification using existing channels
//
// SETUP STEPS (one-time, done outside this file):
//   1. Create a Firebase project at https://console.firebase.google.com
//   2. Add Android app (package: com.opsflood.android)
//      → download google-services.json → place in android/app/
//   3. Add iOS app → download GoogleService-Info.plist → place in ios/Runner/
//   4. Add to pubspec.yaml:
//        firebase_core: ^3.6.0
//        firebase_messaging: ^15.1.3
//   5. Run: flutterfire configure   (installs firebase_options.dart)
//   6. In android/build.gradle add: classpath 'com.google.gms:google-services:4.4.0'
//   7. In android/app/build.gradle add: apply plugin: 'com.google.gms.google-services'
//   8. Enable messaging on OpsFlood backend:
//        Set env var FIREBASE_SERVER_KEY=<key from Firebase Console>
//        Add POST /api/register-device endpoint (see backend README)
//
// NOTE: This file compiles WITHOUT firebase_messaging added to pubspec.yaml.
//       When firebase is not yet configured, it runs in stub mode (noop).
//       Add the packages and uncomment the live implementation when ready.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../constants.dart';

// ─── FCM Payload ──────────────────────────────────────────────────────────────
class FcmFloodAlert {
  final String city;
  final String state;
  final String severity;       // CRITICAL | HIGH | MODERATE
  final String river;
  final double currentLevel;
  final double dangerLevel;
  final String message;
  final DateTime receivedAt;

  const FcmFloodAlert({
    required this.city,
    required this.state,
    required this.severity,
    required this.river,
    required this.currentLevel,
    required this.dangerLevel,
    required this.message,
    required this.receivedAt,
  });

  factory FcmFloodAlert.fromMap(Map<String, dynamic> data) {
    double sf(dynamic v) =>
        v == null ? 0.0 : (double.tryParse(v.toString()) ?? 0.0);
    return FcmFloodAlert(
      city:         (data['city']          ?? data['location'] ?? 'Unknown').toString(),
      state:        (data['state']         ?? '').toString(),
      severity:     (data['severity']      ?? 'HIGH').toString().toUpperCase(),
      river:        (data['river']         ?? data['river_name'] ?? '').toString(),
      currentLevel: sf(data['current_level'] ?? data['river_level']),
      dangerLevel:  sf(data['danger_level']),
      message:      (data['message']       ?? data['body'] ?? '').toString(),
      receivedAt:   DateTime.now(),
    );
  }
}

// ─── FCM Service ──────────────────────────────────────────────────────────────
class FcmService {
  FcmService._();
  static final FcmService instance = FcmService._();

  static const _tokenKey = 'opsflood_fcm_token';

  // Stream controller — screens subscribe to this for live alert badges
  final _alertController = StreamController<FcmFloodAlert>.broadcast();
  Stream<FcmFloodAlert> get alertStream => _alertController.stream;

  String? _token;
  String? get token => _token;

  bool _initialized = false;

  // ── INIT ──────────────────────────────────────────────────────────────────
  // Call once from SplashScreen after RealTimeService.startPolling().
  //
  // When firebase_messaging is added to pubspec, replace the stub block
  // below with the commented live implementation.
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    // ══════════════════════════════════════════════════════════════════════
    // STUB MODE (firebase_messaging not yet in pubspec)
    // ══════════════════════════════════════════════════════════════════════
    if (kDebugMode) {
      debugPrint('[FCM] Running in stub mode. '
          'Add firebase_messaging to pubspec to activate push.');
    }

    // ══════════════════════════════════════════════════════════════════════
    // LIVE MODE — uncomment after: flutter pub add firebase_core firebase_messaging
    //             and running: flutterfire configure
    // ══════════════════════════════════════════════════════════════════════
    //
    // await Firebase.initializeApp(
    //   options: DefaultFirebaseOptions.currentPlatform,
    // );
    //
    // final messaging = FirebaseMessaging.instance;
    //
    // // Request permission (iOS + macOS require this; Android 13+ does too)
    // final settings = await messaging.requestPermission(
    //   alert: true, badge: true, sound: true,
    //   criticalAlert: true,  // shows through Do Not Disturb (iOS)
    // );
    // if (kDebugMode) debugPrint('[FCM] permission: ${settings.authorizationStatus}');
    //
    // // Get device token and register with OpsFlood backend
    // _token = await messaging.getToken();
    // if (_token != null) await _registerTokenWithBackend(_token!);
    //
    // // Listen for token refresh (token rotates after ~60 days)
    // messaging.onTokenRefresh.listen((newToken) async {
    //   _token = newToken;
    //   await _registerTokenWithBackend(newToken);
    // });
    //
    // // ── FOREGROUND messages ──────────────────────────────────────────────
    // // When app is open, FCM does NOT show a notification automatically.
    // // We manually show one via flutter_local_notifications.
    // FirebaseMessaging.onMessage.listen((RemoteMessage msg) {
    //   _handleMessage(msg);
    // });
    //
    // // ── BACKGROUND tap (app was in background, user tapped notification) ─
    // FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage msg) {
    //   _handleMessageTap(msg);
    // });
    //
    // // ── TERMINATED tap (app was closed, user tapped notification) ────────
    // final initial = await messaging.getInitialMessage();
    // if (initial != null) _handleMessageTap(initial);
    //
    // // ── BACKGROUND handler (runs in separate isolate) ─────────────────────
    // FirebaseMessaging.onBackgroundMessage(_fcmBackgroundHandler);
  }

  // ── Register device token with OpsFlood backend ───────────────────────────
  // Backend stores token → sends targeted push when CWC data fires threshold
  Future<void> _registerTokenWithBackend(String token) async {
    try {
      final prefs   = await SharedPreferences.getInstance();
      final old     = prefs.getString(_tokenKey);
      if (old == token) return; // already registered

      final res = await http
          .post(
            Uri.parse('${AppConstants.baseUrl}/api/register-device'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'token':    token,
              'platform': defaultTargetPlatform.name.toLowerCase(),
              'app':      'opsflood_android_v2',
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (res.statusCode == 200 || res.statusCode == 201) {
        await prefs.setString(_tokenKey, token);
        if (kDebugMode) debugPrint('[FCM] device token registered ✅');
      } else {
        if (kDebugMode) debugPrint('[FCM] registration failed: ${res.statusCode}');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[FCM] registration error: $e');
    }
  }

  // ── Handle incoming FCM message (foreground) ──────────────────────────────
  // Parses the data payload and shows a local notification + emits to stream
  void _handleMessage(dynamic msg) {
    try {
      // RemoteMessage has .data (Map<String,String>) and .notification
      final data = (msg.data as Map<Object?, Object?>)
          .map((k, v) => MapEntry(k.toString(), v.toString()));

      final alert = FcmFloodAlert.fromMap(data);
      _alertController.add(alert);
      _showLocalNotification(alert);

      if (kDebugMode) debugPrint('[FCM] foreground alert: ${alert.city} ${alert.severity}');
    } catch (e) {
      if (kDebugMode) debugPrint('[FCM] handleMessage error: $e');
    }
  }

  // ── Handle notification tap ───────────────────────────────────────────────
  void _handleMessageTap(dynamic msg) {
    try {
      final data = (msg.data as Map<Object?, Object?>)
          .map((k, v) => MapEntry(k.toString(), v.toString()));
      final alert = FcmFloodAlert.fromMap(data);
      _alertController.add(alert); // screens receive this and can navigate
      if (kDebugMode) debugPrint('[FCM] tapped alert: ${alert.city}');
    } catch (e) {
      if (kDebugMode) debugPrint('[FCM] handleTap error: $e');
    }
  }

  // ── Show local notification for foreground FCM message ───────────────────
  Future<void> _showLocalNotification(FcmFloodAlert alert) async {
    final plugin = FlutterLocalNotificationsPlugin();
    final isCritical = alert.severity == 'CRITICAL';
    await plugin.show(
      id:    _stableId(alert.city),
      title: '${isCritical ? "🚨" : "⚠️"} ${alert.city} — ${alert.severity}',
      body:  alert.message.isNotEmpty
          ? alert.message
          : '${alert.river} is at ${alert.currentLevel.toStringAsFixed(1)}m '
            '(danger: ${alert.dangerLevel.toStringAsFixed(1)}m)',
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          isCritical
              ? AppConstants.criticalAlertChannelId
              : AppConstants.warningAlertChannelId,
          isCritical
              ? AppConstants.criticalAlertChannelName
              : AppConstants.warningAlertChannelName,
          importance: isCritical ? Importance.max  : Importance.high,
          priority:   isCritical ? Priority.max    : Priority.high,
          ongoing:    isCritical,
          autoCancel: !isCritical,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentSound: true,
          interruptionLevel: InterruptionLevel.timeSensitive,
        ),
      ),
      payload: 'city=${alert.city}&severity=${alert.severity}',
    );
  }

  // ── Unregister on logout ──────────────────────────────────────────────────
  Future<void> unregister() async {
    // await FirebaseMessaging.instance.deleteToken(); // uncomment when live
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    _token = null;
    if (kDebugMode) debugPrint('[FCM] token unregistered');
  }

  void dispose() {
    _alertController.close();
  }

  int _stableId(String city) =>
      city.codeUnits.fold(0, (int a, int b) => (a * 31 + b) & 0x7FFFFFFF);
}

// ── Background FCM handler (top-level, runs in separate isolate) ──────────────
// Required by firebase_messaging for background message handling.
// Uncomment when firebase_messaging is added to pubspec.
//
// @pragma('vm:entry-point')
// Future<void> _fcmBackgroundHandler(RemoteMessage message) async {
//   await Firebase.initializeApp(
//     options: DefaultFirebaseOptions.currentPlatform,
//   );
//   if (kDebugMode) debugPrint('[FCM-BG] ${message.data}');
//   // Background messages are auto-shown by FCM on Android when
//   // notification payload is present. For data-only messages,
//   // show manually via flutter_local_notifications here.
// }
