// lib/services/backend_health_service.dart
// Fetches /health once at startup and exposes structured backend state
// to the entire app via BackendHealthNotifier (used by backendHealthProvider).

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'api_service.dart';

class BackendHealth {
  final bool isOnline;
  final bool modelReady;
  final int artifactCount;
  final int bundleCount;
  final String version;
  final bool dbReady;
  final bool ingestionRunning;
  final String sourceMode;
  final String sourceLabel;
  final DateTime? fetchedAt;

  const BackendHealth({
    this.isOnline        = false,
    this.modelReady      = false,
    this.artifactCount   = 0,
    this.bundleCount     = 0,
    this.version         = 'unknown',
    this.dbReady         = false,
    this.ingestionRunning = false,
    this.sourceMode      = '',
    this.sourceLabel     = '',
    this.fetchedAt,
  });

  static const BackendHealth offline = BackendHealth();

  factory BackendHealth.fromJson(Map<String, dynamic> j) {
    final db        = j['database']  as Map<String, dynamic>? ?? {};
    final ingestion = j['ingestion'] as Map<String, dynamic>? ?? {};
    final policy    = j['source_policy'] as Map<String, dynamic>? ?? {};
    return BackendHealth(
      isOnline:        j['status'] == 'ok',
      modelReady:      j['model_ready'] == true,
      artifactCount:   (j['artifact_count'] as num?)?.toInt() ?? 0,
      bundleCount:     (j['bundle_count']   as num?)?.toInt() ?? 0,
      version:         j['version']?.toString() ?? 'unknown',
      dbReady:         db['ready'] == true,
      ingestionRunning: ingestion['running'] == true,
      sourceMode:      policy['mode']?.toString() ?? '',
      sourceLabel:     policy['label']?.toString() ?? '',
      fetchedAt:       DateTime.tryParse(j['time']?.toString() ?? ''),
    );
  }

  String get statusLabel {
    if (!isOnline)   return 'Offline';
    if (!modelReady) return 'Online — Model Loading';
    return 'Online ✅';
  }
}

class BackendHealthNotifier extends ChangeNotifier {
  BackendHealth _health = BackendHealth.offline;
  bool _loading = false;

  BackendHealth get health  => _health;
  bool          get loading => _loading;

  Future<void> fetch() async {
    if (_loading) return;
    _loading = true;
    notifyListeners();
    try {
      final raw = await ApiService().checkHealth()
          .timeout(const Duration(seconds: 10),
              onTimeout: () => {'status': 'offline'});
      _health = BackendHealth.fromJson(raw);
    } catch (e) {
      if (kDebugMode) debugPrint('[BackendHealth] fetch error: $e');
      _health = BackendHealth.offline;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }
}
