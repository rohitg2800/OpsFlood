// lib/services/notification_channel_service.dart
// OpsFlood — Module 7: Push Notifications & FCM Topics
//
// NotificationChannelService
// ─────────────────────────────────────────────────────────────────────────
// Registers 4 Android notification channels and the equivalent
// iOS notification categories at app startup.
//
// Channel hierarchy:
//   flood_emergency  — IMPORTANCE_MAX, red LED, long vibration, heads-up
//   flood_critical   — IMPORTANCE_HIGH, orange LED, medium vibration
//   flood_warning    — IMPORTANCE_DEFAULT, yellow LED, short vibration
//   flood_info       — IMPORTANCE_LOW, cyan LED, silent
//
// Call NotificationChannelService.instance.init() once from main(),
// AFTER _localNotifications.initialize().

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationChannelService {
  NotificationChannelService._();
  static final NotificationChannelService instance =
      NotificationChannelService._();

  static const _channels = [
    _ChannelDef(
      id:          'flood_emergency',
      name:        'Flood Emergency',
      description: 'HFL breach, embankment collapse — highest priority',
      importance:  Importance.max,
      ledColor:    _rgb(0xFF, 0x17, 0x44), // red
      vibration:   [0, 500, 200, 500, 200, 500],
      playSound:   true,
      enableLights: true,
    ),
    _ChannelDef(
      id:          'flood_critical',
      name:        'Flood Critical',
      description: 'Above danger level',
      importance:  Importance.high,
      ledColor:    _rgb(0xFF, 0x6D, 0x00), // orange
      vibration:   [0, 400, 200, 400],
      playSound:   true,
      enableLights: true,
    ),
    _ChannelDef(
      id:          'flood_warning',
      name:        'Flood Warning',
      description: 'Above warning level or rapid rise',
      importance:  Importance.defaultImportance,
      ledColor:    _rgb(0xFF, 0xD6, 0x00), // yellow
      vibration:   [0, 300],
      playSound:   true,
      enableLights: true,
    ),
    _ChannelDef(
      id:          'flood_info',
      name:        'Flood Advisory',
      description: 'Heavy rainfall, general advisories',
      importance:  Importance.low,
      ledColor:    _rgb(0x00, 0xE5, 0xFF), // cyan
      vibration:   [0, 100],
      playSound:   false,
      enableLights: true,
    ),
  ];

  final _plugin = FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    final androidPlugin =
        _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      for (final ch in _channels) {
        await androidPlugin.createNotificationChannel(
          AndroidNotificationChannel(
            ch.id,
            ch.name,
            description:  ch.description,
            importance:   ch.importance,
            ledColor:     ch.ledColor,
            vibrationPattern: Int64List.fromList(ch.vibration),
            playSound:    ch.playSound,
            enableLights: ch.enableLights,
          ),
        );
      }
    }
  }

  /// Returns the [AndroidNotificationDetails] for a given channel ID.
  static AndroidNotificationDetails androidDetails(String channelId) {
    final ch = _channels.firstWhere(
      (c) => c.id == channelId,
      orElse: () => _channels.last,
    );
    return AndroidNotificationDetails(
      ch.id,
      ch.name,
      channelDescription: ch.description,
      importance:         ch.importance,
      priority: ch.importance == Importance.max
          ? Priority.max
          : ch.importance == Importance.high
              ? Priority.high
              : Priority.defaultPriority,
      ledColor:     ch.ledColor,
      vibrationPattern: Int64List.fromList(ch.vibration),
      playSound:    ch.playSound,
      enableLights: ch.enableLights,
      styleInformation: const BigTextStyleInformation(''),
    );
  }

  static Color _rgb(int r, int g, int b) =>
      Color.fromARGB(255, r, g, b);
}

// ── Internal channel definition ───────────────────────────────────────────

import 'dart:typed_data';
import 'package:flutter/painting.dart';

class _ChannelDef {
  final String       id;
  final String       name;
  final String       description;
  final Importance   importance;
  final Color        ledColor;
  final List<int>    vibration;
  final bool         playSound;
  final bool         enableLights;
  const _ChannelDef({
    required this.id,
    required this.name,
    required this.description,
    required this.importance,
    required this.ledColor,
    required this.vibration,
    required this.playSound,
    required this.enableLights,
  });
}
