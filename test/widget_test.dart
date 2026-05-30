// test/widget_test.dart
// App-level smoke test — verifies widget tree pumps without exception.
//
// TIMER LEAK FIX (v2)
// ─────────────────
// Two timers were pending when the tree was torn down:
//
//   1. LiveFetchEngine — 45 s periodic polling timer (startPolling)
//      Fix: pumpWidget(SizedBox) fires every State.dispose() which
//           propagates → LiveFetchEngine._timer?.cancel()
//
//   2. SplashScreen — 800 ms one-shot (_checkBackend)
//      Fix: pump(900 ms) lets the timer fire and complete BEFORE we
//           dispose the tree, so it is no longer pending at teardown.
//
// Order matters:
//   pump(900ms)          ← splash one-shot fires & completes
//   pumpWidget(SizedBox) ← disposes tree, cancels polling timer
//   pump() x2            ← flushes microtasks from dispose chain
import 'package:equinox_flood/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('App smoke test — OpsFloodApp pumps without exception',
      (WidgetTester tester) async {
    // 1. Build the full app tree.
    await tester.pumpWidget(
      const ProviderScope(child: OpsFloodApp()),
    );

    // 2. Verify root widget mounted.
    expect(find.byType(OpsFloodApp), findsOneWidget);

    // 3. Advance clock by 900 ms so the SplashScreen 800 ms one-shot
    //    timer (_checkBackend) fires and completes naturally.
    //    All HTTP calls inside it return 400 in test environment — that
    //    is expected and handled; no exception is thrown.
    await tester.pump(const Duration(milliseconds: 2600));

    // 4. Tear down the tree. Every State.dispose() fires in order:
    //      SplashScreen → IndiaRiversScreen → LiveFetchEngine._timer.cancel()
    //    The 45 s periodic polling timer is cancelled here.
    await tester.pumpWidget(const SizedBox.shrink());

    // 5. Two pump(Duration.zero) calls flush any microtasks / futures
    //    queued during the dispose chain (e.g. async dispose in services).
    await tester.pump(Duration.zero);
    await tester.pump(Duration.zero);
    // ✓ No timers pending — test framework invariant satisfied.
  });
}
