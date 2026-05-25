// lib/services/fcm_service.dart
//
// OpsFlood — FcmService  (extended for per-city FCM topic management)
//
// New public methods:
//   subscribeToTopic(topic)   — subscribe device to FCM topic
//   unsubscribeFromTopic(topic) — unsubscribe device from FCM topic
//
// Topic naming convention: flood_alert_<State>_<City>
//   e.g. flood_alert_Bihar_Patna
//        flood_alert_Assam_Guwahati
//
// State-level topic:  flood_state_<State>
//   Subscribed automatically when any city in state crosses HIGH/CRITICAL.
//
// The server should publish to these topics when it detects threshold crossings
// via /api/v1/alerts endpoint (handled server-side, not in this file).
library;

import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// Background handler must be top-level
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (kDebugMode) {
    debugPrint('[FCM] Background message: ${message.notification?.title}');
  }
  // Show local notification for background FCM message
  final plugin = FlutterLocalNotificationsPlugin();
  await plugin.initialize(
    const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    ),
  );
  final title = message.notification?.title ?? 'Flood Alert';
  final body  = message.notification?.body  ?? '';
  await plugin.show(
    message.hashCode,
    title,
    body,
    const NotificationDetails(
      android: AndroidNotificationDetails(
        'flood_alerts', 'Flood Alerts',
        importance: Importance.max,
        priority: Priority.max,
        playSound: true,
        enableVibration: true,
      ),
      iOS: DarwinNotificationDetails(
          presentAlert: true, presentSound: true),
    ),
  );
}

class FcmService {
  static final FcmService _instance = FcmService._();
  factory FcmService() => _instance;
  FcmService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotif =
      FlutterLocalNotificationsPlugin();

  String? fcmToken;
  bool    _initialised = false;

  // Tracks subscribed topics to avoid redundant calls
  final Set<String> _subscribed = {};

  // ── Init ────────────────────────────────────────────────────────────────────

  Future<void> init() async {
    if (_initialised) return;
    _initialised = true;

    // Background message handler
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // Request permission
    final settings = await _messaging.requestPermission(
      alert: true, badge: true, sound: true,
    );
    if (kDebugMode) {
      debugPrint('[FCM] Permission: ${settings.authorizationStatus}');
    }

    // Init local notifications
    await _localNotif.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
    );

    // Android notification channel
    await _localNotif
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            'flood_alerts',
            'Flood Alerts',
            description: 'Live flood risk alerts for Indian cities',
            importance: Importance.max,
            playSound: true,
            enableVibration: true,
          ),
        );

    // Get FCM token
    fcmToken = await _messaging.getToken();
    if (kDebugMode) debugPrint('[FCM] token: $fcmToken');

    // Subscribe to all-India topic by default
    await subscribeToTopic('flood_alerts_india');

    // Handle foreground FCM messages
    FirebaseMessaging.onMessage.listen(_handleForeground);

    // Handle notification tap (app in background)
    FirebaseMessaging.onMessageOpenedApp.listen((msg) {
      if (kDebugMode) debugPrint('[FCM] opened: ${msg.notification?.title}');
    });
  }

  // ── Topic management ────────────────────────────────────────────────────────

  Future<void> subscribeToTopic(String topic) async {
    final clean = _cleanTopic(topic);
    if (_subscribed.contains(clean)) return;
    try {
      await _messaging.subscribeToTopic(clean);
      _subscribed.add(clean);
      if (kDebugMode) debugPrint('[FCM] subscribed: $clean');
    } catch (e) {
      if (kDebugMode) debugPrint('[FCM] subscribe error ($clean): $e');
    }
  }

  Future<void> unsubscribeFromTopic(String topic) async {
    final clean = _cleanTopic(topic);
    if (!_subscribed.contains(clean)) return;
    try {
      await _messaging.unsubscribeFromTopic(clean);
      _subscribed.remove(clean);
      if (kDebugMode) debugPrint('[FCM] unsubscribed: $clean');
    } catch (e) {
      if (kDebugMode) debugPrint('[FCM] unsubscribe error ($clean): $e');
    }
  }

  /// Subscribe to all cities in a state at once
  Future<void> subscribeToState(String state) async {
    final topic = 'flood_state_${state.replaceAll(' ', '_')}'
        .replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '');
    await subscribeToTopic(topic);
  }

  Future<void> unsubscribeFromState(String state) async {
    final topic = 'flood_state_${state.replaceAll(' ', '_')}'
        .replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '');
    await unsubscribeFromTopic(topic);
  }

  // ── Foreground message handler ───────────────────────────────────────────────

  Future<void> _handleForeground(RemoteMessage message) async {
    if (kDebugMode) {
      debugPrint('[FCM] Foreground: ${message.notification?.title}');
    }
    final notif = message.notification;
    if (notif == null) return;
    await _localNotif.show(
      message.hashCode,
      notif.title ?? 'Flood Alert',
      notif.body  ?? '',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'flood_alerts', 'Flood Alerts',
          importance: Importance.max,
          priority: Priority.max,
          playSound: true,
          enableVibration: true,
        ),
        iOS: DarwinNotificationDetails(
            presentAlert: true, presentSound: true),
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  /// FCM topic names: max 900 chars, alphanumeric + _ - only
  String _cleanTopic(String raw) =>
      raw.replaceAll(' ', '_')
         .replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '')
         .substring(0, raw.length.clamp(0, 900));

  bool isSubscribed(String topic) => _subscribed.contains(_cleanTopic(topic));
  Set<String> get subscribedTopics => Set.unmodifiable(_subscribed);
}
