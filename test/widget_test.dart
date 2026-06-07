// test/widget_test.dart
// App-level smoke test — pumps the full widget tree without exception.
//
// OpsFloodApp was renamed to EquinoxBHApp in main.dart.
// This test is updated to match.
import 'package:equinox_flood/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('App smoke test — EquinoxBHApp pumps without exception',
      (WidgetTester tester) async {
    // 1. Build the full app tree.
    await tester.pumpWidget(
      const ProviderScope(child: EquinoxBHApp()),
    );

    // 2. Verify root widget mounted.
    expect(find.byType(EquinoxBHApp), findsOneWidget);

    // 3. Advance clock so splash timers fire and complete.
    await tester.pump(const Duration(milliseconds: 2600));

    // 4. Tear down — triggers State.dispose() chain, cancels polling timers.
    await tester.pumpWidget(const SizedBox.shrink());

    // 5. Flush any microtasks from dispose chain.
    await tester.pump(Duration.zero);
    await tester.pump(Duration.zero);
  });
}
