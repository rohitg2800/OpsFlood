// lib/services/rtdas_threshold_sync_service.dart
//
// Periodic background sync: RTDAS → ThresholdOverrideStore.
//
// Schedule:
//   - On app start: sync immediately if data is stale (>18 h) or missing.
//   - Thereafter:  Timer.periodic(6 h) for the lifetime of the app.
//
// Failure model:
//   - All failures are caught and logged; the app NEVER crashes.
//   - On failure the existing store values are left intact (hardcoded v4
//     bihar_rivers.dart values remain the fallback).
//
// Thread safety:
//   - _doSync() is guarded by _syncing flag so concurrent timer fires
//     (e.g. if forceSync() is called while a background sync is running)
//     produce only one HTTP request.
library;

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'rtdas_threshold_scraper.dart';
import 'threshold_override_store.dart';

class RtdasThresholdSyncService {
  // How often to re-check RTDAS for threshold changes.
  static const _syncInterval = Duration(hours: 6);

  // Consider data stale and force a re-fetch after this many hours.
  static const _staleHoursGuard = 18.0;

  // SharedPrefs sentinel key that tracks last full-table sync timestamp.
  static const _syncSentinelKey = '__last_full_sync__';

  // Singleton
  static RtdasThresholdSyncService? _instance;
  static RtdasThresholdSyncService get instance =>
      _instance ??= RtdasThresholdSyncService._();
  RtdasThresholdSyncService._();

  final _scraper = RtdasThresholdScraper();
  final _store   = ThresholdOverrideStore.instance;

  Timer?  _timer;
  bool    _syncing = false;
  bool    _started = false;

  /// Notifier: incremented each time at least one station threshold changes.
  /// Riverpod providers or ValueListenableBuilders can watch this.
  final updatedCount = ValueNotifier<int>(0);

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Call once from main.dart (and once from BiharLiveEngine.start).
  /// Idempotent — safe to call multiple times.
  Future<void> start() async {
    if (_started) return;
    _started = true;

    await _store.load();
    await _syncIfNeeded();

    _timer?.cancel();
    _timer = Timer.periodic(_syncInterval, (_) => _syncIfNeeded());
    debugPrint('[RtdasSync] started — interval=${_syncInterval.inHours}h');
  }

  void stop() {
    _timer?.cancel();
    _started = false;
    debugPrint('[RtdasSync] stopped.');
  }

  /// Trigger an immediate sync regardless of staleness.
  /// E.g. called from a "Refresh" button in Settings.
  Future<void> forceSync() => _doSync();

  // ── Internal ───────────────────────────────────────────────────────────────

  Future<void> _syncIfNeeded() async {
    final stale = _store.isStale(_syncSentinelKey,
        maxHours: _staleHoursGuard);
    if (!stale) {
      debugPrint('[RtdasSync] data is fresh — skipping sync');
      return;
    }
    await _doSync();
  }

  Future<void> _doSync() async {
    if (_syncing) {
      debugPrint('[RtdasSync] already syncing — skipping concurrent call');
      return;
    }
    _syncing = true;
    debugPrint('[RtdasSync] starting full RTDAS threshold sync …');

    try {
      final rows = await _scraper.fetch();
      int changed  = 0;
      int skipped  = 0;

      for (final row in rows) {
        final key      = _norm(row.station);
        final existing = _store.get(key);

        final dlSame  = existing?.dl  == row.dangerLevel;
        final wlSame  = existing?.wl  == row.warningLevel;
        final hflSame = existing?.hfl == row.hfl;

        if (dlSame && wlSame && hflSame) {
          skipped++;
          continue;
        }

        _store.put(key, ThresholdEntry(
          wl:        row.warningLevel,
          dl:        row.dangerLevel,
          hfl:       row.hfl,
          source:    'RTDAS/${row.maintainedBy ?? "WRD"}',
          fetchedAt: DateTime.now(),
        ));
        changed++;

        if (kDebugMode) {
          debugPrint('[RtdasSync]  ↳ UPDATED $key  '
              'WL=${row.warningLevel}  DL=${row.dangerLevel}  HFL=${row.hfl}  '
              '(was WL=${existing?.wl}  DL=${existing?.dl}  HFL=${existing?.hfl})');
        }
      }

      // Stamp the sentinel with NOW so _syncIfNeeded() backs off for _staleHoursGuard h.
      _store.put(_syncSentinelKey, ThresholdEntry(
        source:    'sentinel',
        fetchedAt: DateTime.now(),
      ));

      await _store.save();
      updatedCount.value += changed;

      debugPrint('[RtdasSync] DONE — $changed updated / $skipped unchanged '
          '/ ${rows.length} total rows');
    } catch (e, st) {
      debugPrint('[RtdasSync] ERROR during sync: $e\n$st');
      // Do NOT update the sentinel — the next _syncIfNeeded() call will retry.
    } finally {
      _syncing = false;
    }
  }

  static String _norm(String v) => v
      .toLowerCase()
      .replaceAll(RegExp(r'\s*\(.*?\)'), '')
      .replaceAll(RegExp(r'[^a-z0-9 ]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}
