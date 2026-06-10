// lib/utils/performance_monitor.dart
// OpsFlood — Module 9: Performance tracing helpers
//
// Thin wrappers around dart:developer Timeline for Debug/Profile builds.
// All calls are no-ops in release builds (kReleaseMode guard).
//
// Usage:
//   PerfTrace.start('cwc_fetch');
//   await _fetch();
//   PerfTrace.end('cwc_fetch');
//
//   // Or with sync block:
//   PerfTrace.sync('build_chart', () => _buildChart());

import 'dart:developer' as dev;
import 'package:flutter/foundation.dart';

class PerfTrace {
  PerfTrace._();

  static void start(String name) {
    if (kReleaseMode) return;
    dev.Timeline.startSync(name);
  }

  static void end(String name) {
    if (kReleaseMode) return;
    dev.Timeline.finishSync();
  }

  static T sync<T>(String name, T Function() fn) {
    if (kReleaseMode) return fn();
    dev.Timeline.startSync(name);
    try {
      return fn();
    } finally {
      dev.Timeline.finishSync();
    }
  }

  static Future<T> async<T>(
      String name, Future<T> Function() fn) async {
    if (kReleaseMode) return fn();
    final task = dev.TimelineTask()..start(name);
    try {
      return await fn();
    } finally {
      task.finish();
    }
  }

  /// Logs a custom event marker visible in DevTools timeline.
  static void mark(String name,
      [Map<String, dynamic>? data]) {
    if (kReleaseMode) return;
    dev.Timeline.instantSync(name, arguments: data);
  }
}

/// Attaches a [WidgetsBindingObserver] that warns when a frame
/// exceeds [budgetMs] milliseconds.  Call [FrameBudgetGuard.attach()]
/// from main() in debug/profile builds only.
class FrameBudgetGuard extends WidgetsBindingObserver {
  final int budgetMs;
  FrameBudgetGuard({this.budgetMs = 16});

  static void attach({int budgetMs = 16}) {
    if (kReleaseMode) return;
    WidgetsBinding.instance.addObserver(
        FrameBudgetGuard(budgetMs: budgetMs));
  }

  @override
  void didBeginFrame() {
    _start = DateTime.now();
  }

  DateTime _start = DateTime.now();

  @override
  void didDrawFrame() {
    final elapsed =
        DateTime.now().difference(_start).inMilliseconds;
    if (elapsed > budgetMs) {
      // ignore: avoid_print
      debugPrint(
          '⚠️  Frame budget exceeded: ${elapsed}ms (budget ${budgetMs}ms)');
    }
  }
}
