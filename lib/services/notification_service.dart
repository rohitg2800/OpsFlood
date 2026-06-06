import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Resolves issue #22: Smart Push Notifications with FCM
/// Topic subscription pattern: flood_{state}_{district}
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static const String _historyKey = 'notification_history';
  static const int _maxHistoryItems = 100;

  Future<void> initialize() async {
    // Request permission
    final settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      debugPrint('FCM: Notifications authorized');
    }

    // Init local notifications for foreground display
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    await _localNotifications.initialize(
      const InitializationSettings(
          android: androidSettings, iOS: iosSettings),
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handle background/terminated app message open
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);

    // Subscribe to default topics
    await subscribeToDistrict('bihar', 'all');
  }

  Future<void> subscribeToDistrict(String state, String district) async {
    final topic = 'flood_${state}_$district'
        .toLowerCase()
        .replaceAll(' ', '_');
    await _fcm.subscribeToTopic(topic);
    debugPrint('FCM: Subscribed to topic: $topic');
  }

  Future<void> unsubscribeFromDistrict(String state, String district) async {
    final topic = 'flood_${state}_$district'
        .toLowerCase()
        .replaceAll(' ', '_');
    await _fcm.unsubscribeFromTopic(topic);
  }

  Future<void> subscribeToStation(String stationId) async {
    await _fcm.subscribeToTopic('station_$stationId');
  }

  Future<String?> getToken() async {
    return await _fcm.getToken();
  }

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    await _saveToHistory(message);
    await _showLocalNotification(message);
  }

  void _handleMessageOpenedApp(RemoteMessage message) {
    // Deep-link routing handled here
    final stationId = message.data['station_id'];
    if (stationId != null) {
      debugPrint('FCM: Deep-link to station: $stationId');
      // Navigate to station detail — router handles this
    }
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    const androidDetails = AndroidNotificationDetails(
      'flood_alerts',
      'Flood Alerts',
      channelDescription: 'Real-time flood monitoring alerts',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      icon: '@mipmap/ic_launcher',
      actions: [
        AndroidNotificationAction('view_station', 'View Station'),
        AndroidNotificationAction('dismiss', 'Dismiss'),
      ],
    );
    const notificationDetails =
        NotificationDetails(android: androidDetails);

    await _localNotifications.show(
      notification.hashCode,
      notification.title,
      notification.body,
      notificationDetails,
      payload: jsonEncode(message.data),
    );
  }

  void _onNotificationTap(NotificationResponse response) {
    if (response.payload != null) {
      final data = jsonDecode(response.payload!) as Map<String, dynamic>;
      final stationId = data['station_id'];
      debugPrint('Notification tapped: station=$stationId');
    }
  }

  Future<void> _saveToHistory(RemoteMessage message) async {
    final prefs = await SharedPreferences.getInstance();
    final history = prefs.getStringList(_historyKey) ?? [];
    final item = jsonEncode({
      'title': message.notification?.title ?? '',
      'body': message.notification?.body ?? '',
      'data': message.data,
      'timestamp': DateTime.now().toIso8601String(),
    });
    history.insert(0, item);
    if (history.length > _maxHistoryItems) {
      history.removeLast();
    }
    await prefs.setStringList(_historyKey, history);
  }

  Future<List<Map<String, dynamic>>> getNotificationHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final history = prefs.getStringList(_historyKey) ?? [];
    return history
        .map((e) => jsonDecode(e) as Map<String, dynamic>)
        .toList();
  }

  Future<void> clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_historyKey);
  }
}
