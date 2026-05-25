// test/widget_test.dart
// App-level smoke test — verifies widget tree pumps without exception.
//
// FIX: LiveFetchEngine.startPolling() creates a periodic timer (45 s) and
// several one-shot timers via refreshData(). flutter_test's FakeAsync
// environment throws if any timer is still pending when the test ends.
// Solution: tear the widget tree down explicitly (replace with SizedBox)
// so every StatefulWidget.dispose() fires, which calls stopPolling() on
// the RealTimeService → LiveFetchEngine, cancelling all timers.
import 'package:equinox_flood/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('App smoke test — OpsFloodApp pumps without exception',
      (WidgetTester tester) async {
    // Build the app inside a ProviderScope (required for Riverpod).
    await tester.pumpWidget(
      const ProviderScope(child: OpsFloodApp()),
    );

    // Verify the root widget is present.
    expect(find.byType(OpsFloodApp), findsOneWidget);

    // Tear down the widget tree so all State.dispose() calls fire.
    // This cancels the periodic polling timer inside LiveFetchEngine
    // (via RealTimeService.stopPolling / LiveFetchEngine.stopPolling),
    // leaving no pending timers for FakeAsync to complain about.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}
