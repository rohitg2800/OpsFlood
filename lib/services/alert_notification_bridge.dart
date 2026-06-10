// lib/services/alert_notification_bridge.dart
// OpsFlood — Module 7: Push Notifications & FCM Topics
//
// AlertNotificationBridge
// ─────────────────────────────────────────────────────────────────────────
// Bridges:
//   AlertEngine.alertStream  →  NotificationService (local push)
//
// Responsibilities:
//   • Listens to the live AlertEngine stream
//   • Deduplicates: same stationId + same severity suppressed for 30 min
//   • Checks user's NotificationSettings (per-severity enabled flag)
//   • Checks quiet hours (no push during user-configured quiet window)
//   • Maps AlertSeverity → Android notification channel ID
//   • Fires a local notification via NotificationService
//   • Also subscribes the device to the matching FCM severity topic
//     if not already subscribed

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'alert_engine.dart';           // FloodAlert, AlertSeverity
import 'notification_service.dart';   // NotificationService
import 'fcm_topic_manager.dart';      // FcmTopicManager, FcmTopics

class AlertNotificationBridge {
  AlertNotificationBridge._();
  static final AlertNotificationBridge instance =
      AlertNotificationBridge._();

  StreamSubscription<FloodAlert>? _sub;

  // Suppression window per station — key: stationId, value: last fired time
  final _suppressed = <String, DateTime>{};
  static const _suppressWindow = Duration(minutes: 30);

  // ── Start / stop ───────────────────────────────────────────────────

  /// Call from DataFetchEngine.start() or main().
  void start(Stream<FloodAlert> alertStream) {
    _sub?.cancel();
    _sub = alertStream.listen(_onAlert);
    debugPrint('[Bridge] AlertNotificationBridge started');
  }

  void stop() {
    _sub?.cancel();
    _sub = null;
  }

  // ── Alert handler ────────────────────────────────────────────────────

  Future<void> _onAlert(FloodAlert alert) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // 1. Per-severity enabled check
      final enabledKey = 'notif_sev_${alert.severity.name}';
      final enabled = prefs.getBool(enabledKey) ?? true;
      if (!enabled) return;

      // 2. Quiet hours check
      if (await _inQuietHours(prefs)) return;

      // 3. Suppression window
      final key  = '${alert.station}_${alert.severity.name}';
      final last = _suppressed[key];
      if (last != null &&
          DateTime.now().difference(last) < _suppressWindow) {
        return;
      }
      _suppressed[key] = DateTime.now();

      // 4. Fire local notification
      await NotificationService.instance.showFloodAlert(
        id:          alert.id.hashCode & 0x7FFFFFFF,
        title:       _title(alert),
        body:        _body(alert),
        channelId:   _channelId(alert.severity),
        payload:     alert.id,
      );

      // 5. Ensure FCM severity topic is subscribed
      final topic = _severityTopic(alert.severity);
      if (!FcmTopicManager.instance.isSubscribed(topic)) {
        await FcmTopicManager.instance.subscribeTo(topic);
      }
    } catch (e) {
      debugPrint('[Bridge] Error processing alert: $e');
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────

  String _title(FloodAlert alert) {
    final icon = _icon(alert.severity);
    switch (alert.severity) {
      case AlertSeverity.emergency:
        return '$icon EMERGENCY: ${alert.station}';
      case AlertSeverity.critical:
        return '$icon CRITICAL: ${alert.station}';
      case AlertSeverity.warning:
        return '$icon Warning: ${alert.station}';
      case AlertSeverity.info:
        return '$icon Advisory: ${alert.station}';
    }
  }

  String _body(FloodAlert alert) {
    final parts = <String>[];
    if (alert.river.isNotEmpty) parts.add(alert.river);
    if (alert.district.isNotEmpty) parts.add(alert.district);
    if (alert.currentLevel != null) {
      parts.add('Level: ${alert.currentLevel!.toStringAsFixed(2)} m');
    }
    if (alert.thresholdLevel != null) {
      parts.add('Threshold: ${alert.thresholdLevel!.toStringAsFixed(2)} m');
    }
    switch (alert.type) {
      case AlertType.rapidRise:
        if (alert.rateOfRise != null) {
          parts.add(
              'Rise rate: +${alert.rateOfRise!.toStringAsFixed(2)} m/h');
        }
        break;
      case AlertType.rainfallExtreme:
      case AlertType.rainfallHeavy:
        if (alert.rainfall24h != null) {
          parts.add(
              '24h rain: ${alert.rainfall24h!.toStringAsFixed(0)} mm');
        }
        break;
      default:
        break;
    }
    if (alert.isOffline) parts.add('[Offline evaluation]');
    return parts.join('  •  ');
  }

  static String _icon(AlertSeverity s) {
    switch (s) {
      case AlertSeverity.emergency: return '🚨';
      case AlertSeverity.critical:  return '🔴';
      case AlertSeverity.warning:   return '⚠️';
      case AlertSeverity.info:      return 'ℹ️';
    }
  }

  static String _channelId(AlertSeverity s) {
    switch (s) {
      case AlertSeverity.emergency: return 'flood_emergency';
      case AlertSeverity.critical:  return 'flood_critical';
      case AlertSeverity.warning:   return 'flood_warning';
      case AlertSeverity.info:      return 'flood_info';
    }
  }

  static String _severityTopic(AlertSeverity s) {
    switch (s) {
      case AlertSeverity.emergency: return FcmTopics.emergency;
      case AlertSeverity.critical:  return FcmTopics.critical;
      case AlertSeverity.warning:   return FcmTopics.warning;
      case AlertSeverity.info:      return FcmTopics.info;
    }
  }

  Future<bool> _inQuietHours(SharedPreferences prefs) async {
    final enabled = prefs.getBool('quiet_hours_enabled') ?? false;
    if (!enabled) return false;
    final startH = prefs.getInt('quiet_start_hour') ?? 22;
    final startM = prefs.getInt('quiet_start_min')  ?? 0;
    final endH   = prefs.getInt('quiet_end_hour')   ?? 7;
    final endM   = prefs.getInt('quiet_end_min')    ?? 0;
    final now    = TimeOfDay.now();
    final nowMins   = now.hour * 60 + now.minute;
    final startMins = startH  * 60 + startM;
    final endMins   = endH    * 60 + endM;
    // Handle overnight window (e.g. 22:00 → 07:00)
    if (startMins > endMins) {
      return nowMins >= startMins || nowMins < endMins;
    }
    return nowMins >= startMins && nowMins < endMins;
  }
}

// Minimal TimeOfDay shim so this service has no UI dependency
class TimeOfDay {
  final int hour;
  final int minute;
  const TimeOfDay({required this.hour, required this.minute});
  static TimeOfDay now() {
    final dt = DateTime.now();
    return TimeOfDay(hour: dt.hour, minute: dt.minute);
  }
}
