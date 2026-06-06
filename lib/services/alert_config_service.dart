import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Resolves issue #23: Custom Alert Configuration
/// Stores per-user alert configs in Firestore
class AlertConfig {
  final String id;
  final String userId;
  final String stationId;
  final String stationName;
  final double thresholdMeters;
  final AlertType alertType;
  final bool enabled;
  final QuietHours? quietHours;
  final DateTime? lastTriggered;

  const AlertConfig({
    required this.id,
    required this.userId,
    required this.stationId,
    required this.stationName,
    required this.thresholdMeters,
    required this.alertType,
    this.enabled = true,
    this.quietHours,
    this.lastTriggered,
  });

  factory AlertConfig.fromMap(String id, Map<String, dynamic> map) {
    return AlertConfig(
      id: id,
      userId: map['user_id'] ?? '',
      stationId: map['station_id'] ?? '',
      stationName: map['station_name'] ?? '',
      thresholdMeters: (map['threshold_meters'] ?? 0.0).toDouble(),
      alertType: AlertType.values.firstWhere(
        (e) => e.name == map['alert_type'],
        orElse: () => AlertType.above,
      ),
      enabled: map['enabled'] ?? true,
      quietHours: map['quiet_hours'] != null
          ? QuietHours.fromMap(map['quiet_hours'])
          : null,
      lastTriggered: map['last_triggered'] != null
          ? DateTime.parse(map['last_triggered'])
          : null,
    );
  }

  Map<String, dynamic> toMap() => {
        'user_id': userId,
        'station_id': stationId,
        'station_name': stationName,
        'threshold_meters': thresholdMeters,
        'alert_type': alertType.name,
        'enabled': enabled,
        'quiet_hours': quietHours?.toMap(),
        'last_triggered': lastTriggered?.toIso8601String(),
        'updated_at': FieldValue.serverTimestamp(),
      };

  AlertConfig copyWith({
    bool? enabled,
    double? thresholdMeters,
    QuietHours? quietHours,
  }) =>
      AlertConfig(
        id: id,
        userId: userId,
        stationId: stationId,
        stationName: stationName,
        thresholdMeters: thresholdMeters ?? this.thresholdMeters,
        alertType: alertType,
        enabled: enabled ?? this.enabled,
        quietHours: quietHours ?? this.quietHours,
        lastTriggered: lastTriggered,
      );
}

enum AlertType { above, below }

class QuietHours {
  final String start; // "22:00"
  final String end; // "06:00"

  const QuietHours({required this.start, required this.end});

  factory QuietHours.fromMap(Map<String, dynamic> map) =>
      QuietHours(start: map['start'] ?? '22:00', end: map['end'] ?? '06:00');

  Map<String, dynamic> toMap() => {'start': start, 'end': end};

  bool get isActiveNow {
    final now = DateTime.now();
    final startParts = start.split(':');
    final endParts = end.split(':');
    final startMinutes =
        int.parse(startParts[0]) * 60 + int.parse(startParts[1]);
    final endMinutes = int.parse(endParts[0]) * 60 + int.parse(endParts[1]);
    final currentMinutes = now.hour * 60 + now.minute;
    // Handle overnight quiet hours (e.g., 22:00 to 06:00)
    if (startMinutes > endMinutes) {
      return currentMinutes >= startMinutes || currentMinutes < endMinutes;
    }
    return currentMinutes >= startMinutes && currentMinutes < endMinutes;
  }
}

class AlertConfigService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get _userId => _auth.currentUser?.uid;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('alert_configs');

  Stream<List<AlertConfig>> watchAlertConfigs() {
    if (_userId == null) return const Stream.empty();
    return _collection
        .where('user_id', isEqualTo: _userId)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => AlertConfig.fromMap(doc.id, doc.data()))
            .toList());
  }

  Future<List<AlertConfig>> getAlertConfigs() async {
    if (_userId == null) return [];
    final snap =
        await _collection.where('user_id', isEqualTo: _userId).get();
    return snap.docs
        .map((doc) => AlertConfig.fromMap(doc.id, doc.data()))
        .toList();
  }

  Future<void> createAlertConfig(AlertConfig config) async {
    await _collection.add(config.toMap());
    debugPrint('AlertConfig created for station: ${config.stationId}');
  }

  Future<void> updateAlertConfig(AlertConfig config) async {
    await _collection.doc(config.id).update(config.toMap());
  }

  Future<void> deleteAlertConfig(String configId) async {
    await _collection.doc(configId).delete();
  }

  Future<void> toggleAlertConfig(String configId, bool enabled) async {
    await _collection.doc(configId).update({'enabled': enabled});
  }
}
