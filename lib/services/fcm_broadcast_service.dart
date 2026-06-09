// lib/services/fcm_broadcast_service.dart
//
// FIX #6 — 100K-user scale layer
//
// ARCHITECTURE
// ────────────
// Instead of every device independently scraping WRD/CWC (O(N) load on
// government servers), a single Firebase Cloud Function runs server-side,
// fetches the full Bihar snapshot every 60 seconds, and broadcasts it as a
// Firebase Cloud Messaging (FCM) data-only message to the topic
// 'flood_bihar_snapshot'.
//
// All app devices subscribe to that topic. When the FCM push arrives:
//   • FcmBroadcastService receives it via FirebaseMessaging.onMessage
//   • Deserialises the compressed JSON payload into a DataFetchSnapshot
//   • Emits it on the [snapshots] stream
//   • DataFetchEngine._onBroadcastSnapshot() applies it immediately
//
// On-device HTTP fetch (DataFetchEngine._fetchCycle) is SKIPPED as long as
// the FCM snapshot is younger than 3 minutes. It runs only as warm-standby
// when:
//   a. The device has no FCM connectivity (offline / background kill)
//   b. The Cloud Function is down
//   c. App cold-start before first FCM message arrives
//
// CLOUD FUNCTION (deploy separately — not in this repo)
// ─────────────────────────────────────────────────────
// functions/index.js (Firebase Functions v2, Node 20):
//
//   const {onSchedule}  = require('firebase-functions/v2/scheduler');
//   const admin         = require('firebase-admin');
//   const fetch         = require('node-fetch');
//   admin.initializeApp();
//
//   exports.broadcastFloodSnapshot = onSchedule('every 1 minutes', async () => {
//     // 1. Fetch WRD Bihar + CWC
//     const stations = await buildSnapshotJson(); // your server-side logic
//     const payload  = JSON.stringify({ ts: Date.now(), st: stations });
//     await admin.messaging().send({
//       topic: 'flood_bihar_snapshot',
//       data:  { snapshot: payload },
//       android: { priority: 'high', ttl: 90_000 },
//       apns: { headers: { 'apns-priority': '5' } },
//     });
//   });
//
// RESULT
// ──────
// At 100K users:
//   Before: 100K devices × 2 HTTP calls/min = 200K req/min to govt servers
//   After:  1 Cloud Function call/min         = 1 req/min to govt servers
//           FCM delivers to all 100K devices simultaneously at near-zero cost
library;

import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'data_fetch_engine.dart';

class FcmBroadcastService {
  FcmBroadcastService._();
  static final instance = FcmBroadcastService._();

  static const _topic = 'flood_bihar_snapshot';

  final _ctrl = StreamController<DataFetchSnapshot>.broadcast();
  Stream<DataFetchSnapshot> get snapshots => _ctrl.stream;

  bool _initialised = false;

  Future<void> init() async {
    if (_initialised) return;
    _initialised = true;

    try {
      // Subscribe to the broadcast topic
      await FirebaseMessaging.instance.subscribeToTopic(_topic);
      _log('subscribed to FCM topic: $_topic');
    } catch (e) {
      _log('topic subscribe failed (non-fatal): $e');
    }

    // Foreground messages
    FirebaseMessaging.onMessage.listen(_handleMessage);

    // App opened from a background FCM message
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessage);

    // Check for initial message (app killed state)
    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial != null) _handleMessage(initial);
  }

  void _handleMessage(RemoteMessage msg) {
    final raw = msg.data['snapshot'];
    if (raw == null || raw is! String || raw.isEmpty) return;
    final snap = DataFetchSnapshot.fromCompressedJson(raw);
    if (snap == null) return;
    _log('received broadcast: ${snap.stations.length} stations, '
        'age=${DateTime.now().difference(snap.fetchedAt).inSeconds}s');
    if (!_ctrl.isClosed) _ctrl.add(snap);
  }

  void _log(String msg) {
    if (kDebugMode) debugPrint('[FcmBroadcast] $msg');
  }

  void dispose() {
    _ctrl.close();
  }
}
