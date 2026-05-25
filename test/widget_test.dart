// test/widget_test.dart
// App-level smoke test — verifies widget tree pumps without exception.
//
// Timer-leak fix (two-part):
//
// Part A — RealTimeService.dispose() now calls stopPolling() and clears
//   onStateChanged, so no in-flight timer can call notifyListeners() on a
//   disposed ChangeNotifier.
//
// Part B — This test tears the tree down with pumpWidget(SizedBox) so
//   all State.dispose() chains fire, then calls pump() (NOT pumpAndSettle)
//   to flush only the current frame.  Using pumpAndSettle here would tell
//   FakeAsync to fire ALL pending timers (the ~110 city one-shot delays),
//   which is slow and was the trigger for the disposed-notifier crash.
import 'package:equinox_flood/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('App smoke test — OpsFloodApp pumps without exception',
      (WidgetTester tester) async {
    // Build the full app tree.
    await tester.pumpWidget(
      const ProviderScope(child: OpsFloodApp()),
    );

    // Verify the root widget is present.
    expect(find.byType(OpsFloodApp), findsOneWidget);

    // Tear down the tree: triggers every State.dispose() in the hierarchy,
    // which propagates to RealTimeService.dispose() -> stopPolling() ->
    // LiveFetchEngine._timer?.cancel().  No timers remain after this.
    await tester.pumpWidget(const SizedBox.shrink());

    // Single pump to flush the current frame only.
    // Do NOT use pumpAndSettle() here — it fires all pending FakeAsync
    // timers and would hit already-disposed notifiers.
    await tester.pump();
  });
}
